extends RefCounted
class_name V2BossTerminalHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "核心终端"))
	return [
		_action("decrypt", "破解" + name, "揭示 Boss 弱点并解锁撤离信号", -1, true, context),
		_action("extract", "读取" + name, "取得任务数据并标记最终目标", -1, false, context),
	]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "decrypt":
		return {"success": true, "state": "decrypted", "consequence": "揭示 Boss 弱点并解锁撤离信号", "duration_turns": -1, "boss_exposed": true, "raises_alert": true}
	if action_id == "extract":
		return {"success": true, "state": "extracted", "consequence": "取得任务数据并标记最终目标", "duration_turns": -1, "objective_complete": true, "raises_alert": false}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
