extends Node2D
class_name V2AffordancePresenter

const MOVE_COLOR := Color(0.08, 0.70, 0.92, 0.16)
const MOVE_BORDER := Color(0.24, 0.86, 1.0, 0.72)
const PATH_COLOR := Color(0.72, 1.0, 0.94, 0.98)
const DESTINATION_COLOR := Color(0.18, 0.94, 0.78, 0.96)
const ATTACK_BORDER := Color(1.0, 0.34, 0.24, 0.96)
const ATTACK_HOVER := Color(1.0, 0.82, 0.24, 0.98)
const DANGER_COLOR := Color(1.0, 0.58, 0.12, 0.13)
const DANGER_BORDER := Color(1.0, 0.76, 0.22, 0.98)

@export var cell_size: float = 64.0

func show_for_unit(unit: Unit, move_query: Dictionary, attack_query: Dictionary) -> void:
	clear_all()
	if unit == null or not is_instance_valid(unit):
		return
	show_reachable(move_query.get("reachable", {}))
	# range_cells is intentionally ignored: broad red range fills communicate
	# legal targets that do not exist. Only query-backed targets are persistent.
	show_attackable(attack_query.get("targets", []))

func show_reachable(cells: Variant) -> void:
	_clear_group(&"v2_move_overlay")
	var raw_cells: Array = cells.keys() if cells is Dictionary else cells if cells is Array else []
	for raw_cell in raw_cells:
		var cell := _coerce_cell(raw_cell)
		if cell != Vector2i(-1, -1):
			_spawn_cell(cell, MOVE_COLOR, MOVE_BORDER, &"v2_move_overlay", false)

func show_attackable(targets: Variant) -> void:
	_clear_group(&"v2_attackable_outline")
	if not targets is Array:
		return
	for target in targets:
		var cell := _target_cell(target)
		if cell != Vector2i(-1, -1):
			_add_target_outline(cell, ATTACK_BORDER, &"v2_attackable_outline", false, false)

func show_move_preview(preview: Dictionary) -> void:
	clear_transient()
	if not bool(preview.get("valid", false)):
		return
	var destination := _coerce_cell(preview.get("destination", Vector2i(-1, -1)))
	if destination == Vector2i(-1, -1):
		return
	if bool(preview.get("dangerous", false)):
		_spawn_cell(destination, DANGER_COLOR, DANGER_BORDER, &"v2_danger_destination", true)
		return
	var path := _coerce_path(preview.get("path", []))
	if path.is_empty() or path.back() != destination:
		return
	for cell in path:
		_spawn_cell(cell, Color(MOVE_COLOR, 0.24), PATH_COLOR, &"v2_path_overlay", true)
	_add_destination_marker(destination)
	var route_path := path.duplicate()
	var origin := _coerce_cell(preview.get("origin", Vector2i(-1, -1)))
	if origin != Vector2i(-1, -1) and (route_path.is_empty() or route_path.front() != origin):
		route_path.push_front(origin)
	_draw_path_route(route_path)

func show_attack_preview(preview: Dictionary) -> void:
	clear_transient()
	if not bool(preview.get("valid", false)):
		return
	var target: Unit = preview.get("target") as Unit
	if target == null or not is_instance_valid(target):
		return
	var locked := bool(preview.get("locked", false))
	var panel := _add_target_outline(target.grid_pos, ATTACK_BORDER if locked else ATTACK_HOVER, &"v2_attack_preview", true, locked)
	panel.add_to_group("v2_attack_focus")
	panel.set_meta("v2_target_id", String(target.entity_id))
	panel.set_meta("v2_damage", int(preview.get("damage", 0)))
	panel.set_meta("v2_hp_after", int(preview.get("hp_after", target.current_hp)))
	_add_attack_numbers(target.grid_pos, int(preview.get("damage", 0)), int(preview.get("hp_after", target.current_hp)), locked)
	if not String(preview.get("intent_change", "")).is_empty():
		_add_intent_change_cue(target.grid_pos, locked)

func clear_transient() -> void:
	for child in get_children():
		if bool(child.get_meta("v2_transient", false)):
			child.free()

func clear_all() -> void:
	for child in get_children():
		child.free()

# Compatibility entry points retained for the existing controller and focused
# input tests while all production drawing is routed through the new contract.
func show_path(path: Array[Vector2i], dangerous: bool) -> void:
	show_move_preview({
		"valid": not path.is_empty(),
		"path": path,
		"destination": path.back() if not path.is_empty() else Vector2i(-1, -1),
		"dangerous": dangerous,
	})

func clear_preview() -> void:
	clear_transient()

func show_attack_focus(cell: Vector2i, locked: bool) -> void:
	clear_transient()
	var panel := _add_target_outline(cell, ATTACK_BORDER if locked else ATTACK_HOVER, &"v2_attack_focus", true, locked)
	panel.set_meta("v2_focus_locked", locked)

func clear_attack_focus() -> void:
	_clear_group(&"v2_attack_focus")

func clear_temporary_attack_focus() -> void:
	for child in get_children():
		if bool(child.get_meta("v2_transient", false)) and not bool(child.get_meta("v2_focus_locked", false)):
			child.free()

func _spawn_cell(cell: Vector2i, fill: Color, border: Color, group_name: StringName, transient: bool) -> void:
	var origin := _cell_origin(cell)
	var panel := Panel.new()
	panel.position = origin + Vector2(4, 4)
	panel.size = Vector2(cell_size - 8, cell_size - 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 2 if not transient else 8
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if not transient else 3)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	panel.add_theme_stylebox_override("panel", style)
	panel.add_to_group(group_name)
	panel.set_meta("v2_transient", transient)
	add_child(panel)

func _add_target_outline(cell: Vector2i, color: Color, group_name: StringName, transient: bool, locked: bool) -> Panel:
	var panel := Panel.new()
	panel.position = _cell_origin(cell) + Vector2(3, 3)
	panel.size = Vector2(cell_size - 6, cell_size - 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 6 if not transient else 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(5 if locked else 4)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.add_to_group(group_name)
	panel.set_meta("v2_transient", transient)
	panel.set_meta("v2_focus_locked", locked)
	add_child(panel)
	return panel

func _add_destination_marker(cell: Vector2i) -> void:
	var marker := Panel.new()
	marker.position = _cell_origin(cell) + Vector2(cell_size * 0.28, cell_size * 0.28)
	marker.size = Vector2.ONE * cell_size * 0.44
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 11
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DESTINATION_COLOR, 0.18)
	style.border_color = DESTINATION_COLOR
	style.set_border_width_all(4)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	marker.add_theme_stylebox_override("panel", style)
	marker.add_to_group("v2_move_destination")
	marker.set_meta("v2_transient", true)
	add_child(marker)

func _draw_path_route(path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	var route := Line2D.new()
	route.name = "V2PathRoute"
	route.width = 5.0
	route.default_color = PATH_COLOR
	route.joint_mode = Line2D.LINE_JOINT_ROUND
	route.begin_cap_mode = Line2D.LINE_CAP_ROUND
	route.end_cap_mode = Line2D.LINE_CAP_ROUND
	route.z_index = 9
	for cell in path:
		route.add_point(_cell_origin(cell) + Vector2.ONE * cell_size * 0.5)
	route.add_to_group("v2_path_line")
	route.set_meta("v2_transient", true)
	add_child(route)

func _add_attack_numbers(cell: Vector2i, damage: int, hp_after: int, locked: bool) -> void:
	var label := Label.new()
	label.position = _cell_origin(cell) + Vector2(4, cell_size - 24)
	label.size = Vector2(cell_size - 8, 20)
	label.text = "伤害 %d · HP %d" % [damage, hp_after]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", ATTACK_BORDER if locked else Color(0.3, 0.18, 0.02, 0.98))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 12
	label.add_to_group("v2_attack_preview_numbers")
	label.set_meta("v2_transient", true)
	label.set_meta("v2_focus_locked", locked)
	add_child(label)

func _add_intent_change_cue(cell: Vector2i, locked: bool) -> void:
	var cue := Panel.new()
	cue.position = _cell_origin(cell) + Vector2(cell_size - 17, 2)
	cue.size = Vector2(15, 15)
	cue.rotation = PI / 4.0
	cue.pivot_offset = cue.size * 0.5
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.z_index = 13
	var style := StyleBoxFlat.new()
	style.bg_color = ATTACK_BORDER if locked else ATTACK_HOVER
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	cue.add_theme_stylebox_override("panel", style)
	cue.add_to_group("v2_intent_change_cue")
	cue.set_meta("v2_transient", true)
	cue.set_meta("v2_focus_locked", locked)
	add_child(cue)

func _clear_group(group_name: StringName) -> void:
	for child in get_children():
		if child.is_in_group(group_name):
			child.free()

func _coerce_path(value: Variant) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not value is Array:
		return path
	for raw_cell in value:
		var cell := _coerce_cell(raw_cell)
		if cell == Vector2i(-1, -1):
			return [] as Array[Vector2i]
		path.append(cell)
	return path

func _target_cell(target: Variant) -> Vector2i:
	if target is Unit:
		return target.grid_pos
	return _coerce_cell(target)

func _coerce_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)

func _cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size, cell.y * cell_size)
