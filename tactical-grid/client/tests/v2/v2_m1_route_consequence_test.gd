extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Interaction = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const VisibilityStateScript = preload("res://scripts/game/visibility_state.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")

var t := Runner.new()

func _initialize() -> void:
	var loaded: Dictionary = MapLoader.load_map(&"ch1_m1")
	t.check(bool(loaded.get("success", false)), "M1 路线后果测试加载正式地图")
	if not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	var camera_service := _make_service(map)
	var camera_route := camera_service.select_route("camera_maintenance")
	t.check(bool(camera_route.get("success", false)), "维修摄像头路线可以一次选择")
	t.check(camera_route.get("event", "") == "route_selected", "路线选择产生稳定事件")
	t.check(camera_route.get("route_id", "") == "camera_maintenance", "维修路线返回稳定路线 ID")
	t.check(bool(camera_route.get("route_preview", false)), "维修路线提供救援区预览")
	t.check(bool(camera_route.get("raises_alert", false)), "维修路线明确提示会提高警戒")
	t.check(not bool(camera_service.select_route("cargo_breakthrough").get("success", true)), "路线选择不可重复覆盖")
	t.check(camera_service.select_route("cargo_breakthrough").get("reason", "") == "route_already_selected", "重复路线返回稳定原因")

	var cargo_service := _make_service(map)
	var cargo_route := cargo_service.select_route("cargo_breakthrough")
	t.check(bool(cargo_route.get("success", false)), "货柜路线可以选择")
	t.check(bool(cargo_route.get("shorter_path", false)), "货柜路线标记为短路径")
	t.check(not bool(cargo_route.get("route_preview", true)), "货柜路线不伪造救援区预览")
	t.check(not bool(cargo_route.get("raises_alert", true)), "货柜路线不额外提高警戒")

	var gantry_actor := _make_unit("gantry_actor", Vector2i(12, 5))
	var gantry_actions: Array = camera_service.query_actions(gantry_actor, "facility_gantry")
	t.check(gantry_actions.size() == 1, "吊车只提供一个明确动作")
	t.check(gantry_actions[0].get("id", "") == "lower_gantry", "吊车动作 ID 稳定")
	var gantry_result: Dictionary = camera_service.commit_action(
		gantry_actor, "facility_gantry", "lower_gantry", camera_service.get_state_revision()
	)
	t.check(bool(gantry_result.get("success", false)), "吊车动作提交成功")
	t.check(gantry_result.get("route_id", "") == "gantry_bridge", "吊车返回稳定路线 ID")
	t.check((gantry_result.get("map_changes", []) as Array).size() == 2, "吊车返回两格开路变化")
	t.check(gantry_result.get("enemy_intent_changes", {}).get("m1_sniper_evac_a", "") == "intercept", "吊车同步更新撤离拦截意图")

	var record_actor := _make_unit("record_actor", Vector2i(4, 5))
	var record_before: Array = camera_service.query_actions(record_actor, "facility_record")
	t.check(bool(record_before[0].get("enabled", false)), "记录室作为可选支线可直接上传")
	var record_after: Array = camera_service.query_actions(record_actor, "facility_record")
	t.check(bool(record_after[0].get("enabled", false)), "记录室保持可操作")
	var flow := Flow.new()
	flow.setup({"id": "ch1_m1", "rescue_character": "scout"}, map, [], [])
	var reward_service := _make_service(map, flow)
	reward_service.mark_encounter_cleared("m1_e03_record")
	var reward_actor := _make_unit("reward_actor", Vector2i(4, 5))
	var record_result: Dictionary = reward_service.commit_action(
		reward_actor, "facility_record", "upload_incident_record", reward_service.get_state_revision()
	)
	t.check(bool(record_result.get("success", false)), "记录室奖励动作提交成功")
	t.check(bool(record_result.get("optional_complete", false)), "记录室完成可选目标")
	t.check(record_result.get("reward_module", "") == "scout_b", "记录室奖励保持侦察模块 B")

	for unit in [gantry_actor, record_actor, reward_actor]:
		unit.free()
	t.finish(self)

func _make_service(map: Dictionary, flow: RefCounted = null) -> Interaction:
	var visibility: VisibilityState = VisibilityStateScript.new()
	visibility.setup(26, 18)
	var service := Interaction.new()
	service.setup(map, null, visibility, null, flow)
	return service

func _make_unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = entity_id
	unit.team = "player"
	unit.job = "assault"
	unit.grid_pos = position
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
