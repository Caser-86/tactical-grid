extends Control
class_name SettingsMenu

@onready var difficulty_option = $Panel/VBox/Scroll/VBox/Difficulty/DifficultyOption
@onready var sfx_slider = $Panel/VBox/Scroll/VBox/Audio/SfxSlider
@onready var bgm_slider = $Panel/VBox/Scroll/VBox/Audio/BgmSlider
@onready var grid_toggle = $Panel/VBox/Scroll/VBox/Display/GridToggle
@onready var danger_zone_option = $Panel/VBox/Scroll/VBox/Display/DangerZoneOption
@onready var colorblind_option = $Panel/VBox/Scroll/VBox/Accessibility/ColorblindOption
@onready var large_font_toggle = $Panel/VBox/Scroll/VBox/Accessibility/LargeFontToggle
@onready var reduce_motion_toggle = $Panel/VBox/Scroll/VBox/Accessibility/ReduceMotionToggle
@onready var back_button = $Panel/BackButton

var settings: Dictionary = {}

func _ready() -> void:
	_load_settings()
	_populate_options()
	_setup_ui()
	back_button.pressed.connect(_on_back)

	difficulty_option.item_selected.connect(_on_setting_changed)
	danger_zone_option.item_selected.connect(_on_setting_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	grid_toggle.toggled.connect(_on_setting_changed)
	colorblind_option.item_selected.connect(_on_setting_changed)
	large_font_toggle.toggled.connect(_on_setting_changed)
	reduce_motion_toggle.toggled.connect(_on_setting_changed)

func _populate_options() -> void:
	if difficulty_option.item_count == 0:
		difficulty_option.add_item("剧情")
		difficulty_option.add_item("标准")
		difficulty_option.add_item("困难")
		difficulty_option.add_item("残酷")

	if danger_zone_option.item_count == 0:
		danger_zone_option.add_item("始终显示")
		danger_zone_option.add_item("选中时")
		danger_zone_option.add_item("关闭")

	if colorblind_option.item_count == 0:
		colorblind_option.add_item("关闭")
		colorblind_option.add_item("红色弱视")
		colorblind_option.add_item("绿色弱视")
		colorblind_option.add_item("蓝黄色弱视")

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
	difficulty_option.select(_get_difficulty_index(settings.get("difficulty", "standard")))
	sfx_slider.value = settings.get("sfx_volume", 80)
	bgm_slider.value = settings.get("bgm_volume", 70)
	grid_toggle.button_pressed = settings.get("show_grid", "hover") == "always"
	danger_zone_option.select(_get_danger_zone_index(settings.get("danger_zone_display", "selected")))
	colorblind_option.select(_get_colorblind_index(settings.get("colorblind_mode", "off")))
	large_font_toggle.button_pressed = settings.get("large_font", false)
	reduce_motion_toggle.button_pressed = settings.get("reduce_motion", false)

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

func _get_danger_zone_index(mode: String) -> int:
	match mode:
		"always": return 0
		"selected": return 1
		"off": return 2
		_: return 1

func _on_setting_changed(_value = null) -> void:
	settings.difficulty = ["story", "standard", "hard", "brutal"][difficulty_option.selected]
	settings.show_grid = "always" if grid_toggle.button_pressed else "hover"
	settings.danger_zone_display = ["always", "selected", "off"][danger_zone_option.selected]
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

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
