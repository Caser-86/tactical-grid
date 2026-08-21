extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CampaignProgress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")

var t := Runner.new()
var save_manager: Variant
var game_manager: Variant

func _initialize() -> void:
	save_manager = get_root().get_node("SaveManager")
	game_manager = get_root().get_node("GameManager")
	var created: Dictionary = V2CampaignProgress.create_default()
	t.check(created.get("game_line", "") == "v2_infiltration", "默认存档写入 V2 身份")
	t.check(created.get("save_version", "") == "2.0.0", "默认存档版本为 2.0.0")
	t.check(created.get("rescued_characters", []) == ["assault"], "新档只有突击兵")
	t.check(V2CampaignProgress.validate(created).get("valid", false), "默认 V2 存档通过校验")

	var v1 := {"save_version": "1.0.0", "campaign_progress": {}}
	t.check(not bool(V2CampaignProgress.validate(v1).get("valid", true)), "V1 存档被拒绝")

	var completed: Dictionary = V2CampaignProgress.complete_mission(created, &"ch1_m1", {
		"rating": 3,
		"rescue_character": "scout",
		"unlocked_modules": ["scout_a"],
	})
	t.check("ch1_m1" in completed.get("completed_missions", []), "完成任务写入完成列表")
	t.check("scout" in completed.get("rescued_characters", []), "救援角色写入可选队伍")
	t.check("scout_a" in completed.get("unlocked_modules", []), "任务奖励写入模块解锁")
	t.check(completed.get("current_mission", "") == "ch1_m2", "完成 M1 推进到 M2")

	save_manager.delete_v2_save(0)
	var save_data: Dictionary = save_manager.create_v2_save()
	t.check(save_manager.V2_MAX_LOCAL_SAVES == 3, "V2 保留三个存档槽")
	t.check(save_manager.save_game_v2(save_data, 0), "V2 存档可写入")
	var loaded: Dictionary = save_manager.load_game_v2(0)
	t.check(loaded.get("game_line", "") == "v2_infiltration", "V2 存档读取保持身份")
	t.check(not save_manager.save_game_v2(v1, 1), "V1 数据不能写入 V2 存档")
	var game_manager_save: Dictionary = game_manager.begin_v2_new_game_for_test(2)
	t.check(game_manager_save.get("game_line", "") == "v2_infiltration", "GameManager 创建 V2 新档")
	t.check(game_manager.complete_v2_mission({"mission_id": "ch1_m1", "rating": 2, "rescue_character": "scout"}), "GameManager 保存 V2 任务进度")
	var progressed: Dictionary = save_manager.load_game_v2(2)
	t.check(progressed.get("current_mission", "") == "ch1_m2", "V2 任务进度持久化")
	save_manager.delete_v2_save(0)
	save_manager.delete_v2_save(2)
	t.finish(self)
