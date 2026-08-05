extends RefCounted
class_name V2CameraHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "摄像头"))
	return [
		_action("observe", "查看" + name, "揭示周围区域并保留观察", 2, false, context),
		_action("disable", "关闭" + name, "停止监控，移除它提供的观察", -1, false, context),
	]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "observe":
		return {"success": true, "state": "observed", "reveal_radius": 3, "consequence": "揭示周围区域并保留观察", "duration_turns": 2, "raises_alert": false}
	if action_id == "disable":
		return {"success": true, "state": "disabled", "consequence": "停止监控，移除它提供的观察", "duration_turns": -1, "raises_alert": false}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
