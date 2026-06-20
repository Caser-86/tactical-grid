extends Control
class_name ShopPanel

@onready var items_container = $Panel/ScrollContainer/ItemsContainer
@onready var credit_label = $Panel/TopBar/CreditLabel
@onready var refresh_button = $Panel/TopBar/RefreshButton
@onready var close_button = $Panel/TopBar/CloseButton

var shop_items: Array = []
var player_credit: int = 0

func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh)
	close_button.pressed.connect(hide)

func open_shop(shop_type: String = "general") -> void:
	match shop_type:
		"weapons":
			_generate_weapon_shop()
		"items":
			_generate_item_shop()
		_:
			_generate_test_items()
	_display_items()
	show()

func _generate_test_items() -> void:
	shop_items.clear()
	var weapons = GameData.weapon_data.get("weapons", {})
	var items = GameData.item_data.get("items", {})

	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		shop_items.append({
			"id": weapon_id,
			"name": weapon.get("name", weapon_id),
			"type": "equipment",
			"rarity": weapon.get("rarity", "common"),
			"price": _get_price(weapon.get("rarity", "common")),
			"data": weapon,
		})

	for item_id in items:
		var item = items[item_id]
		shop_items.append({
			"id": item_id,
			"name": item.get("name", item_id),
			"type": "item",
			"rarity": item.get("rarity", "common"),
			"price": _get_price(item.get("rarity", "common")) / 2,
			"data": item,
		})

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

	credit_label.text = "信用点 " + str(player_credit)

	for item in shop_items:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(600, 40)

		var name_label = Label.new()
		name_label.text = item.name
		name_label.custom_minimum_size = Vector2(200, 30)
		name_label.modulate = GameTheme.get_rarity_color(item.rarity)
		row.add_child(name_label)

		var rarity_label = Label.new()
		rarity_label.text = "[" + item.rarity + "]"
		rarity_label.custom_minimum_size = Vector2(80, 30)
		rarity_label.modulate = GameTheme.get_rarity_color(item.rarity)
		row.add_child(rarity_label)

		var price_label = Label.new()
		price_label.text = "信用点 " + str(item.price)
		price_label.custom_minimum_size = Vector2(100, 30)
		row.add_child(price_label)

		var buy_button = Button.new()
		buy_button.text = "购买"
		buy_button.custom_minimum_size = Vector2(80, 30)
		buy_button.disabled = player_credit < item.price
		buy_button.pressed.connect(_on_buy.bind(item))
		row.add_child(buy_button)

		items_container.add_child(row)

func _on_buy(item: Dictionary) -> void:
	if player_credit < item.price:
		return

	player_credit -= item.price
	var resources = GameManager.save_data.get("resources", {})
	resources["credit"] = player_credit
	GameManager.save_data["resources"] = resources

	var inv = GameManager.save_data.get("inventory", [])
	var existing = inv.filter(func(i): return i.get("id") == item.id)
	if existing.size() > 0:
		existing[0]["count"] = existing[0].get("count", 1) + 1
	else:
		inv.append({"id": item.get("id", ""), "type": item.get("type", ""), "count": 1})
	GameManager.save_data["inventory"] = inv
	SaveManager.auto_save(GameManager.save_data)
	_display_items()

func _on_refresh() -> void:
	_generate_test_items()
	_display_items()

func set_credit(credit: int) -> void:
	player_credit = credit
	if is_inside_tree():
		_display_items()

func _generate_weapon_shop() -> void:
	shop_items.clear()
	var weapons = GameData.weapon_data.get("weapons", {})
	var rare_weapons = GameData.weapon_data.get("rare_weapons", {})
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		shop_items.append({
			"id": weapon_id,
			"name": weapon.get("name", weapon_id),
			"type": "equipment",
			"rarity": weapon.get("rarity", "common"),
			"price": _get_price(weapon.get("rarity", "common")),
			"data": weapon,
		})
	for weapon_id in rare_weapons:
		var weapon = rare_weapons[weapon_id]
		shop_items.append({
			"id": weapon_id,
			"name": weapon.get("name", weapon_id),
			"type": "equipment",
			"rarity": weapon.get("rarity", "rare"),
			"price": _get_price(weapon.get("rarity", "rare")),
			"data": weapon,
		})

func _generate_item_shop() -> void:
	shop_items.clear()
	var items = GameData.item_data.get("items", {})
	for item_id in items:
		var item = items[item_id]
		shop_items.append({
			"id": item_id,
			"name": item.get("name", item_id),
			"type": "item",
			"rarity": item.get("rarity", "common"),
			"price": _get_price(item.get("rarity", "common")) / 2,
			"data": item,
		})
