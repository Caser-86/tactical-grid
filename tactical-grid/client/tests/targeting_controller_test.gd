## TargetingController 统一目标选择状态机测试
## 覆盖五类目标：自身、友方、敌方、位置、任意单位
## 测试范围、视线、阵营过滤和取消机制
extends Node

const TargetingControllerScript = preload("res://scripts/game/targeting_controller.gd")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []

func _ready() -> void:
	print("=== TargetingController 统一目标选择状态机测试 ===")
	# 清理存档，避免 autoload 副作用
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	_test_self_target()
	_test_ally_target_with_range()
	_test_enemy_target_with_los()
	_test_position_target_with_area()
	_test_any_unit_target_team_filter()
	_test_cancel_clears_state()
	_test_invalid_cell_rejected()
	_test_infer_skill_spec_static()
	_test_infer_item_spec_static()
	_test_query_preview_attached_to_target_data()

	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)

## 创建测试用 Unit 实例（不加入场景树）
func _make_unit(team: String, grid_pos: Vector2i, name: String = "") -> Unit:
	var u = Unit.new()
	u.unit_name = name if name != "" else (team + "_unit")
	u.team = team
	u.grid_pos = grid_pos
	u.max_hp = 100
	u.current_hp = 100
	u.max_ap = 2
	u.current_ap = 2
	u.move_points = 5
	u.weapon_range = [1, 5]
	u.weapon_damage = [20, 30]
	return u

## 创建 TargetingController 实例并加入场景树（信号需要）
func _make_controller() -> TargetingController:
	var tc = TargetingController.new()
	add_child(tc)
	return tc

## 构建标准上下文
func _make_context(players: Array, enemies: Array, los_check: Callable = Callable()) -> Dictionary:
	var ctx := {
		"map_width": 10,
		"map_height": 8,
		"players": players,
		"enemies": enemies,
		"los_check": los_check,
	}
	return ctx

## 无视线阻挡的默认视线检查器
func _always_true_los(_from: Vector2i, _to: Vector2i) -> bool:
	return true

## 始终无视线
func _always_false_los(_from: Vector2i, _to: Vector2i) -> bool:
	return false

## 测试 1: 自身目标
func _test_self_target() -> void:
	print("\n--- 测试: 自身目标 (TARGET_SELF) ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(1, 1), "caster")
	var spec := {
		"target_type": TargetingControllerScript.TARGET_SELF,
		"range": 0,
		"team_filter": TargetingControllerScript.TEAM_SELF,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	var ctx = _make_context([caster], [])
	tc.begin(caster, "test_self_skill", spec, ctx)
	_check(tc.is_active, "begin 后 is_active=true")
	var valid = tc.get_valid_cells()
	_check(valid.size() == 1, "自身目标合法格数为 1 (实际: %d)" % valid.size())
	_check(valid.has(Vector2i(1, 1)), "合法格包含施法者位置")
	var result = tc.try_confirm(Vector2i(1, 1))
	_check(result.get("success", false), "确认自身目标成功")
	var data = result.get("target_data", {})
	_check(data.get("position") == Vector2i(1, 1), "target_data.position 正确")
	_check(data.get("target_unit") == caster, "target_data.target_unit 为施法者")
	_check(not tc.is_active, "确认后 is_active=false")
	tc.queue_free()

## 测试 2: 友方目标 + 范围限制
func _test_ally_target_with_range() -> void:
	print("\n--- 测试: 友方目标 + 范围限制 (TARGET_ALLY, range=3) ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(2, 2), "medic")
	var ally_near = _make_unit("player", Vector2i(2, 3), "ally_near")  # 距离 1
	var ally_far = _make_unit("player", Vector2i(8, 8), "ally_far")  # 距离 12
	var players = [caster, ally_near, ally_far]
	var spec := {
		"target_type": TargetingControllerScript.TARGET_ALLY,
		"range": 3,
		"team_filter": TargetingControllerScript.TEAM_ALLY,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	var ctx = _make_context(players, [], Callable(self, "_always_true_los"))
	tc.begin(caster, "medic_heal", spec, ctx)
	var valid = tc.get_valid_cells()
	_check(valid.has(Vector2i(2, 3)), "近距友方 (2,3) 在合法目标中")
	_check(not valid.has(Vector2i(8, 8)), "远距友方 (8,8) 不在合法目标中（超出 range=3）")
	_check(valid.has(Vector2i(2, 2)), "施法者自身在友方目标中（医疗技能允许自身）")
	# 确认近距友方
	var result = tc.try_confirm(Vector2i(2, 3))
	_check(result.get("success", false), "确认近距友方成功")
	var data = result.get("target_data", {})
	_check(data.get("target_unit") == ally_near, "target_data.target_unit 为近距友方")
	tc.queue_free()

## 测试 3: 敌方目标 + 视线要求
func _test_enemy_target_with_los() -> void:
	print("\n--- 测试: 敌方目标 + 视线 (TARGET_ENEMY, requires_los=true) ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(1, 1), "sniper")
	var enemy_visible = _make_unit("enemy", Vector2i(2, 2), "enemy_vis")  # 距离 2
	var enemy_blocked = _make_unit("enemy", Vector2i(5, 5), "enemy_blocked")  # 距离 8，超范围
	var enemies = [enemy_visible, enemy_blocked]
	var spec := {
		"target_type": TargetingControllerScript.TARGET_ENEMY,
		"range": 5,
		"team_filter": TargetingControllerScript.TEAM_ENEMY,
		"requires_los": true,
		"area_radius": 0,
		"action_kind": "skill",
	}
	# 先用 always_true_los 测试范围
	var ctx = _make_context([caster], enemies, Callable(self, "_always_true_los"))
	tc.begin(caster, "snip_precise", spec, ctx)
	var valid = tc.get_valid_cells()
	_check(valid.has(Vector2i(2, 2)), "可见敌人 (2,2) 在合法目标中")
	_check(not valid.has(Vector2i(5, 5)), "超范围敌人 (5,5) 不在合法目标中")
	tc.cancel()
	# 再用 always_false_los 测试视线
	var ctx2 = _make_context([caster], enemies, Callable(self, "_always_false_los"))
	tc.begin(caster, "snip_precise", spec, ctx2)
	var valid2 = tc.get_valid_cells()
	_check(valid2.size() == 0, "视线全部阻挡时无合法敌方目标 (实际: %d)" % valid2.size())
	tc.cancel()
	tc.queue_free()

## 测试 4: 位置目标 + 范围效果
func _test_position_target_with_area() -> void:
	print("\n--- 测试: 位置目标 + 范围效果 (TARGET_POSITION, area_radius=1) ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(3, 3), "grenadier")
	var spec := {
		"target_type": TargetingControllerScript.TARGET_POSITION,
		"range": 4,
		"team_filter": TargetingControllerScript.TEAM_ANY,
		"requires_los": false,
		"area_radius": 1,
		"action_kind": "skill",
	}
	var ctx = _make_context([caster], [])
	tc.begin(caster, "heavy_grenade", spec, ctx)
	var valid = tc.get_valid_cells()
	_check(valid.size() > 0, "位置目标有合法格 (实际: %d)" % valid.size())
	_check(valid.has(Vector2i(3, 3)), "施法者自身格为合法位置目标")
	_check(valid.has(Vector2i(4, 4)), "距离 2 的格为合法位置目标")
	_check(not valid.has(Vector2i(8, 8)), "超范围格不合法")
	# 确认 (4,4)，应附带 area_cells
	var result = tc.try_confirm(Vector2i(4, 4))
	_check(result.get("success", false), "确认位置目标 (4,4) 成功")
	var data = result.get("target_data", {})
	_check(data.get("area_radius") == 1, "target_data.area_radius=1")
	var area_cells = data.get("area_cells", [])
	_check(area_cells.size() == 9, "3x3 范围包含 9 格 (实际: %d)" % area_cells.size())
	_check(area_cells.has(Vector2i(4, 4)), "范围包含中心格")
	_check(area_cells.has(Vector2i(3, 3)), "范围包含 (3,3)")
	_check(area_cells.has(Vector2i(5, 5)), "范围包含 (5,5)")
	tc.queue_free()

## 测试 5: 任意单位目标 + 阵营过滤
func _test_any_unit_target_team_filter() -> void:
	print("\n--- 测试: 任意单位目标 (TARGET_ANY_UNIT, team_filter=any) ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(2, 2), "caster")
	var ally = _make_unit("player", Vector2i(2, 3), "ally")  # 距离 1
	var enemy = _make_unit("enemy", Vector2i(3, 2), "enemy")  # 距离 1
	var spec := {
		"target_type": TargetingControllerScript.TARGET_ANY_UNIT,
		"range": 3,
		"team_filter": TargetingControllerScript.TEAM_ANY,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	var ctx = _make_context([caster, ally], [enemy])
	tc.begin(caster, "test_any", spec, ctx)
	var valid = tc.get_valid_cells()
	_check(valid.has(Vector2i(2, 3)), "任意单位目标包含友方格")
	_check(valid.has(Vector2i(3, 2)), "任意单位目标包含敌方格")
	var units = tc.get_valid_units()
	_check(units.has(ally), "合法单位包含友方")
	_check(units.has(enemy), "合法单位包含敌方")
	tc.cancel()
	tc.queue_free()

## 测试 6: 取消机制
func _test_cancel_clears_state() -> void:
	print("\n--- 测试: 取消机制 ---")
	var tc = _make_controller()
	# GDScript lambda 对基本类型按值捕获，用字典传递可变状态
	var state := {"cancelled": false}
	tc.targeting_cancelled.connect(func(): state["cancelled"] = true)
	var caster = _make_unit("player", Vector2i(1, 1), "caster")
	var spec := {
		"target_type": TargetingControllerScript.TARGET_ENEMY,
		"range": 3,
		"team_filter": TargetingControllerScript.TEAM_ENEMY,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	var enemy = _make_unit("enemy", Vector2i(2, 2), "enemy")
	var ctx = _make_context([caster], [enemy], Callable(self, "_always_true_los"))
	tc.begin(caster, "test_cancel", spec, ctx)
	_check(tc.is_active, "begin 后激活")
	_check(tc.get_action_id() == "test_cancel", "action_id 正确")
	tc.cancel()
	_check(not tc.is_active, "cancel 后 is_active=false")
	_check(bool(state["cancelled"]), "targeting_cancelled 信号已触发")
	_check(tc.get_valid_cells().size() == 0, "cancel 后合法格列表为空")
	_check(tc.get_actor() == null, "cancel 后 actor 为 null")
	tc.queue_free()

## 测试 7: 无效格子被拒绝
func _test_invalid_cell_rejected() -> void:
	print("\n--- 测试: 无效格子被拒绝 ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(1, 1), "caster")
	var enemy = _make_unit("enemy", Vector2i(2, 2), "enemy")
	var spec := {
		"target_type": TargetingControllerScript.TARGET_ENEMY,
		"range": 3,
		"team_filter": TargetingControllerScript.TEAM_ENEMY,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	var ctx = _make_context([caster], [enemy], Callable(self, "_always_true_los"))
	tc.begin(caster, "test_invalid", spec, ctx)
	# (5,5) 不在合法目标中
	var result = tc.try_confirm(Vector2i(5, 5))
	_check(not result.get("success", false), "无效格子 (5,5) 被拒绝")
	_check(result.get("reason") == "invalid_cell", "拒绝原因=invalid_cell (实际: %s)" % result.get("reason", ""))
	_check(tc.is_active, "拒绝后仍处于激活状态")
	# 边界外
	var result2 = tc.try_confirm(Vector2i(-1, -1))
	_check(not result2.get("success", false), "边界外格 (-1,-1) 被拒绝")
	_check(result2.get("reason") == "out_of_bounds", "拒绝原因=out_of_bounds (实际: %s)" % result2.get("reason", ""))
	# 正确目标
	var result3 = tc.try_confirm(Vector2i(2, 2))
	_check(result3.get("success", false), "合法格 (2,2) 确认成功")
	tc.queue_free()

## 测试 8: 静态方法 infer_skill_spec
func _test_infer_skill_spec_static() -> void:
	print("\n--- 测试: infer_skill_spec 静态推断 ---")
	var caster = _make_unit("player", Vector2i(1, 1), "caster")
	# 自身技能
	var spec_self = TargetingControllerScript.infer_skill_spec("asslt_adrenaline", {}, caster)
	_check(spec_self.get("target_type") == TargetingControllerScript.TARGET_SELF, "asslt_adrenaline 推断为 SELF")
	# 敌方技能
	var spec_enemy = TargetingControllerScript.infer_skill_spec("snip_precise", {}, caster)
	_check(spec_enemy.get("target_type") == TargetingControllerScript.TARGET_ENEMY, "snip_precise 推断为 ENEMY")
	_check(spec_enemy.get("requires_los") == true, "snip_precise 要求视线")
	_check(int(spec_enemy.get("range", 0)) == 5, "snip_precise range=武器最大射程 5 (实际: %d)" % int(spec_enemy.get("range", 0)))
	# 位置技能（范围）
	var spec_pos = TargetingControllerScript.infer_skill_spec("heavy_grenade", {}, caster)
	_check(spec_pos.get("target_type") == TargetingControllerScript.TARGET_POSITION, "heavy_grenade 推断为 POSITION")
	_check(int(spec_pos.get("area_radius", 0)) == 1, "heavy_grenade area_radius=1")
	# 友方技能
	var spec_ally = TargetingControllerScript.infer_skill_spec("medic_heal", {}, caster)
	_check(spec_ally.get("target_type") == TargetingControllerScript.TARGET_ALLY, "medic_heal 推断为 ALLY")
	# 显式 target 字段优先
	var explicit_data := {"target": "enemy", "range": 7}
	var spec_explicit = TargetingControllerScript.infer_skill_spec("custom_skill", explicit_data, caster)
	_check(spec_explicit.get("target_type") == TargetingControllerScript.TARGET_ENEMY, "显式 target=enemy 优先")
	_check(int(spec_explicit.get("range", 0)) == 7, "显式 range=7 生效 (实际: %d)" % int(spec_explicit.get("range", 0)))

## 测试 9: 静态方法 infer_item_spec
func _test_infer_item_spec_static() -> void:
	print("\n--- 测试: infer_item_spec 静态推断 ---")
	var user = _make_unit("player", Vector2i(1, 1), "user")
	# 消耗品（自身）
	var med_kit := {"type": "consumable", "effect": {"heal": 40}}
	var spec_consumable = TargetingControllerScript.infer_item_spec("med_kit", med_kit, user)
	_check(spec_consumable.get("target_type") == TargetingControllerScript.TARGET_SELF, "med_kit 推断为 SELF")
	# 投掷物（位置）
	var grenade := {"type": "throwable", "effect": {"damage": [40, 60], "area": "3x3"}}
	var spec_throw = TargetingControllerScript.infer_item_spec("frag_grenade", grenade, user)
	_check(spec_throw.get("target_type") == TargetingControllerScript.TARGET_POSITION, "手雷推断为 POSITION")
	_check(int(spec_throw.get("area_radius", 0)) == 1, "3x3 区域 area_radius=1")
	_check(int(spec_throw.get("range", 0)) == 5, "默认投掷距离=5")
	# 复活针（友方）
	var revive := {"type": "consumable", "effect": {"revive": true, "hp_percent": 0.3}}
	var spec_revive = TargetingControllerScript.infer_item_spec("revive_shot", revive, user)
	_check(spec_revive.get("target_type") == TargetingControllerScript.TARGET_ALLY, "复活针推断为 ALLY")
	# 陷阱（自身）
	var mine := {"type": "trap", "effect": {"damage": 60}}
	var spec_trap = TargetingControllerScript.infer_item_spec("mine", mine, user)
	_check(spec_trap.get("target_type") == TargetingControllerScript.TARGET_SELF, "地雷推断为 SELF")

## CODE-CH1-010: 目标选择通过 query_action 获取预览，target_data 包含 cost 和 hit_chance
func _test_query_preview_attached_to_target_data() -> void:
	print("\n--- 测试: 目标选择返回的预览数据包含 cost 和 hit_chance ---")
	var tc = _make_controller()
	var caster = _make_unit("player", Vector2i(1, 1), "caster")
	var enemy = _make_unit("enemy", Vector2i(2, 2), "enemy")
	var spec := {
		"target_type": TargetingControllerScript.TARGET_ENEMY,
		"range": 5,
		"team_filter": TargetingControllerScript.TEAM_ENEMY,
		"requires_los": false,
		"area_radius": 0,
		"action_kind": "skill",
	}
	var stub = _StubActionSystem.new()
	stub.query_result = {
		"valid": true,
		"cost": {"ap": 2, "move": 0},
		"hit_chance": 0.85,
		"damage": 25,
	}
	var ctx = _make_context([caster], [enemy], Callable(self, "_always_true_los"))
	ctx["action_system"] = stub
	tc.begin(caster, "snip_precise", spec, ctx)
	var result = tc.try_confirm(Vector2i(2, 2))
	_check(result.get("success", false), "确认敌方目标成功")
	var data = result.get("target_data", {})
	_check(data.has("cost"), "target_data 包含 cost (来自 query_action 预览)")
	_check(int(data.get("cost", {}).get("ap", 0)) == 2, "cost.ap=2 (实际: %d)" % int(data.get("cost", {}).get("ap", 0)))
	_check(data.has("hit_chance"), "target_data 包含 hit_chance (来自 query_action 预览)")
	_check(abs(float(data.get("hit_chance", 0.0)) - 0.85) < 0.001, "hit_chance=0.85 (实际: %s)" % str(data.get("hit_chance")))
	# 验证 stub 收到了 query 请求
	_check(stub.last_request.get("action") == &"skill", "stub 收到 action=skill 的 query 请求")
	_check(stub.last_request.get("action_id") == "snip_precise", "stub 收到正确的 action_id")
	_check(stub.last_request.get("target") == enemy, "stub 收到 target=敌方单位")
	tc.queue_free()

## CODE-CH1-010: 用于测试的 action_system 桩件，模拟 query_action 返回预览数据
class _StubActionSystem:
	extends RefCounted
	var query_result: Dictionary = {}
	var last_request: Dictionary = {}
	func query_action(request: Dictionary) -> Dictionary:
		last_request = request.duplicate(true)
		return query_result

func _print_summary() -> void:
	print("\n=== 测试汇总 ===")
	print("通过: %d" % _passed)
	print("失败: %d" % _failed)
	if _errors.size() > 0:
		print("失败项:")
		for e in _errors:
			print("  - ", e)
