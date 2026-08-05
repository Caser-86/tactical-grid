extends RefCounted
class_name V2CombatRules

static func preview_attack(attacker: Unit, target: Unit, context: Dictionary) -> Dictionary:
	if attacker == null or target == null:
		return {"valid": false, "reason": &"invalid_unit"}
	if attacker == target:
		return {"valid": false, "reason": &"same_unit"}
	if not attacker.is_alive:
		return {"valid": false, "reason": &"attacker_dead"}
	if not target.is_alive:
		return {"valid": false, "reason": &"target_dead"}
	if String(attacker.team) == String(target.team):
		return {"valid": false, "reason": &"same_team"}
	if not bool(context.get("has_los", false)):
		return {"valid": false, "reason": &"no_line_of_sight"}
	var distance := int(context.get("distance", -1))
	if not attacker.weapon_range is Array or (attacker.weapon_range as Array).size() < 2:
		return {"valid": false, "reason": &"invalid_weapon"}
	var weapon_range: Array = attacker.weapon_range
	if distance < int(weapon_range[0]) or distance > int(weapon_range[1]):
		return {"valid": false, "reason": &"out_of_range"}
	var cover := StringName(String(context.get("cover", "none")))
	if not cover in [&"none", &"half", &"full"]:
		return {"valid": false, "reason": &"invalid_cover"}
	var flanked := bool(context.get("flanked", false))
	if cover == &"full" and not flanked:
		return {"valid": false, "reason": &"full_cover"}
	if not attacker.weapon_damage is Array or (attacker.weapon_damage as Array).is_empty():
		return {"valid": false, "reason": &"invalid_weapon"}
	var weapon_damage: Array = attacker.weapon_damage
	var base_damage := int(weapon_damage[0])
	var cover_reduction := 1 if cover == &"half" and not flanked else 0
	var armor_reduction := mini(maxi(0, int(target.armor)), 2)
	var after_reduction := maxi(1, base_damage - cover_reduction - armor_reduction)
	var shield_absorb := mini(maxi(0, int(target.current_shield)), after_reduction)
	var hp_damage := after_reduction - shield_absorb
	return {
		"valid": true,
		"attacker_id": attacker.entity_id,
		"target_id": target.entity_id,
		"base_damage": base_damage,
		"cover_reduction": cover_reduction,
		"armor_reduction": armor_reduction,
		"shield_absorb": shield_absorb,
		"final_damage": after_reduction,
		"hp_damage": hp_damage,
		"hp_before": target.current_hp,
		"hp_after": maxi(0, target.current_hp - hp_damage),
		"shield_before": target.current_shield,
		"shield_after": maxi(0, target.current_shield - shield_absorb),
		"state_revision": int(context.get("state_revision", 0)),
		"cost": {"action": true},
	}
