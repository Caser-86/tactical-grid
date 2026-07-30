## Enemy planner
## Splits AI planning from execution.
## Plans with vision and line-of-sight constraints:
## - Enemies can only target player units they can see (have LOS to).
## - Hidden enemies (not visible to player) still plan, but their intents
##   are filtered by EnemyIntentState before reaching the HUD.
## - Planning produces an intent dictionary that EnemyIntentState stores
##   and the execution phase commits.
extends Node
class_name EnemyPlanner

var _map_data: Dictionary = {}
var _width: int = 0
var _height: int = 0


## Setup with map data for LOS and pathfinding checks.
func setup(map_data: Dictionary) -> void:
	_map_data = map_data
	var size: Dictionary = map_data.get("size", {})
	_width = int(size.get("width", 0))
	_height = int(size.get("height", 0))


## Plan an action for an enemy unit.
## Returns a dictionary with the planned action and intent metadata.
## enemy: the enemy Unit
## player_units: all player units (alive)
## enemies: all enemy units (for friendly-fire avoidance)
## visibility_state: the player's visibility (enemies plan against what they can see)
func plan_action(
	enemy: Node,
	player_units: Array,
	enemies: Array,
	visibility_state: VisibilityState
) -> Dictionary:
	# Use UtilityAI for the base decision, then annotate with intent metadata
	var action = UtilityAI.decide_action(enemy, player_units, _map_data, enemies)

	# Annotate with intent information
	var intent: Dictionary = {
		"type": String(action.get("type", "wait")),
	}

	match intent["type"]:
		"attack":
			var target = action.get("target")
			if target and is_instance_valid(target):
				intent["target_pos"] = target.grid_pos
				# Mark as lethal if expected damage could kill the target
				var expected_dmg = int((enemy.weapon_damage[0] + enemy.weapon_damage[1]) / 2.0)
				if target.current_hp <= expected_dmg:
					intent["lethal"] = true
				else:
					intent["lethal"] = false
		"move", "move_to_cover":
			intent["target_pos"] = Vector2i(action.get("target_pos", Vector2i(-1, -1)))
		"overwatch":
			pass
		"wait":
			pass

	return {"action": action, "intent": intent}


## Check if an enemy has line of sight to a target cell.
func has_los_to(enemy: Node, target_pos: Vector2i) -> bool:
	if _width <= 0 or _height <= 0:
		return false
	return VisionSystem.has_line_of_sight(
		enemy.grid_pos, target_pos,
		_width, _height,
		func(pos): return MapLoader.get_blocker_at(_map_data, pos.x, pos.y) != 0
	)


## Get cells visible to an enemy (for AI targeting decisions).
func get_enemy_visible_cells(enemy: Node) -> Array[Vector2i]:
	if _width <= 0 or _height <= 0:
		return []
	return VisionSystem.get_visible_cells(
		enemy.grid_pos, enemy.vision_range,
		_width, _height,
		func(pos): return MapLoader.get_blocker_at(_map_data, pos.x, pos.y) != 0
	)
