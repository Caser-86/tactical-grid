extends Node2D
class_name UnitSprite

var unit: Node
var selected: bool = false
var hover: bool = false

var portrait_texture: Texture2D
var _base_position: Vector2 = Vector2.ZERO
var _move_tween: Tween

func _draw() -> void:
	if not unit:
		return

	var frame_rect = Rect2(-32, -44, 64, 88)
	var portrait_rect = Rect2(-20, -22, 40, 40)
	var team_color = _get_unit_color()
	var job_name = GameData.get_job(unit.job).get("name", unit.job)
	var level_text = "Lv.%d" % unit.stats.get("level", 1)

	draw_circle(Vector2(0, 8), 26, Color(0, 0, 0, 0.34))
	draw_rect(frame_rect.grow(1), Color(0, 0, 0, 0.65), true)
	draw_rect(frame_rect, Color(0.07, 0.08, 0.1, 0.98), true)
	draw_rect(Rect2(frame_rect.position.x + 1, frame_rect.position.y + 1, frame_rect.size.x - 2, 8), team_color.darkened(0.2), true)
	draw_rect(portrait_rect.grow(1), team_color.darkened(0.4), true)
	draw_rect(portrait_rect, Color(0.08, 0.09, 0.11, 1.0), true)

	if portrait_texture:
		draw_texture_rect(portrait_texture, portrait_rect, false)
	else:
		draw_circle(Vector2.ZERO, 18, team_color)
		var fallback_text = unit.job.substr(0, 1).to_upper()
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-6, 6),
			fallback_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			Color.WHITE
		)

	draw_rect(Rect2(-24, 18, 48, 16), Color(0, 0, 0, 0.45), true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-22, 30),
		job_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		46,
		10,
		GameTheme.TEXT_PRIMARY
	)

	draw_rect(Rect2(10, -37, 20, 16), team_color.darkened(0.15), true)
	draw_rect(Rect2(10, -37, 20, 16), Color(1, 1, 1, 0.15), false, 1)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(11, -26),
		level_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		18,
		9,
		Color.WHITE
	)

	_draw_hp_bar()
	_draw_ap_indicator()

	var ring_color = Color.WHITE if selected else team_color.lightened(0.12)
	var ring_width = 3.5 if selected else 1.5
	draw_arc(Vector2.ZERO, 26, 0, TAU, 32, ring_color, ring_width)

	if selected:
		draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color(0.14, 0.85, 1.0, 0.8), 2)
	elif hover:
		draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color(1, 1, 1, 0.45), 1.5)

func _get_unit_color() -> Color:
	if unit.team == "player":
		return GameTheme.PLAYER_COLOR
	elif unit.team == "enemy":
		return GameTheme.ENEMY_COLOR
	return GameTheme.NEUTRAL_COLOR

func _draw_hp_bar() -> void:
	var bar_width = 46
	var bar_height = 5
	var bar_y = -34
	var hp_ratio = 0.0
	if unit.max_hp > 0:
		hp_ratio = clamp(float(unit.current_hp) / float(unit.max_hp), 0.0, 1.0)

	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(0, 0, 0, 0.65), true)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * hp_ratio, bar_height), GameTheme.get_hp_color(unit.current_hp, unit.max_hp), true)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(1, 1, 1, 0.2), false, 1)

func _draw_ap_indicator() -> void:
	var dot_radius = 2.5
	var spacing = 8
	var start_x = -((unit.max_ap - 1) * spacing) / 2.0
	var y = 33
	for i in range(unit.max_ap):
		var x = start_x + i * spacing
		var color = Color(0.2, 0.23, 0.28, 0.8)
		if i < unit.current_ap:
			color = Color(0.14, 0.62, 0.96, 0.95)
		draw_circle(Vector2(x, y), dot_radius, color)

func set_selected(s: bool) -> void:
	selected = s
	queue_redraw()

func set_hover(h: bool) -> void:
	hover = h
	queue_redraw()

func update_unit(u: Node) -> void:
	unit = u
	portrait_texture = ArtAssets.get_portrait_for_unit(unit.job, unit.team)
	queue_redraw()

func animate_move_to(target: Vector2) -> void:
	_base_position = target
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", target, 0.16)
	_move_tween.parallel().tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
	_move_tween.tween_property(self, "scale", Vector2.ONE, 0.12)

func flash_hit() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	tween.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(queue_free)
