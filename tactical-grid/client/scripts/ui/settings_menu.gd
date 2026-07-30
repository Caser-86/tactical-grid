## 设置菜单
extends Control

@onready var resolution_option = $Panel/ScrollContainer/VBoxContainer/ResolutionOption
@onready var fullscreen_check = $Panel/ScrollContainer/VBoxContainer/FullscreenCheck
@onready var master_slider = $Panel/ScrollContainer/VBoxContainer/MasterSlider
@onready var music_slider = $Panel/ScrollContainer/VBoxContainer/MusicSlider
@onready var sfx_slider = $Panel/ScrollContainer/VBoxContainer/SFXSlider
@onready var difficulty_option = $Panel/ScrollContainer/VBoxContainer/DifficultyOption
@onready var large_text_check = $Panel/ScrollContainer/VBoxContainer/LargeTextCheck
@onready var reduce_motion_check = $Panel/ScrollContainer/VBoxContainer/ReduceMotionCheck
@onready var colorblind_option = $Panel/ScrollContainer/VBoxContainer/ColorblindOption
@onready var subtitle_speed_slider = $Panel/ScrollContainer/VBoxContainer/SubtitleSpeedSlider
@onready var keybinding_button = $Panel/ScrollContainer/VBoxContainer/KeybindingButton
@onready var back_button = $Panel/ScrollContainer/VBoxContainer/BackButton
@onready var resolution_confirm_panel = $ResolutionConfirmPanel
@onready var resolution_confirm_label = $ResolutionConfirmPanel/VBoxContainer/Message
@onready var resolution_keep_button = $ResolutionConfirmPanel/VBoxContainer/Buttons/KeepButton
@onready var resolution_revert_button = $ResolutionConfirmPanel/VBoxContainer/Buttons/RevertButton
@onready var resolution_confirm_timer = $ResolutionConfirmTimer

const RESOLUTIONS = ["1280x720", "1920x1080", "2560x1440"]
const DIFFICULTIES = ["story", "standard", "hard"]
const COLORBLIND_MODES = ["none", "protanopia", "deuteranopia", "tritanopia"]
const COLORBLIND_LABELS = ["关闭", "红色盲", "绿色盲", "蓝色盲"]

var _settings: Dictionary = {}
var _caller: String = "main_menu"
var _binding_dialog: PanelContainer
var _binding_buttons: Dictionary = {}
var _pending_binding_action := ""
var _pending_resolution := ""
var _previous_resolution := ""
var _resolution_seconds_remaining := 0

const BINDING_LABELS := {
	"pause": "暂停/返回",
	"end_turn": "结束回合",
	"next_unit": "下一个单位",
	"toggle_overview": "概览",
	"toggle_network": "切换网络",
}

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.SETTINGS
	_settings = GameManager.get_settings().duplicate(true)
	_setup_ui()
	back_button.pressed.connect(_on_back)
	keybinding_button.pressed.connect(_open_keybinding_dialog)
	resolution_keep_button.pressed.connect(_keep_pending_resolution)
	resolution_revert_button.pressed.connect(_revert_pending_resolution)
	resolution_confirm_timer.timeout.connect(_on_resolution_confirm_tick)
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
	_set_window_resolution(resolution)

	if _settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _set_window_resolution(resolution: String) -> void:
	var parts = resolution.split("x")
	if parts.size() == 2:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))

func _apply_audio() -> void:
	AudioManager.set_bus_volumes(
		_settings.get("master_volume", 1.0),
		_settings.get("music_volume", 1.0),
		_settings.get("sfx_volume", 1.0)
	)

## 应用可访问性设置到当前场景树
## - large_text: 放大默认字体尺寸
## - reduce_motion: 禁用Tween自动播放（由各UI脚本自行检查）
## - colorblind_mode: 调整战场高亮配色（由BattleController读取）
## - subtitle_speed: 控制对话逐字显示速度（由DialogueSystem读取）
func _apply_accessibility() -> void:
	AccessibilitySettings.apply_settings(_settings)

func _on_resolution_changed(index: int) -> void:
	_begin_resolution_confirmation(RESOLUTIONS[index])

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
	if not _pending_resolution.is_empty():
		_revert_pending_resolution()
	_apply()
	if _caller == "pause":
		# 返回暂停菜单：由调用者决定
		queue_free()
	else:
		GameManager.go_to_main_menu()

func _begin_resolution_confirmation(resolution: String) -> void:
	if resolution == _settings.get("resolution", "1280x720"):
		return
	if _pending_resolution.is_empty():
		_previous_resolution = _settings.get("resolution", "1280x720")
	_pending_resolution = resolution
	_resolution_seconds_remaining = 15
	_set_window_resolution(resolution)
	resolution_confirm_panel.show()
	resolution_keep_button.grab_focus()
	_update_resolution_confirm_message()
	resolution_confirm_timer.start()

func _keep_pending_resolution() -> void:
	if _pending_resolution.is_empty():
		return
	_settings["resolution"] = _pending_resolution
	resolution_confirm_timer.stop()
	_pending_resolution = ""
	resolution_confirm_panel.hide()
	_apply()

func _revert_pending_resolution() -> void:
	if _pending_resolution.is_empty():
		return
	_set_window_resolution(_previous_resolution)
	resolution_option.select(RESOLUTIONS.find(_previous_resolution))
	resolution_confirm_timer.stop()
	_pending_resolution = ""
	resolution_confirm_panel.hide()

func _on_resolution_confirm_tick() -> void:
	_resolution_seconds_remaining -= 1
	if _resolution_seconds_remaining <= 0:
		_revert_pending_resolution()
		return
	_update_resolution_confirm_message()

func _update_resolution_confirm_message() -> void:
	resolution_confirm_label.text = "正在预览 %s。将在 %d 秒后自动恢复。" % [_pending_resolution, _resolution_seconds_remaining]

func _open_keybinding_dialog() -> void:
	if _binding_dialog:
		return
	_binding_dialog = PanelContainer.new()
	_binding_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_binding_dialog.position = Vector2(-220, -180)
	_binding_dialog.size = Vector2(440, 360)
	_binding_dialog.z_index = 10
	add_child(_binding_dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_binding_dialog.add_child(content)
	var title := Label.new()
	title.text = "按键绑定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var help := Label.new()
	help.text = "选择一项后按下新按键。Esc 取消当前修改。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	for action in InputBindings.ACTIONS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(_begin_rebind.bind(action, button))
		content.add_child(button)
		_binding_buttons[action] = button
	_refresh_binding_buttons()
	var restore := Button.new()
	restore.text = "恢复默认按键"
	restore.pressed.connect(_restore_default_bindings)
	content.add_child(restore)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(_close_keybinding_dialog)
	content.add_child(close)
	close.grab_focus()

func _begin_rebind(action: String, button: Button) -> void:
	_pending_binding_action = action
	button.text = "%s：请按下新按键..." % BINDING_LABELS[action]
	button.grab_focus()

func _input(event: InputEvent) -> void:
	if _pending_binding_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_pending_binding_action = ""
		_refresh_binding_buttons()
		get_viewport().set_input_as_handled()
		return
	var binding := {"keycode": event.keycode, "physical_keycode": event.physical_keycode}
	_settings["keybindings"][_pending_binding_action] = binding
	InputBindings.set_binding(_pending_binding_action, binding)
	_pending_binding_action = ""
	_apply()
	_refresh_binding_buttons()
	get_viewport().set_input_as_handled()

func _restore_default_bindings() -> void:
	_settings["keybindings"] = InputBindings.restore_defaults()
	_apply()
	_refresh_binding_buttons()

func _refresh_binding_buttons() -> void:
	for action in _binding_buttons:
		var button: Button = _binding_buttons[action]
		button.text = "%s：%s" % [BINDING_LABELS[action], InputBindings.get_binding_label(action)]

func _close_keybinding_dialog() -> void:
	_pending_binding_action = ""
	_binding_buttons.clear()
	_binding_dialog.queue_free()
	_binding_dialog = null
	keybinding_button.grab_focus()
