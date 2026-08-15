extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const TutorialFlowScript = preload("res://scripts/v2/mission/v2_tutorial_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var flow := TutorialFlowScript.new()
	flow.setup({"safe_turns": 3})

	var initial_hint: Dictionary = flow.get_hint()
	t.check(initial_hint == {
		"visible": true,
		"anchor_kind": "unit",
		"anchor_id": "selected_unit",
		"text": "选择突击兵",
		"step_id": "select",
	}, "首条教学是锚定突击兵的短提示")
	t.check(flow.get_visible_hint_count() == 1, "一次最多显示一条教学提示")
	t.check(not flow.is_m1_safe_tutorial_complete() and flow.is_m1_safety_active(1), "前三个玩家回合开启 M1 安全窗口")

	var wrong := flow.on_event(&"unit_moved")
	t.check(not bool(wrong.get("advanced", false)) and flow.current_step() == &"select", "错误事件不会跳过当前教学")
	var selected := flow.on_event(&"unit_selected", {"unit_id": "player_assault"})
	t.check(bool(selected.get("advanced", false)) and selected.get("current_step", &"") == &"move", "选择后只推进一步到移动")
	t.check(flow.get_hint() == {
		"visible": true,
		"anchor_kind": "cell",
		"anchor_id": "reachable_cell",
		"text": "点击青色格移动",
		"step_id": "move",
	}, "移动提示锚定可达格且使用正式短句")

	var moved := flow.on_event(&"unit_moved", {"anchor_id": "reachable_4_3"})
	t.check(bool(moved.get("advanced", false)) and flow.current_step() == &"attack_preview", "移动后只推进到攻击预览")
	t.check(flow.get_hint().get("anchor_kind", "") == "enemy" and flow.get_hint().get("text", "") == "悬停红框敌人查看伤害", "攻击预览提示锚定敌人")

	var previewed := flow.on_event(&"attack_previewed", {"anchor_id": "enemy_sentry_a"})
	t.check(bool(previewed.get("advanced", false)) and flow.current_step() == &"attack", "攻击预览后只推进到攻击提交")
	t.check(flow.get_hint().get("anchor_id", "") == "enemy_sentry_a" and flow.get_hint().get("text", "") == "点击敌人发动攻击", "攻击提交提示保留目标身份")

	var committed := flow.on_event(&"attack_committed", {"anchor_id": "enemy_sentry_a"})
	t.check(bool(committed.get("advanced", false)) and flow.current_step() == &"intent", "攻击提交后只推进到敌方意图")
	t.check(not flow.is_m1_safe_tutorial_complete(), "只攻击不结束安全窗口")
	t.check(flow.get_hint().get("anchor_kind", "") == "intent" and flow.get_hint().get("text", "") == "敌人的箭头表示下一步行动", "意图提示锚定敌方箭头")

	var intent := flow.on_event(&"enemy_intent_observed", {"anchor_id": "enemy_sentry_a"})
	t.check(bool(intent.get("advanced", false)) and flow.is_m1_safe_tutorial_complete(), "观察意图后结束安全窗口")
	t.check(not flow.is_m1_safety_active(2) and not flow.get_hint().get("visible", true) and flow.get_visible_hint_count() == 0, "教学完成后提示消失且安全保护关闭")

	var late_turn := TutorialFlowScript.new()
	late_turn.setup({"safe_turns": 3})
	t.check(late_turn.is_m1_safety_active(3) and not late_turn.is_m1_safety_active(4), "未完成教学也只保护前三个玩家回合")

	var skipped := TutorialFlowScript.new()
	skipped.setup()
	var skip_result := skipped.skip()
	t.check(bool(skip_result.get("skipped", false)) and skipped.is_skipped(), "跳过教学返回明确状态")
	t.check(not skipped.get_hint().get("visible", true) and not skipped.is_m1_safety_active(1), "跳过教学不留下提示或隐形保护")
	var restored := TutorialFlowScript.new()
	restored.setup({"safe_turns": 3})
	restored.restore_m1_safe_tutorial_complete(true)
	t.check(restored.is_m1_safe_tutorial_complete() and not restored.is_m1_safety_active(1) and not restored.get_hint().get("visible", true), "检查点恢复后不重新显示教学或安全窗口")
	t.finish(self)
