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
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	main_menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)

	resume_button.grab_focus()
	get_tree().paused = true

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
