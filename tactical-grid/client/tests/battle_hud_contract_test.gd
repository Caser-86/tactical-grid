## 战斗 HUD 契约测试
## 验证选中玩家单位时显示五个行动按钮，选中敌人时不显示
## 验证按钮图标尺寸受限，不挤压 HUD
extends Node

const BattleScene = preload("res://scenes/battle.tscn")
const GameDataScript = preload("res://scripts/data/game_data.gd")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _battle: Node = null

func _ready() -> void:
	print("=== 战斗 HUD 契约测试 ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	GameManager.begin_new_game_for_test(0)
	await _test_hud_contract()
	await get_tree().process_frame

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

func _test_hud_contract() -> void:
	print("\n--- 测试: HUD 按钮可见性与图标尺寸 ---")
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var hud = _battle.get_node_or_null("HUD")
	_check(hud != null, "HUD 节点存在")
	if hud == null:
		return

	# 验证行动按钮节点存在
	var move_btn = hud.get_node_or_null("BottomBar/ActionBar/MoveButton")
	var attack_btn = hud.get_node_or_null("BottomBar/ActionBar/AttackButton")
	var skill_btn = hud.get_node_or_null("BottomBar/ActionBar/SkillButton")
	var item_btn = hud.get_node_or_null("BottomBar/ActionBar/ItemButton")
	var overwatch_btn = hud.get_node_or_null("BottomBar/ActionBar/OverwatchButton")
	var end_turn_btn = hud.get_node_or_null("BottomBar/ActionBar/EndTurnButton")

	_check(move_btn != null, "MoveButton 存在")
	_check(attack_btn != null, "AttackButton 存在")
	_check(skill_btn != null, "SkillButton 存在")
	_check(item_btn != null, "ItemButton 存在")
	_check(overwatch_btn != null, "OverwatchButton 存在")
	_check(end_turn_btn != null, "EndTurnButton 存在")

	if move_btn == null or end_turn_btn == null:
		return

	# 初始状态：行动按钮应隐藏，结束回合应可见
	_check(not move_btn.visible, "初始状态 MoveButton 隐藏")
	_check(not attack_btn.visible, "初始状态 AttackButton 隐藏")
	_check(end_turn_btn.visible, "初始状态 EndTurnButton 可见")

	# 创建玩家单位并选中
	var player_unit = GameData.create_player_unit("assault", "TestSoldier")
	_battle.player_units = [player_unit]
	_battle.selected_unit = player_unit
	hud.update_unit_info(player_unit)

	# 验证五个行动按钮可见
	_check(move_btn.visible, "选中玩家单位后 MoveButton 可见")
	_check(attack_btn.visible, "选中玩家单位后 AttackButton 可见")
	_check(skill_btn.visible, "选中玩家单位后 SkillButton 可见")
	_check(item_btn.visible, "选中玩家单位后 ItemButton 可见")
	_check(overwatch_btn.visible, "选中玩家单位后 OverwatchButton 可见")
	_check(end_turn_btn.visible, "选中玩家单位后 EndTurnButton 仍可见")

	# 验证单位信息标签有内容
	var unit_info_label = hud.get_node_or_null("RightPanel/UnitInfoLabel")
	if unit_info_label:
		_check(unit_info_label.text.length() > 0, "单位信息标签有内容")
		_check(unit_info_label.text.contains("TestSoldier"), "单位信息包含单位名称")

	# 创建敌人单位并选中
	var enemy_unit = GameData.create_enemy_unit("sentry_basic")
	_battle.selected_unit = enemy_unit
	hud.update_unit_info(enemy_unit)

	# 验证行动按钮隐藏（敌人不显示玩家行动按钮）
	_check(not move_btn.visible, "选中敌人后 MoveButton 隐藏")
	_check(not attack_btn.visible, "选中敌人后 AttackButton 隐藏")
	_check(not skill_btn.visible, "选中敌人后 SkillButton 隐藏")
	_check(not item_btn.visible, "选中敌人后 ItemButton 隐藏")
	_check(not overwatch_btn.visible, "选中敌人后 OverwatchButton 隐藏")
	_check(end_turn_btn.visible, "选中敌人后 EndTurnButton 仍可见")

	# 验证图标尺寸受限（通过 theme_override_constants）
	var icon_max = end_turn_btn.get_theme_constant("icon_max_width")
	_check(icon_max > 0 and icon_max <= 24, "EndTurnButton 图标尺寸受限 (当前: %d, 应 <= 24)" % icon_max)

	# 验证按钮尺寸不超过 120x48
	_check(end_turn_btn.custom_minimum_size.x <= 120, "EndTurnButton 宽度 <= 120 (当前: %d)" % int(end_turn_btn.custom_minimum_size.x))
	_check(end_turn_btn.custom_minimum_size.y <= 48, "EndTurnButton 高度 <= 48 (当前: %d)" % int(end_turn_btn.custom_minimum_size.y))

	# 清理
	if player_unit and is_instance_valid(player_unit):
		player_unit.queue_free()
	if enemy_unit and is_instance_valid(enemy_unit):
		enemy_unit.queue_free()
	_battle.queue_free()
	await get_tree().process_frame

func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if _errors.size() > 0:
		print("  失败项:")
		for e in _errors:
			print("    - ", e)
	print("  =================")
