extends RefCounted
class_name V2EncounterActivation

var _map_data: Dictionary = {}
var _encounters: Array = []
var _enemy_entities: Dictionary = {}
var _active_ids: Dictionary = {}
var _triggered_ids: Dictionary = {}
var _started := false

func setup(map_data: Dictionary) -> void:
	_map_data = map_data.duplicate(true)
	_encounters = (_map_data.get("encounters", []) as Array).duplicate(true)
	_enemy_entities.clear()
	_active_ids.clear()
	_triggered_ids.clear()
	_started = false
	for raw_entity in _map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		if String(entity.get("type", "")) == "spawn_enemy":
			_enemy_entities[String(entity.get("id", ""))] = entity.duplicate(true)

func update(player_positions: Array, mission_events: Array) -> Dictionary:
	var activated: Array[String] = []
	var deactivated: Array[String] = []
	if not _started:
		_started = true
		for encounter in _encounters:
			if String(encounter.get("trigger", "")) == "start":
				_apply_encounter(encounter, activated, deactivated)
				break
	for encounter in _encounters:
		var encounter_id := String(encounter.get("id", ""))
		if encounter_id.is_empty() or _triggered_ids.has(encounter_id):
			continue
		if _matches_trigger(encounter, player_positions, mission_events):
			_apply_encounter(encounter, activated, deactivated)
	return {
		"success": true,
		"activated_ids": activated,
		"deactivated_ids": deactivated,
		"active_ids": get_active_enemy_ids(),
		"active_count": _active_ids.size(),
	}

func get_total_enemy_ids() -> Array:
	var result: Array = _enemy_entities.keys()
	result.sort()
	return result

func get_active_enemy_ids() -> Array:
	var result: Array = _active_ids.keys()
	result.sort()
	return result

func is_active(entity_id: String) -> bool:
	return _active_ids.has(entity_id)

func get_enemy_entity(entity_id: String) -> Dictionary:
	return (_enemy_entities.get(entity_id, {}) as Dictionary).duplicate(true)

func _apply_encounter(encounter: Dictionary, activated: Array[String], deactivated: Array[String]) -> void:
	var encounter_id := String(encounter.get("id", ""))
	if encounter_id.is_empty():
		return
	_triggered_ids[encounter_id] = true
	var desired: Dictionary = {}
	for raw_id in encounter.get("active_enemy_ids", []):
		desired[String(raw_id)] = true
	var previous: Dictionary = _active_ids.duplicate(true)
	_active_ids = desired
	for raw_id in previous.keys():
		var id := String(raw_id)
		if not _active_ids.has(id):
			deactivated.append(id)
	for raw_id in _active_ids.keys():
		var id := String(raw_id)
		if not previous.has(id):
			activated.append(id)
	# The map contract must never activate more than the encounter cap. If a
	# malformed content update exceeds it, keep the stable lowest IDs active.
	var cap := int(encounter.get("active_cap", 3))
	if cap >= 0 and _active_ids.size() > cap:
		var ids := get_active_enemy_ids()
		for i in range(cap, ids.size()):
			var overflow_id: String = ids[i]
			_active_ids.erase(overflow_id)
			if not deactivated.has(overflow_id):
				deactivated.append(overflow_id)
			if activated.has(overflow_id):
				activated.erase(overflow_id)

func _matches_trigger(encounter: Dictionary, player_positions: Array, mission_events: Array) -> bool:
	var trigger := String(encounter.get("trigger", ""))
	if trigger == "start":
		return false
	for raw_event in mission_events:
		var event_name := String(raw_event.get("event", "")) if raw_event is Dictionary else String(raw_event)
		if event_name == trigger:
			return true
	if trigger == "enter_rescue_radius":
		return _any_position_in_radius(player_positions, encounter)
	if trigger == "enter_record_radius":
		return _any_position_in_radius(player_positions, encounter)
	if trigger == "pre_evac":
		return _any_position_on_cells(player_positions, encounter.get("trigger_cells", []))
	return false

func _any_position_in_radius(player_positions: Array, encounter: Dictionary) -> bool:
	var center := _parse_cell(encounter.get("center", null))
	if center.x < 0:
		return false
	var radius := maxi(0, int(encounter.get("radius", 0)))
	for raw_position in player_positions:
		var position := _parse_cell(raw_position)
		if position.x >= 0 and absi(position.x - center.x) + absi(position.y - center.y) <= radius:
			return true
	return false

func _any_position_on_cells(player_positions: Array, raw_cells: Array) -> bool:
	for raw_position in player_positions:
		var position := _parse_cell(raw_position)
		for raw_cell in raw_cells:
			if position.x >= 0 and position == _parse_cell(raw_cell):
				return true
	return false

func _parse_cell(raw_cell: Variant) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
	return Vector2i(-1, -1)
