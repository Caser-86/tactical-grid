## A* 寻路算法
## 用于计算单位移动路径和可达范围
class_name Pathfinding

## 地形通行成本函数类型
## 返回 -1 表示不可通行，正数表示移动成本
## 由调用方提供具体实现

## A* 寻路，返回路径数组（不含起点）
static func find_path(
	start: Vector2i,
	end: Vector2i,
	width: int,
	height: int,
	move_cost_fn: Callable,
	blocked_check: Callable
) -> Array[Vector2i]:
	if start == end:
		return []

	var open_set: Array[Dictionary] = []
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	g_score[start] = 0
	f_score[start] = manhattan(start, end)
	open_set.append({pos = start, f = f_score[start]})

	while open_set.size() > 0:
		# 找 f_score 最小的
		open_set.sort_custom(func(a, b): return a.f < b.f)
		var current = open_set.pop_front().pos

		if current == end:
			return reconstruct_path(came_from, current)

		for neighbor in GridSystem.get_neighbors(current):
			if not GridSystem.is_in_bounds(neighbor, width, height):
				continue
			if blocked_check.call(neighbor):
				continue

			var cost = move_cost_fn.call(neighbor)
			if cost < 0:
				continue

			var tentative_g = g_score[current] + cost
			var neighbor_key = neighbor
			if not g_score.has(neighbor_key) or tentative_g < g_score[neighbor_key]:
				came_from[neighbor_key] = current
				g_score[neighbor_key] = tentative_g
				f_score[neighbor_key] = tentative_g + manhattan(neighbor, end)

				# 检查是否已在 open_set
				var in_open = false
				for item in open_set:
					if item.pos == neighbor:
						item.f = f_score[neighbor_key]
						in_open = true
						break
				if not in_open:
					open_set.append({pos = neighbor, f = f_score[neighbor_key]})

	return []  # 不可达

## 重建路径
static func reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	# 去掉起点
	if path.size() > 0:
		path.pop_front()
	return path

## 获取所有可达格子及其成本
## 返回 Dictionary: Vector2i -> int (成本)
static func get_reachable_cells(
	start: Vector2i,
	move_points: int,
	width: int,
	height: int,
	move_cost_fn: Callable,
	blocked_check: Callable
) -> Dictionary:
	var distances: Dictionary = {}
	var queue: Array[Dictionary] = [{pos = start, cost = 0}]
	distances[start] = 0

	while queue.size() > 0:
		queue.sort_custom(func(a, b): return a.cost < b.cost)
		var current = queue.pop_front()

		if current.cost > move_points:
			continue

		for neighbor in GridSystem.get_neighbors(current.pos):
			if not GridSystem.is_in_bounds(neighbor, width, height):
				continue
			if blocked_check.call(neighbor):
				continue

			var cost = move_cost_fn.call(neighbor)
			if cost < 0:
				continue

			var new_cost = current.cost + cost
			if not distances.has(neighbor) or new_cost < distances[neighbor]:
				distances[neighbor] = new_cost
				if new_cost <= move_points:
					queue.append({pos = neighbor, cost = new_cost})

	return distances

## 曼哈顿距离
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return GridSystem.manhattan_distance(a, b)
