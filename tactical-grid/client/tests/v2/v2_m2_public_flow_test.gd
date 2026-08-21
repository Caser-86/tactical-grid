extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const Hazard = preload("res://scripts/v2/mission/v2_hazard_controller.gd")
const Interaction = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Rescue = preload("res://scripts/v2/mission/v2_rescue_controller.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var mission := _load_mission("ch1_m2")
	var loaded := MapLoader.load_map(&"ch1_m2")
	t.check(not mission.is_empty() and bool(loaded.get("success", false)), "M2 公开流程加载正式任务和锁定地图")
	if mission.is_empty() or not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	for route_id in ["west_maintenance", "east_overpass"]:
		_run_route(route_id, mission, map)
	t.finish(self)

func _run_route(route_id: String, source_mission: Dictionary, map: Dictionary) -> void:
	var mission := source_mission.duplicate(true)
	var assault := _unit("m2_assault_%s" % route_id, Vector2i(7, 13))
	var scout := _unit("m2_scout_%s" % route_id, Vector2i(4, 17))
	var players: Array = [assault, scout]
	var flow := Flow.new()
	flow.setup(mission, map, players, [])
	flow.apply_event(&"mission_started")
	var interaction := Interaction.new()
	interaction.setup(map, null, null, null, flow)
	var action_service := ActionService.new()
	action_service.setup(map, players, [])
	var facility_id := "facility_power_west" if route_id == "west_maintenance" else "facility_security_bypass"
	var action_id := "cut_power_grid" if route_id == "west_maintenance" else "bypass_security_door"
	if route_id == "east_overpass":
		assault.move_to(Vector2i(20, 12))
	var actions := interaction.query_actions(assault, facility_id)
	t.check(actions.size() == 1 and bool(actions[0].get("enabled", false)), "%s 封锁设施公开预览可操作" % route_id)
	var route_result := interaction.commit_action(assault, facility_id, action_id, interaction.get_state_revision())
	t.check(bool(route_result.get("success", false)) and route_result.get("route_id", "") == route_id, "%s 公开设施提交返回路线后果" % route_id)
	var lockdown := flow.apply_event(&"lockdown_cleared", {"route_id": route_id, "map_changes": route_result.get("map_changes", [])})
	t.check(bool(lockdown.get("success", false)) and flow.get_current_step_id() == "rescue_sniper", "%s 封锁解除后目标切换为营救狙击手" % route_id)

	var hazards := Hazard.new()
	hazards.setup(map.get("hazards", []), Vector2i(28, 20))
	var warning := hazards.advance_player_turn(2)
	t.check(not (warning.get("warning_cells", []) as Array).is_empty(), "%s 危险喷口提前显示预警" % route_id)
	var sniper := _unit("player_sniper_%s" % route_id, Vector2i(19, 5))
	var rescue := Rescue.new()
	rescue.setup(map, players, [], action_service, flow, Callable(self, "_create_rescue"), Callable(self, "_register_rescue"))
	assault.move_to(Vector2i(18, 5))
	assault.begin_v2_turn()
	var rescue_preview := rescue.query_rescue(assault, &"rescue_sniper")
	t.check(bool(rescue_preview.get("valid", false)), "%s 狙击手公开营救预览有效" % route_id)
	var rescued := rescue.commit_rescue(rescue_preview)
	t.check(bool(rescued.get("success", false)) and rescued.get("character_id", "") == "sniper", "%s 公开营救加入狙击手" % route_id)
	var rescued_sniper: Unit = rescued.get("new_unit", sniper)
	var turbine_actor := _unit("m2_turbine_%s" % route_id, Vector2i(14, 9))
	var turbine_service := Interaction.new()
	turbine_service.setup(map, null, null, null, flow)
	var turbine := turbine_service.commit_action(turbine_actor, "facility_turbine", "show_sniper_ability", turbine_service.get_state_revision())
	t.check(bool(turbine.get("success", false)) and turbine.get("action_id", "") == "show_sniper_ability", "%s 涡轮大厅公开操作提交成功" % route_id)
	var showcase := flow.apply_event(&"sniper_ability_showcase", {"sniper_lines_visible": true})
	t.check(bool(showcase.get("success", false)) and flow.get_current_step_id() == "evacuate_squad", "%s 狙击手教学后目标切换为撤离" % route_id)
	var countermeasure := flow.apply_event(&"engineer_countermeasure_started", {"enemy_ids": ["m2_sniper_exit", "m2_drone_exit"]})
	t.check(bool(countermeasure.get("success", false)), "%s 撤离前工程师反制被记录" % route_id)
	var evac_center: Vector2i = flow.get_snapshot().get("evac_center", Vector2i(-1, -1))
	for unit in players + [rescued_sniper]:
		var destination := evac_center if unit == assault else evac_center + Vector2i.RIGHT if unit == scout else evac_center + Vector2i.UP
		unit.move_to(destination)
		flow.apply_event(&"unit_moved", {"unit": unit, "unit_id": unit.entity_id, "position": unit.grid_pos})
	var evac := flow.apply_event(&"evac_checked")
	t.check(bool(evac.get("victory", false)) and flow.is_victory(), "%s 三名存活队员进入撤离区后胜利" % route_id)
	for unit in players + [sniper, rescued_sniper, turbine_actor]:
		if unit != null and is_instance_valid(unit):
			unit.free()

func _create_rescue(_character_id: StringName, entity_id: String, position: Vector2i) -> Unit:
	return _unit(entity_id, position)

func _register_rescue(_unit_to_register: Unit) -> void:
	pass

func _load_mission(id: String) -> Dictionary:
	var file := FileAccess.open("res://data/v2/missions.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.get(id, {}) if parsed is Dictionary else {}

func _unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = entity_id
	unit.team = "player"
	unit.job = "assault"
	unit.grid_pos = position
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	unit.begin_v2_turn()
	return unit
