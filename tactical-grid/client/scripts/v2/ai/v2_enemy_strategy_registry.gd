extends RefCounted
class_name V2EnemyStrategyRegistry

const Common = preload("res://scripts/v2/ai/v2_enemy_strategy_common.gd")
const SentryStrategy = preload("res://scripts/v2/ai/strategies/v2_sentry_strategy.gd")
const DroneStrategy = preload("res://scripts/v2/ai/strategies/v2_drone_strategy.gd")
const ShieldGuardStrategy = preload("res://scripts/v2/ai/strategies/v2_shield_guard_strategy.gd")

## One stable dispatch point keeps the V2 brain compatible with runtime callers
## while making each M1 role independently testable.
static func plan(enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.is_alive or enemy.team != "enemy":
		return Common.fallback(enemy, revision, &"invalid_enemy")
	var strategy_id := String(Common.profile(enemy, context).get("strategy", enemy.job))
	match strategy_id:
		"sentry":
			return SentryStrategy.plan(enemy, context, revision)
		"drone":
			return DroneStrategy.plan(enemy, context, revision)
		"shield_guard":
			return ShieldGuardStrategy.plan(enemy, context, revision)
		"sniper_sentry":
			return _plan_sniper(enemy, context, revision)
		"protocol_engineer":
			return _plan_engineer(enemy, context, revision)
		_:
			var intent := Common.base_intent(enemy, revision)
			intent["fallback_reason"] = &"unknown_enemy_strategy"
			return intent

static func _plan_sniper(enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var intent := Common.base_intent(enemy, revision)
	var profile: Dictionary = Common.profile(enemy, context)
	var target: Unit = Common.select_target(enemy, Common.alive_units(context.get("players", [])), context)
	if target != null and Common.can_attack(enemy, target, profile, context):
		intent["type"] = &"telegraph"
		intent["target_id"] = target.entity_id
		intent["target_cell"] = target.grid_pos
		intent["telegraph"] = &"charge_line"
		intent["damage"] = int(profile.get("damage", 0))
		return intent
	var firing_cell := Common.choose_line_improvement(enemy, target, profile, context)
	if firing_cell.x >= 0:
		intent["type"] = &"move"
		intent["target_id"] = target.entity_id if target != null else ""
		intent["target_cell"] = firing_cell
		intent["path"] = [firing_cell]
		intent["telegraph"] = &"line_improve"
		return intent
	intent["fallback_reason"] = &"no_legal_firing_line"
	return intent

static func _plan_engineer(enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var intent := Common.base_intent(enemy, revision)
	var facility := Common.select_facility(context)
	if not facility.is_empty():
		intent["type"] = &"operate"
		intent["facility_id"] = String(facility.get("id", ""))
		intent["target_cell"] = facility.get("position", enemy.grid_pos)
		return intent
	var target: Unit = Common.select_target(enemy, Common.alive_units(context.get("players", [])), context)
	return Common.move_toward(enemy, target, intent, context, &"no_operable_facility")
