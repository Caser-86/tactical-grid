extends RefCounted
class_name V2RecordHandler

func query(_actor: Unit, _facility: Dictionary, context: Dictionary) -> Array:
	var enabled := bool(context.get("can_operate", false))
	var reason := String(context.get("reason", ""))
	if bool(context.get("optional_complete", false)):
		enabled = false
		reason = "事故记录已经上传"
	return [{
		"id": "upload_incident_record",
		"label": "上传事故记录",
		"consequence": "完成可选目标，解锁侦察模块 B",
		"duration_turns": -1,
		"raises_alert": false,
		"enabled": enabled,
		"reason": reason,
	}]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id != "upload_incident_record":
		return {"success": false, "reason": "unknown_action"}
	return {
		"success": true,
		"state": "uploaded",
		"consequence": "事故记录已上传，侦察模块 B 已登记",
		"duration_turns": -1,
		"raises_alert": false,
		"optional_complete": true,
		"optional_record_uploaded": true,
		"reward_module": "scout_b",
		"unlocked_modules": ["scout_b"],
	}
