## 商店面板
## 显示可购买的武器和物品；调用 GameManager 完成购买并刷新库存
extends Control
class_name ShopPanel

@onready var items_container = $Panel/ScrollContainer/ItemsContainer
@onready var credit_label = $Panel/TopBar/CreditLabel
@onready var intel_label = $Panel/TopBar/IntelLabel
@onready var refresh_button = $Panel/TopBar/RefreshButton
@onready var close_button = $Panel/TopBar/CloseButton

var shop_items: Array = []
var player_credit: int = 0

func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh)
	close_button.pressed.connect(_on_close)
	# 监听库存变化
	GameManager.inventory_changed.connect(_on_inventory_changed)

## 打开商店
func open_shop(shop_type: String = "general") -> void:
	_generate_shop_items(shop_type)
	_display_items()
	show()

## 生成商店商品列表
func _generate_shop_items(_shop_type: String = "general") -> void:
	shop_items.clear()
	var weapons = GameData.weapon_data.get("weapons", {})
	var items = GameData.item_data.get("items", {})

	# 添加武器（仅常见品质）
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		var rarity = weapon.get("rarity", "common")
		# 商店只卖 common 和 uncommon
		if rarity in ["common", "uncommon"]:
			shop_items.append({
				"id": weapon_id,
				"name": weapon.get("name", weapon_id),
				"type": "equipment",
				"rarity": rarity,
				"price": _get_price(rarity),
				"data": weapon,
				"description": _format_weapon_desc(weapon),
			})

	# 添加物品（消耗品）
	for item_id in items:
		var item = items[item_id]
		var rarity = item.get("rarity", "common")
		# 商店只卖 common 和 uncommon 的消耗品
		if rarity in ["common", "uncommon"] and item.get("type", "") == "consumable":
			shop_items.append({
				"id": item_id,
				"name": item.get("name", item_id),
				"type": "item",
				"rarity": rarity,
				"price": _get_price(rarity) / 2,
				"data": item,
				"description": item.get("description", ""),
			})

func _format_weapon_desc(weapon: Dictionary) -> String:
	var dmg = weapon.get("damage", [0, 0])
	var rng = weapon.get("range", [0, 0])
	return "伤害 %d-%d | 射程 %d-%d" % [dmg[0], dmg[1], rng[0], rng[1]]

func _get_price(rarity: String) -> int:
	match rarity:
		"common": return 200
		"uncommon": return 500
		"rare": return 1200
		"epic": return 3000
		"legendary": return 8000
		_: return 200

func _display_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	# 从 GameManager 获取当前信用点和情报
	player_credit = GameManager.get_credit()
	credit_label.text = "💰 %d" % player_credit
	var intel = GameManager.current_save.get("resources", {}).get("intel", 0)
	intel_label.text = "情报: %d" % intel
	refresh_button.disabled = intel < 10

	# 显示库存已有数量
	var inventory = GameManager.get_inventory()

	if shop_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "（商店货物已售罄）"
		empty_label.modulate = Color.GRAY
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_container.add_child(empty_label)
		return

	for item in shop_items:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(720, 56)

		# 名称
		var name_label = Label.new()
		name_label.text = item.name
		name_label.custom_minimum_size = Vector2(180, 30)
		name_label.modulate = GameTheme.get_rarity_color(item.rarity)
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		# 稀有度
		var rarity_label = Label.new()
		rarity_label.text = "[" + item.rarity + "]"
		rarity_label.custom_minimum_size = Vector2(80, 30)
		rarity_label.modulate = GameTheme.get_rarity_color(item.rarity)
		row.add_child(rarity_label)

		# 描述
		var desc_label = Label.new()
		desc_label.text = item.description
		desc_label.custom_minimum_size = Vector2(240, 30)
		desc_label.modulate = Color(0.78, 0.78, 0.78)
		desc_label.clip_text = true
		row.add_child(desc_label)

		# 价格
		var price_label = Label.new()
		price_label.text = "💰 " + str(item.price)
		price_label.custom_minimum_size = Vector2(80, 30)
		price_label.modulate = Color(1, 0.85, 0.4)
		row.add_child(price_label)

		# 已持有数量
		var owned = inventory.get(item.id, 0)
		var owned_label = Label.new()
		owned_label.text = "持有: " + str(owned)
		owned_label.custom_minimum_size = Vector2(80, 30)
		owned_label.modulate = Color.GRAY
		row.add_child(owned_label)

		# 购买按钮
		var buy_button = Button.new()
		buy_button.text = "购买"
		buy_button.custom_minimum_size = Vector2(80, 32)
		buy_button.disabled = player_credit < item.price
		buy_button.pressed.connect(_on_buy.bind(item))
		row.add_child(buy_button)

		items_container.add_child(row)

func _on_buy(item: Dictionary) -> void:
	# 简单确认对话框
	var dialog = preload("res://scenes/error_dialog.tscn").instantiate()
	dialog.setup(
		"购买确认",
		"购买 %s？\n价格：%d 💰\n当前余额：%d 💰" % [item.name, item.price, player_credit],
		Callable(self, "_confirm_buy").bind(item)
	)
	add_child(dialog)

func _confirm_buy(item: Dictionary) -> void:
	# 调用 GameManager 购买
	if GameManager.purchase_item(item.id, item.price):
		_display_items()

func _on_refresh() -> void:
	# 刷新商店（消耗情报点）
	var intel = GameManager.current_save.get("resources", {}).get("intel", 0)
	if intel < 10:
		return
	GameManager.current_save.resources.intel = intel - 10
	GameManager.save_current()
	_generate_shop_items()
	_display_items()

func _on_inventory_changed() -> void:
	if is_visible_in_tree():
		_display_items()

func _on_close() -> void:
	hide()
	queue_free()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

func set_credit(credit: int) -> void:
	player_credit = credit
	if is_inside_tree():
		_display_items()
