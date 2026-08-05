extends RefCounted
class_name V2PowerHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "电力节点"))
	return [
		_action("reroute", "重接" + name, "恢复关联设施供电", -1, false, context),
		_action("overload", "过载" + name, "永久破坏节点并制造噪声", -1, true, context),
	]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "reroute":
		return {"success": true, "state": "restored", "consequence": "恢复关联设施供电", "duration_turns": -1, "raises_alert": false}
	if action_id == "overload":
		return {"success": true, "state": "damaged", "consequence": "永久破坏节点并制造噪声", "duration_turns": -1, "raises_alert": true}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
