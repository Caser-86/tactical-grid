extends RefCounted
class_name V2CoolingControlHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var enabled := bool(context.get("can_operate", false))
	var reason := String(context.get("reason", ""))
	var required_encounter := String(facility.get("requires_encounter_clear", ""))
	if not required_encounter.is_empty() and not bool((context.get("cleared_encounters", {}) as Dictionary).get(required_encounter, false)):
		enabled = false
		reason = "先清理控制室附近敌人"
	if bool(facility.get("optional_complete", false)):
		enabled = false
		reason = "冷却喷口已经关闭"
	return [{
		"id": "shutdown_cooling_nozzles",
		"label": "关闭冷却喷口",
		"consequence": "停止固定危险周期，解锁突击模块 B",
		"duration_turns": -1,
		"raises_alert": false,
		"enabled": enabled,
		"reason": reason,
	}]

func commit(_actor: Unit, facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id != "shutdown_cooling_nozzles":
		return {"success": false, "reason": "unknown_action"}
	return {
		"success": true,
		"state": "offline",
		"hazard_closed": true,
		"optional_complete": true,
		"unlocked_modules": [String(facility.get("reward", "assault_b"))],
		"consequence": "冷却喷口已关闭，突击模块 B 已解锁",
		"duration_turns": -1,
		"raises_alert": false,
	}
