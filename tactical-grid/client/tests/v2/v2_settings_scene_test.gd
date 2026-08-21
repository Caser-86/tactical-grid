extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const SettingsScene = preload("res://scenes/settings_menu.tscn")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := get_node_or_null("/root/GameManager")
	t.check(manager != null, "V2 设置场景找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	manager.set("current_save", SaveManager.create_default_save())
	manager.set("v2_menu_settings", V2VisualMode.default_settings())
	var settings := SettingsScene.instantiate()
	add_child(settings)
	await get_tree().process_frame
	var label := settings.get_node("Panel/ScrollContainer/VBoxContainer/DifficultyLabel") as Label
	var option := settings.get_node("Panel/ScrollContainer/VBoxContainer/DifficultyOption") as OptionButton
	t.check(label.visible and option.visible, "V2 设置显示难度入口")
	t.check(option.item_count == 2, "V2 设置只显示故事和标准难度")
	t.check(option.get_item_text(0) == "故事" and option.get_item_text(1) == "标准", "V2 难度使用玩家可读中文名称")
	option.select(0)
	settings.call("_on_difficulty_changed", 0)
	t.check(manager.get_settings().get("difficulty", "") == "story", "V2 设置可以保存故事难度")
	t.check(SaveManager.load_v2_settings().get("difficulty", "") == "story", "V2 主菜单难度写入独立设置文件")
	t.check(String(manager.current_save.get("game_line", "")) != "v2_infiltration", "V2 主菜单设置不创建伪存档或改写产品身份")
	t.check(manager.current_save.get("settings", {}).get("difficulty", "standard") == "standard", "V2 主菜单设置不写入 V1 当前存档")
	settings.queue_free()
	await get_tree().process_frame
	t.check(manager.call("new_v2_game", 2), "V2 主菜单设置后可以创建正式新档")
	t.check(manager.current_save.get("settings", {}).get("difficulty", "") == "story", "新建 V2 存档继承主菜单故事难度")
	var legacy_slot := SaveManager.create_v2_save()
	legacy_slot["settings"] = V2VisualMode.default_settings()
	legacy_slot["settings"]["difficulty"] = "standard"
	t.check(SaveManager.save_game_v2(legacy_slot, 2), "测试可写入携带旧难度的 V2 存档")
	t.check(manager.call("load_v2_slot", 2), "V2 可以载入已有存档")
	t.check(manager.get_settings().get("difficulty", "") == "story", "载入旧 V2 存档不覆盖主菜单保存的难度")
	SaveManager.delete_v2_save(2)
	manager.set("v2_menu_settings", V2VisualMode.default_settings())
	SaveManager.save_v2_settings(V2VisualMode.default_settings())
	t.finish(get_tree())
