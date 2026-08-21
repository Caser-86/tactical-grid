extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UtilityAI = preload("res://scripts/ai/utility_ai.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const Activation = preload("res://scripts/v2/mission/v2_encounter_activation.gd")

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

	var activation := Activation.new()
	activation.setup(_encounter_map())
	var blocked: Dictionary = activation.update([Vector2i(2, 1)], [])
	t.check(
		blocked.get("waiting_ids", []).has("enemy_spawn")
		and blocked.get("spawn_cell_occupied", []).has("enemy_spawn"),
		"占用出生格的敌人保持等待并记录 spawn_cell_occupied"
	)
	var promoted: Dictionary = activation.update([], [])
	t.check(
		promoted.get("activated_ids", []).has("enemy_spawn")
		and activation.get_active_enemy_ids().has("enemy_spawn"),
		"出生格释放后按稳定顺序晋升等待敌人"
	)

	var blocked_live_enemy := Activation.new()
	blocked_live_enemy.setup(_encounter_map())
	var blocked_by_enemy: Dictionary = blocked_live_enemy.update([], [], [], [Vector2i(2, 1)])
	t.check(
		blocked_by_enemy.get("waiting_ids", []).has("enemy_spawn")
		and blocked_by_enemy.get("spawn_cell_occupied", []).has("enemy_spawn"),
		"存活敌人占用出生格时等待队列不生成重叠敌人"
	)
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

func _encounter_map() -> Dictionary:
	return {
		"entities": [
			{"id": "enemy_spawn", "type": "spawn_enemy", "x": 1, "y": 1},
		],
		"encounters": [
			{
				"id": "encounter_spawn",
				"trigger": "start",
				"active_enemy_ids": ["enemy_spawn"],
				"spawn_cells": [[2, 1]],
			},
		],
	}
