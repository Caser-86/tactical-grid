extends Control
class_name RoguelikeController

@onready var title_label = $TopBar/TitleLabel
@onready var floor_label = $TopBar/FloorLabel
@onready var credit_label = $TopBar/CreditLabel
@onready var nodes_container = $Center/NodesContainer
@onready var event_panel = $EventPanel
@onready var event_title = $EventPanel/VBox/TitleLabel
@onready var event_desc = $EventPanel/VBox/DescLabel
@onready var event_choices = $EventPanel/VBox/ChoicesContainer
@onready var shop_panel = $ShopPanel
@onready var result_panel = $ResultPanel
@onready var result_title = $ResultPanel/VBox/TitleLabel
@onready var result_stats = $ResultPanel/VBox/StatsLabel
@onready var back_button = $ResultPanel/VBox/BackButton

var node_buttons: Array = []
var current_event: Dictionary = {}

func _ready() -> void:
	AudioManager.bgm_base()
	if not RoguelikeManager.is_active:
		RoguelikeManager.start_run()
	if RoguelikeManager.current_run.get("current_floor", 0) == 0:
		RoguelikeManager.advance_floor()
	_update_ui()
	_build_path_ui()
	_show_current_node()

func _update_ui() -> void:
	var run = RoguelikeManager.current_run
	title_label.text = "深渊远征"
	floor_label.text = "第 %d / %d 层" % [run.get("current_floor", 0), RoguelikeManager.MAX_FLOORS]
	credit_label.text = "%d CR" % run.get("credit", 0)

func _build_path_ui() -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	node_buttons.clear()

	var path = RoguelikeManager.current_run.get("path", [])
	for i in range(path.size()):
		var node = path[i]
		var button = Button.new()
		button.custom_minimum_size = Vector2(80, 80)
		button.text = _get_node_label(node)
		button.disabled = i != RoguelikeManager.current_run.get("current_floor", 0) - 1

		var style = StyleBoxFlat.new()
		style.bg_color = _get_node_color(node.get("type", "normal_battle"))
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(_on_node_selected.bind(i))
		nodes_container.add_child(button)
		node_buttons.append(button)

func _get_node_label(node: Dictionary) -> String:
	var type = node.get("type", "normal_battle")
	match type:
		"normal_battle": return "战斗"
		"elite_battle": return "精英"
		"boss": return "BOSS"
		"shop": return "商店"
		"event": return "事件"
		"rest": return "休息"
		"treasure": return "宝藏"
		"mystery": return "?"
		_: return type

func _get_node_color(type: String) -> Color:
	match type:
		"normal_battle": return Color(0.2, 0.35, 0.5)
		"elite_battle": return Color(0.5, 0.25, 0.4)
		"boss": return Color(0.7, 0.15, 0.15)
		"shop": return Color(0.2, 0.5, 0.35)
		"event": return Color(0.5, 0.4, 0.2)
		"rest": return Color(0.3, 0.3, 0.5)
		"treasure": return Color(0.5, 0.45, 0.15)
		"mystery": return Color(0.3, 0.15, 0.5)
		_: return Color(0.3, 0.3, 0.3)

func _show_current_node() -> void:
	_hide_panels()
	var node = RoguelikeManager.get_current_node()
	if node.is_empty():
		_show_victory()
		return

	match node.get("type", ""):
		"normal_battle", "elite_battle", "boss":
			_enter_battle(node)
		"shop":
			_show_shop(node)
		"event":
			_show_event(node)
		"rest":
			_show_rest(node)
		"treasure", "mystery":
			_show_treasure(node)

func _hide_panels() -> void:
	event_panel.hide()
	shop_panel.hide()
	result_panel.hide()

func _on_node_selected(index: int) -> void:
	var current_floor = RoguelikeManager.current_run.get("current_floor", 0)
	if index != current_floor - 1:
		return
	_show_current_node()

func _enter_battle(node: Dictionary) -> void:
	var theme = node.get("data", {}).get("terrain", "warehouse")
	var is_boss = node.get("type", "") == "boss"
	var enemy_count = node.get("data", {}).get("enemies", 3)
	var enemy_tier = node.get("data", {}).get("enemy_tier", "normal")
	var boss_id = node.get("data", {}).get("boss_id", "")

	var map_data = ProceduralGenerator.generate_roguelike_battle(theme, enemy_count, enemy_tier, boss_id, is_boss)
	GameManager.current_map_data = MapLoader.load_from_dict(map_data)
	GameManager.current_level_id = "rl_f" + str(RoguelikeManager.current_run.get("current_floor", 1))
	GameManager.in_roguelike = true
	_call_deferred_change_scene("res://scenes/battle.tscn")

func _call_deferred_change_scene(scene_path: String) -> void:
	TransitionManager.change_scene.call_deferred(scene_path)

func _show_event(node: Dictionary) -> void:
	current_event = node.get("data", {})
	event_title.text = current_event.get("name", "事件")
	event_desc.text = current_event.get("description", "")

	for child in event_choices.get_children():
		child.queue_free()

	for choice in current_event.get("choices", []):
		var button = Button.new()
		button.text = choice.get("text", "选择")
		button.pressed.connect(_on_event_choice.bind(choice))
		event_choices.add_child(button)

	event_panel.show()

func _on_event_choice(choice: Dictionary) -> void:
	var effect = choice.get("effect", "nothing")
	_apply_event_effect(effect)
	_hide_panels()
	_advance_or_victory()

func _apply_event_effect(effect: String) -> void:
	match effect:
		"random_upgrade":
			var upgrades = GameData.roguelike_data.get("roguelike", {}).get("upgrade_pool", {}).get("stat_boosts", [])
			if upgrades.size() > 0:
				RoguelikeManager.apply_upgrade(upgrades[0].get("id", ""))
		"lose_20_hp_get_epic_upgrade":
			for member in RoguelikeManager.current_run.team_state.members:
				member.hp = max(member.hp - 20, 1)
			var upgrades = GameData.roguelike_data.get("roguelike", {}).get("upgrade_pool", {}).get("combat_boosts", [])
			if upgrades.size() > 0:
				RoguelikeManager.apply_upgrade(upgrades[0].get("id", ""))
		"open_shop":
			_show_shop({"data": {"inventory": _generate_simple_shop_inventory()}})
		"fight_merchant":
			_enter_battle({"type": "elite_battle", "data": {"enemies": 4, "enemy_tier": "elite", "terrain": "warehouse"}})
		"chance_50_injury":
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			if rng.randf() < 0.5:
				for member in RoguelikeManager.current_run.team_state.members:
					member.hp = max(member.hp - 15, 1)
		"guaranteed_injury_get_loot":
			for member in RoguelikeManager.current_run.team_state.members:
				member.hp = max(member.hp - 15, 1)
			RoguelikeManager.current_run.credit += 150
		"nothing", "detour":
			pass

func _show_shop(node: Dictionary) -> void:
	for child in shop_panel.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "远征商店"
	title.add_theme_font_size_override("font_size", 24)
	shop_panel.add_child(title)

	var inventory = node.get("data", {}).get("inventory", [])
	for item in inventory:
		var button = Button.new()
		button.text = "%s - %d CR" % [item.get("item", "物品"), item.get("price", 0)]
		button.pressed.connect(_on_shop_buy.bind(item))
		shop_panel.add_child(button)

	var close = Button.new()
	close.text = "关闭"
	close.pressed.connect(_advance_or_victory)
	shop_panel.add_child(close)

	shop_panel.show()

func _on_shop_buy(item: Dictionary) -> void:
	if RoguelikeManager.purchase_item(item):
		_update_ui()
	else:
		_show_floating_text("信用点不足")

func _generate_simple_shop_inventory() -> Array:
	var floor = RoguelikeManager.current_run.get("current_floor", 1)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var pool := ["med_kit", "painkiller", "grenade", "ammo_ap", "stim_pack"]
	var items := []
	var count = rng.randi_range(3, 5)
	for i in range(count):
		var item_id = pool[rng.randi_range(0, pool.size() - 1)]
		items.append({
			"item": item_id,
			"price": int((50 + floor * 30) * rng.randf_range(0.8, 1.2)),
			"stock": 1,
		})
	return items

func _show_rest(node: Dictionary) -> void:
	var heal = node.get("data", {}).get("heal_percent", 0.3)
	for member in RoguelikeManager.current_run.team_state.members:
		member.hp = min(member.hp + int(member.max_hp * heal), member.max_hp)
		if node.get("data", {}).get("ap_restore", false):
			member.ap = member.max_ap
	_show_floating_text("全队恢复 %d%% HP" % int(heal * 100))
	_advance_or_victory()

func _show_treasure(node: Dictionary) -> void:
	var reward = node.get("data", {}).get("reward", {})
	match reward.get("type", ""):
		"credit":
			var amount = reward.get("amount", 100)
			RoguelikeManager.current_run.credit += amount
			_show_floating_text("获得 %d CR" % amount)
		"equipment":
			_show_floating_text("获得装备: " + reward.get("rarity", "稀有"))
		"upgrade":
			var pool = reward.get("pool", "stat_boosts")
			var upgrades = GameData.roguelike_data.get("roguelike", {}).get("upgrade_pool", {}).get(pool, [])
			if upgrades.size() > 0:
				RoguelikeManager.apply_upgrade(upgrades[0].get("id", ""))
			_show_floating_text("获得强化")
		"trap":
			var damage = reward.get("damage", 30)
			for member in RoguelikeManager.current_run.team_state.members:
				member.hp = max(member.hp - damage, 1)
			_show_floating_text("陷阱! 全队受到 %d 伤害" % damage)
	_advance_or_victory()

func _advance_or_victory() -> void:
	RoguelikeManager.complete_floor({"credit": 50})
	var result = RoguelikeManager.advance_floor()
	if result.get("victory", false):
		_show_victory()
		return
	_update_ui()
	_build_path_ui()
	_show_current_node()

func _show_victory() -> void:
	_hide_panels()
	var result = RoguelikeManager.finish_run()
	result_title.text = "远征完成!" if result.get("is_victory", false) else "远征结束"
	result_stats.text = "到达层数: %d\n获得信用点: %d\n击杀数: %d" % [
		result.get("floors_cleared", 0),
		result.get("credit_earned", 0),
		result.get("kills", 0)
	]
	back_button.pressed.connect(_return_to_base)
	result_panel.show()

func _return_to_base() -> void:
	TransitionManager.change_scene("res://scenes/base.tscn")

func _show_floating_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(size.x / 2 - 100, size.y / 2)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 80, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

func _exit_tree() -> void:
	AudioManager.stop_bgm()
	ArtAssets.clear_cache()
