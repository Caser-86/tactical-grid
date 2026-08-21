extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var mission := {
		"id": "contract_objective_steps",
		"objective_steps": [
			{"id": "secure_access", "complete_event": "access_panel_hacked"},
			{"id": "extract_team", "complete_event": "team_extracted"},
		],
	}
	var flow := Flow.new()
	flow.setup(mission, {}, [], [])

	var supports_steps := flow.has_method("get_current_step_id") \
		and flow.has_method("get_objective_step_index") \
		and flow.has_method("get_objective_step_count")
	t.check(supports_steps, "任务流公开目标步骤读取契约")
	t.check(flow.has_method("get_snapshot") and flow.has_method("restore_snapshot"), "任务流公开快照恢复契约")
	if not supports_steps:
		t.finish(self)
		return

	t.check(flow.call("get_current_step_id") == &"secure_access", "设置后从第一个目标步骤开始")
	t.check(int(flow.call("get_objective_step_index")) == 0, "第一个目标步骤索引为零")
	t.check(int(flow.call("get_objective_step_count")) == 2, "目标步骤总数为二")

	var advanced: Dictionary = flow.apply_event(&"access_panel_hacked")
	t.check(
		flow.call("get_current_step_id") == &"extract_team"
		and int(advanced.get("step_index", -1)) == 1
		and int(advanced.get("step_count", -1)) == 2,
		"完成事件推进到第二个步骤并返回索引和总数"
	)

	var restored := Flow.new()
	restored.setup(mission, {}, [], [])
	var restored_result: Dictionary = restored.call("restore_snapshot", flow.call("get_snapshot"))
	t.check(
		bool(restored_result.get("success", false))
		and restored.call("get_current_step_id") == &"extract_team"
		and int(restored.call("get_objective_step_index")) == 1,
		"快照恢复保留当前目标步骤"
	)
	t.finish(self)
