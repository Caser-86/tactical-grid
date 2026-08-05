extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var repo := Repository.new()
	var load_result := repo.reload_all()
	var mission := repo.get_mission(&"ch1_m1")
	var required_ids := [
		&"ch1_m1_brief",
		&"ch1_m1_intro",
		&"ch1_m1_rescue",
		&"ch1_m1_record",
		&"ch1_m1_outro",
	]

	t.check(bool(load_result.get("success", false)), "M1 V2 对话数据仓库加载成功")
	t.check(mission.get("dialogue_ids", []) == [
		"ch1_m1_brief",
		"ch1_m1_intro",
		"ch1_m1_rescue",
		"ch1_m1_record",
		"ch1_m1_outro",
	], "M1 对话 ID 覆盖战前、战中节点和战后")
	for dialogue_id in required_ids:
		var dialogue := repo.get_dialogue(dialogue_id)
		var lines: Array = dialogue.get("lines", [])
		t.check(not dialogue.is_empty() and not lines.is_empty(), "%s 有正式内容" % dialogue_id)
		t.check(String(dialogue.get("trigger", "")) != "", "%s 有事件触发器" % dialogue_id)
		for line in lines:
			t.check(String(line.get("text", "")).length() > 0, "%s 不含空台词" % dialogue_id)

	var brief := repo.get_dialogue(&"ch1_m1_brief")
	var outro := repo.get_dialogue(&"ch1_m1_outro")
	t.check((brief.get("lines", []) as Array).size() <= 6, "战前对话不超过六节点")
	t.check((outro.get("lines", []) as Array).size() <= 8, "战后对话不超过八节点")
	t.check(_has_choices(brief), "战前行动方针有两个可点击选项")
	t.check(_choice_count(brief) == 2, "战前选项数量固定为两个")
	t.check(repo.get_dialogue(&"ch1_m1_record").get("full_text", "").length() <= 120, "事故记录正文不超过 120 字")
	t.check(String(repo.get_dialogue(&"ch1_m1_rescue").get("trigger", "")) == "scout_rescued", "营救对话绑定营救事件")
	t.check(String(repo.get_dialogue(&"ch1_m1_record").get("trigger", "")) == "optional_record_uploaded", "记录对话绑定可选记录事件")

	repo.free()
	t.finish(self)

func _has_choices(dialogue: Dictionary) -> bool:
	for line in dialogue.get("lines", []):
		if bool(line.get("choices", false)):
			return true
	return false

func _choice_count(dialogue: Dictionary) -> int:
	return (dialogue.get("choices", []) as Array).size()
