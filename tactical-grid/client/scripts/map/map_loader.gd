## 地图加载器
## 从后端 API 或本地 JSON 加载地图数据
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
	return {"ok": true, "data": normalized}

## 将服务端锁定地图格式归一化为客户端运行时使用的 map_data 结构。
## 服务端地图包含 vision/validation/victory(s) 等额外字段，这里只保留运行时需要的部分。
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

	var result := {
		"map_id": raw.get("map_id", level_id),
		"level_id": level_id,
		"seed": int(raw.get("seed", 0)),
		"size": {"width": w, "height": h},
		"theme": raw.get("theme", "warehouse"),
		"mission_type": raw.get("mission_type", "extract"),
		"difficulty": int(raw.get("difficulty", 1)),
		"layers": layers,
		"objects": raw.get("objects", []),
		"scripts": raw.get("scripts", []),
		"victory": raw.get("victory", {}),
	}
	return result

## 从 JSON 字典加载地图数据（保留旧接口，兼容测试和 API 返回数据）
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
