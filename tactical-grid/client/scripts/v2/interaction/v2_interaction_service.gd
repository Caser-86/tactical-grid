extends RefCounted
class_name V2InteractionService

const CameraHandler = preload("res://scripts/v2/interaction/handlers/camera_handler.gd")
const DoorHandler = preload("res://scripts/v2/interaction/handlers/door_handler.gd")
const PowerHandler = preload("res://scripts/v2/interaction/handlers/power_handler.gd")
const RailHandler = preload("res://scripts/v2/interaction/handlers/rail_handler.gd")
const BeaconHandler = preload("res://scripts/v2/interaction/handlers/beacon_handler.gd")
const BossTerminalHandler = preload("res://scripts/v2/interaction/handlers/boss_terminal_handler.gd")
const RecordHandler = preload("res://scripts/v2/interaction/handlers/record_handler.gd")

var _map_data: Dictionary = {}
var _facilities_by_id: Dictionary = {}
var _handlers: Dictionary = {}
var _visibility_state: Node = null
var _mission_flow: RefCounted = null
var _state_revision: int = 0

func setup(
	map_data: Dictionary,
	_network_state: Node = null,
	visibility_state: Node = null,
	_alert_state: Node = null,
	mission_flow: RefCounted = null
) -> void:
	_map_data = map_data.duplicate(true)
	_visibility_state = visibility_state
	_mission_flow = mission_flow
	_facilities_by_id.clear()
	_handlers = {
		"camera": CameraHandler.new(),
		"door": DoorHandler.new(),
		"power": PowerHandler.new(),
		"rail": RailHandler.new(),
		"beacon": BeaconHandler.new(),
		"boss_terminal": BossTerminalHandler.new(),
		"record": RecordHandler.new(),
	}
	_state_revision = 0
	var raw_facilities: Variant = _map_data.get("facilities", [])
	if not raw_facilities is Array or (raw_facilities as Array).is_empty():
		raw_facilities = _map_data.get("network_nodes", _map_data.get("nodes", []))
	for raw_facility in raw_facilities:
		if not raw_facility is Dictionary:
			continue
		var facility: Dictionary = raw_facility.duplicate(true)
		var facility_id := String(facility.get("id", ""))
		if facility_id.is_empty():
			continue
		var facility_type := String(facility.get("type", facility.get("action", "")))
		facility_type = _normalize_type(facility_type)
		if not _handlers.has(facility_type):
			continue
		facility["type"] = facility_type
		facility["position"] = _facility_position(facility)
		facility["map_size"] = _map_data.get("size", {}).duplicate(true)
		facility["used_actions"] = facility.get("used_actions", []).duplicate()
		facility["revision"] = int(facility.get("revision", 0))
		_facilities_by_id[facility_id] = facility

func query_actions(actor: Unit, entity_id: String) -> Array:
	var facility: Dictionary = _facilities_by_id.get(entity_id, {})
	if facility.is_empty():
		return []
	var handler: RefCounted = _handlers.get(String(facility.get("type", "")), null)
	if handler == null:
		return []
	var context := _build_context(actor, facility)
	var actions: Array = handler.query(actor, facility, context)
	for action in actions:
		var action_id := String(action.get("id", ""))
		if action_id in facility.get("used_actions", []) and bool(action.get("enabled", false)):
			action["enabled"] = false
			action["reason"] = "该操作已经完成"
		if String(facility.get("state", "")) in ["damaged", "destroyed"]:
			action["enabled"] = false
			action["reason"] = "设施已经失效"
	return actions.slice(0, 2)

func commit_action(actor: Unit, entity_id: String, action_id: String, expected_revision: int = -1) -> Dictionary:
	var facility: Dictionary = _facilities_by_id.get(entity_id, {})
	if facility.is_empty():
		return {"success": false, "reason": "facility_not_found"}
	if expected_revision >= 0 and expected_revision != _state_revision:
		return {"success": false, "reason": "stale_facility_preview", "state_revision": _state_revision}
	var actions := query_actions(actor, entity_id)
	var selected: Dictionary = {}
	for action in actions:
		if String(action.get("id", "")) == action_id:
			selected = action
			break
	if selected.is_empty():
		return {"success": false, "reason": "unknown_action", "state_revision": _state_revision}
	if not bool(selected.get("enabled", false)):
		return {"success": false, "reason": String(selected.get("reason", "interaction_unavailable")), "state_revision": _state_revision}
	if actor == null or not actor.spend_v2_action():
		return {"success": false, "reason": "action_unavailable", "state_revision": _state_revision}
	var handler: RefCounted = _handlers.get(String(facility.get("type", "")), null)
	var result: Dictionary = handler.commit(actor, facility, action_id, _build_context(actor, facility))
	if not bool(result.get("success", false)):
		return result
	var mission_result := _apply_mission_event(actor, facility, action_id, result)
	if not bool(mission_result.get("success", true)):
		return mission_result
	for key in mission_result.keys():
		result[key] = mission_result[key]
	facility["state"] = result.get("state", facility.get("state", "neutral"))
	var used_actions: Array = facility.get("used_actions", []).duplicate()
	used_actions.append(action_id)
	facility["used_actions"] = used_actions
	facility["revision"] = int(facility.get("revision", 0)) + 1
	_state_revision += 1
	result["facility_id"] = entity_id
	result["action_id"] = action_id
	result["state_revision"] = _state_revision
	result["ap_cost"] = 1
	_apply_visibility_side_effect(result, action_id)
	return result

func get_facility(entity_id: String) -> Dictionary:
	return (_facilities_by_id.get(entity_id, {}) as Dictionary).duplicate(true)

func get_facility_at(cell: Vector2i) -> Dictionary:
	for raw_facility in _facilities_by_id.values():
		var facility: Dictionary = raw_facility
		if _facility_position(facility) == cell:
			return facility.duplicate(true)
	return {}

func get_state_revision() -> int:
	return _state_revision

func _build_context(actor: Unit, facility: Dictionary) -> Dictionary:
	var context := {"can_operate": false, "reason": ""}
	context["mission_flow"] = _mission_flow
	context["optional_complete"] = bool(_mission_flow.optional_complete) if _mission_flow != null else false
	if actor == null or not is_instance_valid(actor):
		context["reason"] = "invalid_unit"
		return context
	if not actor.is_alive or actor.team != "player":
		context["reason"] = "invalid_unit"
		return context
	if not actor.can_act():
		context["reason"] = "action_unavailable"
		return context
	var position: Vector2i = _facility_position(facility)
	var range_limit := int(facility.get("interaction_range", 1))
	if position != Vector2i(-1, -1) and GridSystem.manhattan_distance(actor.grid_pos, position) > range_limit:
		context["reason"] = "out_of_range"
		return context
	context["can_operate"] = true
	return context

func _apply_mission_event(actor: Unit, facility: Dictionary, action_id: String, result: Dictionary) -> Dictionary:
	if action_id != "upload_incident_record" or _mission_flow == null:
		return {"success": true}
	var event_result: Dictionary = _mission_flow.apply_event(&"optional_record_uploaded", {
		"unit": actor,
		"facility_id": String(facility.get("id", "")),
		"reward_module": String(result.get("reward_module", "scout_b")),
	})
	if not bool(event_result.get("success", false)):
		return event_result
	return {
		"success": true,
		"optional_complete": bool(_mission_flow.optional_complete),
		"optional_record_uploaded": true,
		"reward_module": String(result.get("reward_module", "scout_b")),
		"unlocked_modules": result.get("unlocked_modules", ["scout_b"]),
	}

func _apply_visibility_side_effect(result: Dictionary, action_id: String) -> void:
	if _visibility_state == null:
		return
	var zone_id := String(result.get("camera_zone_id", ""))
	if zone_id.is_empty():
		return
	if action_id == "disable_camera":
		_visibility_state.remove_camera_zone(zone_id)
		return
	var cells: Array = result.get("camera_zone_cells", [])
	if not cells.is_empty():
		_visibility_state.add_camera_zone(zone_id, cells)

func _facility_position(facility: Dictionary) -> Vector2i:
	var raw_position: Variant = facility.get("position", null)
	if raw_position is Vector2i:
		return raw_position
	if raw_position is Vector2:
		return Vector2i(raw_position)
	if raw_position is Array and raw_position.size() >= 2:
		return Vector2i(int(raw_position[0]), int(raw_position[1]))
	if facility.has("x") and facility.has("y"):
		return Vector2i(int(facility.get("x", -1)), int(facility.get("y", -1)))
	return Vector2i(-1, -1)

func _normalize_type(raw_type: String) -> String:
	match raw_type:
		"power_conduit":
			return "power"
		"reinforcement_beacon":
			return "beacon"
		"terminal":
			return "boss_terminal"
	return raw_type
