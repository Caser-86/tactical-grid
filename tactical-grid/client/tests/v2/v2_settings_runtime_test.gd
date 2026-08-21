extends Node

const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := get_node_or_null("/root/GameManager")
	t.check(manager != null, "V2 运行时设置测试找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	var settings := V2VisualMode.default_settings()
	settings["visual_mode"] = "grayscale"
	settings["music_volume"] = 0.35
	manager.set("v2_menu_settings", settings)
	if manager.has_method("apply_v2_runtime_settings"):
		manager.call("apply_v2_runtime_settings")
	t.check(V2VisualMode.current_mode() == &"grayscale", "V2 冷启动会应用保存的视觉模式")
	t.check(is_equal_approx(AudioManager.bgm_volume, 0.35), "V2 冷启动会应用保存的音乐音量")
	manager.set("v2_menu_settings", V2VisualMode.default_settings())
	if manager.has_method("apply_v2_runtime_settings"):
		manager.call("apply_v2_runtime_settings")
	t.finish(get_tree())
