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
		output_path = "res://../artifacts/v2/verification/m2-cooling-works/screenshots/%dx%d_%s_%s.png" % [target_size.x, target_size.y, visual_mode, stage]
	get_window().size = target_size
	get_viewport().size = target_size
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "M2 visual 找到正式 GameManager")
	if manager == null:
		t.finish(get_tree())
		return
	var save: Dictionary = manager.call("begin_v2_new_game_for_test", 0)
	manager.set("current_level_id", "ch1_m2")
	manager.set("current_save", save)
	var settings: Dictionary = manager.get("current_save").get("settings", {}).duplicate(true)
	settings["visual_mode"] = visual_mode
	manager.get("current_save")["settings"] = settings
	VisualMode.apply(settings)
	AccessibilitySettings.apply_settings(settings)
	var battle := BattleScene.instantiate() as BattleController
	t.check(battle != null, "M2 visual 实例化正式战斗场景")
	if battle == null:
		t.finish(get_tree())
		return
	add_child(battle)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "M2 visual 进入玩家行动阶段")
	if not ready:
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return
	if stage == "result":
		battle.hide()
		battle.hud.hide()
		_result_layer = CanvasLayer.new()
		_result_layer.layer = 200
		add_child(_result_layer)
		await _prepare_result(manager, _result_layer)
	else:
		await _prepare_stage(manager, battle)
		battle.camera.toggle_overview()
		await get_tree().process_frame
		await get_tree().process_frame
	var viewport_texture := get_viewport().get_texture()
	if DisplayServer.get_name() == "headless" or viewport_texture == null:
		t.check(DisplayServer.get_name() == "headless", "M2 visual 无头驱动明确报告无 framebuffer")
		_validate_stage(battle)
		await _cleanup_battle(battle)
		t.finish(get_tree())
		return
	var image := viewport_texture.get_image()
	t.check(image != null and not image.is_empty(), "M2 %s 生成非空视觉快照" % stage)
	if image == null or image.is_empty():
		t.finish(get_tree())
		return
	t.check(image.get_width() == target_size.x and image.get_height() == target_size.y, "M2 %s 快照尺寸正确" % stage)
	_validate_stage(battle)
	if visual_mode == "grayscale":
		_apply_grayscale(image)
	var absolute_path := output_path
	if absolute_path.begins_with("res://"):
		absolute_path = ProjectSettings.globalize_path(absolute_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	t.check(image.save_png(absolute_path) == OK and FileAccess.file_exists(absolute_path), "M2 %s 保存 PNG" % stage)
	print("M2 visual snapshot: %s (%dx%d, mode=%s, stage=%s)" % [absolute_path, image.get_width(), image.get_height(), visual_mode, stage])
	await _cleanup_battle(battle)
	if _result_layer != null and is_instance_valid(_result_layer):
		_result_layer.queue_free()
	await _stop_test_audio()
	t.finish(get_tree())

func _prepare_stage(manager: Node, battle: BattleController) -> void:
	var actor: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	if actor == null:
		return
	match stage:
		"start":
			battle.call("_deselect_unit")
		"route_west":
			await _operate_facility(manager, battle, actor, "facility_power_west", Vector2i(7, 14))
		"route_east":
			await _operate_facility(manager, battle, actor, "facility_security_bypass", Vector2i(20, 13))
		"turbine":
			await _prepare_route(manager, battle, actor, "facility_power_west", Vector2i(7, 14))
			await _rescue_sniper(manager, battle, actor)
			var sniper: Unit = battle.player_units.back()
			await _operate_facility(manager, battle, sniper, "facility_turbine", Vector2i(14, 10))
		"hazard_warning":
			await _prepare_route(manager, battle, actor, "facility_power_west", Vector2i(7, 14))
			battle.call("_advance_v2_hazard_player_turn")
			battle.call("_advance_v2_hazard_player_turn")
		"cooling_room":
			await _prepare_route(manager, battle, actor, "facility_power_west", Vector2i(7, 14))
			battle.v2_interaction_service.mark_encounter_cleared("m2_e03_turbine")
			await _operate_facility(manager, battle, actor, "facility_cooling_control", Vector2i(6, 6))
		"sniper_rescue":
			await _prepare_route(manager, battle, actor, "facility_power_west", Vector2i(7, 14))
			await _rescue_sniper(manager, battle, actor)
		"exit_countermeasure":
			await _prepare_route(manager, battle, actor, "facility_power_west", Vector2i(7, 14))
			await _rescue_sniper(manager, battle, actor)
			var sniper: Unit = battle.player_units.back()
			await _operate_facility(manager, battle, sniper, "facility_turbine", Vector2i(14, 10))
			for unit in battle.player_units:
				unit.grid_pos = Vector2i(24, 2)
				battle.call("_update_unit_sprite_pos", unit, false)
			battle.call("_prepare_v2_m2_evac")
		_:
			t.check(false, "M2 visual 不识别阶段 %s" % stage)

func _prepare_route(manager: Node, battle: BattleController, actor: Unit, facility_id: String, position: Vector2i) -> void:
	await _operate_facility(manager, battle, actor, facility_id, position)

func _operate_facility(manager: Node, battle: BattleController, actor: Unit, facility_id: String, position: Vector2i) -> void:
	actor.grid_pos = position
	actor.begin_v2_turn()
	battle.selected_unit = actor
	battle.call("_update_unit_sprite_pos", actor, false)
	var actions: Array = battle.v2_interaction_service.query_actions(actor, facility_id)
	t.check(not actions.is_empty() and bool(actions[0].get("enabled", false)), "M2 %s 设施可操作" % facility_id)
	if actions.is_empty() or not bool(actions[0].get("enabled", false)):
		return
	var result: Dictionary = battle.v2_interaction_service.commit_action(actor, facility_id, String(actions[0].get("id", "")), battle.v2_interaction_service.get_state_revision())
	t.check(bool(result.get("success", false)), "M2 %s 设施提交成功" % facility_id)
	if bool(result.get("success", false)):
		battle.call("_apply_v2_interaction_result", result)
	await _dismiss_dialogue(manager)

func _rescue_sniper(manager: Node, battle: BattleController, actor: Unit) -> void:
	var rescue_pos: Vector2i = battle.v2_rescue_controller.get_rescue_position(&"rescue_sniper")
	actor.grid_pos = rescue_pos + Vector2i.LEFT
	actor.begin_v2_turn()
	battle.call("_update_unit_sprite_pos", actor, false)
	var preview: Dictionary = battle.v2_rescue_controller.query_rescue(actor, &"rescue_sniper")
	t.check(bool(preview.get("valid", false)), "M2 狙击手营救预览有效")
	if bool(preview.get("valid", false)):
		var result: Dictionary = battle.v2_rescue_controller.commit_rescue(preview)
		t.check(bool(result.get("success", false)), "M2 狙击手营救提交成功")
		await get_tree().process_frame
		await _dismiss_dialogue(manager)

func _prepare_result(manager: Node, result_layer: CanvasLayer) -> void:
	manager.set("battle_result", {
		"result": "victory",
		"level_id": "ch1_m2",
		"turns": 12,
		"units_survived": 3,
		"units_total": 3,
		"rewards": {"credit": 360, "exp": 260, "intel": 2},
		"primary_objective": "解除区域封锁并救出狙击手",
		"optional_objective": "关闭冷却控制室",
		"optional_record": true,
		"rescued": ["sniper"],
		"rescue_character": "sniper",
		"unlocked_modules": ["sniper_a", "assault_b"],
	})
	var result_screen := MissionResultScene.instantiate()
	result_screen.name = "M2VisualResult"
	result_layer.add_child(result_screen)
	await get_tree().process_frame
	t.check(result_screen.visible, "M2 result 结算层可见")
	t.check(result_screen.size == result_screen.get_viewport_rect().size, "M2 result 结算层覆盖当前视口")
	t.check(result_screen.get_node("Panel").visible, "M2 result 结算面板可见")
	var loot_container := result_screen.get_node("Panel/LootContainer") as Control
	var buttons := result_screen.get_node("Panel/Buttons") as Control
	t.check(buttons.position.y >= loot_container.position.y + loot_container.get_combined_minimum_size().y, "M2 result 奖励文本不与按钮重叠")
	t.check(result_screen.get_node("Panel/TitleLabel").text == "任务完成", "M2 result 显示任务完成")

func _validate_stage(battle: BattleController) -> void:
	if stage == "result":
		return
	t.check(battle.hud.objective_label.text != "", "M2 %s HUD 目标文本存在" % stage)
	if stage == "cooling_room":
		t.check(bool(battle.v2_mission_flow.get_snapshot().get("mission_flags", {}).get("cooling_nozzles_shutdown", false)), "M2 cooling_room 记录喷口关闭")
	if stage == "sniper_rescue":
		t.check(bool(battle.v2_mission_flow.rescued_characters.get("sniper", false)), "M2 sniper_rescue 显示狙击手归队")
	if stage == "exit_countermeasure":
		t.check(bool(battle.v2_mission_flow.get_snapshot().get("mission_flags", {}).get("engineer_countermeasure_started", false)), "M2 exit_countermeasure 记录工程师反制")

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
	var valid_stages := ["start", "route_west", "route_east", "turbine", "hazard_warning", "cooling_room", "sniper_rescue", "exit_countermeasure", "result"]
	if not stage in valid_stages:
		stage = "start"

func _wait_for_player_phase(battle: BattleController) -> bool:
	for _i in range(180):
		if battle.turn_manager != null and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION:
			return true
		await get_tree().process_frame
	return false

func _dismiss_dialogue(manager: Node, max_frames: int = 90) -> void:
	for _i in range(max_frames):
		await get_tree().process_frame
		var dialogue: Node = manager.get("_active_dialogue")
		if dialogue != null and is_instance_valid(dialogue):
			dialogue.call("_end_dialogue")
			await get_tree().process_frame
			return

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
