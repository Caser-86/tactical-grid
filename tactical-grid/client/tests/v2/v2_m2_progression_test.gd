extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Progress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")
const Squad = preload("res://scripts/v2/mission/v2_squad_selection.gd")
const Loadout = preload("res://scripts/v2/mission/v2_module_loadout.gd")

var t := Runner.new()

func _initialize() -> void:
	var save := Progress.create_default()
	var m1_result := Progress.complete_mission(save, &"ch1_m1", {
		"rescued": ["scout"],
		"optional_record": true,
		"rating": 3,
	})
	var m2_result := Progress.complete_mission(m1_result, &"ch1_m2", {
		"rescued": ["sniper"],
		"rescue_character": "sniper",
		"optional_record": true,
		"unlocked_modules": ["sniper_a", "assault_b"],
		"rating": 3,
	})
	t.check(m2_result.completed_missions == ["ch1_m1", "ch1_m2"], "M2 完成记录只追加一次且顺序稳定")
	t.check(m2_result.current_mission == "ch1_m3", "M2 完成解锁第三关")
	t.check(m2_result.rescued_characters == ["assault", "scout", "sniper"], "M2 营救狙击手写入基地 roster")
	t.check("sniper_a" in m2_result.unlocked_modules, "营救狙击手解锁狙击模块 A")
	t.check("assault_b" in m2_result.unlocked_modules, "关闭冷却喷口解锁突击模块 B")
	t.check(bool(m2_result.story_flags.get("ch1_m1_optional_record", false)), "M1 可选记录旗标保持不变")
	t.check(not bool(m2_result.story_flags.get("ch1_m2_optional_record", false)), "M2 不伪造 M1 可选记录旗标")
	var m3: Dictionary = {"id": "ch1_m3", "starting_roster": ["assault", "scout", "sniper", "heavy"], "deployment_limit": 3}
	var valid_squad := Squad.validate_squad_for_save(m3, ["assault", "sniper"], m2_result)
	t.check(bool(valid_squad.get("valid", false)), "M2 后可以部署突击兵和狙击手")
	var locked_heavy := Squad.validate_squad_for_save(m3, ["assault", "heavy"], m2_result)
	t.check(not bool(locked_heavy.get("valid", true)), "未营救重装兵仍不能部署")
	var sniper_equip := Loadout.equip(m2_result, &"sniper", &"sniper_a")
	t.check(bool(sniper_equip.get("success", false)), "基地可以装备狙击模块 A")
	var assault_equip := Loadout.equip(m2_result, &"assault", &"assault_b")
	t.check(bool(assault_equip.get("success", false)), "基地可以装备突击模块 B")
	t.check(String(m2_result.equipped_modules.get("sniper", "")) == "sniper_a", "狙击模块装备状态可读")
	t.check(String(m2_result.equipped_modules.get("assault", "")) == "assault_b", "突击模块装备状态可读")
	t.check(bool(Progress.validate(m2_result).get("valid", false)), "M2 完成后的 V2 存档通过校验")
	t.finish(self)
