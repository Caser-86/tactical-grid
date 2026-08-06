extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Activation = preload("res://scripts/v2/mission/v2_encounter_activation.gd")
const EnemyBrain = preload("res://scripts/v2/ai/v2_enemy_brain.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")

var t := Runner.new()

func _initialize() -> void:
	var loaded: Dictionary = MapLoader.load_map(&"ch1_m1")
	t.check(bool(loaded.get("success", false)), "M1 激活测试加载锁定地图")
	if not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var activation := Activation.new()
	activation.setup(loaded.get("data", {}))
	t.check(activation.get_total_enemy_ids().size() == 6, "M1 总敌人数固定为六名")
	var start: Dictionary = activation.update([Vector2i(3, 14)], [])
	t.check(start.get("active_count", 0) == 2, "开场只激活南区两名敌人")
	t.check(activation.get_active_enemy_ids().has("enemy_sentry_south"), "开场激活南区哨兵")
	t.check(activation.get_active_enemy_ids().has("enemy_drone_south"), "开场激活南区无人机")
	t.check(not activation.get_active_enemy_ids().has("enemy_sentry_rescue"), "营救区敌人开场不激活")

	var rescue: Dictionary = activation.update([Vector2i(12, 8)], [])
	t.check(rescue.get("active_count", 0) <= 3, "进入营救区同时最多三名敌人")
	t.check(activation.get_active_enemy_ids().has("enemy_sentry_rescue"), "进入营救区激活营救哨兵")
	t.check(activation.get_active_enemy_ids().has("enemy_drone_rescue"), "进入营救区激活营救无人机")
	t.check(not activation.get_active_enemy_ids().has("enemy_sentry_record"), "未进入记录路线不激活记录哨兵")

	var record: Dictionary = activation.update([Vector2i(4, 4)], [])
	t.check(record.get("active_count", 0) <= 3, "进入记录路线同时最多三名敌人")
	t.check(record.get("active_count", 0) == 1, "记录路线只激活一名哨兵")
	t.check(activation.get_active_enemy_ids() == ["enemy_sentry_record"], "记录路线替换南区巡逻")

	var fresh := Activation.new()
	fresh.setup(loaded.get("data", {}))
	fresh.update([Vector2i(3, 14)], [])
	fresh.update([Vector2i(13, 7)], [&"scout_rescued"])
	var evac: Dictionary = fresh.update([Vector2i(16, 5)], [&"scout_rescued"])
	t.check(evac.get("active_count", 0) <= 3, "撤离前同时最多三名敌人")
	t.check(fresh.get_active_enemy_ids().has("enemy_sentry_evac"), "撤离前激活拦截哨兵")

	var sentry := _make_enemy("sentry", "sentry_test", Vector2i(8, 12))
	var player := _make_player("player_test", Vector2i(8, 13))
	var sentry_intent: Dictionary = EnemyBrain.plan_intent(sentry, {"players": [player], "state_revision": 1})
	t.check(sentry_intent.get("type", "") == &"attack", "哨兵近距离优先攻击")
	var drone := _make_enemy("drone", "drone_test", Vector2i(10, 10))
	var drone_intent: Dictionary = EnemyBrain.plan_intent(drone, {"players": [player], "state_revision": 1})
	t.check(drone_intent.get("type", "") == &"scan", "无人机优先扫描")
	t.check(int(drone_intent.get("radius", 0)) == 3, "无人机扫描半径来自职责数据")

	for unit in [sentry, player, drone]:
		unit.free()
	t.finish(self)

func _make_enemy(job: String, entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.job = job
	unit.entity_id = entity_id
	unit.unit_name = job
	unit.team = "enemy"
	unit.grid_pos = position
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit

func _make_player(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.job = "assault"
	unit.entity_id = entity_id
	unit.unit_name = "突击兵"
	unit.team = "player"
	unit.grid_pos = position
	unit.is_alive = true
	return unit
