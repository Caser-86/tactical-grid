## 战斗相机控制器
## 管理平移、缩放、边界约束、选中单位跟随和目标定位
extends Camera2D
class_name BattleCameraController

signal event_feedback_started(kind: StringName)

## 相机缩放范围
const DEFAULT_ZOOM := 1.0
const MIN_ZOOM := 0.65
const MAX_ZOOM := 1.5
## 平移速度（像素/秒）
const PAN_SPEED := 600.0
## 缩放步长
const ZOOM_STEP := 1.1
## 平滑跟随插值系数
const FOLLOW_LERP := 8.0
## 边缘平移触发边距（像素）
const EDGE_PAN_MARGIN := 16.0
const FEEDBACK_EVENTS: Array[StringName] = [&"critical", &"explosion", &"boss_phase"]

## 地图边界（世界坐标）
var _map_bounds: Rect2 = Rect2()
## 安全视口区域（HUD 不遮挡的可用区域）
var _safe_viewport: Rect2 = Rect2()
## 是否跟随选中单位
var _follow_target: Node2D = null
## 边缘平移方向（由鼠标位置或键盘输入设置）
var _edge_pan: Vector2 = Vector2.ZERO
## 是否启用键盘平移
var _keyboard_pan: Vector2 = Vector2.ZERO
var _feedback_tween: Tween
## 中键拖拽状态
var _dragging: bool = false
var _last_drag_screen_pos: Vector2 = Vector2.ZERO
## 全图概览状态
var _in_overview: bool = false
var _saved_zoom: Vector2 = Vector2.ONE
var _saved_position: Vector2 = Vector2.ZERO
## Home 键目标
var _home_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	enabled = true

func _process(delta: float) -> void:
	# 鼠标边缘平移
	_update_edge_pan()
	# 合并边缘平移和键盘平移
	var pan_dir = _edge_pan + _keyboard_pan
	if pan_dir.length() > 0.01:
		var move = pan_dir.normalized() * PAN_SPEED * delta
		position += move
		_clamp_to_bounds()

	# 平滑跟随选中单位
	if _follow_target and is_instance_valid(_follow_target):
		var target_pos = _follow_target.global_position
		global_position = global_position.lerp(target_pos, FOLLOW_LERP * delta)
		_clamp_to_bounds()

func _input(event: InputEvent) -> void:
	# 鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				begin_drag(event.position)
			else:
				end_drag()

	# 鼠标移动拖拽
	if event is InputEventMouseMotion and _dragging:
		drag_to(event.position)

	# 键盘平移与快捷键
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W, KEY_UP: _keyboard_pan.y = -1.0
			KEY_S, KEY_DOWN: _keyboard_pan.y = 1.0
			KEY_A, KEY_LEFT: _keyboard_pan.x = -1.0
			KEY_D, KEY_RIGHT: _keyboard_pan.x = 1.0
			KEY_HOME: focus_home(_home_target)
			KEY_TAB: toggle_overview()
	elif event is InputEventKey and not event.pressed:
		match event.keycode:
			KEY_W, KEY_UP, KEY_S, KEY_DOWN: _keyboard_pan.y = 0.0
			KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT: _keyboard_pan.x = 0.0

## 设置地图边界和安全视口
func setup(map_bounds: Rect2, safe_viewport: Rect2, initial_focus: Vector2 = Vector2(INF, INF)) -> void:
	_map_bounds = map_bounds
	_safe_viewport = safe_viewport
	zoom = Vector2.ONE * DEFAULT_ZOOM
	var focus_point := initial_focus
	if not is_finite(focus_point.x) or not is_finite(focus_point.y):
		focus_point = map_bounds.get_center()
	_home_target = focus_point
	position = focus_point + _get_safe_viewport_offset()

## 切换全图概览
func toggle_overview() -> void:
	if _in_overview:
		zoom = _saved_zoom
		position = _saved_position
		_in_overview = false
	else:
		_saved_zoom = zoom
		_saved_position = position
		var safe_size := _get_safe_viewport().size
		var fit_zoom := minf(safe_size.x / _map_bounds.size.x, safe_size.y / _map_bounds.size.y)
		zoom = Vector2.ONE * clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)
		position = _map_bounds.get_center() + _get_safe_viewport_offset()
		_in_overview = true
	_clamp_to_bounds()

## 聚焦到目标位置（Home 键）
func focus_home(target: Vector2) -> void:
	_home_target = target
	position = target + _get_safe_viewport_offset()
	_clamp_to_bounds()

## 设置 Home 目标（不移动相机）
func set_home_target(target: Vector2) -> void:
	_home_target = target

## 开始中键拖拽
func begin_drag(screen_pos: Vector2) -> void:
	_dragging = true
	_last_drag_screen_pos = screen_pos

## 拖拽移动
func drag_to(screen_pos: Vector2) -> void:
	if not _dragging:
		return
	position -= (screen_pos - _last_drag_screen_pos) / zoom
	_last_drag_screen_pos = screen_pos
	_clamp_to_bounds()

## 结束拖拽
func end_drag() -> void:
	_dragging = false

## 平滑定位到指定格子（世界坐标）
func focus_position(world_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position", world_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 跟随选中单位
func set_follow_target(target: Node2D) -> void:
	_follow_target = target

## 取消跟随
func clear_follow_target() -> void:
	_follow_target = null

## Important-event feedback is owned by the camera so combat rules never manipulate it directly.
func play_event_feedback(kind: StringName, world_pos: Vector2, duration_override: float = -1.0) -> void:
	if kind not in FEEDBACK_EVENTS:
		return
	if GameManager.get_settings().get("reduce_motion", false):
		return
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()

	event_feedback_started.emit(kind)
	var origin := position
	var direction := (world_pos - origin).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var intensity := 3.0
	match kind:
		&"explosion": intensity = 4.0
		&"boss_phase": intensity = 5.0
	var duration := duration_override if duration_override > 0.0 else 0.20

	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "position", origin + direction * intensity, duration * 0.24)
	_feedback_tween.tween_property(self, "position", origin - direction * intensity * 0.65, duration * 0.24)
	_feedback_tween.tween_property(self, "position", origin + direction.orthogonal() * intensity * 0.35, duration * 0.22)
	_feedback_tween.tween_property(self, "position", origin, duration * 0.30)
	_feedback_tween.finished.connect(_clamp_to_bounds)

## 更新鼠标边缘平移方向
func _update_edge_pan() -> void:
	var viewport_size := get_viewport_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	_edge_pan = Vector2.ZERO
	# Skip edge pan when cursor is at origin (headless) or outside the viewport
	if mouse_pos.x <= 0.0 or mouse_pos.y <= 0.0:
		return
	if mouse_pos.x >= viewport_size.x or mouse_pos.y >= viewport_size.y:
		return
	if mouse_pos.x < EDGE_PAN_MARGIN:
		_edge_pan.x = -1.0
	elif mouse_pos.x > viewport_size.x - EDGE_PAN_MARGIN:
		_edge_pan.x = 1.0
	if mouse_pos.y < EDGE_PAN_MARGIN:
		_edge_pan.y = -1.0
	elif mouse_pos.y > viewport_size.y - EDGE_PAN_MARGIN:
		_edge_pan.y = 1.0

## 在指定屏幕坐标处缩放
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom = zoom
	var new_zoom = old_zoom * factor
	new_zoom = new_zoom.clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
	if new_zoom == old_zoom:
		return
	# 保持鼠标位置对应的世界坐标不变
	var world_pos_before = screen_pos / old_zoom + position - get_viewport_rect().size * 0.5 / old_zoom
	zoom = new_zoom
	var world_pos_after = screen_pos / new_zoom + position - get_viewport_rect().size * 0.5 / new_zoom
	position += world_pos_before - world_pos_after
	_clamp_to_bounds()

## 限制相机不移出地图边界
func _clamp_to_bounds() -> void:
	if _map_bounds.size == Vector2.ZERO:
		return
	var safe_viewport := _get_safe_viewport()
	var half = safe_viewport.size * 0.5 / zoom
	# Camera2D is centered on the physical viewport, while the battlefield belongs
	# in the shifted safe viewport. Clamp the safe viewport's world-space center.
	var safe_center = position - _get_safe_viewport_offset()
	var min_x = _map_bounds.position.x + half.x
	var max_x = _map_bounds.position.x + _map_bounds.size.x - half.x
	var min_y = _map_bounds.position.y + half.y
	var max_y = _map_bounds.position.y + _map_bounds.size.y - half.y
	# 如果地图比安全视口小，居中显示
	if max_x < min_x:
		safe_center.x = _map_bounds.get_center().x
	else:
		safe_center.x = clampf(safe_center.x, min_x, max_x)
	if max_y < min_y:
		safe_center.y = _map_bounds.get_center().y
	else:
		safe_center.y = clampf(safe_center.y, min_y, max_y)
	position = safe_center + _get_safe_viewport_offset()


func _get_safe_viewport() -> Rect2:
	if _safe_viewport.size.x > 0.0 and _safe_viewport.size.y > 0.0:
		return _safe_viewport
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


func _get_safe_viewport_offset() -> Vector2:
	var viewport_center := get_viewport_rect().size * 0.5
	return (viewport_center - _get_safe_viewport().get_center()) / zoom
