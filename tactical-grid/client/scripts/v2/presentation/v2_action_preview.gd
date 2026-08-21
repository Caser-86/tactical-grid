extends RefCounted
class_name V2ActionPreview

func build_move(unit: Unit, cell: Vector2i, move_query: Dictionary) -> Dictionary:
	var invalid := _invalid_move(StringName(String(move_query.get("reason", &"invalid_move"))))
	if unit == null or not is_instance_valid(unit) or not unit.is_alive:
		invalid["reason"] = &"invalid_unit"
		return invalid
	if not bool(move_query.get("valid", false)):
		return invalid
	var query_destination: Variant = move_query.get("target", null)
	if not query_destination is Vector2i or query_destination != cell:
		invalid["reason"] = &"destination_mismatch"
		return invalid
	var raw_path: Variant = move_query.get("path", [])
	if not raw_path is Array or raw_path.is_empty():
		invalid["reason"] = &"path_missing"
		return invalid
	var path: Array[Vector2i] = []
	for raw_cell in raw_path:
		if not raw_cell is Vector2i:
			invalid["reason"] = &"malformed_path"
			return invalid
		path.append(raw_cell)
	if path.back() != cell:
		invalid["reason"] = &"path_destination_mismatch"
		return invalid
	return {
		"valid": true,
		"path": path,
		"destination": cell,
		"dangerous": bool(move_query.get("dangerous", false)),
		"reason": &"",
	}

func build_attack(unit: Unit, target: Unit, attack_query: Dictionary) -> Dictionary:
	var invalid := _invalid_attack(StringName(String(attack_query.get("reason", &"invalid_attack"))))
	if unit == null or not is_instance_valid(unit) or not unit.is_alive:
		invalid["reason"] = &"invalid_unit"
		return invalid
	if target == null or not is_instance_valid(target) or not target.is_alive:
		invalid["reason"] = &"invalid_target"
		return invalid
	if not bool(attack_query.get("valid", false)):
		return invalid
	var query_target: Variant = attack_query.get("target_unit", null)
	if query_target != target:
		invalid["reason"] = &"target_mismatch"
		return invalid
	return {
		"valid": true,
		"target": target,
		"damage": int(attack_query.get("final_damage", attack_query.get("damage", 0))),
		"hp_after": int(attack_query.get("hp_after", target.current_hp)),
		"intent_change": StringName(String(attack_query.get("intent_change", &""))),
		"reason": &"",
	}

func _invalid_move(reason: StringName) -> Dictionary:
	return {
		"valid": false,
		"path": [] as Array[Vector2i],
		"destination": Vector2i(-1, -1),
		"dangerous": false,
		"reason": reason,
	}

func _invalid_attack(reason: StringName) -> Dictionary:
	return {
		"valid": false,
		"target": null,
		"damage": 0,
		"hp_after": 0,
		"intent_change": &"",
		"reason": reason,
	}
