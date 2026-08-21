extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const V2ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const Pathfinding = preload("res://scripts/core/pathfinding.gd")

var t := Runner.new()

class TrackingResolver:
	extends RefCounted
	var call_count := 0
	var context_key_count := 0
	var has_exact_context_keys := false

	func resolve_click(cell: Vector2i, context: Dictionary) -> Dictionary:
		call_count += 1
		context_key_count = context.size()
		var expected_keys := [
			"selected_unit", "friendly_at", "enemy_at", "facility_at",
			"move_query", "attack_query", "interaction_query",
		]
		has_exact_context_keys = expected_keys.all(func(key: String): return context.has(key))
		var preview: Variant = (context.get("move_query") as Callable).call(cell)
		return {
			"kind": &"move",
			"reason": &"reachable",
			"cell": cell,
			"move_preview": preview,
		}

func _initialize() -> void:
	var controller_script: Script = ResourceLoader.load("res://scripts/v2/runtime/v2_battle_controller.gd") as Script
	t.check(controller_script != null, "BattleController 可加载")
	if controller_script == null:
		t.finish(self)
		return
	_set_v2_game_line()
	var reachable := Pathfinding.get_reachable_cells(
		Vector2i(1, 1), 1, 8, 8,
		func(_cell: Vector2i) -> int: return 1,
		func(_cell: Vector2i) -> bool: return false
	)
	t.check(reachable.has(Vector2i(2, 1)) and not reachable.has(Vector2i(3, 1)), "移动范围不包含超出移动点数的边界格")

	var battle: Node = controller_script.new()
	var click_unit: Unit = _make_unit("player_click", Vector2i(1, 1), 5)
	var click_service := V2ActionService.new()
	click_service.setup(_make_map(), [click_unit], [])
	battle.set("v2_action_service", click_service)
	battle.set("selected_unit", click_unit)
	battle.set("player_units", [click_unit])
	battle.set("enemy_units", [])
	var tracking_resolver := TrackingResolver.new()
	var has_resolver_slot := _has_property(battle, "v2_context_action_resolver")
	t.check(has_resolver_slot, "V2 控制器提供上下文行动解析器槽位")
	if has_resolver_slot:
		battle.set("v2_context_action_resolver", tracking_resolver)
		battle.call("_on_v2_cell_left_clicked", Vector2i(2, 1))
		t.check(tracking_resolver.call_count == 1, "一次地图点击只解析一个上下文快照")
		t.check(tracking_resolver.context_key_count == 7 and tracking_resolver.has_exact_context_keys, "上下文快照只包含七个规定键")
		t.check(click_unit.grid_pos == Vector2i(2, 1) and not click_unit.v2_turn_state.move_available, "解析出的合法移动预览通过现有路径一次提交")

	var safe_unit: Unit = _make_unit("player_safe", Vector2i(1, 1), 5)
	var safe_service := V2ActionService.new()
	safe_service.setup(_make_map(), [safe_unit], [])
	battle.set("v2_action_service", safe_service)
	battle.set("selected_unit", safe_unit)
	battle.set("player_units", [safe_unit])

	var safe_destination := Vector2i(2, 1)
	var safe_result: Dictionary = battle.call("request_move", safe_destination)
	t.check(bool(safe_result.get("success", false)) and bool(safe_result.get("committed", false)), "蓝色安全格一次点击移动")
	t.check(safe_unit.grid_pos == safe_destination, "单位到达安全目标格")
	t.check(not safe_unit.v2_turn_state.move_available, "安全移动消耗移动预算")
	t.check(safe_unit.v2_turn_state.action_available, "安全移动保留行动机会")
	var repeat_result: Dictionary = battle.call("request_move", Vector2i(3, 1))
	t.check(not bool(repeat_result.get("success", true)) and repeat_result.get("reason", &"") == &"move_unavailable", "重复移动返回明确预算错误")

	var guarded_unit: Unit = _make_unit("player_guarded", Vector2i(1, 1), 5)
	var guarded_service := V2ActionService.new()
	guarded_service.setup(_make_map(), [guarded_unit], [])
	battle.set("v2_action_service", guarded_service)
	battle.set("selected_unit", guarded_unit)
	var preview_for_other_cell: Dictionary = guarded_service.query_action({
		"action": &"move",
		"unit": guarded_unit,
		"target": Vector2i(2, 1),
	})
	var mismatched_result: Dictionary = battle.call("request_move", Vector2i(3, 1), preview_for_other_cell)
	t.check(not bool(mismatched_result.get("success", true)) and mismatched_result.get("reason", &"") == &"destination_mismatch", "上下文移动预览目标不一致时拒绝提交")
	t.check(guarded_unit.grid_pos == Vector2i(1, 1) and guarded_unit.v2_turn_state.move_available, "拒绝错位移动预览不改变单位状态")

	var reserve_unit: Unit = _make_unit("player_reserve", Vector2i(1, 1), 5)
	var pending_enemy: Unit = _make_unit("enemy_pending", Vector2i(2, 1), 3)
	pending_enemy.team = "enemy"
	pending_enemy.is_alive = false
	pending_enemy.is_downed = false
	var reserve_service := V2ActionService.new()
	reserve_service.setup(_make_map(), [reserve_unit], [pending_enemy])
	battle.set("v2_action_service", reserve_service)
	battle.set("selected_unit", reserve_unit)
	var reserved_result: Dictionary = battle.call("request_move", pending_enemy.grid_pos)
	t.check(not bool(reserved_result.get("success", true)) and reserved_result.get("reason", &"") == &"occupied", "待激活敌人的出生格不能成为玩家移动落点")
	t.check(reserve_unit.grid_pos == Vector2i(1, 1), "出生格被保留时玩家不移动")

	var live_unit: Unit = _make_unit("player_live", Vector2i(1, 1), 5)
	var live_enemy: Unit = _make_unit("enemy_live", Vector2i(2, 1), 3)
	live_enemy.team = "enemy"
	var stale_service := V2ActionService.new()
	stale_service.setup(_make_map(), [live_unit], [])
	battle.set("player_units", [live_unit])
	battle.set("enemy_units", [live_enemy])
	battle.set("v2_action_service", stale_service)
	battle.set("selected_unit", live_unit)
	var authoritative_result: Dictionary = battle.call("request_move", live_enemy.grid_pos)
	t.check(not bool(authoritative_result.get("success", true)) and authoritative_result.get("reason", &"") == &"occupied", "战场实时敌人优先于过期动作缓存阻止移动")
	t.check(live_unit.grid_pos == Vector2i(1, 1), "实时敌人占格时玩家不移动")

	var dangerous_unit: Unit = _make_unit("player_danger", Vector2i(1, 1), 5)
	var dangerous_service := V2ActionService.new()
	dangerous_service.setup(_make_map([Vector2i(2, 1)]), [dangerous_unit], [])
	battle.set("player_units", [dangerous_unit])
	battle.set("enemy_units", [])
	battle.set("v2_action_service", dangerous_service)
	battle.set("selected_unit", dangerous_unit)
	var dangerous_destination := Vector2i(2, 1)
	var first: Dictionary = battle.call("request_move", dangerous_destination)
	t.check(bool(first.get("success", false)) and not bool(first.get("committed", true)) and bool(first.get("confirmation_required", false)), "危险格首次点击只请求确认")
	t.check(dangerous_unit.grid_pos == Vector2i(1, 1), "危险格首次点击不移动")
	t.check(dangerous_unit.v2_turn_state.move_available, "危险格首次点击不消耗移动")
	var second: Dictionary = battle.call("request_move", dangerous_destination)
	t.check(bool(second.get("success", false)) and bool(second.get("committed", false)), "危险格第二次同格点击提交")
	t.check(dangerous_unit.grid_pos == dangerous_destination, "确认后单位到达危险格")

	battle.set("selected_unit", null)
	var no_selection: Dictionary = battle.call("request_move", Vector2i(3, 3))
	t.check(not bool(no_selection.get("success", true)) and no_selection.get("reason", &"") == &"no_selected_unit", "未选择单位拒绝移动")

	battle.free()
	click_unit.free()
	safe_unit.free()
	reserve_unit.free()
	pending_enemy.free()
	live_unit.free()
	live_enemy.free()
	dangerous_unit.free()
	guarded_unit.free()
	t.finish(self)

func _make_unit(id: String, position: Vector2i, move_points: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.team = "player"
	unit.job = "assault"
	unit.grid_pos = position
	unit.move_points = move_points
	unit.base_move_points = move_points
	unit.max_hp = 7
	unit.current_hp = 7
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit

func _make_map(danger_cells: Array = []) -> Dictionary:
	var terrain: Array = []
	var blockers: Array = []
	for _y in range(8):
		terrain.append([0, 0, 0, 0, 0, 0, 0, 0])
		blockers.append([0, 0, 0, 0, 0, 0, 0, 0])
	return {
		"size": {"width": 8, "height": 8},
		"layers": {"base_terrain": terrain, "blocker": blockers},
		"danger_cells": danger_cells,
	}

func _set_v2_game_line() -> void:
	var manager := root.get_node_or_null("GameManager")
	if manager:
		manager.current_save["game_line"] = "v2_infiltration"

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
