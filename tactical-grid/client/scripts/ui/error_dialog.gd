## 统一错误对话框
extends Control

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var message_label = $Panel/VBoxContainer/MessageLabel
@onready var confirm_button = $Panel/VBoxContainer/ConfirmButton

var _on_confirm: Callable = Callable()
var _pending_title: String = ""
var _pending_message: String = ""

func _ready() -> void:
	# 应用 setup 中暂存的标题/消息（若在进入树之前调用 setup）
	if _pending_title != "":
		title_label.text = _pending_title
		_pending_title = ""
	if _pending_message != "":
		message_label.text = _pending_message
		_pending_message = ""
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.grab_focus()

## 配置对话框；可在节点进入场景树之前调用，标题/消息会暂存到 _ready 时应用
func setup(title: String, message: String, on_confirm: Callable = Callable()) -> void:
	_on_confirm = on_confirm
	if is_inside_tree():
		title_label.text = title
		message_label.text = message
	else:
		# 节点尚未进入树，@onready 引用未初始化，暂存
		_pending_title = title
		_pending_message = message

func _on_confirm_pressed() -> void:
	if _on_confirm.is_valid():
		_on_confirm.call()
	queue_free()
