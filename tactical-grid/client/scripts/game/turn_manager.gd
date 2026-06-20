## 回合管理器
## 控制回合流程状态机
extends Node
class_name TurnManager

signal turn_phase_changed(phase: TurnPhase)
signal player_turn_started()
signal enemy_turn_started()
signal turn_ended(turn_number: int)
signal turn_limit_reached()

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
			current_phase = TurnPhase.ENEMY_ACTION
			turn_phase_changed.emit(current_phase)
			# 注意：不在此处递归切换到 ENEMY_ACTION
			# 等待 GameManager._on_turn_phase_changed 接收 ENEMY_START 信号后
			# 执行敌人回合再调用 end_enemy_turn() 切换到 ENEMY_END
			return

		TurnPhase.ENEMY_END:
			set_phase(TurnPhase.CHECK_VICTORY)

		TurnPhase.CHECK_VICTORY:
			turn_ended.emit(turn_number)
			if turn_number >= max_turns:
				turn_limit_reached.emit()
			else:
				set_phase(TurnPhase.PLAYER_START)

func end_player_turn() -> void:
	if current_phase == TurnPhase.PLAYER_ACTION:
		set_phase(TurnPhase.PLAYER_END)

func end_enemy_turn() -> void:
	if current_phase == TurnPhase.ENEMY_ACTION:
		set_phase(TurnPhase.ENEMY_END)

func _refresh_player_units() -> void:
	for unit in GameManager.player_units:
		if unit.has_method("refresh_ap"):
			unit.refresh_ap()
		if unit.has_method("reduce_skill_cooldowns"):
			unit.reduce_skill_cooldowns()

func _refresh_enemy_units() -> void:
	for unit in GameManager.enemy_units:
		if unit.has_method("refresh_ap"):
			unit.refresh_ap()
		if unit.has_method("reduce_skill_cooldowns"):
			unit.reduce_skill_cooldowns()
