extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CheckpointAdapter = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var player = _make_unit("player_assault", "assault", Vector2i(2, 2), 7)
	player.current_hp = 5
	player.enable_v2_turn_mode()
	player.v2_turn_state.spend_action()
	player.v2_turn_state.set_cooldown(&"area_scan", 2)
	var enemy = _make_unit("enemy_sentry", "sentry", Vector2i(5, 2), 4)
	var context := _make_context([player], [enemy])
	var snapshot: Dictionary = V2CheckpointAdapter.capture(context)
	t.check(int(snapshot.get("schema_version", 0)) == 3, "V2 检查点 schema 为 3")
	t.check(not bool(snapshot.player_units[0].turn_state.action_available), "保存行动状态")
	t.check(int(snapshot.player_units[0].turn_state.cooldowns.area_scan) == 2, "保存冷却")
	t.check(bool(V2CheckpointAdapter.validate(snapshot).get("valid", false)), "新检查点哈希和结构有效")

	var fresh_player = _make_unit("player_assault", "assault", Vector2i(0, 0), 7)
	var fresh_enemy = _make_unit("enemy_sentry", "sentry", Vector2i(1, 1), 4)
	var fresh_context := _make_context([fresh_player], [fresh_enemy])
	var restored: Dictionary = V2CheckpointAdapter.restore(snapshot, fresh_context)
	t.check(bool(restored.get("success", false)), "检查点恢复成功")
	t.check(fresh_player.grid_pos == Vector2i(2, 2) and fresh_player.current_hp == 5, "恢复单位位置和生命")
	t.check(not fresh_player.can_act() and fresh_player.v2_turn_state.get_cooldown(&"area_scan") == 2, "恢复行动状态和冷却")
	var round_trip: Dictionary = V2CheckpointAdapter.capture(fresh_context)
	t.check(round_trip.get("hash", "") == snapshot.get("hash", ""), "恢复后状态哈希一致")

	var stable := true
	for _i in range(10):
		var repeated: Dictionary = V2CheckpointAdapter.capture(fresh_context)
		if repeated.get("hash", "") != snapshot.get("hash", ""):
			stable = false
	t.check(stable, "十次 capture 哈希一致")

	var tampered: Dictionary = snapshot.duplicate(true)
	tampered.player_units[0].current_hp = 1
	t.check(not bool(V2CheckpointAdapter.validate(tampered).get("valid", true)), "篡改生命值被哈希校验拒绝")
	var hp_before: int = fresh_player.current_hp
	var rejected: Dictionary = V2CheckpointAdapter.restore(tampered, fresh_context)
	t.check(not bool(rejected.get("success", true)) and fresh_player.current_hp == hp_before, "失败恢复不修改当前上下文")

	var duplicate_ids: Dictionary = snapshot.duplicate(true)
	duplicate_ids.enemy_units[0].entity_id = "player_assault"
	t.check(not bool(V2CheckpointAdapter.validate(duplicate_ids).get("valid", true)), "重复实体 ID 被拒绝")
	var wrong_line: Dictionary = snapshot.duplicate(true)
	wrong_line.game_line = "v1_legacy"
	t.check(not bool(V2CheckpointAdapter.validate(wrong_line).get("valid", true)), "V1 游戏线检查点被拒绝")

	player.queue_free()
	enemy.queue_free()
	fresh_player.queue_free()
	fresh_enemy.queue_free()
	t.finish(self)

func _make_unit(id: String, role: String, position: Vector2i, hp: int):
	var unit = UnitScript.new()
	unit.entity_id = id
	unit.job = role
	unit.team = "enemy" if role == "sentry" else "player"
	unit.grid_pos = position
	unit.max_hp = hp
	unit.current_hp = hp
	unit.is_alive = true
	return unit

func _make_context(players: Array, enemies: Array) -> Dictionary:
	return {
		"game_line": "v2_infiltration",
		"level_id": "ch1_m1",
		"encounter_id": "enc_a",
		"turn": 2,
		"player_units": players,
		"enemy_units": enemies,
		"alert_state": {"level": 1},
		"visibility_state": {"observed_cells": [[2, 2]]},
		"facilities": [{"id": "door_a", "open": false}],
		"mission_flow": {"phase": "infiltrate"},
		"enemy_intents": {"enemy_sentry": {"type": "attack", "telegraph": true}},
		"turn_state": {"player_phase": true},
		"extra": {"seed": 1001},
	}
