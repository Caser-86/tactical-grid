## 第一章教程提示系统
## 显示可跳过、可持久化的教程提示；已读状态存于 campaign_progress.story_flags
## 未知 flag 直接回调不阻断，保证无头测试与未来扩展不卡流程
extends Control
class_name TutorialHint

signal hint_closed(flag: String)

## 第一章教程文案表（flag -> 提示文本）
const HINT_COPY := {
	"teach_movement": "选中队员后，先点下方【移动】，再点蓝色高亮格移动。每回合的移动会消耗移动点数。",
	"teach_attack": "选中队员后，先点下方【攻击】，再点红色目标攻击。注意武器射程、命中率与掩体影响。",
	"teach_cover": "站在掩体后方可降低被命中率。森林、墙体和高地都能提供掩护。",
	"teach_evac": "完成目标后，所有存活单位需到达撤离点撤离。回合数越少评级越高。",
	"teach_highground": "高地提供命中与视野加成，占据高处获得战术优势。",
	"teach_destructible": "部分掩体可被破坏。破坏后失去掩护效果，可开辟新路线。",
	"teach_resource": "情报是关键资源，首通奖励提供更多情报，用于解锁装备与角色。",
	"teach_overwatch": "守望模式消耗 AP，在敌人移动进入射程时触发反应射击。",
	"teach_interaction": "点击终端等交互对象激活目标。steal_data 任务需要激活所有终端。",
	"teach_escort": "护送 VIP 到撤离点。VIP 阵亡则任务失败，注意保护。",
	"teach_skills": "技能消耗 AP，提供强力战术选项。不同职业有不同技能树。",
	"teach_items": "物品如医疗包可在战斗中使用，不消耗 AP，注意补给。",
	"teach_camera": "战场大于屏幕。按住鼠标中键拖动画面，滚轮缩放，WASD 或方向键平移；Tab 查看全图，Home 返回当前单位。",
	"teach_upload_hold": "终端上传需要连续控制 2 个敌方回合。至少一名队员留在终端一格范围内，否则上传暂停。",
}

@onready var _text_label: Label = $Panel/TextLabel
@onready var _continue_button: Button = $Panel/Buttons/ContinueButton
@onready var _skip_button: Button = $Panel/Buttons/SkipButton

var _flag: String = ""
var _on_closed: Callable = Callable()
var _skip_remaining: bool = false

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
	# 未知 flag 或已读：直接回调，不显示 UI
	if get_hint_copy(flag) == "" or is_known(flag):
		_close()
		return
	_text_label.text = get_hint_copy(flag)
	show()

func _ready() -> void:
	hide()
	_continue_button.pressed.connect(_on_continue)
	_skip_button.pressed.connect(_on_skip)

func _on_continue() -> void:
	mark_known(_flag)
	_close()

func _on_skip() -> void:
	mark_known(_flag)
	_skip_remaining = true
	_close()

## 关闭提示并恢复回调
func _close() -> void:
	if is_inside_tree():
		hide()
	hint_closed.emit(_flag)
	if _on_closed.is_valid():
		_on_closed.call()
