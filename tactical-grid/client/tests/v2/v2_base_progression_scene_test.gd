extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const Progress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")
const BaseScene = preload("res://scenes/base.tscn")
const MissionResultScene = preload("res://scenes/mission_result.tscn")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M110 正式基地找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	manager.call("begin_v2_new_game_for_test", 0)
	var completed: Dictionary = Progress.complete_mission(manager.current_save, &"ch1_m1", {"rescued": ["scout"], "optional_record": true, "rating": 3})
	manager.set("current_save", completed)
	manager.call("save_current_v2")
	var base := BaseScene.instantiate()
	add_child(base)
	await get_tree().process_frame
	t.check(base.get_script() != null, "正式基地场景脚本已加载")
	t.check(not bool(base.get_node("BottomBar/HBox/ArmoryBtn").visible), "V2 基地隐藏旧军械库入口")
	t.check(not bool(base.get_node("BottomBar/HBox/ShopBtn").visible), "V2 基地隐藏旧商店入口")
	t.check(bool(base.get_node("BottomBar/HBox/BarracksBtn").visible), "V2 基地保留队员入口")
	t.check(base.get_node("BottomBar/HBox/BarracksBtn").text == "队员 / SQUAD", "V2 队员入口使用明确名称")
	t.check(base.get_node("Center/OperationTitle").text == "渗透行动 // 编队准备", "V2 基地使用编队准备标题")
	t.check(base.get_node("Center/ScrollContainer/MissionList").get_child_count() == 1, "V2 基地只显示当前任务")
	t.check("熄灯协议" in base.get_node("Center/SituationPanel/Content/SituationTitle").text, "V2 基地显示下一任务")
	t.check(bool(base.get_node("Center/SituationPanel/Content/V2SquadPanel").visible), "V2 基地显示编队选择区")
	t.check(base.get_node("Center/SituationPanel/Content/V2SquadPanel").get_child_count() >= 3, "V2 编队区显示两名角色选项")
	var m2: Dictionary = V2Data.get_mission(&"ch1_m2")
	base.call("_on_v2_squad_toggled", false, "scout", m2)
	t.check(manager.current_save.get("selected_squad", []) == ["assault"], "玩家可以取消勾选侦察兵")
	base.call("_on_v2_squad_toggled", true, "scout", m2)
	t.check(manager.current_save.get("selected_squad", []) == ["assault", "scout"], "玩家可以重新加入侦察兵")

	base.call("_on_barracks")
	await get_tree().process_frame
	var panel: Node = null
	for child in base.get_children():
		if child is CharacterPanel:
			panel = child
			break
	t.check(panel != null, "V2 基地可以打开队员面板")
	if panel != null:
		t.check(bool(panel.get("v2_mode")), "角色面板进入 V2 模式")
		t.check(panel.get("v2_character_ids") == ["assault", "scout"], "角色面板显示突击兵和侦察兵")
		t.check(not bool(panel.get_node("Panel/MainContainer/CenterContainer/StatSection").visible), "V2 隐藏六属性加点")
		t.check(not bool(panel.get_node("Panel/MainContainer/CenterContainer/SkillSection").visible), "V2 隐藏技能树")
		t.check(bool(panel.get_node("Panel/MainContainer/CenterContainer/EquipSection").visible), "V2 显示模块面板")
		panel.call("show_v2_character", 1)
		t.check("侦察" in panel.get_node("Panel/MainContainer/LeftContainer/JobLabel").text, "侦察兵角色身份可读")

	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	manager.set("battle_result", {
		"result": "victory",
		"level_id": "ch1_m1",
		"primary_objective": "找到失联侦察兵并一起撤离",
		"optional_record": true,
		"rescued": ["scout"],
		"unlocked_modules": ["scout_a", "scout_b"],
		"turns": 5,
		"units_survived": 2,
		"units_total": 2,
		"rewards": {},
	})
	var result_screen := MissionResultScene.instantiate()
	add_child(result_screen)
	await get_tree().process_frame
	t.check(not bool(result_screen.get_node("Panel/StarsContainer").visible), "V2 结算隐藏旧星级面板")
	var result_text := ""
	for child in result_screen.get_node("Panel/LootContainer").get_children():
		if child is Label:
			result_text += child.text + "\n"
	t.check("可选记录：已上传" in result_text, "V2 结算显示可选记录结果")
	t.check("侦察兵已加入基地" in result_text, "V2 结算显示侦察兵加入")
	t.check("scout_b" in result_text, "V2 结算显示新模块")
	result_screen.queue_free()
	await get_tree().process_frame
	if base != null and is_instance_valid(base):
		base.queue_free()
	await get_tree().process_frame
	t.finish(get_tree())
