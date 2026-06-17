## HUD 控制器
## 管理战斗界面的所有 UI 元素
extends CanvasLayer
class_name HUD

@onready var turn_label = $TopBar/TurnLabel
@onready var phase_label = $TopBar/PhaseLabel
@onready var objective_label = $TopBar/ObjectiveLabel
@onready var unit_info_panel = $RightPanel/UnitInfo
@onready var action_bar = $BottomBar/ActionBar
@onready var end_turn_button = $BottomBar/ActionBar/EndTurnButton

func _ready() -> void:
	GameManager.turn_manager.turn_phase_changed.connect(_on_phase_changed)
	GameManager.turn_manager.turn_ended.connect(_on_turn_ended)

func update_turn_display(turn: int, phase: int) -> void:
	turn_label.text = "回合 " + str(turn)
	match phase:
		1:  # PLAYER_ACTION
			phase_label.text = "玩家回合"
			phase_label.modulate = Color.CYAN
		4:  # ENEMY_ACTION
			phase_label.text = "敌人回合"
			phase_label.modulate = Color.RED
		_:
			phase_label.text = "..."

func update_unit_info(unit: Node) -> void:
	if not unit:
		unit_info_panel.hide()
		return
	unit_info_panel.show()
	# 更新显示
	var info_text = "%s\nHP: %d/%d\nAP: %d/%d\n移动: %d\n位置: (%d, %d)" % [
		unit.unit_name,
		unit.current_hp, unit.max_hp,
		unit.current_ap, unit.max_ap,
		unit.move_points,
		unit.grid_pos.x, unit.grid_pos.y
	]
	# TODO: 设置到 Label

func update_objective(text: String) -> void:
	objective_label.text = text

func _on_phase_changed(phase: int) -> void:
	update_turn_display(GameManager.turn_manager.turn_number, phase)

func _on_turn_ended(turn: int) -> void:
	pass

func _on_end_turn_pressed() -> void:
	GameManager.turn_manager.end_player_turn()
