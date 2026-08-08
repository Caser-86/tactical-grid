extends RefCounted
class_name V2GantryCraneHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "吊机控制台"))
	return [{
		"id": "lower_gantry",
		"label": "放下" + name,
		"consequence": "打开吊桥，解除撤离路线封锁；撤离拦截敌人将进入警戒",
		"duration_turns": -1,
		"raises_alert": false,
		"enabled": bool(context.get("can_operate", false)),
		"reason": String(context.get("reason", "")),
	}]

func commit(_actor: Unit, facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	if action_id != "lower_gantry":
		return {"success": false, "reason": "unknown_action"}
	return {
		"success": true,
		"state": "open",
		"route_id": String(facility.get("route_id", "gantry_bridge")),
		"map_changes": (facility.get("map_changes", []) as Array).duplicate(true),
		"enemy_intent_changes": (facility.get("enemy_intent_changes", {}) as Dictionary).duplicate(true),
		"consequence": "吊桥已放下，撤离路线开放；撤离拦截敌人已进入警戒",
		"duration_turns": -1,
		"raises_alert": false,
	}
