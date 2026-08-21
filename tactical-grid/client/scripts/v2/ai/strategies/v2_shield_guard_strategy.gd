extends RefCounted
class_name V2ShieldGuardStrategy

const Common = preload("res://scripts/v2/ai/v2_enemy_strategy_common.gd")

static func plan(enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.is_alive or enemy.team != "enemy":
		return Common.fallback(enemy, revision, &"invalid_enemy")
	var intent := Common.base_intent(enemy, revision)
	var protected: Unit = Common.select_protect_target(enemy, context)
	if protected != null:
		intent["type"] = &"protect"
		intent["target_id"] = protected.entity_id
		intent["target_cell"] = protected.grid_pos
		intent["protect_reduction"] = int(Common.profile(enemy, context).get("protect_reduction", 1))
		intent["telegraph"] = &"shield_link"
		return intent
	var block_cell := Common.choose_choke_step(enemy, context)
	if block_cell.x >= 0:
		intent["type"] = &"move"
		intent["target_cell"] = block_cell
		intent["path"] = [block_cell]
		intent["telegraph"] = &"block_route"
		return intent
	var target: Unit = Common.select_target(enemy, Common.alive_units(context.get("players", [])), context)
	var profile: Dictionary = Common.profile(enemy, context)
	if target != null and Common.can_attack(enemy, target, profile, context):
		intent["type"] = &"attack"
		intent["target_id"] = target.entity_id
		intent["target_cell"] = target.grid_pos
		intent["damage"] = int(profile.get("damage", 0))
		return intent
	intent["type"] = &"guard"
	intent["fallback_reason"] = &"no_protect_or_block"
	return intent
