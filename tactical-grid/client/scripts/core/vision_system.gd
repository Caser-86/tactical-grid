## 视线计算系统
## 使用 Bresenham 算法判断两个格子之间是否有视线
extends RefCounted
class_name VisionSystem

## 检查 from 到 to 之间是否有视线（无硬阻挡）
static func has_line_of_sight(
	from: Vector2i,
	to: Vector2i,
	width: int,
	height: int,
	is_blocking_fn: Callable
) -> bool:
	var points = bresenham_line(from, to)
	# 检查路径上是否有阻挡（不含起点和终点）
	for i in range(1, points.size() - 1):
		if is_blocking_fn.call(points[i]):
			return false
	return true

## Bresenham 直线算法
static func bresenham_line(start: Vector2i, end: Vector2i) -> Array:
	var points: Array = []
	var x0 = start.x
	var y0 = start.y
	var x1 = end.x
	var y1 = end.y

	var dx = absi(x1 - x0)
	var dy = absi(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

	return points

## 获取所有可见格子
static func get_visible_cells(
	origin: Vector2i,
	vision_range: int,
	width: int,
	height: int,
	is_blocking_fn: Callable
) -> Array:
	var visible: Array = []

	for y in range(maxi(0, origin.y - vision_range), mini(height, origin.y + vision_range + 1)):
		for x in range(maxi(0, origin.x - vision_range), mini(width, origin.x + vision_range + 1)):
			var pos = Vector2i(x, y)
			if GridSystem.manhattan_distance(origin, pos) > vision_range:
				continue
			if has_line_of_sight(origin, pos, width, height, is_blocking_fn):
				visible.append(pos)

	return visible

## 计算掩体类型
## 返回 "none", "half", "full"
static func calculate_cover(
	target: Vector2i,
	attacker: Vector2i,
	get_terrain_fn: Callable
) -> String:
	# 检查目标周围四个方向中，面向攻击者方向的格子
	var dx = attacker.x - target.x
	var dy = attacker.y - target.y

	# 确定主要方向
	var cover_pos: Vector2i
	if absi(dx) >= absi(dy):
		cover_pos = Vector2i(target.x + (1 if dx > 0 else -1), target.y)
	else:
		cover_pos = Vector2i(target.x, target.y + (1 if dy > 0 else -1))

	var terrain = get_terrain_fn.call(cover_pos)
	# 根据地形返回掩体类型
	match terrain:
		6:  # WALL
			return "full"
		7:  # CRATE
			return "half"
		2:  # FOREST
			return "half"
		_:
			return "none"
