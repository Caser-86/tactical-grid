extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const MainMenuScene = preload("res://scenes/main_menu.tscn")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu := MainMenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame

	var v2_continue: Button = menu.get_node("VBoxContainer/ContinueV2Button")
	var v2_new: Button = menu.get_node("VBoxContainer/NewV2GameButton")
	var v1_continue: Button = menu.get_node("VBoxContainer/ContinueButton")
	var v1_new: Button = menu.get_node("VBoxContainer/NewGameButton")
	t.check(v2_continue != null and v2_new != null, "主菜单提供独立 V2 继续和新游戏入口")
	t.check(v2_new.text == "新游戏 V2" and not v2_new.disabled, "V2 新游戏入口可用")
	t.check(v1_continue != null and v1_new != null, "主菜单保留 V1 兼容入口")
	t.check(v1_new.text == "新游戏 V1 原作", "V1 入口明确标注原作")

	menu.queue_free()
	await get_tree().process_frame
	t.finish(get_tree())
