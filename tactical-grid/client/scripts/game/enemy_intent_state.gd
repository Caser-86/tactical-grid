## Enemy intent state system
## Tracks what each enemy plans to do and exposes only the intents
## the player is allowed to see based on current visibility.
## A hidden enemy cannot produce a public intent.
## A newly observed enemy cannot deal unannounced lethal damage that same reveal turn.
## CH1-050: Intents are planned at the end of the player's turn and committed
## during the enemy turn. When an enemy leaves sight, its intent is frozen and
## marked stale so the renderer can show an "outdated" marker instead of the
## real-time plan.
extends Node
class_name EnemyIntentState

var _visibility_state: VisibilityState = null
## All intents: entity_id -> Dictionary (type, target_pos, lethal, stale, planned_turn, ...)
var _intents: Dictionary = {}


## Setup with a reference to the VisibilityState for filtering.
func setup(visibility_state: VisibilityState) -> void:
	_visibility_state = visibility_state
	_intents.clear()


## Set the intent for an enemy.
## intent: {type: "move"/"attack"/"overwatch"/"scan"/..., target_pos: Vector2i, lethal: bool}
func set_intent(entity_id: String, intent: Dictionary) -> void:
	var copy: Dictionary = intent.duplicate(true)
	copy["stale"] = false
	_intents[entity_id] = copy


## Get the raw intent for an enemy (regardless of visibility).
func get_intent(entity_id: String) -> Dictionary:
	return _intents.get(entity_id, {})


## Get public intents filtered by current visibility.
## Only observed enemies appear; newly revealed enemies have lethal intents suppressed.
## Stale intents (enemy left sight after planning) are still returned but carry
## stale=true so the renderer can mark them as outdated instead of hiding them.
func get_public_intents() -> Dictionary:
	var public_intents: Dictionary = {}
	for eid in _intents.keys():
		if _visibility_state == null:
			continue
		var intent: Dictionary = _intents[eid].duplicate(true)
		var is_stale: bool = bool(intent.get("stale", false))
		# Observed enemies always show their current intent.
		# Stale intents (enemy left sight after planning) remain visible so the
		# player can still read the last known plan, marked as outdated.
		if not _visibility_state.is_enemy_observed(eid) and not is_stale:
			# Enemy is hidden and intent is not stale yet (never seen or frozen).
			# Hidden enemies with no stale snapshot must not leak any intent.
			if not _visibility_state.get_last_known(eid).has("pos"):
				continue
			# Last-known snapshot exists but intent not yet frozen: hide it
			# until freeze_stale_intents() is called at turn boundary.
			continue
		# Suppress lethal intent for newly revealed enemies
		if _visibility_state.is_newly_revealed(eid) and bool(intent.get("lethal", false)):
			intent["lethal"] = false
			intent["suppressed"] = true
		public_intents[eid] = intent
	return public_intents


## CH1-050: Freeze intents for enemies that have left sight since planning.
## Marks their intent as stale=true so the renderer shows an outdated marker
## instead of a real-time plan. Called at the start of the player action phase
## before the player can act on the information.
func freeze_stale_intents() -> void:
	if _visibility_state == null:
		return
	for eid in _intents.keys():
		if _visibility_state.is_enemy_observed(eid):
			# Enemy still observed: refresh stale flag (information is current).
			_intents[eid]["stale"] = false
			continue
		# Enemy not currently observed: mark intent as stale if we have ever
		# seen the enemy (otherwise the intent was hidden to begin with).
		if _visibility_state.get_last_known(eid).has("pos"):
			_intents[eid]["stale"] = true


## CH1-050: Build a threat summary for HUD display.
## Returns: { lethal_count, attack_count, move_count, overwatch_count, others, total, top_threats: Array }
## top_threats is a list of {entity_id, type, target_pos, lethal, stale} sorted by danger.
func get_threat_summary() -> Dictionary:
	var public := get_public_intents()
	var lethal_count := 0
	var attack_count := 0
	var move_count := 0
	var overwatch_count := 0
	var others := 0
	var top_threats: Array = []
	for eid in public.keys():
		var intent: Dictionary = public[eid]
		var itype: String = String(intent.get("type", "wait"))
		var is_lethal: bool = bool(intent.get("lethal", false))
		var is_stale: bool = bool(intent.get("stale", false))
		match itype:
			"attack":
				attack_count += 1
				if is_lethal:
					lethal_count += 1
			"move", "move_to_cover":
				move_count += 1
			"overwatch":
				overwatch_count += 1
			_:
				others += 1
		# Stale intents are downranked: they are informational but not actionable.
		# Lethal attacks rank highest, then regular attacks, then overwatch, then moves.
		var rank := 0
		if is_stale:
			rank -= 100
		if is_lethal:
			rank += 50
		match itype:
			"attack": rank += 30
			"overwatch": rank += 20
			"move", "move_to_cover": rank += 10
		top_threats.append({
			"entity_id": eid,
			"type": itype,
			"target_pos": intent.get("target_pos", Vector2i(-1, -1)),
			"lethal": is_lethal,
			"stale": is_stale,
			"rank": rank,
		})
	top_threats.sort_custom(func(a, b): return int(a["rank"]) > int(b["rank"]))
	# Keep top 3 to keep the HUD readable.
	if top_threats.size() > 3:
		top_threats.resize(3)
	return {
		"lethal_count": lethal_count,
		"attack_count": attack_count,
		"move_count": move_count,
		"overwatch_count": overwatch_count,
		"others": others,
		"total": public.size(),
		"top_threats": top_threats,
	}


## Clear all intents.
func clear() -> void:
	_intents.clear()


## Remove intent for a specific enemy (e.g. when killed).
func remove_intent(entity_id: String) -> void:
	_intents.erase(entity_id)
