extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const RouterScript = preload("res://scripts/v2/input/v2_battle_input_router.gd")

var t := Runner.new()
var _pan_delta := Vector2.ZERO
var _zoom_amount := 0
var _focus_count := 0

func _initialize() -> void:
	var camera_script: Script = ResourceLoader.load("res://scripts/game/battle_camera_controller.gd") as Script
	var camera: Node = camera_script.new()
	root.add_child(camera)
	camera.configure_bounds(Rect2(0, 0, 3200, 2400), Rect2(0, 0, 800, 500), Vector2(1200, 900))
	var before_pan: Vector2 = camera.position
	camera.begin_drag(Vector2(500, 300))
	camera.drag_to(Vector2(450, 260))
	camera.end_drag()
	t.check(camera.position != before_pan, "中键拖动改变镜头位置")

	var before_zoom: Vector2 = camera.zoom
	camera.zoom_at(1.0, Vector2(400, 250))
	t.check(camera.zoom != before_zoom and camera.zoom.x > before_zoom.x, "滚轮向上放大镜头")
	camera.zoom_at(-1.0, Vector2(400, 250))
	t.check(camera.zoom.x < 1.5, "滚轮向下缩小且不超过边界")
	camera.focus_cell(Vector2i(20, 10))
	t.check(camera.position.x >= 0.0 and camera.position.y >= 0.0, "Home 聚焦格子后仍受地图边界约束")

	var router: V2BattleInputRouter = RouterScript.new()
	root.add_child(router)
	router.camera_pan_requested.connect(_on_pan)
	router.camera_zoom_requested.connect(_on_zoom)
	router.focus_requested.connect(_on_focus)
	var middle_down := InputEventMouseButton.new()
	middle_down.button_index = MOUSE_BUTTON_MIDDLE
	middle_down.pressed = true
	middle_down.position = Vector2(500, 300)
	var middle_motion := InputEventMouseMotion.new()
	middle_motion.position = Vector2(450, 260)
	var middle_up := InputEventMouseButton.new()
	middle_up.button_index = MOUSE_BUTTON_MIDDLE
	middle_up.pressed = false
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var home := InputEventKey.new()
	home.keycode = KEY_HOME
	home.pressed = true
	router.handle_event(middle_down, Callable())
	router.handle_event(middle_motion, Callable(func(_screen: Vector2): return Vector2i.ZERO))
	router.handle_event(middle_up, Callable())
	router.handle_event(wheel, Callable())
	router.handle_event(home, Callable())
	t.check(_pan_delta == Vector2(-50, -40), "输入路由器转发中键拖动增量")
	t.check(_zoom_amount == 1, "输入路由器转发滚轮缩放")
	t.check(_focus_count == 1 and router.get_state_name() == "free_select", "Home 聚焦不改变战术状态")

	camera.free()
	router.free()
	t.finish(self)

func _on_pan(delta: Vector2) -> void:
	_pan_delta += delta

func _on_zoom(amount: int) -> void:
	_zoom_amount += amount

func _on_focus() -> void:
	_focus_count += 1
