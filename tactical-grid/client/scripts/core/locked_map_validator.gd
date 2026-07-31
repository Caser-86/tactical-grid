## 锁定地图验证器
## CODE-P1-02: 验证锁定地图的数据完整性
## CODE-CH1-020: 扩展为 schema_version=2 模式校验，支持
## entities / network_nodes / facilities / connections / encounters / checkpoints
## 同时向后兼容 schema_version=1 的旧模式。
extends RefCounted
class_name LockedMapValidator

## 已知设施类型白名单
const KNOWN_FACILITY_TYPES := ["camera", "door", "turret", "power_conduit", "reinforcement_beacon"]

## 验证锁定地图数据。返回 {valid: bool, errors: Array[String], warnings: Array[String]}
static func validate(map_data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	# 检查 schema_version（默认 1 以兼容旧文件）
	var schema_ver := int(map_data.get("schema_version", 1))
	if schema_ver < 1:
		errors.append("Invalid schema_version: %s" % schema_ver)

	# 检查地图尺寸
	var size: Dictionary = map_data.get("size", {})
	var width := int(size.get("width", 0))
	var height := int(size.get("height", 0))
	if width <= 0 or height <= 0:
		errors.append("Invalid map size: %dx%d" % [width, height])

	# v1 字段校验：objects + nodes + connections + facilities
	# v2 字段校验：entities + network_nodes + connections + facilities + encounters + checkpoints
	# 两种命名都接受；v2 优先。先收集所有 ID，再做唯一性校验。
	var entity_ids: Dictionary = {}
	var node_ids: Dictionary = {}

	# 实体（v2 entities 或 v1 objects）
	for ent in map_data.get("entities", []):
		_validate_entity(ent, entity_ids, width, height, errors)
	# 兼容 v1：若 entities 为空且 objects 非空，也校验 objects
	if map_data.get("entities", []).is_empty():
		for obj in map_data.get("objects", []):
			_validate_entity(obj, entity_ids, width, height, errors)

	# 网络节点（v2 network_nodes 或 v1 nodes）
	for node in map_data.get("network_nodes", []):
		_validate_network_node(node, node_ids, entity_ids, width, height, errors)
	if map_data.get("network_nodes", []).is_empty():
		for node in map_data.get("nodes", []):
			_validate_network_node(node, node_ids, entity_ids, width, height, errors)

	# 检查 connections 引用有效 node ID
	for conn in map_data.get("connections", []):
		var from_id: String = String(conn.get("from", ""))
		var to_id: String = String(conn.get("to", ""))
		if from_id != "" and not node_ids.has(from_id):
			errors.append("Connection references unknown source node: %s" % from_id)
		if to_id != "" and not node_ids.has(to_id):
			errors.append("Connection references unknown target node: %s" % to_id)

	# 检查 facilities 类型与位置
	for facility in map_data.get("facilities", []):
		_validate_facility(facility, width, height, errors)

	# v2 专属字段：mission_id / encounters / checkpoints
	if schema_ver >= 2:
		_validate_v2_fields(map_data, entity_ids, node_ids, errors, warnings)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
	}

## 校验单个实体（v1 objects 与 v2 entities 共用）
static func _validate_entity(ent: Dictionary, seen_ids: Dictionary, width: int, height: int, errors: Array) -> void:
	var ent_id: String = String(ent.get("id", ""))
	if ent_id != "":
		if seen_ids.has(ent_id):
			errors.append("Duplicate entity ID: %s" % ent_id)
		else:
			seen_ids[ent_id] = true
	var x := int(ent.get("x", -1))
	var y := int(ent.get("y", -1))
	if x < 0 or x >= width or y < 0 or y >= height:
		errors.append("Entity %s at (%d,%d) out of bounds %dx%d" % [ent_id, x, y, width, height])

## 校验单个网络节点
static func _validate_network_node(node: Dictionary, node_ids: Dictionary, entity_ids: Dictionary, width: int, height: int, errors: Array) -> void:
	var node_id: String = String(node.get("id", ""))
	if node_id == "":
		errors.append("Network node missing ID")
	elif node_ids.has(node_id):
		errors.append("Duplicate network node ID: %s" % node_id)
	elif entity_ids.has(node_id):
		errors.append("Network node ID conflicts with entity ID: %s" % node_id)
	else:
		node_ids[node_id] = true
	var nx := int(node.get("x", -1))
	var ny := int(node.get("y", -1))
	if nx < 0 or nx >= width or ny < 0 or ny >= height:
		errors.append("Node %s at (%d,%d) out of bounds" % [node_id, nx, ny])

## 校验单个设施
## 设施可以由 type+x+y 直接定位，也可以通过 node_id 引用网络节点。
## 仅在提供 x/y 时校验边界，保持与旧地图兼容。
static func _validate_facility(facility: Dictionary, width: int, height: int, errors: Array) -> void:
	var ftype: String = String(facility.get("type", ""))
	if ftype != "" and not ftype in KNOWN_FACILITY_TYPES:
		errors.append("Unknown facility type: %s" % ftype)
	if facility.has("x") and facility.has("y"):
		var fx := int(facility.get("x", -1))
		var fy := int(facility.get("y", -1))
		if fx < 0 or fx >= width or fy < 0 or fy >= height:
			errors.append("Facility %s at (%d,%d) out of bounds" % [ftype, fx, fy])

## v2 专属字段校验：mission_id、encounters、checkpoints
static func _validate_v2_fields(map_data: Dictionary, entity_ids: Dictionary, node_ids: Dictionary, errors: Array, warnings: Array) -> void:
	# mission_id 必须存在且非空
	var mission_id: String = String(map_data.get("mission_id", ""))
	if mission_id == "":
		errors.append("v2 map missing mission_id")
	elif mission_id != String(map_data.get("level_id", mission_id)):
		# 仅警告：mission_id 与 level_id 不一致不致命，但应保持一致
		warnings.append("mission_id (%s) differs from level_id (%s)" % [mission_id, map_data.get("level_id", "")])

	# encounters：唯一 ID，引用的 network_node/entity 必须存在
	var encounter_ids: Dictionary = {}
	for enc in map_data.get("encounters", []):
		var enc_id: String = String(enc.get("id", ""))
		if enc_id == "":
			errors.append("Encounter missing ID")
		elif encounter_ids.has(enc_id):
			errors.append("Duplicate encounter ID: %s" % enc_id)
		else:
			encounter_ids[enc_id] = true
		# zone_id 可选；若提供，必须是有效字符串
		var zone_id: String = String(enc.get("zone_id", ""))
		if zone_id == "" and not enc.has("zone_id"):
			warnings.append("Encounter %s has no zone_id" % enc_id)
		# trigger_cells 可选；若提供，每项必须是 [x,y] 数组
		var trigger_cells = enc.get("trigger_cells", [])
		if trigger_cells is Array:
			for cell in trigger_cells:
				if not (cell is Array and cell.size() == 2):
					errors.append("Encounter %s has malformed trigger_cell: %s" % [enc_id, str(cell)])

	# checkpoints：唯一 ID，引用的 encounter 必须存在
	var checkpoint_ids: Dictionary = {}
	for cp in map_data.get("checkpoints", []):
		var cp_id: String = String(cp.get("id", ""))
		if cp_id == "":
			errors.append("Checkpoint missing ID")
		elif checkpoint_ids.has(cp_id):
			errors.append("Duplicate checkpoint ID: %s" % cp_id)
		else:
			checkpoint_ids[cp_id] = true
		# checkpoint 必须引用一个有效 encounter
		var enc_ref: String = String(cp.get("encounter_id", ""))
		if enc_ref == "":
			errors.append("Checkpoint %s missing encounter_id" % cp_id)
		elif not encounter_ids.has(enc_ref):
			errors.append("Checkpoint %s references unknown encounter: %s" % [cp_id, enc_ref])
		# next_encounter_id 可选；若提供，必须引用有效 encounter
		var next_ref: String = String(cp.get("next_encounter_id", ""))
		if next_ref != "" and not encounter_ids.has(next_ref):
			errors.append("Checkpoint %s references unknown next_encounter: %s" % [cp_id, next_ref])
