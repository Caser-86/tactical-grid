extends Node

const BattleScene = preload("res://scenes/v2_battle.tscn")
const MissionResultScene = preload("res://scenes/mission_result.tscn")
const VisualMode = preload("res://scripts/v2/presentation/v2_visual_mode.gd")
const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()
var target_size := Vector2i(1280, 720)
var visual_mode := "normal"
var stage := "start"
var output_path := ""
var _explicit_output := false
var _result_layer: CanvasLayer

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_user_args()
	if output_path.is_empty() or not _explicit_output:
		output_path = "res://../artifacts/v2/verification/m1-graybox/screenshots/%dx%d_%s_%s.png" % [target_size.x, target_size.y, visual_mode, stage]
	get_window().size = target_size
	get_viewport().size = target_size

	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M112 视觉矩阵找到正式 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	var save: Dictionary = manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m1")
	manager.set("current_save", _with_known_tutorials(save))
	var settings: Dictionary = manager.get("current_save").get("settings", {}).duplicate(true)
	settings["visual_mode"] = visual_mode
	manager.get("current_save")["settings"] = settings
	VisualMode.apply(settings)
	AccessibilitySettings.apply_settings(settings)

	var battle := BattleScene.instantiate() as BattleController
	t.check(battle != null, "M112 视觉矩阵实例化正式 battle.tscn")
	if battle == null:
		t.finish(get_tree())
		return
	add_child(battle)
	await _dismiss_dialogue(manager)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "M112 视觉矩阵进入玩家行动阶段")
	if not ready:
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return
	_dismiss_tutorial_hint(battle)

	if stage == "result":
		battle.hide()
		battle.hud.hide()
		_result_layer = CanvasLayer.new()
		_result_layer.layer = 200
		add_child(_result_layer)
		await _prepare_result(manager, _result_layer)
	else:
		await _prepare_battle_stage(manager, battle)
	_dismiss_tutorial_hint(battle)
	if stage != "result":
		battle.camera.toggle_overview()
		await get_tree().process_frame
		await get_tree().process_frame

	var viewport_texture := get_viewport().get_texture()
	if DisplayServer.get_name() == "headless" or viewport_texture == null:
		# Godot's dummy headless driver has no readable framebuffer. The real
		# matrix runner uses the Windows compatibility renderer; keep the gate
		# useful by validating the stage contract without fabricating a PNG.
		t.check(DisplayServer.get_name() == "headless", "M112 无头驱动明确报告无 framebuffer")
		_validate_stage(manager, battle)
		await _cleanup_battle(battle)
		var headless_result := get_node_or_null("V2VisualResult")
		if headless_result != null and is_instance_valid(headless_result):
			headless_result.queue_free()
		await _stop_test_audio()
		t.finish(get_tree())
		return
	var image := viewport_texture.get_image()
	t.check(image != null and not image.is_empty(), "M112 %s 生成非空视觉快照" % stage)
	if image == null or image.is_empty():
		t.finish(get_tree())
		return
	t.check(image.get_width() == target_size.x and image.get_height() == target_size.y, "M112 %s 快照尺寸为 %dx%d" % [stage, target_size.x, target_size.y])
	_validate_stage(manager, battle)
	if visual_mode == "grayscale":
		_apply_grayscale(image)
	var absolute_path := output_path
	if absolute_path.begins_with("res://"):
		absolute_path = ProjectSettings.globalize_path(absolute_path)
	var directory := absolute_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var error := image.save_png(absolute_path)
	t.check(error == OK and FileAccess.file_exists(absolute_path), "M112 %s 保存 PNG 到矩阵目录" % stage)
	print("M112 visual snapshot: %s (%dx%d, mode=%s, stage=%s)" % [absolute_path, image.get_width(), image.get_height(), visual_mode, stage])
	await _cleanup_battle(battle)
	if _result_layer != null and is_instance_valid(_result_layer):
		_result_layer.queue_free()
	await _stop_test_audio()
	t.finish(get_tree())

func _prepare_battle_stage(manager: Node, battle: BattleController) -> void:
	var actor: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	if actor == null:
		return
	match stage:
		"start":
			battle.call("_deselect_unit")
		"route_split":
			actor.grid_pos = Vector2i(8, 14)
			battle.call("_update_unit_sprite_pos", actor, false)
			battle.call("_apply_v2_mission_event", &"entered_route_split", {"position": actor.grid_pos})
			battle.call("_show_v2_route_choice")
		"record_room":
			actor.grid_pos = Vector2i(4, 5)
			battle.call("_update_unit_sprite_pos", actor, false)
			battle.v2_interaction_service.mark_encounter_cleared("m1_e03_record")
			var record_result := _commit_facility_action(battle, actor, "facility_record")
			t.check(bool(record_result.get("success", false)), "M112 record_room 展示事故记录室奖励状态")
		"gantry_open":
			await _prepare_route_and_gantry(battle, actor)
		"rescue":
			await _prepare_route_and_gantry(battle, actor)
			var rescue_result := await _rescue_actor(battle, actor)
			var rescue_ok := bool(rescue_result.get("success", false))
			var rescue_label := "M112 rescue 阶段展示已营救状态"
			if not rescue_ok:
				rescue_label += ": %s" % String(rescue_result.get("reason", "unknown"))
			t.check(rescue_ok, rescue_label)
			await _dismiss_dialogue(manager, 24)
		"evac":
			await _prepare_route_and_gantry(battle, actor)
			var rescue_result := await _rescue_actor(battle, actor)
			t.check(bool(rescue_result.get("success", false)), "M112 evac 阶段先完成营救状态")
			await _dismiss_dialogue(manager, 24)
			var scout: Unit = rescue_result.get("new_unit", null)
			if scout != null:
				var evac_center: Vector2i = battle.v2_mission_flow.get_snapshot().get("evac_center", Vector2i(-1, -1))
				actor.grid_pos = evac_center + Vector2i.LEFT
				scout.grid_pos = evac_center + Vector2i(0, -2)
				battle.call("_update_unit_sprite_pos", actor, false)
				battle.call("_update_unit_sprite_pos", scout, false)
				battle.call("refresh_visibility_transaction", &"m112_visual_evac")
				battle.call("_render_v2_hud")
		"evac_intercept":
			await _prepare_route_and_gantry(battle, actor)
			var rescue_result := await _rescue_actor(battle, actor)
			t.check(bool(rescue_result.get("success", false)), "M112 evac_intercept 阶段完成营救转折")
			await _dismiss_dialogue(manager, 24)
		"dialogue":
			GameManager.play_dialogue("ch1_m1_rescue")
			await _wait_for_dialogue(manager)
		_:
			t.check(false, "M112 不识别视觉阶段 %s" % stage)

func _prepare_result(manager: Node, result_layer: CanvasLayer) -> void:
	manager.set("battle_result", {
		"result": "victory",
		"level_id": "ch1_m1",
		"turns": 5,
		"units_survived": 2,
		"units_total": 2,
		"rewards": {"credit": 240, "exp": 180, "intel": 1},
		"primary_objective": "找到失联侦察兵并一起撤离",
		"optional_record": true,
		"rescued": ["scout"],
		"unlocked_modules": ["scout_a", "scout_b"],
	})
	var result_screen := MissionResultScene.instantiate()
	result_screen.name = "V2VisualResult"
	result_layer.add_child(result_screen)
	await get_tree().process_frame
	t.check(result_screen.visible, "M112 result 阶段结算层可见")
	var result_viewport_size: Vector2 = result_screen.get_viewport_rect().size
	t.check(result_screen.size == result_viewport_size, "M112 result 阶段结算层覆盖当前视口")
	t.check(result_screen.get_node("Panel").visible, "M112 result 阶段结算面板可见")
	var loot_container := result_screen.get_node("Panel/LootContainer") as Control
	var buttons := result_screen.get_node("Panel/Buttons") as Control
	t.check(buttons.position.y >= loot_container.position.y + loot_container.get_combined_minimum_size().y, "M112 result 阶段奖励文本不与按钮重叠")
	t.check(result_screen.get_node("Panel/TitleLabel").text == "任务完成", "M112 result 阶段显示任务完成")

func _rescue_actor(battle: BattleController, actor: Unit) -> Dictionary:
	if actor == null or battle.v2_rescue_controller == null:
		return {"success": false, "reason": &"rescue_unavailable"}
	var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_scout")
	actor.grid_pos = rescue_pos + Vector2i.LEFT
	battle.call("_update_unit_sprite_pos", actor, false)
	battle.call("refresh_visibility_transaction", &"m112_visual_rescue")
	var preview: Dictionary = battle.v2_rescue_controller.query_rescue(actor, &"rescue_scout")
	if not bool(preview.get("valid", false)):
		return preview
	var result: Dictionary = battle.v2_rescue_controller.commit_rescue(preview)
	await get_tree().process_frame
	return result

func _prepare_attack_target(battle: BattleController, actor: Unit) -> Unit:
	for raw_enemy in battle.enemy_units:
		var enemy: Unit = raw_enemy
		if enemy == null or not enemy.is_alive:
			continue
		for cell in [actor.grid_pos + Vector2i.RIGHT, actor.grid_pos + Vector2i.LEFT, actor.grid_pos + Vector2i.DOWN, actor.grid_pos + Vector2i.UP]:
			if not GridSystem.is_in_bounds(cell, battle.map_width, battle.map_height):
				continue
			if battle.call("_get_unit_at", cell) != null:
				continue
			enemy.grid_pos = cell
			battle.call("_update_unit_sprite_pos", enemy, false)
			battle.call("refresh_visibility_transaction", &"m112_visual_attack")
			var preview: Dictionary = battle.call("_query_v2_attack_preview", enemy)
			if bool(preview.get("valid", false)):
				return enemy
	return null

func _prepare_route_and_gantry(battle: BattleController, actor: Unit) -> void:
	actor.grid_pos = Vector2i(8, 14)
	battle.call("_update_unit_sprite_pos", actor, false)
	battle.call("_apply_v2_mission_event", &"entered_route_split", {"position": actor.grid_pos})
	battle.call("_on_v2_route_selected", "cargo_breakthrough")
	actor.grid_pos = Vector2i(12, 5)
	battle.call("_update_unit_sprite_pos", actor, false)
	battle.call("refresh_visibility_transaction", &"m112_visual_gantry")
	var gantry_result := _commit_facility_action(battle, actor, "facility_gantry")
	t.check(bool(gantry_result.get("success", false)), "M112 visual flow 正式打开吊桥")
	# Each visual stage is an isolated still frame; refresh the actor budget so
	# the next staged interaction can be shown without simulating enemy turns.
	actor.begin_v2_turn()

func _commit_facility_action(battle: BattleController, actor: Unit, facility_id: String) -> Dictionary:
	var actions: Array = battle.v2_interaction_service.query_actions(actor, facility_id)
	if actions.is_empty():
		return {"success": false, "reason": "no_actions"}
	var action_id := String(actions[0].get("id", ""))
	var result: Dictionary = battle.v2_interaction_service.commit_action(actor, facility_id, action_id, battle.v2_interaction_service.get_state_revision())
	if bool(result.get("success", false)):
		battle.call("_apply_v2_interaction_result", result)
	return result

func _validate_stage(manager: Node, battle: BattleController) -> void:
	if stage == "result":
		return
	t.check(battle.hud.objective_label.text != "", "M112 %s HUD 目标文本存在" % stage)
	if stage == "route_split":
		t.check(battle.v2_mission_flow.get_current_step_id() == "select_route", "M112 route_split 阶段显示路线选择状态")
	if stage == "record_room":
		t.check(bool(battle.v2_mission_flow.get_snapshot().get("optional_complete", false)), "M112 record_room 阶段记录奖励已登记")
	if stage == "gantry_open":
		var blockers: Array = battle.map_data.get("layers", {}).get("blocker", [])
		t.check(blockers.size() > 5 and (blockers[5] as Array).size() > 14 and int((blockers[5] as Array)[14]) == 0, "M112 gantry_open 阶段吊桥格已打开")
	if stage == "rescue":
		t.check(String(battle.v2_mission_flow.get_state_name()) == "ESCORT_TO_EVAC", "M112 rescue 阶段目标切换为护送撤离")
	if stage == "evac_intercept":
		var mission_flags: Dictionary = battle.v2_mission_flow.get_snapshot().get("mission_flags", {})
		t.check(bool(mission_flags.get("evac_intercept_started", false)), "M112 evac_intercept 阶段记录撤离反制")
	if stage == "evac":
		t.check(battle.v2_mission_flow.get_snapshot().get("evac_center", Vector2i(-1, -1)).x >= 0, "M112 evac 阶段显示撤离点")
	if stage == "dialogue":
		var dialogue: Node = manager.get("_active_dialogue")
		t.check(dialogue != null and is_instance_valid(dialogue) and dialogue.visible, "M112 dialogue 阶段显示对话层")

func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-size="):
			var parts := argument.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2:
				target_size = Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
		elif argument.begins_with("--qa-mode="):
			visual_mode = argument.trim_prefix("--qa-mode=")
		elif argument.begins_with("--qa-stage="):
			stage = argument.trim_prefix("--qa-stage=")
		elif argument.begins_with("--qa-output="):
			output_path = argument.trim_prefix("--qa-output=")
			_explicit_output = true
	if not visual_mode in ["normal", "grayscale", "deuteranopia_assist"]:
		visual_mode = "normal"
	if not stage in ["start", "route_split", "record_room", "gantry_open", "rescue", "evac_intercept", "evac", "dialogue", "result"]:
		stage = "start"

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

func _dismiss_dialogue(manager: Node, max_frames: int = 60) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

func _wait_for_dialogue(manager: Node) -> void:
	for _i in range(60):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue) and dialogue.visible:
			return

func _dismiss_tutorial_hint(battle: BattleController) -> void:
	var hint: Control = battle.get("_active_tutorial_hint")
	if hint != null and is_instance_valid(hint):
		hint.call("_on_continue")

func _wait_for_player_phase(battle: BattleController) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
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

func _apply_grayscale(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			image.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
