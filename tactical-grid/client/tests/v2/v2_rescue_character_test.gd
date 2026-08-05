extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Rescue = preload("res://scripts/v2/mission/v2_rescue_controller.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()
var _registered: Array = []

func _initialize() -> void:
	var map := {
		"size": {"width": 22, "height": 16},
		"entities": [
			{"id": "rescue_scout", "type": "objective_primary", "x": 13, "y": 7, "team": "neutral", "character_id": "scout", "state": "captive"},
			{"id": "evac_northeast", "type": "evac", "x": 19, "y": 2, "radius": 1},
		],
		"layers": {
			"base_terrain": _layer(22, 16, 0),
			"blocker": _layer(22, 16, 0),
		},
	}
	var mission := {"id": "ch1_m1", "rescue_character": "scout"}
	var assault := _unit("spawn_assault", "assault", Vector2i(12, 7))
	var enemy := _unit("enemy_sentry_south", "sentry", Vector2i(8, 12), "enemy")
	var players: Array = [assault]
	var enemies: Array = [enemy]
	var flow := Flow.new()
	flow.setup(mission, map, players, enemies)
	var action_service := ActionService.new()
	action_service.setup(map, players, enemies)
	var rescue := Rescue.new()
	rescue.setup(
		map,
		players,
		enemies,
		action_service,
		flow,
		Callable(self, "_create_scout"),
		Callable(self, "_register_unit"),
	)

	var preview: Dictionary = rescue.query_rescue(assault, &"rescue_scout")
	t.check(bool(preview.get("valid", false)), "相邻突击兵可以预览营救")
	t.check(bool(preview.get("cost", {}).get("action", false)), "营救预览明确消耗行动预算")
	t.check(String(preview.get("character_id", "")) == "scout", "营救预览锁定侦察兵")

	var captive: Dictionary = rescue.get_captive(&"rescue_scout")
	var captive_attack := action_service.query_action({"action": &"attack", "unit": assault, "target": captive})
	t.check(not bool(captive_attack.get("valid", false)) and captive_attack.get("reason") == &"invalid_unit", "营救前中立对象不能被攻击")

	var result: Dictionary = rescue.commit_rescue(preview)
	var scout: Unit = result.get("new_unit", null)
	t.check(bool(result.get("success", false)), "相邻营救提交成功")
	t.check(String(result.get("character_id", "")) == "scout", "营救结果携带角色 ID")
	t.check(scout != null and scout.entity_id == "player_scout", "侦察兵使用稳定实体 ID")
	t.check(scout != null and scout.job == "scout" and scout.team == "player", "侦察兵以玩家单位加入")
	t.check(scout != null and scout.v2_turn_state.can_move() and scout.v2_turn_state.can_act(), "同关加入时获得完整移动和行动预算")
	t.check(players.size() == 2 and players.has(scout) and _registered.has(scout), "侦察兵注册到队伍和运行时注册回调")
	t.check(flow.get_state_name() == &"ESCORT_TO_EVAC", "营救成功切换到护送撤离状态")
	t.check(String(rescue.get_rescue_state(&"rescue_scout")) == "rescued", "营救对象状态变为已营救")

	var duplicate: Dictionary = rescue.query_rescue(assault, &"rescue_scout")
	t.check(not bool(duplicate.get("valid", false)) and duplicate.get("reason") == &"already_rescued", "重复营救被明确拒绝")
	t.check(not assault.v2_turn_state.action_available, "营救只消耗营救者的行动预算")

	var far_assault := _unit("far_assault", "assault", Vector2i(3, 14))
	far_assault.enable_v2_turn_mode()
	var far_preview := rescue.query_rescue(far_assault, &"rescue_scout")
	t.check(not bool(far_preview.get("valid", false)) and far_preview.get("reason") == &"already_rescued", "已营救对象不因距离变化重复开放")

	var second_map := map.duplicate(true)
	var second_flow := Flow.new()
	var second_assault := _unit("second_assault", "assault", Vector2i(3, 14))
	second_flow.setup(mission, second_map, [second_assault], enemies)
	var second_service := ActionService.new()
	second_service.setup(second_map, [second_assault], enemies)
	var second_rescue := Rescue.new()
	second_rescue.setup(second_map, [second_assault], enemies, second_service, second_flow, Callable(self, "_create_scout"), Callable())
	var too_far := second_rescue.query_rescue(second_assault, &"rescue_scout")
	t.check(not bool(too_far.get("valid", false)) and too_far.get("reason") == &"rescue_too_far", "非相邻位置不能直接营救")
	var empty_map := second_map.duplicate(true)
	empty_map["entities"] = []
	var empty_rescue := Rescue.new()
	empty_rescue.setup(empty_map, [second_assault], enemies, second_service, second_flow, Callable(self, "_create_scout"), Callable())
	var no_target := empty_rescue.query_rescue(second_assault, &"rescue_scout")
	t.check(not bool(no_target.get("valid", false)) and no_target.get("reason") == &"rescue_unavailable", "没有营救对象时返回明确失败")

	assault.free()
	enemy.free()
	scout.free()
	far_assault.free()
	second_assault.free()
	t.finish(self)

func _create_scout(character_id: StringName, entity_id: String, position: Vector2i) -> Unit:
	var unit := UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = "侦察兵"
	unit.team = "player"
	unit.job = String(character_id)
	unit.grid_pos = position
	unit.max_hp = 5
	unit.current_hp = 5
	unit.move_points = 7
	unit.base_move_points = 7
	unit.vision_range = 8
	unit.weapon_range = [1, 4]
	unit.weapon_damage = [2, 2]
	unit.enable_v2_turn_mode()
	return unit

func _register_unit(unit: Unit) -> void:
	_registered.append(unit)

func _unit(entity_id: String, role: String, position: Vector2i, team: String = "player") -> Unit:
	var unit := UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = role
	unit.team = team
	unit.job = role
	unit.grid_pos = position
	unit.max_hp = 7
	unit.current_hp = 7
	unit.weapon_range = [1, 4]
	unit.weapon_damage = [2, 2]
	unit.enable_v2_turn_mode()
	return unit

func _layer(width: int, height: int, value: int) -> Array:
	var result: Array = []
	for _y in range(height):
		var row: Array = []
		for _x in range(width):
			row.append(value)
		result.append(row)
	return result
