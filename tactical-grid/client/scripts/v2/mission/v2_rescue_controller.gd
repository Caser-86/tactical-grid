extends RefCounted
class_name V2RescueController

## Transactional rescue interaction for V2 mission characters.
## A captive is a map entity until the action commits; it is never represented
## as a combat Unit and therefore cannot be accidentally targeted or damaged.

signal rescue_committed(result: Dictionary)
signal checkpoint_requested(checkpoint_id: StringName, result: Dictionary)

var _map_data: Dictionary = {}
var _players: Array = []
var _enemies: Array = []
var _action_service: RefCounted = null
var _mission_flow: RefCounted = null
var _create_unit: Callable
var _register_unit: Callable
var _previews: Dictionary = {}
var _rescued: Dictionary = {}
var _state_revision := 0
var _next_preview_id := 1

func setup(
	map_data: Dictionary,
	players: Array,
	enemies: Array,
	action_service: RefCounted = null,
	mission_flow: RefCounted = null,
	create_unit: Callable = Callable(),
	register_unit: Callable = Callable(),
) -> void:
	_map_data = map_data.duplicate(true)
	# Keep the owning BattleController arrays live so joining the squad is visible
	# to rendering, turn flow and save capture in the same frame.
	_players = players
	_enemies = enemies
	_action_service = action_service
	_mission_flow = mission_flow
	_create_unit = create_unit
	_register_unit = register_unit
	_previews.clear()
	_rescued.clear()
	_state_revision = 0
	_next_preview_id = 1
	for raw_entity in _map_data.get("entities", []):
		if raw_entity is Dictionary and String((raw_entity as Dictionary).get("state", "")) == "rescued":
			_rescued[String((raw_entity as Dictionary).get("id", ""))] = true

func query_rescue(actor: Unit, rescue_id: StringName) -> Dictionary:
	var id := String(rescue_id)
	var entity := _get_rescue_entity(id)
	if entity.is_empty():
		return {"valid": false, "reason": &"rescue_unavailable", "rescue_id": id}
	if _rescued.has(id) or String(entity.get("state", "captive")) == "rescued":
		return {"valid": false, "reason": &"already_rescued", "rescue_id": id}
	if actor == null or not is_instance_valid(actor) or not _players.has(actor):
		return {"valid": false, "reason": &"invalid_actor", "rescue_id": id}
	if actor.team != "player" or not actor.is_alive:
		return {"valid": false, "reason": &"invalid_actor", "rescue_id": id}
	if not actor.v2_turn_mode_enabled or not actor.can_act():
		return {"valid": false, "reason": &"action_unavailable", "rescue_id": id}
	var target := _entity_position(entity)
	if _manhattan(actor.grid_pos, target) != 1:
		return {
			"valid": false,
			"reason": &"rescue_too_far",
			"rescue_id": id,
			"target": target,
			"distance": _manhattan(actor.grid_pos, target),
		}
	var preview := {
		"valid": true,
		"action": &"rescue",
		"actor": actor,
		"actor_id": actor.entity_id,
		"actor_pos": actor.grid_pos,
		"rescue_id": id,
		"character_id": String(entity.get("character_id", "scout")),
		"target": target,
		"target_position": target,
		"cost": {"action": true},
		"state_revision": _state_revision,
	}
	preview["preview_id"] = _next_preview_id
	_next_preview_id += 1
	_previews[preview.preview_id] = preview.duplicate(true)
	return preview

func commit_rescue(preview: Dictionary) -> Dictionary:
	var preview_id := int(preview.get("preview_id", 0))
	if not _previews.has(preview_id):
		return {"success": false, "reason": &"unknown_preview", "preview_id": preview_id}
	var stored: Dictionary = _previews[preview_id]
	var validation := _validate_preview(stored, preview)
	if not bool(validation.get("valid", false)):
		return {"success": false, "reason": validation.get("reason", &"invalid_preview"), "preview_id": preview_id}
	var actor: Unit = stored.get("actor", null)
	var rescue_id := String(stored.get("rescue_id", ""))
	var character_id := String(stored.get("character_id", "scout"))
	var target: Vector2i = stored.get("target_position", Vector2i(-1, -1))
	if not _create_unit.is_valid():
		return {"success": false, "reason": &"unit_factory_unavailable", "preview_id": preview_id}
	var new_unit: Unit = _create_unit.call(StringName(character_id), "player_%s" % character_id, target)
	if new_unit == null or not is_instance_valid(new_unit):
		return {"success": false, "reason": &"unit_creation_failed", "preview_id": preview_id}
	if not actor.spend_v2_action():
		new_unit.free()
		return {"success": false, "reason": &"action_unavailable", "preview_id": preview_id}
	if new_unit.entity_id.is_empty():
		new_unit.entity_id = "player_%s" % character_id
	new_unit.grid_pos = target
	new_unit.team = "player"
	new_unit.enable_v2_turn_mode()
	if not _players.has(new_unit):
		_players.append(new_unit)
	if _register_unit.is_valid():
		_register_unit.call(new_unit)
	var entity := _get_rescue_entity(rescue_id)
	entity["state"] = "rescued"
	entity["rescued_by"] = actor.entity_id
	_rescued[rescue_id] = true
	var flow_result := {"success": true}
	if _mission_flow != null and is_instance_valid(_mission_flow):
		flow_result = _mission_flow.apply_event(&"scout_rescued", {
			"character_id": character_id,
			"new_unit": new_unit,
			"unit_id": new_unit.entity_id,
			"position": new_unit.grid_pos,
		})
	if not bool(flow_result.get("success", false)):
		return {"success": false, "reason": flow_result.get("reason", &"mission_flow_rejected"), "preview_id": preview_id}
	_state_revision += 1
	_previews.erase(preview_id)
	if _action_service != null and _action_service.has_method("refresh_units"):
		_action_service.refresh_units(_players, _enemies)
	var result := {
		"success": true,
		"action": &"rescue",
		"rescue_id": rescue_id,
		"character_id": character_id,
		"new_unit": new_unit,
		"position": target,
		"checkpoint_id": &"cp_rescue",
		"flow": flow_result,
		"preview_id": preview_id,
		"state_revision": _state_revision,
	}
	rescue_committed.emit(result)
	checkpoint_requested.emit(&"cp_rescue", result)
	return result

func cancel_preview(preview: Dictionary) -> void:
	_previews.erase(int(preview.get("preview_id", 0)))

func get_rescue_id_at(cell: Vector2i) -> String:
	for raw_entity in _map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		if String(entity.get("type", "")) != "objective_primary":
			continue
		if _entity_position(entity) == cell:
			return String(entity.get("id", ""))
	return ""

func is_reserved_cell(cell: Vector2i) -> bool:
	return not get_rescue_id_at(cell).is_empty()

func get_rescue_position(rescue_id: StringName) -> Vector2i:
	var entity := _get_rescue_entity(String(rescue_id))
	return _entity_position(entity) if not entity.is_empty() else Vector2i(-1, -1)

func get_captive(rescue_id: StringName) -> Dictionary:
	var entity := _get_rescue_entity(String(rescue_id))
	return entity.duplicate(true)

func get_rescue_state(rescue_id: StringName) -> String:
	var id := String(rescue_id)
	if _rescued.has(id):
		return "rescued"
	var entity := _get_rescue_entity(id)
	return String(entity.get("state", "unavailable")) if not entity.is_empty() else "unavailable"

func get_state_revision() -> int:
	return _state_revision

## Restore the captive marker after loading a V2 rescue checkpoint. The Unit
## itself is restored by V2CheckpointAdapter; this method only synchronizes the
## map-side interaction state so the rescued character cannot be rescued twice.
func restore_rescued_state(rescue_id: StringName) -> bool:
	var id := String(rescue_id)
	var entity := _get_rescue_entity(id)
	if entity.is_empty():
		return false
	entity["state"] = "rescued"
	_rescued[id] = true
	_state_revision += 1
	return true

func _validate_preview(stored: Dictionary, submitted: Dictionary) -> Dictionary:
	if int(submitted.get("state_revision", -1)) != int(stored.get("state_revision", -1)):
		return {"valid": false, "reason": &"stale_preview"}
	if int(stored.get("state_revision", -1)) != _state_revision:
		return {"valid": false, "reason": &"stale_preview"}
	var actor: Unit = stored.get("actor", null)
	if actor == null or not is_instance_valid(actor) or not actor.is_alive or not actor.can_act():
		return {"valid": false, "reason": &"action_unavailable"}
	var entity := _get_rescue_entity(String(stored.get("rescue_id", "")))
	if entity.is_empty() or _rescued.has(String(stored.get("rescue_id", ""))):
		return {"valid": false, "reason": &"already_rescued"}
	if actor.grid_pos != stored.get("actor_pos", actor.grid_pos):
		return {"valid": false, "reason": &"stale_preview"}
	if _manhattan(actor.grid_pos, _entity_position(entity)) != 1:
		return {"valid": false, "reason": &"rescue_too_far"}
	return {"valid": true}

func _get_rescue_entity(rescue_id: String) -> Dictionary:
	for raw_entity in _map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		if String(entity.get("id", "")) == rescue_id and String(entity.get("type", "")) == "objective_primary":
			return entity
	return {}

func _entity_position(entity: Dictionary) -> Vector2i:
	return Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))

func _manhattan(from: Vector2i, to: Vector2i) -> int:
	return absi(from.x - to.x) + absi(from.y - to.y)
