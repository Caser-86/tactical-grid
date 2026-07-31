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
## Cell -> door node_id that blocks it (for pathfinding integration).
var _door_cells: Dictionary = {}
## Power conduit -> list of facility node_ids it powers.
var _power_dependencies: Dictionary = {}
## Facility node_id -> powering conduit node_id (reverse of _power_dependencies).
var _powered_by: Dictionary = {}
## Connections for overlay rendering: [{from, to}, ...]
var _connections: Array = []
## Whether the network overlay is visible (G toggle)
var overlay_visible: bool = false


## Setup with node definitions from map data.
## CH1-060: Also accepts connections array to link power conduits to facilities
## and to render overlay links between nodes.
func setup(nodes: Array, connections: Array = []) -> void:
	_nodes.clear()
	_node_positions.clear()
	_door_cells.clear()
	_power_dependencies.clear()
	_powered_by.clear()
	_connections.clear()
	for node in nodes:
		var nid: String = String(node.get("id", ""))
		if nid == "":
			continue
		_nodes[nid] = node.duplicate(true)
		_nodes[nid]["state"] = String(node.get("state", STATE_NEUTRAL))
		_nodes[nid]["taken_over"] = false
		_node_positions[nid] = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
		# CH1-060: Index door cells for pathfinding blocking queries.
		if String(node.get("type", "")) == FACILITY_DOOR:
			_door_cells[Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))] = nid
	# CH1-060: Parse connections for power dependency and overlay rendering.
	for conn in connections:
		var from_id: String = String(conn.get("from", ""))
		var to_id: String = String(conn.get("to", ""))
		if from_id == "" or to_id == "":
			continue
		_connections.append({"from": from_id, "to": to_id})
		# Power conduits power the facilities they connect to.
		if _nodes.has(from_id) and String(_nodes[from_id].get("type", "")) == FACILITY_POWER_CONDUIT:
			if not _power_dependencies.has(from_id):
				_power_dependencies[from_id] = []
			_power_dependencies[from_id].append(to_id)
			_powered_by[to_id] = from_id


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


## CH1-060: Query an operation without executing it. Returns a preview with
## immediate_result, duration, alert_cost and facility-specific effects so the
## HUD can explain what will happen before the player commits.
func query_operation(node_id: String, operation: String, available_ap: int) -> Dictionary:
	var node: Dictionary = _nodes.get(node_id, {})
	if node.is_empty():
		return {"valid": false, "reason": "node_not_found"}
	var state: String = String(node.get("state", STATE_NEUTRAL))
	if state == STATE_DAMAGED:
		return {"valid": false, "reason": "node_damaged"}
	if available_ap < 1:
		return {"valid": false, "reason": "no_ap"}
	if operation == OP_TAKEOVER and state == STATE_PLAYER:
		return {"valid": false, "reason": "already_player_owned"}
	var ftype: String = String(node.get("type", ""))
	var preview: Dictionary = {
		"valid": true,
		"node_id": node_id,
		"operation": operation,
		"ap_cost": 1,
		"facility_type": ftype,
	}
	match operation:
		OP_TAKEOVER:
			preview["duration"] = "while_owned"
			preview["alert_cost"] = 0
			preview["immediate_result"] = _describe_takeover(ftype)
		OP_DISABLE:
			preview["duration"] = "permanent"
			preview["alert_cost"] = 0
			preview["immediate_result"] = _describe_disable(ftype)
		OP_OVERLOAD:
			preview["duration"] = "permanent"
			preview["alert_cost"] = 2
			preview["immediate_result"] = _describe_overload(ftype)
		_:
			return {"valid": false, "reason": "unknown_operation"}
	# CH1-060: Power conduit operations affect connected facilities.
	if ftype == FACILITY_POWER_CONDUIT and operation in [OP_DISABLE, OP_OVERLOAD]:
		var dependents: Array = _power_dependencies.get(node_id, [])
		if not dependents.is_empty():
			preview["facilities_disabled"] = dependents.duplicate()
			preview["immediate_result"] += "；切断 %d 个关联设施" % dependents.size()
	return preview


## CH1-060: Human-readable description of takeover effects by facility type.
func _describe_takeover(ftype: String) -> String:
	match ftype:
		FACILITY_CAMERA:
			return "接管摄像头：揭示周围区域并建立持久观察"
		FACILITY_DOOR:
			return "接管门：开启通道，改变敌方路线"
		FACILITY_TURRET:
			return "接管炮塔：转为玩家方，自动射击敌人"
		FACILITY_POWER_CONDUIT:
			return "接管电力：恢复关联设施供电"
		FACILITY_BEACON:
			return "接管信标：阻止敌方增援"
		_:
			return "接管节点"


## CH1-060: Human-readable description of disable effects by facility type.
func _describe_disable(ftype: String) -> String:
	match ftype:
		FACILITY_CAMERA:
			return "禁用摄像头：观察区收回为已记录"
		FACILITY_DOOR:
			return "禁用门：通道永久关闭"
		FACILITY_TURRET:
			return "禁用炮塔：停止射击"
		FACILITY_POWER_CONDUIT:
			return "禁用电力：关联设施断电"
		FACILITY_BEACON:
			return "禁用信标：增援延迟 +2 回合"
		_:
			return "禁用节点"


## CH1-060: Human-readable description of overload effects by facility type.
func _describe_overload(ftype: String) -> String:
	match ftype:
		FACILITY_CAMERA:
			return "过载摄像头：永久损毁，产生电击危害"
		FACILITY_DOOR:
			return "过载门：永久卡死，产生电击危害"
		FACILITY_TURRET:
			return "过载炮塔：爆炸损毁，产生电击危害"
		FACILITY_POWER_CONDUIT:
			return "过载电力：关联设施全部断电，产生电击危害"
		FACILITY_BEACON:
			return "过载信标：永久摧毁，产生电击危害"
		_:
			return "过载节点：永久损毁"


## Get the current state of a node.
func get_node_state(node_id: String) -> String:
	var node: Dictionary = _nodes.get(node_id, {})
	return String(node.get("state", STATE_NEUTRAL))


## Get all node data.
func get_all_nodes() -> Dictionary:
	return _nodes.duplicate(true)


## CH1-060: Check if a cell is blocked by a closed door (enemy/neutral state).
## Player-owned doors are open and do not block movement.
func is_cell_blocked_by_door(pos: Vector2i) -> bool:
	var nid: String = String(_door_cells.get(pos, ""))
	if nid == "":
		return false
	var state: String = get_node_state(nid)
	return state == STATE_ENEMY or state == STATE_NEUTRAL


## CH1-060: Check if a facility is available (powered and not damaged).
## A facility is unavailable if its power conduit is disabled/overloaded.
func is_facility_available(node_id: String) -> bool:
	var node: Dictionary = _nodes.get(node_id, {})
	if node.is_empty():
		return false
	var state: String = String(node.get("state", STATE_NEUTRAL))
	if state == STATE_DAMAGED:
		return false
	# Check if this facility depends on a power conduit.
	var conduit_id: String = String(_powered_by.get(node_id, ""))
	if conduit_id != "":
		var conduit_state: String = get_node_state(conduit_id)
		if conduit_state == STATE_DAMAGED:
			return false
	return true


## CH1-060: Get all connections for overlay rendering.
func get_connections() -> Array:
	return _connections.duplicate(true)


## CH1-060: Get all player-owned turrets for automatic fire during enemy turn.
## Returns array of {node_id, pos, range, damage}.
func get_player_turrets() -> Array:
	var turrets: Array = []
	for nid in _nodes:
		var node: Dictionary = _nodes[nid]
		if String(node.get("type", "")) == FACILITY_TURRET and String(node.get("state", "")) == STATE_PLAYER:
			if not is_facility_available(nid):
				continue
			turrets.append({
				"node_id": nid,
				"pos": _node_positions.get(nid, Vector2i(-1, -1)),
				"range": int(node.get("turret_range", 5)),
				"damage": int(node.get("turret_damage", 3)),
			})
	return turrets


## CH1-060: Get total reinforcement delay from all disabled beacons.
func get_reinforcement_delay_bonus() -> int:
	var total: int = 0
	for nid in _nodes:
		var node: Dictionary = _nodes[nid]
		if String(node.get("type", "")) == FACILITY_BEACON:
			var state: String = String(node.get("state", STATE_NEUTRAL))
			if state == STATE_DAMAGED:
				total += int(node.get("delay_turns", 0))
	return total


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
		"duration": "while_owned",
		"alert_cost": 0,
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
		FACILITY_BEACON:
			result["reinforcements_blocked"] = true

	network_operation_performed.emit(node_id, OP_TAKEOVER, result)
	return result


## Disable: change node state to damaged.
## CH1-060: Power conduit disable cascades to connected facilities (they lose power).
func _do_disable(node_id: String, node: Dictionary, actor_id: String, ap_remaining: int) -> Dictionary:
	node["state"] = STATE_DAMAGED

	var result: Dictionary = {
		"success": true,
		"operation": OP_DISABLE,
		"node_id": node_id,
		"ap_cost": 1,
		"ap_remaining": ap_remaining,
		"duration": "permanent",
		"alert_cost": 0,
	}

	var ftype: String = String(node.get("type", ""))
	match ftype:
		FACILITY_BEACON:
			# Disabling a beacon increases reinforcement delay
			var old_delay: int = int(node.get("delay_turns", 0))
			node["delay_turns"] = old_delay + 2
			result["delay_increased"] = true
		FACILITY_POWER_CONDUIT:
			# CH1-060: Cascading power loss to connected facilities.
			var dependents: Array = _power_dependencies.get(node_id, [])
			if not dependents.is_empty():
				result["facilities_disabled"] = dependents.duplicate()

	network_operation_performed.emit(node_id, OP_DISABLE, result)
	return result


## Overload: permanently damage facility, create hazard, raise alert.
## CH1-060: Power conduit overload cascades to connected facilities.
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
		"alert_cost": 2,
		"hazard_created": true,
		"hazard_pos": pos,
		"duration": "permanent",
	}

	var ftype: String = String(node.get("type", ""))
	if ftype == FACILITY_POWER_CONDUIT:
		# CH1-060: Cascading power loss to connected facilities.
		var dependents: Array = _power_dependencies.get(node_id, [])
		if not dependents.is_empty():
			result["facilities_disabled"] = dependents.duplicate()

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
