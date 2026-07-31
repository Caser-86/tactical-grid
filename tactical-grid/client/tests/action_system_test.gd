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
	await _test_attack_query_validate_commit()
	await _test_skill_query_validate_commit()
	await _test_item_query_validate_commit()
	await _test_overwatch_query_validate_commit()
	await _test_stale_preview_rejected()
	await _test_double_commit_rejected()
	await _test_cancel_keeps_resources()
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

## CODE-CH1-010: 攻击的 query→validate→commit 路径
func _test_attack_query_validate_commit() -> void:
	print("\n--- 测试: 攻击查询→验证→提交 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	if _battle.enemy_units.is_empty():
		_check(false, "关卡存在敌方单位")
		_battle.queue_free()
		await get_tree().process_frame
		return
	var attacker: Unit = _battle.player_units[0]
	var target: Unit = _battle.enemy_units[0]
	attacker.current_ap = 2
	var ap_before := attacker.current_ap
	var hp_before := target.current_hp
	# 在攻击者附近找一个有效攻击位置（射程+视线内）
	var preview: Dictionary = {}
	var offsets := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 0), Vector2i(0, 2),
		Vector2i(3, 0), Vector2i(0, 3), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(4, 0), Vector2i(0, 4), Vector2i(1, 1)]
	for offset in offsets:
		target.grid_pos = attacker.grid_pos + offset
		var p: Dictionary = _battle.action_system.query_action({"action": &"attack", "unit": attacker, "target": target})
		if bool(p.get("valid", false)):
			preview = p
			break
	if not bool(preview.get("valid", false)):
		_check(false, "找到有效攻击位置")
		_battle.queue_free()
		await get_tree().process_frame
		return
	_check(preview.has("hit_chance"), "攻击预览包含 hit_chance")
	_check(preview.has("damage"), "攻击预览包含 damage")
	_check(int(preview.get("cost", {}).get("ap", 0)) == 1, "攻击消耗 1AP")
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(bool(validation.get("valid", false)), "攻击预览验证通过")
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result.get("success", false)), "攻击提交成功")
	_check(attacker.current_ap == ap_before - 1, "攻击消耗 1AP")
	var r: Dictionary = result.get("result", {})
	if bool(r.get("hit", false)):
		_check(target.current_hp < hp_before, "命中后目标 HP 减少")
	else:
		_check(target.current_hp == hp_before, "未命中时目标 HP 不变")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-CH1-010: 技能的 query→validate→commit 路径
func _test_skill_query_validate_commit() -> void:
	print("\n--- 测试: 技能查询→验证→提交 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	var caster: Unit = _battle.player_units[0]
	caster.current_ap = 2
	var ap_before := caster.current_ap
	var skill_id := "gen_hunker_down"
	var preview: Dictionary = _battle.action_system.query_action({"action": &"skill", "unit": caster, "action_id": skill_id})
	_check(bool(preview.get("valid", false)), "技能预览有效")
	_check(int(preview.get("cost", {}).get("ap", 0)) == 1, "技能预览包含 AP 消耗")
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(bool(validation.get("valid", false)), "技能预览验证通过")
	preview["target_data"] = {"position": caster.grid_pos, "target_unit": caster}
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result.get("success", false)), "技能提交成功")
	_check(caster.current_ap == ap_before - 1, "技能消耗 1AP")
	_check(caster.has_status("hunker"), "技能施加 hunker 状态")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-CH1-010: 物品的 query→validate→commit 路径
func _test_item_query_validate_commit() -> void:
	print("\n--- 测试: 物品查询→验证→提交 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _battle.get_script() == null:
		_check(false, "战斗脚本加载")
		_battle.queue_free()
		await get_tree().process_frame
		return
	var user: Unit = _battle.player_units[0]
	user.current_ap = 2
	user.current_hp = 10
	var hp_before := user.current_hp
	var preview: Dictionary = _battle.action_system.query_action({"action": &"item", "unit": user, "action_id": "med_kit"})
	_check(bool(preview.get("valid", false)), "物品预览有效")
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(bool(validation.get("valid", false)), "物品预览验证通过")
	preview["target_data"] = {"position": user.grid_pos, "target_unit": user}
	preview["target_unit"] = user
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result.get("success", false)), "物品提交成功")
	_check(user.current_hp > hp_before, "治疗物品恢复 HP (before=%d after=%d)" % [hp_before, user.current_hp])
	_battle.queue_free()
	await get_tree().process_frame

## CODE-CH1-010: 警戒的 query→validate→commit 路径
func _test_overwatch_query_validate_commit() -> void:
	print("\n--- 测试: 警戒查询→验证→提交 ---")
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
	unit.current_ap = 2
	var ap_before := unit.current_ap
	var preview: Dictionary = _battle.action_system.query_action({"action": &"overwatch", "unit": unit})
	_check(bool(preview.get("valid", false)), "警戒预览有效")
	_check(int(preview.get("cost", {}).get("ap", 0)) == 1, "警戒消耗 1AP")
	var validation: Dictionary = _battle.action_system.validate_action(preview)
	_check(bool(validation.get("valid", false)), "警戒预览验证通过")
	var result: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result.get("success", false)), "警戒提交成功")
	_check(unit.current_ap == ap_before - 1, "警戒消耗 1AP")
	_check(unit.has_status("overwatch"), "单位获得 overwatch 状态")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-CH1-010: 同一预览重复提交被拒绝（commit 后 preview_id 被消费）
func _test_double_commit_rejected() -> void:
	print("\n--- 测试: 重复提交同一预览被拒绝 ---")
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
	unit.current_ap = 2
	var preview: Dictionary = _battle.action_system.query_action({"action": &"overwatch", "unit": unit})
	_check(bool(preview.get("valid", false)), "警戒预览有效")
	var result1: Dictionary = _battle.action_system.commit_action(preview)
	_check(bool(result1.get("success", false)), "首次提交成功")
	# 同一 preview 再次提交应失败（preview_id 已被消费）
	var result2: Dictionary = _battle.action_system.commit_action(preview)
	_check(not bool(result2.get("success", true)), "重复提交同一预览被拒绝")
	_battle.queue_free()
	await get_tree().process_frame

## CODE-CH1-010: 取消（query 后不 commit）不消耗资源
func _test_cancel_keeps_resources() -> void:
	print("\n--- 测试: 取消不扣资源 ---")
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
	unit.current_ap = 2
	var ap_before := unit.current_ap
	var move_before := unit.move_points
	var preview: Dictionary = _battle.action_system.query_action({"action": &"overwatch", "unit": unit})
	_check(bool(preview.get("valid", false)), "警戒预览有效")
	# 不提交，直接验证资源不变
	_check(unit.current_ap == ap_before, "查询后不提交，AP 不变")
	_check(unit.move_points == move_before, "查询后不提交，move_points 不变")
	_check(not unit.has_status("overwatch"), "查询后不提交，未进入警戒")
	# 预览仍保留在 _active_previews 中（未被消费）
	var preview_id: int = int(preview.get("preview_id", 0))
	_check(_battle.action_system._active_previews.has(preview_id), "未提交的预览仍保留在 _active_previews")
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
