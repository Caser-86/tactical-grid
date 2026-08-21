extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Encounter = preload("res://scripts/v2/mission/v2_encounter_activation.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const TurnManagerScript = preload("res://scripts/game/turn_manager.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	_run_mission("ch1_m1")
	_run_mission("ch1_m2")
	t.finish(self)

func _run_mission(mission_id: String) -> void:
	var map_result := MapLoader.load_map(StringName(mission_id))
	var mission := _load_mission(mission_id)
	t.check(bool(map_result.get("success", false)) and not mission.is_empty(), "%s 稳定性测试加载正式内容" % mission_id)
	if not bool(map_result.get("success", false)) or mission.is_empty():
		return
	var map: Dictionary = map_result.get("data", {})
	var assault := _unit("stability_assault_%s" % mission_id, Vector2i(3, 3))
	var players: Array = [assault]
	var flow := Flow.new()
	var configured := mission.duplicate(true)
	if mission_id == "ch1_m1":
		configured["expanded_flow"] = true
	flow.setup(configured, map, players, [])
	flow.apply_event(&"mission_started")
	var encounters := Encounter.new()
	encounters.setup(map)
	encounters.update([assault.grid_pos], [])
	var turn_manager: TurnManager = TurnManagerScript.new()
	turn_manager.setup(players, [], 100)
	turn_manager.start_battle()
	var baseline := flow.get_snapshot()
	for iteration in range(20):
		var previous_turn := turn_manager.turn_number
		turn_manager.end_player_turn()
		turn_manager.end_enemy_turn()
		t.check(turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION and turn_manager.turn_number == previous_turn + 1, "%s 第 %d 次结束回合后恢复玩家阶段" % [mission_id, iteration + 1])
		var snapshot := flow.get_snapshot()
		t.check(not snapshot.is_empty() and not String(snapshot.get("guide_text", "")).is_empty(), "%s 第 %d 次 HUD 快照非空" % [mission_id, iteration + 1])
		var restored := flow.restore_snapshot(snapshot)
		t.check(bool(restored.get("success", false)) and flow.get_current_step_id() == snapshot.get("step_id", ""), "%s 第 %d 次保存恢复保持任务阶段" % [mission_id, iteration + 1])
		var positions := {}
		for unit in players:
			var key := "%d,%d" % [unit.grid_pos.x, unit.grid_pos.y]
			positions[key] = int(positions.get(key, 0)) + 1
		t.check(positions.size() == players.size(), "%s 第 %d 次单位坐标唯一" % [mission_id, iteration + 1])
		var encounter_snapshot := encounters.get_snapshot()
		t.check(_state_sets_are_disjoint(encounter_snapshot), "%s 第 %d 次 active/waiting/defeated 集合互斥" % [mission_id, iteration + 1])
		if iteration % 2 == 0:
			var failed := flow.apply_event(&"primary_irreversible_failure")
			t.check(bool(failed.get("defeat", false)), "%s 第 %d 次失败重试入口可达" % [mission_id, iteration + 1])
			var retry := flow.restore_snapshot(baseline)
			t.check(bool(retry.get("success", false)) and not flow.is_defeat(), "%s 第 %d 次恢复检查点清除失败状态" % [mission_id, iteration + 1])
	for unit in players:
		if unit != null and is_instance_valid(unit):
			unit.free()
	if turn_manager != null and is_instance_valid(turn_manager):
		turn_manager.free()

func _state_sets_are_disjoint(snapshot: Dictionary) -> bool:
	var seen := {}
	for key in ["active_ids", "waiting_ids", "defeated_ids"]:
		for raw_id in snapshot.get(key, []):
			var entity_id := String(raw_id)
			if seen.has(entity_id):
				return false
			seen[entity_id] = true
	return true

func _load_mission(id: String) -> Dictionary:
	var file := FileAccess.open("res://data/v2/missions.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.get(id, {}) if parsed is Dictionary else {}

func _unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.grid_pos = position
	unit.team = "player"
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	unit.begin_v2_turn()
	return unit
