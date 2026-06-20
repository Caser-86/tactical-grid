extends CanvasLayer

## 简单性能监控器（开发/测试用）

var _label: Label = null
var _timer: Timer = null
var enabled: bool = false

func _ready() -> void:
	layer = 127
	_label = Label.new()
	_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_label.offset_right = -10
	_label.offset_top = 10
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.visible = false
	add_child(_label)

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_update)
	add_child(_timer)

	# 通过命令行参数 --perf 或项目设置开启
	if OS.has_feature("editor") or OS.get_cmdline_args().has("--perf"):
		set_enabled(true)

func set_enabled(value: bool) -> void:
	enabled = value
	_label.visible = enabled
	if enabled:
		_timer.start()
	else:
		_timer.stop()

func _update() -> void:
	var fps = Engine.get_frames_per_second()
	var mem = OS.get_static_memory_usage() / 1024.0 / 1024.0
	var mem_peak = OS.get_static_memory_peak_usage() / 1024.0 / 1024.0
	var objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_label.text = "FPS: %d\nMEM: %.1f / %.1f MB\nOBJ: %d  NODE: %d" % [fps, mem, mem_peak, objects, nodes]
