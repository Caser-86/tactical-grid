extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const V2ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")

var t := Runner.new()

func _initialize() -> void:
	var controller_script: Script = ResourceLoader.load("res://scripts/game/battle_controller.gd") as Script
	t.check(controller_script != null, "BattleController 可加载")
	if controller_script == null:
		t.finish(self)
		return

	var battle: Node = controller_script.new()
	var safe_unit: Unit = _make_unit("player_safe", Vector2i(1, 1), 5)
	var safe_service := V2ActionService.new()
	safe_service.setup(_make_map(), [safe_unit], [])
	battle.set("v2_action_service", safe_service)
	battle.set("selected_unit", safe_unit)

	var safe_destination := Vector2i(2, 1)
	var safe_result: Dictionary = battle.call("request_move", safe_destination)
	t.check(bool(safe_result.get("success", false)) and bool(safe_result.get("committed", false)), "蓝色安全格一次点击移动")
	t.check(safe_unit.grid_pos == safe_destination, "单位到达安全目标格")
	t.check(not safe_unit.v2_turn_state.move_available, "安全移动消耗移动预算")
	t.check(safe_unit.v2_turn_state.action_available, "安全移动保留行动机会")
	var repeat_result: Dictionary = battle.call("request_move", Vector2i(3, 1))
	t.check(not bool(repeat_result.get("success", true)) and repeat_result.get("reason", &"") == &"move_unavailable", "重复移动返回明确预算错误")

	var dangerous_unit: Unit = _make_unit("player_danger", Vector2i(1, 1), 5)
	var dangerous_service := V2ActionService.new()
	dangerous_service.setup(_make_map([Vector2i(2, 1)]), [dangerous_unit], [])
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
	safe_unit.free()
	dangerous_unit.free()
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
