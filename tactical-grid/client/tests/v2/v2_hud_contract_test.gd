extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const PresenterScript = preload("res://scripts/v2/presentation/v2_hud_presenter.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var hud: HUD = _make_hud()
	await process_frame
	t.check(hud != null and hud.context_label != null, "V2 HUD 控制器成功加载")

	var presenter := PresenterScript.new()
	presenter.setup(hud)
	var selected: Unit = _make_unit()
	presenter.render({
		"turn": 2,
		"phase": "玩家回合",
		"state": "unit_selected",
		"primary_objective": "找到侦察兵并撤离",
		"alert": "潜伏",
		"next_consequence": "被摄像头识别后进入搜索",
		"selected": selected,
		"context_prompt": "悬停敌人查看伤害，点击一次攻击",
		"action_budget": {"move": true, "action": true},
		"ability": "",
		"interaction": "",
		"attack_preview": "",
	})

	t.check(hud.objective_label.text == "找到侦察兵并撤离", "顶部只显示一句主目标")
	t.check(hud.context_label != null and hud.context_label.text.contains("点击一次攻击"), "当前状态有明确文字提示")
	t.check(hud.action_budget_label != null and hud.action_budget_label.text.contains("移动") and hud.action_budget_label.text.contains("行动"), "右侧显示移动与行动两项预算")
	t.check(hud.action_hint_label != null and hud.action_hint_label.visible and hud.action_hint_label.text.contains("蓝格") and hud.action_hint_label.text.contains("红色敌人") and hud.action_hint_label.text.contains("右键"), "右侧常驻显示 V2 直接操作摘要")
	t.check(not hud.move_button.visible and not hud.attack_button.visible, "V2 不显示常驻移动攻击按钮")
	t.check(hud.phase_label.text.contains("已选中"), "回合栏显示当前输入状态")
	t.check(hud.get_node("TopBar/AlertLabel").visible and hud.get_node("TopBar/AlertLabel").text.contains("下一步"), "顶部显示警戒和下一步后果")
	t.check(hud.get_node("RightPanel").visible, "选中单位时显示右侧信息")

	presenter.render({
		"turn": 2,
		"phase": "玩家回合",
		"state": "free_select",
		"primary_objective": "找到侦察兵并撤离",
		"alert": "潜伏",
		"next_consequence": "",
		"selected": null,
		"context_prompt": "选择一个单位开始行动",
		"action_budget": {"move": false, "action": false},
	})
	t.check(not hud.get_node("RightPanel").visible, "没有选中对象时收起右侧信息")
	t.check(hud.context_label.visible and hud.context_label.text.contains("选择一个单位"), "无选中对象时保留下一步提示")
	t.check(not hud.action_budget_label.visible, "没有选中对象时隐藏预算卡")

	selected.free()
	hud.free()
	t.finish(self)

func _make_unit() -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = "v2_hud_unit"
	unit.unit_name = "突击兵"
	unit.team = "player"
	unit.job = "assault"
	unit.grid_pos = Vector2i(2, 2)
	unit.max_hp = 10
	unit.current_hp = 10
	unit.move_points = 5
	unit.enable_v2_turn_mode()
	return unit

func _make_hud() -> HUD:
	var hud: HUD = HUDScript.new()
	var top_bar := Panel.new()
	top_bar.name = "TopBar"
	var turn := Label.new()
	turn.name = "TurnLabel"
	var phase := Label.new()
	phase.name = "PhaseLabel"
	var objective := Label.new()
	objective.name = "ObjectiveLabel"
	top_bar.add_child(turn)
	top_bar.add_child(phase)
	top_bar.add_child(objective)
	hud.add_child(top_bar)

	var right_panel := Panel.new()
	right_panel.name = "RightPanel"
	var unit_info := Label.new()
	unit_info.name = "UnitInfoLabel"
	var budget := Label.new()
	budget.name = "V2ActionBudgetLabel"
	var action_hint := Label.new()
	action_hint.name = "V2ActionHintLabel"
	right_panel.add_child(unit_info)
	right_panel.add_child(budget)
	right_panel.add_child(action_hint)
	hud.add_child(right_panel)

	var bottom_bar := Panel.new()
	bottom_bar.name = "BottomBar"
	var action_bar := HBoxContainer.new()
	action_bar.name = "ActionBar"
	for button_name in ["MoveButton", "AttackButton", "SkillButton", "ItemButton", "OverwatchButton", "EndTurnButton"]:
		var button := Button.new()
		button.name = button_name
		action_bar.add_child(button)
	bottom_bar.add_child(action_bar)
	hud.add_child(bottom_bar)

	var battle_log := Label.new()
	battle_log.name = "BattleLog"
	hud.add_child(battle_log)
	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	hud.add_child(pause_button)
	root.add_child(hud)
	return hud
