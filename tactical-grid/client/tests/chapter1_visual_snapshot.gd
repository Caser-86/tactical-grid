## CH1-090 visual QA helper.
## Renders the first battle scene at a requested resolution, accessibility mode,
## and runtime stage, then writes one PNG for visual review. Use qa-mode=grayscale
## for a luminance check; this scene is excluded from release export.
extends Node

const BattleScene = preload("res://scenes/battle.tscn")

var target_size := Vector2i(1280, 720)
var colorblind_mode := "none"
var qa_stage := "initial"
var output_path := "build/chapter1_visual_1280x720_none.png"

func _ready() -> void:
	_parse_user_args()
	get_window().size = target_size
	get_viewport().size = target_size

	GameManager.current_level_id = "ch1_m1"
	GameManager.current_save = SaveManager.create_default_save()
	GameManager.current_save["characters"] = GameManager.progression.create_starter_roster()
	var settings: Dictionary = GameManager.current_save.get("settings", {}).duplicate(true)
	settings["colorblind_mode"] = colorblind_mode
	GameManager.current_save["settings"] = settings
	AccessibilitySettings.apply_settings(settings)

	var battle := BattleScene.instantiate() as BattleController
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Skip blocking intro/tutorial panels for a clean battlefield composition shot.
	if GameManager._active_dialogue and is_instance_valid(GameManager._active_dialogue):
		GameManager._active_dialogue._end_dialogue()
	if battle._active_tutorial_hint and is_instance_valid(battle._active_tutorial_hint):
		battle._active_tutorial_hint._on_continue()
	await get_tree().process_frame
	if battle.turn_manager == null or battle.turn_manager.turn_number <= 0:
		battle._start_battle()
	battle._dismiss_context_hint()
	await _prepare_stage(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Visual snapshot failed: viewport image is empty")
		get_tree().quit(1)
		return
	if colorblind_mode == "grayscale":
		_apply_grayscale(image)
	var absolute_path := output_path
	if not absolute_path.is_absolute_path():
		absolute_path = ProjectSettings.globalize_path(absolute_path)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Visual snapshot failed to save: %s (%s)" % [absolute_path, error])
		await _cleanup_snapshot(battle)
		get_tree().quit(1)
		return
	print("Visual snapshot saved: %s (%dx%d, mode=%s, stage=%s)" % [absolute_path, image.get_width(), image.get_height(), colorblind_mode, qa_stage])
	await _cleanup_snapshot(battle)
	get_tree().quit(0)

func _cleanup_snapshot(battle: BattleController) -> void:
	# The helper exits immediately after saving the image; clean transient nodes
	# and audio first so visual QA does not produce false leak warnings.
	if battle and is_instance_valid(battle):
		if battle.effect_layer:
			for child in battle.effect_layer.get_children():
				child.queue_free()
		battle._cleanup_units()
		battle.queue_free()
	AudioManager.stop_bgm()
	AudioManager.stop_ambient()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	AudioManager.audio_cache.clear()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.2, true, false, true).timeout

func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-size="):
			var parts := argument.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2:
				target_size = Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
		elif argument.begins_with("--qa-mode="):
			colorblind_mode = argument.trim_prefix("--qa-mode=")
		elif argument.begins_with("--qa-stage="):
			qa_stage = argument.trim_prefix("--qa-stage=")
		elif argument.begins_with("--qa-output="):
			output_path = argument.trim_prefix("--qa-output=")

func _prepare_stage(battle: BattleController) -> void:
	var actor: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	if actor == null:
		push_error("Visual snapshot failed: M1 has no player actor")
		return

	match qa_stage:
		"initial":
			pass
		"selection":
			battle._select_unit(actor)
		"network":
			battle._select_unit(actor)
			_reveal_all_for_qa(battle)
			battle._on_toggle_network()
			battle.camera.toggle_overview()
		"intent":
			_reveal_all_for_qa(battle)
			battle._plan_enemy_intents()
			battle._refresh_enemy_intent_display()
			battle.camera.toggle_overview()
		"upload":
			_reveal_all_for_qa(battle)
			_activate_upload_for_qa(battle, actor)
			battle.camera.toggle_overview()
		"evac":
			_reveal_all_for_qa(battle)
			_complete_upload_for_qa(battle, actor)
			actor.grid_pos = battle.mission_objective_state.evac_point
			battle._update_unit_sprite_pos(actor)
			battle._sync_objective_state_from_mos()
			battle.camera.toggle_overview()
		_:
			push_error("Visual snapshot failed: unknown qa-stage=%s" % qa_stage)

func _reveal_all_for_qa(battle: BattleController) -> void:
	var all_cells: Array[Vector2i] = []
	for y in range(battle.map_height):
		for x in range(battle.map_width):
			all_cells.append(Vector2i(x, y))
	var visible_enemies: Array = []
	for enemy in battle.enemy_units:
		if enemy and enemy.is_alive:
			visible_enemies.append({
				"entity_id": enemy.entity_id,
				"pos": enemy.grid_pos,
				"hp": enemy.current_hp,
			})
	battle.visibility_state.set_turn(battle.turn_manager.turn_number)
	battle.visibility_state.update_visibility(all_cells, visible_enemies)
	battle._refresh_enemy_sprite_visibility()
	battle._refresh_last_known_ghosts()
	if battle.visibility_renderer:
		battle.visibility_renderer.refresh()

func _activate_upload_for_qa(battle: BattleController, actor: Unit) -> void:
	var terminals: Array = battle.mission_objective_state.terminals
	if terminals.is_empty():
		return
	var terminal_pos: Vector2i = terminals[0]
	actor.grid_pos = terminal_pos
	battle._update_unit_sprite_pos(actor)
	battle.mission_objective_state.apply_event(&"terminal_interacted", {
		"unit": actor,
		"position": terminal_pos,
	})
	battle.hud.update_objective(battle.mission_objective_state.get_status_text())
	battle._spawn_effect("upload", terminal_pos)

func _complete_upload_for_qa(battle: BattleController, actor: Unit) -> void:
	_activate_upload_for_qa(battle, actor)
	var required := maxi(1, battle.mission_objective_state.upload_turns_required)
	for _step in range(required):
		battle.mission_objective_state.apply_event(&"enemy_turn_completed", {})
	battle.hud.update_objective(battle.mission_objective_state.get_status_text())

func _apply_grayscale(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			image.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
