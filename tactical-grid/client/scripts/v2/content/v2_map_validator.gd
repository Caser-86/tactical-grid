extends RefCounted
class_name V2MapValidator

const REQUIRED_LAYERS := ["base_terrain", "blocker", "vision", "height", "cover"]
const ALLOWED_FACILITY_TYPES := ["camera", "door", "power", "rail", "beacon", "boss_terminal", "record"]
const BLOCKED_TERRAIN_VALUES := [5]

static func validate(map_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if map_data.is_empty():
		errors.append("map root must be a non-empty object")
		return {"valid": false, "errors": errors, "warnings": warnings}

	if int(map_data.get("schema_version", 0)) != 3:
		errors.append("schema_version must be exactly 3")
	var map_id := String(map_data.get("map_id", ""))
	if map_id.is_empty():
		errors.append("map_id is required")
	if String(map_data.get("mission_id", "")).is_empty():
		errors.append("mission_id is required")

	var size: Variant = map_data.get("size", {})
	var width := 0
	var height := 0
	if not size is Dictionary:
		errors.append("size must be an object")
	else:
		width = int(size.get("width", 0))
		height = int(size.get("height", 0))
		if width <= 0 or height <= 0:
			errors.append("size must contain positive width and height")

	var layers_valid := _validate_layers(map_data.get("layers", {}), width, height, errors)
	var stable_ids: Dictionary = {}
	var spawn_cells: Array[Vector2i] = []
	var primary_cells: Array[Vector2i] = []
	var evac_cells: Array[Vector2i] = []
	var entity_by_id: Dictionary = {}

	var entities: Variant = map_data.get("entities", [])
	if not entities is Array:
		errors.append("entities must be an array")
	else:
		for raw_entity in entities:
			if not raw_entity is Dictionary:
				errors.append("entity must be an object")
				continue
			var entity: Dictionary = raw_entity
			var entity_id := String(entity.get("id", ""))
			_register_id(entity_id, "entity", stable_ids, errors)
			if not entity_id.is_empty():
				entity_by_id[entity_id] = entity
			_validate_position(entity, "entity " + entity_id, width, height, errors)
			var cell := Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))
			var entity_type := String(entity.get("type", ""))
			if entity_type.is_empty():
				errors.append("entity %s is missing type" % entity_id)
			if entity_type == "spawn_player":
				spawn_cells.append(cell)
			if _is_primary_entity(entity):
				primary_cells.append(cell)
			if _is_evac_entity(entity):
				evac_cells.append(cell)

	if spawn_cells.is_empty():
		errors.append("at least one spawn_player entity is required")
	if evac_cells.is_empty():
		errors.append("at least one evac entity is required")

	var primary_id := String(map_data.get("primary_objective_id", ""))
	if not primary_id.is_empty():
		if not entity_by_id.has(primary_id):
			errors.append("primary_objective_id references unknown entity: %s" % primary_id)
		else:
			primary_cells = [_entity_cell(entity_by_id[primary_id])]
	if primary_cells.is_empty():
		warnings.append("map has no primary objective entity; route check is limited to evacuation")

	_validate_encounters(map_data.get("encounters", []), width, height, stable_ids, errors)
	_validate_checkpoints(map_data.get("checkpoints", []), width, height, stable_ids, errors)
	_validate_facilities(map_data.get("facilities", []), width, height, stable_ids, errors)
	_validate_route_references(map_data, stable_ids, errors)

	if layers_valid and width > 0 and height > 0:
		if not primary_cells.is_empty() and not _any_route_reaches(map_data, spawn_cells, primary_cells):
			errors.append("no player spawn can reach the primary objective")
		if not evac_cells.is_empty() and not _any_route_reaches(map_data, spawn_cells, evac_cells):
			errors.append("no player spawn can reach an evacuation point")

	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}

static func _validate_layers(raw_layers: Variant, width: int, height: int, errors: Array[String]) -> bool:
	if not raw_layers is Dictionary:
		errors.append("layers must be an object")
		return false
	var layers: Dictionary = raw_layers
	var non_empty := false
	for layer_name in REQUIRED_LAYERS:
		if not layers.has(layer_name):
			errors.append("layers missing %s" % layer_name)
			continue
		if not layers[layer_name] is Array:
			errors.append("layer %s must be an array" % layer_name)
			continue
		if not (layers[layer_name] as Array).is_empty():
			non_empty = true
	if not non_empty:
		return true
	var valid := true
	for layer_name in REQUIRED_LAYERS:
		if not layers.has(layer_name) or not layers[layer_name] is Array:
			valid = false
			continue
		var rows: Array = layers[layer_name]
		if rows.size() != height:
			errors.append("layer %s height %d does not match %d" % [layer_name, rows.size(), height])
			valid = false
		for row in rows:
			if not row is Array or (row as Array).size() != width:
				errors.append("layer %s row width does not match %d" % [layer_name, width])
				valid = false
	return valid

static func _validate_encounters(raw_encounters: Variant, width: int, height: int, stable_ids: Dictionary, errors: Array[String]) -> void:
	if not raw_encounters is Array:
		errors.append("encounters must be an array")
		return
	for raw_encounter in raw_encounters:
		if not raw_encounter is Dictionary:
			errors.append("encounter must be an object")
			continue
		var encounter: Dictionary = raw_encounter
		var encounter_id := String(encounter.get("id", ""))
		_register_id(encounter_id, "encounter", stable_ids, errors)
		var position: Variant = _optional_cell(encounter)
		if position != null:
			_validate_cell(position, "encounter " + encounter_id, width, height, errors)
		for trigger_cell in encounter.get("trigger_cells", []):
			var parsed: Variant = _parse_cell(trigger_cell)
			if parsed == null:
				errors.append("encounter %s has malformed trigger cell" % encounter_id)
			else:
				_validate_cell(parsed, "encounter " + encounter_id + " trigger", width, height, errors)
		var active_cap := _first_int(encounter, ["active_cap", "max_active", "mission_active_cap"], -1)
		var active_count := _first_int(encounter, ["active_count", "active_enemies", "enemy_count", "spawn_count"], -1)
		if active_cap < 0 and active_count >= 0:
			errors.append("encounter %s has active count without active cap" % encounter_id)
		if active_cap >= 0 and active_count >= 0 and active_count > active_cap:
			errors.append("encounter %s active count exceeds cap" % encounter_id)

static func _validate_checkpoints(raw_checkpoints: Variant, width: int, height: int, stable_ids: Dictionary, errors: Array[String]) -> void:
	if not raw_checkpoints is Array:
		errors.append("checkpoints must be an array")
		return
	var encounter_ids: Dictionary = {}
	# Encounter IDs are collected from the already validated stable ID namespace.
	for raw_id in stable_ids.keys():
		if String(raw_id).begins_with("encounter:"):
			encounter_ids[String(raw_id).trim_prefix("encounter:")] = true
	for raw_checkpoint in raw_checkpoints:
		if not raw_checkpoint is Dictionary:
			errors.append("checkpoint must be an object")
			continue
		var checkpoint: Dictionary = raw_checkpoint
		var checkpoint_id := String(checkpoint.get("id", ""))
		_register_id(checkpoint_id, "checkpoint", stable_ids, errors)
		var position: Variant = _optional_cell(checkpoint)
		if position != null:
			_validate_cell(position, "checkpoint " + checkpoint_id, width, height, errors)
		var encounter_id := String(checkpoint.get("encounter_id", ""))
		if encounter_id.is_empty():
			errors.append("checkpoint %s missing encounter_id" % checkpoint_id)
		elif not encounter_ids.has(encounter_id):
			errors.append("checkpoint %s references unknown encounter: %s" % [checkpoint_id, encounter_id])
		var next_id := String(checkpoint.get("next_encounter_id", ""))
		if not next_id.is_empty() and not encounter_ids.has(next_id):
			errors.append("checkpoint %s references unknown next encounter: %s" % [checkpoint_id, next_id])

static func _validate_facilities(raw_facilities: Variant, width: int, height: int, stable_ids: Dictionary, errors: Array[String]) -> void:
	if not raw_facilities is Array:
		errors.append("facilities must be an array")
		return
	for raw_facility in raw_facilities:
		if not raw_facility is Dictionary:
			errors.append("facility must be an object")
			continue
		var facility: Dictionary = raw_facility
		var facility_id := String(facility.get("id", ""))
		_register_id(facility_id, "facility", stable_ids, errors)
		var facility_type := String(facility.get("type", facility.get("action", "")))
		if not facility_type in ALLOWED_FACILITY_TYPES:
			errors.append("unknown facility action: %s" % facility_type)
		var position: Variant = _optional_cell(facility)
		if position != null:
			_validate_cell(position, "facility " + facility_id, width, height, errors)

static func _validate_route_references(map_data: Dictionary, stable_ids: Dictionary, errors: Array[String]) -> void:
	for route in map_data.get("main_routes", []):
		if not route is Dictionary:
			errors.append("main route must be an object")
			continue
		var route_id := String(route.get("id", ""))
		if route_id.is_empty():
			errors.append("main route is missing id")
		for required_id in route.get("required_ids", []):
			if not stable_ids.has(String(required_id)):
				errors.append("main route %s references unknown ID: %s" % [route_id, required_id])

static func _validate_position(record: Dictionary, label: String, width: int, height: int, errors: Array[String]) -> void:
	if not record.has("x") or not record.has("y"):
		errors.append("%s is missing x/y" % label)
		return
	_validate_cell(Vector2i(int(record.get("x", -1)), int(record.get("y", -1))), label, width, height, errors)

static func _validate_cell(cell: Vector2i, label: String, width: int, height: int, errors: Array[String]) -> void:
	if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
		errors.append("%s at (%d,%d) is out of bounds" % [label, cell.x, cell.y])

static func _register_id(id: String, kind: String, stable_ids: Dictionary, errors: Array[String]) -> void:
	if id.is_empty():
		errors.append("%s is missing stable id" % kind)
		return
	if stable_ids.has(id):
		errors.append("duplicate stable ID: %s" % id)
		return
	stable_ids[id] = true
	# Keep a typed alias for checkpoint encounter lookup without changing public IDs.
	if kind == "encounter":
		stable_ids["encounter:" + id] = true

static func _is_primary_entity(entity: Dictionary) -> bool:
	var entity_type := String(entity.get("type", ""))
	return entity_type in ["objective_primary", "primary_objective"] or (
		entity_type in ["objective", "terminal"] and String(entity.get("objective", "")) == "primary"
	)

static func _is_evac_entity(entity: Dictionary) -> bool:
	return String(entity.get("type", "")) in ["evac", "extract", "extraction", "evac_zone"]

static func _entity_cell(entity: Dictionary) -> Vector2i:
	return Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))

static func _optional_cell(record: Dictionary) -> Variant:
	if record.has("x") and record.has("y"):
		return Vector2i(int(record.get("x", -1)), int(record.get("y", -1)))
	if record.has("cell"):
		return _parse_cell(record.get("cell"))
	return null

static func _parse_cell(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return null

static func _first_int(record: Dictionary, keys: Array, default_value: int) -> int:
	for key in keys:
		if record.has(key):
			return int(record.get(key, default_value))
	return default_value

static func _any_route_reaches(map_data: Dictionary, starts: Array[Vector2i], targets: Array[Vector2i]) -> bool:
	for start in starts:
		for target in targets:
			if _is_reachable(map_data, start, target):
				return true
	return false

static func _is_reachable(map_data: Dictionary, start: Vector2i, target: Vector2i) -> bool:
	if start == target:
		return true
	var size: Dictionary = map_data.get("size", {})
	var width := int(size.get("width", 0))
	var height := int(size.get("height", 0))
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in directions:
			var next: Vector2i = current + direction
			if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
				continue
			if visited.has(next) or not _is_passable(map_data, next):
				continue
			if next == target:
				return true
			visited[next] = true
			queue.append(next)
	return false

static func _is_passable(map_data: Dictionary, cell: Vector2i) -> bool:
	var layers: Dictionary = map_data.get("layers", {})
	var terrain: Variant = _layer_value(layers.get("base_terrain", []), cell)
	if terrain != null and int(terrain) in BLOCKED_TERRAIN_VALUES:
		return false
	var blocker: Variant = _layer_value(layers.get("blocker", []), cell)
	if blocker == null:
		return true
	if blocker is bool:
		return bool(blocker) == false
	return int(blocker) == 0

static func _layer_value(layer: Variant, cell: Vector2i) -> Variant:
	if not layer is Array:
		return null
	var rows: Array = layer
	if cell.y < 0 or cell.y >= rows.size() or not rows[cell.y] is Array:
		return null
	var row: Array = rows[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return null
	return row[cell.x]
