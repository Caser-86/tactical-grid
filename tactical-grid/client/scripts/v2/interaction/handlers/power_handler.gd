extends RefCounted
class_name V2PowerHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var configured_action := String(facility.get("action_id", ""))
	if configured_action == "cut_power_grid":
		return [_action("cut_power_grid", "切断西侧电网", "西侧观察范围降低，维护门解锁", -1, false, context)]
	var name := String(facility.get("name", "电力节点"))
	return [
		_action("reroute", "重接" + name, "恢复关联设施供电", -1, false, context),
		_action("overload", "过载" + name, "永久破坏节点并制造噪声", -1, true, context),
	]

func commit(_actor: Unit, facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "cut_power_grid":
		return {
			"success": true,
			"state": "offline",
			"power_state": "offline",
			"enemy_vision_delta": -2,
			"door_id": "west_service_door",
			"route_id": String(facility.get("route_id", "west_maintenance")),
			"map_changes": (facility.get("map_changes", []) as Array).duplicate(true),
			"enemy_intent_changes": (facility.get("enemy_intent_changes", {}) as Dictionary).duplicate(true),
			"event": "lockdown_cleared",
			"consequence": "西侧电网已切断，观察范围降低，维护门解锁",
			"duration_turns": -1,
			"raises_alert": false,
		}
	if action_id == "reroute":
		return {"success": true, "state": "restored", "consequence": "恢复关联设施供电", "duration_turns": -1, "raises_alert": false}
	if action_id == "overload":
		return {"success": true, "state": "damaged", "consequence": "永久破坏节点并制造噪声", "duration_turns": -1, "raises_alert": true}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
