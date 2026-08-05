extends RefCounted
class_name V2ActionService

const V2CombatRulesScript = preload("res://scripts/v2/combat/v2_combat_rules.gd")

var _map_data: Dictionary = {}
var _players: Array = []
var _enemies: Array = []
var _previews: Dictionary = {}
var _committed_previews: Dictionary = {}
var _state_revision: int = 0
var _next_preview_id: int = 1

func setup(map_data: Dictionary, players: Array, enemies: Array) -> void:
	_map_data = map_data.duplicate(true)
	_players = players.duplicate()
	_enemies = enemies.duplicate()
	_previews.clear()
	_committed_previews.clear()
	_state_revision = 0
	_next_preview_id = 1

func query_action(request: Dictionary) -> Dictionary:
	var action := StringName(String(request.get("action", "")))
	match action:
		&"move":
			return _query_move(request)
		&"attack":
			return _query_attack(request)
		&"ability", &"interaction":
			return {"valid": false, "reason": &"unsupported_action"}
		_:
			return {"valid": false, "reason": &"unknown_action"}

func validate_action(preview: Dictionary) -> Dictionary:
	var preview_id := int(preview.get("preview_id", 0))
	if _committed_previews.has(preview_id):
		return {"valid": false, "reason": &"already_committed"}
	if not _previews.has(preview_id):
		return {"valid": false, "reason": &"unknown_preview"}
	var stored: Dictionary = _previews[preview_id]
	if int(preview.get("state_revision", -1)) != int(stored.get("state_revision", -1)):
		return {"valid": false, "reason": &"stale_preview"}
	if int(stored.get("state_revision", -1)) != _state_revision:
		return {"valid": false, "reason": &"stale_preview"}
	if not _is_fresh(stored):
		return {"valid": false, "reason": &"stale_preview"}
	return {"valid": true, "preview_id": preview_id, "state_revision": _state_revision}

func commit_action(preview: Dictionary) -> Dictionary:
	var preview_id := int(preview.get("preview_id", 0))
	if _committed_previews.has(preview_id):
		return {"success": false, "reason": &"already_committed", "preview_id": preview_id}
	var validation: Dictionary = validate_action(preview)
	if not bool(validation.get("valid", false)):
		return {"success": false, "reason": validation.get("reason", &"invalid_preview"), "preview_id": preview_id}
	var stored: Dictionary = _previews[preview_id]
	var action := StringName(String(stored.get("action", "")))
	var result: Dictionary
	match action:
		&"move":
			result = _commit_move(stored)
		&"attack":
			result = _commit_attack(stored)
		_:
			return {"success": false, "reason": &"unknown_action", "preview_id": preview_id}
	if not bool(result.get("success", false)):
		return result
	_state_revision += 1
	_previews.erase(preview_id)
	_committed_previews[preview_id] = true
	result["preview_id"] = preview_id
	result["state_revision"] = _state_revision
	return result

func cancel_preview(preview_id: int) -> void:
	_previews.erase(preview_id)

func get_state_revision() -> int:
	return _state_revision

func _query_move(request: Dictionary) -> Dictionary:
	var unit: Unit = _get_unit(request.get("unit", null))
	if unit == null:
		return {"valid": false, "reason": &"invalid_unit"}
	if not unit.v2_turn_mode_enabled or not unit.can_move():
		return {"valid": false, "reason": &"move_unavailable"}
	var target_value: Variant = request.get("target", null)
	if not target_value is Vector2i:
		return {"valid": false, "reason": &"invalid_target"}
	var target: Vector2i = target_value
	if not _is_in_bounds(target):
		return {"valid": false, "reason": &"out_of_bounds"}
	if not _is_passable(target):
		return {"valid": false, "reason": &"blocked"}
	if _is_occupied(target, unit):
		return {"valid": false, "reason": &"occupied"}
	var distance := _manhattan(unit.grid_pos, target)
	if distance <= 0:
		return {"valid": false, "reason": &"same_position"}
	if distance > maxi(1, unit.move_points):
		return {"valid": false, "reason": &"move_too_far"}
	var preview := {
		"valid": true,
		"action": &"move",
		"unit": unit,
		"unit_id": unit.entity_id,
		"from": unit.grid_pos,
		"target": target,
		"distance": distance,
		"cost": {"move": true},
	}
	return _store_preview(preview)

func _query_attack(request: Dictionary) -> Dictionary:
	var attacker: Unit = _get_unit(request.get("unit", null))
	var target: Unit = _get_unit(request.get("target", request.get("target_unit", null)))
	if attacker == null or target == null:
		return {"valid": false, "reason": &"invalid_unit"}
	if not attacker.v2_turn_mode_enabled or not attacker.can_act():
		return {"valid": false, "reason": &"action_unavailable"}
	var context: Dictionary = {}
	var raw_context: Variant = request.get("context", {})
	if raw_context is Dictionary:
		context = raw_context.duplicate(true)
	context["has_los"] = bool(context.get("has_los", true))
	context["distance"] = int(context.get("distance", _manhattan(attacker.grid_pos, target.grid_pos)))
	context["cover"] = StringName(String(context.get("cover", "none")))
	context["flanked"] = bool(context.get("flanked", false))
	context["state_revision"] = _state_revision
	var combat_preview: Dictionary = V2CombatRulesScript.preview_attack(attacker, target, context)
	if not bool(combat_preview.get("valid", false)):
		return combat_preview
	combat_preview["action"] = &"attack"
	combat_preview["unit"] = attacker
	combat_preview["target_unit"] = target
	combat_preview["context"] = context
	combat_preview["attacker_pos"] = attacker.grid_pos
	combat_preview["target_pos"] = target.grid_pos
	combat_preview["target_hp"] = target.current_hp
	combat_preview["target_shield"] = target.current_shield
	return _store_preview(combat_preview)

func _store_preview(preview: Dictionary) -> Dictionary:
	var preview_id := _next_preview_id
	_next_preview_id += 1
	preview["preview_id"] = preview_id
	preview["state_revision"] = _state_revision
	_previews[preview_id] = preview.duplicate(true)
	return preview

func _is_fresh(preview: Dictionary) -> bool:
	var unit: Unit = preview.get("unit", null)
	if unit == null or not is_instance_valid(unit) or not unit.is_alive:
		return false
	var action := StringName(String(preview.get("action", "")))
	if action == &"move":
		return unit.grid_pos == preview.get("from", Vector2i(-1, -1)) and unit.can_move()
	if action == &"attack":
		var target: Unit = preview.get("target_unit", null)
		if target == null or not is_instance_valid(target) or not target.is_alive:
			return false
		return (
			unit.grid_pos == preview.get("attacker_pos", Vector2i(-1, -1))
			and target.grid_pos == preview.get("target_pos", Vector2i(-1, -1))
			and target.current_hp == int(preview.get("target_hp", -1))
			and target.current_shield == int(preview.get("target_shield", -1))
			and unit.can_act()
		)
	return false

func _commit_move(preview: Dictionary) -> Dictionary:
	var unit: Unit = preview.get("unit", null)
	if not unit.spend_v2_move():
		return {"success": false, "reason": &"move_unavailable"}
	var from: Vector2i = unit.grid_pos
	var target: Vector2i = preview.get("target", Vector2i(-1, -1))
	unit.move_to(target)
	return {"success": true, "action": &"move", "from": from, "target": target, "event": {"type": &"unit_moved"}}

func _commit_attack(preview: Dictionary) -> Dictionary:
	var attacker: Unit = preview.get("unit", null)
	var target: Unit = preview.get("target_unit", null)
	if not attacker.spend_v2_action():
		return {"success": false, "reason": &"action_unavailable"}
	var final_damage := int(preview.get("final_damage", 0))
	var hp_damage := int(preview.get("hp_damage", 0))
	target.current_shield = int(preview.get("shield_after", target.current_shield))
	target.current_hp = maxi(0, int(preview.get("hp_after", target.current_hp)))
	target.unit_damaged.emit(target, final_damage)
	if target.current_hp <= 0:
		target.current_hp = 0
		target.is_alive = false
		target.is_downed = true
		target.unit_died.emit(target)
	return {
		"success": true,
		"action": &"attack",
		"attacker_id": attacker.entity_id,
		"target_id": target.entity_id,
		"damage": final_damage,
		"hp_damage": hp_damage,
		"event": {"type": &"damage_applied", "amount": final_damage},
	}

func _get_unit(value: Variant) -> Unit:
	if value is Unit:
		return value
	return null

func _is_in_bounds(cell: Vector2i) -> bool:
	var size: Dictionary = _map_data.get("size", {})
	var width := int(size.get("width", 0))
	var height := int(size.get("height", 0))
	return width > 0 and height > 0 and cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func _is_passable(cell: Vector2i) -> bool:
	var layers: Dictionary = _map_data.get("layers", {})
	var terrain: Variant = _layer_value(layers.get("base_terrain", []), cell)
	if terrain != null and int(terrain) == 5:
		return false
	var blocker: Variant = _layer_value(layers.get("blocker", []), cell)
	if blocker == null:
		return true
	if blocker is bool:
		return not bool(blocker)
	return int(blocker) == 0

func _layer_value(layer: Variant, cell: Vector2i) -> Variant:
	if not layer is Array:
		return null
	var rows: Array = layer
	if cell.y < 0 or cell.y >= rows.size() or not rows[cell.y] is Array:
		return null
	var row: Array = rows[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return null
	return row[cell.x]

func _is_occupied(cell: Vector2i, except_unit: Unit) -> bool:
	for raw_unit in _players + _enemies:
		var unit: Unit = raw_unit
		if unit != null and unit != except_unit and unit.is_alive and unit.grid_pos == cell:
			return true
	return false

func _manhattan(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)
