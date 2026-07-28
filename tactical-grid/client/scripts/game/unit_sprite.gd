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

	# 阵营底座：保留清晰的棋盘可读性，主体轮廓在其上区分职业和敌人。
	draw_circle(Vector2.ZERO, radius, color.darkened(0.45))
	draw_circle(Vector2.ZERO, radius - 3, color.darkened(0.18))
	_draw_tactical_silhouette(color)

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

## 以简洁的俯视轮廓区分单位，而不是只显示单色圆点。
func _draw_tactical_silhouette(team_color: Color) -> void:
	var body_color := Color(0.075, 0.10, 0.13) if unit.team == "player" else Color(0.17, 0.055, 0.045)
	var highlight := team_color.lightened(0.22)
	if unit.team == "enemy":
		# 敌方使用机械菱形、核心和天线，缩小时仍能快速识别。
		var drone := PackedVector2Array([
			Vector2(0, -15), Vector2(14, 0), Vector2(0, 15), Vector2(-14, 0)
		])
		draw_colored_polygon(drone, body_color)
		draw_polyline(PackedVector2Array([drone[0], drone[1], drone[2], drone[3], drone[0]]), highlight, 2.0, true)
		draw_circle(Vector2.ZERO, 5, Color(1.0, 0.26, 0.18))
		draw_line(Vector2(0, -15), Vector2(0, -21), highlight, 2.0)
		draw_circle(Vector2(0, -22), 2, highlight)
		return

	# 玩家单位使用头盔、护甲和武器朝向的组合，职业用武器轮廓区分。
	draw_circle(Vector2(0, -7), 6, Color(0.70, 0.82, 0.86))
	draw_rect(Rect2(-9, -2, 18, 15), body_color, true)
	draw_rect(Rect2(-7, 0, 14, 8), highlight.darkened(0.45), true)
	draw_line(Vector2(-10, -2), Vector2(10, -2), highlight, 2.0)
	match unit.job:
		"sniper":
			draw_line(Vector2(4, 1), Vector2(19, -8), highlight, 3.0)
			draw_circle(Vector2(10, -3), 3, Color(0.75, 0.92, 1.0))
		"heavy":
			draw_rect(Rect2(5, -1, 13, 6), highlight.darkened(0.2), true)
			draw_line(Vector2(18, 2), Vector2(22, 2), highlight, 2.0)
		"medic":
			draw_circle(Vector2(0, 6), 4, Color(0.28, 0.95, 0.62))
			draw_line(Vector2(-4, 6), Vector2(4, 6), Color.WHITE, 1.5)
			draw_line(Vector2(0, 2), Vector2(0, 10), Color.WHITE, 1.5)
		"scout":
			draw_line(Vector2(5, 0), Vector2(16, -4), highlight, 2.0)
			draw_circle(Vector2(-8, -10), 2, Color(0.54, 0.98, 0.98))
		_:
			draw_line(Vector2(5, 1), Vector2(16, -5), highlight, 3.0)

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
