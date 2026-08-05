extends "res://scripts/game/battle_controller.gd"

const V2EnemyBrainScript = preload("res://scripts/v2/ai/v2_enemy_brain.gd")
const V2IntentExecutorScript = preload("res://scripts/v2/ai/v2_intent_executor.gd")
const V2RuntimeMapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")

## V2 owns its map, roster, onboarding, and enemy turn. The shared controller
## remains a rendering/turn-system base so the V1 branch is never changed.
func _ready() -> void:
	super._ready()
	_install_v2_control_guide()

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
	guide.text = "左键队员：显示范围  ·  左键蓝格：移动\n左键红色敌人：攻击  ·  右键：取消选择  ·  中键：拖动地图"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", 12)
	guide.add_theme_color_override("font_color", Color(0.64, 0.86, 0.93, 0.96))
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(guide)

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
	for y in range(map_height):
		for x in range(map_width):
			var terrain := int(base_terrain[y][x]) if y < base_terrain.size() and x < base_terrain[y].size() else 0
			var blocker := int(blockers[y][x]) if y < blockers.size() and x < blockers[y].size() else 0
			var cell := Vector2i(x, y)
			_draw_tactical_tile(cell, terrain, blocker, "", "", _get_environment_variant(cell, "floor", 8), _get_terrain_edge_variants(cell, terrain), _get_blocker_variant(cell, blocker))
	_render_v2_map_entities()
	_render_evac_zone()

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
			marker.z_index = 2
			var ring := Polygon2D.new()
			ring.polygon = PackedVector2Array([Vector2(0, -22), Vector2(22, 0), Vector2(0, 22), Vector2(-22, 0)])
			ring.color = Color(0.12, 0.95, 0.72, 0.66)
			marker.add_child(ring)
			var label := Label.new()
			label.text = "撤离"
			label.position = Vector2(-34, -42)
			label.size = Vector2(68, 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.add_child(label)
			map_layer.add_child(marker)
		elif kind == "facility_marker":
			var facility := Label.new()
			facility.name = "V2Facility_%s" % String(entity.get("id", "facility"))
			facility.text = "终端" if String(entity.get("facility_type", "")) == "record" else "摄像头"
			facility.position = GridSystem.grid_to_world(position) + Vector2(6, 6)
			facility.size = Vector2(CELL_SIZE - 12, CELL_SIZE - 12)
			facility.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			facility.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			facility.mouse_filter = Control.MOUSE_FILTER_IGNORE
			facility.add_theme_color_override("font_color", Color(0.98, 0.72, 0.24, 0.95))
			map_layer.add_child(facility)

func _render_evac_zone() -> void:
	_clear_layer(evac_zone_layer)
	for cell in evac_cells:
		_highlight_cell(evac_zone_layer, cell, Color(0.0, 0.88, 0.72, 0.18))

func _play_intro_then_start() -> void:
	# The V2 base already plays its dedicated briefing. Never queue V1 dialogue
	# or V1 modal tutorials over the first playable frame.
	await get_tree().process_frame
	_begin_tutorials_or_start()

func _begin_tutorials_or_start() -> void:
	# V2 starts immediately, then uses the non-blocking V2 tutorial state machine.
	_start_battle()

func _run_enemy_turn() -> void:
	await run_v2_enemy_turn()

func run_v2_enemy_turn() -> void:
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
				target.take_damage(int(result.get("damage", 0)))
				_update_unit_sprite_pos(target, true)
		&"move":
			var target_cell: Variant = result.get("target_cell", Vector2i(-1, -1))
			if target_cell is Vector2i and enemy.spend_v2_move():
				enemy.move_to(target_cell)
				_update_unit_sprite_pos(enemy, true)
		&"scan":
			if alert_state:
				alert_state.apply_event(&"drone_scan_completed")
	_reconcile_v2_unit_occupancy()
	_refresh_v2_runtime_state()

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
	return {
		"state_revision": v2_action_service.get_state_revision() if v2_action_service else 0,
		"turn": turn_manager.turn_number if turn_manager else 0,
		"players": player_units,
		"enemies": enemy_units,
		"blocked_cells": blocked_cells,
		"enemy_profiles": profiles,
		"facilities": facilities,
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
