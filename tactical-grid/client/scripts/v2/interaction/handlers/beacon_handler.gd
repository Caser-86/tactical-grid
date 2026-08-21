extends RefCounted
class_name V2BeaconHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	if String(facility.get("action_id", "")) == "show_sniper_ability":
		return [{
			"id": "show_sniper_ability",
			"label": "标记北侧威胁",
			"consequence": "狙击手完成一次公开远程火力演示",
			"duration_turns": -1,
			"raises_alert": false,
			"enabled": bool(context.get("can_operate", false)),
			"reason": String(context.get("reason", "")),
		}]
	var name := String(facility.get("name", "增援信标"))
	return [
		_action("suppress", "压制" + name, "延迟敌方增援两个回合", 2, false, context),
		_action("destroy", "摧毁" + name, "永久关闭增援信标", -1, true, context),
	]

func commit(_actor: Unit, _facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id == "show_sniper_ability":
		return {
			"success": true,
			"state": "showcased",
			"event": "sniper_ability_showcase",
			"sniper_lines_visible": true,
			"consequence": "狙击手已标记北侧威胁，远程火力演示完成",
			"duration_turns": -1,
			"raises_alert": false,
		}
	if action_id == "suppress":
		return {"success": true, "state": "suppressed", "consequence": "延迟敌方增援两个回合", "duration_turns": 2, "reinforcement_delay": 2, "raises_alert": false}
	if action_id == "destroy":
		return {"success": true, "state": "destroyed", "consequence": "永久关闭增援信标", "duration_turns": -1, "raises_alert": true}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}
