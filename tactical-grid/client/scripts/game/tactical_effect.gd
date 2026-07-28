## 短生命周期程序化战斗特效，所有视觉状态都在动画结束时自动清理。
extends Node2D
class_name TacticalEffect

var effect_type := "hit"
var elapsed := 0.0
var duration := 0.35

func setup(kind: String) -> void:
	effect_type = kind
	match kind:
		"explosion", "destroy": duration = 0.55
		"heal", "terminal": duration = 0.70
		"miss": duration = 0.28
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	match effect_type:
		"muzzle":
			var length := 10.0 + progress * 16.0
			draw_line(Vector2.ZERO, Vector2(length, -length * 0.4), Color(1.0, 0.78, 0.26, fade), 3.0)
			draw_line(Vector2.ZERO, Vector2(length * 0.65, length * 0.42), Color(1.0, 0.94, 0.62, fade), 2.0)
		"crit":
			_draw_impact(Color(1.0, 0.78, 0.16, fade), 8.0 + progress * 22.0, 8, 3.0)
		"miss":
			draw_arc(Vector2.ZERO, 14.0 + progress * 11.0, 0.45, 2.7, 16, Color(0.70, 0.82, 0.90, fade), 2.0)
			draw_arc(Vector2.ZERO, 14.0 + progress * 11.0, 3.6, 5.85, 16, Color(0.70, 0.82, 0.90, fade), 2.0)
		"explosion", "destroy":
			var radius := 8.0 + progress * (34.0 if effect_type == "explosion" else 26.0)
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.26, 0.06, fade * 0.26))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(1.0, 0.72, 0.22, fade), 3.0)
			_draw_impact(Color(1.0, 0.90, 0.54, fade), radius, 7, 2.0)
		"heal":
			var radius := 8.0 + progress * 22.0
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(0.24, 1.0, 0.62, fade), 2.5)
			draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.84, 1.0, 0.92, fade), 2.5)
			draw_line(Vector2(0, -7), Vector2(0, 7), Color(0.84, 1.0, 0.92, fade), 2.5)
		"terminal":
			var height := 22.0 + progress * 18.0
			draw_line(Vector2(0, 12), Vector2(0, -height), Color(0.20, 0.94, 1.0, fade), 3.0)
			draw_arc(Vector2(0, -height), 9.0 + progress * 6.0, 0, TAU, 20, Color(0.64, 1.0, 1.0, fade), 2.0)
		_:
			_draw_impact(Color(1.0, 0.38, 0.22, fade), 7.0 + progress * 18.0, 6, 2.5)

func _draw_impact(color: Color, radius: float, rays: int, width: float) -> void:
	for i in range(rays):
		var angle := TAU * float(i) / float(rays)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(direction * (radius * 0.30), direction * radius, color, width)
