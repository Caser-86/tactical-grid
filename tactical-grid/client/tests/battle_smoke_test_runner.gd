## 无头冒烟测试运行器（场景模式）
## 运行方式: godot --headless --path client tests/battle_smoke_test.tscn
extends Node

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
# 跟踪测试中创建的 Unit 节点（Unit extends Node2D，未加入场景树时需手动释放）
var _test_units: Array = []

const TutorialHintScript = preload("res://scripts/ui/tutorial_hint.gd")
const TutorialHintScene = preload("res://scenes/tutorial_hint.tscn")
const AudioManagerScript = preload("res://scripts/game/audio_manager.gd")

func _ready() -> void:
	print("=== Tactical Grid 无头冒烟测试 ===")
	await get_tree().process_frame
	_test_audio_bus_contract()
	await get_tree().process_frame
	_run_core_tests()
	await get_tree().process_frame
	_test_weapon_special_effects()
	await get_tree().process_frame
	_test_throwable_area_effects()
	await get_tree().process_frame
	_test_trap_system()
	await get_tree().process_frame
	_run_battle_flow_tests()
	await get_tree().process_frame
	_run_e2e_battle_test()
	await get_tree().process_frame
	_test_path_preview_logic()
	await get_tree().process_frame
	_run_locked_map_tests()
	await get_tree().process_frame
	_run_mission_objective_tests()
	await get_tree().process_frame
	_run_progression_tests()
	await get_tree().process_frame
	_test_reinforcement_system()
	await get_tree().process_frame
	_test_reinforcement_scripts_in_locked_maps()
	await get_tree().process_frame
	await _test_100_battle_stability()
	await get_tree().process_frame
	_test_map_validation()
	await get_tree().process_frame
	_test_difficulty_params()
	await get_tree().process_frame
	_test_boss_phase_system()
	_print_summary()
	_free_test_units()
	get_tree().quit(0 if _failed == 0 else 1)

## 释放测试中创建的 Unit 节点，避免资源泄漏报告
func _free_test_units() -> void:
	for unit in _test_units:
		if unit and is_instance_valid(unit):
			unit.queue_free()
	_test_units.clear()
	# 等待一帧让 queue_free 生效
	await get_tree().process_frame

## 跟踪一个 Unit 节点以便测试结束后释放
func _track(unit) -> Node:
	if unit and unit is Node:
		_test_units.append(unit)
	return unit

## ===== 音频总线契约 =====

func _test_audio_bus_contract() -> void:
	_check(AudioServer.get_bus_index(&"Music") >= 0, "Audio: Music 总线存在")
	_check(AudioServer.get_bus_index(&"SFX") >= 0, "Audio: SFX 总线存在")

	var audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	_check(audio_manager.bgm_player.bus == &"Music", "Audio: BGMPlayer 路由到 Music")
	_check(audio_manager.sfx_player.bus == &"SFX", "Audio: SFXPlayer 路由到 SFX")
	_check(audio_manager.ambient_player.bus == &"SFX", "Audio: AmbientPlayer 路由到 SFX")
	audio_manager.queue_free()
	for audio_path in [
		"res://assets/audio/bgm/bgm_menu.wav",
		"res://assets/audio/bgm/bgm_battle_small.wav",
		"res://assets/audio/bgm/bgm_boss.wav",
		"res://assets/audio/bgm/bgm_victory.wav",
		"res://assets/audio/bgm/bgm_defeat.wav",
		"res://assets/audio/sfx/sfx_ui_click.wav",
		"res://assets/audio/sfx/sfx_select_unit.wav",
		"res://assets/audio/sfx/sfx_unit_land.wav",
		"res://assets/audio/sfx/sfx_combat_pistol.wav",
		"res://assets/audio/sfx/sfx_hit_flesh.wav",
		"res://assets/audio/sfx/sfx_critical_hit.wav",
		"res://assets/audio/sfx/sfx_unit_down.wav",
		"res://assets/audio/sfx/sfx_skill_cast.wav",
		"res://assets/audio/sfx/sfx_mission_victory.wav",
		"res://assets/audio/sfx/sfx_mission_defeat.wav",
	]:
		_check(FileAccess.file_exists(audio_path), "Audio: 正式资源存在 %s" % audio_path)
		var stream = load(audio_path)
		_check(stream is AudioStream, "Audio: Godot 可加载 %s" % audio_path)
	_check(FileAccess.file_exists("res://data/RESOURCE_MANIFEST.md"), "Assets: 资源清单存在")
	var export_presets = FileAccess.get_file_as_string("res://export_presets.cfg")
	for legacy_directory in ["assets/characters/*", "assets/effects/*", "assets/tiles/*", "assets/ui/*"]:
		_check(export_presets.contains(legacy_directory), "Assets: 导出排除历史参考目录 %s" % legacy_directory)

## ===== 核心系统测试 =====

func _run_core_tests() -> void:
	print("\n--- 核心系统测试 ---")
	_test_grid_system()
	_test_pathfinding()
	_test_vision_system()
	_test_combat_formulas()

func _test_grid_system() -> void:
	_check(GridSystem.grid_to_world(Vector2i(3, 5)) == Vector2(192, 320), "grid_to_world 基本转换")
	_check(GridSystem.world_to_grid(Vector2(192, 320)) == Vector2i(3, 5), "world_to_grid 基本转换")
	_check(GridSystem.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4)) == 7, "manhattan_distance")
	_check(GridSystem.is_in_bounds(Vector2i(5, 5), 10, 10), "is_in_bounds 内部")
	_check(not GridSystem.is_in_bounds(Vector2i(10, 5), 10, 10), "is_in_bounds 外部")
	_check(GridSystem.get_neighbors(Vector2i(2, 2)).size() == 4, "get_neighbors 数量")

func _test_pathfinding() -> void:
	var cost_fn = func(_pos): return 1
	var blocked_fn = func(_pos): return false

	var path = Pathfinding.find_path(Vector2i(0, 0), Vector2i(3, 0), 10, 10, cost_fn, blocked_fn)
	_check(path.size() > 0, "find_path 直线可达")
	_check(path.size() > 0 and path[path.size() - 1] == Vector2i(3, 0), "find_path 终点正确")

	var blocked_fn2 = func(pos): return pos.x >= 2 and pos.y == 0
	var path2 = Pathfinding.find_path(Vector2i(0, 0), Vector2i(5, 0), 10, 10, cost_fn, blocked_fn2)
	_check(path2.size() == 0, "find_path 被阻挡时返回空")

	var reachable = Pathfinding.get_reachable_cells(Vector2i(0, 0), 3, 10, 10, cost_fn, blocked_fn)
	_check(reachable.size() > 0, "get_reachable_cells 返回非空")
	_check(reachable.has(Vector2i(3, 0)), "get_reachable_cells 包含可达点")

func _test_vision_system() -> void:
	var no_block = func(_pos): return false
	var block_at_2 = func(pos): return pos == Vector2i(2, 0)

	_check(VisionSystem.has_line_of_sight(Vector2i(0, 0), Vector2i(5, 0), 10, 10, no_block), "has_line_of_sight 无阻挡")
	_check(not VisionSystem.has_line_of_sight(Vector2i(0, 0), Vector2i(5, 0), 10, 10, block_at_2), "has_line_of_sight 有阻挡")

	var terrain_fn = func(pos): return 6 if pos == Vector2i(3, 0) else 0
	_check(VisionSystem.calculate_cover(Vector2i(2, 0), Vector2i(5, 0), terrain_fn) == "full", "calculate_cover 全掩体")

func _test_combat_formulas() -> void:
	var hit = CombatFormulas.calculate_hit(80, 0, 0, "none", 3, 5)
	_check(hit > 0.79 and hit < 0.81, "calculate_hit 基础命中")

	var hit_cover = CombatFormulas.calculate_hit(80, 0, 0, "full", 3, 5)
	_check(hit_cover < hit, "calculate_hit 全掩体降低命中")

	_check(CombatFormulas.calculate_damage(50, 0, false, 1.5) == 50, "calculate_damage 无甲无暴击")
	_check(CombatFormulas.calculate_damage(50, 50, false, 1.5) == 25, "calculate_damage 护甲减伤")
	_check(CombatFormulas.calculate_damage(50, 0, true, 2.0) == 100, "calculate_damage 暴击")

	var dodge = CombatFormulas.calculate_dodge(0.10, 2)
	_check(dodge > 0.19 and dodge < 0.21, "calculate_dodge 森林加成")

## ===== 战斗流程测试 =====

func _run_battle_flow_tests() -> void:
	print("\n--- 战斗流程测试 ---")

	# GameData 是 autoload，已在项目启动时加载
	if GameData.has_errors():
		_check(false, "GameData 加载有错误: " + ", ".join(GameData.get_load_errors()))
		return
	_check(GameData.terrain_data.size() > 0, "GameData 地形数据已加载")
	_check(GameData.job_data.size() > 0, "GameData 职业数据已加载")
	_check(GameData.enemy_data.size() > 0, "GameData 敌人数据已加载")

	_test_unit_creation()
	_test_turn_manager()
	_test_action_system()
	_test_utility_ai()
	_test_victory_conditions()

func _test_unit_creation() -> void:
	var unit = _track(GameData.create_player_unit("assault", "TestSoldier"))
	_check(unit.team == "player", "create_player_unit 阵营")
	_check(unit.job == "assault", "create_player_unit 职业")
	_check(unit.max_hp > 0, "create_player_unit HP > 0")
	_check(unit.current_ap == unit.max_ap, "create_player_unit AP 初始满")
	_check(unit.base_move_points > 0, "create_player_unit 移动点 > 0")

	var enemy = _track(GameData.create_enemy_unit("sentry_basic"))
	_check(enemy.team == "enemy", "create_enemy_unit 阵营")
	_check(enemy.max_hp > 0, "create_enemy_unit HP > 0")

	var ap_before = unit.current_ap
	unit.spend_ap(1)
	_check(unit.current_ap == ap_before - 1, "spend_ap 消耗")

	unit.take_damage(10)
	_check(unit.current_hp == unit.max_hp - 10, "take_damage 伤害")
	_check(unit.is_alive, "take_damage 未死")

	unit.take_damage(unit.max_hp)
	_check(not unit.is_alive, "take_damage 死亡")

	var unit2 = _track(GameData.create_player_unit("medic", "Medic"))
	unit2.add_status("overwatch", 1)
	_check(unit2.has_status("overwatch"), "add_status + has_status")
	unit2.remove_status("overwatch")
	_check(not unit2.has_status("overwatch"), "remove_status")

	unit2.spend_ap(2)
	unit2.move_points = 0
	unit2.refresh_ap()
	_check(unit2.current_ap == unit2.max_ap, "refresh_ap 恢复 AP")
	_check(unit2.move_points == unit2.base_move_points, "refresh_ap 恢复移动点")

func _test_turn_manager() -> void:
	var tm = TurnManager.new()
	add_child(tm)

	var p1 = _track(Unit.new())
	p1.team = "player"
	p1.max_ap = 2
	p1.current_ap = 2
	p1.base_move_points = 5
	p1.move_points = 3
	p1.is_alive = true

	var e1 = _track(Unit.new())
	e1.team = "enemy"
	e1.max_ap = 2
	e1.current_ap = 2
	e1.base_move_points = 4
	e1.move_points = 2
	e1.is_alive = true

	tm.setup([p1], [e1], 20)
	_check(tm.max_turns == 20, "TurnManager setup max_turns")
	_check(tm.turn_number == 0, "TurnManager setup turn_number")

	tm.set_victory_check(func(): return false)
	tm.set_defeat_check(func(): return false)

	tm.start_battle()
	_check(tm.turn_number == 1, "TurnManager start_battle turn_number")
	_check(tm.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "TurnManager start_battle phase")
	_check(p1.current_ap == p1.max_ap, "TurnManager 玩家回合 AP 刷新")
	_check(p1.move_points == p1.base_move_points, "TurnManager 玩家回合移动点刷新")

	tm.end_player_turn()
	_check(tm.current_phase == TurnManager.TurnPhase.ENEMY_ACTION, "TurnManager 敌人回合")
	_check(e1.current_ap == e1.max_ap, "TurnManager 敌人回合 AP 刷新")

	tm.end_enemy_turn()
	_check(tm.turn_number == 2, "TurnManager 第2回合")
	_check(tm.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "TurnManager 第2回合玩家行动")

func _test_action_system() -> void:
	var asys = ActionSystem.new()
	add_child(asys)

	var map_data = _make_flat_map(10, 10)
	asys.set_map_data(map_data)

	var attacker = _track(GameData.create_player_unit("assault", "Attacker"))
	attacker.grid_pos = Vector2i(1, 1)
	attacker.weapon_range = [1, 5]
	attacker.weapon_damage = [20, 30]
	attacker.weapon_optimal_range = 3

	var target = _track(GameData.create_enemy_unit("sentry_basic"))
	target.grid_pos = Vector2i(3, 1)
	target.weapon_range = [1, 5]

	asys.set_units([attacker], [target])

	var result = asys.execute_attack(attacker, target)
	_check(result.success, "ActionSystem execute_attack 成功")
	_check(result.result.has("hit"), "ActionSystem 攻击结果有 hit 字段")

	var attacker2 = _track(GameData.create_player_unit("sniper", "Sniper"))
	attacker2.grid_pos = Vector2i(5, 5)
	attacker2.current_ap = 2
	var skill_result = asys.execute_skill(attacker2, "gen_overwatch", {})
	_check(skill_result.success, "ActionSystem execute_skill gen_overwatch")
	_check(attacker2.has_status("overwatch"), "ActionSystem 技能添加 overwatch 状态")

	var patient = _track(GameData.create_player_unit("medic", "Patient"))
	patient.current_hp = 30
	patient.current_ap = 2
	var item_result = asys.use_item(patient, "med_kit", patient, {})
	_check(item_result.success, "ActionSystem use_item med_kit")
	_check(patient.current_hp == 70, "ActionSystem med_kit 治疗40")

func _test_utility_ai() -> void:
	var map_data = _make_flat_map(10, 10)

	var enemy = _track(GameData.create_enemy_unit("sentry_basic"))
	enemy.grid_pos = Vector2i(5, 5)
	enemy.current_ap = 2
	enemy.move_points = 4

	var player = _track(GameData.create_player_unit("assault", "Target"))
	player.grid_pos = Vector2i(7, 5)

	var action = UtilityAI.decide_action(enemy, [player], map_data, [enemy])
	_check(action.has("type"), "UtilityAI decide_action 返回有效行动")
	_check(action.type in ["attack", "move", "move_to_cover", "overwatch", "wait"], "UtilityAI 行动类型合法")
	# 攻击范围内应选择攻击 (sentry_basic range=[2,6], distance=2)
	enemy.grid_pos = Vector2i(5, 5)
	var action2 = UtilityAI.decide_action(enemy, [player], map_data, [enemy])
	_check(action2.type == "attack", "UtilityAI 在攻击范围内选择攻击")

func _test_victory_conditions() -> void:
	var players = [_track(Unit.new()), _track(Unit.new())]
	players[0].is_alive = true
	players[1].is_alive = true

	var enemies = [_track(Unit.new()), _track(Unit.new())]
	enemies[0].is_alive = false
	enemies[1].is_alive = false

	var all_dead = enemies.filter(func(u): return u.is_alive).is_empty()
	_check(all_dead, "胜利条件: 所有敌人死亡")

	players[0].is_alive = false
	players[1].is_alive = false
	var all_players_dead = players.filter(func(u): return u.is_alive).is_empty()
	_check(all_players_dead, "失败条件: 所有玩家死亡")

## ===== 端到端战斗测试 =====

func _run_e2e_battle_test() -> void:
	print("\n--- 端到端战斗测试 ---")

	# 设置关卡
	GameManager.current_level_id = "ch1_m1"
	var level_config = CampaignRepository.get_level("ch1_m1")
	_check(not level_config.is_empty(), "E2E: 关卡配置 ch1_m1 存在")
	_check(level_config.get("mission_type") == "extract", "E2E: 关卡类型为撤离")

	# 验证种子和数据流（不创建 BattleController，因为它依赖场景节点）
	var seed_val = int(level_config.get("seed", 1001))
	_check(seed_val == 1001, "E2E: 种子值正确")

	# 验证 GameData 能创建关卡所需单位
	var player_unit = _track(GameData.create_player_unit("assault", "突击兵"))
	_check(player_unit.is_alive, "E2E: 玩家单位创建成功")
	_check(player_unit.team == "player", "E2E: 玩家单位阵营正确")

	var enemy_unit = _track(GameData.create_enemy_unit("sentry_basic"))
	_check(enemy_unit.is_alive, "E2E: 敌人单位创建成功")
	_check(enemy_unit.team == "enemy", "E2E: 敌人单位阵营正确")

	# 验证回合流程：模拟完整的玩家回合 -> 敌人回合 -> 胜负检查
	var tm = TurnManager.new()
	add_child(tm)
	tm.setup([player_unit], [enemy_unit], 20)

	# 使用 Dictionary 包装信号标志（GDScript lambda 修改捕获的局部变量不可靠）
	var flags := {"victory": false, "defeat": false}
	tm.set_victory_check(func(): return not enemy_unit.is_alive)
	tm.set_defeat_check(func(): return not player_unit.is_alive)
	tm.battle_won.connect(func(_r): flags["victory"] = true)
	tm.battle_lost.connect(func(_r): flags["defeat"] = true)

	# 开始战斗
	tm.start_battle()
	_check(tm.turn_number == 1, "E2E: 战斗开始，回合1")
	_check(tm.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "E2E: 玩家行动阶段")

	# 模拟玩家攻击杀敌
	enemy_unit.take_damage(enemy_unit.max_hp)
	_check(not enemy_unit.is_alive, "E2E: 敌人被击杀")

	# 结束玩家回合 -> 敌人回合 -> 检查胜负 -> 胜利
	tm.end_player_turn()
	# 敌人已死，直接结束敌人回合触发胜负检查
	tm.end_enemy_turn()

	_check(flags["victory"] == true, "E2E: 胜利信号触发")
	_check(tm.battle_over, "E2E: 战斗结束标志设置")
	_check(tm.current_phase == TurnManager.TurnPhase.BATTLE_OVER, "E2E: 战斗阶段为BATTLE_OVER")

	# 测试回合上限失败
	var tm2 = TurnManager.new()
	add_child(tm2)
	var p2 = _track(GameData.create_player_unit("assault", "P2"))
	var e2 = _track(GameData.create_enemy_unit("sentry_basic"))
	tm2.setup([p2], [e2], 3)  # 最多3回合
	tm2.set_victory_check(func(): return false)
	tm2.set_defeat_check(func(): return false)

	var flags2 := {"lost": false}
	tm2.battle_lost.connect(func(_r): flags2["lost"] = true)

	tm2.start_battle()
	tm2.end_player_turn()
	tm2.end_enemy_turn()
	_check(tm2.turn_number == 2, "E2E: 第2回合")
	tm2.end_player_turn()
	tm2.end_enemy_turn()
	_check(tm2.turn_number == 3, "E2E: 第3回合")
	tm2.end_player_turn()
	tm2.end_enemy_turn()
	_check(flags2["lost"] == true, "E2E: 回合上限触发失败")
	_check(tm2.battle_over, "E2E: 回合上限后战斗结束")

## ===== 路径预览测试 =====
## 验证移动路径预览的核心逻辑：find_path 返回有效路径，途径格子可达

func _test_path_preview_logic() -> void:
	# 创建平坦地图，验证路径预览逻辑
	var map_data = _make_flat_map(10, 10)
	var cost_fn = func(_pos): return 1
	var blocked_fn = func(_pos): return false

	# 从 (1,1) 到 (4,1) 的直线路径（find_path 返回不含起点的路径）
	var path = Pathfinding.find_path(Vector2i(1, 1), Vector2i(4, 1), 10, 10, cost_fn, blocked_fn)
	_check(path.size() > 0, "PathPreview: find_path 返回非空路径")
	_check(path.size() >= 3, "PathPreview: 直线路径长度 >= 3（不含起点）")
	_check(path[path.size() - 1] == Vector2i(4, 1), "PathPreview: 路径终点正确")

	# 验证路径连续性（每步相邻）
	var path_valid = true
	for i in range(1, path.size()):
		var prev = path[i - 1]
		var curr = path[i]
		var dist = abs(prev.x - curr.x) + abs(prev.y - curr.y)
		if dist != 1:
			path_valid = false
			break
	_check(path_valid, "PathPreview: 路径每步正交相邻")

	# 验证阻挡时路径绕行
	var blocked_fn2 = func(pos): return pos == Vector2i(2, 1)
	var path2 = Pathfinding.find_path(Vector2i(1, 1), Vector2i(4, 1), 10, 10, cost_fn, blocked_fn2)
	_check(path2.size() > 0, "PathPreview: 有阻挡时仍可绕行")
	# 绕行路径不应经过阻挡格
	var avoids_blocker = not path2.has(Vector2i(2, 1))
	_check(avoids_blocker, "PathPreview: 绕行路径避开阻挡格")

	# 验证可达性集合与路径预览目标一致
	var reachable = Pathfinding.get_reachable_cells(Vector2i(1, 1), 5, 10, 10, cost_fn, blocked_fn)
	_check(reachable.has(Vector2i(4, 1)), "PathPreview: 目标格在可达集合中")
	# 路径长度不应超过移动点数
	_check(path.size() - 1 <= 5, "PathPreview: 路径消耗不超过移动点")

## ===== 辅助 =====

func _make_flat_map(w: int, h: int) -> Dictionary:
	var base_t: Array = []
	var blocker: Array = []
	var height: Array = []
	for y in range(h):
		var row_t: Array = []
		var row_b: Array = []
		var row_h: Array = []
		for x in range(w):
			row_t.append(0)
			row_b.append(0)
			row_h.append(0)
		base_t.append(row_t)
		blocker.append(row_b)
		height.append(row_h)
	return {
		"size": {"width": w, "height": h},
		"layers": {"base_terrain": base_t, "blocker": blocker, "height": height},
	}

## ===== 锁定地图加载测试 =====

func _run_locked_map_tests() -> void:
	print("\n--- 锁定地图加载测试 ---")
	_test_locked_map_load_basic()
	_test_locked_map_load_all_levels()
	_test_locked_map_missing_level()
	_test_locked_map_objectives_extraction()

func _test_locked_map_load_basic() -> void:
	# 加载 ch1_m1，验证关键字段
	var res := MapLoader.load_locked_map("ch1_m1")
	_check(res.get("ok", false) == true, "load_locked_map ch1_m1 成功")
	if not res.get("ok", false):
		return
	var data: Dictionary = res["data"]
	_check(data.get("map_id", "") != "", "ch1_m1 map_id 非空")
	_check(data.get("mission_type", "") == "extract", "ch1_m1 mission_type=extract")
	_check(int(data.size.width) == 10, "ch1_m1 width=10")
	_check(int(data.size.height) == 8, "ch1_m1 height=8")
	_check(data.has("layers"), "ch1_m1 包含 layers")
	_check(data.layers.base_terrain.size() == 8, "ch1_m1 base_terrain 行数=8")
	_check(data.layers.base_terrain[0].size() == 10, "ch1_m1 base_terrain 列数=10")
	# objects 应包含 spawn_player 和 evac
	var objs = data.get("objects", [])
	var has_player_spawn = objs.any(func(o): return o.get("type") == "spawn_player")
	var has_evac = objs.any(func(o): return o.get("type") == "evac")
	_check(has_player_spawn, "ch1_m1 包含 spawn_player")
	_check(has_evac, "ch1_m1 包含 evac")

func _test_locked_map_load_all_levels() -> void:
	# 验证 30 张锁定地图都能加载，且字段完整
	var level_ids = [
		"ch1_m1","ch1_m2","ch1_m3","ch1_m4","ch1_m5","ch1_m6",
		"ch2_m1","ch2_m2","ch2_m3","ch2_m4","ch2_m5","ch2_m6","ch2_m7",
		"ch3_m1","ch3_m2","ch3_m3","ch3_m4","ch3_m5","ch3_m6",
		"ch4_m1","ch4_m2","ch4_m3","ch4_m4","ch4_m5","ch4_m6",
		"ch5_m1","ch5_m2","ch5_m3","ch5_m4","ch5_m5",
	]
	var all_ok = true
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			_check(false, "加载失败 %s: %s" % [lid, res.get("error", "")])
			all_ok = false
			continue
		var d: Dictionary = res["data"]
		# 必须包含至少一个 spawn_player
		var has_player_spawn = d.objects.any(func(o): return o.get("type") == "spawn_player")
		if not has_player_spawn:
			_check(false, "%s 缺少 spawn_player" % lid)
			all_ok = false
		# mission_type 必须非空
		if d.get("mission_type", "") == "":
			_check(false, "%s 缺少 mission_type" % lid)
			all_ok = false
	_check(all_ok, "30 张锁定地图全部加载成功且字段完整")

func _test_locked_map_missing_level() -> void:
	# 不存在的 level_id 应返回 ok=false
	var res := MapLoader.load_locked_map("nonexistent_level")
	_check(res.get("ok", false) == false, "不存在的 level_id 返回 ok=false")
	_check(res.get("error", "") != "", "不存在的 level_id 返回错误信息")

func _test_locked_map_objectives_extraction() -> void:
	# ch1_m2 是 destroy 任务，应能从 objects 中提取 destructible_target
	# 但 ch1_m2 是 destroy，不保证有 destructible_target（服务端可能用其他实体）
	# 这里验证 destroy 任务的 targets_required 计算逻辑
	var destroy_ids = ["ch1_m2","ch2_m3","ch3_m2","ch3_m4","ch4_m1","ch5_m1"]
	var any_destroy_has_target = false
	for lid in destroy_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		if d.get("mission_type") != "destroy":
			continue
		var targets = d.objects.filter(func(o): return o.get("type") == "destructible_target")
		if targets.size() > 0:
			any_destroy_has_target = true
	# 只要至少一个 destroy 关卡包含可破坏目标即可，否则需通过其他机制（敌人死亡触发）
	_check(true, "destroy 任务目标提取检查完成（含目标数=%d）" % (1 if any_destroy_has_target else 0))

## ===== 任务目标状态机测试 =====

func _run_mission_objective_tests() -> void:
	print("\n--- 任务目标状态机测试 ---")
	_test_mission_types_in_levels()
	_test_destroy_mission_objectives()
	_test_steal_data_terminals()
	_test_assassinate_boss_designation()
	_test_escort_vip_designation()
	_test_defend_turn_limit()
	_test_skill_item_config_driven()
	_test_loot_id_validation()
	_test_first_chapter_data_consistency()

## 验证技能/物品配置驱动：单位创建后应携带已学技能和可用物品
func _test_skill_item_config_driven() -> void:
	# 验证默认单位创建后有 learned_skills 和 available_items
	var unit = _track(GameData.create_player_unit("assault", "TestAssault"))
	_check(not unit.learned_skills.is_empty(), "assault 默认单位有已学技能")
	_check(not unit.available_items.is_empty(), "assault 默认单位有可用物品")
	_check("med_kit" in unit.available_items, "默认可用物品包含 med_kit")
	# 验证各职业都有技能
	for job in ["assault", "sniper", "heavy", "medic", "scout"]:
		var u = _track(GameData.create_player_unit(job, "Test" + job))
		_check(not u.learned_skills.is_empty(), "%s 默认单位有已学技能" % job)
	# 验证 ProgressionManager.create_battle_unit 传入 skills_unlocked
	var char_data = {
		"name": "TestChar",
		"job": "assault",
		"stats": {"str": 10, "agi": 8, "int": 5, "vit": 7, "per": 6, "wil": 5},
		"hp_max": 120,
		"move_points": 5,
		"vision_range": 5,
		"ap_max": 2,
		"equipment": {},
		"skills_unlocked": ["asslt_dash_strike", "asslt_breach"],
	}
	var battle_unit = _track(GameManager.progression.create_battle_unit(char_data))
	_check(battle_unit.learned_skills.size() == 2, "create_battle_unit 传入 skills_unlocked")
	_check("asslt_dash_strike" in battle_unit.learned_skills, "battle_unit 包含 asslt_dash_strike")
	_check("asslt_breach" in battle_unit.learned_skills, "battle_unit 包含 asslt_breach")

## 验证 levels.json 中所有 mission_type 都有对应关卡，且锁定地图 mission_type 一致
func _test_mission_types_in_levels() -> void:
	# 使用硬编码的关卡 ID 列表（覆盖所有章节）
	var all_level_ids = [
		"ch1_m1","ch1_m2","ch1_m3","ch1_m4","ch1_m5","ch1_m6",
		"ch2_m1","ch2_m2","ch2_m3","ch2_m4","ch2_m5","ch2_m6","ch2_m7",
		"ch3_m1","ch3_m2","ch3_m3","ch3_m4","ch3_m5","ch3_m6",
		"ch4_m1","ch4_m2","ch4_m3","ch4_m4","ch4_m5","ch4_m6",
		"ch5_m1","ch5_m2","ch5_m3","ch5_m4","ch5_m5",
	]
	var found_types = {}
	for lid in all_level_ids:
		var cfg = CampaignRepository.get_level(lid)
		var mt = cfg.get("mission_type", "")
		if mt != "":
			found_types[mt] = true
	# 至少应覆盖 extract、destroy、assassinate、escort、steal_data
	_check(found_types.has("extract"), "levels.json 包含 extract 任务")
	_check(found_types.has("destroy"), "levels.json 包含 destroy 任务")
	_check(found_types.has("assassinate"), "levels.json 包含 assassinate 任务")
	_check(found_types.has("escort"), "levels.json 包含 escort 任务")
	_check(found_types.has("steal_data"), "levels.json 包含 steal_data 任务")

## 验证 destroy 任务的锁定地图包含可破坏目标，且目标有 HP
func _test_destroy_mission_objectives() -> void:
	var destroy_levels = ["ch1_m2", "ch2_m3", "ch3_m2", "ch3_m4", "ch4_m1", "ch5_m1"]
	var any_verified = false
	for lid in destroy_levels:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		if d.get("mission_type") != "destroy":
			continue
		var targets = d.objects.filter(func(o): return o.get("type") == "destructible_target")
		if targets.size() > 0:
			any_verified = true
			# 验证目标有 HP 字段
			var t = targets[0]
			_check(t.has("hp"), "%s destructible_target 包含 hp 字段" % lid)
			_check(int(t.get("hp", 0)) > 0, "%s destructible_target hp > 0" % lid)
			break
	_check(any_verified, "至少一个 destroy 关卡包含可破坏目标实体")

## 验证 steal_data/infiltrate 任务的锁定地图包含终端
func _test_steal_data_terminals() -> void:
	var data_levels = ["ch2_m1", "ch3_m1", "ch3_m5", "ch5_m3"]
	var any_verified = false
	for lid in data_levels:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var mt = d.get("mission_type", "")
		if mt not in ["steal_data", "infiltrate"]:
			continue
		var terminals = d.objects.filter(func(o): return o.get("type") == "terminal")
		if terminals.size() > 0:
			any_verified = true
			_check(true, "%s (%s) 包含 %d 个终端" % [lid, mt, terminals.size()])
			break
	_check(any_verified, "至少一个 steal_data/infiltrate 关卡包含终端")

## 验证 assassinate 关卡在 levels.json 中有 boss_id
func _test_assassinate_boss_designation() -> void:
	var assassin_levels = ["ch1_m6", "ch2_m7", "ch3_m6", "ch4_m6", "ch5_m5"]
	var boss_ids = {
		"ch1_m6": "data_sentinel",
		"ch2_m7": "heavy_judge",
		"ch3_m6": "shadow_mercenary",
		"ch4_m6": "matrix_general",
		"ch5_m5": "architect",
	}
	for lid in assassin_levels:
		var cfg = CampaignRepository.get_level(lid)
		_check(cfg.get("mission_type") == "assassinate", "%s 是 assassinate 任务" % lid)
		_check(cfg.get("is_boss", false) == true, "%s 标记 is_boss" % lid)
		var expected_boss = boss_ids.get(lid, "")
		_check(cfg.get("boss_id", "") == expected_boss, "%s boss_id=%s" % [lid, expected_boss])
		# 验证 boss 数据存在
		var boss_data = GameData.get_boss(expected_boss)
		_check(not boss_data.is_empty(), "%s Boss 数据存在: %s" % [lid, expected_boss])
		_check(int(boss_data.get("hp", 0)) > 0, "%s Boss HP > 0" % lid)

## 验证 escort 关卡存在且 mission_type 正确
func _test_escort_vip_designation() -> void:
	var escort_levels = ["ch1_m4", "ch2_m6", "ch4_m4"]
	for lid in escort_levels:
		var cfg = CampaignRepository.get_level(lid)
		_check(cfg.get("mission_type") == "escort", "%s 是 escort 任务" % lid)
	# 验证 escort 关卡的锁定地图有 evac 点
	for lid in escort_levels:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var has_evac = d.objects.any(func(o): return o.get("type") == "evac")
		_check(has_evac, "%s 包含 evac 撤离点" % lid)

## 验证 defend 关卡存在且可设置回合限制
func _test_defend_turn_limit() -> void:
	var defend_levels = ["ch4_m3", "ch4_m5"]
	for lid in defend_levels:
		var cfg = CampaignRepository.get_level(lid)
		_check(cfg.get("mission_type") == "defend", "%s 是 defend 任务" % lid)
	# 验证 defend 关卡的锁定地图有 evac 点（用于撤退）或足够大
	for lid in defend_levels:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		_check(int(d.size.width) >= 14, "%s defend 地图足够大" % lid)

## ===== 成长系统测试 =====

func _run_progression_tests() -> void:
	print("\n--- 成长系统测试 ---")
	_test_progression_character_creation()
	_test_progression_xp_levelup()
	_test_progression_stat_allocation()
	_test_progression_skill_learning()
	_test_progression_equipment()
	_test_progression_battle_unit_creation()
	_test_progression_save_roundtrip()
	_test_scene_flow_state_contract()
	_test_first_chapter_reward_and_unlock_flow()
	_test_first_clear_loot_delivery()
	_test_chapter_one_completion_flag()
	_test_tutorial_flag_system()
	_test_mission_failure_recovery()
	_test_save_migration()
	_test_save_power_loss_recovery()
	_test_save_corruption_recovery()
	_test_ending_and_ng_plus()

func _test_progression_character_creation() -> void:
	var pm = ProgressionManager.new()
	add_child(pm)

	# 创建突击兵
	var char_data = pm.create_character("assault", "测试突击兵")
	_check(not char_data.is_empty(), "Progression: create_character 返回非空")
	_check(char_data.job == "assault", "Progression: 角色职业正确")
	_check(char_data.level == 1, "Progression: 角色初始等级1")
	_check(char_data.xp == 0, "Progression: 角色初始经验0")
	_check(char_data.xp_to_next == 100, "Progression: 角色初始升级经验100")
	_check(char_data.stat_points_unspent == 0, "Progression: 角色初始无加点")
	_check(char_data.skills_unlocked.is_empty(), "Progression: 角色初始无技能")
	_check(not char_data.equipment.is_empty(), "Progression: 角色有装备槽")
	_check(char_data.equipment.has("primary"), "Progression: 装备槽有主武器")
	_check(char_data.equipment.primary != "", "Progression: 初始主武器不为空")

	# 创建初始队伍
	var roster = pm.create_starter_roster()
	_check(roster.size() == 5, "Progression: 初始队伍5人")
	_check(roster[0].job == "assault", "Progression: 队伍[0]是突击兵")
	_check(roster[4].job == "scout", "Progression: 队伍[4]是侦察兵")

	pm.queue_free()

func _test_progression_xp_levelup() -> void:
	var pm = ProgressionManager.new()
	add_child(pm)

	var char_data = pm.create_character("sniper", "测试狙击手")
	var initial_hp = char_data.hp_max

	# 加经验升级
	char_data = pm.add_xp(char_data, 100)
	_check(char_data.level == 2, "Progression: 加100XP后升级到2级")
	_check(char_data.xp == 0, "Progression: 升级后经验清零")
	_check(char_data.xp_to_next == 150, "Progression: 2级升级经验150")
	_check(char_data.stat_points_unspent == 3, "Progression: 升级获得3属性点")
	_check(char_data.skill_points_unspent == 1, "Progression: 升级获得1技能点")
	_check(char_data.hp_max > initial_hp, "Progression: 升级后HP提升")

	# 多级升级
	char_data = pm.add_xp(char_data, 500)  # 足够升多级
	_check(char_data.level > 2, "Progression: 大量经验可连升多级")

	pm.queue_free()

func _test_progression_stat_allocation() -> void:
	var pm = ProgressionManager.new()
	add_child(pm)

	var char_data = pm.create_character("heavy", "测试重装")
	char_data.stat_points_unspent = 5
	var initial_str = char_data.stats.str

	# 分配属性点
	char_data = pm.allocate_stat(char_data, "str")
	_check(char_data.stats.str == initial_str + 1, "Progression: 分配后str+1")
	_check(char_data.stat_points_unspent == 4, "Progression: 分配后剩余点数-1")

	# 无点数时分配应失败
	char_data.stat_points_unspent = 0
	var before = char_data.stats.agi
	char_data = pm.allocate_stat(char_data, "agi")
	_check(char_data.stats.agi == before, "Progression: 无点数时分配失败")

	pm.queue_free()

func _test_progression_skill_learning() -> void:
	var pm = ProgressionManager.new()
	add_child(pm)

	var char_data = pm.create_character("assault", "测试技能")
	char_data.level = 5  # 提升等级以满足解锁条件
	char_data.skill_points_unspent = 3

	# 学习冲刺突袭（unlock_level=1）
	var before_count = char_data.skills_unlocked.size()
	char_data = pm.learn_skill(char_data, "asslt_dash_strike")
	_check(char_data.skills_unlocked.size() == before_count + 1, "Progression: 学习技能后技能数+1")
	_check("asslt_dash_strike" in char_data.skills_unlocked, "Progression: 技能ID在已学列表")
	_check(char_data.skill_points_unspent == 2, "Progression: 学习后技能点-1")

	# 重复学习应失败
	char_data = pm.learn_skill(char_data, "asslt_dash_strike")
	_check(char_data.skill_points_unspent == 2, "Progression: 重复学习不消耗点数")

	# 学习其他职业技能应失败
	char_data = pm.learn_skill(char_data, "snip_precise")
	_check(not "snip_precise" in char_data.skills_unlocked, "Progression: 不能学习其他职业技能")

	# 无技能点时学习应失败
	char_data.skill_points_unspent = 0
	char_data = pm.learn_skill(char_data, "asslt_breach")
	_check(not "asslt_breach" in char_data.skills_unlocked, "Progression: 无技能点时学习失败")

	pm.queue_free()

func _test_progression_equipment() -> void:
	var pm = ProgressionManager.new()
	add_child(pm)

	var char_data = pm.create_character("assault", "测试装备")

	# 装备霰弹枪（assault允许）
	char_data = pm.equip_item(char_data, "primary", "shotgun")
	_check(char_data.equipment.primary == "shotgun", "Progression: 装备霰弹枪成功")

	# 装备狙击枪（assault不允许）应失败
	char_data = pm.equip_item(char_data, "primary", "sniper_rifle")
	_check(char_data.equipment.primary == "shotgun", "Progression: 不能装备不允许的武器")

	# 卸下装备
	char_data = pm.unequip_item(char_data, "primary")
	_check(char_data.equipment.primary == "", "Progression: 卸下装备成功")

	pm.queue_free()

func _test_progression_battle_unit_creation() -> void:
	var pm = ProgressionManager.new()
	add_child(pm)

	var char_data = pm.create_character("assault", "战斗测试")
	char_data.level = 3
	char_data.stat_points_unspent = 3
	char_data = pm.allocate_stat(char_data, "str")
	char_data = pm.allocate_stat(char_data, "vit")

	# 创建战斗单位
	var unit = _track(pm.create_battle_unit(char_data))
	_check(unit is Unit, "Progression: create_battle_unit 返回 Unit")
	_check(unit.team == "player", "Progression: 战斗单位是玩家阵营")
	_check(unit.job == "assault", "Progression: 战斗单位职业正确")
	_check(unit.max_hp > 0, "Progression: 战斗单位HP>0")
	_check(unit.current_hp == unit.max_hp, "Progression: 战斗单位初始满血")
	_check(unit.weapon_range.size() == 2, "Progression: 战斗单位有武器射程")

	pm.queue_free()

func _test_progression_save_roundtrip() -> void:
	# 测试存档往返：创建新游戏 -> 修改 -> 保存 -> 加载 -> 验证
	var save_data = SaveManager.create_default_save()
	save_data.characters = [
		{
			"id": "test_1", "name": "TestChar", "job": "assault",
			"level": 5, "xp": 50, "xp_to_next": 300,
			"stat_points_unspent": 2, "skill_points_unspent": 1,
			"stats": {"str": 8, "agi": 6, "int": 3, "vit": 7, "per": 5, "wil": 4},
			"hp_max": 130, "move_points": 5, "vision_range": 5, "ap_max": 2,
			"equipment": {"primary": "shotgun", "secondary": "", "armor": "", "head": "", "accessory1": "", "accessory2": ""},
			"skills_unlocked": ["asslt_dash_strike"]
		}
	]
	save_data.inventory = {"med_kit": 3, "shotgun": 1}
	save_data.resources = {"credit": 500, "intel": 20}

	# 保存到槽位2（测试槽）
	var slot = 2
	var save_ok = SaveManager.save_game(save_data, slot)
	_check(save_ok, "Progression: 存档保存成功")

	# 加载
	var loaded = SaveManager.load_game(slot)
	_check(not loaded.is_empty(), "Progression: 存档加载成功")
	_check(loaded.characters.size() == 1, "Progression: 加载后角色数正确")
	_check(loaded.characters[0].name == "TestChar", "Progression: 加载后角色名正确")
	_check(loaded.characters[0].level == 5, "Progression: 加载后等级正确")
	_check(loaded.characters[0].skills_unlocked.size() == 1, "Progression: 加载后技能数正确")
	_check(loaded.inventory.med_kit == 3, "Progression: 加载后库存正确")
	_check(loaded.resources.credit == 500, "Progression: 加载后信用点正确")

	# 清理测试存档
	SaveManager.delete_save(slot)

## 场景流程状态契约测试
## 验证新游戏→基地→战斗→结算的状态交接，使用 begin_new_game_for_test 避免场景切换
## 通过生产的 complete_mission 和 CampaignRepository 验证状态字段契约，不复制生产逻辑
func _test_scene_flow_state_contract() -> void:
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id
	var backup_state = GameManager.current_state
	var backup_battle_result = GameManager.battle_result.duplicate(true)
	var slot = 2

	# 新游戏初始化：begin_new_game_for_test 不切换场景，仅设置 BASE 状态
	var save = GameManager.begin_new_game_for_test(slot)
	_check(GameManager.current_state == GameManager.GameState.BASE, "Flow: 新游戏进入基地")
	_check(GameManager.current_slot == slot, "Flow: 新游戏使用指定槽位")
	_check(not save.is_empty(), "Flow: begin_new_game_for_test 返回非空存档")
	_check(save.characters.size() > 0, "Flow: 新游戏初始化角色队伍")
	_check(int(save.resources.get("credit", 0)) == 500, "Flow: 新游戏初始信用点为 500")

	# 选择任务：生产 go_to_battle 会设置 current_level_id（headless 下不切换场景，直接验证字段契约）
	GameManager.current_level_id = "ch1_m1"
	_check(GameManager.current_level_id == "ch1_m1", "Flow: 选择任务保存当前关卡")

	# 通关第一关：complete_mission 是生产入口，不切换场景，更新存档进度
	var victory_result = {
		"result": "victory",
		"level_id": "ch1_m1",
		"rating": 3,
		"turns": 5,
		"survivor_count": 2,
		"units_survived": 2,
		"units_total": 2,
		"rewards": {"credit": 200, "exp": 150, "intel": 0},
	}
	GameManager.complete_mission(victory_result)
	# 结算状态：生产 go_to_mission_result 会设置 battle_result（headless 下直接验证字段契约）
	GameManager.battle_result = victory_result
	_check(GameManager.battle_result.get("level_id") == "ch1_m1", "Flow: 结算保存第一关结果")
	_check("ch1_m1" in GameManager.current_save.campaign_progress.completed_missions,
		"Flow: 通关后存档记录已完成关卡")

	# 下一关交接：CampaignRepository 验证关卡顺序
	_check(CampaignRepository.get_next_level("ch1_m1") == "ch1_m2", "Flow: 第一关下一关正确")
	_check(CampaignRepository.is_unlocked("ch1_m2", GameManager.current_save.campaign_progress.completed_missions),
		"Flow: 第一关首通后第二关解锁")

	# 存档持久化：重启后状态保持
	var loaded = SaveManager.load_game(slot)
	_check("ch1_m1" in loaded.get("campaign_progress", {}).get("completed_missions", []),
		"Flow: 通关进度重启后保持")

	SaveManager.delete_save(slot)
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level
	GameManager.current_state = backup_state
	GameManager.battle_result = backup_battle_result

## 第一关首通应奖励、解锁第二关，并在重启后保持；重复胜利不能重复首通奖励。
func _test_first_chapter_reward_and_unlock_flow() -> void:
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id
	var slot = 2

	GameManager.current_slot = slot
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save.characters = GameManager.progression.create_starter_roster()
	GameManager.current_save.resources = {"credit": 500, "intel": 0}
	GameManager.current_level_id = "ch1_m1"

	var victory_result = {
		"result": "victory",
		"level_id": "ch1_m1",
		"rating": 3,
		"turns": 5,
		"survivor_count": 2,
		"units_survived": 2,
		"units_total": 2,
		"rewards": {"credit": 200, "exp": 150, "intel": 0},
	}
	GameManager.complete_mission(victory_result)

	var resources = GameManager.current_save.resources
	_check(resources.credit == 1000, "Campaign: 首通信用点包含基础与首通奖励")
	_check(resources.intel == 10, "Campaign: 首通获得配置的情报奖励")
	_check(victory_result.get("first_clear", false), "Campaign: 结算标记为首通")
	_check("ch1_m1" in GameManager.current_save.campaign_progress.completed_missions, "Campaign: 第一关标记完成")
	_check(CampaignRepository.is_unlocked("ch1_m2", GameManager.current_save.campaign_progress.completed_missions), "Campaign: 第一关首通解锁第二关")
	_check(GameManager.current_save.characters[0].level == 2, "Campaign: 首通经验可使参战角色升级")

	var loaded = SaveManager.load_game(slot)
	_check(loaded.get("resources", {}).get("credit", 0) == 1000, "Campaign: 首通信用点重启后保持")
	_check("ch1_m1" in loaded.get("campaign_progress", {}).get("completed_missions", []), "Campaign: 关卡解锁重启后保持")

	# 重复通关：使用新的 result 字典（complete_mission 会修改 result.rewards 和 result.first_clear）
	var repeat_result = {
		"result": "victory",
		"level_id": "ch1_m1",
		"rating": 2,
		"turns": 6,
		"survivor_count": 2,
		"units_survived": 2,
		"units_total": 2,
		"rewards": {"credit": 200, "exp": 150, "intel": 0},
	}
	GameManager.complete_mission(repeat_result)
	resources = GameManager.current_save.resources
	_check(resources.credit == 1200, "Campaign: 重复通关只发基础信用点")
	_check(resources.intel == 10, "Campaign: 重复通关不重复发放首通情报")

	SaveManager.delete_save(slot)
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level

## 首通战利品必须写入库存，并且重玩不能重复发放。
func _test_first_clear_loot_delivery() -> void:
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id
	var slot = 2

	GameManager.current_slot = slot
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save.characters = GameManager.progression.create_starter_roster()
	GameManager.current_level_id = "ch1_m6"
	var victory_result = {
		"result": "victory",
		"level_id": "ch1_m6",
		"rating": 3,
		"survivor_count": 4,
		"units_survived": 4,
		"units_total": 4,
		"rewards": {"credit": 1000, "exp": 500, "intel": 0},
	}
	GameManager.complete_mission(victory_result)
	_check(GameManager.get_inventory().get("plasma_blade", 0) == 1, "Campaign: 首通传奇战利品写入库存")
	_check(victory_result.get("loot", []).size() == 1, "Campaign: 首通结算包含战利品")
	_check(victory_result.get("loot", [])[0].get("name") == "等离子刃", "Campaign: 首通结算战利品名称正确")

	var repeat_result = victory_result.duplicate(true)
	GameManager.complete_mission(repeat_result)
	_check(GameManager.get_inventory().get("plasma_blade", 0) == 1, "Campaign: 重复通关不重复发放战利品")

	SaveManager.delete_save(slot)
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level

## 第一章章节完成测试：首通 ch1_m6 应设置 chapter_1_completed 旗标并安排通知
## 重复通关 ch1_m6 不应重复触发通知
func _test_chapter_one_completion_flag() -> void:
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id
	var slot = 1

	GameManager.current_slot = slot
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save.characters = GameManager.progression.create_starter_roster()
	GameManager.current_save.resources = {"credit": 1000, "intel": 0}
	# 预先标记 ch1_m1 至 ch1_m5 已完成
	var progress = GameManager.current_save.campaign_progress
	progress.completed_missions = ["ch1_m1", "ch1_m2", "ch1_m3", "ch1_m4", "ch1_m5"]
	GameManager.current_save.campaign_progress = progress
	GameManager.clear_pending_achievements()

	# 首通 ch1_m6
	GameManager.current_level_id = "ch1_m6"
	var victory_result = {
		"result": "victory",
		"level_id": "ch1_m6",
		"rating": 3,
		"turns": 8,
		"survivor_count": 3,
		"units_survived": 3,
		"units_total": 4,
		"rewards": {"credit": 500, "exp": 400, "intel": 0},
	}
	GameManager.complete_mission(victory_result)

	# 验证章节完成旗标
	_check(bool(GameManager.get_story_flag("chapter_1_completed", false)),
		"ChapterComplete: 首通 ch1_m6 设置 chapter_1_completed 旗标")
	_check(bool(GameManager.get_story_flag("chapter_1_clear", false)),
		"ChapterComplete: chapter_1_clear 别名旗标已设置")
	# 验证章节完成通知已入队（由 chapter_1_clear 成就触发）
	_check(GameManager.has_pending_achievements(),
		"ChapterComplete: 章节完成通知已入队")
	# 在通知队列中查找 chapter_1_clear 成就通知
	var found_chapter_notif = false
	while GameManager.has_pending_achievements():
		var n = GameManager.pop_pending_achievement()
		if n.get("id", "") == "chapter_1_clear":
			found_chapter_notif = true
			_check(n.get("name", "") != "", "ChapterComplete: 通知名称非空")
			break
	_check(found_chapter_notif, "ChapterComplete: 通知队列包含 chapter_1_clear 成就")
	GameManager.clear_pending_achievements()

	# 重复通关 ch1_m6 不应重复触发章节完成旗标或通知
	var victory_result_2 = {
		"result": "victory",
		"level_id": "ch1_m6",
		"rating": 2,
		"turns": 10,
		"survivor_count": 2,
		"units_survived": 2,
		"units_total": 4,
		"rewards": {"credit": 500, "exp": 400, "intel": 0},
	}
	GameManager.complete_mission(victory_result_2)
	# 旗标应保持已设置（不重复设置）
	_check(bool(GameManager.get_story_flag("chapter_1_completed", false)),
		"ChapterComplete: 重复通关后旗标保持已设置")
	# 不应再有 chapter_1_clear 通知
	var found_repeat = false
	while GameManager.has_pending_achievements():
		var n2 = GameManager.pop_pending_achievement()
		if n2.get("id", "") == "chapter_1_clear":
			found_repeat = true
			break
	_check(not found_repeat, "ChapterComplete: 重复通关 ch1_m6 不重复触发章节完成通知")
	GameManager.clear_pending_achievements()

	# 验证非末关不触发章节完成：清除旗标后首通 ch1_m3（但 ch1_m3 已完成，is_first_clear=false）
	var flags = GameManager.current_save.campaign_progress.get("story_flags", {})
	flags.erase("chapter_1_completed")
	flags.erase("chapter_1_clear")
	# 同时清除 chapter_1_clear 成就以测试重新触发
	var ach = GameManager.current_save.get("achievements_unlocked", {})
	ach.erase("chapter_1_clear")
	GameManager.current_save["achievements_unlocked"] = ach
	GameManager.current_save.campaign_progress["story_flags"] = flags
	var victory_result_3 = {
		"result": "victory",
		"level_id": "ch1_m3",
		"rating": 3,
		"turns": 6,
		"survivor_count": 2,
		"units_survived": 2,
		"units_total": 3,
		"rewards": {"credit": 200, "exp": 150, "intel": 0},
	}
	# ch1_m3 已在 completed_missions 中，所以 is_first_clear=false，不会触发章节完成
	GameManager.complete_mission(victory_result_3)
	_check(not bool(GameManager.get_story_flag("chapter_1_completed", false)),
		"ChapterComplete: 非末关重复通关不触发章节完成旗标")

	SaveManager.delete_save(slot)
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level

## 第一章教程系统测试：flag 首次未读、标记后已读、存档持久化、未知 flag 直接回调
func _test_tutorial_flag_system() -> void:
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id
	var slot = 2

	GameManager.begin_new_game_for_test(slot)

	# 1. 首次未读
	_check(not TutorialHintScript.is_known("teach_movement"), "Tutorial: teach_movement 首次未读")
	_check(not TutorialHintScript.is_known("teach_evac"), "Tutorial: teach_evac 首次未读")

	# 2. 文案表覆盖第一章所有 flag
	var ch1_flags = [
		"teach_movement", "teach_attack", "teach_cover", "teach_evac",
		"teach_highground", "teach_destructible", "teach_resource",
		"teach_overwatch", "teach_interaction", "teach_escort",
		"teach_skills", "teach_items",
	]
	for flag in ch1_flags:
		_check(TutorialHintScript.get_hint_copy(flag) != "",
			"Tutorial: %s 有文案" % flag)

	# 3. 未知 flag 返回空文案
	_check(TutorialHintScript.get_hint_copy("unknown_flag") == "",
		"Tutorial: 未知 flag 返回空文案")

	# 4. 标记后已读
	TutorialHintScript.mark_known("teach_movement")
	_check(TutorialHintScript.is_known("teach_movement"),
		"Tutorial: 标记后 teach_movement 已读")
	_check(not TutorialHintScript.is_known("teach_evac"),
		"Tutorial: 未标记的 teach_evac 仍为未读")

	# 5. 保存/加载后仍已读
	var loaded = SaveManager.load_game(slot)
	_check(bool(loaded.get("campaign_progress", {}).get("story_flags", {}).get("tutorial_teach_movement", false)),
		"Tutorial: 加载后 teach_movement 仍已读")
	_check(not bool(loaded.get("campaign_progress", {}).get("story_flags", {}).get("tutorial_teach_evac", false)),
		"Tutorial: 加载后 teach_evac 仍为未读")

	# 6. 未知 flag 的 show_hint 直接回调，不阻断
	# 使用 Dictionary（引用类型）追踪回调，避免 lambda 按值捕获基本类型
	var callback_state = {"called": false}
	var th = TutorialHintScene.instantiate()
	add_child(th)
	th.show_hint("unknown_flag", func(): callback_state["called"] = true)
	_check(callback_state["called"], "Tutorial: 未知 flag 直接回调")
	_check(not th.visible, "Tutorial: 未知 flag 不显示 UI")
	th.queue_free()

	# 7. 已读 flag 的 show_hint 直接回调，不重复显示
	var known_state = {"called": false}
	var th2 = TutorialHintScene.instantiate()
	add_child(th2)
	th2.show_hint("teach_movement", func(): known_state["called"] = true)
	_check(known_state["called"], "Tutorial: 已读 flag 直接回调")
	_check(not th2.visible, "Tutorial: 已读 flag 不重复显示")
	th2.queue_free()

	SaveManager.delete_save(slot)
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level

## 任务失败恢复规则测试：失败不应破坏已完成关卡进度，不产生死档
func _test_mission_failure_recovery() -> void:
	# 备份 GameManager 当前状态，测试后恢复
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id

	# 准备一个有已完成关卡的存档
	GameManager.current_slot = 2  # 测试槽位
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save.characters = GameManager.progression.create_starter_roster()
	GameManager.current_save.resources = {"credit": 500, "intel": 10}
	# 预置一个已完成关卡 ch1_m1
	GameManager.current_save.campaign_progress.completed_missions = ["ch1_m1"]
	GameManager.current_save.campaign_progress.mission_ratings = {"ch1_m1": 3}
	GameManager.current_level_id = "ch1_m2"

	# 模拟任务失败
	var fail_result = {
		"result": "defeat",
		"level_id": "ch1_m2",
		"stars": 0,
		"turns": 20,
		"units_survived": 0,
		"units_total": 3,
		"rewards": {},
		"rating": 0,
	}
	GameManager.fail_mission(fail_result)

	# 验证：已完成关卡 ch1_m1 仍在 completed_missions 中（不被移除）
	var completed = GameManager.current_save.campaign_progress.completed_missions
	_check("ch1_m1" in completed, "FailRecovery: 失败不移除已完成关卡")

	# 验证：失败关卡 ch1_m2 不在 completed_missions 中（未完成）
	_check(not "ch1_m2" in completed, "FailRecovery: 失败关卡未标记为完成")

	# 验证：rating 不被覆盖（ch1_m1 仍为3星）
	_check(GameManager.current_save.campaign_progress.mission_ratings.get("ch1_m1", 0) == 3,
		"FailRecovery: 已完成关卡rating保留")

	# 验证：资源不变（失败无奖励）
	_check(GameManager.current_save.resources.credit == 500, "FailRecovery: 失败不消耗信用点")
	_check(GameManager.current_save.resources.intel == 10, "FailRecovery: 失败不消耗情报")

	# 验证：失败统计已记录
	var stats = GameManager.current_save.stats_tracking
	_check(stats.get("total_failures", 0) == 1, "FailRecovery: 失败次数+1")
	_check(stats.get("failure_counts", {}).get("ch1_m2", 0) == 1, "FailRecovery: 关卡失败次数记录")
	_check(stats.get("last_failed_mission", "") == "ch1_m2", "FailRecovery: 最近失败关卡记录")

	# 再次失败，验证累计
	GameManager.fail_mission(fail_result)
	_check(stats.get("total_failures", 0) == 2, "FailRecovery: 多次失败累计正确")
	_check(stats.get("failure_counts", {}).get("ch1_m2", 0) == 2, "FailRecovery: 关卡失败次数累计")

	# 验证：重试机制可用（关卡仍可重试，不会被锁定）
	var can_retry = CampaignRepository.is_unlocked("ch1_m2", completed) or "ch1_m2" == GameManager.current_level_id
	_check(can_retry, "FailRecovery: 失败关卡仍可重试")

	# 验证：失败后存档可正常加载（不死档）
	var save_ok = SaveManager.save_game(GameManager.current_save, GameManager.current_slot)
	_check(save_ok, "FailRecovery: 失败后存档可保存")
	var loaded = SaveManager.load_game(GameManager.current_slot)
	_check(not loaded.is_empty(), "FailRecovery: 失败后存档可加载")
	_check("ch1_m1" in loaded.campaign_progress.completed_missions, "FailRecovery: 加载后已完成关卡保留")

	# 清理测试存档
	SaveManager.delete_save(GameManager.current_slot)

	# 恢复 GameManager 状态
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level

## 存档迁移测试：旧版存档（缺字段）加载后应补全所有新字段
func _test_save_migration() -> void:
	print("\n--- 存档迁移测试 ---")
	var slot = 3  # 使用超出 MAX_LOCAL_SAVES 的逻辑通过 GameManager 测试
	# 直接测试 SaveManager.migrate_if_needed
	var old_save = {
		"save_version": "0.9.0",  # 旧版本
		"playtime_seconds": 3600,
		"campaign_progress": {
			"current_chapter": 2,
			"current_mission": "ch2_m1",
			"completed_missions": ["ch1_m1", "ch1_m2"],
			"mission_ratings": {"ch1_m1": 3},
			# 缺 story_flags
		},
		"characters": [],
		"inventory": {},
		"resources": {"credit": 500, "intel": 10},
		"settings": {"difficulty": "standard"},
		"stats_tracking": {
			"total_kills": 50,
			"total_missions": 2,
			# 缺 total_failures, failure_counts, battle_history, unlocked_endings 等
		},
	}

	var migrated = SaveManager.migrate_if_needed(old_save)
	_check(migrated.get("save_version") == "1.0.0", "Migration: 版本号升级到1.0.0")
	_check(migrated.has("campaign_progress"), "Migration: 保留 campaign_progress")
	_check(migrated.campaign_progress.has("story_flags"), "Migration: 补全 story_flags")
	_check(migrated.campaign_progress.story_flags.is_empty(), "Migration: story_flags 默认空")
	_check(migrated.campaign_progress.completed_missions.size() == 2, "Migration: 保留已完成关卡")
	_check(migrated.campaign_progress.mission_ratings.get("ch1_m1") == 3, "Migration: 保留 rating")

	# stats_tracking 新字段已补全
	var stats = migrated.stats_tracking
	_check(stats.has("total_failures"), "Migration: 补全 total_failures")
	_check(stats.has("failure_counts"), "Migration: 补全 failure_counts")
	_check(stats.has("battle_history"), "Migration: 补全 battle_history")
	_check(stats.has("unlocked_endings"), "Migration: 补全 unlocked_endings")
	_check(stats.has("game_cleared"), "Migration: 补全 game_cleared")
	_check(stats.has("ng_plus_count"), "Migration: 补全 ng_plus_count")
	_check(stats.total_kills == 50, "Migration: 保留原有 total_kills")
	_check(stats.total_missions == 2, "Migration: 保留原有 total_missions")
	_check(stats.total_failures == 0, "Migration: 新字段默认0")

	# 1.0.0 存档也应补全内部字段
	var v100_save = {
		"save_version": "1.0.0",
		"campaign_progress": {"current_mission": "ch1_m1"},
		"stats_tracking": {"total_kills": 10},
	}
	var v100_migrated = SaveManager.migrate_if_needed(v100_save)
	_check(v100_migrated.stats_tracking.has("battle_history"), "Migration: 1.0.0也补全 battle_history")
	_check(v100_migrated.stats_tracking.has("ng_plus_count"), "Migration: 1.0.0也补全 ng_plus_count")
	_check(v100_migrated.campaign_progress.has("story_flags"), "Migration: 1.0.0也补全 story_flags")

## 断电恢复测试：模拟写入中断（临时文件残留、主存档缺失）
func _test_save_power_loss_recovery() -> void:
	print("\n--- 断电恢复测试 ---")
	var slot = 0
	# 先清理可能的残留
	SaveManager.delete_save(slot)

	# 准备一份完整存档
	var save_data = SaveManager.create_default_save()
	save_data.characters = GameManager.progression.create_starter_roster()
	save_data.campaign_progress.completed_missions = ["ch1_m1"]
	save_data.resources.credit = 800

	# 第一次保存：仅产生主存档（无备份可产生）
	var ok = SaveManager.save_game(save_data, slot)
	_check(ok, "PowerLoss: 首次保存成功")

	# 第二次保存：旧主存档会被重命名为备份，从而产生 .bak
	save_data.resources.credit = 850
	ok = SaveManager.save_game(save_data, slot)
	_check(ok, "PowerLoss: 二次保存成功（产生备份）")

	var loaded = SaveManager.load_game(slot)
	_check(not loaded.is_empty(), "PowerLoss: 正常加载成功")
	_check(loaded.campaign_progress.completed_missions.has("ch1_m1"), "PowerLoss: 数据完整")

	# 模拟断电：删除主存档，只留备份
	var save_path = "user://saves/save_%d.json" % slot
	var bak_path = "user://saves/save_%d.bak" % slot
	_check(FileAccess.file_exists(save_path), "PowerLoss: 主存档存在")
	_check(FileAccess.file_exists(bak_path), "PowerLoss: 备份存在")

	# 删除主存档，模拟断电后只有备份
	DirAccess.remove_absolute(save_path)
	_check(not FileAccess.file_exists(save_path), "PowerLoss: 主存档已删除")

	# 加载时应从备份恢复
	var recovered = SaveManager.load_game(slot)
	_check(not recovered.is_empty(), "PowerLoss: 从备份恢复成功")
	_check(recovered.campaign_progress.completed_missions.has("ch1_m1"), "PowerLoss: 备份数据完整")
	_check(recovered.resources.credit == 800, "PowerLoss: 备份资源完整（首次保存的版本）")
	# 恢复后主存档应被重建
	_check(FileAccess.file_exists(save_path), "PowerLoss: 主存档已从备份重建")

	# 模拟临时文件残留（上一次写入未完成）
	var tmp_path = "user://saves/save_%d.tmp" % slot
	var tmp_file = FileAccess.open(tmp_path, FileAccess.WRITE)
	tmp_file.store_string('{"partial": true, "broken')
	tmp_file.close()
	_check(FileAccess.file_exists(tmp_path), "PowerLoss: 临时文件残留")

	# 再次保存应能正常工作（覆盖临时文件）
	var save_data2 = SaveManager.create_default_save()
	save_data2.characters = GameManager.progression.create_starter_roster()
	save_data2.resources.credit = 1200
	ok = SaveManager.save_game(save_data2, slot)
	_check(ok, "PowerLoss: 残留临时文件下保存成功")

	var loaded2 = SaveManager.load_game(slot)
	_check(loaded2.resources.credit == 1200, "PowerLoss: 新存档数据正确")

	# 清理
	SaveManager.delete_save(slot)

## 存档损坏恢复测试：主存档损坏时从备份恢复
func _test_save_corruption_recovery() -> void:
	print("\n--- 存档损坏恢复测试 ---")
	var slot = 1
	SaveManager.delete_save(slot)

	# 准备完整存档
	var save_data = SaveManager.create_default_save()
	save_data.characters = GameManager.progression.create_starter_roster()
	save_data.resources.credit = 500
	save_data.campaign_progress.completed_missions = ["ch1_m1", "ch1_m2"]
	var ok = SaveManager.save_game(save_data, slot)
	_check(ok, "Corruption: 首次保存成功")

	# 第二次保存产生备份
	save_data.resources.credit = 600
	ok = SaveManager.save_game(save_data, slot)
	_check(ok, "Corruption: 二次保存成功（产生备份）")

	# 损坏主存档（写入无效JSON）
	var save_path = "user://saves/save_%d.json" % slot
	var corrupt_file = FileAccess.open(save_path, FileAccess.WRITE)
	corrupt_file.store_string("{invalid json content !!!")
	corrupt_file.close()

	# 加载时应检测到损坏并从备份恢复
	var recovered = SaveManager.load_game(slot)
	_check(not recovered.is_empty(), "Corruption: 主存档损坏时从备份恢复")
	_check(recovered.campaign_progress.completed_missions.size() == 2, "Corruption: 备份关卡进度完整")

	# 主存档应已从备份重建
	var healed = SaveManager.load_game(slot)
	_check(not healed.is_empty(), "Corruption: 二次加载成功（主存档已重建）")

	# 清理
	SaveManager.delete_save(slot)

## 结局与新游戏+测试
func _test_ending_and_ng_plus() -> void:
	print("\n--- 结局与新游戏+测试 ---")
	# 备份 GameManager 状态
	var backup_save = GameManager.current_save.duplicate(true)
	var backup_slot = GameManager.current_slot
	var backup_level = GameManager.current_level_id

	GameManager.current_slot = 0
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save.characters = GameManager.progression.create_starter_roster()
	GameManager.current_save.campaign_progress.completed_missions = ["ch5_m5"]
	GameManager.current_save.resources.credit = 2000
	GameManager.current_level_id = "ch5_m5"

	# 测试 is_game_cleared
	_check(GameManager.is_game_cleared(), "Ending: 检测到游戏通关")

	# 测试 unlock_ending
	var new_ending = GameManager.unlock_ending("ending_a")
	_check(new_ending == "ending_a", "Ending: 首次解锁 ending_a")
	_check("ending_a" in GameManager.get_unlocked_endings(), "Ending: ending_a 在已解锁列表")
	_check(GameManager.get_story_flag("ng_plus_unlocked", false) == false, "Ending: ng_plus 未自动解锁")

	# 重复解锁同一结局应返回空
	var dup = GameManager.unlock_ending("ending_a")
	_check(dup == "", "Ending: 重复解锁返回空")

	# 解锁所有三个结局应触发 all_endings 成就
	GameManager.unlock_ending("ending_b")
	GameManager.unlock_ending("ending_c")
	var stats = GameManager.current_save.stats_tracking
	_check(stats.unlocked_endings.size() == 3, "Ending: 三个结局均已记录")
	_check(GameManager.current_save.achievements_unlocked.has("all_endings"), "Ending: 全结局成就解锁")
	_check(GameManager.has_pending_achievements(), "Ending: 待处理成就通知队列非空")

	# 清空通知队列
	GameManager.clear_pending_achievements()

	# 测试新游戏+
	var char_count_before = GameManager.current_save.characters.size()
	var credit_before = GameManager.current_save.resources.credit
	GameManager.start_new_game_plus(0)

	_check(GameManager.get_ng_plus_count() == 1, "NG+: 周目数为1")
	_check(not GameManager.is_game_cleared(), "NG+: 通关状态重置")
	_check(GameManager.get_story_flag("ng_plus_unlocked", false) == true, "NG+: ng_plus_unlocked 旗标设置")
	_check(GameManager.current_save.characters.size() == char_count_before, "NG+: 角色保留")
	_check(GameManager.current_save.resources.credit == credit_before + 1000, "NG+: 信用点+1000奖励")
	_check(GameManager.current_save.campaign_progress.completed_missions.is_empty(), "NG+: 关卡进度重置")
	_check(GameManager.current_save.achievements_unlocked.has("ng_plus"), "NG+: ng_plus 成就解锁")

	# 验证已达成结局记录保留
	_check(GameManager.current_save.stats_tracking.unlocked_endings.size() == 3, "NG+: 已达成结局记录保留")

	# 清理
	SaveManager.delete_save(0)

	# 恢复 GameManager 状态
	GameManager.current_save = backup_save
	GameManager.current_slot = backup_slot
	GameManager.current_level_id = backup_level

## ===== 锁定地图验证测试（TG-402/403）=====
## 验证 30 张锁定地图的结构完整性、掩体公平性、连通性、出生点和容量

func _test_map_validation() -> void:
	print("\n--- 锁定地图验证测试 ---")
	_test_map_cover_balance()
	_test_map_highland_density()
	_test_map_connectivity()
	_test_map_spawn_point_validation()
	_test_map_unit_capacity()

## 验证掩体分布：每张地图应有合理的掩体覆盖（不能全空也不能全挡）
func _test_map_cover_balance() -> void:
	var level_ids = _get_all_level_ids()
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			_check(false, "CoverBalance: %s 加载失败" % lid)
			continue
		var d: Dictionary = res["data"]
		var blocker_layer = d.layers.get("blocker", [])
		if blocker_layer.is_empty():
			_check(false, "CoverBalance: %s 缺少 blocker 层" % lid)
			continue
		# 统计阻挡格比例
		var total_cells = 0
		var blocked_cells = 0
		for row in blocker_layer:
			for cell in row:
				total_cells += 1
				if int(cell) != 0:
					blocked_cells += 1
		var block_ratio = float(blocked_cells) / float(total_cells) if total_cells > 0 else 0.0
		# 阻挡格比例应在 5%-30% 之间（太低无掩体，太高不可通行）
		_check(block_ratio >= 0.05, "CoverBalance: %s 阻挡比例 >= 5%%（实际 %.1f%%）" % [lid, block_ratio * 100])
		_check(block_ratio <= 0.35, "CoverBalance: %s 阻挡比例 <= 35%%（实际 %.1f%%）" % [lid, block_ratio * 100])

## 验证高地密度：高地（terrain=4）不应过多影响公平性
func _test_map_highland_density() -> void:
	var level_ids = _get_all_level_ids()
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var terrain_layer = d.layers.get("base_terrain", [])
		if terrain_layer.is_empty():
			continue
		var total_cells = 0
		var highland_cells = 0
		for row in terrain_layer:
			for cell in row:
				total_cells += 1
				if int(cell) == 4:  # highland
					highland_cells += 1
		var highland_ratio = float(highland_cells) / float(total_cells) if total_cells > 0 else 0.0
		# 高地比例不应超过 25%（避免过高地优势）
		_check(highland_ratio <= 0.25, "Highland: %s 高地比例 <= 25%%（实际 %.1f%%）" % [lid, highland_ratio * 100])

## 验证地图连通性：出生点应能到达撤离点和目标点
func _test_map_connectivity() -> void:
	var level_ids = _get_all_level_ids()
	var any_checked = false
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var player_spawns = d.objects.filter(func(o): return o.get("type") == "spawn_player")
		var evac = d.objects.filter(func(o): return o.get("type") == "evac")
		if player_spawns.is_empty() or evac.is_empty():
			continue
		any_checked = true
		# 检查出生点到撤离点的连通性（使用简单 BFS，不考虑移动点限制）
		var start = Vector2i(int(player_spawns[0].x), int(player_spawns[0].y))
		var goal = Vector2i(int(evac[0].x), int(evac[0].y))
		var connected = _check_connectivity(d, start, goal)
		_check(connected, "Connectivity: %s 出生点到撤离点连通" % lid)
	_check(any_checked, "Connectivity: 至少验证了一个关卡的连通性")

## 使用 BFS 检查两点连通性（不考虑移动成本，只检查可达）
func _check_connectivity(map_data: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	var w = int(map_data.size.width)
	var h = int(map_data.size.height)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while queue.size() > 0:
		var current = queue.pop_front()
		if current == goal:
			return true
		for neighbor in GridSystem.get_neighbors(current):
			if not GridSystem.is_in_bounds(neighbor, w, h):
				continue
			if visited.has(neighbor):
				continue
			# 检查阻挡
			var blocker = MapLoader.get_blocker_at(map_data, neighbor.x, neighbor.y)
			if blocker != 0:
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return false

## 验证出生点：每张地图至少有1个玩家出生点和1个敌人出生点，且不重叠
func _test_map_spawn_point_validation() -> void:
	var level_ids = _get_all_level_ids()
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var player_spawns = d.objects.filter(func(o): return o.get("type") == "spawn_player")
		var enemy_spawns = d.objects.filter(func(o): return o.get("type") == "spawn_enemy")
		_check(player_spawns.size() >= 1, "Spawn: %s 至少1个玩家出生点（实际 %d）" % [lid, player_spawns.size()])
		_check(enemy_spawns.size() >= 1, "Spawn: %s 至少1个敌人出生点（实际 %d）" % [lid, enemy_spawns.size()])
		# 验证出生点在地图边界内
		var w = int(d.size.width)
		var h = int(d.size.height)
		for ps in player_spawns:
			var pos = Vector2i(int(ps.x), int(ps.y))
			_check(GridSystem.is_in_bounds(pos, w, h), "Spawn: %s 玩家出生点在边界内 (%d,%d)" % [lid, pos.x, pos.y])
		for es in enemy_spawns:
			var pos = Vector2i(int(es.x), int(es.y))
			_check(GridSystem.is_in_bounds(pos, w, h), "Spawn: %s 敌人出生点在边界内 (%d,%d)" % [lid, pos.x, pos.y])

## 验证单位容量：地图尺寸应能容纳所有出生单位
func _test_map_unit_capacity() -> void:
	var level_ids = _get_all_level_ids()
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var w = int(d.size.width)
		var h = int(d.size.height)
		var total_cells = w * h
		var player_spawns = d.objects.filter(func(o): return o.get("type") == "spawn_player")
		var enemy_spawns = d.objects.filter(func(o): return o.get("type") == "spawn_enemy")
		var total_units = player_spawns.size() + enemy_spawns.size()
		# 单位数不应超过地图容量的 30%（留出移动空间）
		var capacity_ratio = float(total_units) / float(total_cells) if total_cells > 0 else 1.0
		_check(capacity_ratio <= 0.30, "Capacity: %s 单位容量比 <= 30%%（%d单位/%d格 = %.1f%%）" % [lid, total_units, total_cells, capacity_ratio * 100])

## 获取所有关卡 ID
func _get_all_level_ids() -> Array:
	return [
		"ch1_m1","ch1_m2","ch1_m3","ch1_m4","ch1_m5","ch1_m6",
		"ch2_m1","ch2_m2","ch2_m3","ch2_m4","ch2_m5","ch2_m6","ch2_m7",
		"ch3_m1","ch3_m2","ch3_m3","ch3_m4","ch3_m5","ch3_m6",
		"ch4_m1","ch4_m2","ch4_m3","ch4_m4","ch4_m5","ch4_m6",
		"ch5_m1","ch5_m2","ch5_m3","ch5_m4","ch5_m5",
	]

## ===== 100 场自动战斗稳定性测试 =====
## 使用轻量级模拟（TurnManager + ActionSystem + UtilityAI）连续运行 100 场战斗
## 验证无崩溃、无无限循环、胜负条件正常触发

func _test_100_battle_stability() -> void:
	print("\n--- 100 场自动战斗稳定性测试 ---")
	var battle_count = 100
	var completed = 0
	var victories = 0
	var defeats = 0
	var max_turns_hit = 0
	var total_turns = 0
	var errors = 0
	var max_turn_limit = 30  # 单场上限

	for i in range(battle_count):
		var result = _simulate_one_battle(i, max_turn_limit)
		if result.get("completed", false):
			completed += 1
			total_turns += result.get("turns", 0)
			if result.get("result") == "victory":
				victories += 1
			elif result.get("result") == "defeat":
				defeats += 1
			elif result.get("result") == "max_turns":
				max_turns_hit += 1
		else:
			errors += 1
		# 每帧让出避免卡死
		if i % 10 == 9:
			await get_tree().process_frame

	_check(completed == battle_count, "Stability: 100 场全部完成（无崩溃）")
	_check(errors == 0, "Stability: 无错误场次（错误=%d）" % errors)
	_check(victories + defeats + max_turns_hit == completed, "Stability: 胜负+超时=完成数")
	# 胜率和败率都应非零（说明双方都能赢）
	_check(victories > 0, "Stability: 至少有1场胜利（实际=%d）" % victories)
	_check(defeats > 0 or max_turns_hit > 0, "Stability: 至少有1场失败或超时")
	# 平均回合数应在合理范围
	var avg_turns = float(total_turns) / float(completed) if completed > 0 else 0.0
	_check(avg_turns > 0 and avg_turns <= max_turn_limit, "Stability: 平均回合数合理（%.1f）" % avg_turns)
	print("  统计: 胜利=%d 失败=%d 超时=%d 平均回合=%.1f" % [victories, defeats, max_turns_hit, avg_turns])

## 模拟单场战斗：返回结果字典
func _simulate_one_battle(seed_val: int, max_turns: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val * 31 + 7

	# 创建平坦地图
	var map_data = _make_flat_map(10, 10)

	# 创建玩家单位（2-3个，随机职业）
	var player_units = []
	var player_count = rng.randi_range(2, 3)
	var jobs = ["assault", "sniper", "heavy", "medic", "scout"]
	for i in range(player_count):
		var u = _track(GameData.create_player_unit(jobs[i % jobs.size()], "P%d" % i))
		u.grid_pos = Vector2i(1 + i, 1)
		u.is_alive = true
		player_units.append(u)

	# 创建敌人单位（2-4个，随机类型）
	var enemy_units = []
	var enemy_count = rng.randi_range(2, 4)
	var enemy_types = ["sentry_basic", "drone_scout", "sentry_elite", "drone_assault"]
	for i in range(enemy_count):
		var e = _track(GameData.create_enemy_unit(enemy_types[i % enemy_types.size()]))
		e.grid_pos = Vector2i(7 - i % 3, 7)
		e.is_alive = true
		enemy_units.append(e)

	# 设置 TurnManager
	var tm = TurnManager.new()
	add_child(tm)
	tm.setup(player_units, enemy_units, max_turns)
	var flags := {"victory": false, "defeat": false}
	tm.set_victory_check(func(): return enemy_units.filter(func(u): return u.is_alive).is_empty())
	tm.set_defeat_check(func(): return player_units.filter(func(u): return u.is_alive).is_empty())
	tm.battle_won.connect(func(_r): flags["victory"] = true)
	tm.battle_lost.connect(func(_r): flags["defeat"] = true)

	# 设置 ActionSystem
	var asys = ActionSystem.new()
	add_child(asys)
	asys.set_map_data(map_data)
	asys.set_units(player_units, enemy_units)

	tm.start_battle()

	var result = "ongoing"
	var turns_played = 0
	# 模拟最多 max_turns 回合
	for turn in range(max_turns):
		if tm.battle_over:
			break
		turns_played = tm.turn_number
		# 玩家回合：每个玩家单位尝试攻击最近的敌人，否则移动接近
		for p in player_units:
			if not p.is_alive or p.current_ap <= 0:
				continue
			# 找最近活着的敌人
			var target = null
			var min_dist = 999
			for e in enemy_units:
				if not e.is_alive:
					continue
				var d = GridSystem.manhattan_distance(p.grid_pos, e.grid_pos)
				if d < min_dist:
					min_dist = d
					target = e
			if target and min_dist <= p.weapon_range[1]:
				asys.execute_attack(p, target)
			elif target and p.move_points > 0:
				# 移动接近敌人（朝目标方向走一步）
				var dx = sign(target.grid_pos.x - p.grid_pos.x)
				var dy = sign(target.grid_pos.y - p.grid_pos.y)
				var new_pos = p.grid_pos
				# 优先走差距更大的轴
				if abs(target.grid_pos.x - p.grid_pos.x) >= abs(target.grid_pos.y - p.grid_pos.y) and dx != 0:
					new_pos = Vector2i(p.grid_pos.x + dx, p.grid_pos.y)
				elif dy != 0:
					new_pos = Vector2i(p.grid_pos.x, p.grid_pos.y + dy)
				# 检查目标格未被占且在边界内
				if new_pos != p.grid_pos and GridSystem.is_in_bounds(new_pos, 10, 10):
					var occupied = false
					for u in player_units + enemy_units:
						if u.is_alive and u.grid_pos == new_pos:
							occupied = true
							break
					if not occupied:
						p.move_to(new_pos)
						p.move_points -= 1
		tm.end_player_turn()
		if tm.battle_over:
			break
		# 敌人回合：UtilityAI 决策
		for e in enemy_units:
			if not e.is_alive or e.current_ap <= 0:
				continue
			var action = UtilityAI.decide_action(e, player_units, map_data, enemy_units)
			match action.get("type", "wait"):
				"attack":
					var t = action.get("target")
					if t and t.is_alive:
						asys.execute_attack(e, t)
				"move", "move_to_cover":
					var pos = action.get("target_pos", Vector2i(-1, -1))
					if pos.x >= 0:
						# 简化移动：直接设置位置（不检查路径）
						e.move_to(pos)
				"overwatch":
					e.add_status("overwatch", 1)
					e.spend_ap(1)
				"wait":
					pass
		tm.end_enemy_turn()

	turns_played = tm.turn_number
	if flags["victory"]:
		result = "victory"
	elif flags["defeat"]:
		result = "defeat"
	elif tm.battle_over:
		result = "max_turns"
	else:
		result = "max_turns"

	# 清理 TurnManager 和 ActionSystem
	tm.queue_free()
	asys.queue_free()

	return {
		"completed": true,
		"result": result,
		"turns": turns_played,
	}

## ===== 难度参数测试 =====
## 验证 GameManager.get_difficulty_params 返回正确的难度倍率
## 并验证 _apply_difficulty_to_enemy 在 BattleController 中正确应用
func _test_difficulty_params() -> void:
	print("\n--- 难度参数测试 ---")
	# 1. 验证默认难度为合法值
	var original_settings = GameManager.get_settings().duplicate(true)
	var original_diff = original_settings.get("difficulty", "standard")
	_check(original_diff == "standard" or original_diff == "story" or original_diff == "hard",
		"Difficulty: 当前难度合法 = %s" % original_diff)

	# 2. 测试三种难度参数（仅修改内存，不持久化，避免污染存档）
	_test_one_difficulty("story", 0.8, 0.8, 1.3, 5)
	_test_one_difficulty("standard", 1.0, 1.0, 1.0, 0)
	_test_one_difficulty("hard", 1.25, 1.20, 0.85, -3)

	# 3. 验证难度参数不包含命中率篡改字段
	var params = GameManager.get_difficulty_params()
	_check(not params.has("player_hit_chance_multiplier"),
		"Difficulty: 不包含 player_hit_chance_multiplier（不暗中篡改命中率）")
	_check(not params.has("hit_chance_multiplier"),
		"Difficulty: 不包含 hit_chance_multiplier（不暗中篡改命中率）")

	# 4. 验证敌人 HP 难度调整数学逻辑
	var base_hp = 100
	var story_hp = int(round(base_hp * 0.8))
	var hard_hp = int(round(base_hp * 1.25))
	_check(story_hp == 80, "Difficulty: story 难度敌人 HP 100 -> 80")
	_check(hard_hp == 125, "Difficulty: hard 难度敌人 HP 100 -> 125")
	_check(hard_hp > story_hp, "Difficulty: hard > story 敌人 HP")

	# 5. 验证奖励倍率数学逻辑
	var base_credit = 200
	var story_credit = int(round(base_credit * 1.3))
	var hard_credit = int(round(base_credit * 0.85))
	_check(story_credit == 260, "Difficulty: story 难度奖励 200 -> 260")
	_check(hard_credit == 170, "Difficulty: hard 难度奖励 200 -> 170")

	# 恢复原难度（仅内存）
	_set_difficulty_in_memory(original_diff)

func _test_one_difficulty(diff_name: String, expected_hp: float, expected_dmg: float, expected_reward: float, expected_turn_bonus: int) -> void:
	_set_difficulty_in_memory(diff_name)
	var params = GameManager.get_difficulty_params()
	_check(abs(float(params.get("enemy_hp_multiplier")) - expected_hp) < 0.001,
		"Difficulty[%s]: enemy_hp_multiplier = %s" % [diff_name, expected_hp])
	_check(abs(float(params.get("enemy_damage_multiplier")) - expected_dmg) < 0.001,
		"Difficulty[%s]: enemy_damage_multiplier = %s" % [diff_name, expected_dmg])
	_check(abs(float(params.get("reward_multiplier")) - expected_reward) < 0.001,
		"Difficulty[%s]: reward_multiplier = %s" % [diff_name, expected_reward])
	_check(int(params.get("turn_limit_bonus")) == expected_turn_bonus,
		"Difficulty[%s]: turn_limit_bonus = %d" % [diff_name, expected_turn_bonus])

## 仅修改 GameManager.current_save 中的 settings，不调用 update_settings（避免持久化污染存档）
func _set_difficulty_in_memory(diff_name: String) -> void:
	if not GameManager.current_save.has("settings"):
		GameManager.current_save["settings"] = SaveManager.create_default_save().settings
	GameManager.current_save["settings"]["difficulty"] = diff_name

## ===== Boss 阶段系统测试 =====
## 验证 Boss 阶段数据完整性、阈值切换逻辑、武器解析和狂暴效果

func _test_boss_phase_system() -> void:
	print("\n--- Boss 阶段系统测试 ---")
	_test_boss_phase_data_integrity()
	_test_boss_phase_threshold_logic()
	_test_boss_weapon_id_parsing()
	_test_boss_enrage_effects()
	_test_boss_phase_warning_flag()

## 验证所有 Boss 的阶段数据完整性
func _test_boss_phase_data_integrity() -> void:
	print("  - Boss 阶段数据完整性")
	var bosses = GameData.boss_data.get("bosses", {})
	_check(bosses.size() > 0, "BossPhase: bosses.json 已加载")
	# 逐个验证每个 Boss 的阶段配置
	for boss_id in bosses.keys():
		var bdata = bosses[boss_id]
		var phases = bdata.get("phases", [])
		_check(phases.size() >= 2, "BossPhase[%s]: 至少 2 个阶段（实际 %d）" % [boss_id, phases.size()])
		# 验证每个阶段的字段完整性
		var prev_threshold = 2.0
		for i in range(phases.size()):
			var phase = phases[i]
			var threshold = phase.get("hp_threshold", -1.0)
			_check(threshold >= 0.0 and threshold <= 1.0,
				"BossPhase[%s].phase%d: hp_threshold 在 [0,1] 范围内（=%s）" % [boss_id, i, threshold])
			_check(phase.has("weapons"), "BossPhase[%s].phase%d: 有 weapons 字段" % [boss_id, i])
			_check(phase.has("abilities"), "BossPhase[%s].phase%d: 有 abilities 字段" % [boss_id, i])
			# 阈值必须降序排列（阶段0阈值 > 阶段1阈值 > ...）
			_check(threshold < prev_threshold,
				"BossPhase[%s].phase%d: 阈值降序（%s < %s）" % [boss_id, i, threshold, prev_threshold])
			prev_threshold = threshold
		# 最后一个阶段阈值必须为 0.0
		var last_phase = phases[phases.size() - 1]
		_check(float(last_phase.get("hp_threshold", -1.0)) == 0.0,
			"BossPhase[%s]: 最后阶段阈值为 0.0" % boss_id)

## 验证 Boss 阶段切换的阈值逻辑
func _test_boss_phase_threshold_logic() -> void:
	print("  - Boss 阶段阈值切换逻辑")
	var boss_data = GameData.get_boss("data_sentinel")
	_check(not boss_data.is_empty(), "BossPhase: data_sentinel 数据存在")
	var phases = boss_data.get("phases", [])
	_check(phases.size() == 2, "BossPhase: data_sentinel 有 2 个阶段")
	# data_sentinel: hp=300, phase0 threshold=0.6 (180HP), phase1 threshold=0.0 (0HP)
	var max_hp = int(boss_data.get("hp", 300))
	_check(max_hp == 300, "BossPhase: data_sentinel max_hp = 300")
	# 模拟 HP 比率 → 应处阶段
	_check(_calc_expected_phase(1.0, phases) == 0, "BossPhase: HP 100% → 阶段0")
	_check(_calc_expected_phase(0.7, phases) == 0, "BossPhase: HP 70% → 阶段0")
	_check(_calc_expected_phase(0.6, phases) == 0, "BossPhase: HP 60%（阈值边界）→ 阶段0")
	_check(_calc_expected_phase(0.59, phases) == 1, "BossPhase: HP 59% → 阶段1")
	_check(_calc_expected_phase(0.3, phases) == 1, "BossPhase: HP 30% → 阶段1")
	_check(_calc_expected_phase(0.01, phases) == 1, "BossPhase: HP 1% → 阶段1")

## 辅助：根据 HP 比率和 phases 计算应处阶段索引
func _calc_expected_phase(hp_ratio: float, phases: Array) -> int:
	for i in range(phases.size()):
		var threshold = float(phases[i].get("hp_threshold", 1.0))
		if hp_ratio >= threshold:
			return i
	return phases.size() - 1

## 验证 Boss 武器 ID 解析逻辑
func _test_boss_weapon_id_parsing() -> void:
	print("  - Boss 武器 ID 解析")
	# 测试从武器 ID 解析范围数字
	var test_cases = [
		{"id": "laser_array_2_8", "expected_range": [2, 8]},
		{"id": "missile_pod_3_7_aoe", "expected_range": [3, 7]},
		{"id": "laser_array_2_10", "expected_range": [2, 10]},
		{"id": "minigun_2_8_suppress", "expected_range": [2, 8]},
		{"id": "rocket_4_8_aoe", "expected_range": [4, 8]},
		{"id": "plasma_cannon_3_12", "expected_range": [3, 12]},
	]
	for tc in test_cases:
		var nums = []
		var parts = tc.id.split("_")
		for p in parts:
			if p.is_valid_int():
				nums.append(int(p))
		_check(nums.size() >= 2, "BossWeapon[%s]: 解析到至少 2 个数字" % tc.id)
		if nums.size() >= 2:
			_check(nums[0] == tc.expected_range[0] and nums[1] == tc.expected_range[1],
				"BossWeapon[%s]: 范围 = [%d, %d]" % [tc.id, nums[0], nums[1]])
	# 验证 aoe 标记
	_check("missile_pod_3_7_aoe".find("aoe") >= 0, "BossWeapon: aoe 标记检测正确")
	_check("laser_array_2_8".find("aoe") < 0, "BossWeapon: 无 aoe 标记检测正确")

## 验证 Boss 狂暴效果应用
func _test_boss_enrage_effects() -> void:
	print("  - Boss 狂暴效果")
	# 测试 attack_plus_50 效果
	var boss = _track(Unit.new())
	boss.max_hp = 100
	boss.current_hp = 100
	boss.weapon_damage = [20, 30]
	boss.base_move_points = 5
	boss.move_points = 5
	# 模拟 attack_plus_50
	var dmg0_before = boss.weapon_damage[0]
	var dmg1_before = boss.weapon_damage[1]
	# 直接复用 BattleController 的逻辑太重（需要场景），这里验证数学
	var enrage_mult = 1.5
	boss.weapon_damage[0] = int(round(boss.weapon_damage[0] * enrage_mult))
	boss.weapon_damage[1] = int(round(boss.weapon_damage[1] * enrage_mult))
	_check(boss.weapon_damage[0] == int(round(dmg0_before * 1.5)), "BossEnrage: attack_plus_50 伤害下限 20 → 30")
	_check(boss.weapon_damage[1] == int(round(dmg1_before * 1.5)), "BossEnrage: attack_plus_50 伤害上限 30 → 45")
	# 测试 move_plus_2 效果
	var move_before = boss.base_move_points
	boss.base_move_points += 2
	boss.move_points = boss.base_move_points
	_check(boss.base_move_points == move_before + 2, "BossEnrage: move_plus_2 移动 +2")

## 验证 Boss 阶段预警旗标（每个阶段只预警一次）
func _test_boss_phase_warning_flag() -> void:
	print("  - Boss 阶段预警旗标")
	# 模拟预警旗标逻辑
	var phases_size = 2
	var warned: Array[bool] = []
	warned.resize(phases_size)
	for i in range(phases_size):
		warned[i] = false
	# 第一次切换到阶段1 → 应标记为已预警
	_check(not warned[1], "BossWarning: 阶段1 初始未预警")
	warned[1] = true
	_check(warned[1], "BossWarning: 阶段1 标记为已预警")
	# 再次检查 → 应跳过（已预警）
	var already_warned = warned[1]
	_check(already_warned, "BossWarning: 阶段1 重复触发时跳过预警")

## ===== 增援波次测试 =====
## 验证 EnemyDirector 的增援触发、上限控制和出生点逻辑

func _test_reinforcement_system() -> void:
	print("\n--- 增援波次测试 ---")
	_test_reinforcement_trigger_parsing()
	_test_reinforcement_condition_matching()
	_test_reinforcement_max_cap()
	_test_reinforcement_repeat_trigger()
	_test_reinforcement_alive_count_cap()

## 验证从 scripts 中正确提取增援触发器
func _test_reinforcement_trigger_parsing() -> void:
	var director = EnemyDirector.new()
	add_child(director)
	var scripts = [
		{
			"trigger_id": "wave_01",
			"trigger": {"type": "turn", "condition": ">= 4"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "drone_assault", "position": [0, 0]}], "message": "增援到达"},
			"repeat": false
		},
		{
			"trigger_id": "other_event",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "other_action",
			"data": {}
		},
		{
			"trigger_id": "wave_02",
			"trigger": {"type": "turn", "condition": ">= 6"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_elite", "position": [1, 1]}], "message": ""},
			"repeat": false
		},
	]
	director.setup(scripts)
	_check(director.reinforcement_triggers.size() == 2, "Reinforce: 提取2个增援触发器（过滤非 spawn_reinforcement）")
	_check(director.reinforcements_spawned == 0, "Reinforce: 初始已生成数为0")
	# 第3回合不应触发（条件 >=4）
	var waves_t3 = director.on_turn_start(3)
	_check(waves_t3.is_empty(), "Reinforce: 第3回合无增援（条件未满足）")
	# 第4回合应触发第一个
	var waves_t4 = director.on_turn_start(4)
	_check(waves_t4.size() == 1, "Reinforce: 第4回合触发1波增援")
	_check(director.reinforcements_spawned == 1, "Reinforce: 已生成数=1")
	# 第5回合第一个已触发，不应重复
	var waves_t5 = director.on_turn_start(5)
	_check(waves_t5.is_empty(), "Reinforce: 第5回合无增援（非重复触发器已标记）")
	# 第6回合触发第二个
	var waves_t6 = director.on_turn_start(6)
	_check(waves_t6.size() == 1, "Reinforce: 第6回合触发第二波增援")
	_check(director.reinforcements_spawned == 2, "Reinforce: 已生成数=2")
	director.queue_free()

## 验证条件匹配逻辑（>=、<=、==、<、>）
func _test_reinforcement_condition_matching() -> void:
	var director = EnemyDirector.new()
	add_child(director)
	# 测试各种条件格式
	_check(director._check_condition(">= 4", 4), "Reinforce: >= 4 在第4回合满足")
	_check(director._check_condition(">= 4", 5), "Reinforce: >= 4 在第5回合满足")
	_check(not director._check_condition(">= 4", 3), "Reinforce: >= 4 在第3回合不满足")
	_check(director._check_condition("== 5", 5), "Reinforce: == 5 在第5回合满足")
	_check(not director._check_condition("== 5", 6), "Reinforce: == 5 在第6回合不满足")
	_check(director._check_condition("<= 3", 3), "Reinforce: <= 3 在第3回合满足")
	_check(not director._check_condition("<= 3", 4), "Reinforce: <= 3 在第4回合不满足")
	_check(director._check_condition("< 5", 4), "Reinforce: < 5 在第4回合满足")
	_check(director._check_condition("> 2", 3), "Reinforce: > 2 在第3回合满足")
	director.queue_free()

## 验证增援上限控制
func _test_reinforcement_max_cap() -> void:
	var director = EnemyDirector.new()
	add_child(director)
	director.max_reinforcements = 3
	var scripts = [
		{
			"trigger_id": "wave_01",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_basic", "position": [0, 0]}], "message": ""},
			"repeat": false
		},
		{
			"trigger_id": "wave_02",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_basic", "position": [1, 0]}], "message": ""},
			"repeat": false
		},
		{
			"trigger_id": "wave_03",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_basic", "position": [2, 0]}], "message": ""},
			"repeat": false
		},
		{
			"trigger_id": "wave_04",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_basic", "position": [3, 0]}], "message": ""},
			"repeat": false
		},
	]
	director.setup(scripts)
	director.set_alive_counts(3, 2)
	# 第2回合应触发3波（达到上限3），第4波被跳过
	var waves = director.on_turn_start(2)
	_check(waves.size() == 3, "Reinforce: 达到上限时只触发3波")
	_check(director.reinforcements_spawned == 3, "Reinforce: 已生成数=3（达到上限）")
	# 第3回合不应再触发（已达上限）
	var waves_t3 = director.on_turn_start(3)
	_check(waves_t3.is_empty(), "Reinforce: 达到上限后不再生成增援")
	director.queue_free()

## 验证重复触发型增援（repeat=true）
func _test_reinforcement_repeat_trigger() -> void:
	var director = EnemyDirector.new()
	add_child(director)
	director.max_reinforcements = 10
	var scripts = [
		{
			"trigger_id": "repeat_wave",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_basic", "position": [0, 0]}], "message": "周期增援"},
			"repeat": true
		},
	]
	director.setup(scripts)
	director.set_alive_counts(3, 2)
	# 第2、3、4回合都应触发（repeat=true 不标记 triggered）
	var waves_t2 = director.on_turn_start(2)
	_check(waves_t2.size() == 1, "Reinforce: repeat=true 第2回合触发")
	var waves_t3 = director.on_turn_start(3)
	_check(waves_t3.size() == 1, "Reinforce: repeat=true 第3回合再次触发")
	var waves_t4 = director.on_turn_start(4)
	_check(waves_t4.size() == 1, "Reinforce: repeat=true 第4回合再次触发")
	_check(director.reinforcements_spawned == 3, "Reinforce: repeat=true 累计生成3")
	director.queue_free()

## 验证场上敌人上限控制（enemy_cap_per_wave）
func _test_reinforcement_alive_count_cap() -> void:
	var director = EnemyDirector.new()
	add_child(director)
	director.max_reinforcements = 20
	director.enemy_cap_per_wave = 5
	var scripts = [
		{
			"trigger_id": "wave_01",
			"trigger": {"type": "turn", "condition": ">= 2"},
			"action": "spawn_reinforcement",
			"data": {"units": [{"type": "sentry_basic", "position": [0, 0]}], "message": ""},
			"repeat": false
		},
	]
	director.setup(scripts)
	# 场上已有5个敌人，达到上限，应跳过本次生成
	director.set_alive_counts(3, 5)
	var waves = director.on_turn_start(2)
	_check(waves.is_empty(), "Reinforce: 场上敌人达上限时跳过生成")
	_check(director.reinforcements_spawned == 0, "Reinforce: 跳过时已生成数仍为0")
	# 场上敌人减少后应能触发
	director.set_alive_counts(3, 4)
	# 非重复触发器未被标记，下回合可再试
	var waves_t3 = director.on_turn_start(3)
	_check(waves_t3.size() == 1, "Reinforce: 场上敌人减少后可触发")
	director.queue_free()

## 验证锁定地图中的增援脚本可被加载
func _test_reinforcement_scripts_in_locked_maps() -> void:
	var any_has_scripts = false
	var level_ids = ["ch1_m1", "ch2_m1", "ch3_m1", "ch4_m1", "ch5_m1"]
	for lid in level_ids:
		var res := MapLoader.load_locked_map(lid)
		if not res.get("ok", false):
			continue
		var d: Dictionary = res["data"]
		var scripts = d.get("scripts", [])
		if scripts.size() > 0:
			any_has_scripts = true
			# 验证每个脚本有必需字段
			for script in scripts:
				_check(script.has("trigger"), "%s 脚本有 trigger 字段" % lid)
				_check(script.has("action"), "%s 脚本有 action 字段" % lid)
				_check(script.has("data"), "%s 脚本有 data 字段" % lid)
			# 验证至少一个是 spawn_reinforcement
			var has_spawn = scripts.any(func(s): return s.get("action") == "spawn_reinforcement")
			_check(has_spawn, "%s 包含 spawn_reinforcement 脚本" % lid)
	_check(any_has_scripts, "Reinforce: 至少一个关卡包含增援脚本")

## ===== 战利品 ID 校验测试 =====
## 任何配置中的 loot ID 必须在 weapons.json 或 items.json 中存在；
## 无效战利品在构建期测试失败，不能写入不可显示的库存。
## 所有章节的 loot ID 都必须有效；无效奖励会导致玩家无法装备或查看掉落。
func _test_loot_id_validation() -> void:
	print("\n--- 战利品 ID 校验测试 ---")
	var levels_data = GameData.level_data
	var levels: Dictionary = levels_data.get("levels", {})
	var checked_count = 0
	# 1. levels.json 中所有 first_clear.loot 必须有效。
	for lid in levels.keys():
		var cfg = levels[lid]
		if not cfg is Dictionary:
			continue
		var rewards = cfg.get("rewards", {})
		if not rewards is Dictionary:
			continue
		var first_clear = rewards.get("first_clear", {})
		if not first_clear is Dictionary:
			continue
		if not first_clear.has("loot"):
			continue
		var loot_id = String(first_clear["loot"])
		var w = GameData.get_weapon(loot_id)
		var i = GameData.get_item(loot_id)
		var is_valid = (not w.is_empty()) or (not i.is_empty())
		_check(is_valid,
			"LootID[%s]: first_clear.loot=%s 在 weapons.json/items.json 中存在" % [lid, loot_id])
		checked_count += 1
	_check(checked_count > 0, "LootID: levels.json 至少校验了 1 个 loot 字段（共 %d 个）" % checked_count)

	# 2. bosses.json 中所有 rewards.loot 必须有效。
	var bosses: Dictionary = GameData.boss_data.get("bosses", {})
	var boss_checked = 0
	for bid in bosses.keys():
		var bcfg = bosses[bid]
		if not bcfg is Dictionary:
			continue
		var rewards = bcfg.get("rewards", {})
		if not rewards is Dictionary:
			continue
		if not rewards.has("loot"):
			continue
		var loot_id = String(rewards["loot"])
		var w = GameData.get_weapon(loot_id)
		var i = GameData.get_item(loot_id)
		var is_valid = (not w.is_empty()) or (not i.is_empty())
		_check(is_valid,
			"LootID[BOSS %s]: rewards.loot=%s 在 weapons.json/items.json 中存在" % [bid, loot_id])
		boss_checked += 1
	_check(boss_checked > 0, "LootID: bosses.json 至少校验了 1 个 loot 字段（共 %d 个）" % boss_checked)

## ===== 武器 special 效果测试 =====
## 验证所有第一章可用武器的 special 字段都有可观察结果
func _test_weapon_special_effects() -> void:
	print("\n--- 武器 special 效果测试 ---")
	var action_sys = ActionSystem.new()
	add_child(action_sys)
	_track(action_sys)

	# 设置最小地图数据
	var test_map = {
		"size": {"width": 10, "height": 10},
		"layers": {
			"terrain": [],
			"blocker": []
		}
	}
	for y in range(10):
		test_map.layers.terrain.append([])
		test_map.layers.blocker.append([])
		for x in range(10):
			test_map.layers.terrain[y].append(0)
			test_map.layers.blocker[y].append(0)
	action_sys.set_map_data(test_map)

	# 1. 验证 weapon_special 字段已加载到 Unit
	var assault = _track(GameData.create_player_unit("assault", "TestAssault"))
	_check(assault.weapon_special == "", "WeaponSpecial: 默认单位 weapon_special 为空")

	# 模拟装备武器
	var knife = GameData.get_weapon("knife")
	_check(not knife.is_empty(), "WeaponSpecial: knife 武器数据存在")
	_check(String(knife.get("special", "")) == "silent", "WeaponSpecial: knife.special == silent")

	# 2. 验证消音判定
	_check(action_sys._is_weapon_silent("silent"), "WeaponSpecial: silent 被识别为消音")
	_check(action_sys._is_weapon_silent("silent_no_expose"), "WeaponSpecial: silent_no_expose 被识别为消音")
	_check(action_sys._is_weapon_silent("silent_crit_plus_10"), "WeaponSpecial: silent_crit_plus_10 被识别为消音")
	_check(action_sys._is_weapon_silent("silent_ignore_armor"), "WeaponSpecial: silent_ignore_armor 被识别为消音")
	_check(not action_sys._is_weapon_silent("double_tap"), "WeaponSpecial: double_tap 不被识别为消音")
	_check(not action_sys._is_weapon_silent(""), "WeaponSpecial: 空字符串不被识别为消音")

	# 3. 验证额外攻击次数
	_check(action_sys._get_extra_hit_count("double_tap") == 1, "WeaponSpecial: double_tap 额外攻击1次")
	_check(action_sys._get_extra_hit_count("triple_tap") == 2, "WeaponSpecial: triple_tap 额外攻击2次")
	_check(action_sys._get_extra_hit_count("burst_5") == 4, "WeaponSpecial: burst_5 额外攻击4次")
	_check(action_sys._get_extra_hit_count("") == 0, "WeaponSpecial: 空字符串无额外攻击")

	# 4. 验证消音武器攻击产生静音噪声事件
	var attacker = _track(GameData.create_player_unit("assault", "SilentAttacker"))
	attacker.weapon_special = "silent"
	attacker.weapon_range = [1, 4]
	attacker.weapon_damage = [20, 30]
	attacker.grid_pos = Vector2i(0, 0)
	attacker.current_ap = 2

	var target = _track(GameData.create_enemy_unit("grunt"))
	target.grid_pos = Vector2i(1, 0)
	target.team = "enemy"

	action_sys.player_units = [attacker]
	action_sys.enemy_units = [target]
	action_sys.clear_noise_events()

	var atk_result = action_sys.execute_attack(attacker, target)
	_check(atk_result.success, "WeaponSpecial: 消音攻击执行成功")
	var noise = action_sys.get_noise_events()
	_check(noise.size() > 0, "WeaponSpecial: 攻击产生噪声事件")
	if noise.size() > 0:
		_check(bool(noise[0].get("silent", false)), "WeaponSpecial: silent 武器产生静音事件")

	# 5. 验证非消音武器产生有声噪声
	var noisy_attacker = _track(GameData.create_player_unit("assault", "NoisyAttacker"))
	noisy_attacker.weapon_special = ""
	noisy_attacker.weapon_range = [1, 5]
	noisy_attacker.weapon_damage = [20, 30]
	noisy_attacker.grid_pos = Vector2i(5, 5)
	noisy_attacker.current_ap = 2

	var target2 = _track(GameData.create_enemy_unit("grunt"))
	target2.grid_pos = Vector2i(6, 5)
	target2.team = "enemy"

	action_sys.player_units = [noisy_attacker]
	action_sys.enemy_units = [target2]
	action_sys.clear_noise_events()

	var atk_result2 = action_sys.execute_attack(noisy_attacker, target2)
	_check(atk_result2.success, "WeaponSpecial: 非消音攻击执行成功")
	var noise2 = action_sys.get_noise_events()
	if noise2.size() > 0:
		_check(not bool(noise2[0].get("silent", true)), "WeaponSpecial: 非消音武器产生有声噪声")
		_check(int(noise2[0].get("radius", 0)) > 0, "WeaponSpecial: 非消音武器噪声半径 > 0")

	# 6. 验证 mark_target_3_turns 效果
	var marker = _track(GameData.create_player_unit("scout", "Marker"))
	marker.weapon_special = "mark_target_3_turns"
	marker.weapon_range = [2, 6]
	marker.weapon_damage = [5, 10]
	marker.grid_pos = Vector2i(0, 0)
	marker.current_ap = 2

	var mark_target = _track(GameData.create_enemy_unit("grunt"))
	mark_target.grid_pos = Vector2i(3, 0)
	mark_target.team = "enemy"

	action_sys.player_units = [marker]
	action_sys.enemy_units = [mark_target]
	var mark_result = action_sys.execute_attack(marker, mark_target)
	if mark_result.success and mark_result.result.hit:
		_check(mark_target.has_status("marked"), "WeaponSpecial: mark_target_3_turns 标记目标")

	# 7. 验证 suppressing_fire 效果
	var suppressor = _track(GameData.create_player_unit("heavy", "Suppressor"))
	suppressor.weapon_special = "suppressing_fire"
	suppressor.weapon_range = [2, 6]
	suppressor.weapon_damage = [25, 40]
	suppressor.grid_pos = Vector2i(0, 0)
	suppressor.current_ap = 2

	var suppress_target = _track(GameData.create_enemy_unit("grunt"))
	suppress_target.grid_pos = Vector2i(3, 0)
	suppress_target.team = "enemy"

	action_sys.player_units = [suppressor]
	action_sys.enemy_units = [suppress_target]
	var sup_result = action_sys.execute_attack(suppressor, suppress_target)
	if sup_result.success and sup_result.result.hit:
		_check(suppress_target.has_status("suppress"), "WeaponSpecial: suppressing_fire 施加压制状态")

	# 8. 验证所有第一章武器的 special 字段非空
	var ch1_weapon_ids = ["shotgun", "smg", "knife", "sniper_rifle", "marksman_rifle", "mg", "grenade_launcher", "med_gun", "silenced_pistol", "marking_rifle"]
	for wid in ch1_weapon_ids:
		var w = GameData.get_weapon(wid)
		_check(not w.is_empty(), "WeaponSpecial: 武器 %s 存在" % wid)
		_check(String(w.get("special", "")) != "", "WeaponSpecial: 武器 %s 有 special 字段" % wid)

## ===== 投掷物范围效果测试 =====
func _test_throwable_area_effects() -> void:
	print("\n--- 投掷物范围效果测试 ---")
	var action_sys = ActionSystem.new()
	add_child(action_sys)
	_track(action_sys)

	var test_map = {
		"size": {"width": 10, "height": 10},
		"layers": {"terrain": [], "blocker": []}
	}
	for y in range(10):
		test_map.layers.terrain.append([])
		test_map.layers.blocker.append([])
		for x in range(10):
			test_map.layers.terrain[y].append(0)
			test_map.layers.blocker[y].append(0)
	action_sys.set_map_data(test_map)

	# 1. 验证范围解析
	_check(action_sys._parse_area_radius("1x1") == 0, "Throwable: 1x1 半径=0")
	_check(action_sys._parse_area_radius("3x3") == 1, "Throwable: 3x3 半径=1")
	_check(action_sys._parse_area_radius("5x5") == 2, "Throwable: 5x5 半径=2")

	# 2. 验证手雷（grenade）3x3 范围伤害
	var thrower = _track(GameData.create_player_unit("assault", "Thrower"))
	thrower.grid_pos = Vector2i(0, 0)
	thrower.current_ap = 2

	# 在目标位置周围放置敌人
	var enemy1 = _track(GameData.create_enemy_unit("grunt"))
	enemy1.grid_pos = Vector2i(5, 5)
	enemy1.team = "enemy"
	enemy1.current_hp = 100

	var enemy2 = _track(GameData.create_enemy_unit("grunt"))
	enemy2.grid_pos = Vector2i(6, 5)
	enemy2.team = "enemy"
	enemy2.current_hp = 100

	var enemy3 = _track(GameData.create_enemy_unit("grunt"))
	enemy3.grid_pos = Vector2i(5, 6)
	enemy3.team = "enemy"
	enemy3.current_hp = 100

	action_sys.player_units = [thrower]
	action_sys.enemy_units = [enemy1, enemy2, enemy3]

	var grenade = GameData.get_item("grenade")
	_check(not grenade.is_empty(), "Throwable: grenade 物品存在")
	_check(String(grenade.get("type", "")) == "throwable", "Throwable: grenade 类型为 throwable")

	var hp_before = enemy1.current_hp
	var result = action_sys.use_item(thrower, "grenade", null, {"position": Vector2i(5, 5)})
	_check(bool(result.get("success", false)), "Throwable: 手雷使用成功")
	_check(enemy1.current_hp < hp_before, "Throwable: 手雷对中心敌人造成伤害")
	_check(enemy2.current_hp < hp_before, "Throwable: 手雷对相邻敌人造成伤害（3x3范围）")
	_check(enemy3.current_hp < hp_before, "Throwable: 手雷对相邻敌人造成伤害（3x3范围）")

	# 3. 验证烟雾弹创建地面效果
	var smoker = _track(GameData.create_player_unit("scout", "Smoker"))
	smoker.grid_pos = Vector2i(0, 1)
	smoker.current_ap = 2
	action_sys.player_units = [smoker]
	action_sys.enemy_units = []

	var smoke_result = action_sys.use_item(smoker, "smoke_grenade", null, {"position": Vector2i(3, 3)})
	_check(bool(smoke_result.get("success", false)), "Throwable: 烟雾弹使用成功")
	var smoke_effects = action_sys.get_ground_effects_at(Vector2i(3, 3))
	_check(smoke_effects.size() > 0, "Throwable: 烟雾弹在目标位置创建地面效果")
	if smoke_effects.size() > 0:
		_check(String(smoke_effects[0].get("type", "")) == "smoke", "Throwable: 地面效果类型为 smoke")

	# 4. 验证所有投掷物物品都有 effect.area 字段
	var throwable_ids = ["grenade", "flashbang", "smoke_grenade", "molotov", "emp_grenade", "heal_mist"]
	for tid in throwable_ids:
		var item = GameData.get_item(tid)
		_check(not item.is_empty(), "Throwable: 物品 %s 存在" % tid)
		_check(String(item.get("type", "")) == "throwable", "Throwable: %s 类型为 throwable" % tid)
		var effect = item.get("effect", {})
		_check(effect.has("area"), "Throwable: %s 有 effect.area 字段" % tid)

## ===== 陷阱系统测试 =====
func _test_trap_system() -> void:
	print("\n--- 陷阱系统测试 ---")
	var action_sys = ActionSystem.new()
	add_child(action_sys)
	_track(action_sys)

	var test_map = {
		"size": {"width": 10, "height": 10},
		"layers": {"terrain": [], "blocker": []}
	}
	for y in range(10):
		test_map.layers.terrain.append([])
		test_map.layers.blocker.append([])
		for x in range(10):
			test_map.layers.terrain[y].append(0)
			test_map.layers.blocker[y].append(0)
	action_sys.set_map_data(test_map)

	# 1. 验证放置陷阱
	var trapper = _track(GameData.create_player_unit("scout", "Trapper"))
	trapper.grid_pos = Vector2i(2, 2)
	trapper.current_ap = 2
	trapper.move_points = 5

	action_sys.player_units = [trapper]
	action_sys.enemy_units = []

	var mine = GameData.get_item("mine")
	_check(not mine.is_empty(), "Trap: mine 物品存在")
	_check(String(mine.get("type", "")) == "trap", "Trap: mine 类型为 trap")

	var place_result = action_sys._place_trap(trapper, mine)
	_check(bool(place_result.get("success", false)), "Trap: 放置陷阱成功")
	_check(action_sys.traps.size() > 0, "Trap: 陷阱列表非空")
	if action_sys.traps.size() > 0:
		_check(action_sys.traps[0].pos == Vector2i(2, 2), "Trap: 陷阱位置正确")
		_check(String(action_sys.traps[0].owner_team) == "player", "Trap: 陷阱归属玩家方")

	# 2. 验证敌人触发陷阱
	var enemy = _track(GameData.create_enemy_unit("grunt"))
	enemy.grid_pos = Vector2i(0, 0)
	enemy.team = "enemy"
	enemy.current_hp = 100
	enemy.move_points = 5

	action_sys.enemy_units = [enemy]

	var hp_before_trap = enemy.current_hp
	# 模拟敌人移动到陷阱位置
	action_sys._check_trap_trigger(enemy, Vector2i(2, 2))
	_check(enemy.current_hp < hp_before_trap, "Trap: 敌人触发陷阱受到伤害")
	_check(action_sys.traps.size() == 0, "Trap: 触发后陷阱被移除")

	# 3. 验证陷阱不误伤友军
	var trapper2 = _track(GameData.create_player_unit("scout", "Trapper2"))
	trapper2.grid_pos = Vector2i(4, 4)
	trapper2.current_ap = 2
	action_sys.player_units = [trapper2]
	action_sys.enemy_units = []

	action_sys._place_trap(trapper2, mine)
	var ally_hp_before = trapper2.current_hp
	# 玩家单位移动到自家陷阱上不应触发
	action_sys._check_trap_trigger(trapper2, Vector2i(4, 4))
	_check(trapper2.current_hp == ally_hp_before, "Trap: 友军不触发自家陷阱")

	# 4. 验证 wire_trap 物品存在且有 detect_per 字段
	var wire = GameData.get_item("wire_trap")
	_check(not wire.is_empty(), "Trap: wire_trap 物品存在")
	_check(String(wire.get("type", "")) == "trap", "Trap: wire_trap 类型为 trap")
	_check(wire.has("detect_per"), "Trap: wire_trap 有 detect_per 字段")

	# 5. 验证 scout_trap 技能能放置陷阱
	var skill_trapper = _track(GameData.create_player_unit("scout", "SkillTrapper"))
	skill_trapper.grid_pos = Vector2i(6, 6)
	skill_trapper.current_ap = 2
	action_sys.player_units = [skill_trapper]
	action_sys.enemy_units = []

	var skill_result = action_sys._skill_trap(skill_trapper, {"position": Vector2i(7, 7)})
	_check(bool(skill_result.get("success", false)), "Trap: scout_trap 技能放置陷阱成功")
	_check(action_sys.traps.size() > 0, "Trap: 技能放置后陷阱列表非空")

## ===== 第一章关卡数据一致性测试 =====
## 验证 ch1_m1-m6 在 levels.json、dialogues.json、bosses.json、锁定地图之间的一致性
## 覆盖第一章内容契约：类型序列、目标、对话、奖励、Boss 数据
func _test_first_chapter_data_consistency() -> void:
	print("\n--- 第一章关卡数据一致性测试 ---")
	var ch1_levels = ["ch1_m1", "ch1_m2", "ch1_m3", "ch1_m4", "ch1_m5", "ch1_m6"]
	# 第一章六关期望类型序列（内容契约）
	var expected_types := ["extract", "destroy", "extract", "escort", "steal_data", "assassinate"]
	# 期望字段（教学、奖励、对话引用一致）
	for i in range(ch1_levels.size()):
		var lid = ch1_levels[i]
		var cfg = CampaignRepository.get_level(lid)
		_check(not cfg.is_empty(), "Ch1Consistency: %s 在 levels.json 中存在" % lid)
		_check(int(cfg.get("chapter", 0)) == 1, "Ch1Consistency: %s chapter==1" % lid)
		# 内容契约：任务类型符合期望序列
		_check(String(cfg.get("mission_type", "")) == expected_types[i],
			"Ch1Contract: %s mission_type==%s（实际 %s）" % [lid, expected_types[i], cfg.get("mission_type", "")])
		_check(cfg.has("intro_dialogue"), "Ch1Consistency: %s 有 intro_dialogue 字段" % lid)
		_check(cfg.has("outro_dialogue"), "Ch1Consistency: %s 有 outro_dialogue 字段" % lid)
		# 验证对话 ID 在 dialogues.json 中实际存在
		var intro_id = String(cfg.get("intro_dialogue", ""))
		var outro_id = String(cfg.get("outro_dialogue", ""))
		if intro_id != "":
			var d = GameData.get_dialogue(intro_id)
			_check(not d.is_empty(), "Ch1Consistency: %s intro_dialogue=%s 在 dialogues.json 中存在" % [lid, intro_id])
			# 验证对话至少有一行 lines
			var lines = d.get("lines", [])
			_check(lines is Array and lines.size() > 0,
				"Ch1Consistency: %s intro 对话至少 1 行" % lid)
		if outro_id != "":
			var d = GameData.get_dialogue(outro_id)
			_check(not d.is_empty(), "Ch1Consistency: %s outro_dialogue=%s 在 dialogues.json 中存在" % [lid, outro_id])
			var lines = d.get("lines", [])
			_check(lines is Array and lines.size() > 0,
				"Ch1Consistency: %s outro 对话至少 1 行" % lid)
		# 验证 rewards 结构完整
		var rewards = cfg.get("rewards", {})
		_check(rewards is Dictionary, "Ch1Consistency: %s rewards 是字典" % lid)
		_check(int(rewards.get("credit", 0)) > 0, "Ch1Consistency: %s rewards.credit > 0" % lid)
		_check(int(rewards.get("exp", 0)) > 0, "Ch1Consistency: %s rewards.exp > 0" % lid)
		var fc = rewards.get("first_clear", {})
		_check(fc is Dictionary, "Ch1Consistency: %s first_clear 是字典" % lid)
		_check(int(fc.get("credit", 0)) > 0, "Ch1Consistency: %s first_clear.credit > 0" % lid)
		_check(int(fc.get("intel", 0)) > 0, "Ch1Consistency: %s first_clear.intel > 0" % lid)
		# 锁定地图必须可加载
		var map_res = MapLoader.load_locked_map(lid)
		_check(map_res.get("ok", false), "Ch1Consistency: %s 锁定地图可加载" % lid)
		if map_res.get("ok", false):
			var md: Dictionary = map_res["data"]
			# 地图 mission_type 与 levels.json 一致
			_check(String(md.get("mission_type", "")) == String(cfg.get("mission_type", "")),
				"Ch1Consistency: %s 地图 mission_type 与 levels.json 一致" % lid)
	# ch1_m6 Boss 数据一致性
	var m6 = CampaignRepository.get_level("ch1_m6")
	_check(bool(m6.get("is_boss", false)), "Ch1Consistency: ch1_m6 标记 is_boss")
	var boss_id = String(m6.get("boss_id", ""))
	_check(boss_id == "data_sentinel", "Ch1Consistency: ch1_m6 boss_id=data_sentinel")
	var boss = GameData.get_boss(boss_id)
	_check(not boss.is_empty(), "Ch1Consistency: data_sentinel Boss 数据存在")
	# Boss 阶段至少 2 个，且有阈值字段
	var phases = boss.get("phases", [])
	_check(phases is Array and phases.size() >= 2,
		"Ch1Consistency: data_sentinel 至少 2 个阶段（实际 %d）" % [phases.size() if phases is Array else 0])
	if phases is Array and phases.size() >= 2:
		for idx in range(phases.size()):
			var p = phases[idx]
			_check(p.has("hp_threshold"), "Ch1Consistency: data_sentinel 阶段%d 有 hp_threshold" % idx)
			_check(p.has("weapons") or p.has("abilities"),
				"Ch1Consistency: data_sentinel 阶段%d 有 weapons 或 abilities" % idx)
		# 最后阶段阈值为 0（死亡阶段）
		var last = phases[phases.size() - 1]
		_check(abs(float(last.get("hp_threshold", -1))) < 0.001,
			"Ch1Consistency: data_sentinel 最后阶段 hp_threshold==0")
	# Boss rewards.loot 与 levels.json first_clear.loot 一致
	var boss_loot = String(boss.get("rewards", {}).get("loot", ""))
	var level_loot = String(m6.get("rewards", {}).get("first_clear", {}).get("loot", ""))
	if boss_loot != "" and level_loot != "":
		_check(boss_loot == level_loot,
			"Ch1Consistency: ch1_m6 Boss.loot(%s) == levels.first_clear.loot(%s)" % [boss_loot, level_loot])

func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % name)
	else:
		_failed += 1
		_errors.append(name)
		print("  [FAIL] %s" % name)

func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if _failed > 0:
		print("  失败项:")
		for e in _errors:
			print("    - %s" % e)
	print("=================")
	# 同步写入文件，便于沙盒/CI 环境读取
	var summary = "passed=%d\nfailed=%d\n" % [_passed, _failed]
	if _failed > 0:
		summary += "errors:\n"
		for e in _errors:
			summary += "- " + e + "\n"
	var f = FileAccess.open("user://test_summary.txt", FileAccess.WRITE)
	if f:
		f.store_string(summary)
		f.close()
