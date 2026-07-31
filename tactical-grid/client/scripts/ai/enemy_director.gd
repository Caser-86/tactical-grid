## 敌人 Director
## 负责增援节奏和局面修正，不直接改命中率或血量
extends Node
class_name EnemyDirector

## 增援生成请求信号：参数为单位数据数组 [{type, position}, ...] 和提示消息
signal reinforcement_spawned(units_data: Array, message: String)
## 玩家增援生成请求信号：参数同上，但不占用敌人增援上限
signal player_reinforcement_spawned(units_data: Array, message: String)

var turn_count: int = 0
var reinforcement_triggers: Array[Dictionary] = []
var pressure_level: float = 0.0  # 0-1，玩家优势度
var player_losses_this_battle: int = 0
var enemy_losses_this_battle: int = 0
## 已生成增援总数（用于上限控制）
var reinforcements_spawned: int = 0
## 增援上限（防止无限生成，由 BattleController 根据关卡配置设置）
var max_reinforcements: int = 20
## 存活敌人数量（由 BattleController 每回合更新，用于上限控制）
var alive_enemy_count: int = 0
## 单次增援后场上敌人上限（防止一次刷出过多）
var enemy_cap_per_wave: int = 12

## 初始化 Director
func setup(scripts: Array) -> void:
	turn_count = 0
	player_losses_this_battle = 0
	enemy_losses_this_battle = 0
	pressure_level = 0.5
	reinforcements_spawned = 0

	# 从地图脚本中提取增援触发器
	reinforcement_triggers.clear()
	for script in scripts:
		var action_type = String(script.get("action", ""))
		if action_type == "spawn_reinforcement" or action_type == "spawn_player":
			# 标记触发状态，避免重复触发
			var entry = script.duplicate(true)
			entry["triggered"] = false
			reinforcement_triggers.append(entry)

## 每回合更新：评估压力并检查增援触发
## 返回本次触发的增援列表（可能为空）
func on_turn_start(turn_number: int) -> Array:
	turn_count = turn_number
	_evaluate_pressure()
	return _evaluate_triggers(turn_number, &"")

## 评估当前压力
func _evaluate_pressure() -> void:
	# pressure_level 由 BattleController 通过 set_alive_counts 更新
	# 这里做兜底：若无外部更新则保持当前值
	pass

## 设置存活单位数量（由 BattleController 每回合调用）
func set_alive_counts(alive_players: int, alive_enemies: int) -> void:
	if alive_players == 0:
		pressure_level = 0.0
		return
	var ratio = float(alive_enemies) / float(alive_players + alive_enemies)
	pressure_level = clampf(ratio, 0.0, 1.0)
	alive_enemy_count = alive_enemies

## 触发器匹配：兼容回合触发和事件触发
func _trigger_matches(entry: Dictionary, turn: int, event_name: StringName) -> bool:
	var trigger: Dictionary = entry.get("trigger", {})
	match String(trigger.get("type", "turn")):
		"event":
			return StringName(trigger.get("name", "")) == event_name
		_:
			# 回合型触发器只在事件名为空（回合评估）时匹配
			return event_name.is_empty() and _check_condition(String(trigger.get("condition", "")), turn)

## 统一评估增援触发器：回合触发和事件触发共用同一套上限/重复/信号逻辑
## spawn_player 动作不占用敌人增援上限和场上敌人数量限制
## CODE-CH1-020: 把 trigger_id 注入每个 unit_data，使 BattleController 能派生稳定 entity_id。
func _evaluate_triggers(turn: int, event_name: StringName) -> Array:
	var spawned: Array = []
	for trigger in reinforcement_triggers:
		if trigger.get("triggered", false):
			continue
		# 重复触发型触发器不标记 triggered
		var is_repeat = trigger.get("repeat", false)
		if not _trigger_matches(trigger, turn, event_name):
			continue
		var data = trigger.get("data", {})
		var raw_units = data.get("units", [])
		var msg = data.get("message", "")
		var trig_id: String = String(trigger.get("trigger_id", ""))
		# 给每个 unit_data 注入 trigger_id（若未显式提供 id），便于 BattleController 派生稳定身份
		var units_data: Array = []
		for ud in raw_units:
			var copy = ud.duplicate(true) if ud is Dictionary else ud
			if copy is Dictionary and not copy.has("trigger_id"):
				copy["trigger_id"] = trig_id
			units_data.append(copy)
		var action: String = String(trigger.get("action", "spawn_reinforcement"))
		if action == "spawn_player":
			# 玩家增援不占用敌人上限
			if not is_repeat:
				trigger["triggered"] = true
			spawned.append({"units": units_data, "message": msg})
			player_reinforcement_spawned.emit(units_data, msg)
			continue
		# 敌人增援：检查上限
		if reinforcements_spawned >= max_reinforcements:
			break
		var would_exceed = (alive_enemy_count + units_data.size()) > enemy_cap_per_wave
		if would_exceed:
			# 非重复触发器保留以便下回合再试
			if not is_repeat:
				pass
			continue
		# 标记触发（重复型不标记）
		if not is_repeat:
			trigger["triggered"] = true
		# 累计已生成数量
		reinforcements_spawned += units_data.size()
		spawned.append({"units": units_data, "message": msg})
		# 发送信号通知 BattleController 实际生成单位
		reinforcement_spawned.emit(units_data, msg)
	return spawned

## 事件触发：由 BattleController 在收到 mission_event 时调用
func on_event(event_name: StringName) -> Array:
	return _evaluate_triggers(turn_count, event_name)

## 检查条件（支持 ">= N"、"<N"、"==N"）
func _check_condition(condition: String, turn: int) -> bool:
	condition = condition.strip_edges()
	if condition.begins_with(">="):
		var value = int(condition.substr(2).strip_edges())
		return turn >= value
	if condition.begins_with("<="):
		var value = int(condition.substr(2).strip_edges())
		return turn <= value
	if condition.begins_with("=="):
		var value = int(condition.substr(2).strip_edges())
		return turn == value
	if condition.begins_with("<"):
		var value = int(condition.substr(1).strip_edges())
		return turn < value
	if condition.begins_with(">"):
		var value = int(condition.substr(1).strip_edges())
		return turn > value
	return false

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
