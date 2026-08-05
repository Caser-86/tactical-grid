extends Node

const BattleScene = preload("res://scenes/battle.tscn")
const BattleControllerScript = preload("res://scripts/game/battle_controller.gd")
const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()
var _last_mouse_screen_pos := Vector2.ZERO
var _saw_enemy_turn := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== V2 player turn input E2E ===")
	var manager: Node = get_node_or_null("/root/GameManager")
	t.check(manager != null, "V2 E2E 找到 GameManager")
	if manager == null:
		t.finish(get_tree())
		return

	var save: Dictionary = manager.call("begin_v2_new_game_for_test", 0)
	t.check(String(save.get("game_line", "")) == "v2_infiltration", "V2 E2E 使用独立存档身份")
	manager.set("current_level_id", "ch1_m1")
	# 只在内存中预标记上下文教程，避免测试把焦点落在教程按钮而不是战场输入。
	manager.set("current_save", _with_known_tutorials(manager.get("current_save")))

	var battle := BattleScene.instantiate() as BattleController
	t.check(battle != null and battle.get_script() == BattleControllerScript, "V2 E2E 实例化正式 battle.tscn")
	if battle == null:
		t.finish(get_tree())
		return
	add_child(battle)
	await _dismiss_intro(manager)
	var ready := await _wait_for_player_phase(battle)
	t.check(ready, "V2 E2E 等待到玩家行动阶段")
	if not ready:
		_cleanup_battle(battle)
		t.finish(get_tree())
		return
	# Headless Godot may create a tiny OS window and scale pushed mouse events.
	# Match the shipped viewport before converting cells to screen coordinates.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	_capture_viewport("input-session-720p-initial.png")

	battle.turn_manager.turn_phase_changed.connect(_on_phase_changed)
	var player: Unit = battle.player_units[0] if not battle.player_units.is_empty() else null
	t.check(player != null and player.team == "player", "V2 M1 实战只部署一名玩家角色")
	t.check(player != null and player.v2_turn_mode_enabled, "V2 实战单位启用移动/行动双预算")
	t.check(battle.v2_input_router.get_state_name() == "unit_selected", "玩家回合自动选中单位")
	t.check(not battle.hud.move_button.visible and not battle.hud.attack_button.visible and not battle.hud.skill_button.visible and not battle.hud.item_button.visible and not battle.hud.overwatch_button.visible, "V2 HUD 不暴露旧动作按钮")
	t.check(battle.hud.end_turn_button.visible and not battle.hud.end_turn_button.disabled, "V2 HUD 保留可用结束回合入口")

	if player == null:
		_cleanup_battle(battle)
		t.finish(get_tree())
		return

	# 1. 左键点击角色：直接选中并显示两类范围。
	await _move_mouse_to_cell(battle, player.grid_pos)
	await _click_left()
	t.check(battle.selected_unit == player, "左键点击角色选中玩家单位")
	t.check(battle.v2_input_router.get_state_name() == "unit_selected", "选中角色后保持单位选择状态")
	t.check(battle.v2_affordance_presenter.get_child_count() > 0, "选中角色后显示移动/攻击范围")
	t.check(battle.hud.context_label.text.contains("蓝色") and battle.hud.context_label.text.contains("红色"), "选中角色后提示蓝色移动与红色攻击")

	# 2. 左键蓝色安全格：一次点击完成移动，不依赖底部按钮。
	var move_target := _find_safe_move_target(battle, player)
	t.check(move_target.x >= 0, "V2 实战存在安全移动格")
	if move_target.x >= 0:
		await _move_mouse_to_cell(battle, move_target)
		await _click_left()
		await get_tree().process_frame
		t.check(player.grid_pos == move_target, "左键蓝色格完成移动")
		t.check(not player.v2_turn_state.move_available and player.v2_turn_state.action_available, "移动只消耗移动预算并保留行动预算")
		t.check(battle.v2_input_router.get_state_name() == "unit_selected", "移动完成后回到单位选择状态")
		t.check(battle.hud.action_budget_label.text.contains("移动 已用") and battle.hud.action_budget_label.text.contains("行动 可用"), "移动后 HUD 显示精确预算")

	# 3. 把一名真实敌人放入当前可见的相邻格，随后仍通过真实鼠标完成攻击。
	var target: Unit = battle.enemy_units[0] if not battle.enemy_units.is_empty() else null
	var attack_cell := _prepare_adjacent_target(battle, player, target)
	t.check(target != null and attack_cell.x >= 0, "V2 E2E 准备可见且可攻击的真实敌人")
	if target != null and attack_cell.x >= 0:
		await get_tree().process_frame
		var hp_before := target.current_hp
		await _move_mouse_to_cell(battle, attack_cell)
		t.check(battle.hud.get_attack_preview_text().contains("悬停预览"), "悬停敌人显示攻击预览")
		await _click_left()
		await get_tree().process_frame
		t.check(battle.v2_input_router.get_state_name() == "attack_locked", "第一次左键敌人锁定攻击预览")
		t.check(target.current_hp == hp_before, "攻击预览不提前扣除生命")
		t.check(battle.hud.get_attack_preview_text().contains("HP %d" % hp_before), "攻击预览显示目标当前生命")
		var expected_hp_after := int(battle.v2_locked_attack_preview.get("hp_after", hp_before))
		await _click_left()
		await get_tree().process_frame
		await get_tree().process_frame
		t.check(target.current_hp < hp_before, "第二次左键同一敌人完成攻击")
		t.check(target.current_hp == expected_hp_after, "攻击结算严格等于锁定预览的 HP 结果")
		t.check(not player.v2_turn_state.action_available, "攻击只消耗行动预算")
		t.check(battle.v2_input_router.get_state_name() == "unit_selected", "攻击完成后回到单位选择状态")
		t.check(battle.hud.phase_label.text.contains("已选中"), "攻击完成后 HUD 状态同步回已选中")

	# 4. 中键拖动与滚轮缩放由真实输入路由到镜头。
	var camera_before := battle.camera.position
	await _drag_camera()
	t.check(battle.camera.position != camera_before, "中键拖动真实改变战场镜头")
	var zoom_before := battle.camera.zoom.x
	await _wheel_zoom()
	t.check(battle.camera.zoom.x > zoom_before, "滚轮真实放大镜头")

	# 5. 右键取消当前选择，重新左键选中后用 G 查看网络层。
	await _click_right()
	t.check(battle.selected_unit == null and battle.v2_input_router.get_state_name() == "free_select", "右键取消选择并回到自由选择")
	await _move_mouse_to_cell(battle, player.grid_pos)
	await _click_left()
	await _press_key(KEY_G)
	t.check(battle.hud.is_network_overlay_visible(), "G 键真实切换网络覆盖层")
	await _press_key(KEY_G)
	t.check(not battle.hud.is_network_overlay_visible(), "再次按 G 键关闭网络覆盖层")

	# 6. Space 结束回合，确认敌方阶段被消费且下一回合 HUD 恢复。
	await _press_key(KEY_SPACE)
	for _i in range(240):
		if battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION and battle.turn_manager.turn_number >= 2:
			break
		await get_tree().process_frame
	t.check(_saw_enemy_turn, "Space 结束回合经过敌方行动阶段")
	t.check(battle.turn_manager.turn_number == 2 and battle.turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "敌方行动后进入下一玩家回合")
	t.check(battle.v2_input_router.get_state_name() == "unit_selected", "下一玩家回合自动恢复单位选择状态")
	t.check(battle.hud.context_label.visible and battle.hud.phase_label.text.contains("玩家回合"), "下一玩家回合 HUD 恢复可操作提示")
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport("input-session-1080p-next-turn.png")

	_cleanup_battle(battle)
	await _stop_test_audio()
	t.finish(get_tree())

func _with_known_tutorials(save: Dictionary) -> Dictionary:
	var next := save.duplicate(true)
	var progress: Dictionary = next.get("campaign_progress", {})
	var flags: Dictionary = progress.get("story_flags", {})
	for flag in ["teach_selection", "teach_movement", "teach_attack", "teach_observe", "teach_network_takeover", "teach_end_turn"]:
		flags["tutorial_" + flag] = true
	progress["story_flags"] = flags
	next["campaign_progress"] = progress
	return next

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

func _move_mouse_to_cell(battle: BattleController, cell: Vector2i) -> void:
	var world_pos := GridSystem.grid_to_world(cell) + Vector2(BattleController.CELL_SIZE * 0.5, BattleController.CELL_SIZE * 0.5)
	var screen_pos := battle.get_viewport().canvas_transform * world_pos
	_last_mouse_screen_pos = screen_pos
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	get_viewport().push_input(motion)
	await get_tree().process_frame

func _click_left() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = _last_mouse_screen_pos
		event.global_position = _last_mouse_screen_pos
		get_viewport().push_input(event)
		await get_tree().process_frame

func _click_right() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = _last_mouse_screen_pos
		event.global_position = _last_mouse_screen_pos
		get_viewport().push_input(event)
		await get_tree().process_frame

func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.echo = false
	get_viewport().push_input(event)
	await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame

func _find_safe_move_target(battle: BattleController, player: Unit) -> Vector2i:
	for raw_cell in battle.reachable_cells.keys():
		var cell: Vector2i = raw_cell
		if cell == player.grid_pos:
			continue
		var preview: Dictionary = battle.v2_action_service.query_action({"action": &"move", "unit": player, "target": cell})
		if bool(preview.get("valid", false)) and not bool(preview.get("dangerous", false)):
			return cell
	return Vector2i(-1, -1)

func _prepare_adjacent_target(battle: BattleController, player: Unit, target: Unit) -> Vector2i:
	if target == null:
		return Vector2i(-1, -1)
	var candidates: Array[Vector2i] = [
		player.grid_pos + Vector2i.RIGHT,
		player.grid_pos + Vector2i.LEFT,
		player.grid_pos + Vector2i.DOWN,
		player.grid_pos + Vector2i.UP,
	]
	for cell in candidates:
		if not GridSystem.is_in_bounds(cell, battle.map_width, battle.map_height):
			continue
		if battle.call("_get_unit_at", cell) != null:
			continue
		target.grid_pos = cell
		target.current_hp = target.max_hp
		target.is_alive = true
		battle.call("_update_unit_sprite_pos", target, false)
		battle.call("refresh_visibility_transaction", &"e2e_target_setup")
		var preview: Dictionary = battle.call("_query_v2_attack_preview", target)
		if bool(preview.get("valid", false)):
			battle.call("_refresh_selected_unit_affordances", player)
			return cell
	return Vector2i(-1, -1)

func _drag_camera() -> void:
	var start := Vector2(600.0, 400.0)
	var end := Vector2(500.0, 400.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = start
	get_viewport().push_input(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = end
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	release.position = end
	get_viewport().push_input(release)
	await get_tree().process_frame

func _wheel_zoom() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.position = Vector2(600.0, 400.0)
	get_viewport().push_input(event)
	await get_tree().process_frame

func _on_phase_changed(phase: TurnManager.TurnPhase) -> void:
	if phase == TurnManager.TurnPhase.ENEMY_ACTION:
		_saw_enemy_turn = true

func _cleanup_battle(battle: BattleController) -> void:
	if battle != null and is_instance_valid(battle):
		battle.call("_cleanup_units")
		# The coordinator owns this temporary scene; free it synchronously so
		# detached render nodes do not survive until the headless process exits.
		battle.free()
	await get_tree().process_frame
	await get_tree().process_frame

func _stop_test_audio() -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	audio.call("stop_bgm")
	audio.call("stop_ambient")
	var bgm_player: Node = audio.get("bgm_player")
	if bgm_player and is_instance_valid(bgm_player):
		bgm_player.set("stream", null)
	var sfx_player: Node = audio.get("sfx_player")
	if sfx_player and is_instance_valid(sfx_player):
		sfx_player.call("stop")
		sfx_player.set("stream", null)
	var pool: Array = audio.get("_sfx_pool")
	for player in pool:
		if player and is_instance_valid(player):
			player.call("stop")
			player.set("stream", null)
	audio.set("audio_cache", {})
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_viewport(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[P2] screenshot skipped in headless mode: ", file_name)
		return
	# Keep verification evidence at the repository-level artifacts directory,
	# outside the client project and aligned with the V2 release plan.
	var directory := ProjectSettings.globalize_path("res://../artifacts/v2/verification/p2")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("[P2] screenshot unavailable: ", file_name)
		return
	var path := directory.path_join(file_name)
	var error := image.save_png(path)
	print("[P2] screenshot ", file_name, " -> ", error == OK)
