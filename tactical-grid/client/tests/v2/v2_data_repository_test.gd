extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var repo := Repository.new()
	var result := repo.reload_all()
	var role_ids: Array[StringName] = [&"assault", &"scout", &"sniper", &"heavy"]
	var all_roles_present := true
	for id in role_ids:
		if repo.get_character(id).is_empty():
			all_roles_present = false
	t.check(bool(result.get("success", false)), "六份 V2 数据通过模式校验")
	t.check(all_roles_present, "四名角色齐全")
	t.check(int(repo.get_character(&"assault").get("hp", 0)) == 7, "突击兵 HP 基线为 7")
	t.check(int(repo.get_enemy(&"sentry").get("damage", 0)) == 2, "哨兵伤害基线为 2")
	t.check(repo.get_mission(&"ch1_m6").get("boss_id", "") == "data_sentinel", "M6 引用数据哨兵")
	repo.free()
	t.finish(self)
