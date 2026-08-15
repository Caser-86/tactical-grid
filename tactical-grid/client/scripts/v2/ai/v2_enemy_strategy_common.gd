extends RefCounted
class_name V2EnemyStrategyCommon

const DEFAULT_PROFILES := {
	"sentry": {"attack_range": [1, 5], "damage": 1},
	"drone": {"attack_range": [1, 3], "damage": 1, "scan_radius": 3},
	"sniper_sentry": {"attack_range": [3, 8], "damage": 3},
	"shield_guard": {"attack_range": [1, 3], "damage": 2, "protect_reduction": 1},
	"protocol_engineer": {"attack_range": [1, 4], "damage": 1},
}

## Shared, side-effect-free helpers for V2 enemy intent planning.
## Strategies only propose actions. The executor is still the authority that
## commits movement, damage, scans, and protection links.

static func base_intent(enemy: Unit, revision: int) -> Dictionary:
	return {
		"enemy_id": enemy.entity_id if is_instance_valid(enemy) else "",
		"type": &"guard",
		"revision": revision,
		"target_id": "",
		"target_cell": enemy.grid_pos if is_instance_valid(enemy) else Vector2i(-1, -1),
		"path": [],
		"damage": 0,
		"telegraph": &"",
		"fallback_reason": "",
		"reason": "",
	}

static func fallback(enemy: Unit, revision: int, reason: StringName) -> Dictionary:
	var result := base_intent(enemy, revision)
	result["reason"] = reason
	result["fallback_reason"] = reason
	return result

static func alive_units(raw_units: Variant) -> Array:
	var alive: Array = []
	if not raw_units is Array:
		return alive
	for value in raw_units:
		if value is Unit and value.is_alive:
			alive.append(value)
	return alive

static func select_target(enemy: Unit, players: Array, context: Dictionary) -> Unit:
	var best: Unit = null
	var best_threat := -2147483647
	var best_distance := 2147483647
	var threat_table: Dictionary = context.get("threat", {})
	for candidate in players:
		var threat := int(threat_table.get(candidate.entity_id, 0))
		var distance := enemy.grid_pos.distance_to(candidate.grid_pos)
		if best == null or threat > best_threat or (threat == best_threat and distance < best_distance) or (threat == best_threat and distance == best_distance and candidate.entity_id < best.entity_id):
			best = candidate
			best_threat = threat
			best_distance = distance
	return best

static func select_protect_target(enemy: Unit, context: Dictionary) -> Unit:
	var best: Unit = null
	var best_priority := -2147483647
	var best_distance := 2147483647
	var priority_table: Dictionary = context.get("protect_priority", {})
	for candidate in alive_units(context.get("enemies", [])):
		if candidate == enemy:
			continue
		var priority := int(priority_table.get(candidate.entity_id, 0))
		if candidate.job == "sentry":
			priority += 100
		if candidate.current_hp < candidate.max_hp:
			priority += 10
		var distance := enemy.grid_pos.distance_to(candidate.grid_pos)
		if best == null or priority > best_priority or (priority == best_priority and distance < best_distance) or (priority == best_priority and distance == best_distance and candidate.entity_id < best.entity_id):
			best = candidate
			best_priority = priority
			best_distance = distance
	return best

static func profile(enemy: Unit, context: Dictionary) -> Dictionary:
	var profiles: Dictionary = context.get("enemy_profiles", {})
	var value: Variant = profiles.get(enemy.job, {})
	if value is Dictionary and not value.is_empty():
		return value
	var fallback: Variant = DEFAULT_PROFILES.get(enemy.job, {})
	return fallback if fallback is Dictionary else {}

static func can_attack(enemy: Unit, target: Unit, profile_data: Dictionary, context: Dictionary) -> bool:
	if target == null or not target.is_alive:
		return false
	var attack_range: Array = profile_data.get("attack_range", [1, 0])
	if attack_range.size() < 2:
		return false
	var distance := enemy.grid_pos.distance_to(target.grid_pos)
	if distance < int(attack_range[0]) or distance > int(attack_range[1]):
		return false
	var los_check: Variant = context.get("los_check", null)
	if los_check is Callable:
		return bool(los_check.call(enemy.grid_pos, target.grid_pos))
	return true

static func is_in_bounds(cell: Vector2i, context: Dictionary) -> bool:
	var map_size: Vector2i = context.get("map_size", Vector2i(-1, -1))
	return map_size.x < 0 or (cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y)

static func is_blocked(cell: Vector2i, context: Dictionary) -> bool:
	for blocked in context.get("blocked_cells", []):
		if blocked is Vector2i and blocked == cell:
			return true
	return false

static func is_occupied(cell: Vector2i, context: Dictionary, except_unit: Unit) -> bool:
	for raw_unit in context.get("players", []) + context.get("enemies", []):
		var unit: Unit = raw_unit
		if unit != null and unit != except_unit and unit.is_alive and unit.grid_pos == cell:
			return true
	return false

static func is_legal_step(enemy: Unit, cell: Vector2i, context: Dictionary) -> bool:
	return is_in_bounds(cell, context) and enemy.grid_pos.distance_to(cell) == 1 and not is_blocked(cell, context) and not is_occupied(cell, context, enemy)

static func adjacent_cells(enemy: Unit) -> Array[Vector2i]:
	return [
		enemy.grid_pos + Vector2i(-1, 0),
		enemy.grid_pos + Vector2i(1, 0),
		enemy.grid_pos + Vector2i(0, -1),
		enemy.grid_pos + Vector2i(0, 1),
	]

static func choose_line_improvement(enemy: Unit, target: Unit, profile_data: Dictionary, context: Dictionary) -> Vector2i:
	if target == null:
		return Vector2i(-1, -1)
	for candidate in adjacent_cells(enemy):
		if not is_legal_step(enemy, candidate, context):
			continue
		var distance := candidate.distance_to(target.grid_pos)
		var attack_range: Array = profile_data.get("attack_range", [1, 0])
		if attack_range.size() < 2 or distance < int(attack_range[0]) or distance > int(attack_range[1]):
			continue
		var los_check: Variant = context.get("los_check", null)
		if los_check is Callable and not bool(los_check.call(candidate, target.grid_pos)):
			continue
		return candidate
	return Vector2i(-1, -1)

static func choose_choke_step(enemy: Unit, context: Dictionary) -> Vector2i:
	var choke_cells: Array = context.get("choke_cells", [])
	for candidate in adjacent_cells(enemy):
		if choke_cells.has(candidate) and is_legal_step(enemy, candidate, context):
			return candidate
	return Vector2i(-1, -1)

static func next_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if abs(delta.x) >= abs(delta.y) and delta.x != 0:
		return from + Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return from + Vector2i(0, signi(delta.y))
	return from

static func move_toward(enemy: Unit, target: Unit, intent: Dictionary, context: Dictionary, reason: StringName = &"") -> Dictionary:
	if target == null:
		intent["type"] = &"guard"
		intent["fallback_reason"] = reason if not reason.is_empty() else &"no_target"
		return intent
	var step := next_step(enemy.grid_pos, target.grid_pos)
	if not is_legal_step(enemy, step, context):
		intent["type"] = &"guard"
		intent["fallback_reason"] = reason if not reason.is_empty() else &"no_legal_step"
		return intent
	intent["type"] = &"move"
	intent["target_id"] = target.entity_id
	intent["target_cell"] = step
	intent["path"] = [step]
	return intent

static func select_scan_cell(enemy: Unit, context: Dictionary) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_priority := -2147483647
	var best_distance := 2147483647
	var best_key := ""
	var candidates: Array = []
	for raw in context.get("scan_targets", []):
		if raw is Dictionary:
			var cell_value: Variant = raw.get("cell", raw.get("position", Vector2i(-1, -1)))
			if cell_value is Vector2i:
				candidates.append({"cell": cell_value, "priority": int(raw.get("priority", 0)), "key": String(raw.get("id", cell_value))})
	for cell_value in context.get("unobserved_cells", []):
		if cell_value is Vector2i:
			candidates.append({"cell": cell_value, "priority": 0, "key": String(cell_value)})
	for candidate in candidates:
		var cell: Vector2i = candidate["cell"]
		if not is_in_bounds(cell, context) or is_blocked(cell, context):
			continue
		var priority := int(candidate.get("priority", 0))
		var distance := enemy.grid_pos.distance_to(cell)
		var key := String(candidate.get("key", cell))
		if priority > best_priority or (priority == best_priority and distance < best_distance) or (priority == best_priority and distance == best_distance and key < best_key):
			best_cell = cell
			best_priority = priority
			best_distance = distance
			best_key = key
	return best_cell

static func select_facility(context: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for value in context.get("facilities", []):
		if not value is Dictionary or not bool(value.get("operable", false)):
			continue
		if String(value.get("owner", "")) != "player":
			continue
		var candidate_id := String(value.get("id", ""))
		if best.is_empty() or candidate_id < String(best.get("id", "")):
			best = value
	return best
