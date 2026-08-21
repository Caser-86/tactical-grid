## Utility AI
## 每个敌人根据评分选择最优行动
class_name UtilityAI

## 评估所有可能行动并返回最优行动
static func decide_action(
	enemy: Node,
	player_units: Array,
	map_data: Dictionary,
	enemies: Array
) -> Dictionary:
	var actions: Array[Dictionary] = []

	# 1. 评估攻击行动
	for target in player_units:
		if not target.is_alive:
			continue
		var dist = GridSystem.manhattan_distance(enemy.grid_pos, target.grid_pos)
		if dist >= enemy.weapon_range[0] and dist <= enemy.weapon_range[1]:
			var cover = VisionSystem.calculate_cover(
				target.grid_pos, enemy.grid_pos,
				func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			)
			var hit_chance = CombatFormulas.calculate_hit(
				enemy.base_hit, enemy.height, target.height,
				cover, dist, enemy.weapon_optimal_range
			)
			# 评分：命中率 × 预期伤害 × 目标优先级
			var expected_damage = int((enemy.weapon_damage[0] + enemy.weapon_damage[1]) / 2.0 * hit_chance)
			var priority = _get_target_priority(target)
			var score = expected_damage * priority

			# 低血量目标加分
			if target.current_hp <= expected_damage:
				score *= 2.0  # 可击杀

			actions.append({
				"type": "attack",
				"target": target,
				"score": score,
				"hit_chance": hit_chance,
			})

	# 2. 评估移动行动（朝最近玩家移动）
	# 如果已经有攻击选项，降低移动优先级
	var has_attack_option = false
	for a in actions:
		if a.type == "attack":
			has_attack_option = true
			break
	var nearest_player = _find_nearest_player(enemy, player_units)
	if nearest_player:
		var best_move = _find_best_move_position(enemy, nearest_player, map_data, player_units, enemies)
		if best_move:
			var move_score = 30.0
			if has_attack_option:
				move_score = 5.0  # 已能攻击时很少移动
			actions.append({
				"type": "move",
				"target_pos": best_move,
				"score": move_score,
			})

	# 3. 评估寻找掩体
	if enemy.current_hp < enemy.max_hp * 0.5:
		var cover_pos = _find_best_cover(enemy, player_units, map_data, enemies)
		if cover_pos:
			actions.append({
				"type": "move_to_cover",
				"target_pos": cover_pos,
				"score": 40.0,  # 低血量时优先找掩体
			})

	# 4. 评估警戒（如果还有 AP）
	if enemy.current_ap >= 1:
		var overwatch_score = 15.0
		if has_attack_option:
			overwatch_score = 3.0  # 已能攻击时很少警戒
		actions.append({
			"type": "overwatch",
			"score": overwatch_score,
		})

	# 选择最高分行动
	if actions.size() == 0:
		return {"type": "wait"}

	actions.sort_custom(func(a, b): return a.score > b.score)
	return actions[0]

## 获取目标优先级
static func _get_target_priority(target: Node) -> float:
	match target.job:
		"medic":
			return 1.5  # 优先打医疗
		"sniper":
			return 1.3  # 狙击手威胁大
		"assault":
			return 1.0
		"heavy":
			return 0.8  # 重装血厚，优先级低
		"scout":
			return 1.1
		_:
			return 1.0

## 找最近玩家
static func _find_nearest_player(enemy: Node, players: Array) -> Node:
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

## 找最佳移动位置（接近目标但保持射程）
static func _find_best_move_position(
	enemy: Node,
	target: Node,
	map_data: Dictionary,
	players: Array,
	enemies: Array
) -> Vector2i:
	var cost_func = func(pos):
		var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
		var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
		if blocker == 6 or blocker == 7 or terrain == 5:
			return -1
		match terrain:
			0,1,4,9: return 1
			2,3,8: return 2
			_: return 1

	var blocked_func = func(pos):
		return not MapLoader.is_passable(map_data, pos.x, pos.y) or _occupied_by_other_unit(pos, enemy, players, enemies)

	var reachable = Pathfinding.get_reachable_cells(
		enemy.grid_pos,
		enemy.move_points,
		map_data.size.width,
		map_data.size.height,
		cost_func,
		blocked_func
	)

	var best_pos = Vector2i(-1, -1)
	var best_score = -1.0

	for cell in reachable:
		if cell == enemy.grid_pos:
			continue
		var dist = GridSystem.manhattan_distance(cell, target.grid_pos)
		# 评分：越接近最佳射程越好
		var score = 0.0
		if dist >= enemy.weapon_range[0] and dist <= enemy.weapon_range[1]:
			score = 50.0  # 在射程内
		else:
			score = 30.0 - dist  # 越近越好

		if score > best_score:
			best_score = score
			best_pos = cell

	return best_pos if best_score > 0 else Vector2i(-1, -1)

## 找最佳掩体位置
static func _find_best_cover(
	enemy: Node,
	players: Array,
	map_data: Dictionary,
	enemies: Array
) -> Vector2i:
	var cost_func = func(pos):
		var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
		var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
		if blocker == 6 or blocker == 7 or terrain == 5:
			return -1
		match terrain:
			0,1,4,9: return 1
			2,3,8: return 2
			_: return 1

	var blocked_func = func(pos):
		return not MapLoader.is_passable(map_data, pos.x, pos.y) or _occupied_by_other_unit(pos, enemy, players, enemies)

	var reachable = Pathfinding.get_reachable_cells(
		enemy.grid_pos,
		enemy.move_points,
		map_data.size.width,
		map_data.size.height,
		cost_func,
		blocked_func
	)

	var best_pos = Vector2i(-1, -1)
	var best_cover_score = -1.0

	for cell in reachable:
		if cell == enemy.grid_pos:
			continue
		# 评估这个位置的掩体质量
		var cover_score = 0.0
		for player in players:
			if not player.is_alive:
				continue
			var cover = VisionSystem.calculate_cover(
				cell, player.grid_pos,
				func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			)
			match cover:
				"full": cover_score += 40.0
				"half": cover_score += 20.0

		if cover_score > best_cover_score:
			best_cover_score = cover_score
			best_pos = cell

	return best_pos if best_cover_score > 0 else Vector2i(-1, -1)

static func _occupied_by_other_unit(pos: Vector2i, moving_unit: Node, players: Array, enemies: Array) -> bool:
	for raw_unit in players + enemies:
		var unit: Node = raw_unit
		if unit == null or unit == moving_unit or not unit.is_alive:
			continue
		if unit.grid_pos == pos:
			return true
	return false
