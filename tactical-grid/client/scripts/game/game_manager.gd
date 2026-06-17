## 游戏管理器（单例）
## 全局游戏状态管理
extends Node

var current_map_data: Dictionary = {}
var player_units: Array = []
var enemy_units: Array = []
var turn_manager: Node  # TurnManager
var enemy_director: Node  # EnemyDirector
var selected_unit: Node = null  # Unit
var current_level_id: String = ""
var api: Node  # ApiClient
var save_manager: Node  # SaveManager 引用（避免类型解析问题）

# API 配置
var api_base_url: String = "http://localhost:3001/api"
var auth_token: String = ""

# 存档数据
var save_data: Dictionary = {}

func _ready() -> void:
	# 初始化子系统
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)

	enemy_director = EnemyDirector.new()
	add_child(enemy_director)

	api = ApiClient.new()
	add_child(api)

	save_manager = Node.new()  # 占位（实际用全局 SaveManager）

	# 加载默认存档（使用全局 SaveManager 单例）
	if Engine.has_singleton("SaveManager") or has_node("/root/SaveManager"):
		save_data = SaveManager.create_default_save()

## 加载关卡
func load_level(level_id: String) -> void:
	current_level_id = level_id
	_load_level_from_api(level_id)

## 从 API 加载关卡
func _load_level_from_api(level_id: String) -> void:
	if auth_token == "":
		var login_result = await api.guest_login()
		if login_result.code == 0:
			auth_token = login_result.data.token
			api.set_token(auth_token)

	var result = await api.get_level(level_id)
	if result.code == 0:
		current_map_data = MapLoader.load_from_dict(result.data)
		_setup_battle()

## 设置战斗
func _setup_battle() -> void:
	_spawn_units()

	# 初始化 Director
	var scripts = current_map_data.get("scripts", [])
	enemy_director.setup(scripts)

	# 开始战斗
	turn_manager.start_battle()

## 生成单位
func _spawn_units() -> void:
	player_units.clear()
	enemy_units.clear()

	var player_spawns = MapLoader.get_player_spawns(current_map_data)
	var enemy_spawns = MapLoader.get_enemy_spawns(current_map_data)

	# 生成玩家单位（默认 4 个突击兵，后续从存档读取）
	var jobs = ["assault", "sniper", "medic", "scout"]
	for i in range(player_spawns.size()):
		var spawn = player_spawns[i]
		var job = jobs[i % jobs.size()]
		var unit = GameData.create_player_unit(job, "玩家" + str(i + 1))
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		player_units.append(unit)

	# 生成敌人单位
	for spawn in enemy_spawns:
		var enemy_type = spawn.get("job", "sentry_basic")
		var unit = GameData.create_enemy_unit(enemy_type)
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		enemy_units.append(unit)

## 选中单位
func select_unit(unit) -> void:
	selected_unit = unit

## 取消选中
func deselect_unit() -> void:
	selected_unit = null

## 回合阶段变化
func _on_turn_phase_changed(phase) -> void:
	match phase:
		3:  # TurnManager.TurnPhase.ENEMY_START
			enemy_director.on_turn_start(turn_manager.turn_number)
		4:  # TurnManager.TurnPhase.ENEMY_ACTION
			_execute_enemy_turn()

## 执行敌人回合
func _execute_enemy_turn() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for enemy in enemy_units:
		if not enemy.is_alive:
			continue

		# 用 AI 执行行动
		var actions = EnemyTemplates.execute_turn(
			enemy, player_units, current_map_data, enemy_units, enemy_director, rng
		)

		# 检查战斗是否结束
		if _check_victory():
			return

		# 短暂延迟，让玩家看清楚
		await get_tree().create_timer(0.5).timeout

	# 结束敌人回合
	turn_manager.end_enemy_turn()

## 检查胜负
func _check_victory() -> bool:
	# 检查是否全灭
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.size() == 0:
		_on_defeat()
		return true

	var alive_enemies = enemy_units.filter(func(u): return u.is_alive)
	# 如果任务类型是 destroy 且所有目标已摧毁
	# TODO: 根据胜利条件检查
	return false

## 胜利
func _on_victory() -> void:
	print("Victory!")
	# 上报结果
	var result_data = {
		"result": "victory",
		"turns": turn_manager.turn_number,
		"units_survived": player_units.filter(func(u): return u.is_alive).size(),
		"units_total": player_units.size(),
		"zero_casualty": player_units.all(func(u): return u.is_alive)
	}
	_report_mission_result(result_data)

## 失败
func _on_defeat() -> void:
	print("Defeat!")
	var result_data = {
		"result": "defeat",
		"turns": turn_manager.turn_number,
		"units_survived": 0,
		"units_total": player_units.size(),
		"zero_casualty": false,
	}
	_report_mission_result(result_data)

## 上报关卡结果
func _report_mission_result(result: Dictionary) -> void:
	result["level_id"] = current_level_id
	result["seed"] = current_map_data.get("seed", 0)
	var api_result = await api.complete_level(current_level_id, result)

	if api_result.code == 0:
		print("Mission result reported. Stars: ", api_result.data.stars)
		# TODO: 显示结算界面
