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
## 顶部栏保留一行战斗状态，第二行用于警报，避免状态文案覆盖回合信息。
const TOP_BAR_HEIGHT := 78.0

## 当前目标选择提示文本（由 battle_controller 设置）
var targeting_hint: String = ""

## 当前活跃的行动选择面板（技能/物品列表）
var _action_picker: PopupPanel = null
## 行动选择面板的回调（选中后调用）
var _action_picker_callback: Callable = Callable()

## CODE-P0-02: 上下文状态枚举，驱动 HUD 提示与按钮可见性
enum ContextState { NONE, UNIT_SELECTED, MOVE_PREVIEW, ATTACK_PREVIEW, FACILITY_PREVIEW }
var _context_state: ContextState = ContextState.NONE
var _context_prompt: Label = null
## CODE-P2-02: 警报显示标签和网络覆盖层
var _alert_label: Label = null
var _network_overlay: Control = null
var _network_overlay_visible: bool = false
## CH1-050: 敌方意图威胁摘要标签，显示在警报标签下方。
var _threat_label: Label = null

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
	# CODE-P0-02: context prompt label
	_context_prompt = Label.new()
	_context_prompt.name = "ContextPrompt"
	_context_prompt.text = "选择一个单位开始行动"
	_context_prompt.add_theme_font_size_override("font_size", 16)
	_context_prompt.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0, 0.85))
	_context_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_context_prompt.offset_top = -80.0
	_context_prompt.offset_bottom = -60.0
	_context_prompt.visible = false
	add_child(_context_prompt)
	set_context_state(ContextState.NONE)
	# CODE-P2-02: Alert display label (top bar second row)
	_alert_label = Label.new()
	_alert_label.name = "AlertLabel"
	_alert_label.text = ""
	_alert_label.add_theme_font_size_override("font_size", 12)
	_alert_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	_alert_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_alert_label.anchor_right = 1.0
	_alert_label.offset_left = 8.0
	_alert_label.offset_top = 50.0
	_alert_label.offset_right = -112.0
	_alert_label.offset_bottom = 73.0
	_alert_label.clip_text = true
	_alert_label.visible = false
	$TopBar.add_child(_alert_label)

	# CODE-P2-02: Network overlay (hidden by default, G toggles; visualization only)
	_network_overlay = Control.new()
	_network_overlay.name = "NetworkOverlay"
	_network_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_network_overlay.visible = false
	_network_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_network_overlay)

	# CH1-050: Threat summary label (right panel, below selected-unit details).
	# Summarizes observed enemy intents so the player can read the most
	# dangerous known threats before ending the turn.
	_threat_label = Label.new()
	_threat_label.name = "ThreatLabel"
	_threat_label.text = ""
	_threat_label.add_theme_font_size_override("font_size", 13)
	_threat_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.55))
	_threat_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_threat_label.offset_left = 10.0
	_threat_label.offset_top = 312.0
	_threat_label.offset_right = 240.0
	_threat_label.offset_bottom = 432.0
	_threat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_threat_label.visible = false
	$RightPanel.add_child(_threat_label)

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

## 为 PopupPanel 应用与战场一致的高对比样式
func _style_popup_panel(panel: PopupPanel) -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.06, 0.08, 0.98), Color(0.18, 0.72, 0.82, 0.85)))
	panel.add_theme_constant_override("margin_left", 12)
	panel.add_theme_constant_override("margin_right", 12)
	panel.add_theme_constant_override("margin_top", 10)
	panel.add_theme_constant_override("margin_bottom", 10)

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
		set_context_state(ContextState.NONE)
		return

	var team_label = "玩家" if unit.team == "player" else "敌人"
	var shield_info := ""
	if unit.max_shield > 0:
		shield_info = "\n护盾: %d/%d" % [unit.current_shield, unit.max_shield]
	var info = "%s [%s]\nHP: %d/%d%s\nAP: %d/%d\n移动: %d\n位置: (%d, %d)" % [
		unit.unit_name, team_label,
		unit.current_hp, unit.max_hp,
		shield_info,
		unit.current_ap, unit.max_ap,
		unit.move_points,
		unit.grid_pos.x, unit.grid_pos.y
	]
	unit_info_label.text = info

	# 只有玩家单位且在玩家回合时显示操作按钮
	if unit.team == "player":
		set_action_buttons_visible(true)
		set_context_state(ContextState.UNIT_SELECTED)
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

## CODE-P0-02: 上下文状态控制 HUD 显示
func set_context_state(state: ContextState) -> void:
	_context_state = state
	match state:
		ContextState.NONE:
			set_action_buttons_visible(false)
			end_turn_button.visible = true
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "选择一个单位开始行动"
		ContextState.UNIT_SELECTED:
			if _context_prompt:
				_context_prompt.visible = false
		ContextState.MOVE_PREVIEW:
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "点击蓝色高亮格移动，右键取消"
		ContextState.ATTACK_PREVIEW:
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "点击红色目标攻击，右键取消"
		ContextState.FACILITY_PREVIEW:
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "点击设施节点交互，右键取消"

## 在窗口尺寸变化时更新 HUD 安全区域，避免裁切或大面积空白
func apply_viewport_layout(viewport_size: Vector2i) -> void:
	# 目标栏占据回合信息与暂停按钮之间的空间，Boss 状态在窄屏也优先可读。
	objective_label.offset_left = minf(370.0, float(viewport_size.x) * 0.36)
	objective_label.offset_right = -100.0

	# RightPanel 固定宽度 250，贴右边缘
	var right_panel = $RightPanel
	right_panel.offset_left = -250.0
	right_panel.offset_right = 0.0
	right_panel.offset_top = TOP_BAR_HEIGHT

	# BattleLog 限制在左侧 350px 宽度内，距底部 70px
	var log = $BattleLog
	log.offset_right = min(350.0, float(viewport_size.x) * 0.3)

	# ActionBar 居中，总宽度不超过视口 80%
	var action_bar = $BottomBar/ActionBar
	var bar_width = float(viewport_size.x) * 0.8
	action_bar.offset_left = -bar_width * 0.5
	action_bar.offset_right = bar_width * 0.5

func get_top_bar_height() -> float:
	return TOP_BAR_HEIGHT

func add_log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	battle_log.text = "\n".join(_log_lines)

## 显示技能/物品选择面板
## items: Array[Dictionary]，每个字典包含 {id, name, description, disabled, disabled_reason}
## on_selected: Callable，签名为 (String id) -> void
func show_action_picker(title: String, items: Array, on_selected: Callable) -> void:
	hide_action_picker()
	_action_picker_callback = on_selected
	var popup := PopupPanel.new()
	popup.name = "ActionPicker"
	_style_popup_panel(popup)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	popup.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.55))
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for item in items:
		var id = String(item.get("id", ""))
		var name = String(item.get("name", id))
		var desc = String(item.get("description", ""))
		var disabled = bool(item.get("disabled", false))
		var disabled_reason = String(item.get("disabled_reason", ""))
		var btn := Button.new()
		btn.text = name
		btn.custom_minimum_size = Vector2(280, 36)
		_style_button(btn)
		if disabled:
			btn.disabled = true
			btn.tooltip_text = disabled_reason if disabled_reason != "" else "不可用"
		elif desc != "":
			btn.tooltip_text = desc
		btn.pressed.connect(_on_action_picker_item.bind(id))
		vbox.add_child(btn)

	# 取消按钮
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(280, 36)
	_style_button(cancel_btn)
	cancel_btn.add_theme_color_override("font_color", Color(0.82, 0.78, 0.78))
	cancel_btn.pressed.connect(_on_action_picker_cancel)
	vbox.add_child(cancel_btn)

	add_child(popup)
	_action_picker = popup
	# 弹出在屏幕中下方
	popup.popup_centered_clamped(Vector2i(360, 0), 0.85)
	# 调整垂直位置到底部偏上
	await get_tree().process_frame
	if is_instance_valid(popup):
		var vp_size = get_viewport().get_visible_rect().size
		popup.position = Vector2i(int((vp_size.x - popup.size.x) * 0.5), int(vp_size.y - popup.size.y - 90))

## 隐藏行动选择面板
func hide_action_picker() -> void:
	if _action_picker != null and is_instance_valid(_action_picker):
		_action_picker.queue_free()
	_action_picker = null
	_action_picker_callback = Callable()

func _on_action_picker_item(id: String) -> void:
	var cb = _action_picker_callback
	hide_action_picker()
	if cb.is_valid():
		cb.call(id)

func _on_action_picker_cancel() -> void:
	hide_action_picker()

## 设置目标选择提示文本（显示在 TopBar 下方）
func set_targeting_hint(text: String) -> void:
	targeting_hint = text
	# 复用 objective_label 显示提示，或追加到 objective
	# 这里简单地将提示加入战斗日志，便于测试观测
	if text != "":
		add_log(">> " + text)


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
## CODE-P2-02: Update alert display from AlertState
## CH1-060: Now shows distance to next escalation event (turns_until) and
## color-codes the label by severity so players can read urgency at a glance.
func update_alert_display(alert_state: Node) -> void:
	if not _alert_label:
		return
	if not alert_state or not is_instance_valid(alert_state):
		_alert_label.visible = false
		return
	var level_names := ["平静", "可疑", "警戒", "战斗"]
	var level: int = alert_state.get_alert_level()
	var consequence: Dictionary = alert_state.get_consequence()
	var next: Dictionary = alert_state.get_next_consequence()
	var level_name: String = level_names[level] if level >= 0 and level < level_names.size() else "未知"
	var desc: String = String(consequence.get("description", ""))
	var next_desc: String = String(next.get("description", ""))
	var turns_until: int = int(next.get("turns_until", 0))
	# CH1-060: Show turns_until so the player knows how close the next escalation is.
	var next_text: String = next_desc
	if turns_until > 0 and level < 3:
		next_text = "%s（%d 回合后）" % [next_desc, turns_until]
	_alert_label.text = "警报: %s - %s | 下一步: %s" % [level_name, desc, next_text]
	# CH1-060: Color-code by severity: calm=cyan, suspicious=yellow, alert=orange, combat=red.
	match level:
		0:
			_alert_label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0, 0.85))
		1:
			_alert_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		2:
			_alert_label.add_theme_color_override("font_color", Color(0.96, 0.65, 0.30))
		3:
			_alert_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
	_alert_label.visible = true


## CODE-P2-02: Toggle network overlay visibility (G key). Only visualization, never gameplay.
func toggle_network_overlay() -> void:
	_network_overlay_visible = not _network_overlay_visible
	if _network_overlay:
		_network_overlay.visible = _network_overlay_visible


## CODE-P2-02: Set network overlay visibility directly
func set_network_overlay_visible(vis: bool) -> void:
	_network_overlay_visible = vis
	if _network_overlay:
		_network_overlay.visible = vis


## CODE-P2-02: Check if network overlay is visible
func is_network_overlay_visible() -> bool:
	return _network_overlay_visible


## CH1-050: Update the threat summary label with the current public intents.
## summary: { lethal_count, attack_count, move_count, overwatch_count, others, total, top_threats }
## Renders a one-line overview plus up to three top threats with type icons
## and a stale marker when the information is outdated.
func update_threat_summary(summary: Dictionary) -> void:
	if not _threat_label:
		return
	var total: int = int(summary.get("total", 0))
	if total <= 0:
		_threat_label.text = ""
		_threat_label.visible = false
		return
	var lethal: int = int(summary.get("lethal_count", 0))
	var attacks: int = int(summary.get("attack_count", 0))
	var moves: int = int(summary.get("move_count", 0))
	var overwatch: int = int(summary.get("overwatch_count", 0))
	var others: int = int(summary.get("others", 0))
	var parts: Array[String] = []
	if lethal > 0:
		parts.append("致命 %d" % lethal)
	if attacks > 0:
		parts.append("攻击 %d" % attacks)
	if moves > 0:
		parts.append("移动 %d" % moves)
	if overwatch > 0:
		parts.append("警戒 %d" % overwatch)
	if others > 0:
		parts.append("其他 %d" % others)
	var header := "已知敌方意图：%s" % " | ".join(parts)
	var top_threats: Array = summary.get("top_threats", [])
	var lines := [header]
	for threat in top_threats:
		var itype: String = String(threat.get("type", "wait"))
		var is_stale: bool = bool(threat.get("stale", false))
		var is_lethal: bool = bool(threat.get("lethal", false))
		var tag := itype
		if is_lethal:
			tag = "致命攻击"
		elif itype == "attack":
			tag = "攻击"
		elif itype in ["move", "move_to_cover"]:
			tag = "移动"
		elif itype == "overwatch":
			tag = "警戒"
		var suffix := ""
		if is_stale:
			suffix = "（已过期）"
		lines.append("  - %s%s" % [tag, suffix])
	_threat_label.text = "\n".join(lines)
	# Highlight in red when at least one lethal threat is visible.
	if lethal > 0:
		_threat_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
	else:
		_threat_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.55))
	_threat_label.visible = true

