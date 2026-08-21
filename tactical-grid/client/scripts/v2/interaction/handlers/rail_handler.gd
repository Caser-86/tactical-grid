extends RefCounted
class_name V2RailHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "轨道开关"))
	return [
		_action("switch", "切换" + name, "改变通行路线，打开另一条路径", -1, false, context),
		_action("jam", "卡住" + name, "固定路线并阻止敌方车辆通过", -1, true, context),
	]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "switch":
		return {"success": true, "state": "switched", "consequence": "改变通行路线，打开另一条路径", "duration_turns": -1, "raises_alert": false}
	if action_id == "jam":
		return {"success": true, "state": "jammed", "consequence": "固定路线并阻止敌方车辆通过", "duration_turns": -1, "raises_alert": true}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
