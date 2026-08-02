## 对话布局契约测试
## 验证角色立绘不会溢出对话框或覆盖对白、选项。
extends Node

const DialogueScene = preload("res://scenes/dialogue.tscn")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []

func _ready() -> void:
	print("=== 对话布局契约测试 ===")
	GameManager.current_save = SaveManager.create_default_save()
	var dialogue := DialogueScene.instantiate() as DialogueSystem
	add_child(dialogue)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel := dialogue.get_node("Panel") as Panel
	var portrait_left := dialogue.get_node("Panel/PortraitLeft") as TextureRect
	var portrait_right := dialogue.get_node("Panel/PortraitRight") as TextureRect
	var text_label := dialogue.get_node("Panel/TextLabel") as Label
	var choices := dialogue.get_node("Panel/ChoicesContainer") as VBoxContainer
	_check(panel.clip_contents, "对话面板裁剪溢出内容")
	_check(portrait_left.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "左侧立绘忽略原图尺寸")
	_check(portrait_right.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "右侧立绘忽略原图尺寸")
	_check(portrait_left.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "左侧立绘保持比例居中")
	_check(portrait_right.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "右侧立绘保持比例居中")

	dialogue.start_dialogue("ch1_m1_intro")
	await get_tree().process_frame
	dialogue.current_lines = dialogue.dialogue_data.get("lines", [])
	dialogue.current_index = 7
	dialogue._show_line(dialogue.current_lines[dialogue.current_index])
	await get_tree().process_frame
	dialogue._show_full_text()
	await get_tree().process_frame

	_check(portrait_right.texture is Texture2D, "指挥官右侧立绘加载成功")
	var portrait_rect := portrait_right.get_rect()
	var panel_rect := Rect2(Vector2.ZERO, panel.size)
	_check(panel_rect.encloses(portrait_rect), "右侧立绘保持在对话面板内")
	_check(text_label.get_rect().end.x <= portrait_right.position.x - 8.0, "对白文本避开右侧立绘")
	_check(choices.get_rect().end.x <= portrait_right.position.x - 8.0, "选项按钮避开右侧立绘")
	_check(not dialogue.continue_hint.visible, "显示选项时隐藏继续提示")

	dialogue.free()
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
