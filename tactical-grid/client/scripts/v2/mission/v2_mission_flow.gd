extends RefCounted
class_name V2MissionFlow

const CheckpointAdapterScript = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")

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
var optional_reward_flags: Dictionary = {}
var evac_route_opened := false
var event_history: Array[Dictionary] = []

var _rescue_character_id := "scout"
var _rescue_entity_id := "rescue_scout"
var _evac_center := Vector2i(-1, -1)
var _evac_radius := 1
var _rescued_units: Array = []
var _positions: Dictionary = {}
var _objective_steps: Array[Dictionary] = []
var _objective_step_index := 0
var _completed_step_ids: Dictionary = {}
var _mission_flags: Dictionary = {}

func setup(mission_data: Dictionary, locked_map: Dictionary, players: Array, enemies: Array) -> void:
	mission = mission_data.duplicate(true)
	map_data = locked_map.duplicate(true)
	player_units = players.duplicate()
	enemy_units = enemies.duplicate()
	state = State.SEARCH_SCOUT
	rescued_characters.clear()
	optional_complete = false
	optional_reward_flags.clear()
	evac_route_opened = false
	event_history.clear()
	_rescued_units.clear()
	_positions.clear()
	_completed_step_ids.clear()
	_mission_flags.clear()
	_objective_step_index = 0
	_evac_center = Vector2i(-1, -1)
	_evac_radius = 1
	_rescue_character_id = String(mission.get("rescue_character", "scout"))
	_objective_steps = _read_objective_steps(mission.get("objective_steps", []))
	if _objective_steps.is_empty():
		_objective_steps = _legacy_m1_steps()
	_find_mission_entities()
	for unit in player_units:
		_remember_unit(unit)

func apply_event(event_name: StringName, payload: Dictionary = {}) -> Dictionary:
	var normalized_event := _normalize_event(event_name)
	var result := {"success": true, "event": event_name, "changed": false}
	if state in [State.COMPLETE, State.FAILED] and event_name not in [&"mission_started", &"evac_checked"]:
		return _finish_event(event_name, _fail(&"mission_finished"))

	var current_step := _current_objective_step()
	if not current_step.is_empty() and normalized_event == StringName(current_step.get("complete_event", "")):
		if event_name == &"evac_checked" and not _all_conscious_players_in_evac():
			return _finish_event(event_name, _fail(&"evac_not_ready"))
		if normalized_event == &"character_rescued":
			var rescue_validation := _validate_rescue(payload)
			if not bool(rescue_validation.get("success", false)):
				return _finish_event(event_name, rescue_validation)
		var progression := _advance_current_step(normalized_event, payload, result)
		if not bool(progression.get("success", false)):
			return _finish_event(event_name, progression)
		if normalized_event == &"character_rescued":
			var character_id := String(payload.get("character_id", _rescue_character_id))
			rescued_characters[character_id] = true
			_register_rescued_unit(payload)
			result["character_id"] = character_id
		if event_name == &"evac_checked":
			# M1's configured final marker is descriptive; reaching evacuation ends it.
			if get_current_step_id() == "evacuate":
				state = State.COMPLETE
			result["victory"] = state == State.COMPLETE
		return _finish_event(event_name, _complete_result(result))

	if _event_already_completed(normalized_event):
		return _finish_event(event_name, _fail(&"event_already_completed"))

	match event_name:
		&"mission_started":
			_mission_flags["mission_started"] = true
			result["changed"] = true
		&"optional_record_uploaded":
			if optional_complete:
				return _finish_event(event_name, _fail(&"optional_already_complete"))
			optional_complete = true
			optional_reward_flags["scout_b"] = true
			_mission_flags["optional_record_uploaded"] = true
			result["changed"] = true
			result["optional_complete"] = true
			result["optional_record_uploaded"] = true
			result["reward_module"] = "scout_b"
			result["unlocked_modules"] = ["scout_b"]
		&"evac_route_opened":
			if evac_route_opened:
				result["route_already_open"] = true
			else:
				evac_route_opened = true
				_mission_flags["evac_route_opened"] = true
				result["changed"] = true
				result["evac_route_opened"] = true
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
			result["victory"] = false
			result["reason"] = &"rescue_required" if state == State.SEARCH_SCOUT else &"evac_not_ready"
		&"primary_irreversible_failure":
			state = State.FAILED
			result["changed"] = true
			result["defeat"] = true
		_:
			return _finish_event(event_name, _fail(&"unknown_event"))

	return _finish_event(event_name, _complete_result(result))

func get_state() -> State:
	return state

func get_state_name() -> StringName:
	if state == State.COMPLETE or state == State.FAILED:
		return STATE_NAMES.get(state, &"SEARCH_SCOUT")
	# Existing M1 callers still consume the original two state labels.
	return &"SEARCH_SCOUT" if _objective_step_index == 0 else &"ESCORT_TO_EVAC"

func get_current_step_id() -> String:
	return String(_current_objective_step().get("id", ""))

func get_objective_step_index() -> int:
	return _objective_step_index

func get_objective_step_count() -> int:
	return _objective_steps.size()

func get_primary_text() -> String:
	if state == State.COMPLETE:
		return "侦察兵已撤离" if _rescue_character_id == "scout" else "任务已完成"
	if state == State.FAILED:
		return "小队已失能"
	return String(_current_objective_step().get("objective_text", mission.get("primary", "")))

func get_current_guide_text() -> String:
	if state == State.COMPLETE:
		return "任务完成：小队已进入撤离区，系统正在打开结算。"
	if state == State.FAILED:
		return "任务失败：重新开始后完成当前任务目标。"
	return String(_current_objective_step().get("guide_text", ""))

func get_guide_text() -> String:
	return get_current_guide_text()

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
		"step_id": get_current_step_id(),
		"step_index": _objective_step_index,
		"step_count": get_objective_step_count(),
		"primary_text": get_primary_text(),
		"guide_text": get_current_guide_text(),
		"completed_step_ids": _completed_step_ids.duplicate(true),
		"mission_flags": _mission_flags.duplicate(true),
		"rescued_characters": rescued_characters.duplicate(true),
		"optional_complete": optional_complete,
		"optional_reward_flags": optional_reward_flags.duplicate(true),
		"evac_route_opened": evac_route_opened,
		"evac_center": _evac_center,
		"evac_radius": _evac_radius,
		"event_count": event_history.size(),
	}

func restore_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {"success": false, "reason": &"empty_snapshot"}
	var restored_state := _state_from_name(String(snapshot.get("state", "SEARCH_SCOUT")))
	if restored_state < 0:
		return {"success": false, "reason": &"unknown_state"}
	var restored_index := int(snapshot.get("step_index", -1))
	if restored_index < 0:
		restored_index = _step_index_for_id(String(snapshot.get("step_id", "")))
	if restored_index < 0:
		restored_index = 0 if restored_state == State.SEARCH_SCOUT else mini(1, _objective_steps.size() - 1)
	if restored_index >= _objective_steps.size():
		return {"success": false, "reason": &"unknown_step"}
	state = restored_state
	_objective_step_index = restored_index
	_completed_step_ids = (snapshot.get("completed_step_ids", {}) as Dictionary).duplicate(true)
	_mission_flags = (snapshot.get("mission_flags", {}) as Dictionary).duplicate(true)
	rescued_characters = (snapshot.get("rescued_characters", {}) as Dictionary).duplicate(true)
	optional_complete = bool(snapshot.get("optional_complete", false))
	optional_reward_flags = (snapshot.get("optional_reward_flags", {}) as Dictionary).duplicate(true)
	evac_route_opened = bool(snapshot.get("evac_route_opened", false))
	return {"success": true, "state": get_state_name(), "step_id": get_current_step_id(), "step_index": _objective_step_index, "step_count": get_objective_step_count()}

func get_retry_actions(has_checkpoint: bool) -> Array[StringName]:
	return CheckpointAdapterScript.get_retry_actions(has_checkpoint)

func _read_objective_steps(raw_steps: Variant) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if not raw_steps is Array:
		return steps
	for raw_step in raw_steps:
		if not raw_step is Dictionary:
			continue
		var step: Dictionary = raw_step.duplicate(true)
		if String(step.get("id", "")).is_empty() or String(step.get("complete_event", "")).is_empty():
			continue
		step["required_flags"] = step.get("required_flags", []).duplicate() if step.get("required_flags", []) is Array else []
		steps.append(step)
	return steps

func _legacy_m1_steps() -> Array[Dictionary]:
	return [
		{
			"id": "search_scout",
			"objective_text": "找到失联侦察兵",
			"guide_text": "流程 1/2：前往青色侦察标记并点击营救；终点是地图右上方绿色菱形撤离点。",
			"complete_event": "character_rescued",
			"checkpoint_id": "cp_rescue",
			"required_flags": [],
		},
		{
			"id": "escort_scout",
			"objective_text": "带侦察兵抵达撤离点",
			"guide_text": "流程 2/2：前往地图右上方绿色菱形撤离点；两名队员进入后自动完成。",
			"complete_event": "evac_checked",
			"checkpoint_id": "cp_pre_evac",
			"required_flags": ["scout_rescued"],
		},
	]

func _current_objective_step() -> Dictionary:
	if _objective_step_index < 0 or _objective_step_index >= _objective_steps.size():
		return {}
	return _objective_steps[_objective_step_index]

func _normalize_event(event_name: StringName) -> StringName:
	return &"character_rescued" if event_name == &"scout_rescued" else event_name

func _advance_current_step(event_name: StringName, payload: Dictionary, result: Dictionary) -> Dictionary:
	var step := _current_objective_step()
	if step.is_empty() or event_name != StringName(step.get("complete_event", "")):
		return _fail(&"unknown_event")
	if not _required_flags_satisfied(step):
		return _fail(&"required_flags_unsatisfied")
	_record_payload_flags(payload)
	var completed_step_id := String(step.get("id", ""))
	_completed_step_ids[completed_step_id] = true
	_mission_flags[completed_step_id] = true
	_mission_flags[String(event_name)] = true
	if event_name == &"character_rescued":
		var character_id := String(payload.get("character_id", _rescue_character_id))
		_mission_flags["%s_rescued" % character_id] = true
		if character_id == "scout":
			_mission_flags["scout_rescued"] = true
	var checkpoint_id := StringName(step.get("checkpoint_id", ""))
	if _objective_step_index < _objective_steps.size() - 1:
		_objective_step_index += 1
	else:
		state = State.COMPLETE
	result["changed"] = true
	result["checkpoint_id"] = checkpoint_id
	return result

func _required_flags_satisfied(step: Dictionary) -> bool:
	for raw_flag in step.get("required_flags", []):
		if not bool(_mission_flags.get(String(raw_flag), false)):
			return false
	return true

func _record_payload_flags(payload: Dictionary) -> void:
	for key in ["flags", "set_flags"]:
		var raw_flags: Variant = payload.get(key, {})
		if raw_flags is Dictionary:
			for raw_flag in raw_flags:
				_mission_flags[String(raw_flag)] = bool(raw_flags[raw_flag])
		elif raw_flags is Array:
			for raw_flag in raw_flags:
				_mission_flags[String(raw_flag)] = true
	var flag := String(payload.get("flag", ""))
	if not flag.is_empty():
		_mission_flags[flag] = true

func _validate_rescue(payload: Dictionary) -> Dictionary:
	var character_id := String(payload.get("character_id", _rescue_character_id))
	if not _rescue_character_id.is_empty() and character_id != _rescue_character_id:
		return _fail(&"wrong_rescue_character")
	return {"success": true}

func _event_already_completed(event_name: StringName) -> bool:
	for raw_step in _objective_steps:
		var step: Dictionary = raw_step
		if StringName(step.get("complete_event", "")) == event_name and bool(_completed_step_ids.get(String(step.get("id", "")), false)):
			return true
	return false

func _complete_result(result: Dictionary) -> Dictionary:
	result["state"] = get_state_name()
	result["step_id"] = get_current_step_id()
	result["step_index"] = get_objective_step_index()
	result["step_count"] = get_objective_step_count()
	result["guide_text"] = get_current_guide_text()
	result["victory"] = state == State.COMPLETE
	result["defeat"] = state == State.FAILED
	return result

func _state_from_name(state_name: String) -> int:
	for candidate in STATE_NAMES.keys():
		if String(STATE_NAMES[candidate]) == state_name:
			return int(candidate)
	return -1

func _step_index_for_id(step_id: String) -> int:
	for index in _objective_steps.size():
		if String(_objective_steps[index].get("id", "")) == step_id:
			return index
	return -1

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
	return _complete_result({"success": false, "changed": false, "reason": reason})

func _finish_event(event_name: StringName, result: Dictionary) -> Dictionary:
	_complete_result(result)
	event_history.append({"event": event_name, "state": get_state_name(), "step_id": get_current_step_id()})
	state_changed.emit(get_state_name(), result)
	return result
