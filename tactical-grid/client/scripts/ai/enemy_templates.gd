## 敌人行为模板
## 定义不同敌人类型的 AI 行为模式
class_name EnemyTemplates

## 获取敌人行为配置
static func get_behavior_template(enemy_type: String) -> Dictionary:
	match enemy_type:
		"drone_scout":
			return {
				"aggression": 0.6,
				"target_priority": "nearest",
				"prefer_flank": true,
				"retreat_hp_percent": 0.3,
				"use_overwatch": false,
			}
		"sentry_basic":
			return {
				"aggression": 0.5,
				"target_priority": "nearest",
				"prefer_cover": true,
				"retreat_hp_percent": 0.2,
				"use_overwatch": true,
			}
		"sentry_sniper":
			return {
				"aggression": 0.4,
				"target_priority": "weakest",
				"prefer_highground": true,
				"retreat_hp_percent": 0.4,
				"use_overwatch": true,
			}
		"shield_bot":
			return {
				"aggression": 0.3,
				"target_priority": "frontline",
				"block_chokepoint": true,
				"retreat_hp_percent": 0.1,
				"use_overwatch": false,
			}
		"heavy_gunner":
			return {
				"aggression": 0.5,
				"target_priority": "clustered",
				"prefer_cover": true,
				"use_suppress": true,
				"retreat_hp_percent": 0.2,
			}
		"stealth_assassin":
			return {
				"aggression": 0.8,
				"target_priority": "medic",
				"prefer_flank": true,
				"use_stealth": true,
				"retreat_hp_percent": 0.5,
			}
		"flame_trooper":
			return {
				"aggression": 0.9,
				"target_priority": "nearest",
				"prefer_close": true,
				"retreat_hp_percent": 0.15,
			}
		_:
			return {
				"aggression": 0.5,
				"target_priority": "nearest",
				"retreat_hp_percent": 0.3,
				"use_overwatch": true,
			}

## 执行完整敌人回合
## 对单个敌人执行 AI 决策和行动
static func execute_turn(
	enemy: Node,  # Unit
	players: Array,
	map_data: Dictionary,
	enemies: Array,
	director: Node,  # EnemyDirector
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var actions_log: Array[Dictionary] = []
	var behavior = get_behavior_template(enemy.job)

	# 处理状态效果
	enemy.on_turn_start()

	if not enemy.is_alive:
		return actions_log

	# 检查是否被眩晕
	if enemy.has_status("stun"):
		actions_log.append({"unit": enemy.unit_name, "action": "stunned"})
		return actions_log

	var aggression = behavior.get("aggression", 0.5) * director.get_aggression()

	# 循环行动直到 AP 用完
	while enemy.current_ap > 0 and enemy.is_alive:
		var action = UtilityAI.decide_action(enemy, players, map_data, enemies)

		match action.type:
			"attack":
				var result = _execute_attack(enemy, action.target, map_data, rng)
				actions_log.append({
					"unit": enemy.unit_name,
					"action": "attack",
					"target": action.target.unit_name,
					"result": result
				})
				enemy.spend_ap(1)

			"move":
				var move_result = _execute_move(enemy, action.target_pos, map_data)
				if move_result:
					actions_log.append({
						"unit": enemy.unit_name,
						"action": "move",
						"to": action.target_pos
					})
					# 移动不消耗 AP，但消耗移动点
				else:
					break  # 移动失败，结束行动

			"move_to_cover":
				var move_result = _execute_move(enemy, action.target_pos, map_data)
				if move_result:
					actions_log.append({
						"unit": enemy.unit_name,
						"action": "move_to_cover",
						"to": action.target_pos
					})
				else:
					break

			"overwatch":
				if behavior.get("use_overwatch", false):
					enemy.add_status("overwatch", 1)
					enemy.spend_ap(1)
					actions_log.append({
						"unit": enemy.unit_name,
						"action": "overwatch"
					})
				else:
					break  # 不擅长警戒，结束

			"wait":
				break

			_:
				break

		# 检查是否应该撤退
		if behavior.get("retreat_hp_percent", 0.0) > 0:
			if float(enemy.current_hp) / float(enemy.max_hp) < behavior.retreat_hp_percent:
				# 撤退逻辑
				break

	return actions_log

## 执行攻击
static func _execute_attack(
	attacker: Node,
	target: Node,
	map_data: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var dist = GridSystem.manhattan_distance(attacker.grid_pos, target.grid_pos)
	var cover = VisionSystem.calculate_cover(
		target.grid_pos, attacker.grid_pos,
		func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	)

	var result = CombatFormulas.resolve_attack(
		attacker.base_hit,
		attacker.height, target.height,
		cover, dist, attacker.weapon_optimal_range,
		int((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2),
		target.armor,
		attacker.crit_chance, attacker.crit_multiplier,
		attacker.dodge, MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y),
		rng
	)

	if result.hit:
		target.take_damage(result.damage)

	return result

## 执行移动
static func _execute_move(
	unit: Node,
	target_pos: Vector2i,
	map_data: Dictionary
) -> bool:
	if target_pos.x < 0:
		return false
	if not MapLoader.is_passable(map_data, target_pos.x, target_pos.y):
		return false

	var path = Pathfinding.find_path(
		unit.grid_pos, target_pos,
		map_data.size.width, map_data.size.height,
		func(pos):
			var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
			var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			if blocker == 6 or blocker == 7 or terrain == 5:
				return -1
			match terrain:
				0,1,4,9: return 1
				2,3,8: return 2
				_: return 1
		func(pos): return not MapLoader.is_passable(map_data, pos.x, pos.y)
	)

	if path.size() == 0:
		return false

	# 计算路径成本
	var cost = 0
	for cell in path:
		var terrain = MapLoader.get_terrain_at(map_data, cell.x, cell.y)
		match terrain:
			0,1,4,9: cost += 1
			2,3,8: cost += 2
			_: cost += 1

	if cost > unit.move_points:
		# 走到能走的最远位置
		var move_cost = 0
		var last_pos = unit.grid_pos
		for cell in path:
			var terrain = MapLoader.get_terrain_at(map_data, cell.x, cell.y)
			var step_cost = 1
			match terrain:
				2,3,8: step_cost = 2
			if move_cost + step_cost > unit.move_points:
				break
			move_cost += step_cost
			last_pos = cell
		unit.move_to(last_pos)
	else:
		unit.move_to(target_pos)

	unit.position = GridSystem.grid_to_world(unit.grid_pos)
	return true
