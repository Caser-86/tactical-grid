## 琛屽姩鑿滃崟
## 鏄剧ず褰撳墠鍗曚綅鍙敤鐨勮鍔ㄩ€夐」
extends Control
class_name ActionMenu

signal action_selected(action: String)

@onready var move_button = get_node_or_null("Panel/VBox/MoveButton")
@onready var attack_button = get_node_or_null("Panel/VBox/AttackButton")
@onready var skill_button = get_node_or_null("Panel/VBox/SkillButton")
@onready var item_button = get_node_or_null("Panel/VBox/ItemButton")
@onready var overwatch_button = get_node_or_null("Panel/VBox/OverwatchButton")
@onready var end_turn_button = get_node_or_null("Panel/VBox/EndTurnButton")

func _ready() -> void:
	if move_button:
		move_button.pressed.connect(func(): action_selected.emit("move"))
	if attack_button:
		attack_button.pressed.connect(func(): action_selected.emit("attack"))
	if skill_button:
		skill_button.pressed.connect(func(): action_selected.emit("skill"))
	if item_button:
		item_button.pressed.connect(func(): action_selected.emit("item"))
	if overwatch_button:
		overwatch_button.pressed.connect(func(): action_selected.emit("overwatch"))
	if end_turn_button:
		end_turn_button.pressed.connect(func(): action_selected.emit("end_turn"))

## 鏍规嵁鍗曚綅鐘舵€佹洿鏂版寜閽彲鐢ㄦ€?
func update_for_unit(unit: Node) -> void:
	if not unit:
		hide()
		return

	show()

	if move_button:
		move_button.disabled = not unit.can_move() or unit.move_points <= 0
	if attack_button:
		attack_button.disabled = not unit.can_act()
	if skill_button:
		skill_button.disabled = not unit.can_act()
	if item_button:
		item_button.disabled = not unit.can_act() or not _has_usable_inventory_items()
	if overwatch_button:
		overwatch_button.disabled = unit.current_ap < 1

	# 绉诲姩鍚庢敾鍑婚檺鍒?
	if unit.has_status("moved"):
		if attack_button:
			attack_button.disabled = true

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
