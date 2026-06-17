## 行动菜单
## 显示当前单位可用的行动选项
extends Control
class_name ActionMenu

signal action_selected(action: String)

@onready var move_button = $Panel/VBox/MoveButton
@onready var attack_button = $Panel/VBox/AttackButton
@onready var skill_button = $Panel/VBox/SkillButton
@onready var item_button = $Panel/VBox/ItemButton
@onready var overwatch_button = $Panel/VBox/OverwatchButton
@onready var end_turn_button = $Panel/VBox/EndTurnButton

func _ready() -> void:
	move_button.pressed.connect(func(): action_selected.emit("move"))
	attack_button.pressed.connect(func(): action_selected.emit("attack"))
	skill_button.pressed.connect(func(): action_selected.emit("skill"))
	item_button.pressed.connect(func(): action_selected.emit("item"))
	overwatch_button.pressed.connect(func(): action_selected.emit("overwatch"))
	end_turn_button.pressed.connect(func(): action_selected.emit("end_turn"))

## 根据单位状态更新按钮可用性
func update_for_unit(unit: Node) -> void:
	if not unit:
		hide()
		return

	show()

	move_button.disabled = not unit.can_move() or unit.move_points <= 0
	attack_button.disabled = not unit.can_act()
	skill_button.disabled = not unit.can_act()
	item_button.disabled = not unit.can_act()
	overwatch_button.disabled = unit.current_ap < 1

	# 移动后攻击限制
	if unit.has_status("moved"):
		attack_button.disabled = true
