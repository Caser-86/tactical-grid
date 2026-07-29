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
	_apply_visual_theme()
	move_button.pressed.connect(_on_move_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	item_button.pressed.connect(_on_item_pressed)
	overwatch_button.pressed.connect(_on_overwatch_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	set_action_buttons_visible(false)

## 将默认控件转换为高对比的战术 HUD，不改变任何输入或战斗规则。
func _apply_visual_theme() -> void:
	$TopBar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.055, 0.075, 0.94), Color(0.18, 0.72, 0.82, 0.62)))
	$RightPanel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.045, 0.06, 0.08, 0.92), Color(0.18, 0.55, 0.66, 0.50)))
	$BottomBar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.04, 0.055, 0.96), Color(0.16, 0.68, 0.80, 0.68)))
	for button in [move_button, attack_button, skill_button, item_button, overwatch_button, end_turn_button, pause_button]:
		_style_button(button)
	end_turn_button.add_theme_color_override("font_color", Color(0.95, 0.84, 0.55))
	phase_label.add_theme_font_size_override("font_size", 18)
	turn_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
	unit_info_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.96))
	battle_log.add_theme_color_override("font_color", Color(0.62, 0.78, 0.84))

func _make_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func _style_button(button: Button) -> void:
	var normal := _make_panel_style(Color(0.07, 0.13, 0.17, 0.98), Color(0.20, 0.55, 0.66, 0.78))
	var hover := _make_panel_style(Color(0.09, 0.23, 0.29, 1.0), Color(0.32, 0.94, 1.0, 0.95))
	var pressed := _make_panel_style(Color(0.04, 0.32, 0.39, 1.0), Color(0.68, 1.0, 1.0, 1.0))
	var disabled := _make_panel_style(Color(0.055, 0.065, 0.075, 0.92), Color(0.20, 0.25, 0.28, 0.65))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.94, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.48, 0.52))

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

## 在窗口尺寸变化时更新 HUD 安全区域，避免裁切或大面积空白
func apply_viewport_layout(viewport_size: Vector2i) -> void:
	# RightPanel 固定宽度 250，贴右边缘
	var right_panel = $RightPanel
	right_panel.offset_left = -250.0
	right_panel.offset_right = 0.0

	# BattleLog 限制在左侧 350px 宽度内，距底部 70px
	var log = $BattleLog
	log.offset_right = min(350.0, float(viewport_size.x) * 0.3)

	# ActionBar 居中，总宽度不超过视口 80%
	var action_bar = $BottomBar/ActionBar
	var bar_width = float(viewport_size.x) * 0.8
	action_bar.offset_left = -bar_width * 0.5
	action_bar.offset_right = bar_width * 0.5

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
