extends Node

const BattleScene = preload("res://scenes/battle.tscn")
const BattleControllerScript = preload("res://scripts/game/battle_controller.gd")
const Checkpoint = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== V2 M112 M1 real route E2E ===")
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M112 找到正式 GameManager")
	if manager == null:
		t.finish(get_tree())
		return

	await _run_route(manager, "main_direct", false, false)
	await _run_route(manager, "optional_record", true, false)
	await _run_route(manager, "checkpoint_retry", false, true)
	await _stop_test_audio()
	t.finish(get_tree())

func _run_route(manager: Node, route_id: String, include_optional: bool, should_retry: bool) -> void:
	print("--- M112 route: ", route_id, " ---")
	var save: Dictionary = manager.call("begin_v2_new_game_for_test", 0)
	t.check(String(save.get("game_line", "")) == "v2_infiltration", route_id + " 使用 V2 独立存档")
	manager.set("current_level_id", "ch1_m1")
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))
	var battle := BattleScene.instantiate() as BattleController
	t.check(battle != null and battle.get_script() == BattleControllerScript, route_id + " 实例化正式 battle.tscn")
	if battle == null:
		return
	add_child(battle)
	await _dismiss_dialogue(manager)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, route_id + " 进入玩家行动阶段")
	if not ready:
		_cleanup_battle(battle)
		return

	var assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	t.check(assault != null and assault.job == "assault", route_id + " 找到突击兵")
	if assault == null:
		_cleanup_battle(battle)
		return
	# Keep the deterministic E2E focused on player-route contracts. Enemy
	# intent/impact is covered by the dedicated M1 combat tests; zeroing fixture
	# damage prevents a long route from being invalidated by a random defeat.
	for raw_enemy in battle.enemy_units:
		var fixture_enemy: Unit = raw_enemy
		if fixture_enemy != null:
			fixture_enemy.weapon_damage = [0, 0]
	battle.call("_select_unit", assault)
	# The south console is an optional observation action. Start its route from
	# the interaction radius, then let the real turn boundary restore the action
	# budget before the combat leg.
	assault.grid_pos = Vector2i(7, 10)
	battle.call("_update_unit_sprite_pos", assault, false)
	battle.call("refresh_visibility_transaction", &"m112_camera_setup")
	var camera_result := _commit_facility_action(battle, assault, "facility_camera_console_south")
	t.check(bool(camera_result.get("success", false)), route_id + " 通过正式设施事务观察摄像头")
	t.check(battle.alert_state.get_front_state() == &"searching", route_id + " 观察摄像头后进入搜索警戒")
	await _end_turn_and_wait(battle)

	var safe_move := _find_safe_move_target(battle, assault)
	t.check(safe_move.x >= 0, route_id + " 找到公开可行的安全移动格")
	if safe_move.x >= 0:
		var move_result: Dictionary = battle.call("request_move", safe_move)
		t.check(bool(move_result.get("success", false)) and bool(move_result.get("committed", false)), route_id + " 通过正式移动事务提交移动")

	var target: Unit = _prepare_attack_target(battle, assault)
	t.check(target != null, route_id + " 找到可见攻击目标")
	if target != null:
		var attack_preview: Dictionary = battle.call("request_attack_preview", target)
		t.check(bool(attack_preview.get("valid", false)), route_id + " 正式攻击预览有效")
		var attack_result: Dictionary = battle.call("confirm_locked_attack", target)
		t.check(bool(attack_result.get("success", false)), route_id + " 正式攻击事务成功")
		t.check(int(attack_result.get("hp_after", target.current_hp)) == target.current_hp, route_id + " 攻击结果与单位生命同步")

	var rescue_result := await _rescue_through_formal_service(battle, assault)
	t.check(bool(rescue_result.get("success", false)), route_id + " 通过正式营救事务救出侦察兵")
	var scout: Unit = rescue_result.get("new_unit", null)
	t.check(scout != null and battle.player_units.has(scout), route_id + " 侦察兵加入正式玩家队伍")
	t.check(String(battle.v2_mission_flow.get_state_name()) == "ESCORT_TO_EVAC", route_id + " 营救后进入护送撤离状态")

	if include_optional:
		var record_actor: Unit = scout if scout != null else assault
		if record_actor != null:
			record_actor.grid_pos = Vector2i(4, 5)
			battle.call("_update_unit_sprite_pos", record_actor, false)
			battle.call("refresh_visibility_transaction", &"m112_record_setup")
		var record_result := _commit_facility_action(battle, record_actor, "facility_optional_record")
		t.check(bool(record_result.get("success", false)), route_id + " 通过正式设施事务上传事故记录")
		t.check(bool(battle.v2_mission_flow.get_snapshot().get("optional_complete", false)), route_id + " 可选事故记录被正式记录")

	if should_retry:
		var checkpoint_saved: bool = bool(battle.call("_save_v2_checkpoint", &"cp_rescue"))
		t.check(checkpoint_saved, route_id + " 营救后正式保存检查点")
		var checkpoint: Dictionary = manager.call("get_v2_encounter_checkpoint")
		t.check(String(checkpoint.get("checkpoint_id", "")) == "cp_rescue", route_id + " 读取营救检查点")
		t.check(bool(Checkpoint.validate(checkpoint).get("valid", false)), route_id + " 检查点符合正式 schema")
		assault.current_hp = 1
		battle.call("_apply_v2_mission_event", &"primary_irreversible_failure")
		t.check(battle.v2_mission_flow.is_defeat(), route_id + " 正式失败事务进入失败状态")
		manager.set("pending_v2_checkpoint", checkpoint)
		var restored: bool = bool(battle.call("_restore_v2_checkpoint"))
		t.check(restored, route_id + " 正式战斗恢复营救检查点")
		t.check(String(battle.v2_mission_flow.get_state_name()) == "ESCORT_TO_EVAC", route_id + " 恢复后保留营救进度")
	else:
		var evac_result := await _complete_evacuation(battle, assault, scout)
		t.check(bool(evac_result.get("success", false)), route_id + " 通过正式移动事务抵达撤离点")
		t.check(battle.v2_mission_flow.is_victory(), route_id + " 正式撤离流程进入胜利状态")
		t.check(manager.battle_result.is_empty() or String(manager.battle_result.get("result", "")) != "defeat", route_id + " 胜利路线没有被错误标记为失败")

	_cleanup_battle(battle)
	await get_tree().process_frame

func _rescue_through_formal_service(battle: BattleController, assault: Unit) -> Dictionary:
	if assault == null:
		return {"success": false, "reason": &"assault_missing"}
	await _end_turn_and_wait(battle)
	var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_scout")
	assault.grid_pos = rescue_pos + Vector2i.LEFT
	battle.call("_update_unit_sprite_pos", assault, false)
	battle.call("refresh_visibility_transaction", &"m112_rescue_setup")
	var preview: Dictionary = battle.v2_rescue_controller.query_rescue(assault, &"rescue_scout")
	if not bool(preview.get("valid", false)):
		return preview
	var result: Dictionary = battle.v2_rescue_controller.commit_rescue(preview)
	await get_tree().process_frame
	return result

func _complete_evacuation(battle: BattleController, assault: Unit, scout: Unit) -> Dictionary:
	if assault == null or scout == null:
		return {"success": false, "reason": &"squad_incomplete"}
	var evac_center: Vector2i = battle.v2_mission_flow.get_snapshot().get("evac_center", Vector2i(-1, -1))
	if evac_center.x < 0:
		return {"success": false, "reason": &"evac_not_found"}
	# Keep the fixture close to the exit, then use the same public movement
	# transaction that the player uses to enter the zone.
	assault.grid_pos = evac_center + Vector2i.LEFT
	# Keep the scout outside the radius so the second public move is the
	# transaction that actually completes the all-controlled-units check.
	scout.grid_pos = evac_center + Vector2i(0, -2)
	battle.call("_update_unit_sprite_pos", assault, false)
	battle.call("_update_unit_sprite_pos", scout, false)
	battle.call("refresh_visibility_transaction", &"m112_evac_setup")
	battle.call("_select_unit", assault)
	var assault_move: Dictionary = battle.call("request_move", evac_center)
	if not bool(assault_move.get("success", false)):
		return assault_move
	battle.call("_select_unit", scout)
	var scout_move: Dictionary = battle.call("request_move", evac_center + Vector2i.UP)
	if not bool(scout_move.get("success", false)):
		return scout_move
	return {"success": battle.v2_mission_flow.is_victory()}

func _commit_facility_action(battle: BattleController, actor: Unit, facility_id: String) -> Dictionary:
	if actor == null:
		return {"success": false, "reason": &"actor_missing"}
	var actions: Array = battle.v2_interaction_service.query_actions(actor, facility_id)
	if actions.is_empty():
		return {"success": false, "reason": &"no_actions"}
	var action_id := String(actions[0].get("id", ""))
	var result: Dictionary = battle.v2_interaction_service.commit_action(actor, facility_id, action_id, battle.v2_interaction_service.get_state_revision())
	if bool(result.get("success", false)):
		battle.call("_apply_v2_interaction_result", result)
	return result

func _end_turn_and_wait(battle: BattleController) -> bool:
	var end_result: Dictionary = battle.call("request_end_turn")
	if not bool(end_result.get("success", false)):
		return false
	return await _wait_for_player_phase(battle, battle.turn_manager.turn_number + 1)

func _prepare_attack_target(battle: BattleController, player: Unit) -> Unit:
	for raw_enemy in battle.enemy_units:
		var enemy: Unit = raw_enemy
		if enemy == null or not enemy.is_alive:
			continue
		for cell in [player.grid_pos + Vector2i.RIGHT, player.grid_pos + Vector2i.LEFT, player.grid_pos + Vector2i.DOWN, player.grid_pos + Vector2i.UP]:
			if not GridSystem.is_in_bounds(cell, battle.map_width, battle.map_height):
				continue
			if battle.call("_get_unit_at", cell) != null:
				continue
			enemy.grid_pos = cell
			battle.call("_update_unit_sprite_pos", enemy, false)
			battle.call("refresh_visibility_transaction", &"m112_attack_setup")
			var preview: Dictionary = battle.call("_query_v2_attack_preview", enemy)
			if bool(preview.get("valid", false)):
				return enemy
	return null

func _find_safe_move_target(battle: BattleController, player: Unit) -> Vector2i:
	for raw_cell in battle.reachable_cells.keys():
		var cell: Vector2i = raw_cell
		if cell == player.grid_pos:
			continue
		var preview: Dictionary = battle.v2_action_service.query_action({"action": &"move", "unit": player, "target": cell})
		if bool(preview.get("valid", false)) and not bool(preview.get("dangerous", false)):
			return cell
	return Vector2i(-1, -1)

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

func _dismiss_dialogue(manager: Node) -> void:
	for _i in range(60):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _wait_for_player_phase(battle: BattleController, minimum_turn: int = 1) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION and battle.turn_manager.turn_number >= minimum_turn:
			return true
		await get_tree().process_frame
	return false

func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.call("_cleanup_units")
		battle.free()
	await get_tree().process_frame
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
	await get_tree().process_frame
