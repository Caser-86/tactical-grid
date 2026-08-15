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
	t.check(activation.get_total_enemy_ids().size() == 8, "M1 总敌人数固定为八名")
	var start: Dictionary = activation.update([Vector2i(3, 16)], [])
	t.check(start.get("active_count", 0) == 1, "开场只激活一名教学哨兵")
	t.check(activation.get_active_enemy_ids().has("m1_sentry_south"), "开场激活南区哨兵")
	t.check(not activation.get_active_enemy_ids().has("m1_sentry_rescue"), "营救区敌人开场不激活")

	for enemy_id in start.get("active_ids", []):
		activation.mark_enemy_defeated(String(enemy_id))
	var route: Dictionary = activation.update([Vector2i(15, 8)], [])
	t.check(route.get("active_count", 0) <= 3, "营救路线同时最多三名敌人")
	t.check(activation.get_active_enemy_ids().has("m1_sentry_route") or activation.get_waiting_enemy_ids().has("m1_sentry_route"), "营救路线包含路线哨兵")
	t.check(activation.get_active_enemy_ids().has("m1_drone_route"), "营救路线激活路线无人机")
	t.check(activation.get_active_enemy_ids().has("m1_sentry_rescue") or activation.get_waiting_enemy_ids().has("m1_sentry_rescue"), "营救路线包含营救哨兵")
	t.check(activation.get_active_enemy_ids().has("m1_drone_rescue") or activation.get_waiting_enemy_ids().has("m1_drone_rescue"), "营救路线包含营救无人机")
	t.check(activation.get_waiting_enemy_ids().size() == 1, "超过同时上限的营救敌人排队而非叠在同一格")
	var rescue_ids := ["m1_sentry_route", "m1_drone_route", "m1_sentry_rescue", "m1_drone_rescue"]
	for _i in range(3):
		for enemy_id in activation.get_active_enemy_ids():
			if rescue_ids.has(String(enemy_id)):
				activation.mark_enemy_defeated(String(enemy_id))
		activation.update([Vector2i(15, 8)], [])
	for enemy_id in rescue_ids:
		t.check(activation.get_defeated_enemy_ids().has(enemy_id), "营救路线敌人可按顺序清除：%s" % enemy_id)

	var rescue_activation := Activation.new()
	rescue_activation.setup(loaded.get("data", {}))
	var rescue_start: Dictionary = rescue_activation.update([Vector2i(3, 16)], [])
	for enemy_id in rescue_start.get("active_ids", []):
		rescue_activation.mark_enemy_defeated(String(enemy_id))
	var rescue: Dictionary = rescue_activation.update([Vector2i(15, 8)], [])
	t.check(rescue.get("active_count", 0) <= 3, "进入营救区同时最多三名敌人")
	t.check(rescue_activation.get_active_enemy_ids().has("m1_sentry_route") or rescue_activation.get_waiting_enemy_ids().has("m1_sentry_route"), "进入营救区包含路线哨兵")
	t.check(rescue_activation.get_active_enemy_ids().has("m1_drone_route"), "进入营救区激活路线无人机")
	t.check(not rescue_activation.get_active_enemy_ids().has("m1_shield_evac"), "撤离防线敌人不会提前激活")

	var fresh := Activation.new()
	fresh.setup(loaded.get("data", {}))
	var fresh_start: Dictionary = fresh.update([Vector2i(3, 16)], [])
	for enemy_id in fresh_start.get("active_ids", []):
		fresh.mark_enemy_defeated(String(enemy_id))
	fresh.update([Vector2i(15, 8)], [])
	for _i in range(4):
		for enemy_id in fresh.get_active_enemy_ids():
			fresh.mark_enemy_defeated(String(enemy_id))
		fresh.update([Vector2i(15, 8)], [])
	var evac: Dictionary = fresh.update([Vector2i(20, 4)], [{"event": "pre_evac"}])
	t.check(evac.get("active_count", 0) <= 3, "撤离前同时最多三名敌人")
	t.check(fresh.get_active_enemy_ids().has("m1_shield_evac"), "撤离前激活盾卫")
	t.check(fresh.get_active_enemy_ids().has("m1_sentry_evac"), "撤离前激活撤离哨兵")
	t.check(fresh.get_active_enemy_ids().has("m1_drone_evac"), "撤离前激活撤离无人机")

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
