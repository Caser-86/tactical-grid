## 基地控制器
extends Control
class_name BaseController

@onready var chapter_label = $TopBar/ChapterLabel
@onready var credit_label = $TopBar/CreditLabel
@onready var mission_list = $Center/MissionList

func _ready() -> void:
	_load_campaign()

func _load_campaign() -> void:
	var api = ApiClient.new()
	add_child(api)

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

func _display_missions(chapters: Array) -> void:
	for child in mission_list.get_children():
		child.queue_free()

	for chapter in chapters:
		var chapter_label = Label.new()
		chapter_label.text = "第%d章 %s" % [chapter.chapter, chapter.name]
		chapter_label.add_theme_font_size_override("font_size", 24)
		mission_list.add_child(chapter_label)

		for mission in chapter.missions:
			var button = Button.new()
			button.text = "%s%s" % [
				"🔒 " if mission.locked else "",
				mission.name
			]
			button.disabled = mission.locked
			button.custom_minimum_size = Vector2(300, 40)
			button.pressed.connect(_on_mission_selected.bind(mission.level_id))
			mission_list.add_child(button)

func _on_mission_selected(level_id: String) -> void:
	GameManager.load_level(level_id)
	# 切换到战斗场景
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
