extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2BattleInputRouter = preload("res://scripts/v2/input/v2_battle_input_router.gd")

var t := Runner.new()
var _left_cells: Array[Vector2i] = []
var _cancelled := 0
var _ended := 0
var _next_unit := 0
var _focused := 0
var _network_requested := 0

func _initialize() -> void:
	var router: V2BattleInputRouter = V2BattleInputRouter.new()
	router.cell_left_clicked.connect(_on_left_cell)
	router.cancel_requested.connect(_on_cancel)
	router.end_turn_requested.connect(_on_end_turn)
	router.next_unit_requested.connect(_on_next_unit)
	router.focus_requested.connect(_on_focus)
	router.network_overlay_requested.connect(_on_network)

	t.check(router.get_state_name() == "free_select", "初始为自由选择")
	t.check(bool(router.set_state(V2BattleInputRouter.State.UNIT_SELECTED).get("success", false)), "自由选择进入单位选择")
	t.check(bool(router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).get("success", false)), "单位选择进入攻击锁定")

	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	t.check(router.handle_event(right, Callable()), "右键被路由器消费")
	t.check(router.get_state_name() == "unit_selected", "右键取消攻击锁定")

	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	left.position = Vector2(160, 96)
	t.check(router.handle_event(left, func(_screen: Vector2): return Vector2i(2, 3)), "左键网格点击被消费")
	t.check(_left_cells == [Vector2i(2, 3)], "左键发出确定格子")

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
	t.check(router.handle_event(left, func(_screen: Vector2): return Vector2i(4, 4)), "敌方回合消费左键避免穿透")
	t.check(_left_cells.size() == 1, "敌方回合不发出玩家格子点击")
	t.check(router.handle_event(space, Callable()), "敌方回合消费结束键")
	t.check(_ended == 1, "敌方回合不重复请求结束")

	t.check(bool(router.set_state(V2BattleInputRouter.State.PAUSED).get("success", false)), "可进入暂停")
	t.check(not bool(router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).get("success", true)), "暂停拒绝战斗预览")
	t.check(router.handle_event(right, Callable()), "暂停消费右键")
	t.check(_cancelled == 0, "暂停不伪造取消信号")

	t.check(bool(router.set_state(V2BattleInputRouter.State.UNIT_SELECTED).get("success", false)), "暂停恢复单位选择")
	t.check(router.handle_event(right, Callable()), "单位选择右键返回自由选择")
	t.check(router.get_state_name() == "free_select", "单位选择右键取消选择")
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
