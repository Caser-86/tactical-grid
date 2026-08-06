extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CheckpointAdapter = preload("res://scripts/v2/mission/v2_checkpoint_adapter.gd")
const V2InteractionService = preload("res://scripts/v2/interaction/v2_interaction_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var adapter := V2CheckpointAdapter.new()
	var player := _unit("player_assault", "player", Vector2i(2, 3), 5)
	var enemy := _unit("enemy_sentry", "enemy", Vector2i(7, 3), 3)
	var schema_3: Dictionary = _with_hash({
		"schema_version": 3,
		"game_line": "v2_infiltration",
		"level_id": "ch1_m1",
		"encounter_id": "cp_rescue",
		"checkpoint_id": "cp_rescue",
		"turn": 4,
		"player_units": adapter.call("_serialize_units", [player]),
		"enemy_units": adapter.call("_serialize_units", [enemy]),
		"alert_state": {"level": 2},
		"visibility_state": {"revealed_cells": [Vector2i(2, 3)]},
		"facilities": [],
		"mission_flow": {"phase": "escort_to_evac", "step_index": 1, "completed_step_ids": {"search_scout": true}},
		"encounter_state": {"active_ids": ["enemy_sentry"], "defeated_ids": ["enemy_drone"], "started": true},
		"enemy_intents": {},
		"turn_state": {"phase": "player"},
		"extra": {},
	})

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
	t.check(String(migrated.get("encounter_id", "")) == "encounter_rescue", "旧 M1 cp_rescue 映射到稳定遭遇 ID")
	t.check((migrated.get("encounter_state", {}) as Dictionary).get("defeated_ids", []).has("enemy_drone"), "迁移保留击倒敌人集合")
	t.check(
		(migrated.get("mission_flow", {}) as Dictionary).get("phase", "") == "escort_to_evac",
		"迁移保留旧版任务阶段"
	)
	t.check((migrated.get("mission_flow", {}) as Dictionary).get("step_id", "") == "escort_scout", "迁移为旧阶段补充稳定任务步骤 ID")
	t.check(migrated.has("hazard_state") and migrated.has("facility_state"), "迁移补齐危险区和设施状态字段")
	t.check(bool(V2CheckpointAdapter.validate(migrated).get("valid", false)), "迁移后的 schema 4 检查点通过校验")

	var wrong_line: Dictionary = migrated.duplicate(true)
	wrong_line.game_line = "v1_legacy"
	wrong_line = _with_hash(wrong_line)
	t.check(not bool(V2CheckpointAdapter.validate(wrong_line).get("valid", true)), "V1 game_line 检查点继续被 V2 拒绝")

	_assert_facility_snapshot_validation()
	_assert_restore_failure_boundary(migrated)
	player.free()
	enemy.free()
	t.finish(self)

func _assert_facility_snapshot_validation() -> void:
	var service := V2InteractionService.new()
	service.setup({
		"facilities": [
			{"id": "camera_east", "type": "camera", "position": [2, 1], "state": "neutral"},
			{"id": "door_a", "type": "door", "position": [3, 1], "state": "locked"},
		],
		"size": {"width": 6, "height": 4},
	})
	var snapshot: Dictionary = service.get_snapshot()
	t.check(snapshot.get("facilities", []).size() == 2 and snapshot.has("state_revision"), "设施快照包含 ID、类型、状态、动作和版本")
	var valid_restore: Dictionary = service.restore_snapshot(snapshot)
	t.check(bool(valid_restore.get("success", false)) and bool(valid_restore.get("restored", false)) and service.get_state_revision() == 1, "设施快照成功恢复后递增状态版本")

	var before_invalid: Dictionary = service.get_snapshot()
	var unknown_id: Dictionary = before_invalid.duplicate(true)
	var unknown_facilities: Array = (unknown_id.get("facilities", []) as Array).duplicate(true)
	unknown_facilities.append({"id": "unknown_terminal", "type": "camera", "state": "neutral", "used_actions": [], "revision": 0})
	unknown_id["facilities"] = unknown_facilities
	var unknown_restore: Dictionary = service.restore_snapshot(unknown_id)
	t.check(not bool(unknown_restore.get("success", true)) and service.get_snapshot() == before_invalid, "设施恢复拒绝未知 ID 并保持原状态")

	var duplicate_actions: Dictionary = before_invalid.duplicate(true)
	var duplicate_facilities: Array = (duplicate_actions.get("facilities", []) as Array).duplicate(true)
	var first_facility: Dictionary = (duplicate_facilities[0] as Dictionary).duplicate(true)
	first_facility["used_actions"] = ["observe", "observe"]
	duplicate_facilities[0] = first_facility
	duplicate_actions["facilities"] = duplicate_facilities
	var duplicate_restore: Dictionary = service.restore_snapshot(duplicate_actions)
	t.check(not bool(duplicate_restore.get("success", true)) and service.get_snapshot() == before_invalid, "设施恢复拒绝重复 action 并回滚")

	var stale: Dictionary = before_invalid.duplicate(true)
	stale["state_revision"] = 0
	var stale_restore: Dictionary = service.restore_snapshot(stale)
	t.check(not bool(stale_restore.get("success", true)) and service.get_snapshot() == before_invalid, "设施恢复拒绝旧版本快照并回滚")

func _assert_restore_failure_boundary(snapshot: Dictionary) -> void:
	var adapter := V2CheckpointAdapter.new()
	var order: Array = []
	var fresh_player := _unit("player_assault", "player", Vector2i(0, 0), 5)
	var fresh_enemy := _unit("enemy_sentry", "enemy", Vector2i(1, 0), 3)
	var result: Dictionary = adapter.call("restore_v2_layers", snapshot, {
		"player_units": [fresh_player],
		"enemy_units": [fresh_enemy],
		"encounter_service": RestoreProbe.new("encounter", order, false),
		"facility_service": RestoreProbe.new("facilities", order, true),
		"hazard_service": RestoreProbe.new("hazards", order, false),
		"mission_flow": RestoreProbe.new("mission", order, false),
		"restore_order": order,
	})
	t.check(not bool(result.get("success", true)) and not bool(result.get("enter_battle", true)), "控制器局部恢复失败不会进入战斗")
	t.check(order == ["map", "units", "encounter", "facilities"], "控制器恢复按 map、Units、encounter、facilities 顺序停止在失败边界")
	fresh_player.free()
	fresh_enemy.free()

func _unit(entity_id: String, team: String, grid_pos: Vector2i, current_hp: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = entity_id
	unit.team = team
	unit.grid_pos = grid_pos
	unit.max_hp = current_hp
	unit.current_hp = current_hp
	unit.is_alive = true
	return unit

func _with_hash(snapshot: Dictionary) -> Dictionary:
	var next := snapshot.duplicate(true)
	next["timestamp"] = int(next.get("timestamp", 0))
	next.erase("hash")
	var body: Dictionary = next.duplicate(true)
	body.erase("timestamp")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(JSON.stringify(body).to_utf8_buffer())
	next["hash"] = hashing.finish().hex_encode()
	return next

class RestoreProbe:
	extends RefCounted

	var probe_name := ""
	var order_ref: Array = []
	var should_fail := false

	func _init(p_name: String, p_order: Array, p_should_fail: bool) -> void:
		probe_name = p_name
		order_ref = p_order
		should_fail = p_should_fail

	func restore_snapshot(_snapshot: Dictionary) -> Dictionary:
		order_ref.append(probe_name)
		if should_fail:
			return {"success": false, "reason": StringName("%s_restore_failed" % probe_name)}
		return {"success": true}
