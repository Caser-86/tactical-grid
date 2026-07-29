## Runtime unit presentation.
## Uses production textures with a readable faction base and programmatic state animation.
extends Node2D
class_name UnitSprite

const SUPPORTED_STATES: Array[StringName] = [
	&"idle", &"move", &"attack", &"hit", &"skill", &"death",
]
const ART_MAX_SIZE := 56.0
const BOSS_ART_MAX_SIZE := 80.0
const STANDARD_RADIUS := 25
const BOSS_RADIUS := 31

var unit: Node
var selected := false
var hover := false
var current_state: StringName = &"idle"
var art_sprite: Sprite2D

var _state_tween: Tween
var _idle_elapsed := 0.0
var _base_art_scale := Vector2.ONE

func _ready() -> void:
	_ensure_art_sprite()

func _process(delta: float) -> void:
	if not art_sprite or current_state != &"idle":
		return
	if GameManager.get_settings().get("reduce_motion", false):
		art_sprite.position = Vector2.ZERO
		art_sprite.rotation = 0.0
		return
	_idle_elapsed += delta
	art_sprite.position.y = sin(_idle_elapsed * 2.8) * 1.25
	art_sprite.rotation = sin(_idle_elapsed * 1.4) * 0.012

func _draw() -> void:
	if not unit:
		return

	var color := _get_unit_color()
	var radius := BOSS_RADIUS if _is_boss_unit() else STANDARD_RADIUS

	_draw_ellipse(Vector2(0, 5), Vector2(23, 13), Color(0, 0, 0, 0.42))
	draw_circle(Vector2.ZERO, radius, color.darkened(0.62))
	draw_circle(Vector2.ZERO, radius - 3, color.darkened(0.30))
	if not art_sprite or not art_sprite.texture:
		_draw_tactical_silhouette(color)

	var border_color := Color.WHITE if selected else color.lightened(0.05)
	var border_width := 3.0 if selected else 2.0
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, border_color, border_width)
	if _is_boss_unit():
		draw_arc(Vector2.ZERO, radius + 4, 0, TAU, 48, Color(0.18, 0.96, 1.0, 0.88), 2.0)
	_draw_hp_bar(radius)
	_draw_shield_bar(radius)
	_draw_ap_indicator(radius)

	if selected:
		draw_arc(Vector2.ZERO, radius + (9 if _is_boss_unit() else 6), 0, TAU, 40, Color(0.22, 1.0, 0.78), 2.5)
	elif hover:
		draw_arc(Vector2.ZERO, radius + (7 if _is_boss_unit() else 4), 0, TAU, 40, Color(1, 1, 1, 0.55), 1.5)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _ensure_art_sprite() -> void:
	if art_sprite and is_instance_valid(art_sprite):
		return
	art_sprite = Sprite2D.new()
	art_sprite.name = "Art"
	art_sprite.centered = true
	art_sprite.z_index = 1
	art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(art_sprite)

func _refresh_art_texture() -> void:
	_ensure_art_sprite()
	if not unit:
		art_sprite.texture = null
		return
	var key: StringName = unit.boss_art_key if not unit.boss_art_key.is_empty() else StringName(unit.job)
	if not ArtCatalog.has_texture(&"unit", key):
		key = &"cyber_guard" if unit.team == "enemy" else &"assault"
	art_sprite.texture = ArtCatalog.get_texture(&"unit", key)
	if art_sprite.texture:
		var texture_size := art_sprite.texture.get_size()
		var longest_side := maxf(texture_size.x, texture_size.y)
		var target_size := BOSS_ART_MAX_SIZE if _is_boss_unit() else ART_MAX_SIZE
		var scale_factor := minf(1.0, target_size / maxf(1.0, longest_side))
		_base_art_scale = Vector2.ONE * scale_factor
	else:
		_base_art_scale = Vector2.ONE
	_reset_art_transform()

func _is_boss_unit() -> bool:
	return unit != null and not unit.boss_art_key.is_empty()

func get_supported_states() -> Array[StringName]:
	return SUPPORTED_STATES.duplicate()

func get_current_state() -> StringName:
	return current_state

func play_state(state: StringName, direction: Vector2 = Vector2.RIGHT, duration_override: float = -1.0) -> void:
	if state not in SUPPORTED_STATES:
		return
	if state == &"move":
		current_state = &"move"
		return
	if state == &"death":
		play_death(duration_override)
		return

	_begin_state(state)
	var state_direction := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var base_duration := duration_override if duration_override > 0.0 else _default_state_duration(state)
	var duration := AccessibilitySettings.get_effect_duration(base_duration)

	match state:
		&"attack":
			_state_tween = create_tween()
			_state_tween.tween_property(art_sprite, "position", -state_direction * 3.0, duration * 0.20)
			_state_tween.tween_property(art_sprite, "position", state_direction * 6.0, duration * 0.32)
			_state_tween.tween_property(art_sprite, "position", Vector2.ZERO, duration * 0.48)
		&"hit":
			_state_tween = create_tween()
			_state_tween.tween_property(art_sprite, "modulate", Color(1.0, 0.28, 0.20), duration * 0.24)
			_state_tween.tween_property(art_sprite, "modulate", Color.WHITE, duration * 0.24)
			_state_tween.tween_property(art_sprite, "modulate", Color(1.0, 0.48, 0.34), duration * 0.20)
			_state_tween.tween_property(art_sprite, "modulate", Color.WHITE, duration * 0.32)
		&"skill":
			_state_tween = create_tween()
			_state_tween.tween_property(art_sprite, "scale", _base_art_scale * 1.12, duration * 0.32)
			_state_tween.parallel().tween_property(art_sprite, "modulate", Color(0.48, 1.0, 0.96), duration * 0.32)
			_state_tween.tween_property(art_sprite, "scale", _base_art_scale, duration * 0.68)
			_state_tween.parallel().tween_property(art_sprite, "modulate", Color.WHITE, duration * 0.68)
		_:
			current_state = &"idle"
			return
	_state_tween.finished.connect(_return_to_idle)

func play_move_to(target_position: Vector2, duration_override: float = -1.0) -> void:
	_begin_state(&"move")
	var distance := position.distance_to(target_position)
	var base_duration := duration_override if duration_override > 0.0 else clampf(distance / 420.0, 0.14, 0.42)
	var duration := AccessibilitySettings.get_effect_duration(base_duration)
	art_sprite.rotation = 0.045
	_state_tween = create_tween()
	_state_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_state_tween.tween_property(self, "position", target_position, duration)
	_state_tween.finished.connect(_return_to_idle)

func play_death(duration_override: float = -1.0) -> void:
	_begin_state(&"death")
	var base_duration := duration_override if duration_override > 0.0 else 0.55
	var duration := AccessibilitySettings.get_effect_duration(base_duration)
	_state_tween = create_tween()
	_state_tween.set_parallel(true)
	_state_tween.tween_property(art_sprite, "rotation", 0.72, duration)
	_state_tween.tween_property(art_sprite, "scale", _base_art_scale * 0.62, duration)
	_state_tween.tween_property(art_sprite, "modulate", Color(0.34, 0.38, 0.42, 0.16), duration)
	_state_tween.tween_property(self, "modulate", Color(1, 1, 1, 0.42), duration)

func _begin_state(state: StringName) -> void:
	if _state_tween and _state_tween.is_valid():
		_state_tween.kill()
	current_state = state
	_reset_art_transform()

func _return_to_idle() -> void:
	if current_state == &"death":
		return
	current_state = &"idle"
	_reset_art_transform()

func _reset_art_transform() -> void:
	if not art_sprite:
		return
	art_sprite.position = Vector2.ZERO
	art_sprite.rotation = 0.0
	art_sprite.scale = _base_art_scale
	art_sprite.modulate = Color.WHITE
	modulate = Color.WHITE

func _default_state_duration(state: StringName) -> float:
	match state:
		&"attack": return 0.24
		&"hit": return 0.30
		&"skill": return 0.42
		_: return 0.20

func _get_unit_color() -> Color:
	if unit.team == "player":
		return GameTheme.PLAYER_COLOR
	if unit.team == "enemy":
		return GameTheme.ENEMY_COLOR
	return GameTheme.NEUTRAL_COLOR

func _draw_tactical_silhouette(team_color: Color) -> void:
	var body_color := Color(0.075, 0.10, 0.13) if unit.team == "player" else Color(0.17, 0.055, 0.045)
	var highlight := team_color.lightened(0.22)
	if unit.team == "enemy":
		var drone := PackedVector2Array([
			Vector2(0, -15), Vector2(14, 0), Vector2(0, 15), Vector2(-14, 0),
		])
		draw_colored_polygon(drone, body_color)
		draw_polyline(PackedVector2Array([drone[0], drone[1], drone[2], drone[3], drone[0]]), highlight, 2.0, true)
		draw_circle(Vector2.ZERO, 5, Color(1.0, 0.26, 0.18))
		return
	draw_circle(Vector2(0, -7), 6, Color(0.70, 0.82, 0.86))
	draw_rect(Rect2(-9, -2, 18, 15), body_color, true)
	draw_line(Vector2(4, 1), Vector2(18, -6), highlight, 3.0)

func _draw_hp_bar(radius: int) -> void:
	var bar_width := radius * 2
	var bar_height := 4
	var bar_y := -radius - 10
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(0, 0, 0, 0.72), true)
	var hp_ratio := float(unit.current_hp) / float(maxi(1, unit.max_hp))
	var hp_color := GameTheme.get_hp_color(unit.current_hp, unit.max_hp)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * hp_ratio, bar_height), hp_color, true)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(1, 1, 1, 0.72), false, 1)

func _draw_shield_bar(radius: int) -> void:
	if not has_visible_shield_bar():
		return
	var bar_width := radius * 2
	var bar_height := 4
	var bar_y := -radius - 16
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(0, 0, 0, 0.72), true)
	var shield_ratio := float(unit.current_shield) / float(maxi(1, unit.max_shield))
	draw_rect(
		Rect2(-bar_width / 2.0, bar_y, bar_width * shield_ratio, bar_height),
		Color(0.16, 0.86, 1.0),
		true
	)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(0.65, 0.96, 1.0, 0.86), false, 1)

func has_visible_shield_bar() -> bool:
	return unit != null and unit.max_shield > 0

func _on_shield_changed(_source: Unit, _current: int, _maximum: int) -> void:
	queue_redraw()

func _draw_ap_indicator(radius: int) -> void:
	var spacing := 8
	var start_x: float = -((unit.max_ap - 1) * spacing) / 2.0
	var y := radius + 8
	for index in range(unit.max_ap):
		var color := Color(0.13, 0.72, 1.0) if index < unit.current_ap else Color(0.16, 0.19, 0.22)
		draw_circle(Vector2(start_x + index * spacing, y), 3, color)

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func set_hover(value: bool) -> void:
	hover = value
	queue_redraw()

func update_unit(value: Node) -> void:
	var previous_unit := unit as Unit
	if previous_unit and previous_unit.shield_changed.is_connected(_on_shield_changed):
		previous_unit.shield_changed.disconnect(_on_shield_changed)
	unit = value
	var next_unit := unit as Unit
	if next_unit and not next_unit.shield_changed.is_connected(_on_shield_changed):
		next_unit.shield_changed.connect(_on_shield_changed)
	_refresh_art_texture()
	queue_redraw()
