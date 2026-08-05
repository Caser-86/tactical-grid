## Visibility memory system
## Tracks per-cell visibility state: unexplored, recorded, observed.
## Provides last-known position snapshots for enemies that have left sight.
## Information is a tactical resource, not a cosmetic fog overlay.
extends Node
class_name VisibilityState

## Cell state constants
const STATE_UNEXPLORED := &"unexplored"
const STATE_RECORDED := &"recorded"
const STATE_OBSERVED := &"observed"

## CH1-040: Render state constants consumed by VisibilityRenderer.
## RENDER_HIDDEN  -> unexplored: solid black overlay.
## RENDER_DIMMED  -> recorded: desaturated/dimmed terrain overlay.
## RENDER_VISIBLE -> observed: no overlay, real-time units and facilities shown.
const RENDER_HIDDEN := &"hidden"
const RENDER_DIMMED := &"dimmed"
const RENDER_VISIBLE := &"visible"

## CH1-040: Last-known snapshots become "uncertain" after this many turns.
const UNCERTAINTY_TURN_THRESHOLD := 1

var _width: int = 0
var _height: int = 0
## Per-cell state: Vector2i -> StringName
var _cell_states: Dictionary = {}
## Last-known enemy data: entity_id -> {pos, hp, turn_seen, uncertain, ...}
var _last_known: Dictionary = {}
## Enemies currently observed this turn: entity_id -> true
var _observed_enemies: Dictionary = {}
## Enemies newly revealed this turn (not seen last turn): entity_id -> true
var _newly_revealed: Dictionary = {}
## Enemies observed last turn (for newly-revealed computation)
var _previously_observed: Dictionary = {}
## CH1-040: Current turn counter, advanced each update_visibility call.
var _current_turn: int = 0
## CH1-040: Camera zones: zone_id -> Array[Vector2i].
## Cells covered by an active camera zone stay observed until the zone is removed.
var _camera_zones: Dictionary = {}
## Summary of the latest visibility transaction for immediate HUD feedback.
var _last_update_summary: Dictionary = {}


## Initialize for a map of the given dimensions.
func setup(width: int, height: int) -> void:
	_width = width
	_height = height
	_cell_states.clear()
	_last_known.clear()
	_observed_enemies.clear()
	_newly_revealed.clear()
	_previously_observed.clear()
	_current_turn = 0
	_camera_zones.clear()
	_last_update_summary.clear()


## CH1-040: Advance the internal turn counter. Called by the battle controller
## at the start of each player action phase, before update_visibility.
func set_turn(turn: int) -> void:
	_current_turn = maxi(0, turn)


## Update visibility from the current player sight.
## visible_cells: cells currently in sight of any player unit.
## visible_enemies: array of dictionaries with at least {entity_id, pos, hp}.
func update_visibility(visible_cells: Array[Vector2i], visible_enemies: Array) -> Dictionary:
	var newly_observed_cells := 0
	# Demote previously observed cells to recorded (unless covered by a camera zone)
	for cell in _cell_states.keys():
		if _cell_states[cell] == STATE_OBSERVED:
			if not _is_in_camera_zone(cell):
				_cell_states[cell] = STATE_RECORDED

	# Mark currently visible cells as observed
	for cell in visible_cells:
		# Count only unexplored -> observed transitions as new exploration.
		# Recorded -> observed is a refreshed sightline, not new map knowledge.
		if get_cell_state(cell) == STATE_UNEXPLORED:
			newly_observed_cells += 1
		_cell_states[cell] = STATE_OBSERVED

	# Re-assert camera zone cells as observed (camera keeps them lit)
	for zone_id in _camera_zones.keys():
		for cell in _camera_zones[zone_id]:
			if _is_in_bounds(cell):
				_cell_states[cell] = STATE_OBSERVED

	# Track newly revealed enemies: those visible now but not last turn
	_newly_revealed.clear()
	for enemy_data in visible_enemies:
		var eid: String = String(enemy_data.get("entity_id", ""))
		if eid == "":
			continue
		_observed_enemies[eid] = true
		# Store last-known snapshot with turn stamp and uncertainty flag.
		# While observed, the snapshot is certain (uncertain=false). Once the
		# enemy leaves sight, _mark_stale_last_known() flips uncertain=true.
		var snapshot: Dictionary = enemy_data.duplicate(true)
		snapshot["turn_seen"] = _current_turn
		snapshot["uncertain"] = false
		_last_known[eid] = snapshot
		if not _previously_observed.has(eid):
			_newly_revealed[eid] = true

	# Remove enemies no longer visible from observed set, and mark their
	# last-known snapshot as uncertain (stale) so the renderer can show a "?".
	var to_remove: Array = []
	for eid in _observed_enemies.keys():
		var still_visible := false
		for enemy_data in visible_enemies:
			if String(enemy_data.get("entity_id", "")) == eid:
				still_visible = true
				break
		if not still_visible:
			to_remove.append(eid)
	for eid in to_remove:
		_observed_enemies.erase(eid)
		_mark_stale_last_known(eid)

	# Remember currently observed for next turn's newly-revealed check
	_previously_observed = _observed_enemies.duplicate(true)
	var observed_enemy_ids: Array = _observed_enemies.keys()
	observed_enemy_ids.sort()
	_last_update_summary = {
		"newly_observed_cells": newly_observed_cells,
		"newly_revealed_enemies": _newly_revealed.size(),
		"observed_enemy_ids": observed_enemy_ids,
		"turn": _current_turn,
	}
	return _last_update_summary.duplicate(true)

## Return the result of the most recent visibility transaction without
## recomputing sight. BattleController uses this to render immediate feedback.
func get_last_update_summary() -> Dictionary:
	return _last_update_summary.duplicate(true)


## CH1-040: Mark a last-known snapshot as uncertain (stale) once the enemy
## leaves sight. Real-time HP/position are no longer reliable from this point.
func _mark_stale_last_known(entity_id: String) -> void:
	if not _last_known.has(entity_id):
		return
	var snapshot: Dictionary = _last_known[entity_id]
	snapshot["uncertain"] = true
	snapshot["turn_seen"] = _current_turn


## Get the visibility state of a cell.
func get_cell_state(cell: Vector2i) -> StringName:
	if _cell_states.has(cell):
		return _cell_states[cell]
	return STATE_UNEXPLORED


## Check if a cell is currently observed (in active sight).
func is_cell_observed(cell: Vector2i) -> bool:
	return get_cell_state(cell) == STATE_OBSERVED


## Check if an enemy is currently observed.
func is_enemy_observed(entity_id: String) -> bool:
	return _observed_enemies.has(entity_id)


## Check if an enemy was first revealed this turn.
func is_newly_revealed(entity_id: String) -> bool:
	return _newly_revealed.has(entity_id)


## Get last-known data for an enemy that has been seen at least once.
## Returns empty dict if never seen.
func get_last_known(entity_id: String) -> Dictionary:
	return _last_known.get(entity_id, {})


## Get all currently observed enemy IDs.
func get_observed_enemies() -> Dictionary:
	return _observed_enemies.duplicate(true)


## Get all last-known enemy snapshots (including those no longer visible).
func get_all_last_known() -> Dictionary:
	return _last_known.duplicate(true)


## CH1-040: Register a persistent camera observation zone.
## Cells in the zone stay observed across turns until remove_camera_zone() is
## called. Used by camera-takeover facilities: while the camera is active the
## area stays lit; when the camera is disabled the zone is removed and cells
## revert to recorded on the next update_visibility call.
func add_camera_zone(zone_id: String, cells: Array) -> void:
	if zone_id == "":
		return
	var packed: Array[Vector2i] = []
	for cell in cells:
		if cell is Vector2i and _is_in_bounds(cell):
			packed.append(cell)
	_camera_zones[zone_id] = packed
	# Immediately light up the zone for the current frame.
	for cell in packed:
		_cell_states[cell] = STATE_OBSERVED


## CH1-040: Remove a camera zone. Cells covered only by this zone (not in
## active player sight and not covered by another zone) will demote to recorded
## on the next update_visibility call.
func remove_camera_zone(zone_id: String) -> void:
	_camera_zones.erase(zone_id)


## CH1-040: Check if a cell is inside any active camera zone.
func _is_in_camera_zone(cell: Vector2i) -> bool:
	for zone_id in _camera_zones.keys():
		if _camera_zones[zone_id].has(cell):
			return true
	return false


## CH1-040: Bounds check helper.
func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _width and cell.y < _height


## CH1-040: Return the render state for a cell, consumed by VisibilityRenderer.
func get_render_state(cell: Vector2i) -> StringName:
	match get_cell_state(cell):
		STATE_OBSERVED:
			return RENDER_VISIBLE
		STATE_RECORDED:
			return RENDER_DIMMED
		_:
			return RENDER_HIDDEN


## CH1-040: Get the turn an enemy was last observed. Returns -1 if never seen.
func get_last_known_turn(entity_id: String) -> int:
	var snapshot: Dictionary = _last_known.get(entity_id, {})
	return int(snapshot.get("turn_seen", -1))


## CH1-040: Whether the last-known snapshot is uncertain (enemy has left sight
## and its real-time HP/position/intent should not be displayed).
func is_last_known_uncertain(entity_id: String) -> bool:
	var snapshot: Dictionary = _last_known.get(entity_id, {})
	return bool(snapshot.get("uncertain", false))


## CH1-040: Get last-known snapshots for enemies whose last-seen cell is in a
## recorded or observed cell (i.e. worth rendering as a ghost marker). Excludes
## enemies whose last-known position is in unexplored territory.
func get_renderable_last_known() -> Dictionary:
	var result: Dictionary = {}
	for eid in _last_known.keys():
		var snapshot: Dictionary = _last_known[eid]
		var pos = snapshot.get("pos", null)
		if pos == null:
			continue
		if not (pos is Vector2i):
			continue
		var cell_state := get_cell_state(pos)
		if cell_state == STATE_UNEXPLORED:
			continue
		result[eid] = snapshot.duplicate(true)
	return result


## Reveal cells permanently (e.g. from camera takeover).
## These cells are marked as observed; they will decay to recorded on the next
## update_visibility call, consistent with normal sight semantics.
func reveal_cells(cells: Array) -> void:
	for cell in cells:
		_cell_states[cell] = STATE_OBSERVED


## Reset all visibility state (e.g. for a new battle).
func clear() -> void:
	_cell_states.clear()
	_last_known.clear()
	_observed_enemies.clear()
	_newly_revealed.clear()
	_previously_observed.clear()
	_current_turn = 0
	_camera_zones.clear()
	_last_update_summary.clear()


## CODE-CH1-020: 序列化迷雾记忆状态为可 JSON 化字典（供 EncounterCheckpointState 使用）。
## Vector2i 作为 Dictionary 键时会被 Godot 序列化为 "x,y" 字符串；这里显式转换以便
## 跨会话恢复且不依赖 Godot 内部键序列化。
func serialize() -> Dictionary:
	var cells: Array = []
	for cell in _cell_states.keys():
		cells.append({"cell": {"x": cell.x, "y": cell.y}, "state": String(_cell_states[cell])})
	var last_known: Array = []
	for eid in _last_known.keys():
		last_known.append({"entity_id": eid, "data": _last_known[eid]})
	var camera_zones: Array = []
	for zone_id in _camera_zones.keys():
		var zone_cells: Array = []
		for cell in _camera_zones[zone_id]:
			zone_cells.append({"x": cell.x, "y": cell.y})
		camera_zones.append({"zone_id": zone_id, "cells": zone_cells})
	return {
		"width": _width,
		"height": _height,
		"cell_states": cells,
		"last_known": last_known,
		"observed_enemies": _observed_enemies.keys(),
		"current_turn": _current_turn,
		"camera_zones": camera_zones,
	}


## CODE-CH1-020: 从序列化字典恢复迷雾记忆状态。
## 注意：_previously_observed 和 _newly_revealed 不恢复，因为它们只与单回合边界相关。
func deserialize(data: Dictionary) -> void:
	_width = int(data.get("width", 0))
	_height = int(data.get("height", 0))
	_cell_states.clear()
	_last_known.clear()
	_observed_enemies.clear()
	_newly_revealed.clear()
	_previously_observed.clear()
	_current_turn = int(data.get("current_turn", 0))
	_camera_zones.clear()
	for entry in data.get("cell_states", []):
		var cell_dict = entry.get("cell", {})
		var cell := Vector2i(int(cell_dict.get("x", 0)), int(cell_dict.get("y", 0)))
		_cell_states[cell] = StringName(entry.get("state", "unexplored"))
	for entry in data.get("last_known", []):
		var eid = entry.get("entity_id", "")
		if eid != "":
			_last_known[eid] = entry.get("data", {})
	for eid in data.get("observed_enemies", []):
		_observed_enemies[eid] = true
	for entry in data.get("camera_zones", []):
		var zone_id = String(entry.get("zone_id", ""))
		if zone_id == "":
			continue
		var packed: Array[Vector2i] = []
		for cell_dict in entry.get("cells", []):
			packed.append(Vector2i(int(cell_dict.get("x", 0)), int(cell_dict.get("y", 0))))
		_camera_zones[zone_id] = packed
