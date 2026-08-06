extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CheckpointAdapter = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var adapter := V2CheckpointAdapter.new()
	var player := _unit("player_assault", "player", Vector2i(2, 3), 5)
	var enemy := _unit("enemy_sentry", "enemy", Vector2i(7, 3), 3)
	var schema_3: Dictionary = V2CheckpointAdapter.capture({
		"game_line": "v2_infiltration",
		"level_id": "ch1_m1",
		"encounter_id": "cp_rescue",
		"checkpoint_id": "cp_rescue",
		"turn": 4,
		"player_units": [player],
		"enemy_units": [enemy],
		"alert_state": {"level": 2},
		"visibility_state": {"revealed_cells": [Vector2i(2, 3)]},
		"facilities": [],
		"mission_flow": {"phase": "escort_to_evac"},
		"enemy_intents": {},
		"turn_state": {"phase": "player"},
		"extra": {},
	})
	t.check(bool(V2CheckpointAdapter.validate(schema_3).get("valid", false)), "schema 3 检查点夹具通过现有校验并含有效哈希")

	t.check(adapter.has_method("migrate_schema_3_to_4"), "检查点适配器公开 schema 3 到 4 的迁移契约")
	if not adapter.has_method("migrate_schema_3_to_4"):
		player.free()
		enemy.free()
		t.finish(self)
		return

	var migrated: Dictionary = adapter.call("migrate_schema_3_to_4", schema_3)
	t.check(int(migrated.get("schema_version", 0)) == 4, "schema 3 检查点迁移到 schema 4")
	t.check(migrated.get("player_units", []) == schema_3.get("player_units", []), "迁移保留玩家状态")
	t.check(migrated.get("enemy_units", []) == schema_3.get("enemy_units", []), "迁移保留敌人状态")
	t.check(
		(migrated.get("mission_flow", {}) as Dictionary).get("phase", "") == "escort_to_evac",
		"迁移保留旧版任务阶段"
	)
	player.free()
	enemy.free()
	t.finish(self)

func _unit(entity_id: String, team: String, grid_pos: Vector2i, current_hp: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.team = team
	unit.grid_pos = grid_pos
	unit.max_hp = current_hp
	unit.current_hp = current_hp
	unit.is_alive = true
	return unit
