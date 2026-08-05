extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2InteractionService = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var service := V2InteractionService.new()
	service.setup({
		"facilities": [
			{"id": "camera_east", "type": "camera", "name": "东侧摄像头", "position": [2, 1]},
			{"id": "door_a", "type": "door", "name": "检修门", "position": [2, 2]},
			{"id": "power_a", "type": "power", "name": "电力节点", "position": [2, 3]},
			{"id": "rail_a", "type": "rail", "name": "轨道开关", "position": [2, 4]},
			{"id": "beacon_a", "type": "beacon", "name": "增援信标", "position": [2, 5]},
			{"id": "boss_terminal", "type": "boss_terminal", "name": "核心终端", "position": [2, 6]},
		],
	})

	var scout := _make_unit("scout", Vector2i(1, 1))
	var camera_actions: Array = service.query_actions(scout, "camera_east")
	t.check(camera_actions.size() <= 2 and camera_actions.size() == 2, "单设施最多提供两个操作")
	t.check(String(camera_actions[0].get("label", "")) == "查看东侧摄像头", "操作名称描述具体摄像头")
	t.check(String(camera_actions[0].get("consequence", "")).contains("揭示"), "提交前说明摄像头结果")
	t.check(camera_actions[0].has("raises_alert") and camera_actions[0].has("duration_turns"), "操作预览说明警戒和持续时间")
	t.check(bool(camera_actions[0].get("enabled", false)), "相邻队员可以操作设施")

	var camera_commit: Dictionary = service.commit_action(scout, "camera_east", "observe", 0)
	t.check(bool(camera_commit.get("success", false)), "摄像头操作提交成功")
	t.check(camera_commit.get("reveal_radius", 0) == 3 and camera_commit.get("state_revision", 0) == 1, "摄像头返回揭示范围和设施版本")
	t.check(not scout.v2_turn_state.action_available, "设施操作消费行动预算")

	var second_scout := _make_unit("second_scout", Vector2i(1, 1))
	var camera_after: Array = service.query_actions(second_scout, "camera_east")
	t.check(not bool(camera_after[0].get("enabled", true)) and String(camera_after[0].get("reason", "")).contains("完成"), "已完成的摄像头操作不会重复执行")
	var stale: Dictionary = service.commit_action(second_scout, "camera_east", "disable", 0)
	t.check(not bool(stale.get("success", true)) and stale.get("reason", "") == "stale_facility_preview", "旧设施版本不能提交")

	var expected := {
		"door_a": "开启检修门",
		"power_a": "重接电力节点",
		"rail_a": "切换轨道开关",
		"beacon_a": "压制增援信标",
		"boss_terminal": "破解核心终端",
	}
	var index := 0
	for facility_id in expected.keys():
		var actor := _make_unit("actor_%d" % index, Vector2i(1, 2 + index))
		var actions: Array = service.query_actions(actor, String(facility_id))
		t.check(actions.size() == 2, "%s 返回两个清晰操作" % facility_id)
		t.check(String(actions[0].get("label", "")) == String(expected[facility_id]), "%s 操作名称明确" % facility_id)
		var result: Dictionary = service.commit_action(actor, String(facility_id), String(actions[0].get("id", "")), service.get_state_revision())
		t.check(bool(result.get("success", false)) and result.get("facility_id", "") == facility_id, "%s 操作结果可提交" % facility_id)
		actor.free()
		index += 1

	var distant := _make_unit("distant", Vector2i(7, 7))
	var unavailable: Array = service.query_actions(distant, "door_a")
	t.check(not bool(unavailable[0].get("enabled", true)) and unavailable[0].get("reason", "") == "out_of_range", "远距离队员不能操作设施")

	scout.free()
	second_scout.free()
	distant.free()
	t.finish(self)

func _make_unit(id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = "player"
	unit.grid_pos = position
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
