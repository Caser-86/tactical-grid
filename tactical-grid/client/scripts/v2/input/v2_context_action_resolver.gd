extends RefCounted
class_name V2ContextActionResolver

func resolve_click(cell: Vector2i, context: Dictionary) -> Dictionary:
	var friendly: Variant = context.get("friendly_at")
	if _is_living_player(friendly):
		var select_result := _base_result(&"select", &"living_friendly", cell)
		select_result["unit"] = friendly
		return select_result

	var selected: Variant = context.get("selected_unit")
	if selected == null:
		return _base_result(&"invalid", &"no_selected_unit", cell)
	if not _is_living_player(selected):
		return _base_result(&"invalid", &"selected_unit_unavailable", cell)

	var enemy: Variant = context.get("enemy_at")
	if _is_living_enemy(enemy):
		return _resolve_query(
			cell,
			context.get("attack_query", Callable()),
			enemy,
			&"attack",
			&"legal_attack",
			&"invalid_attack",
			&"attack_query_unavailable",
			&"malformed_attack_query",
			"target",
			"attack_preview"
		)

	var facility: Variant = context.get("facility_at", {})
	if facility is Dictionary and not facility.is_empty():
		return _resolve_query(
			cell,
			context.get("interaction_query", Callable()),
			facility,
			&"interact",
			&"usable_facility",
			&"interaction_unavailable",
			&"interaction_query_unavailable",
			&"malformed_interaction_query",
			"facility",
			"interaction_preview"
		)

	return _resolve_query(
		cell,
		context.get("move_query", Callable()),
		cell,
		&"move",
		&"reachable",
		&"invalid_move",
		&"move_query_unavailable",
		&"malformed_move_query",
		"",
		"move_preview"
	)

func _resolve_query(
	cell: Vector2i,
	query: Variant,
	candidate: Variant,
	kind: StringName,
	success_reason: StringName,
	fallback_reason: StringName,
	unavailable_reason: StringName,
	malformed_reason: StringName,
	object_key: String,
	preview_key: String
) -> Dictionary:
	if not query is Callable or not query.is_valid():
		return _base_result(&"invalid", unavailable_reason, cell)
	var raw_preview: Variant = query.call(candidate)
	if not raw_preview is Dictionary:
		return _base_result(&"invalid", malformed_reason, cell)
	var preview: Dictionary = raw_preview
	if not bool(preview.get("valid", false)):
		var invalid_result := _base_result(&"invalid", _query_reason(preview, fallback_reason), cell)
		if not object_key.is_empty():
			invalid_result[object_key] = candidate
		invalid_result[preview_key] = preview
		return invalid_result
	var result := _base_result(kind, success_reason, cell)
	if not object_key.is_empty():
		result[object_key] = candidate
	result[preview_key] = preview
	return result

func _base_result(kind: StringName, reason: StringName, cell: Vector2i) -> Dictionary:
	return {
		"kind": kind,
		"reason": reason,
		"cell": cell,
	}

func _query_reason(preview: Dictionary, fallback: StringName) -> StringName:
	var reason := String(preview.get("reason", ""))
	return StringName(reason) if not reason.is_empty() else fallback

func _is_living_player(value: Variant) -> bool:
	return _is_living_unit(value) and String(value.get("team")) == "player"

func _is_living_enemy(value: Variant) -> bool:
	return _is_living_unit(value) and String(value.get("team")) != "player"

func _is_living_unit(value: Variant) -> bool:
	return value is Object and is_instance_valid(value) and bool(value.get("is_alive"))
