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

	_apply_localization()

	var has_save = SaveManager.load_latest_save().size() > 0
	continue_button.visible = has_save

	AudioManager.play_bgm("bgm_main_menu")

func _apply_localization() -> void:
	continue_button.text = LocalizationManager.get_text("continue", continue_button.text)
	new_game_button.text = LocalizationManager.get_text("new_game", new_game_button.text)
	quick_battle_button.text = LocalizationManager.get_text("quick_battle", quick_battle_button.text)
	settings_button.text = LocalizationManager.get_text("settings", settings_button.text)
	quit_button.text = LocalizationManager.get_text("quit", quit_button.text)
	var title = get_node_or_null("CenterContainer/VBoxContainer/TitleLabel")
	if title:
		title.text = LocalizationManager.get_text("game_title", title.text)

func _on_continue() -> void:
	var save = SaveManager.load_latest_save()
	if save.size() > 0:
		GameManager.save_data = save
	TransitionManager.change_scene("res://scenes/base.tscn")

func _on_new_game() -> void:
	GameManager.save_data = SaveManager.create_default_save()
	SaveManager.auto_save(GameManager.save_data)
	TransitionManager.change_scene("res://scenes/base.tscn")

func _on_quick_battle() -> void:
	TransitionManager.change_scene("res://scenes/battle.tscn")

func _on_settings() -> void:
	TransitionManager.change_scene("res://scenes/settings.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()

func _check_save() -> bool:
	var saves = SaveManager.get_local_saves()
	return saves.size() > 0
