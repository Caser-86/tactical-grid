extends Node
class_name ActionSystem

var map_data: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func set_map_data(data: Dictionary) -> void:
	map_data = data

func execute_move(unit: Node, target: Vector2i) -> bool:
	if not unit.can_move():
		return false

	var reachable = Pathfinding.get_reachable_cells(
		unit.grid_pos,
		unit.move_points,
		map_data.get("size", {}).get("width", 10),
		map_data.get("size", {}).get("height", 8),
		_get_move_cost.bind(unit.job),
		_is_blocked
	)

	if not reachable.has(target):
		return false

	var path = Pathfinding.find_path(
		unit.grid_pos,
		target,
		map_data.get("size", {}).get("width", 10),
		map_data.get("size", {}).get("height", 8),
		_get_move_cost.bind(unit.job),
		_is_blocked
	)
	if path.is_empty():
		return false

	unit.move_points -= int(reachable[target])
	unit.move_to(target)
	if AudioManager:
		AudioManager.sfx_move()
	return true

func execute_attack(
	attacker: Node,
	target: Node,
	attack_hit_bonus: int = 0,
	attack_crit_bonus: float = 0.0,
	armor_multiplier: float = 1.0,
	ignore_half_cover: bool = false,
	damage_multiplier: float = 1.0,
	force_silent: bool = false,
	consume_ap: bool = true
) -> Dictionary:
	if not attacker.is_alive or attacker.has_status("stun"):
		return {"success": false, "reason": "cannot_act"}
	if consume_ap and not attacker.can_act():
		return {"success": false, "reason": "cannot_act"}

	var dist = GridSystem.manhattan_distance(attacker.grid_pos, target.grid_pos)
	if dist < attacker.weapon_range[0] or dist > attacker.weapon_range[1]:
		return {"success": false, "reason": "out_of_range"}

	var has_los = VisionSystem.has_line_of_sight(
		attacker.grid_pos,
		target.grid_pos,
		map_data.get("size", {}).get("width", 10),
		map_data.get("size", {}).get("height", 8),
		_is_vision_blocking
	)
	if not has_los:
		return {"success": false, "reason": "no_line_of_sight"}

	if consume_ap and not attacker.spend_ap(1):
		return {"success": false, "reason": "no_ap"}

	var cover = VisionSystem.calculate_cover(
		target.grid_pos,
		attacker.grid_pos,
		func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	)

	var weapon_id = String(attacker.get("equipped_weapon"))
	if weapon_id == "Null":
		weapon_id = ""
	var weapon = GameData.get_weapon(weapon_id)
	var special = String(weapon.get("special", ""))
	var effective_cover = cover
	var effective_armor = target.armor
	var weapon_hit_bonus = int(weapon.get("hit_modifier", 0))
	var weapon_crit_bonus = 0.0
	var effective_crit_multiplier = attacker.crit_multiplier
	if special == "silent_ignore_armor" or special == "silent_ignores_half_armor":
		effective_armor = 0
	elif special == "armor_pierce_destroy_cover":
		effective_armor = maxi(int(target.armor / 2), 0)
		if effective_cover == "half":
			effective_cover = "none"
	elif special == "pierce_50_ignore_half_cover":
		effective_armor = maxi(int(target.armor / 2), 0)
		if effective_cover == "half":
			effective_cover = "none"
	elif special == "pierce_all_charge_1_turn":
		effective_armor = 0
	effective_armor = maxi(int(float(effective_armor) * armor_multiplier), 0)
	if ignore_half_cover and effective_cover == "half":
		effective_cover = "none"
	if special in ["setup_bonus_30_hit", "setup_2_turns_guaranteed_hit_crit"] and (attacker.has_status("setup") or attacker.has_status("steady")):
		weapon_hit_bonus += 30
	if special == "move_and_shoot":
		weapon_hit_bonus += 10
	if special == "setup_2_turns_guaranteed_hit_crit" and (attacker.has_status("setup") or attacker.has_status("steady")):
		weapon_hit_bonus += 25
		weapon_crit_bonus += 0.35
	if attacker.has_status("highground"):
		weapon_hit_bonus += 15
		weapon_crit_bonus += 0.10
	if attacker.job == "assault" and dist <= 1:
		weapon_hit_bonus += 15
		weapon_crit_bonus += 0.15
	if attacker.job == "sniper":
		effective_crit_multiplier += 0.5
		if dist >= attacker.weapon_optimal_range + 2:
			weapon_hit_bonus += 10
	if attacker.job == "assault" and float(target.current_hp) / float(max(target.max_hp, 1)) <= 0.3:
		damage_multiplier *= 1.25
	if attacker.job == "heavy" and float(attacker.current_hp) / float(max(attacker.max_hp, 1)) < 0.3:
		damage_multiplier *= 1.5

	var result = CombatFormulas.resolve_attack(
		attacker.base_hit + weapon_hit_bonus + attack_hit_bonus,
		attacker.height,
		target.height,
		effective_cover,
		dist,
		attacker.weapon_optimal_range,
		int(((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2) * damage_multiplier),
		effective_armor,
		attacker.crit_chance + weapon_crit_bonus + attack_crit_bonus,
		effective_crit_multiplier,
		target.dodge,
		MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y),
		rng
	)

	if result.get("hit", false):
		target.take_damage(int(result.get("damage", 0)))
		_apply_weapon_specials(attacker, target, result, weapon, special, dist)
		if attacker.job == "assault" and not target.is_alive:
			attacker.heal(20)

	if not weapon.get("silenced", false) and not force_silent and special not in ["silent", "silent_no_expose", "silent_ignore_armor", "silent_crit_plus_10", "silent_ignores_half_armor"]:
		attacker.add_status("revealed", 1)

	_play_attack_sfx(attacker, weapon, result)

	return {"success": true, "result": result}

func execute_skill(caster: Node, skill_id: String, target_data: Dictionary) -> Dictionary:
	var skill = _get_skill_data(skill_id)
	if skill.is_empty():
		return {"success": false, "reason": "skill_not_found"}

	var ap_cost = int(skill.get("ap_cost", 1))
	if caster.current_ap < ap_cost:
		return {"success": false, "reason": "no_ap"}

	if caster.get_skill_cooldown(skill_id) > 0:
		return {"success": false, "reason": "on_cooldown"}

	if not caster.spend_ap(ap_cost):
		return {"success": false, "reason": "no_ap"}

	var result: Dictionary = {}
	match skill_id:
		"asslt_dash_strike":
			result = _skill_dash_strike(caster, target_data)
		"asslt_breach":
			result = _skill_breach(caster, target_data)
		"asslt_storm_dash":
			result = _skill_storm_dash(caster, target_data)
		"asslt_chain_slash":
			result = _skill_chain_slash(caster, target_data)
		"asslt_adrenaline":
			result = _skill_adrenaline(caster)
		"asslt_blink":
			result = _skill_blink(caster, target_data)
		"snip_precise":
			result = _skill_precise_shot(caster, target_data)
		"snip_silent_shot":
			result = _skill_silent_shot(caster, target_data)
		"snip_double_tap":
			result = _skill_double_tap(caster, target_data)
		"snip_assassinate":
			result = _skill_assassinate(caster, target_data)
		"snip_piercing":
			result = _skill_piercing(caster, target_data)
		"snip_highground":
			result = _skill_highground(caster)
		"snip_suppressing_fire":
			result = _skill_suppressing_fire(caster, target_data)
		"scout_silent_kill":
			result = _skill_silent_kill(caster, target_data)
		"snip_overwatch":
			result = _skill_overwatch(caster)
		"snip_death_mark":
			result = _skill_death_mark(caster, target_data)
		"heavy_suppress":
			result = _skill_suppress(caster, target_data)
		"heavy_grenade":
			result = _skill_grenade(caster, target_data)
		"heavy_taunt":
			result = _skill_taunt(caster)
		"heavy_protect":
			result = _skill_protect(caster, target_data)
		"heavy_barrage":
			result = _skill_barrage(caster, target_data)
		"heavy_iron_fortress":
			result = _skill_iron_fortress(caster)
		"heavy_self_repair":
			result = _skill_self_repair(caster)
		"heavy_cleave":
			result = _skill_cleave(caster, target_data)
		"heavy_ground_slam":
			result = _skill_ground_slam(caster, target_data)
		"medic_heal":
			result = _skill_heal(caster, target_data)
		"medic_revive":
			result = _skill_revive(caster, target_data)
		"medic_adrenaline_shot":
			result = _skill_adrenaline_shot(caster, target_data)
		"medic_area_heal":
			result = _skill_area_heal(caster, target_data)
		"medic_cure":
			result = _skill_cure(caster, target_data)
		"medic_barrier_blast":
			result = _skill_barrier_blast(caster)
		"medic_pain_block":
			result = _skill_pain_block(caster, target_data)
		"medic_mass_cure":
			result = _skill_mass_cure(caster, target_data)
		"medic_stim_pack":
			result = _skill_stim_pack(caster, target_data)
		"scout_stealth":
			result = _skill_stealth(caster)
		"scout_scan":
			result = _skill_scan(caster, target_data)
		"scout_mark":
			result = _skill_mark(caster, target_data)
		"scout_trap":
			result = _skill_trap(caster, target_data)
		"scout_sabotage":
			result = _skill_sabotage(caster, target_data)
		"scout_recon_drone":
			result = _skill_recon_drone(caster, target_data)
		"scout_decoy":
			result = _skill_decoy(caster, target_data)
		"scout_shadow_step":
			result = _skill_shadow_step(caster, target_data)
		"gen_overwatch":
			result = _skill_overwatch(caster)
		"gen_hunker_down":
			result = _skill_hunker_down(caster)
		"gen_sprint":
			result = _skill_sprint(caster)
		"gen_reposition":
			result = _skill_reposition(caster)
		"gen_interact":
			result = _skill_interact(caster, target_data)
		_:
			# 通用路由：按 skill.effect 分发
			result = _dispatch_skill_effect(caster, skill, target_data)

	if not result.get("success", false):
		caster.current_ap = min(caster.current_ap + ap_cost, caster.max_ap)
		caster.ap_changed.emit(caster, caster.current_ap)
		return result

	var cooldown = int(skill.get("cooldown", 0))
	if cooldown > 0:
		caster.set_skill_cooldown(skill_id, cooldown)

	_play_skill_sfx(skill_id, skill)

	return result

## 通用效果分发器（支持通过skill.effect路由到具体处理）
func _dispatch_skill_effect(caster: Node, skill: Dictionary, target_data: Dictionary) -> Dictionary:
	var effect_name = String(skill.get("effect", ""))
	match effect_name:
		"whirlwind_attack":
			return _skill_whirlwind(caster, target_data, skill)
		"warcry_buff":
			return _skill_warcry(caster, target_data, skill)
		"aimed_shot":
			return _skill_aimed_shot(caster, target_data, skill)
		"execute_attack":
			return _skill_execute(caster, target_data, skill)
		"cone_burst":
			return _skill_cone_burst(caster, target_data, skill)
		"pierce_line":
			return _skill_pierce_line(caster, target_data, skill)
		"perfect_overwatch":
			return _skill_perfect_overwatch(caster, target_data, skill)
		"multi_shot":
			return _skill_multi_shot(caster, target_data, skill)
		"shield_wall":
			return _skill_shield_wall(caster, target_data, skill)
		"slam_attack":
			return _skill_slam(caster, target_data, skill)
		"fortify_buff":
			return _skill_fortify(caster, target_data, skill)
		"taunt":
			return _skill_taunt(caster)
		"shadow_step":
			return _skill_shadow_step_new(caster, target_data, skill)
		"trap_master":
			return _skill_trap_master(caster, target_data, skill)
		"team_stealth":
			return _skill_team_stealth(caster, target_data, skill)
		"bonus_ap":
			return _skill_bonus_ap(caster, target_data, skill)
		"aoe_heal":
			return _skill_aoe_heal(caster, target_data, skill)
		"revive":
			return _skill_revive_new(caster, target_data, skill)
		"shield_boost":
			return _skill_shield_boost(caster, target_data, skill)
		"overheal":
			return _skill_overheal(caster, target_data, skill)
		"emp_burst":
			return _skill_emp_burst(caster, target_data, skill)
		"deploy_turret":
			return _skill_deploy_turret(caster, target_data, skill)
		"self_buff":
			return _skill_self_buff(caster, target_data, skill)
		"hack_enemy":
			return _skill_hack_enemy(caster, target_data, skill)
		"inspire_team":
			return _skill_inspire(caster, target_data, skill)
		"extra_turn":
			return _skill_extra_turn(caster, target_data, skill)
		"rally_buff":
			return _skill_rally(caster, target_data, skill)
		"add_move_2":
			return _skill_add_move_2(caster, target_data, skill)
		_:
			return {"success": false, "reason": "effect_not_implemented: " + effect_name}

func _play_attack_sfx(attacker: Node, weapon: Dictionary, result: Dictionary) -> void:
	if not AudioManager:
		return
	var weapon_type = String(weapon.get("type", "pistol"))
	AudioManager.sfx_attack(weapon_type)
	if result.get("crit", false):
		AudioManager.sfx_critical()
	elif result.get("hit", false):
		AudioManager.sfx_hit()
	else:
		AudioManager.play_sfx("sfx_dodge")

func _play_skill_sfx(skill_id: String, skill: Dictionary) -> void:
	if not AudioManager:
		return
	var tags = skill.get("tags", [])
	if tags is Array:
		if "heal" in tags:
			AudioManager.sfx_heal()
			return
		if "explosive" in tags:
			AudioManager.sfx_explosion()
			return
	AudioManager.sfx_skill()

# === 新战棋技能处理函数 ===

func _skill_whirlwind(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var dmg_mod = float(skill.get("damage_mod", 0.7))
	var hit_mod = int(skill.get("hit_mod", -10))
	var radius = int(skill.get("radius", 1))
	var dmg = int((caster.weapon_damage[0] + caster.weapon_damage[1]) * dmg_mod / 2.0)
	var targets_hit = 0
	for x in range(caster.grid_pos.x - radius, caster.grid_pos.x + radius + 1):
		for y in range(caster.grid_pos.y - radius, caster.grid_pos.y + radius + 1):
			var pos = Vector2i(x, y)
			if pos == caster.grid_pos:
				continue
			if abs(pos.x - caster.grid_pos.x) + abs(pos.y - caster.grid_pos.y) > radius:
				continue
			var u = _get_unit_at(pos)
			if u and u.team != caster.team:
				_apply_follow_up_damage(u, dmg)
				targets_hit += 1
	return {"success": true, "targets": targets_hit, "whirlwind": true}

func _skill_warcry(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var radius = int(skill.get("radius", 2))
	var hit_b = int(skill.get("buff_hit", 15))
	var crit_b = int(skill.get("buff_crit", 10))
	var duration = int(skill.get("duration", 3))
	for u in _get_all_units():
		if u.team != caster.team:
			continue
		if u == caster:
			continue
		if abs(u.grid_pos.x - caster.grid_pos.x) + abs(u.grid_pos.y - caster.grid_pos.y) > radius:
			continue
		u.add_status("warcry", duration, {"hit_mod": hit_b, "crit_mod": crit_b})
	caster.add_status("warcry", duration, {"hit_mod": hit_b, "crit_mod": crit_b})
	return {"success": true, "warcry": true}

func _skill_aimed_shot(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u or u.team == caster.team:
		return {"success": false, "reason": "no_target"}
	var dmg = int((caster.weapon_damage[0] + caster.weapon_damage[1]) / 2)
	_apply_follow_up_damage(u, dmg + 10)
	return {"success": true, "aimed": true, "target": u}

func _skill_execute(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u or u.team == caster.team:
		return {"success": false, "reason": "no_target"}
	var execute_bonus = float(skill.get("execute_bonus", 50)) / 100.0
	var low_bonus = float(skill.get("low_hp_bonus", 100)) / 100.0
	var dmg_mult = 1.0 + execute_bonus
	if u.current_hp / float(u.max_hp) < 0.3:
		dmg_mult = 1.0 + execute_bonus + low_bonus
	var dmg = int((caster.weapon_damage[0] + caster.weapon_damage[1]) * dmg_mult / 2.0)
	_apply_follow_up_damage(u, dmg)
	return {"success": true, "execute": true, "target": u}

func _skill_cone_burst(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var hits = int(skill.get("hits", 2))
	var dmg_mod = float(skill.get("damage_mod", 0.5))
	var range_max = int(skill.get("range", 3))
	var total_targets = 0
	for h in range(hits):
		for i in range(1, range_max + 1):
			var pos = caster.grid_pos + Vector2i(i, 0)
			var u = _get_unit_at(pos)
			if u and u.team != caster.team:
				_apply_follow_up_damage(u, int((caster.weapon_damage[0] + caster.weapon_damage[1]) * dmg_mod / 2.0))
				total_targets += 1
	return {"success": true, "cone_burst": true, "targets": total_targets}

func _skill_pierce_line(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var dir = target_data.get("dir", Vector2i(1, 0))
	var range_max = int(skill.get("range", 15))
	var dmg_mod = float(skill.get("damage_mod", 0.6))
	var total = 0
	for i in range(1, range_max + 1):
		var pos = caster.grid_pos + Vector2i(dir.x * i, dir.y * i)
		var u = _get_unit_at(pos)
		if u and u.team != caster.team:
			_apply_follow_up_damage(u, int((caster.weapon_damage[0] + caster.weapon_damage[1]) * dmg_mod / 2.0))
			total += 1
	return {"success": true, "pierce_line": true, "targets": total}

func _skill_perfect_overwatch(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	caster.add_status("perfect_overwatch", int(skill.get("duration", 1)), {"crit_mod": 50, "overwatch_extra": 1})
	return {"success": true, "perfect_overwatch": true}

func _skill_multi_shot(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var shots = int(skill.get("shots", 3))
	var dmg = int((caster.weapon_damage[0] + caster.weapon_damage[1]) / 2)
	var hit = 0
	for u in _get_all_units():
		if hit >= shots:
			break
		if u.team != caster.team and u.is_alive:
			_apply_follow_up_damage(u, dmg)
			hit += 1
	return {"success": true, "multi_shot": true, "targets": hit}

func _skill_shield_wall(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var armor_mod = int(skill.get("armor_mod", 50))
	caster.add_status("shield_wall", 1, {"armor_mod": armor_mod, "lock_movement": true})
	return {"success": true, "shield_wall": true}

func _skill_slam(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos + Vector2i(1, 0))
	var u = _get_unit_at(pos)
	if not u or u.team == caster.team:
		return {"success": false, "reason": "no_target"}
	var kb = int(skill.get("knockback", 2))
	_apply_follow_up_damage(u, int((caster.weapon_damage[0] + caster.weapon_damage[1]) / 2))
	u.add_status("stun", 1, {})
	for i in range(kb):
		var step = u.grid_pos + Vector2i(pos.x - caster.grid_pos.x, pos.y - caster.grid_pos.y)
		if _is_blocked(step) or _get_unit_at(step) != null:
			break
		u.grid_pos = step
	return {"success": true, "slam": true, "target": u}

func _skill_fortify(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var radius = int(skill.get("radius", 2))
	var armor_mod = int(skill.get("armor_mod", 20))
	var hp_mod = int(skill.get("hp_mod", 15))
	var dur = int(skill.get("duration", 4))
	for u in _get_all_units():
		if u.team != caster.team:
			continue
		if abs(u.grid_pos.x - caster.grid_pos.x) + abs(u.grid_pos.y - caster.grid_pos.y) > radius:
			continue
		u.add_status("fortify", dur, {"armor_mod": armor_mod, "max_hp_bonus": hp_mod})
	return {"success": true, "fortify": true}

func _skill_shadow_step_new(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var range_max = int(skill.get("range", 7))
	if abs(pos.x - caster.grid_pos.x) + abs(pos.y - caster.grid_pos.y) > range_max:
		return {"success": false, "reason": "out_of_range"}
	if _is_blocked(pos) or _get_unit_at(pos) != null:
		return {"success": false, "reason": "blocked"}
	caster.grid_pos = pos
	if skill.get("stealth_on_arrive", false):
		caster.add_status("stealth", 1, {})
	return {"success": true, "shadow_step": true}

func _skill_trap_master(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var trap_count = int(skill.get("traps", 2))
	var pos = target_data.get("pos", caster.grid_pos)
	for i in range(trap_count):
		var p = pos + Vector2i(i, 0)
		if _is_blocked(p) or _get_unit_at(p) != null:
			continue
		var trap_id = "wire_trap"
		_append_map_object({
			"id": "trap_" + str(Time.get_ticks_msec()) + "_" + str(i),
			"type": "trap",
			"item_id": trap_id,
			"pos": p,
			"team": caster.team,
		})
	return {"success": true, "trap_master": true}

func _skill_team_stealth(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var dur = int(skill.get("duration", 3))
	for u in _get_all_units():
		if u.team == caster.team and u.is_alive:
			u.add_status("stealth", dur, {})
	return {"success": true, "team_stealth": true}

func _skill_bonus_ap(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var ap_bonus = int(skill.get("ap_bonus", 1))
	caster.current_ap = min(caster.current_ap + ap_bonus, caster.max_ap + ap_bonus)
	caster.ap_changed.emit(caster, caster.current_ap)
	return {"success": true, "bonus_ap": ap_bonus}

func _skill_aoe_heal(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var radius = int(skill.get("radius", 2))
	var amount = int(skill.get("amount", 30))
	var healed = 0
	for u in _get_all_units():
		if u.team != caster.team or not u.is_alive:
			continue
		if abs(u.grid_pos.x - caster.grid_pos.x) + abs(u.grid_pos.y - caster.grid_pos.y) > radius:
			continue
		u.current_hp = min(u.current_hp + amount, u.max_hp)
		healed += 1
		if skill.get("cleanse", false):
			_remove_negative_statuses(u)
	return {"success": true, "aoe_heal": true, "healed": healed}

func _skill_revive_new(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u:
		return {"success": false, "reason": "no_target"}
	if u.is_alive:
		return {"success": false, "reason": "target_alive"}
	var pct = float(skill.get("rez_percent", 0.5))
	u.current_hp = int(u.max_hp * pct)
	u.is_alive = true
	return {"success": true, "revived": u}

func _skill_shield_boost(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u or u.team != caster.team:
		return {"success": false, "reason": "no_ally"}
	var barrier = int(skill.get("barrier", 50))
	var armor_mod = int(skill.get("armor_mod", 15))
	var dur = int(skill.get("duration", 3))
	u.add_status("barrier", dur, {"amount": barrier})
	u.add_status("shielded", dur, {"armor_mod": armor_mod})
	return {"success": true, "shield_boost": true}

func _skill_overheal(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u or u.team != caster.team:
		return {"success": false, "reason": "no_ally"}
	var amount = int(skill.get("amount", 40))
	var new_hp = min(u.current_hp + amount, u.max_hp)
	var overheal = (u.current_hp + amount) - u.max_hp
	u.current_hp = new_hp
	if overheal > 0 and skill.get("shield_from_overheal", false):
		u.add_status("barrier", 2, {"amount": overheal})
	return {"success": true, "overheal": true}

func _skill_emp_burst(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var radius = int(skill.get("radius", 4))
	var stun_dur = int(skill.get("stun", 2))
	var hit_count = 0
	for u in _get_all_units():
		if u.team == caster.team or not u.is_alive:
			continue
		if abs(u.grid_pos.x - caster.grid_pos.x) + abs(u.grid_pos.y - caster.grid_pos.y) > radius:
			continue
		u.add_status("stun", stun_dur, {})
		u.add_status("jammed", stun_dur, {})
		hit_count += 1
	return {"success": true, "emp_burst": true, "targets": hit_count}

func _skill_deploy_turret(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	if _is_blocked(pos) or _get_unit_at(pos) != null:
		return {"success": false, "reason": "blocked"}
	_append_map_object({
		"id": "turret_" + str(Time.get_ticks_msec()),
		"type": "turret",
		"team": caster.team,
		"pos": pos,
		"duration": int(skill.get("duration", 3)),
		"damage": int(skill.get("turret_damage", 25)),
		"range": int(skill.get("turret_range", 6)),
	})
	return {"success": true, "turret_deployed": true}

func _skill_self_buff(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var dur = int(skill.get("duration", 2))
	caster.add_status("self_buff", dur, skill)
	return {"success": true, "self_buff": true}

func _skill_hack_enemy(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u or u.team == caster.team:
		return {"success": false, "reason": "no_target"}
	u.add_status("hacked", int(skill.get("duration", 1)), {"attacker_team": caster.team})
	return {"success": true, "hacked": true}

func _skill_inspire(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var ap_bonus = int(skill.get("ap_bonus", 1))
	var hit_mod = int(skill.get("hit_mod", 15))
	var dur = int(skill.get("duration", 1))
	for u in _get_all_units():
		if u.team == caster.team and u.is_alive:
			u.current_ap = min(u.current_ap + ap_bonus, u.max_ap + ap_bonus)
			u.add_status("inspired", dur, {"hit_mod": hit_mod})
			u.ap_changed.emit(u, u.current_ap)
	return {"success": true, "inspire": true}

func _skill_extra_turn(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var pos = target_data.get("pos", caster.grid_pos)
	var u = _get_unit_at(pos)
	if not u or u.team != caster.team:
		return {"success": false, "reason": "no_ally"}
	u.add_status("extra_turn", 1, {})
	return {"success": true, "extra_turn": true}

func _skill_rally(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	var hp_mod = int(skill.get("hp_mod", 25))
	var armor_mod = int(skill.get("armor_mod", 15))
	for u in _get_all_units():
		if u.team == caster.team and u.is_alive:
			u.max_hp += hp_mod
			u.current_hp += hp_mod
			u.armor = int(u.armor * (1.0 + armor_mod / 100.0))
	return {"success": true, "rally": true}

func _skill_add_move_2(caster: Node, target_data: Dictionary, skill: Dictionary) -> Dictionary:
	caster.move_points += 2
	return {"success": true, "add_move_2": true}

func use_item(unit: Node, item_id: String, target: Node = null, target_data: Dictionary = {}) -> Dictionary:
	var item = GameData.get_item(item_id)
	if item.is_empty():
		return {"success": false, "reason": "item_not_found"}

	var ap_cost = int(item.get("ap_cost", 1))
	if not unit.spend_ap(ap_cost):
		return {"success": false, "reason": "no_ap"}

	var item_type = String(item.get("type", ""))
	var effect = item.get("effect", {})
	var actual_target = target if target else unit
	var result: Dictionary = {}

	if item_type == "throwable":
		var throw_pos = target_data.get("position", actual_target.grid_pos if actual_target else unit.grid_pos)
		result = _use_throwable(unit, item, {"position": throw_pos})
		if not result.get("success", false):
			unit.current_ap = min(unit.current_ap + ap_cost, unit.max_ap)
			unit.ap_changed.emit(unit, unit.current_ap)
		return result

	if item_type == "trap":
		var trap_pos = target_data.get("position", unit.grid_pos)
		var trap_result = _place_trap(unit, item, trap_pos)
		if not trap_result.get("success", false):
			unit.current_ap = min(unit.current_ap + ap_cost, unit.max_ap)
			unit.ap_changed.emit(unit, unit.current_ap)
		return trap_result

	if effect.has("heal"):
		actual_target.heal(int(effect.get("heal", 0)))

	if effect.has("remove_status"):
		actual_target.remove_status(String(effect.get("remove_status", "")))

	if effect.has("remove_all_debuffs"):
		for status in actual_target.status_effects:
			if status.id.begins_with("debuff_") or status.id in ["bleed", "burn", "poison", "stun", "suppress", "fear", "blind", "slow", "jammed", "rooted", "disarmed", "silenced"]:
				actual_target.remove_status(status.id)

	if effect.has("add_status"):
		for status_id in effect.add_status:
			actual_target.add_status(status_id, int(effect.add_status[status_id]))

	if effect.get("revive", false) and actual_target.is_downed:
		actual_target.is_alive = true
		actual_target.is_downed = false
		actual_target.current_hp = int(actual_target.max_hp * float(effect.get("hp_percent", 0.3)))

	result = {"success": true, "item": item_id, "target": actual_target.unit_name}
	return result

func enter_overwatch(unit: Node) -> bool:
	if unit.current_ap < 1:
		return false
	unit.spend_ap(1)
	unit.add_status("overwatch", 1)
	return true

func check_overwatch_trigger(moving_unit: Node, from_pos: Vector2i, to_pos: Vector2i) -> Array:
	var triggers: Array = []
	var all_units = GameManager.player_units + GameManager.enemy_units
	for watcher in all_units:
		if not watcher.is_alive or not watcher.has_status("overwatch"):
			continue
		if watcher.team == moving_unit.team:
			continue

		var dist = GridSystem.manhattan_distance(watcher.grid_pos, to_pos)
		if dist > watcher.weapon_range[1]:
			continue

		var has_los = VisionSystem.has_line_of_sight(
			watcher.grid_pos,
			to_pos,
			map_data.get("size", {}).get("width", 10),
			map_data.get("size", {}).get("height", 8),
			_is_vision_blocking
		)
		if not has_los:
			continue

		var result = execute_attack(watcher, moving_unit, 0, 0.0, 1.0, false, 1.0, false, false)
		if result.get("success", false):
			triggers.append({
				"watcher": watcher,
				"target": moving_unit,
				"result": result.get("result", {})
			})
		watcher.remove_status("overwatch")
	return triggers

func end_unit_action(unit: Node) -> void:
	unit.move_points = 0

func _skill_dash_strike(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {"success": false}

	var adjacent = _find_adjacent_to(target_pos)
	if adjacent.x < 0:
		return {"success": false}

	caster.move_to(adjacent)
	var target = _get_unit_at(target_pos)
	if target:
		var result = execute_attack(caster, target, 0, 0.0, 1.0, false, 1.0, false, false)
		if result.get("success", false):
			return {"success": true, "moved_to": adjacent, "attack": result.get("result", {})}
	return {"success": true, "moved_to": adjacent}

func _skill_breach(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {"success": false}

	var blocker = MapLoader.get_blocker_at(map_data, target_pos.x, target_pos.y)
	if blocker != 6 and blocker != 7:
		return {"success": false, "reason": "no_destructible"}

	map_data.layers.blocker[target_pos.y][target_pos.x] = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team != caster.team:
				unit.take_damage(30)
	return {"success": true, "destroyed": target_pos}

func _skill_storm_dash(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {"success": false, "reason": "no_target"}

	var path = Pathfinding.find_path(
		caster.grid_pos,
		target_pos,
		map_data.get("size", {}).get("width", 10),
		map_data.get("size", {}).get("height", 8),
		_get_move_cost.bind(caster.job),
		_is_blocked
	)
	if path.is_empty():
		return {"success": false, "reason": "no_path"}

	var max_steps = mini(path.size() - 1, 5)
	var last_pos = caster.grid_pos
	for i in range(1, max_steps + 1):
		var step_pos = path[i]
		var unit = _get_unit_at(step_pos)
		if unit and unit.team != caster.team:
			unit.take_damage(20)
		last_pos = step_pos
	caster.move_to(last_pos)
	return {"success": true, "moved_to": last_pos, "path_length": max_steps}

func _skill_chain_slash(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	if GridSystem.manhattan_distance(caster.grid_pos, target.grid_pos) > 1:
		return {"success": false, "reason": "out_of_range"}
	var first = execute_attack(caster, target, 0, 0.0, 1.0, false, 1.0, false, false)
	var second = {"success": false}
	if first.get("success", false) and target.is_alive:
		second = execute_attack(caster, target, -5, 0.0, 1.0, false, 0.9, false, false)
	return {"success": true, "first": first.get("result", {}), "second": second.get("result", {})}

func _skill_adrenaline(caster: Node) -> Dictionary:
	caster.add_status("adrenaline", 1)
	caster.current_ap = min(caster.current_ap + 1, caster.max_ap + 1)
	return {"success": true}

func _skill_blink(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {"success": false}
	if not MapLoader.is_passable(map_data, target_pos.x, target_pos.y):
		return {"success": false}
	caster.move_to(target_pos)
	return {"success": true, "teleported": true}

func _skill_precise_shot(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false}
	var result = execute_attack(caster, target, 0, 0.0, 1.0, false, 1.0, false, false)
	if result.get("success", false):
		return {"success": true, "result": result.get("result", {})}
	return result

func _skill_silent_shot(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	var result = execute_attack(caster, target, 0, 0.0, 1.0, false, 1.0, true, false)
	return {"success": true, "result": result.get("result", {})}

func _skill_double_tap(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	var first = execute_attack(caster, target, 0, 0.0, 1.0, false, 1.0, false, false)
	var second = {"success": false}
	if first.get("success", false) and target.is_alive:
		second = execute_attack(caster, target, -10, 0.0, 1.0, false, 0.85, false, false)
	return {"success": true, "first": first.get("result", {}), "second": second.get("result", {})}

func _skill_assassinate(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	if not _is_isolated_target(target):
		return {"success": false, "reason": "target_not_isolated"}
	var result = execute_attack(caster, target, 20, 0.5, 0.5, true, 1.5, true, false)
	return {"success": true, "result": result.get("result", {})}

func _skill_piercing(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	var result = execute_attack(caster, target, 10, 0.0, 0.5, true, 1.0, false, false)
	return {"success": true, "result": result.get("result", {})}

func _skill_highground(caster: Node) -> Dictionary:
	caster.add_status("highground", 1)
	return {"success": true, "target": caster.unit_name}

func _skill_suppressing_fire(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	var result = execute_attack(caster, target, -10, 0.0, 1.0, false, 0.85, false, false)
	if result.get("success", false) and result.get("result", {}).get("hit", false):
		target.add_status("suppress", 1)
	return {"success": true, "result": result.get("result", {})}

func _skill_silent_kill(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	if target.current_hp > int(target.max_hp * 0.5):
		return {"success": false, "reason": "target_too_healthy"}
	var result = execute_attack(caster, target, 25, 0.2, 1.2, true, 1.5, true, false)
	if result.get("success", false) and not target.is_alive:
		caster.heal(20)
	return {"success": true, "result": result.get("result", {})}

func _skill_overwatch(caster: Node) -> Dictionary:
	enter_overwatch(caster)
	return {"success": true}

func _skill_death_mark(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false}
	target.add_status("marked", 2)
	return {"success": true, "target": target.unit_name}

func _skill_suppress(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false}
	target.add_status("suppress", 1)
	return {"success": true, "target": target.unit_name}

func _skill_grenade(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {"success": false}

	var damage = 50
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team != caster.team:
				unit.take_damage(damage)
			if MapLoader.get_blocker_at(map_data, pos.x, pos.y) == 7:
				map_data.layers.blocker[pos.y][pos.x] = 0

	return {"success": true, "area": "3x3", "center": target_pos}

func _skill_taunt(caster: Node) -> Dictionary:
	caster.add_status("taunting", 1)
	return {"success": true}

func _skill_protect(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	target.add_status("barrier", 2, {"amount": 25})
	caster.add_status("taunting", 1)
	return {"success": true, "target": target.unit_name}

func _skill_barrage(caster: Node, target_data: Dictionary) -> Dictionary:
	var center = target_data.get("position", Vector2i(-1, -1))
	if center.x < 0:
		return {"success": false, "reason": "no_target"}
	var hit_count := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector2i(center.x + dx, center.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team != caster.team:
				unit.take_damage(18)
				unit.add_status("suppress", 2)
				hit_count += 1
	return {"success": true, "center": center, "hit_count": hit_count}

func _skill_iron_fortress(caster: Node) -> Dictionary:
	caster.add_status("damage_reduction", 1, {"amount": 50})
	caster.add_status("steady", 1)
	return {"success": true, "target": caster.unit_name}

func _skill_self_repair(caster: Node) -> Dictionary:
	caster.heal(40)
	caster.add_status("barrier", 2, {"amount": 10})
	return {"success": true, "healed": 40, "target": caster.unit_name}

func _skill_cleave(caster: Node, target_data: Dictionary) -> Dictionary:
	var target_pos = target_data.get("position", Vector2i(-1, -1))
	if target_pos.x < 0:
		return {"success": false, "reason": "no_target"}
	var direction = target_pos - caster.grid_pos
	if direction == Vector2i.ZERO:
		return {"success": false, "reason": "invalid_target"}
	var step = Vector2i(signi(direction.x), signi(direction.y))
	if step.x != 0 and step.y != 0:
		if abs(direction.x) >= abs(direction.y):
			step.y = 0
		else:
			step.x = 0
	var hits := 0
	var positions := []
	for i in range(1, 4):
		var pos = caster.grid_pos + Vector2i(step.x * i, step.y * i)
		if not GridSystem.is_in_bounds(pos, map_data.get("size", {}).get("width", 10), map_data.get("size", {}).get("height", 8)):
			continue
		positions.append(pos)
		var unit = _get_unit_at(pos)
		if unit and unit.team != caster.team:
			unit.take_damage(30)
			hits += 1
	return {"success": true, "positions": positions, "hit_count": hits}

func _skill_ground_slam(caster: Node, target_data: Dictionary) -> Dictionary:
	var impacted := 0
	for neighbor in GridSystem.get_neighbors(caster.grid_pos):
		var unit = _get_unit_at(neighbor)
		if unit and unit.team != caster.team:
			unit.take_damage(50)
			if not unit.is_alive:
				impacted += 1
				continue
			var dx = neighbor.x - caster.grid_pos.x
			var dy = neighbor.y - caster.grid_pos.y
			var knock_pos = Vector2i(
				clampi(neighbor.x + signi(dx), 0, map_data.get("size", {}).get("width", 10) - 1),
				clampi(neighbor.y + signi(dy), 0, map_data.get("size", {}).get("height", 8) - 1)
			)
			if MapLoader.is_passable(map_data, knock_pos.x, knock_pos.y) and not _get_unit_at(knock_pos):
				unit.move_to(knock_pos)
			impacted += 1
	return {"success": true, "impacted": impacted}

func _skill_cure(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	_remove_negative_statuses(target)
	return {"success": true, "target": target.unit_name}

func _skill_barrier_blast(caster: Node) -> Dictionary:
	var allies := 0
	var team_units = GameManager.player_units if caster.team == "player" else GameManager.enemy_units
	for unit in team_units:
		if unit.is_alive:
			unit.add_status("barrier", 2, {"amount": 30})
			allies += 1
	return {"success": true, "affected": allies}

func _skill_pain_block(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	target.add_status("prevent_death", 2)
	return {"success": true, "target": target.unit_name}

func _skill_mass_cure(caster: Node, target_data: Dictionary) -> Dictionary:
	var center = target_data.get("position", caster.grid_pos)
	var affected := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var pos = Vector2i(center.x + dx, center.y + dy)
			var unit = _get_unit_at(pos)
			if unit and unit.team == caster.team:
				_remove_negative_statuses(unit)
				affected += 1
	return {"success": true, "affected": affected}

func _skill_stim_pack(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false, "reason": "no_target"}
	target.move_points += 2
	target.add_status("charge", 1)
	return {"success": true, "target": target.unit_name}

func _skill_heal(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit", caster)
	target.heal(40)
	target.add_status("barrier", 2, {"amount": 10})
	return {"success": true, "healed": 40, "target": target.unit_name}

func _skill_revive(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target or not target.is_downed:
		return {"success": false, "reason": "not_downed"}
	target.is_alive = true
	target.is_downed = false
	target.current_hp = int(target.max_hp * 0.3)
	return {"success": true, "revived": target.unit_name}

func _skill_adrenaline_shot(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit", caster)
	target.add_status("adrenaline", 1)
	target.current_ap = min(target.current_ap + 1, target.max_ap + 1)
	return {"success": true, "target": target.unit_name}

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
	return {"success": true, "healed_count": healed_count}

func _skill_stealth(caster: Node) -> Dictionary:
	caster.add_status("invisible", 1)
	return {"success": true}

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
	return {"success": true, "revealed": revealed}

func _skill_mark(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target:
		return {"success": false}
	target.add_status("marked", 2)
	return {"success": true, "target": target.unit_name}

func _skill_trap(caster: Node, target_data: Dictionary) -> Dictionary:
	var pos = target_data.get("position", caster.grid_pos)
	if not MapLoader.is_passable(map_data, pos.x, pos.y):
		return {"success": false, "reason": "invalid_position"}

	var trap_obj = {
		"id": "trap_" + str(randi()),
		"type": "trap",
		"x": pos.x,
		"y": pos.y,
		"team": caster.team,
		"damage": 30,
		"trigger": "enemy_enter",
	}
	_append_map_object(trap_obj)
	return {"success": true, "trap_pos": pos, "trap": trap_obj}

func _skill_sabotage(caster: Node, target_data: Dictionary) -> Dictionary:
	var pos = target_data.get("position", Vector2i(-1, -1))
	if pos.x < 0:
		return {"success": false, "reason": "no_target"}
	var damaged := 0
	if MapLoader.get_blocker_at(map_data, pos.x, pos.y) in [6, 7]:
		map_data.layers.blocker[pos.y][pos.x] = 0
		damaged += 1
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var scan_pos = Vector2i(pos.x + dx, pos.y + dy)
			var unit = _get_unit_at(scan_pos)
			if unit and unit.team != caster.team:
				unit.add_status("jammed", 2)
				damaged += 1
	return {"success": true, "position": pos, "affected": damaged}

func _skill_recon_drone(caster: Node, target_data: Dictionary) -> Dictionary:
	var pos = target_data.get("position", caster.grid_pos)
	if not MapLoader.is_passable(map_data, pos.x, pos.y):
		return {"success": false, "reason": "invalid_position"}
	var drone_obj = {
		"id": "drone_" + str(randi()),
		"type": "recon_drone",
		"x": pos.x,
		"y": pos.y,
		"team": caster.team,
		"radius": 3,
		"duration": 3,
		"name": "侦察无人机",
	}
	_append_map_object(drone_obj)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var scan_pos = Vector2i(pos.x + dx, pos.y + dy)
			var unit = _get_unit_at(scan_pos)
			if unit and unit.team != caster.team:
				unit.add_status("revealed", 2)
	return {"success": true, "position": pos, "drone": drone_obj}

func _skill_decoy(caster: Node, target_data: Dictionary) -> Dictionary:
	var pos = target_data.get("position", caster.grid_pos)
	if not MapLoader.is_passable(map_data, pos.x, pos.y):
		return {"success": false, "reason": "invalid_position"}
	var decoy_obj = {
		"id": "decoy_" + str(randi()),
		"type": "decoy",
		"x": pos.x,
		"y": pos.y,
		"team": caster.team,
		"duration": 3,
		"name": "诱饵",
	}
	_append_map_object(decoy_obj)
	return {"success": true, "position": pos, "decoy": decoy_obj}

func _skill_shadow_step(caster: Node, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_unit")
	if not target or target.team != caster.team:
		return {"success": false, "reason": "no_target"}
	var caster_pos = caster.grid_pos
	caster.move_to(target.grid_pos)
	target.move_to(caster_pos)
	return {"success": true, "swapped": [caster.unit_name, target.unit_name]}

func _skill_hunker_down(caster: Node) -> Dictionary:
	caster.add_status("hunker", 1)
	return {"success": true}

func _skill_sprint(caster: Node) -> Dictionary:
	caster.move_points += 2
	caster.add_status("charge", 1)
	return {"success": true}

func _skill_reposition(caster: Node) -> Dictionary:
	if caster.last_grid_pos == caster.grid_pos:
		return {"success": false, "reason": "no_previous_position"}
	if not MapLoader.is_passable(map_data, caster.last_grid_pos.x, caster.last_grid_pos.y):
		return {"success": false, "reason": "blocked"}
	var other = _get_unit_at(caster.last_grid_pos)
	if other and other != caster:
		return {"success": false, "reason": "occupied"}
	caster.move_to(caster.last_grid_pos)
	return {"success": true, "position": caster.grid_pos}

func _skill_interact(caster: Node, target_data: Dictionary) -> Dictionary:
	var pos = target_data.get("position", caster.grid_pos)
	for obj in map_data.get("objects", []):
		if int(obj.get("x", -1)) == pos.x and int(obj.get("y", -1)) == pos.y:
			if obj.get("type", "") in ["terminal", "door", "chest", "console"]:
				obj["activated"] = true
				return {"success": true, "object": obj}
	return {"success": false, "reason": "nothing_to_interact"}

func _get_move_cost(pos: Vector2i, job: String) -> int:
	return GameData.get_move_cost(job, MapLoader.get_terrain_at(map_data, pos.x, pos.y))

func _is_blocked(pos: Vector2i) -> bool:
	return not MapLoader.is_passable(map_data, pos.x, pos.y)

func _is_vision_blocking(pos: Vector2i) -> bool:
	return MapLoader.get_blocker_at(map_data, pos.x, pos.y) == 6

func _get_skill_data(skill_id: String) -> Dictionary:
	return GameData.get_skill(skill_id)

func _get_all_units() -> Array:
	return GameManager.player_units + GameManager.enemy_units

func _get_unit_at(pos: Vector2i):
	for unit in _get_all_units():
		if unit.is_alive and unit.grid_pos == pos:
			return unit
	return null

func _find_adjacent_to(pos: Vector2i) -> Vector2i:
	for neighbor in GridSystem.get_neighbors(pos):
		if MapLoader.is_passable(map_data, neighbor.x, neighbor.y) and not _get_unit_at(neighbor):
			return neighbor
	return Vector2i(-1, -1)

func _apply_weapon_specials(attacker: Node, target: Node, result: Dictionary, weapon: Dictionary, special: String, dist: int) -> void:
	var weapon_id = String(attacker.get("equipped_weapon"))
	if weapon_id == "Null":
		weapon_id = ""
	if special == "":
		return

	var damage = int(result.get("damage", 0))
	match special:
		"close_range_bonus_1.3x_at_2_tiles", "close_range_bonus_1.4x", "double_shot_close_range":
			if dist <= 2 and damage != 0:
				var bonus = int(round(abs(damage) * (0.3 if special == "close_range_bonus_1.3x_at_2_tiles" else 0.4)))
				_apply_follow_up_damage(target, bonus if damage > 0 else -bonus)
		"double_tap":
			if damage != 0:
				_apply_follow_up_damage(target, int(round(damage * 0.5)))
		"triple_tap":
			if damage != 0:
				_apply_follow_up_damage(target, int(round(damage * 0.35)))
				_apply_follow_up_damage(target, int(round(damage * 0.35)))
		"dual_wield_double_strike_kill_refund_ap":
			if damage != 0:
				_apply_follow_up_damage(target, int(round(damage * 0.6)))
			if not target.is_alive:
				attacker.current_ap = min(attacker.current_ap + 1, attacker.max_ap + 1)
		"setup_bonus_30_hit", "setup_2_turns_guaranteed_hit_crit":
			if attacker.has_status("setup") or attacker.has_status("steady"):
				target.add_status("marked", 1)
				if special == "setup_2_turns_guaranteed_hit_crit":
					target.add_status("exposed", 1)
		"move_and_shoot":
			attacker.add_status("mobile_fire", 1)
		"bleed":
			if rng.randf() < 0.3:
				target.add_status("bleed", 2)
		"burn":
			if rng.randf() < 0.25:
				target.add_status("burn", 2)
		"aoe_3x3_destroy_cover":
			_apply_area_damage(attacker, target.grid_pos, 1, int(round(abs(damage) * 0.7)), weapon, "destroy_cover")
		"aoe_5x5_burn":
			_apply_area_damage(attacker, target.grid_pos, 2, int(round(abs(damage) * 0.5)), weapon, "burn")
		"burn_cone_3_tiles":
			_apply_area_damage(attacker, target.grid_pos, 1, int(round(abs(damage) * 0.6)), weapon, "burn")
		"stun":
			if rng.randf() < 0.15:
				target.add_status("stun", 1)
		"suppress":
			target.add_status("suppress", 1)
		"armor_pierce":
			target.armor = maxi(target.armor - 15, 0)
		"poison_3_turns":
			target.add_status("poison", 3)
		"mark_target_3_turns":
			target.add_status("marked", 3)
		"silent_no_expose":
			target.add_status("marked", 1)
		"silent_crit_plus_10":
			if result.get("critical", false):
				attacker.current_ap = min(attacker.current_ap + 1, attacker.max_ap + 1)
		"kill_heal_10_bleed_3":
			if not target.is_alive:
				attacker.heal(10)
			elif rng.randf() < 0.35:
				target.add_status("bleed", 3)
		"suppressing_fire", "burst_5_suppress_range_1":
			if dist <= 1 or special == "suppressing_fire":
				target.add_status("suppress", 1)
		"heal_40", "heal_50_remove_1_debuff", "damage_heals_adjacent_ally":
			_apply_heal_weapon_effect(attacker, target, result, weapon, special)
		"knockback":
			if target.job == "heavy" and float(target.current_hp) / float(max(target.max_hp, 1)) > 0.5:
				return
			var dx = target.grid_pos.x - attacker.grid_pos.x
			var dy = target.grid_pos.y - attacker.grid_pos.y
			var new_pos = Vector2i(
				clampi(target.grid_pos.x + signi(dx), 0, map_data.get("size", {}).get("width", 10) - 1),
				clampi(target.grid_pos.y + signi(dy), 0, map_data.get("size", {}).get("height", 8) - 1)
			)
			if MapLoader.is_passable(map_data, new_pos.x, new_pos.y):
				var occupied = GameManager.player_units + GameManager.enemy_units
				var blocked = occupied.any(func(u): return u.is_alive and u.grid_pos == new_pos)
				if not blocked:
					target.move_to(new_pos)
		"lifesteal":
			if result.get("hit", false):
				attacker.heal(int(result.get("damage", 0) * 0.2))
		_:
			return

func _apply_follow_up_damage(target: Node, damage: int) -> void:
	if damage == 0 or not target.is_alive:
		return
	target.take_damage(damage)

func _apply_area_damage(attacker: Node, center: Vector2i, radius: int, damage: int, weapon: Dictionary, effect_type: String) -> void:
	if radius < 1 or damage == 0:
		return
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			if not GridSystem.is_in_bounds(pos, map_data.get("size", {}).get("width", 10), map_data.get("size", {}).get("height", 8)):
				continue
			var unit = _get_unit_at(pos)
			if unit and unit.team != attacker.team and unit.is_alive:
				unit.take_damage(damage)
				if effect_type == "burn":
					unit.add_status("burn", 2)
			if effect_type == "destroy_cover" and MapLoader.get_blocker_at(map_data, pos.x, pos.y) == 7:
				map_data.layers.blocker[pos.y][pos.x] = 0

func _apply_heal_weapon_effect(attacker: Node, target: Node, result: Dictionary, weapon: Dictionary, special: String) -> void:
	if String(weapon.get("special", "")) == "heal_40":
		target.heal(40)
	elif String(weapon.get("special", "")) == "heal_50_remove_1_debuff":
		target.heal(50)
		for status in target.status_effects:
			if status.id.begins_with("debuff_") or status.id in ["bleed", "burn", "poison", "stun", "suppress", "fear", "blind", "slow", "jammed", "rooted", "disarmed", "silenced"]:
				target.remove_status(status.id)
				break
	elif String(weapon.get("special", "")) == "damage_heals_adjacent_ally":
		var ally = _find_nearest_ally(attacker, target.grid_pos)
		if ally:
			var heal_amount = maxi(int(abs(int(result.get("damage", 0))) / 2), 10)
			ally.heal(heal_amount)

func _find_nearest_ally(unit: Node, center: Vector2i) -> Node:
	var allies = GameManager.player_units if unit.team == "player" else GameManager.enemy_units
	var best: Node = null
	var best_dist := 9999
	for ally in allies:
		if not ally.is_alive:
			continue
		var dist = GridSystem.manhattan_distance(center, ally.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best = ally
	return best

func _is_isolated_target(target: Node) -> bool:
	var allies = GameManager.player_units if target.team == "player" else GameManager.enemy_units
	for ally in allies:
		if ally == target or not ally.is_alive:
			continue
		if GridSystem.manhattan_distance(ally.grid_pos, target.grid_pos) <= 1:
			return false
	return true

func _remove_negative_statuses(unit: Node) -> void:
	var to_remove: Array[String] = []
	for status in unit.status_effects:
		if String(status.id).begins_with("debuff_") or status.id in ["bleed", "burn", "poison", "stun", "suppress", "fear", "blind", "slow", "jammed", "rooted", "disarmed", "silenced", "marked", "revealed"]:
			to_remove.append(String(status.id))
	for status_id in to_remove:
		unit.remove_status(status_id)

func _use_throwable(unit: Node, item: Dictionary, target_data: Dictionary) -> Dictionary:
	var effect = item.get("effect", {})
	var area = String(effect.get("area", "1x1"))
	var damage = effect.get("damage", [0, 0])
	var target_pos = target_data.get("position", unit.grid_pos)

	var radius = 1
	match area:
		"1x1":
			radius = 0
		"3x3":
			radius = 1
		"5x5":
			radius = 2

	var hit_units: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos = Vector2i(target_pos.x + dx, target_pos.y + dy)
			var target_unit = _get_unit_at(pos)
			if target_unit and target_unit.team != unit.team:
				var dmg = int(damage[0])
				if damage.size() >= 2:
					dmg = rng.randi_range(int(damage[0]), int(damage[1]))
				target_unit.take_damage(dmg)
				hit_units.append(target_unit.unit_name)

			if MapLoader.get_blocker_at(map_data, pos.x, pos.y) == 7:
				map_data.layers.blocker[pos.y][pos.x] = 0

	if effect.has("add_status"):
		for status_id in effect.add_status:
			var duration = int(effect.add_status[status_id])
			for unit_name in hit_units:
				for u in GameManager.player_units + GameManager.enemy_units:
					if u.unit_name == unit_name:
						u.add_status(status_id, duration)

	return {"success": true, "item": item.get("name", ""), "area": area, "hit": hit_units}

func _place_trap(unit: Node, item: Dictionary, pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if pos.x < 0:
		pos = unit.grid_pos

	var effect = item.get("effect", {})
	var trap_obj = {
		"id": "trap_" + str(randi()),
		"type": "trap",
		"x": pos.x,
		"y": pos.y,
		"team": unit.team,
		"damage": effect.get("damage", [20, 30]),
		"trigger": effect.get("trigger", "enemy_enter"),
		"status": effect.get("add_status", {}),
		"name": item.get("name", "陷阱"),
	}
	_append_map_object(trap_obj)
	return {"success": true, "trap": item.get("name", ""), "pos": pos}

func _append_map_object(obj: Dictionary) -> void:
	var objects = map_data.get("objects", [])
	objects.append(obj)
	map_data["objects"] = objects
