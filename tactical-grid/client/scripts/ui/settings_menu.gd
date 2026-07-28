## 设置菜单
extends Control

@onready var resolution_option = $Panel/VBoxContainer/ResolutionOption
@onready var fullscreen_check = $Panel/VBoxContainer/FullscreenCheck
@onready var master_slider = $Panel/VBoxContainer/MasterSlider
@onready var music_slider = $Panel/VBoxContainer/MusicSlider
@onready var sfx_slider = $Panel/VBoxContainer/SFXSlider
@onready var difficulty_option = $Panel/VBoxContainer/DifficultyOption
@onready var large_text_check = $Panel/VBoxContainer/LargeTextCheck
@onready var reduce_motion_check = $Panel/VBoxContainer/ReduceMotionCheck
@onready var colorblind_option = $Panel/VBoxContainer/ColorblindOption
@onready var subtitle_speed_slider = $Panel/VBoxContainer/SubtitleSpeedSlider
@onready var back_button = $Panel/VBoxContainer/BackButton

const RESOLUTIONS = ["1280x720", "1920x1080", "2560x1440"]
const DIFFICULTIES = ["story", "standard", "hard"]
const COLORBLIND_MODES = ["none", "protanopia", "deuteranopia", "tritanopia"]
const COLORBLIND_LABELS = ["关闭", "红色盲", "绿色盲", "蓝色盲"]

var _settings: Dictionary = {}
var _caller: String = "main_menu"

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.SETTINGS
	_settings = GameManager.get_settings().duplicate(true)
	_setup_ui()
	back_button.pressed.connect(_on_back)
	back_button.grab_focus()

func _setup_ui() -> void:
	# 分辨率
	resolution_option.clear()
	for r in RESOLUTIONS:
		resolution_option.add_item(r)
	var res = _settings.get("resolution", "1280x720")
	var res_index = RESOLUTIONS.find(res)
	resolution_option.selected = res_index if res_index >= 0 else 0
	resolution_option.item_selected.connect(_on_resolution_changed)

	# 全屏
	fullscreen_check.button_pressed = _settings.get("fullscreen", false)
	fullscreen_check.toggled.connect(_on_fullscreen_changed)

	# 音量
	master_slider.value = _settings.get("master_volume", 1.0) * 100.0
	music_slider.value = _settings.get("music_volume", 1.0) * 100.0
	sfx_slider.value = _settings.get("sfx_volume", 1.0) * 100.0
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	# 难度
	difficulty_option.clear()
	for d in DIFFICULTIES:
		difficulty_option.add_item(d)
	var diff = _settings.get("difficulty", "standard")
	var diff_index = DIFFICULTIES.find(diff)
	difficulty_option.selected = diff_index if diff_index >= 0 else 1
	difficulty_option.item_selected.connect(_on_difficulty_changed)

	# 可访问性：大字体
	large_text_check.button_pressed = _settings.get("large_text", false)
	large_text_check.toggled.connect(_on_large_text_changed)

	# 可访问性：减少动态效果
	reduce_motion_check.button_pressed = _settings.get("reduce_motion", false)
	reduce_motion_check.toggled.connect(_on_reduce_motion_changed)

	# 可访问性：色弱配色
	colorblind_option.clear()
	for label in COLORBLIND_LABELS:
		colorblind_option.add_item(label)
	var cb_mode = _settings.get("colorblind_mode", "none")
	var cb_index = COLORBLIND_MODES.find(cb_mode)
	colorblind_option.selected = cb_index if cb_index >= 0 else 0
	colorblind_option.item_selected.connect(_on_colorblind_changed)

	# 可访问性：字幕/文字速度
	subtitle_speed_slider.value = _settings.get("subtitle_speed", 1.0)
	subtitle_speed_slider.value_changed.connect(_on_subtitle_speed_changed)

func _apply() -> void:
	GameManager.update_settings(_settings)
	_apply_display()
	_apply_audio()
	_apply_accessibility()

func _apply_display() -> void:
	var resolution = _settings.get("resolution", "1280x720")
	var parts = resolution.split("x")
	if parts.size() == 2:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))

	if _settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(_settings.get("master_volume", 1.0)))

## 应用可访问性设置到当前场景树
## - large_text: 放大默认字体尺寸
## - reduce_motion: 禁用Tween自动播放（由各UI脚本自行检查）
## - colorblind_mode: 调整战场高亮配色（由BattleController读取）
## - subtitle_speed: 控制对话逐字显示速度（由DialogueSystem读取）
func _apply_accessibility() -> void:
	var window = get_tree().root
	if _settings.get("large_text", false):
		# 主题默认字体尺寸放大到 20，普通为 14-16
		if not window.has_theme_font_size("font"):
			window.set_theme_font_size("font", 20)
	else:
		window.set_theme_font_size("font", 0)  # 0 表示使用默认
	# reduce_motion / colorblind_mode / subtitle_speed 由各业务系统读取 settings 自行处理
	# 这里只负责触发设置变更，确保 GameManager 已经持久化

func _on_resolution_changed(index: int) -> void:
	_settings["resolution"] = RESOLUTIONS[index]
	_apply()

func _on_fullscreen_changed(enabled: bool) -> void:
	_settings["fullscreen"] = enabled
	_apply()

func _on_master_changed(value: float) -> void:
	_settings["master_volume"] = value / 100.0
	_apply()

func _on_music_changed(value: float) -> void:
	_settings["music_volume"] = value / 100.0
	_apply()

func _on_sfx_changed(value: float) -> void:
	_settings["sfx_volume"] = value / 100.0
	_apply()

func _on_difficulty_changed(index: int) -> void:
	_settings["difficulty"] = DIFFICULTIES[index]
	_apply()

func _on_large_text_changed(enabled: bool) -> void:
	_settings["large_text"] = enabled
	_apply()

func _on_reduce_motion_changed(enabled: bool) -> void:
	_settings["reduce_motion"] = enabled
	_apply()

func _on_colorblind_changed(index: int) -> void:
	_settings["colorblind_mode"] = COLORBLIND_MODES[index]
	_apply()

func _on_subtitle_speed_changed(value: float) -> void:
	_settings["subtitle_speed"] = value
	_apply()

func _on_back() -> void:
	_apply()
	if _caller == "pause":
		# 返回暂停菜单：由调用者决定
		queue_free()
	else:
		GameManager.go_to_main_menu()
