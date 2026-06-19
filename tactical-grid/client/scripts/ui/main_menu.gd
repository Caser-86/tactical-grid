extends Control

@onready var continue_button = $VBoxContainer/ContinueButton
@onready var new_game_button = $VBoxContainer/NewGameButton
@onready var quick_battle_button = $VBoxContainer/QuickBattleButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var background_art = $BackgroundArt

func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	quick_battle_button.pressed.connect(_on_quick_battle)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ArtAssets.get_menu_background()
	if bg:
		background_art.texture = bg

	AudioManager.bgm_menu()

	var has_save = _check_save()
	continue_button.disabled = not has_save

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _on_quick_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()

func _check_save() -> bool:
	var saves = SaveManager.get_local_saves()
	return saves.size() > 0
