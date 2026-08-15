extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Recorder = preload("res://scripts/v2/mission/v2_playtest_recorder.gd")

var t := Runner.new()

func _initialize() -> void:
	var disabled := Recorder.new()
	var no_flag: Dictionary = disabled.start_from_cmdline(["--path", "res://"], "standard")
	t.check(not bool(no_flag.get("enabled", false)), "普通启动默认关闭试玩记录")
	t.check(disabled.get_session().is_empty(), "普通启动不创建试玩数据")

	var enabled := Recorder.new()
	var with_flag: Dictionary = enabled.start_from_cmdline(["--v2-playtest-id=P01"], "standard")
	t.check(bool(with_flag.get("enabled", false)) and bool(with_flag.get("success", false)), "显式 QA 参数启用试玩记录")
	t.check(String(with_flag.get("participant_id", "")) == "P01", "QA 参数只接受匿名编号")
	enabled.record(&"unit_selected", {"unit_id": "player_assault"})
	var session := enabled.finish({"completed": false, "ended_by": "test"})
	t.check((session.get("events", []) as Array).size() == 3, "启用后记录启动、选择和结束事件")

	var invalid := Recorder.new()
	var invalid_result: Dictionary = invalid.start_from_cmdline(["--v2-playtest-id=Alice"], "standard")
	t.check(not bool(invalid_result.get("enabled", false)), "无效 QA 参数不会启用记录")
	t.check(invalid.get_session().is_empty(), "无效参数不写入身份信息")

	var owner := Recorder.new()
	var owner_result: Dictionary = owner.start_from_cmdline(["--v2-playtest-id=OWNER"], "story")
	t.check(bool(owner_result.get("enabled", false)) and String(owner_result.get("participant_id", "")) == "OWNER", "OWNER 参数启用单人验收记录")
	owner.record(&"move_committed", {"turn": 1})
	var owner_session := owner.finish({"completed": false, "human_result": "approved"})
	t.check(String(owner_session.get("human_result", "")) == "incomplete", "集成入口不能替 AI 写入 approved")
	t.check(int(owner_session.get("counters", {}).get("actions", 0)) == 1, "集成入口保留动作计数")

	t.finish(self)
