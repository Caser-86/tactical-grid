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
	portrait_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			_show_full_text()
		elif choices_container.get_child_count() == 0:
			_next_line()

func start_dialogue(dialogue_id: String) -> void:
	dialogue_data = _load_dialogue(dialogue_id)
	if dialogue_data.is_empty():
		dialogue_finished.emit()
		return

	current_lines = dialogue_data.get("lines", [])
	current_index = 0
	if current_lines.is_empty():
		dialogue_finished.emit()
		hide()
		return
	show()
	_show_line(current_lines[current_index])

func _show_line(line: Dictionary) -> void:
	for child in choices_container.get_children():
		child.queue_free()

	name_label.text = line.get("speaker", "???")
	text_label.text = ""
	is_typing = true
	continue_hint.visible = false
	_type_text(line.get("text", ""))

	var speaker = line.get("speaker", "")
	_load_portrait(speaker, line.get("portrait_side", "left"))

	if line.get("choices", false):
		_show_choices()

func _type_text(text: String) -> void:
	for i in range(text.length()):
		if not is_typing:
			text_label.text = text
			break
		text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(type_speed).timeout
	is_typing = false
	continue_hint.visible = true

func _show_full_text() -> void:
	is_typing = false
	if current_index < current_lines.size():
		text_label.text = current_lines[current_index].get("text", "")
	continue_hint.visible = true

func _next_line() -> void:
	current_index += 1
	if current_index >= current_lines.size():
		_end_dialogue()
	else:
		_show_line(current_lines[current_index])

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

func _on_choice_selected(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	var choice = current_choices[index]
	if choice.has("flag"):
		choice_made.emit(choice.flag)
		if not GameManager.save_data.has("campaign_progress"):
			GameManager.save_data["campaign_progress"] = {"story_flags": {}}
		var campaign_progress = GameManager.save_data["campaign_progress"]
		if not campaign_progress.has("story_flags"):
			campaign_progress["story_flags"] = {}
		campaign_progress["story_flags"][choice.flag] = true

	if choice.has("response"):
		current_lines = [choice.response]
		current_index = 0
		_show_line(choice.response)
	else:
		_end_dialogue()

func _end_dialogue() -> void:
	hide()
	dialogue_finished.emit()

func _load_portrait(speaker: String, side: String = "left") -> void:
	var target_portrait = portrait_left if side == "left" else portrait_right
	var other_portrait = portrait_right if side == "left" else portrait_left
	other_portrait.visible = false

	var texture = ArtAssets.get_portrait_for_speaker(speaker)
	target_portrait.texture = texture
	target_portrait.visible = texture != null

func _load_dialogue(dialogue_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/dialogues.json", FileAccess.READ)
	if not file:
		return {}

	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)
	if data and data.has("dialogues") and data.dialogues.has(dialogue_id):
		return data.dialogues[dialogue_id]

	return {}
