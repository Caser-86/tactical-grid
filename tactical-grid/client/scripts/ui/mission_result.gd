## 关卡结算界面
extends Control
class_name MissionResult

@onready var title_label = $Panel/TitleLabel
@onready var stars_container = $Panel/StarsContainer
@onready var turns_label = $Panel/StatsLabel/TurnsValue
@onready var survived_label = $Panel/StatsLabel/SurvivedValue
@onready var time_label = $Panel/StatsLabel/TimeValue
@onready var credit_label = $Panel/RewardsLabel/CreditValue
@onready var exp_label = $Panel/RewardsLabel/ExpValue
@onready var intel_label = $Panel/RewardsLabel/IntelValue
@onready var loot_container = $Panel/LootContainer
@onready var retry_button = $Panel/Buttons/RetryButton
@onready var base_button = $Panel/Buttons/BaseButton
@onready var next_button = $Panel/Buttons/NextButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry)
	base_button.pressed.connect(_on_base)
	next_button.pressed.connect(_on_next)
	# 显示战斗结果（GameManager 在切换场景前已存入 battle_result）
	show_result(GameManager.battle_result)

## 显示结算结果
func show_result(data: Dictionary) -> void:
	var is_victory = data.get("result", "defeat") == "victory"

	if is_victory:
		title_label.text = "任务完成"
		title_label.modulate = Color.GREEN
	else:
		title_label.text = "任务失败"
		title_label.modulate = Color.RED

	# 显示星级
	_show_stars(data.get("stars", 0))

	# 显示统计
	turns_label.text = str(data.get("turns", 0))
	var survived = data.get("units_survived", 0)
	var total = data.get("units_total", 4)
	survived_label.text = "%d/%d" % [survived, total]
	time_label.text = _format_time(data.get("playtime_seconds", 0))

	# 显示奖励
	var rewards = data.get("rewards", {})
	credit_label.text = str(rewards.get("credit", 0))
	exp_label.text = str(rewards.get("exp", 0))
	intel_label.text = str(rewards.get("intel", 0))

	# 显示首通奖励
	if data.get("first_clear", false):
		var fc_label = Label.new()
		fc_label.text = "首次通关奖励！"
		fc_label.modulate = Color.GOLD
		loot_container.add_child(fc_label)

	# 显示掉落物品
	var loot = data.get("loot", [])
	for item in loot:
		var loot_label = Label.new()
		loot_label.text = "获得: " + item.get("name", "未知物品")
		loot_container.add_child(loot_label)

	# 按钮可用性
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
	GameManager.go_to_battle(GameManager.current_level_id)

func _on_base() -> void:
	GameManager.go_to_base()

func _on_next() -> void:
	var next_id = CampaignRepository.get_next_level(GameManager.current_level_id)
	if next_id != "":
		GameManager.go_to_battle(next_id)
	else:
		GameManager.go_to_base()
