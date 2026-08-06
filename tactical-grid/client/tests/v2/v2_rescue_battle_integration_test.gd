extends Node

const BattleScene = preload("res://scenes/battle.tscn")
const BattleControllerScript = preload("res://scripts/game/battle_controller.gd")
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
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
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
		_cleanup_battle(battle)
		t.finish(get_tree())
		return

	var assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	t.check(assault != null and battle.v2_rescue_controller != null, "正式战斗已注册营救控制器")
	if assault == null or battle.v2_rescue_controller == null:
		_cleanup_battle(battle)
		t.finish(get_tree())
		return

	var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_scout")
	assault.grid_pos = rescue_pos + Vector2i.LEFT
	battle.call("_update_visibility")
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
	t.check(String(battle.v2_mission_flow.get_state_name()) == "ESCORT_TO_EVAC", "正式战斗目标切换为护送撤离")

	_cleanup_battle(battle)
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

func _wait_for_player_phase(battle: BattleController) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await get_tree().process_frame
	return false

func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		await get_tree().process_frame

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
