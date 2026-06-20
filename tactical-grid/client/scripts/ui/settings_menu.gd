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
@onready var display_container = $Panel/VBox/Scroll/VBox/Display

var settings: Dictionary = {}

var _resolution_option: OptionButton = null
var _fullscreen_toggle: CheckBox = null
var _hotkey_button: Button = null
var _language_option: OptionButton = null

func _ready() -> void:
	_load_settings()
	_populate_options()
	_build_extra_display_options()
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
	if _resolution_option:
		_resolution_option.item_selected.connect(_on_resolution_changed)
	if _fullscreen_toggle:
		_fullscreen_toggle.toggled.connect(_on_fullscreen_changed)
	if _language_option:
		_language_option.item_selected.connect(_on_language_changed)
	if _hotkey_button:
		_hotkey_button.pressed.connect(_on_reset_hotkeys)

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

	var lang = settings.get("language", "zh")
	if lang in LocalizationManager.SUPPORTED_LANGUAGES:
		LocalizationManager.set_language(lang)

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
		"resolution": "1280x720",
		"fullscreen": false,
		"language": "zh",
		"hotkeys": _default_hotkeys(),
	}

func _default_hotkeys() -> Dictionary:
	return {
		"end_turn": "Key: Space",
		"select_next": "Key: Tab",
		"camera_up": "Key: W / Up",
		"camera_down": "Key: S / Down",
		"camera_left": "Key: A / Left",
		"camera_right": "Key: D / Right",
	}

func _build_extra_display_options() -> void:
	if not display_container:
		return

	var lang_row = HBoxContainer.new()
	var lang_label = Label.new()
	lang_label.text = "语言 / Language"
	lang_row.add_child(lang_label)
	_language_option = OptionButton.new()
	for lang in LocalizationManager.SUPPORTED_LANGUAGES:
		_language_option.add_item(LocalizationManager.get_language_name(lang))
		_language_option.set_item_metadata(_language_option.item_count - 1, lang)
	lang_row.add_child(_language_option)
	display_container.add_child(lang_row)

	var res_row = HBoxContainer.new()
	var res_label = Label.new()
	res_label.text = "分辨率"
	res_row.add_child(res_label)
	_resolution_option = OptionButton.new()
	for res in ["1280x720", "1600x900", "1920x1080", "2560x1440"]:
		_resolution_option.add_item(res)
	res_row.add_child(_resolution_option)
	display_container.add_child(res_row)

	_fullscreen_toggle = CheckBox.new()
	_fullscreen_toggle.text = "全屏模式"
	display_container.add_child(_fullscreen_toggle)

	_hotkey_button = Button.new()
	_hotkey_button.text = "重置默认快捷键"
	display_container.add_child(_hotkey_button)

func _setup_ui() -> void:
	difficulty_option.select(_get_difficulty_index(settings.get("difficulty", "standard")))
	sfx_slider.value = settings.get("sfx_volume", 80)
	bgm_slider.value = settings.get("bgm_volume", 70)
	grid_toggle.button_pressed = settings.get("show_grid", "hover") == "always"
	danger_zone_option.select(_get_danger_zone_index(settings.get("danger_zone_display", "selected")))
	colorblind_option.select(_get_colorblind_index(settings.get("colorblind_mode", "off")))
	large_font_toggle.button_pressed = settings.get("large_font", false)
	reduce_motion_toggle.button_pressed = settings.get("reduce_motion", false)
	if _resolution_option:
		var res_text = settings.get("resolution", "1280x720")
		for i in range(_resolution_option.item_count):
			if _resolution_option.get_item_text(i) == res_text:
				_resolution_option.select(i)
				break
	if _fullscreen_toggle:
		_fullscreen_toggle.button_pressed = settings.get("fullscreen", false)
	if _language_option:
		var lang = settings.get("language", "zh")
		for i in range(_language_option.item_count):
			if _language_option.get_item_metadata(i) == lang:
				_language_option.select(i)
				break
	_apply_audio()
	_apply_display()

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
	settings["difficulty"] = ["story", "standard", "hard", "brutal"][difficulty_option.selected]
	settings["show_grid"] = "always" if grid_toggle.button_pressed else "hover"
	settings["danger_zone_display"] = ["always", "selected", "off"][danger_zone_option.selected]
	settings["colorblind_mode"] = ["off", "protanopia", "deuteranopia", "tritanopia"][colorblind_option.selected]
	settings["large_font"] = large_font_toggle.button_pressed
	settings["reduce_motion"] = reduce_motion_toggle.button_pressed
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	settings["sfx_volume"] = int(value)
	_apply_audio()
	_save_settings()

func _on_bgm_changed(value: float) -> void:
	settings["bgm_volume"] = int(value)
	_apply_audio()
	_save_settings()

func _apply_audio() -> void:
	var sfx_vol = settings.get("sfx_volume", 80) / 100.0
	var bgm_vol = settings.get("bgm_volume", 70) / 100.0
	AudioManager.set_sfx_volume(sfx_vol)
	AudioManager.set_bgm_volume(bgm_vol)

func _on_resolution_changed(_index: int) -> void:
	if not _resolution_option:
		return
	settings["resolution"] = _resolution_option.get_item_text(_resolution_option.selected)
	_apply_display()
	_save_settings()

func _on_fullscreen_changed(_pressed: bool) -> void:
	settings["fullscreen"] = _fullscreen_toggle.button_pressed
	_apply_display()
	_save_settings()

func _on_language_changed(_index: int) -> void:
	if not _language_option:
		return
	var lang = _language_option.get_item_metadata(_language_option.selected)
	settings["language"] = lang
	LocalizationManager.set_language(lang)
	_save_settings()

func _apply_display() -> void:
	var fullscreen = settings.get("fullscreen", false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		var res_text = settings.get("resolution", "1280x720")
		var parts = res_text.split("x")
		if parts.size() == 2:
			DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))

func _on_reset_hotkeys() -> void:
	settings["hotkeys"] = _default_hotkeys()
	_save_settings()
	_hotkey_button.text = "快捷键已恢复默认（已保存）"
	await get_tree().create_timer(1.5).timeout
	_hotkey_button.text = "重置默认快捷键"

func _save_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func _on_back() -> void:
	TransitionManager.change_scene("res://scenes/main_menu.tscn")

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
