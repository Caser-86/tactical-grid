## 商店面板
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
	# 从 API 获取商店数据
	# TODO: 实现 API 调用
	_generate_test_items()
	_display_items()
	show()

func _generate_test_items() -> void:
	shop_items.clear()
	var weapons = GameData.weapon_data.get("weapons", {})
	var items = GameData.item_data.get("items", {})

	# 添加武器
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

	# 添加物品
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

	credit_label.text = "💰 " + str(player_credit)

	for item in shop_items:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(600, 40)

		# 名称
		var name_label = Label.new()
		name_label.text = item.name
		name_label.custom_minimum_size = Vector2(200, 30)
		name_label.modulate = GameTheme.get_rarity_color(item.rarity)
		row.add_child(name_label)

		# 稀有度
		var rarity_label = Label.new()
		rarity_label.text = "[" + item.rarity + "]"
		rarity_label.custom_minimum_size = Vector2(80, 30)
		rarity_label.modulate = GameTheme.get_rarity_color(item.rarity)
		row.add_child(rarity_label)

		# 价格
		var price_label = Label.new()
		price_label.text = "💰 " + str(item.price)
		price_label.custom_minimum_size = Vector2(100, 30)
		row.add_child(price_label)

		# 购买按钮
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
	# TODO: 添加到背包
	print("Purchased: ", item.name)
	_display_items()

func _on_refresh() -> void:
	# 刷新商店（消耗情报点）
	_generate_test_items()
	_display_items()

func set_credit(credit: int) -> void:
	player_credit = credit
	if is_inside_tree():
		_display_items()
