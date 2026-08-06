extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const PresenterScript = preload("res://scripts/v2/presentation/v2_hud_presenter.gd")
const FlowScript = preload("res://scripts/v2/mission/v2_mission_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== V2 objective HUD contract ===")
	var hud: HUD = _make_hud()
	var presenter := PresenterScript.new()
	presenter.setup(hud)
	var snapshot := {
		"mission_id": "ch1_m2",
		"step_id": "disable_lockdown",
		"step_index": 2,
		"step_count": 10,
		"objective_text": "进入冷却控制室",
		"guide_text": "前往冷却控制室",
		"route_hint": "沿北侧通道前进",
		"hazard_warning": "危险区将在下一回合生效",
		"checkpoint_id": "cp_rescue",
		"turn": 4,
		"phase": "玩家回合",
		"ordinary_controls": "蓝格移动 · 红色敌人攻击",
	}
	presenter.render(snapshot)

	t.check(hud.objective_label.text.contains("3/10"), "目标栏显示无歧义的阶段进度")
	t.check(hud.objective_label.text.contains("进入冷却控制室"), "目标栏显示当前目标")
	t.check(_v2_guide_text(hud).contains("前往冷却控制室"), "底栏显示下一具体行动")
	t.check(_v2_guide_text(hud).contains("沿北侧通道前进"), "底栏显示路线提示")
	t.check(_v2_guide_text(hud).contains("cp_rescue"), "底栏显示检查点状态")
	t.check(_v2_guide_text(hud).contains("危险区"), "危险区预警进入非模态底栏")
	t.check(hud.get_node("TopBar/AlertLabel").text.contains("进入冷却控制室"), "优先级渲染将当前目标置于警报栏")
	t.check(hud.get_node_or_null("ContextPrompt") is Label, "V2 提示使用普通控件而非模态窗口")
	t.check(_no_popup_descendant(hud), "V2 HUD 快照渲染不会打开中央模态")

	_assert_priority(hud, presenter)
	_assert_long_text_layout(hud, presenter)
	_assert_missing_optional_fields(hud, presenter)
	_assert_m1_player_facing_progress()
	_assert_v1_isolation()

	presenter = null
	hud.free()
	t.finish(self)

func _assert_priority(hud: HUD, presenter: RefCounted) -> void:
	presenter.render({
		"objective_text": "当前目标",
		"guide_text": "下一步",
		"hazard_warning": "危险预警",
		"route_hint": "路线提示",
		"ordinary_controls": "普通操作",
		"status": "failure",
		"outcome_text": "任务失败",
	})
	t.check(hud.get_node("TopBar/AlertLabel").text.begins_with("任务失败"), "失败优先于目标、危险、路线和操作提示")

	presenter.render({
		"objective_text": "当前目标",
		"guide_text": "下一步",
		"hazard_warning": "危险预警",
		"route_hint": "路线提示",
		"ordinary_controls": "普通操作",
		"status": "victory",
		"outcome_text": "任务完成",
	})
	t.check(hud.get_node("TopBar/AlertLabel").text.begins_with("任务完成"), "胜利优先于目标、危险、路线和操作提示")

	presenter.render({"objective_text": "当前目标", "hazard_warning": "危险预警", "route_hint": "路线提示", "ordinary_controls": "普通操作"})
	t.check(hud.get_node("TopBar/AlertLabel").text == "当前目标", "当前目标优先于危险、路线和普通操作")

	presenter.render({"hazard_warning": "危险预警", "route_hint": "路线提示", "ordinary_controls": "普通操作"})
	t.check(hud.get_node("TopBar/AlertLabel").text == "危险预警", "危险预警优先于路线和普通操作")

	presenter.render({"route_hint": "路线提示", "ordinary_controls": "普通操作"})
	t.check(hud.get_node("TopBar/AlertLabel").text == "路线提示", "路线提示优先于普通操作")

	presenter.render({"ordinary_controls": "普通操作"})
	t.check(hud.get_node("TopBar/AlertLabel").text == "普通操作", "没有任务提示时显示普通操作")

func _assert_long_text_layout(hud: HUD, presenter: RefCounted) -> void:
	var long_text := "前往冷却控制室并沿北侧通道绕开摄像头，等待危险区预警结束后从东侧维护门进入控制室。"
	presenter.render({"objective_text": long_text, "guide_text": long_text, "route_hint": long_text, "hazard_warning": long_text})
	var guide := hud.get_node_or_null("BottomBar/V2DirectControlGuide") as Label
	t.check(guide != null and guide.autowrap_mode != TextServer.AUTOWRAP_OFF, "长任务文案启用自动换行")
	t.check(guide != null and guide.clip_text, "长任务文案限制在底栏安全区域")
	t.check(hud.context_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "上下文提示启用自动换行")
	t.check(_no_popup_descendant(hud), "长任务文案不会退化为中央模态")

func _assert_missing_optional_fields(hud: HUD, presenter: RefCounted) -> void:
	presenter.render({"mission_id": "ch1_m1", "objective_text": "找到侦察兵"})
	t.check(hud.objective_label.text.contains("找到侦察兵"), "缺少可选字段时仍显示目标")
	t.check(hud.get_node("TopBar/AlertLabel").text != "", "缺少可选字段时保留安全提示默认值")
	t.check(hud.turn_label.text == "回合 -", "后续快照缺少回合字段时清除旧回合标签")
	t.check(_no_popup_descendant(hud), "缺少可选字段时不创建模态")

func _assert_m1_player_facing_progress() -> void:
	var mission_file := FileAccess.open("res://data/v2/missions.json", FileAccess.READ)
	if mission_file == null:
		t.check(false, "加载 shipped M1 任务数据")
		return
	var missions: Variant = JSON.parse_string(mission_file.get_as_text())
	mission_file.close()
	var mission: Dictionary = missions.get("ch1_m1", {}) if missions is Dictionary else {}
	var flow := FlowScript.new()
	flow.setup(mission, {}, [], [])
	t.check(int(flow.call("get_objective_step_count")) == 3, "M1 保留三个原始目标步骤供存档和测试")
	var supports_display_progress := flow.has_method("get_display_objective_step_index") \
		and flow.has_method("get_display_objective_step_count")
	t.check(supports_display_progress, "任务流公开玩家可见目标进度读取契约")
	if not supports_display_progress:
		return
	t.check(
		int(flow.call("get_display_objective_step_index")) == 0
		and int(flow.call("get_display_objective_step_count")) == 2
		and flow.get_current_guide_text().contains("流程 1/2"),
		"M1 营救前 HUD 进度与玩家指南均为 1/2"
	)
	var rescue := flow.apply_event(&"character_rescued", {"character_id": "scout"})
	t.check(bool(rescue.get("success", false)), "M1 进度断言可推进真实营救事件")
	t.check(
		int(flow.call("get_objective_step_index")) == 1
		and int(flow.call("get_display_objective_step_index")) == 1
		and int(flow.call("get_display_objective_step_count")) == 2
		and flow.get_current_guide_text().contains("流程 2/2"),
		"M1 营救后 pre-evac HUD 进度与玩家指南均为 2/2"
	)

func _assert_v1_isolation() -> void:
	var hud: HUD = _make_hud()
	hud.update_objective("V1 原作目标")
	hud.update_turn_display(7, TurnManager.TurnPhase.PLAYER_ACTION)
	t.check(hud.objective_label.text == "V1 原作目标", "V1 HUD 调用仍保留原目标布局")
	t.check(hud.turn_label.text == "回合 7" and hud.phase_label.text == "玩家回合", "V1 HUD 回合显示未被 V2 接口污染")
	t.check(not hud._v2_hud_active, "V1 HUD 未调用 V2 渲染入口")
	hud.free()

func _v2_guide_text(hud: HUD) -> String:
	var guide := hud.get_node_or_null("BottomBar/V2DirectControlGuide") as Label
	return guide.text if guide != null else ""

func _no_popup_descendant(node: Node) -> bool:
	for child in node.get_children():
		if child is Popup or child is Window:
			return false
		if not _no_popup_descendant(child):
			return false
	return true

func _make_hud() -> HUD:
	var hud: HUD = HUDScript.new()
	var top_bar := Panel.new()
	top_bar.name = "TopBar"
	for child_name in ["TurnLabel", "PhaseLabel", "ObjectiveLabel"]:
		var label := Label.new()
		label.name = child_name
		top_bar.add_child(label)
	hud.add_child(top_bar)

	var right_panel := Panel.new()
	right_panel.name = "RightPanel"
	for child_name in ["UnitInfoLabel", "V2ActionBudgetLabel", "V2ActionHintLabel"]:
		var label := Label.new()
		label.name = child_name
		right_panel.add_child(label)
	hud.add_child(right_panel)

	var bottom_bar := Panel.new()
	bottom_bar.name = "BottomBar"
	var shortcut_hint := Label.new()
	shortcut_hint.name = "ShortcutHint"
	bottom_bar.add_child(shortcut_hint)
	var v2_guide := Label.new()
	v2_guide.name = "V2DirectControlGuide"
	bottom_bar.add_child(v2_guide)
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
