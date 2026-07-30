## Enemy intent state system
## Tracks what each enemy plans to do and exposes only the intents
## the player is allowed to see based on current visibility.
## A hidden enemy cannot produce a public intent.
## A newly observed enemy cannot deal unannounced lethal damage that same reveal turn.
extends Node
class_name EnemyIntentState

var _visibility_state: VisibilityState = null
## All intents: entity_id -> Dictionary (type, target_pos, lethal, ...)
var _intents: Dictionary = {}


## Setup with a reference to the VisibilityState for filtering.
func setup(visibility_state: VisibilityState) -> void:
	_visibility_state = visibility_state
	_intents.clear()


## Set the intent for an enemy.
## intent: {type: "move"/"attack"/"overwatch"/"scan"/..., target_pos: Vector2i, lethal: bool}
func set_intent(entity_id: String, intent: Dictionary) -> void:
	_intents[entity_id] = intent.duplicate(true)


## Get the raw intent for an enemy (regardless of visibility).
func get_intent(entity_id: String) -> Dictionary:
	return _intents.get(entity_id, {})


## Get public intents filtered by current visibility.
## Only observed enemies appear; newly revealed enemies have lethal intents suppressed.
func get_public_intents() -> Dictionary:
	var public_intents: Dictionary = {}
	for eid in _intents.keys():
		if _visibility_state == null or not _visibility_state.is_enemy_observed(eid):
			continue
		var intent: Dictionary = _intents[eid].duplicate(true)
		# Suppress lethal intent for newly revealed enemies
		if _visibility_state.is_newly_revealed(eid) and bool(intent.get("lethal", false)):
			intent["lethal"] = false
			intent["suppressed"] = true
		public_intents[eid] = intent
	return public_intents


## Clear all intents.
func clear() -> void:
	_intents.clear()


## Remove intent for a specific enemy (e.g. when killed).
func remove_intent(entity_id: String) -> void:
	_intents.erase(entity_id)
