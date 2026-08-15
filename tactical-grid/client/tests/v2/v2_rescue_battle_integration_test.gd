extends Node

const BattleScene = preload("res://scenes/v2_battle.tscn")
const BattleControllerScript = preload("res://scripts/v2/runtime/v2_battle_controller.gd")
const Runner = preload("res://tests/v2/test_runner.gd")
const Checkpoint = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M104 集成测试找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	var save: Dictionary = manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	manager.set("current_save", _with_known_tutorials(save))
	var battle := BattleScene.instantiate() as BattleController
	t.check(battle != null and battle.get_script() == BattleControllerScript, "M104 实例化正式 battle.tscn")
	if battle == null:
		t.finish(get_tree())
		return
	add_child(battle)
	await _dismiss_intro(manager)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "M104 等待到玩家行动阶段")
	if not ready:
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return

	var assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	t.check(assault != null and battle.v2_rescue_controller != null, "正式战斗已注册营救控制器")
	if assault == null or battle.v2_rescue_controller == null:
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return

	# Production M1 has no route-selection modal or gantry gate. Finding the
	# captive is a spatial beat: once the player reaches an adjacent cell the
	# rescue action becomes available.
	var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_scout")
	assault.grid_pos = rescue_pos + Vector2i.LEFT
	battle.call("_update_unit_sprite_pos", assault, false)
	battle.call("_update_visibility")
	var located: Dictionary = battle.call("_apply_v2_mission_event", &"scout_located", {"position": rescue_pos, "unit_id": assault.entity_id})
	t.check(bool(located.get("success", false)) and battle.v2_mission_flow.get_current_step_id() == "rescue_scout", "正式战斗中靠近标记后目标切换为营救")
	assault.begin_v2_turn()

	var captive: Dictionary = battle.v2_rescue_controller.get_captive(&"rescue_scout")
	var captive_attack: Dictionary = battle.v2_action_service.query_action({"action": &"attack", "unit": assault, "target": captive})
	t.check(not bool(captive_attack.get("valid", false)), "正式战斗中未营救对象不能成为攻击目标")
	var preview: Dictionary = battle.v2_rescue_controller.query_rescue(assault, &"rescue_scout")
	t.check(bool(preview.get("valid", false)), "正式战斗中相邻营救预览有效")
	var result: Dictionary = battle.v2_rescue_controller.commit_rescue(preview)
	await get_tree().process_frame
	var scout: Unit = result.get("new_unit", null)
	t.check(bool(result.get("success", false)), "正式战斗中营救提交成功")
	t.check(battle.player_units.size() == 2 and battle.player_units.has(scout), "侦察兵加入 BattleController 玩家队伍")
	t.check(scout != null and battle.call("_get_unit_sprite", scout) != null, "侦察兵立即获得可渲染单位精灵")
	t.check(scout != null and scout.v2_turn_state.can_move() and scout.v2_turn_state.can_act(), "侦察兵加入后本回合可立即行动")
	var checkpoint: Dictionary = SaveManager.get_encounter_checkpoint(GameManager.current_save)
	t.check(String(checkpoint.get("encounter_id", "")) == "cp_rescue", "营救后保存 cp_rescue 检查点")
	t.check(bool(Checkpoint.validate(checkpoint).get("valid", false)), "营救检查点可被 V2 schema 验证")
	t.check(String(battle.v2_mission_flow.get_state_name()) == "ESCORT_TO_EVAC" and battle.v2_mission_flow.get_current_step_id() == "evacuate_squad", "正式战斗目标切换为撤离阶段")

	await _cleanup_battle(battle)
	t.check(not is_instance_valid(assault), "战斗退出后突击兵数据节点已释放")
	t.check(not is_instance_valid(scout), "战斗退出后营救侦察兵数据节点已释放")
	await _stop_test_audio()
	t.finish(get_tree())

func _dismiss_intro(manager: Node) -> void:
	for _i in range(30):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

func _wait_for_player_phase(battle: BattleController) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await get_tree().process_frame
	return false

func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		# Unit data nodes are intentionally detached from the battle tree. Release
		# them before queueing the scene root so test shutdown does not rely on a
		# deferred lifecycle callback.
		battle.call("_cleanup_units")
		battle.queue_free()
		await get_tree().process_frame
		t.check(not is_instance_valid(battle), "营救测试退出前已销毁战斗根节点")

func _stop_test_audio() -> void:
	AudioManager.stop_bgm()
	AudioManager.stop_ambient()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	AudioManager.audio_cache.clear()
	await get_tree().process_frame
	AudioManager.stop_bgm()
	AudioManager.audio_cache.clear()
	await get_tree().process_frame
	if AudioManager.bgm_player and is_instance_valid(AudioManager.bgm_player):
		AudioManager.bgm_player.free()
		AudioManager.bgm_player = null
