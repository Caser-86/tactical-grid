extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const RouterScript = preload("res://scripts/v2/input/v2_battle_input_router.gd")
const PresenterScript = preload("res://scripts/v2/presentation/v2_affordance_presenter.gd")
const V2ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var battle_script: Script = ResourceLoader.load("res://scripts/game/battle_controller.gd") as Script
	t.check(battle_script != null, "BattleController 攻击输入接口可加载")
	if battle_script == null:
		t.finish(self)
		return
	_set_v2_game_line()

	var first_battle := _make_battle(battle_script, [
		_make_unit("player_assault", "player", Vector2i(1, 1), 7),
	], [
		_make_unit("enemy_sentry_a", "enemy", Vector2i(3, 1), 7),
	])
	var attacker: Unit = first_battle.get("attacker")
	var target: Unit = first_battle.get("target")
	var battle: Node = first_battle.get("battle")
	var hud: HUD = first_battle.get("hud")

	battle.call("_on_v2_cell_hovered", target.grid_pos)
	t.check(hud.get_attack_preview_text().contains("7 → 4"), "悬停显示 HP 前后变化")
	battle.call("_on_v2_cell_left_clicked", target.grid_pos)
	t.check(target.current_hp == 4, "单击敌人立即提交攻击")
	t.check(not attacker.v2_turn_state.action_available, "攻击提交消费行动预算")
	t.check(battle.v2_locked_attack_preview.is_empty() and battle.v2_input_router.get_state_name() == "unit_selected", "单击攻击后清除锁定状态")
	var repeat: Dictionary = battle.call("request_attack_preview", target)
	t.check(not bool(repeat.get("valid", true)) and repeat.get("reason", &"") == &"action_unavailable", "已攻击单位不能再次攻击")

	var hover_battle_data := _make_battle(battle_script, [
		_make_unit("player_hover", "player", Vector2i(1, 1), 7),
	], [
		_make_unit("enemy_hover_a", "enemy", Vector2i(3, 1), 7),
		_make_unit("enemy_hover_b", "enemy", Vector2i(4, 1), 7),
	])
	var hover_battle: Node = hover_battle_data.get("battle")
	var hover_hud: HUD = hover_battle_data.get("hud")
	var hover_presenter: V2AffordancePresenter = hover_battle_data.get("presenter")
	var hover_a: Unit = hover_battle_data.get("target")
	var hover_b: Unit = hover_battle_data.get("target_b")
	_set_v2_game_line()
	hover_battle.call("_on_v2_cell_hovered", hover_a.grid_pos)
	t.check(hover_hud.get_attack_preview_text().contains("悬停预览") and hover_hud.get_attack_preview_text().contains("7 → 4"), "悬停显示临时攻击预览")
	t.check(_group_count(hover_presenter, "v2_attack_focus") == 1, "悬停显示临时目标焦点")
	hover_battle.call("_on_v2_cell_hovered", Vector2i(0, 0))
	t.check(hover_hud.get_attack_preview_text() == "", "离开目标清除临时攻击卡片")
	t.check(hover_a.current_hp == 7 and hover_b.current_hp == 7, "悬停和离开不造成伤害")

	var locked: Dictionary = hover_battle.call("request_attack_preview", hover_a)
	t.check(bool(locked.get("valid", false)), "第一次点击 A 锁定目标")
	hover_battle.call("_on_v2_cell_hovered", hover_b.grid_pos)
	t.check(hover_hud.get_attack_preview_text().contains("enemy_hover_b"), "锁定 A 时悬停 B 只显示 B 的临时预览")
	hover_battle.call("_on_v2_cell_hovered", Vector2i(0, 0))
	t.check(hover_hud.get_attack_preview_text().contains("enemy_hover_a") and hover_hud.get_attack_preview_text().contains("已锁定"), "离开 B 后恢复 A 的锁定卡片")
	var committed_a: Dictionary = hover_battle.call("confirm_locked_attack", hover_a)
	t.check(bool(committed_a.get("success", false)) and hover_a.current_hp == 4 and hover_b.current_hp == 7, "确认锁定 A 不会误伤 B")

	var stale_data := _make_battle(battle_script, [
		_make_unit("player_stale", "player", Vector2i(1, 1), 7),
	], [
		_make_unit("enemy_stale", "enemy", Vector2i(3, 1), 7),
	])
	var stale_battle: Node = stale_data.get("battle")
	var stale_attacker: Unit = stale_data.get("attacker")
	var stale_target: Unit = stale_data.get("target")
	var stale_preview: Dictionary = stale_battle.call("request_attack_preview", stale_target)
	stale_target.grid_pos = Vector2i(4, 4)
	var stale_result: Dictionary = stale_battle.call("confirm_locked_attack", stale_target)
	t.check(bool(stale_preview.get("valid", false)) and not bool(stale_result.get("success", true)), "目标移动后拒绝陈旧攻击预览")
	t.check(stale_result.get("reason", &"") == &"stale_preview" and stale_attacker.v2_turn_state.action_available, "陈旧攻击不消费行动")

	var cancel_data := _make_battle(battle_script, [
		_make_unit("player_cancel", "player", Vector2i(1, 1), 7),
	], [
		_make_unit("enemy_cancel", "enemy", Vector2i(3, 1), 7),
	])
	var cancel_battle: Node = cancel_data.get("battle")
	var cancel_target: Unit = cancel_data.get("target")
	cancel_battle.call("request_attack_preview", cancel_target)
	cancel_battle.v2_input_router.handle_event(_right_click(), Callable(func(_position: Vector2): return Vector2i.ZERO))
	t.check(cancel_battle.v2_input_router.get_state_name() == "unit_selected", "右键取消攻击锁定并保留单位选择")
	t.check(cancel_battle.v2_locked_attack_preview.is_empty() and cancel_target.current_hp == 7, "右键清除锁定且不造成伤害")

	_cleanup(first_battle)
	_cleanup(hover_battle_data)
	_cleanup(stale_data)
	_cleanup(cancel_data)
	t.finish(self)

func _make_battle(battle_script: Script, players: Array, enemies: Array) -> Dictionary:
	var battle: Node = battle_script.new()
	var hud: HUD = HUDScript.new()
	var router: V2BattleInputRouter = RouterScript.new()
	var presenter: V2AffordancePresenter = PresenterScript.new()
	root.add_child(router)
	root.add_child(presenter)
	var service := V2ActionService.new()
	service.setup(_make_map(), players, enemies)
	battle.set("v2_action_service", service)
	battle.set("v2_input_router", router)
	battle.set("v2_affordance_presenter", presenter)
	battle.set("hud", hud)
	battle.set("map_data", _make_map())
	battle.set("map_width", 8)
	battle.set("map_height", 8)
	battle.set("player_units", players)
	battle.set("enemy_units", enemies)
	battle.set("selected_unit", players[0])
	router.pointer_cancel_requested.connect(Callable(battle, "_on_v2_cancel_requested"))
	return {
		"battle": battle,
		"hud": hud,
		"router": router,
		"presenter": presenter,
		"attacker": players[0],
		"target": enemies[0],
		"target_b": enemies[1] if enemies.size() > 1 else null,
	}

func _make_unit(id: String, team: String, position: Vector2i, hp: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = team
	unit.job = "assault"
	unit.grid_pos = position
	unit.max_hp = hp
	unit.current_hp = hp
	unit.weapon_range = [1, 5]
	unit.weapon_damage = [3, 3]
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit

func _make_map() -> Dictionary:
	var terrain: Array = []
	var blockers: Array = []
	for _y in range(8):
		terrain.append([0, 0, 0, 0, 0, 0, 0, 0])
		blockers.append([0, 0, 0, 0, 0, 0, 0, 0])
	return {
		"size": {"width": 8, "height": 8},
		"layers": {"base_terrain": terrain, "blocker": blockers},
	}

func _group_count(node: Node, group_name: StringName) -> int:
	var count := 0
	for child in node.get_children():
		if child.is_in_group(group_name):
			count += 1
	return count

func _right_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event

func _set_v2_game_line() -> void:
	var manager := root.get_node_or_null("GameManager")
	if manager:
		manager.current_save["game_line"] = "v2_infiltration"

func _cleanup(data: Dictionary) -> void:
	var battle: Node = data.get("battle")
	var router: Node = data.get("router")
	var presenter: Node = data.get("presenter")
	var hud: Node = data.get("hud")
	if battle and is_instance_valid(battle):
		battle.free()
	if router and is_instance_valid(router):
		router.free()
	if presenter and is_instance_valid(presenter):
		presenter.free()
	if hud and is_instance_valid(hud):
		hud.free()
	for key in ["attacker", "target", "target_b"]:
		var unit: Unit = data.get(key)
		if unit and is_instance_valid(unit):
			unit.free()
	var players: Array = data.get("players", [])
	for unit in players:
		if unit and is_instance_valid(unit):
			unit.free()
