## 数据哨兵生产契约测试
## 直接加载正式战斗场景，验证三阶段、真实护盾、阶段顺序和增援上限。
extends Node

const BattleScene = preload("res://scenes/battle.tscn")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _battle: BattleController = null


func _ready() -> void:
	print("=== 数据哨兵生产契约测试 ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	GameManager.begin_new_game_for_test(0)
	GameManager.current_save.settings.difficulty = "standard"
	GameManager.current_level_id = "ch1_m6"
	_battle = BattleScene.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame

	_test_three_phase_runtime()
	_test_real_shield_absorption_and_regeneration()
	_test_phase_order_and_warning_deduplication()
	_test_reinforcement_cap()
	_test_reinforcement_total_budget()
	_test_death_blocks_phase_transition()

	await _dispose_battle()
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame
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


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _test_three_phase_runtime() -> void:
	print("\n--- 测试: 正式场景加载三阶段 Boss ---")
	_check(_battle.boss_unit != null, "ch1_m6 生成数据哨兵")
	_check(_battle.boss_phases.size() == 3, "数据哨兵具有三个可运行阶段")
	if _battle.boss_unit == null:
		return
	_check(_battle.boss_current_phase == 0, "Boss 从第一阶段开始")
	_check(_battle.boss_unit.max_hp == 300, "标准难度 Boss HP 为 300")
	_check(_battle.boss_unit.weapon_damage == [20, 26], "第一阶段使用独立伤害配置")
	var objective_text := _battle._get_objective_text()
	_check(objective_text.contains("数据哨兵"), "战斗目标常驻显示 Boss 名称")
	_check(objective_text.contains("警戒协议"), "战斗目标常驻显示当前 Boss 阶段")
	_check(objective_text.contains("护盾 50/50"), "战斗目标常驻显示 Boss 护盾")


func _test_real_shield_absorption_and_regeneration() -> void:
	print("\n--- 测试: 护盾是独立伤害吸收层 ---")
	var boss := _battle.boss_unit
	if boss == null:
		_check(false, "Boss 存在，才能验证护盾")
		return
	var has_max_shield := _has_property(boss, &"max_shield")
	var has_current_shield := _has_property(boss, &"current_shield")
	_check(has_max_shield and has_current_shield, "Unit 暴露独立 max_shield/current_shield")
	if not has_max_shield or not has_current_shield:
		return

	_check(boss.max_shield == 50 and boss.current_shield == 50, "Boss 初始护盾为 50/50")
	var hp_before := boss.current_hp
	boss.take_damage(30)
	_check(boss.current_shield == 20, "30 点伤害优先消耗 30 护盾")
	_check(boss.current_hp == hp_before, "护盾未击穿时 HP 不变")
	boss.take_damage(25)
	_check(boss.current_shield == 0, "护盾被击穿后归零")
	_check(boss.current_hp == hp_before - 5, "溢出的 5 点伤害进入 HP")

	var armor_before := boss.armor
	boss.current_shield = 5
	_battle._boss_regen_shield(20)
	_check(boss.current_shield == 25, "护盾恢复增加独立护盾值")
	_check(boss.armor == armor_before, "护盾恢复不会篡改护甲")

	boss.current_hp = boss.max_hp
	boss.current_shield = boss.max_shield
	_battle.hud.update_unit_info(boss)
	_check(_battle.hud.unit_info_label.text.contains("护盾: 50/50"), "HUD 显示 Boss 当前护盾")


func _test_phase_order_and_warning_deduplication() -> void:
	print("\n--- 测试: 跨阈值时按序触发阶段 ---")
	var boss := _battle.boss_unit
	if boss == null or _battle.boss_phases.size() < 3:
		_check(false, "三阶段 Boss 存在，才能验证阶段顺序")
		return

	boss.is_alive = true
	boss.current_hp = 90
	_battle._check_boss_phase_transition(boss)
	_check(_battle.boss_current_phase == 2, "30% HP 进入最终阶段")
	_check(_battle.boss_phase_warned[1], "跨阈值时展示第二阶段预警")
	_check(_battle.boss_phase_warned[2], "跨阈值时展示第三阶段预警")
	_check(boss.weapon_damage == [35, 45], "最终阶段伤害调优为 35-45")
	_check(_battle._get_objective_text().contains("过载协议"), "阶段切换后常驻信息同步到最终阶段")

	var log_count := _battle.hud._log_lines.size()
	_battle._check_boss_phase_transition(boss)
	_check(_battle.hud._log_lines.size() == log_count, "重复检查不会重复展示阶段预警")


func _test_reinforcement_cap() -> void:
	print("\n--- 测试: Boss 召唤服从单位上限 ---")
	var alive_enemies := 0
	for unit in _battle.enemy_units:
		if unit and unit.is_alive:
			alive_enemies += 1
	_battle.enemy_director.enemy_cap_per_wave = alive_enemies
	var count_before := _battle.enemy_units.size()
	_battle._boss_summon_unit("drone_scout", "无人机")
	_check(_battle.enemy_units.size() == count_before, "达到单位上限时不会追加增援")


func _test_reinforcement_total_budget() -> void:
	print("\n--- 测试: Boss 召唤服从全场增援预算 ---")
	_battle.enemy_director.enemy_cap_per_wave = 99
	_battle.enemy_director.max_reinforcements = 0
	_battle.enemy_director.reinforcements_spawned = 0
	var count_before := _battle.enemy_units.size()
	_battle._boss_summon_unit("drone_scout", "无人机")
	_check(_battle.enemy_units.size() == count_before, "耗尽全场增援预算后不会追加增援")
	_check(_battle.enemy_director.reinforcements_spawned == 0, "被拒绝的召唤不消耗预算")


func _test_death_blocks_phase_transition() -> void:
	print("\n--- 测试: Boss 死亡后阶段机停止 ---")
	var boss := _battle.boss_unit
	if boss == null:
		_check(false, "Boss 存在，才能验证死亡保护")
		return
	_battle._apply_boss_phase(boss, 0)
	boss.current_hp = 0
	boss.is_alive = false
	_battle._check_boss_phase_transition(boss)
	_check(_battle.boss_current_phase == 0, "Boss 死亡后不会触发后续阶段")


func _dispose_battle() -> void:
	if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
		GameManager._active_dialogue.free()
	GameManager._active_dialogue = null
	if _battle and is_instance_valid(_battle):
		_battle._cleanup_units()
		_battle.free()
	_battle = null
	await get_tree().process_frame
	await get_tree().physics_frame


func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if not _errors.is_empty():
		print("  失败项:")
		for error in _errors:
			print("    - ", error)
	print("  =================")
