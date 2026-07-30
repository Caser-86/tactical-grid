## 锁定地图验证器
## CODE-P1-02: 验证锁定地图的数据完整性
extends RefCounted
class_name LockedMapValidator

## 验证锁定地图数据。返回 {valid: bool, errors: Array[String]}
static func validate(map_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	# 检查 schema_version
	var schema_ver = map_data.get("schema_version", 1)
	if int(schema_ver) < 1:
		errors.append("Invalid schema_version: %s" % schema_ver)

	# 检查地图尺寸
	var size: Dictionary = map_data.get("size", {})
	var width := int(size.get("width", 0))
	var height := int(size.get("height", 0))
	if width <= 0 or height <= 0:
		errors.append("Invalid map size: %dx%d" % [width, height])

	# 检查对象 ID 唯一性（同一位置可容纳多个对象，如出生点+资源，不视为错误）
	var seen_ids: Dictionary = {}
	for obj in map_data.get("objects", []):
		var obj_id: String = String(obj.get("id", ""))
		if obj_id != "":
			if seen_ids.has(obj_id):
				errors.append("Duplicate object ID: %s" % obj_id)
			seen_ids[obj_id] = true
		var x := int(obj.get("x", -1))
		var y := int(obj.get("y", -1))
		if x < 0 or x >= width or y < 0 or y >= height:
			errors.append("Object %s at (%d,%d) out of bounds %dx%d" % [obj_id, x, y, width, height])

	# 检查 nodes 和 connections（如果存在）
	var nodes: Array = map_data.get("nodes", [])
	var node_ids: Dictionary = {}
	for node in nodes:
		var node_id: String = String(node.get("id", ""))
		if node_id == "":
			errors.append("Node missing ID")
		elif node_ids.has(node_id):
			errors.append("Duplicate node ID: %s" % node_id)
		else:
			node_ids[node_id] = true
		var nx := int(node.get("x", -1))
		var ny := int(node.get("y", -1))
		if nx < 0 or nx >= width or ny < 0 or ny >= height:
			errors.append("Node %s at (%d,%d) out of bounds" % [node_id, nx, ny])

	# 检查 connections 引用有效 node ID
	for conn in map_data.get("connections", []):
		var from_id: String = String(conn.get("from", ""))
		var to_id: String = String(conn.get("to", ""))
		if not node_ids.has(from_id):
			errors.append("Connection references unknown source node: %s" % from_id)
		if not node_ids.has(to_id):
			errors.append("Connection references unknown target node: %s" % to_id)

	# 检查 facilities 引用有效 ID
	var known_facility_types := ["camera", "door", "turret", "power_conduit", "reinforcement_beacon"]
	for facility in map_data.get("facilities", []):
		var ftype: String = String(facility.get("type", ""))
		if ftype != "" and not ftype in known_facility_types:
			errors.append("Unknown facility type: %s" % ftype)

	return {"valid": errors.is_empty(), "errors": errors}