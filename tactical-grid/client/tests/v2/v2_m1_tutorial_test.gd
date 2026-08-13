extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const TutorialFlowScript = preload("res://scripts/v2/mission/v2_tutorial_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var flow := TutorialFlowScript.new()
	flow.setup()
	t.check(flow.current_step() == &"select", "首先教学选择")
	t.check("蓝色" in flow.current_text() and "红色" in flow.current_text(), "选择提示同时解释移动和攻击颜色")
	t.check(flow.get_visible_hint_count() == 1, "一次只显示一条提示")
	var wrong := flow.on_event(&"unit_moved")
	t.check(not bool(wrong.get("advanced", false)), "未选择不能跳过步骤")
	var selected := flow.on_event(&"unit_selected")
	t.check(bool(selected.get("advanced", false)), "完成选择后推进")
	t.check(flow.current_step() == &"move", "第二步教学移动")
	t.check("蓝色格" in flow.current_text() and "右键" in flow.current_text(), "移动提示说明可移动格和取消方式")

	var moved := flow.on_event(&"unit_moved")
	t.check(bool(moved.get("advanced", false)), "完成移动后推进到后续提示")
	t.check(flow.current_step() == &"attack", "移动后进入攻击提示而非阻塞主线")
	var completed := flow.on_event(&"evac_completed")
	t.check(bool(completed.get("advanced", false)), "主线撤离事件可直接完成软引导")
	t.check(flow.is_complete(), "主线完成后教学结束")
	t.check(flow.get_visible_hint_count() == 0, "教学完成后没有残留提示")

	var optional := TutorialFlowScript.new()
	optional.setup()
	optional.on_event(&"unit_selected")
	optional.on_event(&"unit_moved")
	var camera_first := optional.on_event(&"camera_viewed")
	t.check(bool(camera_first.get("advanced", false)) and optional.current_step() == &"evac", "摄像头教学可选且不会要求先攻击或观察敌人")
	t.check(bool(optional.on_event(&"evac_completed").get("advanced", false)) and optional.is_complete(), "可选教学之后仍可直接结束")

	var skipped := TutorialFlowScript.new()
	skipped.setup()
	var skip_result := skipped.skip()
	t.check(bool(skip_result.get("skipped", false)), "跳过教学返回明确状态")
	t.check(skipped.is_skipped(), "跳过只关闭教学状态")
	t.check(skipped.get_visible_hint_count() == 0, "跳过后不再显示提示")
	t.check(skipped.on_event(&"unit_selected").get("advanced", false) == false, "跳过后行为规则不被教学状态改写")
	t.finish(self)
