extends Node2D
class_name BattleController

@onready var terrain_layer: Node2D = get_node_or_null("TerrainLayer") as Node2D
@onready var units_container: Node2D = get_node_or_null("Units") as Node2D
@onready var overlay: Node2D = get_node_or_null("Overlay") as Node2D
@onready var info_layer: Node2D = get_node_or_null("InfoLayer") as Node2D
@onready var hud: HUD = get_node_or_null("HUD") as HUD
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D") as Camera2D

var map_data: Dictionary = {}
var map_width: int = 10
var map_height: int = 8
var selected_unit: Node = null
var reachable_cells: Dictionary = {}
var current_action: String = "move"
var action_system: ActionSystem = null
var pending_skill_id: String = ""
var pending_skill_target_kind: String = ""
var pending_item_id: String = ""
var pending_item_target_kind: String = ""
var battle_objective_text: String = "消灭所有敌人"
var _camera_dragging: bool = false
var _camera_drag_start: Vector2 = Vector2.ZERO
var _camera_drag_start_pos: Vector2 = Vector2.ZERO
var _camera_min_zoom: float = 0.5
var _camera_max_zoom: float = 3.0

const ACTION_SYSTEM_SCRIPT := preload("res://scripts/game/action_system.gd")

const COLOR_MOVE = Color(0.13, 0.59, 0.95, 0.28)
const COLOR_ATTACK = Color(0.96, 0.26, 0.21, 0.28)
const COLOR_MOVE_BORDER = Color(0.13, 0.59, 0.95, 0.65)
const COLOR_ATTACK_BORDER = Color(0.96, 0.26, 0.21, 0.65)
const COLOR_SELECTED = Color(1.0, 1.0, 1.0, 0.85)

func _ready() -> void:
	if not terrain_layer or not units_container or not overlay or not hud or not camera_2d:
		push_error("Battle scene layout is incomplete.")
		return
	action_system = ACTION_SYSTEM_SCRIPT.new() as ActionSystem
	if not action_system:
		push_error("ActionSystem init failed")
		return
	add_child(action_system)
	action_system.rng.randomize()
	_connect_hud_buttons()
	_load_battle()

func _exit_tree() -> void:
	if action_system:
		action_system.queue_free()
	ArtAssets.clear_cache()
	BattleVisuals.clear_cache()
	AudioManager.stop_bgm()

func _load_battle() -> void:
	var level_data = GameManager.current_map_data
	if level_data.is_empty():
		level_data = LocalMapData.get_test_level()
	map_data = MapLoader.load_from_dict(level_data)
	map_width = map_data.get("size", {}).get("width", 10)
	map_height = map_data.get("size", {}).get("height", 8)
	var theme = map_data.get("theme", "warehouse")
	BattleVisuals.set_theme(theme)
	action_system.set_map_data(map_data)
	GameManager.current_map_data = map_data
	GameManager.player_units.clear()
	GameManager.enemy_units.clear()
	_setup_audio_for_theme(theme)
	_render_map()
	_spawn_units()
	GameManager.enemy_director.setup(map_data.get("scripts", []))
	if not GameManager.enemy_director.reinforcement_spawned.is_connected(_on_reinforcement_spawned):
		GameManager.enemy_director.reinforcement_spawned.connect(_on_reinforcement_spawned)
	GameManager.turn_manager.start_battle()
	if not GameManager.turn_manager.player_turn_started.is_connected(_on_player_turn_started):
		GameManager.turn_manager.player_turn_started.connect(_on_player_turn_started)
	if not GameManager.enemy_action_started.is_connected(_on_enemy_action_started):
		GameManager.enemy_action_started.connect(_on_enemy_action_started)
	if not hud.skill_hovered.is_connected(_on_skill_hovered):
		hud.skill_hovered.connect(_on_skill_hovered)
	if not hud.skill_preview_cleared.is_connected(_on_skill_preview_cleared):
		hud.skill_preview_cleared.connect(_on_skill_preview_cleared)
	_setup_tutorial()
	battle_objective_text = _get_mission_objective_text()
	hud.update_objective(battle_objective_text)
	hud.show_battle_hint(battle_objective_text, 2.5)
	_center_camera_on_map()

func _setup_audio_for_theme(theme: String) -> void:
	AudioManager.bgm_battle(_get_bgm_size())
	AudioManager.play_ambient("ambient_" + theme)

func _get_bgm_size() -> String:
	var cells = map_width * map_height
	if cells > 200:
		return "large"
	if cells > 100:
		return "medium"
	return "small"

func _get_mission_objective_text() -> String:
	var mission_type = map_data.get("mission_type", "extract")
	match mission_type:
		"assassinate":
			return "任务目标：消灭所有敌方单位"
		"destroy":
			return "任务目标：摧毁所有目标设施"
		"defend":
			var defend_turns = _get_defend_turns()
			return "任务目标：坚守 %d 回合" % defend_turns
		"extract":
			var evac = map_data.get("evac_point", {})
			if evac:
				return "任务目标：抵达撤离点 (%d,%d)" % [evac.get("x", 0), evac.get("y", 0)]
			return "任务目标：消灭所有敌人"
		"escort":
			return "任务目标：护送目标到达撤离点"
		_:
			return "任务目标：消灭所有敌人"

func _get_defend_turns() -> int:
	var victory = map_data.get("victory", {})
	if victory.get("type", "") == "survive_turns" and victory.has("turns"):
		return int(victory.get("turns", 5))
	var special_rules = map_data.get("special_rules", [])
	for rule in special_rules:
		if rule is String and rule.begins_with("defend_"):
			var num = rule.replace("defend_", "")
			if num.is_valid_int():
				return num.to_int()
		if rule is String and rule.begins_with("survive_"):
			var parts = rule.split("_")
			if parts.size() >= 2 and parts[1].is_valid_int():
				return parts[1].to_int()
	return 5

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
	_draw_grid_lines()
	_draw_unit_shadows()

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

func _draw_grid_lines() -> void:
	var grid_node = Node2D.new()
	grid_node.name = "GridLines"
	grid_node.z_index = 0
	terrain_layer.add_child(grid_node)
	grid_node.draw.connect(func():
		var width = map_width * GridSystem.CELL_SIZE
		var height = map_height * GridSystem.CELL_SIZE
		for x in range(map_width + 1):
			var wx = x * GridSystem.CELL_SIZE
			grid_node.draw_line(Vector2(wx, 0), Vector2(wx, height), Color(1, 1, 1, 0.06), 1.0)
		for y in range(map_height + 1):
			var wy = y * GridSystem.CELL_SIZE
			grid_node.draw_line(Vector2(0, wy), Vector2(width, wy), Color(1, 1, 1, 0.06), 1.0)
	)

func _draw_unit_shadows() -> void:
	var shadow_node = Node2D.new()
	shadow_node.name = "UnitShadows"
	shadow_node.z_index = 1
	terrain_layer.add_child(shadow_node)
	shadow_node.draw.connect(func():
		for unit in GameManager.player_units + GameManager.enemy_units:
			if not unit.is_alive:
				continue
			var center = GridSystem.grid_to_world(unit.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0 + 8)
			shadow_node.draw_circle(center, 18, Color(0, 0, 0, 0.35))
	)

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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_camera_dragging = true
				_camera_drag_start = event.position
				_camera_drag_start_pos = camera_2d.position
			else:
				_camera_dragging = false
				var drag_delta = event.position - _camera_drag_start
				if drag_delta.length() < 8.0:
					var world_pos = get_global_mouse_position()
					_handle_left_click(world_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_handle_right_click()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(0.9)
	elif event is InputEventMouseMotion:
		if _camera_dragging:
			var drag_delta = event.position - _camera_drag_start
			camera_2d.position = _camera_drag_start_pos - drag_delta / camera_2d.zoom.x
		else:
			_update_hover_preview()

func _update_hover_preview() -> void:
	if not selected_unit:
		return
	if selected_unit.team != "player":
		return
	var world_pos = get_global_mouse_position()
	var grid_pos = GridSystem.world_to_grid(world_pos)
	# 恢复基础移动范围高亮
	_clear_overlay()
	_render_map()
	_show_move_range(selected_unit)
	# 如果悬停在可达格子上，显示路径预览
	if reachable_cells.has(grid_pos) and grid_pos != selected_unit.grid_pos:
		_draw_preview_path(grid_pos)

func _zoom_camera(factor: float) -> void:
	if not camera_2d:
		return
	var new_zoom = camera_2d.zoom.x * factor
	new_zoom = clampf(new_zoom, _camera_min_zoom, _camera_max_zoom)
	camera_2d.zoom = Vector2(new_zoom, new_zoom)

func _handle_left_click(world_pos: Vector2) -> void:
	var grid_pos = GridSystem.world_to_grid(world_pos)
	var clicked_unit = _get_unit_at(grid_pos)

	# 技能/物品目标选择保持原逻辑
	match current_action:
		"skill_target":
			_handle_skill_target_click(grid_pos, clicked_unit)
			return
		"item_target":
			_handle_item_target_click(grid_pos, clicked_unit)
			return

	# 简化操作：选中单位后，根据点击目标自动判断意图
	if clicked_unit:
		if clicked_unit.team == "player":
			_select_unit(clicked_unit)
			return
		elif selected_unit and clicked_unit.team == "enemy":
			# 如果敌人在射程内直接攻击，否则尝试移动到射程内
			if _can_attack(selected_unit, clicked_unit):
				_attack_unit(selected_unit, clicked_unit)
			else:
				_move_towards_attack_range(selected_unit, clicked_unit)
			return

	# 点击空地：如果选中了我方单位且格子可达，直接移动
	if selected_unit and selected_unit.team == "player" and reachable_cells.has(grid_pos):
		_move_unit(selected_unit, grid_pos)
		return

func _can_attack(attacker: Node, target: Node) -> bool:
	var dist = GridSystem.manhattan_distance(attacker.grid_pos, target.grid_pos)
	return dist >= attacker.weapon_range[0] and dist <= attacker.weapon_range[1]

func _move_towards_attack_range(attacker: Node, target: Node) -> void:
	if attacker.current_ap <= 0 or attacker.move_points <= 0:
		return
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 999999
	for cell in reachable_cells:
		if _get_unit_at(cell):
			continue
		var dist = GridSystem.manhattan_distance(cell, target.grid_pos)
		if dist >= attacker.weapon_range[0] and dist <= attacker.weapon_range[1]:
			var move_cost = GridSystem.manhattan_distance(attacker.grid_pos, cell)
			if move_cost < best_dist:
				best_dist = move_cost
				best_cell = cell
	if best_cell != Vector2i(-1, -1):
		_move_unit(attacker, best_cell)
	else:
		AudioManager.sfx_ui_error()

func _handle_right_click() -> void:
	var world_pos = get_global_mouse_position()
	var cell = GridSystem.world_to_grid(world_pos)
	var unit_at_cell = _get_unit_at(cell)
	if unit_at_cell and unit_at_cell.team == "enemy":
		_show_enemy_info_panel(unit_at_cell)
		return
	_cancel_pending_target_selection()
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
	_highlight_selected_unit(unit)
	_show_move_range(unit)
	_update_unit_info(unit)
	hud.update_action_menu(unit)
	AudioManager.sfx_select_unit()
	focus_on_unit(unit, 0.22)

func _highlight_selected_unit(unit: Node) -> void:
	var cell_world := GridSystem.grid_to_world(unit.grid_pos)
	var line = Line2D.new()
	line.points = PackedVector2Array([
		Vector2(1, 1),
		Vector2(GridSystem.CELL_SIZE - 1, 1),
		Vector2(GridSystem.CELL_SIZE - 1, GridSystem.CELL_SIZE - 1),
		Vector2(1, GridSystem.CELL_SIZE - 1),
		Vector2(1, 1),
	])
	line.default_color = COLOR_SELECTED
	line.width = 3.0
	line.position = cell_world
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.name = "SelectedUnitHighlight"
	overlay.add_child(line)

func _deselect_unit() -> void:
	_cancel_pending_target_selection()
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
			_highlight_cell(cell, COLOR_MOVE, COLOR_MOVE_BORDER)

func _show_attack_range(unit: Node) -> void:
	_clear_overlay()
	_render_map()
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			var dist = GridSystem.manhattan_distance(unit.grid_pos, pos)
			if dist >= unit.weapon_range[0] and dist <= unit.weapon_range[1] and pos != unit.grid_pos:
				_highlight_cell(pos, COLOR_ATTACK, COLOR_ATTACK_BORDER)

func _draw_preview_path(target_pos: Vector2i) -> void:
	if not selected_unit:
		return
	if not reachable_cells.has(target_pos):
		return
	if target_pos == selected_unit.grid_pos:
		return
	var path = Pathfinding.find_path(
		selected_unit.grid_pos,
		target_pos,
		map_width,
		map_height,
		_get_move_cost.bind(selected_unit.job),
		_is_blocked
	)
	_draw_path_line(path)

func _move_unit(unit: Node, target: Vector2i) -> void:
	if not unit.spend_ap(1):
		return
	var from_pos = unit.grid_pos
	unit.move_to(target)
	unit.add_status("moved", 1)
	var sprite = _get_sprite_for_unit(unit)
	if sprite:
		sprite.animate_move_to(GridSystem.grid_to_world(target))

	# 检查 overwatch 触发
	if action_system:
		var triggers = action_system.check_overwatch_trigger(unit, from_pos, target)
		for trigger in triggers:
			var watcher = trigger.get("watcher")
			var result = trigger.get("result", {})
			var watcher_sprite = _get_sprite_for_unit(watcher)
			if watcher_sprite:
				watcher_sprite.play("attack")
			var watcher_world = GridSystem.grid_to_world(watcher.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
			var target_world = GridSystem.grid_to_world(unit.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
			BattleEffects.play_muzzle_flash(watcher_world, self)
			_spawn_projectile(watcher_world, target_world, "rifle")
			if result.get("hit", false):
				_show_floating_text(unit.grid_pos, "-%d" % int(result.get("damage", 0)), GameTheme.HP_LOW)
				AudioManager.sfx_hit(MapLoader.get_terrain_at(map_data, unit.grid_pos.x, unit.grid_pos.y))
				BattleEffects.play_hit(target_world)
				if not unit.is_alive:
					_check_victory()
				if watcher_sprite:
					AudioManager.sfx_attack("rifle")
	_clear_overlay()
	_render_map()
	_show_move_range(unit)
	hud.update_action_menu(unit)
	_update_unit_info(unit)
	var terrain = MapLoader.get_terrain_at(map_data, target.x, target.y)
	AudioManager.sfx_move(terrain)
	_shake_camera(2.0, 0.08)
	TutorialManager.advance_if("move")

func _draw_path_line(path: Array) -> void:
	if path.size() < 2:
		return
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.18, 0.74, 1.0, 0.85)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	for cell in path:
		line.add_point(GridSystem.grid_to_world(Vector2i(cell)) + Vector2(32, 32))
	overlay.add_child(line)

	# 在路径终点画一个箭头
	var last = path[-1]
	var second_last = path[-2] if path.size() >= 2 else path[-1]
	var dir = Vector2(Vector2i(last) - Vector2i(second_last)).normalized()
	var arrow = Polygon2D.new()
	var tip = GridSystem.grid_to_world(Vector2i(last)) + Vector2(32, 32)
	arrow.polygon = PackedVector2Array([
		tip + dir.rotated(PI * 0.85) * 14,
		tip + dir.rotated(-PI * 0.85) * 14,
		tip + dir * 18,
	])
	arrow.color = Color(0.18, 0.74, 1.0, 0.9)
	overlay.add_child(arrow)

func _attack_unit(attacker: Node, target: Node) -> void:
	var result = action_system.execute_attack(attacker, target)
	if not result.get("success", false):
		var reason = result.get("reason", "")
		if reason == "out_of_range":
			_show_floating_text(attacker.grid_pos, "OUT OF RANGE", Color(0.8, 0.4, 0.4))
		return

	var attack_result = result.get("result", {})

	var attacker_sprite := _get_sprite_for_unit(attacker)
	var target_sprite := _get_sprite_for_unit(target)

	if attacker_sprite:
		attacker_sprite.play("attack")

	# 播放弹道特效
	var attacker_world = GridSystem.grid_to_world(attacker.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
	var target_world = GridSystem.grid_to_world(target.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
	BattleEffects.play_muzzle_flash(attacker_world, self)
	var weapon_id = attacker.get("equipped_weapon")
	if weapon_id == null:
		weapon_id = ""
	var weapon_data = GameData.get_weapon(str(weapon_id))
	var wtype = String(weapon_data.get("type", "rifle")) if weapon_data else "rifle"
	_spawn_projectile(attacker_world, target_world, wtype)

	if attack_result.get("hit", false):
		var target_terrain = MapLoader.get_terrain_at(map_data, target.grid_pos.x, target.grid_pos.y)
		AudioManager.sfx_hit(target_terrain)
		BattleEffects.play_hit(target_world)
		_show_floating_text(target.grid_pos, "-%d" % int(attack_result.get("damage", 0)), GameTheme.HP_LOW)
		if target_sprite:
			target_sprite.play("hit")
			target_sprite.flash_hit()
		_shake_camera(4.0, 0.12)
		if attack_result.get("critical", false):
			AudioManager.sfx_critical()
			BattleEffects.play_critical(target_world)
			_show_floating_text(target.grid_pos + Vector2i(0, -1), "CRIT", Color(1.0, 0.75, 0.03))
		if not target.is_alive:
			AudioManager.sfx_unit_down()
			_show_floating_text(target.grid_pos, "K.O.", Color(0.96, 0.26, 0.21))
			if target_sprite:
				if target.has_meta("is_boss"):
					target_sprite.play_defeated_shatter()
				else:
					target_sprite.play("death")
					var death_tween = create_tween()
					death_tween.tween_interval(0.6)
					death_tween.tween_property(target_sprite, "modulate:a", 0.0, 0.25)
					death_tween.tween_callback(target_sprite.queue_free)
			_check_victory()
	else:
		if attack_result.get("dodged", false):
			_show_floating_text(target.grid_pos, "DODGE", Color(0.42, 0.86, 1.0))
		else:
			_show_floating_text(target.grid_pos, "MISS", Color(0.65, 0.65, 0.65))

	AudioManager.sfx_attack(wtype)
	_refresh_all_unit_sprites()
	_update_unit_info(null)
	_deselect_unit()
	TutorialManager.advance_if("attack")

func _spawn_projectile(from: Vector2, to: Vector2, weapon_type: String) -> void:
	var projectile = Line2D.new()
	projectile.width = 3.0
	projectile.default_color = _projectile_color(weapon_type)
	projectile.begin_cap_mode = Line2D.LINE_CAP_ROUND
	projectile.end_cap_mode = Line2D.LINE_CAP_ROUND
	projectile.add_point(from)
	projectile.add_point(from)
	projectile.z_index = 10
	overlay.add_child(projectile)

	var duration := 0.12
	var tween = create_tween()
	tween.tween_method(func(t: float):
		projectile.set_point_position(1, from.lerp(to, t))
	, 0.0, 1.0, duration)
	tween.tween_callback(func():
		projectile.queue_free()
		BattleEffects.play_muzzle_flash(from)
	)

func _projectile_color(weapon_type: String) -> Color:
	match weapon_type:
		"laser", "beam", "plasma":
			return Color(0.2, 0.85, 1.0, 0.95)
		"plasma_cannon", "rocket":
			return Color(1.0, 0.45, 0.1, 0.95)
		"shotgun", "pistol", "rifle", "sniper":
			return Color(1.0, 0.95, 0.4, 0.9)
		_:
			return Color(1.0, 0.95, 0.4, 0.9)

func _setup_tutorial() -> void:
	var levels = GameData.level_data.get("levels", {})
	var level = levels.get(GameManager.current_level_id, {})
	var flags = level.get("tutorial_flags", [])
	if flags.size() == 0:
		return
	if not TutorialManager.step_changed.is_connected(_on_tutorial_step_changed):
		TutorialManager.step_changed.connect(_on_tutorial_step_changed)
	if not TutorialManager.tutorial_finished.is_connected(_on_tutorial_finished):
		TutorialManager.tutorial_finished.connect(_on_tutorial_finished)
	TutorialManager.start(flags)

func _on_tutorial_step_changed(text: String) -> void:
	if hud:
		hud.show_battle_hint(text, 5.0)

func _on_tutorial_finished() -> void:
	if hud:
		hud.show_battle_hint("教学完成，继续任务！", 2.0)

func _on_enemy_action_started(enemy: Node, _action_type: String) -> void:
	focus_on_unit(enemy, 0.35)

var _skill_preview_active: bool = false

func _on_skill_hovered(skill_id: String) -> void:
	if not selected_unit:
		return
	_clear_overlay()
	_render_map()
	_skill_preview_active = true
	var skill = GameData.get_skill(skill_id)
	if skill.is_empty():
		return
	var skill_range = _get_skill_range(skill_id, selected_unit)
	var min_r = skill_range[0]
	var max_r = skill_range[1]
	var center = selected_unit.grid_pos
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			var dist = GridSystem.manhattan_distance(center, pos)
			if dist >= min_r and dist <= max_r and pos != center:
				var color = COLOR_ATTACK
				var enemy_at = _get_unit_at(pos)
				if enemy_at and enemy_at.team == "enemy":
					color = COLOR_ATTACK.lerp(Color(1.0, 0.2, 0.2), 0.5)
				elif not enemy_at:
					color = COLOR_ATTACK.lerp(Color(0.5, 0.5, 0.6), 0.5)
				_highlight_cell(pos, color, color.darkened(0.3))

func _on_skill_preview_cleared() -> void:
	if _skill_preview_active:
		_skill_preview_active = false
		_clear_overlay()
		_render_map()
		if selected_unit:
			current_action = "move"
			_show_move_range(selected_unit)

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
			_restore_battle_objective()
			_show_move_range(selected_unit)
		"attack":
			current_action = "attack"
			_restore_battle_objective()
			_show_attack_range(selected_unit)
		"overwatch":
			_enter_overwatch()
		"end_turn":
			_on_end_turn()

func _on_skill_selected(skill_id: String) -> void:
	if not selected_unit:
		return
	pending_skill_id = skill_id
	pending_skill_target_kind = _get_skill_target_kind(skill_id)
	if pending_skill_target_kind == "none":
		_use_skill(skill_id)
		return
	current_action = "skill_target"
	_clear_overlay()
	_render_map()
	_refresh_target_highlights()
	_show_skill_target_hint(skill_id)

func _on_item_selected(item_id: String) -> void:
	if not selected_unit:
		return
	pending_item_id = item_id
	pending_item_target_kind = _get_item_target_kind(item_id)
	if pending_item_target_kind == "none":
		_use_item(item_id)
		return
	current_action = "item_target"
	_clear_overlay()
	_render_map()
	_refresh_target_highlights()
	_show_item_target_hint(item_id)

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

func _highlight_cell(pos: Vector2i, color: Color, border_color: Color = Color.TRANSPARENT) -> void:
	var padding := 4
	var cell_world := GridSystem.grid_to_world(pos)
	var inner_size := GridSystem.CELL_SIZE - padding * 2

	# 填充
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(padding, padding),
		Vector2(padding + inner_size, padding),
		Vector2(padding + inner_size, padding + inner_size),
		Vector2(padding, padding + inner_size),
	])
	poly.color = color
	poly.position = cell_world
	overlay.add_child(poly)

	# 边框
	if border_color.a > 0:
		var line = Line2D.new()
		line.points = PackedVector2Array([
			Vector2(padding, padding),
			Vector2(padding + inner_size, padding),
			Vector2(padding + inner_size, padding + inner_size),
			Vector2(padding, padding + inner_size),
			Vector2(padding, padding),
		])
		line.default_color = border_color
		line.width = 2.0
		line.position = cell_world
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		overlay.add_child(line)

func _clear_overlay() -> void:
	_clear_children(overlay)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _update_unit_info(unit: Node) -> void:
	if hud:
		hud.update_unit_info(unit)

func _play_dot_death(unit: Node) -> void:
	var sprite = _get_sprite_for_unit(unit)
	if sprite:
		sprite.play("death")
		var tween = create_tween()
		tween.tween_interval(0.6)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.tween_callback(sprite.queue_free)

func _check_victory() -> void:
	GameManager._check_victory()
	_update_objective_progress()

func _update_objective_progress() -> void:
	var mission_type = map_data.get("mission_type", "extract")
	var alive_enemies = GameManager.enemy_units.filter(func(u): return u.is_alive)
	match mission_type:
		"assassinate":
			var total = GameManager.enemy_units.size()
			var killed = total - alive_enemies.size()
			hud.update_objective("任务目标：消灭所有敌人  %d/%d" % [killed, total])
		"destroy":
			var targets = map_data.get("objects", []).filter(func(o):
				return o.get("type") == "destructible_target"
			)
			var total = targets.size()
			var alive = targets.filter(func(t): return t.get("hp", 0) > 0).size()
			hud.update_objective("任务目标：摧毁所有目标  %d/%d 已摧毁" % [total - alive, total])
		_:
			hud.update_objective(battle_objective_text)

func _show_enemy_info_panel(enemy: Node) -> void:
	var panel_name = "EnemyInfoPanel"
	var existing = get_tree().current_scene.get_node_or_null(panel_name)
	if existing:
		existing.queue_free()
		return
	var job_data = GameData.get_job(enemy.job)
	var job_name = job_data.get("name", enemy.job)
	var hp_text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
	var ap_text = "%d/%d" % [enemy.current_ap, enemy.max_ap]
	var armor_text = "%d" % enemy.armor
	var range_text = "%d~%d" % [enemy.weapon_range[0], enemy.weapon_range[1]]
	var dmg_text = "%d~%d" % [enemy.weapon_damage[0], enemy.weapon_damage[1]]
	var weapon_text = String(enemy.weapon_name) if "weapon_name" in enemy else "未知"
	var status_text = ""
	if enemy.has_method("get_all_statuses"):
		var statuses = enemy.get_all_statuses()
		if statuses.size() > 0:
			status_text = " | ".join(statuses.keys())

	var info_text = "%s\nHP: %s  AP: %s\n护甲: %s  射程: %s\n伤害: %s  武器: %s" % [
		job_name, hp_text, ap_text, armor_text, range_text, dmg_text, weapon_text
	]
	if status_text != "":
		info_text += "\n状态: " + status_text

	var panel = PanelContainer.new()
	panel.name = panel_name
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.92)
	style.border_color = GameTheme.ENEMY_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = info_text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GameTheme.TEXT_PRIMARY)
	panel.add_child(label)

	var pos = GridSystem.grid_to_world(enemy.grid_pos) + Vector2(GridSystem.CELL_SIZE + 4, 0)
	if pos.x + 200 > map_width * GridSystem.CELL_SIZE:
		pos.x -= GridSystem.CELL_SIZE + 210
	panel.position = pos
	# 使用 info_layer 避免被 _clear_overlay 清除
	if not info_layer:
		info_layer = Node2D.new()
		info_layer.name = "InfoLayer"
		add_child(info_layer)
	info_layer.add_child(panel)

	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func(): if is_instance_valid(panel): panel.queue_free())
	panel.add_child(timer)
	timer.start()

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

func _get_skill_target_kind(skill_id: String) -> String:
	if skill_id in ["asslt_adrenaline", "heavy_taunt", "heavy_iron_fortress", "heavy_self_repair", "medic_barrier_blast", "gen_hunker_down", "gen_sprint", "gen_reposition", "scout_stealth"]:
		return "none"
	if skill_id in ["medic_heal", "medic_revive", "medic_adrenaline_shot", "medic_cure", "medic_pain_block", "medic_stim_pack", "heavy_protect", "scout_shadow_step"]:
		return "unit_ally"
	if skill_id in ["asslt_dash_strike", "asslt_breach", "asslt_blink", "heavy_grenade", "heavy_barrage", "heavy_cleave", "heavy_ground_slam", "medic_mass_cure", "scout_scan", "scout_trap", "scout_recon_drone", "scout_decoy", "gen_interact", "scout_sabotage", "asslt_storm_dash", "asslt_chain_slash"]:
		return "position"
	if skill_id in ["snip_highground"]:
		return "none"
	if skill_id in ["snip_suppressing_fire"]:
		return "unit_enemy"
	return "unit_enemy"

func _build_skill_target(skill_id: String, caster: Node) -> Dictionary:
	if skill_id in ["asslt_adrenaline", "heavy_taunt", "heavy_iron_fortress", "heavy_self_repair", "medic_barrier_blast", "gen_hunker_down", "gen_sprint", "gen_reposition", "scout_stealth", "snip_highground"]:
		return {}
	if skill_id in ["medic_heal", "medic_revive", "medic_adrenaline_shot", "medic_cure", "medic_pain_block", "medic_stim_pack", "heavy_protect"]:
		return {"target_unit": _find_best_ally_target(caster)}
	if skill_id in ["asslt_dash_strike", "asslt_breach", "asslt_blink", "heavy_grenade", "heavy_barrage", "heavy_cleave", "heavy_ground_slam", "medic_mass_cure", "scout_scan", "scout_trap", "scout_recon_drone", "scout_decoy", "gen_interact", "scout_sabotage", "asslt_storm_dash", "asslt_chain_slash"]:
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

func _get_item_target_kind(item_id: String) -> String:
	var item = GameData.get_item(item_id)
	if item.is_empty():
		return "none"
	var item_type = item.get("type", "")
	var effect = item.get("effect", {})
	if item_type in ["throwable", "trap"]:
		return "position"
	if effect.has("heal") or effect.has("revive") or effect.has("remove_status") or effect.has("remove_all_debuffs") or effect.has("add_status"):
		return "unit_ally"
	return "none"

func _get_skill_target_range(skill_id: String) -> Array[int]:
	var skill = GameData.get_skill(skill_id)
	if skill.is_empty():
		return [1, 5]
	var range_value = skill.get("range", [1, 5])
	if range_value is Array and range_value.size() >= 2:
		return [int(range_value[0]), int(range_value[1])]
	return [1, 5]

func _get_item_target_range(item_id: String) -> Array[int]:
	var item = GameData.get_item(item_id)
	if item.is_empty():
		return [1, 5]
	var range_value = item.get("range", [1, 5])
	if range_value is Array and range_value.size() >= 2:
		return [int(range_value[0]), int(range_value[1])]
	return [1, 5]

func _use_skill(skill_id: String, target_data: Dictionary = {}) -> void:
	if target_data.is_empty():
		target_data = _build_skill_target(skill_id, selected_unit)
	var result = action_system.execute_skill(selected_unit, skill_id, target_data)
	if result.get("success", false):
		AudioManager.sfx_skill()
		_render_map()
		_refresh_all_unit_sprites()
		hud.update_action_menu(selected_unit)
		_update_unit_info(selected_unit)
		_check_victory()
		_show_skill_floating_text(selected_unit, skill_id, result)
		_play_skill_visuals(selected_unit, skill_id, result)
		if skill_id == "snip_overwatch" or skill_id == "gen_overwatch":
			AudioManager.sfx_overwatch()
	else:
		_show_floating_text(selected_unit.grid_pos, "SKILL FAIL", Color(0.8, 0.4, 0.4))
		_clear_pending_skill_target()
		current_action = "move"
		_restore_battle_objective()
		_show_move_range(selected_unit)

func _show_skill_floating_text(caster: Node, skill_id: String, result: Dictionary) -> void:
	var skill = GameData.get_skill(skill_id)
	var skill_name = skill.get("name", "SKILL")
	_show_floating_text(caster.grid_pos, skill_name, Color(0.42, 0.86, 1.0))

	# 治疗类
	var healed = result.get("healed", 0)
	if healed > 0:
		_show_floating_text(caster.grid_pos + Vector2i(0, -1), "+%d" % healed, Color(0.25, 0.9, 0.4))
		return

	# 直接伤害类
	var target = result.get("target")
	if target is Node and result.get("damage", 0) > 0:
		_show_floating_text(target.grid_pos, "-%d" % int(result.damage), GameTheme.HP_LOW)
		return

	# 多目标伤害类
	var targets = result.get("targets", 0)
	if targets is int and targets > 0:
		_show_floating_text(caster.grid_pos + Vector2i(0, -1), "命中 %d" % targets, Color(1.0, 0.75, 0.03))
		return

	# 增益/位移类
	var buff = result.get("buff", "")
	if buff != "":
		_show_floating_text(caster.grid_pos + Vector2i(0, -1), buff, Color(0.9, 0.75, 0.3))

func _play_skill_visuals(caster: Node, skill_id: String, result: Dictionary) -> void:
	var caster_sprite := _get_sprite_for_unit(caster)
	if caster_sprite:
		caster_sprite.play("attack")

	var skill = GameData.get_skill(skill_id)
	var tags = skill.get("tags", [])
	var effect = String(skill.get("effect", ""))
	var center = GridSystem.grid_to_world(caster.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
	var target_pos = result.get("target_pos", caster.grid_pos)
	var target_world = GridSystem.grid_to_world(target_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
	var target_node = result.get("target")
	if target_node is Node:
		target_world = GridSystem.grid_to_world(target_node.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)

	# 元素/类型特效
	if skill_id.contains("emp") or effect.contains("emp"):
		BattleEffects.play_electro(target_world, self)
		return
	if skill_id.contains("burn") or effect.contains("burn") or "fire" in tags:
		BattleEffects.play_burn(target_world, self)
		return
	if skill_id.contains("freeze") or skill_id.contains("ice") or effect.contains("freeze"):
		BattleEffects.play_freeze(target_world, self)
		return
	if skill_id.contains("blink") or skill_id.contains("shadow_step") or effect.contains("shadow_step") or skill_id.contains("teleport"):
		BattleEffects.play_teleport(center, self)
		return
	if skill_id.contains("smoke") or skill_id.contains("stealth"):
		BattleEffects.play_smoke(center, self)
		return

	# 通用 tags
	if tags is Array:
		if "heal" in tags:
			BattleEffects.play_heal(target_world, self)
			return
		if "explosive" in tags:
			BattleEffects.play_explosion(target_world, self)
			return
		if "shield" in tags or effect.contains("shield") or skill_id.contains("shield"):
			BattleEffects.play_shield(target_world if target_node is Node else center, self)
			return
		if "buff" in tags or effect.contains("buff") or effect.contains("warcry") or effect.contains("fortify") or effect.contains("inspire") or effect.contains("rally"):
			BattleEffects.play_buff(center, self)
			return
		if "debuff" in tags or effect.contains("hack") or effect.contains("taunt") or effect.contains("mark") or skill_id.contains("suppressing"):
			BattleEffects.play_debuff(target_world, self)
			return

	# 默认在施法者位置播放一次 hit 特效表示技能生效
	BattleEffects.play_hit(center, self)

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

func _use_item(item_id: String, target_data: Dictionary = {}) -> void:
	if target_data.is_empty():
		target_data = _build_item_target(item_id, selected_unit)
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
			var explosion_pos = target_data.get("position", selected_unit.grid_pos)
			BattleEffects.play_explosion(GridSystem.grid_to_world(explosion_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0), self)
		else:
			AudioManager.sfx_heal()
			var heal_target = result.get("target", selected_unit)
			var heal_pos = selected_unit.grid_pos
			if heal_target is Node:
				heal_pos = heal_target.grid_pos
			BattleEffects.play_heal(GridSystem.grid_to_world(heal_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0), self)
		_render_map()
		_refresh_all_unit_sprites()
		hud.update_action_menu(selected_unit)
		_update_unit_info(selected_unit)
		_check_victory()
		_show_item_floating_text(selected_unit, item, result)
		_clear_pending_item_target()
		current_action = "move"
		if selected_unit:
			_show_move_range(selected_unit)
	else:
		_show_floating_text(selected_unit.grid_pos, "ITEM FAIL", Color(0.8, 0.4, 0.4))
		_clear_pending_item_target()
		current_action = "move"
		_restore_battle_objective()
		if selected_unit:
			_show_move_range(selected_unit)

func _show_item_floating_text(caster: Node, item: Dictionary, result: Dictionary) -> void:
	var item_name = item.get("name", "ITEM")
	_show_floating_text(caster.grid_pos, item_name, Color(0.42, 0.86, 1.0))
	var healed = result.get("healed", 0)
	if healed > 0:
		var target = result.get("target")
		var pos = caster.grid_pos if not (target is Node) else target.grid_pos
		_show_floating_text(pos + Vector2i(0, -1), "+%d" % healed, Color(0.25, 0.9, 0.4))
	var damage = result.get("damage", 0)
	if damage > 0:
		var target = result.get("target")
		if target is Node:
			_show_floating_text(target.grid_pos, "-%d" % int(damage), GameTheme.HP_LOW)

func _handle_skill_target_click(grid_pos: Vector2i, clicked_unit: Node) -> void:
	if not pending_skill_id or not selected_unit:
		_cancel_pending_target_selection()
		return

	var target_data := {}
	match pending_skill_target_kind:
		"unit_ally":
			if clicked_unit and clicked_unit.team == selected_unit.team:
				target_data = {"target_unit": clicked_unit}
		"unit_enemy":
			if clicked_unit and clicked_unit.team != selected_unit.team:
				target_data = {"target_unit": clicked_unit}
		"position":
			target_data = {"position": grid_pos}

	if target_data.is_empty():
		_show_floating_text(selected_unit.grid_pos, "请选择目标", Color(0.95, 0.8, 0.2))
		return

	var skill_id = pending_skill_id
	_cancel_pending_target_selection()
	_use_skill(skill_id, target_data)

func _handle_item_target_click(grid_pos: Vector2i, clicked_unit: Node) -> void:
	if not pending_item_id or not selected_unit:
		_cancel_pending_target_selection()
		return

	var target_data := {}
	match pending_item_target_kind:
		"unit_ally":
			if clicked_unit and clicked_unit.team == selected_unit.team:
				target_data = {"target_unit": clicked_unit}
		"unit_enemy":
			if clicked_unit and clicked_unit.team != selected_unit.team:
				target_data = {"target_unit": clicked_unit}
		"position":
			target_data = {"position": grid_pos}

	if target_data.is_empty():
		_show_floating_text(selected_unit.grid_pos, "请选择目标", Color(0.95, 0.8, 0.2))
		return

	var item_id = pending_item_id
	_cancel_pending_target_selection()
	_use_item(item_id, target_data)

func _show_skill_target_hint(skill_id: String) -> void:
	var kind = _get_skill_target_kind(skill_id)
	match kind:
		"unit_ally":
			hud.update_objective("选择友方目标")
		"unit_enemy":
			hud.update_objective("选择敌方目标")
		"position":
			hud.update_objective("选择地面位置")
		_:
			hud.update_objective("确认技能")

func _show_item_target_hint(item_id: String) -> void:
	var kind = _get_item_target_kind(item_id)
	match kind:
		"unit_ally":
			hud.update_objective("选择友方目标")
		"position":
			hud.update_objective("选择地面位置")
		_:
			hud.update_objective("确认物品")

func _restore_battle_objective() -> void:
	if hud:
		hud.update_objective(battle_objective_text)

func _cancel_pending_target_selection() -> void:
	pending_skill_id = ""
	pending_skill_target_kind = ""
	pending_item_id = ""
	pending_item_target_kind = ""
	_clear_target_highlights()
	if current_action == "skill_target" or current_action == "item_target":
		current_action = "move"
		_restore_battle_objective()
		if selected_unit:
			_show_move_range(selected_unit)

func _clear_pending_skill_target() -> void:
	pending_skill_id = ""
	pending_skill_target_kind = ""
	_clear_target_highlights()

func _clear_pending_item_target() -> void:
	pending_item_id = ""
	pending_item_target_kind = ""
	_clear_target_highlights()

func _refresh_target_highlights() -> void:
	_clear_target_highlights()
	if not selected_unit:
		return

	var target_kind := ""
	var target_range := [1, 5]
	if pending_skill_id != "":
		target_kind = pending_skill_target_kind
		target_range = _get_skill_target_range(pending_skill_id)
	elif pending_item_id != "":
		target_kind = pending_item_target_kind
		target_range = _get_item_target_range(pending_item_id)

	for sprite in units_container.get_children():
		if not (sprite is UnitSprite):
			continue
		var unit_sprite := sprite as UnitSprite
		if not unit_sprite.unit or not unit_sprite.unit.is_alive:
			continue
		var should_hover := false
		match target_kind:
			"unit_ally":
				should_hover = unit_sprite.unit.team == selected_unit.team
			"unit_enemy":
				should_hover = unit_sprite.unit.team != selected_unit.team
			_:
				should_hover = false
		unit_sprite.set_hover(should_hover)

	if target_kind == "position":
		if pending_skill_id != "":
			_highlight_skill_position_targets(target_range)
		elif pending_item_id != "":
			_highlight_item_position_targets(target_range)

func _clear_target_highlights() -> void:
	for sprite in units_container.get_children():
		if sprite is UnitSprite:
			(sprite as UnitSprite).set_hover(false)

func _highlight_skill_position_targets(target_range: Array[int]) -> void:
	var min_range = 1
	var max_range = 5
	if target_range.size() >= 2:
		min_range = int(target_range[0])
		max_range = int(target_range[1])
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			var dist = GridSystem.manhattan_distance(selected_unit.grid_pos, pos)
			if dist < min_range or dist > max_range:
				continue
			_highlight_cell(pos, Color(0.25, 0.84, 0.98, 0.22))

func _highlight_item_position_targets(target_range: Array[int]) -> void:
	var min_range = 1
	var max_range = 5
	if target_range.size() >= 2:
		min_range = int(target_range[0])
		max_range = int(target_range[1])
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			var dist = GridSystem.manhattan_distance(selected_unit.grid_pos, pos)
			if dist < min_range or dist > max_range:
				continue
			if not MapLoader.is_passable(map_data, pos.x, pos.y):
				continue
			_highlight_cell(pos, Color(0.42, 0.95, 0.45, 0.22))

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
		"name": item.get("name", "闄烽槺"),
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
	var base_zoom = camera_2d.zoom
	var tween = create_tween()
	tween.tween_method(Callable(self, "_apply_camera_shake").bind(base_pos, strength), 0.0, 1.0, duration)
	tween.parallel().tween_property(camera_2d, "zoom", base_zoom * 1.08, duration * 0.5)
	tween.tween_property(camera_2d, "zoom", base_zoom, duration * 0.5)
	tween.tween_callback(func():
		camera_2d.position = base_pos
		camera_2d.zoom = base_zoom
	)

func _apply_camera_shake(t: float, base_pos: Vector2, strength: float) -> void:
	camera_2d.position = base_pos + Vector2(
		sin(t * TAU * 4.0) * strength,
		cos(t * TAU * 6.0) * strength * 0.5
	)

func focus_on_position(world_pos: Vector2, duration: float = 0.25) -> void:
	if not camera_2d:
		return
	if _camera_dragging:
		return
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera_2d, "position", world_pos, duration)

func focus_on_unit(unit: Node, duration: float = 0.25) -> void:
	if not unit:
		return
	var world_pos = GridSystem.grid_to_world(unit.grid_pos) + Vector2(GridSystem.CELL_SIZE / 2.0, GridSystem.CELL_SIZE / 2.0)
	focus_on_position(world_pos, duration)

func _center_camera_on_map() -> void:
	if not camera_2d:
		return
	# terrain_layer 是普通 Node2D，get_used_rect() 无效
	# 直接用 map_width/map_height 计算地图中心
	var map_pixel_w = map_width * GridSystem.CELL_SIZE
	var map_pixel_h = map_height * GridSystem.CELL_SIZE
	var center = Vector2(map_pixel_w / 2.0, map_pixel_h / 2.0)
	camera_2d.position = center
	var scale_x = float(get_viewport().size.x) / map_pixel_w
	var scale_y = float(get_viewport().size.y) / map_pixel_h
	var target_zoom = maxf(scale_x, scale_y)
	target_zoom = clampf(target_zoom, 0.5, 3.0)
	camera_2d.zoom = Vector2(target_zoom, target_zoom)
