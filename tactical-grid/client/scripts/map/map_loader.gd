## 地图加载器
## 从后端 API 或本地 JSON 加载地图数据
class_name MapLoader

## 从 JSON 字典加载地图数据
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
