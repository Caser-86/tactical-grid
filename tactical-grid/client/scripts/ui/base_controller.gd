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
	var rogue_btn = $BottomBar/HBox.get_node_or_null("RoguelikeBtn")
	if rogue_btn:
		rogue_btn.pressed.connect(_on_roguelike)
	$BottomBar/HBox/BackBtn.pressed.connect(_on_back)

	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ArtAssets.get_menu_background()
	if bg:
		background_art.texture = bg

	if GameManager.save_data.is_empty():
		GameManager.save_data = SaveManager.create_default_save()
		SaveManager.auto_save(GameManager.save_data)

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
		if login_result.get("code", -1) == 0:
			var token = login_result.get("data", {}).get("token", "")
			GameManager.auth_token = token
			api.set_token(token)
	else:
		api.set_token(GameManager.auth_token)

	var result = await api.get_campaign()
	if result.get("code", -1) == 0:
		_display_missions(result.get("data", {}).get("chapters", []))
		loaded_remote_campaign = true

	if not loaded_remote_campaign:
		_display_local_campaign()

	_update_credit_label()
	api.queue_free()

func _display_local_campaign() -> void:
	var chapters: Array = []

	# 主线关卡（按章节分组）
	var main_chapters: Dictionary = {}
	for level_id in GameData.level_data.get("levels", {}):
		var level = GameData.level_data.levels[level_id]
		var chapter_num = int(level.get("chapter", 1))
		if not main_chapters.has(chapter_num):
			main_chapters[chapter_num] = []
		main_chapters[chapter_num].append({
			"name": level.get("name", level_id),
			"level_id": level_id,
			"locked": not _is_level_unlocked(level_id),
			"is_boss": level.get("is_boss", false),
			"stars": _get_level_stars(level_id),
		})

	# 章节排序
	var chapter_keys = main_chapters.keys()
	chapter_keys.sort()
	for ch_num in chapter_keys:
		chapters.append({
			"chapter": ch_num,
			"name": _get_chapter_name(ch_num),
			"missions": main_chapters[ch_num],
		})

	# 支线任务
	var side_missions: Array = []
	for sq_id in GameData.level_data.get("sidequests", {}):
		var sq = GameData.level_data.sidequests[sq_id]
		side_missions.append({
			"name": sq.get("name", sq_id),
			"level_id": sq_id,
			"locked": false,
			"is_boss": false,
		})

	if side_missions.size() > 0:
		chapters.append({
			"chapter": 99,
			"name": "支线任务",
			"missions": side_missions,
		})

	# 经典测试关卡
	var test_missions: Array = []
	for level in LocalMapData.get_all_levels():
		test_missions.append({
			"name": level.get("name", level.get("id", "level")),
			"level_id": level.get("id", ""),
			"locked": false,
			"is_boss": false,
		})
	chapters.append({
		"chapter": 0,
		"name": "经典测试关卡",
		"missions": test_missions,
	})

	_display_missions(chapters)
	chapter_label.text = "本地测试"

func _is_level_unlocked(level_id: String) -> bool:
	if level_id == "ch1_m1":
		return true
	var campaign = GameManager.save_data.get("campaign_progress", {})
	var completed = campaign.get("completed_missions", [])
	var current = campaign.get("current_mission", "ch1_m1")
	if completed.has(level_id) or current == level_id:
		return true
	# 如果前一关已完成，则解锁
	var prev_id = _get_prev_level_id(level_id)
	return completed.has(prev_id)

func _get_prev_level_id(level_id: String) -> String:
	var regex = RegEx.new()
	regex.compile("ch(\\d+)_m(\\d+)")
	var result = regex.search(level_id)
	if not result:
		return ""
	var chapter = int(result.get_string(1))
	var mission = int(result.get_string(2))
	var prev_mission = mission - 1
	if prev_mission >= 1:
		return "ch%d_m%d" % [chapter, prev_mission]
	var prev_chapter = chapter - 1
	if prev_chapter >= 1:
		# 假设每章最多7关
		return "ch%d_m7" % prev_chapter
	return ""

func _get_level_stars(level_id: String) -> int:
	var campaign = GameManager.save_data.get("campaign_progress", {})
	var ratings = campaign.get("mission_ratings", {})
	return ratings.get(level_id, 0)

func _get_chapter_name(chapter_num: int) -> String:
	match chapter_num:
		1:
			return "入侵 - 序章"
		2:
			return "城市 - 雨夜"
		3:
			return "地下 - 影袭"
		4:
			return "堡垒 - 围城"
		5:
			return "决战 - 架构师"
		_:
			return "第%d章" % chapter_num

func _update_credit_label() -> void:
	var resources = GameManager.save_data.get("resources", {})
	var credits = resources.get("credit", 0)
	var intel = resources.get("intel", 0)
	var materials = resources.get("materials", {})
	var mat_count = 0
	for mat_id in materials:
		mat_count += materials[mat_id]
	credit_label.text = "CR: %d  |  情报: %d  |  材料: %d" % [credits, intel, mat_count]

func _display_missions(chapters: Array) -> void:
	for child in mission_list.get_children():
		child.queue_free()

	for chapter in chapters:
		var chapter_title = Label.new()
		chapter_title.text = "第%d章：%s" % [chapter.chapter, chapter.name]
		chapter_title.add_theme_font_size_override("font_size", 26)
		chapter_title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
		mission_list.add_child(chapter_title)

		for mission in chapter.missions:
			var button = Button.new()
			var boss_tag = "【BOSS】" if mission.get("is_boss", false) else ""
			var stars = mission.get("stars", 0)
			var star_str = ""
			if stars > 0 and not mission.locked:
				star_str = "  " + "★".repeat(stars) + "☆".repeat(3 - stars)
			var lock_str = "[锁定] " if mission.locked else ""
			button.text = "%s%s%s%s" % [lock_str, boss_tag, mission.name, star_str]
			button.disabled = mission.locked
			button.custom_minimum_size = Vector2(320, 44)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_style_mission_button(button, mission)
			button.pressed.connect(_on_mission_selected.bind(mission.level_id))
			mission_list.add_child(button)

func _style_mission_button(button: Button, mission: Dictionary) -> void:
	var normal = StyleBoxFlat.new()
	var hover = StyleBoxFlat.new()
	var disabled = StyleBoxFlat.new()

	var base_color := Color(0.18, 0.20, 0.24)
	var boss_color := Color(0.35, 0.18, 0.12)
	var locked_color := Color(0.12, 0.12, 0.13)

	var bg = base_color
	if mission.get("is_boss", false):
		bg = boss_color
	if mission.locked:
		bg = locked_color

	for style in [normal, hover, disabled]:
		style.bg_color = bg
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6

	hover.bg_color = bg.lightened(0.12)
	disabled.bg_color = bg.darkened(0.15)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))

	if mission.get("is_boss", false) and not mission.locked:
		button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))

func _on_mission_selected(level_id: String) -> void:
	GameManager.load_level(level_id)
	TransitionManager.change_scene("res://scenes/battle.tscn")

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

func _on_roguelike() -> void:
	TransitionManager.change_scene("res://scenes/roguelike_map.tscn")

func _on_back() -> void:
	TransitionManager.change_scene("res://scenes/main_menu.tscn")

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
