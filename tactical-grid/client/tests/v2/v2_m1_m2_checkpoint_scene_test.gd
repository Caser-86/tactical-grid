extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const BattleScene = preload("res://scenes/v2_battle.tscn")
const BattleControllerScript = preload("res://scripts/v2/runtime/v2_battle_controller.gd")
const Checkpoint = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const MissionResultScene = preload("res://scenes/mission_result.tscn")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "Task 3 找到正式 GameManager")
	if manager == null:
		t.finish(get_tree())
		return

	await _run_level(manager, "ch1_m1", [
		{"id": "cp_start", "step": "find_scout", "flag": "mission_started", "rescue": "scout"},
		{"id": "cp_rescue", "step": "evacuate_squad", "flag": "scout_rescued", "rescue": "scout"},
		{"id": "cp_pre_evac", "step": "evacuate_squad", "flag": "scout_rescued", "rescue": ""},
	])
	await _run_level(manager, "ch1_m2", [
		{"id": "cp_start", "step": "rescue_sniper", "flag": "lockdown_cleared", "rescue": "sniper"},
		{"id": "cp_rescue", "step": "show_sniper_ability", "flag": "sniper_rescued", "rescue": "sniper"},
		{"id": "cp_pre_evac", "step": "evacuate_squad", "flag": "engineer_countermeasure_started", "rescue": ""},
	])
	_assert_failure_screen_and_v2_isolation(manager)
	await _stop_test_audio()
	t.finish(get_tree())

func _run_level(manager: Node, level_id: String, checkpoints: Array) -> void:
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", level_id)
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))
	var battle := await _start_battle(manager)
	if battle == null:
		return
	t.check(battle.get_script() == BattleControllerScript, level_id + " 使用 V2 战斗控制器，不进入 V1")
	var start_snapshot: Dictionary = manager.call("get_v2_encounter_checkpoint")
	t.check(String(start_snapshot.get("game_line", "")) == "v2_infiltration", level_id + " 开场检查点使用 V2 存档身份")
	for checkpoint in checkpoints:
		var checkpoint_id := String(checkpoint.get("id", ""))
		if checkpoint_id == "cp_start":
			_apply_stage_before_checkpoint(battle, level_id, checkpoint)
		elif checkpoint_id == "cp_rescue":
			_apply_rescue_checkpoint(battle, level_id, String(checkpoint.get("rescue", "")))
		else:
			_apply_pre_evac_checkpoint(battle, level_id)
		var saved: bool = bool(battle.call("_save_v2_checkpoint", StringName(checkpoint_id)))
		t.check(saved, level_id + " " + checkpoint_id + " 通过正式 V2 保存入口写入")
		var snapshot: Dictionary = manager.call("get_v2_encounter_checkpoint")
		t.check(String(snapshot.get("checkpoint_id", "")) == checkpoint_id, level_id + " " + checkpoint_id + " 检查点 ID 稳定")
		t.check(String(snapshot.get("game_line", "")) == "v2_infiltration" and bool(Checkpoint.validate(snapshot).get("valid", false)), level_id + " " + checkpoint_id + " schema/hash 有效")
		var flow_snapshot: Dictionary = snapshot.get("mission_flow", {})
		t.check(String(flow_snapshot.get("step_id", "")) == String(checkpoint.get("step", "")), level_id + " " + checkpoint_id + " 恢复目标阶段正确")
		t.check(bool((flow_snapshot.get("mission_flags", {}) as Dictionary).get(String(checkpoint.get("flag", "")), false)), level_id + " " + checkpoint_id + " 保存关键任务旗标")
		var expected_step_id := String(flow_snapshot.get("step_id", ""))
		await _restore_checkpoint_in_fresh_v2_scene(manager, battle, snapshot, level_id, checkpoint_id, expected_step_id)
		battle = get_node_or_null("V2CheckpointBattle")
		if battle == null:
			return
	_cleanup_battle(battle)
	await get_tree().process_frame
func _apply_stage_before_checkpoint(battle: Node, level_id: String, checkpoint: Dictionary) -> void:
	if level_id == "ch1_m1":
		battle.call("_apply_v2_mission_event", &"mission_started")
	else:
		battle.call("_apply_v2_mission_event", &"lockdown_cleared", {"route_id": "west_maintenance"})

func _apply_rescue_checkpoint(battle: Node, level_id: String, rescue_id: String) -> void:
	var unit_id := "player_" + rescue_id
	var rescue_position := Vector2i(15, 8) if rescue_id == "scout" else Vector2i(19, 5)
	var rescued := _make_rescue_unit(rescue_id, unit_id, rescue_position)
	t.check(rescued != null, level_id + " 创建检查点用营救队员")
	if rescued == null:
		return
	if level_id == "ch1_m1":
		var located: Dictionary = battle.call("_apply_v2_mission_event", &"scout_located", {"position": rescue_position, "unit_id": "player_%s" % rescue_id})
		t.check(bool(located.get("success", false)), level_id + " 找到侦察兵后推进营救步骤")
	battle.call("_register_v2_rescued_unit", rescued)
	var result: Dictionary = battle.call("_apply_v2_mission_event", &"character_rescued", {
		"character_id": rescue_id,
		"new_unit": rescued,
		"unit_id": unit_id,
		"position": rescue_position,
	})
	t.check(bool(result.get("success", false)), level_id + " 营救事件写入检查点任务状态")

func _apply_pre_evac_checkpoint(battle: Node, _level_id: String) -> void:
	if _level_id == "ch1_m2":
		battle.call("_apply_v2_mission_event", &"sniper_ability_showcase", {"sniper_lines_visible": true})
	battle.call("_apply_v2_mission_event", &"evac_route_opened")
	battle.call("_apply_v2_mission_event", &"evac_intercept_started", {"enemy_ids": ["m2_sniper_exit", "m2_drone_exit"]})
	battle.call("_apply_v2_mission_event", &"engineer_countermeasure_started", {"enemy_ids": ["m2_sniper_exit", "m2_drone_exit"]})

func _restore_checkpoint_in_fresh_v2_scene(manager: Node, source: Node, snapshot: Dictionary, level_id: String, checkpoint_id: String, expected_step_id: String) -> void:
	_cleanup_battle(source)
	await get_tree().process_frame
	manager.set("current_level_id", level_id)
	manager.set("pending_v2_checkpoint", snapshot)
	var restored := BattleScene.instantiate()
	restored.name = "V2CheckpointBattle"
	t.check(restored != null and restored.get_script() == BattleControllerScript, level_id + " " + checkpoint_id + " 从正式 V2 场景恢复")
	if restored == null:
		return
	add_child(restored)
	var ready := await _wait_for_player_phase(restored)
	t.check(ready, level_id + " " + checkpoint_id + " 恢复后进入玩家阶段")
	if not ready:
		return
	t.check(String(restored.get("v2_last_checkpoint_id")) == checkpoint_id, level_id + " " + checkpoint_id + " 恢复后保留检查点身份")
	var restored_flow: Variant = restored.get("v2_mission_flow")
	t.check(restored_flow != null and String(restored_flow.get_current_step_id()) == expected_step_id, level_id + " " + checkpoint_id + " 恢复任务步骤")
	t.check(_unique_live_positions(restored.get("player_units")), level_id + " " + checkpoint_id + " 恢复后玩家单位不重合")
	t.check(restored.get("v2_encounter_activation") != null and restored.get("v2_interaction_service") != null, level_id + " " + checkpoint_id + " 恢复 V2 遭遇和设施服务")

func _assert_failure_screen_and_v2_isolation(manager: Node) -> void:
	var checkpoint: Dictionary = manager.call("get_v2_encounter_checkpoint")
	manager.set("battle_result", {
		"result": "defeat",
		"level_id": "ch1_m2",
		"defeat_reason": "all_units_down",
		"has_encounter_checkpoint": true,
		"turns": 8,
		"units_survived": 0,
		"units_total": 2,
		"rewards": {},
	})
	var result_screen := MissionResultScene.instantiate()
	add_child(result_screen)
	await get_tree().process_frame
	for button_name in ["EncounterRetryButton", "RetryButton", "BaseButton"]:
		var button := result_screen.get_node("Panel/Buttons/" + button_name) as Button
		t.check(button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE, "失败页 %s 可见、启用且可聚焦" % button_name)
	t.check(result_screen.get_node("Panel/Buttons/EncounterRetryButton").text == "从检查点重试", "失败页检查点按钮文案明确")
	t.check(result_screen.get_node("Panel/Buttons/RetryButton").text == "重新开始任务", "失败页重开按钮文案明确")
	t.check(result_screen.get_node("Panel/Buttons/BaseButton").text == "返回基地", "失败页返回按钮文案明确")
	t.check(result_screen.call("get_failure_actions", true) == [&"retry_checkpoint", &"restart_mission", &"return_base"], "失败页三种出口顺序稳定")
	if result_screen != null and is_instance_valid(result_screen):
		result_screen.queue_free()
	await get_tree().process_frame
	var v1_snapshot := checkpoint.duplicate(true)
	v1_snapshot["game_line"] = "v1_legacy"
	v1_snapshot.erase("hash")
	var v1_validation: Dictionary = Checkpoint.validate(v1_snapshot)
	t.check(not bool(v1_validation.get("valid", true)), "V1 检查点不能进入 V2 恢复入口")
	manager.call("clear_v2_encounter_checkpoint")
	t.check((manager.call("get_v2_encounter_checkpoint") as Dictionary).is_empty(), "失败测试结束后清除 V2 检查点")

func _make_rescue_unit(character_id: String, entity_id: String, position: Vector2i) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.unit_name = character_id
	unit.team = "player"
	unit.job = character_id
	unit.grid_pos = position
	unit.max_hp = 8
	unit.current_hp = 8
	unit.is_alive = true
	unit.is_downed = false
	unit.enable_v2_turn_mode()
	unit.begin_v2_turn()
	return unit

func _start_battle(manager: Node) -> Node:
	var battle := BattleScene.instantiate()
	if battle == null:
		return null
	add_child(battle)
	await _dismiss_dialogue(manager)
	if not await _wait_for_player_phase(battle):
		_cleanup_battle(battle)
		return null
	return battle

func _wait_for_player_phase(battle: Node) -> bool:
	for _i in range(180):
		if battle != null and battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await get_tree().process_frame
	return false

func _dismiss_dialogue(manager: Node) -> void:
	for _i in range(60):
		await get_tree().process_frame
		var dialogue: Variant = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _cleanup_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.call("_cleanup_units")
		battle.free()

func _unique_live_positions(units: Array) -> bool:
	var seen: Dictionary = {}
	for raw_unit in units:
		var unit: Unit = raw_unit
		if unit == null or not unit.is_alive:
			continue
		if seen.has(unit.grid_pos):
			return false
		seen[unit.grid_pos] = true
	return true

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

func _stop_test_audio() -> void:
	AudioManager.stop_bgm()
	AudioManager.stop_ambient()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	AudioManager.audio_cache.clear()
	await get_tree().process_frame
