extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const TutorialFlowScript = preload("res://scripts/v2/mission/v2_tutorial_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var flow := TutorialFlowScript.new()
	flow.setup()
	t.check(flow.current_step() == &"select", "首先教学选择")
	t.check(flow.current_text().length() <= 28, "提示不超过 28 字")
	t.check(flow.get_visible_hint_count() == 1, "一次只显示一条提示")
	var wrong := flow.on_event(&"unit_moved")
	t.check(not bool(wrong.get("advanced", false)), "未选择不能跳过步骤")
	var selected := flow.on_event(&"unit_selected")
	t.check(bool(selected.get("advanced", false)), "完成选择后推进")
	t.check(flow.current_step() == &"move", "第二步教学移动")
	t.check(flow.current_text() == "点击蓝色格移动", "移动提示使用短文案")

	for expected in [
		{"event": &"unit_moved", "step": &"attack", "text": "悬停查看伤害，点击红色敌人攻击"},
		{"event": &"attack_committed", "step": &"intent", "text": "箭头显示敌人下一步"},
		{"event": &"enemy_intent_observed", "step": &"camera", "text": "靠近控制台查看摄像头"},
		{"event": &"camera_viewed", "step": &"evac", "text": "两名队员进入撤离区"},
	]:
		var result: Dictionary = flow.on_event(expected.event)
		t.check(bool(result.get("advanced", false)), "行为推进：%s" % String(expected.event))
		t.check(flow.current_step() == expected.step, "推进到步骤：%s" % String(expected.step))
		t.check(flow.current_text() == expected.text, "步骤文案明确：%s" % String(expected.step))
		t.check(flow.get_visible_hint_count() <= 1, "步骤切换不叠加提示：%s" % String(expected.step))

	var evac_wait := flow.on_event(&"unit_moved")
	t.check(not bool(evac_wait.get("advanced", false)), "单名队员移动不能完成撤离教学")
	var completed := flow.on_event(&"evac_completed")
	t.check(bool(completed.get("advanced", false)), "两名队员撤离后完成教学")
	t.check(flow.is_complete(), "六步教学完成")
	t.check(flow.get_visible_hint_count() == 0, "教学完成后没有残留提示")

	var skipped := TutorialFlowScript.new()
	skipped.setup()
	var skip_result := skipped.skip()
	t.check(bool(skip_result.get("skipped", false)), "跳过教学返回明确状态")
	t.check(skipped.is_skipped(), "跳过只关闭教学状态")
	t.check(skipped.get_visible_hint_count() == 0, "跳过后不再显示提示")
	t.check(skipped.on_event(&"unit_selected").get("advanced", false) == false, "跳过后行为规则不被教学状态改写")
	t.finish(self)
