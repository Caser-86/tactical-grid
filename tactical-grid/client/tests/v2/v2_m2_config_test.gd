extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var repo := Repository.new()
	var result := repo.reload_all()
	var mission := repo.get_mission(&"ch1_m2")
	var duration: Array = mission.get("duration_minutes", [])
	var steps: Array = mission.get("objective_steps", [])
	t.check(bool(result.get("success", false)), "M2 数据仓库加载成功")
	t.check(String(mission.get("id", "")) == "ch1_m2", "M2 稳定任务 ID 固定")
	t.check(String(mission.get("map_id", "")) == "ch1_m2_cooling_works_v1", "M2 使用正式锁定地图 ID")
	t.check(mission.get("starting_roster", []) == ["assault", "scout"], "M2 双人小队开场")
	t.check(String(mission.get("rescue_character", "")) == "sniper", "M2 营救狙击手")
	t.check(int(mission.get("deployment_limit", 0)) == 3, "M2 最多部署三名角色")
	t.check(String(mission.get("primary", "")) == "关闭区域封锁并救出狙击手", "M2 主目标文案固定")
	t.check(String(mission.get("optional", "")) == "进入冷却控制室", "冷却控制室为可选目标")
	t.check(int(mission.get("enemy_total", 0)) == 13 and int(mission.get("active_cap", 0)) == 3, "十三敌编制且同时最多三敌")
	t.check(duration.size() == 2 and int(duration[0]) == 25 and int(duration[1]) == 30, "首次时长目标固定为 25 到 30 分钟")
	t.check(steps.size() == 4, "M2 采用四阶段正式目标流程")
	var ids := []
	for step in steps:
		ids.append(String(step.get("id", "")))
	t.check(ids == ["disable_lockdown", "rescue_sniper", "show_sniper_ability", "evacuate_squad"], "M2 阶段顺序固定")
	t.check(String(mission.get("rescue_recovery_hp", "")) == "", "M2 不复用 M1 营救回血字段")
	repo.free()
	t.finish(self)
