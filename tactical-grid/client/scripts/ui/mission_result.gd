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
	modulate = Color(1, 1, 1, 0)
	visible = true
	var is_victory = data.get("result", "defeat") == "victory"
	if is_victory:
		title_label.text = "任务完成"
		title_label.modulate = Color.GREEN
		AudioManager.bgm_victory()
	else:
		title_label.text = "任务失败"
		title_label.modulate = Color.RED
		AudioManager.bgm_defeat()

	# 入场动画
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	tween.parallel().tween_property($Panel, "scale", Vector2.ONE, 0.5).from(Vector2(0.85, 0.85))

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
	GameManager.player_units.clear()
	GameManager.enemy_units.clear()
	GameManager.selected_unit = null
	if GameManager.in_roguelike:
		RoguelikeManager.complete_floor({"credit": 100})
		RoguelikeManager.advance_floor()
		GameManager.in_roguelike = false
		TransitionManager.change_scene("res://scenes/roguelike_map.tscn")
	else:
		TransitionManager.change_scene("res://scenes/base.tscn")

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
		var levels = GameData.level_data.get("levels", {})
		if not levels.has(next_id):
			next_id = "ch%d_m1" % (chapter + 1)
			if not levels.has(next_id):
				TransitionManager.change_scene("res://scenes/base.tscn")
				return
		GameManager.load_level(next_id)
		TransitionManager.change_scene("res://scenes/battle.tscn")
	else:
		TransitionManager.change_scene("res://scenes/base.tscn")

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
