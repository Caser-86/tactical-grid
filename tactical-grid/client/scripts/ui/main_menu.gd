## 主菜单控制器
extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var continue_v2_button = $VBoxContainer/ContinueV2Button
@onready var new_v2_game_button = $VBoxContainer/NewV2GameButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU
	AudioManager.bgm_menu()

	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	continue_v2_button.pressed.connect(_on_continue_v2)
	new_v2_game_button.pressed.connect(_on_new_v2_game)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

	# V1 与 V2 分别显示可继续状态，避免继续按钮误读另一条产品线的存档。
	var has_v1_save := SaveManager.has_any_save()
	var has_v2_save := SaveManager.has_any_v2_save()
	continue_button.disabled = not has_v1_save
	continue_v2_button.disabled = not has_v2_save

	# 设置焦点
	if has_v2_save:
		continue_v2_button.grab_focus()
	elif has_v1_save:
		continue_button.grab_focus()
	else:
		new_v2_game_button.grab_focus()

func _on_continue() -> void:
	AudioManager.sfx_ui_click()
	if not GameManager.continue_game():
		continue_button.disabled = true

func _on_new_game() -> void:
	AudioManager.sfx_ui_click()
	GameManager.new_game(0)

func _on_continue_v2() -> void:
	AudioManager.sfx_ui_click()
	if not GameManager.continue_v2_game():
		continue_v2_button.disabled = true
		return
	GameManager.go_to_base()

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
