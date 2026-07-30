## Tactical network state
## Manages network nodes (camera, door, turret, power conduit, reinforcement beacon)
## and their states (enemy/player/neutral/damaged).
## Operations: takeover (1AP), disable (1AP), overload (1AP).
## Each operation has tactical consequences: reveal, route change, ownership flip, hazard, delay.
extends Node
class_name TacticalNetworkState

## Node state constants
const STATE_ENEMY := "enemy"
const STATE_PLAYER := "player"
const STATE_NEUTRAL := "neutral"
const STATE_DAMAGED := "damaged"

## Operation constants
const OP_TAKEOVER := "takeover"
const OP_DISABLE := "disable"
const OP_OVERLOAD := "overload"

## Facility type constants
const FACILITY_CAMERA := "camera"
const FACILITY_DOOR := "door"
const FACILITY_TURRET := "turret"
const FACILITY_POWER_CONDUIT := "power_conduit"
const FACILITY_BEACON := "reinforcement_beacon"

## Signal emitted when a network operation succeeds
signal network_operation_performed(node_id: String, operation: String, result: Dictionary)
## Signal emitted when alert should be raised
signal alert_requested(amount: int, reason: String)

## All nodes: node_id -> Dictionary (type, state, x, y, ...)
var _nodes: Dictionary = {}
## Node positions: node_id -> Vector2i
var _node_positions: Dictionary = {}
## Whether the network overlay is visible (G toggle)
var overlay_visible: bool = false


## Setup with node definitions from map data.
func setup(nodes: Array) -> void:
	_nodes.clear()
	_node_positions.clear()
	for node in nodes:
		var nid: String = String(node.get("id", ""))
		if nid == "":
			continue
		_nodes[nid] = node.duplicate(true)
		_nodes[nid]["state"] = String(node.get("state", STATE_NEUTRAL))
		_nodes[nid]["taken_over"] = false
		_node_positions[nid] = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))


## Perform a network operation on a node.
## Returns a result dictionary with success, ap_cost, ap_remaining, and operation-specific data.
func perform_operation(node_id: String, operation: String, actor_id: String, available_ap: int) -> Dictionary:
	var node: Dictionary = _nodes.get(node_id, {})
	if node.is_empty():
		return {"success": false, "reason": "node_not_found"}

	var state: String = node.get("state", STATE_NEUTRAL)
	if state == STATE_DAMAGED:
		return {"success": false, "reason": "node_damaged"}

	# All operations cost 1 AP
	if available_ap < 1:
		return {"success": false, "reason": "no_ap"}

	var ap_remaining: int = available_ap - 1

	match operation:
		OP_TAKEOVER:
			return _do_takeover(node_id, node, actor_id, ap_remaining)
		OP_DISABLE:
			return _do_disable(node_id, node, actor_id, ap_remaining)
		OP_OVERLOAD:
			return _do_overload(node_id, node, actor_id, ap_remaining)
		_:
			return {"success": false, "reason": "unknown_operation"}


## Get the current state of a node.
func get_node_state(node_id: String) -> String:
	var node: Dictionary = _nodes.get(node_id, {})
	return String(node.get("state", STATE_NEUTRAL))


## Get all node data.
func get_all_nodes() -> Dictionary:
	return _nodes.duplicate(true)


## Get node position.
func get_node_position(node_id: String) -> Vector2i:
	return _node_positions.get(node_id, Vector2i(-1, -1))


## Check if a door node is open (player-controlled).
func is_door_open(node_id: String) -> bool:
	var node: Dictionary = _nodes.get(node_id, {})
	if node.is_empty() or String(node.get("type", "")) != FACILITY_DOOR:
		return false
	return String(node.get("state", "")) == STATE_PLAYER


## Get turret owner team.
func get_turret_owner(node_id: String) -> String:
	var node: Dictionary = _nodes.get(node_id, {})
	if node.is_empty() or String(node.get("type", "")) != FACILITY_TURRET:
		return ""
	return String(node.get("state", STATE_NEUTRAL))


## Get beacon delay turns.
func get_beacon_delay(node_id: String) -> int:
	var node: Dictionary = _nodes.get(node_id, {})
	if node.is_empty() or String(node.get("type", "")) != FACILITY_BEACON:
		return 0
	return int(node.get("delay_turns", 0))


## Toggle overlay visibility (G key). Only affects visualization, never gameplay.
func toggle_overlay() -> void:
	overlay_visible = not overlay_visible


## Takeover: change node state to player, produce one-time pulse.
func _do_takeover(node_id: String, node: Dictionary, actor_id: String, ap_remaining: int) -> Dictionary:
	if String(node.get("state", "")) == STATE_PLAYER:
		return {"success": false, "reason": "already_player_owned"}

	node["state"] = STATE_PLAYER
	node["taken_over"] = true

	var result: Dictionary = {
		"success": true,
		"operation": OP_TAKEOVER,
		"node_id": node_id,
		"ap_cost": 1,
		"ap_remaining": ap_remaining,
		"pulse": true,
	}

	# Type-specific effects
	var ftype: String = String(node.get("type", ""))
	match ftype:
		FACILITY_CAMERA:
			result["reveal_cells"] = _compute_reveal_cells(node)
		FACILITY_DOOR:
			result["route_changed"] = true
		FACILITY_TURRET:
			result["ownership_changed"] = true

	network_operation_performed.emit(node_id, OP_TAKEOVER, result)
	return result


## Disable: change node state to damaged.
func _do_disable(node_id: String, node: Dictionary, actor_id: String, ap_remaining: int) -> Dictionary:
	node["state"] = STATE_DAMAGED

	var result: Dictionary = {
		"success": true,
		"operation": OP_DISABLE,
		"node_id": node_id,
		"ap_cost": 1,
		"ap_remaining": ap_remaining,
	}

	var ftype: String = String(node.get("type", ""))
	match ftype:
		FACILITY_BEACON:
			# Disabling a beacon increases reinforcement delay
			var old_delay: int = int(node.get("delay_turns", 0))
			node["delay_turns"] = old_delay + 2
			result["delay_increased"] = true

	network_operation_performed.emit(node_id, OP_DISABLE, result)
	return result


## Overload: permanently damage facility, create hazard, raise alert.
func _do_overload(node_id: String, node: Dictionary, actor_id: String, ap_remaining: int) -> Dictionary:
	node["state"] = STATE_DAMAGED

	var pos: Vector2i = _node_positions.get(node_id, Vector2i(-1, -1))

	var result: Dictionary = {
		"success": true,
		"operation": OP_OVERLOAD,
		"node_id": node_id,
		"ap_cost": 1,
		"ap_remaining": ap_remaining,
		"permanent": true,
		"alert_raised": true,
		"hazard_created": true,
		"hazard_pos": pos,
	}

	# Overload always raises alert
	alert_requested.emit(2, "overload")

	network_operation_performed.emit(node_id, OP_OVERLOAD, result)
	return result


## Compute reveal cells for a camera node.
func _compute_reveal_cells(node: Dictionary) -> Array:
	var pos: Vector2i = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var radius: int = int(node.get("reveal_radius", 4))
	var cells: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius:
				cells.append(Vector2i(pos.x + dx, pos.y + dy))
	return cells
