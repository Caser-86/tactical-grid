## CH1-040: 战争迷雾运行时渲染层
## 根据 VisibilityState 的每格状态绘制三态遮挡：
##   - 未探索 (RENDER_HIDDEN):  实黑遮挡，玩家完全看不到地形与单位
##   - 已记录 (RENDER_DIMMED):  半透明深色叠加，地形降饱和显示，不显示实时单位
##   - 正在观察 (RENDER_VISIBLE): 无叠加，地形、单位与设施全部实时显示
## 渲染器只负责视觉遮挡；目标和交互校验使用 VisibilityState 的真实状态，不读遮罩颜色。
extends Node2D
class_name VisibilityRenderer

## 未探索格的实黑叠加色
const COLOR_HIDDEN := Color(0.015, 0.022, 0.030, 0.97)
## 已记录格的降饱和叠加色（保留地形可见但明显变暗）
const COLOR_DIMMED := Color(0.04, 0.06, 0.10, 0.55)
## 摄像头区域微调色相，让玩家能识别"由摄像头维持的观察区"
const COLOR_CAMERA_TINT := Color(0.10, 0.32, 0.40, 0.18)

var _visibility_state: VisibilityState
var _cell_size: float = 64.0
var _map_width: int = 0
var _map_height: int = 0
## CH1-040: 摄像头区域格子集合（用于视觉提示），由 battle_controller 同步
var _camera_cells: Dictionary = {}

## 绑定 VisibilityState 和地图尺寸。cell_size 必须与 BattleController.CELL_SIZE 一致。
func setup(state: VisibilityState, map_width: int, map_height: int, cell_size: float) -> void:
	_visibility_state = state
	_map_width = map_width
	_map_height = map_height
	_cell_size = cell_size
	_camera_cells.clear()
	queue_redraw()


## CH1-040: 同步摄像头区域格子集合（用于渲染时给摄像头维持的观察区加微调色）
func set_camera_cells(cells: Array) -> void:
	_camera_cells.clear()
	for cell in cells:
		if cell is Vector2i:
			_camera_cells[cell] = true
	queue_redraw()


## CH1-040: 强制重绘（VisibilityState 更新后调用）
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _visibility_state == null:
		return
	if _map_width <= 0 or _map_height <= 0:
		return
	for y in range(_map_height):
		for x in range(_map_width):
			var cell := Vector2i(x, y)
			var render_state := _visibility_state.get_render_state(cell)
			var rect := Rect2(
				Vector2(x * _cell_size, y * _cell_size),
				Vector2(_cell_size, _cell_size)
			)
			match render_state:
				VisibilityState.RENDER_HIDDEN:
					draw_rect(rect, COLOR_HIDDEN, true)
				VisibilityState.RENDER_DIMMED:
					draw_rect(rect, COLOR_DIMMED, true)
					# 已记录格在边缘画一条暗线，帮助玩家区分"去过但看不到"与"正在看见"
					draw_rect(rect, Color(0.10, 0.16, 0.22, 0.35), false, 1.0)
				VisibilityState.RENDER_VISIBLE:
					# 正在观察区无遮挡；若由摄像头维持则加微调色提示
					if _camera_cells.has(cell):
						draw_rect(rect, COLOR_CAMERA_TINT, true)
				_:
					draw_rect(rect, COLOR_HIDDEN, true)


## CH1-040: 获取某格的渲染状态字符串（供测试断言）
func get_render_state_for_cell(cell: Vector2i) -> StringName:
	if _visibility_state == null:
		return VisibilityState.RENDER_HIDDEN
	return _visibility_state.get_render_state(cell)
