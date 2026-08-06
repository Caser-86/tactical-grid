extends RefCounted
class_name V2IntentExecutor

static func execute(intent: Dictionary, context: Dictionary) -> Dictionary:
	var enemy_id: String = String(intent.get("enemy_id", ""))
	var revision: int = int(context.get("state_revision", 0))
	if int(intent.get("revision", -1)) != revision:
		return _fallback(enemy_id, revision, &"stale_revision")

	var enemy: Unit = _find_unit(context.get("enemies", []), enemy_id)
	if enemy == null or not enemy.is_alive:
		return _fallback(enemy_id, revision, &"invalid_enemy")

	var intent_type: StringName = StringName(intent.get("type", "wait"))
	match intent_type:
		&"attack":
			return _execute_attack(intent, enemy, context, revision)
		&"move":
			return _execute_move(intent, enemy, context, revision)
		&"scan":
			return _success(intent, enemy_id, revision, {"radius": int(intent.get("radius", 0))})
		&"telegraph":
			return _execute_telegraph(intent, enemy, context, revision)
		&"protect":
			return _execute_protect(intent, enemy, context, revision)
		&"operate":
			return _execute_operate(intent, enemy, context, revision)
		&"guard", &"wait":
			return _success(intent, enemy_id, revision)
		_:
			return _fallback(enemy_id, revision, &"unknown_intent")

static func _execute_attack(intent: Dictionary, enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var target_id: String = String(intent.get("target_id", ""))
	var target: Unit = _find_unit(context.get("players", []), target_id)
	if target == null or not target.is_alive:
		return _fallback(enemy.entity_id, revision, &"invalid_target")
	if context.get("blocked_attacks", []).has(enemy.entity_id):
		return _fallback(enemy.entity_id, revision, &"blocked_path")
	if intent.has("target_cell") and intent.get("target_cell") != target.grid_pos:
		return _fallback(enemy.entity_id, revision, &"stale_target")
	return _success(intent, enemy.entity_id, revision, {
		"target_id": target.entity_id,
		"damage": maxi(0, int(intent.get("damage", 0))),
	})

static func _execute_move(intent: Dictionary, enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var path: Array = intent.get("path", [])
	if path.is_empty():
		return _fallback(enemy.entity_id, revision, &"missing_path")
	var target_cell: Variant = path[0]
	if not target_cell is Vector2i or enemy.grid_pos.distance_to(target_cell) != 1:
		return _fallback(enemy.entity_id, revision, &"invalid_path")
	if _is_blocked(target_cell, context):
		return _fallback(enemy.entity_id, revision, &"blocked_path")
	if _is_occupied(target_cell, context, enemy):
		return _fallback(enemy.entity_id, revision, &"occupied")
	return _success(intent, enemy.entity_id, revision, {"target_cell": target_cell, "path": path})

static func _execute_telegraph(intent: Dictionary, enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var target_id: String = String(intent.get("target_id", ""))
	var target: Unit = _find_unit(context.get("players", []), target_id)
	if target == null or not target.is_alive:
		return _fallback(enemy.entity_id, revision, &"invalid_target")
	return _success(intent, enemy.entity_id, revision, {
		"target_id": target.entity_id,
		"telegraph": StringName(intent.get("telegraph", "charge_line")),
		"damage": 0,
	})

static func _execute_protect(intent: Dictionary, enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var target: Unit = _find_unit(context.get("enemies", []), String(intent.get("target_id", "")))
	if target == null or not target.is_alive or target == enemy:
		return _fallback(enemy.entity_id, revision, &"invalid_protect_target")
	return _success(intent, enemy.entity_id, revision, {"target_id": target.entity_id, "damage": 0})

static func _execute_operate(intent: Dictionary, enemy: Unit, context: Dictionary, revision: int) -> Dictionary:
	var facility_id: String = String(intent.get("facility_id", ""))
	for facility in context.get("facilities", []):
		if facility is Dictionary and String(facility.get("id", "")) == facility_id and bool(facility.get("operable", false)):
			return _success(intent, enemy.entity_id, revision, {"facility_id": facility_id, "damage": 0})
	return _fallback(enemy.entity_id, revision, &"invalid_facility")

static func _success(intent: Dictionary, enemy_id: String, revision: int, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"enemy_id": enemy_id,
		"type": intent.get("type", &"wait"),
		"revision": revision,
		"damage": maxi(0, int(intent.get("damage", 0))),
	}
	for key in extra:
		result[key] = extra[key]
	return result

static func _fallback(enemy_id: String, revision: int, reason: StringName) -> Dictionary:
	return {
		"success": false,
		"enemy_id": enemy_id,
		"type": &"guard",
		"reason": reason,
		"revision": revision,
		"damage": 0,
	}

static func _find_unit(raw_units: Variant, entity_id: String) -> Unit:
	if not raw_units is Array:
		return null
	for value in raw_units:
		if value is Unit and value.entity_id == entity_id:
			return value
	return null

static func _is_blocked(cell: Vector2i, context: Dictionary) -> bool:
	for blocked in context.get("blocked_cells", []):
		if blocked is Vector2i and blocked == cell:
			return true
	return false

static func _is_occupied(cell: Vector2i, context: Dictionary, except_unit: Unit) -> bool:
	for raw_unit in context.get("players", []) + context.get("enemies", []):
		var unit: Unit = raw_unit
		if unit != null and unit != except_unit and unit.is_alive and unit.grid_pos == cell:
			return true
	return false
