extends Node

const ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const BattleControllerScript = preload("res://scripts/game/battle_controller.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Runner = preload("res://tests/v2/test_runner.gd")
const TurnManagerScript = preload("res://scripts/game/turn_manager.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var missions := _load_shipped_missions()
	t.check(missions.has("ch1_m1") and missions.has("ch1_m2"), "回归使用 shipped M1/M2 mission 数据")
	if missions.has("ch1_m1"):
		_run_m1_controller_flow(missions["ch1_m1"])
	if missions.has("ch1_m2"):
		_run_m2_terminal_regression(missions["ch1_m2"])
	t.finish(get_tree())

func _run_m1_controller_flow(mission: Dictionary) -> void:
	var m1_steps: Array = mission.get("objective_steps", [])
	t.check(not m1_steps.is_empty() and String(m1_steps.back().get("complete_event", "")) == "mission_completed", "M1 shipped 终端阶段配置为 mission_completed")
	var map_result := MapLoader.load_map(StringName(String(mission.get("map_id", ""))))
	t.check(bool(map_result.get("success", false)), "M1 使用 shipped map 数据")
	if not bool(map_result.get("success", false)):
		return
	var map: Dictionary = map_result.get("data", {})
	var evac_center := _evac_center(map)
	var assault := _unit("assault_1", evac_center + Vector2i.LEFT)
	var scout := _unit("player_scout", evac_center + Vector2i(-3, 0))
	var battle := _build_battle(mission, map, [assault], [assault])
	var flow: RefCounted = battle.v2_mission_flow
	var rescue_result: Dictionary = flow.apply_event(&"character_rescued", {
		"character_id": "scout",
		"unit": scout,
	})
	t.check(bool(rescue_result.get("success", false)), "M1 营救后允许进入正式撤离路径")
	battle.player_units.append(scout)
	battle.turn_manager.register_player_unit(scout)
	battle.v2_action_service.refresh_units(battle.player_units, battle.enemy_units)

	battle.selected_unit = assault
	var not_ready_move: Dictionary = battle.request_move(evac_center)
	t.check(bool(not_ready_move.get("success", false)) and bool(not_ready_move.get("committed", false)), "BattleController.request_move 提交 M1 首个撤离移动")
	t.check(not flow.is_victory() and flow.get_current_step_id() == "escort_scout", "M1 准备不足时不推进撤离阶段")
	t.check(not _has_event(flow, &"mission_completed"), "M1 准备不足时不提交 mission_completed")

	battle.selected_unit = scout
	var completed_move: Dictionary = battle.request_move(evac_center + Vector2i.UP)
	t.check(bool(completed_move.get("success", false)) and bool(completed_move.get("committed", false)), "BattleController.request_move 提交准备完成的 M1 撤离移动")
	t.check(flow.is_victory(), "真实 BattleController 撤离路径推进 V2MissionFlow victory")
	t.check(_has_event(flow, &"mission_completed"), "真实 BattleController 路径提交配置化 mission_completed")
	t.check(battle.turn_manager.current_phase == TurnManagerScript.TurnPhase.BATTLE_OVER and battle.turn_manager.battle_over, "控制器胜利交接 TurnManager.BATTLE_OVER")
	t.check(flow.get_snapshot().get("event_count", 0) == 7, "M1 移动/撤离/终端事件各只提交一次")

	var duplicate: Dictionary = battle.call("_apply_v2_mission_event", &"evac_checked")
	t.check(not bool(duplicate.get("success", true)) and not bool(duplicate.get("final_event_submitted", false)), "M1 重复撤离不重复提交终端事件")
	_dispose_battle(battle)

func _run_m2_terminal_regression(mission: Dictionary) -> void:
	var m2_steps: Array = mission.get("objective_steps", [])
	t.check(not m2_steps.is_empty() and String(m2_steps.back().get("complete_event", "")) == "evac_checked", "M2 shipped 终端阶段配置为 evac_checked")
	var evac_center := Vector2i(4, 4)
	var map := {
		"size": {"width": 8, "height": 8},
		"entities": [{"id": "evac_m2", "type": "evac", "x": evac_center.x, "y": evac_center.y, "radius": 1}],
	}
	var assault := _unit("m2_assault", evac_center)
	var scout := _unit("m2_scout", evac_center)
	var sniper := _unit("m2_sniper", evac_center + Vector2i(-2, 0))
	var battle := _build_battle(mission, map, [assault, scout], [assault, scout])
	var flow: RefCounted = battle.v2_mission_flow
	var lockdown_result: Dictionary = flow.apply_event(&"lockdown_disabled")
	t.check(bool(lockdown_result.get("success", false)), "M2 shipped 配置可完成 lockdown_disabled")
	var rescue_result: Dictionary = flow.apply_event(&"character_rescued", {
		"character_id": "sniper",
		"unit": sniper,
	})
	t.check(bool(rescue_result.get("success", false)), "M2 shipped 配置可完成 sniper 营救")
	battle.player_units.append(sniper)
	battle.turn_manager.register_player_unit(sniper)
	battle.v2_action_service.refresh_units(battle.player_units, battle.enemy_units)
	battle.selected_unit = sniper
	var result: Dictionary = battle.request_move(evac_center + Vector2i.UP)
	t.check(bool(result.get("success", false)) and bool(result.get("committed", false)), "M2 通过 BattleController 移动触发 ready evac_checked")
	t.check(flow.is_victory(), "M2 ready evac_checked 直接完成任务")
	t.check(not _has_event(flow, &"mission_completed"), "M2 不合成额外 mission_completed 事件")
	_dispose_battle(battle)

func _build_battle(mission: Dictionary, map: Dictionary, players: Array, turn_players: Array) -> BattleController:
	var manager: Node = get_node("/root/GameManager")
	manager.set("current_save", {"game_line": "v2_infiltration"})
	var battle: BattleController = BattleControllerScript.new()
	battle.level_id = String(mission.get("id", ""))
	battle.map_data = map.duplicate(true)
	battle.map_width = int(map.get("size", {}).get("width", 8))
	battle.map_height = int(map.get("size", {}).get("height", 8))
	battle.player_units = players
	battle.enemy_units = []
	battle.v2_mission_flow = Flow.new()
	battle.v2_mission_flow.setup(mission, map, players, [])
	battle.v2_mission_flow.apply_event(&"mission_started")
	battle.v2_action_service = ActionService.new()
	battle.v2_action_service.setup(map, players, [])
	battle.turn_manager = TurnManagerScript.new()
	battle.add_child(battle.turn_manager)
	battle.turn_manager.setup(turn_players, [], 3)
	battle.turn_manager.set_victory_check(Callable(battle, "_check_victory"))
	battle.turn_manager.start_battle()
	return battle

func _load_shipped_missions() -> Dictionary:
	var file := FileAccess.open("res://data/v2/missions.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func _evac_center(map: Dictionary) -> Vector2i:
	for raw_entity in map.get("entities", []):
		if raw_entity is Dictionary and String(raw_entity.get("type", "")) in ["evac", "extract", "evac_zone"]:
			return Vector2i(int(raw_entity.get("x", -1)), int(raw_entity.get("y", -1)))
	return Vector2i(-1, -1)

func _has_event(flow: RefCounted, event_name: StringName) -> bool:
	for event in flow.event_history:
		if StringName(event.get("event", "")) == event_name:
			return true
	return false

func _unit(entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.grid_pos = position
	unit.is_alive = true
	unit.is_downed = false
	unit.enable_v2_turn_mode()
	unit.begin_v2_turn()
	return unit

func _dispose_battle(battle: BattleController) -> void:
	if battle != null and is_instance_valid(battle):
		for raw_unit in battle.player_units + battle.enemy_units:
			if raw_unit != null and is_instance_valid(raw_unit):
				raw_unit.free()
		battle.player_units.clear()
		battle.enemy_units.clear()
		battle.free()
