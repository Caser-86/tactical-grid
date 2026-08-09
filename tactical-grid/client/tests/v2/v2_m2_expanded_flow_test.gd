extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const Hazard = preload("res://scripts/v2/mission/v2_hazard_controller.gd")
const Interaction = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const VisibilityStateScript = preload("res://scripts/game/visibility_state.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var repo := Repository.new()
	var load_result := repo.reload_all()
	var map_result := MapLoader.load_map(&"ch1_m2")
	t.check(bool(load_result.get("success", false)), "M2 流程测试加载数据仓库")
	t.check(bool(map_result.get("success", false)), "M2 流程测试加载正式地图")
	if not bool(load_result.get("success", false)) or not bool(map_result.get("success", false)):
		t.finish(self)
		return
	var mission: Dictionary = repo.get_mission(&"ch1_m2")
	var map: Dictionary = map_result.get("data", {})
	for route_id in ["west_maintenance", "east_overpass"]:
		_run_route(route_id, mission, map)
	_run_hazard_cycle(map)
	repo.free()
	t.finish(self)

func _run_route(route_id: String, mission: Dictionary, map: Dictionary) -> void:
	var assault := _make_unit("assault_%s" % route_id, Vector2i(3, 17))
	var scout := _make_unit("scout_%s" % route_id, Vector2i(4, 17))
	var players: Array = [assault, scout]
	var flow := Flow.new()
	flow.setup(mission, map, players, [])
	flow.apply_event(&"mission_started")
	var lockdown := flow.apply_event(&"lockdown_cleared", {"route_id": route_id})
	t.check(bool(lockdown.get("success", false)), "%s 解除封锁推进流程" % route_id)
	t.check(flow.get_current_step_id() == "rescue_sniper", "%s 解除封锁后目标为营救狙击手" % route_id)
	var sniper_unit := _make_unit("player_sniper_%s" % route_id, Vector2i(19, 5))
	var rescued := flow.apply_event(&"character_rescued", {
		"character_id": "sniper",
		"new_unit": sniper_unit,
		"unit_id": "player_sniper_%s" % route_id,
		"position": Vector2i(19, 5),
	})
	t.check(bool(rescued.get("success", false)), "%s 营救狙击手推进流程" % route_id)
	t.check(bool(flow.rescued_characters.get("sniper", false)), "%s 写入狙击手营救状态" % route_id)
	var showcase := flow.apply_event(&"sniper_ability_showcase", {"sniper_lines_visible": true})
	t.check(bool(showcase.get("success", false)), "%s 完成狙击手火力教学" % route_id)
	t.check(flow.get_current_step_id() == "evacuate_squad", "%s 火力教学后目标为撤离" % route_id)
	assault.grid_pos = Vector2i(24, 2)
	scout.grid_pos = Vector2i(24, 2)
	sniper_unit.grid_pos = Vector2i(24, 2)
	var countermeasure := flow.apply_event(&"engineer_countermeasure_started", {"enemy_ids": ["m2_sniper_exit", "m2_drone_exit"]})
	t.check(bool(countermeasure.get("success", false)), "%s 记录工程师撤离反制" % route_id)
	var evac := flow.apply_event(&"evac_checked")
	t.check(bool(evac.get("success", false)) and bool(evac.get("victory", false)), "%s 三人抵达撤离区后完成任务" % route_id)
	for unit in players:
		if unit != null and is_instance_valid(unit):
			unit.free()
	if is_instance_valid(sniper_unit):
		sniper_unit.free()

func _run_hazard_cycle(map: Dictionary) -> void:
	var hazards := Hazard.new()
	hazards.setup(map.get("hazards", []), Vector2i(28, 20))
	var warning := hazards.advance_player_turn(2)
	t.check((warning.get("warning_cells", []) as Array).size() == 3, "西侧喷口提前一回合显示三格预警")
	var active := hazards.advance_player_turn(3)
	t.check((active.get("active_cells", []) as Array).size() == 3, "西侧喷口在固定回合生效")
	var damage := hazards.consume_enemy_phase_damage(3)
	t.check(damage.size() == 1 and damage[0].get("damage", 0) == 1, "喷口敌方阶段只结算一次固定伤害")
	var close := hazards.commit_close_action("shutdown_cooling_nozzles")
	t.check(bool(close.get("success", false)) and close.get("closed_now", []).size() == 2, "控制室关闭全部冷却喷口")
	var after_close := hazards.advance_player_turn(7)
	t.check((after_close.get("warning_cells", []) as Array).is_empty() and (after_close.get("active_cells", []) as Array).is_empty(), "关闭喷口后后续周期停止")

func _make_unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = entity_id
	unit.team = "player"
	unit.job = "assault"
	unit.grid_pos = position
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
