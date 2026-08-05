extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UtilityAI = preload("res://scripts/ai/utility_ai.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var player := _make_unit("player", "player", Vector2i(4, 1))
	var enemy := _make_unit("enemy", "enemy", Vector2i(1, 1))
	enemy.move_points = 3
	enemy.weapon_range = [4, 5]
	enemy.current_ap = 2

	var action: Dictionary = UtilityAI.decide_action(enemy, [player], _make_map(), [enemy])
	var target_pos: Vector2i = action.get("target_pos", Vector2i(-1, -1))
	t.check(String(action.get("type", "")) == "move", "远距离敌人选择移动而不是等待")
	t.check(target_pos != player.grid_pos, "敌方 AI 不选择玩家占用格")
	t.check(target_pos != enemy.grid_pos, "敌方 AI 不选择自身所在格")

	player.free()
	enemy.free()
	t.finish(self)

func _make_unit(id: String, team: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.team = team
	unit.job = "assault"
	unit.grid_pos = position
	unit.max_hp = 7
	unit.current_hp = 7
	unit.is_alive = true
	unit.weapon_damage = [3, 3]
	return unit

func _make_map() -> Dictionary:
	var terrain: Array = [
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0],
	]
	var blockers: Array = [
		[6, 6, 6, 6, 6],
		[6, 0, 0, 0, 0],
		[6, 6, 6, 6, 6],
	]
	return {
		"size": {"width": 5, "height": 3},
		"layers": {"base_terrain": terrain, "blocker": blockers},
	}
