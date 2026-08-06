extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const Bridge = preload("res://scripts/v2/mission/v2_mission_event_bridge.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const TurnManagerScript = preload("res://scripts/game/turn_manager.gd")

var t := Runner.new()

func _initialize() -> void:
	var mission := {
		"id": "ch1_m1",
		"rescue_character": "scout",
		"objective_steps": [
			{"id": "search_scout", "complete_event": "character_rescued", "required_flags": []},
			{"id": "escort_scout", "complete_event": "evac_checked", "required_flags": ["scout_rescued"]},
			{"id": "evacuate", "complete_event": "mission_completed", "required_flags": ["scout_rescued"]},
		],
	}
	var map := {"entities": [{"id": "evac_northeast", "type": "evac", "x": 19, "y": 2, "radius": 1}]}
	var assault := _unit("assault_1", Vector2i(19, 2))
	var scout := _unit("player_scout", Vector2i(16, 2))
	var flow := Flow.new()
	flow.setup(mission, map, [assault], [])
	var turn_manager := TurnManagerScript.new()
	turn_manager.setup([assault], [], 3)
	turn_manager.set_victory_check(Callable(flow, "is_victory"))
	turn_manager.start_battle()

	var rescue_result: Dictionary = flow.apply_event(&"character_rescued", {
		"character_id": "scout",
		"unit": scout,
	})
	t.check(bool(rescue_result.get("success", false)), "桥接回归先接受 M1 营救事件")

	var bridge := Bridge.new()
	var not_ready: Dictionary = bridge.apply_event(flow, &"evac_checked")
	t.check(not bool(not_ready.get("success", true)) and not flow.is_victory(), "并非所有清醒队员在撤离区时不自动完成")

	scout.grid_pos = Vector2i(19, 2)
	flow.apply_event(&"unit_moved", {"unit": scout, "unit_id": scout.entity_id, "position": scout.grid_pos})
	var completed: Dictionary = bridge.apply_event(flow, &"evac_checked")
	if bool(completed.get("victory", false)) and not turn_manager.battle_over:
		turn_manager._end_battle(true)
	t.check(bool(completed.get("success", false)) and bool(completed.get("victory", false)), "实际 M1 撤离桥接提交配置化最终事件并胜利")
	t.check(flow.get_snapshot().get("event_count", 0) == 5, "桥接只记录一次 evac_checked 和一次 mission_completed")
	t.check(turn_manager.battle_over and turn_manager.current_phase == TurnManagerScript.TurnPhase.BATTLE_OVER, "胜利结果完成 TurnManager")

	var duplicate: Dictionary = bridge.apply_event(flow, &"evac_checked")
	t.check(not bool(duplicate.get("success", true)) and not bool(duplicate.get("final_event_submitted", false)), "重复撤离检查不重复提交最终事件")
	t.check(flow.get_snapshot().get("event_count", 0) == 6, "重复检查只记录自身且不重复 mission_completed")

	var legacy_flow := Flow.new()
	var legacy_assault := _unit("legacy_assault", Vector2i(19, 2))
	var legacy_scout := _unit("legacy_scout", Vector2i(19, 2))
	legacy_flow.setup({"id": "ch1_m1", "rescue_character": "scout"}, map, [legacy_assault], [])
	legacy_flow.apply_event(&"scout_rescued", {"character_id": "scout", "unit": legacy_scout})
	var legacy_result: Dictionary = bridge.apply_event(legacy_flow, &"evac_checked")
	t.check(bool(legacy_result.get("victory", false)) and not bool(legacy_result.get("final_event_submitted", false)), "旧两阶段任务仍由 evac_checked 直接完成")
	legacy_assault.queue_free()
	legacy_scout.queue_free()
	turn_manager.queue_free()
	assault.queue_free()
	scout.queue_free()
	t.finish(self)

func _unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.grid_pos = position
	unit.is_alive = true
	unit.is_downed = false
	return unit
