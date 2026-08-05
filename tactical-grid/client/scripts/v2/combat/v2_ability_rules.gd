extends RefCounted
class_name V2AbilityRules

const ABILITY_ROLES := {
	"impact_advance": "assault",
	"area_scan": "scout",
	"interrupt_shot": "sniper",
	"barrier_projection": "heavy",
}
const COOLDOWNS := {
	"impact_advance": 2,
	"area_scan": 3,
	"interrupt_shot": 3,
	"barrier_projection": 3,
}

static func query(actor: Unit, ability_id: StringName, target_data: Dictionary, context: Dictionary) -> Dictionary:
	if actor == null:
		return {"valid": false, "reason": &"invalid_unit"}
	if not actor.is_alive or not actor.v2_turn_mode_enabled:
		return {"valid": false, "reason": &"action_unavailable"}
	var id := String(ability_id)
	if not ABILITY_ROLES.has(id):
		return {"valid": false, "reason": &"unknown_ability"}
	if String(actor.job) != String(ABILITY_ROLES[id]):
		return {"valid": false, "reason": &"wrong_role"}
	if actor.v2_turn_state.get_cooldown(ability_id) > 0:
		return {"valid": false, "reason": &"on_cooldown"}
	if not actor.can_act():
		return {"valid": false, "reason": &"action_unavailable"}
	var preview: Dictionary
	match ability_id:
		&"impact_advance":
			preview = _query_impact_advance(actor, target_data, context)
		&"area_scan":
			preview = _query_area_scan(actor, target_data, context)
		&"interrupt_shot":
			preview = _query_interrupt_shot(actor, target_data, context)
		&"barrier_projection":
			preview = _query_barrier(actor, target_data, context)
		_:
			return {"valid": false, "reason": &"unknown_ability"}
	if not bool(preview.get("valid", false)):
		return preview
	preview["ability_id"] = ability_id
	preview["actor_id"] = actor.entity_id
	preview["actor"] = actor
	preview["cooldown"] = int(COOLDOWNS.get(id, 0))
	preview["cost"] = {"action": true}
	preview["state_revision"] = int(context.get("state_revision", 0))
	return preview

static func commit(actor: Unit, preview: Dictionary, context: Dictionary) -> Dictionary:
	if actor == null or not bool(preview.get("valid", false)):
		return {"success": false, "reason": &"invalid_preview"}
	if String(preview.get("actor_id", "")) != actor.entity_id:
		return {"success": false, "reason": &"wrong_actor"}
	if context.has("state_revision") and int(context.get("state_revision", -1)) != int(preview.get("state_revision", -2)):
		return {"success": false, "reason": &"stale_preview"}
	if not actor.is_alive or not actor.v2_turn_mode_enabled or not actor.can_act():
		return {"success": false, "reason": &"action_unavailable"}
	var ability_id := StringName(String(preview.get("ability_id", "")))
	if actor.v2_turn_state.get_cooldown(ability_id) > 0:
		return {"success": false, "reason": &"on_cooldown"}
	if not actor.spend_v2_action():
		return {"success": false, "reason": &"action_unavailable"}
	actor.v2_turn_state.set_cooldown(ability_id, int(preview.get("cooldown", COOLDOWNS.get(String(ability_id), 0))))
	var result: Dictionary = {"success": true, "ability_id": ability_id, "actor_id": actor.entity_id}
	match ability_id:
		&"impact_advance":
			var destination: Vector2i = preview.get("destination", actor.grid_pos)
			actor.move_to(destination)
			result["move_distance"] = int(preview.get("move_distance", 0))
			result["push_distance"] = int(preview.get("push_distance", 0))
			result["shield_after_push"] = int(preview.get("shield_after_push", 0))
		&"area_scan":
			result["reveal_radius"] = int(preview.get("reveal_radius", 0))
			result["disable_cameras"] = bool(preview.get("disable_cameras", false))
		&"interrupt_shot":
			var target: Unit = preview.get("target_unit", null)
			if target == null or not is_instance_valid(target) or not target.is_alive:
				return {"success": false, "reason": &"target_invalid"}
			target.take_damage(int(preview.get("damage", 0)))
			result["damage"] = int(preview.get("damage", 0))
			result["cancel_intent"] = bool(preview.get("cancel_intent", false))
			result["mark_target"] = bool(preview.get("mark_target", false))
		&"barrier_projection":
			var barrier_target: Unit = preview.get("target_unit", actor)
			var shield := int(preview.get("shield", 0))
			barrier_target.max_shield = maxi(barrier_target.max_shield, shield)
			barrier_target.current_shield = mini(barrier_target.max_shield, barrier_target.current_shield + shield)
			result["shield"] = shield
			result["target_id"] = barrier_target.entity_id
	return result

static func apply_passive(event_name: StringName, actor: Unit, context: Dictionary) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if actor == null or not actor.is_alive:
		return effects
	var passive_id := String(context.get("passive_id", _passive_for_role(actor.job)))
	match passive_id:
		&"close_armor":
			if event_name == &"turn_ended" and int(context.get("observed_enemy_distance", 999)) <= 3:
				effects.append({"type": &"shield", "passive_id": &"close_armor", "shield": 1})
		&"forward_observer":
			if event_name == &"enemy_revealed":
				effects.append({"type": &"vision_bonus", "passive_id": &"forward_observer", "vision_bonus": 1})
		&"steady_position":
			if event_name == &"before_attack_preview" and not bool(context.get("did_move", true)):
				effects.append({"type": &"damage_bonus", "passive_id": &"steady_position", "damage_bonus": 1})
		&"heavy_frame":
			if event_name == &"before_attack_taken" and bool(context.get("direct", false)) and not bool(context.get("already_triggered", false)):
				effects.append({"type": &"damage_reduction", "passive_id": &"heavy_frame", "damage_reduction": 1})
	return effects

static func _query_impact_advance(actor: Unit, target_data: Dictionary, context: Dictionary) -> Dictionary:
	var position: Variant = target_data.get("position", null)
	if not position is Vector2i:
		return {"valid": false, "reason": &"invalid_target"}
	var destination: Vector2i = position
	var distance := absi(destination.x - actor.grid_pos.x) + absi(destination.y - actor.grid_pos.y)
	if distance <= 0 or distance > 3 or (destination.x != actor.grid_pos.x and destination.y != actor.grid_pos.y):
		return {"valid": false, "reason": &"not_straight_or_too_far"}
	var modules: Array = _modules(context)
	var result := {
		"valid": true,
		"destination": destination,
		"move_distance": distance,
		"push_distance": 1 + (1 if "assault_a" in modules else 0),
		"shield_after_push": 1 if "assault_b" in modules else 0,
	}
	return result

static func _query_area_scan(actor: Unit, target_data: Dictionary, context: Dictionary) -> Dictionary:
	var position: Variant = target_data.get("position", actor.grid_pos)
	if not position is Vector2i:
		return {"valid": false, "reason": &"invalid_target"}
	var target: Vector2i = position
	var distance := absi(target.x - actor.grid_pos.x) + absi(target.y - actor.grid_pos.y)
	if distance > 3:
		return {"valid": false, "reason": &"scan_out_of_range"}
	var modules: Array = _modules(context)
	return {
		"valid": true,
		"position": target,
		"reveal_radius": 3 + (1 if "scout_a" in modules else 0),
		"reveal_intent": true,
		"disable_cameras": "scout_b" in modules,
	}

static func _query_interrupt_shot(actor: Unit, target_data: Dictionary, context: Dictionary) -> Dictionary:
	var target: Unit = target_data.get("target_unit", null)
	if target == null or not is_instance_valid(target) or not target.is_alive:
		return {"valid": false, "reason": &"target_invalid"}
	if String(target.team) == String(actor.team):
		return {"valid": false, "reason": &"same_team"}
	var distance := absi(target.grid_pos.x - actor.grid_pos.x) + absi(target.grid_pos.y - actor.grid_pos.y)
	if distance > 8:
		return {"valid": false, "reason": &"out_of_range"}
	var modules: Array = _modules(context)
	return {
		"valid": true,
		"target_unit": target,
		"damage": 2 + (1 if "sniper_a" in modules else 0),
		"cancel_intent": true,
		"mark_target": "sniper_b" in modules,
	}

static func _query_barrier(actor: Unit, target_data: Dictionary, context: Dictionary) -> Dictionary:
	var target: Unit = target_data.get("target_unit", actor)
	if target == null or not is_instance_valid(target) or not target.is_alive:
		return {"valid": false, "reason": &"target_invalid"}
	if String(target.team) != String(actor.team):
		return {"valid": false, "reason": &"same_team_required"}
	var modules: Array = _modules(context)
	var target_range := 2 if "heavy_b" in modules else 1
	var distance := absi(target.grid_pos.x - actor.grid_pos.x) + absi(target.grid_pos.y - actor.grid_pos.y)
	if distance > target_range:
		return {"valid": false, "reason": &"target_out_of_range"}
	return {
		"valid": true,
		"target_unit": target,
		"shield": 2 + (1 if "heavy_a" in modules else 0),
		"duration": 2,
		"target_range": target_range,
	}

static func _modules(context: Dictionary) -> Array:
	var raw_modules: Variant = context.get("modules", [])
	if raw_modules is Array:
		return (raw_modules as Array).duplicate()
	if raw_modules is Dictionary:
		var values: Array = []
		for raw_id in raw_modules.values():
			values.append(String(raw_id))
		return values
	return []

static func _passive_for_role(role: String) -> String:
	match role:
		"assault": return "close_armor"
		"scout": return "forward_observer"
		"sniper": return "steady_position"
		"heavy": return "heavy_frame"
	return ""
