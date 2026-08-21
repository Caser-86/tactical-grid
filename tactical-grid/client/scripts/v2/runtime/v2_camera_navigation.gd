extends RefCounted
class_name V2CameraNavigation

const MIN_INSPECT_RADIUS := 1
const MAX_INSPECT_RADIUS := 7
const PLAYER_ZOOM_HINT := 1.0
const MIN_INSPECT_ZOOM_HINT := 0.75
const MAX_INSPECT_ZOOM_HINT := 1.35

var _inspecting := false
var _return_cell := Vector2i.ZERO
var _current_player_cell := Vector2i.ZERO

func begin_inspect(center: Vector2i, radius: int, return_cell: Vector2i) -> Dictionary:
	if not _is_valid_cell(center):
		return _result(false, &"player", _current_player_cell, PLAYER_ZOOM_HINT, false)
	if _is_valid_cell(return_cell):
		_current_player_cell = return_cell
	_return_cell = _current_player_cell
	_inspecting = true
	var clamped_radius := clampi(radius, MIN_INSPECT_RADIUS, MAX_INSPECT_RADIUS)
	return _result(true, &"inspect", center, _inspect_zoom_hint(clamped_radius), true)

func cancel_inspect() -> Dictionary:
	_inspecting = false
	_current_player_cell = _return_cell if _is_valid_cell(_return_cell) else _current_player_cell
	return _result(true, &"player", _current_player_cell, PLAYER_ZOOM_HINT, false)

func focus_player(cell: Vector2i) -> Dictionary:
	_inspecting = false
	if not _is_valid_cell(cell):
		return _result(false, &"player", _current_player_cell, PLAYER_ZOOM_HINT, false)
	_current_player_cell = cell
	_return_cell = cell
	return _result(true, &"player", cell, PLAYER_ZOOM_HINT, false)

func is_inspecting() -> bool:
	return _inspecting

func _inspect_zoom_hint(radius: int) -> float:
	return clampf(1.45 - float(radius) * 0.1, MIN_INSPECT_ZOOM_HINT, MAX_INSPECT_ZOOM_HINT)

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0

func _result(success: bool, mode: StringName, focus_cell: Vector2i, zoom_hint: float, show_return: bool) -> Dictionary:
	return {
		"success": success,
		"mode": mode,
		"focus_cell": focus_cell,
		"zoom_hint": zoom_hint,
		"show_return": show_return,
	}
