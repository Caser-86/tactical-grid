## 敌人 Director
## 负责增援节奏和局面修正，不直接改命中率或血量
extends Node
class_name EnemyDirector

var turn_count: int = 0
var reinforcement_triggers: Array[Dictionary] = []
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
		if script.action == "spawn_reinforcement":
			reinforcement_triggers.append(script)

## 每回合更新
func on_turn_start(turn_number: int) -> void:
	turn_count = turn_number
	_evaluate_pressure()

	# 检查增援触发
	_check_reinforcements(turn_number)

## 评估当前压力
func _evaluate_pressure() -> void:
	var player_units = get_tree().get_nodes_in_group("player_units")
	var enemy_units = get_tree().get_nodes_in_group("enemy_units")

	var alive_players = player_units.filter(func(u): return u.is_alive).size()
	var alive_enemies = enemy_units.filter(func(u): return u.is_alive).size()

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
	# 通知游戏管理器生成增援
	var units = data.get("units", [])
	for unit_data in units:
		# TODO: 实际生成敌人单位
		print("Director: Spawning reinforcement: ", unit_data)

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
