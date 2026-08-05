extends Node2D
class_name V2AffordancePresenter

const MOVE_COLOR := Color(0.12, 0.56, 1.0, 0.24)
const MOVE_BORDER := Color(0.20, 0.78, 1.0, 0.88)
const ATTACK_COLOR := Color(1.0, 0.16, 0.18, 0.20)
const ATTACK_BORDER := Color(1.0, 0.36, 0.25, 0.92)
const DANGER_COLOR := Color(1.0, 0.58, 0.12, 0.32)
const DANGER_BORDER := Color(1.0, 0.78, 0.24, 0.98)
const HOVER_BORDER := Color(1.0, 0.88, 0.30, 0.98)

@export var cell_size: float = 64.0

func show_for_unit(unit: Unit, move_query: Dictionary, attack_query: Dictionary) -> void:
	clear_all()
	if unit == null or not is_instance_valid(unit):
		return
	var reachable: Variant = move_query.get("reachable", {})
	if reachable is Dictionary:
		for raw_cell in reachable.keys():
			var cell := _coerce_cell(raw_cell)
			if cell != Vector2i(-1, -1):
				_spawn_cell(cell, MOVE_COLOR, MOVE_BORDER, "v2_move_overlay", "M", false)

	var range_cells: Variant = attack_query.get("range_cells", [])
	if range_cells is Array:
		for raw_cell in range_cells:
			var cell := _coerce_cell(raw_cell)
			if cell != Vector2i(-1, -1):
				_spawn_cell(cell, ATTACK_COLOR, ATTACK_BORDER, "v2_attack_overlay", "A", false)

	var targets: Variant = attack_query.get("targets", [])
	if targets is Array:
		for target in targets:
			var target_cell := _target_cell(target)
			if target_cell != Vector2i(-1, -1):
				_outline_target(target_cell, ATTACK_BORDER)

func show_path(path: Array[Vector2i], dangerous: bool) -> void:
	clear_preview()
	for index in range(1, path.size()):
		var cell: Vector2i = path[index]
		var fill: Color = DANGER_COLOR if dangerous else MOVE_COLOR
		var border: Color = DANGER_BORDER if dangerous else MOVE_BORDER
		var group_name := "v2_danger_overlay" if dangerous else "v2_path_overlay"
		_spawn_cell(cell, fill, border, group_name, "!" if dangerous else ">", true)

func clear_preview() -> void:
	for child in get_children():
		if bool(child.get_meta("v2_preview", false)):
			child.free()

## V2: 将攻击目标分为临时悬停焦点和已锁定焦点，避免玩家误以为悬停就是开火。
func show_attack_focus(cell: Vector2i, locked: bool) -> void:
	if locked:
		clear_attack_focus()
	else:
		clear_temporary_attack_focus()
	var panel := Panel.new()
	panel.position = _cell_origin(cell) + Vector2(1, 1)
	panel.size = Vector2(cell_size - 2, cell_size - 2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 7
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.72, 0.12, 0.08 if locked else 0.03)
	style.border_color = ATTACK_BORDER if locked else HOVER_BORDER
	style.set_border_width_all(5 if locked else 3)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	panel.add_theme_stylebox_override("panel", style)
	panel.add_to_group("v2_attack_focus")
	panel.set_meta("v2_focus_locked", locked)
	panel.set_meta("v2_preview", not locked)
	add_child(panel)

func clear_attack_focus() -> void:
	for child in get_children():
		if child.is_in_group("v2_attack_focus"):
			child.free()

func clear_temporary_attack_focus() -> void:
	for child in get_children():
		if child.is_in_group("v2_attack_focus") and not bool(child.get_meta("v2_focus_locked", false)):
			child.free()

func clear_all() -> void:
	for child in get_children():
		child.free()

func _spawn_cell(cell: Vector2i, fill: Color, border: Color, group_name: String, glyph: String, preview: bool) -> void:
	var origin := _cell_origin(cell)
	var inset := 3.0
	var fill_rect := ColorRect.new()
	fill_rect.position = origin + Vector2(inset, inset)
	fill_rect.size = Vector2(cell_size - inset * 2.0, cell_size - inset * 2.0)
	fill_rect.color = fill
	fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_rect.z_index = 2
	fill_rect.add_to_group(group_name)
	if group_name == "v2_danger_overlay":
		fill_rect.add_to_group("v2_path_overlay")
	fill_rect.set_meta("v2_preview", preview)
	add_child(fill_rect)
	_add_border(origin, border, preview)
	_add_glyph(origin, glyph, border, preview)

func _add_border(origin: Vector2, color: Color, preview: bool) -> void:
	var width := 2.0
	var edges := [
		{&"position": origin, &"size": Vector2(cell_size, width)},
		{&"position": origin + Vector2(0, cell_size - width), &"size": Vector2(cell_size, width)},
		{&"position": origin, &"size": Vector2(width, cell_size)},
		{&"position": origin + Vector2(cell_size - width, 0), &"size": Vector2(width, cell_size)},
	]
	for edge_data in edges:
		var edge := ColorRect.new()
		edge.position = edge_data[&"position"]
		edge.size = edge_data[&"size"]
		edge.color = color
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.z_index = 3
		edge.set_meta("v2_preview", preview)
		add_child(edge)

func _add_glyph(origin: Vector2, glyph: String, color: Color, preview: bool) -> void:
	var label := Label.new()
	label.position = origin + Vector2(7, 5)
	label.size = Vector2(cell_size - 14, cell_size - 10)
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 4
	label.set_meta("v2_preview", preview)
	add_child(label)

func _outline_target(cell: Vector2i, color: Color) -> void:
	var panel := Panel.new()
	panel.position = _cell_origin(cell) + Vector2(2, 2)
	panel.size = Vector2(cell_size - 4, cell_size - 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.add_to_group("v2_attack_overlay")
	panel.set_meta("v2_preview", false)
	add_child(panel)

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
