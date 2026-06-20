extends CanvasLayer

## 全屏场景过渡与加载画面

var _overlay: ColorRect = null
var _label: Label = null
var _tween: Tween = null

const DEFAULT_FADE_DURATION := 0.35
const DEFAULT_COLOR := Color(0.05, 0.05, 0.08, 1.0)

func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color.TRANSPARENT
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_label = Label.new()
	_label.name = "LoadingLabel"
	_label.text = "加载中..."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchors_preset = Control.PRESET_FULL_RECT
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.visible = false
	add_child(_label)

func fade_out(color: Color = DEFAULT_COLOR, duration: float = DEFAULT_FADE_DURATION) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_overlay.color = Color(color.r, color.g, color.b, 0.0)
	_label.visible = false
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_overlay, "color:a", 1.0, duration)
	return _tween

func fade_in(duration: float = DEFAULT_FADE_DURATION) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_label.visible = false
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_overlay, "color:a", 0.0, duration)
	_tween.finished.connect(func(): _overlay.color = Color.TRANSPARENT)
	return _tween

func show_loading(text: String = "加载中...") -> void:
	_overlay.color = DEFAULT_COLOR
	_label.text = text
	_label.visible = true

func hide_loading() -> void:
	_label.visible = false
	fade_in()

func change_scene(path: String) -> void:
	var tw = fade_out()
	tw.finished.connect(func():
		get_tree().change_scene_to_file(path)
		call_deferred("_fade_in_after_scene_change")
	)

func change_scene_with_loading(path: String) -> void:
	var tw = fade_out()
	tw.finished.connect(func():
		show_loading()
		get_tree().change_scene_to_file(path)
		call_deferred("_fade_in_after_scene_change")
	)

func _fade_in_after_scene_change() -> void:
	fade_in()
