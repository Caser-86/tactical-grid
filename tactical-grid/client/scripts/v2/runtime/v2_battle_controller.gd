extends "res://scripts/game/battle_controller.gd"

const V2EnemyBrainScript = preload("res://scripts/v2/ai/v2_enemy_brain.gd")
const V2IntentExecutorScript = preload("res://scripts/v2/ai/v2_intent_executor.gd")
const V2RuntimeMapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const V2HazardControllerScript = preload("res://scripts/v2/mission/v2_hazard_controller.gd")
const PathfindingScript = preload("res://scripts/core/pathfinding.gd")
const V2ContextActionResolverScript = preload("res://scripts/v2/input/v2_context_action_resolver.gd")

var v2_hazard_controller: RefCounted = null
var _v2_hazard_turn_state: Dictionary = {}
var _v2_restore_attempted := false
var _v2_restore_failure: Dictionary = {}
var _v2_guidance_layer: Node2D = null

func _init() -> void:
	v2_context_action_resolver = V2ContextActionResolverScript.new()

## V2 owns its map, roster, onboarding, and enemy turn. The shared controller
## remains a rendering/turn-system base so the V1 branch is never changed.
func _ready() -> void:
	super._ready()
	# Capture camera gestures before HUD/map Controls get a chance to consume
	# them. This is intentionally V2-only; V1 keeps its original input path.
	set_process_input(true)
	_install_v2_control_guide()
	_ensure_v2_guidance_layer()

func _input(event: InputEvent) -> void:
	if _route_v2_input(event):
		get_viewport().set_input_as_handled()

func _route_v2_input(event: InputEvent) -> bool:
	if not _is_v2_battle() or v2_input_router == null:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and is_v2_camera_inspecting():
		return_to_v2_camera_player()
		return true
	if not _is_v2_routed_event(event):
		return false
	return v2_input_router.handle_event(event, _screen_to_cell, _v2_pointer_context)

func _is_v2_routed_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return mouse_button.button_index == MOUSE_BUTTON_LEFT \
			or mouse_button.button_index == MOUSE_BUTTON_RIGHT \
			or mouse_button.button_index == MOUSE_BUTTON_MIDDLE \
			or mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP \
			or mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN
	if event is InputEventMouseMotion:
		return v2_input_router.is_camera_panning()
	return event is InputEventKey

func _v2_pointer_context(screen_position: Vector2) -> Dictionary:
	var cell := _screen_to_cell(screen_position)
	var over_hud := _v2_hud_control_at(screen_position)
	var over_map := GridSystem.is_in_bounds(cell, map_width, map_height)
	return {
		"over_map": over_map,
		"over_hud": over_hud,
		"drag_allowed": over_map and not over_hud and _v2_drag_allowed_at(cell),
	}

func _v2_drag_allowed_at(cell: Vector2i) -> bool:
	if _has_active_input_mode() or not v2_pending_move_preview.is_empty() or not v2_locked_attack_preview.is_empty():
		return false
	var unit := _get_unit_at(cell)
	if unit != null and unit.is_alive:
		return false
	if v2_interaction_service != null and not v2_interaction_service.get_facility_at(cell).is_empty():
		return false
	if v2_rescue_controller != null and v2_rescue_controller.is_reserved_cell(cell):
		return false
	return true

func _build_v2_context_action_context(cell: Vector2i) -> Dictionary:
	if not _is_v2_battle():
		return super._build_v2_context_action_context(cell)
	var clicked_unit: Unit = _get_unit_at(cell)
	var friendly: Unit = clicked_unit if clicked_unit != null and clicked_unit.team == "player" else null
	var enemy: Unit = clicked_unit if clicked_unit != null and clicked_unit.team != "player" else null
	var facility: Dictionary = v2_interaction_service.get_facility_at(cell) if v2_interaction_service != null else {}
	return {
		"selected_unit": selected_unit,
		"friendly_at": friendly,
		"enemy_at": enemy,
		"facility_at": facility,
		"move_query": Callable(self, "_query_v2_context_move"),
		"attack_query": Callable(self, "_query_v2_attack_preview"),
		"interaction_query": Callable(self, "_query_v2_context_interaction"),
	}

func _v2_hud_control_at(screen_position: Vector2, node: Node = hud) -> bool:
	if node == null:
		return false
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(screen_position):
				return true
		if _v2_hud_control_at(screen_position, child):
			return true
	return false

func _ensure_v2_guidance_layer() -> Node2D:
	if _v2_guidance_layer != null and is_instance_valid(_v2_guidance_layer):
		return _v2_guidance_layer
	_v2_guidance_layer = Node2D.new()
	_v2_guidance_layer.name = "V2ObjectiveGuidance"
	_v2_guidance_layer.z_index = 15
	add_child(_v2_guidance_layer)
	return _v2_guidance_layer

func _render_v2_guidance() -> void:
	var layer := _ensure_v2_guidance_layer()
	for child in layer.get_children():
		# Guidance nodes have no animation or external signal ownership. Free them
		# immediately so repeated HUD refreshes cannot leave stale routes behind or
		# force Godot to rename the next route node.
		child.free()
	if not _is_v2_battle() or v2_mission_flow == null or v2_mission_flow.is_victory() or v2_mission_flow.is_defeat():
		return
	var guide_cell: Vector2i = v2_mission_flow.get_current_guide_cell() if v2_mission_flow.has_method("get_current_guide_cell") else Vector2i(-1, -1)
	if guide_cell.x < 0 or guide_cell.x >= map_width or guide_cell.y < 0 or guide_cell.y >= map_height:
		return
	var actor: Unit = selected_unit if selected_unit != null and is_instance_valid(selected_unit) and selected_unit.is_alive else player_units[0] if not player_units.is_empty() else null
	if actor != null:
		var route := _find_v2_guidance_route(actor, guide_cell)
		# The beacon is the long-term objective, but the route line must never
		# promise a destination outside this unit's current movement budget.
		var reachable_route: Array[Vector2i] = [actor.grid_pos]
		var spent_move := 0
		for cell in route:
			var step_cost := maxi(1, int(_get_move_cost(cell, actor.job)))
			if spent_move + step_cost > maxi(0, actor.move_points):
				break
			spent_move += step_cost
			reachable_route.append(cell)
		if reachable_route.size() > 1:
			var line := Line2D.new()
			line.name = "V2ObjectiveRoute"
			line.width = 4.0
			line.default_color = Color(1.0, 0.78, 0.22, 0.88)
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.z_index = 0
			line.add_point(_get_cell_center(actor.grid_pos))
			for cell in reachable_route.slice(1):
				line.add_point(_get_cell_center(cell))
			layer.add_child(line)
	var marker := Node2D.new()
	marker.name = "V2ObjectiveBeacon"
	marker.position = _get_cell_center(guide_cell)
	marker.z_index = 2
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -24), Vector2(24, 0), Vector2(0, 24), Vector2(-24, 0),
	])
	diamond.color = Color(1.0, 0.72, 0.16, 0.34)
	marker.add_child(diamond)
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.90, 0.40, 0.98)
	ring.closed = true
	ring.points = PackedVector2Array([
		Vector2(0, -29), Vector2(29, 0), Vector2(0, 29), Vector2(-29, 0),
	])
	marker.add_child(ring)
	var label := Label.new()
	label.text = "下一步"
	label.position = Vector2(-42, -60)
	label.size = Vector2(84, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.48, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.06, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
	layer.add_child(marker)

func _find_v2_guidance_route(actor: Unit, guide_cell: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = [guide_cell]
	# A mission beacon may be occupied by an enemy encounter. Route the line to
	# the nearest legal approach cell instead of drawing through that unit.
	if _is_blocked(guide_cell):
		candidates.clear()
		for neighbor in GridSystem.get_neighbors(guide_cell):
			if GridSystem.is_in_bounds(neighbor, map_width, map_height) and not _is_blocked(neighbor):
				candidates.append(neighbor)
	var best_route: Array[Vector2i] = []
	for candidate in candidates:
		var route: Array[Vector2i] = PathfindingScript.find_path(
			actor.grid_pos,
			candidate,
			map_width,
			map_height,
			_get_move_cost.bind(actor.job),
			_is_blocked
		)
		if not route.is_empty() and (best_route.is_empty() or route.size() < best_route.size()):
			best_route = route
	return best_route

func _install_v2_control_guide() -> void:
	if hud == null:
		return
	var legacy_hint := hud.get_node_or_null("BottomBar/ShortcutHint") as Label
	if legacy_hint != null:
		legacy_hint.visible = false
	var bottom_bar := hud.get_node_or_null("BottomBar") as Control
	if bottom_bar == null:
		return
	var existing := bottom_bar.get_node_or_null("V2DirectControlGuide")
	if existing != null:
		existing.queue_free()
	var guide := Label.new()
	guide.name = "V2DirectControlGuide"
	guide.position = Vector2(14, 6)
	guide.size = Vector2(510, 54)
	guide.text = "左键角色：显示范围  ·  左键蓝格：移动\n左键红色敌人：攻击  ·  右键取消预览  ·  Esc取消选择\n中键拖动地图  ·  Home回到角色  ·  Space结束我方回合（随后敌人行动）"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 12)
	guide.add_theme_color_override("font_color", Color(0.64, 0.86, 0.93, 0.96))
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(guide)

func _setup_objective_state() -> void:
	# Start from the shared objective extraction, then apply V2-only pacing from
	# the V2 mission repository. This keeps V1 levels.json behavior untouched.
	super._setup_objective_state()
	if not _is_v2_battle() or mission_objective_state == null:
		return
	var repository := get_node_or_null("/root/V2Data")
	if repository == null or not repository.has_method("get_mission"):
		return
	var mission: Dictionary = repository.call("get_mission", StringName(level_id))
	if mission.is_empty() or not mission_objective_state.has_method("apply_v2_tutorial_overrides"):
		return
	mission_objective_state.call(
		"apply_v2_tutorial_overrides",
		int(mission.get("max_turns", 0)),
		int(mission.get("enemy_passive_turns", 0))
	)
	_sync_objective_state_from_mos()

func _setup_v2_services() -> void:
	super._setup_v2_services()
	if not _is_v2_battle():
		return
	var hazard_map: Dictionary = v2_mission_flow.map_data if v2_mission_flow != null else map_data
	var size_data: Dictionary = hazard_map.get("size", {})
	var hazard_map_size := Vector2i(int(size_data.get("width", map_width)), int(size_data.get("height", map_height)))
	v2_hazard_controller = V2HazardControllerScript.new()
	v2_hazard_controller.setup(hazard_map.get("hazards", hazard_map.get("environmental_hazards", [])), hazard_map_size)

func _finalize_v2_move(result: Dictionary) -> void:
	super._finalize_v2_move(result)
	if not _is_v2_battle() or level_id != "ch1_m1" or v2_mission_flow == null:
		return
	if v2_mission_flow.get_current_step_id() != "search_route_split" or selected_unit == null:
		return
	if not _v2_cell_in_list(selected_unit.grid_pos, map_data.get("route_split_cells", [])):
		return
	var entered := _apply_v2_mission_event(&"entered_route_split", {"position": selected_unit.grid_pos})
	if bool(entered.get("success", false)):
		_show_v2_route_choice()

func _show_v2_route_choice() -> void:
	if hud == null or v2_interaction_service == null:
		return
	var actions := [
		{
			"id": "camera_maintenance",
			"name": "摄像维护：提前侦察 / 警戒 +1",
			"description": "提前揭示救援区，但会提高警戒。",
			"disabled": false,
		},
		{
			"id": "cargo_breakthrough",
			"name": "货柜突破：路线较短 / 警戒不变",
			"description": "不提供救援区预览，但路径更短且不额外提高警戒。",
			"disabled": false,
		},
	]
	if v2_input_router:
		v2_input_router.set_state(V2BattleInputRouter.State.INTERACTION_MENU)
	hud.show_action_picker("路线分叉：选择一条推进路线", actions, Callable(self, "_on_v2_route_selected"))
	hud.set_context_prompt("两条路线都能到达吊机；选择后本关不再更换。")
	_render_v2_hud()

func _on_v2_route_selected(route_id: String) -> void:
	if v2_interaction_service == null or v2_mission_flow == null:
		return
	var route_result: Dictionary = v2_interaction_service.select_route(route_id)
	if not bool(route_result.get("success", false)):
		if hud:
			hud.show_action_reason(route_result.get("reason", "route_unavailable"))
		return
	var mission_result := _apply_v2_mission_event(&"route_selected", {"route_id": route_id})
	if not bool(mission_result.get("success", false)):
		if hud:
			hud.show_action_reason(mission_result.get("reason", "route_unavailable"))
		return
	if bool(route_result.get("raises_alert", false)) and alert_state:
		alert_state.apply_event("camera_identified_player")
	_update_v2_encounters([{"event": "route_selected", "route_id": route_id}])
	if hud:
		hud.hide_action_picker()
		hud.set_context_prompt("已选择%s。下一步：前往地图中上方吊机控制台并放下吊桥。" % String(route_result.get("route_name", route_id)))
	if v2_input_router:
		v2_input_router.set_state(V2BattleInputRouter.State.UNIT_SELECTED)
	if _is_v2_battle():
		GameManager.play_dialogue("ch1_m1_route" if level_id == "ch1_m1" else "ch1_m2_route")
	_record_v2_playtest_event(&"route_selected", {"route_id": route_id})
	_render_v2_hud()

func _start_battle() -> void:
	if boss_unit:
		AudioManager.bgm_boss()
	else:
		AudioManager.bgm_battle_layer(alert_state.get_alert_level() if alert_state else AlertState.LEVEL_CALM)
	current_encounter_id = "zone_a"
	var diff_params = GameManager.get_difficulty_params()
	var base_turn_limit := mission_objective_state.max_turns if mission_objective_state else int(level_config.get("max_turns", 20))
	var turn_limit = base_turn_limit + int(diff_params.get("turn_limit_bonus", 0))
	turn_limit = max(5, turn_limit)
	turn_manager.setup(player_units, enemy_units, turn_limit)
	action_system.set_units(player_units, enemy_units)
	if tactical_network_state and not map_data.is_empty():
		var nodes: Array = map_data.get("nodes", [])
		var connections: Array = map_data.get("connections", [])
		tactical_network_state.setup(nodes, connections)
		_render_network_nodes()
	enemy_director.max_reinforcements = int(level_config.get("max_reinforcements", 20))
	enemy_director.enemy_cap_per_wave = int(level_config.get("enemy_cap", 12))
	hud.set_battle_controller(self)
	_configure_v2_playtest_recorder()
	_v2_restore_attempted = false
	_v2_restore_failure.clear()
	turn_manager.start_battle()
	var restored_v2_checkpoint := _restore_v2_checkpoint()
	if restored_v2_checkpoint:
		_reconcile_v2_unit_occupancy()
	elif _v2_restore_attempted:
		_handle_v2_checkpoint_restore_failure(_v2_restore_failure)
		return
	else:
		_save_v2_checkpoint(&"cp_start")
	hud.update_objective(_get_objective_text())
	hud.update_turn_display(turn_manager.turn_number, TurnManager.TurnPhase.PLAYER_ACTION)
	hud.update_alert_display(alert_state)
	_render_v2_hud()
	_log("战斗开始！难度=%s 回合上限=%d" % [GameManager.get_settings().get("difficulty", "standard"), turn_limit])
	_begin_context_tutorials()
	_render_v2_hud()

func _save_v2_checkpoint(checkpoint_id: StringName) -> bool:
	if not _is_v2_battle() or GameManager.current_save.is_empty():
		return false
	var snapshot := V2CheckpointAdapterScript.capture({
		"game_line": "v2_infiltration",
		"level_id": level_id,
		"encounter_id": String(checkpoint_id),
		"checkpoint_id": String(checkpoint_id),
		"turn": turn_manager.turn_number if turn_manager else 0,
		"player_units": player_units,
		"enemy_units": enemy_units,
		"alert_state": alert_state.serialize() if alert_state else {},
		"visibility_state": visibility_state.serialize() if visibility_state else {},
		"facilities": v2_mission_flow.map_data.get("facilities", []) if v2_mission_flow else [],
		"encounter_state": v2_encounter_activation.get_snapshot() if v2_encounter_activation and v2_encounter_activation.has_method("get_snapshot") else {},
		"hazard_state": v2_hazard_controller.get_snapshot() if v2_hazard_controller and v2_hazard_controller.has_method("get_snapshot") else {},
		"facility_state": v2_interaction_service.get_snapshot() if v2_interaction_service and v2_interaction_service.has_method("get_snapshot") else {},
		"mission_flow": v2_mission_flow.get_snapshot() if v2_mission_flow else {},
		"enemy_intents": {},
		"turn_state": {"phase": turn_manager.current_phase if turn_manager else 0},
		"extra": {"checkpoint_id": String(checkpoint_id)},
	})
	var validation: Dictionary = V2CheckpointAdapterScript.validate(snapshot)
	if not bool(validation.get("valid", false)):
		_log("V2 检查点无效：%s" % "; ".join(validation.get("errors", [])))
		return false
	if not GameManager.set_v2_encounter_checkpoint(snapshot):
		_log("V2 检查点写入失败：%s" % checkpoint_id)
		return false
	v2_last_checkpoint = snapshot
	v2_last_checkpoint_id = String(checkpoint_id)
	return true

func _restore_v2_checkpoint() -> bool:
	var snapshot: Dictionary = GameManager.consume_v2_checkpoint_request()
	if snapshot.is_empty():
		return false
	_v2_restore_attempted = true
	_v2_restore_failure.clear()
	var validation: Dictionary = V2CheckpointAdapterScript.validate(snapshot)
	if not bool(validation.get("valid", false)):
		_log("V2 检查点校验失败，回退任务起点：%s" % "; ".join(validation.get("errors", [])))
		_v2_restore_failure = {"reason": &"invalid_snapshot", "validation": validation}
		GameManager.clear_v2_encounter_checkpoint()
		return false
	var player_ids: Dictionary = {}
	var staged_rescue_units: Array[Unit] = []
	for unit in player_units:
		if unit:
			player_ids[unit.entity_id] = true
	for raw_unit in snapshot.get("player_units", []):
		if not raw_unit is Dictionary:
			continue
		var data: Dictionary = raw_unit
		var entity_id := String(data.get("entity_id", ""))
		if entity_id.is_empty() or player_ids.has(entity_id):
			continue
		var position_data: Dictionary = data.get("grid_pos", {})
		var character_id := StringName(String(data.get("job", _get_v2_rescue_character_id())))
		var rescued := _create_v2_rescue_unit(character_id, entity_id, Vector2i(int(position_data.get("x", 0)), int(position_data.get("y", 0))))
		if rescued == null:
			_log("V2 检查点缺少可恢复角色：%s" % entity_id)
			_v2_restore_failure = {"reason": &"missing_player_entity", "entity_id": entity_id}
			_rollback_staged_v2_rescue_units(staged_rescue_units)
			GameManager.clear_v2_encounter_checkpoint()
			return false
		player_units.append(rescued)
		staged_rescue_units.append(rescued)
		player_ids[entity_id] = true
		if turn_manager:
			turn_manager.register_player_unit(rescued)
	var context := {
		"game_line": "v2_infiltration",
		"level_id": level_id,
		"encounter_id": String(snapshot.get("encounter_id", "")),
		"player_units": player_units,
		"enemy_units": enemy_units,
		"encounter_service": v2_encounter_activation,
		"facility_service": v2_interaction_service,
		"hazard_service": v2_hazard_controller,
		"mission_flow": v2_mission_flow,
	}
	var restored: Dictionary = V2CheckpointAdapterScript.restore_v2_layers(snapshot, context)
	if not bool(restored.get("success", false)):
		_log("V2 检查点恢复失败，回退任务起点：%s" % String(restored.get("reason", "unknown")))
		_v2_restore_failure = restored.duplicate(true)
		_rollback_staged_v2_rescue_units(staged_rescue_units)
		GameManager.clear_v2_encounter_checkpoint()
		return false
	var restored_snapshot: Dictionary = restored.get("snapshot", snapshot)
	if v2_rescue_controller and v2_mission_flow:
		var rescue_character_id := _get_v2_rescue_character_id()
		if bool(v2_mission_flow.rescued_characters.get(String(rescue_character_id), false)):
			v2_rescue_controller.restore_rescued_state(_get_v2_rescue_entity_id())
	if alert_state:
		alert_state.deserialize(restored_snapshot.get("alert_state", {}))
	if visibility_state and restored_snapshot.get("visibility_state", {}) is Dictionary:
		visibility_state.deserialize(restored_snapshot.get("visibility_state", {}))
	if action_system:
		action_system.set_units(player_units, enemy_units)
	if v2_action_service:
		v2_action_service.refresh_units(player_units, enemy_units)
	if turn_manager:
		turn_manager.turn_number = maxi(1, int(restored_snapshot.get("turn", 1)))
		turn_manager.current_phase = TurnManager.TurnPhase.PLAYER_ACTION
		turn_manager.battle_over = false
	current_encounter_id = String(restored_snapshot.get("encounter_id", "zone_a"))
	v2_last_checkpoint = restored_snapshot.duplicate(true)
	v2_last_checkpoint_id = String(restored_snapshot.get("checkpoint_id", ""))
	_sync_v2_enemy_sprites_after_restore()
	_update_visibility()
	_advance_v2_hazard_player_turn()
	_refresh_v2_runtime_state()
	_v2_restore_failure.clear()
	return true

func _rollback_staged_v2_rescue_units(staged_units: Array) -> void:
	for raw_unit in staged_units:
		var unit: Unit = raw_unit
		if unit == null:
			continue
		player_units.erase(unit)
		if is_instance_valid(unit):
			unit.free()
	if action_system:
		action_system.set_units(player_units, enemy_units)
	if v2_action_service:
		v2_action_service.refresh_units(player_units, enemy_units)

func _handle_v2_checkpoint_restore_failure(failure: Dictionary) -> void:
	var reason := String(failure.get("reason", "unknown"))
	_log("V2 检查点恢复中止：%s" % reason)
	if turn_manager:
		turn_manager.battle_over = true
		turn_manager.current_phase = TurnManager.TurnPhase.BATTLE_OVER
		turn_manager.input_locked = true
	var battle_result := {
		"result": "defeat",
		"level_id": level_id,
		"stars": 0,
		"turns": turn_manager.turn_number if turn_manager else 0,
		"units_survived": 0,
		"units_total": player_units.size(),
		"survivor_count": 0,
		"rewards": {},
		"rating": 0,
		"optional_credit": 0,
		"optional_resource_collected": false,
		"defeat_reason": "checkpoint_restore_failed",
		"restore_error": reason,
		"has_encounter_checkpoint": false,
		"encounter_id": "",
		"mission_id": level_id,
		"v2_restore_error": true,
	}
	_finish_v2_playtest(false, battle_result)
	_clear_v2_failed_restore_runtime_state()
	GameManager.go_to_mission_result(battle_result)

func _clear_v2_failed_restore_runtime_state() -> void:
	if unit_layer:
		for child in unit_layer.get_children():
			child.queue_free()
	_cleanup_units()
	v2_action_service = null
	v2_interaction_service = null
	v2_hazard_controller = null
	_v2_hazard_turn_state.clear()
	_render_v2_hazard_overlay()

func _generate_map() -> void:
	var result: Dictionary = V2RuntimeMapLoader.load_map(StringName(level_id))
	if not bool(result.get("success", false)):
		push_error("V2 map load failed: %s" % String(result.get("reason", "unknown")))
		return
	map_data = result.get("data", {}).duplicate(true)
	var size: Dictionary = map_data.get("size", {})
	map_width = int(size.get("width", 0))
	map_height = int(size.get("height", 0))
	mission_type = String(map_data.get("mission_type", "rescue_extract"))
	evac_cells.clear()
	for raw_entity in map_data.get("entities", []):
		if not raw_entity is Dictionary or String(raw_entity.get("type", "")) != "evac":
			continue
		var entity: Dictionary = raw_entity
		var center := Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))
		var radius := maxi(0, int(entity.get("radius", 0)))
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if GridSystem.is_in_bounds(cell, map_width, map_height) and GridSystem.manhattan_distance(center, cell) <= radius:
					evac_cells.append(cell)
	if action_system:
		action_system.set_map_data(map_data)
	GameManager.current_map_data = map_data.duplicate(true)

func _spawn_units() -> void:
	player_units.clear()
	enemy_units.clear()
	var repository: Node = get_node_or_null("/root/V2Data")
	if repository == null:
		push_error("V2 roster load failed: V2Data autoload missing")
		return
	var mission: Dictionary = repository.get_mission(StringName(level_id)) if repository.has_method("get_mission") else {}
	var selected: Array = GameManager.current_save.get("selected_squad", [])
	if selected.is_empty():
		selected = mission.get("starting_roster", ["assault"])
	var spawn_entities: Array = []
	for raw_entity in map_data.get("entities", []):
		if raw_entity is Dictionary and String(raw_entity.get("type", "")) == "spawn_player":
			spawn_entities.append(raw_entity)
	for index in range(mini(selected.size(), spawn_entities.size())):
		var character_id := StringName(String(selected[index]))
		var character_data: Dictionary = repository.get_character(character_id) if repository.has_method("get_character") else {}
		if character_data.is_empty():
			continue
		var spawn: Dictionary = spawn_entities[index]
		var unit: Unit = GameData.create_v2_player_unit(character_data)
		unit.entity_id = String(spawn.get("id", "player_%d" % index))
		unit.grid_pos = Vector2i(int(spawn.get("x", 0)), int(spawn.get("y", 0)))
		unit.height = MapLoader.get_height_at(map_data, unit.grid_pos.x, unit.grid_pos.y)
		player_units.append(unit)

func _render_map() -> void:
	for child in map_layer.get_children():
		child.queue_free()
	var layers: Dictionary = map_data.get("layers", {})
	var base_terrain: Array = layers.get("base_terrain", [])
	var blockers: Array = layers.get("blocker", [])
	var environment: Dictionary = map_data.get("environment", {})
	var environment_kit := String(environment.get("kit", map_data.get("theme", "")))
	for y in range(map_height):
		for x in range(map_width):
			var terrain := int(base_terrain[y][x]) if y < base_terrain.size() and x < base_terrain[y].size() else 0
			var blocker := int(blockers[y][x]) if y < blockers.size() and x < blockers[y].size() else 0
			var cell := Vector2i(x, y)
			var cell_kit := _get_environment_kit_for_cell(cell, environment_kit)
			_draw_tactical_tile(cell, terrain, blocker, "", cell_kit, _get_environment_variant(cell, "floor", 8), _get_terrain_edge_variants(cell, terrain), _get_blocker_variant(cell, blocker))
	_render_environment_decorations(environment_kit, environment.get("decorations", []))
	_render_v2_map_entities()
	_render_evac_zone()

func _get_environment_kit_for_cell(cell: Vector2i, default_kit: String) -> String:
	var environment: Dictionary = map_data.get("environment", {})
	for raw_override in environment.get("kit_overrides", []):
		if not raw_override is Dictionary:
			continue
		var override: Dictionary = raw_override
		var origin := Vector2i(int(override.get("x", -1)), int(override.get("y", -1)))
		var size := Vector2i(maxi(1, int(override.get("width", 1))), maxi(1, int(override.get("height", 1))))
		if Rect2i(origin, size).has_point(cell):
			return String(override.get("kit", default_kit))
	return default_kit

func _render_v2_map_entities() -> void:
	for raw_entity in map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		var kind := String(entity.get("type", ""))
		var position := Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))
		if not GridSystem.is_in_bounds(position, map_width, map_height):
			continue
		if kind == "evac":
			var marker := Node2D.new()
			marker.name = "V2EvacMarker"
			marker.position = _get_cell_center(position)
			marker.z_index = 3
			var icon := Sprite2D.new()
			icon.name = "V2EvacIcon"
			icon.texture = ArtCatalog.get_texture(&"objective", &"evac")
			icon.scale = Vector2(0.75, 0.75)
			icon.z_index = 1
			marker.add_child(icon)
			var ring := Polygon2D.new()
			ring.name = "V2EvacRing"
			ring.polygon = PackedVector2Array([Vector2(0, -28), Vector2(28, 0), Vector2(0, 28), Vector2(-28, 0)])
			ring.color = Color(0.12, 0.95, 0.72, 0.78)
			marker.add_child(ring)
			var label := Label.new()
			label.name = "V2EvacLabel"
			label.text = "撤离点\n营救后前往"
			label.position = Vector2(-72, -66)
			label.size = Vector2(144, 48)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", Color(0.70, 1.0, 0.88, 1.0))
			label.add_theme_color_override("font_shadow_color", Color(0.02, 0.10, 0.08, 1.0))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.add_child(label)
			map_layer.add_child(marker)
		elif kind == "facility_marker":
			var facility_node := Node2D.new()
			facility_node.name = "V2Facility_%s" % String(entity.get("id", "facility"))
			facility_node.position = _get_cell_center(position)
			facility_node.z_index = 4
			var facility_icon := Sprite2D.new()
			facility_icon.texture = ArtCatalog.get_texture(&"network_node", &"camera") if String(entity.get("facility_type", "")) == "camera" else ArtCatalog.get_texture(&"objective", &"terminal")
			facility_icon.scale = Vector2(0.78, 0.78)
			facility_node.add_child(facility_icon)
			var facility_label := Label.new()
			facility_label.text = "摄像头" if String(entity.get("facility_type", "")) == "camera" else "终端"
			facility_label.position = Vector2(-48, 22)
			facility_label.size = Vector2(96, 22)
			facility_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			facility_label.add_theme_font_size_override("font_size", 12)
			facility_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.34, 0.98))
			facility_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			facility_node.add_child(facility_label)
			map_layer.add_child(facility_node)

func _render_evac_zone() -> void:
	_clear_layer(evac_zone_layer)
	for cell in evac_cells:
		_highlight_cell(evac_zone_layer, cell, Color(0.0, 0.88, 0.72, 0.18))

func _update_v2_evac_marker() -> void:
	var marker := map_layer.get_node_or_null("V2EvacMarker") as Node2D
	if marker == null:
		return
	var label := marker.get_node_or_null("V2EvacLabel") as Label
	var ring := marker.get_node_or_null("V2EvacRing") as Polygon2D
	var unlocked := v2_mission_flow != null and String(v2_mission_flow.get_state_name()) == "ESCORT_TO_EVAC"
	if label != null:
		label.text = "撤离点\n进入后自动完成" if unlocked else "撤离点\n营救后前往"
	if ring != null:
		ring.color = Color(0.12, 0.95, 0.72, 0.92) if unlocked else Color(0.42, 0.72, 0.62, 0.78)

func _play_intro_then_start() -> void:
	# The V2 base already plays its dedicated briefing. Never queue V1 dialogue
	# or V1 modal tutorials over the first playable frame.
	await get_tree().process_frame
	_begin_tutorials_or_start()

func _begin_tutorials_or_start() -> void:
	# V2 starts immediately, then uses the non-blocking V2 tutorial state machine.
	_start_battle()

func _on_phase_changed(phase: TurnManager.TurnPhase) -> void:
	if phase == TurnManager.TurnPhase.PLAYER_ACTION:
		_advance_v2_hazard_player_turn()
	elif phase == TurnManager.TurnPhase.ENEMY_ACTION:
		_consume_v2_hazard_enemy_phase()
	super._on_phase_changed(phase)

func _run_enemy_turn() -> void:
	await run_v2_enemy_turn()

func _is_v2_m1_tutorial_safety_active() -> bool:
	if not _is_v2_battle() or level_id != "ch1_m1" or v2_tutorial_flow == null:
		return false
	var player_turn := turn_manager.turn_number if turn_manager else 1
	return v2_tutorial_flow.has_method("is_m1_safety_active") and bool(v2_tutorial_flow.is_m1_safety_active(player_turn))

func _is_v2_enemy_turn_passive() -> bool:
	if _is_v2_m1_tutorial_safety_active():
		return false
	return _is_v2_battle() and mission_objective_state != null and mission_objective_state.is_enemy_passive(turn_manager.turn_number if turn_manager else 1)

func run_v2_enemy_turn() -> void:
	if _is_v2_enemy_turn_passive():
		_log("教学宽限：敌人观察小队，本回合不执行攻击或移动")
		_refresh_v2_runtime_state()
		if turn_manager and not turn_manager.battle_over:
			turn_manager.end_enemy_turn()
		return
	for raw_enemy in enemy_units:
		var enemy: Unit = raw_enemy
		if enemy == null or not enemy.is_alive or turn_manager == null or turn_manager.battle_over:
			continue
		_execute_v2_enemy_action(enemy)
		await get_tree().create_timer(0.12).timeout
	if turn_manager and not turn_manager.battle_over:
		_reconcile_v2_unit_occupancy()
		_refresh_v2_runtime_state()
		turn_manager.end_enemy_turn()

## V2 previews use the same strategy result that the enemy executor will
## commit. The base controller keeps its V1 UtilityAI preview untouched.
func _plan_enemy_intents() -> void:
	if not _is_v2_battle():
		super._plan_enemy_intents()
		return
	if not enemy_intent_state:
		return
	enemy_intent_state.clear()
	var context := _build_v2_enemy_context()
	for raw_enemy in enemy_units:
		var enemy: Unit = raw_enemy
		if enemy == null or not enemy.is_alive or enemy.current_ap <= 0:
			continue
		var intent: Dictionary = V2EnemyBrainScript.plan_intent(enemy, context)
		var public_intent := intent.duplicate(true)
		public_intent["type"] = String(intent.get("type", "guard"))
		public_intent["target_pos"] = intent.get("target_cell", enemy.grid_pos)
		var target := _find_v2_player(String(intent.get("target_id", "")))
		public_intent["lethal"] = String(intent.get("type", "")) == "attack" and target != null and int(intent.get("damage", 0)) >= target.current_hp
		enemy_intent_state.set_intent(enemy.entity_id, public_intent)
	_enemy_intents_planned = true
	_advance_v2_tutorial(&"enemy_intent_observed")
	_refresh_enemy_intent_display()

func _advance_v2_hazard_player_turn() -> Dictionary:
	if not _is_v2_battle() or v2_hazard_controller == null or not v2_hazard_controller.has_method("advance_player_turn"):
		_v2_hazard_turn_state.clear()
		_render_v2_hazard_overlay()
		return {}
	var turn := turn_manager.turn_number if turn_manager else 1
	_v2_hazard_turn_state = v2_hazard_controller.advance_player_turn(turn)
	_render_v2_hazard_overlay()
	_apply_v2_hazard_prompt(_v2_hazard_turn_state)
	return _v2_hazard_turn_state.duplicate(true)

func _consume_v2_hazard_enemy_phase() -> Array:
	if not _is_v2_battle() or v2_hazard_controller == null or not v2_hazard_controller.has_method("consume_enemy_phase_damage"):
		return []
	if _is_v2_m1_tutorial_safety_active() or _is_v2_enemy_turn_passive():
		return []
	var turn := turn_manager.turn_number if turn_manager else 1
	var events: Array = v2_hazard_controller.consume_enemy_phase_damage(turn)
	if events.is_empty():
		return []
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var damage := int(event.get("damage", 0))
		var cells := _v2_cell_set(event.get("cells", []))
		for raw_unit in player_units + enemy_units:
			var unit: Unit = raw_unit
			if unit == null or not unit.is_alive or not cells.has(unit.grid_pos):
				continue
			unit.take_damage(damage)
			_update_unit_sprite_pos(unit, true)
			_log("危险区 %s 对 %s 造成 %d 伤害" % [String(event.get("hazard_id", "")), unit.unit_name, damage])
	_refresh_v2_runtime_state()
	return events

func _commit_v2_hazard_close_action(action_id: String) -> Dictionary:
	if not _is_v2_battle() or v2_hazard_controller == null or not v2_hazard_controller.has_method("commit_close_action"):
		return {"success": false, "reason": &"hazard_controller_unavailable"}
	var result: Dictionary = v2_hazard_controller.commit_close_action(action_id)
	if bool(result.get("success", false)):
		_advance_v2_hazard_player_turn()
	return result

func _apply_v2_interaction_result(result: Dictionary) -> void:
	super._apply_v2_interaction_result(result)
	var action_id := String(result.get("action_id", ""))
	if action_id in ["view_camera_east", "view_rescue_zone"]:
		var center: Vector2i = result.get("reveal_center", selected_unit.grid_pos if selected_unit else Vector2i(-1, -1))
		if center.x >= 0 and center.y >= 0:
			begin_v2_camera_inspection(center, maxi(7, int(result.get("reveal_radius", 7))))
		if hud and is_v2_camera_inspecting():
			hud.set_context_prompt("摄像头视角：查看东侧区域；按 F 或返回队员继续战术行动。")
	if level_id == "ch1_m2":
		if action_id in ["cut_power_grid", "bypass_security_door"]:
			_apply_v2_map_changes(result.get("map_changes", []), "open")
			var lockdown_result := _apply_v2_mission_event(&"lockdown_cleared", {
				"route_id": String(result.get("route_id", "")),
				"map_changes": result.get("map_changes", []),
				"enemy_intent_changes": result.get("enemy_intent_changes", {}),
			})
			_update_v2_encounters([{"event": "route_selected", "route_id": String(result.get("route_id", ""))}])
			if hud and bool(lockdown_result.get("success", false)):
				hud.set_context_prompt("封锁已解除：%s。下一步前往中央涡轮大厅。" % String(result.get("consequence", "路线已开放")))
			GameManager.play_dialogue("ch1_m2_route")
		elif action_id == "show_sniper_ability":
			var showcase := _apply_v2_mission_event(&"sniper_ability_showcase", {"sniper_lines_visible": true})
			if hud and bool(showcase.get("success", false)):
				hud.set_context_prompt("狙击手已完成远程火力演示。下一步：带小队前往北侧撤离门。")
			GameManager.play_dialogue("ch1_m2_turbine")
			_record_v2_playtest_event(&"sniper_ability_showcase", {})

	if action_id == "lower_gantry":
		_apply_v2_map_changes(result.get("map_changes", []), "open")
		var gantry_event := _apply_v2_mission_event(&"gantry_lowered", {
			"route_id": String(result.get("route_id", "gantry_bridge")),
			"map_changes": result.get("map_changes", []),
			"enemy_intent_changes": result.get("enemy_intent_changes", {}),
		})
		if bool(gantry_event.get("success", false)) and hud:
			hud.set_context_prompt("通路已放下。下一步：沿吊桥通路前往中部青色侦察标记并营救侦察兵。")
		if _is_v2_battle() and level_id == "ch1_m1":
			GameManager.play_dialogue("ch1_m1_gantry")
		_record_v2_playtest_event(&"gantry_lowered", {"route_id": String(result.get("route_id", "gantry_bridge"))})
	var close_result := {}
	if action_id == "shutdown_cooling_nozzles":
		close_result = _commit_v2_hazard_close_action(action_id)
		var cooling_event := _apply_v2_mission_event(&"cooling_nozzles_shutdown", {"hazard_closed": true})
		if hud and bool(cooling_event.get("success", false)):
			hud.set_context_prompt("冷却喷口已关闭，危险周期停止；突击模块 B 已解锁。")
		GameManager.play_dialogue("ch1_m2_cooling")
	else:
		close_result = _commit_v2_hazard_close_action(action_id)
	if bool(close_result.get("success", false)) and hud:
		hud.set_context_prompt("危险区已关闭：%s" % ", ".join(close_result.get("closed_now", [])))
		_render_v2_hud()
	elif _is_v2_battle():
		_render_v2_hud()

func _on_v2_rescue_committed(result: Dictionary) -> void:
	super._on_v2_rescue_committed(result)
	if not _is_v2_battle() or level_id != "ch1_m1":
		if level_id == "ch1_m2" and hud:
			hud.set_context_prompt("狙击手已加入小队。前往中央涡轮大厅，点击涡轮封锁并选择“标记北侧威胁”。")
			GameManager.play_dialogue("ch1_m2_rescue")
			_render_v2_hud()
		return
	var route_changes: Dictionary = map_data.get("route_changes", {})
	var lockdown: Array = []
	for raw_cell in route_changes.get("rescue_lockdown", []):
		lockdown.append({"cell": raw_cell, "state": "closed"})
	_apply_v2_map_changes(lockdown, "closed")
	var intercept := _apply_v2_mission_event(&"evac_intercept_started", {"enemy_ids": ["m1_sniper_evac_a", "m1_sniper_evac_b"]})
	_update_v2_encounters([{"event": "pre_evac"}])
	if hud and bool(intercept.get("success", false)):
		hud.set_context_prompt("营救触发撤离拦截：东北直通线已封锁。沿吊桥通路前往右上方绿色撤离标记。")
		GameManager.play_dialogue("ch1_m1_intercept")
	_render_v2_hud()

func _prepare_v2_m2_evac() -> void:
	if level_id != "ch1_m2" or v2_mission_flow == null:
		return
	var flags: Dictionary = v2_mission_flow.get_snapshot().get("mission_flags", {})
	if bool(flags.get("engineer_countermeasure_started", false)):
		return
	var route_changes: Array = []
	for raw_cell in map_data.get("route_changes", {}).get("rescue_exit_intercept", []):
		route_changes.append({"cell": raw_cell, "state": "closed"})
	_apply_v2_map_changes(route_changes, "closed")
	var countermeasure := _apply_v2_mission_event(&"engineer_countermeasure_started", {
		"map_changes": route_changes,
		"enemy_ids": ["m2_sniper_exit", "m2_drone_exit"],
	})
	_update_v2_encounters([{"event": "pre_evac"}])
	if hud and bool(countermeasure.get("success", false)):
		hud.set_context_prompt("工程师反制启动：北侧直线路径已封锁，沿东侧高架桥进入撤离门。")
		GameManager.play_dialogue("ch1_m2_countermeasure")
	_render_v2_hud()

func _apply_v2_map_changes(raw_changes: Variant, default_state: String) -> void:
	if not raw_changes is Array:
		return
	var changes: Array = []
	for raw_change in raw_changes:
		var cell := _parse_v2_hazard_cell(raw_change.get("cell", raw_change) if raw_change is Dictionary else raw_change)
		if cell.x < 0:
			continue
		var state := String(raw_change.get("state", default_state)) if raw_change is Dictionary else default_state
		changes.append({"cell": [cell.x, cell.y], "state": state})
		var layers: Dictionary = map_data.get("layers", {})
		var blockers: Variant = layers.get("blocker", [])
		if blockers is Array and cell.y < (blockers as Array).size() and (blockers as Array)[cell.y] is Array:
			var row: Array = (blockers as Array)[cell.y]
			if cell.x < row.size():
				row[cell.x] = 0 if state == "open" else 5
		if v2_mission_flow != null:
			var flow_layers: Dictionary = v2_mission_flow.map_data.get("layers", {})
			var flow_blockers: Variant = flow_layers.get("blocker", [])
			if flow_blockers is Array and cell.y < (flow_blockers as Array).size() and (flow_blockers as Array)[cell.y] is Array:
				var flow_row: Array = (flow_blockers as Array)[cell.y]
				if cell.x < flow_row.size():
					flow_row[cell.x] = 0 if state == "open" else 5
	if v2_action_service and v2_action_service.has_method("apply_map_changes"):
		v2_action_service.apply_map_changes(changes)
	if not changes.is_empty():
		_render_map()
		_render_v2_rescue_marker()
		_update_visibility()

func _v2_cell_in_list(cell: Vector2i, raw_cells: Variant) -> bool:
	if not raw_cells is Array:
		return false
	for raw_cell in raw_cells:
		if _parse_v2_hazard_cell(raw_cell) == cell:
			return true
	return false

func _render_v2_hazard_overlay() -> void:
	if effect_layer == null:
		return
	for child in effect_layer.get_children():
		if String(child.name).begins_with("V2HazardOverlay_"):
			child.free()
	var warning_cells: Array = _v2_hazard_turn_state.get("warning_cells", [])
	var active_cells: Array = _v2_hazard_turn_state.get("active_cells", [])
	for raw_cell in warning_cells:
		var cell := _parse_v2_hazard_cell(raw_cell)
		if cell.x >= 0:
			_draw_v2_hazard_cell(cell, Color(1.0, 0.78, 0.12, 0.32), "warning")
	for raw_cell in active_cells:
		var cell := _parse_v2_hazard_cell(raw_cell)
		if cell.x >= 0:
			_draw_v2_hazard_cell(cell, Color(1.0, 0.14, 0.08, 0.44), "active")

func _draw_v2_hazard_cell(cell: Vector2i, color: Color, kind: String) -> void:
	var overlay := Polygon2D.new()
	overlay.name = "V2HazardOverlay_%s_%d_%d" % [kind, cell.x, cell.y]
	overlay.position = GridSystem.grid_to_world(cell)
	overlay.polygon = PackedVector2Array([
		Vector2(6, 6),
		Vector2(CELL_SIZE - 6, 6),
		Vector2(CELL_SIZE - 6, CELL_SIZE - 6),
		Vector2(6, CELL_SIZE - 6),
	])
	overlay.color = color
	overlay.z_index = 5
	effect_layer.add_child(overlay)

func _apply_v2_hazard_prompt(state: Dictionary) -> void:
	if hud == null:
		return
	var warning_count := (state.get("warning_cells", []) as Array).size()
	var active_count := (state.get("active_cells", []) as Array).size()
	if active_count > 0:
		hud.set_context_prompt("危险区已生效：敌方阶段会结算 %d 个危险格" % active_count)
	elif warning_count > 0:
		hud.set_context_prompt("危险区预警：%d 个格子将在下一轮生效" % warning_count)

## V2 owns the mission-facing HUD contract. V1 and the shared controller keep
## their original presentation paths; this override is only reached by the V2
## battle scene.
func _render_v2_hud(context_override: String = "") -> void:
	if not _is_v2_battle() or v2_hud_presenter == null or hud == null:
		return
	_render_v2_guidance()
	v2_hud_presenter.render(_build_v2_hud_snapshot(context_override))

func _build_v2_hud_snapshot(context_override: String = "") -> Dictionary:
	var mission_snapshot: Dictionary = v2_mission_flow.get_snapshot() if v2_mission_flow != null and v2_mission_flow.has_method("get_snapshot") else {}
	var objective_text: String = String(v2_mission_flow.get_primary_text()) if v2_mission_flow != null and v2_mission_flow.has_method("get_primary_text") else String(_get_objective_text())
	var guide_text: String = String(v2_mission_flow.get_current_guide_text()) if v2_mission_flow != null and v2_mission_flow.has_method("get_current_guide_text") else ""
	var step_id := String(v2_mission_flow.get_current_step_id()) if v2_mission_flow != null and v2_mission_flow.has_method("get_current_step_id") else ""
	var raw_step_index := int(v2_mission_flow.get_objective_step_index()) if v2_mission_flow != null and v2_mission_flow.has_method("get_objective_step_index") else 0
	var step_index := int(v2_mission_flow.get_display_objective_step_index()) if v2_mission_flow != null and v2_mission_flow.has_method("get_display_objective_step_index") else raw_step_index
	var step_count := int(v2_mission_flow.get_display_objective_step_count()) if v2_mission_flow != null and v2_mission_flow.has_method("get_display_objective_step_count") else (int(v2_mission_flow.get_objective_step_count()) if v2_mission_flow != null and v2_mission_flow.has_method("get_objective_step_count") else 0)
	var route_hint := _get_v2_route_hint(mission_snapshot, raw_step_index)
	var hazard_warning := _get_v2_hazard_warning()
	var checkpoint_id := v2_last_checkpoint_id
	if checkpoint_id.is_empty():
		checkpoint_id = String(v2_last_checkpoint.get("checkpoint_id", ""))
	var phase_text := _get_v2_phase_text()
	var ordinary_controls := "左键角色显示范围 · 蓝格移动 · 红色敌人攻击 · 右键取消预览 · Esc取消选择 · 中键拖动地图 · Home回到角色 · Space结束我方回合（随后敌人行动）"
	var context_prompt := context_override
	if context_prompt.is_empty() and hud != null:
		context_prompt = hud.get_context_prompt_text()

	var status := ""
	var outcome_text := ""
	if v2_mission_flow != null:
		if v2_mission_flow.has_method("is_defeat") and v2_mission_flow.is_defeat():
			status = "failure"
			outcome_text = "任务失败"
		elif v2_mission_flow.has_method("is_victory") and v2_mission_flow.is_victory():
			status = "victory"
			outcome_text = "任务完成"

	var alert_name := "平静"
	var next_text := ""
	if alert_state:
		alert_name = alert_state.get_front_state_label()
		var next_consequence: Dictionary = alert_state.get_next_consequence()
		next_text = String(next_consequence.get("description", ""))
		var turns_until := int(next_consequence.get("turns_until", 0))
		if turns_until > 0:
			next_text += "（%d回合后）" % turns_until

	var budget := {"move": false, "action": false}
	if selected_unit and is_instance_valid(selected_unit) and selected_unit.team == "player":
		budget["move"] = selected_unit.can_move()
		budget["action"] = selected_unit.can_act()
	var tutorial_hint: Dictionary = v2_tutorial_flow.get_hint() if v2_tutorial_flow != null and v2_tutorial_flow.has_method("get_hint") else {"visible": false}
	return {
		"mission_id": level_id,
		"step_id": step_id,
		"step_index": step_index,
		"step_count": step_count,
		"objective_text": objective_text,
		"guide_text": guide_text,
		"guide_cell": v2_mission_flow.get_current_guide_cell() if v2_mission_flow != null and v2_mission_flow.has_method("get_current_guide_cell") else Vector2i(-1, -1),
		"route_hint": route_hint,
		"hazard_warning": hazard_warning,
		"checkpoint_id": checkpoint_id,
		"turn": turn_manager.turn_number if turn_manager else 0,
		"phase": phase_text,
		"current_turn": turn_manager.turn_number if turn_manager else 0,
		"current_phase": phase_text,
		"status": status,
		"outcome_text": outcome_text,
		"state": v2_input_router.get_state_name() if v2_input_router else "free_select",
		"primary_objective": objective_text,
		"mission_guide": guide_text,
		"ordinary_controls": ordinary_controls,
		"alert": alert_name,
		"next_consequence": next_text,
		"selected": selected_unit,
		"context_prompt": context_prompt,
		"action_budget": budget,
		"ability": "",
		"interaction": "设施菜单：选择一个操作" if not v2_pending_interaction_facility_id.is_empty() else "",
		"attack_preview": hud.get_attack_preview_text() if hud else "",
		"visibility_summary": v2_visibility_summary.duplicate(true),
		"tutorial_hint": tutorial_hint,
		"m1_safe_tutorial_complete": v2_tutorial_flow.is_m1_safe_tutorial_complete() if v2_tutorial_flow != null and v2_tutorial_flow.has_method("is_m1_safe_tutorial_complete") else false,
	}

func _get_v2_phase_text() -> String:
	if turn_manager == null:
		return ""
	match turn_manager.current_phase:
		TurnManager.TurnPhase.ENEMY_ACTION:
			return "敌人回合"
		TurnManager.TurnPhase.BATTLE_OVER:
			return "战斗结束"
		_:
			return "玩家回合"

func _get_v2_route_hint(mission_snapshot: Dictionary, step_index: int) -> String:
	var route_hint := String(mission_snapshot.get("route_hint", ""))
	if not route_hint.is_empty():
		return route_hint
	if v2_mission_flow != null:
		var mission_data: Dictionary = v2_mission_flow.mission
		var steps: Variant = mission_data.get("expanded_objective_steps", []) if bool(mission_data.get("expanded_flow", false)) else mission_data.get("objective_steps", [])
		if steps is Array and step_index >= 0 and step_index < steps.size() and steps[step_index] is Dictionary:
			route_hint = String((steps[step_index] as Dictionary).get("route_hint", ""))
		if route_hint.is_empty():
			route_hint = String(mission_data.get("route_hint", ""))
	if route_hint.is_empty():
		route_hint = String(map_data.get("route_hint", ""))
	return route_hint

func _get_v2_hazard_warning() -> String:
	var active_cells: Array = _v2_hazard_turn_state.get("active_cells", [])
	var warning_cells: Array = _v2_hazard_turn_state.get("warning_cells", [])
	if not active_cells.is_empty():
		return "危险区已生效：敌方阶段结算 %d 个危险格" % active_cells.size()
	if not warning_cells.is_empty():
		return "危险区预警：%d 个格子将在下一轮生效" % warning_cells.size()
	return ""

func _v2_cell_set(raw_cells: Variant) -> Dictionary:
	var cells: Dictionary = {}
	if raw_cells is Array:
		for raw_cell in raw_cells:
			var cell := _parse_v2_hazard_cell(raw_cell)
			if cell.x >= 0:
				cells[cell] = true
	return cells

func _parse_v2_hazard_cell(raw_cell: Variant) -> Vector2i:
	if raw_cell is Vector2i:
		return raw_cell
	if raw_cell is Vector2:
		return Vector2i(raw_cell)
	if raw_cell is Array and raw_cell.size() >= 2:
		return Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	if raw_cell is Dictionary:
		return Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
	return Vector2i(-1, -1)

func _update_v2_encounters(mission_events: Array) -> Dictionary:
	if not _is_v2_battle() or v2_encounter_activation == null:
		return {"success": false, "reason": &"encounter_activation_unavailable"}
	for position in _get_v2_player_positions():
		_check_encounter_zone(position)
	var result: Dictionary = v2_encounter_activation.update(
		_get_v2_player_positions(),
		mission_events,
		_get_v2_live_enemy_ids(),
		_get_v2_occupied_positions()
	)
	_apply_encounter_delta(result)
	return result

func _apply_encounter_delta(delta: Dictionary) -> void:
	if v2_encounter_activation == null:
		return
	var changed := false
	var defeated_ids: Array = v2_encounter_activation.get_defeated_enemy_ids()
	var departed_ids: Array = v2_encounter_activation.get_departed_enemy_ids()
	# The encounter state is authoritative for both active and waiting departures.
	# Trigger deltas report both, while the persistent departed set also covers
	# cleanup on repeated refreshes.
	for raw_id in departed_ids:
		var entity_id := String(raw_id)
		var departed_unit := _get_v2_enemy_unit(entity_id)
		if departed_unit == null:
			continue
		if departed_unit.is_alive:
			departed_unit.is_alive = false
			changed = true
		# V2ActionService treats non-downed inactive enemies as reserved spawn
		# cells. Departed is a terminal, occupancy-free lifecycle state.
		if not departed_unit.is_downed:
			departed_unit.is_downed = true
			changed = true
		var departed_sprite := _get_unit_sprite(departed_unit)
		if departed_sprite != null:
			_remove_v2_enemy_sprite(departed_sprite)
			changed = true
	for raw_id in defeated_ids:
		var defeated_id := String(raw_id)
		var defeated_unit := _get_v2_enemy_unit(defeated_id)
		if defeated_unit == null:
			continue
		if defeated_unit.is_alive:
			defeated_unit.is_alive = false
			defeated_unit.is_downed = true
			changed = true
		var corpse_sprite := _get_unit_sprite(defeated_unit)
		if corpse_sprite != null:
			_remove_v2_enemy_sprite(corpse_sprite)
			changed = true
	for raw_id in delta.get("activated_ids", []):
		var entity_id := String(raw_id)
		var unit := _get_v2_enemy_unit(entity_id)
		if unit == null or not v2_encounter_activation.is_active(entity_id):
			continue
		if unit.is_alive:
			continue
		var spawn_cell := _find_v2_spawn_cell(entity_id, unit)
		if spawn_cell.x < 0:
			v2_encounter_activation.defer_enemy_spawn(entity_id)
			continue
		unit.grid_pos = spawn_cell
		unit.is_alive = true
		unit.is_downed = false
		unit.current_hp = unit.max_hp
		if _v2_units_rendered and _get_unit_sprite(unit) == null:
			_create_unit_sprite(unit)
		changed = true
	if not changed:
		return
	if action_system:
		action_system.set_units(player_units, enemy_units)
	if v2_action_service:
		v2_action_service.refresh_units(player_units, enemy_units)
	_reconcile_v2_unit_occupancy()
	_refresh_enemy_sprite_visibility()
	_update_visibility()
	_refresh_enemy_intent_display()
	if v2_interaction_service != null and v2_encounter_activation != null:
		var defeated: Array = v2_encounter_activation.get_defeated_enemy_ids()
		if "m1_sentry_record" in defeated and "m1_engineer_record" in defeated:
			v2_interaction_service.mark_encounter_cleared("m1_e03_record")

func _on_unit_died(unit: Unit) -> void:
	super._on_unit_died(unit)
	if not _is_v2_battle() or v2_encounter_activation == null or unit == null:
		return
	var result: Dictionary = v2_encounter_activation.mark_enemy_defeated(unit.entity_id)
	if not bool(result.get("success", false)):
		return
	var delta: Dictionary = v2_encounter_activation.update(
		_get_v2_player_positions(),
		[],
		_get_v2_live_enemy_ids(),
		_get_v2_occupied_positions()
	)
	_apply_encounter_delta(delta)

func _get_v2_enemy_unit(entity_id: String) -> Unit:
	for raw_unit in enemy_units:
		var unit: Unit = raw_unit
		if unit != null and unit.entity_id == entity_id:
			return unit
	return null

func _get_v2_live_enemy_ids() -> Array:
	var ids: Array = []
	for raw_unit in enemy_units:
		var unit: Unit = raw_unit
		if unit != null and unit.is_alive:
			ids.append(unit.entity_id)
	ids.sort()
	return ids

func _get_v2_occupied_positions() -> Array:
	var positions: Array = []
	for raw_unit in player_units + enemy_units:
		var unit: Unit = raw_unit
		if unit != null and unit.is_alive:
			positions.append(unit.grid_pos)
	return positions

func _find_v2_spawn_cell(entity_id: String, unit: Unit) -> Vector2i:
	var occupied := {}
	for raw_unit in player_units + enemy_units:
		var other: Unit = raw_unit
		if other != null and other != unit and other.is_alive:
			occupied[other.grid_pos] = true
	if v2_encounter_activation.has_method("get_spawn_cells"):
		for raw_cell in v2_encounter_activation.get_spawn_cells(entity_id):
			var cell: Vector2i = raw_cell if raw_cell is Vector2i else Vector2i(-1, -1)
			if cell.x < 0 or not GridSystem.is_in_bounds(cell, map_width, map_height) or occupied.has(cell):
				continue
			if not map_data.is_empty() and not MapLoader.is_passable(map_data, cell.x, cell.y):
				continue
			return cell
	return Vector2i(-1, -1)

func _execute_v2_enemy_action(enemy: Unit) -> void:
	var context := _build_v2_enemy_context()
	var intent: Dictionary = V2EnemyBrainScript.plan_intent(enemy, context)
	var result: Dictionary = V2IntentExecutorScript.execute(intent, context)
	if not bool(result.get("success", false)):
		return
	match StringName(result.get("type", &"wait")):
		&"attack":
			var target := _find_v2_player(String(result.get("target_id", "")))
			if target != null:
				target.take_damage(_v2_tutorial_safe_damage(enemy, target, int(result.get("damage", 0))))
				_update_unit_sprite_pos(target, true)
		&"move":
			var target_cell: Variant = result.get("target_cell", Vector2i(-1, -1))
			# The intent executor validates occupancy first, but the live roster is
			# authoritative at commit time. Never let an AI move share a player cell.
			if target_cell is Vector2i and not _is_occupied_by_other_unit(target_cell, enemy) and enemy.spend_v2_move():
				enemy.move_to(target_cell)
				_update_unit_sprite_pos(enemy, true)
		&"scan":
			if alert_state:
				alert_state.apply_event(&"drone_scan_completed")
			_log("侦察无人机扫描 %s，警戒等级更新" % String(result.get("target_cell", enemy.grid_pos)))
		&"protect":
			_log("盾卫保护 %s，减伤 %d" % [String(result.get("target_id", "")), int(result.get("protect_reduction", 0))])
		&"guard":
			if String(result.get("fallback_reason", "")) != "":
				_log("%s 守住当前位置（%s）" % [enemy.unit_name, String(result.get("fallback_reason", ""))])
	_reconcile_v2_unit_occupancy()
	_refresh_v2_runtime_state()

func _v2_tutorial_safe_damage(enemy: Unit, target: Unit, requested_damage: int) -> int:
	var damage := maxi(0, requested_damage)
	if not _is_v2_m1_tutorial_safety_active() or enemy == null or target == null:
		return damage
	if enemy.job != "sentry" or target.team != "player" or target.job != "assault":
		return damage
	return mini(damage, maxi(0, target.current_hp - 1))

func _build_v2_enemy_context() -> Dictionary:
	var profiles: Dictionary = {}
	var repository: Node = get_node_or_null("/root/V2Data")
	for raw_enemy in enemy_units:
		var enemy: Unit = raw_enemy
		if enemy == null:
			continue
		var data: Dictionary = repository.get_enemy(StringName(enemy.job)) if repository and repository.has_method("get_enemy") else {}
		profiles[enemy.job] = {
			"attack_range": data.get("attack_range", enemy.weapon_range),
			"damage": int(data.get("damage", enemy.weapon_damage[0] if not enemy.weapon_damage.is_empty() else 0)),
			"scan_radius": int(data.get("scan_radius", 3)),
			"protect_reduction": int(data.get("protect_reduction", 0)),
			"strategy": String(data.get("strategy", enemy.job)),
		}
	var blocked_cells: Array[Vector2i] = []
	for y in range(map_height):
		for x in range(map_width):
			var cell := Vector2i(x, y)
			if _is_blocked(cell):
				blocked_cells.append(cell)
	var facilities: Array = []
	for raw_facility in map_data.get("facilities", []):
		if raw_facility is Dictionary:
			var facility: Dictionary = raw_facility.duplicate(true)
			facility["position"] = Vector2i(int(facility.get("x", -1)), int(facility.get("y", -1)))
			facilities.append(facility)
	var scan_targets: Array = []
	for facility in facilities:
		if facility.get("position", Vector2i(-1, -1)) is Vector2i:
			scan_targets.append({
				"id": String(facility.get("id", "facility")),
				"cell": facility["position"],
				"priority": 20,
			})
	for raw_entity in map_data.get("entities", []):
		if not raw_entity is Dictionary:
			continue
		var entity: Dictionary = raw_entity
		var entity_type := String(entity.get("type", ""))
		if entity_type not in ["objective", "evac", "facility_marker"]:
			continue
		var entity_cell := Vector2i(int(entity.get("x", -1)), int(entity.get("y", -1)))
		if GridSystem.is_in_bounds(entity_cell, map_width, map_height):
			scan_targets.append({
				"id": String(entity.get("id", entity_type)),
				"cell": entity_cell,
				"priority": 15,
			})
	var unobserved_cells: Array[Vector2i] = []
	if visibility_state != null and visibility_state.has_method("is_cell_observed"):
		for y in range(map_height):
			for x in range(map_width):
				var cell := Vector2i(x, y)
				if not visibility_state.is_cell_observed(cell) and not _is_blocked(cell):
					unobserved_cells.append(cell)
	var choke_cells: Array[Vector2i] = []
	for raw_cell in map_data.get("choke_cells", []):
		var choke_cell: Variant = raw_cell
		if raw_cell is Dictionary:
			choke_cell = Vector2i(int(raw_cell.get("x", -1)), int(raw_cell.get("y", -1)))
		if choke_cell is Vector2i and GridSystem.is_in_bounds(choke_cell, map_width, map_height):
			choke_cells.append(choke_cell)
	return {
		"state_revision": v2_action_service.get_state_revision() if v2_action_service else 0,
		"turn": turn_manager.turn_number if turn_manager else 0,
		"players": player_units,
		"enemies": enemy_units,
		"los_check": Callable(self, "_has_los_for_targeting"),
		"blocked_cells": blocked_cells,
		"map_size": Vector2i(map_width, map_height),
		"enemy_profiles": profiles,
		"facilities": facilities,
		"scan_targets": scan_targets,
		"unobserved_cells": unobserved_cells,
		"choke_cells": choke_cells,
		"allow_drone_attack_fallback": true,
	}

func _find_v2_player(entity_id: String) -> Unit:
	for raw_player in player_units:
		var player: Unit = raw_player
		if player != null and player.is_alive and player.entity_id == entity_id:
			return player
	return null

func _refresh_v2_runtime_state() -> void:
	if v2_action_service:
		v2_action_service.refresh_units(player_units, enemy_units)
	_update_visibility()
	_refresh_enemy_intent_display()
	_render_v2_hud()
