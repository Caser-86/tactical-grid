extends RefCounted
class_name UtilityAI

static func decide_action(enemy, player_units, map_data, enemies) -> Dictionary:
	var enemy_info = GameData.get_enemy(String(enemy.job))
	var ai_weights = enemy_info.get("ai_weights", {})
	var actions = []

	for target in player_units:
		if not target.is_alive:
			continue

		var dist = GridSystem.manhattan_distance(enemy.grid_pos, target.grid_pos)
		if dist >= enemy.weapon_range[0] and dist <= enemy.weapon_range[1]:
			var cover = VisionSystem.calculate_cover(
				target.grid_pos,
				enemy.grid_pos,
				func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			)
			var hit_chance = CombatFormulas.calculate_hit(
				enemy.base_hit,
				enemy.height,
				target.height,
				cover,
				dist,
				enemy.weapon_optimal_range
			)
			var expected_damage = int((enemy.weapon_damage[0] + enemy.weapon_damage[1]) / 2.0 * hit_chance)
			var priority = _get_target_priority(target)
			var score = expected_damage * priority * _get_attack_weight(ai_weights)
			if target.current_hp <= expected_damage:
				score *= 2.0
			if cover == "full":
				score *= 0.85
			elif cover == "half":
				score *= 0.95
			actions.append({"type": "attack", "target": target, "score": score, "hit_chance": hit_chance})

	var nearest_player = _find_nearest_player(enemy, player_units)
	if nearest_player:
		var best_move = _find_best_move_position(enemy, nearest_player, map_data)
		if best_move.x >= 0:
			actions.append({"type": "move", "target_pos": best_move, "score": 30.0 * _get_approach_weight(ai_weights)})

	if enemy.current_hp < enemy.max_hp * 0.5:
		var cover_pos = _find_best_cover(enemy, player_units, map_data)
		if cover_pos.x >= 0:
			actions.append({"type": "move_to_cover", "target_pos": cover_pos, "score": 40.0 * _get_cover_weight(ai_weights)})

	if enemy.current_ap >= 1:
		actions.append({"type": "overwatch", "score": 15.0 * _get_overwatch_weight(ai_weights)})

	if actions.is_empty():
		return {"type": "wait"}

	actions.sort_custom(func(a, b): return a.score > b.score)
	return actions[0]

static func _get_target_priority(target) -> float:
	if target.job == "medic":
		return 1.5
	elif target.job == "sniper":
		return 1.3
	elif target.job == "scout":
		return 1.1
	elif target.job == "assault":
		return 1.0
	elif target.job == "heavy":
		return 0.8
	return 1.0

static func _get_attack_weight(ai_weights: Dictionary) -> float:
	var value = 0.3
	for key in ["attack", "flank", "suppress"]:
		value = maxi(value, float(ai_weights.get(key, 0.0)))
	return maxf(value, 0.1)

static func _get_approach_weight(ai_weights: Dictionary) -> float:
	return maxf(float(ai_weights.get("approach", 0.3)) + float(ai_weights.get("flank", 0.0)) * 0.5, 0.1)

static func _get_cover_weight(ai_weights: Dictionary) -> float:
	return maxf(float(ai_weights.get("take_cover", 0.2)) + float(ai_weights.get("reposition", 0.0)) * 0.3, 0.1)

static func _get_overwatch_weight(ai_weights: Dictionary) -> float:
	return maxf(float(ai_weights.get("guard_point", 0.2)) + float(ai_weights.get("patrol", 0.0)) * 0.2, 0.1)

static func _find_nearest_player(enemy, players):
	var nearest = null
	var min_dist = 9999
	for p in players:
		if not p.is_alive:
			continue
		var d = GridSystem.manhattan_distance(enemy.grid_pos, p.grid_pos)
		if d < min_dist:
			min_dist = d
			nearest = p
	return nearest

static func _get_step_cost(pos, map_data) -> int:
	var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	if blocker == 6 or blocker == 7 or terrain == 5:
		return -1
	if terrain == 2 or terrain == 3 or terrain == 8:
		return 2
	return 1

static func _find_best_move_position(enemy, target, map_data) -> Vector2i:
	var reachable = Pathfinding.get_reachable_cells(
		enemy.grid_pos,
		enemy.move_points,
		map_data.size.width,
		map_data.size.height,
		func(pos): return _get_step_cost(pos, map_data),
		func(pos): return not MapLoader.is_passable(map_data, pos.x, pos.y)
	)
	var best_pos = Vector2i(-1, -1)
	var best_score = -1.0
	for cell in reachable:
		if cell == enemy.grid_pos:
			continue
		var dist = GridSystem.manhattan_distance(cell, target.grid_pos)
		var score = 0.0
		if dist >= enemy.weapon_range[0] and dist <= enemy.weapon_range[1]:
			score = 50.0
		else:
			score = 30.0 - dist
		if score > best_score:
			best_score = score
			best_pos = cell
	return best_pos if best_score > 0 else Vector2i(-1, -1)

static func _find_best_cover(enemy, players, map_data) -> Vector2i:
	var reachable = Pathfinding.get_reachable_cells(
		enemy.grid_pos,
		enemy.move_points,
		map_data.size.width,
		map_data.size.height,
		func(pos): return _get_step_cost(pos, map_data),
		func(pos): return not MapLoader.is_passable(map_data, pos.x, pos.y)
	)
	var best_pos = Vector2i(-1, -1)
	var best_cover_score = -1.0
	for cell in reachable:
		if cell == enemy.grid_pos:
			continue
		var cover_score = 0.0
		for player in players:
			if not player.is_alive:
				continue
			var cover = VisionSystem.calculate_cover(
				cell,
				player.grid_pos,
				func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			)
			if cover == "full":
				cover_score += 40.0
			elif cover == "half":
				cover_score += 20.0
		if cover_score > best_cover_score:
			best_cover_score = cover_score
			best_pos = cell
	return best_pos if best_cover_score > 0 else Vector2i(-1, -1)
