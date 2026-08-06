extends Node

const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := get_node_or_null("/root/GameManager")
	t.check(manager != null and manager.has_method("is_v2_runtime") and bool(manager.call("is_v2_runtime")), "V2 构建固定为独立产品线")
	t.check(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/v2_boot.tscn", "V2 从专用启动场景启动")

	var menu_path := "res://scenes/v2_main_menu.tscn"
	t.check(ResourceLoader.exists(menu_path), "V2 使用专用主菜单场景")
	if ResourceLoader.exists(menu_path):
		var menu_scene := ResourceLoader.load(menu_path) as PackedScene
		var menu := menu_scene.instantiate() if menu_scene else null
		add_child(menu)
		await get_tree().process_frame
		t.check(menu.get_node_or_null("VBoxContainer/ContinueV2Button") != null, "V2 菜单保留独立继续入口")
		t.check(menu.get_node_or_null("VBoxContainer/NewV2GameButton") != null, "V2 菜单保留独立新游戏入口")
		t.check(menu.get_node_or_null("VBoxContainer/ContinueButton") == null and menu.get_node_or_null("VBoxContainer/NewGameButton") == null, "V2 菜单不暴露 V1 存档入口")
		menu.queue_free()
		await get_tree().process_frame

	t.finish(get_tree())
