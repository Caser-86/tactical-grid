## 敌人 Director
## 负责增援节奏和局面修正，不直接改命中率或血量
extends Node
class_name EnemyDirector

signal reinforcement_spawned(unit: Node, pos: Vector2i)

var turn_count: int = 0
var reinforcement_triggers: Array = []
var pressure_level: float = 0.0  # 0-1，玩家优势度
var player_losses_this_battle: int = 0
var enemy_losses_this_battle: int = 0

## 初始化 Director
func setup(scripts: Array) -> void:
	turn_count = 0
	player_losses_this_battle = 0
	enemy_losses_this_battle = 0
	pressure_level = 0.5

	# 从地图脚本中提取增援触发器
	reinforcement_triggers.clear()
	for script in scripts:
		if script.get("action", "") == "spawn_reinforcement":
			var trigger_data = {
				"triggered": false,
				"trigger": script.get("trigger", {}),
				"data": script.get("data", {}),
			}
			reinforcement_triggers.append(trigger_data)

## 每回合更新
func on_turn_start(turn_number: int) -> void:
	turn_count = turn_number
	_evaluate_pressure()

	# 检查增援触发
	_check_reinforcements(turn_number)

## 评估当前压力
func _evaluate_pressure() -> void:
	var alive_players = GameManager.player_units.filter(func(u): return u.is_alive).size()
	var alive_enemies = GameManager.enemy_units.filter(func(u): return u.is_alive).size()

	if alive_players == 0:
		pressure_level = 0.0
		return

	# 比例：敌人越多，压力越高
	var ratio = float(alive_enemies) / float(alive_players + alive_enemies)
	pressure_level = clampf(ratio, 0.0, 1.0)

## 检查增援
func _check_reinforcements(turn: int) -> void:
	for trigger in reinforcement_triggers:
		if trigger.triggered:
			continue

		var condition = trigger.trigger.get("condition", "")
		if _check_condition(condition, turn):
			trigger.triggered = true
			_spawn_reinforcement(trigger.data)

## 检查条件
func _check_condition(condition: String, turn: int) -> bool:
	if condition.begins_with(">="):
		var value = int(condition.substr(2).strip_edges())
		return turn >= value
	return false

## 生成增援
func _spawn_reinforcement(data: Dictionary) -> void:
	var units = data.get("units", [])
	var map_data = GameManager.current_map_data
	var width = map_data.get("size", {}).get("width", 10)
	var height = map_data.get("size", {}).get("height", 8)

	for unit_data in units:
		var enemy_type = unit_data.get("type", "sentry_basic")
		var pos = unit_data.get("position", [0, 0])

		# 如果位置是 [0,0]（默认），随机选取一个远离玩家的位置
		var spawn_pos = Vector2i(pos[0], pos[1])
		if spawn_pos == Vector2i(0, 0):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var best_pos = Vector2i(0, 0)
			var best_dist = 0
			for attempt in range(20):
				var rx = rng.randi_range(0, width - 1)
				var ry = rng.randi_range(0, height / 2)
				if not MapLoader.is_passable(map_data, rx, ry):
					continue
				var min_dist = 999
				for p in GameManager.player_units:
					if p.is_alive:
						var d = GridSystem.manhattan_distance(Vector2i(rx, ry), p.grid_pos)
						min_dist = mini(min_dist, d)
				if min_dist > best_dist:
					best_dist = min_dist
					best_pos = Vector2i(rx, ry)
			spawn_pos = best_pos

		# 创建敌人单位
		var unit = GameData.create_enemy_unit(enemy_type)
		unit.grid_pos = spawn_pos
		GameManager.enemy_units.append(unit)
		reinforcement_spawned.emit(unit, spawn_pos)

		# 通知消息
		var msg = data.get("message", "敌方增援已到达！")
		print("Director: ", msg)

## 记录玩家损失
func on_player_loss() -> void:
	player_losses_this_battle += 1
	# 玩家损失后，稍微延迟增援
	pressure_level = minf(pressure_level + 0.1, 1.0)

## 记录敌人损失
func on_enemy_loss() -> void:
	enemy_losses_this_battle += 1
	pressure_level = maxf(pressure_level - 0.1, 0.0)

## 获取建议的敌人攻击性（0-1）
func get_aggression() -> float:
	# 压力高时敌人更保守（防守），压力低时更激进
	return 1.0 - pressure_level

## 是否应该触发额外增援（玩家优势太大时）
func should_add_pressure() -> bool:
	return pressure_level < 0.3 and turn_count > 3
