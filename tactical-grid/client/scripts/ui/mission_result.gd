## 关卡结算界面
## CH1-080: 失败页明确说明最近失败原因，并提供"从遭遇重试/重新开始/返回基地"
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
@onready var encounter_retry_button = $Panel/Buttons/EncounterRetryButton

func _ready() -> void:
	_apply_visual_theme()
	retry_button.pressed.connect(_on_retry)
	base_button.pressed.connect(_on_base)
	next_button.pressed.connect(_on_next)
	encounter_retry_button.pressed.connect(_on_encounter_retry)
	# 显示战斗结果（GameManager 在切换场景前已存入 battle_result）
	show_result(GameManager.battle_result)

## 显示结算结果
func show_result(data: Dictionary) -> void:
	var is_victory = data.get("result", "defeat") == "victory"
	var is_v2 := String(GameManager.current_save.get("game_line", "")) == "v2_infiltration"

	if is_victory:
		title_label.text = "任务完成"
		title_label.modulate = Color.GREEN
	else:
		title_label.text = "任务失败"
		title_label.modulate = Color.RED
		# CH1-080: 失败页明确说明最近失败原因
		var reason_text := _get_defeat_reason_text(String(data.get("defeat_reason", "")))
		var reason_label := Label.new()
		reason_label.text = reason_text
		reason_label.add_theme_font_size_override("font_size", 18)
		reason_label.modulate = Color("f4b45a")
		reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_container.add_child(reason_label)

	# V2 uses clear mission feedback instead of the V1 star/rating panel.
	if is_v2:
		_show_v2_summary(data)
	else:
		# 显示任务徽章（替代星级，保留整数 rating 字段用于存档）
		_show_badges(data)

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
	# CH1-080: 失败时提供"从遭遇重试/重新开始/返回基地"三选项
	next_button.visible = is_victory
	retry_button.visible = true
	retry_button.modulate = Color("f4b45a") if not is_victory else Color.WHITE
	# "从遭遇重试"仅在失败且有遭遇检查点时显示（不在 zone_a 失败）
	var has_checkpoint: bool = bool(data.get("has_encounter_checkpoint", false))
	if is_v2:
		has_checkpoint = not GameManager.get_v2_encounter_checkpoint().is_empty()
	encounter_retry_button.visible = not is_victory and has_checkpoint
	if is_v2:
		encounter_retry_button.text = "从检查点重试"
		retry_button.text = "重新开始任务"
		base_button.text = "返回基地"

func _show_v2_summary(data: Dictionary) -> void:
	stars_container.visible = false
	var header := Label.new()
	header.text = "行动回顾"
	header.modulate = Color("6dd6e5")
	header.add_theme_font_size_override("font_size", 19)
	loot_container.add_child(header)
	var primary := Label.new()
	primary.text = "主目标：%s" % ("已完成" if data.get("result", "defeat") == "victory" else "未完成")
	primary.modulate = Color("7ee68a") if data.get("result", "defeat") == "victory" else Color("f4b45a")
	loot_container.add_child(primary)
	var optional := Label.new()
	optional.text = "可选记录：%s" % ("已上传" if bool(data.get("optional_record", false)) else "未上传")
	optional.modulate = Color("7ee68a") if bool(data.get("optional_record", false)) else Color("9aa9ad")
	loot_container.add_child(optional)
	var rescued: Array = data.get("rescued", [])
	if "scout" in rescued:
		var rescued_label := Label.new()
		rescued_label.text = "新队员：侦察兵已加入基地"
		rescued_label.modulate = Color("6dd6e5")
		loot_container.add_child(rescued_label)
	for module_id in data.get("unlocked_modules", []):
		var module_label := Label.new()
		module_label.text = "新模块：%s" % String(module_id)
		module_label.modulate = Color("f4b45a")
		loot_container.add_child(module_label)

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

	for button in [retry_button, base_button, next_button, encounter_retry_button]:
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

## 显示任务徽章：任务完成 / 小队完整 / 情报收集
## CH1-080: 每个徽章说明取得或失去原因
## 替代原星级系统，保留 battle_result["stars"] 整数用于存档 rating 字段
func _show_badges(data: Dictionary) -> void:
	for child in stars_container.get_children():
		child.queue_free()
	var is_victory: bool = data.get("result", "defeat") == "victory"
	var stars: int = int(data.get("stars", 0))
	var survived: int = int(data.get("units_survived", 0))
	var total: int = int(data.get("units_total", 0))
	var turns: int = int(data.get("turns", 0))
	var optional_collected: bool = bool(data.get("optional_resource_collected", false))
	# Badge 1: Mission — awarded on any victory
	var mission_earned: bool = is_victory
	var mission_reason := "完成任务目标" if mission_earned else "未完成任务目标"
	# Badge 2: Squad — awarded when all units survive (stars >= 2)
	var squad_earned: bool = stars >= 2
	var squad_reason := "全员存活 (%d/%d)" % [survived, total] if squad_earned else "有单位阵亡 (%d/%d)" % [survived, total]
	# Badge 3: Intel — awarded on full clear (stars == 3: fast + optional)
	var intel_earned: bool = stars >= 3
	var intel_reason: String
	if intel_earned:
		intel_reason = "速通并收集可选资源"
	else:
		var parts: Array[String] = []
		if not optional_collected:
			parts.append("未收集可选资源")
		if turns > int(level_config_three_star_turns()):
			parts.append("回合数 %d 超过三星上限" % turns)
		intel_reason = "、".join(parts) if not parts.is_empty() else "未达成速通条件"
	_add_badge("任务", mission_earned, Color("6dd6e5"), mission_reason)
	_add_badge("小队", squad_earned, Color("7ee68a"), squad_reason)
	_add_badge("情报", intel_earned, Color.GOLD, intel_reason)

## 从 GameManager.battle_result 获取三星回合上限
func level_config_three_star_turns() -> int:
	var level_id: String = String(GameManager.battle_result.get("level_id", ""))
	var level: Dictionary = CampaignRepository.get_level(level_id)
	return int(level.get("three_star_turns", 10))

## CH1-080: 徽章带原因说明，鼠标悬停显示 tooltip
func _add_badge(label_text: String, earned: bool, color: Color, reason: String = "") -> void:
	var badge = Label.new()
	badge.text = label_text
	badge.add_theme_font_size_override("font_size", 22)
	if earned:
		badge.modulate = color
		badge.tooltip_text = "取得原因：" + reason
	else:
		badge.modulate = Color(0.3, 0.3, 0.3, 0.5)
		badge.tooltip_text = "未取得原因：" + reason
	stars_container.add_child(badge)

func _format_time(seconds: int) -> String:
	var m = seconds / 60
	var s = seconds % 60
	return "%d:%02d" % [m, s]

func _on_retry() -> void:
	if String(GameManager.current_save.get("game_line", "")) == "v2_infiltration":
		GameManager.restart_v2_mission(GameManager.current_level_id)
		return
	GameManager.go_to_battle(GameManager.current_level_id)

## CH1-080: 从遭遇检查点重试（当前为重开关卡，完整状态恢复见 CH1-020）
func _on_encounter_retry() -> void:
	GameManager.go_to_battle_from_encounter(GameManager.current_level_id)

func _on_base() -> void:
	GameManager.go_to_base()

func _on_next() -> void:
	var next_id = CampaignRepository.get_next_level(GameManager.current_level_id)
	if next_id != "":
		GameManager.go_to_battle(next_id)
	else:
		GameManager.go_to_base()

## Stable contract consumed by V2 retry tests and future result-screen variants.
func get_failure_actions(has_checkpoint: bool) -> Array[StringName]:
	var actions: Array[StringName] = []
	if has_checkpoint:
		actions.append(&"retry_checkpoint")
	actions.append(&"restart_mission")
	actions.append(&"return_base")
	return actions

## CH1-080: 失败原因文案
func _get_defeat_reason_text(reason: String) -> String:
	match reason:
		"all_units_down":
			return "失败原因：全队阵亡。注意利用掩体和网络节点减少伤害。"
		"turn_limit":
			return "失败原因：回合上限耗尽。尝试更积极的推进路线或利用设施改变战局。"
		"":
			return "失败原因：未满足任务目标。"
		_:
			return "失败原因：%s" % reason
