extends RefCounted
class_name UtilityAI

## 敌人AI决策入口
static func decide_action(enemy, player_units, map_data, enemies) -> Dictionary:
	var enemy_info = GameData.get_enemy(String(enemy.job))
	var ai_weights = enemy_info.get("ai_weights", {})
	var width = map_data.get("size", {}).get("width", 10)
	var height = map_data.get("size", {}).get("height", 8)

	var reachable = _get_reachable(enemy, map_data, width, height)
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.is_empty():
		return {"type": "wait"}

	var actions = []

	# 1. 评估所有可执行攻击
	for target in alive_players:
		var dist = GridSystem.manhattan_distance(enemy.grid_pos, target.grid_pos)
		if dist >= enemy.weapon_range[0] and dist <= enemy.weapon_range[1]:
			var attack_score = _evaluate_attack(enemy, target, map_data, true)
			actions.append({"type": "attack", "target": target, "score": attack_score.score, "hit_chance": attack_score.hit_chance})

	# 2. 评估所有移动后的位置
	for cell in reachable:
		if cell == enemy.grid_pos:
			continue
		var move_score = _evaluate_move_position(enemy, cell, alive_players, map_data, reachable)
		if move_score > 0:
			actions.append({"type": "move", "target_pos": cell, "score": move_score})

	# 3. 评估警戒
	if enemy.current_ap >= 1:
		actions.append({"type": "overwatch", "score": 15.0 * _get_overwatch_weight(ai_weights)})

	if actions.is_empty():
		return {"type": "wait"}

	actions.sort_custom(func(a, b): return a.score > b.score)
	var best = actions[0]

	# 如果最佳行动是移动，且移动后可以直接攻击，则把目标信息也带上
	if best.type == "move":
		var best_target = _find_best_target_at_position(enemy, best.target_pos, alive_players, map_data)
		if best_target:
			best["follow_up_target"] = best_target

	return best

static func _evaluate_attack(enemy, target, map_data, in_place: bool) -> Dictionary:
	var cover = VisionSystem.calculate_cover(
		target.grid_pos,
		enemy.grid_pos,
		func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	)
	var dist = GridSystem.manhattan_distance(enemy.grid_pos, target.grid_pos)
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
	var score = expected_damage * priority * 10.0

	# 残血目标优先集火
	if target.current_hp <= expected_damage:
		score *= 2.5
	elif target.current_hp <= expected_damage * 2:
		score *= 1.6

	# 治疗兵和狙击手高优先级
	if target.job == "medic":
		score *= 1.4

	# 掩体惩罚
	if cover == "full":
		score *= 0.7
	elif cover == "half":
		score *= 0.9

	if in_place:
		score *= 1.15  # 原地攻击有轻微奖励，避免无意义移动

	return {"score": score, "hit_chance": hit_chance}

static func _evaluate_move_position(enemy, cell: Vector2i, players: Array, map_data: Dictionary, reachable: Dictionary) -> float:
	var width = map_data.get("size", {}).get("width", 10)
	var height = map_data.get("size", {}).get("height", 8)
	var best_attack_score = 0.0

	for target in players:
		var dist = GridSystem.manhattan_distance(cell, target.grid_pos)
		if dist < enemy.weapon_range[0] or dist > enemy.weapon_range[1]:
			continue
		# 模拟从 cell 攻击 target 的评分
		var cover = VisionSystem.calculate_cover(
			target.grid_pos, cell,
			func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
		)
		var hit_chance = CombatFormulas.calculate_hit(
			enemy.base_hit, enemy.height, target.height,
			cover, dist, enemy.weapon_optimal_range
		)
		var expected_damage = int((enemy.weapon_damage[0] + enemy.weapon_damage[1]) / 2.0 * hit_chance)
		var priority = _get_target_priority(target)
		var score = expected_damage * priority * 10.0

		# 侧翼奖励：目标在 cell 位置没有掩体保护，说明是侧翼/背面
		if cover == "none":
			score *= 1.5
		elif cover == "half":
			score *= 1.1

		# 残血集火
		if target.current_hp <= expected_damage:
			score *= 2.2
		elif target.current_hp <= expected_damage * 2:
			score *= 1.5

		if score > best_attack_score:
			best_attack_score = score

	# 如果没有进入射程，按距离奖励接近目标
	if best_attack_score <= 0:
		var nearest_dist = 9999
		for target in players:
			var d = GridSystem.manhattan_distance(cell, target.grid_pos)
			if d < nearest_dist:
				nearest_dist = d
		best_attack_score = maxf(0, 40 - nearest_dist * 2)

	# 自身掩体保护奖励
	var self_cover_score = 0.0
	for target in players:
		if not target.is_alive:
			continue
		var self_cover = VisionSystem.calculate_cover(
			cell, target.grid_pos,
			func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
		)
		if self_cover == "full":
			self_cover_score += 12.0
		elif self_cover == "half":
			self_cover_score += 6.0

	# 高地奖励
	var cell_height = MapLoader.get_height_at(map_data, cell.x, cell.y)
	var highground_bonus = cell_height * 4.0

	# 距离惩罚：避免走来走去浪费AP
	var move_cost = reachable.get(cell, 0)
	var move_penalty = move_cost * 0.8

	return best_attack_score + self_cover_score + highground_bonus - move_penalty

static func _find_best_target_at_position(enemy, cell: Vector2i, players: Array, map_data: Dictionary):
	var best_target = null
	var best_score = -1.0
	for target in players:
		var dist = GridSystem.manhattan_distance(cell, target.grid_pos)
		if dist < enemy.weapon_range[0] or dist > enemy.weapon_range[1]:
			continue
		var cover = VisionSystem.calculate_cover(
			target.grid_pos, cell,
			func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
		)
		var hit_chance = CombatFormulas.calculate_hit(
			enemy.base_hit, enemy.height, target.height,
			cover, dist, enemy.weapon_optimal_range
		)
		var expected_damage = int((enemy.weapon_damage[0] + enemy.weapon_damage[1]) / 2.0 * hit_chance)
		var score = expected_damage * _get_target_priority(target)
		if cover == "none":
			score *= 1.4
		if target.current_hp <= expected_damage:
			score *= 2.0
		if score > best_score:
			best_score = score
			best_target = target
	return best_target

static func _get_target_priority(target) -> float:
	if target.current_hp <= target.max_hp * 0.25:
		return 1.6
	if target.current_hp <= target.max_hp * 0.5:
		return 1.3
	match target.job:
		"medic": return 1.5
		"sniper": return 1.3
		"scout": return 1.1
		"assault": return 1.0
		"heavy": return 0.8
	return 1.0

static func _get_reachable(enemy, map_data: Dictionary, width: int, height: int) -> Dictionary:
	return Pathfinding.get_reachable_cells(
		enemy.grid_pos,
		enemy.move_points,
		width,
		height,
		func(pos): return _get_step_cost(pos, map_data),
		func(pos): return not MapLoader.is_passable(map_data, pos.x, pos.y)
	)

static func _get_step_cost(pos: Vector2i, map_data: Dictionary) -> int:
	var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	if blocker == 6 or blocker == 7 or terrain == 5:
		return -1
	if terrain == 2 or terrain == 3 or terrain == 8:
		return 2
	return 1

static func _get_attack_weight(ai_weights: Dictionary) -> float:
	var value = 0.3
	for key in ["attack", "flank", "suppress"]:
		value = maxf(value, float(ai_weights.get(key, 0.0)))
	return maxf(value, 0.1)

static func _get_approach_weight(ai_weights: Dictionary) -> float:
	return maxf(float(ai_weights.get("approach", 0.3)) + float(ai_weights.get("flank", 0.0)) * 0.5, 0.1)

static func _get_cover_weight(ai_weights: Dictionary) -> float:
	return maxf(float(ai_weights.get("take_cover", 0.2)) + float(ai_weights.get("reposition", 0.0)) * 0.3, 0.1)

static func _get_overwatch_weight(ai_weights: Dictionary) -> float:
	return maxf(float(ai_weights.get("guard_point", 0.2)) + float(ai_weights.get("patrol", 0.0)) * 0.2, 0.1)

## 保留旧接口兼容
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
