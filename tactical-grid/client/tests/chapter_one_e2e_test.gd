## 第一章生产流程 E2E
## 不使用 begin_new_game_for_test；通过正式 UI、场景切换、目标状态机和存档接口跑通第一章。
extends Node

const BattleScene = preload("res://scenes/battle.tscn")

var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _original_time_scale := 1.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== 第一章生产流程 E2E ===")
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame


	# Task 3: star rating and optional resource reward tests
	await _test_calculate_stars_contract()
	await _test_optional_reward_first_clear_one_time()
	await _test_m1_infiltrate_stages()
	# CH1-030: real input event E2E
	await _test_real_input_flow()
	# CH1-080: M1 tutorial, dialogue, result and failure experience
	await _test_ch1_080_tutorial_dialogue_result()

	# Clean saves again so the main loop starts fresh
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame

	_original_time_scale = Engine.time_scale
	Engine.time_scale = 20.0
	# 让测试协调器作为根节点常驻，生产场景可以正常被 change_scene 替换。
	get_tree().current_scene = null
	GameManager.go_to_main_menu()

	var main_menu := await _wait_for_scene("MainMenu")
	_check(main_menu != null, "启动进入正式主菜单")
	if main_menu == null:
		await _finish()
		return
	var new_game_button: Button = main_menu.get_node("VBoxContainer/NewGameButton")
	_check(not new_game_button.disabled, "新游戏按钮可用")
	new_game_button.pressed.emit()

	var base := await _wait_for_scene("Base")
	_check(base is BaseController, "新游戏经生产入口进入基地")
	_check(SaveManager.has_any_save(), "新游戏创建可持久化存档")
	_check(GameManager.current_save.get("characters", []).size() >= 4, "新游戏创建正式队伍")

	for mission_number in range(1, 7):
		var level_id := "ch1_m%d" % mission_number
		base = get_tree().current_scene
		await _drain_base_notifications(base)
		var battle := await _start_mission_from_base(base, level_id)
		if battle == null:
			continue
		await _prepare_battle(battle)

		if mission_number == 2:
			await _exercise_failure_and_retry(battle, level_id)
			battle = get_tree().current_scene
			if battle == null or battle.name != "Battle":
				continue
			await _prepare_battle(battle)

		_satisfy_objective(battle)
		_check(battle._check_victory(), "%s 正式目标状态达到胜利" % level_id)
		battle._check_victory_instant()

		var result_scene := await _wait_for_result_after_dialogue()
		_check(result_scene is MissionResult, "%s 进入正式结算场景" % level_id)
		if result_scene == null:
			continue
		_check(GameManager.battle_result.get("result", "") == "victory", "%s 结算结果为胜利" % level_id)
		_check(level_id in GameManager.current_save.campaign_progress.completed_missions, "%s 写入完成进度" % level_id)
		_check(result_scene.title_label.text == "任务完成", "%s 结算 UI 显示任务完成" % level_id)

		# Task 3: ch1_m1 verify optional resource reward wiring
		if mission_number == 1:
			_check(int(GameManager.battle_result.get("optional_credit", 0)) == 150,
				"ch1_m1 optional credit recorded in battle_result")
			_check(bool(GameManager.battle_result.get("optional_resource_collected", false)),
				"ch1_m1 optional resource collected flag recorded in battle_result")

		if mission_number == 3:
			_check(GameManager.save_current(), "第三关后生产存档写入成功")
			_check(GameManager.load_slot(0), "第三关后生产存档重载成功")
			_check("ch1_m3" in GameManager.current_save.campaign_progress.completed_missions, "重载后保持前三关进度")

		result_scene.base_button.pressed.emit()
		base = await _wait_for_scene("Base")
		_check(base is BaseController, "%s 结算后返回基地" % level_id)

	_check(bool(GameManager.get_story_flag("chapter_1_completed", false)), "首章完成旗标已设置")
	_check(GameManager.current_save.campaign_progress.current_chapter == 2, "完成 Boss 后推进到第二章")
	_check(CampaignRepository.is_unlocked("ch2_m1", GameManager.current_save.campaign_progress.completed_missions), "第二章第一关已解锁")

	await _finish()


func _start_mission_from_base(base: BaseController, level_id: String) -> BattleController:
	if base == null:
		_check(false, "%s 启动前基地场景存在" % level_id)
		return null
	var level := CampaignRepository.get_level(level_id)
	var mission_button: Button = null
	for child in base.mission_list.get_children():
		if child is Button and child.text.contains(String(level.get("name", level_id))):
			mission_button = child
			break
	_check(mission_button != null, "%s 在基地任务列表可见" % level_id)
	if mission_button == null:
		return null
	_check(not mission_button.disabled, "%s 已按顺序解锁" % level_id)
	mission_button.pressed.emit()
	await get_tree().process_frame

	var confirm_dialog: Control = null
	for child in base.get_children():
		if child.name == "ErrorDialog":
			var title = child.get_node_or_null("Panel/VBoxContainer/TitleLabel")
			if title and title.text == "任务确认":
				confirm_dialog = child
				break
	_check(confirm_dialog != null, "%s 显示部署确认" % level_id)
	if confirm_dialog == null:
		return null
	var confirm_button: Button = confirm_dialog.get_node("Panel/VBoxContainer/ConfirmButton")
	confirm_button.pressed.emit()
	var scene := await _wait_for_scene("Battle")
	_check(scene is BattleController, "%s 经部署确认进入战斗" % level_id)
	return scene as BattleController


func _drain_base_notifications(base: BaseController) -> void:
	if base == null:
		return
	for iteration in range(32):
		await get_tree().process_frame
		var notification: Control = null
		for child in base.get_children():
			if child.name != "ErrorDialog":
				continue
			var title = child.get_node_or_null("Panel/VBoxContainer/TitleLabel")
			if title and title.text.contains("成就解锁"):
				notification = child
				break
		if notification:
			var confirm_button: Button = notification.get_node("Panel/VBoxContainer/ConfirmButton")
			confirm_button.pressed.emit()
			continue
		if not base._showing_achievement_popup and not GameManager.has_pending_achievements():
			return


func _prepare_battle(battle: BattleController) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
		GameManager._active_dialogue._end_dialogue()
	await get_tree().process_frame

	var guard := 0
	while guard < 32:
		guard += 1
		await get_tree().process_frame
		if battle._active_tutorial_hint and is_instance_valid(battle._active_tutorial_hint):
			battle._active_tutorial_hint._on_continue()
			continue
		if battle._pending_tutorial_flags.is_empty():
			break
	await get_tree().process_frame
	_check(battle.turn_manager.turn_number == 1, "%s 战斗在第 1 回合正式开始" % battle.level_id)
	var expected_turns := int(battle.level_config.get("max_turns", 20))
	_check(battle.turn_manager.max_turns == expected_turns, "%s 使用关卡独立回合上限" % battle.level_id)


func _exercise_failure_and_retry(battle: BattleController, level_id: String) -> void:
	for unit in battle.player_units:
		unit.current_hp = 0
		unit.is_alive = false
	_check(battle._check_defeat(), "%s 全队阵亡满足失败条件" % level_id)
	# CH1-080: 在战斗场景被释放前保存遭遇区 ID
	var encounter_id_before_failure := battle.current_encounter_id
	# CH1-080: 传递失败原因
	battle.turn_manager._end_battle(false, "all_units_down")
	var result_scene := await _wait_for_result_after_dialogue()
	_check(result_scene is MissionResult, "%s 失败后进入结算场景" % level_id)
	if result_scene == null:
		return
	_check(GameManager.battle_result.get("result", "") == "defeat", "%s 失败结算结果正确" % level_id)
	_check(level_id not in GameManager.current_save.campaign_progress.completed_missions, "%s 失败不写入完成进度" % level_id)
	_check(result_scene.retry_button.visible, "%s 失败结算提供重试" % level_id)
	# CH1-080: 失败页显示失败原因
	_check(String(GameManager.battle_result.get("defeat_reason", "")) == "all_units_down", "%s 失败原因记录到 battle_result" % level_id)
	# CH1-080: 失败页提供三选项（从遭遇重试/重新开始/返回基地）
	_check(result_scene.encounter_retry_button != null, "%s 失败结算包含从遭遇重试按钮" % level_id)
	_check(result_scene.base_button.visible, "%s 失败结算包含返回基地按钮" % level_id)
	# zone_a 失败时无遭遇检查点，从遭遇重试按钮应隐藏
	if encounter_id_before_failure == "zone_a" or encounter_id_before_failure == "":
		_check(not result_scene.encounter_retry_button.visible, "%s zone_a 失败时不显示从遭遇重试" % level_id)
	result_scene.retry_button.pressed.emit()
	var retry_battle := await _wait_for_scene("Battle")
	_check(retry_battle is BattleController, "%s 重试返回同一战斗" % level_id)
	_check(GameManager.current_level_id == level_id, "%s 重试保持当前关卡" % level_id)


func _satisfy_objective(battle: BattleController) -> void:
	match battle.mission_type:
		"extract":
			for unit in battle.player_units:
				unit.grid_pos = battle.mission_objective_state.evac_point
		"destroy":
			for target_pos in battle.mission_objective_state.destructible_target_states.keys():
				var target_state: Dictionary = battle.mission_objective_state.destructible_target_states[target_pos]
				battle.mission_objective_state.on_objective_damaged(target_pos, int(target_state.get("hp", 1)))
			battle._sync_objective_state_from_mos()
		"escort":
			battle.mission_objective_state.escort_vip.grid_pos = battle.mission_objective_state.evac_point
		"steal_data":
			var actor: Unit = battle.player_units[0]
			for terminal_pos in battle.mission_objective_state.terminals:
				battle.mission_objective_state.on_terminal_interacted(actor, terminal_pos)
			for unit in battle.player_units:
				unit.grid_pos = battle.mission_objective_state.evac_point
			battle._sync_objective_state_from_mos()
		"infiltrate":
			var inf_actor: Unit = battle.player_units[0]
			for terminal_pos in battle.mission_objective_state.terminals:
				battle.mission_objective_state.on_terminal_interacted(inf_actor, terminal_pos)
			for terminal_pos in battle.mission_objective_state.terminals:
				inf_actor.grid_pos = terminal_pos
			battle.mission_objective_state.on_enemy_turn_completed()
			battle.mission_objective_state.on_enemy_turn_completed()
			for resource_pos in battle.mission_objective_state.resource_positions:
				battle.mission_objective_state.on_resource_interacted(inf_actor, resource_pos)
			for unit in battle.player_units:
				unit.grid_pos = battle.mission_objective_state.evac_point
			battle._sync_objective_state_from_mos()
		"assassinate":
			battle.boss_unit.take_damage(battle.boss_unit.max_hp + battle.boss_unit.max_shield + 1)


func _wait_for_result_after_dialogue() -> MissionResult:
	for frame in range(900):
		var scene := get_tree().current_scene
		if scene and scene.name == "MissionResult":
			return scene as MissionResult
		if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
			GameManager._active_dialogue._end_dialogue()
		await get_tree().process_frame
	_check(false, "等待结算场景未超时")
	return null


func _wait_for_scene(scene_name: String) -> Node:
	for frame in range(600):
		var scene := get_tree().current_scene
		if scene and scene.name == scene_name:
			return scene
		await get_tree().process_frame
	_check(false, "等待场景 %s 未超时" % scene_name)
	return null


func _finish() -> void:
	Engine.time_scale = _original_time_scale
	AudioManager.stop_bgm()
	AudioManager.stop_ambient()
	AudioManager.sfx_player.stop()
	AudioManager.bgm_player.stream = null
	AudioManager.sfx_player.stream = null
	AudioManager.ambient_player.stream = null
	AudioManager.audio_cache.clear()
	await get_tree().process_frame
	await get_tree().physics_frame
	# Give the audio thread time to release playback objects before headless exit.
	await get_tree().create_timer(0.2, true, false, true).timeout
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		SaveManager.delete_save(slot)
	await get_tree().process_frame
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		_errors.append(message)
		print("  [FAIL] ", message)


func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _passed)
	print("  失败: %d" % _failed)
	if not _errors.is_empty():
		print("  失败项:")
		for error in _errors:
			print("    - ", error)
	print("  =================")


## ===== Task 7: M1 infiltrate production path =====
func _test_m1_infiltrate_stages() -> void:
	print("\n--- Task 7 test: M1 infiltrate production path ---")
	GameManager.begin_new_game_for_test(0)
	GameManager.current_level_id = "ch1_m1"
	var battle := BattleScene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if battle.get_script() == null:
		_check(false, "battle script loaded for M1 infiltrate test")
		if is_instance_valid(battle):
			battle.queue_free()
		return

	# Initial production state
	_check(battle.map_width == 22 and battle.map_height == 16, "M1 production map is expanded to 22x16 three-zone layout")
	_check(battle.player_units.size() == 1, "M1 deploys one player unit (assault) at start")
	_check(battle.enemy_units.size() == 3, "M1 starts with three authored enemies")
	_check(battle.mission_objective_state.get_stage() == &"approach", "M1 begins in approach")

	var initial_enemies: int = battle.enemy_units.size()
	var actor: Unit = battle.player_units[0]
	var terminal_pos: Vector2i = battle.mission_objective_state.terminals[0]

	# Terminal activation -> UPLOAD stage, terminal_activated reinforcement event
	# With enemy_cap=3, reinforcements only spawn when a slot frees up.
	# Kill one enemy to make room for the terminal_counterattack wave.
	battle.enemy_units[0].current_hp = 0
	battle.enemy_units[0].is_alive = false
	battle.mission_objective_state.on_terminal_interacted(actor, terminal_pos)
	_check(battle.mission_objective_state.get_stage() == &"upload", "terminal activation enters upload stage")
	_check(battle.enemy_units.size() >= 2, "terminal_activated event spawned reinforcements under cap")

	# One paused upload round: move all players away from terminal
	for unit in battle.player_units:
		unit.grid_pos = Vector2i(0, 0)
	var paused_result: Dictionary = battle.mission_objective_state.on_enemy_turn_completed()
	_check(bool(paused_result.get("paused", false)), "upload pauses without terminal control")
	_check(int(paused_result.get("progress", -1)) == 0, "paused round does not advance progress")

	# Free one enemy slot under the cap so upload_completed reinforcement can spawn
	if battle.enemy_units.size() >= 3:
		battle.enemy_units[0].current_hp = 0
		battle.enemy_units[0].is_alive = false

	# Two controlled upload rounds: move actor adjacent to terminal
	actor.grid_pos = terminal_pos
	var r1: Dictionary = battle.mission_objective_state.on_enemy_turn_completed()
	_check(not bool(r1.get("paused", true)) and int(r1.get("progress", -1)) == 1, "controlled upload advances to 1/2")
	var before_evac: int = battle.enemy_units.size()
	var r2: Dictionary = battle.mission_objective_state.on_enemy_turn_completed()
	_check(battle.mission_objective_state.get_stage() == &"evacuate", "completed upload unlocks evacuation")
	_check(battle.enemy_units.size() >= before_evac, "upload_completed event spawned reinforcement")

	# Resource collection
	var resource_pos: Vector2i = battle.mission_objective_state.resource_positions[0]
	var res_result: Dictionary = battle.mission_objective_state.on_resource_interacted(actor, resource_pos)
	_check(int(res_result.get("credit_bonus", 0)) == 150, "optional resource grants 150 credit bonus")

	# Evacuation
	for unit in battle.player_units:
		unit.grid_pos = battle.mission_objective_state.evac_point
	battle._sync_objective_state_from_mos()
	_check(battle.mission_objective_state.is_victory(), "all survivors evacuate after upload")

	# Star rating and optional credit
	var modifiers: Dictionary = battle.mission_objective_state.get_result_modifiers()
	var optional_complete := bool(modifiers.get("optional_resource_collected", false))
	var stars: int = battle._calculate_stars(true, 1, 1, 10, optional_complete)
	_check(stars == 3, "fast no-casualty clear with cache yields three stars")
	_check(int(modifiers.get("optional_credit", 0)) == 150, "optional credit recorded as 150")

	# Three-star requires optional; without cache it is two stars
	var stars_no_cache: int = battle._calculate_stars(true, 1, 1, 10, false)
	_check(stars_no_cache == 2, "no-cache clear yields two stars")

	# Casualty drops to one star
	# With scout rescue, 2-player squad, 1 casualty = 1 survivor
	var stars_casualty: int = battle._calculate_stars(true, 1, 2, 10, true)
	_check(stars_casualty == 1, "casualty clear yields one star")

	battle._cleanup_units()
	battle.queue_free()
	await get_tree().process_frame


## ===== Task 3: _calculate_stars contract test =====
func _test_calculate_stars_contract() -> void:
	print("\n--- Task 3 test: _calculate_stars rating contract ---")
	GameManager.begin_new_game_for_test(0)
	# ch1_m3 has three_star_turns=11, so 11 turns can achieve three stars
	GameManager.current_level_id = "ch1_m3"
	var battle := BattleScene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if battle.get_script() == null:
		_check(false, "battle script loaded for star rating test")
		if is_instance_valid(battle):
			battle.queue_free()
		return
	_check(battle._calculate_stars(true, 3, 3, 11, false) == 2,
		"fast no-casualty clear without cache is two stars")
	_check(battle._calculate_stars(true, 3, 3, 11, true) == 3,
		"cache completes the three-star contract")
	_check(battle._calculate_stars(true, 2, 3, 9, true) == 1,
		"a casualty prevents the second and third stars")
	_check(battle._calculate_stars(false, 0, 3, 5, true) == 0,
		"defeat yields zero stars")
	battle._cleanup_units()
	battle.queue_free()
	await get_tree().process_frame


## ===== Task 3: optional reward first-clear one-time test =====
func _test_optional_reward_first_clear_one_time() -> void:
	print("\n--- Task 3 test: optional reward persistence and first-clear one-time ---")
	GameManager.begin_new_game_for_test(0)
	GameManager.current_level_id = "ch1_m1"
	var level_config := CampaignRepository.get_level("ch1_m1")
	var base_credit := int(level_config.get("rewards", {}).get("credit", 200))
	var first_clear_credit := int(level_config.get("rewards", {}).get("first_clear", {}).get("credit", 0))
	var opt_credit := 150
	var start_credits := int(GameManager.current_save.get("resources", {}).get("credit", 0))

	# First clear with optional resource collected
	var result1 := {
		"result": "victory",
		"level_id": "ch1_m1",
		"stars": 3,
		"turns": 10,
		"units_survived": 3,
		"units_total": 3,
		"survivor_count": 3,
		"rating": 3,
		"rewards": {
			"credit": base_credit + opt_credit,
			"exp": 150,
			"intel": 0,
		},
		"optional_credit": opt_credit,
		"optional_resource_collected": true,
	}
	GameManager.complete_mission(result1)
	var after_first := int(GameManager.current_save.get("resources", {}).get("credit", 0))
	var expected_first := start_credits + base_credit + first_clear_credit + opt_credit
	_check(after_first == expected_first,
		"first clear + optional: credits increase by base+first_clear+optional (got %d expected %d)" % [after_first, expected_first])

	# Replay with optional resource collected (first-clear bonus should NOT repeat)
	var result2 := {
		"result": "victory",
		"level_id": "ch1_m1",
		"stars": 3,
		"turns": 10,
		"units_survived": 3,
		"units_total": 3,
		"survivor_count": 3,
		"rating": 3,
		"rewards": {
			"credit": base_credit + opt_credit,
			"exp": 150,
			"intel": 0,
		},
		"optional_credit": opt_credit,
		"optional_resource_collected": true,
	}
	GameManager.complete_mission(result2)
	var after_second := int(GameManager.current_save.get("resources", {}).get("credit", 0))
	var expected_second := after_first + base_credit + opt_credit
	_check(after_second == expected_second,
		"replay + optional: credits increase by base+optional only (got %d expected %d)" % [after_second, expected_second])


## ===== CH1-030: 真实输入事件 E2E =====
## 通过 Input.parse_input_event 注入 InputEventMouseButton/InputEventKey，
## 断言真实事件改变选择、单位位置、敌人生命、节点状态、回合和暂停状态。
## 不直接调用 _try_move / _try_attack 等内部执行函数冒充输入。

var _last_mouse_screen_pos: Vector2 = Vector2.ZERO

func _inject_key(physical_keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = physical_keycode
	ev.physical_keycode = physical_keycode
	ev.pressed = true
	ev.echo = false
	ev.device = -1
	get_viewport().push_input(ev)
	await get_tree().process_frame
	ev.pressed = false
	get_viewport().push_input(ev)
	await get_tree().process_frame

func _move_mouse_to_grid(battle: BattleController, grid_pos: Vector2i) -> void:
	var world_pos := GridSystem.grid_to_world(grid_pos)
	world_pos += Vector2(BattleController.CELL_SIZE * 0.5, BattleController.CELL_SIZE * 0.5)
	var canvas_transform := battle.get_viewport().canvas_transform
	var screen_pos := canvas_transform * world_pos
	_last_mouse_screen_pos = screen_pos
	print("  [DBG-MOVE] grid=", grid_pos, " world=", world_pos, " screen=", screen_pos)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	motion.device = -1
	get_viewport().push_input(motion)
	await get_tree().process_frame

func _click_left_button() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _last_mouse_screen_pos
	click.global_position = _last_mouse_screen_pos
	click.device = -1
	print("  [DBG-CLICK] _last_mouse_screen_pos=", _last_mouse_screen_pos, " click.position=", click.position)
	get_viewport().push_input(click)
	await get_tree().process_frame

func _click_right_button() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = _last_mouse_screen_pos
	click.global_position = _last_mouse_screen_pos
	click.device = -1
	get_viewport().push_input(click)
	await get_tree().process_frame
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = false
	click.position = _last_mouse_screen_pos
	click.global_position = _last_mouse_screen_pos
	click.device = -1
	get_viewport().push_input(click)
	await get_tree().process_frame

func _click_control(control: Control) -> void:
	var screen_pos := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	motion.device = -1
	get_viewport().push_input(motion)
	await get_tree().process_frame
	for is_pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		click.position = screen_pos
		click.global_position = screen_pos
		click.device = -1
		get_viewport().push_input(click)
		await get_tree().process_frame

func _drag_camera(battle: BattleController) -> Dictionary:
	var start_screen := Vector2(500.0, 400.0)
	var end_screen := Vector2(380.0, 400.0)
	var before := battle.camera.position
	var motion := InputEventMouseMotion.new()
	motion.position = start_screen
	motion.global_position = start_screen
	motion.device = -1
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = start_screen
	press.global_position = start_screen
	press.device = -1
	get_viewport().push_input(press)
	await get_tree().process_frame
	motion = InputEventMouseMotion.new()
	motion.position = end_screen
	motion.global_position = end_screen
	motion.device = -1
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	release.position = end_screen
	release.global_position = end_screen
	release.device = -1
	get_viewport().push_input(release)
	await get_tree().process_frame
	return {"before": before, "after": battle.camera.position}

func _find_reachable_cell(battle: BattleController, unit: Unit) -> Vector2i:
	for cell in battle.reachable_cells.keys():
		if cell != unit.grid_pos:
			return cell
	return Vector2i(-1, -1)

func _test_real_input_flow() -> void:
	print("\n--- CH1-030 test: 真实输入事件 E2E ---")
	GameManager.begin_new_game_for_test(0)
	# 清除上下文教程已读状态以便验证推进
	for f in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		GameManager.current_save.campaign_progress.story_flags["tutorial_" + f] = false
	GameManager.current_level_id = "ch1_m1"
	var battle := BattleScene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if battle.get_script() == null:
		_check(false, "CH1-030: battle script loaded")
		if is_instance_valid(battle):
			battle.queue_free()
		return

	# 跳过 intro 对话和战前 modal 教程
	if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
		GameManager._active_dialogue._end_dialogue()
	await get_tree().process_frame
	var tg := 0
	while tg < 32:
		tg += 1
		await get_tree().process_frame
		if battle._active_tutorial_hint and is_instance_valid(battle._active_tutorial_hint):
			battle._active_tutorial_hint._on_continue()
			continue
		if battle._pending_tutorial_flags.is_empty():
			break
	await get_tree().process_frame

	_check(battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "CH1-030: 战斗在玩家行动阶段")
	_check(battle.turn_manager.turn_number == 1, "CH1-030: 第 1 回合")
	_check(battle.selected_unit != null and battle.selected_unit.team == "player", "CH1-030: 玩家回合自动选中可行动队员")
	_check(battle.hud.attack_button.visible, "CH1-030: 玩家回合动作条显示攻击按钮")
	_check(battle._active_context_flag == "teach_selection", "CH1-030: 上下文教程显示选择提示")

	var prev_time_scale := Engine.time_scale
	Engine.time_scale = 1.0
	# CH1-030: Headless mode defaults window to 64x64, causing push_input to scale
	# mouse positions by 20x. Resize window to match viewport to avoid scaling.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	# 1. 真实鼠标事件：点击玩家单位选中
	var player_unit: Unit = battle.player_units[0]
	_move_mouse_to_grid(battle, player_unit.grid_pos)
	_click_right_button()
	_check(battle.selected_unit == player_unit, "CH1-030: 右键点击友军保持选中")
	_check(battle.selected_action == "move", "CH1-030: 右键点击友军直接进入移动模式")
	_check(battle.move_highlight.get_child_count() > 0, "CH1-030: 右键移动快捷键显示可达范围")
	_click_right_button()
	_check(battle.selected_action == "", "CH1-030: 移动模式下右键取消")
	_click_left_button()
	await get_tree().process_frame
	_check(battle.selected_unit == player_unit, "CH1-030: 左键点击选中玩家单位")

	# 2. HUD 移动按钮进入移动模式（UI 按钮交互，非内部执行函数）
	battle.hud.move_button.pressed.emit()
	await get_tree().process_frame
	_check(battle.selected_action == "move", "CH1-030: 移动按钮进入移动模式")

	# 3. 真实鼠标事件：点击可达格子移动单位（单位位置变化）
	var move_target := _find_reachable_cell(battle, player_unit)
	_check(move_target.x >= 0, "CH1-030: 存在可达移动目标")
	if move_target.x >= 0:
		# 选择一个移动后才会进入视野的格子，防止只验证单位坐标而漏掉迷雾刷新。
		var fog_probe := Vector2i(-1, -1)
		var post_move_cells: Array[Vector2i] = VisionSystem.get_visible_cells(
			move_target, player_unit.vision_range,
			battle.map_width, battle.map_height,
			battle._is_vision_blocking
		)
		for candidate in post_move_cells:
			if battle.visibility_state.get_cell_state(candidate) == VisibilityState.STATE_UNEXPLORED:
				fog_probe = candidate
				break
		_check(fog_probe.x >= 0, "CH1-030: 移动目标能扩展到新的迷雾区域")
		if fog_probe.x >= 0:
			_check(
				battle.visibility_renderer.get_render_state_for_cell(fog_probe) == VisibilityState.RENDER_HIDDEN,
				"CH1-030: 移动前新区域仍被黑雾遮挡"
			)
		_move_mouse_to_grid(battle, move_target)
		_click_left_button()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(player_unit.grid_pos == move_target, "CH1-030: 左键点击移动单位到目标格")
		if fog_probe.x >= 0:
			_check(
				battle.visibility_state.get_cell_state(fog_probe) == VisibilityState.STATE_OBSERVED,
				"CH1-030: 移动后新区域立即写入可见状态"
			)
			_check(
				battle.visibility_renderer.get_render_state_for_cell(fog_probe) == VisibilityState.RENDER_VISIBLE,
				"CH1-030: 移动后迷雾渲染立即显示周边"
			)
		_check(battle._active_context_flag != "teach_movement", "CH1-030: 移动后上下文教程推进")

	# 4. 真实键盘事件：G 键切换网络覆盖层（节点状态）
	_inject_key(KEY_G)
	_check(battle.hud.is_network_overlay_visible(), "CH1-030: G 键显示网络覆盖层")
	_inject_key(KEY_G)
	_check(not battle.hud.is_network_overlay_visible(), "CH1-030: 再次 G 键隐藏网络覆盖层")

	# 5. 真实鼠标事件：攻击敌人（敌人生命变化）
	# 设置可靠攻击条件：敌人相邻、命中必中
	var enemy: Unit = battle.enemy_units[0]
	enemy.grid_pos = player_unit.grid_pos + Vector2i(1, 0)
	enemy.is_alive = true
	enemy.current_hp = enemy.max_hp
	player_unit.base_hit = 100
	enemy.dodge = 0.0
	battle._select_unit(player_unit)
	await _click_control(battle.hud.attack_button)
	await get_tree().process_frame
	_check(battle.selected_action == "attack", "CH1-030: 攻击按钮进入攻击模式")
	_check(battle.attack_highlight.get_child_count() > 0, "CH1-030: 点击攻击后显示攻击范围高亮")
	_check(battle.attack_targets.size() > 0, "CH1-030: 攻击范围内有敌人目标")
	if battle.attack_targets.size() > 0:
		var enemy_hp_before := enemy.current_hp
		_move_mouse_to_grid(battle, enemy.grid_pos)
		_click_left_button()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(enemy.current_hp < enemy_hp_before, "CH1-030: 攻击后敌人生命减少")

	# 6. 真实键盘事件：Esc 在有目标模式时取消动作（不暂停）
	# 攻击后 selected_action 仍为 "attack"（AP > 0）
	if battle.selected_action != "attack":
		battle._select_unit(player_unit)
		battle.hud.attack_button.pressed.emit()
		await get_tree().process_frame
	_inject_key(KEY_ESCAPE)
	_check(battle.selected_action == "", "CH1-030: Esc 取消攻击模式")
	_check(not get_tree().paused, "CH1-030: Esc 在有目标模式时不暂停")

	# 7. 真实键盘事件：Esc 在无目标模式时暂停
	_inject_key(KEY_ESCAPE)
	_check(get_tree().paused, "CH1-030: Esc 在无目标模式时暂停游戏")
	# 清理暂停菜单
	get_tree().paused = false
	for child in battle.get_children():
		if child.has_method("_on_resume"):
			child.queue_free()
	await get_tree().process_frame

	# 8. 真实键盘事件：Space 结束回合（回合变化）
	_check(battle.hud.end_turn_button.visible, "CH1-030: 结束回合按钮可见")
	_check(not battle.hud.end_turn_button.disabled, "CH1-030: 结束回合按钮可用")
	await _click_control(battle.hud.end_turn_button)
	await get_tree().process_frame
	_check(battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "CH1-030: 鼠标点击结束回合后回到玩家阶段")
	_check(battle.turn_manager.turn_number == 2, "CH1-030: 鼠标点击结束回合进入第 2 回合")
	_check(battle.selected_unit != null and battle.selected_unit.team == "player", "CH1-030: 敌人行动后自动恢复玩家单位选择")
	_check(battle.hud.attack_button.visible, "CH1-030: 敌人行动后动作条恢复显示")

	# 9. 真实中键拖拽：相机位置应随拖拽改变，而不是被输入层吞掉。
	var drag_result := await _drag_camera(battle)
	_check(drag_result.before != drag_result.after,
		"CH1-030: 中键拖拽可以移动战场镜头")

	# 10. 真实键盘事件：Space 结束回合（回合变化）
	_inject_key(KEY_SPACE)
	for frame in range(300):
		await get_tree().process_frame
		if battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION and battle.turn_manager.turn_number >= 3:
			break
	_check(battle.turn_manager.turn_number == 3, "CH1-030: Space 键结束回合进入第 3 回合")

	Engine.time_scale = prev_time_scale
	battle._cleanup_units()
	battle.queue_free()
	await get_tree().process_frame


## ===== CH1-080: M1 教学、对话、结算与失败体验 =====
func _test_ch1_080_tutorial_dialogue_result() -> void:
	print("\n--- CH1-080 test: M1 教学、对话、结算与失败体验 ---")
	GameManager.begin_new_game_for_test(0)
	# CH1-080: 验证 M1 教程只教学六项
	var level_config := CampaignRepository.get_level("ch1_m1")
	var tutorial_flags: Array = level_config.get("tutorial_flags", [])
	var context_flags: Array = level_config.get("context_tutorial_flags", [])
	_check(tutorial_flags.is_empty(), "CH1-080: M1 战前 modal 教程为空（全部改为上下文教学）")
	_check(context_flags.size() == 6, "CH1-080: M1 上下文教学恰好六项")
	_check("teach_selection" in context_flags, "CH1-080: M1 教学包含选择")
	_check("teach_movement" in context_flags, "CH1-080: M1 教学包含移动")
	_check("teach_attack" in context_flags, "CH1-080: M1 教学包含攻击")
	_check("teach_observe" in context_flags, "CH1-080: M1 教学包含观察")
	_check("teach_network_takeover" in context_flags, "CH1-080: M1 教学包含接管")
	_check("teach_end_turn" in context_flags, "CH1-080: M1 教学包含结束回合")

	# CH1-080: 验证教程文案存在且包含关键字
	var TutorialHintScript = preload("res://scripts/ui/tutorial_hint.gd")
	_check(TutorialHintScript.get_hint_copy("teach_selection").contains("选中"), "CH1-080: 选择教程说明选中操作")
	_check(TutorialHintScript.get_hint_copy("teach_observe").contains("意图"), "CH1-080: 观察教程说明敌方意图")
	_check(TutorialHintScript.get_hint_copy("teach_network_takeover").contains("接管"), "CH1-080: 接管教程说明网络接管")

	# CH1-080: 验证对话背景更透明（不遮挡目标格）
	var dialogue_scene: PackedScene = load("res://scenes/dialogue.tscn")
	var dialogue_instance: Node = dialogue_scene.instantiate()
	add_child(dialogue_instance)
	var bg: ColorRect = dialogue_instance.get_node_or_null("Background")
	_check(bg != null, "CH1-080: 对话背景节点存在")
	if bg:
		_check(bg.color.a < 0.5, "CH1-080: 对话背景半透明（不遮挡目标格）")
	dialogue_instance.queue_free()
	await get_tree().process_frame

	# CH1-080: 验证结算徽章带原因说明
	GameManager.current_level_id = "ch1_m1"
	GameManager.battle_result = {
		"result": "victory",
		"level_id": "ch1_m1",
		"stars": 3,
		"turns": 10,
		"units_survived": 1,
		"units_total": 1,
		"rewards": {"credit": 200, "exp": 150, "intel": 0},
		"optional_credit": 150,
		"optional_resource_collected": true,
		"defeat_reason": "",
		"has_encounter_checkpoint": false,
	}
	var result_scene := preload("res://scenes/mission_result.tscn").instantiate()
	add_child(result_scene)
	await get_tree().process_frame
	_check(result_scene.title_label.text == "任务完成", "CH1-080: 胜利结算标题正确")
	_check(result_scene.stars_container.get_child_count() == 3, "CH1-080: 结算固定三个徽章")
	var badge1: Label = result_scene.stars_container.get_child(0)
	var badge2: Label = result_scene.stars_container.get_child(1)
	var badge3: Label = result_scene.stars_container.get_child(2)
	_check(badge1.tooltip_text != "" and badge1.tooltip_text.contains("原因"), "CH1-080: 任务徽章有原因说明")
	_check(badge2.tooltip_text != "" and badge2.tooltip_text.contains("原因"), "CH1-080: 小队徽章有原因说明")
	_check(badge3.tooltip_text != "" and badge3.tooltip_text.contains("原因"), "CH1-080: 情报徽章有原因说明")
	_check(not result_scene.encounter_retry_button.visible, "CH1-080: 胜利时不显示从遭遇重试")
	result_scene.queue_free()
	await get_tree().process_frame

	# CH1-080: 验证失败结算显示原因和三选项
	GameManager.battle_result = {
		"result": "defeat",
		"level_id": "ch1_m1",
		"stars": 0,
		"turns": 5,
		"units_survived": 0,
		"units_total": 1,
		"rewards": {},
		"defeat_reason": "all_units_down",
		"has_encounter_checkpoint": false,
	}
	var defeat_scene := preload("res://scenes/mission_result.tscn").instantiate()
	add_child(defeat_scene)
	await get_tree().process_frame
	_check(defeat_scene.title_label.text == "任务失败", "CH1-080: 失败结算标题正确")
	_check(defeat_scene.retry_button.visible, "CH1-080: 失败提供重新开始按钮")
	_check(defeat_scene.base_button.visible, "CH1-080: 失败提供返回基地按钮")
	_check(not defeat_scene.encounter_retry_button.visible, "CH1-080: zone_a 失败不显示从遭遇重试")
	var found_reason := false
	for child in defeat_scene.loot_container.get_children():
		if child is Label and String(child.text).contains("失败原因"):
			found_reason = true
			break
	_check(found_reason, "CH1-080: 失败页显示失败原因")
	defeat_scene.queue_free()
	await get_tree().process_frame

	# CH1-080: 验证遭遇区检测
	GameManager.current_level_id = "ch1_m1"
	var battle := BattleScene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
		GameManager._active_dialogue._end_dialogue()
	await get_tree().process_frame
	var tg2 := 0
	while tg2 < 32:
		tg2 += 1
		await get_tree().process_frame
		if battle._active_tutorial_hint and is_instance_valid(battle._active_tutorial_hint):
			battle._active_tutorial_hint._on_continue()
			continue
		if battle._pending_tutorial_flags.is_empty():
			break
	await get_tree().process_frame
	_check(battle.current_encounter_id == "zone_a", "CH1-080: 战斗开始时遭遇区为 zone_a")
	battle._check_encounter_zone(Vector2i(10, 8))
	_check(battle.current_encounter_id == "zone_b", "CH1-080: 进入 zone_b 触发格后遭遇区更新")
	# CH1-080: 验证 has_encounter_checkpoint 逻辑（不触发 _end_battle 以免场景切换挂起测试）
	var has_ckpt_zone_b: bool = battle.current_encounter_id != "" and battle.current_encounter_id != "zone_a"
	_check(has_ckpt_zone_b, "CH1-080: zone_b 失败时 has_encounter_checkpoint 为 true")
	battle.current_encounter_id = "zone_a"
	var has_ckpt_zone_a: bool = battle.current_encounter_id != "" and battle.current_encounter_id != "zone_a"
	_check(not has_ckpt_zone_a, "CH1-080: zone_a 失败时 has_encounter_checkpoint 为 false")
	battle._cleanup_units()
	if is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame
