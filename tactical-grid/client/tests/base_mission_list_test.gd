## 基地任务列表契约测试
## 验证新游戏存档下基地场景显示第一章六个任务按钮
extends Node

const BaseScene = preload("res://scenes/base.tscn")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []

func _ready() -> void:
	print("=== 基地任务列表契约测试 ===")
	# 清理存档
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	# 测试 1: build_campaign_tree 返回正确字段
	_test_campaign_tree_fields()
	await get_tree().process_frame

	# 测试 2: 基地场景实例化后有六个任务按钮
	await _test_base_mission_list()
	await get_tree().process_frame

	# 清理
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

func _test_campaign_tree_fields() -> void:
	print("\n--- 测试: build_campaign_tree 字段完整性 ---")
	var tree = CampaignRepository.build_campaign_tree([])
	_check(tree.size() > 0, "build_campaign_tree 返回非空")

	var ch1 = null
	for chapter in tree:
		if chapter.get("chapter", 0) == 1:
			ch1 = chapter
			break
	_check(ch1 != null, "第一章存在于战役树中")

	if ch1 == null:
		return

	var missions = ch1.get("missions", [])
	_check(missions.size() == 6, "第一章有 6 个任务 (实际: %d)" % missions.size())

	# 验证每个任务都有必需字段
	var required_fields = ["level_id", "name", "mission_type", "size", "difficulty", "locked", "completed", "is_boss", "rewards"]
	for mission in missions:
		for field in required_fields:
			_check(mission.has(field), "任务 %s 包含字段 %s" % [mission.get("level_id", "?"), field])

	# 验证 ch1_m1 解锁，其余锁定
	var m1 = _find_mission(missions, "ch1_m1")
	_check(m1 != null, "ch1_m1 存在于战役树")
	if m1:
		_check(not m1.get("locked", true), "ch1_m1 默认解锁")
		_check(not m1.get("completed", true), "ch1_m1 默认未完成")
		_check(not m1.get("is_boss", true), "ch1_m1 不是 Boss 关")

	var m6 = _find_mission(missions, "ch1_m6")
	_check(m6 != null, "ch1_m6 存在于战役树")
	if m6:
		_check(m6.get("locked", false), "ch1_m6 默认锁定")
		_check(m6.get("is_boss", false), "ch1_m6 是 Boss 关")

func _find_mission(missions: Array, level_id: String) -> Dictionary:
	for m in missions:
		if m.get("level_id", "") == level_id:
			return m
	return {}

func _test_base_mission_list() -> void:
	print("\n--- 测试: 基地场景任务按钮 ---")
	# 初始化新游戏存档
	GameManager.begin_new_game_for_test(0)

	# 实例化基地场景
	var base = BaseScene.instantiate()
	add_child(base)

	# 等待两帧让 @onready 和 _ready 完成
	await get_tree().process_frame
	await get_tree().process_frame

	var background = base.get_node_or_null("Background")
	_check(background is TextureRect, "基地使用全屏 TextureRect 正式背景")
	if background is TextureRect:
		_check(background.texture is Texture2D, "基地正式背景纹理已接入")

	var operation_frame = base.get_node_or_null("Center/OperationFrame")
	_check(operation_frame is Panel, "基地行动序列面板存在")

	var situation_panel = base.get_node_or_null("Center/SituationPanel")
	_check(situation_panel is Panel, "基地战区态势面板存在")
	if situation_panel:
		var situation_title = situation_panel.get_node_or_null("Content/SituationTitle")
		var situation_body = situation_panel.get_node_or_null("Content/SituationBody")
		_check(situation_title is Label and not situation_title.text.is_empty(), "战区态势标题可读")
		_check(situation_body is Label and not situation_body.text.is_empty(), "战区态势内容可读")

	# 查找 MissionList
	var mission_list = base.get_node_or_null("Center/ScrollContainer/MissionList")
	_check(mission_list != null, "MissionList 节点存在")

	if mission_list == null:
		base.queue_free()
		await get_tree().process_frame
		return

	# 统计按钮数量（排除 Label 和其他非 Button 节点）
	var buttons: Array = []
	for child in mission_list.get_children():
		if child is Button:
			buttons.append(child)

	_check(buttons.size() == 6, "基地显示 6 个任务按钮 (实际: %d)" % buttons.size())

	# 验证第一个按钮是 ch1_m1 且未禁用
	if buttons.size() > 0:
		var first_btn = buttons[0]
		_check(not first_btn.disabled, "第一个任务按钮(ch1_m1)可点击")
		_check(first_btn.text.length() > 0, "第一个任务按钮有文字")

	# 验证 ch1_m2 至 ch1_m6 按钮被禁用
	if buttons.size() >= 6:
		for i in range(1, 6):
			_check(buttons[i].disabled, "任务按钮 %d (ch1_m%d) 被锁定" % [i + 1, i + 1])

	# 清理
	base.queue_free()
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
