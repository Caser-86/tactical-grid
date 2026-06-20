extends Node2D

@onready var terrain_layer: Node2D = get_node_or_null("TerrainLayer") as Node2D
@onready var units_container: Node2D = get_node_or_null("Units") as Node2D
@onready var overlay: Node2D = get_node_or_null("Overlay") as Node2D
@onready var hud: HUD = get_node_or_null("HUD") as HUD
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D") as Camera2D

var map_data: Dictionary = {}
var map_width: int = 10
var map_height: int = 8
var selected_unit: Node = null
var reachable_cells: Dictionary = {}
var current_action: String = "move"
var action_system: ActionSystem = null

const ACTION_SYSTEM_SCRIPT := preload("res://scripts/game/action_system.gd")

const COLOR_MOVE = Color(0.13, 0.59, 0.95, 0.38)
const COLOR_ATTACK = Color(0.96, 0.26, 0.21, 0.34)

func _ready() -> void:
	if not terrain_layer or not units_container or not overlay or not hud or not camera_2d:
		push_error("Local battle scene layout is incomplete.")
		return
	action_system = ACTION_SYSTEM_SCRIPT.new() as ActionSystem
	if not action_system:
		push_error("ActionSystem init failed")
		return
	add_child(action_system)
	action_system.rng.randomize()
	_connect_hud_buttons()
	_load_local_map()
	AudioManager.bgm_battle("small")

func _exit_tree() -> void:
	if action_system:
		action_system.queue_free()
	ArtAssets.clear_cache()
	BattleVisuals.clear_cache()
	AudioManager.stop_bgm()

func _load_local_map() -> void:
	var level_data = LocalMapData.get_test_level()
	map_data = MapLoader.load_from_dict(level_data)
	map_width = map_data.get("size", {}).get("width", 10)
	map_height = map_data.get("size", {}).get("height", 8)
	BattleVisuals.set_theme(map_data.get("theme", "warehouse"))
	action_system.set_map_data(map_data)
	GameManager.current_map_data = map_data
	GameManager.player_units.clear()
	GameManager.enemy_units.clear()
	_render_map()
	_spawn_units()
	GameManager.enemy_director.setup(map_data.get("scripts", []))
	if not GameManager.enemy_director.reinforcement_spawned.is_connected(_on_reinforcement_spawned):
		GameManager.enemy_director.reinforcement_spawned.connect(_on_reinforcement_spawned)
	GameManager.turn_manager.start_battle()
	if not GameManager.turn_manager.player_turn_started.is_connected(_on_player_turn_started):
		GameManager.turn_manager.player_turn_started.connect(_on_player_turn_started)
	hud.update_objective("消灭所有敌人")

func _on_reinforcement_spawned(unit: Node, _pos: Vector2i) -> void:
	if not units_container:
		return
	var sprite = _create_unit_sprite(unit)
	sprite.position = GridSystem.grid_to_world(unit.grid_pos)
	units_container.add_child(sprite)

func _connect_hud_buttons() -> void:
	if not hud.action_selected.is_connected(_on_action_selected):
		hud.action_selected.connect(_on_action_selected)
	if not hud.skill_selected.is_connected(_on_skill_selected):
		hud.skill_selected.connect(_on_skill_selected)
	if not hud.item_selected.is_connected(_on_item_selected):
		hud.item_selected.connect(_on_item_selected)

func _render_map() -> void:
	_clear_children(terrain_layer)
	var base_terrain = map_data.layers.base_terrain
	var blocker = map_data.layers.blocker

	for y in range(map_height):
		for x in range(map_width):
			_draw_tile(Vector2i(x, y), base_terrain[y][x], 0)

	for y in range(map_height):
		for x in range(map_width):
			if blocker[y][x] != 0:
				_draw_tile(Vector2i(x, y), blocker[y][x], 1)

	_render_objects()

func _render_objects() -> void:
	var objects = map_data.get("objects", [])
	for obj in objects:
		var obj_type = obj.get("type", "")
		if obj_type in ["spawn_player", "spawn_enemy"]:
			continue
		var texture = ArtAssets.get_object_texture(obj_type)
		if not texture:
			continue
		var sprite = Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = GridSystem.grid_to_world(Vector2i(obj.get("x", 0), obj.get("y", 0)))
		sprite.scale = Vector2(GridSystem.CELL_SIZE / texture.get_width(), GridSystem.CELL_SIZE / texture.get_height())
		sprite.z_index = 2
		terrain_layer.add_child(sprite)

func _draw_tile(pos: Vector2i, terrain_id: int, layer: int) -> void:
	var visuals = get_node_or_null("/root/BattleVisuals")
	if not visuals:
		return
	var texture = visuals.get_source_texture()
	var region = visuals.get_blocker_region(terrain_id) if layer == 1 else visuals.get_terrain_region(terrain_id)
	var tint = Color.WHITE
	if layer == 1 and terrain_id == 7:
		tint = Color(0.92, 0.74, 0.48, 0.96)

	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.modulate = tint
	sprite.position = GridSystem.grid_to_world(pos)
	sprite.scale = Vector2(
		GridSystem.CELL_SIZE / region.size.x,
		GridSystem.CELL_SIZE / region.size.y
	)
	sprite.z_index = layer
	terrain_layer.add_child(sprite)

func _spawn_units() -> void:
	var player_spawns = MapLoader.get_player_spawns(map_data)
	var jobs = ["assault", "sniper", "medic", "scout"]

	for i in range(min(player_spawns.size(), 4)):
		var spawn = player_spawns[i]
		var unit = GameData.create_player_unit(jobs[i % jobs.size()], "玩家" + str(i + 1))
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		var sprite = _create_unit_sprite(unit)
		sprite.position = GridSystem.grid_to_world(unit.grid_pos)
		units_container.add_child(sprite)
		GameManager.player_units.append(unit)

	for spawn in MapLoader.get_enemy_spawns(map_data):
		var unit = GameData.create_enemy_unit(spawn.get("job", "sentry_basic"))
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		var sprite = _create_unit_sprite(unit)
		sprite.position = GridSystem.grid_to_world(unit.grid_pos)
		units_container.add_child(sprite)
		GameManager.enemy_units.append(unit)

func _create_unit_sprite(unit: Node) -> UnitSprite:
	var sprite = UnitSprite.new()
	sprite.update_unit(unit)
	return sprite

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()

func _handle_left_click(world_pos: Vector2) -> void:
	var grid_pos = GridSystem.world_to_grid(world_pos)
	var clicked_unit = _get_unit_at(grid_pos)

	match current_action:
		"move":
			if clicked_unit and clicked_unit.team == "player":
				_select_unit(clicked_unit)
			elif selected_unit and reachable_cells.has(grid_pos):
				_move_unit(selected_unit, grid_pos)
		"attack":
			if selected_unit and clicked_unit and clicked_unit.team == "enemy":
				_attack_unit(selected_unit, clicked_unit)

func _handle_right_click() -> void:
	_deselect_unit()
	current_action = "move"

func _select_unit(unit: Node) -> void:
	_deselect_unit()
	selected_unit = unit
	GameManager.select_unit(unit)
	for sprite in units_container.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			sprite.set_selected(true)
			break
	_show_move_range(unit)
	_update_unit_info(unit)
	hud.update_action_menu(unit)
	AudioManager.sfx_select_unit()

func _deselect_unit() -> void:
	if selected_unit:
		for sprite in units_container.get_children():
			if sprite is UnitSprite and sprite.unit == selected_unit:
				sprite.set_selected(false)
				break
	selected_unit = null
	GameManager.deselect_unit()
	reachable_cells.clear()
	_clear_overlay()
	_render_map()
	hud.update_action_menu(null)

func _show_move_range(unit: Node) -> void:
	_clear_overlay()
	_render_map()
	reachable_cells = Pathfinding.get_reachable_cells(
		unit.grid_pos,
		unit.move_points,
		map_width,
		map_height,
		_get_move_cost.bind(unit.job),
		_is_blocked
	)
	for cell in reachable_cells:
		if cell != unit.grid_pos:
			_highlight_cell(cell, COLOR_MOVE)

func _show_attack_range(unit: Node) -> void:
	_clear_overlay()
	_render_map()
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			var dist = GridSystem.manhattan_distance(unit.grid_pos, pos)
			if dist >= unit.weapon_range[0] and dist <= unit.weapon_range[1] and pos != unit.grid_pos:
				_highlight_cell(pos, COLOR_ATTACK)

func _move_unit(unit: Node, target: Vector2i) -> void:
	if not unit.spend_ap(1):
		return
	unit.move_to(target)
	var sprite = _get_sprite_for_unit(unit)
	if sprite:
		sprite.animate_move_to(GridSystem.grid_to_world(target))
	_clear_overlay()
	_render_map()
	_show_move_range(unit)
	hud.update_action_menu(unit)
	_update_unit_info(unit)
	var terrain = MapLoader.get_terrain_at(map_data, target.x, target.y)
	AudioManager.sfx_move(terrain)
	_shake_camera(2.0, 0.08)

func _attack_unit(attacker: Node, target: Node) -> void:
	var dist = GridSystem.manhattan_distance(attacker.grid_pos, target.grid_pos)
	if dist < attacker.weapon_range[0] or dist > attacker.weapon_range[1]:
		return
	if not attacker.spend_ap(1):
		return

	var cover = VisionSystem.calculate_cover(
		target.grid_pos, attacker.grid_pos,
		func(pos): return MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	)

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var result = CombatFormulas.resolve_attack(
		attacker.base_hit,
		attacker.height, target.height,
		cover, dist, attacker.weapon_optimal_range,
		int((attacker.weapon_damage[0] + attacker.weapon_damage[1]) / 2),
		target.armor,
		attacker.crit_chance, attacker.crit_multiplier,
		target.dodge, MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y),
		rng
	)

	var target_sprite := _get_sprite_for_unit(target)

	if result.get("hit", false):
		target.take_damage(int(result.get("damage", 0)))
		var target_terrain = MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y)
		AudioManager.sfx_hit(target_terrain)
		BattleEffects.play_hit(GridSystem.grid_to_world(target.grid_pos) + Vector2(GridSystem.CELL_SIZE/2.0, GridSystem.CELL_SIZE/2.0))
		_show_floating_text(target.grid_pos, "-%d" % int(result.get("damage", 0)), GameTheme.HP_LOW)
		if target_sprite:
			target_sprite.flash_hit()
		_shake_camera(4.0, 0.12)
		if result.get("critical", false):
			AudioManager.sfx_critical()
			BattleEffects.play_critical(GridSystem.grid_to_world(target.grid_pos) + Vector2(GridSystem.CELL_SIZE/2.0, GridSystem.CELL_SIZE/2.0))
			_show_floating_text(target.grid_pos + Vector2i(0, -1), "CRIT", Color(1.0, 0.75, 0.03))
		if not target.is_alive:
			AudioManager.sfx_unit_down()
			_show_floating_text(target.grid_pos, "K.O.", Color(0.96, 0.26, 0.21))
			if target_sprite:
				target_sprite.fade_out()
			_check_victory()
	else:
		if result.get("dodged", false):
			_show_floating_text(target.grid_pos, "DODGE", Color(0.42, 0.86, 1.0))
		else:
			_show_floating_text(target.grid_pos, "MISS", Color(0.65, 0.65, 0.65))

	_refresh_all_unit_sprites()
	_update_unit_info(null)
	_deselect_unit()

func _on_player_turn_started() -> void:
	AudioManager.sfx_turn_start(true)

func _on_end_turn() -> void:
	GameManager.turn_manager.end_player_turn()
	_deselect_unit()
	AudioManager.sfx_turn_start(false)

func _on_action_selected(action: String) -> void:
	if not selected_unit:
		return

	match action:
		"move":
			current_action = "move"
			_show_move_range(selected_unit)
		"attack":
			current_action = "attack"
			_show_attack_range(selected_unit)
		"overwatch":
			_enter_overwatch()
		"end_turn":
			_on_end_turn()

func _on_skill_selected(skill_id: String) -> void:
	if not selected_unit:
		return
	_use_skill(skill_id)

func _on_item_selected(item_id: String) -> void:
	if not selected_unit:
		return
	_use_item(item_id)

func _get_unit_at(pos: Vector2i):
	for unit in GameManager.player_units + GameManager.enemy_units:
		if unit.is_alive and unit.grid_pos == pos:
			return unit
	return null

func _get_sprite_for_unit(unit: Node) -> UnitSprite:
	for sprite in units_container.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			return sprite
	return null

func _get_move_cost(pos: Vector2i, job: String) -> int:
	var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	if blocker == 6 or blocker == 7:
		return -1
	if terrain == 5:
		return -1
	match terrain:
		0, 1, 4:
			return 1
		2:
			return 2 if job != "scout" else 1
		3:
			return 2
		8:
			return 2
		9:
			return 1
		_:
			return 1

func _is_blocked(pos: Vector2i) -> bool:
	return not MapLoader.is_passable(map_data, pos.x, pos.y)

func _highlight_cell(pos: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(GridSystem.CELL_SIZE - 2, GridSystem.CELL_SIZE - 2)
	rect.position = GridSystem.grid_to_world(pos) + Vector2(1, 1)
	overlay.add_child(rect)

func _clear_overlay() -> void:
	_clear_children(overlay)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _update_unit_info(unit: Node) -> void:
	if hud:
		hud.update_unit_info(unit)

func _check_victory() -> void:
	GameManager._check_victory()

func _refresh_all_unit_sprites() -> void:
	for sprite in units_container.get_children():
		if sprite is UnitSprite:
			sprite.update_unit(sprite.unit)

func _find_best_enemy_target(caster: Node) -> Node:
	var best_target: Node = null
	var best_distance := 9999
	for unit in GameManager.enemy_units:
		if not unit.is_alive:
			continue
		var dist = GridSystem.manhattan_distance(caster.grid_pos, unit.grid_pos)
		if dist < best_distance:
			best_distance = dist
			best_target = unit
	return best_target

func _find_best_ally_target(caster: Node) -> Node:
	var best_target: Node = caster
	var best_missing := -1
	for unit in GameManager.player_units:
		if not unit.is_alive:
			continue
		var missing = unit.max_hp - unit.current_hp
		if missing > best_missing:
			best_missing = missing
			best_target = unit
	return best_target

func _find_target_position(caster: Node, target: Node = null) -> Vector2i:
	if target:
		return target.grid_pos
	var candidate = caster.grid_pos + Vector2i(1, 0)
	if MapLoader.is_passable(map_data, candidate.x, candidate.y):
		return candidate
	for neighbor in GridSystem.get_neighbors(caster.grid_pos):
		if MapLoader.is_passable(map_data, neighbor.x, neighbor.y):
			return neighbor
	return caster.grid_pos

func _build_skill_target(skill_id: String, caster: Node) -> Dictionary:
	if skill_id in ["asslt_adrenaline", "heavy_taunt", "heavy_iron_fortress", "heavy_self_repair", "medic_barrier_blast", "gen_hunker_down", "gen_sprint", "gen_reposition", "scout_stealth"]:
		return {}
	if skill_id in ["medic_heal", "medic_revive", "medic_adrenaline_shot", "medic_cure", "medic_pain_block", "medic_stim_pack", "heavy_protect"]:
		return {"target_unit": _find_best_ally_target(caster)}
	if skill_id in ["gen_interact", "scout_sabotage", "asslt_storm_dash", "asslt_chain_slash"]:
		return {"position": _find_target_position(caster, _find_best_enemy_target(caster))}
	if skill_id in ["scout_shadow_step"]:
		var ally = _find_best_ally_target(caster)
		if ally == caster:
			for unit in GameManager.player_units:
				if unit.is_alive and unit != caster:
					ally = unit
					break
		return {"target_unit": ally}
	if skill_id in ["snip_suppressing_fire"]:
		return {"target_unit": _find_best_enemy_target(caster)}
	return {"target_unit": _find_best_enemy_target(caster)}

func _use_skill(skill_id: String) -> void:
	var target_data = _build_skill_target(skill_id, selected_unit)
	var result = action_system.execute_skill(selected_unit, skill_id, target_data)
	if result.get("success", false):
		AudioManager.sfx_skill()
		_render_map()
		_refresh_all_unit_sprites()
		hud.update_action_menu(selected_unit)
		_update_unit_info(selected_unit)
		_check_victory()
		_show_floating_text(selected_unit.grid_pos, "SKILL", Color(0.42, 0.86, 1.0))
		if skill_id == "snip_overwatch" or skill_id == "gen_overwatch":
			AudioManager.sfx_overwatch()
	else:
		_show_floating_text(selected_unit.grid_pos, "SKILL FAIL", Color(0.8, 0.4, 0.4))
	current_action = "move"
	if selected_unit:
		_show_move_range(selected_unit)

func _build_item_target(item_id: String, caster: Node) -> Dictionary:
	var item = GameData.get_item(item_id)
	if item.is_empty():
		return {}
	var item_type = item.get("type", "")
	var effect = item.get("effect", {})
	if item_type in ["throwable", "trap"]:
		return {"position": _find_target_position(caster, _find_best_enemy_target(caster))}
	if effect.has("heal") or effect.has("revive") or effect.has("remove_status") or effect.has("remove_all_debuffs") or effect.has("add_status"):
		return {"target_unit": _find_best_ally_target(caster)}
	return {}

func _use_item(item_id: String) -> void:
	var target_data = _build_item_target(item_id, selected_unit)
	var item = GameData.get_item(item_id)
	var item_type = item.get("type", "")
	var target = target_data.get("target_unit", null)
	var target_pos = target_data.get("position", selected_unit.grid_pos)
	var result: Dictionary = {}

	if item_type == "trap":
		result = _place_trap_on_map(item, target_pos)
	elif item_type == "throwable":
		result = action_system.use_item(selected_unit, item_id, null, {"position": target_pos})
	else:
		result = action_system.use_item(selected_unit, item_id, target)

	if result.get("success", false):
		_consume_inventory_item(item_id)
		if item_type in ["throwable", "trap"]:
			AudioManager.sfx_explosion()
		else:
			AudioManager.sfx_heal()
		_render_map()
		_refresh_all_unit_sprites()
		hud.update_action_menu(selected_unit)
		_update_unit_info(selected_unit)
		_check_victory()
		_show_floating_text(selected_unit.grid_pos, "ITEM", Color(0.42, 0.86, 1.0))
	else:
		_show_floating_text(selected_unit.grid_pos, "ITEM FAIL", Color(0.8, 0.4, 0.4))
	current_action = "move"
	if selected_unit:
		_show_move_range(selected_unit)

func _place_trap_on_map(item: Dictionary, pos: Vector2i) -> Dictionary:
	if not MapLoader.is_passable(map_data, pos.x, pos.y):
		return {"success": false, "reason": "invalid_position"}

	var effect = item.get("effect", {})
	var trap_obj = {
		"id": "trap_" + str(randi()),
		"type": "trap",
		"x": pos.x,
		"y": pos.y,
		"team": selected_unit.team if selected_unit else "player",
		"damage": effect.get("damage", [20, 30]),
		"trigger": effect.get("trigger", "enemy_enter"),
		"status": effect.get("add_status", {}),
		"name": item.get("name", "陷阱"),
	}
	if not map_data.has("objects"):
		map_data["objects"] = []
	map_data.objects.append(trap_obj)
	return {"success": true, "trap": item.get("name", ""), "pos": pos}

func _consume_inventory_item(item_id: String) -> void:
	var inventory = GameManager.save_data.get("inventory", [])
	for i in range(inventory.size()):
		if inventory[i].get("id", "") != item_id:
			continue
		var count = int(inventory[i].get("count", 1))
		if count > 1:
			inventory[i]["count"] = count - 1
		else:
			inventory.remove_at(i)
		GameManager.save_data["inventory"] = inventory
		return

func _enter_overwatch() -> void:
	if not selected_unit:
		return
	if action_system.enter_overwatch(selected_unit):
		AudioManager.sfx_overwatch()
		_refresh_all_unit_sprites()
		_update_unit_info(selected_unit)
		_show_floating_text(selected_unit.grid_pos, "OVERWATCH", Color(1.0, 0.76, 0.25))
		_deselect_unit()
	else:
		_show_floating_text(selected_unit.grid_pos, "NO AP", Color(0.8, 0.4, 0.4))

func _show_floating_text(grid_pos: Vector2i, text: String, color: Color) -> void:
	if not hud:
		return

	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(label)

	var screen_pos = _world_to_screen(GridSystem.grid_to_world(grid_pos))
	label.position = screen_pos + Vector2(10, -10)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(Callable(label, "queue_free"))

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

func _shake_camera(strength: float, duration: float) -> void:
	if not camera_2d:
		return
	var base_pos = camera_2d.position
	var tween = create_tween()
	tween.tween_method(Callable(self, "_apply_camera_shake").bind(base_pos, strength), 0.0, 1.0, duration)
	tween.tween_callback(func():
		camera_2d.position = base_pos
	)

func _apply_camera_shake(t: float, base_pos: Vector2, strength: float) -> void:
	camera_2d.position = base_pos + Vector2(
		sin(t * TAU * 4.0) * strength,
		cos(t * TAU * 6.0) * strength * 0.5
	)





