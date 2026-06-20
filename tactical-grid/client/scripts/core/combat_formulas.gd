## 战斗公式
## 命中率、伤害、暴击等计算
extends RefCounted
class_name CombatFormulas

## 计算命中率（返回 0.0-1.0）
static func calculate_hit(
	base_hit: int,
	attacker_height: int,
	target_height: int,
	cover_type: String,
	distance: int,
	weapon_optimal_range: int
) -> float:
	var hit = float(base_hit)

	# 高度差
	hit += (attacker_height - target_height) * 10.0

	# 掩体
	match cover_type:
		"half":
			hit -= 20.0
		"full":
			hit -= 40.0
		"soft":
			hit -= 15.0

	# 距离惩罚（超过最佳射程后每格 -8）
	if distance > weapon_optimal_range:
		hit -= (distance - weapon_optimal_range) * 8.0

	# 限制在 5%-95%
	hit = clampf(hit, 5.0, 95.0)
	return hit / 100.0

## 计算伤害
static func calculate_damage(
	base_damage: int,
	armor: int,
	is_critical: bool,
	crit_multiplier: float
) -> int:
	# 护甲固定减伤（每点护甲减2点伤害），最少保留10%基础伤害
	var min_damage = max(1, int(base_damage * 0.1))
	var damage = max(base_damage - armor * 2, min_damage)

	if is_critical:
		damage = int(damage * crit_multiplier)

	return damage

## 判断是否暴击
static func is_critical_hit(crit_chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < crit_chance

## 计算暴击率（返回 0.0-1.0）
static func calculate_crit_chance(
	base_crit: float,
	attacker_height: int,
	target_height: int
) -> float:
	var crit = base_crit
	# 高地打低地暴击+5%
	if attacker_height > target_height:
		crit += 0.05
	return clampf(crit, 0.0, 0.75)

## 计算闪避率
static func calculate_dodge(
	base_dodge: float,
	terrain_type: int
) -> float:
	var dodge = base_dodge
	# 森林+10%闪避
	if terrain_type == 2:
		dodge += 0.10
	return clampf(dodge, 0.0, 0.40)

## 完整的攻击结算
## 返回 Dictionary: { hit: bool, damage: int, critical: bool, dodged: bool }
static func resolve_attack(
	base_hit: int,
	attacker_height: int,
	target_height: int,
	cover_type: String,
	distance: int,
	weapon_optimal_range: int,
	base_damage: int,
	target_armor: int,
	crit_chance: float,
	crit_multiplier: float,
	target_dodge: float,
	terrain_type: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var hit_chance = calculate_hit(base_hit, attacker_height, target_height, cover_type, distance, weapon_optimal_range)
	var final_dodge = calculate_dodge(target_dodge, terrain_type)

	# 先判定闪避
	if rng.randf() < final_dodge:
		return {"hit": false, "damage": 0, "critical": false, "dodged": true}

	# 再判定命中
	if rng.randf() > hit_chance:
		return {"hit": false, "damage": 0, "critical": false, "dodged": false}

	# 命中，判定暴击
	var final_crit = calculate_crit_chance(crit_chance, attacker_height, target_height)
	var is_crit = rng.randf() < final_crit

	# 计算伤害
	var damage = calculate_damage(base_damage, target_armor, is_crit, crit_multiplier)

	return {"hit": true, "damage": damage, "critical": is_crit, "dodged": false}
