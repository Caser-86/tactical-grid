## 主菜单控制器
extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU

	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

	# 检查是否有存档
	var has_save = SaveManager.has_any_save()
	continue_button.disabled = not has_save

	# 设置焦点
	if has_save:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()

func _on_continue() -> void:
	if not GameManager.continue_game():
		continue_button.disabled = true

func _on_new_game() -> void:
	GameManager.new_game(0)

func _on_settings() -> void:
	GameManager.go_to_settings("main_menu")

func _on_quit() -> void:
	GameManager.quit_game()
