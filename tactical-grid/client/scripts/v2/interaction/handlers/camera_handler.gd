extends RefCounted
class_name V2CameraHandler

func query(_actor: Unit, facility: Dictionary, context: Dictionary) -> Array:
	var name := String(facility.get("name", "摄像头"))
	var view_action_id := String(facility.get("action_id", "observe"))
	return [
		_action(view_action_id, "查看" + name, "揭示周围区域并持续观察", -1, false, context),
		_action("disable_camera", "关闭" + name, "停止监控，移除它提供的观察", -1, false, context),
	]

func commit(actor: Unit, facility: Dictionary, action_id: String, _context: Dictionary) -> Dictionary:
	var view_action_id := String(facility.get("action_id", "observe"))
	var zone_id := String(facility.get("camera_zone_id", ""))
	if zone_id.is_empty() and view_action_id == "view_camera_east":
		zone_id = "camera_east_zone"
	if action_id == view_action_id:
		var result := {
			"success": true,
			"state": "observed",
			"reveal_radius": int(facility.get("reveal_radius", 3)),
			"reveal_center": _position(facility.get("reveal_center", facility.get("position", Vector2i(-1, -1)))),
			"camera_zone_id": zone_id,
			"camera_zone_cells": _zone_cells(facility),
			"consequence": "揭示周围区域并保留观察",
			"duration_turns": -1,
			"raises_alert": false,
		}
		if _has_module(actor, "scout_b"):
			result["module_camera_disable_turns"] = 1
			result["consequence"] = "揭示周围区域并保留观察；侦察模块 B 使摄像头短暂失效"
		return result
	if action_id == "disable_camera":
		return {
			"success": true,
			"state": "disabled",
			"camera_zone_id": zone_id,
			"camera_zone_cells": [],
			"consequence": "停止监控，移除它提供的观察",
			"duration_turns": -1,
			"raises_alert": false,
		}
	return {"success": false, "reason": "unknown_action"}

func _action(id: String, label: String, consequence: String, duration: int, alert: bool, context: Dictionary) -> Dictionary:
	return {"id": id, "label": label, "consequence": consequence, "duration_turns": duration, "raises_alert": alert, "enabled": bool(context.get("can_operate", false)), "reason": String(context.get("reason", ""))}

func _position(raw_position: Variant) -> Vector2i:
	if raw_position is Vector2i:
		return raw_position
	if raw_position is Array and raw_position.size() >= 2:
		return Vector2i(int(raw_position[0]), int(raw_position[1]))
	if raw_position is Dictionary:
		return Vector2i(int(raw_position.get("x", -1)), int(raw_position.get("y", -1)))
	return Vector2i(-1, -1)

func _zone_cells(facility: Dictionary) -> Array[Vector2i]:
	var center := _position(facility.get("reveal_center", facility.get("position", Vector2i(-1, -1))))
	var radius := maxi(0, int(facility.get("reveal_radius", 3)))
	var size: Dictionary = facility.get("map_size", {})
	var width := int(size.get("width", 0))
	var height := int(size.get("height", 0))
	var cells: Array[Vector2i] = []
	if center.x < 0:
		return cells
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if absi(x - center.x) + absi(y - center.y) > radius:
				continue
			if width > 0 and (x < 0 or x >= width or y < 0 or y >= height):
				continue
			cells.append(Vector2i(x, y))
	return cells

func _has_module(actor: Unit, module_id: String) -> bool:
	if actor == null or actor.job != "scout":
		return false
	var equipment: Dictionary = actor.equipment if actor.equipment is Dictionary else {}
	for key in ["v2_modules", "modules", "module_ids"]:
		var modules: Variant = equipment.get(key, [])
		if modules is Array and module_id in modules:
			return true
	return false
