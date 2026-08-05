extends RefCounted
class_name V2CheckpointAdapter

const SCHEMA_VERSION := 3
const GAME_LINE := "v2_infiltration"
const V2UnitTurnStateScript = preload("res://scripts/v2/combat/v2_unit_turn_state.gd")
const CHECKPOINT_IDS := [&"cp_start", &"cp_rescue", &"cp_pre_evac"]

static func checkpoint_for_event(event_name: StringName) -> StringName:
	match event_name:
		&"mission_started":
			return &"cp_start"
		&"scout_rescued":
			return &"cp_rescue"
		&"evac_route_opened":
			return &"cp_pre_evac"
	return &""

static func is_valid_checkpoint_id(checkpoint_id: StringName) -> bool:
	return checkpoint_id in CHECKPOINT_IDS

static func get_retry_actions(has_checkpoint: bool) -> Array[StringName]:
	var actions: Array[StringName] = []
	if has_checkpoint:
		actions.append(&"retry_checkpoint")
	actions.append(&"restart_mission")
	actions.append(&"return_base")
	return actions

static func capture(context: Dictionary) -> Dictionary:
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"game_line": String(context.get("game_line", GAME_LINE)),
		"level_id": String(context.get("level_id", "")),
		"encounter_id": String(context.get("encounter_id", "")),
		"checkpoint_id": String(context.get("checkpoint_id", "")),
		"turn": int(context.get("turn", 0)),
		"player_units": _serialize_units(context.get("player_units", [])),
		"enemy_units": _serialize_units(context.get("enemy_units", [])),
		"alert_state": (context.get("alert_state", {}) as Dictionary).duplicate(true),
		"visibility_state": (context.get("visibility_state", {}) as Dictionary).duplicate(true),
		"facilities": (context.get("facilities", []) as Array).duplicate(true),
		"mission_flow": (context.get("mission_flow", {}) as Dictionary).duplicate(true),
		"enemy_intents": (context.get("enemy_intents", {}) as Dictionary).duplicate(true),
		"turn_state": (context.get("turn_state", {}) as Dictionary).duplicate(true),
		"extra": (context.get("extra", {}) as Dictionary).duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
	}
	snapshot["hash"] = _compute_hash(snapshot)
	return snapshot

static func validate(snapshot: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version must be 3")
	if String(snapshot.get("game_line", "")) != GAME_LINE:
		errors.append("game_line must be %s" % GAME_LINE)
	for key in ["level_id", "encounter_id", "player_units", "enemy_units", "alert_state", "visibility_state", "facilities", "mission_flow", "enemy_intents", "turn_state", "extra", "hash"]:
		if not snapshot.has(key):
			errors.append("missing field: %s" % key)
	if String(snapshot.get("level_id", "")).is_empty():
		errors.append("level_id is required")
	if String(snapshot.get("encounter_id", "")).is_empty():
		errors.append("encounter_id is required")
	var checkpoint_id := String(snapshot.get("checkpoint_id", ""))
	if not checkpoint_id.is_empty() and not is_valid_checkpoint_id(StringName(checkpoint_id)):
		errors.append("unknown checkpoint_id: %s" % checkpoint_id)
	if not snapshot.get("player_units", []) is Array:
		errors.append("player_units must be an array")
	if not snapshot.get("enemy_units", []) is Array:
		errors.append("enemy_units must be an array")
	_validate_unit_ids(snapshot.get("player_units", []), snapshot.get("enemy_units", []), errors)
	if errors.is_empty() and String(snapshot.get("hash", "")) != _compute_hash(snapshot):
		errors.append("snapshot hash mismatch")
	return {"valid": errors.is_empty(), "errors": errors}

static func restore(snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var validation: Dictionary = validate(snapshot)
	if not bool(validation.get("valid", false)):
		return {"success": false, "reason": &"invalid_snapshot", "validation": validation}
	var player_check: Dictionary = _check_context_units(snapshot.player_units, context.get("player_units", []))
	if not bool(player_check.get("valid", false)):
		return {"success": false, "reason": &"missing_player_entity", "entity_id": player_check.get("entity_id", "")}
	var enemy_check: Dictionary = _check_context_units(snapshot.enemy_units, context.get("enemy_units", []))
	if not bool(enemy_check.get("valid", false)):
		return {"success": false, "reason": &"missing_enemy_entity", "entity_id": enemy_check.get("entity_id", "")}
	_restore_units(snapshot.player_units, context.get("player_units", []))
	_restore_units(snapshot.enemy_units, context.get("enemy_units", []))
	context["game_line"] = GAME_LINE
	context["level_id"] = snapshot.level_id
	context["encounter_id"] = snapshot.encounter_id
	context["turn"] = int(snapshot.turn)
	context["alert_state"] = snapshot.alert_state.duplicate(true)
	context["visibility_state"] = snapshot.visibility_state.duplicate(true)
	context["facilities"] = snapshot.facilities.duplicate(true)
	context["mission_flow"] = snapshot.mission_flow.duplicate(true)
	context["enemy_intents"] = snapshot.enemy_intents.duplicate(true)
	context["turn_state"] = snapshot.turn_state.duplicate(true)
	context["extra"] = snapshot.extra.duplicate(true)
	return {"success": true, "hash": snapshot.hash}

static func _serialize_units(units: Variant) -> Array:
	var result: Array = []
	if not units is Array:
		return result
	for raw_unit in units:
		if raw_unit is Unit:
			var unit: Unit = raw_unit
			var data := {
				"entity_id": unit.entity_id,
				"unit_name": unit.unit_name,
				"team": unit.team,
				"job": unit.job,
				"grid_pos": {"x": unit.grid_pos.x, "y": unit.grid_pos.y},
				"height": unit.height,
				"max_hp": unit.max_hp,
				"current_hp": unit.current_hp,
				"max_ap": unit.max_ap,
				"current_ap": unit.current_ap,
				"move_points": unit.move_points,
				"base_move_points": unit.base_move_points,
				"is_alive": unit.is_alive,
				"is_downed": unit.is_downed,
				"status_effects": unit.status_effects.duplicate(true),
				"armor": unit.armor,
				"current_shield": unit.current_shield,
				"max_shield": unit.max_shield,
				"v2_turn_mode_enabled": unit.v2_turn_mode_enabled,
			}
			var state: Variant = unit.v2_turn_state
			if state != null and state.has_method("serialize"):
				data["turn_state"] = state.serialize()
			result.append(data)
		elif raw_unit is Dictionary:
			result.append((raw_unit as Dictionary).duplicate(true))
	return result

static func _validate_unit_ids(player_units: Variant, enemy_units: Variant, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for raw_unit in [player_units, enemy_units]:
		if not raw_unit is Array:
			continue
		for raw_entry in raw_unit:
			if not raw_entry is Dictionary:
				errors.append("unit snapshot must be an object")
				continue
			var entity_id := String((raw_entry as Dictionary).get("entity_id", ""))
			if entity_id.is_empty():
				errors.append("unit snapshot missing entity_id")
			elif seen.has(entity_id):
				errors.append("duplicate entity_id: %s" % entity_id)
			else:
				seen[entity_id] = true

static func _check_context_units(snapshot_units: Variant, context_units: Variant) -> Dictionary:
	var context_ids: Dictionary = {}
	if context_units is Array:
		for raw_unit in context_units:
			if raw_unit is Unit:
				context_ids[(raw_unit as Unit).entity_id] = raw_unit
			elif raw_unit is Dictionary:
				context_ids[String((raw_unit as Dictionary).get("entity_id", ""))] = raw_unit
	if snapshot_units is Array:
		for raw_entry in snapshot_units:
			if raw_entry is Dictionary:
				var entity_id := String((raw_entry as Dictionary).get("entity_id", ""))
				if not context_ids.has(entity_id):
					return {"valid": false, "entity_id": entity_id}
	return {"valid": true}

static func _restore_units(snapshot_units: Array, context_units: Variant) -> void:
	var context_by_id: Dictionary = {}
	if context_units is Array:
		for raw_unit in context_units:
			if raw_unit is Unit:
				context_by_id[(raw_unit as Unit).entity_id] = raw_unit
	for raw_entry in snapshot_units:
		if not raw_entry is Dictionary:
			continue
		var data: Dictionary = raw_entry
		var entity_id := String(data.get("entity_id", ""))
		if not context_by_id.has(entity_id):
			continue
		var unit: Unit = context_by_id[entity_id]
		var position: Dictionary = data.get("grid_pos", {})
		unit.grid_pos = Vector2i(int(position.get("x", 0)), int(position.get("y", 0)))
		unit.unit_name = String(data.get("unit_name", unit.unit_name))
		unit.team = String(data.get("team", unit.team))
		unit.job = String(data.get("job", unit.job))
		unit.height = int(data.get("height", unit.height))
		unit.max_hp = int(data.get("max_hp", unit.max_hp))
		unit.current_hp = int(data.get("current_hp", unit.current_hp))
		unit.max_ap = int(data.get("max_ap", unit.max_ap))
		unit.current_ap = int(data.get("current_ap", unit.current_ap))
		unit.move_points = int(data.get("move_points", unit.move_points))
		unit.base_move_points = int(data.get("base_move_points", unit.base_move_points))
		unit.is_alive = bool(data.get("is_alive", unit.is_alive))
		unit.is_downed = bool(data.get("is_downed", unit.is_downed))
		unit.status_effects = (data.get("status_effects", []) as Array).duplicate(true)
		unit.armor = int(data.get("armor", unit.armor))
		unit.current_shield = int(data.get("current_shield", unit.current_shield))
		unit.max_shield = int(data.get("max_shield", unit.max_shield))
		if bool(data.get("v2_turn_mode_enabled", false)):
			unit.enable_v2_turn_mode()
		var raw_state: Variant = data.get("turn_state", null)
		if raw_state is Dictionary:
			unit.v2_turn_state = V2UnitTurnStateScript.deserialize(raw_state)

static func _compute_hash(snapshot: Dictionary) -> String:
	var body: Dictionary = snapshot.duplicate(true)
	body.erase("timestamp")
	body.erase("hash")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(JSON.stringify(body).to_utf8_buffer())
	return hashing.finish().hex_encode()
