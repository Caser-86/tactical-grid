## 回合管理器
## 控制回合流程状态机，管理输入锁和胜负检查
extends Node
class_name TurnManager

signal turn_phase_changed(phase: TurnPhase)
signal player_turn_started()
signal enemy_turn_started()
signal turn_ended(turn_number: int)
signal input_locked_changed(locked: bool)
signal battle_won(result: Dictionary)
signal battle_lost(result: Dictionary)

enum TurnPhase {
	PLAYER_START,
	PLAYER_ACTION,
	PLAYER_END,
	ENEMY_START,
	ENEMY_ACTION,
	ENEMY_END,
	CHECK_VICTORY,
	BATTLE_OVER,
}

var current_phase: TurnPhase = TurnPhase.PLAYER_START
var turn_number: int = 0
var max_turns: int = 20

var input_locked: bool = false:
	set(v):
		input_locked = v
		input_locked_changed.emit(v)

var battle_over: bool = false

## 由 BattleController 设置
var _player_units: Array = []
var _enemy_units: Array = []
var _check_victory_fn: Callable
var _check_defeat_fn: Callable

func setup(player_units: Array, enemy_units: Array, max_t: int = 20) -> void:
	_player_units = player_units
	_enemy_units = enemy_units
	max_turns = max_t
	turn_number = 0
	battle_over = false
	current_phase = TurnPhase.PLAYER_START

func start_battle() -> void:
	turn_number = 1
	set_phase(TurnPhase.PLAYER_START)

func set_phase(phase: TurnPhase) -> void:
	if battle_over:
		return
	current_phase = phase
	turn_phase_changed.emit(phase)

	match phase:
		TurnPhase.PLAYER_START:
			player_turn_started.emit()
			_refresh_units(_player_units)
			set_phase(TurnPhase.PLAYER_ACTION)

		TurnPhase.PLAYER_END:
			set_phase(TurnPhase.ENEMY_START)

		TurnPhase.ENEMY_START:
			enemy_turn_started.emit()
			_refresh_units(_enemy_units)
			set_phase(TurnPhase.ENEMY_ACTION)

		TurnPhase.ENEMY_END:
			set_phase(TurnPhase.CHECK_VICTORY)

		TurnPhase.CHECK_VICTORY:
			turn_ended.emit(turn_number)
			if _check_defeat_fn.is_valid() and _check_defeat_fn.call():
				_end_battle(false, "all_units_down")
				return
			if _check_victory_fn.is_valid() and _check_victory_fn.call():
				_end_battle(true)
				return
			if turn_number >= max_turns:
				_end_battle(false, "turn_limit")
				return
			turn_number += 1
			set_phase(TurnPhase.PLAYER_START)

func end_player_turn() -> void:
	if current_phase == TurnPhase.PLAYER_ACTION:
		set_phase(TurnPhase.PLAYER_END)

func end_enemy_turn() -> void:
	if current_phase == TurnPhase.ENEMY_ACTION:
		set_phase(TurnPhase.ENEMY_END)

func _refresh_units(units: Array) -> void:
	for unit in units:
		if unit == null or not unit.is_alive:
			continue
		unit.refresh_ap()
		unit.on_turn_start()
		if unit.v2_turn_mode_enabled:
			unit.begin_v2_turn()

func _end_battle(victory: bool, reason: String = "") -> void:
	battle_over = true
	current_phase = TurnPhase.BATTLE_OVER
	turn_phase_changed.emit(current_phase)
	var result = {
		"victory": victory,
		"turns": turn_number,
		"reason": reason,
	}
	if victory:
		battle_won.emit(result)
	else:
		battle_lost.emit(result)

func set_victory_check(fn: Callable) -> void:
	_check_victory_fn = fn

func set_defeat_check(fn: Callable) -> void:
	_check_defeat_fn = fn
