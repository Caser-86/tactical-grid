extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const Progress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")
const DialogueScene = preload("res://scenes/dialogue.tscn")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M111 正式对话场景找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	manager.set("current_save", Progress.create_default())
	var dialogue := DialogueScene.instantiate()
	add_child(dialogue)
	await get_tree().process_frame
	dialogue.start_dialogue("ch1_m1_brief")
	await get_tree().process_frame
	t.check(bool(dialogue.visible), "V2 战前简报可以显示")
	t.check(dialogue.get("dialogue_data").get("id", "") == "ch1_m1_brief", "对话系统读取 V2 数据而非 V1 同名 ID")
	dialogue.call("_show_full_text")
	dialogue.call("_next_line")
	await get_tree().process_frame
	dialogue.call("_show_full_text")
	dialogue.call("_next_line")
	await get_tree().process_frame
	t.check(dialogue.get_node("Panel/ChoicesContainer").get_child_count() == 2, "战前简报生成两个可点击按钮")
	dialogue.call("_show_full_text")
	dialogue.call("_on_choice_selected", 0)
	await get_tree().process_frame
	t.check(bool(manager.current_save.get("story_flags", {}).get("ch1_m1_cautious", false)), "V2 选项写入独立剧情旗标")
	t.check(dialogue.get("current_lines").size() == 1, "选择后显示对应短回应")
	dialogue.call("_end_dialogue")
	await get_tree().process_frame
	t.check(not is_instance_valid(dialogue), "对话结束释放实例")
	t.finish(get_tree())
