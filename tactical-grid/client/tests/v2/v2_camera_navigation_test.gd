extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const NavigationScript = preload("res://scripts/v2/runtime/v2_camera_navigation.gd")

var t := Runner.new()

func _initialize() -> void:
	var navigation: RefCounted = NavigationScript.new()
	var inspection: Dictionary = navigation.begin_inspect(Vector2i(15, 5), 7, Vector2i(3, 14))
	_check_result_shape(inspection, "开始摄像头查看返回完整导航结果")
	t.check(bool(inspection.get("success", false)), "摄像头查看成功开始")
	t.check(inspection.get("mode") == &"inspect" and inspection.get("focus_cell") == Vector2i(15, 5), "摄像头查看聚焦目标区域")
	t.check(bool(inspection.get("show_return", false)) and float(inspection.get("zoom_hint", 2.0)) <= 0.75, "半径 7 查看显示返回控件并缩放到完整区域")
	t.check(navigation.is_inspecting(), "开始摄像头查看后保持查看状态")

	var cancelled: Dictionary = navigation.cancel_inspect()
	_check_result_shape(cancelled, "取消摄像头查看返回完整导航结果")
	t.check(bool(cancelled.get("success", false)) and cancelled.get("mode") == &"player", "取消摄像头查看回到队员模式")
	t.check(cancelled.get("focus_cell") == Vector2i(3, 14) and not bool(cancelled.get("show_return", true)), "取消摄像头查看恢复存储的队员格")
	t.check(not navigation.is_inspecting(), "取消摄像头查看结束查看状态")

	navigation.begin_inspect(Vector2i(18, 2), 99, Vector2i(3, 14))
	var focused: Dictionary = navigation.focus_player(Vector2i(4, 14))
	_check_result_shape(focused, "F 聚焦队员返回完整导航结果")
	t.check(bool(focused.get("success", false)) and focused.get("mode") == &"player", "F 聚焦始终回到队员模式")
	t.check(focused.get("focus_cell") == Vector2i(4, 14) and not bool(focused.get("show_return", true)), "F 聚焦使用当前存活队员格并隐藏返回控件")
	t.check(not navigation.is_inspecting(), "F 聚焦结束摄像头查看")

	var no_op: Dictionary = navigation.cancel_inspect()
	_check_result_shape(no_op, "非查看状态取消返回完整导航结果")
	t.check(bool(no_op.get("success", false)) and no_op.get("focus_cell") == Vector2i(4, 14), "非查看状态取消保持当前队员格")

	var invalid_focus: Dictionary = navigation.focus_player(Vector2i(-1, -1))
	_check_result_shape(invalid_focus, "无效队员格仍返回完整导航结果")
	t.check(not bool(invalid_focus.get("success", true)) and invalid_focus.get("focus_cell") == Vector2i(4, 14), "无效队员格不会产生无效镜头焦点")
	t.finish(self)

func _check_result_shape(result: Dictionary, message: String) -> void:
	t.check(
		result.has("success")
			and result.has("mode")
			and result.has("focus_cell")
			and result.has("zoom_hint")
			and result.has("show_return")
			and result.get("mode") is StringName
			and result.get("focus_cell") is Vector2i,
		message
	)
