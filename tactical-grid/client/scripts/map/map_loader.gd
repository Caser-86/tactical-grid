## 地图加载器
## 从客户端锁定 JSON 加载正式关卡数据。
class_name MapLoader

## 锁定地图存放目录（相对 res://）
const LOCKED_MAPS_DIR := "res://data/locked_maps/"

## 按 level_id 加载锁定地图 JSON。
## 成功返回 { "ok": true, "data": <map_dict> }，失败返回 { "ok": false, "error": <msg> }。
## 锁定地图是服务端生成并版本锁定的正式关卡数据，优先于运行时生成使用。
static func load_locked_map(level_id: String) -> Dictionary:
	if level_id == "":
		return {"ok": false, "error": "empty level_id"}
	var path := LOCKED_MAPS_DIR + level_id + ".json"
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "file not found: " + path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "cannot open: " + path}
	var text := file.get_as_text()
	file.close()
	var test_json := JSON.new()
	var err := test_json.parse(text)
	if err != OK:
		return {"ok": false, "error": "JSON parse failed: %s (line %d)" % [test_json.get_error_message(), test_json.get_error_line()]}
	var raw = test_json.data
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "root is not an object"}
	# 规范化字段，补全运行时所需结构
	var normalized := _normalize_locked_map(raw, level_id)
	var validation := LockedMapValidator.validate(normalized)
	if not bool(validation.get("valid", true)):
		push_warning("Locked map validation errors for %s: %s" % [level_id, str(validation.get("errors", []))])
	return {"ok": true, "data": normalized}

## 将服务端锁定地图格式归一化为客户端运行时使用的 map_data 结构。
## CODE-CH1-020: 同时支持 schema_version=1 和 =2 的输入。
## - v1 输入：从 objects/nodes 派生 entities/network_nodes，并补全 encounters/checkpoints 为空数组。
## - v2 输入：直接使用 entities/network_nodes，同时保留 objects/nodes 别名供旧代码读取。
## 归一化后所有 v2 字段都存在，schema_version 保持输入值（v1 仍为 1，由 validator 决定是否宽松校验）。
static func _normalize_locked_map(raw: Dictionary, level_id: String) -> Dictionary:
	var layers = raw.get("layers", {})
	# 确保三层都存在，缺失时用空数组占位（上层调用方应自行处理尺寸）
	if not layers.has("base_terrain"):
		layers["base_terrain"] = []
	if not layers.has("blocker"):
		layers["blocker"] = []
	if not layers.has("height"):
		layers["height"] = layers.get("height", [])

	var size_dict = raw.get("size", {"width": 10, "height": 8})
	# size 可能是 {"width":..,"height":..}，也可能是字符串
	var w = 10
	var h = 8
	if typeof(size_dict) == TYPE_DICTIONARY:
		w = int(size_dict.get("width", 10))
		h = int(size_dict.get("height", 8))

	var schema_ver := int(raw.get("schema_version", 1))
	# v2 字段：优先使用新名称；若新名称为空且旧名称存在，则从旧名称派生
	var entities: Array = raw.get("entities", [])
	var objects: Array = raw.get("objects", [])
	if entities.is_empty() and not objects.is_empty():
		entities = objects.duplicate(true)
	elif objects.is_empty() and not entities.is_empty():
		# v2 优先：旧代码读取 objects 时也能拿到数据
		objects = entities.duplicate(true)

	var network_nodes: Array = raw.get("network_nodes", [])
	var nodes: Array = raw.get("nodes", [])
	if network_nodes.is_empty() and not nodes.is_empty():
		network_nodes = nodes.duplicate(true)
	elif nodes.is_empty() and not network_nodes.is_empty():
		nodes = network_nodes.duplicate(true)

	# v2 专属字段：encounters / checkpoints / mission_id
	# v1 输入无这些字段时，补全为空数组/默认 mission_id
	var encounters: Array = raw.get("encounters", [])
	var checkpoints: Array = raw.get("checkpoints", [])
	var mission_id: String = String(raw.get("mission_id", level_id))

	var result := {
		"map_id": raw.get("map_id", level_id),
		"level_id": level_id,
		"mission_id": mission_id,
		"seed": int(raw.get("seed", 0)),
		"size": {"width": w, "height": h},
		"theme": raw.get("theme", "warehouse"),
		"mission_type": raw.get("mission_type", "extract"),
		"difficulty": int(raw.get("difficulty", 1)),
		"layers": layers,
		# v1 别名（保留供旧代码读取）
		"objects": objects,
		"nodes": nodes,
		# v2 规范名称
		"entities": entities,
		"network_nodes": network_nodes,
		"facilities": raw.get("facilities", []),
		"connections": raw.get("connections", []),
		"encounters": encounters,
		"checkpoints": checkpoints,
		"scripts": raw.get("scripts", []),
		"victory": raw.get("victory", {}),
		"environment": raw.get("environment", {}),
		"mission_flow": raw.get("mission_flow", {}),
		"schema_version": schema_ver,
	}
	return result

## CODE-CH1-020: 将 v1 锁定地图迁移为 v2 模式。
## 用于在加载阶段把 v1 文件提升为 v2，使运行时只需要处理一种数据形状。
## 返回的字典 schema_version=2，entities/network_nodes/encounters/checkpoints 已填充。
## 如果输入已经是 v2，原样返回（深拷贝）。
static func migrate_to_v2(map_data: Dictionary) -> Dictionary:
	var schema_ver := int(map_data.get("schema_version", 1))
	if schema_ver >= 2:
		return map_data.duplicate(true)
	var result := map_data.duplicate(true)
	# 从 v1 别名派生 v2 字段
	if result.get("entities", []).is_empty():
		result["entities"] = (result.get("objects", []) as Array).duplicate(true)
	if result.get("network_nodes", []).is_empty():
		result["network_nodes"] = (result.get("nodes", []) as Array).duplicate(true)
	if not result.has("mission_id") or String(result.get("mission_id", "")) == "":
		var mid: String = String(result.get("level_id", ""))
		if mid == "":
			mid = String(result.get("map_id", ""))
		result["mission_id"] = mid
	if not result.has("encounters"):
		result["encounters"] = []
	if not result.has("checkpoints"):
		result["checkpoints"] = []
	result["schema_version"] = 2
	return result

## 从 JSON 字典加载地图数据（保留旧接口供测试和工具使用）。
static func load_from_dict(data: Dictionary) -> Dictionary:
	var map_data = data.get("map_data", data)

	var result = {
		"map_id": map_data.get("map_id", ""),
		"seed": map_data.get("seed", 0),
		"size": map_data.get("size", {"width": 10, "height": 8}),
		"theme": map_data.get("theme", "warehouse"),
		"mission_type": map_data.get("mission_type", "extract"),
		"layers": map_data.get("layers", {}),
		"objects": map_data.get("objects", []),
		"scripts": map_data.get("scripts", []),
		"victory": map_data.get("victory", {}),
		"environment": map_data.get("environment", {}),
		"mission_flow": map_data.get("mission_flow", {}),
	}

	return result

## 获取地形类型
static func get_terrain_at(map_data: Dictionary, x: int, y: int) -> int:
	var layers = map_data.get("layers", {})
	var base = layers.get("base_terrain", [])
	if y < 0 or y >= base.size():
		return -1
	if x < 0 or x >= base[y].size():
		return -1
	return base[y][x]

## 获取阻挡类型
static func get_blocker_at(map_data: Dictionary, x: int, y: int) -> int:
	var layers = map_data.get("layers", {})
	var blocker = layers.get("blocker", [])
	if y < 0 or y >= blocker.size():
		return 0
	if x < 0 or x >= blocker[y].size():
		return 0
	return blocker[y][x]

## 获取高度
static func get_height_at(map_data: Dictionary, x: int, y: int) -> int:
	var layers = map_data.get("layers", {})
	var height = layers.get("height", [])
	if y < 0 or y >= height.size():
		return 0
	if x < 0 or x >= height[y].size():
		return 0
	return height[y][x]

## 检查格子是否可通行
static func is_passable(map_data: Dictionary, x: int, y: int) -> bool:
	var terrain = get_terrain_at(map_data, x, y)
	var blocker = get_blocker_at(map_data, x, y)

	# 水域不可通行
	if terrain == 5:
		return false
	# 墙体不可通行
	if blocker == 6:
		return false
	# 箱子不可通行
	if blocker == 7:
		return false
	return true

## 获取玩家出生点
static func get_player_spawns(map_data: Dictionary) -> Array:
	return map_data.get("objects", []).filter(func(o): return o.type == "spawn_player")

## 获取敌人出生点
static func get_enemy_spawns(map_data: Dictionary) -> Array:
	return map_data.get("objects", []).filter(func(o): return o.type == "spawn_enemy")

## 获取所有交互点
static func get_interactables(map_data: Dictionary) -> Array:
	return map_data.get("objects", []).filter(func(o):
		return o.type in ["terminal", "evac", "resource", "destructible_target", "alarm_panel", "npc"]
	)
