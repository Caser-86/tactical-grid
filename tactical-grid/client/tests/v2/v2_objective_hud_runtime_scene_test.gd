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
	await _assert_camera_return_controls(manager)
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

func _assert_camera_return_controls(manager: Node) -> void:
	manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))
	var battle := BattleScene.instantiate()
	t.check(battle != null and battle.get_script() == BattleControllerScript, "摄像头返回测试实例化正式 V2 battle scene")
	if battle == null:
		return
	add_child(battle)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "摄像头返回测试进入真实玩家回合")
	if not ready:
		await _cleanup_battle(battle)
		return
	var player: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	battle.selected_unit = player
	var selected_before: Unit = battle.selected_unit
	var return_button := battle.hud.get_node_or_null("V2CameraReturnButton") as Button
	t.check(return_button != null and not return_button.visible, "普通 V2 状态隐藏摄像头返回控件")

	var inspection: Dictionary = battle.begin_v2_camera_inspection(Vector2i(15, 5), 7)
	await get_tree().process_frame
	t.check(bool(inspection.get("success", false)) and battle.is_v2_camera_inspecting(), "摄像头查看进入独立导航状态")
	t.check(return_button != null and return_button.visible and return_button.text == "返回队员 [F]", "摄像头查看显示紧凑返回控件")
	var viewport_center := get_viewport().get_visible_rect().get_center()
	t.check(return_button != null and return_button.mouse_filter == Control.MOUSE_FILTER_STOP and not return_button.get_global_rect().has_point(viewport_center), "返回控件只消费自身点击且不遮挡地图中心")

	var f_key := InputEventKey.new()
	f_key.keycode = KEY_F
	f_key.physical_keycode = KEY_F
	f_key.pressed = true
	battle._input(f_key)
	await get_tree().process_frame
	t.check(not battle.is_v2_camera_inspecting() and battle.selected_unit == selected_before, "F 返回当前队员且保留普通 V2 选择")
	t.check(return_button != null and not return_button.visible, "F 返回后隐藏摄像头返回控件")

	battle.begin_v2_camera_inspection(Vector2i(15, 5), 7)
	return_button.emit_signal("pressed")
	await get_tree().process_frame
	t.check(not battle.is_v2_camera_inspecting() and battle.selected_unit == selected_before, "HUD 返回控件不改变普通 V2 选择")

	battle.begin_v2_camera_inspection(Vector2i(15, 5), 7)
	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	battle._input(escape_key)
	await get_tree().process_frame
	t.check(not battle.is_v2_camera_inspecting() and battle.selected_unit == selected_before, "Esc 返回当前队员且保留普通 V2 选择")

	battle.begin_v2_camera_inspection(Vector2i(15, 5), 7)
	var camera_facility: Dictionary = _find_camera_facility(battle.v2_mission_flow.map_data)
	t.check(String(camera_facility.get("type", "")) == "camera", "M1 运行时提供可重复点击的摄像头设施")
	var camera_cell: Vector2i = camera_facility.get("position", Vector2i(-1, -1))
	battle.call("_on_v2_cell_left_clicked", camera_cell)
	await get_tree().process_frame
	t.check(not battle.is_v2_camera_inspecting(), "重复点击摄像头设施返回当前队员")
	t.check(battle.selected_unit == selected_before, "重复点击摄像头设施保留普通 V2 选择")
	await _cleanup_battle(battle)

func _find_camera_facility(map: Dictionary) -> Dictionary:
	for raw_facility in map.get("facilities", []):
		if not raw_facility is Dictionary:
			continue
		var facility: Dictionary = raw_facility
		if String(facility.get("type", "")) == "camera":
			return {
				"type": "camera",
				"position": Vector2i(int(facility.get("x", -1)), int(facility.get("y", -1))),
			}
	return {}

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
	t.check(battle.mission_objective_state.is_enemy_passive(3) and not battle.mission_objective_state.is_enemy_passive(4), "V2 M1 保留旧任务宽限配置供兼容读取")
	t.check(bool(battle.call("_is_v2_m1_tutorial_safety_active")), "V2 M1 前三回合启用非阻塞安全教学窗口")
	t.check(not bool(battle.call("_is_v2_enemy_turn_passive")), "V2 安全教学期敌人仍执行可观察意图")
	t.check(not battle.turn_manager.input_locked, "V2 非模态教学不锁定地图输入")
	var tutorial_hint: Dictionary = battle.v2_tutorial_flow.get_hint()
	t.check(tutorial_hint.get("visible", false) and tutorial_hint.get("text", "") == "选择突击兵" and tutorial_hint.get("anchor_kind", "") == "unit", "V2 快照提供第一条单位锚定教学提示")
	var tutorial_panel := battle.hud.get_node_or_null("V2TutorialHint") as Panel
	t.check(tutorial_panel != null and tutorial_panel.visible and tutorial_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "V2 HUD 显示非模态教学卡且不拦截地图")
	battle.turn_manager.turn_number = 4
	t.check(not bool(battle.call("_is_v2_m1_tutorial_safety_active")), "V2 第四回合关闭安全教学窗口")
	t.check(not bool(battle.call("_is_v2_enemy_turn_passive")), "V2 第四回合恢复敌方行动")
	battle.turn_manager.turn_number = 1
	var sentry: Unit = null
	for raw_enemy in battle.enemy_units:
		var candidate: Unit = raw_enemy
		if candidate != null and candidate.is_alive and candidate.job == "sentry":
			sentry = candidate
			break
	var assault_for_safety: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	if sentry != null and assault_for_safety != null:
		assault_for_safety.current_hp = 2
		var safe_damage := int(battle.call("_v2_tutorial_safe_damage", sentry, assault_for_safety, 5))
		t.check(safe_damage == 1, "V2 安全教学只允许哨兵把突击兵压到 1 HP")
		assault_for_safety.current_hp = assault_for_safety.max_hp
	var initial: Dictionary = battle.v2_hud_presenter.last_snapshot
	t.check(String(initial.get("step_id", "")) == "find_scout" and int(initial.get("step_index", -1)) == 0 and int(initial.get("step_count", -1)) == 3, "M1 正式营救流程真实 HUD 快照为 1/3")
	t.check(String(initial.get("guide_text", "")).contains("青色侦察标记") and String(initial.get("guide_text", "")).contains("靠近"), "M1 快照提供明确搜索目标与动作")
	t.check(battle.hud.objective_label.text.contains("1/3") and battle.hud.get_node("BottomBar/V2DirectControlGuide").text.contains("流程 1/3"), "M1 正式营救流程真实 HUD 控件显示 1/3")
	var mission_card := battle.hud.get_node_or_null("V2MissionCard") as Panel
	t.check(mission_card != null and mission_card.visible and String(mission_card.get_node("MissionCardText").text).contains("青色侦察标记"), "M1 HUD 显示持久营救任务卡和具体目标")
	var guidance := battle.get_node_or_null("V2ObjectiveGuidance") as Node2D
	var initial_assault: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	t.check(guidance != null, "M1 地图保留目标指引层供任务标记使用")
	var assault: Unit = initial_assault
	if assault != null and battle.v2_rescue_controller != null:
		var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_scout")
		assault.grid_pos = rescue_pos + Vector2i.LEFT
		battle.call("_update_unit_sprite_pos", assault, false)
		battle.call("_update_visibility")
		var located: Dictionary = battle.call("_apply_v2_mission_event", &"scout_located", {"position": rescue_pos, "unit_id": assault.entity_id})
		t.check(bool(located.get("success", false)) and battle.v2_mission_flow.get_current_step_id() == "rescue_scout", "M1 正式流程靠近标记后进入营救阶段")
		var preview: Dictionary = battle.v2_rescue_controller.query_rescue(assault, &"rescue_scout")
		var rescue: Dictionary = battle.v2_rescue_controller.commit_rescue(preview) if bool(preview.get("valid", false)) else preview
		await get_tree().process_frame
		t.check(bool(rescue.get("success", false)), "M1 真实营救事务成功")
		var rescued_snapshot: Dictionary = battle.v2_hud_presenter.last_snapshot
		t.check(String(rescued_snapshot.get("step_id", "")) == "evacuate_squad" and int(rescued_snapshot.get("step_index", -1)) == 2 and int(rescued_snapshot.get("step_count", -1)) == 3, "M1 营救后撤离真实 HUD 快照为 3/3")
		var evac_center: Vector2i = battle.v2_mission_flow.get_snapshot().get("evac_center", Vector2i(-1, -1))
		assault.grid_pos = evac_center + Vector2i.LEFT
		battle.call("_update_unit_sprite_pos", assault, false)
		battle.call("_update_visibility")
		battle.selected_unit = assault
		var evac_move: Dictionary = battle.request_move(evac_center)
		await get_tree().process_frame
		t.check(bool(evac_move.get("success", false)) and bool(evac_move.get("committed", false)), "M1 真实首名队员进入撤离区")
		var pre_evac_snapshot: Dictionary = battle.v2_hud_presenter.last_snapshot
		t.check(String(pre_evac_snapshot.get("checkpoint_id", "")) == "cp_rescue" and String(pre_evac_snapshot.get("step_id", "")) == "evacuate_squad", "M1 首名队员进入撤离区后仍保留营救检查点")
		t.check(battle.hud.objective_label.text.contains("3/3") and battle.hud.get_node("BottomBar/V2DirectControlGuide").text.contains("流程 3/3") and battle.hud.get_node("BottomBar/V2DirectControlGuide").text.contains("检查点：cp_rescue"), "M1 首名队员进入撤离区后保留撤离阶段与检查点")
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
