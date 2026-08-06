extends Node
class_name V2BattleInputRouter

signal cell_left_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cancel_requested()
signal pointer_cancel_requested()
signal end_turn_requested()
signal next_unit_requested()
signal focus_requested()
signal network_overlay_requested()
signal camera_pan_requested(delta: Vector2)
signal camera_zoom_requested(amount: int)

enum State {
	FREE_SELECT,
	UNIT_SELECTED,
	ATTACK_LOCKED,
	ABILITY_TARGETING,
	INTERACTION_MENU,
	ENEMY_TURN,
	PAUSED,
}

const TRANSITIONS := {
	State.FREE_SELECT: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
	State.UNIT_SELECTED: [State.FREE_SELECT, State.ATTACK_LOCKED, State.ABILITY_TARGETING, State.INTERACTION_MENU, State.ENEMY_TURN, State.PAUSED],
	State.ATTACK_LOCKED: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
	State.ABILITY_TARGETING: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
	State.INTERACTION_MENU: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
	State.ENEMY_TURN: [State.FREE_SELECT, State.UNIT_SELECTED, State.PAUSED],
	State.PAUSED: [State.FREE_SELECT, State.UNIT_SELECTED, State.ENEMY_TURN],
}

var _state: State = State.FREE_SELECT
var _middle_dragging := false
var _last_pointer_position := Vector2.ZERO
var _last_cancelled_state: State = State.FREE_SELECT

func set_state(next_state: State) -> Dictionary:
	if _state == next_state:
		return {"success": true, "reason": &"same_state", "state": next_state}
	var allowed: Array = TRANSITIONS.get(_state, [])
	if not allowed.has(next_state):
		return {"success": false, "reason": &"illegal_transition", "state": _state}
	var previous: State = _state
	_state = next_state
	return {"success": true, "previous_state": previous, "state": _state}

func get_state_name() -> String:
	match _state:
		State.FREE_SELECT:
			return "free_select"
		State.UNIT_SELECTED:
			return "unit_selected"
		State.ATTACK_LOCKED:
			return "attack_locked"
		State.ABILITY_TARGETING:
			return "ability_targeting"
		State.INTERACTION_MENU:
			return "interaction_menu"
		State.ENEMY_TURN:
			return "enemy_turn"
		State.PAUSED:
			return "paused"
	return "free_select"

func get_state() -> State:
	return _state

func get_last_cancelled_state() -> State:
	return _last_cancelled_state

func handle_event(event: InputEvent, screen_to_cell: Callable) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, screen_to_cell)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, screen_to_cell)
	if event is InputEventKey:
		return _handle_key(event as InputEventKey)
	return false

func _handle_mouse_button(event: InputEventMouseButton, screen_to_cell: Callable) -> bool:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_middle_dragging = true
			_last_pointer_position = event.position
		else:
			_middle_dragging = false
		return true

	if not event.pressed:
		return false

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera_zoom_requested.emit(1)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera_zoom_requested.emit(-1)
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		return _handle_cancel()
	if event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_left_click(event.position, screen_to_cell)
	return false

func _handle_mouse_motion(event: InputEventMouseMotion, screen_to_cell: Callable) -> bool:
	if _middle_dragging:
		var delta: Vector2 = event.position - _last_pointer_position
		_last_pointer_position = event.position
		camera_pan_requested.emit(delta)
		return true
	if _state == State.ENEMY_TURN or _state == State.PAUSED:
		return true
	if not screen_to_cell.is_valid():
		return false
	var cell: Variant = screen_to_cell.call(event.position)
	if cell is Vector2i:
		cell_hovered.emit(cell)
		return true
	return false

func _handle_left_click(position: Vector2, screen_to_cell: Callable) -> bool:
	if _state == State.ENEMY_TURN or _state == State.PAUSED:
		return true
	if not screen_to_cell.is_valid():
		return true
	var cell: Variant = screen_to_cell.call(position)
	if cell is Vector2i:
		cell_left_clicked.emit(cell)
	return true

func _handle_cancel() -> bool:
	_last_cancelled_state = _state
	match _state:
		State.ATTACK_LOCKED, State.ABILITY_TARGETING, State.INTERACTION_MENU:
			set_state(State.UNIT_SELECTED)
			pointer_cancel_requested.emit()
		State.UNIT_SELECTED:
			set_state(State.FREE_SELECT)
			pointer_cancel_requested.emit()
		State.FREE_SELECT, State.ENEMY_TURN, State.PAUSED:
			return true
	return true

func _handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_ESCAPE:
			return _handle_escape()
		KEY_SPACE:
			if _state != State.ENEMY_TURN and _state != State.PAUSED:
				end_turn_requested.emit()
			return true
		KEY_TAB:
			if _state != State.ENEMY_TURN and _state != State.PAUSED:
				next_unit_requested.emit()
			return true
		KEY_HOME:
			focus_requested.emit()
			return true
		KEY_G:
			network_overlay_requested.emit()
			return true
	return false

func _handle_escape() -> bool:
	if _state == State.PAUSED:
		set_state(State.FREE_SELECT)
		return true
	if _state == State.ATTACK_LOCKED or _state == State.ABILITY_TARGETING or _state == State.INTERACTION_MENU:
		set_state(State.UNIT_SELECTED)
		cancel_requested.emit()
		return true
	if _state == State.UNIT_SELECTED:
		set_state(State.FREE_SELECT)
		cancel_requested.emit()
		return true
	if _state == State.FREE_SELECT:
		set_state(State.PAUSED)
		return true
	return true
