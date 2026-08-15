extends Node2D

const Runner = preload("res://tests/v2/test_runner.gd")
const BASE_SIZE := Vector2(1920.0, 1080.0)
const UNIT_KEYS := [&"v2_assault", &"v2_scout", &"v2_sentry", &"v2_drone", &"v2_shield_guard"]
const UNIT_LABELS := ["ASSAULT", "SCOUT", "SENTRY", "DRONE", "SHIELD GUARD"]
const DIRECTIONS := [&"north", &"east", &"south", &"west"]
const DIRECTION_LABELS := ["NORTH", "EAST", "SOUTH", "WEST"]
const ACCENTS := [Color("55e7ff"), Color("b8ff3d"), Color("ff5149"), Color("55e7ff"), Color("ff9d35")]

var t := Runner.new()
var target_size := Vector2i(1920, 1080)
var output_path := ""
var _content: Node2D
var _floor_texture: Texture2D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_args()
	var window := get_window()
	window.size = target_size
	window.content_scale_size = target_size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_viewport().size = target_size
	var catalog: Node = get_node_or_null("/root/ArtCatalog")
	t.check(catalog != null, "M1 四方向快照找到 ArtCatalog")
	if catalog == null:
		t.finish(get_tree())
		return

	_content = Node2D.new()
	_content.name = "DirectionContactSheet"
	var scale_factor := minf(float(target_size.x) / BASE_SIZE.x, float(target_size.y) / BASE_SIZE.y)
	scale = Vector2.ONE * scale_factor
	position = (Vector2(target_size) - BASE_SIZE * scale_factor) * 0.5
	add_child(_content)
	_floor_texture = catalog.call("get_environment_component_texture", &"echo_yard", &"floor", 0)
	_build_samples(catalog)
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame

	t.check(_content.get_child_count() == 20, "M1 四方向快照包含五类角色的四个朝向")
	if DisplayServer.get_name() == "headless":
		t.check(true, "M1 无头驱动跳过 framebuffer 保存但保留结构验证")
		t.finish(get_tree())
		return

	var image := get_viewport().get_texture().get_image()
	t.check(image != null and not image.is_empty(), "M1 四方向快照 framebuffer 非空")
	if image != null and not image.is_empty():
		var absolute_path := output_path
		if absolute_path.is_empty():
			absolute_path = "res://assets/v2/source/units/m1_identity_direction_contact_sheet.png"
		if absolute_path.begins_with("res://"):
			absolute_path = ProjectSettings.globalize_path(absolute_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		var error := image.save_png(absolute_path)
		t.check(error == OK and FileAccess.file_exists(absolute_path), "M1 四方向快照保存成功")
		print("M1 identity direction contact sheet: %s" % absolute_path)
	t.finish(get_tree())

func _build_samples(catalog: Node) -> void:
	for column in range(UNIT_KEYS.size()):
		var x := 340.0 + column * 330.0
		for row in range(DIRECTIONS.size()):
			var y := 330.0 + row * 170.0
			var key := StringName("%s_%s" % [String(UNIT_KEYS[column]), String(DIRECTIONS[row])])
			var texture: Texture2D = catalog.call("get_texture", &"unit", key)
			var sprite := Sprite2D.new()
			sprite.name = "%s_%s" % [UNIT_LABELS[column], DIRECTION_LABELS[row]]
			sprite.texture = texture
			sprite.position = Vector2(x, y)
			sprite.scale = Vector2.ONE * 0.68
			_content.add_child(sprite)

func _draw() -> void:
	if _floor_texture != null:
		for y in range(0, int(BASE_SIZE.y), 64):
			for x in range(0, int(BASE_SIZE.x), 64):
				draw_texture_rect(_floor_texture, Rect2(x, y, 64, 64), false, Color(0.72, 0.78, 0.82, 1.0))
	draw_rect(Rect2(0, 0, BASE_SIZE.x, BASE_SIZE.y), Color(0.015, 0.025, 0.035, 0.24), true)
	draw_rect(Rect2(50, 44, 1820, 100), Color(0.02, 0.05, 0.07, 0.94), true)
	draw_line(Vector2(50, 144), Vector2(1870, 144), Color("27b9d4"), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(82, 104), "M1 UNIT DIRECTION SAMPLE  //  ECHO YARD RUNTIME SCALE", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("d9f8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(82, 132), "Five identities, four authored views, no mirrored or placeholder frames", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("7ca6b3"))
	for row in range(DIRECTIONS.size()):
		var y := 330.0 + row * 170.0
		draw_string(ThemeDB.fallback_font, Vector2(76, y + 8), DIRECTION_LABELS[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("c9e4eb"))
		draw_line(Vector2(220, y + 56), Vector2(1840, y + 56), Color(0.22, 0.55, 0.62, 0.42), 1.0)
	for column in range(UNIT_KEYS.size()):
		var x := 340.0 + column * 330.0
		draw_string(ThemeDB.fallback_font, Vector2(x - 90, 206), UNIT_LABELS[column], HORIZONTAL_ALIGNMENT_CENTER, 180, 22, ACCENTS[column])
		draw_circle(Vector2(x, 330.0 + 3 * 170.0 + 2), 55.0, Color(ACCENTS[column], 0.10))
		draw_arc(Vector2(x, 330.0 + 3 * 170.0 + 2), 59.0, 0.0, TAU, 32, ACCENTS[column], 3.0)

func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-size="):
			var parts := argument.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2:
				target_size = Vector2i(maxi(640, int(parts[0])), maxi(360, int(parts[1])))
		elif argument.begins_with("--qa-output="):
			output_path = argument.trim_prefix("--qa-output=")
