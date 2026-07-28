## 剧情对话系统
## 管理剧情对话的显示和玩家选择
extends Control
class_name DialogueSystem

signal dialogue_finished()
signal choice_made(flag: String)

@onready var portrait_left = $Panel/PortraitLeft
@onready var portrait_right = $Panel/PortraitRight
@onready var name_label = $Panel/NameLabel
@onready var text_label = $Panel/TextLabel
@onready var choices_container = $Panel/ChoicesContainer
@onready var continue_hint = $Panel/ContinueHint

var dialogue_data: Dictionary = {}
var current_lines: Array = []
var current_index: int = 0
var is_typing: bool = false
var type_speed: float = 0.03
var current_choices: Array = []

func _ready() -> void:
	hide()
	continue_hint.visible = false
	# 读取可访问性字幕速度设置（subtitle_speed > 1 表示更快，< 1 表示更慢）
	var settings = GameManager.get_settings()
	var subtitle_speed = settings.get("subtitle_speed", 1.0)
	if subtitle_speed > 0.0:
		type_speed = 0.03 / subtitle_speed

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_typing:
				# 跳过打字动画
				_show_full_text()
			elif choices_container.get_child_count() == 0:
				# 继续下一句
				_next_line()

## 开始对话
func start_dialogue(dialogue_id: String) -> void:
	dialogue_data = _load_dialogue(dialogue_id)
	if dialogue_data.is_empty():
		dialogue_finished.emit()
		queue_free()
		return

	current_lines = dialogue_data.get("lines", [])
	if current_lines.is_empty():
		dialogue_finished.emit()
		queue_free()
		return
	current_index = 0
	show()
	_show_line(current_lines[current_index])

## 显示一行对话
func _show_line(line: Dictionary) -> void:
	# 清除选项
	for child in choices_container.get_children():
		child.queue_free()

	# 设置角色名
	name_label.text = line.get("speaker", "???")

	# 设置文字（打字机效果）
	text_label.text = ""
	is_typing = true
	continue_hint.visible = false
	_type_text(line.get("text", ""))

	# 设置头像
	# TODO: 根据 speaker 加载对应立绘

	# 如果有选项
	if line.get("choices", false):
		_show_choices()

## 打字机效果
func _type_text(text: String) -> void:
	for i in range(text.length()):
		if not is_typing:
			text_label.text = text
			break
		text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(type_speed).timeout

	is_typing = false
	continue_hint.visible = true

## 跳过打字
func _show_full_text() -> void:
	is_typing = false
	if current_index < current_lines.size():
		text_label.text = current_lines[current_index].get("text", "")
	continue_hint.visible = true

## 下一行
func _next_line() -> void:
	current_index += 1
	if current_index >= current_lines.size():
		_end_dialogue()
	else:
		_show_line(current_lines[current_index])

## 显示选项
func _show_choices() -> void:
	var choices = dialogue_data.get("choices", [])
	current_choices = choices

	for i in range(choices.size()):
		var choice = choices[i]
		var button = Button.new()
		button.text = choice.get("text", "")
		button.custom_minimum_size = Vector2(400, 40)
		button.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(button)

	continue_hint.visible = false

## 选项被选择
func _on_choice_selected(index: int) -> void:
	var choice = current_choices[index]

	# 触发 flag
	if choice.has("flag"):
		choice_made.emit(choice.flag)
		GameManager.current_save.campaign_progress.story_flags[choice.flag] = true
		GameManager.save_current()

	# 显示回应
	if choice.has("response"):
		current_lines = [choice.response]
		current_index = 0
		_show_line(choice.response)
	else:
		_end_dialogue()

## 结束对话
func _end_dialogue() -> void:
	hide()
	dialogue_finished.emit()
	queue_free()

## 加载对话数据
func _load_dialogue(dialogue_id: String) -> Dictionary:
	# 优先使用 GameData 已加载的数据
	if GameData and not GameData.get_dialogue(dialogue_id).is_empty():
		return GameData.get_dialogue(dialogue_id)
	# 兜底：直接从文件读取
	var file = FileAccess.open("res://data/dialogues.json", FileAccess.READ)
	if not file:
		return {}

	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data and data.has("dialogues") and data.dialogues.has(dialogue_id):
		return data.dialogues[dialogue_id]

	return {}
