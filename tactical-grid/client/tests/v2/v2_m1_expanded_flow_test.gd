extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	for route_id in ["camera_maintenance", "cargo_breakthrough"]:
		_run_route(route_id)
	t.finish(self)

func _run_route(route_id: String) -> void:
	var map := {
		"entities": [
			{"id": "rescue_scout", "type": "objective_primary", "x": 16, "y": 8},
			{"id": "evac_northeast", "type": "evac", "x": 23, "y": 2, "radius": 1},
		],
	}
	var mission := {
		"id": "ch1_m1",
		"rescue_character": "scout",
		"expanded_flow": true,
		"expanded_objective_steps": [
			{"id": "search_route_split", "objective_text": "抵达路线分叉", "complete_event": "entered_route_split", "required_flags": []},
			{"id": "select_route", "objective_text": "选择推进路线", "complete_event": "route_selected", "required_flags": []},
			{"id": "operate_gantry", "objective_text": "放下吊桥", "complete_event": "gantry_lowered", "required_flags": ["route_selected"]},
			{"id": "rescue_scout", "objective_text": "营救失联侦察兵", "complete_event": "character_rescued", "required_flags": ["route_selected", "gantry_lowered"]},
			{"id": "evacuate_squad", "objective_text": "带小队撤离", "complete_event": "evac_checked", "required_flags": ["scout_rescued", "gantry_lowered"]},
		],
	}
	var assault := _unit("assault_%s" % route_id, Vector2i(3, 16))
	var flow := Flow.new()
	flow.setup(mission, map, [assault], [])
	t.check(flow.get_current_step_id() == "search_route_split", "%s 从路线分叉目标开始" % route_id)
	var entered := flow.apply_event(&"entered_route_split", {"position": Vector2i(8, 14)})
	t.check(bool(entered.get("success", false)) and flow.get_current_step_id() == "select_route", "%s 进入分叉后更新目标" % route_id)
	var selected := flow.apply_event(&"route_selected", {"route_id": route_id})
	t.check(bool(selected.get("success", false)) and selected.get("route_id", "") == route_id, "%s 路线选择写入任务流" % route_id)
	t.check(flow.get_current_step_id() == "operate_gantry", "%s 路线选择后目标为吊桥" % route_id)
	var gantry := flow.apply_event(&"gantry_lowered", {"route_id": "gantry_bridge", "map_changes": [[14, 5], [15, 5]]})
	t.check(bool(gantry.get("success", false)) and flow.get_current_step_id() == "rescue_scout", "%s 吊桥完成后目标为营救" % route_id)
	var scout := _unit("scout_%s" % route_id, Vector2i(16, 8))
	var rescued := flow.apply_event(&"character_rescued", {"character_id": "scout", "unit": scout})
	t.check(bool(rescued.get("success", false)) and flow.get_current_step_id() == "evacuate_squad", "%s 营救后目标为撤离" % route_id)
	var intercept := flow.apply_event(&"evac_intercept_started", {"enemy_ids": ["m1_sniper_evac_a", "m1_sniper_evac_b"]})
	t.check(bool(intercept.get("success", false)) and bool(intercept.get("evac_intercept_started", false)), "%s 撤离反制事件可记录" % route_id)
	assault.grid_pos = Vector2i(23, 2)
	scout.grid_pos = Vector2i(23, 2)
	flow.apply_event(&"unit_moved", {"unit": assault, "unit_id": assault.entity_id, "position": assault.grid_pos})
	flow.apply_event(&"unit_moved", {"unit": scout, "unit_id": scout.entity_id, "position": scout.grid_pos})
	var evacuated := flow.apply_event(&"evac_checked")
	t.check(bool(evacuated.get("success", false)) and bool(evacuated.get("victory", false)), "%s 两人撤离后完成任务" % route_id)
	t.check(flow.is_victory() and not flow.is_defeat(), "%s 结算状态为胜利" % route_id)
	assault.free()
	scout.free()

func _unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = entity_id
	unit.team = "player"
	unit.job = "assault"
	unit.grid_pos = position
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
