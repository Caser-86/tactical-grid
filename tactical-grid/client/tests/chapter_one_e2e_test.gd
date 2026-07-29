## 第一章生产流程 E2E
## 不使用 begin_new_game_for_test；通过正式 UI、场景切换、目标状态机和存档接口跑通第一章。
extends Node

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
	battle.turn_manager._end_battle(false)
	var result_scene := await _wait_for_result_after_dialogue()
	_check(result_scene is MissionResult, "%s 失败后进入结算场景" % level_id)
	if result_scene == null:
		return
	_check(GameManager.battle_result.get("result", "") == "defeat", "%s 失败结算结果正确" % level_id)
	_check(level_id not in GameManager.current_save.campaign_progress.completed_missions, "%s 失败不写入完成进度" % level_id)
	_check(result_scene.retry_button.visible, "%s 失败结算提供重试" % level_id)
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
