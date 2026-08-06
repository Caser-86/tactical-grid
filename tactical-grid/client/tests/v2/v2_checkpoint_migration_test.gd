extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CheckpointAdapter = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")

var t := Runner.new()

func _initialize() -> void:
	var adapter := V2CheckpointAdapter.new()
	var schema_3 := {
		"schema_version": 3,
		"player_units": [{"entity_id": "player_assault", "current_hp": 5}],
		"enemy_units": [{"entity_id": "enemy_sentry", "current_hp": 3}],
		"mission_flow": {"phase": "escort_to_evac"},
	}

	t.check(adapter.has_method("migrate_schema_3_to_4"), "检查点适配器公开 schema 3 到 4 的迁移契约")
	if not adapter.has_method("migrate_schema_3_to_4"):
		t.finish(self)
		return

	var migrated: Dictionary = adapter.call("migrate_schema_3_to_4", schema_3)
	t.check(int(migrated.get("schema_version", 0)) == 4, "schema 3 检查点迁移到 schema 4")
	t.check(migrated.get("player_units", []) == schema_3.player_units, "迁移保留玩家状态")
	t.check(migrated.get("enemy_units", []) == schema_3.enemy_units, "迁移保留敌人状态")
	t.check(
		(migrated.get("mission_flow", {}) as Dictionary).get("phase", "") == "escort_to_evac",
		"迁移保留旧版任务阶段"
	)
	t.finish(self)
