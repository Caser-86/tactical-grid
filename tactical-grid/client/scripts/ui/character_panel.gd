## 角色详情面板
## 显示角色属性、装备、技能树；支持属性加点、装备穿戴/卸下、技能学习
extends Control
class_name CharacterPanel

@onready var portrait = $Panel/MainContainer/LeftContainer/Portrait
@onready var name_label = $Panel/MainContainer/LeftContainer/NameLabel
@onready var job_label = $Panel/MainContainer/LeftContainer/JobLabel
@onready var level_label = $Panel/MainContainer/LeftContainer/LevelLabel

@onready var hp_bar = $Panel/MainContainer/LeftContainer/StatsContainer/HPBar
@onready var hp_label = $Panel/MainContainer/LeftContainer/StatsContainer/HPLabel
@onready var ap_label = $Panel/MainContainer/LeftContainer/StatsContainer/APLabel
@onready var move_label = $Panel/MainContainer/LeftContainer/StatsContainer/MoveLabel
@onready var vision_label = $Panel/MainContainer/LeftContainer/StatsContainer/VisionLabel

@onready var stat_section = $Panel/MainContainer/CenterContainer/StatSection
@onready var equip_section = $Panel/MainContainer/CenterContainer/EquipSection
@onready var skill_section = $Panel/MainContainer/CenterContainer/SkillSection

@onready var stat_container = $Panel/MainContainer/CenterContainer/StatSection/StatScroll/StatContainer
@onready var equipment_container = $Panel/MainContainer/CenterContainer/EquipSection/EquipScroll/EquipmentContainer
@onready var inventory_container = $Panel/MainContainer/CenterContainer/EquipSection/InventoryScroll/InventoryContainer
@onready var skill_tree_container = $Panel/MainContainer/CenterContainer/SkillSection/SkillScroll/SkillTreeContainer

@onready var tab_buttons = $Panel/TabContainer
@onready var back_button = $Panel/BackButton
@onready var prev_char_btn = $Panel/TopBar/PrevCharBtn
@onready var next_char_btn = $Panel/TopBar/NextCharBtn
@onready var title_label = $Panel/TopBar/TitleLabel

var current_character: Dictionary = {}
var current_char_index: int = -1
var current_tab: int = 0  # 0=属性, 1=装备, 2=技能

const STAT_NAMES = {
	"str": "力量", "agi": "敏捷", "int": "智力",
	"vit": "体质", "per": "感知", "wil": "意志"
}

const STAT_COLORS = {
	"str": Color(0.96, 0.42, 0.42),
	"agi": Color(0.42, 0.85, 0.42),
	"int": Color(0.42, 0.62, 0.96),
	"vit": Color(0.96, 0.69, 0.42),
	"per": Color(0.42, 0.85, 0.85),
	"wil": Color(0.69, 0.42, 0.96),
}

const SLOT_NAMES = {
	"primary": "主武器",
	"secondary": "副武器",
	"armor": "护甲",
	"head": "头部",
	"accessory1": "配件1",
	"accessory2": "配件2",
}

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	prev_char_btn.pressed.connect(_on_prev_char)
	next_char_btn.pressed.connect(_on_next_char)
	# 连接 Tab 按钮
	for i in range(tab_buttons.get_child_count()):
		var btn = tab_buttons.get_child(i)
		btn.pressed.connect(_on_tab_changed.bind(i))
	# 监听库存变化（装备/购买后刷新）
	GameManager.inventory_changed.connect(_on_inventory_changed)

## 打开面板并显示指定角色
func open_panel(char_index: int = 0) -> void:
	var roster = GameManager.get_roster()
	if roster.is_empty():
		_show_empty()
		show()
		return
	char_index = clampi(char_index, 0, roster.size() - 1)
	show_character(char_index)
	show()

## 显示空状态
func _show_empty() -> void:
	current_character = {}
	current_char_index = -1
	title_label.text = "暂无角色"
	name_label.text = "-"
	job_label.text = "-"
	level_label.text = "-"
	for child in stat_container.get_children():
		child.queue_free()
	for child in equipment_container.get_children():
		child.queue_free()
	for child in skill_tree_container.get_children():
		child.queue_free()

## 显示指定角色
func show_character(char_index: int) -> void:
	var roster = GameManager.get_roster()
	if char_index < 0 or char_index >= roster.size():
		return
	current_char_index = char_index
	current_character = roster[char_index]
	_update_display()

## 更新整个面板
func _update_display() -> void:
	if current_character.is_empty():
		return

	# 基本信息
	name_label.text = current_character.get("name", "Soldier")
	job_label.text = GameData.get_job(current_character.get("job", "assault")).get("name", "")
	var xp = current_character.get("xp", 0)
	var xp_next = current_character.get("xp_to_next", 100)
	var lvl = current_character.get("level", 1)
	level_label.text = "Lv.%d  (%d/%d XP)" % [lvl, xp, xp_next]
	title_label.text = "%s - %s" % [name_label.text, job_label.text]

	# HP
	var max_hp = current_character.get("hp_max", 100)
	hp_bar.max_value = max_hp
	hp_bar.value = max_hp  # 基地中满血
	hp_label.text = "%d/%d" % [max_hp, max_hp]
	ap_label.text = "AP: %d" % current_character.get("ap_max", 2)
	move_label.text = "移动: %d" % current_character.get("move_points", 5)
	vision_label.text = "视野: %d" % current_character.get("vision_range", 5)

	# 角色导航按钮可用性
	var roster = GameManager.get_roster()
	prev_char_btn.disabled = current_char_index <= 0
	next_char_btn.disabled = current_char_index >= roster.size() - 1

	# 三个分区
	_update_stats()
	_update_equipment()
	_update_skill_tree()
	_apply_tab_visibility()

func _update_stats() -> void:
	for child in stat_container.get_children():
		child.queue_free()

	var unspent = current_character.get("stat_points_unspent", 0)

	# 显示可分配点数
	var points_label = Label.new()
	points_label.text = "可分配属性点: %d" % unspent
	points_label.modulate = Color.YELLOW if unspent > 0 else Color.GRAY
	points_label.add_theme_font_size_override("font_size", 16)
	stat_container.add_child(points_label)

	for stat_id in ["str", "agi", "int", "vit", "per", "wil"]:
		var value = current_character.get("stats", {}).get(stat_id, 5)
		var row = HBoxContainer.new()

		var name_lbl = Label.new()
		name_lbl.text = STAT_NAMES[stat_id]
		name_lbl.custom_minimum_size = Vector2(60, 24)
		name_lbl.modulate = STAT_COLORS[stat_id]
		row.add_child(name_lbl)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 20
		bar.value = value
		bar.custom_minimum_size = Vector2(160, 24)
		bar.show_percentage = false
		row.add_child(bar)

		var val_lbl = Label.new()
		val_lbl.text = str(value)
		val_lbl.custom_minimum_size = Vector2(40, 24)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val_lbl)

		# 加点按钮
		if unspent > 0:
			var plus_btn = Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(36, 24)
			plus_btn.pressed.connect(_on_stat_up.bind(stat_id))
			row.add_child(plus_btn)

		stat_container.add_child(row)

func _update_equipment() -> void:
	for child in equipment_container.get_children():
		child.queue_free()
	for child in inventory_container.get_children():
		child.queue_free()

	var equipment = current_character.get("equipment", {})
	var inventory = GameManager.get_inventory()

	# 装备槽列表
	for slot_id in ["primary", "secondary", "armor", "head", "accessory1", "accessory2"]:
		var row = HBoxContainer.new()

		var slot_label = Label.new()
		slot_label.text = SLOT_NAMES[slot_id] + ":"
		slot_label.custom_minimum_size = Vector2(70, 28)
		row.add_child(slot_label)

		var equip = equipment.get(slot_id, "")
		var equip_label = Label.new()
		if equip != "":
			var item_data = GameData.get_weapon(equip)
			if item_data.is_empty():
				item_data = GameData.get_item(equip)
			equip_label.text = item_data.get("name", equip)
			equip_label.modulate = GameTheme.get_rarity_color(item_data.get("rarity", "common"))
		else:
			equip_label.text = "（空）"
			equip_label.modulate = Color.GRAY
		equip_label.custom_minimum_size = Vector2(160, 28)
		row.add_child(equip_label)

		# 卸下按钮
		if equip != "":
			var unequip_btn = Button.new()
			unequip_btn.text = "卸下"
			unequip_btn.custom_minimum_size = Vector2(60, 24)
			unequip_btn.pressed.connect(_on_unequip.bind(slot_id))
			row.add_child(unequip_btn)

		equipment_container.add_child(row)

	# 显示库存中可装备的物品
	if inventory.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "（背包为空，前往商店购买装备）"
		empty_label.modulate = Color.GRAY
		inventory_container.add_child(empty_label)
		return

	# 按槽位类型筛选可装备物品
	for item_id in inventory:
		var count = inventory[item_id]
		var item_data = GameData.get_weapon(item_id)
		var is_weapon = not item_data.is_empty()
		if is_weapon:
			# 武器需检查职业限制
			var job_info = GameData.get_job(current_character.get("job", "assault"))
			var allowed = job_info.get("weapons_allowed", [])
			if not item_id in allowed:
				continue  # 该职业不能用此武器
		else:
			item_data = GameData.get_item(item_id)
			if item_data.is_empty():
				continue

		var row = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = item_data.get("name", item_id)
		name_label.custom_minimum_size = Vector2(160, 28)
		name_label.modulate = GameTheme.get_rarity_color(item_data.get("rarity", "common"))
		row.add_child(name_label)

		var count_label = Label.new()
		count_label.text = "x%d" % count
		count_label.custom_minimum_size = Vector2(40, 28)
		count_label.modulate = Color.GRAY
		row.add_child(count_label)

		# 根据物品类型显示可装备的槽位按钮
		var item_type = item_data.get("type", "")
		var slots_for_type: Array = []
		if is_weapon:
			if item_data.get("type", "primary") == "primary":
				slots_for_type = ["primary"]
			else:
				slots_for_type = ["secondary"]
		else:
			match item_type:
				"armor": slots_for_type = ["armor"]
				"helmet": slots_for_type = ["head"]
				"accessory": slots_for_type = ["accessory1", "accessory2"]
				_: slots_for_type = []

		for slot in slots_for_type:
			var equip_btn = Button.new()
			equip_btn.text = SLOT_NAMES[slot]
			equip_btn.custom_minimum_size = Vector2(60, 24)
			equip_btn.pressed.connect(_on_equip.bind(slot, item_id))
			row.add_child(equip_btn)

		# 如果没有可装备的槽位，至少显示一个标识
		if slots_for_type.is_empty():
			var note = Label.new()
			note.text = "（消耗品，请在战斗中使用）"
			note.modulate = Color.GRAY
			note.custom_minimum_size = Vector2(180, 28)
			row.add_child(note)

		inventory_container.add_child(row)

func _update_skill_tree() -> void:
	for child in skill_tree_container.get_children():
		child.queue_free()

	var skill_points = current_character.get("skill_points_unspent", 0)
	var points_label = Label.new()
	points_label.text = "可分配技能点: %d" % skill_points
	points_label.modulate = Color.YELLOW if skill_points > 0 else Color.GRAY
	points_label.add_theme_font_size_override("font_size", 16)
	skill_tree_container.add_child(points_label)

	var char_job = current_character.get("job", "assault")
	var char_level = current_character.get("level", 1)
	var unlocked_skills = current_character.get("skills_unlocked", [])

	# 已学技能区
	var learned_title = Label.new()
	learned_title.text = "已学技能 (%d):" % unlocked_skills.size()
	learned_title.modulate = Color(0.5, 1.0, 0.5)
	learned_title.add_theme_font_size_override("font_size", 14)
	skill_tree_container.add_child(learned_title)

	for skill_id in unlocked_skills:
		var skill = GameData.get_skill(skill_id)
		if skill.is_empty():
			continue
		var row = _build_skill_row(skill_id, skill, true, false)
		skill_tree_container.add_child(row)

	# 可学技能区
	var learnable_title = Label.new()
	learnable_title.text = "可学习技能:"
	learnable_title.modulate = Color(1.0, 0.85, 0.4)
	learnable_title.add_theme_font_size_override("font_size", 14)
	skill_tree_container.add_child(learnable_title)

	var job_skills = GameData.get_job_skills(char_job)
	var has_learnable = false
	for entry in job_skills:
		var skill_id = entry.id
		var skill = entry.data
		if skill_id in unlocked_skills:
			continue
		var unlock_level = int(skill.get("unlock_level", 1))
		var can_learn = char_level >= unlock_level and skill_points > 0
		var row = _build_skill_row(skill_id, skill, false, can_learn)
		skill_tree_container.add_child(row)
		has_learnable = true

	if not has_learnable:
		var empty = Label.new()
		empty.text = "  （暂无可学技能，提升等级解锁更多）"
		empty.modulate = Color.GRAY
		skill_tree_container.add_child(empty)

	# 未达等级的技能预告
	var locked_title = Label.new()
	locked_title.text = "未解锁（需提升等级）:"
	locked_title.modulate = Color.GRAY
	locked_title.add_theme_font_size_override("font_size", 14)
	skill_tree_container.add_child(locked_title)

	var has_locked = false
	for entry in job_skills:
		var skill_id = entry.id
		var skill = entry.data
		if skill_id in unlocked_skills:
			continue
		var unlock_level = int(skill.get("unlock_level", 1))
		if char_level >= unlock_level:
			continue  # 已在可学列表
		var row = _build_skill_row(skill_id, skill, false, false)
		skill_tree_container.add_child(row)
		has_locked = true

	if not has_locked:
		var empty = Label.new()
		empty.text = "  （所有技能已解锁）"
		empty.modulate = Color.GRAY
		skill_tree_container.add_child(empty)

## 构建技能行
func _build_skill_row(skill_id: String, skill: Dictionary, is_learned: bool, can_learn: bool) -> HBoxContainer:
	var row = HBoxContainer.new()

	var status_label = Label.new()
	if is_learned:
		status_label.text = "[已学]"
		status_label.modulate = Color(0.5, 1.0, 0.5)
	elif can_learn:
		status_label.text = "[可学]"
		status_label.modulate = Color(1.0, 0.85, 0.4)
	else:
		status_label.text = "[Lv.%d]" % int(skill.get("unlock_level", 1))
		status_label.modulate = Color.GRAY
	status_label.custom_minimum_size = Vector2(70, 24)
	row.add_child(status_label)

	var name_label = Label.new()
	name_label.text = skill.get("name", skill_id)
	name_label.custom_minimum_size = Vector2(120, 24)
	name_label.modulate = Color.WHITE if is_learned else (Color.WHITE if can_learn else Color.GRAY)
	row.add_child(name_label)

	var type_label = Label.new()
	var skill_type = skill.get("type", "active")
	var type_text = "主动" if skill_type == "active" else ("被动" if skill_type == "passive" else "反应")
	type_label.text = "[%s]" % type_text
	type_label.custom_minimum_size = Vector2(50, 24)
	type_label.modulate = Color(0.7, 0.85, 1.0)
	row.add_child(type_label)

	var cost_label = Label.new()
	cost_label.text = "AP:%d" % int(skill.get("ap_cost", 0))
	cost_label.custom_minimum_size = Vector2(50, 24)
	cost_label.modulate = Color(0.85, 0.7, 1.0)
	row.add_child(cost_label)

	var desc_label = Label.new()
	desc_label.text = skill.get("description", "")
	desc_label.custom_minimum_size = Vector2(280, 24)
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	row.add_child(desc_label)

	# 学习按钮
	if can_learn:
		var learn_btn = Button.new()
		learn_btn.text = "学习"
		learn_btn.custom_minimum_size = Vector2(60, 24)
		learn_btn.pressed.connect(_on_learn_skill.bind(skill_id))
		row.add_child(learn_btn)

	return row

## 应用当前 Tab 显示
func _apply_tab_visibility() -> void:
	stat_section.visible = (current_tab == 0)
	equip_section.visible = (current_tab == 1)
	skill_section.visible = (current_tab == 2)

## ===== 事件回调 =====

func _on_stat_up(stat_id: String) -> void:
	if current_char_index < 0:
		return
	if GameManager.allocate_stat(current_char_index, stat_id):
		current_character = GameManager.get_roster()[current_char_index]
		_update_display()

func _on_equip(slot: String, item_id: String) -> void:
	if current_char_index < 0:
		return
	if GameManager.equip_to_character(current_char_index, slot, item_id):
		current_character = GameManager.get_roster()[current_char_index]
		_update_display()

func _on_unequip(slot: String) -> void:
	if current_char_index < 0:
		return
	if GameManager.unequip_from_character(current_char_index, slot):
		current_character = GameManager.get_roster()[current_char_index]
		_update_display()

func _on_learn_skill(skill_id: String) -> void:
	if current_char_index < 0:
		return
	if GameManager.learn_skill(current_char_index, skill_id):
		current_character = GameManager.get_roster()[current_char_index]
		_update_display()

func _on_prev_char() -> void:
	if current_char_index > 0:
		show_character(current_char_index - 1)

func _on_next_char() -> void:
	var roster = GameManager.get_roster()
	if current_char_index < roster.size() - 1:
		show_character(current_char_index + 1)

func _on_tab_changed(tab: int) -> void:
	current_tab = tab
	_apply_tab_visibility()

func _on_inventory_changed() -> void:
	if is_visible_in_tree() and current_char_index >= 0:
		current_character = GameManager.get_roster()[current_char_index]
		_update_display()

func _on_back() -> void:
	hide()
	queue_free()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
