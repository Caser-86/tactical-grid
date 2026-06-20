extends RefCounted
class_name EnemyTemplates

static func get_behavior_template(enemy_type: String) -> Dictionary:
	if enemy_type == "drone_scout":
		return {"aggression": 0.6, "retreat_hp_percent": 0.3, "use_overwatch": false}
	elif enemy_type == "sentry_basic":
		return {"aggression": 0.5, "retreat_hp_percent": 0.2, "use_overwatch": true}
	elif enemy_type == "sentry_sniper":
		return {"aggression": 0.4, "retreat_hp_percent": 0.4, "use_overwatch": true}
	elif enemy_type == "heavy_gunner":
		return {"aggression": 0.5, "retreat_hp_percent": 0.2}
	else:
		return {"aggression": 0.5, "retreat_hp_percent": 0.3, "use_overwatch": true}

static func _calc_step_cost(pos: Vector2i, map_data: Dictionary) -> int:
	var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	if blocker == 6 or blocker == 7 or terrain == 5:
		return -1
	if terrain == 2 or terrain == 3 or terrain == 8:
		return 2
	return 1

static func _check_blocked(pos: Vector2i, map_data: Dictionary) -> bool:
	return not MapLoader.is_passable(map_data, pos.x, pos.y)

static func execute_turn(enemy, players, map_data, enemies, director, rng) -> Array:
	var actions_log = []
	var behavior = get_behavior_template(enemy.job)
	var enemy_info = GameData.get_enemy(String(enemy.job))
	var special = enemy_info.get("special", [])
	enemy.on_turn_start()
	if not enemy.is_alive:
		return actions_log
	if enemy.has_status("stun"):
		actions_log.append({"unit": enemy.unit_name, "action": "stunned"})
		return actions_log

	if _try_support_action(enemy, players, enemies, special, actions_log):
		pass

	while enemy.current_ap > 0 and enemy.is_alive:
		var action = UtilityAI.decide_action(enemy, players, map_data, enemies)
		if action.type == "attack":
			var result = _do_attack(enemy, action.target, map_data, rng)
			actions_log.append({"unit": enemy.unit_name, "action": "attack", "result": result})
			enemy.spend_ap(1)
		elif action.type == "move":
			if _do_move(enemy, action.target_pos, map_data):
				actions_log.append({"unit": enemy.unit_name, "action": "move"})
			else:
				break
		elif action.type == "move_to_cover":
			if _do_move(enemy, action.target_pos, map_data):
				actions_log.append({"unit": enemy.unit_name, "action": "move_to_cover"})
			else:
				break
		elif action.type == "overwatch":
			if behavior.get("use_overwatch", false):
				enemy.add_status("overwatch", 1)
				enemy.spend_ap(1)
				actions_log.append({"unit": enemy.unit_name, "action": "overwatch"})
			else:
				break
		else:
			break
		if behavior.get("retreat_hp_percent", 0.0) > 0:
			if float(enemy.current_hp) / float(enemy.max_hp) < behavior.retreat_hp_percent:
				break
	return actions_log

static func _try_support_action(enemy, players, enemies, special: Array, actions_log: Array) -> bool:
	if enemy.current_ap <= 0 or not enemy.is_alive:
		return false
	if "heal_ally_40" in special or enemy.job == "combat_medic":
		var ally = _find_best_damaged_ally(enemy, players, enemies)
		if ally and GridSystem.manhattan_distance(enemy.grid_pos, ally.grid_pos) <= 5:
			ally.heal(40)
			ally.add_status("barrier", 2, {"amount": 10})
			enemy.spend_ap(1)
			actions_log.append({"unit": enemy.unit_name, "action": "heal_ally", "target": ally.unit_name})
			return true
	if "ally_barrier_40" in special or enemy.job == "shield_maestro":
		var shield_target = _find_best_damaged_ally(enemy, players, enemies)
		if shield_target and GridSystem.manhattan_distance(enemy.grid_pos, shield_target.grid_pos) <= 5:
			shield_target.add_status("barrier", 2, {"amount": 40})
			enemy.spend_ap(1)
			actions_log.append({"unit": enemy.unit_name, "action": "barrier_ally", "target": shield_target.unit_name})
			return true
	if "highland_bonus_x2" in special or enemy.job == "sentry_sniper":
		var best_pos = _find_best_highground_position(enemy, enemies, players, GameManager.current_map_data)
		if best_pos.x >= 0 and best_pos != enemy.grid_pos:
			_do_move(enemy, best_pos, GameManager.current_map_data)
			enemy.spend_ap(1)
			actions_log.append({"unit": enemy.unit_name, "action": "seek_highground"})
			return true
	return false

static func _do_attack(attacker, target, map_data, rng) -> Dictionary:
	var dist = GridSystem.manhattan_distance(attacker.grid_pos, target.grid_pos)
	var cover = VisionSystem.calculate_cover(
		target.grid_pos, attacker.grid_pos,
		func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	)
	var result = CombatFormulas.resolve_attack(
		attacker.base_hit, attacker.height, target.height,
		cover, dist, attacker.weapon_optimal_range,
		int((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2),
		target.armor, attacker.crit_chance, attacker.crit_multiplier,
		target.dodge, MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y), rng
	)
	if result.get("hit", false):
		target.take_damage(int(result.get("damage", 0)))
	return result

static func _do_move(unit, target_pos, map_data) -> bool:
	if target_pos.x < 0:
		return false
	if not MapLoader.is_passable(map_data, target_pos.x, target_pos.y):
		return false
	var path = Pathfinding.find_path(
		unit.grid_pos, target_pos,
		map_data.get("size", {}).get("width", 10), map_data.get("size", {}).get("height", 8),
		func(pos): return _calc_step_cost(pos, map_data),
		func(pos): return _check_blocked(pos, map_data)
	)
	if path.size() == 0:
		return false
	var cost = 0
	for cell in path:
		var t = MapLoader.get_terrain_at(map_data, cell.x, cell.y)
		if t == 2 or t == 3 or t == 8:
			cost += 2
		else:
			cost += 1
	if cost > unit.move_points:
		var mc = 0
		var last = unit.grid_pos
		for cell in path:
			var t = MapLoader.get_terrain_at(map_data, cell.x, cell.y)
			var sc = 2 if (t == 2 or t == 3 or t == 8) else 1
			if mc + sc > unit.move_points:
				break
			mc += sc
			last = cell
		unit.move_to(last)
	else:
		unit.move_to(target_pos)
	unit.spend_ap(1)
	return true

static func _find_best_damaged_ally(enemy, players, enemies):
	var allies = enemies if enemy.team == "enemy" else players
	var best = null
	var best_missing := 0
	for ally in allies:
		if not ally.is_alive or ally == enemy:
			continue
		var missing = ally.max_hp - ally.current_hp
		if missing > best_missing:
			best_missing = missing
			best = ally
	return best

static func _find_best_highground_position(enemy, enemies, players, map_data) -> Vector2i:
	var reachable = Pathfinding.get_reachable_cells(
		enemy.grid_pos, enemy.move_points,
		map_data.get("size", {}).get("width", 10), map_data.get("size", {}).get("height", 8),
		func(pos): return _calc_step_cost(pos, map_data),
		func(pos): return _check_blocked(pos, map_data)
	)
	var best_pos = Vector2i(-1, -1)
	var best_score := -9999.0
	for cell in reachable:
		if cell == enemy.grid_pos:
			continue
		var height = MapLoader.get_height_at(map_data, cell.x, cell.y)
		var cover_score = 0.0
		for player in players:
			if not player.is_alive:
				continue
			var cover = VisionSystem.calculate_cover(
				cell, player.grid_pos,
				func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			)
			if cover == "full":
				cover_score += 1.5
			elif cover == "half":
				cover_score += 0.5
		var score = float(height) * 3.0 + cover_score
		if score > best_score:
			best_score = score
			best_pos = cell
	return best_pos
