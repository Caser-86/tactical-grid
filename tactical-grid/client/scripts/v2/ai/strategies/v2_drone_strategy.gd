extends RefCounted
class_name V2DroneStrategy

const Common = preload("res://scripts/v2/ai/v2_enemy_strategy_common.gd")

static func plan(enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.is_alive or enemy.team != "enemy":
		return Common.fallback(enemy, revision, &"invalid_enemy")
	var intent := Common.base_intent(enemy, revision)
	var profile: Dictionary = Common.profile(enemy, context)
	var target: Unit = Common.select_target(enemy, Common.alive_units(context.get("players", [])), context)
	var scan_cell := Common.select_scan_cell(enemy, context)
	if scan_cell.x < 0:
		scan_cell = enemy.grid_pos
	intent["type"] = &"scan"
	intent["target_cell"] = scan_cell
	intent["radius"] = int(profile.get("scan_radius", 3))
	intent["telegraph"] = &"scan_pulse"
	if target != null:
		intent["target_id"] = target.entity_id
	if scan_cell != enemy.grid_pos or not bool(context.get("allow_drone_attack_fallback", false)):
		return intent
	if target != null and Common.can_attack(enemy, target, profile, context):
		intent["type"] = &"attack"
		intent["target_cell"] = target.grid_pos
		intent["damage"] = int(profile.get("damage", 0))
		intent["telegraph"] = &""
		return intent
	return intent
