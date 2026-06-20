## 游戏管理器（单例）
## 全局游戏状态管理
extends Node

signal boss_phase_changed(boss: Node, phase_name: String)
signal enemy_action_started(enemy: Node, action_type: String)
signal enemy_action_finished(enemy: Node)

var current_map_data: Dictionary = {}
var player_units: Array = []
var enemy_units: Array = []
var turn_manager: Node  # TurnManager
var enemy_director: Node  # EnemyDirector
var selected_unit: Node = null  # Unit
var current_level_id: String = ""
var api: Node  # ApiClient
var in_roguelike: bool = false

# API 配置
var api_base_url: String = "http://localhost:3000/api"
var auth_token: String = ""

# 本地模式（不需要后端服务器）
var local_mode: bool = true

# 存档数据
var save_data: Dictionary = {}

func _ready() -> void:
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	if not turn_manager.player_turn_started.is_connected(_on_player_turn_started):
		turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.turn_phase_changed.connect(_on_turn_phase_changed)
	if not turn_manager.turn_limit_reached.is_connected(_on_turn_limit_reached):
		turn_manager.turn_limit_reached.connect(_on_turn_limit_reached)

	enemy_director = EnemyDirector.new()
	add_child(enemy_director)

	if not local_mode:
		api = ApiClient.new()
		add_child(api)

	var latest_save = SaveManager.load_latest_save()
	if latest_save.size() > 0:
		save_data = latest_save
	else:
		save_data = SaveManager.create_default_save()
		SaveManager.auto_save(save_data)

	_setup_auto_save_timer()

func _setup_auto_save_timer() -> void:
	var timer = Timer.new()
	timer.name = "AutoSaveTimer"
	timer.wait_time = 300.0  # 5 分钟
	timer.autostart = true
	timer.timeout.connect(_on_auto_save_timeout)
	add_child(timer)

func _on_auto_save_timeout() -> void:
	if save_data.size() > 0:
		SaveManager.auto_save(save_data)
		print("Auto saved at ", Time.get_time_string_from_system())

func load_level(level_id: String) -> void:
	current_level_id = level_id
	if local_mode:
		_load_local_level(level_id)
	else:
		_load_level_from_api(level_id)

func _load_local_level(level_id: String) -> void:
	# 优先尝试 procedural generator
	var generated = ProceduralGenerator.generate_from_id(level_id)
	if not generated.is_empty():
		current_map_data = MapLoader.load_from_dict(generated)
		return

	# 回退到 LocalMapData 中的测试关卡
	var levels = LocalMapData.get_all_levels()
	for level in levels:
		if level.id == level_id:
			current_map_data = MapLoader.load_from_dict(level)
			return

	current_map_data = MapLoader.load_from_dict(LocalMapData.get_test_level())

func _load_level_from_api(level_id: String) -> void:
	if auth_token == "":
		var login_result = await api.guest_login()
		if login_result.get("code", -1) == 0:
			auth_token = login_result.get("data", {}).get("token", "")
			api.set_token(auth_token)

	var result = await api.get_level(level_id)
	if result.get("code", -1) == 0:
		current_map_data = MapLoader.load_from_dict(result.get("data", {}))

func _setup_battle() -> void:
	_battle_start_time = Time.get_unix_time_from_system()
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
		var unit = GameData.create_player_unit(job, "玩家" + str(i + 1))
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		player_units.append(unit)

	var is_boss_level = current_map_data.get("is_boss", false)
	var boss_id = current_map_data.get("boss_id", "")
	var mission_type = current_map_data.get("mission_type", "extract")
	var vip_spawn = null
	if mission_type == "escort":
		for obj in current_map_data.get("objects", []):
			if obj.get("type", "") == "npc" and obj.get("is_vip", false):
				vip_spawn = obj
				break

	for i in range(enemy_spawns.size()):
		var spawn = enemy_spawns[i]
		var enemy_type = spawn.get("job", "sentry_basic")
		if is_boss_level and boss_id != "" and i == 0:
			enemy_type = boss_id
		var unit = GameData.create_enemy_unit(enemy_type)
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		enemy_units.append(unit)
		if is_boss_level and i == 0:
			unit.unit_name = GameData.boss_data.get("bosses", {}).get(boss_id, {}).get("name", unit.unit_name)
			_setup_boss_phase(unit, boss_id)

	if vip_spawn:
		var npc = GameData.create_enemy_unit("npc_civilian")
		npc.grid_pos = Vector2i(vip_spawn.get("x", 0), vip_spawn.get("y", 0))
		npc.unit_name = vip_spawn.get("name", "VIP")
		npc.team = "neutral"
		npc.set_meta("is_vip", true)
		enemy_units.append(npc)

func select_unit(unit) -> void:
	selected_unit = unit

func deselect_unit() -> void:
	selected_unit = null

func _on_turn_phase_changed(phase) -> void:
	if phase == TurnManager.TurnPhase.ENEMY_START:
		enemy_director.on_turn_start(turn_manager.turn_number)
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
		best_target.add_status("barrier", 2, {"amount": 10})

func _execute_enemy_turn() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		# 先触发持续伤害（流血/燃烧/中毒）
		if enemy.has_method("on_turn_start"):
			enemy.on_turn_start()
		if not enemy.is_alive:
			# 持续伤害杀死敌人也更新目标
			_on_unit_killed_by_dot(enemy)
			continue

		enemy_action_started.emit(enemy, "start")
		var actions = EnemyTemplates.execute_turn(
			enemy, player_units, current_map_data, enemy_units, enemy_director, rng
		)
		enemy_action_finished.emit(enemy)

		if _check_victory():
			return

		await get_tree().create_timer(0.5).timeout

	turn_manager.end_enemy_turn()

func _on_unit_killed_by_dot(unit: Node) -> void:
	AudioManager.sfx_unit_down()
	# 通知场景查找并播放死亡动画
	var scene = get_tree().current_scene
	if scene and scene.has_method("_play_dot_death"):
		scene._play_dot_death(unit)
	_check_victory()

func _check_victory() -> bool:
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.size() == 0:
		_on_defeat()
		return true

	var mission_type = current_map_data.get("mission_type", "extract")
	var alive_enemies = enemy_units.filter(func(u): return u.is_alive)

	# 护送任务：VIP 死亡即失败
	if mission_type == "escort":
		var vip = _get_vip()
		if vip == null or not vip.is_alive:
			_on_defeat()
			return true
		if _check_vip_at_evac():
			_on_victory()
			return true

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
			var defend_turns = _get_defend_turns()
			if turn_manager.turn_number >= defend_turns:
				_on_victory()
				return true
		"extract", "infiltrate":
			if _check_all_players_at_evac():
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

func _check_all_players_at_evac() -> bool:
	var evac = current_map_data.get("evac_point", {})
	if evac.is_empty():
		return false
	var evac_pos = Vector2i(evac.get("x", -1), evac.get("y", -1))
	if evac_pos.x < 0:
		return false
	var alive_players = player_units.filter(func(u): return u.is_alive)
	if alive_players.is_empty():
		return false
	return alive_players.all(func(u): return u.grid_pos == evac_pos)

func _check_vip_at_evac() -> bool:
	var evac = current_map_data.get("evac_point", {})
	if evac.is_empty():
		return false
	var evac_pos = Vector2i(evac.get("x", -1), evac.get("y", -1))
	if evac_pos.x < 0:
		return false
	var vip = enemy_units.filter(func(u): return u.is_alive and u.has_meta("is_vip"))
	if vip.is_empty():
		return false
	return vip[0].grid_pos == evac_pos

func _get_vip() -> Node:
	var vips = enemy_units.filter(func(u): return u.is_alive and u.has_meta("is_vip"))
	if vips.is_empty():
		return null
	return vips[0]

func _get_defend_turns() -> int:
	var victory = current_map_data.get("victory", {})
	if victory.get("type", "") == "survive_turns" and victory.has("turns"):
		return int(victory.get("turns", 5))
	var special_rules = current_map_data.get("special_rules", [])
	for rule in special_rules:
		if rule is String and rule.begins_with("defend_"):
			var num = rule.replace("defend_", "")
			if num.is_valid_int():
				return num.to_int()
		if rule is String and rule.begins_with("survive_"):
			var parts = rule.split("_")
			if parts.size() >= 2 and parts[1].is_valid_int():
				return parts[1].to_int()
	return 5

func _on_victory() -> void:
	AudioManager.sfx_victory()
	var result_data = {
		"result": "victory",
		"turns": turn_manager.turn_number,
		"units_survived": player_units.filter(func(u): return u.is_alive).size(),
		"units_total": player_units.size(),
		"zero_casualty": player_units.all(func(u): return u.is_alive),
		"playtime_seconds": _get_battle_playtime()
	}
	_report_mission_result(result_data)

func _on_defeat() -> void:
	AudioManager.sfx_defeat()
	var result_data = {
		"result": "defeat",
		"turns": turn_manager.turn_number,
		"units_survived": 0,
		"units_total": player_units.size(),
		"zero_casualty": false,
		"playtime_seconds": _get_battle_playtime()
	}
	_report_mission_result(result_data)

func _on_turn_limit_reached() -> void:
	_on_defeat()


var _battle_start_time: int = 0

func _get_battle_playtime() -> int:
	return int(Time.get_unix_time_from_system() - _battle_start_time)

func _report_mission_result(result: Dictionary) -> void:
	result["level_id"] = current_level_id
	result["seed"] = current_map_data.get("seed", 0)

	if not local_mode:
		var api_result = await api.complete_level(current_level_id, result)
		if api_result.get("code", -1) == 0:
			var api_data = api_result.get("data", {})
			result["stars"] = api_data.get("stars", 0)
			result["rewards"] = api_data.get("rewards", {})
			result["first_clear"] = api_data.get("first_clear", false)
	else:
		var is_victory = result.get("result") == "victory"
		result["stars"] = _calculate_stars(is_victory)
		result["rewards"] = _calculate_rewards(is_victory, result.get("zero_casualty", false))
		result["first_clear"] = false

	save_data.playtime_seconds = save_data.get("playtime_seconds", 0) + result.get("playtime_seconds", 0)
	_apply_mission_rewards_to_save(result)
	_update_campaign_progress(result)
	SaveManager.auto_save(save_data)

	var result_scene = load("res://scenes/mission_result.tscn")
	if result_scene:
		var result_ui = result_scene.instantiate()
		get_tree().current_scene.add_child(result_ui)
		result_ui.show_result(result)
	else:
		_show_simple_result(result)

func _calculate_stars(is_victory: bool) -> int:
	if not is_victory:
		return 0
	var stars = 3
	if turn_manager.turn_number > 8:
		stars -= 1
	if player_units.any(func(u): return not u.is_alive):
		stars -= 1
	return maxi(stars, 1)

func _calculate_rewards(is_victory: bool, zero_casualty: bool) -> Dictionary:
	var base_credit = 100 if is_victory else 0
	var base_exp = 50 if is_victory else 0
	var boss_id = current_map_data.get("boss_id", "")
	if boss_id != "" and is_victory:
		var boss_rewards = GameData.boss_data.get("bosses", {}).get(boss_id, {}).get("rewards", {})
		base_credit += boss_rewards.get("credit", 0)
		base_exp += boss_rewards.get("exp", 0)
	if zero_casualty:
		base_credit = int(base_credit * 1.3)
		base_exp = int(base_exp * 1.3)
	return {"credit": base_credit, "exp": base_exp}

func _apply_mission_rewards_to_save(result: Dictionary) -> void:
	var rewards = result.get("rewards", {})
	var resources = save_data.get("resources", {})
	if not resources.has("materials") or resources["materials"] == null:
		resources["materials"] = {}
	resources["credit"] = resources.get("credit", 0) + rewards.get("credit", 0)
	resources["intel"] = resources.get("intel", 0) + rewards.get("intel", 0)
	var materials = rewards.get("materials", {})
	for mat_id in materials:
		resources["materials"][mat_id] = resources["materials"].get(mat_id, 0) + materials[mat_id]
	var loot = result.get("loot", [])
	var inventory = save_data.get("inventory", [])
	for item in loot:
		var existing = inventory.filter(func(i): return i.get("id", "") == item.get("id", ""))
		if existing.size() > 0 and item.get("stackable", true):
			existing[0]["count"] = existing[0].get("count", 0) + item.get("count", 1)
		else:
			inventory.append({
				"id": item.get("id", ""),
				"type": item.get("type", "consumable"),
				"count": item.get("count", 1)
			})
	var stats = save_data.get("stats_tracking", {})
	stats["total_missions"] = stats.get("total_missions", 0) + 1

func _update_campaign_progress(result: Dictionary) -> void:
	var is_victory = result.get("result", "") == "victory"
	var level_id = result.get("level_id", "")
	if level_id == "":
		return
	var campaign = save_data.get("campaign_progress", {})
	var completed = campaign.get("completed_missions", [])
	if is_victory and not completed.has(level_id):
		completed.append(level_id)
	var ratings = campaign.get("mission_ratings", {})
	var new_stars = result.get("stars", 0)
	var old_stars = ratings.get(level_id, 0)
	if new_stars > old_stars:
		ratings[level_id] = new_stars
	if is_victory:
		var next_id = _get_next_level_id(level_id)
		if next_id != "" and not completed.has(next_id):
			campaign["current_mission"] = next_id
			campaign["current_chapter"] = _get_chapter_from_id(next_id)
	campaign["completed_missions"] = completed
	campaign["mission_ratings"] = ratings

func _get_next_level_id(level_id: String) -> String:
	var regex = RegEx.new()
	regex.compile("ch(\\d+)_m(\\d+)")
	var result_regex = regex.search(level_id)
	if not result_regex:
		return ""
	var chapter = int(result_regex.get_string(1))
	var mission = int(result_regex.get_string(2))
	var next_mission = mission + 1
	var next_id = "ch%d_m%d" % [chapter, next_mission]
	if GameData.level_data.get("levels", {}).has(next_id):
		return next_id
	var next_chapter = chapter + 1
	var chapter_first = "ch%d_m1" % next_chapter
	if GameData.level_data.get("levels", {}).has(chapter_first):
		return chapter_first
	return ""

func _get_chapter_from_id(level_id: String) -> int:
	var regex = RegEx.new()
	regex.compile("ch(\\d+)_m(\\d+)")
	var result_regex = regex.search(level_id)
	if not result_regex:
		return 1
	return int(result_regex.get_string(1))

func _setup_boss_phase(boss: Node, boss_id: String) -> void:
	var boss_info = GameData.boss_data.get("bosses", {}).get(boss_id, {})
	if boss_info.is_empty():
		return
	boss.set_meta("is_boss", true)
	boss.set_meta("boss_id", boss_id)
	boss.set_meta("current_phase", 0)
	boss.set_meta("phases", boss_info.get("phases", []))
	var shield_amount = boss_info.get("shield", 0)
	boss.set_meta("shield", shield_amount)
	if shield_amount > 0:
		boss.add_status("barrier", 99, {"amount": shield_amount})
	boss.unit_damaged.connect(_on_boss_damaged.bind(boss))

func _on_boss_damaged(boss: Node) -> void:
	if not boss or not boss.is_alive:
		return
	if not boss.has_meta("is_boss"):
		return
	var phases = boss.get_meta("phases") as Array
	var current_phase = boss.get_meta("current_phase") as int
	var hp_percent = float(boss.current_hp) / float(boss.max_hp)
	while current_phase < phases.size() - 1:
		var threshold = float(phases[current_phase].get("hp_threshold", 0.0))
		if hp_percent <= threshold:
			current_phase += 1
			boss.set_meta("current_phase", current_phase)
			_enter_boss_phase(boss, phases[current_phase])
		else:
			break

func _enter_boss_phase(boss: Node, phase: Dictionary) -> void:
	boss.max_ap = phase.get("ap", boss.max_ap)
	boss.current_ap = boss.max_ap
	var enrage = phase.get("enrage", "")
	if enrage != "":
		boss.add_status("enrage", 99, {"damage_bonus": 0.5})
	BattleEffects.play_boss_phase_transition(GridSystem.grid_to_world(boss.grid_pos))
	AudioManager.sfx_level_up()
	boss_phase_changed.emit(boss, phase.get("name", "新阶段"))

func _show_simple_result(result: Dictionary) -> void:
	var is_victory = result.get("result", "defeat") == "victory"
	var msg = "胜利！" if is_victory else "失败..."
	msg += "\n回合: %d" % result.get("turns", 0)
	msg += "\n星级: %d" % result.get("stars", 0)
	var rewards = result.get("rewards", {})
	if rewards.size() > 0:
		msg += "\n奖励: %d信用 %d经验" % [rewards.get("credit", 0), rewards.get("exp", 0)]
	print(msg)
	TransitionManager.change_scene("res://scenes/base.tscn")
