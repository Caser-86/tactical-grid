## 程序化战术格：为所有地图提供可读的地面、掩体和任务标记。
extends Node2D
class_name TacticalTile

const CELL_SIZE := 64.0

var terrain_id := -1
var blocker_id := 0
var objective_type := ""
var environment_kit := ""
var floor_variant := 0
var blocker_variant := 0
var edge_variants: Array = []
var floor_texture: Texture2D
var blocker_texture: Texture2D
var edge_textures: Array[Texture2D] = []

func setup(
	base_terrain: int,
	blocker: int = 0,
	objective: String = "",
	kit: String = "",
	selected_floor_variant: int = 0,
	selected_edge_variants: Array = [],
	selected_blocker_variant: int = 0
) -> void:
	terrain_id = base_terrain
	blocker_id = blocker
	objective_type = objective
	environment_kit = kit
	floor_variant = selected_floor_variant
	edge_variants = selected_edge_variants.duplicate()
	blocker_variant = selected_blocker_variant
	floor_texture = ArtCatalog.get_environment_component_texture(environment_kit, &"floor", floor_variant) if not environment_kit.is_empty() else null
	blocker_texture = ArtCatalog.get_environment_component_texture(environment_kit, &"prop", blocker_variant) if blocker_id != 0 and not environment_kit.is_empty() else null
	edge_textures.clear()
	for edge_variant in edge_variants:
		var texture := ArtCatalog.get_environment_component_texture(environment_kit, &"edge", int(edge_variant))
		if texture:
			edge_textures.append(texture)
	queue_redraw()

func _draw() -> void:
	if terrain_id >= 0:
		_draw_ground()
	if blocker_id != 0:
		_draw_blocker()
	if objective_type != "":
		_draw_objective()

func _draw_ground() -> void:
	if floor_texture:
		draw_texture_rect(floor_texture, Rect2(Vector2.ZERO, Vector2.ONE * CELL_SIZE), false)
		for texture in edge_textures:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2.ONE * CELL_SIZE), false)
		return
	var base := GameTheme.get_terrain_color(terrain_id).darkened(0.35)
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * CELL_SIZE), base, true)
	draw_rect(Rect2(Vector2(1, 1), Vector2.ONE * (CELL_SIZE - 2)), base.lightened(0.08), false, 1.0)
	match terrain_id:
		1, 9: # 道路与桥：平行板材线
			for y in range(10, 64, 12):
				draw_line(Vector2(2, y), Vector2(62, y), Color(0.60, 0.70, 0.72, 0.18), 1.0)
		2: # 森林：低对比树冠，避免遮挡单位
			for p in [Vector2(15, 18), Vector2(43, 14), Vector2(30, 43), Vector2(52, 47)]:
				draw_circle(p, 9, Color(0.08, 0.22, 0.15, 0.82))
				draw_circle(p - Vector2(2, 3), 5, Color(0.18, 0.40, 0.25, 0.72))
		3: # 沙地：风蚀曲线
			for y in range(12, 64, 14):
				draw_arc(Vector2(30, y), 20, 0.15, 2.9, 12, Color(0.85, 0.68, 0.38, 0.22), 1.0)
		4: # 高地：岩层边缘
			draw_polyline(PackedVector2Array([Vector2(4, 45), Vector2(20, 36), Vector2(34, 42), Vector2(59, 26)]), Color(0.78, 0.55, 0.34, 0.45), 2.0)
		5: # 水域：水波
			for y in range(12, 64, 13):
				draw_arc(Vector2(31, y), 16, 0.25, 2.8, 10, Color(0.32, 0.78, 0.96, 0.38), 1.2)
		8: # 毒池：危险气泡
			for p in [Vector2(15, 16), Vector2(42, 22), Vector2(28, 45), Vector2(51, 50)]:
				draw_circle(p, 4, Color(0.48, 0.92, 0.18, 0.45))
		_:
			# 工业地板分缝。
			draw_line(Vector2(32, 2), Vector2(32, 62), Color(0.65, 0.78, 0.80, 0.10), 1.0)
			draw_line(Vector2(2, 32), Vector2(62, 32), Color(0.65, 0.78, 0.80, 0.10), 1.0)

func _draw_blocker() -> void:
	if blocker_texture:
		draw_texture_rect(blocker_texture, Rect2(Vector2.ZERO, Vector2.ONE * CELL_SIZE), false)
		return
	if blocker_id == 6: # 墙体
		draw_rect(Rect2(6, 14, 52, 38), Color(0.10, 0.14, 0.17), true)
		draw_rect(Rect2(6, 14, 52, 38), Color(0.38, 0.55, 0.60, 0.60), false, 2.0)
		draw_line(Vector2(10, 26), Vector2(54, 26), Color(0.45, 0.85, 0.90, 0.30), 1.0)
		draw_line(Vector2(10, 40), Vector2(54, 40), Color(0.45, 0.85, 0.90, 0.22), 1.0)
	else: # 箱体和其他半掩体
		draw_rect(Rect2(12, 16, 40, 36), Color(0.24, 0.16, 0.09), true)
		draw_rect(Rect2(12, 16, 40, 36), Color(0.92, 0.58, 0.20, 0.72), false, 2.0)
		draw_line(Vector2(12, 16), Vector2(52, 52), Color(0.98, 0.78, 0.35, 0.45), 1.0)
		draw_line(Vector2(52, 16), Vector2(12, 52), Color(0.98, 0.78, 0.35, 0.45), 1.0)

func _draw_objective() -> void:
	match objective_type:
		"evac":
			draw_arc(Vector2(32, 32), 24, 0, TAU, 28, Color(0.20, 1.0, 0.56, 0.95), 3.0)
			draw_string(ThemeDB.fallback_font, Vector2(25, 38), "E", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.82, 1.0, 0.90))
		"destructible_target":
			draw_circle(Vector2(32, 32), 20, Color(1.0, 0.42, 0.08, 0.35))
			draw_line(Vector2(18, 18), Vector2(46, 46), Color(1.0, 0.80, 0.35), 3.0)
			draw_line(Vector2(46, 18), Vector2(18, 46), Color(1.0, 0.80, 0.35), 3.0)
		"terminal":
			draw_rect(Rect2(20, 16, 24, 32), Color(0.03, 0.17, 0.20, 0.90), true)
			draw_rect(Rect2(20, 16, 24, 32), Color(0.20, 0.94, 0.96, 0.92), false, 2.0)
			draw_line(Vector2(25, 26), Vector2(39, 26), Color(0.70, 1.0, 1.0), 2.0)
			draw_line(Vector2(25, 33), Vector2(35, 33), Color(0.34, 0.90, 0.96), 2.0)
