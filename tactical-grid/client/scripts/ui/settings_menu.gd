## 设置界面
extends Control
class_name SettingsMenu

@onready var difficulty_option = $Panel/Scroll/VBox/Difficulty/DifficultyOption
@onready var sfx_slider = $Panel/Scroll/VBox/Audio/SfxSlider
@onready var bgm_slider = $Panel/Scroll/VBox/Audio/BgmSlider
@onready var grid_toggle = $Panel/Scroll/VBox/Display/GridToggle
@onready var danger_zone_option = $Panel/Scroll/VBox/Display/DangerZoneOption
@onready var colorblind_option = $Panel/Scroll/VBox/Accessibility/ColorblindOption
@onready var large_font_toggle = $Panel/Scroll/VBox/Accessibility/LargeFontToggle
@onready var reduce_motion_toggle = $Panel/Scroll/VBox/Accessibility/ReduceMotionToggle
@onready var back_button = $Panel/BackButton

var settings: Dictionary = {}

func _ready() -> void:
	_load_settings()
	_setup_ui()
	back_button.pressed.connect(_on_back)

	# 连接信号
	difficulty_option.item_selected.connect(_on_setting_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	grid_toggle.toggled.connect(_on_setting_changed)
	colorblind_option.item_selected.connect(_on_setting_changed)
	large_font_toggle.toggled.connect(_on_setting_changed)
	reduce_motion_toggle.toggled.connect(_on_setting_changed)

func _load_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if file:
		settings = JSON.parse_string(file.get_as_text()) or {}
		file.close()

	if settings.is_empty():
		settings = _default_settings()

func _default_settings() -> Dictionary:
	return {
		"difficulty": "standard",
		"sfx_volume": 80,
		"bgm_volume": 70,
		"show_grid": "hover",
		"danger_zone_display": "selected",
		"colorblind_mode": "off",
		"large_font": false,
		"reduce_motion": false,
	}

func _setup_ui() -> void:
	# 难度
	difficulty_option.select(_get_difficulty_index(settings.difficulty))

	# 音量
	sfx_slider.value = settings.sfx_volume
	bgm_slider.value = settings.bgm_volume

	# 显示
	grid_toggle.button_pressed = settings.show_grid == "always"

	# 可访问性
	colorblind_option.select(_get_colorblind_index(settings.colorblind_mode))
	large_font_toggle.button_pressed = settings.large_font
	reduce_motion_toggle.button_pressed = settings.reduce_motion

func _get_difficulty_index(diff: String) -> int:
	match diff:
		"story": return 0
		"standard": return 1
		"hard": return 2
		"brutal": return 3
		_: return 1

func _get_colorblind_index(mode: String) -> int:
	match mode:
		"off": return 0
		"protanopia": return 1
		"deuteranopia": return 2
		"tritanopia": return 3
		_: return 0

func _on_setting_changed(_value = null) -> void:
	settings.difficulty = ["story", "standard", "hard", "brutal"][difficulty_option.selected]
	settings.show_grid = "always" if grid_toggle.button_pressed else "hover"
	settings.colorblind_mode = ["off", "protanopia", "deuteranopia", "tritanopia"][colorblind_option.selected]
	settings.large_font = large_font_toggle.button_pressed
	settings.reduce_motion = reduce_motion_toggle.button_pressed
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	settings.sfx_volume = int(value)
	_save_settings()

func _on_bgm_changed(value: float) -> void:
	settings.bgm_volume = int(value)
	_save_settings()

func _save_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
