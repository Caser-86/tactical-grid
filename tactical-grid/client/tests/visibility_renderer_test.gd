## CH1-040: VisibilityRenderer 渲染状态映射测试
## 验证渲染器根据 VisibilityState 返回正确的三态渲染状态，
## 以及摄像头区域格子集合同步与刷新行为。
extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CH1-040: VisibilityRenderer tests ===")
	_test_renderer_setup_default_hidden()
	_test_renderer_maps_observed_to_visible()
	_test_renderer_maps_recorded_to_dimmed()
	_test_renderer_refresh_after_state_change()
	_test_camera_cells_tint()
	_test_renderer_without_state_returns_hidden()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

## 构建一个挂载到场景树的 VisibilityRenderer + VisibilityState 组合。
## 返回 {renderer, state, parent} 三元组；调用方负责 queue_free parent。
func _build_renderer(map_width: int, map_height: int) -> Dictionary:
	var parent := Node2D.new()
	add_child(parent)
	var state := VisibilityState.new()
	parent.add_child(state)
	state.setup(map_width, map_height)
	var renderer := VisibilityRenderer.new()
	parent.add_child(renderer)
	renderer.setup(state, map_width, map_height, 64.0)
	return {"parent": parent, "renderer": renderer, "state": state}

func _test_renderer_setup_default_hidden() -> void:
	print("\n--- Test: unexplored cells render as hidden after setup ---")
	var fixture := _build_renderer(6, 6)
	var renderer: VisibilityRenderer = fixture.renderer
	var state: VisibilityState = fixture.state
	# All cells unexplored by default
	_check(renderer.get_render_state_for_cell(Vector2i(0, 0)) == VisibilityState.RENDER_HIDDEN, "Top-left unexplored cell is hidden")
	_check(renderer.get_render_state_for_cell(Vector2i(5, 5)) == VisibilityState.RENDER_HIDDEN, "Bottom-right unexplored cell is hidden")
	_check(state.get_render_state(Vector2i(3, 3)) == VisibilityState.RENDER_HIDDEN, "State reports hidden for unexplored cell")
	fixture.parent.queue_free()

func _test_renderer_maps_observed_to_visible() -> void:
	print("\n--- Test: observed cells map to RENDER_VISIBLE ---")
	var fixture := _build_renderer(6, 6)
	var renderer: VisibilityRenderer = fixture.renderer
	var state: VisibilityState = fixture.state
	state.set_turn(1)
	state.update_visibility([Vector2i(2, 2), Vector2i(3, 3)], [])
	renderer.refresh()
	_check(renderer.get_render_state_for_cell(Vector2i(2, 2)) == VisibilityState.RENDER_VISIBLE, "Observed cell (2,2) renders visible")
	_check(renderer.get_render_state_for_cell(Vector2i(3, 3)) == VisibilityState.RENDER_VISIBLE, "Observed cell (3,3) renders visible")
	fixture.parent.queue_free()

func _test_renderer_maps_recorded_to_dimmed() -> void:
	print("\n--- Test: recorded cells map to RENDER_DIMMED ---")
	var fixture := _build_renderer(6, 6)
	var renderer: VisibilityRenderer = fixture.renderer
	var state: VisibilityState = fixture.state
	state.set_turn(1)
	state.update_visibility([Vector2i(1, 1)], [])
	# Move sight away so (1,1) demotes to recorded
	state.set_turn(2)
	state.update_visibility([Vector2i(5, 5)], [])
	renderer.refresh()
	_check(renderer.get_render_state_for_cell(Vector2i(1, 1)) == VisibilityState.RENDER_DIMMED, "Previously observed cell renders dimmed")
	_check(renderer.get_render_state_for_cell(Vector2i(5, 5)) == VisibilityState.RENDER_VISIBLE, "Currently observed cell renders visible")
	_check(renderer.get_render_state_for_cell(Vector2i(0, 0)) == VisibilityState.RENDER_HIDDEN, "Never-explored cell renders hidden")
	fixture.parent.queue_free()

func _test_renderer_refresh_after_state_change() -> void:
	print("\n--- Test: renderer refresh picks up state changes ---")
	var fixture := _build_renderer(6, 6)
	var renderer: VisibilityRenderer = fixture.renderer
	var state: VisibilityState = fixture.state
	# Initially hidden
	_check(renderer.get_render_state_for_cell(Vector2i(4, 4)) == VisibilityState.RENDER_HIDDEN, "Cell (4,4) hidden before any sight")
	# Reveal and refresh
	state.set_turn(1)
	state.update_visibility([Vector2i(4, 4)], [])
	renderer.refresh()
	_check(renderer.get_render_state_for_cell(Vector2i(4, 4)) == VisibilityState.RENDER_VISIBLE, "Cell (4,4) visible after refresh")
	fixture.parent.queue_free()

func _test_camera_cells_tint() -> void:
	print("\n--- Test: camera cells synced to renderer for tinting ---")
	var fixture := _build_renderer(6, 6)
	var renderer: VisibilityRenderer = fixture.renderer
	var state: VisibilityState = fixture.state
	state.set_turn(1)
	state.update_visibility([Vector2i(1, 1)], [])
	state.add_camera_zone("cam_test", [Vector2i(2, 2), Vector2i(3, 3)])
	_check(state.get_cell_state(Vector2i(2, 2)) == VisibilityState.STATE_OBSERVED, "Camera cell (2,2) observed in state")
	_check(state.get_cell_state(Vector2i(3, 3)) == VisibilityState.STATE_OBSERVED, "Camera cell (3,3) observed in state")
	renderer.set_camera_cells([Vector2i(2, 2), Vector2i(3, 3)])
	renderer.refresh()
	_check(renderer.get_render_state_for_cell(Vector2i(2, 2)) == VisibilityState.RENDER_VISIBLE, "Camera cell renders visible")
	# Remove camera zone; cells revert to recorded on next update
	state.remove_camera_zone("cam_test")
	state.set_turn(2)
	state.update_visibility([Vector2i(0, 0)], [])
	renderer.set_camera_cells([])
	renderer.refresh()
	_check(renderer.get_render_state_for_cell(Vector2i(2, 2)) == VisibilityState.RENDER_DIMMED, "Camera cell dims after zone removal")
	fixture.parent.queue_free()

func _test_renderer_without_state_returns_hidden() -> void:
	print("\n--- Test: renderer without state returns hidden ---")
	var parent := Node2D.new()
	add_child(parent)
	var renderer := VisibilityRenderer.new()
	parent.add_child(renderer)
	# Don't call setup; renderer should gracefully report hidden
	_check(renderer.get_render_state_for_cell(Vector2i(0, 0)) == VisibilityState.RENDER_HIDDEN, "Renderer without state returns hidden")
	parent.queue_free()

func _print_summary() -> void:
	print("\n=== VisibilityRenderer: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
