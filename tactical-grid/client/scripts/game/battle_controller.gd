## 战斗场景控制器
## 管理战斗场景的渲染和交互
extends Node2D
class_name BattleController

const CELL_SIZE = 64

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var units_container: Node2D = $Units
@onready var overlay: Node2D = $Overlay
@onready var hud: HUD = $HUD

var map_data: Dictionary = {}
var map_width: int = 10
var map_height: int = 8
var selected_unit: Node = null  # Unit
var reachable_cells: Dictionary = {}

# 颜色
const COLOR_MOVE = Color(0.13, 0.59, 0.95, 0.4)
const COLOR_ATTACK = Color(0.96, 0.26, 0.21, 0.4)
const COLOR_DANGER = Color(1.0, 0.62, 0.0, 0.4)
const COLOR_SELECTED = Color(0.0, 1.0, 0.0, 0.3)

func _ready() -> void:
	# 加载测试地图
	_load_test_map()

func _load_test_map() -> void:
	# 从 API 加载或使用本地测试数据
	var api = ApiClient.new()
	add_child(api)

	var result = await api.guest_login()
	if result.code == 0:
		GameManager.auth_token = result.data.token

	var level_result = await api.get_level("ch1_m1")
	if level_result.code == 0:
		map_data = MapLoader.load_from_dict(level_result.data)
		_render_map()
		_spawn_units()
		GameManager.current_map_data = map_data
		GameManager._setup_battle()

## 渲染地图
func _render_map() -> void:
	map_width = map_data.size.width
	map_height = map_data.size.height

	var base_terrain = map_data.layers.base_terrain
	var blocker = map_data.layers.blocker

	# 绘制地形（使用颜色作为占位，后续替换为 tileset）
	for y in range(map_height):
		for x in range(map_width):
			var terrain = base_terrain[y][x]
			var color = _get_terrain_color(terrain)
			_draw_cell(Vector2i(x, y), color)

	# 绘制阻挡物
	for y in range(map_height):
		for x in range(map_width):
			var block = blocker[y][x]
			if block != 0:
				_draw_cell(Vector2i(x, y), _get_blocker_color(block))

func _get_terrain_color(terrain: int) -> Color:
	match terrain:
		0: return Color(0.3, 0.4, 0.3)  # plain - 暗绿
		1: return Color(0.4, 0.35, 0.25)  # road - 棕色
		2: return Color(0.1, 0.3, 0.1)  # forest - 深绿
		3: return Color(0.6, 0.5, 0.3)  # sand - 沙色
		4: return Color(0.4, 0.3, 0.2)  # highland - 棕红
		5: return Color(0.1, 0.2, 0.5)  # water - 蓝
		_: return Color(0.3, 0.4, 0.3)

func _get_blocker_color(block: int) -> Color:
	match block:
		6: return Color(0.2, 0.2, 0.2)  # wall - 灰
		7: return Color(0.5, 0.4, 0.2)  # crate - 木色
		_: return Color.TRANSPARENT

func _draw_cell(pos: Vector2i, color: Color) -> void:
	# 用绘制创建占位格子
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	rect.position = GridSystem.grid_to_world(pos)
	overlay.add_child(rect)

## 生成单位
func _spawn_units() -> void:
	for spawn in MapLoader.get_player_spawns(map_data):
		var unit = GameData.create_player_unit("assault", "玩家")
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		var sprite = _create_unit_sprite(unit)
		sprite.position = GridSystem.grid_to_world(unit.grid_pos)
		units_container.add_child(sprite)
		GameManager.player_units.append(unit)

	for spawn in MapLoader.get_enemy_spawns(map_data):
		var enemy_type = spawn.get("job", "sentry_basic")
		var unit = GameData.create_enemy_unit(enemy_type)
		unit.grid_pos = Vector2i(spawn.x, spawn.y)
		var sprite = _create_unit_sprite(unit)
		sprite.position = GridSystem.grid_to_world(unit.grid_pos)
		units_container.add_child(sprite)
		GameManager.enemy_units.append(unit)

func _create_unit_sprite(unit: Node) -> UnitSprite:
	var sprite = UnitSprite.new()
	sprite.update_unit(unit)
	return sprite

## 点击处理
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.position)

func _handle_left_click(world_pos: Vector2) -> void:
	var grid_pos = GridSystem.world_to_grid(world_pos)

	# 检查是否点击了单位
	var clicked_unit = _get_unit_at(grid_pos)
	if clicked_unit and clicked_unit.team == "player":
		_select_unit(clicked_unit)
		return

	# 如果选中了单位，尝试移动
	if selected_unit and reachable_cells.has(grid_pos):
		_move_unit(selected_unit, grid_pos)

func _handle_right_click(world_pos: Vector2) -> void:
	# 右键取消选择
	_deselect_unit()

func _select_unit(unit: Node) -> void:
	# 取消之前选中的精灵
	if selected_unit:
		for sprite in units_container.get_children():
			if sprite is UnitSprite and sprite.unit == selected_unit:
				sprite.set_selected(false)
				break

	selected_unit = unit
	GameManager.select_unit(unit)

	# 选中新精灵
	for sprite in units_container.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			sprite.set_selected(true)
			break

	_show_move_range(unit)

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

func _show_move_range(unit: Node) -> void:
	_clear_overlay()
	reachable_cells = Pathfinding.get_reachable_cells(
		unit.grid_pos,
		unit.move_points,
		map_width,
		map_height,
		_get_move_cost.bind(unit.job),
		_is_blocked
	)

	for cell in reachable_cells:
		if cell == unit.grid_pos:
			continue
		_highlight_cell(cell, COLOR_MOVE)

func _move_unit(unit: Node, target: Vector2i) -> void:
	if not unit.spend_ap(0):
		return
	unit.move_to(target)
	# 找到对应的精灵并更新位置
	for sprite in units_container.get_children():
		if sprite is UnitSprite and sprite.unit == unit:
			sprite.position = GridSystem.grid_to_world(target)
			sprite.update_unit(unit)
			break
	_clear_overlay()
	_show_move_range(unit)

func _get_unit_at(pos: Vector2i) -> Dictionary:
	for unit in GameManager.player_units + GameManager.enemy_units:
		if unit.is_alive and unit.grid_pos == pos:
			return unit
	return null

func _get_sprite_at(pos: Vector2i) -> UnitSprite:
	for sprite in units_container.get_children():
		if sprite is UnitSprite and sprite.unit and sprite.unit.is_alive and sprite.unit.grid_pos == pos:
			return sprite
	return null

func _highlight_cell(pos: Vector2i, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	rect.position = GridSystem.grid_to_world(pos) + Vector2(1, 1)
	overlay.add_child(rect)

func _clear_overlay() -> void:
	for child in overlay.get_children():
		# 不删除地图渲染
		if child is ColorRect and child.color != _get_terrain_color(0):
			# 只清除高亮，不删除地图格子
			pass

func _get_move_cost(pos: Vector2i, job: String) -> int:
	var terrain = MapLoader.get_terrain_at(map_data, pos.x, pos.y)
	var blocker = MapLoader.get_blocker_at(map_data, pos.x, pos.y)
	if blocker == 6 or blocker == 7:
		return -1
	if terrain == 5:
		return -1
	match terrain:
		0, 1, 4: return 1
		2: return 2 if job != "scout" else 1
		3: return 2
		8: return 2
		9: return 1
		_: return 1

func _is_blocked(pos: Vector2i) -> bool:
	return not MapLoader.is_passable(map_data, pos.x, pos.y)
