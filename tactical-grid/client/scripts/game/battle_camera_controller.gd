## 战斗相机控制器
## 管理平移、缩放、边界约束、选中单位跟随和目标定位
extends Camera2D
class_name BattleCameraController

## 相机缩放范围
const MIN_ZOOM := 0.65
const MAX_ZOOM := 1.5
## 平移速度（像素/秒）
const PAN_SPEED := 600.0
## 缩放步长
const ZOOM_STEP := 1.1
## 平滑跟随插值系数
const FOLLOW_LERP := 8.0

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

func _ready() -> void:
	enabled = true

func _process(delta: float) -> void:
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

	# 键盘平移
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W, KEY_UP: _keyboard_pan.y = -1.0
			KEY_S, KEY_DOWN: _keyboard_pan.y = 1.0
			KEY_A, KEY_LEFT: _keyboard_pan.x = -1.0
			KEY_D, KEY_RIGHT: _keyboard_pan.x = 1.0
	elif event is InputEventKey and not event.pressed:
		match event.keycode:
			KEY_W, KEY_UP, KEY_S, KEY_DOWN: _keyboard_pan.y = 0.0
			KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT: _keyboard_pan.x = 0.0

## 设置地图边界和安全视口
func setup(map_bounds: Rect2, safe_viewport: Rect2) -> void:
	_map_bounds = map_bounds
	_safe_viewport = safe_viewport
	# 初始定位到地图中心
	position = map_bounds.get_center()
	_clamp_to_bounds()

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
	var viewport_size = get_viewport_rect().size / zoom
	var half = viewport_size * 0.5
	var min_x = _map_bounds.position.x + half.x
	var max_x = _map_bounds.position.x + _map_bounds.size.x - half.x
	var min_y = _map_bounds.position.y + half.y
	var max_y = _map_bounds.position.y + _map_bounds.size.y - half.y
	# 如果地图比视口小，居中显示
	if max_x < min_x:
		position.x = _map_bounds.get_center().x
	else:
		position.x = clampf(position.x, min_x, max_x)
	if max_y < min_y:
		position.y = _map_bounds.get_center().y
	else:
		position.y = clampf(position.y, min_y, max_y)
