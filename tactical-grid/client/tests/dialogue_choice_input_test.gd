## 对话选项真实输入测试
## 使用 viewport.push_input 注入鼠标点击，确保按钮不是只能通过直接 emit 触发。
extends Node

const DialogueScene = preload("res://scenes/dialogue.tscn")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []

func _ready() -> void:
	print("=== 对话选项真实输入测试 ===")
	get_window().size = Vector2i(1280, 720)
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

	var choices := dialogue.get_node("Panel/ChoicesContainer") as VBoxContainer
	_check(choices.get_child_count() == 2, "对话显示两个选择按钮")
	if choices.get_child_count() > 0:
		var button := choices.get_child(0) as Button
		var click_position := button.get_global_rect().get_center()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = click_position
		click.global_position = click_position
		click.device = -1
		get_viewport().push_input(click)
		await get_tree().process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = click_position
		release.global_position = click_position
		release.device = -1
		get_viewport().push_input(release)
		await get_tree().process_frame
		_check(GameManager.get_story_flag("cautious_approach", false), "鼠标点击第一个选项触发剧情旗标")
		_check(dialogue.current_lines.size() == 1, "点击选项后进入对应回应文本")

	dialogue.free()
	GameManager.current_save = SaveManager.create_default_save()
	var second_dialogue := DialogueScene.instantiate() as DialogueSystem
	add_child(second_dialogue)
	await get_tree().process_frame
	second_dialogue.start_dialogue("ch1_m1_intro")
	second_dialogue._show_full_text()
	await get_tree().process_frame
	await get_tree().process_frame
	second_dialogue.current_lines = second_dialogue.dialogue_data.get("lines", [])
	second_dialogue.current_index = 7
	second_dialogue._show_line(second_dialogue.current_lines[second_dialogue.current_index])
	await get_tree().process_frame
	second_dialogue._show_full_text()
	await get_tree().process_frame
	await get_tree().process_frame

	var second_choices := second_dialogue.get_node("Panel/ChoicesContainer") as VBoxContainer
	_check(second_choices.get_child_count() == 2, "第二次对话仍显示两个选择按钮")
	if second_choices.get_child_count() > 1:
		var second_button := second_choices.get_child(1) as Button
		var second_position := second_button.get_global_rect().get_center()
		var second_press := InputEventMouseButton.new()
		second_press.button_index = MOUSE_BUTTON_LEFT
		second_press.pressed = true
		second_press.position = second_position
		second_press.global_position = second_position
		second_press.device = -1
		get_viewport().push_input(second_press)
		await get_tree().process_frame
		var second_release := InputEventMouseButton.new()
		second_release.button_index = MOUSE_BUTTON_LEFT
		second_release.pressed = false
		second_release.position = second_position
		second_release.global_position = second_position
		second_release.device = -1
		get_viewport().push_input(second_release)
		await get_tree().process_frame
		_check(GameManager.get_story_flag("aggressive_approach", false), "鼠标点击第二个选项触发剧情旗标")
		_check(second_dialogue.current_lines.size() == 1, "点击第二个选项后进入对应回应文本")
	second_dialogue.free()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)

func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  Passed: %d" % _passed)
	print("  Failed: %d" % _failed)
	if not _errors.is_empty():
		print("  Failures:")
		for error in _errors:
			print("    - ", error)
	print("  =================")
