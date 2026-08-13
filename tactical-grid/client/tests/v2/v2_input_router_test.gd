extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2BattleInputRouter = preload("res://scripts/v2/input/v2_battle_input_router.gd")
const V2BattleControllerPath := "res://scripts/v2/runtime/v2_battle_controller.gd"
const SharedBattleControllerPath := "res://scripts/game/battle_controller.gd"

var t := Runner.new()
var _left_cells: Array[Vector2i] = []
var _cancelled := 0
var _ended := 0
var _next_unit := 0
var _focused := 0
var _network_requested := 0
var _pointer_cancelled := 0
var _inspect_cancelled := 0
var _pan_delta := Vector2.ZERO

func _initialize() -> void:
	_assert_v2_input_entry_wiring()

	var router: V2BattleInputRouter = V2BattleInputRouter.new()
	router.cell_left_clicked.connect(_on_left_cell)
	router.cancel_requested.connect(_on_cancel)
	router.end_turn_requested.connect(_on_end_turn)
	router.next_unit_requested.connect(_on_next_unit)
	router.focus_requested.connect(_on_focus)
	router.network_overlay_requested.connect(_on_network)
	router.pointer_cancel_requested.connect(_on_pointer_cancel)
	router.camera_pan_requested.connect(_on_pan)
	if router.has_signal("camera_inspect_cancel_requested"):
		router.connect("camera_inspect_cancel_requested", _on_inspect_cancel)

	t.check(router.get_state_name() == "free_select", "初始为自由选择")
	t.check(_handle_event_argument_count(router) == 3, "handle_event 提供可选 pointer_context 参数")
	t.check(router.has_signal("camera_inspect_cancel_requested"), "输入路由器暴露镜头查看取消信号")
	t.check(bool(router.set_state(V2BattleInputRouter.State.UNIT_SELECTED).get("success", false)), "自由选择进入单位选择")
	t.check(bool(router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).get("success", false)), "单位选择进入攻击锁定")

	var map_context := func(_screen: Vector2): return {"drag_allowed": true, "over_map": true, "over_hud": false}
	var target_context := func(_screen: Vector2): return {"drag_allowed": false, "over_map": true, "over_hud": false}
	var hud_context := func(_screen: Vector2): return {"drag_allowed": true, "over_map": false, "over_hud": true}
	var to_cell := func(_screen: Vector2): return Vector2i(2, 3)

	var right_down := _mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(160, 96))
	var right_up := _mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(160, 96))
	t.check(_route(router, right_down, Callable(), map_context), "右键按下开始短按候选")
	t.check(router.get_state_name() == "attack_locked", "右键按下尚不提前取消攻击锁定")
	t.check(_route(router, right_up, Callable(), map_context), "右键短按释放被路由器消费")
	t.check(router.get_state_name() == "unit_selected", "右键短按释放取消攻击锁定")

	var left_down := _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(160, 96))
	var left_up := _mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(164, 96))
	t.check(_route(router, left_down, to_cell, target_context), "左键按下开始点击候选")
	t.check(_left_cells.is_empty(), "左键按下尚不提交格子点击")
	t.check(_route(router, left_up, to_cell, target_context), "阈值内左键释放被消费")
	t.check(_left_cells == [Vector2i(2, 3)], "左键发出确定格子")

	var left_drag_pan_before := _pan_delta
	var left_drag_clicks_before := _left_cells.size()
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(200, 120)), to_cell, map_context)
	t.check(router.is_camera_panning(), "空地左键按下进入镜头平移候选")
	_route(router, _mouse_motion(Vector2(220, 120)), to_cell, map_context)
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(220, 120)), to_cell, map_context)
	t.check(_pan_delta != left_drag_pan_before and _left_cells.size() == left_drag_clicks_before, "空地左键拖动平移且不提交格子点击")
	t.check(not router.is_camera_panning(), "空地左键释放结束镜头平移")

	var right_drag_pan_before := _pan_delta
	var right_drag_cancel_before := _pointer_cancelled
	var right_drag_inspect_before := _inspect_cancelled
	_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(240, 120)), Callable(), map_context)
	_route(router, _mouse_motion(Vector2(260, 140)), Callable(), map_context)
	_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(260, 140)), Callable(), map_context)
	t.check(_pan_delta != right_drag_pan_before and _pointer_cancelled == right_drag_cancel_before and _inspect_cancelled == right_drag_inspect_before, "右键拖动平移且不发出取消")

	var short_cancel_before := _pointer_cancelled
	var short_inspect_before := _inspect_cancelled
	_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(240, 120)), Callable(), map_context)
	_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(244, 120)), Callable(), map_context)
	t.check(_pointer_cancelled == short_cancel_before + 1 and _inspect_cancelled == short_inspect_before + 1, "短右键释放仍发出战术与镜头查看取消")

	var threshold_clicks_before := _left_cells.size()
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(280, 120)), to_cell, map_context)
	_route(router, _mouse_motion(Vector2(288, 120)), to_cell, map_context)
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(288, 120)), to_cell, map_context)
	t.check(_left_cells.size() == threshold_clicks_before, "累计移动恰好 8 像素不再视为点击")

	var cumulative_clicks_before := _left_cells.size()
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(300, 160)), to_cell, map_context)
	_route(router, _mouse_motion(Vector2(306, 160)), to_cell, map_context)
	_route(router, _mouse_motion(Vector2(302, 160)), to_cell, map_context)
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(302, 160)), to_cell, map_context)
	t.check(_left_cells.size() == cumulative_clicks_before, "折返累计移动超过阈值时不误判为点击")

	var blocked_pan_before := _pan_delta
	var blocked_clicks_before := _left_cells.size()
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(300, 120)), to_cell, target_context)
	_route(router, _mouse_motion(Vector2(320, 120)), to_cell, target_context)
	_route(router, _mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(320, 120)), to_cell, target_context)
	t.check(_pan_delta == blocked_pan_before and _left_cells.size() == blocked_clicks_before and not router.is_camera_panning(), "drag_allowed 为 false 时不启动平移且拖动不误点")

	var hud_pan_before := _pan_delta
	t.check(not _route(router, _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(1120, 120)), to_cell, hud_context), "HUD 上的左键按下不启动地图手势")
	t.check(_pan_delta == hud_pan_before and not router.is_camera_panning(), "HUD 起点不会启动镜头平移")
	var hud_middle_down := _mouse_button(MOUSE_BUTTON_MIDDLE, true, Vector2(1120, 120))
	var hud_middle_up := _mouse_button(MOUSE_BUTTON_MIDDLE, false, Vector2(1120, 120))
	t.check(not _route(router, hud_middle_down, Callable(), hud_context), "HUD 上的中键按下不启动地图拖拽")
	_route(router, hud_middle_up, Callable(), hud_context)

	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	t.check(router.handle_event(space, Callable()), "Space 被消费")
	t.check(_ended == 1, "Space 请求结束回合")

	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	t.check(router.handle_event(tab, Callable()), "Tab 被消费")
	t.check(_next_unit == 1, "Tab 请求下一个单位")

	var home := InputEventKey.new()
	home.keycode = KEY_HOME
	home.physical_keycode = KEY_HOME
	home.pressed = true
	t.check(router.handle_event(home, Callable()), "Home 被消费")
	t.check(_focused == 1, "Home 请求聚焦")

	var g_key := InputEventKey.new()
	g_key.keycode = KEY_G
	g_key.physical_keycode = KEY_G
	g_key.pressed = true
	t.check(router.handle_event(g_key, Callable()), "G 被消费")
	t.check(_network_requested == 1, "G 请求网络覆盖")

	t.check(bool(router.set_state(V2BattleInputRouter.State.ENEMY_TURN).get("success", false)), "进入敌方回合")
	t.check(not bool(router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).get("success", true)), "敌方回合拒绝玩家预览")
	t.check(_route(router, _mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(160, 96)), func(_screen: Vector2): return Vector2i(4, 4), target_context), "敌方回合消费左键避免穿透")
	t.check(_left_cells.size() == 1, "敌方回合不发出玩家格子点击")
	t.check(router.handle_event(space, Callable()), "敌方回合消费结束键")
	t.check(_ended == 1, "敌方回合不重复请求结束")

	t.check(bool(router.set_state(V2BattleInputRouter.State.PAUSED).get("success", false)), "可进入暂停")
	t.check(not bool(router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).get("success", true)), "暂停拒绝战斗预览")
	_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(160, 96)), Callable(), map_context)
	t.check(_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(160, 96)), Callable(), map_context), "暂停消费右键")
	t.check(_cancelled == 0, "暂停不伪造取消信号")

	t.check(bool(router.set_state(V2BattleInputRouter.State.UNIT_SELECTED).get("success", false)), "暂停恢复单位选择")
	_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(160, 96)), Callable(), map_context)
	t.check(_route(router, _mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(160, 96)), Callable(), map_context), "单位选择右键被消费")
	t.check(router.get_state_name() == "unit_selected", "单位选择右键只取消当前预览并保留选择")
	router.free()
	t.finish(self)

func _on_left_cell(cell: Vector2i) -> void:
	_left_cells.append(cell)

func _on_cancel() -> void:
	_cancelled += 1

func _on_end_turn() -> void:
	_ended += 1

func _on_next_unit() -> void:
	_next_unit += 1

func _on_focus() -> void:
	_focused += 1

func _on_network() -> void:
	_network_requested += 1

func _on_pointer_cancel() -> void:
	_pointer_cancelled += 1

func _on_inspect_cancel() -> void:
	_inspect_cancelled += 1

func _on_pan(delta: Vector2) -> void:
	_pan_delta += delta

func _assert_v2_input_entry_wiring() -> void:
	var v2_source := FileAccess.get_file_as_string(V2BattleControllerPath)
	var shared_source := FileAccess.get_file_as_string(SharedBattleControllerPath)
	var v2_input_body := _function_body(v2_source, "_input")
	var v2_route_body := _function_body(v2_source, "_route_v2_input")
	var pointer_context_body := _function_body(v2_source, "_v2_pointer_context")
	var shared_unhandled_body := _function_body(shared_source, "_unhandled_input")
	t.check(v2_input_body.contains("_route_v2_input(event)"), "V2 _input 在 HUD 与 unhandled 之前进入专属输入路由")
	t.check(v2_route_body.contains("handle_event(event, _screen_to_cell, _v2_pointer_context)"), "V2 专属入口向路由器传入真实第三个 pointer_context 参数")
	t.check(pointer_context_body.contains("_screen_to_cell(screen_position)") and pointer_context_body.contains("over_map") and pointer_context_body.contains("over_hud") and pointer_context_body.contains("drag_allowed"), "V2 pointer context 同时判定地图、HUD 和可拖动起点")
	t.check(v2_route_body.contains("not _is_v2_battle()"), "V2 专属入口以 V1 guard 拒绝非 V2 战斗")
	t.check(shared_unhandled_body.contains("if _is_v2_battle():") and shared_unhandled_body.contains("handle_event(event, _screen_to_cell, _v2_pointer_context)") and shared_unhandled_body.contains("set_input_as_handled()"), "共享 unhandled 路径只在 V2 guard 内使用三参数并标记已处理")

func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + 1)
	if end < 0:
		return source.substr(start)
	return source.substr(start, end - start)

func _route(router: V2BattleInputRouter, event: InputEvent, screen_to_cell: Callable, pointer_context: Callable) -> bool:
	if _handle_event_argument_count(router) >= 3:
		return bool(router.callv("handle_event", [event, screen_to_cell, pointer_context]))
	return router.handle_event(event, screen_to_cell)

func _handle_event_argument_count(router: V2BattleInputRouter) -> int:
	for method in router.get_method_list():
		if String(method.get("name", "")) == "handle_event":
			var arguments: Array = method.get("args", [])
			return arguments.size()
	return 0

func _mouse_button(button: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	return event

func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event
