extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2EnemyBrain = preload("res://scripts/v2/ai/v2_enemy_brain.gd")
const V2IntentExecutor = preload("res://scripts/v2/ai/v2_intent_executor.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var assault: Unit = _make_unit("player_assault", "assault", "player", Vector2i(2, 2), 7)
	var scout: Unit = _make_unit("player_scout", "scout", "player", Vector2i(1, 5), 5)
	var sentry: Unit = _make_unit("enemy_sentry", "sentry", "enemy", Vector2i(5, 2), 4)
	var drone: Unit = _make_unit("enemy_drone", "drone", "enemy", Vector2i(6, 5), 3)
	var sniper: Unit = _make_unit("enemy_sniper", "sniper_sentry", "enemy", Vector2i(8, 2), 3)
	var guard: Unit = _make_unit("enemy_guard", "shield_guard", "enemy", Vector2i(5, 5), 6)
	var engineer: Unit = _make_unit("enemy_engineer", "protocol_engineer", "enemy", Vector2i(7, 7), 4)
	var terminal := {"id": "relay_terminal", "position": Vector2i(8, 7), "operable": true, "owner": "player"}
	var context := {
		"state_revision": 9,
		"turn": 3,
		"players": [assault, scout],
		"enemies": [sentry, drone, sniper, guard, engineer],
		"facilities": [terminal],
		"enemy_profiles": {
			"sentry": {"attack_range": [1, 5], "damage": 2},
			"drone": {"attack_range": [1, 3], "damage": 1, "scan_radius": 3},
			"sniper_sentry": {"attack_range": [3, 8], "damage": 3},
			"shield_guard": {"attack_range": [1, 3], "damage": 2},
			"protocol_engineer": {"attack_range": [1, 4], "damage": 1},
		},
	}

	var sentry_intent: Dictionary = V2EnemyBrain.plan_intent(sentry, context)
	t.check(sentry_intent.get("type", &"") in [&"move", &"attack"], "哨兵巡逻或攻击")
	t.check(sentry_intent.get("enemy_id", "") == "enemy_sentry", "哨兵意图绑定稳定 ID")

	var drone_intent: Dictionary = V2EnemyBrain.plan_intent(drone, context)
	t.check(drone_intent.get("type", &"") == &"scan", "无人机优先扫描")
	t.check(int(drone_intent.get("radius", 0)) == 3, "无人机扫描半径来自职责数据")

	var sniper_intent: Dictionary = V2EnemyBrain.plan_intent(sniper, context)
	t.check(sniper_intent.get("telegraph", &"") == &"charge_line", "狙击蓄力一回合")
	t.check(sniper_intent.get("type", &"") == &"telegraph", "狙击蓄力先生成可见预告")

	var guard_intent: Dictionary = V2EnemyBrain.plan_intent(guard, context)
	t.check(guard_intent.get("type", &"") == &"protect", "盾卫保护高优先单位")
	t.check(guard_intent.get("target_id", "") == "enemy_sentry", "盾卫保护稳定目标")

	var engineer_intent: Dictionary = V2EnemyBrain.plan_intent(engineer, context)
	t.check(engineer_intent.get("type", &"") == &"operate", "工程师操作具名设施")
	t.check(engineer_intent.get("facility_id", "") == "relay_terminal", "工程师意图绑定设施 ID")

	var first_json := JSON.stringify(sentry_intent)
	var deterministic := true
	for _i in range(100):
		if JSON.stringify(V2EnemyBrain.plan_intent(sentry, context)) != first_json:
			deterministic = false
	t.check(deterministic, "相同敌人状态一百次意图完全一致")
	t.check(sentry_intent.get("revision", -1) == 9, "意图携带状态版本")

	var blocked_attack := {
		"enemy_id": "enemy_sentry",
		"type": "attack",
		"target_id": "player_assault",
		"target_cell": Vector2i(2, 2),
		"path": [],
		"damage": 2,
		"telegraph": "",
		"revision": 9,
	}
	var blocked_context := context.duplicate(true)
	blocked_context["blocked_attacks"] = ["enemy_sentry"]
	var fallback: Dictionary = V2IntentExecutor.execute(blocked_attack, blocked_context)
	t.check(fallback.get("type", &"") in [&"move", &"guard", &"wait"], "阻断攻击降级为安全后备")
	t.check(int(fallback.get("damage", 0)) == 0, "阻断后备行为不比原意图更致命")

	var stale_context := context.duplicate(true)
	stale_context["state_revision"] = 10
	var stale_result: Dictionary = V2IntentExecutor.execute(blocked_attack, stale_context)
	t.check(stale_result.get("type", &"") in [&"move", &"guard", &"wait"], "陈旧意图不能直接执行攻击")
	t.check(stale_result.get("reason", &"") == &"stale_revision", "陈旧意图返回明确原因")

	var unknown_intent: Dictionary = V2IntentExecutor.execute({"enemy_id": "missing", "type": "attack", "damage": 99}, context)
	t.check(unknown_intent.get("type", &"") in [&"move", &"guard", &"wait"], "未知实体使用安全后备")
	t.check(int(unknown_intent.get("damage", 0)) == 0, "未知实体不产生伤害")

	assault.queue_free()
	scout.queue_free()
	sentry.queue_free()
	drone.queue_free()
	sniper.queue_free()
	guard.queue_free()
	engineer.queue_free()
	t.finish(self)

func _make_unit(id: String, role: String, team: String, position: Vector2i, hp: int):
	var unit = UnitScript.new()
	unit.entity_id = id
	unit.job = role
	unit.team = team
	unit.grid_pos = position
	unit.max_hp = hp
	unit.current_hp = hp
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
