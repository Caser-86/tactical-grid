extends Node

const BattleScene = preload("res://scenes/v2_battle.tscn")
const BattleControllerScript = preload("res://scripts/v2/runtime/v2_battle_controller.gd")
const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()
var _test_tree: SceneTree

func _ready() -> void:
	_test_tree = get_tree()
	_run.call_deferred()

func _run() -> void:
	print("=== V2 hazard runtime scene regression ===")
	var manager: Node = _test_tree.root.get_node_or_null("GameManager")
	t.check(manager != null, "危险区场景测试找到正式 GameManager")
	if manager == null:
		t.finish(_test_tree)
		return
	await _assert_turn_boundary_hazard_runtime(manager)
	await _assert_restore_recomputes_hazard_overlay(manager)
	await _assert_failed_restore_entry_cleans_runtime(manager)
	await _stop_test_audio()
	t.finish(_test_tree)

func _assert_turn_boundary_hazard_runtime(manager: Node) -> void:
	var battle := await _start_fixture_battle(manager)
	if battle == null:
		return
	var player: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	t.check(player != null and player.grid_pos == Vector2i(1, 1), "fixture 部署玩家在危险区测试格")
	t.check(_has_hazard_overlay(battle, "warning", Vector2i(1, 1)), "玩家阶段通过 V2BattleController 渲染危险区预警")
	t.check(not _has_hazard_overlay(battle, "active", Vector2i(1, 1)), "预警回合尚未渲染生效危险格")
	var hp_before := player.current_hp if player != null else 0
	battle.turn_manager.end_player_turn()
	await _test_tree.process_frame
	t.check(player != null and player.current_hp == hp_before, "预警当回合敌方阶段不提前造成伤害")
	battle.turn_manager.end_enemy_turn()
	await _test_tree.process_frame
	t.check(battle.turn_manager.turn_number == 2 and _has_hazard_overlay(battle, "active", Vector2i(1, 1)), "下一玩家阶段通过真实回合边界渲染生效危险格")
	battle.turn_manager.end_player_turn()
	await _test_tree.process_frame
	var hp_after_damage := player.current_hp if player != null else 0
	t.check(player != null and hp_after_damage == hp_before - 2, "伤害回合敌方阶段通过控制器结算一次 HP 伤害")
	battle.turn_manager.set_phase(TurnManager.TurnPhase.ENEMY_ACTION)
	await _test_tree.process_frame
	t.check(player != null and player.current_hp == hp_after_damage, "重复敌方阶段信号不重复消费同一危险区伤害")
	battle.turn_manager.end_enemy_turn()
	await _test_tree.process_frame
	if player != null:
		player.v2_turn_state.begin_turn()
	var result: Dictionary = battle.v2_interaction_service.commit_action(player, "facility_hazard_shutdown", "overload", battle.v2_interaction_service.get_state_revision())
	battle.call("_apply_v2_interaction_result", result)
	await _test_tree.process_frame
	t.check(bool(result.get("success", false)), "fixture 通过真实 V2 设施动作提交 close_action_id")
	t.check(not _has_hazard_overlay(battle, "warning", Vector2i(1, 1)) and not _has_hazard_overlay(battle, "active", Vector2i(1, 1)), "close_action_id 立即移除已关闭危险区覆盖层")
	battle.turn_manager.end_player_turn()
	await _test_tree.process_frame
	var hp_after_close := player.current_hp if player != null else 0
	battle.turn_manager.end_enemy_turn()
	await _test_tree.process_frame
	t.check(not _has_hazard_overlay(battle, "warning", Vector2i(1, 1)) and player != null and player.current_hp == hp_after_close, "关闭后后续周期不再显示或造成伤害")
	await _cleanup_battle(battle)

func _assert_restore_recomputes_hazard_overlay(manager: Node) -> void:
	var source := await _start_fixture_battle(manager)
	if source == null:
		return
	var saved := manager.call("get_v2_encounter_checkpoint") as Dictionary
	t.check(not saved.is_empty(), "fixture 起始检查点已由真实战斗入口写入")
	saved["turn"] = 3
	saved["hazard_state"] = {
		"schema_version": 1,
		"closed_ids": {},
		"resolved_damage_keys": {"runtime_vent:0": true},
		"last_turn": 2,
	}
	saved = _with_hash(saved)
	await _cleanup_battle(source)
	manager.set("pending_v2_checkpoint", saved)
	var restored := BattleScene.instantiate()
	t.check(restored != null and restored.get_script() == BattleControllerScript, "恢复测试实例化正式 v2_battle.tscn")
	if restored == null:
		return
	_test_tree.root.add_child(restored)
	await _wait_for_player_phase(restored)
	t.check(restored.turn_manager.turn_number == 3, "恢复入口安装检查点保存的回合数")
	t.check(restored.hud.turn_label.text == "回合 3", "恢复后 HUD 可见回合计数与保存回合一致")
	t.check(not _has_hazard_overlay(restored, "warning", Vector2i(1, 1)), "恢复后没有保留恢复前 turn 1 的 stale 预警覆盖层")
	t.check(_has_hazard_overlay(restored, "warning", Vector2i(2, 1)), "恢复后按保存回合重新渲染危险区预警覆盖层")
	var hazard_snapshot: Dictionary = restored.v2_hazard_controller.get_snapshot()
	t.check(bool((hazard_snapshot.get("resolved_damage_keys", {}) as Dictionary).get("runtime_vent:0", false)), "恢复后保留已消费危险区伤害 key")
	await _cleanup_battle(restored)
	manager.call("clear_v2_encounter_checkpoint")

func _assert_failed_restore_entry_cleans_runtime(manager: Node) -> void:
	var source := await _start_fixture_battle(manager)
	if source == null:
		return
	var failing := manager.call("get_v2_encounter_checkpoint") as Dictionary
	failing["hazard_state"] = {
		"schema_version": 1,
		"closed_ids": {"missing_vent": true},
		"resolved_damage_keys": {},
		"last_turn": 1,
	}
	failing = _with_hash(failing)
	await _cleanup_battle(source)
	t.check(bool(manager.call("set_v2_encounter_checkpoint", failing)), "失败恢复 fixture 写入可通过 schema 的待恢复检查点")
	manager.set("pending_v2_checkpoint", failing)
	var failed_battle := BattleScene.instantiate()
	t.check(failed_battle != null and failed_battle.get_script() == BattleControllerScript, "失败恢复测试通过正式 v2_battle.tscn 入口")
	if failed_battle == null:
		return
	_test_tree.root.add_child(failed_battle)
	await _wait_for_restore_failure(failed_battle, manager)
	t.check(failed_battle.turn_manager.current_phase == TurnManager.TurnPhase.BATTLE_OVER and failed_battle.turn_manager.input_locked, "失败恢复锁定战斗并走失败结果路径")
	t.check((manager.call("get_v2_encounter_checkpoint") as Dictionary).is_empty(), "失败恢复不会落入新战斗 cp_start 写入")
	t.check(String(manager.battle_result.get("defeat_reason", "")) == "checkpoint_restore_failed" and bool(manager.battle_result.get("v2_restore_error", false)), "失败恢复写入明确失败结果")
	t.check(failed_battle.player_units.is_empty() and failed_battle.enemy_units.is_empty(), "失败恢复不保留部分恢复 Unit roster")
	t.check(failed_battle.v2_hazard_controller == null and failed_battle.v2_encounter_activation == null and failed_battle.v2_interaction_service == null, "失败恢复清理 V2 运行时服务")
	# The real failure route swaps the scene; finish before this test owner is freed.
	t.finish(_test_tree)

func _start_fixture_battle(manager: Node) -> Node:
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "v2_hazard_runtime_fixture")
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))
	var battle := BattleScene.instantiate()
	t.check(battle != null and battle.get_script() == BattleControllerScript, "fixture 实例化正式 V2 battle scene")
	if battle == null:
		return null
	_test_tree.root.add_child(battle)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "fixture 等待到玩家行动阶段")
	if not ready:
		await _cleanup_battle(battle)
		return null
	return battle

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

func _has_hazard_overlay(battle: Node, kind: String, cell: Vector2i) -> bool:
	if battle == null or battle.effect_layer == null:
		return false
	return battle.effect_layer.get_node_or_null("V2HazardOverlay_%s_%d_%d" % [kind, cell.x, cell.y]) != null

func _wait_for_player_phase(battle: Node) -> bool:
	for _i in range(180):
		if battle != null and battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await _test_tree.process_frame
	return false

func _wait_for_restore_failure(battle: Node, manager: Node) -> void:
	for _i in range(90):
		if bool(manager.battle_result.get("v2_restore_error", false)):
			return
		if not is_instance_valid(battle):
			return
		await _test_tree.process_frame

func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		await _test_tree.process_frame

func _with_hash(snapshot: Dictionary) -> Dictionary:
	var next := snapshot.duplicate(true)
	next["timestamp"] = int(next.get("timestamp", 0))
	next.erase("hash")
	var body: Dictionary = next.duplicate(true)
	body.erase("timestamp")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(JSON.stringify(body).to_utf8_buffer())
	next["hash"] = hashing.finish().hex_encode()
	return next

func _stop_test_audio() -> void:
	AudioManager.stop_bgm()
	AudioManager.stop_ambient()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	AudioManager.audio_cache.clear()
	await _test_tree.process_frame
	AudioManager.stop_bgm()
	AudioManager.audio_cache.clear()
