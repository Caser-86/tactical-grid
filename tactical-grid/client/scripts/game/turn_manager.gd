## 回合管理器
## 控制回合流程状态机
extends Node
class_name TurnManager

signal turn_phase_changed(phase: TurnPhase)
signal player_turn_started()
signal enemy_turn_started()
signal turn_ended(turn_number: int)

enum TurnPhase {
	PLAYER_START,
	PLAYER_ACTION,
	PLAYER_END,
	ENEMY_START,
	ENEMY_ACTION,
	ENEMY_END,
	CHECK_VICTORY,
}

var current_phase: TurnPhase = TurnPhase.PLAYER_START
var turn_number: int = 0
var max_turns: int = 20  # 回合上限

func start_battle() -> void:
	turn_number = 0
	set_phase(TurnPhase.PLAYER_START)

func set_phase(phase: TurnPhase) -> void:
	current_phase = phase
	turn_phase_changed.emit(phase)

	match phase:
		TurnPhase.PLAYER_START:
			turn_number += 1
			player_turn_started.emit()
			# 刷新所有玩家单位 AP
			_refresh_player_units()
			set_phase(TurnPhase.PLAYER_ACTION)

		TurnPhase.PLAYER_END:
			set_phase(TurnPhase.ENEMY_START)

		TurnPhase.ENEMY_START:
			enemy_turn_started.emit()
			_refresh_enemy_units()
			set_phase(TurnPhase.ENEMY_ACTION)

		TurnPhase.ENEMY_END:
			set_phase(TurnPhase.CHECK_VICTORY)

		TurnPhase.CHECK_VICTORY:
			turn_ended.emit(turn_number)
			if turn_number >= max_turns:
				# 回合超时
				pass
			else:
				set_phase(TurnPhase.PLAYER_START)

func end_player_turn() -> void:
	if current_phase == TurnPhase.PLAYER_ACTION:
		set_phase(TurnPhase.PLAYER_END)

func end_enemy_turn() -> void:
	if current_phase == TurnPhase.ENEMY_ACTION:
		set_phase(TurnPhase.ENEMY_END)

func _refresh_player_units() -> void:
	var units = get_tree().get_nodes_in_group("player_units")
	for unit in units:
		if unit.has_method("refresh_ap"):
			unit.refresh_ap()

func _refresh_enemy_units() -> void:
	var units = get_tree().get_nodes_in_group("enemy_units")
	for unit in units:
		if unit.has_method("refresh_ap"):
			unit.refresh_ap()
