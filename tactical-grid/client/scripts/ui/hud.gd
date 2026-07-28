## HUD 控制器
## 管理战斗界面的所有 UI 元素
extends CanvasLayer
class_name HUD

@onready var turn_label = $TopBar/TurnLabel
@onready var phase_label = $TopBar/PhaseLabel
@onready var objective_label = $TopBar/ObjectiveLabel
@onready var unit_info_label = $RightPanel/UnitInfoLabel
@onready var move_button = $BottomBar/ActionBar/MoveButton
@onready var attack_button = $BottomBar/ActionBar/AttackButton
@onready var skill_button = $BottomBar/ActionBar/SkillButton
@onready var item_button = $BottomBar/ActionBar/ItemButton
@onready var overwatch_button = $BottomBar/ActionBar/OverwatchButton
@onready var end_turn_button = $BottomBar/ActionBar/EndTurnButton
@onready var battle_log = $BattleLog
@onready var pause_button = $PauseButton

var _battle_controller: Node = null
var _log_lines: Array[String] = []
const MAX_LOG_LINES = 8

func _ready() -> void:
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	item_button.pressed.connect(_on_item_pressed)
	overwatch_button.pressed.connect(_on_overwatch_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	set_action_buttons_visible(false)

func set_battle_controller(controller: Node) -> void:
	_battle_controller = controller

func update_turn_display(turn: int, phase: int) -> void:
	turn_label.text = "回合 %d" % turn
	match phase:
		TurnManager.TurnPhase.PLAYER_ACTION:
			phase_label.text = "玩家回合"
			phase_label.modulate = Color.CYAN
		TurnManager.TurnPhase.ENEMY_ACTION:
			phase_label.text = "敌人回合"
			phase_label.modulate = Color.RED
		TurnManager.TurnPhase.BATTLE_OVER:
			phase_label.text = "战斗结束"
			phase_label.modulate = Color.GOLD
		_:
			phase_label.text = "..."

func update_unit_info(unit: Node) -> void:
	if not unit or not unit.is_alive:
		unit_info_label.text = ""
		set_action_buttons_visible(false)
		return

	var team_label = "玩家" if unit.team == "player" else "敌人"
	var info = "%s [%s]\nHP: %d/%d\nAP: %d/%d\n移动: %d\n位置: (%d, %d)" % [
		unit.unit_name, team_label,
		unit.current_hp, unit.max_hp,
		unit.current_ap, unit.max_ap,
		unit.move_points,
		unit.grid_pos.x, unit.grid_pos.y
	]
	unit_info_label.text = info

	# 只有玩家单位且在玩家回合时显示操作按钮
	if unit.team == "player":
		set_action_buttons_visible(true)
		var can_act = unit.current_ap > 0
		attack_button.disabled = not can_act
		skill_button.disabled = not can_act
		overwatch_button.disabled = not can_act
	else:
		set_action_buttons_visible(false)

func update_objective(text: String) -> void:
	objective_label.text = text

func set_buttons_disabled(disabled: bool) -> void:
	move_button.disabled = disabled
	attack_button.disabled = disabled
	skill_button.disabled = disabled
	item_button.disabled = disabled
	overwatch_button.disabled = disabled
	end_turn_button.disabled = disabled

func set_action_buttons_visible(visible: bool) -> void:
	# 始终显示结束回合，其他按钮根据选择状态
	move_button.visible = visible
	attack_button.visible = visible
	skill_button.visible = visible
	item_button.visible = visible
	overwatch_button.visible = visible

func add_log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	battle_log.text = "\n".join(_log_lines)

func _on_move_pressed() -> void:
	if _battle_controller:
		_battle_controller.on_move_button()

func _on_attack_pressed() -> void:
	if _battle_controller:
		_battle_controller.on_attack_button()

func _on_skill_pressed() -> void:
	if _battle_controller:
		_battle_controller.on_skill_button()

func _on_item_pressed() -> void:
	if _battle_controller:
		_battle_controller.on_item_button()

func _on_overwatch_pressed() -> void:
	if _battle_controller:
		_battle_controller.on_overwatch_button()

func _on_end_turn_pressed() -> void:
	if _battle_controller:
		_battle_controller.on_end_turn_button()

func _on_pause_pressed() -> void:
	if _battle_controller:
		_battle_controller._show_pause_menu()
