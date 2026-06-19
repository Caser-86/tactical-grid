extends CanvasLayer
class_name HUD

signal action_selected(action: String)
signal skill_selected(skill_id: String)
signal item_selected(item_id: String)

@onready var top_bar: Panel = get_node_or_null("TopBar") as Panel
@onready var right_panel: Panel = get_node_or_null("RightPanel") as Panel
@onready var bottom_bar: Panel = get_node_or_null("BottomBar") as Panel
@onready var turn_label: Label = get_node_or_null("TopBar/TurnLabel") as Label
@onready var phase_label: Label = get_node_or_null("TopBar/PhaseLabel") as Label
@onready var objective_label: Label = get_node_or_null("TopBar/ObjectiveLabel") as Label
@onready var unit_info_panel: VBoxContainer = get_node_or_null("RightPanel/UnitInfo") as VBoxContainer
@onready var action_bar: HBoxContainer = get_node_or_null("BottomBar/ActionBar") as HBoxContainer
@onready var end_turn_button: Button = get_node_or_null("BottomBar/ActionBar/EndTurnButton") as Button

var action_menu: ActionMenu = null
var skill_menu: PopupMenu = null
var item_menu: PopupMenu = null
var current_unit: Node = null
var _skill_ids: Array[String] = []
var _item_ids: Array[String] = []

const SUPPORTED_SKILLS := {
	"asslt_dash_strike": true,
	"asslt_breach": true,
	"asslt_adrenaline": true,
	"asslt_blink": true,
	"asslt_storm_dash": true,
	"asslt_chain_slash": true,
	"snip_precise": true,
	"snip_silent_shot": true,
	"snip_double_tap": true,
	"snip_assassinate": true,
	"snip_piercing": true,
	"snip_highground": true,
	"snip_suppressing_fire": true,
	"snip_overwatch": true,
	"snip_death_mark": true,
	"heavy_suppress": true,
	"heavy_grenade": true,
	"heavy_taunt": true,
	"heavy_protect": true,
	"heavy_barrage": true,
	"heavy_iron_fortress": true,
	"heavy_self_repair": true,
	"heavy_cleave": true,
	"heavy_ground_slam": true,
	"medic_heal": true,
	"medic_revive": true,
	"medic_adrenaline_shot": true,
	"medic_area_heal": true,
	"medic_cure": true,
	"medic_barrier_blast": true,
	"medic_pain_block": true,
	"medic_mass_cure": true,
	"medic_stim_pack": true,
	"scout_stealth": true,
	"scout_scan": true,
	"scout_mark": true,
	"scout_trap": true,
	"scout_sabotage": true,
	"scout_recon_drone": true,
	"scout_decoy": true,
	"scout_shadow_step": true,
	"scout_silent_kill": true,
	"gen_overwatch": true,
	"gen_hunker_down": true,
	"gen_sprint": true,
	"gen_reposition": true,
	"gen_interact": true,
}

func _ready() -> void:
	if not top_bar or not right_panel or not bottom_bar or not turn_label or not phase_label or not objective_label or not unit_info_panel or not action_bar or not end_turn_button:
		push_warning("HUD layout nodes are incomplete; using safe fallback behavior.")
	_build_action_menu()
	_build_popup_menus()
	_apply_theme()
	if GameManager.turn_manager:
		if not GameManager.turn_manager.turn_phase_changed.is_connected(_on_phase_changed):
			GameManager.turn_manager.turn_phase_changed.connect(_on_phase_changed)
		if not GameManager.turn_manager.turn_ended.is_connected(_on_turn_ended):
			GameManager.turn_manager.turn_ended.connect(_on_turn_ended)
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)

func _apply_theme() -> void:
	if not top_bar or not right_panel or not bottom_bar:
		return
	var panel_style = _make_panel_style()
	top_bar.add_theme_stylebox_override("panel", panel_style)
	right_panel.add_theme_stylebox_override("panel", panel_style)
	bottom_bar.add_theme_stylebox_override("panel", panel_style)

	for label in [turn_label, phase_label, objective_label]:
		if label:
			_style_label(label, 18)
	if objective_label:
		objective_label.modulate = GameTheme.ACCENT

	if action_bar:
		for child in action_bar.get_children():
			if child is Button:
				_style_button(child)

	if action_menu:
		_style_action_menu(action_menu)
		if action_bar:
			action_bar.hide()

	_style_unit_info_panel()
	_style_popup_menu(skill_menu)
	_style_popup_menu(item_menu)

func _style_unit_info_panel() -> void:
	if not unit_info_panel:
		return
	var title = unit_info_panel.get_node_or_null("PanelTitle")
	if not title:
		title = Label.new()
		title.name = "PanelTitle"
		unit_info_panel.add_child(title)
	title.text = "单位状态"
	_style_label(title, 14)
	title.add_theme_color_override("font_color", GameTheme.ACCENT)

	var info = unit_info_panel.get_node_or_null("InfoLabel")
	if not info:
		info = Label.new()
		info.name = "InfoLabel"
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unit_info_panel.add_child(info)
	info.text = "未选中单位"
	_style_label(info, 16)

	for child in unit_info_panel.get_children():
		if child is Label and child.name != "PanelTitle" and child.name != "InfoLabel":
			_style_label(child, 16)

func _style_label(label: Label, size: int) -> void:
	if not label:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GameTheme.TEXT_PRIMARY)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GameTheme.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GameTheme.ACCENT)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.11, 0.12, 0.15, 0.95), Color(0.26, 0.36, 0.48, 1)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.18, 0.22, 0.98), GameTheme.ACCENT))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.09, 0.11, 0.14, 0.98), Color(0.14, 0.62, 0.96, 1)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.06, 0.07, 0.08, 0.75), Color(0.18, 0.18, 0.2, 1)))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true

	match button.name:
		"MoveButton":
			button.icon = _make_ui_icon("move")
		"AttackButton":
			button.icon = _make_ui_icon("attack")
		"SkillButton":
			button.icon = _make_ui_icon("skill")
		"ItemButton":
			button.icon = _make_ui_icon("item")
		"OverwatchButton":
			button.icon = _make_ui_icon("warning")
		"EndTurnButton":
			button.icon = _make_ui_icon("refresh")

func _style_action_menu(menu: ActionMenu) -> void:
	var panel = menu.get_node_or_null("Panel")
	if panel and panel is Panel:
		panel.add_theme_stylebox_override("panel", _make_panel_style())
		var title = panel.get_node_or_null("Title")
		if title and title is Label:
			_style_label(title, 14)
			title.add_theme_color_override("font_color", GameTheme.ACCENT)

	var vbox = menu.get_node_or_null("Panel/VBox")
	if vbox:
		for child in vbox.get_children():
			if child is Button:
				_style_button(child)

func _style_popup_menu(menu: PopupMenu) -> void:
	if not menu:
		return
	menu.add_theme_font_size_override("font_size", 15)
	menu.add_theme_color_override("font_color", GameTheme.TEXT_PRIMARY)
	menu.add_theme_color_override("font_hover_color", Color.WHITE)
	menu.add_theme_color_override("font_pressed_color", GameTheme.ACCENT)
	menu.add_theme_stylebox_override("panel", _make_panel_style())

func _build_action_menu() -> void:
	action_menu = ActionMenu.new()
	action_menu.name = "ActionMenu"
	action_menu.anchor_left = 0.5
	action_menu.anchor_right = 0.5
	action_menu.anchor_top = 1.0
	action_menu.anchor_bottom = 1.0
	action_menu.offset_left = -220.0
	action_menu.offset_top = -250.0
	action_menu.offset_right = 220.0
	action_menu.offset_bottom = -70.0
	action_menu.visible = false

	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	action_menu.add_child(panel)

	var title = Label.new()
	title.name = "Title"
	title.text = "行动指令"
	title.anchor_left = 0.0
	title.anchor_top = 0.0
	title.anchor_right = 1.0
	title.anchor_bottom = 0.0
	title.offset_left = 14.0
	title.offset_top = 12.0
	title.offset_right = -14.0
	title.offset_bottom = 34.0
	panel.add_child(title)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12.0
	vbox.offset_top = 42.0
	vbox.offset_right = -12.0
	vbox.offset_bottom = -12.0
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	for item in [
		{"name": "MoveButton", "text": "移动"},
		{"name": "AttackButton", "text": "攻击"},
		{"name": "SkillButton", "text": "技能列表"},
		{"name": "ItemButton", "text": "物品"},
		{"name": "OverwatchButton", "text": "警戒"},
		{"name": "EndTurnButton", "text": "结束回合"}
	]:
		var button = Button.new()
		button.name = item.name
		button.text = item.text
		button.custom_minimum_size = Vector2(180, 38)
		vbox.add_child(button)

	add_child(action_menu)
	action_menu.action_selected.connect(_on_action_menu_action)

func _build_popup_menus() -> void:
	skill_menu = PopupMenu.new()
	skill_menu.name = "SkillPopup"
	skill_menu.visible = false
	add_child(skill_menu)
	skill_menu.id_pressed.connect(_on_skill_popup_id_pressed)

	item_menu = PopupMenu.new()
	item_menu.name = "ItemPopup"
	item_menu.visible = false
	add_child(item_menu)
	item_menu.id_pressed.connect(_on_item_popup_id_pressed)

func _on_action_menu_action(action: String) -> void:
	hide_choice_menus()
	match action:
		"skill":
			_open_skill_popup()
		"item":
			_open_item_popup()
		_:
			action_selected.emit(action)

func _open_skill_popup() -> void:
	_skill_ids.clear()
	if not current_unit:
		return

	skill_menu.clear()
	var skills = GameData.get_job_skills(current_unit.job)
	for skill_info in skills:
		var skill = skill_info.data
		if skill.get("type", "active") == "passive":
			continue
		if not SUPPORTED_SKILLS.has(skill_info.id):
			continue
		var ap_cost = int(skill.get("ap_cost", 1))
		var unlock_level = int(skill.get("unlock_level", 0))
		var cooldown = int(skill.get("cooldown", 0))
		var desc = skill.get("description", "")
		var label = "%s  AP:%d  CD:%d  Lv:%d" % [
			skill.get("name", skill_info.id),
			ap_cost,
			cooldown,
			unlock_level
		]
		if desc != "":
			label += " - " + desc
		var index = _skill_ids.size()
		_skill_ids.append(skill_info.id)
		skill_menu.add_item(label, index)
		if current_unit.current_ap < ap_cost or not current_unit.can_act():
			skill_menu.set_item_disabled(index, true)

	if _skill_ids.is_empty():
		skill_menu.add_item("暂无可用技能", 0)
		skill_menu.set_item_disabled(0, true)

	_popup_near_action_menu(skill_menu)

func _open_item_popup() -> void:
	_item_ids.clear()
	if not current_unit:
		return

	item_menu.clear()
	var inventory = GameManager.save_data.get("inventory", [])
	for entry in inventory:
		var item_id = entry.get("id", "")
		if item_id == "":
			continue
		var item = GameData.get_item(item_id)
		if item.is_empty():
			continue
		var count = int(entry.get("count", 1))
		if count <= 0:
			continue
		var usable_type = item.get("type", "")
		if usable_type not in ["consumable", "throwable", "trap"]:
			continue
		var index = _item_ids.size()
		_item_ids.append(item_id)
		var label = "%s  x%d  AP:%d" % [
			item.get("name", item_id),
			count,
			int(item.get("ap_cost", 1))
		]
		if item.get("description", "") != "":
			label += " - " + item.get("description", "")
		item_menu.add_item(label, index)

	if _item_ids.is_empty():
		item_menu.add_item("背包为空", 0)
		item_menu.set_item_disabled(0, true)

	_popup_near_action_menu(item_menu)

func _popup_near_action_menu(menu: PopupMenu) -> void:
	if not action_menu:
		return
	var pos = action_menu.get_global_rect().position + Vector2(0, -8)
	menu.position = pos
	menu.popup()

func _on_skill_popup_id_pressed(id: int) -> void:
	if id >= 0 and id < _skill_ids.size():
		skill_selected.emit(_skill_ids[id])
		skill_menu.hide()

func _on_item_popup_id_pressed(id: int) -> void:
	if id >= 0 and id < _item_ids.size():
		item_selected.emit(_item_ids[id])
		item_menu.hide()

func update_action_menu(unit: Node) -> void:
	current_unit = unit
	if action_menu:
		action_menu.update_for_unit(unit)
		if unit:
			if action_menu.item_button:
				action_menu.item_button.disabled = not _has_usable_inventory_items()
			if action_menu.skill_button:
				action_menu.skill_button.disabled = _count_available_skills(unit) == 0
	if not unit:
		hide_choice_menus()

func hide_choice_menus() -> void:
	if skill_menu:
		skill_menu.hide()
	if item_menu:
		item_menu.hide()

func get_action_menu() -> ActionMenu:
	return action_menu

func _has_usable_inventory_items() -> bool:
	if not GameManager or not GameManager.save_data:
		return false
	var inventory = GameManager.save_data.get("inventory", [])
	for entry in inventory:
		var item_id = entry.get("id", "")
		if item_id == "":
			continue
		var item = GameData.get_item(item_id)
		if item.is_empty():
			continue
		if int(entry.get("count", 1)) <= 0:
			continue
		if item.get("type", "") in ["consumable", "throwable", "trap"]:
			return true
	return false

func _count_available_skills(unit: Node) -> int:
	if not unit:
		return 0
	if not GameData:
		return 0
	var count = 0
	for skill_info in GameData.get_job_skills(unit.job):
		var skill = skill_info.data
		if skill.get("type", "active") == "passive":
			continue
		if not SUPPORTED_SKILLS.has(skill_info.id):
			continue
		if int(skill.get("ap_cost", 1)) > unit.current_ap:
			continue
		if not unit.can_act():
			continue
		count += 1
	return count

func _make_ui_icon(icon_id: String) -> Texture2D:
	var visuals = get_node_or_null("/root/BattleVisuals")
	if not visuals:
		return null
	var atlas = visuals.get_ui_icon_texture()
	if not atlas:
		return null
	var rect = visuals.get_ui_icon_region(icon_id)
	var icon = AtlasTexture.new()
	icon.atlas = atlas
	icon.region = Rect2(rect.position, rect.size)
	return icon

func _make_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = GameTheme.BG_PANEL
	style.border_color = Color(0.23, 0.48, 0.76, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style

func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func update_turn_display(turn: int, phase: int) -> void:
	if not turn_label or not phase_label:
		return
	turn_label.text = "回合 " + str(turn)
	match phase:
		1:
			phase_label.text = "玩家回合"
			phase_label.modulate = Color(0.42, 0.86, 1.0)
		4:
			phase_label.text = "敌方回合"
			phase_label.modulate = Color(1.0, 0.35, 0.31)
		_:
			phase_label.text = "..."

func update_unit_info(unit: Node) -> void:
	if not unit_info_panel:
		return
	if not unit:
		unit_info_panel.show()
		var placeholder = unit_info_panel.get_node_or_null("InfoLabel")
		if placeholder and placeholder is Label:
			placeholder.text = "未选中单位\n点击战场中的单位查看详情。"
		return
	unit_info_panel.show()

	var info_text = "%s\nHP: %d/%d\nAP: %d/%d\n移动: %d\n位置: (%d, %d)" % [
		unit.unit_name,
		unit.current_hp, unit.max_hp,
		unit.current_ap, unit.max_ap,
		unit.move_points,
		unit.grid_pos.x, unit.grid_pos.y
	]

	var label = unit_info_panel.get_node_or_null("InfoLabel")
	if label and label is Label:
		label.text = info_text
		_style_label(label, 16)
		return

	for child in unit_info_panel.get_children():
		if child is Label:
			child.text = info_text
			_style_label(child, 16)
			return

	var new_label = Label.new()
	new_label.name = "InfoLabel"
	new_label.text = info_text
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_info_panel.add_child(new_label)
	_style_label(new_label, 16)

func update_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text

func _on_phase_changed(phase: int) -> void:
	update_turn_display(GameManager.turn_manager.turn_number, phase)

func _on_turn_ended(turn: int) -> void:
	pass

func _on_end_turn_pressed() -> void:
	GameManager.turn_manager.end_player_turn()
