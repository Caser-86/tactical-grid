extends Node2D
class_name UnitSprite

var unit: Node
var selected: bool = false
var hover: bool = false

var portrait_texture: Texture2D
var unit_sprite_texture: Texture2D
var _base_position: Vector2 = Vector2.ZERO
var _move_tween: Tween

# 序列帧动画
var _frames: Array[Texture2D] = []
var _frame_index: int = 0
var _frame_timer: float = 0.0
var _frame_interval: float = 0.18
var _current_state: String = "idle"

func _process(delta: float) -> void:
	if not unit:
		return
	# 待机动画：轻微上下浮动
	var float_offset = sin(Time.get_time_dict_from_system().second + Engine.get_process_frames() * delta * 2.5) * 1.5
	position.y = _base_position.y + float_offset

	# 序列帧动画
	if _frames.size() > 1:
		_frame_timer += delta
		if _frame_timer >= _frame_interval:
			_frame_timer = 0.0
			_frame_index = (_frame_index + 1) % _frames.size()
			queue_redraw()

func _draw() -> void:
	if not unit:
		return

	var frame_rect = Rect2(-32, -44, 64, 88)
	var portrait_rect = Rect2(-20, -22, 40, 40)
	var team_color = _get_unit_color()
	var job_name = GameData.get_job(unit.job).get("name", unit.job)
	var level_text = "Lv.%d" % unit.stats.get("level", 1)

	draw_circle(Vector2(0, 8), 26, Color(0, 0, 0, 0.34))

	# 如果有单位精灵，优先绘制全身精灵
	if _frames.size() > 0 and _frame_index < _frames.size():
		var sprite_rect = Rect2(-32, -44, 64, 88)
		draw_texture_rect(_frames[_frame_index], sprite_rect, false)
	elif unit_sprite_texture:
		var sprite_rect = Rect2(-32, -44, 64, 88)
		draw_texture_rect(unit_sprite_texture, sprite_rect, false)
	else:
		# 否则绘制旧的框架+肖像
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
	unit_sprite_texture = ArtAssets.get_unit_sprite(unit.job, unit.team)
	play("idle")
	queue_redraw()

func play(state: String) -> void:
	if _current_state == state:
		return
	_current_state = state
	_frame_index = 0
	_frame_timer = 0.0
	if unit:
		_frames = ArtAssets.get_unit_sprite_frames(unit.job, state)
		if _frames.size() == 0 and state != "idle":
			_frames = ArtAssets.get_unit_sprite_frames(unit.job, "idle")
	queue_redraw()

func animate_move_to(target: Vector2) -> void:
	_base_position = target
	play("move")
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position:x", target.x, 0.16)
	_move_tween.parallel().tween_property(self, "position:y", target.y, 0.16)
	_move_tween.parallel().tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
	_move_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	_move_tween.tween_callback(func(): play("idle"))

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

func play_boss_hp_pulse() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.5)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)
	tween.set_loops(3)

func play_defeated_shatter() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_property(self, "rotation", rotation + PI, 0.6)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.6)
	tween.chain().tween_callback(queue_free)
