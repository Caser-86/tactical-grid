extends RefCounted
class_name V2SentryStrategy

const Common = preload("res://scripts/v2/ai/v2_enemy_strategy_common.gd")

static func plan(enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.is_alive or enemy.team != "enemy":
		return Common.fallback(enemy, revision, &"invalid_enemy")
	var intent := Common.base_intent(enemy, revision)
	var profile: Dictionary = Common.profile(enemy, context)
	var target: Unit = Common.select_target(enemy, Common.alive_units(context.get("players", [])), context)
	if target != null and Common.can_attack(enemy, target, profile, context):
		intent["type"] = &"attack"
		intent["target_id"] = target.entity_id
		intent["target_cell"] = target.grid_pos
		intent["damage"] = int(profile.get("damage", 0))
		return intent
	var firing_cell := Common.choose_line_improvement(enemy, target, profile, context)
	if firing_cell.x >= 0:
		intent["type"] = &"move"
		intent["target_id"] = target.entity_id
		intent["target_cell"] = firing_cell
		intent["path"] = [firing_cell]
		intent["telegraph"] = &"line_improve"
		return intent
	intent["type"] = &"guard"
	intent["fallback_reason"] = &"no_legal_firing_line"
	return intent
