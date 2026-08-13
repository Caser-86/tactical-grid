extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const ResolverScript = preload("res://scripts/v2/input/v2_context_action_resolver.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()
var resolver: RefCounted = ResolverScript.new()
var query_calls := {"move": 0, "attack": 0, "interaction": 0}

func _initialize() -> void:
	var selected := _make_unit("player_selected", "player")
	var friendly := _make_unit("player_friendly", "player")
	var enemy := _make_unit("enemy_sentry", "enemy")
	var facility := {"id": "facility_camera", "type": "camera"}

	var select_result := _resolve(Vector2i(1, 1), selected, friendly, enemy, facility)
	_check_result(select_result, &"select", &"living_friendly", Vector2i(1, 1), "友军优先解析为选择")
	t.check(select_result.get("unit") == friendly, "选择结果携带友军对象")
	_check_calls(0, 0, 0, "选择不调用任何行动查询")

	_reset_calls()
	var move_result := _resolve(Vector2i(2, 1), selected, null, null, {})
	_check_result(move_result, &"move", &"reachable", Vector2i(2, 1), "空的可达格解析为移动")
	t.check(move_result.get("move_preview", {}).get("target") == Vector2i(2, 1), "移动结果携带确定的移动预览")
	_check_calls(1, 0, 0, "移动候选只调用移动查询")

	_reset_calls()
	var attack_result := _resolve(Vector2i(3, 1), selected, null, enemy, facility)
	_check_result(attack_result, &"attack", &"legal_attack", Vector2i(3, 1), "敌人与设施重合时合法攻击优先")
	t.check(attack_result.get("target") == enemy and attack_result.get("attack_preview", {}).get("target") == enemy, "攻击结果携带目标与攻击预览")
	_check_calls(0, 1, 0, "攻击候选只调用攻击查询")

	_reset_calls()
	var interact_result := _resolve(Vector2i(4, 1), selected, null, null, facility)
	_check_result(interact_result, &"interact", &"usable_facility", Vector2i(4, 1), "可用设施解析为交互")
	t.check(interact_result.get("facility") == facility and interact_result.get("interaction_preview", {}).get("facility") == facility, "交互结果携带设施与交互预览")
	_check_calls(0, 0, 1, "设施候选只调用交互查询")

	_reset_calls()
	var blocked_enemy := _resolve_with_queries(
		Vector2i(5, 1), selected, null, enemy, {},
		Callable(self, "_valid_move_query"), Callable(self, "_invalid_attack_query"), Callable(self, "_valid_interaction_query")
	)
	_check_result(blocked_enemy, &"invalid", &"out_of_range", Vector2i(5, 1), "非法敌人保持攻击失败原因")
	t.check(blocked_enemy.get("target") == enemy and blocked_enemy.get("attack_preview", {}).get("reason") == &"out_of_range", "非法攻击保留目标与查询预览")
	_check_calls(0, 1, 0, "敌人占格失败后不会退化为移动")

	_reset_calls()
	var blocked_facility := _resolve_with_queries(
		Vector2i(6, 1), selected, null, null, facility,
		Callable(self, "_valid_move_query"), Callable(), Callable(self, "_invalid_interaction_query")
	)
	_check_result(blocked_facility, &"invalid", &"out_of_range", Vector2i(6, 1), "不可用设施保持交互失败原因")
	t.check(blocked_facility.get("facility") == facility and blocked_facility.get("interaction_preview", {}).get("reason") == &"out_of_range", "不可用设施保留设施与查询预览")
	_check_calls(0, 0, 1, "设施不可用时不会退化为移动")

	_reset_calls()
	var blocked_move := _resolve_with_queries(
		Vector2i(7, 1), selected, null, null, {},
		Callable(self, "_invalid_move_query"), Callable(), Callable()
	)
	_check_result(blocked_move, &"invalid", &"blocked", Vector2i(7, 1), "不可达地面保持移动失败原因")
	t.check(blocked_move.get("move_preview", {}).get("reason") == &"blocked", "非法移动保留查询预览")
	_check_calls(1, 0, 0, "不可达地面只调用移动查询")

	_reset_calls()
	var unavailable_selected := _make_unit("player_spent", "player")
	unavailable_selected.is_alive = false
	var unavailable_result := _resolve(Vector2i(0, 2), unavailable_selected, null, null, {})
	_check_result(unavailable_result, &"invalid", &"selected_unit_unavailable", Vector2i(0, 2), "死亡的所选玩家不能发起行动")
	_check_calls(0, 0, 0, "无效选择不调用查询")

	_reset_calls()
	var no_selection := _resolve(Vector2i(1, 2), null, null, enemy, {})
	_check_result(no_selection, &"invalid", &"no_selected_unit", Vector2i(1, 2), "未选择玩家时目标无效")
	_check_calls(0, 0, 0, "未选择玩家不调用查询")

	_reset_calls()
	var malformed_move := _resolve_with_queries(
		Vector2i(2, 2), selected, null, null, {},
		Callable(self, "_malformed_move_query"), Callable(), Callable()
	)
	_check_result(malformed_move, &"invalid", &"malformed_move_query", Vector2i(2, 2), "非字典移动查询结果稳定失败")

	_reset_calls()
	var malformed_attack := _resolve_with_queries(
		Vector2i(3, 2), selected, null, enemy, {},
		Callable(), Callable(self, "_malformed_attack_query"), Callable()
	)
	_check_result(malformed_attack, &"invalid", &"malformed_attack_query", Vector2i(3, 2), "非字典攻击查询结果稳定失败")

	_reset_calls()
	var malformed_interaction := _resolve_with_queries(
		Vector2i(4, 2), selected, null, null, facility,
		Callable(), Callable(), Callable(self, "_malformed_interaction_query")
	)
	_check_result(malformed_interaction, &"invalid", &"malformed_interaction_query", Vector2i(4, 2), "非字典交互查询结果稳定失败")

	_reset_calls()
	var unavailable_query := _resolve_with_queries(
		Vector2i(5, 2), selected, null, null, {}, Callable(), Callable(), Callable()
	)
	_check_result(unavailable_query, &"invalid", &"move_query_unavailable", Vector2i(5, 2), "缺失候选查询返回稳定原因")

	selected.free()
	friendly.free()
	enemy.free()
	unavailable_selected.free()
	t.finish(self)

func _resolve(cell: Vector2i, selected: Unit, friendly: Unit, enemy: Unit, facility: Dictionary) -> Dictionary:
	return _resolve_with_queries(
		cell, selected, friendly, enemy, facility,
		Callable(self, "_valid_move_query"),
		Callable(self, "_valid_attack_query"),
		Callable(self, "_valid_interaction_query")
	)

func _resolve_with_queries(
	cell: Vector2i,
	selected: Unit,
	friendly: Unit,
	enemy: Unit,
	facility: Dictionary,
	move_query: Callable,
	attack_query: Callable,
	interaction_query: Callable
) -> Dictionary:
	return resolver.call("resolve_click", cell, {
		"selected_unit": selected,
		"friendly_at": friendly,
		"enemy_at": enemy,
		"facility_at": facility,
		"move_query": move_query,
		"attack_query": attack_query,
		"interaction_query": interaction_query,
	})

func _valid_move_query(cell: Vector2i) -> Dictionary:
	query_calls["move"] += 1
	return {"valid": true, "target": cell, "path": [cell]}

func _valid_attack_query(target: Unit) -> Dictionary:
	query_calls["attack"] += 1
	return {"valid": true, "target": target, "damage": 3}

func _valid_interaction_query(facility: Dictionary) -> Dictionary:
	query_calls["interaction"] += 1
	return {"valid": true, "facility": facility, "actions": [{"id": "view", "enabled": true}]}

func _invalid_attack_query(_target: Unit) -> Dictionary:
	query_calls["attack"] += 1
	return {"valid": false, "reason": &"out_of_range"}

func _invalid_move_query(_cell: Vector2i) -> Dictionary:
	query_calls["move"] += 1
	return {"valid": false, "reason": &"blocked"}

func _invalid_interaction_query(_facility: Dictionary) -> Dictionary:
	query_calls["interaction"] += 1
	return {"valid": false, "reason": &"out_of_range"}

func _malformed_move_query(_cell: Vector2i) -> String:
	query_calls["move"] += 1
	return "not-a-dictionary"

func _malformed_attack_query(_target: Unit) -> Array:
	query_calls["attack"] += 1
	return []

func _malformed_interaction_query(_facility: Dictionary) -> int:
	query_calls["interaction"] += 1
	return 7

func _make_unit(id: String, team: String) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.team = team
	unit.is_alive = true
	return unit

func _check_result(result: Dictionary, kind: StringName, reason: StringName, cell: Vector2i, message: String) -> void:
	t.check(
		result.get("kind", &"") == kind
		and result.get("reason", &"") == reason
		and result.get("cell", Vector2i(-1, -1)) == cell,
		message
	)

func _reset_calls() -> void:
	query_calls = {"move": 0, "attack": 0, "interaction": 0}

func _check_calls(move_count: int, attack_count: int, interaction_count: int, message: String) -> void:
	t.check(query_calls == {
		"move": move_count,
		"attack": attack_count,
		"interaction": interaction_count,
	}, message)
