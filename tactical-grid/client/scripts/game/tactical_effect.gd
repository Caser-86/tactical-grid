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
		"network_takeover": duration = 0.50
		"network_disable": duration = 0.35
		"network_overload": duration = 0.65
		"selection": duration = 0.30
		"scan": duration = 0.45
		"upload": duration = 0.60
		"evac": duration = 0.70
	duration = AccessibilitySettings.get_effect_duration(duration)
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
		"network_takeover":
			# CH1-060: Cyan expanding ring with inward spark to signal ownership transfer.
			var radius := 6.0 + progress * 28.0
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(0.35, 1.0, 0.9, fade), 3.0)
			draw_arc(Vector2.ZERO, radius * 0.6, 0, TAU, 20, Color(0.6, 1.0, 1.0, fade * 0.7), 2.0)
			_draw_impact(Color(0.5, 1.0, 0.95, fade), radius * 0.4, 6, 2.0)
		"network_disable":
			# CH1-060: Grey spark burst to signal facility shutdown.
			var radius := 5.0 + progress * 18.0
			_draw_impact(Color(0.75, 0.75, 0.75, fade), radius, 6, 2.0)
			draw_arc(Vector2.ZERO, radius * 0.5, 0, TAU, 16, Color(0.6, 0.6, 0.6, fade * 0.6), 1.5)
		"network_overload":
			# CH1-060: Orange-red electric explosion for overload hazard.
			var radius := 8.0 + progress * 32.0
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.08, fade * 0.28))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(1.0, 0.65, 0.18, fade), 3.0)
			_draw_impact(Color(1.0, 0.85, 0.4, fade), radius, 8, 2.5)
		"selection":
			# CH1-090: Cyan double-ring pulse to confirm unit selection.
			var r1 := 10.0 + progress * 14.0
			var r2 := 6.0 + progress * 20.0
			draw_arc(Vector2.ZERO, r1, 0, TAU, 24, Color(0.35, 1.0, 0.9, fade), 2.5)
			draw_arc(Vector2.ZERO, r2, 0, TAU, 20, Color(0.6, 1.0, 1.0, fade * 0.6), 1.5)
		"scan":
			# CH1-090: Sweeping radar arc to signal network layer toggle.
			var sweep := progress * TAU
			var r := 14.0 + progress * 18.0
			draw_arc(Vector2.ZERO, r, sweep - 1.2, sweep, 16, Color(0.4, 1.0, 0.95, fade), 3.0)
			draw_arc(Vector2.ZERO, r, sweep - 0.6, sweep, 16, Color(0.6, 1.0, 1.0, fade * 0.5), 2.0)
			draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 24, Color(0.3, 0.9, 0.85, fade * 0.25), 1.0)
		"upload":
			# CH1-090: Ascending data stream to signal upload progress.
			for i in range(3):
				var offset := fmod(progress * 3.0 + float(i) * 0.33, 1.0)
				var y := 14.0 - offset * 28.0
				var a := (1.0 - offset) * fade
				draw_circle(Vector2((i - 1) * 5.0, y), 3.0, Color(0.2, 0.94, 1.0, a))
			draw_arc(Vector2(0, -14.0 - progress * 6.0), 8.0 + progress * 4.0, 0, TAU, 16, Color(0.64, 1.0, 1.0, fade), 2.0)
		"evac":
			# CH1-090: Green pillar to signal successful extraction.
			var h := 16.0 + progress * 36.0
			var w := 4.0 + (1.0 - progress) * 4.0
			draw_rect(Rect2(-w, -h, w * 2.0, h), Color(0.0, 1.0, 0.55, fade * 0.35))
			draw_arc(Vector2(0, -h), 10.0 + progress * 8.0, 0, TAU, 20, Color(0.3, 1.0, 0.75, fade), 2.5)
			draw_arc(Vector2(0, -h), 6.0 + progress * 4.0, 0, TAU, 16, Color(0.5, 1.0, 0.9, fade * 0.6), 1.5)
		_:
			_draw_impact(Color(1.0, 0.38, 0.22, fade), 7.0 + progress * 18.0, 6, 2.5)

func _draw_impact(color: Color, radius: float, rays: int, width: float) -> void:
	for i in range(rays):
		var angle := TAU * float(i) / float(rays)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(direction * (radius * 0.30), direction * radius, color, width)
