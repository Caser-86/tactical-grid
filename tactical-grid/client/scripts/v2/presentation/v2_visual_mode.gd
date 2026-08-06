extends RefCounted
class_name V2VisualMode

## V2 设置的单一规范入口。
## 只允许三档文字缩放和三种视觉模式，避免前台选项与运行时能力漂移。

const VISUAL_MODES := [&"normal", &"grayscale", &"deuteranopia_assist"]
const UI_SCALES := [1.0, 1.25, 1.5]
const DEFAULT_RESOLUTION := "1280x720"
const InputBindingsScript = preload("res://scripts/game/input_bindings.gd")

static var _current_settings: Dictionary = {}

static func default_settings() -> Dictionary:
	return {
		"ui_scale": 1.0,
		"visual_mode": "normal",
		"fullscreen": false,
		"resolution": DEFAULT_RESOLUTION,
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"pan_speed": 1.0,
		"screen_shake": true,
		"reduce_motion": false,
		"subtitle_speed": 1.0,
		"keybindings": {},
	}

static func normalize(settings: Dictionary) -> Dictionary:
	var normalized := default_settings()
	for key in normalized.keys():
		if settings.has(key):
			normalized[key] = settings[key]
	# 兼容旧档的大字体和色弱字段，只在 V2 进入设置时转换一次。
	if not settings.has("ui_scale") and bool(settings.get("large_text", false)):
		normalized["ui_scale"] = 1.25
	if not settings.has("visual_mode"):
		var legacy_mode := String(settings.get("colorblind_mode", "none"))
		normalized["visual_mode"] = "grayscale" if legacy_mode == "grayscale" else "deuteranopia_assist" if legacy_mode == "deuteranopia" else "normal"
	var scale := float(normalized.get("ui_scale", 1.0))
	normalized["ui_scale"] = _nearest_scale(scale)
	var mode := StringName(String(normalized.get("visual_mode", "normal")))
	normalized["visual_mode"] = String(mode if mode in VISUAL_MODES else &"normal")
	if not normalized["keybindings"] is Dictionary:
		normalized["keybindings"] = {}
	var bindings := InputBindingsScript.new()
	bindings.ensure_settings(normalized)
	return normalized

static func apply(settings: Dictionary) -> Dictionary:
	_current_settings = normalize(settings)
	return _current_settings.duplicate(true)

static func current_ui_scale() -> float:
	return float(_current_settings.get("ui_scale", 1.0))

static func current_mode() -> StringName:
	return StringName(String(_current_settings.get("visual_mode", "normal")))

static func _nearest_scale(value: float) -> float:
	var best := UI_SCALES[0]
	var distance := absf(value - best)
	for candidate in UI_SCALES:
		if absf(value - float(candidate)) < distance:
			best = candidate
			distance = absf(value - float(candidate))
	return best
