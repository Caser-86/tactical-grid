extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Checkpoint = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var checkpoint := Checkpoint.new()
	t.check(checkpoint.has_method("checkpoint_for_event"), "V2 检查点提供事件映射")
	t.check(checkpoint.has_method("is_valid_checkpoint_id"), "V2 检查点拒绝未知 ID")
	if checkpoint.has_method("checkpoint_for_event"):
		t.check(checkpoint.call("checkpoint_for_event", &"mission_started") == &"cp_start", "任务开始写入 cp_start")
		t.check(checkpoint.call("checkpoint_for_event", &"scout_rescued") == &"cp_rescue", "营救后写入 cp_rescue")
		t.check(checkpoint.call("checkpoint_for_event", &"evac_route_opened") == &"cp_pre_evac", "撤离路线写入 cp_pre_evac")
	if checkpoint.has_method("is_valid_checkpoint_id"):
		t.check(bool(checkpoint.call("is_valid_checkpoint_id", &"cp_rescue")), "合法检查点可恢复")
		t.check(not bool(checkpoint.call("is_valid_checkpoint_id", &"zone_a")), "旧版区域 ID 不可冒充 V2 检查点")

	var flow := Flow.new()
	flow.setup({"id": "ch1_m1", "rescue_character": "scout"}, _make_map(), [], [])
	t.check(flow.has_method("restore_snapshot"), "任务流支持检查点状态恢复")
	var rescue_result: Dictionary = flow.apply_event(&"scout_rescued", {"character_id": "scout", "unit_id": "player_scout", "position": Vector2i(13, 7)})
	t.check(bool(rescue_result.get("success", false)), "测试流可进入营救后阶段")
	var route_result: Dictionary = flow.apply_event(&"evac_route_opened")
	t.check(bool(route_result.get("changed", false)), "撤离路线事件只应用一次且会改变状态")
	t.check(bool(flow.get_snapshot().get("evac_route_opened", false)), "任务快照记录撤离路线状态")
	if flow.has_method("restore_snapshot"):
		var restored: Dictionary = flow.call("restore_snapshot", flow.get_snapshot())
		t.check(bool(restored.get("success", false)), "任务流恢复检查点快照")
		t.check(flow.get_state_name() == &"ESCORT_TO_EVAC", "恢复后仍处于护送撤离")

	var result_scene_text := FileAccess.get_file_as_string("res://scenes/mission_result.tscn")
	t.check("EncounterRetryButton" in result_scene_text, "结算页保留检查点重试按钮")
	t.check("RetryButton" in result_scene_text and "BaseButton" in result_scene_text, "结算页保留重开和返回基地按钮")

	t.finish(self)

func _make_map() -> Dictionary:
	return {
		"entities": [{"id": "rescue_scout", "type": "objective_primary", "x": 13, "y": 7, "character_id": "scout", "state": "captive"}, {"id": "evac_northeast", "type": "evac", "x": 19, "y": 2, "radius": 1}],
	}
