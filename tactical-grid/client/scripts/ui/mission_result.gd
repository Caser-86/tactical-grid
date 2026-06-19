extends Control
class_name MissionResult

@onready var title_label = $Panel/VBox/TitleLabel
@onready var stars_container = $Panel/VBox/StarsContainer
@onready var turns_label = $Panel/VBox/StatsLabel/TurnsValue
@onready var survived_label = $Panel/VBox/StatsLabel/SurvivedValue
@onready var time_label = $Panel/VBox/StatsLabel/TimeValue
@onready var credit_label = $Panel/VBox/RewardsLabel/CreditValue
@onready var exp_label = $Panel/VBox/RewardsLabel/ExpValue
@onready var intel_label = $Panel/VBox/RewardsLabel/IntelValue
@onready var loot_container = $Panel/VBox/LootContainer
@onready var retry_button = $Panel/VBox/Buttons/RetryButton
@onready var base_button = $Panel/VBox/Buttons/BaseButton
@onready var next_button = $Panel/VBox/Buttons/NextButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry)
	base_button.pressed.connect(_on_base)
	next_button.pressed.connect(_on_next)

func show_result(data: Dictionary) -> void:
	var is_victory = data.get("result", "defeat") == "victory"
	if is_victory:
		title_label.text = "任务完成"
		title_label.modulate = Color.GREEN
		AudioManager.bgm_victory()
	else:
		title_label.text = "任务失败"
		title_label.modulate = Color.RED
		AudioManager.bgm_defeat()

	_show_stars(data.get("stars", 0))
	turns_label.text = str(data.get("turns", 0))
	var survived = data.get("units_survived", 0)
	var total = data.get("units_total", 4)
	survived_label.text = "%d/%d" % [survived, total]
	time_label.text = _format_time(data.get("playtime_seconds", 0))

	var rewards = data.get("rewards", {})
	credit_label.text = str(rewards.get("credit", 0))
	exp_label.text = str(rewards.get("exp", 0))
	intel_label.text = str(rewards.get("intel", 0))

	for child in loot_container.get_children():
		child.queue_free()

	if data.get("first_clear", false):
		var fc_label = Label.new()
		fc_label.text = "首次通关奖励"
		fc_label.modulate = Color.GOLD
		loot_container.add_child(fc_label)

	for item in data.get("loot", []):
		var loot_label = Label.new()
		loot_label.text = "获得: " + item.get("name", "未知物品")
		loot_container.add_child(loot_label)

	next_button.visible = is_victory
	retry_button.visible = true

func _show_stars(stars: int) -> void:
	for child in stars_container.get_children():
		child.queue_free()

	for i in range(3):
		var star = Label.new()
		star.text = "★" if i < stars else "☆"
		star.add_theme_font_size_override("font_size", 40)
		star.modulate = Color.GOLD if i < stars else Color.GRAY
		stars_container.add_child(star)

func _format_time(seconds: int) -> String:
	var m = seconds / 60
	var s = seconds % 60
	return "%d:%02d" % [m, s]

func _on_retry() -> void:
	get_tree().reload_current_scene()

func _on_base() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _on_next() -> void:
	var current_id = GameManager.current_level_id
	var regex = RegEx.new()
	regex.compile("ch(\\d+)_m(\\d+)")
	var regex_result = regex.search(current_id)
	if regex_result:
		var chapter = int(regex_result.get_string(1))
		var mission = int(regex_result.get_string(2))
		var next_mission = mission + 1
		var next_id = "ch%d_m%d" % [chapter, next_mission]
		if next_mission > 7:
			next_id = "ch%d_m1" % (chapter + 1)
		GameManager.load_level(next_id)
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/base.tscn")

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
