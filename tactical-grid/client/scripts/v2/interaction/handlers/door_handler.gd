extends RefCounted
class_name V2DoorHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	if String(facility.get("action_id", "")) == "bypass_security_door":
		return [_action("bypass_security_door", "旁路东侧安全门", "保留电力并显示狙击预警线", -1, false, context)]
	var name := String(facility.get("name", "门"))
	return [
		_action("open", "开启" + name, "打开通道，允许队员通过", -1, false, context),
		_action("seal", "封锁" + name, "关闭通道，延缓敌人追击", -1, false, context),
	]

func commit(_actor: Unit, facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "bypass_security_door":
		return {
			"success": true,
			"state": "open",
			"door_state": "open",
			"sniper_lines_visible": true,
			"power_state": "online",
			"route_id": String(facility.get("route_id", "east_overpass")),
			"map_changes": (facility.get("map_changes", []) as Array).duplicate(true),
			"enemy_intent_changes": (facility.get("enemy_intent_changes", {}) as Dictionary).duplicate(true),
			"event": "lockdown_cleared",
			"consequence": "东侧安全门已旁路，电力保持在线，狙击预警线已显示",
			"duration_turns": -1,
			"raises_alert": false,
		}
	if action_id == "open":
		return {"success": true, "state": "open", "consequence": "打开通道，允许队员通过", "duration_turns": -1, "raises_alert": false}
	if action_id == "seal":
		return {"success": true, "state": "sealed", "consequence": "关闭通道，延缓敌人追击", "duration_turns": -1, "raises_alert": false}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
