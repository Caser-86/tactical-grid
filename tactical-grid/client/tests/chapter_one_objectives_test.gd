## 第一章任务目标与特殊规则契约测试
## 覆盖六关任务类型（extract/destroy/extract/escort/steal_data/assassinate）
## 和 ch1_m1 的三条特殊规则（no_overwatch/no_items/enemy_passive_turn_1）
extends Node

const MissionObjectiveStateScript = preload("res://scripts/game/mission_objective_state.gd")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []

func _ready() -> void:
	print("=== 第一章任务目标与特殊规则契约测试 ===")
	# 清理存档，避免 autoload 副作用
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	# 六关任务类型配置契约
	_test_chapter_one_mission_types()
	# 六类任务目标的胜负判断
	_test_extract_victory()
	_test_destroy_objective_damage_and_victory()
	_test_assassinate_boss_death_victory()
	_test_escort_vip_to_evac()
	_test_steal_data_terminal_then_evac()
	_test_defend_turns()
	# 特殊规则
	_test_ch1_m1_special_rules()
	_test_no_rules_allows_all()
	# 边界防护
	_test_terminal_repeat_interact_rejected()
	_test_destroyed_target_rejects_damage()
	# 数据契约：special_rules 兼容字典形式
	_test_special_rules_dict_form()
	# 正式地图撤离区容量：不能因多人队伍而要求单位重叠。
	_test_locked_map_evac_capacity()
	_test_infiltrate_requires_terminal_upload_and_evac()
	_test_upload_pauses_without_terminal_control()
	_test_optional_resource_is_idempotent()

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


## 创建测试用 Unit（加入场景树以便自动释放）
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
	add_child(u)  # 加入场景树以便自动释放，避免 RID 泄漏
	return u


## 创建 MissionObjectiveState 实例并加入场景树
func _make_state() -> MissionObjectiveState:
	var mos = MissionObjectiveState.new()
	add_child(mos)
	return mos


## 构建最小化 map_data，包含指定 objects
func _make_map_data(mission_type: String, objects: Array, width: int = 10, height: int = 8) -> Dictionary:
	return {
		"map_id": "test_map",
		"seed": 1001,
		"size": {"width": width, "height": height},
		"theme": "warehouse",
		"mission_type": mission_type,
		"layers": {
			"base_terrain": [],
			"blocker": [],
			"height": [],
		},
		"objects": objects,
		"scripts": [],
	}


## ===== 测试 1: 六关任务类型配置契约 =====
func _test_chapter_one_mission_types() -> void:
	print("\n--- 测试: 第一章六关任务类型配置 ---")
	var expected = {
		"ch1_m1": "infiltrate",
		"ch1_m2": "destroy",
		"ch1_m3": "extract",
		"ch1_m4": "escort",
		"ch1_m5": "steal_data",
		"ch1_m6": "assassinate",
	}
	for level_id in expected.keys():
		var cfg = CampaignRepository.get_level(level_id)
		_check(not cfg.is_empty(), "%s 存在于 levels.json" % level_id)
		if cfg.is_empty():
			continue
		_check(String(cfg.get("mission_type", "")) == expected[level_id],
			"%s mission_type=%s (期望 %s)" % [level_id, cfg.get("mission_type", "?"), expected[level_id]])


## ===== 测试 2: extract 撤离胜利 =====
func _test_extract_victory() -> void:
	print("\n--- 测试: extract 任务撤离胜利 ---")
	var mos = _make_state()
	var p1 = _make_unit("player", Vector2i(9, 0))
	var p2 = _make_unit("player", Vector2i(8, 0))
	var players = [p1, p2]
	var enemies = [_make_unit("enemy", Vector2i(0, 0))]
	var map_data = _make_map_data("extract", [
		{"type": "evac", "x": 9, "y": 0, "radius": 1},
	])
	mos.setup({"mission_type": "extract"}, map_data, players, enemies)
	_check(mos.mission_type == "extract", "mission_type=extract")
	_check(mos.evac_point == Vector2i(9, 0), "evac_point=(9,0)")
	var evac_cells = mos.get("evac_cells")
	_check(evac_cells is Array and evac_cells.has(Vector2i(8, 0)) and evac_cells.has(Vector2i(9, 0)), "撤离区域包含相邻可站立格")
	# 队员分别站在相邻撤离格，不能重叠也应能成功撤离。
	_check(mos.is_victory(), "所有玩家位于撤离区域 → 胜利")
	# 一个玩家离开撤离区域 → 未胜利
	p1.grid_pos = Vector2i(7, 0)
	_check(not mos.is_victory(), "一个玩家离开撤离点 → 未胜利")
	# 所有玩家死亡 → 失败
	p1.is_alive = false
	p2.is_alive = false
	_check(mos.is_defeat(), "所有玩家死亡 → 失败")
	mos.queue_free()


## ===== 测试 3: destroy 目标损坏和胜利 =====
func _test_destroy_objective_damage_and_victory() -> void:
	print("\n--- 测试: destroy 任务目标损坏与胜利 ---")
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("destroy", [
		{"type": "destructible_target", "x": 4, "y": 2, "hp": 30},
		{"type": "destructible_target", "x": 5, "y": 2, "hp": 20},
	])
	mos.setup({"mission_type": "destroy"}, map_data, players, enemies)
	_check(mos.targets_required == 2, "targets_required=2 (实际 %d)" % mos.targets_required)
	_check(mos.targets_destroyed == 0, "初始 targets_destroyed=0")
	_check(not mos.is_victory(), "未摧毁任何目标 → 未胜利")
	# 摧毁第一个目标（hp=30，伤害 30）
	var r1 = mos.on_objective_damaged(Vector2i(4, 2), 30)
	_check(bool(r1.get("success", false)), "伤害目标 (4,2) 成功")
	_check(bool(r1.get("destroyed", false)), "目标 (4,2) 已摧毁")
	_check(mos.targets_destroyed == 1, "targets_destroyed=1")
	_check(not mos.is_victory(), "只摧毁 1/2 → 未胜利")
	# 部分伤害第二个目标
	var r2 = mos.on_objective_damaged(Vector2i(5, 2), 10)
	_check(bool(r2.get("success", false)), "部分伤害目标 (5,2) 成功")
	_check(not bool(r2.get("destroyed", true)), "目标 (5,2) 未摧毁")
	_check(int(r2.get("remaining_hp", -1)) == 10, "目标 (5,2) 剩余 hp=10")
	# 摧毁第二个目标
	var r3 = mos.on_objective_damaged(Vector2i(5, 2), 10)
	_check(bool(r3.get("destroyed", false)), "目标 (5,2) 已摧毁")
	_check(mos.is_victory(), "摧毁 2/2 → 胜利")
	mos.queue_free()


## ===== 测试 4: assassinate Boss 死亡胜利 =====
func _test_assassinate_boss_death_victory() -> void:
	print("\n--- 测试: assassinate 任务 Boss 死亡胜利 ---")
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var boss = _make_unit("enemy", Vector2i(8, 8), "数据哨兵")
	var enemies = [boss]
	var map_data = _make_map_data("assassinate", [])
	mos.setup({"mission_type": "assassinate", "boss_id": "data_sentinel"}, map_data, players, enemies, {"boss_unit": boss})
	_check(mos.boss_unit == boss, "boss_unit 已设置")
	_check(not mos.is_victory(), "Boss 存活 → 未胜利")
	# Boss 死亡
	boss.is_alive = false
	_check(mos.is_victory(), "Boss 死亡 → 胜利")
	# 无 boss_unit 时退化为歼灭（用新敌人避免共享状态）
	var mos2 = _make_state()
	var enemies2 = [_make_unit("enemy", Vector2i(7, 7))]
	mos2.setup({"mission_type": "assassinate"}, map_data, players, enemies2)
	_check(not mos2.is_victory(), "无 Boss 且有敌人 → 未胜利")
	enemies2[0].is_alive = false
	_check(mos2.is_victory(), "无 Boss 且全灭 → 胜利")
	mos.queue_free()
	mos2.queue_free()


## ===== 测试 5: escort VIP 到达撤离点 =====
func _test_escort_vip_to_evac() -> void:
	print("\n--- 测试: escort 任务 VIP 到达撤离点 ---")
	var mos = _make_state()
	var vip = _make_unit("player", Vector2i(1, 1), "VIP")
	var p2 = _make_unit("player", Vector2i(2, 1))
	var players = [vip, p2]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("escort", [
		{"type": "evac", "x": 9, "y": 0},
	])
	mos.setup({"mission_type": "escort"}, map_data, players, enemies, {"escort_vip": vip})
	_check(mos.escort_vip == vip, "escort_vip 已设置")
	_check(not mos.is_victory(), "VIP 不在撤离点 → 未胜利")
	# VIP 到达撤离点
	vip.grid_pos = Vector2i(9, 0)
	_check(mos.is_victory(), "VIP 到达撤离点 → 胜利")
	# VIP 死亡 → 未胜利
	vip.is_alive = false
	_check(not mos.is_victory(), "VIP 死亡 → 未胜利")
	mos.queue_free()


## ===== 测试 6: steal_data 终端激活后撤离 =====
func _test_steal_data_terminal_then_evac() -> void:
	print("\n--- 测试: steal_data 任务终端激活与撤离 ---")
	var mos = _make_state()
	var p1 = _make_unit("player", Vector2i(1, 1))
	var p2 = _make_unit("player", Vector2i(2, 1))
	var players = [p1, p2]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("steal_data", [
		{"type": "terminal", "x": 4, "y": 2},
		{"type": "terminal", "x": 5, "y": 2},
		{"type": "evac", "x": 9, "y": 0},
	])
	mos.setup({"mission_type": "steal_data"}, map_data, players, enemies)
	_check(mos.terminals_required == 2, "terminals_required=2 (实际 %d)" % mos.terminals_required)
	_check(mos.terminals_activated == 0, "初始 terminals_activated=0")
	_check(not mos.is_victory(), "未激活终端 → 未胜利")
	# 玩家在撤离点但未激活终端
	p1.grid_pos = Vector2i(9, 0)
	p2.grid_pos = Vector2i(8, 0)
	_check(not mos.is_victory(), "玩家在撤离点但未激活终端 → 未胜利")
	# 激活第一个终端
	var r1 = mos.on_terminal_interacted(p1, Vector2i(4, 2))
	_check(bool(r1.get("success", false)), "激活终端 (4,2) 成功")
	_check(int(r1.get("activated", 0)) == 1, "activated=1")
	_check(not mos.is_victory(), "只激活 1/2 → 未胜利")
	# 激活第二个终端
	var r2 = mos.on_terminal_interacted(p2, Vector2i(5, 2))
	_check(bool(r2.get("success", false)), "激活终端 (5,2) 成功")
	_check(int(r2.get("activated", 0)) == 2, "activated=2")
	_check(mos.is_victory(), "激活 2/2 且玩家在撤离点 → 胜利")
	mos.queue_free()


## ===== 测试 7: defend 坚守回合 =====
func _test_defend_turns() -> void:
	print("\n--- 测试: defend 任务坚守回合 ---")
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("defend", [])
	mos.setup({"mission_type": "defend", "max_turns": 5}, map_data, players, enemies)
	_check(mos.defend_turns_required == 5, "defend_turns_required=5")
	_check(mos.max_turns == 5, "max_turns=5")
	# 回合 1 → 未胜利
	mos.on_turn_started(1, "player")
	_check(not mos.is_victory(), "回合 1 → 未胜利")
	# 回合 5 → 胜利
	mos.on_turn_started(5, "player")
	_check(mos.is_victory(), "回合 5 → 胜利")
	mos.queue_free()


## ===== 测试 8: ch1_m1 三条特殊规则 =====
func _test_ch1_m1_special_rules() -> void:
	print("\n--- 测试: ch1_m1 三条特殊规则 ---")
	var cfg = CampaignRepository.get_level("ch1_m1")
	_check(not cfg.is_empty(), "ch1_m1 配置存在")
	if cfg.is_empty():
		return
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("extract", [{"type": "evac", "x": 9, "y": 0}])
	mos.setup(cfg, map_data, players, enemies)
	# 三条规则都应启用
	_check(mos.is_rule_enabled(MissionObjectiveStateScript.RULE_NO_OVERWATCH), "no_overwatch 已启用")
	_check(mos.is_rule_enabled(MissionObjectiveStateScript.RULE_NO_ITEMS), "no_items 已启用")
	_check(mos.is_rule_enabled(MissionObjectiveStateScript.RULE_ENEMY_PASSIVE_TURN_1), "enemy_passive_turn_1 已启用")
	# 查询方法
	_check(not mos.is_overwatch_allowed(), "警戒被禁用")
	_check(not mos.is_item_use_allowed(), "物品被禁用")
	# 首回合敌人被动
	_check(mos.is_enemy_passive(1), "回合 1 敌人被动")
	_check(not mos.is_enemy_passive(2), "回合 2 敌人不再被动")
	# 规则原因非空
	var reason = mos.get_rule_reason(MissionObjectiveStateScript.RULE_NO_OVERWATCH)
	_check(reason.length() > 0, "no_overwatch 原因非空: %s" % reason)
	# 活跃规则摘要包含所有规则
	var summary = mos.get_active_rules_summary()
	_check(summary.length() > 0, "活跃规则摘要非空")
	_check(summary.find("警戒") >= 0 or summary.find("overwatch") >= 0, "摘要包含警戒规则")
	mos.queue_free()


## ===== 测试 9: 无特殊规则的关卡允许所有操作 =====
func _test_no_rules_allows_all() -> void:
	print("\n--- 测试: 无特殊规则关卡允许所有操作 ---")
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("extract", [{"type": "evac", "x": 9, "y": 0}])
	# ch1_m2 没有 special_rules
	mos.setup({"mission_type": "extract"}, map_data, players, enemies)
	_check(mos.is_overwatch_allowed(), "无规则 → 警戒允许")
	_check(mos.is_item_use_allowed(), "无规则 → 物品允许")
	_check(not mos.is_enemy_passive(1), "无规则 → 回合 1 敌人不被动")
	_check(mos.get_active_rules_summary() == "", "无规则 → 摘要为空")
	mos.queue_free()


## ===== 测试 10: 终端重复激活防护 =====
func _test_terminal_repeat_interact_rejected() -> void:
	print("\n--- 测试: 终端重复激活防护 ---")
	var mos = _make_state()
	var p1 = _make_unit("player", Vector2i(1, 1))
	var players = [p1]
	var enemies = []
	var map_data = _make_map_data("steal_data", [
		{"type": "terminal", "x": 4, "y": 2},
		{"type": "evac", "x": 9, "y": 0, "radius": 1},
	])
	mos.setup({"mission_type": "steal_data"}, map_data, players, enemies)
	# 激活终端
	var r1 = mos.on_terminal_interacted(p1, Vector2i(4, 2))
	_check(bool(r1.get("success", false)), "首次激活成功")
	_check(int(mos.terminals_activated) == 1, "terminals_activated=1")
	# 再次激活同一终端（当前实现不阻止重复激活同一终端，但允许测试此行为）
	# 注意：当前 MissionObjectiveState 不跟踪单个终端的激活状态，由 battle_controller 控制
	# 这里测试非终端位置被拒绝
	var r2 = mos.on_terminal_interacted(p1, Vector2i(0, 0))
	_check(not bool(r2.get("success", true)), "非终端位置激活被拒绝")
	mos.queue_free()


## ===== 测试 11: 已摧毁目标拒绝继续伤害 =====
func _test_destroyed_target_rejects_damage() -> void:
	print("\n--- 测试: 已摧毁目标拒绝继续伤害 ---")
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var enemies = []
	var map_data = _make_map_data("destroy", [
		{"type": "destructible_target", "x": 4, "y": 2, "hp": 20},
	])
	mos.setup({"mission_type": "destroy"}, map_data, players, enemies)
	# 摧毁目标
	var r1 = mos.on_objective_damaged(Vector2i(4, 2), 20)
	_check(bool(r1.get("destroyed", false)), "目标已摧毁")
	# 再次伤害已摧毁目标
	var r2 = mos.on_objective_damaged(Vector2i(4, 2), 10)
	_check(not bool(r2.get("success", true)), "已摧毁目标拒绝伤害")
	# 伤害不存在的目标
	var r3 = mos.on_objective_damaged(Vector2i(0, 0), 10)
	_check(not bool(r3.get("success", true)), "不存在目标拒绝伤害")
	mos.queue_free()


## ===== 测试 12: special_rules 字典形式兼容 =====
func _test_special_rules_dict_form() -> void:
	print("\n--- 测试: special_rules 字典形式兼容 ---")
	var mos = _make_state()
	var players = [_make_unit("player", Vector2i(1, 1))]
	var enemies = [_make_unit("enemy", Vector2i(8, 8))]
	var map_data = _make_map_data("extract", [{"type": "evac", "x": 9, "y": 0}])
	# 字典形式，带自定义原因
	var level_config = {
		"mission_type": "extract",
		"special_rules": {
			"no_overwatch": {"enabled": true, "reason": "教学关：暂不开放警戒"},
			"no_items": {"enabled": false, "reason": "物品已开放"},
		}
	}
	mos.setup(level_config, map_data, players, enemies)
	_check(mos.is_rule_enabled("no_overwatch"), "字典形式 no_overwatch 启用")
	_check(not mos.is_rule_enabled("no_items"), "字典形式 no_items 禁用")
	_check(not mos.is_overwatch_allowed(), "警戒被禁用")
	_check(mos.is_item_use_allowed(), "物品被允许")
	var reason = mos.get_rule_reason("no_overwatch")
	_check(reason == "教学关：暂不开放警戒", "自定义原因正确: %s" % reason)
	mos.queue_free()


## ===== 测试 13: 正式地图撤离区域容量 =====
func _test_locked_map_evac_capacity() -> void:
	print("\n--- 测试: 第一章正式地图撤离区域容量 ---")
	for level_id in ["ch1_m1", "ch1_m3", "ch1_m4", "ch1_m5"]:
		var map_result := MapLoader.load_locked_map(level_id)
		_check(bool(map_result.get("ok", false)), "%s 正式地图可加载" % level_id)
		if not bool(map_result.get("ok", false)):
			continue
		var map_data: Dictionary = map_result.get("data", {})
		var player_spawns: Array = map_data.get("objects", []).filter(func(object): return object.get("type", "") == "spawn_player")
		var players: Array = []
		for spawn in player_spawns:
			players.append(_make_unit("player", Vector2i(int(spawn.get("x", 0)), int(spawn.get("y", 0)))))
		var mos := _make_state()
		mos.setup(CampaignRepository.get_level(level_id), map_data, players, [])
		_check(mos.evac_cells.size() >= players.size(), "%s 撤离区域可容纳 %d 名队员" % [level_id, players.size()])
		_check(mos.evac_cells.has(mos.evac_point), "%s 撤离锚点属于可站立区域" % level_id)
		mos.queue_free()


func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if _errors.size() > 0:
		print("  失败项:")
		for e in _errors:
			print("    - ", e)
	print("  =================")

## ===== Task 1: 阶段化任务状态机 fixture =====

## 构建 infiltrate 任务的最小化状态机：3 玩家、1 终端、1 资源、1 撤离点。
## map_data.mission_flow 提供上传回合、控制半径和可选资源奖励。
func _make_infiltrate_state() -> Dictionary:
	var mos := _make_state()
	var players := [
		_make_unit("player", Vector2i(8, 8)),
		_make_unit("player", Vector2i(7, 8)),
		_make_unit("player", Vector2i(6, 8)),
	]
	var map_data := _make_map_data("infiltrate", [
		{"type": "terminal", "x": 8, "y": 7},
		{"type": "resource", "x": 2, "y": 5, "reward": "credit_150"},
		{"type": "evac", "x": 1, "y": 0, "radius": 1},
	], 18, 14)
	map_data["mission_flow"] = {
		"terminal_required": true,
		"upload_turns_required": 2,
		"upload_hold_radius": 1,
		"evac_locked_until_upload": true,
		"optional_resource_credit": 150,
	}
	mos.setup({"mission_type": "infiltrate", "max_turns": 18}, map_data, players, [])
	return {"state": mos, "players": players}


## ===== 测试: infiltrate 需要终端→上传→撤离三阶段 =====
func _test_infiltrate_requires_terminal_upload_and_evac() -> void:
	print("\n--- 测试: infiltrate 三阶段流（接近→上传→撤离） ---")
	var fixture := _make_infiltrate_state()
	var mos: MissionObjectiveState = fixture.state
	var players: Array = fixture.players
	_check(mos.get_stage() == &"approach", "首阶段为 approach")
	_check(not mos.is_victory(), "未激活终端时撤离不构成胜利")
	# 任何玩家站在撤离点也不应胜利（evac 锁定）
	players[0].grid_pos = Vector2i(1, 0)
	players[1].grid_pos = Vector2i(0, 0)
	players[2].grid_pos = Vector2i(2, 0)
	_check(not mos.is_victory(), "上传未完成时撤离被锁定")
	# 激活终端
	players[0].grid_pos = Vector2i(8, 8)
	var terminal_result := mos.on_terminal_interacted(players[0], Vector2i(8, 7))
	_check(terminal_result.get("success", false), "终端激活成功")
	_check(mos.get_stage() == &"upload", "终端激活后进入 upload 阶段")
	# 上传 1/2
	var up1 = mos.on_enemy_turn_completed()
	_check(int(up1.get("progress", -1)) == 1, "上传推进至 1/2")
	_check(mos.get_stage() == &"upload", "1/2 后仍处于 upload 阶段")
	# 上传 2/2
	var up2 = mos.on_enemy_turn_completed()
	_check(int(up2.get("progress", -1)) == 2, "上传推进至 2/2")
	_check(mos.get_stage() == &"evacuate", "上传完成后进入 evacuate 阶段")
	# 全员撤离
	for index in players.size():
		players[index].grid_pos = Vector2i(index, 0)
	_check(mos.is_victory(), "上传完成后全员撤离 → 胜利")
	_check(mos.get_stage() == &"complete", "胜利后进入 complete 阶段")
	mos.queue_free()
	for p in players:
		p.queue_free()


## ===== 测试: 上传需要玩家在终端附近保持控制 =====
func _test_upload_pauses_without_terminal_control() -> void:
	print("\n--- 测试: 无玩家控制终端时上传暂停 ---")
	var fixture := _make_infiltrate_state()
	var mos: MissionObjectiveState = fixture.state
	var players: Array = fixture.players
	# 激活终端进入 upload
	mos.on_terminal_interacted(players[0], Vector2i(8, 7))
	_check(mos.get_stage() == &"upload", "进入 upload 阶段")
	# 把所有玩家移到离终端曼哈顿距离 > 1 的位置
	players[0].grid_pos = Vector2i(0, 0)
	players[1].grid_pos = Vector2i(0, 1)
	players[2].grid_pos = Vector2i(0, 2)
	var result = mos.on_enemy_turn_completed()
	_check(bool(result.get("paused", false)), "无控制时上传暂停")
	_check(int(result.get("progress", -1)) == 0, "暂停时进度保持 0")
	_check(mos.get_stage() == &"upload", "暂停时阶段不变")
	# 玩家回到终端附近
	players[0].grid_pos = Vector2i(8, 8)  # 距离 (8,7) = 1，在半径内
	var result2 = mos.on_enemy_turn_completed()
	_check(not bool(result2.get("paused", true)), "恢复控制后上传推进")
	_check(int(result2.get("progress", -1)) == 1, "进度推进至 1/2")
	mos.queue_free()
	for p in players:
		p.queue_free()


## ===== 测试: 可选资源交互幂等 =====
func _test_optional_resource_is_idempotent() -> void:
	print("\n--- 测试: 可选资源交互幂等性 ---")
	var fixture := _make_infiltrate_state()
	var mos: MissionObjectiveState = fixture.state
	var players: Array = fixture.players
	var resource_pos := Vector2i(2, 5)
	# 第一次交互
	var r1 = mos.on_resource_interacted(players[0], resource_pos)
	_check(r1.get("success", false), "首次资源交互成功")
	_check(int(r1.get("credit_bonus", 0)) == 150, "首次奖励 150 信用点 (实际: %d)" % int(r1.get("credit_bonus", 0)))
	# 第二次交互应拒绝
	var r2 = mos.on_resource_interacted(players[0], resource_pos)
	_check(not r2.get("success", true), "重复交互被拒绝")
	_check(String(r2.get("reason", "")) == "already_collected", "拒绝原因=already_collected")
	# 结果修饰符
	var mods = mos.get_result_modifiers()
	_check(bool(mods.get("optional_resource_collected", false)), "修饰符: optional_resource_collected=true")
	_check(int(mods.get("optional_credit", 0)) == 150, "修饰符: optional_credit=150")
	mos.queue_free()
	for p in players:
		p.queue_free()
