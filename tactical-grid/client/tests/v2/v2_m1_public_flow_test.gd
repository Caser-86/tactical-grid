extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const Interaction = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Rescue = preload("res://scripts/v2/mission/v2_rescue_controller.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var mission := _load_mission("ch1_m1")
	var loaded := MapLoader.load_map(&"ch1_m1")
	t.check(not mission.is_empty() and bool(loaded.get("success", false)), "M1 公开流程加载正式任务和锁定地图")
	if mission.is_empty() or not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	for route_id in ["camera_maintenance", "cargo_breakthrough"]:
		_run_route(route_id, mission, map)
	t.finish(self)

func _run_route(route_id: String, source_mission: Dictionary, map: Dictionary) -> void:
	var mission := source_mission.duplicate(true)
	mission["expanded_flow"] = true
	var operator := _unit("m1_operator_%s" % route_id, Vector2i(13, 5), "player")
	var assault := _unit("m1_assault_%s" % route_id, Vector2i(8, 14), "player")
	var players: Array = [assault]
	var flow := Flow.new()
	flow.setup(mission, map, players, [])
	flow.apply_event(&"mission_started")
	var interaction := Interaction.new()
	interaction.setup(map, null, null, null, flow)
	var action_service := ActionService.new()
	action_service.setup(map, players, [])

	var entered := flow.apply_event(&"entered_route_split", {"position": assault.grid_pos})
	t.check(bool(entered.get("success", false)) and flow.get_current_step_id() == "select_route", "%s 到达路线分叉并更新目标" % route_id)
	var route_result := interaction.select_route(route_id)
	t.check(bool(route_result.get("success", false)) and interaction.get_selected_route_id() == route_id, "%s 通过公开路线服务完成路线选择" % route_id)
	var route_event := flow.apply_event(&"route_selected", {"route_id": route_id})
	t.check(bool(route_event.get("success", false)) and flow.get_current_step_id() == "operate_gantry", "%s 路线选择推进吊机目标" % route_id)

	var gantry_actions := interaction.query_actions(operator, "facility_gantry")
	t.check(gantry_actions.size() == 1 and bool(gantry_actions[0].get("enabled", false)), "%s 吊机公开预览可操作" % route_id)
	var gantry := interaction.commit_action(operator, "facility_gantry", "lower_gantry", interaction.get_state_revision())
	t.check(bool(gantry.get("success", false)) and gantry.get("action_id", "") == "lower_gantry", "%s 吊机公开提交成功" % route_id)
	var gantry_event := flow.apply_event(&"gantry_lowered", {"route_id": gantry.get("route_id", "gantry_bridge"), "map_changes": gantry.get("map_changes", [])})
	t.check(bool(gantry_event.get("success", false)) and flow.get_current_step_id() == "rescue_scout", "%s 吊机事件推进营救目标" % route_id)

	var enemy := _unit("m1_target_%s" % route_id, Vector2i(9, 14), "enemy")
	enemy.max_hp = 3
	enemy.current_hp = 3
	action_service.setup(map, players, [enemy])
	assault.move_to(Vector2i(8, 14))
	assault.begin_v2_turn()
	var attack_preview := action_service.query_action({
		"action": &"attack",
		"unit": assault,
		"target": enemy,
		"context": {"has_los": true, "distance": 1},
	})
	t.check(bool(attack_preview.get("valid", false)), "%s 公开攻击预览显示命中和伤害" % route_id)
	var attack := action_service.commit_action(attack_preview)
	t.check(bool(attack.get("success", false)) and int(attack.get("damage", 0)) > 0, "%s 公开攻击提交造成可见伤害" % route_id)
	enemy.free()

	var rescue_controller := Rescue.new()
	rescue_controller.setup(map, players, [], action_service, flow, Callable(self, "_create_rescue"), Callable(self, "_register_rescue"))
	assault.move_to(Vector2i(15, 8))
	assault.begin_v2_turn()
	var rescue_preview := rescue_controller.query_rescue(assault, &"rescue_scout")
	t.check(bool(rescue_preview.get("valid", false)), "%s 营救公开预览只在相邻格启用" % route_id)
	var rescued := rescue_controller.commit_rescue(rescue_preview)
	t.check(bool(rescued.get("success", false)) and rescued.get("character_id", "") == "scout", "%s 公开营救提交加入侦察兵" % route_id)
	var scout: Unit = rescued.get("new_unit", null)
	var evac_center: Vector2i = flow.get_snapshot().get("evac_center", Vector2i(-1, -1))
	assault.move_to(evac_center)
	scout.move_to(evac_center + Vector2i.RIGHT)
	var assault_moved := flow.apply_event(&"unit_moved", {"unit": assault, "unit_id": assault.entity_id, "position": assault.grid_pos})
	var scout_moved := flow.apply_event(&"unit_moved", {"unit": scout, "unit_id": scout.entity_id, "position": scout.grid_pos})
	t.check(bool(assault_moved.get("success", false)) and bool(scout_moved.get("success", false)), "%s 撤离前记录两名队员公开移动" % route_id)
	var evac := flow.apply_event(&"evac_checked")
	t.check(bool(evac.get("victory", false)) and flow.is_victory(), "%s 两名存活队员进入撤离区后胜利" % route_id)
	for unit in [operator, assault, enemy, scout]:
		if unit != null and is_instance_valid(unit):
			unit.free()

func _create_rescue(_character_id: StringName, entity_id: String, position: Vector2i) -> Unit:
	return _unit(entity_id, position, "player")

func _register_rescue(_unit_to_register: Unit) -> void:
	pass

func _load_mission(id: String) -> Dictionary:
	var file := FileAccess.open("res://data/v2/missions.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.get(id, {}) if parsed is Dictionary else {}

func _unit(entity_id: String, position: Vector2i, team: String) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = entity_id
	unit.team = team
	unit.job = "assault"
	unit.grid_pos = position
	unit.is_alive = true
	unit.is_downed = false
	unit.enable_v2_turn_mode()
	unit.begin_v2_turn()
	return unit
