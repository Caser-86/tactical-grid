## 对话选项布局运行时视觉快照。
## 复现 M1 指挥官选择场景，确认头像不会覆盖对白和按钮。
extends Node

const DialogueScene = preload("res://scenes/dialogue.tscn")

var target_size := Vector2i(1280, 720)
var output_path := "build/dialogue_visual_1280x720.png"

func _ready() -> void:
	_parse_user_args()
	get_window().size = target_size
	get_viewport().size = target_size
	GameManager.current_save = SaveManager.create_default_save()

	var dialogue := DialogueScene.instantiate() as DialogueSystem
	add_child(dialogue)
	await get_tree().process_frame
	dialogue.start_dialogue("ch1_m1_intro")
	dialogue._show_full_text()
	await get_tree().process_frame
	await get_tree().process_frame

	dialogue.current_lines = dialogue.dialogue_data.get("lines", [])
	dialogue.current_index = 7
	dialogue._show_line(dialogue.current_lines[dialogue.current_index])
	await get_tree().process_frame
	dialogue._show_full_text()
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Dialogue visual snapshot failed: viewport image is empty")
		get_tree().quit(1)
		return
	var absolute_path := output_path
	if not absolute_path.is_absolute_path():
		absolute_path = ProjectSettings.globalize_path(absolute_path)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Dialogue visual snapshot failed to save: %s (%s)" % [absolute_path, error])
		get_tree().quit(1)
		return
	print("Dialogue visual snapshot saved: %s (%dx%d)" % [absolute_path, image.get_width(), image.get_height()])
	dialogue.free()
	get_tree().quit(0)

func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-size="):
			var parts := argument.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2:
				target_size = Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
		elif argument.begins_with("--qa-output="):
			output_path = argument.trim_prefix("--qa-output=")
