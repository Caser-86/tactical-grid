extends RefCounted
class_name V2HazardController

var _hazards_by_id: Dictionary = {}
var _hazard_order: Array[String] = []
var _closed_ids: Dictionary = {}
var _resolved_damage_keys: Dictionary = {}
var _map_size := Vector2i.ZERO
var _last_turn := 0

func setup(hazard_data: Array, map_size: Vector2i) -> void:
	_hazards_by_id.clear()
	_hazard_order.clear()
	_closed_ids.clear()
	_resolved_damage_keys.clear()
	_map_size = map_size
	_last_turn = 0
	for raw_hazard in hazard_data:
		if not raw_hazard is Dictionary:
			continue
		var hazard := _normalize_hazard(raw_hazard)
		var hazard_id := String(hazard.get("id", ""))
		if hazard_id.is_empty() or (hazard.get("cells", []) as Array).is_empty():
			continue
		_hazards_by_id[hazard_id] = hazard
		_hazard_order.append(hazard_id)
	_hazard_order.sort()

func advance_player_turn(turn: int) -> Dictionary:
	_last_turn = maxi(_last_turn, turn)
	var warning_cells: Array[Vector2i] = []
	var active_cells: Array[Vector2i] = []
	var cycle: Dictionary = {}
	for hazard_id in _hazard_order:
		if _closed_ids.has(hazard_id):
			continue
		var hazard: Dictionary = _hazards_by_id[hazard_id]
		var cycle_index := _cycle_index_for_turn(hazard, turn)
		if cycle_index >= 0:
			cycle[hazard_id] = cycle_index
		if _is_warning_turn(hazard, turn):
			for cell in hazard.get("cells", []):
				if not warning_cells.has(cell):
					warning_cells.append(cell)
		if _is_damage_turn(hazard, turn):
			for cell in hazard.get("cells", []):
				if not active_cells.has(cell):
					active_cells.append(cell)
	return {
		"warning_cells": warning_cells,
		"active_cells": active_cells,
		"damage_events": [],
		"closed": _sorted_ids(_closed_ids.keys()),
		"cycle": cycle,
	}

func consume_enemy_phase_damage(turn: int) -> Array:
	_last_turn = maxi(_last_turn, turn)
	var damage_events: Array[Dictionary] = []
	for hazard_id in _hazard_order:
		if _closed_ids.has(hazard_id):
			continue
		var hazard: Dictionary = _hazards_by_id[hazard_id]
		if not _is_damage_turn(hazard, turn):
			continue
		var cycle_index := _cycle_index_for_turn(hazard, turn)
		var damage_key := "%s:%d" % [hazard_id, cycle_index]
		if _resolved_damage_keys.has(damage_key):
			continue
		_resolved_damage_keys[damage_key] = true
		damage_events.append({
			"hazard_id": hazard_id,
			"cells": (hazard.get("cells", []) as Array).duplicate(),
			"damage": int(hazard.get("damage", 0)),
			"turn": turn,
			"cycle": cycle_index,
		})
	return damage_events

func commit_close_action(action_id: String) -> Dictionary:
	if action_id.is_empty():
		return {"success": false, "reason": &"unknown_close_action", "closed": _sorted_ids(_closed_ids.keys())}
	var closed_now: Array[String] = []
	for hazard_id in _hazard_order:
		var hazard: Dictionary = _hazards_by_id[hazard_id]
		if String(hazard.get("close_action_id", "")) != action_id:
			continue
		_closed_ids[hazard_id] = true
		closed_now.append(hazard_id)
	if closed_now.is_empty():
		return {"success": false, "reason": &"unknown_close_action", "closed": _sorted_ids(_closed_ids.keys())}
	return {"success": true, "closed": _sorted_ids(_closed_ids.keys()), "closed_now": closed_now}

func get_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"closed_ids": _closed_ids.duplicate(true),
		"resolved_damage_keys": _resolved_damage_keys.duplicate(true),
		"last_turn": _last_turn,
	}

func restore_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {"success": true, "reason": &"empty_hazard_snapshot"}
	var next_closed := _bool_set_from_snapshot(snapshot.get("closed_ids", {}))
	for hazard_id in next_closed.keys():
		if not _hazards_by_id.has(String(hazard_id)):
			return {"success": false, "reason": &"unknown_hazard", "hazard_id": String(hazard_id)}
	var next_resolved := _bool_set_from_snapshot(snapshot.get("resolved_damage_keys", {}))
	for raw_key in next_resolved.keys():
		var key := String(raw_key)
		var parts := key.split(":")
		if parts.is_empty() or not _hazards_by_id.has(parts[0]):
			return {"success": false, "reason": &"unknown_hazard_damage_key", "hazard_key": key}
	_closed_ids = next_closed
	_resolved_damage_keys = next_resolved
	_last_turn = maxi(0, int(snapshot.get("last_turn", 0)))
	return {"success": true, "reason": &"snapshot_restored"}

func _normalize_hazard(raw_hazard: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	for raw_cell in raw_hazard.get("cells", []):
		var cell := _parse_cell(raw_cell)
		if _is_in_bounds(cell) and not cells.has(cell):
			cells.append(cell)
	return {
		"id": String(raw_hazard.get("id", "")),
		"cells": cells,
		"warning_turn": int(raw_hazard.get("warning_turn", raw_hazard.get("start_turn", 0))),
		"damage_turn": int(raw_hazard.get("damage_turn", raw_hazard.get("active_turn", 0))),
		"cycle_length": maxi(0, int(raw_hazard.get("cycle_length", raw_hazard.get("cycle", 0)))),
		"damage": int(raw_hazard.get("damage", 0)),
		"close_action_id": String(raw_hazard.get("close_action_id", "")),
	}

func _is_warning_turn(hazard: Dictionary, turn: int) -> bool:
	return _turn_matches(int(hazard.get("warning_turn", 0)), int(hazard.get("cycle_length", 0)), turn)

func _is_damage_turn(hazard: Dictionary, turn: int) -> bool:
	return _turn_matches(int(hazard.get("damage_turn", 0)), int(hazard.get("cycle_length", 0)), turn)

func _turn_matches(start_turn: int, cycle_length: int, turn: int) -> bool:
	if start_turn <= 0:
		return false
	if cycle_length <= 0:
		return turn == start_turn
	return turn >= start_turn and (turn - start_turn) % cycle_length == 0

func _cycle_index_for_turn(hazard: Dictionary, turn: int) -> int:
	var warning_turn := int(hazard.get("warning_turn", 0))
	var damage_turn := int(hazard.get("damage_turn", 0))
	var cycle_length := int(hazard.get("cycle_length", 0))
	var anchor := mini(warning_turn, damage_turn) if warning_turn > 0 and damage_turn > 0 else maxi(warning_turn, damage_turn)
	if anchor <= 0 or turn < anchor:
		return -1
	if cycle_length <= 0:
		return 0
	return int(floor(float(turn - anchor) / float(cycle_length)))

func _parse_cell(raw_cell: Variant) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Vector2:
		return Vector2i(raw_cell)
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
	return Vector2i(-1, -1)

func _is_in_bounds(cell: Vector2i) -> bool:
	return _map_size.x <= 0 or _map_size.y <= 0 or (cell.x >= 0 and cell.x < _map_size.x and cell.y >= 0 and cell.y < _map_size.y)

func _bool_set_from_snapshot(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if source is Dictionary:
		for raw_key in (source as Dictionary).keys():
			if bool((source as Dictionary).get(raw_key, false)):
				result[String(raw_key)] = true
	elif source is Array:
		for raw_key in source:
			result[String(raw_key)] = true
	return result

func _sorted_ids(raw_ids: Array) -> Array:
	var ids: Array = []
	for raw_id in raw_ids:
		ids.append(String(raw_id))
	ids.sort()
	return ids
