## 行动系统
## 处理单位的移动、攻击、技能、物品、警戒等所有行动
extends Node
class_name ActionSystem

var map_data: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

## 执行移动
func execute_move(unit: Node, target: Vector2i) -> bool:
	if not unit.can_move():
		return false

	# 检查目标格是否可达
	var reachable = Pathfinding.get_reachable_cells(
		unit.grid_pos, unit.move_points,
		map_data.size.width, map_data.size.height,
		_get_move_cost.bind(unit.job),
		_is_blocked
	)

	if not reachable.has(target):
		return false

	# 计算路径
	var path = Pathfinding.find_path(
		unit.grid_pos, target,
		map_data.size.width, map_data.size.height,
		_get_move_cost.bind(unit.job),
		_is_blocked
	)

	if path.size() == 0:
		return false

	# 消耗移动点
	var cost = reachable[target]
	unit.move_points -= cost
	unit.move_to(target)

	return true

## 执行攻击
func execute_attack(attacker: Node, target: Node) -> Dictionary:
	if not attacker.can_act():
		return {success = false, reason = "cannot_act"}

	var dist = GridSystem.manhattan_distance(attacker.grid_pos, target.grid_pos)
	if dist < attacker.weapon_range[0] or dist > attacker.weapon_range[1]:
		return {success = false, reason = "out_of_range"}

	# 检查视线
	var has_los = VisionSystem.has_line_of_sight(
		attacker.grid_pos, target.grid_pos,
		map_data.size.width, map_data.size.height,
		_is_vision_blocking
	)
	if not has_los:
		return {success = false, reason = "no_line_of_sight"}

	# 消耗 AP
	if not attacker.spend_ap(1):
		return {success = false, reason = "no_ap"}

	# 计算掩体
	var cover = VisionSystem.calculate_cover(
		target.grid_pos, attacker.grid_pos,
		func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	)

	# 结算攻击
	var result = CombatFormulas.resolve_attack(
		attacker.base_hit,
		attacker.height, target.height,
		cover, dist, attacker.weapon_optimal_range,
		int((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2),
		target.armor,
		attacker.crit_chance, attacker.crit_multiplier,
		target.dodge, MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y),
		rng
	)

	if result.hit:
		target.take_damage(result.damage)

		# 触发攻击者特殊效果
		_process_attack_effects(attacker, target, result)

	# 暴露位置（非消音武器）
	# TODO: 检查武器是否有消音

	return {success = true, result = result}

## 执行技能
func execute_skill(caster: Node, skill_id: String, target_data: Dictionary) -> Dictionary:
	var skill = _get_skill_data(skill_id)
	if skill.is_empty():
		return {success = false, reason = "skill_not_found"}

	# 检查 AP
	var ap_cost = skill.get("ap_cost", 1)
	if caster.current_ap < ap_cost:
		return {success = false, reason = "no_ap"}

	# 检查冷却
	if skill.has("cooldown_remaining") and skill.cooldown_remaining > 0:
		return {success = false, reason = "on_cooldown"}

	caster.spend_ap(ap_cost)

	# 根据技能类型执行
	var skill_type = skill.get("type", "active")
	match skill_id:
		# 突击兵技能
		"asslt_dash_strike":
			return _skill_dash_strike(caster, target_data)
		"asslt_breach":
			return _skill_breach(caster, target_data)
		"asslt_adrenaline":
			return _skill_adrenaline(caster)
		"asslt_blink":
			return _skill_blink(caster, target_data)
		# 狙击手技能
		"snip_precise":
			return _skill_precise_shot(caster, target_data)
		"snip_overwatch":
			return _skill_overwatch(caster, target_data)
		"snip_death_mark":
			return _skill_death_mark(caster, target_data)
		# 重装兵技能
		"heavy_suppress":
			return _skill_suppress(caster, target_data)
		"heavy_grenade":
			return _skill_grenade(caster, target_data)
		"heavy_taunt":
			return _skill_taunt(caster)
		# 医疗兵技能
		"medic_heal":
			return _skill_heal(caster, target_data)
		"medic_revive":
			return _skill_revive(caster, target_data)
		"medic_adrenaline_shot":
			return _skill_adrenaline_shot(caster, target_data)
		"medic_area_heal":
			return _skill_area_heal(caster, target_data)
		# 侦察兵技能
		"scout_stealth":
			return _skill_stealth(caster)
		"scout_scan":
			return _skill_scan(caster, target_data)
		"scout_mark":
			return _skill_mark(caster, target_data)
		"scout_trap":
			return _skill_trap(caster, target_data)
		# 通用技能
		"gen_overwatch":
			return _skill_overwatch(caster, target_data)
		"gen_hunker_down":
			return _skill_hunker_down(caster)
		"gen_sprint":
			return _skill_sprint(caster)
		_:
			return {success = false, reason = "skill_not_implemented"}

## 使用物品
func use_item(unit: Node, item_id: String, target: Node = null) -> Dictionary:
	var item = GameData.get_item(item_id)
	if item.is_empty():
		return {success = false, reason = "item_not_found"}

	# 检查 AP
	var ap_cost = item.get("ap_cost", 1)
	if not unit.spend_ap(ap_cost):
		return {success = false, reason = "no_ap"}

	var effect = item.get("effect", {})
	var actual_target = target if target else unit

	# 处理治疗效果
	if effect.has("heal"):
		actual_target.heal(effect.heal)

	# 处理移除状态
	if effect.has("remove_status"):
		actual_target.remove_status(effect.remove_status)
	if effect.has("remove_all_debuffs"):
		for status in actual_target.status_effects:
			if status.id.begins_with("debuff_") or status.id in ["bleed", "burn", "poison", "stun", "suppress", "fear", "blind", "slow", "jammed", "rooted", "disarmed", "silenced"]:
				actual_target.remove_status(status.id)

	# 处理添加状态
	if effect.has("add_status"):
		for status_id in effect.add_status:
			var duration = effect.add_status[status_id]
			actual_target.add_status(status_id, duration)

	# 处理复活
	if effect.get("revive", false):
		if actual_target.is_downed:
			actual_target.is_alive = true
			actual_target.is_downed = false
			actual_target.current_hp = int(actual_target.max_hp * effect.get("hp_percent", 0.3))

	# 处理投掷物
	if item.get("type") == "throwable":
		return _use_throwable(unit, item, target_data)

	# 处理陷阱
	if item.get("type") == "trap":
		return _place_trap(unit, item)

	return {success = true, item = item_id, target = actual_target.unit_name}

## 进入警戒
func enter_overwatch(unit: Node) -> bool:
	if unit.current_ap < 1:
		return false
	unit.spend_ap(1)
	unit.add_status("overwatch", 1)
	return true

## 警戒触发检查
func check_overwatch_trigger(moving_unit: Node, from_pos: Vector2i, to_pos: Vector2i) -> Array[Dictionary]:
	var triggers: Array[Dictionary] = []
	var all_units = GameManager.player_units + GameManager.enemy_units

	for watcher in all_units:
		if not watcher.is_alive or not watcher.has_status("overwatch"):
			continue
		if watcher.team == moving_unit.team:
			continue

		# 检查目标格是否在 watcher 的警戒范围内
		var dist = GridSystem.manhattan_distance(watcher.grid_pos, to_pos)
		if dist > watcher.weapon_range[1]:
			continue

		# 检查视线
		var has_los = VisionSystem.has_line_of_sight(
			watcher.grid_pos, to_pos,
			map_data.size.width, map_data.size.height,
			_is_vision_blocking
		)
		if not has_los:
			continue

		# 执行警戒射击
		var result = execute_attack(watcher, moving_unit)
		if result.success:
			triggers.append({
				watcher = watcher,
				target = moving_unit,
				result = result.result
			})

		# 警戒射击只触发一次
		watcher.remove_status("overwatch")

	return triggers

## 结束单位行动
func end_unit_action(unit: Node) -> void:
	unit.move_points = 0  # 移动点归零
	# AP 可以保留用于警戒

## ===== 技能实现 =====

func _skill_dash_strike(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {success = false}

	# 移动到目标旁边
	var adjacent = _find_adjacent_to(target_pos)
	if adjacent.x < 0:
		return {success = false}

	caster.move_to(adjacent)

	# 找到目标单位
	var target = _get_unit_at(target_pos)
	if target:
		var result = execute_attack(caster, target)
		if result.success:
			result.result.hit_chance = minf(1.0, result.result.get("hit_chance", 0) + 0.2)
	return {success = true, moved_to = adjacent}

func _skill_breach(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {success = false}

	# 破坏相邻掩体
	var blocker = MapLoader.get_blocker_at(map_data, target_pos.x, target_pos.y)
	if blocker == 6 or blocker == 7:  # wall or crate
		map_data.layers.blocker[target_pos.y][target_pos.x] = 0
		# 造成范围伤害
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
				var unit = _get_unit_at(pos)
				if unit and unit.team != caster.team:
					unit.take_damage(30)
		return {success = true, destroyed = target_pos}
	return {success = false, reason = "no_destructible"}

func _skill_adrenaline(caster: Node) -> Dictionary:
	caster.add_status("adrenaline", 1)
	caster.current_ap = min(caster.current_ap + 1, caster.max_ap + 1)
	return {success = true}

func _skill_blink(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {success = false}
	if not MapLoader.is_passable(map_data, target_pos.x, target_pos.y):
		return {success = false}
	caster.move_to(target_pos)
	return {success = true, teleported = true}

func _skill_precise_shot(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {success = false}
	var result = execute_attack(caster, target)
	if result.success:
		# 精准射击命中+30暴击+20%
		pass
	return result

func _skill_overwatch(caster: Node, target_data: Dictionary) -> Dictionary:
	enter_overwatch(caster)
	return {success = true}

func _skill_death_mark(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {success = false}
	target.add_status("marked", 2)
	return {success = true, target = target.unit_name}

func _skill_suppress(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {success = false}
	target.add_status("suppress", 1)
	return {success = true, target = target.unit_name}

func _skill_grenade(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {success = false}

	# 3x3 范围伤害
	var damage = 50
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team != caster.team:
				unit.take_damage(damage)
			# 破坏掩体
			var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
			if blocker == 7:  # crate
				map_data.layers.blocker[pos.y][pos.x] = 0

	return {success = true, area = "3x3", center = target_pos}

func _skill_taunt(caster: Node) -> Dictionary:
	caster.add_status("taunting", 1)
	return {success = true}

func _skill_heal(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit", caster)
	target.heal(40)
	# 紧急护盾
	target.add_status("barrier", 2, {amount = 10})
	return {success = true, healed = 40, target = target.unit_name}

func _skill_revive(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target or not target.is_downed:
		return {success = false, reason = "not_downed"}
	target.is_alive = true
	target.is_downed = false
	target.current_hp = int(target.max_hp * 0.3)
	return {success = true, revived = target.unit_name}

func _skill_adrenaline_shot(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit", caster)
	target.add_status("adrenaline", 1)
	target.current_ap = min(target.current_ap + 1, target.max_ap + 1)
	return {success = true, target = target.unit_name}

func _skill_area_heal(caster: Node, target_data: Dictionary) -> Dictionary:
	var center = target_data.get("position", caster.grid_pos)
	var healed_count = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector2i(center.x + dx, center.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team == caster.team:
				unit.heal(20)
				healed_count += 1
	return {success = true, healed_count = healed_count}

func _skill_stealth(caster: Node) -> Dictionary:
	caster.add_status("invisible", 1)
	return {success = true}

func _skill_scan(caster: Node, target_data: Dictionary) -> Dictionary:
	var center = target_data.get("position", caster.grid_pos)
	var revealed: Array = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var pos = Vector2i(center.x + dx, center.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team != caster.team:
				unit.add_status("revealed", 2)
				revealed.append(unit.unit_name)
	return {success = true, revealed = revealed}

func _skill_mark(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {success = false}
	target.add_status("marked", 2)
	return {success = true, target = target.unit_name}

func _skill_trap(caster: Node, target_data: Dictionary) -> Dictionary:
	var pos = target_data.get("position", caster.grid_pos)
	# TODO: 在地图上放置陷阱对象
	return {success = true, trap_pos = pos}

func _skill_hunker_down(caster: Node) -> Dictionary:
	caster.add_status("hunker", 1)
	return {success = true}

func _skill_sprint(caster: Node) -> Dictionary:
	caster.move_points += 2
	caster.add_status("charge", 1)
	return {success = true}

## ===== 辅助函数 =====

func _get_move_cost(pos: Vector2i, job: String) -> int:
	return GameData.get_move_cost(job, MapLoader.get_terrain_at(map_data, pos.x, pos.y))

func _is_blocked(pos: Vector2i) -> bool:
	return not MapLoader.is_passable(map_data, pos.x, pos.y)

func _is_vision_blocking(pos: Vector2i) -> bool:
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	return blocker == 6  # wall blocks vision

func _get_skill_data(skill_id: String) -> Dictionary:
	# TODO: 从技能数据文件加载
	return {}

func _get_unit_at(pos: Vector2i) -> Dictionary:
	for unit in GameManager.player_units + GameManager.enemy_units:
		if unit.is_alive and unit.grid_pos == pos:
			return unit
	return null

func _find_adjacent_to(pos: Vector2i) -> Vector2i:
	for neighbor in GridSystem.get_neighbors(pos):
		if MapLoader.is_passable(map_data, neighbor.x, neighbor.y):
			var unit = _get_unit_at(neighbor)
			if not unit:
				return neighbor
	return Vector2i(-1, -1)

func _process_attack_effects(attacker: Node, target: Node, result: Dictionary) -> void:
	# 处理武器特殊效果
	# TODO: 根据武器 special 字段处理
	pass

func _use_throwable(unit: Node, item: Dictionary, target_data: Dictionary) -> Dictionary:
	var effect = item.get("effect", {})
	var area = effect.get("area", "1x1")
	var damage = effect.get("damage", [0, 0])

	# TODO: 在目标位置创建效果区域
	return {success = true, item = item.name, area = area}

func _place_trap(unit: Node, item: Dictionary) -> Dictionary:
	# TODO: 在单位位置放置陷阱
	return {success = true, trap = item.name}

## 设置地图数据
func set_map_data(data: Dictionary) -> void:
	map_data = data
