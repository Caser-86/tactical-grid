extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2EnemyBrain = preload("res://scripts/v2/ai/v2_enemy_brain.gd")
const V2IntentExecutor = preload("res://scripts/v2/ai/v2_intent_executor.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var assault: Unit = _make_unit("player_assault", "assault", "player", Vector2i(2, 2), 7)
	var sentry: Unit = _make_unit("enemy_sentry", "sentry", "enemy", Vector2i(5, 2), 4)
	var context := _context([assault], [sentry])

	var attack := V2EnemyBrain.plan_intent(sentry, context)
	t.check(attack.get("type", &"") == &"attack", "哨兵拥有合法射界时直接攻击")
	t.check(attack.has_all(["enemy_id", "revision", "target_id", "target_cell", "path", "damage", "telegraph", "fallback_reason"]), "所有策略携带统一意图字段")

	var blocked_context := context.duplicate(true)
	blocked_context["los_check"] = Callable(self, "_no_line_of_sight")
	var blocked := V2EnemyBrain.plan_intent(sentry, blocked_context)
	t.check(blocked.get("type", &"") == &"guard", "哨兵没有射界时原地守候而非无脑追击")
	t.check(blocked.get("fallback_reason", &"") == &"no_legal_firing_line", "哨兵守候原因可读")

	var line_target: Unit = _make_unit("player_line_target", "assault", "player", Vector2i(1, 5), 7)
	var line_sentry: Unit = _make_unit("enemy_line_sentry", "sentry", "enemy", Vector2i(5, 5), 4)
	var line_context := _context([line_target], [line_sentry])
	line_context["los_check"] = Callable(self, "_line_only_from_left")
	var line_intent := V2EnemyBrain.plan_intent(line_sentry, line_context)
	t.check(line_intent.get("type", &"") == &"move", "哨兵会换位寻找射界")
	t.check(line_intent.get("target_cell", Vector2i(-1, -1)) == Vector2i(4, 5), "哨兵换位只选择合法相邻格")

	var drone: Unit = _make_unit("enemy_drone", "drone", "enemy", Vector2i(6, 5), 3)
	var drone_context := _context([assault], [drone])
	drone_context["scan_targets"] = [
		{"id": "low_value", "cell": Vector2i(7, 5), "priority": 1},
		{"id": "high_value", "cell": Vector2i(1, 1), "priority": 5},
	]
	var drone_intent := V2EnemyBrain.plan_intent(drone, drone_context)
	t.check(drone_intent.get("type", &"") == &"scan", "无人机默认扫描而非进入攻击职责")
	t.check(drone_intent.get("target_cell", Vector2i(-1, -1)) == Vector2i(1, 1), "无人机优先扫描高价值目标")
	t.check(drone_intent.get("telegraph", &"") == &"scan_pulse", "无人机扫描带有可读预告")

	var guard: Unit = _make_unit("enemy_guard", "shield_guard", "enemy", Vector2i(5, 5), 6)
	var protected_sentry: Unit = _make_unit("enemy_protected_sentry", "sentry", "enemy", Vector2i(6, 5), 4)
	var guard_context := _context([assault], [guard, protected_sentry])
	var protect_intent := V2EnemyBrain.plan_intent(guard, guard_context)
	t.check(protect_intent.get("type", &"") == &"protect", "盾卫优先保护队友")
	t.check(protect_intent.get("target_id", "") == "enemy_protected_sentry", "盾卫保护目标稳定可预测")
	t.check(int(protect_intent.get("protect_reduction", 0)) == 1, "盾卫携带保护减伤值")

	var solo_guard: Unit = _make_unit("enemy_solo_guard", "shield_guard", "enemy", Vector2i(5, 5), 6)
	var choke_context := _context([], [solo_guard])
	choke_context["choke_cells"] = [Vector2i(4, 5)]
	var choke_intent := V2EnemyBrain.plan_intent(solo_guard, choke_context)
	t.check(choke_intent.get("type", &"") == &"move", "无保护目标时盾卫卡住指定窄口")
	t.check(choke_intent.get("target_cell", Vector2i(-1, -1)) == Vector2i(4, 5), "盾卫卡位不穿过阻挡或单位")

	var invalid_scan := {
		"enemy_id": "enemy_drone",
		"type": "scan",
		"target_cell": Vector2i(9, 9),
		"radius": 3,
		"revision": 9,
	}
	var invalid_scan_context := _context([assault], [drone])
	invalid_scan_context["blocked_cells"] = [Vector2i(9, 9)]
	var scan_result := V2IntentExecutor.execute(invalid_scan, invalid_scan_context)
	t.check(not bool(scan_result.get("success", true)), "扫描提交阶段拒绝被阻挡的目标格")
	t.check(scan_result.get("fallback_reason", &"") == &"invalid_scan_cell", "扫描失效原因明确")
	t.check(int(scan_result.get("fallback_revision", 0)) == 10, "扫描失效推进下一次意图版本")
	t.check(int(scan_result.get("damage", 0)) == 0, "扫描失效不产生伤害")

	var stale_protect := {
		"enemy_id": "enemy_guard",
		"type": "protect",
		"target_id": "enemy_protected_sentry",
		"target_cell": Vector2i(99, 99),
		"protect_reduction": 1,
		"revision": 9,
	}
	var protect_result := V2IntentExecutor.execute(stale_protect, guard_context)
	t.check(not bool(protect_result.get("success", true)), "保护提交阶段拒绝移动后的旧目标")
	t.check(protect_result.get("fallback_reason", &"") == &"stale_protect_target", "保护失效原因明确")
	t.check(int(protect_result.get("damage", 0)) == 0, "保护失效不产生伤害")

	var data_file := FileAccess.open("res://data/v2/enemies.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(data_file.get_as_text())
	t.check(String(data["sentry"].get("strategy", "")) == "sentry", "敌人数据声明哨兵策略")
	t.check(String(data["drone"].get("strategy", "")) == "drone", "敌人数据声明无人机策略")
	t.check(String(data["shield_guard"].get("strategy", "")) == "shield_guard", "敌人数据声明盾卫策略")

	for unit in [assault, sentry, line_target, line_sentry, drone, guard, protected_sentry, solo_guard]:
		unit.queue_free()
	t.finish(self)

func _context(players: Array, enemies: Array) -> Dictionary:
	return {
		"state_revision": 9,
		"players": players,
		"enemies": enemies,
		"enemy_profiles": {
			"sentry": {"attack_range": [1, 5], "damage": 2},
			"drone": {"attack_range": [1, 3], "damage": 1, "scan_radius": 3},
			"shield_guard": {"attack_range": [1, 3], "damage": 2, "protect_reduction": 1},
		},
		"map_size": Vector2i(12, 10),
		"blocked_cells": [],
	}

func _make_unit(id: String, role: String, team: String, position: Vector2i, hp: int) -> Unit:
	var unit := UnitScript.new()
	unit.entity_id = id
	unit.job = role
	unit.team = team
	unit.grid_pos = position
	unit.max_hp = hp
	unit.current_hp = hp
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit

func _no_line_of_sight(_from: Vector2i, _to: Vector2i) -> bool:
	return false

func _line_only_from_left(from: Vector2i, _to: Vector2i) -> bool:
	return from == Vector2i(4, 5)
