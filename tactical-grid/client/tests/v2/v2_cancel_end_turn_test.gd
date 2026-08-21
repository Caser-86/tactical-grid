extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const TurnManagerScript = preload("res://scripts/game/turn_manager.gd")
const RouterScript = preload("res://scripts/v2/input/v2_battle_input_router.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var battle_script: Script = ResourceLoader.load("res://scripts/game/battle_controller.gd") as Script
	t.check(battle_script != null, "BattleController 取消和结束接口可加载")
	if battle_script == null:
		t.finish(self)
		return

	var battle: Node = battle_script.new()
	var unit: Unit = _make_unit("player_assault")
	var router: V2BattleInputRouter = RouterScript.new()
	root.add_child(router)
	battle.set("selected_unit", unit)
	battle.set("v2_input_router", router)

	for state in [V2BattleInputRouter.State.ATTACK_LOCKED, V2BattleInputRouter.State.ABILITY_TARGETING, V2BattleInputRouter.State.INTERACTION_MENU]:
		router.set_state(V2BattleInputRouter.State.UNIT_SELECTED)
		router.set_state(state)
		var cancelled: Dictionary = battle.call("cancel_current_preview")
		t.check(bool(cancelled.get("success", false)), "可取消 %s" % battle.v2_input_router.get_state_name())
		t.check(router.get_state_name() == "unit_selected" and battle.get("selected_unit") == unit, "取消回到单位选择并保留队员")

	var turn_manager: TurnManager = TurnManagerScript.new()
	root.add_child(turn_manager)
	turn_manager.setup([unit], [], 5)
	turn_manager.current_phase = TurnManager.TurnPhase.PLAYER_ACTION
	battle.set("turn_manager", turn_manager)
	router.set_state(V2BattleInputRouter.State.UNIT_SELECTED)
	router.end_turn_requested.connect(Callable(battle, "request_end_turn"))
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	t.check(router.handle_event(space, Callable()), "Space 输入被结束回合接口消费")
	t.check(turn_manager.current_phase == TurnManager.TurnPhase.ENEMY_ACTION, "Space 进入敌方回合")
	var duplicate_end: Dictionary = battle.call("request_end_turn")
	t.check(not bool(duplicate_end.get("success", true)) and duplicate_end.get("reason", &"") == &"not_player_phase", "敌方回合拒绝重复结束")
	turn_manager.end_enemy_turn()
	t.check(turn_manager.current_phase == TurnManager.TurnPhase.PLAYER_ACTION, "敌方阶段结束后恢复玩家回合")

	battle.free()
	router.free()
	turn_manager.free()
	unit.free()
	t.finish(self)

func _make_unit(id: String) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = "player"
	unit.grid_pos = Vector2i(1, 1)
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
