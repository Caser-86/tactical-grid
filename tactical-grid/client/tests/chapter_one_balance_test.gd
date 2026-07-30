## 第一章平衡目标契约
## 验证六关节奏、三难度 Boss 数值、经济可行性和两套基础队伍输出窗口。
extends Node

const BALANCE_PATH := "res://data/chapter1_playtest_matrix.json"
const MAP_ROOT := "res://data/locked_maps/"

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _matrix: Dictionary = {}


func _ready() -> void:
	print("=== 第一章平衡目标契约测试 ===")
	_load_matrix()
	_test_level_pacing()
	_test_difficulty_matrix()
	_test_boss_scaling()
	_test_economy_viability()
	_test_two_baseline_teams()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)


func _load_matrix() -> void:
	_check(FileAccess.file_exists(BALANCE_PATH), "平衡矩阵文件存在")
	if not FileAccess.file_exists(BALANCE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	_check(parsed is Dictionary, "平衡矩阵是有效 JSON 对象")
	if parsed is Dictionary:
		_matrix = parsed
	_check(_matrix.get("evidence_status", "") == "automated_contract_targets", "矩阵明确标记为自动契约目标，不冒充人工试玩")


func _test_level_pacing() -> void:
	print("\n--- 测试: 六关节奏递进 ---")
	var expected_turn_limits := [18, 16, 17, 18, 19, 22]
	var expected_three_star := [11, 10, 11, 12, 13, 16]
	var expected_enemy_counts := [5, 5, 5, 5, 5, 6]
	var expected_reinforcement_budgets := [3, 1, 1, 1, 1, 4]
	var previous_turn_limit := 0
	for index in range(6):
		var level_id := "ch1_m%d" % (index + 1)
		var level := CampaignRepository.get_level(level_id)
		_check(int(level.get("max_turns", 0)) == expected_turn_limits[index], "%s 标准回合上限=%d" % [level_id, expected_turn_limits[index]])
		_check(int(level.get("three_star_turns", 0)) == expected_three_star[index], "%s 三星目标=%d回合" % [level_id, expected_three_star[index]])
		_check(int(level.get("max_reinforcements", -1)) == expected_reinforcement_budgets[index], "%s 增援预算=%d" % [level_id, expected_reinforcement_budgets[index]])
		if index >= 2:
			_check(int(level.get("max_turns", 0)) >= previous_turn_limit, "%s 回合空间不低于前一关" % level_id)
		previous_turn_limit = int(level.get("max_turns", 0))

		var map_path := MAP_ROOT + level_id + ".json"
		var map_data = JSON.parse_string(FileAccess.get_file_as_string(map_path))
		var enemy_count := 0
		if map_data is Dictionary:
			for object in map_data.get("objects", []):
				if object.get("type", "") == "spawn_enemy":
					enemy_count += 1
		_check(enemy_count == expected_enemy_counts[index], "%s 正式地图敌军数量=%d" % [level_id, expected_enemy_counts[index]])
		_check(int(level.get("enemy_count", 0)) == enemy_count, "%s 配置与正式地图敌军数量一致" % level_id)


func _test_difficulty_matrix() -> void:
	print("\n--- 测试: 三难度 18 个目标样本 ---")
	var cases: Array = _matrix.get("mission_targets", [])
	_check(cases.size() == 18, "六关 x 三难度共 18 个目标样本")
	var expected_bonuses := {"story": 5, "standard": 0, "hard": -3}
	for difficulty in expected_bonuses:
		for mission_number in range(1, 7):
			var level_id := "ch1_m%d" % mission_number
			var matches := cases.filter(func(entry):
				return entry.get("level_id", "") == level_id and entry.get("difficulty", "") == difficulty
			)
			_check(matches.size() == 1, "%s/%s 有且仅有一个目标样本" % [level_id, difficulty])
			if matches.size() != 1:
				continue
			var base_turns := int(CampaignRepository.get_level(level_id).get("max_turns", 20))
			var expected_budget: int = maxi(5, base_turns + expected_bonuses[difficulty])
			_check(int(matches[0].get("turn_budget", 0)) == expected_budget, "%s/%s 回合预算=%d" % [level_id, difficulty, expected_budget])
			_check(float(matches[0].get("target_survival_rate", 0.0)) >= 0.5, "%s/%s 目标存活率有正式下限" % [level_id, difficulty])


func _test_boss_scaling() -> void:
	print("\n--- 测试: Boss 三难度缩放 ---")
	var original_settings: Dictionary = GameManager.current_save.get("settings", {}).duplicate(true)
	var boss_data := GameData.get_boss("data_sentinel")
	var expected := {
		"story": {"hp": 240, "shield": 40, "damage": [16, 21]},
		"standard": {"hp": 300, "shield": 50, "damage": [20, 26]},
		"hard": {"hp": 375, "shield": 63, "damage": [24, 31]},
	}
	for difficulty in ["story", "standard", "hard"]:
		GameManager.current_save.settings.difficulty = difficulty
		var controller := BattleController.new()
		var boss := Unit.new()
		controller._apply_boss_stats(boss, boss_data)
		_check(boss.max_hp == expected[difficulty].hp, "Boss[%s] HP=%d" % [difficulty, expected[difficulty].hp])
		_check(boss.max_shield == expected[difficulty].shield, "Boss[%s] 护盾=%d" % [difficulty, expected[difficulty].shield])
		_check(boss.weapon_damage == expected[difficulty].damage, "Boss[%s] 第一阶段伤害=%s" % [difficulty, expected[difficulty].damage])
		boss.free()
		controller.free()
	GameManager.current_save.settings = original_settings


func _test_economy_viability() -> void:
	print("\n--- 测试: 首章经济不会断档 ---")
	var expected_credit_before_boss := {
		"story": 3990,
		"standard": 3600,
		"hard": 3406,
	}
	var reward_multipliers := {"story": 1.3, "standard": 1.0, "hard": 0.85}
	for difficulty in reward_multipliers:
		var credits := 500
		for mission_number in range(1, 6):
			var level := CampaignRepository.get_level("ch1_m%d" % mission_number)
			var rewards: Dictionary = level.get("rewards", {})
			credits += int(round(int(rewards.get("credit", 0)) * float(reward_multipliers[difficulty])))
			credits += int(rewards.get("first_clear", {}).get("credit", 0))
		_check(credits == expected_credit_before_boss[difficulty], "%s 难度 Boss 前总信用点=%d" % [difficulty, expected_credit_before_boss[difficulty]])
		_check(credits >= 900, "%s 难度可负担两件常见武器和五个消耗品" % difficulty)


func _test_two_baseline_teams() -> void:
	print("\n--- 测试: 两套基础队伍均可对抗 Boss ---")
	var teams: Array = _matrix.get("boss_baseline_teams", [])
	_check(teams.size() >= 2, "矩阵至少提供两套 Boss 基础队伍")
	for team in teams:
		var weapons: Array = team.get("weapons", [])
		_check(weapons.size() == 4, "%s 使用四人编制" % team.get("id", "team"))
		var no_crit_round_damage := 0
		for weapon_id in weapons:
			var weapon := GameData.get_weapon(weapon_id)
			_check(not weapon.is_empty(), "%s 武器 %s 存在" % [team.get("id", "team"), weapon_id])
			if weapon.is_empty():
				continue
			var damage: Array = weapon.get("damage", [0, 0])
			var effective := maxi(1, int((int(damage[0]) + int(damage[1])) / 2.0) - 15)
			if weapon.get("special", "") == "double_tap":
				effective *= 2
			no_crit_round_damage += effective
		_check(no_crit_round_damage >= 90, "%s 无暴击单轮理论伤害达到 90" % team.get("id", "team"))
		_check(no_crit_round_damage <= 130, "%s 不会一轮跳过全部 Boss 阶段" % team.get("id", "team"))


func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if not _errors.is_empty():
		print("  失败项:")
		for error in _errors:
			print("    - ", error)
	print("  =================")
