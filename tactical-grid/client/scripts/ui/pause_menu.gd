## 暂停菜单
## 可实例化到任意场景之上
extends Control

signal resumed
signal returned_to_main_menu
signal opened_settings

@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var settings_button = $Panel/VBoxContainer/SettingsButton
@onready var main_menu_button = $Panel/VBoxContainer/MainMenuButton
@onready var quit_button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	_apply_visual_theme()
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	main_menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)

	resume_button.grab_focus()
	get_tree().paused = true

func _apply_visual_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("111c23")
	panel_style.border_color = Color("3dc5d7")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 18
	$Panel.add_theme_stylebox_override("panel", panel_style)
	$Panel/VBoxContainer/Title.add_theme_font_size_override("font_size", 28)
	$Panel/VBoxContainer/Title.modulate = Color("dffaff")

	for button in [resume_button, settings_button, main_menu_button, quit_button]:
		_style_button(button)
	quit_button.add_theme_color_override("font_color", Color("f0b4a6"))

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("172b34")
	normal.border_color = Color("3b8896")
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_right = 5
	normal.corner_radius_bottom_left = 5
	var hover := normal.duplicate()
	hover.bg_color = Color("1e4b55")
	hover.border_color = Color("78e0e7")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("0b1519")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("e6f4f4"))
	button.add_theme_font_size_override("font_size", 17)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume()

func _on_resume() -> void:
	get_tree().paused = false
	resumed.emit()
	queue_free()

func _on_settings() -> void:
	opened_settings.emit()

func _on_main_menu() -> void:
	get_tree().paused = false
	GameManager.save_current()
	returned_to_main_menu.emit()
	GameManager.go_to_main_menu()

func _on_quit() -> void:
	GameManager.save_current()
	GameManager.quit_game()
