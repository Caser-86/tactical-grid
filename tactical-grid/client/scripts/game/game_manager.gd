## 娓告垙绠＄悊鍣紙鍗曚緥锛?## 鍏ㄥ眬娓告垙鐘舵€佺鐞?extends Node

extends Node
var current_map_data: Dictionary = {}
var player_units: Array = []
var enemy_units: Array = []
var turn_manager: Node  # TurnManager
var enemy_director: Node  # EnemyDirector
var selected_unit: Node = null  # Unit
var current_level_id: String = ""
var api: Node  # ApiClient

# API 閰嶇疆
var api_base_url: String = "http://localhost:3000/api"
var auth_token: String = ""

var local_mode: bool = true
# 鏈湴妯″紡锛堜笉闇€瑕佸悗绔湇鍔″櫒锛?var local_mode: bool = true

# 瀛樻。鏁版嵁
var save_data: Dictionary = {}

func _ready() -> void:
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	if not turn_manager.player_turn_started.is_connected(_on_player_turn_started):
		turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)

	enemy_director = EnemyDirector.new()
	add_child(enemy_director)

	if not local_mode:
		api = ApiClient.new()
		add_child(api)

	save_data = SaveManager.create_default_save()

func load_level(level_id: String) -> void:
	current_level_id = level_id
	if local_mode:
		_load_local_level(level_id)
	else:
		_load_level_from_api(level_id)

func _load_local_level(level_id: String) -> void:
	var levels = LocalMapData.get_all_levels()
	for level in levels:
		if level.id == level_id:
			current_map_data = MapLoader.load_from_dict(level)
			_setup_battle()
			return

	current_map_data = MapLoader.load_from_dict(LocalMapData.get_test_level())
	_setup_battle()

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

func _setup_battle() -> void:
	_spawn_units()

	var scripts = current_map_data.get("scripts", [])
	enemy_director.setup(scripts)

	turn_manager.start_battle()

func _spawn_units() -> void:
	player_units.clear()
	enemy_units.clear()

	var player_spawns = MapLoader.get_player_spawns(current_map_data)
	var enemy_spawns = MapLoader.get_enemy_spawns(current_map_data)

	var jobs = ["assault", "sniper", "medic", "scout"]
	for i in range(player_spawns.size()):
		var spawn = player_spawns[i]
		var job = jobs[i % jobs.size()]
		var unit = GameData.create_player_unit(job, "鐜╁" + str(i + 1))
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		player_units.append(unit)

	for spawn in enemy_spawns:
		var enemy_type = spawn.get("job", "sentry_basic")
		var unit = GameData.create_enemy_unit(enemy_type)
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		enemy_units.append(unit)

func select_unit(unit) -> void:
	selected_unit = unit

func deselect_unit() -> void:
	selected_unit = null

func _on_turn_phase_changed(phase) -> void:
	match phase:
		TurnManager.TurnPhase.ENEMY_START:
			enemy_director.on_turn_start(turn_manager.turn_number)
		TurnManager.TurnPhase.ENEMY_ACTION:
			_execute_enemy_turn()

func _on_player_turn_started() -> void:
	for unit in player_units:
		if unit.is_alive and unit.has_method("on_turn_start"):
			unit.on_turn_start()
		_apply_player_passives(unit)

func _apply_player_passives(unit: Node) -> void:
	if not unit or not unit.is_alive:
		return
	if unit.job == "medic":
		_apply_medic_triage(unit)

func _apply_medic_triage(medic: Node) -> void:
	var best_target: Node = null
	var best_missing := 0
	for ally in player_units:
		if not ally.is_alive or ally == medic:
			continue
		var missing = ally.max_hp - ally.current_hp
		if missing > best_missing:
			best_missing = missing
			best_target = ally
	if best_target and best_missing > 0:
		best_target.heal(15)
		best_target.add_status("barrier", 2, {amount = 10})

func _execute_enemy_turn() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for enemy in enemy_units:
		if not enemy.is_alive:
			continue

		var actions = EnemyTemplates.execute_turn(
			enemy, player_units, current_map_data, enemy_units, enemy_director, rng
		)

		if _check_victory():
			return

		await get_tree().create_timer(0.5).timeout

	turn_manager.end_enemy_turn()

func _check_victory() -> bool:
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.size() == 0:
		_on_defeat()
		return true

	var mission_type = current_map_data.get("mission_type", "extract")
	var alive_enemies = enemy_units.filter(func(u): return u.is_alive)

	match mission_type:
		"destroy":
			var targets = current_map_data.get("objects", []).filter(func(o):
				return o.get("type") == "destructible_target"
			)
			var all_destroyed = targets.all(func(t):
				return t.get("hp", 0) <= 0
			)
			if all_destroyed and targets.size() > 0:
				_on_victory()
				return true
		"assassinate":
			if alive_enemies.size() == 0:
				_on_victory()
				return true
		"defend":
			if turn_manager.turn_number >= turn_manager.max_turns:
				_on_victory()
				return true
		"extract", "escort":
			if alive_enemies.size() == 0:
				_on_victory()
				return true
		_:
			if alive_enemies.size() == 0:
				_on_victory()
				return true

	if turn_manager.turn_number >= turn_manager.max_turns:
		_on_defeat()
		return true

	return false

func _on_victory() -> void:
	print("Victory!")
	AudioManager.sfx_victory()
	var result_data = {
		"result": "victory",
		"turns": turn_manager.turn_number,
		"units_survived": player_units.filter(func(u): return u.is_alive).size(),
		"units_total": player_units.size(),
		"zero_casualty": player_units.all(func(u): return u.is_alive)
	}
	_report_mission_result(result_data)

func _on_defeat() -> void:
	print("Defeat!")
	AudioManager.sfx_defeat()
	var result_data = {
		"result": "defeat",
		"turns": turn_manager.turn_number,
		"units_survived": 0,
		"units_total": player_units.size(),
		"zero_casualty": false,
	}
	_report_mission_result(result_data)

func _report_mission_result(result: Dictionary) -> void:
	result["level_id"] = current_level_id
	result["seed"] = current_map_data.get("seed", 0)

	if not local_mode:
		var api_result = await api.complete_level(current_level_id, result)
		if api_result.code == 0:
			result["stars"] = api_result.data.get("stars", 0)
			result["rewards"] = api_result.data.get("rewards", {})
			result["first_clear"] = api_result.data.get("first_clear", false)
	else:
		var is_victory = result.get("result") == "victory"
		result["stars"] = 3 if is_victory else 0
		result["rewards"] = {"credit": 100 if is_victory else 0, "exp": 50 if is_victory else 0}
		result["first_clear"] = false

	save_data.playtime_seconds = save_data.get("playtime_seconds", 0) + result.get("playtime_seconds", 0)
	SaveManager.auto_save(save_data)

	var result_scene = load("res://scenes/mission_result.tscn")
	if result_scene:
		var result_ui = result_scene.instantiate()
		get_tree().current_scene.add_child(result_ui)
		result_ui.show_result(result)
	else:
		_show_simple_result(result)

func _show_simple_result(result: Dictionary) -> void:
	var is_victory = result.get("result", "defeat") == "victory"
	var msg = "胜利！" if is_victory else "失败..."
	msg += "\n鍥炲悎: %d" % result.get("turns", 0)
	msg += "\n鏄熺骇: %d" % result.get("stars", 0)
	var rewards = result.get("rewards", {})
	if rewards.size() > 0:
		msg += "\n濂栧姳: %d淇＄敤 %d缁忛獙" % [rewards.get("credit", 0), rewards.get("exp", 0)]
	print(msg)
	get_tree().change_scene_to_file("res://scenes/base.tscn")

