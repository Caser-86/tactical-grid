extends RefCounted
class_name V2CheckpointAdapter

const SCHEMA_VERSION := 4
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
		"encounter_state": (context.get("encounter_state", {}) as Dictionary).duplicate(true),
		"hazard_state": (context.get("hazard_state", {}) as Dictionary).duplicate(true),
		"facility_state": _default_facility_state(context),
		"mission_flow": (context.get("mission_flow", {}) as Dictionary).duplicate(true),
		"enemy_intents": (context.get("enemy_intents", {}) as Dictionary).duplicate(true),
		"turn_state": (context.get("turn_state", {}) as Dictionary).duplicate(true),
		"extra": (context.get("extra", {}) as Dictionary).duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
	}
	snapshot["hash"] = _compute_hash(snapshot)
	return snapshot

static func validate(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot
	if int(snapshot.get("schema_version", 0)) == 3:
		normalized = migrate_schema_3_to_4(snapshot)
		if normalized.has("_migration_error"):
			return {"valid": false, "errors": [String(normalized.get("_migration_error", "migration_failed"))]}
	var errors: Array[String] = []
	if int(normalized.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version must be 4")
	if String(normalized.get("game_line", "")) != GAME_LINE:
		errors.append("game_line must be %s" % GAME_LINE)
	for key in ["level_id", "encounter_id", "player_units", "enemy_units", "alert_state", "visibility_state", "facilities", "encounter_state", "hazard_state", "facility_state", "mission_flow", "enemy_intents", "turn_state", "extra", "hash"]:
		if not normalized.has(key):
			errors.append("missing field: %s" % key)
	if String(normalized.get("level_id", "")).is_empty():
		errors.append("level_id is required")
	if String(normalized.get("encounter_id", "")).is_empty():
		errors.append("encounter_id is required")
	var checkpoint_id := String(normalized.get("checkpoint_id", ""))
	if not checkpoint_id.is_empty() and not is_valid_checkpoint_id(StringName(checkpoint_id)):
		errors.append("unknown checkpoint_id: %s" % checkpoint_id)
	if not normalized.get("player_units", []) is Array:
		errors.append("player_units must be an array")
	if not normalized.get("enemy_units", []) is Array:
		errors.append("enemy_units must be an array")
	_validate_unit_ids(normalized.get("player_units", []), normalized.get("enemy_units", []), errors)
	if errors.is_empty() and String(normalized.get("hash", "")) != _compute_hash(normalized):
		errors.append("snapshot hash mismatch")
	return {"valid": errors.is_empty(), "errors": errors}

static func restore(snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var working := snapshot
	if int(snapshot.get("schema_version", 0)) == 3:
		working = migrate_schema_3_to_4(snapshot)
	var validation: Dictionary = validate(working)
	if not bool(validation.get("valid", false)):
		return {"success": false, "reason": &"invalid_snapshot", "validation": validation}
	var player_check: Dictionary = _check_context_units(working.player_units, context.get("player_units", []))
	if not bool(player_check.get("valid", false)):
		return {"success": false, "reason": &"missing_player_entity", "entity_id": player_check.get("entity_id", "")}
	var enemy_check: Dictionary = _check_context_units(working.enemy_units, context.get("enemy_units", []))
	if not bool(enemy_check.get("valid", false)):
		return {"success": false, "reason": &"missing_enemy_entity", "entity_id": enemy_check.get("entity_id", "")}
	_restore_units(working.player_units, context.get("player_units", []))
	_restore_units(working.enemy_units, context.get("enemy_units", []))
	context["game_line"] = GAME_LINE
	context["level_id"] = working.level_id
	context["encounter_id"] = working.encounter_id
	context["turn"] = int(working.turn)
	context["alert_state"] = working.alert_state.duplicate(true)
	context["visibility_state"] = working.visibility_state.duplicate(true)
	context["facilities"] = working.facilities.duplicate(true)
	context["encounter_state"] = working.encounter_state.duplicate(true)
	context["hazard_state"] = working.hazard_state.duplicate(true)
	context["facility_state"] = working.facility_state.duplicate(true)
	context["mission_flow"] = working.mission_flow.duplicate(true)
	context["enemy_intents"] = working.enemy_intents.duplicate(true)
	context["turn_state"] = working.turn_state.duplicate(true)
	context["extra"] = working.extra.duplicate(true)
	return {"success": true, "hash": working.hash, "snapshot": working}

static func migrate_schema_3_to_4(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("schema_version", 0)) != 3:
		var not_v3 := snapshot.duplicate(true)
		not_v3["_migration_error"] = "schema_version_not_3"
		return not_v3
	if String(snapshot.get("game_line", "")) != GAME_LINE:
		var wrong_line := snapshot.duplicate(true)
		wrong_line["_migration_error"] = "game_line must be %s" % GAME_LINE
		return wrong_line
	if String(snapshot.get("hash", "")) != _compute_hash(snapshot):
		var bad_hash := snapshot.duplicate(true)
		bad_hash["_migration_error"] = "snapshot hash mismatch"
		return bad_hash
	var migrated := snapshot.duplicate(true)
	var checkpoint_id := String(migrated.get("checkpoint_id", migrated.get("encounter_id", "")))
	migrated["schema_version"] = SCHEMA_VERSION
	migrated["encounter_id"] = _stable_encounter_id(String(migrated.get("encounter_id", checkpoint_id)), checkpoint_id)
	migrated["checkpoint_id"] = checkpoint_id
	migrated["encounter_state"] = (snapshot.get("encounter_state", _default_encounter_state(migrated["encounter_id"])) as Dictionary).duplicate(true)
	migrated["hazard_state"] = (snapshot.get("hazard_state", _default_hazard_state()) as Dictionary).duplicate(true)
	migrated["facility_state"] = (snapshot.get("facility_state", _legacy_facility_state(snapshot.get("facilities", []))) as Dictionary).duplicate(true)
	migrated["mission_flow"] = _migrate_mission_flow((snapshot.get("mission_flow", {}) as Dictionary).duplicate(true))
	migrated["hash"] = _compute_hash(migrated)
	return migrated

static func restore_v2_layers(snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var working := snapshot
	if int(snapshot.get("schema_version", 0)) == 3:
		working = migrate_schema_3_to_4(snapshot)
	var order: Array = context.get("restore_order", [])
	order.append("map")
	context["level_id"] = String(working.get("level_id", context.get("level_id", "")))
	context["encounter_id"] = String(working.get("encounter_id", context.get("encounter_id", "")))
	order.append("units")
	var stages := [
		{"name": "encounter", "service": context.get("encounter_service", null), "snapshot": working.get("encounter_state", {})},
		{"name": "facilities", "service": context.get("facility_service", null), "snapshot": working.get("facility_state", {})},
		{"name": "hazards", "service": context.get("hazard_service", null), "snapshot": working.get("hazard_state", {})},
		{"name": "mission", "service": context.get("mission_flow", null), "snapshot": working.get("mission_flow", {})},
	]
	var rollback_state := _capture_restore_rollback_state(context, stages)
	var unit_restore := restore(working, context)
	if not bool(unit_restore.get("success", false)):
		_rollback_restore_state(context, rollback_state, stages)
		unit_restore["enter_battle"] = false
		return unit_restore
	for stage in stages:
		var service: Variant = stage.get("service", null)
		if service == null:
			continue
		if not service.has_method("restore_snapshot"):
			_rollback_restore_state(context, rollback_state, stages)
			return {"success": false, "reason": StringName("%s_restore_unavailable" % String(stage.get("name", ""))), "enter_battle": false}
		var result: Dictionary = service.restore_snapshot(stage.get("snapshot", {}))
		if not bool(result.get("success", false)):
			_rollback_restore_state(context, rollback_state, stages)
			result["enter_battle"] = false
			return result
	return {"success": true, "enter_battle": true, "hash": working.get("hash", ""), "snapshot": working}

static func _capture_restore_rollback_state(context: Dictionary, stages: Array) -> Dictionary:
	var service_snapshots: Dictionary = {}
	for stage in stages:
		var service: Variant = stage.get("service", null)
		var name := String(stage.get("name", ""))
		if service != null and service.has_method("get_snapshot"):
			service_snapshots[name] = service.get_snapshot()
	return {
		"player_units": _serialize_units(context.get("player_units", [])),
		"enemy_units": _serialize_units(context.get("enemy_units", [])),
		"service_snapshots": service_snapshots,
	}

static func _rollback_restore_state(context: Dictionary, rollback_state: Dictionary, stages: Array) -> void:
	_restore_units(rollback_state.get("player_units", []), context.get("player_units", []))
	_restore_units(rollback_state.get("enemy_units", []), context.get("enemy_units", []))
	var service_snapshots: Dictionary = rollback_state.get("service_snapshots", {})
	var reversed_stages := stages.duplicate()
	reversed_stages.reverse()
	for stage in reversed_stages:
		var service: Variant = stage.get("service", null)
		var name := String(stage.get("name", ""))
		if service == null or not service.has_method("restore_snapshot") or not service_snapshots.has(name):
			continue
		var snapshot: Dictionary = (service_snapshots[name] as Dictionary).duplicate(true)
		snapshot["_rollback_restore"] = true
		service.restore_snapshot(snapshot)

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

static func _default_facility_state(context: Dictionary) -> Dictionary:
	var raw_state: Variant = context.get("facility_state", null)
	if raw_state is Dictionary:
		return (raw_state as Dictionary).duplicate(true)
	return _legacy_facility_state(context.get("facilities", []))

static func _legacy_facility_state(raw_facilities: Variant) -> Dictionary:
	var facilities: Array = []
	if raw_facilities is Array:
		for raw_facility in raw_facilities:
			if not raw_facility is Dictionary:
				continue
			var facility: Dictionary = raw_facility
			facilities.append({
				"id": String(facility.get("id", "")),
				"type": _normalize_facility_type(String(facility.get("type", facility.get("action", "")))),
				"state": String(facility.get("state", "neutral")),
				"used_actions": (facility.get("used_actions", []) as Array).duplicate() if facility.get("used_actions", []) is Array else [],
				"revision": int(facility.get("revision", 0)),
			})
	return {"state_revision": 0, "facilities": facilities}

static func _normalize_facility_type(raw_type: String) -> String:
	match raw_type:
		"power_conduit":
			return "power"
		"reinforcement_beacon":
			return "beacon"
		"terminal":
			return "boss_terminal"
	return raw_type

static func _default_hazard_state() -> Dictionary:
	return {"schema_version": 1, "closed_ids": {}, "resolved_damage_keys": {}, "last_turn": 0}

static func _default_encounter_state(encounter_id: String) -> Dictionary:
	return {
		"active_ids": [],
		"waiting_ids": [],
		"defeated_ids": [],
		"departed_ids": [],
		"triggered_ids": [encounter_id] if not encounter_id.is_empty() else [],
		"active_cap": 3,
		"started": true,
	}

static func _stable_encounter_id(raw_encounter_id: String, checkpoint_id: String) -> String:
	var candidate := raw_encounter_id
	if candidate.is_empty():
		candidate = checkpoint_id
	match candidate:
		"cp_start":
			return "encounter_south"
		"cp_rescue":
			return "encounter_rescue"
		"cp_pre_evac":
			return "encounter_evac"
	return candidate

static func _migrate_mission_flow(flow: Dictionary) -> Dictionary:
	var phase := String(flow.get("phase", flow.get("state", ""))).to_lower()
	if String(flow.get("step_id", "")).is_empty():
		if phase in ["escort_to_evac", "escort_scout"]:
			flow["step_id"] = "escort_scout"
			flow["step_index"] = int(flow.get("step_index", 1))
		elif phase in ["complete", "evacuate"]:
			flow["step_id"] = "evacuate"
			flow["step_index"] = int(flow.get("step_index", 2))
		else:
			flow["step_id"] = "search_scout"
			flow["step_index"] = int(flow.get("step_index", 0))
	if not flow.has("step_count"):
		flow["step_count"] = 3
	if not flow.has("completed_step_ids"):
		flow["completed_step_ids"] = {}
	return flow
