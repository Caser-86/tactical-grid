## 基地控制器
## 显示章节任务列表；提供兵营/军械库/商店入口；选择任务后弹出确认对话框
extends Control
class_name BaseController

@onready var chapter_label = $TopBar/ChapterLabel
@onready var credit_label = $TopBar/CreditLabel
@onready var mission_list = $Center/ScrollContainer/MissionList
@onready var barracks_btn = $BottomBar/HBox/BarracksBtn
@onready var armory_btn = $BottomBar/HBox/ArmoryBtn
@onready var shop_btn = $BottomBar/HBox/ShopBtn
@onready var back_btn = $BottomBar/HBox/BackBtn

const CharacterPanelScene = preload("res://scenes/character_panel.tscn")
const ShopPanelScene = preload("res://scenes/shop_panel.tscn")
const ErrorDialogScene = preload("res://scenes/error_dialog.tscn")

## 是否正在显示成就弹窗（避免多个弹窗叠加）
var _showing_achievement_popup: bool = false

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.BASE

	barracks_btn.pressed.connect(_on_barracks)
	armory_btn.pressed.connect(_on_armory)
	shop_btn.pressed.connect(_on_shop)
	back_btn.pressed.connect(_on_back)

	_load_campaign()
	_update_top_bar()

	# 监听成就解锁通知
	if not GameManager.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameManager.achievement_unlocked.connect(_on_achievement_unlocked)

	# 处理场景切换前已解锁但尚未展示的成就
	# 使用 call_deferred 确保 Base 场景完全进入树后再弹窗，避免与场景切换冲突
	call_deferred("_drain_pending_achievements")

func _load_campaign() -> void:
	var progress = GameManager.current_save.get("campaign_progress", {})
	var completed = progress.get("completed_missions", [])
	var tree = CampaignRepository.build_campaign_tree(completed)

	for child in mission_list.get_children():
		child.queue_free()

	for chapter in tree:
		var chapter_label_node = Label.new()
		chapter_label_node.text = "%s" % chapter.name
		chapter_label_node.add_theme_font_size_override("font_size", 22)
		chapter_label_node.modulate = Color(1.0, 0.85, 0.4)
		mission_list.add_child(chapter_label_node)

		for mission in chapter.missions:
			var button = Button.new()
			button.text = "%s%s" % [
				"🔒 " if mission.locked else ("✓ " if mission.completed else ""),
				mission.name
			]
			button.disabled = mission.locked
			button.custom_minimum_size = Vector2(360, 40)
			if mission.get("is_boss", false):
				button.modulate = Color(1.0, 0.5, 0.5)
			if not mission.locked:
				button.pressed.connect(_on_mission_selected.bind(mission.level_id))
			mission_list.add_child(button)

func _update_top_bar() -> void:
	var progress = GameManager.current_save.get("campaign_progress", {})
	var chapter = progress.get("current_chapter", 1)
	chapter_label.text = CampaignRepository.get_chapter_name(chapter)

	var resources = GameManager.current_save.get("resources", {})
	var credit = resources.get("credit", 0)
	var intel = resources.get("intel", 0)
	credit_label.text = "💰 %d | 情报 %d" % [credit, intel]

## 选择任务后弹出确认对话框
func _on_mission_selected(level_id: String) -> void:
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
	summary += "奖励：%d 💰 / %d XP" % [rewards.get("credit", 0), rewards.get("exp", 0)]
	var first_clear = rewards.get("first_clear", {})
	if not first_clear.is_empty():
		summary += "\n首通奖励：%d 💰 / %d 情报" % [first_clear.get("credit", 0), first_clear.get("intel", 0)]

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
	_drain_pending_achievements()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 检查是否有面板打开
		for child in get_children():
			if child is CharacterPanel or child is ShopPanel:
				return  # 面板自己处理 ESC
		# 没有面板打开，弹出暂停菜单
		var pause = preload("res://scenes/pause_menu.tscn").instantiate()
		add_child(pause)
