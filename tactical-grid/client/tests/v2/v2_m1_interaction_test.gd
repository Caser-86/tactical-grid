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
	t.check(bool(loaded.get("success", false)), "M1 交互测试加载锁定地图")
	if not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	var assault := _make_unit("player_assault", Vector2i(7, 10))
	var scout := _make_unit("player_scout", Vector2i(4, 5))
	var module_scout := _make_unit("module_scout", Vector2i(7, 10))
	module_scout.job = "scout"
	module_scout.equipment = {"v2_modules": ["scout_b"]}
	var flow := Flow.new()
	flow.setup({"id": "ch1_m1", "rescue_character": "scout"}, map, [assault], [])
	var visibility: VisibilityState = VisibilityStateScript.new()
	visibility.setup(22, 16)
	var service := Interaction.new()
	service.setup(map, null, visibility, null, flow)

	var camera_actions: Array = service.query_actions(assault, "facility_camera_console_south")
	t.check(camera_actions.size() == 2, "M1 摄像头提供两个明确操作")
	t.check(camera_actions[0].get("id", "") == "view_camera_east", "摄像头操作使用稳定动作 ID")
	t.check(String(camera_actions[0].get("label", "")).contains("东侧"), "摄像头操作说明目标区域")
	t.check(String(camera_actions[0].get("consequence", "")).contains("持续"), "摄像头操作说明持续观察结果")
	var camera_result: Dictionary = service.commit_action(
		module_scout, "facility_camera_console_south", "view_camera_east", service.get_state_revision()
	)
	t.check(bool(camera_result.get("success", false)), "摄像头查看操作提交成功")
	t.check(camera_result.get("camera_zone_id", "") == "camera_east_zone", "摄像头返回持久区域 ID")
	t.check(camera_result.get("module_camera_disable_turns", 0) == 1, "侦察模块 B 额外短暂关闭摄像头")
	t.check(visibility.is_cell_observed(Vector2i(15, 5)), "摄像头提交后东侧中心格立即可见")
	visibility.update_visibility([], [])
	t.check(visibility.is_cell_observed(Vector2i(15, 5)), "摄像头区域跨回合保持可见")

	var disable_actor := _make_unit("player_disable", Vector2i(7, 10))
	var camera_after: Array = service.query_actions(disable_actor, "facility_camera_console_south")
	t.check(not bool(camera_after[0].get("enabled", true)), "摄像头查看操作不可重复提交")
	t.check(bool(camera_after[1].get("enabled", false)), "摄像头关闭操作仍可用")
	var disable_result: Dictionary = service.commit_action(
		disable_actor, "facility_camera_console_south", "disable_camera", service.get_state_revision()
	)
	t.check(bool(disable_result.get("success", false)), "摄像头关闭操作提交成功")
	visibility.update_visibility([], [])
	t.check(not visibility.is_cell_observed(Vector2i(15, 5)), "摄像头关闭后区域不再保持观察")

	var record_actions: Array = service.query_actions(scout, "facility_optional_record")
	t.check(record_actions.size() == 1, "事故记录点只提供一个具体操作")
	t.check(record_actions[0].get("id", "") == "upload_incident_record", "事故记录使用稳定动作 ID")
	var record_result: Dictionary = service.commit_action(
		scout, "facility_optional_record", "upload_incident_record", service.get_state_revision()
	)
	t.check(bool(record_result.get("success", false)), "事故记录提交成功")
	t.check(bool(record_result.get("optional_complete", false)) and flow.optional_complete, "事故记录完成可选目标")
	t.check(record_result.get("reward_module", "") == "scout_b", "事故记录奖励侦察模块 B")
	t.check(not flow.is_victory(), "完成可选目标不会直接完成主线")
	var record_again_actor := _make_unit("player_record_again", Vector2i(4, 5))
	var record_again: Array = service.query_actions(record_again_actor, "facility_optional_record")
	t.check(not bool(record_again[0].get("enabled", true)), "事故记录不可重复提交")

	var rescued := flow.apply_event(&"scout_rescued", {"character_id": "scout", "unit": scout})
	t.check(bool(rescued.get("success", false)), "可选记录完成后仍可正常营救")
	assault.grid_pos = Vector2i(19, 2)
	scout.grid_pos = Vector2i(19, 2)
	flow.apply_event(&"unit_moved", {"unit": assault, "unit_id": assault.entity_id, "position": assault.grid_pos})
	flow.apply_event(&"unit_moved", {"unit": scout, "unit_id": scout.entity_id, "position": scout.grid_pos})
	t.check(bool(flow.apply_event(&"evac_checked").get("victory", false)), "可选记录不影响营救撤离胜利")

	for unit in [assault, scout, module_scout, disable_actor, record_again_actor]:
		unit.free()
	visibility.free()
	t.finish(self)

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
