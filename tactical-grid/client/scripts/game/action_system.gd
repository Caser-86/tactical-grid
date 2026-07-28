## 行动系统
## 处理单位的移动、攻击、技能、物品、警戒等所有行动
extends Node
class_name ActionSystem

var map_data: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 单位列表（由 BattleController 设置）
var player_units: Array = []
var enemy_units: Array = []

## 陷阱列表（运行时状态）：[{pos, owner_team, item}]
var traps: Array[Dictionary] = []

## 噪声事件列表（消音判定用）：[{pos, radius, silent}]
var noise_events: Array[Dictionary] = []

## 地面效果列表（烟雾/火焰/毒雾等）：[{pos, type, duration, data}]
var ground_effects: Array[Dictionary] = []

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

	# 检查路径上是否触发陷阱
	_check_trap_trigger(unit, target)

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

	# 武器 special 前处理：调整命中/伤害/护甲参数
	var special: String = attacker.weapon_special
	var effective_armor = target.armor
	var effective_hit = attacker.base_hit
	var effective_damage = int((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2)
	var effective_crit = attacker.crit_chance
	var force_hit = false
	var force_crit = false

	# pierce_50_ignore_half_cover：穿透50%护甲，忽略半掩体
	if special == "pierce_50_ignore_half_cover":
		effective_armor = int(target.armor * 0.5)
		if cover == "half":
			cover = "none"
	# pierce_all_charge_1_turn：充能1回合后全穿透（简化为直接全穿透）
	elif special == "pierce_all_charge_1_turn":
		effective_armor = 0
		cover = "none"
	# silent_ignore_armor：消音穿甲
	elif special == "silent_ignore_armor":
		effective_armor = 0
	# setup_bonus_30_hit：架设命中+30
	elif special == "setup_bonus_30_hit":
		effective_hit += 30
	# setup_2_turns_guaranteed_hit_crit：架设2回合必中必暴
	elif special == "setup_2_turns_guaranteed_hit_crit":
		force_hit = true
		force_crit = true
	# close_range_bonus_1.3x_at_2_tiles：距离2格时伤害x1.3
	elif special == "close_range_bonus_1.3x_at_2_tiles" and dist == 2:
		effective_damage = int(effective_damage * 1.3)
	# close_range_bonus_1.4x：近距离伤害x1.4
	elif special == "close_range_bonus_1.4x" and dist <= 2:
		effective_damage = int(effective_damage * 1.4)
	# silent_crit_plus_10：消音暴击+10%
	elif special == "silent_crit_plus_10":
		effective_crit += 0.10

	# 结算攻击
	var result = CombatFormulas.resolve_attack(
		effective_hit,
		attacker.height, target.height,
		cover, dist, attacker.weapon_optimal_range,
		effective_damage,
		effective_armor,
		effective_crit, attacker.crit_multiplier,
		target.dodge, MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y),
		rng
	)

	# 强制命中/暴击（架设类武器）
	if force_hit:
		result.hit = true
		result.dodged = false
	if force_crit:
		result.critical = true
		result.damage = int(result.damage * attacker.crit_multiplier) if result.damage > 0 else result.damage

	if result.hit:
		target.take_damage(result.damage)

		# 触发攻击者特殊效果
		_process_attack_effects(attacker, target, result)

		# 多次攻击：double_tap/triple_tap/burst_5
		var extra_hits = _get_extra_hit_count(special)
		for i in range(extra_hits):
			var extra_result = CombatFormulas.resolve_attack(
				effective_hit, attacker.height, target.height,
				cover, dist, attacker.weapon_optimal_range,
				effective_damage, effective_armor,
				effective_crit, attacker.crit_multiplier,
				target.dodge, MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y),
				rng
			)
			if extra_result.hit and target.is_alive:
				target.take_damage(extra_result.damage)
				_process_attack_effects(attacker, target, extra_result)

		# aoe_3x3_destroy_cover：范围伤害+破坏掩体
		if special == "aoe_3x3_destroy_cover":
			_apply_aoe_damage(attacker, target.grid_pos, 1, int(effective_damage * 0.5), true)

		# damage_heals_adjacent_ally：伤害治疗相邻友军
		if special == "damage_heals_adjacent_ally":
			_heal_adjacent_allies(attacker, int(result.damage * 0.5))

	# 消音判定：非消音武器产生噪声
	var is_silent = _is_weapon_silent(special)
	noise_events.append({
		"pos": attacker.grid_pos,
		"radius": 0 if is_silent else 5,
		"silent": is_silent
	})

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
func use_item(unit: Node, item_id: String, target: Node = null, target_data: Dictionary = {}) -> Dictionary:
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
	var all_units = player_units + enemy_units

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
	if result.success and result.result.hit:
		# 精准射击：命中后标记目标，下回合对该目标命中+30%暴击+20%
		target.add_status("marked", 1, {"hit_bonus": 30, "crit_bonus": 0.20})
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
	# 在指定位置放置陷阱（使用 mine 物品作为默认陷阱）
	var trap_item = GameData.get_item("mine")
	if trap_item.is_empty():
		trap_item = {"name": "陷阱", "effect": {"damage": 50, "knockback": true}}
	traps.append({
		"pos": pos,
		"owner_team": caster.team,
		"item": trap_item,
		"item_id": "mine"
	})
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
	return GameData.get_skill(skill_id)

func _get_unit_at(pos: Vector2i) -> Variant:
	for unit in player_units + enemy_units:
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
	# 处理武器 special 字段的命中后效果
	var special: String = attacker.weapon_special
	if special == "":
		return

	match special:
		# 医疗枪：伤害为负数即治疗
		"heal_40":
			# med_gun 的 damage 是 [-40, -40]，take_damage 已在主流程处理
			# 这里确保不超过 max_hp（take_damage 对负数会减血，需要用 heal 修正）
			pass
		"heal_50_remove_1_debuff":
			# 移除1个 debuff
			_remove_one_debuff(target)
		# 标记目标3回合
		"mark_target_3_turns":
			target.add_status("marked", 3)
		# 击杀回血10+出血3回合
		"kill_heal_10_bleed_3":
			if not target.is_alive:
				attacker.heal(10)
			else:
				target.add_status("bleed", 3)
		# 压制火力：被攻击者获得 suppress 状态
		"suppressing_fire":
			target.add_status("suppress", 1)
		# 5连发压制：被攻击者及周围1格敌人获得 suppress
		"burst_5_suppress_range_1":
			target.add_status("suppress", 1)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var pos = Vector2i(target.grid_pos.x + dx, target.grid_pos.y + dy)
					var unit = _get_unit_at(pos)
					if unit and unit.team != attacker.team:
						unit.add_status("suppress", 1)
		# 双持双击+击杀返还AP
		"dual_wield_double_strike_kill_refund_ap":
			if not target.is_alive:
				attacker.current_ap = mini(attacker.current_ap + 1, attacker.max_ap + 1)

## 判断武器是否消音
func _is_weapon_silent(special: String) -> bool:
	return special in ["silent", "silent_no_expose", "silent_crit_plus_10", "silent_ignore_armor"]

## 获取额外攻击次数
func _get_extra_hit_count(special: String) -> int:
	match special:
		"double_tap":
			return 1
		"triple_tap":
			return 2
		"burst_5":
			return 4
		"dual_wield_double_strike_kill_refund_ap":
			return 1
		_:
			return 0

## 应用范围伤害
func _apply_aoe_damage(attacker: Node, center: Vector2i, radius: int, damage: int, destroy_cover: bool) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			if pos.x < 0 or pos.y < 0:
				continue
			if pos.x >= int(map_data.size.width) or pos.y >= int(map_data.size.height):
				continue
			# 伤害非攻击者队伍的单位
			var unit = _get_unit_at(pos)
			if unit and unit.team != attacker.team:
				unit.take_damage(damage)
			# 破坏掩体
			if destroy_cover:
				var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
				if blocker == 7:  # crate
					map_data.layers.blocker[pos.y][pos.x] = 0

## 治疗相邻友军
func _heal_adjacent_allies(unit: Node, amount: int) -> void:
	for neighbor in GridSystem.get_neighbors(unit.grid_pos):
		var ally = _get_unit_at(neighbor)
		if ally and ally.team == unit.team and ally.is_alive:
			ally.heal(amount)

## 移除一个 debuff
func _remove_one_debuff(unit: Node) -> void:
	var debuff_ids = ["bleed", "burn", "poison", "stun", "suppress", "fear", "blind", "slow", "jammed", "rooted", "disarmed", "silenced"]
	for effect in unit.status_effects:
		if effect.id in debuff_ids:
			unit.remove_status(effect.id)
			return

## 使用投掷物
func _use_throwable(unit: Node, item: Dictionary, target_data: Dictionary) -> Dictionary:
	var effect = item.get("effect", {})
	var area_str = String(effect.get("area", "1x1"))
	var radius = _parse_area_radius(area_str)
	var target_pos = target_data.get("position", unit.grid_pos)

	# 伤害型投掷物（手雷、燃烧瓶等）
	if effect.has("damage"):
		var dmg_range = effect.get("damage", [0, 0])
		var dmg = int((dmg_range[0] + dmg_range[1]) / 2)
		_apply_aoe_damage(unit, target_pos, radius, dmg, bool(effect.get("destroy_cover", false)))

	# 机械伤害（EMP手雷）
	if effect.has("damage_mech"):
		var mech_dmg = int(effect.get("damage_mech", 0))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
				var target_unit = _get_unit_at(pos)
				if target_unit and target_unit.team != unit.team:
					# 机械单位（敌人 job 以 mech/robot/sentry 开头）受双倍伤害
					if target_unit.job.begins_with("mech") or target_unit.job.begins_with("robot") or target_unit.job.begins_with("sentry") or target_unit.job.begins_with("data_"):
						target_unit.take_damage(mech_dmg)
					else:
						target_unit.take_damage(int(mech_dmg * 0.5))
					# 禁用技能
					if effect.has("disable_skills"):
						target_unit.add_status("silenced", int(effect.get("disable_skills", 1)))

	# 添加状态效果
	if effect.has("add_status"):
		for status_id in effect.add_status:
			var duration = effect.add_status[status_id]
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
					var target_unit = _get_unit_at(pos)
					if target_unit and target_unit.team != unit.team:
						target_unit.add_status(status_id, duration)

	# 创建地面效果
	if effect.get("create_smoke", false):
		_create_ground_effect(target_pos, radius, "smoke", int(effect.get("duration", 2)))
	if effect.get("create_fire", false):
		_create_ground_effect(target_pos, radius, "fire", int(effect.get("duration", 2)))
	# 治疗雾
	if effect.has("heal_per_turn"):
		_create_ground_effect(target_pos, radius, "heal_mist", int(effect.get("duration", 3)), {"heal": int(effect.get("heal_per_turn", 15))})

	return {success = true, item = item.get("name", ""), area = area_str, center = target_pos}

## 解析范围字符串为半径（"3x3" -> 1, "5x5" -> 2, "1x1" -> 0）
func _parse_area_radius(area_str: String) -> int:
	if area_str == "1x1":
		return 0
	elif area_str == "3x3":
		return 1
	elif area_str == "5x5":
		return 2
	else:
		# 尝试解析 "NxN" 格式
		var parts = area_str.split("x")
		if parts.size() == 2:
			var n = int(parts[0])
			return int(n / 2)
	return 0

## 创建地面效果
func _create_ground_effect(center: Vector2i, radius: int, type: String, duration: int, data: Dictionary = {}) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			if pos.x < 0 or pos.y < 0:
				continue
			if pos.x >= int(map_data.size.width) or pos.y >= int(map_data.size.height):
				continue
			ground_effects.append({
				"pos": pos,
				"type": type,
				"duration": duration,
				"data": data
			})

## 放置陷阱
func _place_trap(unit: Node, item: Dictionary) -> Dictionary:
	var trap_pos = unit.grid_pos
	traps.append({
		"pos": trap_pos,
		"owner_team": unit.team,
		"item": item,
		"item_id": item.get("name", "")
	})
	return {success = true, trap = item.get("name", ""), pos = trap_pos}

## 检查陷阱触发（单位移动到某格时调用）
func _check_trap_trigger(unit: Node, pos: Vector2i) -> void:
	var triggered_indices: Array[int] = []
	for i in range(traps.size()):
		var trap = traps[i]
		if trap.pos == pos and trap.owner_team != unit.team:
			triggered_indices.append(i)
			_apply_trap_effect(unit, trap)
	# 从后往前移除已触发陷阱，避免索引错位
	for i in range(triggered_indices.size() - 1, -1, -1):
		traps.remove_at(triggered_indices[i])

## 应用陷阱效果
func _apply_trap_effect(unit: Node, trap: Dictionary) -> void:
	var item: Dictionary = trap.get("item", {})
	var effect = item.get("effect", {})
	# 伤害
	if effect.has("damage"):
		unit.take_damage(int(effect.get("damage", 0)))
	# 击退（简化为不移位，只标记）
	if effect.get("knockback", false):
		unit.add_status("rooted", 1)  # 击退后定身1回合
	# 减速+出血
	if effect.get("add_status_bleed", false):
		unit.add_status("bleed", 2)
	# 添加状态
	if effect.has("add_status"):
		for status_id in effect.add_status:
			var duration = effect.add_status[status_id]
			unit.add_status(status_id, duration)
	# 添加慢速状态（铁丝网的 slow）
	if effect.has("add_status_bleed") and not effect.has("add_status"):
		unit.add_status("slow", 2)

## 获取某位置的地面效果
func get_ground_effects_at(pos: Vector2i) -> Array:
	var result: Array = []
	for ge in ground_effects:
		if ge.pos == pos:
			result.append(ge)
	return result

## 获取噪声事件（供 AI 感知系统使用）
func get_noise_events() -> Array[Dictionary]:
	return noise_events

## 清空噪声事件（回合结束时调用）
func clear_noise_events() -> void:
	noise_events.clear()

## 回合开始时处理地面效果
func process_ground_effects_on_turn_start() -> void:
	var expired_indices: Array[int] = []
	for i in range(ground_effects.size()):
		var ge = ground_effects[i]
		var unit = _get_unit_at(ge.pos)
		if unit and unit.is_alive:
			match ge.type:
				"fire":
					unit.take_damage(int(unit.max_hp * 0.08))
				"heal_mist":
					if unit.team == "player":
						unit.heal(int(ge.data.get("heal", 15)))
		ge.duration -= 1
		if ge.duration <= 0:
			expired_indices.append(i)
	# 从后往前移除过期效果
	for i in range(expired_indices.size() - 1, -1, -1):
		ground_effects.remove_at(expired_indices[i])

## 设置地图数据
func set_map_data(data: Dictionary) -> void:
	map_data = data

## 设置单位列表
func set_units(players: Array, enemies: Array) -> void:
	player_units = players
	enemy_units = enemies
