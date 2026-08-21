extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2UnitTurnState = preload("res://scripts/v2/combat/v2_unit_turn_state.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const TurnManagerScript = preload("res://scripts/game/turn_manager.gd")

var t := Runner.new()

func _initialize() -> void:
	var state = V2UnitTurnState.new()
	state.begin_turn()
	t.check(state.can_act(), "新回合可以行动")
	t.check(state.spend_action(), "可先行动")
	t.check(state.spend_move(), "行动后仍可移动")
	t.check(not state.spend_action(), "不能第二次行动")
	t.check(not state.spend_move(), "不能第二次移动")
	state.set_cooldown(&"scan", 2)
	state.begin_turn()
	t.check(state.get_cooldown(&"scan") == 1, "下一回合冷却剩余一")
	state.begin_turn()
	t.check(state.get_cooldown(&"scan") == 0, "第三个玩家回合恢复")

	var snapshot: Dictionary = state.serialize()
	var restored: Variant = V2UnitTurnState.deserialize(snapshot)
	t.check(restored.serialize() == snapshot, "行动状态可序列化恢复")

	var unit = UnitScript.new()
	unit.setup({"name": "V2 Assault", "max_ap": 2, "move_points": 5})
	unit.enable_v2_turn_mode()
	t.check(unit.can_act() and unit.can_move(), "Unit 启用 V2 状态后可行动和移动")
	var unit_state: Variant = unit.v2_turn_state
	unit_state.spend_action()
	t.check(not unit.can_act() and unit.can_move(), "Unit 行动预算与移动预算独立")
	unit.queue_free()

	var player = UnitScript.new()
	player.enable_v2_turn_mode()
	var enemy = UnitScript.new()
	enemy.team = "enemy"
	enemy.enable_v2_turn_mode()
	var turn_manager = TurnManagerScript.new()
	turn_manager.setup([player], [enemy], 3)
	turn_manager.start_battle()
	t.check(turn_manager.current_phase == TurnManagerScript.TurnPhase.PLAYER_ACTION, "TurnManager 进入玩家行动阶段")
	t.check(player.can_move() and player.can_act(), "玩家回合开始刷新 V2 预算")
	turn_manager.queue_free()
	player.queue_free()
	enemy.queue_free()
	t.finish(self)
