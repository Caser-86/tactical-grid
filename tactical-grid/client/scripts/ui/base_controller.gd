## 基地控制器
## 显示章节任务列表；提供兵营/军械库/商店入口；选择任务后弹出确认对话框
extends Control
class_name BaseController

@onready var chapter_label = $TopBar/ChapterLabel
@onready var credit_label = $TopBar/CreditLabel
@onready var mission_list = $Center/ScrollContainer/MissionList
@onready var operation_title = $Center/OperationTitle
@onready var situation_title = $Center/SituationPanel/Content/SituationTitle
@onready var status_tag = $Center/SituationPanel/Content/StatusTag
@onready var situation_body = $Center/SituationPanel/Content/SituationBody
@onready var threat_label = $Center/SituationPanel/Content/ThreatLabel
@onready var threat_bar = $Center/SituationPanel/Content/ThreatBar
@onready var intel_hint = $Center/SituationPanel/Content/IntelHint
@onready var v2_squad_panel = $Center/SituationPanel/Content/V2SquadPanel
@onready var barracks_btn = $BottomBar/HBox/BarracksBtn
@onready var armory_btn = $BottomBar/HBox/ArmoryBtn
@onready var shop_btn = $BottomBar/HBox/ShopBtn
@onready var back_btn = $BottomBar/HBox/BackBtn

const CharacterPanelScene = preload("res://scenes/character_panel.tscn")
const ShopPanelScene = preload("res://scenes/shop_panel.tscn")
const ErrorDialogScene = preload("res://scenes/error_dialog.tscn")
const V2SquadSelectionScript = preload("res://scripts/v2/mission/v2_squad_selection.gd")
const COLOR_CYAN := Color("#37d7ff")
const COLOR_AMBER := Color("#f3a44a")
const COLOR_MUTED := Color("#8aa2a7")

## 是否正在显示成就弹窗（避免多个弹窗叠加）
var _showing_achievement_popup: bool = false

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.BASE

	barracks_btn.pressed.connect(_on_barracks)
	armory_btn.pressed.connect(_on_armory)
	shop_btn.pressed.connect(_on_shop)
	back_btn.pressed.connect(_on_back)

	if _is_v2_base():
		_configure_v2_base()
		_load_v2_campaign()
		_update_v2_top_bar()
	else:
		_load_campaign()
		_update_top_bar()

	# 监听成就解锁通知
	if not GameManager.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameManager.achievement_unlocked.connect(_on_achievement_unlocked)

	# 处理场景切换前已解锁但尚未展示的成就
	# 使用 call_deferred 确保 Base 场景完全进入树后再弹窗，避免与场景切换冲突
	call_deferred("_drain_pending_achievements")

func _is_v2_base() -> bool:
	return String(GameManager.current_save.get("game_line", "")) == "v2_infiltration"

func _configure_v2_base() -> void:
	chapter_label.text = "第一章 // 渗透行动"
	chapter_label.tooltip_text = "V2 Infiltration · M1 纵向切片"
	credit_label.visible = false
	armory_btn.visible = false
	shop_btn.visible = false
	barracks_btn.text = "队员 / SQUAD"
	back_btn.text = "返回 / MENU"
	operation_title.text = "渗透行动 // 编队准备"
	intel_hint.text = "选择任务后进入战术地图"
	v2_squad_panel.visible = true

func _load_v2_campaign() -> void:
	for child in mission_list.get_children():
		child.queue_free()
	var mission_id := String(GameManager.current_save.get("current_mission", "ch1_m1"))
	var repository: Node = get_node_or_null("/root/V2Data")
	var mission: Dictionary = repository.get_mission(StringName(mission_id)) if repository else {}
	if mission.is_empty():
		_show_error("V2 数据错误", "任务数据不存在：%s" % mission_id)
		return
	var button := Button.new()
	button.text = "%s  ·  %s" % [mission_id.to_upper(), String(mission.get("name", mission_id))]
	button.icon = ArtCatalog.get_texture(&"objective", &"evac")
	button.add_theme_constant_override("icon_max_width", 34)
	button.add_theme_font_size_override("font_size", 17)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(320, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "主目标：%s" % String(mission.get("primary", ""))
	button.pressed.connect(_on_v2_mission_selected.bind(mission_id))
	mission_list.add_child(button)
	_show_v2_mission_brief(mission)

func _show_v2_mission_brief(mission: Dictionary) -> void:
	var save: Dictionary = GameManager.current_save
	var available: Array[String] = V2SquadSelectionScript.get_available_characters(save)
	var selected: Array[String] = _get_v2_selected_squad(mission, save)
	situation_title.text = "%s  //  V2" % String(mission.get("name", "任务"))
	status_tag.text = "● 可部署 · %d 名队员已解锁" % available.size()
	status_tag.modulate = COLOR_CYAN
	threat_label.text = "敌人实体 %d  /  同时活跃上限 %d" % [int(mission.get("enemy_total", 0)), int(mission.get("active_cap", 0))]
	threat_bar.value = clampi(int(mission.get("active_cap", 0)) * 20, 0, 100)
	var names: Array[String] = []
	for character_id in selected:
		var data: Dictionary = _get_v2_character(character_id)
		names.append(String(data.get("name", character_id)))
	situation_body.text = (
		"主目标\n%s\n\n"
		+ "可选目标\n%s\n\n"
		+ "当前编队\n%s\n\n"
		+ "流程\n选择队员 → 进入地图 → 营救 → 撤离"
	) % [
		String(mission.get("primary", "")),
		String(mission.get("optional", "无")),
		"、".join(names) if not names.is_empty() else "尚未选择",
	]
	intel_hint.text = "队员面板可查看身份、能力和模块；V2 不使用商店、技能树或六属性加点。"
	_render_v2_squad_picker(mission, available, selected)

func _get_v2_selected_squad(mission: Dictionary, save: Dictionary) -> Array[String]:
	var saved: Array = save.get("selected_squad", [])
	var validation := V2SquadSelectionScript.validate_squad_for_save(mission, saved, save)
	if bool(validation.get("valid", false)):
		return saved.duplicate()
	return V2SquadSelectionScript.get_default_squad(mission, save)

func _render_v2_squad_picker(mission: Dictionary, available: Array[String], selected: Array[String]) -> void:
	for child in v2_squad_panel.get_children():
		child.queue_free()
	var header := Label.new()
	header.text = "部署编队  ·  选择 %d/%d" % [selected.size(), int(mission.get("deployment_limit", 1))]
	header.modulate = COLOR_AMBER
	v2_squad_panel.add_child(header)
	for character_id in available:
		if not character_id in mission.get("starting_roster", []):
			continue
		var data := _get_v2_character(character_id)
		var button := Button.new()
		button.text = ("✓ " if character_id in selected else "○ ") + String(data.get("name", character_id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = character_id in selected
		button.custom_minimum_size = Vector2(0, 30)
		button.toggled.connect(_on_v2_squad_toggled.bind(character_id, mission))
		v2_squad_panel.add_child(button)

func _on_v2_squad_toggled(pressed: bool, character_id: String, mission: Dictionary) -> void:
	var selected := _get_v2_selected_squad(mission, GameManager.current_save)
	if pressed and not character_id in selected:
		selected.append(character_id)
	elif not pressed:
		selected.erase(character_id)
	var validation := V2SquadSelectionScript.validate_squad_for_save(mission, selected, GameManager.current_save)
	if not bool(validation.get("valid", false)):
		_show_error("编队不可用", "至少选择一名队员，且不能超过本任务编制。")
		_show_v2_mission_brief(mission)
		return
	GameManager.current_save["selected_squad"] = selected
	GameManager.save_current_v2()
	_show_v2_mission_brief(mission)

func _get_v2_character(character_id: String) -> Dictionary:
	var repository: Node = get_node_or_null("/root/V2Data")
	if repository and repository.has_method("get_character"):
		return repository.get_character(StringName(character_id))
	return {}

func _on_v2_mission_selected(mission_id: String) -> void:
	var mission: Dictionary = {}
	var repository: Node = get_node_or_null("/root/V2Data")
	if repository:
		mission = repository.get_mission(StringName(mission_id))
	var selected := _get_v2_selected_squad(mission, GameManager.current_save)
	var validation := V2SquadSelectionScript.validate_squad_for_save(mission, selected, GameManager.current_save)
	if not bool(validation.get("valid", false)):
		_show_error("编队不可用", "请在队员面板确认可用角色后再部署。")
		return
	GameManager.current_save["selected_squad"] = selected
	GameManager.save_current_v2()
	GameManager.go_to_battle(mission_id)

func _load_campaign() -> void:
	var progress = GameManager.current_save.get("campaign_progress", {})
	var completed = progress.get("completed_missions", [])
	var current_chapter = int(progress.get("current_chapter", 1))
	var tree = CampaignRepository.build_campaign_tree(completed)

	for child in mission_list.get_children():
		child.queue_free()

	var preview_set := false
	# 只显示当前章节的任务，避免一次列出全部 30 关
	for chapter in tree:
		if int(chapter.get("chapter", 0)) != current_chapter:
			continue
		operation_title.text = "%s行动链" % chapter.name

		var mission_number := 0
		for mission in chapter.missions:
			mission_number += 1
			var button = Button.new()
			var status := "LOCKED" if mission.locked else ("CLEARED" if mission.completed else "READY")
			button.text = "%02d   %-7s   %s" % [mission_number, status, mission.name]
			button.icon = _get_mission_icon(mission)
			button.add_theme_constant_override("icon_max_width", 34)
			button.add_theme_font_size_override("font_size", 16)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.disabled = mission.locked
			button.custom_minimum_size = Vector2(320, 54)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = "%s · %s · 威胁 %d/5" % [
				_get_mission_type_text(mission.mission_type),
				_get_size_text(mission.size),
				int(mission.difficulty),
			]
			if mission.get("is_boss", false):
				button.modulate = Color(1.0, 0.62, 0.58)
			if not mission.locked:
				button.pressed.connect(_on_mission_selected.bind(mission.level_id))
			button.mouse_entered.connect(_show_mission_brief.bind(mission))
			button.focus_entered.connect(_show_mission_brief.bind(mission))
			mission_list.add_child(button)
			if not preview_set and not mission.locked:
				_show_mission_brief(mission)
				preview_set = true

func _show_mission_brief(mission: Dictionary) -> void:
	var level_id := String(mission.get("level_id", ""))
	var level := CampaignRepository.get_level(level_id)
	var difficulty := clampi(int(mission.get("difficulty", 1)), 0, 5)
	var rewards: Dictionary = mission.get("rewards", {})
	var first_clear: Dictionary = rewards.get("first_clear", {})

	situation_title.text = String(mission.get("name", level_id))
	threat_label.text = "威胁等级 %d / 5" % difficulty
	threat_bar.value = difficulty * 20

	if mission.get("locked", false):
		status_tag.text = "● 链路锁定"
		status_tag.modulate = COLOR_MUTED
		intel_hint.text = "完成前序行动后解锁"
	elif mission.get("completed", false):
		status_tag.text = "● 已完成 · 可重复部署"
		status_tag.modulate = COLOR_CYAN
		intel_hint.text = "点击行动节点可再次部署"
	else:
		status_tag.text = "● 可部署"
		status_tag.modulate = COLOR_AMBER
		intel_hint.text = "点击行动节点查看部署确认"

	var reward_text := "%d 信用点 / %d XP" % [
		int(rewards.get("credit", 0)),
		int(rewards.get("exp", 0)),
	]
	if not first_clear.is_empty():
		reward_text += "\n首通 +%d 信用点 / +%d 情报" % [
			int(first_clear.get("credit", 0)),
			int(first_clear.get("intel", 0)),
		]

	situation_body.text = (
		"行动目标\n%s\n\n"
		+ "部署编制\n我方 %d 人  /  敌方约 %d 单位\n\n"
		+ "战区参数\n%s地图  /  %s\n\n"
		+ "行动报酬\n%s"
	) % [
		_get_mission_directive(String(mission.get("mission_type", "extract"))),
		int(level.get("player_units", 0)),
		int(level.get("enemy_count", 0)),
		_get_size_text(String(mission.get("size", "small"))),
		_get_mission_type_text(String(mission.get("mission_type", "extract"))),
		reward_text,
	]

func _get_mission_directive(mission_type: String) -> String:
	match mission_type:
		"extract":
			return "突破封锁并抵达指定撤离坐标。"
		"destroy":
			return "定位并摧毁敌方关键设施。"
		"assassinate":
			return "击破高威胁指挥单位。"
		"escort":
			return "护送关键目标穿越交战区。"
		"steal_data":
			return "接入终端，带回完整情报数据。"
		_:
			return "执行战术网络下达的行动目标。"

func _get_mission_icon(mission: Dictionary) -> Texture2D:
	var mission_type := String(mission.get("mission_type", "extract"))
	match mission_type:
		"extract":
			return ArtCatalog.get_texture(&"objective", &"evac")
		"destroy":
			return ArtCatalog.get_texture(&"objective", &"reactor_target")
		"steal_data":
			return ArtCatalog.get_texture(&"objective", &"terminal")
		"escort":
			return ArtCatalog.get_texture(&"unit", &"medic")
		"assassinate":
			return ArtCatalog.get_texture(&"unit", &"boss_data_sentinel")
	return ArtCatalog.get_texture(&"objective", &"terminal")

func _update_top_bar() -> void:
	var progress = GameManager.current_save.get("campaign_progress", {})
	var chapter = progress.get("current_chapter", 1)
	chapter_label.text = CampaignRepository.get_chapter_name(chapter)

	var resources = GameManager.current_save.get("resources", {})
	var credit = resources.get("credit", 0)
	var intel = resources.get("intel", 0)
	credit_label.text = "信用点 %d | 情报 %d" % [credit, intel]

func _update_v2_top_bar() -> void:
	chapter_label.text = "第一章 // 渗透行动"
	var available: Array[String] = V2SquadSelectionScript.get_available_characters(GameManager.current_save)
	credit_label.visible = false
	status_tag.text = "● %d 名队员可用" % available.size()

## 选择任务后弹出确认对话框
func _on_mission_selected(level_id: String) -> void:
	if _is_v2_base():
		_on_v2_mission_selected(level_id)
		return
	var level = CampaignRepository.get_level(level_id)
	if level.is_empty():
		_show_error("错误", "关卡数据不存在: " + level_id)
		return

	var mission_name = level.get("name", level_id)
	var mission_type = level.get("mission_type", "extract")
	var size = level.get("size", "small")
	var player_units = int(level.get("player_units", 3))
	var enemy_count = int(level.get("enemy_count", 5))
	var rewards = level.get("rewards", {})
	var is_boss = level.get("is_boss", false)

	var type_text = _get_mission_type_text(mission_type)
	var size_text = _get_size_text(size)

	var summary = "%s%s\n" % ["[Boss战] " if is_boss else "", mission_name]
	summary += "类型：%s | 地图：%s\n" % [type_text, size_text]
	summary += "我方单位：%d | 敌方数量：%d\n" % [player_units, enemy_count]
	summary += "奖励：%d 信用点 / %d XP" % [rewards.get("credit", 0), rewards.get("exp", 0)]
	var first_clear = rewards.get("first_clear", {})
	if not first_clear.is_empty():
		summary += "\n首通奖励：%d 信用点 / %d 情报" % [first_clear.get("credit", 0), first_clear.get("intel", 0)]

	var dialog = ErrorDialogScene.instantiate()
	dialog.setup("任务确认", summary, Callable(self, "_confirm_start_mission").bind(level_id))
	add_child(dialog)

func _confirm_start_mission(level_id: String) -> void:
	GameManager.go_to_battle(level_id)

func _get_mission_type_text(mission_type: String) -> String:
	match mission_type:
		"extract": return "撤离"
		"destroy": return "摧毁"
		"assassinate": return "刺杀"
		"escort": return "护送"
		"steal_data": return "窃取数据"
		_: return mission_type

func _get_size_text(size: String) -> String:
	match size:
		"small": return "小型"
		"medium": return "中型"
		"large": return "大型"
		_: return size

func _on_barracks() -> void:
	_open_character_panel(0)

func _on_armory() -> void:
	# 军械库也是角色面板，默认显示装备tab
	_open_character_panel(0)

func _on_shop() -> void:
	# 检查是否已有商店面板打开
	for child in get_children():
		if child is ShopPanel:
			child.queue_free()
			return
	var panel = ShopPanelScene.instantiate()
	add_child(panel)
	panel.open_shop("general")

func _open_character_panel(char_index: int) -> void:
	# 检查是否已有角色面板打开
	for child in get_children():
		if child is CharacterPanel:
			child.queue_free()
			return
	var panel = CharacterPanelScene.instantiate()
	add_child(panel)
	panel.open_panel(char_index)

func _on_back() -> void:
	if _is_v2_base():
		GameManager.save_current_v2()
	else:
		GameManager.save_current()
	GameManager.go_to_main_menu()

func _show_error(title: String, message: String) -> void:
	var dialog = ErrorDialogScene.instantiate()
	dialog.setup(title, message)
	add_child(dialog)

func _on_achievement_unlocked(_achievement_id: String, _ach_data: Dictionary) -> void:
	# 信号触发时不立即弹窗，而是启动队列消费，避免与 pending 队列重复弹出
	# 若当前已有成就弹窗在显示，等其关闭后由 tree_exited 回调继续消费
	_drain_pending_achievements()

## 处理场景切换前累积的待展示成就通知
## 逐个弹出，由对话框关闭后的回调继续触发下一个
func _drain_pending_achievements() -> void:
	# 已有弹窗在显示时，等其关闭后由 tree_exited 回调继续消费
	if _showing_achievement_popup:
		return
	if not GameManager.has_pending_achievements():
		return
	var ach = GameManager.pop_pending_achievement()
	if ach.is_empty():
		return
	_show_achievement_popup(ach.get("id", ""), {
		"name": ach.get("name", ""),
		"description": ach.get("description", ""),
	})

## 弹出成就解锁通知；关闭后继续处理队列中下一个
func _show_achievement_popup(achievement_id: String, ach_data: Dictionary) -> void:
	var ach_name = ach_data.get("name", achievement_id)
	var desc = ach_data.get("description", "")
	var dialog = ErrorDialogScene.instantiate()
	dialog.setup("🏆 成就解锁", "%s\n%s" % [ach_name, desc])
	_showing_achievement_popup = true
	add_child(dialog)
	# 对话框关闭(queue_free)后：清标志并继续展示队列中的下一个
	dialog.tree_exited.connect(_on_achievement_popup_closed)

func _on_achievement_popup_closed() -> void:
	_showing_achievement_popup = false
	# tree_exited 期间父节点仍在更新 children；延迟到下一帧再挂载后续通知。
	call_deferred("_drain_pending_achievements")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 检查是否有面板打开
		for child in get_children():
			if child is CharacterPanel or child is ShopPanel:
				return  # 面板自己处理 ESC
		# 没有面板打开，弹出暂停菜单
		var pause = preload("res://scenes/pause_menu.tscn").instantiate()
		add_child(pause)
