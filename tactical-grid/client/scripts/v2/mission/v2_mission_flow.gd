extends RefCounted
class_name V2MissionFlow

signal state_changed(state_name: StringName, result: Dictionary)

enum State {
	SEARCH_SCOUT,
	ESCORT_TO_EVAC,
	COMPLETE,
	FAILED,
}

const STATE_NAMES := {
	State.SEARCH_SCOUT: &"SEARCH_SCOUT",
	State.ESCORT_TO_EVAC: &"ESCORT_TO_EVAC",
	State.COMPLETE: &"COMPLETE",
	State.FAILED: &"FAILED",
}

var state: State = State.SEARCH_SCOUT
var mission: Dictionary = {}
var map_data: Dictionary = {}
var player_units: Array = []
var enemy_units: Array = []
var rescued_characters: Dictionary = {}
var optional_complete := false
var event_history: Array[Dictionary] = []

var _rescue_character_id := "scout"
var _rescue_entity_id := "rescue_scout"
var _evac_center := Vector2i(-1, -1)
var _evac_radius := 1
var _rescued_units: Array = []
var _positions: Dictionary = {}

func setup(mission_data: Dictionary, locked_map: Dictionary, players: Array, enemies: Array) -> void:
	mission = mission_data.duplicate(true)
	map_data = locked_map.duplicate(true)
	player_units = players.duplicate()
	enemy_units = enemies.duplicate()
	state = State.SEARCH_SCOUT
	rescued_characters.clear()
	optional_complete = false
	event_history.clear()
	_rescued_units.clear()
	_positions.clear()
	_evac_center = Vector2i(-1, -1)
	_evac_radius = 1
	_rescue_character_id = String(mission.get("rescue_character", "scout"))
	_find_mission_entities()
	for unit in player_units:
		_remember_unit(unit)

func apply_event(event_name: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "event": event_name, "changed": false}
	if state in [State.COMPLETE, State.FAILED] and event_name not in [&"mission_started", &"evac_checked"]:
		result["success"] = false
		result["reason"] = &"mission_finished"
		return _finish_event(event_name, result)

	match event_name:
		&"mission_started":
			result["changed"] = true
		&"scout_rescued":
			if state != State.SEARCH_SCOUT:
				return _finish_event(event_name, _fail(&"invalid_transition"))
			var character_id := String(payload.get("character_id", _rescue_character_id))
			if character_id != _rescue_character_id:
				return _finish_event(event_name, _fail(&"wrong_rescue_character"))
			rescued_characters[character_id] = true
			_register_rescued_unit(payload)
			state = State.ESCORT_TO_EVAC
			result["changed"] = true
			result["character_id"] = character_id
		&"unit_moved":
			_remember_moved_payload(payload)
			result["changed"] = true
		&"unit_downed":
			_remember_moved_payload(payload)
			result["changed"] = true
			if _all_controlled_players_downed():
				state = State.FAILED
				result["defeat"] = true
		&"evac_checked":
			if state != State.ESCORT_TO_EVAC:
				result["victory"] = false
				result["reason"] = &"rescue_required"
			elif _all_conscious_players_in_evac():
				state = State.COMPLETE
				result["changed"] = true
				result["victory"] = true
			else:
				result["victory"] = false
				result["reason"] = &"evac_not_ready"
		&"primary_irreversible_failure":
			state = State.FAILED
			result["changed"] = true
			result["defeat"] = true
		_:
			return _finish_event(event_name, _fail(&"unknown_event"))

	result["state"] = get_state_name()
	result["victory"] = state == State.COMPLETE
	result["defeat"] = state == State.FAILED
	return _finish_event(event_name, result)

func get_state() -> State:
	return state

func get_state_name() -> StringName:
	return STATE_NAMES.get(state, &"SEARCH_SCOUT")

func get_primary_text() -> String:
	match state:
		State.SEARCH_SCOUT:
			return "找到失联侦察兵"
		State.ESCORT_TO_EVAC:
			return "带侦察兵抵达撤离点"
		State.COMPLETE:
			return "侦察兵已撤离"
		State.FAILED:
			return "小队已失能"
	return "找到失联侦察兵"

func is_victory() -> bool:
	return state == State.COMPLETE

func is_defeat() -> bool:
	return state == State.FAILED

func is_in_evac(cell: Vector2i) -> bool:
	if _evac_center.x < 0:
		return false
	return abs(cell.x - _evac_center.x) + abs(cell.y - _evac_center.y) <= _evac_radius

func get_snapshot() -> Dictionary:
	return {
		"state": get_state_name(),
		"primary_text": get_primary_text(),
		"rescued_characters": rescued_characters.duplicate(true),
		"optional_complete": optional_complete,
		"evac_center": _evac_center,
		"evac_radius": _evac_radius,
		"event_count": event_history.size(),
	}

func _find_mission_entities() -> void:
	for raw_entity in map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		var entity_type := String(entity.get("type", ""))
		if String(entity.get("id", "")) == _rescue_entity_id:
			_rescue_entity_id = String(entity.get("id", _rescue_entity_id))
		if entity_type in ["evac", "extract", "evac_zone"]:
			_evac_center = Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))
			_evac_radius = maxi(0, int(entity.get("radius", 1)))

func _register_rescued_unit(payload: Dictionary) -> void:
	var rescued_unit: Variant = payload.get("new_unit", payload.get("unit", null))
	if rescued_unit != null:
		if not player_units.has(rescued_unit):
			player_units.append(rescued_unit)
		if not _rescued_units.has(rescued_unit):
			_rescued_units.append(rescued_unit)
		_remember_unit(rescued_unit)
	var unit_id := String(payload.get("unit_id", "player_scout"))
	if not unit_id.is_empty() and not _positions.has(unit_id):
		var position: Variant = payload.get("position", null)
		if position is Vector2i:
			_positions[unit_id] = position

func _remember_moved_payload(payload: Dictionary) -> void:
	var unit: Variant = payload.get("unit", payload.get("new_unit", null))
	if unit != null:
		_remember_unit(unit)
	var unit_id := String(payload.get("unit_id", _unit_id(unit)))
	var position: Variant = payload.get("position", null)
	if position is Vector2i and not unit_id.is_empty():
		_positions[unit_id] = position

func _remember_unit(unit: Variant) -> void:
	var unit_id := _unit_id(unit)
	if unit_id.is_empty():
		return
	var position := _unit_position(unit)
	if position.x >= 0:
		_positions[unit_id] = position

func _all_controlled_players_downed() -> bool:
	var controlled := _controlled_units()
	if controlled.is_empty():
		return false
	for unit in controlled:
		if _unit_alive(unit):
			return false
	return true

func _all_conscious_players_in_evac() -> bool:
	var controlled := _controlled_units()
	var conscious_count := 0
	for unit in controlled:
		if not _unit_alive(unit):
			continue
		conscious_count += 1
		if not is_in_evac(_unit_position(unit)):
			return false
	return conscious_count > 0

func _controlled_units() -> Array:
	var result: Array = []
	for unit in player_units + _rescued_units:
		if not result.has(unit):
			result.append(unit)
	return result

func _unit_id(unit: Variant) -> String:
	if unit is Unit:
		return String((unit as Unit).entity_id)
	if unit is Dictionary:
		return String((unit as Dictionary).get("entity_id", (unit as Dictionary).get("id", "")))
	return ""

func _unit_position(unit: Variant) -> Vector2i:
	if unit is Unit:
		return (unit as Unit).grid_pos
	if unit is Dictionary:
		var data: Dictionary = unit
		var unit_id := _unit_id(unit)
		if _positions.has(unit_id):
			return _positions[unit_id]
		var raw_position: Variant = data.get("position", data.get("grid_pos", Vector2i(-1, -1)))
		if raw_position is Vector2i:
			return raw_position
		if raw_position is Dictionary:
			return Vector2i(int(raw_position.get("x", -1)), int(raw_position.get("y", -1)))
	return _positions.get(_unit_id(unit), Vector2i(-1, -1))

func _unit_alive(unit: Variant) -> bool:
	if unit is Unit:
		return (unit as Unit).is_alive and not (unit as Unit).is_downed
	if unit is Dictionary:
		var data: Dictionary = unit
		return bool(data.get("is_alive", true)) and not bool(data.get("is_downed", false))
	return false

func _fail(reason: StringName) -> Dictionary:
	return {"success": false, "changed": false, "reason": reason, "state": get_state_name()}

func _finish_event(event_name: StringName, result: Dictionary) -> Dictionary:
	result["state"] = get_state_name()
	event_history.append({"event": event_name, "state": get_state_name()})
	state_changed.emit(get_state_name(), result)
	return result
