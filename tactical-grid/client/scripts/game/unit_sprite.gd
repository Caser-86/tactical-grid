## 单位精灵
## 程序化绘制单位，不依赖美术资源
extends Node2D
class_name UnitSprite

var unit: Node  # Unit
var selected: bool = false
var hover: bool = false

func _draw() -> void:
	if not unit:
		return

	var color = _get_unit_color()
	var radius = 22

	# 阴影
	draw_circle(Vector2(0, 4), radius, Color(0, 0, 0, 0.3))

	# 主体
	draw_circle(Vector2.ZERO, radius, color)

	# 边框
	var border_color = Color.WHITE if selected else color.darkened(0.3)
	var border_width = 3 if selected else 2
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, border_color, border_width)

	# HP 条
	_draw_hp_bar(radius)

	# AP 指示器
	_draw_ap_indicator(radius)

	# 职业图标
	_draw_job_icon()

	# 选中/悬停指示
	if selected:
		draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 32, Color.GREEN, 2)
	elif hover:
		draw_arc(Vector2.ZERO, radius + 4, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.5)

func _get_unit_color() -> Color:
	if unit.team == "player":
		return GameTheme.PLAYER_COLOR
	elif unit.team == "enemy":
		return GameTheme.ENEMY_COLOR
	else:
		return GameTheme.NEUTRAL_COLOR

func _draw_hp_bar(radius: int) -> void:
	var bar_width = radius * 2
	var bar_height = 4
	var bar_y = -radius - 10

	# 背景
	draw_rect(
		Rect2(-bar_width / 2, bar_y, bar_width, bar_height),
		Color(0, 0, 0, 0.6),
		true
	)

	# HP
	var hp_ratio = float(unit.current_hp) / float(unit.max_hp)
	var hp_color = GameTheme.get_hp_color(unit.current_hp, unit.max_hp)
	draw_rect(
		Rect2(-bar_width / 2, bar_y, bar_width * hp_ratio, bar_height),
		hp_color,
		true
	)

	# 边框
	draw_rect(
		Rect2(-bar_width / 2, bar_y, bar_width, bar_height),
		Color(1, 1, 1, 0.6),
		false, 1
	)

func _draw_ap_indicator(radius: int) -> void:
	var dot_radius = 3
	var spacing = 8
	var start_x = -((unit.max_ap - 1) * spacing) / 2.0
	var y = radius + 8

	for i in range(unit.max_ap):
		var x = start_x + i * spacing
		if i < unit.current_ap:
			draw_circle(Vector2(x, y), dot_radius, Color(0.13, 0.59, 0.95))
		else:
			draw_circle(Vector2(x, y), dot_radius, Color(0.2, 0.2, 0.2))

func _draw_job_icon() -> void:
	# 用文字表示职业
	var label = unit.job[0].to_upper()
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-5, 5),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		16,
		Color.WHITE
	)

func set_selected(s: bool) -> void:
	selected = s
	queue_redraw()

func set_hover(h: bool) -> void:
	hover = h
	queue_redraw()

func update_unit(u: Node) -> void:
	unit = u
	queue_redraw()
