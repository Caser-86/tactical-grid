extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Progress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")
const Squad = preload("res://scripts/v2/mission/v2_squad_selection.gd")
const Loadout = preload("res://scripts/v2/mission/v2_module_loadout.gd")

var t := Runner.new()

func _initialize() -> void:
	var save := Progress.create_default()
	var result := Progress.complete_mission(save, &"ch1_m1", {
		"rescued": ["scout"],
		"optional_record": true,
		"rating": 3,
	})
	t.check(result.rescued_characters == ["assault", "scout"], "M1 营救侦察兵后永久加入队伍")
	t.check("scout_a" in result.unlocked_modules, "营救侦察兵解锁扩展扫描")
	t.check("scout_b" in result.unlocked_modules, "完成可选记录解锁静默扫描")
	t.check(result.current_mission == "ch1_m2", "完成 M1 解锁下一任务")
	t.check(bool(result.story_flags.get("ch1_m1_optional_record", false)), "可选记录写入故事旗标")

	var available: Array = Squad.get_available_characters(result)
	t.check(available == ["assault", "scout"], "基地只显示已解锁角色且顺序稳定")
	var m2: Dictionary = {"id": "ch1_m2", "starting_roster": ["assault", "scout"], "deployment_limit": 3}
	var valid_squad: Dictionary = Squad.validate_squad(m2, ["assault", "scout"])
	t.check(bool(valid_squad.get("valid", false)), "M2 两人编队有效")
	var duplicate_squad: Dictionary = Squad.validate_squad(m2, ["assault", "assault"])
	t.check(not bool(duplicate_squad.get("valid", true)), "编队不能重复选择同一角色")
	var unknown_squad: Dictionary = Squad.validate_squad(m2, ["assault", "heavy"])
	t.check(not bool(unknown_squad.get("valid", true)), "未列入任务编制的角色不能强行部署")
	var empty_squad: Dictionary = Squad.validate_squad(m2, [])
	t.check(not bool(empty_squad.get("valid", true)), "编队不能为空")

	var equip_result: Dictionary = Loadout.equip(result, &"scout", &"scout_b")
	t.check(bool(equip_result.get("success", false)), "已解锁模块可以装备")
	t.check(String(result.equipped_modules.get("scout", "")) == "scout_b", "装备写入角色当前模块")
	var wrong_role: Dictionary = Loadout.equip(result, &"scout", &"assault_b")
	t.check(not bool(wrong_role.get("success", true)), "其他角色模块不能装备给侦察兵")
	var locked_module: Dictionary = Loadout.equip(result, &"scout", &"heavy_a")
	t.check(not bool(locked_module.get("success", true)), "未解锁模块不能装备")
	t.check(String(Loadout.get_equipped(result, &"scout")) == "scout_b", "基地能读取当前模块")

	var invalid := result.duplicate(true)
	invalid.rescued_characters.erase("assault")
	t.check(not bool(Progress.validate(invalid).get("valid", true)), "存档不能移除初始突击兵")
	t.finish(self)
