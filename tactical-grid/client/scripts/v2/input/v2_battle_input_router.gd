extends Node
class_name V2BattleInputRouter

signal cell_left_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cancel_requested()
signal pointer_cancel_requested()
signal end_turn_requested()
signal next_unit_requested()
signal focus_requested()
signal camera_inspect_cancel_requested()
signal network_overlay_requested()
signal ability_requested()
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
const DRAG_THRESHOLD := 8.0
const KEYBOARD_PAN_STEP := 32.0

var _state: State = State.FREE_SELECT
var _drag_button: MouseButton = MOUSE_BUTTON_NONE
var _drag_origin := Vector2.ZERO
var _last_pointer_position := Vector2.ZERO
var _drag_distance := 0.0
var _drag_allowed := false
var _drag_threshold_crossed := false
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
	return get_state_name_for(_state)

func get_state_name_for(state: State) -> String:
	match state:
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

## The V2 controller uses this during _input so a HUD Control cannot swallow
## the motion event before it reaches the unhandled-input router.
func is_camera_panning() -> bool:
	return _drag_button == MOUSE_BUTTON_MIDDLE or (_drag_button != MOUSE_BUTTON_NONE and _drag_allowed)

func get_last_cancelled_state() -> State:
	return _last_cancelled_state

func handle_event(event: InputEvent, screen_to_cell: Callable, pointer_context: Callable = Callable()) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton, screen_to_cell, pointer_context)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion, screen_to_cell)
	if event is InputEventKey:
		return _handle_key(event as InputEventKey)
	return false

func _handle_mouse_button(event: InputEventMouseButton, screen_to_cell: Callable, pointer_context: Callable) -> bool:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			if not _pointer_allows_map_gesture(event.position, pointer_context):
				_clear_pointer_gesture()
				return false
			_begin_pointer_gesture(MOUSE_BUTTON_MIDDLE, event.position, true)
		elif _drag_button == MOUSE_BUTTON_MIDDLE:
			_clear_pointer_gesture()
			return true
		return false

	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if not _pointer_allows_map_gesture(event.position, pointer_context):
			return false
		camera_zoom_requested.emit(1)
		return true
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not _pointer_allows_map_gesture(event.position, pointer_context):
			return false
		camera_zoom_requested.emit(-1)
		return true
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return false

	# Existing two-argument call sites retain their press-time behavior. Scene-aware
	# gesture classification begins only when a pointer context is supplied.
	if not pointer_context.is_valid():
		if not event.pressed:
			return false
		_clear_pointer_gesture()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			camera_inspect_cancel_requested.emit()
			return _handle_cancel()
		return _handle_left_click(event.position, screen_to_cell)

	if event.pressed:
		var raw_context: Variant = pointer_context.call(event.position)
		if not raw_context is Dictionary:
			_clear_pointer_gesture()
			return false
		var context: Dictionary = raw_context
		if bool(context.get("over_hud", false)) or not bool(context.get("over_map", false)):
			_clear_pointer_gesture()
			return false
		_begin_pointer_gesture(event.button_index, event.position, bool(context.get("drag_allowed", false)))
		return true

	return _finish_pointer_gesture(event.button_index, event.position, screen_to_cell)

func _pointer_allows_map_gesture(position: Vector2, pointer_context: Callable) -> bool:
	if not pointer_context.is_valid():
		return true
	var raw_context: Variant = pointer_context.call(position)
	if not raw_context is Dictionary:
		return false
	var context: Dictionary = raw_context
	return bool(context.get("over_map", false)) and not bool(context.get("over_hud", false))

func _handle_mouse_motion(event: InputEventMouseMotion, screen_to_cell: Callable) -> bool:
	if _drag_button != MOUSE_BUTTON_NONE:
		_update_pointer_gesture(event.position)
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

func _begin_pointer_gesture(button: MouseButton, position: Vector2, drag_allowed: bool) -> void:
	_drag_button = button
	_drag_origin = position
	_last_pointer_position = position
	_drag_distance = 0.0
	_drag_allowed = drag_allowed
	_drag_threshold_crossed = button == MOUSE_BUTTON_MIDDLE

func _update_pointer_gesture(position: Vector2) -> bool:
	if _drag_button == MOUSE_BUTTON_NONE:
		return false
	var segment := position - _last_pointer_position
	var was_over_threshold := _drag_threshold_crossed
	_drag_distance += segment.length()
	_last_pointer_position = position
	if _drag_button == MOUSE_BUTTON_MIDDLE:
		if not segment.is_zero_approx():
			camera_pan_requested.emit(segment)
		return true
	if not _drag_allowed:
		return true
	_drag_threshold_crossed = _drag_distance >= DRAG_THRESHOLD
	if not _drag_threshold_crossed:
		return true
	var pan_delta := segment if was_over_threshold else position - _drag_origin
	if not pan_delta.is_zero_approx():
		camera_pan_requested.emit(pan_delta)
	return true

func _finish_pointer_gesture(button: MouseButton, position: Vector2, screen_to_cell: Callable) -> bool:
	if _drag_button != button:
		return false
	_update_pointer_gesture(position)
	var is_click := _drag_distance < DRAG_THRESHOLD
	_clear_pointer_gesture()
	if not is_click:
		return true
	if button == MOUSE_BUTTON_RIGHT:
		camera_inspect_cancel_requested.emit()
		return _handle_cancel()
	return _handle_left_click(position, screen_to_cell)

func _clear_pointer_gesture() -> void:
	_drag_button = MOUSE_BUTTON_NONE
	_drag_origin = Vector2.ZERO
	_last_pointer_position = Vector2.ZERO
	_drag_distance = 0.0
	_drag_allowed = false
	_drag_threshold_crossed = false

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
			# Right-click is a tactical back action, not a deselect action. Keep
			# the unit selected so the player can immediately choose another blue
			# cell, red target, or facility after cancelling a preview.
			pointer_cancel_requested.emit()
		State.FREE_SELECT, State.ENEMY_TURN, State.PAUSED:
			return true
	return true

func _handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.is_action_pressed(&"camera_up") or _event_matches_key(event, KEY_W):
		camera_pan_requested.emit(Vector2(0.0, KEYBOARD_PAN_STEP))
		return true
	if event.is_action_pressed(&"camera_down") or _event_matches_key(event, KEY_S):
		camera_pan_requested.emit(Vector2(0.0, -KEYBOARD_PAN_STEP))
		return true
	if event.is_action_pressed(&"camera_left") or _event_matches_key(event, KEY_A):
		camera_pan_requested.emit(Vector2(KEYBOARD_PAN_STEP, 0.0))
		return true
	if event.is_action_pressed(&"camera_right") or _event_matches_key(event, KEY_D):
		camera_pan_requested.emit(Vector2(-KEYBOARD_PAN_STEP, 0.0))
		return true
	if event.is_action_pressed(&"focus_unit") or _event_matches_key(event, KEY_F) or _event_matches_key(event, KEY_HOME):
		focus_requested.emit()
		return true
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
		KEY_G:
			network_overlay_requested.emit()
			return true
		KEY_Q:
			if _state == State.UNIT_SELECTED:
				ability_requested.emit()
				return true
			if _state == State.ABILITY_TARGETING:
				return _handle_cancel()
	return false

func _event_matches_key(event: InputEventKey, key: Key) -> bool:
	return event.keycode == key or event.physical_keycode == key

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
