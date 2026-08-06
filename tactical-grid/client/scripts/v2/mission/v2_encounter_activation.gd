extends RefCounted
class_name V2EncounterActivation

const DEFAULT_ACTIVE_CAP := 3

var _map_data: Dictionary = {}
var _encounters: Array = []
var _enemy_entities: Dictionary = {}
var _active_ids: Dictionary = {}
var _waiting_ids: Dictionary = {}
var _defeated_ids: Dictionary = {}
var _departed_ids: Dictionary = {}
var _triggered_ids: Dictionary = {}
var _spawn_candidates: Dictionary = {}
var _retreat_candidates: Dictionary = {}
var _active_spawn_positions: Dictionary = {}
var _last_spawn_failures: Dictionary = {}
var _active_cap := DEFAULT_ACTIVE_CAP
var _started := false

func setup(map_data: Dictionary) -> void:
	_map_data = map_data.duplicate(true)
	_encounters = (_map_data.get("encounters", []) as Array).duplicate(true)
	_enemy_entities.clear()
	_active_ids.clear()
	_waiting_ids.clear()
	_defeated_ids.clear()
	_departed_ids.clear()
	_triggered_ids.clear()
	_spawn_candidates.clear()
	_retreat_candidates.clear()
	_active_spawn_positions.clear()
	_last_spawn_failures.clear()
	_active_cap = DEFAULT_ACTIVE_CAP
	_started = false
	for raw_entity in _map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		if String(entity.get("type", "")) == "spawn_enemy":
			var entity_id := String(entity.get("id", ""))
			if not entity_id.is_empty():
				_enemy_entities[entity_id] = entity.duplicate(true)
	for encounter in _encounters:
		if encounter is Dictionary:
			_register_entry_cells(encounter)

func update(
	player_positions: Array,
	mission_events: Array,
	live_enemy_ids: Array = [],
	occupied_positions: Array = []
) -> Dictionary:
	var activated: Array[String] = []
	var deactivated: Array[String] = []
	_last_spawn_failures.clear()
	var occupied := _cell_set(player_positions)
	for raw_position in occupied_positions:
		var occupied_cell := _parse_cell(raw_position)
		if occupied_cell.x >= 0:
			occupied[occupied_cell] = true
	if not _started:
		_started = true
		for encounter in _encounters:
			if String(encounter.get("trigger", "")) == "start":
				_apply_encounter(encounter, live_enemy_ids, deactivated)
				break
	for encounter in _encounters:
		var encounter_id := String(encounter.get("id", ""))
		if encounter_id.is_empty() or _triggered_ids.has(encounter_id):
			continue
		if _matches_trigger(encounter, player_positions, mission_events):
			_apply_encounter(encounter, live_enemy_ids, deactivated)
	_promote_waiting(occupied, activated)
	return {
		"success": true,
		"activated_ids": activated,
		"deactivated_ids": deactivated,
		"active_ids": get_active_enemy_ids(),
		"waiting_ids": get_waiting_enemy_ids(),
		"defeated_ids": get_defeated_enemy_ids(),
		"departed_ids": get_departed_enemy_ids(),
		"active_count": _active_ids.size(),
		"spawn_cell_occupied": _sorted_ids(_last_spawn_failures.keys()),
		"spawn_failures": _last_spawn_failures.duplicate(true),
	}

func get_total_enemy_ids() -> Array:
	var result: Array = _enemy_entities.keys()
	result.sort()
	return result

func get_active_enemy_ids() -> Array:
	return _sorted_ids(_active_ids.keys())

func get_waiting_enemy_ids() -> Array:
	return _sorted_ids(_waiting_ids.keys())

func get_defeated_enemy_ids() -> Array:
	return _sorted_ids(_defeated_ids.keys())

func get_departed_enemy_ids() -> Array:
	return _sorted_ids(_departed_ids.keys())

func is_active(entity_id: String) -> bool:
	return _active_ids.has(entity_id)

func get_enemy_entity(entity_id: String) -> Dictionary:
	return (_enemy_entities.get(entity_id, {}) as Dictionary).duplicate(true)

func get_spawn_cells(entity_id: String) -> Array:
	var cells: Array = _spawn_candidates.get(entity_id, [])
	if cells.is_empty():
		var entity: Dictionary = get_enemy_entity(entity_id)
		var fallback := _parse_cell(entity)
		if fallback.x >= 0:
			cells.append(fallback)
	return cells.duplicate()

func get_retreat_cells(entity_id: String) -> Array:
	var cells: Array = _retreat_candidates.get(entity_id, [])
	if cells.is_empty():
		var entity: Dictionary = get_enemy_entity(entity_id)
		var fallback := _parse_cell(entity)
		if fallback.x >= 0:
			cells.append(fallback)
	return cells.duplicate()

func mark_enemy_defeated(entity_id: String) -> Dictionary:
	if not _enemy_entities.has(entity_id):
		return {"success": false, "reason": &"unknown_enemy", "entity_id": entity_id}
	if _defeated_ids.has(entity_id):
		return {"success": false, "reason": &"already_defeated", "entity_id": entity_id}
	if _departed_ids.has(entity_id):
		return {"success": false, "reason": &"already_departed", "entity_id": entity_id}
	var was_active := _active_ids.has(entity_id)
	_move_to_state(entity_id, _defeated_ids)
	return {
		"success": true,
		"entity_id": entity_id,
		"was_active": was_active,
		"reason": &"enemy_defeated",
	}

func mark_enemy_departed(entity_id: String) -> Dictionary:
	if not _enemy_entities.has(entity_id):
		return {"success": false, "reason": &"unknown_enemy", "entity_id": entity_id}
	if _departed_ids.has(entity_id):
		return {"success": false, "reason": &"already_departed", "entity_id": entity_id}
	if _defeated_ids.has(entity_id):
		return {"success": false, "reason": &"already_defeated", "entity_id": entity_id}
	var was_active := _active_ids.has(entity_id)
	_move_to_state(entity_id, _departed_ids)
	return {
		"success": true,
		"entity_id": entity_id,
		"was_active": was_active,
		"reason": &"enemy_departed",
	}

func defer_enemy_spawn(entity_id: String, reason: StringName = &"spawn_cell_occupied") -> Dictionary:
	if not _active_ids.has(entity_id):
		return {"success": false, "reason": &"enemy_not_active", "entity_id": entity_id}
	_move_to_state(entity_id, _waiting_ids)
	_last_spawn_failures[entity_id] = reason
	return {"success": true, "reason": reason, "entity_id": entity_id}

func get_snapshot() -> Dictionary:
	return {
		"active_ids": get_active_enemy_ids(),
		"active_enemy_ids": get_active_enemy_ids(),
		"waiting_ids": get_waiting_enemy_ids(),
		"waiting_enemy_ids": get_waiting_enemy_ids(),
		"defeated_ids": get_defeated_enemy_ids(),
		"defeated_enemy_ids": get_defeated_enemy_ids(),
		"departed_ids": get_departed_enemy_ids(),
		"departed_enemy_ids": get_departed_enemy_ids(),
		"triggered_ids": _sorted_ids(_triggered_ids.keys()),
		"active_cap": _active_cap,
		"started": _started,
		"spawn_positions": _serialize_cell_map(_active_spawn_positions),
	}

func restore_snapshot(snapshot: Dictionary) -> Dictionary:
	var active := _ids_from_snapshot(snapshot, "active_ids", "active_enemy_ids")
	var waiting := _ids_from_snapshot(snapshot, "waiting_ids", "waiting_enemy_ids")
	var defeated := _ids_from_snapshot(snapshot, "defeated_ids", "defeated_enemy_ids")
	var departed := _ids_from_snapshot(snapshot, "departed_ids", "departed_enemy_ids")
	var seen: Dictionary = {}
	for bucket in [active, waiting, defeated, departed]:
		for entity_id in bucket:
			if not _enemy_entities.has(entity_id):
				return {"success": false, "reason": &"unknown_enemy", "entity_id": entity_id}
			if seen.has(entity_id):
				return {"success": false, "reason": &"state_sets_overlap", "entity_id": entity_id}
			seen[entity_id] = true
	_active_ids.clear()
	_waiting_ids.clear()
	_defeated_ids.clear()
	_departed_ids.clear()
	for entity_id in active:
		_active_ids[entity_id] = true
	for entity_id in waiting:
		_waiting_ids[entity_id] = true
	for entity_id in defeated:
		_defeated_ids[entity_id] = true
	for entity_id in departed:
		_departed_ids[entity_id] = true
	_triggered_ids.clear()
	for raw_id in snapshot.get("triggered_ids", []):
		_triggered_ids[String(raw_id)] = true
	_active_cap = maxi(0, int(snapshot.get("active_cap", DEFAULT_ACTIVE_CAP)))
	_started = bool(snapshot.get("started", true))
	_active_spawn_positions = _deserialize_cell_map(snapshot.get("spawn_positions", {}))
	return {"success": true, "reason": &"snapshot_restored"}

func _apply_encounter(encounter: Dictionary, live_enemy_ids: Array, deactivated: Array[String]) -> void:
	var encounter_id := String(encounter.get("id", ""))
	if encounter_id.is_empty():
		return
	_triggered_ids[encounter_id] = true
	_active_cap = maxi(0, int(encounter.get("active_cap", DEFAULT_ACTIVE_CAP)))
	_register_entry_cells(encounter)
	var protected: Dictionary = {}
	if not live_enemy_ids.is_empty():
		for raw_id in live_enemy_ids:
			protected[String(raw_id)] = true
	else:
		# Legacy callers do not provide live IDs. An encounter without an explicit
		# retreat list still treats its current active units as live.
		if encounter.get("deactivate_on_trigger", []).is_empty():
			for raw_id in _active_ids.keys():
				protected[String(raw_id)] = true
	for raw_id in encounter.get("deactivate_on_trigger", []):
		var departing_id := String(raw_id)
		if protected.has(departing_id):
			continue
		if _active_ids.has(departing_id) or _waiting_ids.has(departing_id):
			var was_active := _active_ids.has(departing_id)
			_move_to_state(departing_id, _departed_ids)
			if was_active and not deactivated.has(departing_id):
				deactivated.append(departing_id)
	for raw_id in encounter.get("active_enemy_ids", []):
		var entity_id := String(raw_id)
		if not _enemy_entities.has(entity_id) or _defeated_ids.has(entity_id) or _departed_ids.has(entity_id):
			continue
		if not _active_ids.has(entity_id) and not _waiting_ids.has(entity_id):
			_waiting_ids[entity_id] = true

func _promote_waiting(occupied: Dictionary, activated: Array[String]) -> void:
	for entity_id in get_waiting_enemy_ids():
		if _active_ids.size() >= _active_cap:
			break
		var spawn_cell := _choose_spawn_cell(entity_id, occupied)
		if spawn_cell.x < 0:
			_last_spawn_failures[entity_id] = &"spawn_cell_occupied"
			continue
		_move_to_state(entity_id, _active_ids)
		_active_spawn_positions[entity_id] = spawn_cell
		occupied[spawn_cell] = true
		activated.append(entity_id)

func _choose_spawn_cell(entity_id: String, occupied: Dictionary) -> Vector2i:
	for raw_cell in get_spawn_cells(entity_id):
		var cell := _parse_cell(raw_cell)
		if cell.x < 0 or occupied.has(cell):
			continue
		return cell
	return Vector2i(-1, -1)

func _register_entry_cells(encounter: Dictionary) -> void:
	var ids: Array = encounter.get("active_enemy_ids", [])
	_register_cells_for_ids(ids, encounter.get("spawn_cells", null), _spawn_candidates)
	_register_cells_for_ids(ids, encounter.get("retreat_cells", null), _retreat_candidates)
	for raw_id in ids:
		var entity_id := String(raw_id)
		var entity: Dictionary = get_enemy_entity(entity_id)
		if not _spawn_candidates.has(entity_id):
			_register_cells_for_ids([entity_id], entity.get("spawn_cells", null), _spawn_candidates)
		if not _retreat_candidates.has(entity_id):
			_register_cells_for_ids([entity_id], entity.get("retreat_cells", null), _retreat_candidates)

func _register_cells_for_ids(ids: Array, raw_cells: Variant, target: Dictionary) -> void:
	if raw_cells == null or ids.is_empty():
		return
	for index in range(ids.size()):
		var entity_id := String(ids[index])
		var value: Variant = raw_cells
		if raw_cells is Dictionary:
			if not raw_cells.has(entity_id):
				continue
			value = raw_cells.get(entity_id)
		elif raw_cells is Array and not _looks_like_cell(raw_cells):
			if raw_cells.size() == ids.size() and index < raw_cells.size() and _looks_like_cell(raw_cells[index]):
				value = raw_cells[index]
		var cells := _parse_cells(value)
		if not cells.is_empty():
			target[entity_id] = cells

func _move_to_state(entity_id: String, target: Dictionary) -> void:
	_active_ids.erase(entity_id)
	_waiting_ids.erase(entity_id)
	_defeated_ids.erase(entity_id)
	_departed_ids.erase(entity_id)
	_active_spawn_positions.erase(entity_id)
	target[entity_id] = true

func _ids_from_snapshot(snapshot: Dictionary, primary: String, legacy: String) -> Array[String]:
	var source: Variant = snapshot.get(primary, snapshot.get(legacy, []))
	var ids: Array[String] = []
	if source is Array:
		for raw_id in source:
			var entity_id := String(raw_id)
			if not entity_id.is_empty() and not ids.has(entity_id):
				ids.append(entity_id)
	return ids

func _sorted_ids(raw_ids: Array) -> Array:
	var ids: Array = []
	for raw_id in raw_ids:
		ids.append(String(raw_id))
	ids.sort()
	return ids

func _cell_set(raw_cells: Array) -> Dictionary:
	var cells: Dictionary = {}
	for raw_cell in raw_cells:
		var cell := _parse_cell(raw_cell)
		if cell.x >= 0:
			cells[cell] = true
	return cells

func _serialize_cell_map(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_id in source.keys():
		var cell := _parse_cell(source[raw_id])
		if cell.x >= 0:
			result[String(raw_id)] = [cell.x, cell.y]
	return result

func _deserialize_cell_map(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not source is Dictionary:
		return result
	for raw_id in source.keys():
		var cell := _parse_cell(source[raw_id])
		if cell.x >= 0:
			result[String(raw_id)] = cell
	return result

func _parse_cells(raw_cells: Variant) -> Array:
	var cells: Array = []
	if _looks_like_cell(raw_cells):
		var cell := _parse_cell(raw_cells)
		if cell.x >= 0:
			cells.append(cell)
		return cells
	if raw_cells is Array:
		for raw_cell in raw_cells:
			var cell := _parse_cell(raw_cell)
			if cell.x >= 0:
				cells.append(cell)
	return cells

func _looks_like_cell(raw_cell: Variant) -> bool:
	if raw_cell is Vector2i:
		return true
	if raw_cell is Dictionary:
		return raw_cell.has("x") and raw_cell.has("y")
	if raw_cell is Array:
		return raw_cell.size() >= 2 and (raw_cell[0] is int or raw_cell[0] is float)
	return false

func _matches_trigger(encounter: Dictionary, player_positions: Array, mission_events: Array) -> bool:
	var trigger := String(encounter.get("trigger", ""))
	if trigger == "start":
		return false
	for raw_event in mission_events:
		var event_name := String(raw_event.get("event", "")) if raw_event is Dictionary else String(raw_event)
		if event_name == trigger:
			return true
	if trigger == "enter_rescue_radius" or trigger == "enter_record_radius":
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
