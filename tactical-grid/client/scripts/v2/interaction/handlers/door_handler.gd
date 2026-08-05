extends RefCounted
class_name V2DoorHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "门"))
	return [
		_action("open", "开启" + name, "打开通道，允许队员通过", -1, false, context),
		_action("seal", "封锁" + name, "关闭通道，延缓敌人追击", -1, false, context),
	]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "open":
		return {"success": true, "state": "open", "consequence": "打开通道，允许队员通过", "duration_turns": -1, "raises_alert": false}
	if action_id == "seal":
		return {"success": true, "state": "sealed", "consequence": "关闭通道，延缓敌人追击", "duration_turns": -1, "raises_alert": false}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
