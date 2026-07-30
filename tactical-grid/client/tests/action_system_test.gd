extends Node

const BattleScene = preload("res://scenes/battle.tscn")

var _passed := 0
var _failed := 0
var _battle: Node = null

func _ready() -> void:
	print("=== CODE-P1-01: 动作系统契约测试 ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame
	GameManager.begin_new_game_for_test(0)
	GameManager.current_level_id = "ch1_m1"
	await _test_move_query_validate_commit()
	await _test_stale_preview_rejected()
	await _test_invalid_target_rejected()
	await _test_network_takeover_query_validate_commit()
	await _test_network_damaged_node_rejected()
	await _test_network_insufficient_ap_rejected()
	await _test_g_toggle_only_visualization()
	await get_tree().process_frame
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	print("")
	print("通过: %d" % _passed)
	print("失败: %d" % _failed)
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _test_move_query_validate_commit() -> void:
	print("\n--- 测试: 移动查询→验证→提交 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	var unit: Unit = _battle.player_units[0]
	var original_move := unit.move_points
	# 查询移动范围
	var query: Dictionary = _battle.action_system.query_action({"action": &"move", "unit": unit})
	_check(bool(query.get("valid", false)), "移动查询有效")
	var reachable: Dictionary = query.get("reachable", {})
	_check(not reachable.is_empty(), "返回可达范围")
	# 选择一个可达目标（跳过起点，避免原地移动导致 find_path 返回空）
	var target_cell: Vector2i = Vector2i(-1, -1)
	for cell in reachable.keys():
		if cell != unit.grid_pos:
			target_cell = cell
			break
	if target_cell.x < 0:
		_check(false, "找到可达目标格")
		_battle.queue_free()
		await get_tree().process_frame
		return
	# 查询特定目标
	var preview: Dictionary = _battle.action_system.query_action({"action": &"move", "unit": unit, "target": target_cell})
	_check(bool(preview.get("valid", false)), "特定目标移动预览有效")
	_check(int(preview.get("cost", {}).get("move", -1)) >= 0, "预览包含移动消耗")
	var preview_id: int = int(preview.get("preview_id", 0))
	_check(preview_id > 0, "预览分配 ID")
	# 验证预览
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(bool(validation.get("valid", false)), "预览验证通过")
	# 提交
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result.get("success", false)), "移动提交成功")
	_check(unit.grid_pos == target_cell, "单位到达目标格")
	_check(unit.move_points == original_move - int(preview.get("cost", {}).get("move", 0)), "移动消耗正确")
	_battle.queue_free()
	await get_tree().process_frame

func _test_stale_preview_rejected() -> void:
	print("\n--- 测试: 过期预览被拒绝 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	var unit: Unit = _battle.player_units[0]
	# 创建预览
	var preview: Dictionary = _battle.action_system.query_action({"action": &"overwatch", "unit": unit})
	_check(bool(preview.get("valid", false)), "警戒预览有效")
	# 手动清除预览（模拟过期）
	_battle.action_system._active_previews.clear()
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(not bool(validation.get("valid", true)), "过期预览被拒绝")
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(not bool(result.get("success", true)), "过期预览提交失败")
	_battle.queue_free()
	await get_tree().process_frame

func _test_invalid_target_rejected() -> void:
	print("\n--- 测试: 无效目标被拒绝 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	var unit: Unit = _battle.player_units[0]
	# 查询攻击一个不存在的目标
	var preview: Dictionary = _battle.action_system.query_action({"action": &"attack", "unit": unit, "target": null})
	_check(not bool(preview.get("valid", true)), "无效目标攻击预览被拒绝")
	# 查询移动到不可达格
	var preview2: Dictionary = _battle.action_system.query_action({"action": &"move", "unit": unit, "target": Vector2i(999, 999)})
	_check(not bool(preview2.get("valid", true)), "不可达格移动预览被拒绝")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-P2-02: 网络操作 takeover 查询→验证→提交
func _test_network_takeover_query_validate_commit() -> void:
	print("\n--- 测试: 网络接管查询→验证→提交 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	# 确保网络状态存在并添加测试节点
	if _battle.tactical_network_state == null:
		_check(false, "战术网络状态已初始化")
		_battle.queue_free()
		await get_tree().process_frame
		return
	_battle.tactical_network_state.setup([
		{"id": "test_camera_1", "type": "camera", "x": 5, "y": 5, "state": "neutral", "reveal_radius": 3},
	])
	var unit: Unit = _battle.player_units[0]
	unit.current_ap = 2
	var original_ap: int = unit.current_ap
	# 查询网络操作
	var preview: Dictionary = _battle.action_system.query_action({
		"action": &"network", "unit": unit,
		"node_id": "test_camera_1", "operation": "takeover",
	})
	_check(bool(preview.get("valid", false)), "网络接管预览有效")
	_check(int(preview.get("cost", {}).get("ap", 0)) == 1, "网络操作消耗 1AP")
	# 验证预览
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(bool(validation.get("valid", false)), "网络操作预览验证通过")
	# 提交
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result.get("success", false)), "网络接管提交成功")
	_check(unit.current_ap == original_ap - 1, "网络操作消耗 1AP")
	_check(_battle.tactical_network_state.get_node_state("test_camera_1") == "player", "节点状态变为 player")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-P2-02: 已损坏节点拒绝操作
func _test_network_damaged_node_rejected() -> void:
	print("\n--- 测试: 已损坏节点拒绝网络操作 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	if _battle.tactical_network_state == null:
		_check(false, "战术网络状态已初始化")
		_battle.queue_free()
		await get_tree().process_frame
		return
	_battle.tactical_network_state.setup([
		{"id": "test_door_1", "type": "door", "x": 3, "y": 3, "state": "damaged"},
	])
	var unit: Unit = _battle.player_units[0]
	unit.current_ap = 2
	var preview: Dictionary = _battle.action_system.query_action({
		"action": &"network", "unit": unit,
		"node_id": "test_door_1", "operation": "takeover",
	})
	_check(not bool(preview.get("valid", true)), "已损坏节点操作被拒绝")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-P2-02: AP 不足时拒绝网络操作
func _test_network_insufficient_ap_rejected() -> void:
	print("\n--- 测试: AP 不足拒绝网络操作 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	if _battle.tactical_network_state == null:
		_check(false, "战术网络状态已初始化")
		_battle.queue_free()
		await get_tree().process_frame
		return
	_battle.tactical_network_state.setup([
		{"id": "test_turret_1", "type": "turret", "x": 7, "y": 7, "state": "enemy"},
	])
	var unit: Unit = _battle.player_units[0]
	unit.current_ap = 0
	var preview: Dictionary = _battle.action_system.query_action({
		"action": &"network", "unit": unit,
		"node_id": "test_turret_1", "operation": "disable",
	})
	_check(not bool(preview.get("valid", true)), "AP 不足时网络操作被拒绝")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-P2-02: G 键仅切换可视化，不改变游戏状态
func _test_g_toggle_only_visualization() -> void:
	print("\n--- 测试: G 键仅切换网络可视化 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	if _battle.tactical_network_state == null:
		_check(false, "战术网络状态已初始化")
		_battle.queue_free()
		await get_tree().process_frame
		return
	_battle.tactical_network_state.setup([
		{"id": "test_cam_1", "type": "camera", "x": 2, "y": 2, "state": "neutral"},
	])
	var overlay_before: bool = _battle.tactical_network_state.overlay_visible
	# Toggle overlay
	_battle.tactical_network_state.toggle_overlay()
	_check(_battle.tactical_network_state.overlay_visible != overlay_before, "G 键切换 overlay 状态")
	# Node state should be unchanged
	_check(_battle.tactical_network_state.get_node_state("test_cam_1") == "neutral", "G 键不改变节点状态")
	# Toggle back
	_battle.tactical_network_state.toggle_overlay()
	_check(_battle.tactical_network_state.overlay_visible == overlay_before, "再次 G 键恢复 overlay 状态")
	_battle.queue_free()
	await get_tree().process_frame
