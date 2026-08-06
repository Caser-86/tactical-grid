extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var repo := Repository.new()
	var result := repo.reload_all()
	var mission := repo.get_mission(&"ch1_m1")
	var scout := repo.get_character(&"scout")
	var starting_roster: Array = mission.get("starting_roster", [])
	var duration: Array = mission.get("duration_minutes", [])
	var tutorial_steps: Array = mission.get("tutorial_steps", [])

	t.check(bool(result.get("success", false)), "M1 数据仓库加载成功")
	t.check(String(mission.get("id", "")) == "ch1_m1", "M1 稳定任务 ID 固定")
	t.check(String(mission.get("map_id", "")) == "ch1_m1_echo_yard_v3", "M1 使用正式锁定地图 ID")
	t.check(starting_roster == ["assault"], "M1 单人突击开场")
	t.check(String(mission.get("rescue_character", "")) == "scout", "M1 营救侦察兵")
	t.check(int(mission.get("deployment_limit", 0)) == 2, "M1 最多部署两名角色")
	t.check(String(mission.get("primary", "")) == "找到失联侦察兵并一起撤离", "主目标文案固定")
	t.check(String(mission.get("optional", "")) == "上传事故记录", "事故记录为可选目标")
	t.check(int(mission.get("enemy_total", 0)) == 6 and int(mission.get("active_cap", 0)) == 3, "六敌且同时最多三敌")
	t.check(duration.size() == 2 and int(duration[0]) == 12 and int(duration[1]) == 18, "首次时长目标固定为 12 到 18 分钟")
	t.check(tutorial_steps == ["select", "move", "attack", "intent", "camera", "evac"], "教学步骤按单条信息递进")
	t.check(String(scout.get("name", "")) == "侦察兵", "营救角色名称固定")
	t.check(scout.get("unlock", {}) == {"mission": "ch1_m1", "event": "scout_rescued"}, "侦察兵仅在营救事件后解锁")
	t.check(not mission.has("upload_turns_required") and not mission.has("evac_locked_until_upload"), "主线不再强制上传事故记录")
	t.check(not mission.has("credit_reward") and not mission.has("three_star_turns"), "M1 不携带旧信用点或三星回合规则")

	repo.free()
	t.finish(self)
