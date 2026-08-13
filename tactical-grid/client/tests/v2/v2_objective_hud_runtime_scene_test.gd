extends Node

const BattleScene = preload("res://scenes/v2_battle.tscn")
const BattleControllerScript = preload("res://scripts/v2/runtime/v2_battle_controller.gd")
const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== V2 objective HUD runtime scene regression ===")
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "HUD 场景测试找到正式 GameManager")
	if manager == null:
		t.finish(get_tree())
		return

	await _assert_controller_mapping(manager)
	await _assert_m1_rescue_and_pre_evac(manager)
	await _stop_test_audio()
	t.finish(get_tree())

func _assert_controller_mapping(manager: Node) -> void:
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "v2_hazard_runtime_fixture")
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))
	var battle := BattleScene.instantiate()
	t.check(battle != null and battle.get_script() == BattleControllerScript, "映射测试实例化正式 V2 battle scene")
	if battle == null:
		return
	add_child(battle)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "映射测试进入真实 V2 fixture 玩家回合")
	if not ready:
		await _cleanup_battle(battle)
		return
	var snapshot: Dictionary = battle.v2_hud_presenter.last_snapshot
	t.check(String(snapshot.get("mission_id", "")) == "v2_hazard_runtime_fixture", "控制器快照填充 mission_id")
	t.check(not String(snapshot.get("objective_text", "")).is_empty() or not String(snapshot.get("guide_text", "")).is_empty(), "控制器快照填充 objective/guide")
	t.check(String(snapshot.get("route_hint", "")) == "沿测试路线前进", "控制器快照填充 route_hint")
	t.check(String(snapshot.get("hazard_warning", "")).contains("危险区"), "控制器快照填充 hazard_warning")
	t.check(String(snapshot.get("checkpoint_id", "")) == "cp_start", "控制器快照填充 checkpoint_id")
	t.check(int(snapshot.get("turn", 0)) == 1 and int(snapshot.get("current_turn", 0)) == 1, "控制器快照填充 turn/current_turn")
	var guide := battle.hud.get_node_or_null("BottomBar/V2DirectControlGuide") as Label
	t.check(battle.hud.objective_label.text != "" and battle.hud.turn_label.text == "回合 1", "真实 HUD 控件显示任务与回合")
	t.check(guide != null and guide.text.contains("路线：沿测试路线前进") and guide.text.contains("检查点：cp_start"), "真实 HUD 控件显示路线与检查点")
	t.check(guide != null and guide.text.contains("危险："), "真实 HUD 控件显示危险提示")
	await _cleanup_battle(battle)

func _assert_m1_rescue_and_pre_evac(manager: Node) -> void:
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))
	var battle := BattleScene.instantiate()
	t.check(battle != null and battle.get_script() == BattleControllerScript, "M1 HUD 测试实例化正式 V2 battle scene")
	if battle == null:
		return
	add_child(battle)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "M1 HUD 测试进入真实玩家回合")
	if not ready:
		await _cleanup_battle(battle)
		return
	t.check(battle.turn_manager.max_turns == 24, "V2 M1 使用独立 24 回合预算")
	t.check(battle.mission_objective_state.is_enemy_passive(3) and not battle.mission_objective_state.is_enemy_passive(4), "V2 M1 前三回合敌人保持教学宽限")
	t.check(bool(battle.call("_is_v2_enemy_turn_passive")), "V2 敌人回合实际读取前三回合安全教学")
	battle.turn_manager.turn_number = 4
	t.check(not bool(battle.call("_is_v2_enemy_turn_passive")), "V2 第四回合恢复敌方行动")
	battle.turn_manager.turn_number = 1
	var initial: Dictionary = battle.v2_hud_presenter.last_snapshot
	t.check(String(initial.get("step_id", "")) == "search_route_split" and int(initial.get("step_index", -1)) == 0 and int(initial.get("step_count", -1)) == 5, "M1 路线分叉前真实 HUD 快照为 1/5")
	t.check(initial.get("guide_cell", Vector2i(-1, -1)) == Vector2i(8, 14), "M1 快照提供当前目标坐标")
	t.check(battle.hud.objective_label.text.contains("1/5") and battle.hud.get_node("BottomBar/V2DirectControlGuide").text.contains("流程 1/5"), "M1 路线分叉前真实 HUD 控件显示 1/5")
	var mission_card := battle.hud.get_node_or_null("V2MissionCard") as Panel
	t.check(mission_card != null and mission_card.visible and String(mission_card.get_node("MissionCardText").text).contains("黄色分叉标记"), "M1 HUD 显示持久任务卡和具体目的地")
	var guidance := battle.get_node_or_null("V2ObjectiveGuidance") as Node2D
	var beacon := guidance.get_node_or_null("V2ObjectiveBeacon") if guidance != null else null
	t.check(beacon != null, "M1 地图显示下一步目标信标")
	var initial_assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	var route_line := guidance.get_node_or_null("V2ObjectiveRoute") as Line2D if guidance != null else null
	t.check(route_line != null and route_line.points.size() > 1 and initial_assault != null and route_line.points.size() <= initial_assault.move_points + 1, "M1 路线指引只显示本回合可达路径")
	var assault: Unit = initial_assault
	if assault != null and battle.v2_rescue_controller != null:
		assault.grid_pos = Vector2i(8, 14)
		battle.call("_update_unit_sprite_pos", assault, false)
		battle.call("_apply_v2_mission_event", &"entered_route_split", {"position": assault.grid_pos})
		battle.call("_on_v2_route_selected", "cargo_breakthrough")
		assault.grid_pos = Vector2i(12, 5)
		battle.call("_update_unit_sprite_pos", assault, false)
		battle.call("refresh_visibility_transaction", &"m1_hud_gantry")
		var gantry_actions: Array = battle.v2_interaction_service.query_actions(assault, "facility_gantry")
		var gantry_result: Dictionary = {}
		if not gantry_actions.is_empty():
			var gantry_action_id := String(gantry_actions[0].get("id", ""))
			gantry_result = battle.v2_interaction_service.commit_action(assault, "facility_gantry", gantry_action_id, battle.v2_interaction_service.get_state_revision())
			if bool(gantry_result.get("success", false)):
				battle.call("_apply_v2_interaction_result", gantry_result)
		t.check(bool(gantry_result.get("success", false)), "M1 HUD 测试通过正式事务打开吊桥")
		assault.begin_v2_turn()
		var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_scout")
		assault.grid_pos = rescue_pos + Vector2i.LEFT
		battle.call("_update_visibility")
		var preview: Dictionary = battle.v2_rescue_controller.query_rescue(assault, &"rescue_scout")
		var rescue: Dictionary = battle.v2_rescue_controller.commit_rescue(preview) if bool(preview.get("valid", false)) else preview
		await get_tree().process_frame
		t.check(bool(rescue.get("success", false)), "M1 真实营救事务成功")
		var rescued_snapshot: Dictionary = battle.v2_hud_presenter.last_snapshot
		t.check(String(rescued_snapshot.get("step_id", "")) == "evacuate_squad" and int(rescued_snapshot.get("step_index", -1)) == 4 and int(rescued_snapshot.get("step_count", -1)) == 5, "M1 营救后撤离真实 HUD 快照为 5/5")
		var evac_center: Vector2i = battle.v2_mission_flow.get_snapshot().get("evac_center", Vector2i(-1, -1))
		assault.grid_pos = evac_center + Vector2i.LEFT
		battle.call("_update_unit_sprite_pos", assault, false)
		battle.call("_update_visibility")
		battle.selected_unit = assault
		var evac_move: Dictionary = battle.request_move(evac_center)
		await get_tree().process_frame
		t.check(bool(evac_move.get("success", false)) and bool(evac_move.get("committed", false)), "M1 真实首名队员进入撤离区")
		var pre_evac_snapshot: Dictionary = battle.v2_hud_presenter.last_snapshot
		t.check(String(pre_evac_snapshot.get("checkpoint_id", "")) == "cp_rescue" and String(pre_evac_snapshot.get("step_id", "")) == "evacuate_squad", "M1 pre-evac 真实 HUD 快照保留撤离阶段和检查点")
		t.check(battle.hud.objective_label.text.contains("5/5") and battle.hud.get_node("BottomBar/V2DirectControlGuide").text.contains("流程 5/5") and battle.hud.get_node("BottomBar/V2DirectControlGuide").text.contains("检查点：cp_rescue"), "M1 pre-evac 真实 HUD 控件显示 5/5 与检查点")
	await _cleanup_battle(battle)

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

func _wait_for_player_phase(battle: Node) -> bool:
	for _i in range(180):
		if battle != null and battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
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
