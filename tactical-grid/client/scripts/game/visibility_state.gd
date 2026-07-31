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

var _width: int = 0
var _height: int = 0
## Per-cell state: Vector2i -> StringName
var _cell_states: Dictionary = {}
## Last-known enemy data: entity_id -> {pos, hp, ...}
var _last_known: Dictionary = {}
## Enemies currently observed this turn: entity_id -> true
var _observed_enemies: Dictionary = {}
## Enemies newly revealed this turn (not seen last turn): entity_id -> true
var _newly_revealed: Dictionary = {}
## Enemies observed last turn (for newly-revealed computation)
var _previously_observed: Dictionary = {}


## Initialize for a map of the given dimensions.
func setup(width: int, height: int) -> void:
	_width = width
	_height = height
	_cell_states.clear()
	_last_known.clear()
	_observed_enemies.clear()
	_newly_revealed.clear()
	_previously_observed.clear()


## Update visibility from the current player sight.
## visible_cells: cells currently in sight of any player unit.
## visible_enemies: array of dictionaries with at least {entity_id, pos, hp}.
func update_visibility(visible_cells: Array[Vector2i], visible_enemies: Array) -> void:
	# Demote previously observed cells to recorded
	for cell in _cell_states.keys():
		if _cell_states[cell] == STATE_OBSERVED:
			_cell_states[cell] = STATE_RECORDED

	# Mark currently visible cells as observed
	for cell in visible_cells:
		_cell_states[cell] = STATE_OBSERVED

	# Track newly revealed enemies: those visible now but not last turn
	_newly_revealed.clear()
	for enemy_data in visible_enemies:
		var eid: String = String(enemy_data.get("entity_id", ""))
		if eid == "":
			continue
		_observed_enemies[eid] = true
		# Store last-known snapshot
		_last_known[eid] = enemy_data.duplicate(true)
		if not _previously_observed.has(eid):
			_newly_revealed[eid] = true

	# Remove enemies no longer visible from observed set
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

	# Remember currently observed for next turn's newly-revealed check
	_previously_observed = _observed_enemies.duplicate(true)


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
	return {
		"width": _width,
		"height": _height,
		"cell_states": cells,
		"last_known": last_known,
		"observed_enemies": _observed_enemies.keys(),
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
