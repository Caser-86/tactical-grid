extends Control
class_name CharacterPanel

@onready var portrait = $Panel/LeftContainer/Portrait
@onready var name_label = $Panel/LeftContainer/NameLabel
@onready var job_label = $Panel/LeftContainer/JobLabel
@onready var level_label = $Panel/LeftContainer/LevelLabel

@onready var hp_bar = $Panel/LeftContainer/StatsContainer/HPBar
@onready var hp_label = $Panel/LeftContainer/StatsContainer/HPLabel
@onready var ap_label = $Panel/LeftContainer/StatsContainer/APLabel
@onready var move_label = $Panel/LeftContainer/StatsContainer/MoveLabel
@onready var vision_label = $Panel/LeftContainer/StatsContainer/VisionLabel

@onready var stat_container = $Panel/CenterContainer/StatContainer
@onready var equipment_container = $Panel/RightContainer/EquipmentContainer
@onready var skill_tree_container = $Panel/BottomContainer/SkillTreeContainer

@onready var tab_buttons = $Panel/TabContainer
@onready var back_button = $Panel/BackButton

var current_unit: Node = null
var current_tab: int = 0

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	for i in range(tab_buttons.get_child_count()):
		var btn = tab_buttons.get_child(i)
		btn.pressed.connect(_on_tab_changed.bind(i))

func show_unit(unit: Node) -> void:
	current_unit = unit
	_update_display()
	show()

func _update_display() -> void:
	if not current_unit:
		return

	name_label.text = current_unit.unit_name
	job_label.text = GameData.get_job(current_unit.job).get("name", current_unit.job)
	level_label.text = "Lv." + str(current_unit.stats.get("level", 1))
	hp_bar.value = float(current_unit.current_hp) / float(current_unit.max_hp) * 100.0
	hp_label.text = "%d/%d" % [current_unit.current_hp, current_unit.max_hp]
	ap_label.text = "AP: %d/%d" % [current_unit.current_ap, current_unit.max_ap]
	move_label.text = "移动: %d" % current_unit.move_points
	vision_label.text = "视野: %d" % current_unit.vision_range

	var team = current_unit.team if current_unit.team != "" else "player"
	var portrait_tex = ArtAssets.get_portrait_for_unit(current_unit.job, team)
	portrait.texture = portrait_tex
	portrait.visible = portrait_tex != null

	_update_stats()
	_update_equipment()
	_update_skill_tree()

func _update_stats() -> void:
	for child in stat_container.get_children():
		child.queue_free()

	var stat_names = {
		"str": "力量",
		"agi": "敏捷",
		"int": "智力",
		"vit": "体质",
		"per": "感知",
		"wil": "意志"
	}

	for stat_id in ["str", "agi", "int", "vit", "per", "wil"]:
		var value = current_unit.stats.get(stat_id, 5)
		var row = HBoxContainer.new()

		var name_lbl = Label.new()
		name_lbl.text = stat_names[stat_id]
		name_lbl.custom_minimum_size = Vector2(60, 20)
		row.add_child(name_lbl)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 10
		bar.value = value
		bar.custom_minimum_size = Vector2(150, 20)
		row.add_child(bar)

		var val_lbl = Label.new()
		val_lbl.text = str(value)
		val_lbl.custom_minimum_size = Vector2(30, 20)
		row.add_child(val_lbl)

		if current_unit.stats.get("stat_points_unspent", 0) > 0:
			var plus_btn = Button.new()
			plus_btn.text = "+"
			plus_btn.custom_minimum_size = Vector2(30, 20)
			plus_btn.pressed.connect(_on_stat_up.bind(stat_id))
			row.add_child(plus_btn)

		stat_container.add_child(row)

func _update_equipment() -> void:
	for child in equipment_container.get_children():
		child.queue_free()

	var slots = {
		"primary": "主武器",
		"secondary": "副武器",
		"armor": "护甲",
		"head": "头部",
		"accessory1": "配件1",
		"accessory2": "配件2",
		"backpack": "背包"
	}

	for slot_id in slots:
		var row = HBoxContainer.new()
		var slot_label = Label.new()
		slot_label.text = slots[slot_id] + ":"
		slot_label.custom_minimum_size = Vector2(60, 24)
		row.add_child(slot_label)

		var equip = current_unit.equipment.get(slot_id, "")
		var equip_icon = TextureRect.new()
		equip_icon.custom_minimum_size = Vector2(24, 24)
		equip_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		row.add_child(equip_icon)

		var equip_label = Label.new()
		if equip != "":
			var weapon_data = GameData.get_weapon(equip)
			equip_label.text = weapon_data.get("name", equip)
			equip_label.modulate = GameTheme.get_rarity_color(weapon_data.get("rarity", "common"))
			equip_icon.texture = ArtAssets.get_weapon_icon(equip)
		else:
			equip_label.text = "（空）"
			equip_label.modulate = Color.GRAY
		equip_label.custom_minimum_size = Vector2(150, 24)
		row.add_child(equip_label)
		equipment_container.add_child(row)

func _update_skill_tree() -> void:
	for child in skill_tree_container.get_children():
		child.queue_free()

	var job_data = GameData.get_job(current_unit.job)
	var trees = job_data.get("skill_trees", [])
	var job_skills = GameData.get_job_skills(current_unit.job)

	for tree_name in trees:
		var tree_header = Label.new()
		tree_header.text = "▶ " + tree_name
		tree_header.add_theme_font_size_override("font_size", 16)
		tree_header.modulate = GameTheme.ACCENT
		skill_tree_container.add_child(tree_header)

		for skill_info in job_skills:
			var skill = skill_info.data
			if skill.get("tree", "") != tree_name and tree_name != "":
				continue

			var skill_row = HBoxContainer.new()
			skill_row.custom_minimum_size = Vector2(0, 28)

			var skill_label = Label.new()
			var unlock_lv = skill.get("unlock_level", 0)
			var is_unlocked = current_unit.stats.get("level", 1) >= unlock_lv
			var type_tag = "[被动]" if skill.get("type") == "passive" else "[主动]"
			skill_label.text = "  %s %s (Lv.%d)" % [type_tag, skill.get("name", skill_info.id), unlock_lv]
			skill_label.custom_minimum_size = Vector2(250, 28)
			skill_label.modulate = Color.WHITE if is_unlocked else Color(0.5, 0.5, 0.5)
			skill_row.add_child(skill_label)

			var desc_label = Label.new()
			desc_label.text = skill.get("description", "")
			desc_label.modulate = GameTheme.TEXT_SECONDARY
			skill_row.add_child(desc_label)

			skill_tree_container.add_child(skill_row)

func _on_stat_up(stat_id: String) -> void:
	if current_unit.stats.get("stat_points_unspent", 0) <= 0:
		return
	current_unit.stats[stat_id] += 1
	current_unit.stats["stat_points_unspent"] -= 1
	_recalc_derived_stats()
	_update_display()

func _recalc_derived_stats() -> void:
	var s = current_unit.stats
	current_unit.max_hp = s.get("vit", 5) * 10 + 50
	current_unit.base_hit = 50 + s.get("per", 5) * 3
	current_unit.crit_chance = 0.05 + s.get("per", 5) * 0.005
	current_unit.dodge = s.get("agi", 5) * 0.015

func _on_tab_changed(tab: int) -> void:
	current_tab = tab
	stat_container.visible = (tab == 0)
	equipment_container.visible = (tab == 1)
	skill_tree_container.visible = (tab == 2)

func _on_back() -> void:
	hide()
