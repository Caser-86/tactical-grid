extends RefCounted
class_name V2EnemyBrain

const DEFAULT_PROFILES := {
	"sentry": {"attack_range": [1, 5], "damage": 2},
	"drone": {"attack_range": [1, 3], "damage": 1, "scan_radius": 3},
	"sniper_sentry": {"attack_range": [3, 8], "damage": 3},
	"shield_guard": {"attack_range": [1, 3], "damage": 2},
	"protocol_engineer": {"attack_range": [1, 4], "damage": 1},
}

static func plan_intent(enemy: Unit, context: Dictionary) -> Dictionary:
	var revision: int = int(context.get("state_revision", 0))
	if not is_instance_valid(enemy) or not enemy.is_alive or enemy.team != "enemy":
		return _fallback(enemy, revision, &"invalid_enemy")

	var intent: Dictionary = _base_intent(enemy, revision)
	var players: Array = _alive_units(context.get("players", []))
	var target: Unit = _select_target(enemy, players, context)
	var profile: Dictionary = _profile(enemy, context)

	match enemy.job:
		"sentry":
			if target != null and _can_attack(enemy, target, profile):
				intent["type"] = &"attack"
				intent["target_id"] = target.entity_id
				intent["target_cell"] = target.grid_pos
				intent["damage"] = int(profile.get("damage", 0))
			else:
				intent = _move_toward(enemy, target, intent, context)
		"drone":
			intent["type"] = &"scan"
			intent["target_cell"] = enemy.grid_pos
			intent["radius"] = int(profile.get("scan_radius", 3))
			if target != null:
				intent["target_id"] = target.entity_id
		"sniper_sentry":
			if target != null:
				intent["type"] = &"telegraph"
				intent["target_id"] = target.entity_id
				intent["target_cell"] = target.grid_pos
				intent["telegraph"] = &"charge_line"
				intent["damage"] = int(profile.get("damage", 0))
			else:
				intent = _move_toward(enemy, target, intent, context)
		"shield_guard":
			var protected: Unit = _select_protect_target(enemy, context)
			if protected != null:
				intent["type"] = &"protect"
				intent["target_id"] = protected.entity_id
				intent["target_cell"] = protected.grid_pos
				intent["damage"] = 0
			else:
				intent = _move_toward(enemy, target, intent, context)
		"protocol_engineer":
			var facility: Dictionary = _select_facility(context)
			if not facility.is_empty():
				intent["type"] = &"operate"
				intent["facility_id"] = String(facility.get("id", ""))
				intent["target_cell"] = facility.get("position", enemy.grid_pos)
			else:
				intent = _move_toward(enemy, target, intent, context)
		_:
			intent = _move_toward(enemy, target, intent, context)

	return intent

static func _base_intent(enemy: Unit, revision: int) -> Dictionary:
	return {
		"enemy_id": enemy.entity_id if is_instance_valid(enemy) else "",
		"type": &"wait",
		"target_id": "",
		"target_cell": Vector2i(-1, -1),
		"path": [],
		"damage": 0,
		"telegraph": &"",
		"revision": revision,
	}

static func _fallback(enemy: Unit, revision: int, reason: StringName) -> Dictionary:
	var result: Dictionary = _base_intent(enemy, revision)
	result["reason"] = reason
	return result

static func _alive_units(raw_units: Variant) -> Array:
	var alive: Array = []
	if not raw_units is Array:
		return alive
	for value in raw_units:
		if value is Unit and value.is_alive:
			alive.append(value)
	return alive

static func _select_target(enemy: Unit, players: Array, context: Dictionary) -> Unit:
	var best: Unit = null
	var best_threat: int = -2147483647
	var best_distance: int = 2147483647
	var threat_table: Dictionary = context.get("threat", {})
	for candidate in players:
		var threat: int = int(threat_table.get(candidate.entity_id, 0))
		var distance: int = enemy.grid_pos.distance_to(candidate.grid_pos)
		if best == null or threat > best_threat or (threat == best_threat and distance < best_distance) or (threat == best_threat and distance == best_distance and candidate.entity_id < best.entity_id):
			best = candidate
			best_threat = threat
			best_distance = distance
	return best

static func _select_protect_target(enemy: Unit, context: Dictionary) -> Unit:
	var best: Unit = null
	var best_priority: int = -2147483647
	var best_distance: int = 2147483647
	var priority_table: Dictionary = context.get("protect_priority", {})
	for candidate in _alive_units(context.get("enemies", [])):
		if candidate == enemy:
			continue
		var priority: int = int(priority_table.get(candidate.entity_id, 0))
		if candidate.job == "sentry":
			priority += 100
		var distance: int = enemy.grid_pos.distance_to(candidate.grid_pos)
		if best == null or priority > best_priority or (priority == best_priority and distance < best_distance) or (priority == best_priority and distance == best_distance and candidate.entity_id < best.entity_id):
			best = candidate
			best_priority = priority
			best_distance = distance
	return best

static func _select_facility(context: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for value in context.get("facilities", []):
		if not value is Dictionary or not bool(value.get("operable", false)):
			continue
		if String(value.get("owner", "")) != "player":
			continue
		var candidate_id: String = String(value.get("id", ""))
		if best.is_empty() or candidate_id < String(best.get("id", "")):
			best = value
	return best

static func _profile(enemy: Unit, context: Dictionary) -> Dictionary:
	var profiles: Dictionary = context.get("enemy_profiles", {})
	var profile: Dictionary = profiles.get(enemy.job, {})
	if profile.is_empty():
		profile = DEFAULT_PROFILES.get(enemy.job, {})
	return profile

static func _can_attack(enemy: Unit, target: Unit, profile: Dictionary) -> bool:
	var attack_range: Array = profile.get("attack_range", [1, 0])
	var distance: int = enemy.grid_pos.distance_to(target.grid_pos)
	return distance >= int(attack_range[0]) and distance <= int(attack_range[1])

static func _move_toward(enemy: Unit, target: Unit, intent: Dictionary, context: Dictionary) -> Dictionary:
	if target == null:
		intent["type"] = &"guard"
		return intent
	var step := _next_step(enemy.grid_pos, target.grid_pos)
	if step == enemy.grid_pos or _is_blocked(step, context):
		intent["type"] = &"guard"
		return intent
	intent["type"] = &"move"
	intent["target_id"] = target.entity_id
	intent["target_cell"] = step
	intent["path"] = [step]
	return intent

static func _next_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if abs(delta.x) >= abs(delta.y) and delta.x != 0:
		return from + Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return from + Vector2i(0, signi(delta.y))
	return from

static func _is_blocked(cell: Vector2i, context: Dictionary) -> bool:
	for blocked in context.get("blocked_cells", []):
		if blocked is Vector2i and blocked == cell:
			return true
	return false
