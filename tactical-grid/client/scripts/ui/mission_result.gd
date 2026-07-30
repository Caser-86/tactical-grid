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
	_apply_visual_theme()
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
	turns_label.text = "回合数  %s" % str(data.get("turns", 0))
	var survived = data.get("units_survived", 0)
	var total = data.get("units_total", 4)
	survived_label.text = "存活单位  %d/%d" % [survived, total]
	time_label.text = "任务时间  %s" % _format_time(data.get("playtime_seconds", 0))

	# 显示奖励
	var rewards = data.get("rewards", {})
	credit_label.text = "信用点  +%s" % str(rewards.get("credit", 0))
	exp_label.text = "经验值  +%s" % str(rewards.get("exp", 0))
	intel_label.text = "情报  +%s" % str(rewards.get("intel", 0))

	# 显示首通奖励
	if data.get("first_clear", false):
		var fc_label = Label.new()
		fc_label.text = "首次通关奖励！"
		fc_label.modulate = Color.GOLD
		loot_container.add_child(fc_label)

	# 显示掉落物品
	# Task 3: optional resource reward
	if int(data.get("optional_credit", 0)) > 0:
		var opt_label = Label.new()
		opt_label.text = "optional resource  +%d credit" % int(data.get("optional_credit", 0))
		opt_label.modulate = Color.GOLD
		loot_container.add_child(opt_label)

	var loot = data.get("loot", [])
	for item in loot:
		var loot_label = Label.new()
		loot_label.text = "获得: " + item.get("name", "未知物品")
		loot_container.add_child(loot_label)

	# 首通新机制与职业解锁必须在结算页明确反馈给玩家。
	var new_unlocks: Array = data.get("new_unlocks", [])
	if not new_unlocks.is_empty():
		var unlock_header := Label.new()
		unlock_header.text = "新解锁"
		unlock_header.modulate = Color("6dd6e5")
		loot_container.add_child(unlock_header)
		for unlock_id in new_unlocks:
			var unlock_label := Label.new()
			unlock_label.text = "解锁: " + str(unlock_id).replace("_", " ")
			loot_container.add_child(unlock_label)

	# 按钮可用性
	next_button.visible = is_victory
	retry_button.visible = true
	retry_button.modulate = Color("f4b45a") if not is_victory else Color.WHITE

func _apply_visual_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101b22")
	panel_style.border_color = Color("36aeca")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 16
	$Panel.add_theme_stylebox_override("panel", panel_style)

	for label in [turns_label, survived_label, time_label, credit_label, exp_label, intel_label]:
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color("d7ebef")

	for button in [retry_button, base_button, next_button]:
		_style_button(button)

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("172b34")
	normal.border_color = Color("3e8797")
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_right = 5
	normal.corner_radius_bottom_left = 5
	var hover := normal.duplicate()
	hover.bg_color = Color("1d4753")
	hover.border_color = Color("6dd6e5")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("0c151a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("e8f6f7"))
	button.add_theme_font_size_override("font_size", 17)

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
