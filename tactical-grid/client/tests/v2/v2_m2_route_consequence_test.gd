extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Interaction = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const VisibilityStateScript = preload("res://scripts/game/visibility_state.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")

var t := Runner.new()

func _initialize() -> void:
	var loaded: Dictionary = MapLoader.load_map(&"ch1_m2")
	t.check(bool(loaded.get("success", false)), "M2 路线后果测试加载正式地图")
	if not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	var west := _make_service(map)
	var west_actor := _make_unit("west_actor", Vector2i(7, 13))
	var west_actions: Array = west.query_actions(west_actor, "facility_power_west")
	t.check(west_actions.size() == 1 and west_actions[0].get("id", "") == "cut_power_grid", "西侧只显示切断电网动作")
	var west_result := west.commit_action(west_actor, "facility_power_west", "cut_power_grid", west.get_state_revision())
	t.check(bool(west_result.get("success", false)), "西侧动作提交成功")
	t.check(west_result.get("event", "") == "lockdown_cleared", "西侧动作产生封锁解除事件")
	t.check(west_result.get("power_state", "") == "offline", "西侧动作切断电力")
	t.check(int(west_result.get("enemy_vision_delta", 0)) == -2, "西侧动作降低观察范围")
	t.check(west_result.get("door_id", "") == "west_service_door", "西侧动作解锁稳定维护门")
	t.check(west.commit_action(west_actor, "facility_power_west", "cut_power_grid", west.get_state_revision()).get("reason", "") == "该操作已经完成", "西侧动作不可重复提交")

	var east := _make_service(map)
	var east_actor := _make_unit("east_actor", Vector2i(20, 12))
	var east_result := east.commit_action(east_actor, "facility_security_bypass", "bypass_security_door", east.get_state_revision())
	t.check(bool(east_result.get("success", false)), "东侧动作提交成功")
	t.check(east_result.get("event", "") == "lockdown_cleared", "东侧动作产生封锁解除事件")
	t.check(east_result.get("door_state", "") == "open", "东侧动作打开安全门")
	t.check(bool(east_result.get("sniper_lines_visible", false)), "东侧动作显示狙击预警线")
	t.check(east_result.get("power_state", "") == "online", "东侧动作保持电力在线")
	t.check(east.commit_action(east_actor, "facility_security_bypass", "bypass_security_door", east.get_state_revision()).get("reason", "") == "该操作已经完成", "东侧动作不可重复提交")

	var optional := _make_service(map)
	optional.mark_encounter_cleared("m2_e03_turbine")
	var optional_actor := _make_unit("optional_actor", Vector2i(6, 5))
	var optional_actions: Array = optional.query_actions(optional_actor, "facility_cooling_control")
	t.check(optional_actions.size() == 1 and optional_actions[0].get("id", "") == "shutdown_cooling_nozzles", "控制室只显示关闭喷口动作")
	var optional_result := optional.commit_action(optional_actor, "facility_cooling_control", "shutdown_cooling_nozzles", optional.get_state_revision())
	t.check(bool(optional_result.get("success", false)), "控制室动作提交成功")
	t.check(bool(optional_result.get("hazard_closed", false)), "关闭喷口结果写入危险关闭状态")
	t.check(optional_result.get("unlocked_modules", []) == ["assault_b"], "控制室固定解锁突击模块 B")
	for unit in [west_actor, east_actor, optional_actor]:
		unit.free()
	t.finish(self)

func _make_service(map: Dictionary) -> Interaction:
	var visibility: VisibilityState = VisibilityStateScript.new()
	visibility.setup(28, 20)
	var service := Interaction.new()
	service.setup(map, null, visibility)
	return service

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
