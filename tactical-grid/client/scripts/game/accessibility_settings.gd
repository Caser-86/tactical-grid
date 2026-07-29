## 统一应用会影响运行时表现的无障碍设置。
extends Node

const UI_THEME_PATH := "res://themes/tactical_ui_theme.tres"
const DEFAULT_FONT_SIZE := 16
const LARGE_FONT_SIZE := 20

func apply_settings(settings: Dictionary) -> void:
	var ui_theme := load(UI_THEME_PATH) as Theme
	if ui_theme:
		ui_theme.default_font_size = LARGE_FONT_SIZE if settings.get("large_text", false) else DEFAULT_FONT_SIZE

func get_effect_duration(base_duration: float) -> float:
	if GameManager.get_settings().get("reduce_motion", false):
		# 保留命中反馈，但不让动态效果阻塞玩家的下一步判断。
		return maxf(0.12, base_duration * 0.35)
	return base_duration

func get_highlight_color(role: String, fallback: Color) -> Color:
	var mode := String(GameManager.get_settings().get("colorblind_mode", "none"))
	if mode == "none":
		return fallback

	var alpha: float = fallback.a
	match mode:
		"protanopia", "deuteranopia":
			match role:
				"attack": return Color(1.0, 0.72, 0.10, alpha)
				"move", "ally": return Color(0.10, 0.62, 1.0, alpha)
				"path", "selected", "evac": return Color(0.78, 0.32, 1.0, alpha)
				"target", "terminal": return Color(0.08, 0.92, 0.86, alpha)
		"tritanopia":
			match role:
				"attack": return Color(1.0, 0.38, 0.08, alpha)
				"move", "ally": return Color(0.20, 0.86, 0.30, alpha)
				"path", "selected", "evac": return Color(0.92, 0.24, 0.56, alpha)
				"target", "terminal": return Color(1.0, 0.82, 0.14, alpha)
	return fallback
