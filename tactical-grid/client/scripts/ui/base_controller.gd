extends Control
class_name BaseController

@onready var chapter_label = $TopBar/ChapterLabel
@onready var credit_label = $TopBar/CreditLabel
@onready var mission_list = $Center/ScrollContainer/MissionList
@onready var shop_panel = $ShopPanel
@onready var character_panel = $CharacterPanel
@onready var background_art = $BackgroundArt

func _ready() -> void:
	$BottomBar/HBox/BarracksBtn.pressed.connect(_on_barracks)
	$BottomBar/HBox/ArmoryBtn.pressed.connect(_on_armory)
	$BottomBar/HBox/ShopBtn.pressed.connect(_on_shop)
	$BottomBar/HBox/BackBtn.pressed.connect(_on_back)

	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ArtAssets.get_menu_background()
	if bg:
		background_art.texture = bg

	AudioManager.bgm_base()
	_load_campaign()

func _load_campaign() -> void:
	if GameManager.local_mode:
		_display_local_campaign()
		_update_credit_label()
		return

	var api = ApiClient.new()
	add_child(api)

	var loaded_remote_campaign := false
	if GameManager.auth_token == "":
		var login_result = await api.guest_login()
		if login_result.code == 0:
			GameManager.auth_token = login_result.data.token
			api.set_token(login_result.data.token)
	else:
		api.set_token(GameManager.auth_token)

	var result = await api.get_campaign()
	if result.code == 0:
		_display_missions(result.data.chapters)
		loaded_remote_campaign = true

	if not loaded_remote_campaign:
		_display_local_campaign()

	_update_credit_label()
	api.queue_free()

func _display_local_campaign() -> void:
	var missions: Array = []
	for level in LocalMapData.get_all_levels():
		missions.append({
			"name": level.get("name", level.get("id", "level")),
			"level_id": level.get("id", ""),
			"locked": false,
		})

	_display_missions([
		{
			"chapter": 0,
			"name": "本地测试",
			"missions": missions,
		}
	])
	chapter_label.text = "本地测试"

func _update_credit_label() -> void:
	var credits = GameManager.save_data.get("resources", {}).get("credit", 0)
	credit_label.text = str(credits)

func _display_missions(chapters: Array) -> void:
	for child in mission_list.get_children():
		child.queue_free()

	for chapter in chapters:
		var chapter_title = Label.new()
		chapter_title.text = "第%d章：%s" % [chapter.chapter, chapter.name]
		chapter_title.add_theme_font_size_override("font_size", 24)
		mission_list.add_child(chapter_title)

		for mission in chapter.missions:
			var button = Button.new()
			button.text = "%s%s" % [
				"锁定 " if mission.locked else "",
				mission.name
			]
			button.disabled = mission.locked
			button.custom_minimum_size = Vector2(300, 40)
			button.pressed.connect(_on_mission_selected.bind(mission.level_id))
			mission_list.add_child(button)

func _on_mission_selected(level_id: String) -> void:
	GameManager.load_level(level_id)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_barracks() -> void:
	if GameManager.player_units.size() > 0:
		character_panel.show_unit(GameManager.player_units[0])
	else:
		var unit = GameData.create_player_unit("assault", "默认突击兵")
		character_panel.show_unit(unit)

func _on_armory() -> void:
	shop_panel.open_shop("weapons")

func _on_shop() -> void:
	var credits = GameManager.save_data.get("resources", {}).get("credit", 0)
	shop_panel.set_credit(credits)
	shop_panel.open_shop("items")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
