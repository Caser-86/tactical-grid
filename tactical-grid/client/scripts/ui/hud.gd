## HUD 控制器
## 管理战斗界面的所有 UI 元素
extends CanvasLayer
class_name HUD

@onready var turn_label = $TopBar/TurnLabel
@onready var phase_label = $TopBar/PhaseLabel
@onready var objective_label = $TopBar/ObjectiveLabel
@onready var unit_info_label = $RightPanel/UnitInfoLabel
@onready var action_budget_label = $RightPanel/V2ActionBudgetLabel
@onready var action_hint_label = $RightPanel/V2ActionHintLabel
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
## V2 使用统一名称暴露当前操作提示，避免测试和其他表现层依赖内部节点名。
var context_label: Label = null
var _pending_v2_snapshot: Dictionary = {}
var _v2_hud_active := false
## V2: 当前攻击预览卡片文本。单独保留，便于输入测试和结果回显使用同一份数据。
var _attack_preview_text: String = ""
## CODE-P2-02: 警报显示标签和网络覆盖层
var _alert_label: Label = null
var _network_overlay: Control = null
var _network_overlay_visible: bool = false
## CH1-050: 敌方意图威胁摘要标签，显示在警报标签下方。
var _threat_label: Label = null
var _v2_mission_card: Panel = null
var _v2_mission_card_label: Label = null
var _v2_camera_return_button: Button = null

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
	context_label = _context_prompt
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
	if not _pending_v2_snapshot.is_empty():
		render_v2_snapshot(_pending_v2_snapshot)

func _ensure_v2_mission_card() -> Label:
	if _v2_mission_card_label != null and is_instance_valid(_v2_mission_card_label):
		return _v2_mission_card_label
	_v2_mission_card = Panel.new()
	_v2_mission_card.name = "V2MissionCard"
	_v2_mission_card.position = Vector2(12, TOP_BAR_HEIGHT + 8)
	_v2_mission_card.size = Vector2(430, 128)
	_v2_mission_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_v2_mission_card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.055, 0.075, 0.94), Color(1.0, 0.72, 0.18, 0.82)))
	_v2_mission_card_label = Label.new()
	_v2_mission_card_label.name = "MissionCardText"
	_v2_mission_card_label.position = Vector2(12, 8)
	_v2_mission_card_label.size = Vector2(406, 112)
	_v2_mission_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_v2_mission_card_label.add_theme_font_size_override("font_size", 13)
	_v2_mission_card_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96, 0.98))
	_v2_mission_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_v2_mission_card.add_child(_v2_mission_card_label)
	add_child(_v2_mission_card)
	return _v2_mission_card_label

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
	if unit_info_label == null:
		return
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
	# 默认交互直接点击地图；保留移动/攻击回调，但不占用主动作栏。
	move_button.visible = false
	attack_button.visible = false
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
				_context_prompt.visible = true
				_context_prompt.text = "蓝色高亮格 = 可移动；红色区域/敌人 = 可攻击"
		ContextState.MOVE_PREVIEW:
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "左键点击蓝色高亮格移动，右键取消"
		ContextState.ATTACK_PREVIEW:
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "悬停敌人查看伤害，点击一次攻击，右键取消"
		ContextState.FACILITY_PREVIEW:
			if _context_prompt:
				_context_prompt.visible = true
				_context_prompt.text = "点击设施节点交互，右键取消"

## 设置一次性的上下文提示，例如攻击预览或结算结果。
func set_context_prompt(text: String) -> void:
	if _context_prompt:
		_context_prompt.text = text
		_context_prompt.visible = true

func set_v2_camera_return_visible(visible: bool) -> void:
	var button := _ensure_v2_camera_return_button()
	if button != null:
		button.visible = visible

func _ensure_v2_camera_return_button() -> Button:
	if _v2_camera_return_button != null and is_instance_valid(_v2_camera_return_button):
		return _v2_camera_return_button
	_v2_camera_return_button = Button.new()
	_v2_camera_return_button.name = "V2CameraReturnButton"
	_v2_camera_return_button.text = "返回队员 [F]"
	_v2_camera_return_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_v2_camera_return_button.offset_left = -190.0
	_v2_camera_return_button.offset_top = TOP_BAR_HEIGHT + 10.0
	_v2_camera_return_button.offset_right = -14.0
	_v2_camera_return_button.offset_bottom = TOP_BAR_HEIGHT + 42.0
	_v2_camera_return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_v2_camera_return_button.visible = false
	_v2_camera_return_button.pressed.connect(_on_v2_camera_return_pressed)
	_style_button(_v2_camera_return_button)
	add_child(_v2_camera_return_button)
	return _v2_camera_return_button

func _on_v2_camera_return_pressed() -> void:
	if _battle_controller != null and _battle_controller.has_method("return_to_v2_camera_player"):
		_battle_controller.call("return_to_v2_camera_player")

## V2: 以一个快照驱动整块战斗 HUD，保证目标、预算和下一步后果不会互相覆盖。
## 该入口只改变 V2 显示状态，V1 仍使用原有的 update_* 方法。
func render_v2_snapshot(snapshot: Dictionary) -> void:
	if not is_node_ready() or context_label == null:
		_pending_v2_snapshot = snapshot.duplicate(true)
		return
	_v2_hud_active = true
	_pending_v2_snapshot.clear()
	if _is_canonical_v2_snapshot(snapshot):
		_render_canonical_v2_snapshot(snapshot)
		return

	var objective := String(snapshot.get("primary_objective", ""))
	if objective != "":
		objective_label.text = objective

	var phase := String(snapshot.get("phase", "玩家回合"))
	var state := String(snapshot.get("state", "free_select"))
	phase_label.text = "%s · %s" % [phase, _v2_state_label(state)] if state != "" else phase
	phase_label.modulate = Color.CYAN if phase.contains("玩家") else Color.RED if phase.contains("敌人") else Color.GOLD

	var alert := String(snapshot.get("alert", ""))
	var next_consequence := String(snapshot.get("next_consequence", ""))
	var visibility_summary: Dictionary = snapshot.get("visibility_summary", {})
	if _alert_label:
		var alert_text := "警戒：%s" % alert if alert != "" else ""
		if next_consequence != "":
			alert_text += " | 下一步：%s" % next_consequence
		var newly_observed_cells := int(visibility_summary.get("newly_observed_cells", 0))
		var newly_revealed_enemies := int(visibility_summary.get("newly_revealed_enemies", 0))
		if newly_observed_cells > 0:
			alert_text += " | 视野 +%d格" % newly_observed_cells
		if newly_revealed_enemies > 0:
			alert_text += " | 发现敌人 %d" % newly_revealed_enemies
		_alert_label.text = alert_text
		_alert_label.visible = alert_text != ""

	var selected: Node = snapshot.get("selected", null) as Node
	var selected_valid := selected != null and is_instance_valid(selected) and bool(selected.get("is_alive"))
	$RightPanel.visible = selected_valid
	if selected_valid:
		update_unit_info(selected)
	else:
		unit_info_label.text = ""

	# V2 直接地图交互不显示常驻移动/攻击/技能按钮，玩家从地图高亮和提示中行动。
	set_action_buttons_visible(false)
	var budget: Dictionary = snapshot.get("action_budget", {})
	if action_budget_label:
		action_budget_label.visible = selected_valid
		if selected_valid:
			action_budget_label.text = "行动预算\n移动 %s   行动 %s" % [
				"可用" if bool(budget.get("move", false)) else "已用",
				"可用" if bool(budget.get("action", false)) else "已用",
			]
	var ability := String(snapshot.get("ability", ""))
	var interaction := String(snapshot.get("interaction", ""))
	var side_hint := ability if ability != "" else interaction
	if side_hint == "":
		side_hint = "蓝格移动 · 红色敌人攻击\n右键取消 · 中键拖动地图"
	if action_hint_label:
		action_hint_label.text = side_hint
		action_hint_label.visible = selected_valid

	var prompt := String(snapshot.get("context_prompt", ""))
	var attack_preview: Variant = snapshot.get("attack_preview", "")
	if prompt == "" and attack_preview is String:
		prompt = String(attack_preview)
	context_label.text = prompt if prompt != "" else "选择一个单位开始行动"
	context_label.visible = true

	# Keep the mission's next required step visible even when a contextual
	# action prompt changes. V2 supplies a short guide; V1 keeps its original
	# control summary untouched.
	var mission_guide := String(snapshot.get("mission_guide", ""))
	var shortcut_hint := get_node_or_null("BottomBar/ShortcutHint") as Label
	if shortcut_hint != null and mission_guide != "":
		shortcut_hint.text = "%s\n右键取消预览 · Esc取消选择 · 中键拖动地图 · Home回到角色\nSpace结束回合" % mission_guide
	var v2_control_guide := get_node_or_null("BottomBar/V2DirectControlGuide") as Label
	if v2_control_guide != null and mission_guide != "":
		v2_control_guide.text = "%s\n左键队员显示范围 · 蓝格移动 · 红色敌人攻击 · 右键取消预览 · Esc取消选择\n中键拖动地图 · Home回到角色 · Space结束回合" % mission_guide

func _is_canonical_v2_snapshot(snapshot: Dictionary) -> bool:
	return snapshot.has("mission_id") or snapshot.has("objective_text") or snapshot.has("step_id") or snapshot.has("guide_text") or snapshot.has("route_hint") or snapshot.has("hazard_warning") or snapshot.has("checkpoint_id") or snapshot.has("status") or snapshot.has("outcome_text") or snapshot.has("ordinary_controls")

func _render_canonical_v2_snapshot(snapshot: Dictionary) -> void:
	var objective := String(snapshot.get("objective_text", "")).strip_edges()
	var guide := String(snapshot.get("guide_text", "")).strip_edges()
	var route_hint := String(snapshot.get("route_hint", "")).strip_edges()
	var hazard_warning := String(snapshot.get("hazard_warning", "")).strip_edges()
	var checkpoint_id := String(snapshot.get("checkpoint_id", "")).strip_edges()
	var ordinary_controls := String(snapshot.get("ordinary_controls", "")).strip_edges()
	if ordinary_controls.is_empty():
		ordinary_controls = "蓝格移动 · 红色敌人攻击 · 右键取消预览 · Esc取消选择 · Space结束回合"
	var mission_card := _ensure_v2_mission_card()
	mission_card.text = "当前任务\n%s\n%s\n%s\n操作：左键队员看范围；左键蓝格移动；红色敌人攻击；Space结束回合" % [
		objective,
		route_hint if not route_hint.is_empty() else "目标地点：地图上的黄色“下一步”标记",
		_v2_completion_hint(objective),
	]
	_v2_mission_card.visible = true

	var step_count := maxi(0, int(snapshot.get("step_count", 0)))
	var step_index := maxi(0, int(snapshot.get("step_index", 0)))
	var progress := "%d/%d" % [mini(step_index + 1, step_count), step_count] if step_count > 0 else ""
	var status := String(snapshot.get("status", "")).to_lower()
	var outcome := String(snapshot.get("outcome_text", "")).strip_edges()
	var alert_name := String(snapshot.get("alert", "")).strip_edges()
	if status == "failure" and outcome.is_empty():
		outcome = "任务失败"
	elif status == "victory" and outcome.is_empty():
		outcome = "任务完成"

	if not outcome.is_empty() and status in ["failure", "victory"]:
		objective_label.text = outcome
	else:
		objective_label.text = _join_v2_parts([progress, objective], " · ")
		if objective_label.text.is_empty():
			objective_label.text = "等待任务状态"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.clip_text = true
	objective_label.max_lines_visible = 2
	objective_label.add_theme_font_size_override("font_size", _v2_font_size_for(objective_label.text, 18))

	var has_turn := snapshot.has("turn") or snapshot.has("current_turn")
	var turn_value := int(snapshot.get("turn", snapshot.get("current_turn", 0)))
	# Never retain a restored turn when a later canonical snapshot omits it.
	turn_label.text = "回合 %d" % turn_value if has_turn and turn_value > 0 else "回合 -"
	var phase := String(snapshot.get("phase", snapshot.get("current_phase", ""))).strip_edges()
	var state := String(snapshot.get("state", "")).strip_edges()
	phase_label.text = "%s · %s" % [phase, _v2_state_label(state)] if not phase.is_empty() and not state.is_empty() else phase
	phase_label.modulate = Color.CYAN if phase.contains("玩家") else Color.RED if phase.contains("敌人") else Color.GOLD if phase.contains("结束") else Color.WHITE

	# The alert line is a non-modal priority channel. Lower-priority details
	# remain visible in the bounded bottom guidance label below.
	var priority_text := ""
	if not outcome.is_empty() and status in ["failure", "victory"]:
		priority_text = outcome
	elif not alert_name.is_empty() and alert_name not in ["平静", "潜伏"]:
		priority_text = "警戒：%s · %s" % [alert_name, objective] if not objective.is_empty() else "警戒：%s" % alert_name
	elif not objective.is_empty():
		priority_text = objective
	elif not hazard_warning.is_empty():
		priority_text = hazard_warning
	elif not route_hint.is_empty():
		priority_text = route_hint
	else:
		priority_text = ordinary_controls
	if _alert_label:
		_alert_label.text = priority_text
		_alert_label.visible = not priority_text.is_empty()
		_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_alert_label.clip_text = true
		_alert_label.max_lines_visible = 2
		_alert_label.add_theme_font_size_override("font_size", _v2_font_size_for(priority_text, 12))

	var selected: Node = snapshot.get("selected", null) as Node
	var selected_valid := selected != null and is_instance_valid(selected) and bool(selected.get("is_alive"))
	$RightPanel.visible = selected_valid
	if selected_valid:
		update_unit_info(selected)
	else:
		unit_info_label.text = ""
	set_action_buttons_visible(false)
	var budget: Dictionary = snapshot.get("action_budget", {})
	if action_budget_label:
		action_budget_label.visible = selected_valid
		if selected_valid:
			action_budget_label.text = "行动预算\n移动 %s   行动 %s" % [
				"可用" if bool(budget.get("move", false)) else "已用",
				"可用" if bool(budget.get("action", false)) else "已用",
			]
	var prompt := String(snapshot.get("context_prompt", "")).strip_edges()
	if prompt.is_empty():
		prompt = ordinary_controls
	context_label.text = prompt
	context_label.visible = not prompt.is_empty()
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label.clip_text = true
	context_label.max_lines_visible = 2
	context_label.position = Vector2(-260, -104)
	context_label.size = Vector2(520, 42)
	context_label.add_theme_font_size_override("font_size", _v2_font_size_for(prompt, 14))

	var guidance_lines: Array[String] = []
	if not guide.is_empty():
		guidance_lines.append("行动：%s" % guide)
	if not route_hint.is_empty():
		guidance_lines.append("路线：%s" % route_hint)
	if not hazard_warning.is_empty():
		guidance_lines.append("危险：%s" % hazard_warning)
	if not checkpoint_id.is_empty():
		guidance_lines.append("检查点：%s" % checkpoint_id)
	guidance_lines.append("操作：%s" % ordinary_controls)
	var v2_control_guide := _ensure_v2_control_guide()
	if v2_control_guide:
		v2_control_guide.text = "\n".join(guidance_lines)
		v2_control_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v2_control_guide.clip_text = true
		v2_control_guide.max_lines_visible = 4
		v2_control_guide.add_theme_font_size_override("font_size", _v2_font_size_for(v2_control_guide.text, 12))

func _ensure_v2_control_guide() -> Label:
	var guide := get_node_or_null("BottomBar/V2DirectControlGuide") as Label
	if guide != null:
		return guide
	var bottom_bar := get_node_or_null("BottomBar") as Control
	if bottom_bar == null:
		return null
	guide = Label.new()
	guide.name = "V2DirectControlGuide"
	guide.position = Vector2(14, 6)
	guide.size = Vector2(510, 54)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(guide)
	return guide

func _join_v2_parts(parts: Array, separator: String) -> String:
	var non_empty: Array[String] = []
	for raw_part in parts:
		var part := String(raw_part).strip_edges()
		if not part.is_empty():
			non_empty.append(part)
	return separator.join(non_empty)

func _v2_font_size_for(text: String, default_size: int) -> int:
	if text.length() > 100:
		return maxi(10, default_size - 4)
	if text.length() > 52:
		return maxi(11, default_size - 2)
	return default_size

func _v2_state_label(state: String) -> String:
	match state:
		"free_select":
			return "选择单位"
		"unit_selected":
			return "已选中"
		"attack_locked":
			return "攻击已锁定"
		"ability_targeting":
			return "选择技能目标"
		"interaction_menu":
			return "选择设施操作"
		"enemy_turn":
			return "敌人行动"
		"paused":
			return "已暂停"
		_:
			return state

func _v2_completion_hint(objective: String) -> String:
	if objective.contains("路线分叉"):
		return "完成：走到黄色分叉标记，随后选择一条路线"
	if objective.contains("选择推进"):
		return "完成：点击任意一条路线按钮"
	if objective.contains("吊桥"):
		return "完成：靠近吊机后点击设施并选择放下吊桥"
	if objective.contains("营救"):
		return "完成：靠近青色标记后点击营救"
	if objective.contains("撤离"):
		return "完成：所有当前存活队员进入绿色撤离区（营救后会增加可操作队员）"
	return "完成：按地图黄色标记和顶部目标推进"

## V2: 显示确定性攻击预览，不展示旧版随机命中率字段。
func show_attack_preview(preview: Dictionary, target: Unit, locked: bool = true) -> void:
	if target == null:
		return
	var hp_before := int(preview.get("hp_before", target.current_hp))
	var hp_after := int(preview.get("hp_after", target.current_hp))
	var shield_before := int(preview.get("shield_before", target.current_shield))
	var shield_after := int(preview.get("shield_after", target.current_shield))
	var damage := int(preview.get("hp_damage", maxi(0, hp_before - hp_after)))
	var mode := "已锁定" if locked else "悬停预览"
	var text := "%s %s：伤害 %d · HP %d → %d" % [mode, target.unit_name, damage, hp_before, hp_after]
	if shield_before != shield_after:
		text += " · 护盾 %d → %d" % [shield_before, shield_after]
	text += " · %s" % ("再次点击确认" if locked else "点击攻击")
	_attack_preview_text = text
	set_context_prompt(text)

func get_attack_preview_text() -> String:
	return _attack_preview_text

func clear_attack_preview() -> void:
	_attack_preview_text = ""

## V2: 将服务层错误转换为玩家可理解的操作反馈。
func show_action_reason(reason: Variant) -> void:
	var text := "无法执行该操作"
	match String(reason):
		"action_unavailable":
			text = "本单位本回合已经攻击过"
		"out_of_range":
			text = "目标超出攻击范围"
		"no_line_of_sight":
			text = "目标被墙体或掩体遮挡"
		"full_cover":
			text = "目标处于完全掩体后，无法从当前位置攻击"
		"stale_preview":
			text = "目标状态已变化，请重新选择目标"
		"same_team":
			text = "不能攻击友方单位"
		"target_dead":
			text = "目标已经失去战斗能力"
		"move_unavailable":
			text = "本单位本回合已经移动过"
		"blocked":
			text = "目标格不可通行"
		"move_too_far":
			text = "目标格超出移动范围"
		"rescue_locked_until_objective":
			text = "请先完成顶部任务提示中的前置目标"
		"required_flags_unsatisfied":
			text = "请先完成营救前置目标"
		"rescue_too_far":
			text = "请站在营救标记相邻格，再点击营救标记"
		"rescue_unavailable":
			text = "当前营救目标不可用"
		"already_rescued":
			text = "该队员已经加入小队"
	set_context_prompt(text)

func get_context_prompt_text() -> String:
	return _context_prompt.text if _context_prompt else ""

## 在窗口尺寸变化时更新 HUD 安全区域，避免裁切或大面积空白
func apply_viewport_layout(viewport_size: Vector2i) -> void:
	# 目标栏占据回合信息与暂停按钮之间的空间，Boss 状态在窄屏也优先可读。
	objective_label.offset_left = minf(370.0, float(viewport_size.x) * 0.36)
	objective_label.offset_right = -100.0

	# RightPanel 固定宽度 250，贴右边缘
	var right_panel = $RightPanel
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
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

## V2: 设施交互复用同一张选择卡，但把结果、持续时间和警戒影响写进描述。
func show_interaction_actions(facility_name: String, actions: Array, on_selected: Callable) -> void:
	var items: Array = []
	for action in actions:
		var duration := int(action.get("duration_turns", -1))
		var duration_text := "持续%d回合" % duration if duration > 0 else "持续到任务结束"
		var alert_text := "会提高警戒" if bool(action.get("raises_alert", false)) else "不提高警戒"
		items.append({
			"id": String(action.get("id", "")),
			"name": "%s（1行动）" % String(action.get("label", "操作")),
			"description": "结果：%s · %s · %s" % [String(action.get("consequence", "")), duration_text, alert_text],
			"disabled": not bool(action.get("enabled", false)),
			"disabled_reason": String(action.get("reason", "不可用")),
		})
	show_action_picker("交互：%s" % facility_name, items, on_selected)

## 隐藏行动选择面板
func hide_action_picker() -> void:
	if _action_picker != null and is_instance_valid(_action_picker):
		# Hide immediately before queue_free so a just-completed facility click
		# cannot leave a one-frame modal window intercepting the next map click.
		_action_picker.hide()
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

