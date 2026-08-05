extends Node

const Runner = preload("res://tests/v2/test_runner.gd")
const Checkpoint = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const MissionResultScene = preload("res://scenes/mission_result.tscn")
const BattleScene = preload("res://scenes/battle.tscn")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M109 正式场景找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	t.check(manager.has_method("set_v2_encounter_checkpoint"), "正式入口提供 V2 检查点写入")
	t.check(manager.has_method("restart_v2_mission"), "正式入口提供 V2 任务重开")
	var snapshot := Checkpoint.capture({
		"game_line": "v2_infiltration",
		"level_id": "ch1_m1",
		"encounter_id": "cp_rescue",
		"checkpoint_id": "cp_rescue",
		"turn": 3,
		"player_units": [],
		"enemy_units": [],
		"alert_state": {},
		"visibility_state": {},
		"facilities": [],
		"mission_flow": {},
		"enemy_intents": {},
		"turn_state": {},
		"extra": {},
	})
	t.check(bool(manager.call("set_v2_encounter_checkpoint", snapshot)), "正式 V2 存档写入检查点")
	t.check(String((manager.call("get_v2_encounter_checkpoint") as Dictionary).get("checkpoint_id", "")) == "cp_rescue", "正式 V2 存档读取检查点")

	manager.set("battle_result", {
		"result": "defeat",
		"level_id": "ch1_m1",
		"defeat_reason": "all_units_down",
		"has_encounter_checkpoint": true,
		"turns": 3,
		"units_survived": 0,
		"units_total": 1,
		"rewards": {},
	})
	var result_screen := MissionResultScene.instantiate()
	add_child(result_screen)
	await get_tree().process_frame
	t.check(bool(result_screen.get_node("Panel/Buttons/EncounterRetryButton").visible), "失败页显示检查点重试")
	t.check(bool(result_screen.get_node("Panel/Buttons/RetryButton").visible), "失败页显示任务重开")
	t.check(bool(result_screen.get_node("Panel/Buttons/BaseButton").visible), "失败页显示返回基地")
	var actions: Array = result_screen.call("get_failure_actions", true)
	t.check(actions == [&"retry_checkpoint", &"restart_mission", &"return_base"], "失败页三出口顺序稳定")
	result_screen.queue_free()
	await get_tree().process_frame
	var battle := BattleScene.instantiate()
	add_child(battle)
	await _dismiss_intro(manager)
	var battle_ready := await _wait_for_player_phase(battle)
	t.check(battle_ready, "正式 battle 可进入玩家阶段进行重试恢复")
	if battle_ready:
		var assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
		t.check(assault != null, "重试恢复测试找到突击兵")
		if assault != null:
			var saved_pos := assault.grid_pos
			var saved_hp := assault.current_hp
			var checkpoint_result: bool = bool(battle.call("_save_v2_checkpoint", &"cp_start"))
			var retry_snapshot: Dictionary = manager.call("get_v2_encounter_checkpoint")
			assault.grid_pos = saved_pos + Vector2i(2, 0)
			assault.current_hp = 1
			manager.set("pending_v2_checkpoint", retry_snapshot)
			var restored: bool = bool(battle.call("_restore_v2_checkpoint"))
			t.check(checkpoint_result and restored, "正式 battle 接受并恢复检查点")
			t.check(assault.grid_pos == saved_pos and assault.current_hp == saved_hp, "检查点恢复位置和生命而非从起点重开")
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
	await get_tree().process_frame
	manager.call("clear_v2_encounter_checkpoint")
	t.check((manager.call("get_v2_encounter_checkpoint") as Dictionary).is_empty(), "正式入口清除检查点")
	t.finish(get_tree())

func _dismiss_intro(manager: Node) -> void:
	for _i in range(60):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _wait_for_player_phase(battle: Node) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await get_tree().process_frame
	return false
