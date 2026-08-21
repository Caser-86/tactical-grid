extends RefCounted
class_name V2EnemyBrain

const StrategyRegistry = preload("res://scripts/v2/ai/v2_enemy_strategy_registry.gd")

## Compatibility entry point used by the V2 runtime and contract tests.
## The actual decision is owned by the role registry so each enemy plan can be
## tested and tuned without changing the battle controller.
static func plan_intent(enemy: Unit, context: Dictionary) -> Dictionary:
	var revision := int(context.get("state_revision", 0))
	return StrategyRegistry.plan(enemy, context, revision)
