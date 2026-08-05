extends Control

@onready var continue_v2_button: Button = $VBoxContainer/ContinueV2Button
@onready var new_v2_game_button: Button = $VBoxContainer/NewV2GameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU
	AudioManager.bgm_menu()
	continue_v2_button.pressed.connect(_on_continue_v2)
	new_v2_game_button.pressed.connect(_on_new_v2_game)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	continue_v2_button.disabled = not SaveManager.has_any_v2_save()
	if continue_v2_button.disabled:
		new_v2_game_button.grab_focus()
	else:
		continue_v2_button.grab_focus()

func _on_continue_v2() -> void:
	AudioManager.sfx_ui_click()
	if GameManager.continue_v2_game():
		GameManager.go_to_base()
	else:
		continue_v2_button.disabled = true

func _on_new_v2_game() -> void:
	AudioManager.sfx_ui_click()
	if GameManager.new_v2_game(0):
		GameManager.go_to_base()

func _on_settings() -> void:
	AudioManager.sfx_ui_click()
	GameManager.go_to_settings("main_menu")

func _on_quit() -> void:
	AudioManager.sfx_ui_click()
	GameManager.quit_game()
