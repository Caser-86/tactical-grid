## 第一章教程提示系统
## 显示可跳过、可持久化的教程提示；已读状态存于 campaign_progress.story_flags
## 未知 flag 直接回调不阻断，保证无头测试与未来扩展不卡流程
extends Control
class_name TutorialHint

signal hint_closed(flag: String)

## 第一章教程文案表（flag -> 提示文本）
## CH1-080: M1 只教学选择/移动/攻击/观察/接管/结束回合六项，其余 flag 供 M2-M6 复用
const HINT_COPY := {
	"teach_selection": "左键点击队员选中。蓝色格是可移动位置，红色区域/敌人是攻击范围；右键点击队员直接显示移动范围，Tab 可切换队员。",
	"teach_movement": "右键点击队员直接显示移动范围，再点蓝色高亮格移动。每回合的移动会消耗移动点数。",
	"teach_attack": "直接点击红色敌人查看命中率和预计伤害，再次点击确认攻击。右键可取消。",
	"teach_observe": "结束回合前，观察敌方意图箭头：红色为攻击，虚线为移动，三角为警戒，感叹号为致命。点击敌方单位可查看详情。",
	"teach_network_takeover": "按 G 查看网络层。选中队员后点【接管】消耗 1AP：相机揭示区域，门改变路线，炮塔翻转阵营。",
	"teach_end_turn": "完成本回合操作后，按 Space 结束回合，敌人开始行动。",
	"teach_cover": "站在掩体后方可降低被命中率。森林、墙体和高地都能提供掩护。",
	"teach_evac": "完成目标后，所有存活单位需到达撤离点撤离。回合数越少评级越高。",
	"teach_highground": "高地提供命中与视野加成，占据高处获得战术优势。",
	"teach_destructible": "部分掩体可被破坏。破坏后失去掩护效果，可开辟新路线。",
	"teach_resource": "情报是关键资源，首通奖励提供更多情报，用于解锁装备与角色。",
	"teach_overwatch": "守望模式消耗 AP，在敌人移动进入射程时触发反应射击。",
	"teach_interaction": "点击终端等交互对象激活目标。潜入任务需要激活终端并完成上传。",
	"teach_escort": "护送 VIP 到撤离点。VIP 阵亡则任务失败，注意保护。",
	"teach_skills": "技能消耗 AP，提供强力战术选项。不同职业有不同技能树。",
	"teach_items": "物品如医疗包可在战斗中使用，不消耗 AP，注意补给。",
	"teach_camera": "战场大于屏幕。按住鼠标中键拖动画面，滚轮缩放，WASD 或方向键平移；Tab 查看全图，Home 返回当前单位。",
	"teach_upload_hold": "终端上传需要连续控制 2 个敌方回合。至少一名队员留在终端一格范围内，否则上传暂停。",
	"teach_network_scan": "按 G 键查看战术网络覆盖层。敌方控制的节点以红色显示，可操作的节点会高亮。",
	"teach_network_disable": "禁用设施消耗 1AP，使其暂时失效但不改变归属。适合安静通过。",
	"teach_network_overload": "过载设施消耗 1AP，永久损坏但产生强力效果。会触发警报升级。",
}

@onready var _text_label: Label = $Panel/TextLabel
@onready var _continue_button: Button = $Panel/Buttons/ContinueButton
@onready var _skip_button: Button = $Panel/Buttons/SkipButton
@onready var _background: ColorRect = $Background
@onready var _modal_panel: Panel = $Panel
@onready var _context_panel: Panel = $ContextPanel
@onready var _context_label: Label = $ContextPanel/ContextTextLabel

var _flag: String = ""
var _on_closed: Callable = Callable()
var _on_context_skip: Callable = Callable()
var _skip_remaining: bool = false
var _context_skip_button: Button = null

## 获取教程文案；未知 flag 返回空字符串
static func get_hint_copy(flag: String) -> String:
	return HINT_COPY.get(flag, "")

## 该教程 flag 是否已读（持久化于 story_flags）
static func is_known(flag: String) -> bool:
	return bool(GameManager.get_story_flag("tutorial_" + flag, false))

## 标记教程 flag 为已读并立即保存
static func mark_known(flag: String) -> void:
	GameManager.set_story_flag("tutorial_" + flag, true)

## 跳过按钮是否请求跳过剩余教程
func is_skip_requested() -> bool:
	return _skip_remaining

## 显示教程提示；未知 flag 或已读则直接回调，不显示 UI（不阻断无头测试）
func show_hint(flag: String, on_closed: Callable = Callable()) -> void:
	_flag = flag
	_on_closed = on_closed
	_on_context_skip = Callable()
	if _context_skip_button:
		_context_skip_button.visible = false
	# 未知 flag 或已读：直接回调，不显示 UI
	if get_hint_copy(flag) == "" or is_known(flag):
		_close()
		return
	_text_label.text = get_hint_copy(flag)
	# CH1-030: modal 模式显示遮罩与弹窗，隐藏上下文面板
	_background.visible = true
	_modal_panel.visible = true
	_context_panel.visible = false
	show()

## CH1-030: 显示非阻断上下文教学提示（贴地图底部，不遮挡游戏）
## 玩家完成对应动作后由 BattleController 推进到下一步
func show_context_hint(flag: String) -> void:
	var copy := get_hint_copy(flag)
	if copy == "" or is_known(flag):
		return
	_on_context_skip = Callable()
	if _context_skip_button:
		_context_skip_button.visible = false
	_context_label.text = copy
	_background.visible = false
	_modal_panel.visible = false
	_context_panel.visible = true
	show()

## V2 uses a short, state-machine-owned hint instead of the V1 flag copy.
## The callback only dismisses onboarding; it never changes gameplay rules.
func show_v2_context_hint(text: String, on_skip: Callable = Callable()) -> void:
	if text.is_empty():
		return
	_flag = ""
	_on_closed = Callable()
	_on_context_skip = on_skip
	_context_label.text = text
	_background.visible = false
	_modal_panel.visible = false
	_context_panel.visible = true
	if _context_skip_button:
		_context_skip_button.visible = true
	show()

## CH1-030: 隐藏上下文教学提示
func dismiss_context_hint() -> void:
	_context_panel.visible = false
	if _context_skip_button:
		_context_skip_button.visible = false
	if is_inside_tree():
		hide()

## CH1-030: 上下文提示是否正在显示
func is_context_hint_active() -> bool:
	return is_inside_tree() and _context_panel.visible

func _ready() -> void:
	hide()
	_context_skip_button = get_node_or_null("ContextPanel/SkipContextButton") as Button
	_continue_button.pressed.connect(_on_continue)
	_skip_button.pressed.connect(_on_skip)
	if _context_skip_button:
		_context_skip_button.pressed.connect(_on_context_skip_pressed)

func _on_continue() -> void:
	mark_known(_flag)
	_close()

func _on_skip() -> void:
	mark_known(_flag)
	_skip_remaining = true
	_close()

func _on_context_skip_pressed() -> void:
	_skip_remaining = true
	dismiss_context_hint()
	var callback := _on_context_skip
	_on_context_skip = Callable()
	if callback.is_valid():
		callback.call()

## 关闭提示并恢复回调
func _close() -> void:
	if is_inside_tree():
		hide()
		_context_panel.visible = false
	if _context_skip_button:
		_context_skip_button.visible = false
	hint_closed.emit(_flag)
	if _on_closed.is_valid():
		_on_closed.call()
