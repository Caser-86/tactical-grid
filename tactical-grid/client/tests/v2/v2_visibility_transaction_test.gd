extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const VisibilityStateScript = preload("res://scripts/game/visibility_state.gd")
const VisibilityRendererScript = preload("res://scripts/game/visibility_renderer.gd")

var t := Runner.new()

func _initialize() -> void:
	var controller_script: Script = ResourceLoader.load("res://scripts/game/battle_controller.gd") as Script
	t.check(controller_script != null, "BattleController 迷雾事务接口可加载")
	if controller_script == null:
		t.finish(self)
		return
	var battle: Node = controller_script.new()
	var state: VisibilityState = VisibilityStateScript.new()
	var renderer: VisibilityRenderer = VisibilityRendererScript.new()
	var unit_layer := Node2D.new()
	var player := _make_unit("player_move", "player", Vector2i(2, 4), 3)
	var enemy := _make_unit("enemy_revealed", "enemy", Vector2i(8, 4), 3)
	state.setup(12, 8)
	renderer.setup(state, 12, 8, 64.0)
	state.add_camera_zone("camera_a", [Vector2i(10, 4)])
	battle.set("visibility_state", state)
	battle.set("visibility_renderer", renderer)
	battle.set("unit_layer", unit_layer)
	battle.set("player_units", [player])
	battle.set("enemy_units", [enemy])
	battle.set("selected_unit", player)
	battle.set("map_width", 12)
	battle.set("map_height", 8)
	battle.set("map_data", _make_map())
	battle.set("_camera_zone_cells", [Vector2i(10, 4)])

	t.check(state.get_cell_state(Vector2i(8, 4)) == VisibilityState.STATE_UNEXPLORED, "移动前远端格仍是未知")
	player.grid_pos = Vector2i(6, 4)
	var result: Dictionary = battle.call("refresh_visibility_transaction", &"unit_moved")
	t.check(bool(result.get("success", false)), "移动事务刷新成功")
	t.check(result.get("reason", &"") == &"unit_moved", "返回移动事务原因")
	t.check(state.get_cell_state(Vector2i(8, 4)) == VisibilityState.STATE_OBSERVED, "移动返回前新视野已经揭示")
	t.check(renderer.get_render_state_for_cell(Vector2i(8, 4)) == VisibilityState.RENDER_VISIBLE, "渲染器返回前已同步新视野")
	t.check(state.is_enemy_observed("enemy_revealed"), "移动返回前新揭示敌人已进入可见集合")
	t.check(state.get_cell_state(Vector2i(10, 4)) == VisibilityState.STATE_OBSERVED, "持久摄像头区域在同一事务内合并")
	t.check(bool(result.get("renderer_refreshed", false)), "事务明确报告渲染刷新")

	battle.free()
	state.free()
	renderer.free()
	unit_layer.free()
	player.free()
	enemy.free()
	t.finish(self)

func _make_unit(id: String, team: String, position: Vector2i, vision: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = team
	unit.job = "assault"
	unit.grid_pos = position
	unit.vision_range = vision
	unit.current_hp = 7
	unit.max_hp = 7
	unit.is_alive = true
	return unit

func _make_map() -> Dictionary:
	var terrain: Array = []
	var blockers: Array = []
	for _y in range(8):
		terrain.append([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
		blockers.append([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	return {
		"size": {"width": 12, "height": 8},
		"layers": {"base_terrain": terrain, "blocker": blockers},
	}
