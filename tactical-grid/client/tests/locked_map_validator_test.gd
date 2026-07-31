extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CODE-P1-02 / CH1-020: 锁定地图验证器测试 ===")
	_test_valid_map()
	_test_duplicate_ids()
	_test_out_of_bounds()
	_test_dangling_connections()
	_test_unknown_facility()
	_test_deterministic_rng()
	# CODE-CH1-020: v2 模式校验
	_test_valid_v2_map()
	_test_v2_missing_mission_id()
	_test_duplicate_encounter_ids()
	_test_invalid_checkpoint_ref()
	_test_checkpoint_missing_encounter_ref()
	_test_v2_duplicate_node_id()
	_test_v2_entity_node_id_conflict()
	_test_v1_migration_to_v2()
	_test_v2_valid_with_encounters_and_checkpoints()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _test_valid_map() -> void:
	print("\n--- 测试: 有效地图通过验证 ---")
	var map := {
		"schema_version": 1,
		"size": {"width": 10, "height": 10},
		"objects": [
			{"id": "term_1", "type": "terminal", "x": 5, "y": 5},
			{"id": "evac_1", "type": "evac", "x": 0, "y": 0},
		],
		"nodes": [{"id": "node_1", "x": 3, "y": 3}],
		"connections": [{"from": "node_1", "to": "node_1"}],
		"facilities": [{"type": "camera", "x": 2, "y": 2}],
	}
	var result := LockedMapValidator.validate(map)
	_check(bool(result.get("valid", false)), "有效地图通过验证")

func _test_duplicate_ids() -> void:
	print("\n--- 测试: 重复 ID 被拒绝 ---")
	var map := {
		"size": {"width": 10, "height": 10},
		"objects": [
			{"id": "dup", "type": "terminal", "x": 1, "y": 1},
			{"id": "dup", "type": "terminal", "x": 2, "y": 2},
		],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "重复 ID 被拒绝")

func _test_out_of_bounds() -> void:
	print("\n--- 测试: 超界坐标被拒绝 ---")
	var map := {
		"size": {"width": 5, "height": 5},
		"objects": [{"id": "oob", "type": "terminal", "x": 10, "y": 3}],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "超界坐标被拒绝")

func _test_dangling_connections() -> void:
	print("\n--- 测试: 悬空连接被拒绝 ---")
	var map := {
		"size": {"width": 10, "height": 10},
		"nodes": [{"id": "node_1", "x": 1, "y": 1}],
		"connections": [{"from": "node_1", "to": "nonexistent"}],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "悬空连接被拒绝")

func _test_unknown_facility() -> void:
	print("\n--- 测试: 未知设施类型被拒绝 ---")
	var map := {
		"size": {"width": 10, "height": 10},
		"facilities": [{"type": "unknown_machine", "x": 1, "y": 1}],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "未知设施类型被拒绝")

func _test_deterministic_rng() -> void:
	print("\n--- 测试: 确定性 RNG ---")
	var as1 := ActionSystem.new()
	as1.set_seed(42)
	var r1a := as1.rng.randi()
	var r1b := as1.rng.randi()
	var as2 := ActionSystem.new()
	as2.set_seed(42)
	var r2a := as2.rng.randi()
	var r2b := as2.rng.randi()
	_check(r1a == r2a, "相同种子第一随机数一致")
	_check(r1b == r2b, "相同种子第二随机数一致")
	_check(r1a != r1b, "连续随机数不同")

# ===== CODE-CH1-020: v2 模式校验测试 =====

func _test_valid_v2_map() -> void:
	print("\n--- 测试: v2 有效地图通过验证 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "test_m1",
		"size": {"width": 10, "height": 10},
		"entities": [
			{"id": "term_1", "type": "terminal", "x": 5, "y": 5},
		],
		"network_nodes": [{"id": "node_1", "x": 3, "y": 3}],
		"encounters": [],
		"checkpoints": [],
	}
	var result := LockedMapValidator.validate(map)
	_check(bool(result.get("valid", false)), "v2 有效地图通过验证")

func _test_v2_missing_mission_id() -> void:
	print("\n--- 测试: v2 缺少 mission_id 被拒绝 ---")
	var map := {
		"schema_version": 2,
		"size": {"width": 10, "height": 10},
		"entities": [],
		"encounters": [],
		"checkpoints": [],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "v2 缺少 mission_id 被拒绝")

func _test_duplicate_encounter_ids() -> void:
	print("\n--- 测试: 重复遭遇 ID 被拒绝 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "test_m1",
		"size": {"width": 10, "height": 10},
		"encounters": [
			{"id": "zone_a", "zone_id": "A", "trigger_cells": [[5, 5]]},
			{"id": "zone_a", "zone_id": "A", "trigger_cells": [[6, 6]]},
		],
		"checkpoints": [],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "重复遭遇 ID 被拒绝")

func _test_invalid_checkpoint_ref() -> void:
	print("\n--- 测试: 检查点引用未知遭遇被拒绝 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "test_m1",
		"size": {"width": 10, "height": 10},
		"encounters": [
			{"id": "zone_a", "zone_id": "A"},
		],
		"checkpoints": [
			{"id": "cp_a_to_b", "encounter_id": "zone_a", "next_encounter_id": "nonexistent"},
		],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "检查点引用未知遭遇被拒绝")

func _test_checkpoint_missing_encounter_ref() -> void:
	print("\n--- 测试: 检查点缺少 encounter_id 被拒绝 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "test_m1",
		"size": {"width": 10, "height": 10},
		"encounters": [
			{"id": "zone_a", "zone_id": "A"},
		],
		"checkpoints": [
			{"id": "cp_orphan"},
		],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "检查点缺少 encounter_id 被拒绝")

func _test_v2_duplicate_node_id() -> void:
	print("\n--- 测试: 重复网络节点 ID 被拒绝 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "test_m1",
		"size": {"width": 10, "height": 10},
		"network_nodes": [
			{"id": "dup_node", "x": 1, "y": 1},
			{"id": "dup_node", "x": 2, "y": 2},
		],
		"encounters": [],
		"checkpoints": [],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "重复网络节点 ID 被拒绝")

func _test_v2_entity_node_id_conflict() -> void:
	print("\n--- 测试: 实体与节点 ID 冲突被拒绝 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "test_m1",
		"size": {"width": 10, "height": 10},
		"entities": [
			{"id": "shared_id", "type": "terminal", "x": 5, "y": 5},
		],
		"network_nodes": [
			{"id": "shared_id", "x": 1, "y": 1},
		],
		"encounters": [],
		"checkpoints": [],
	}
	var result := LockedMapValidator.validate(map)
	_check(not bool(result.get("valid", true)), "实体与节点 ID 冲突被拒绝")

func _test_v1_migration_to_v2() -> void:
	print("\n--- 测试: v1 地图迁移到 v2 ---")
	var v1_map := {
		"map_id": "test_v1",
		"schema_version": 1,
		"size": {"width": 10, "height": 10},
		"objects": [
			{"id": "obj_1", "type": "terminal", "x": 5, "y": 5},
		],
		"nodes": [{"id": "node_1", "x": 3, "y": 3}],
	}
	var migrated := MapLoader.migrate_to_v2(v1_map)
	_check(int(migrated.get("schema_version", 0)) == 2, "迁移后 schema_version=2")
	_check(String(migrated.get("mission_id", "")) == "test_v1", "迁移补全 mission_id")
	_check((migrated.get("entities", []) as Array).size() == 1, "迁移从 objects 派生 entities")
	_check((migrated.get("network_nodes", []) as Array).size() == 1, "迁移从 nodes 派生 network_nodes")
	_check((migrated.get("encounters", []) as Array).is_empty(), "迁移补全空 encounters")
	_check((migrated.get("checkpoints", []) as Array).is_empty(), "迁移补全空 checkpoints")
	# 迁移后的地图应通过 v2 校验
	var validation := LockedMapValidator.validate(migrated)
	_check(bool(validation.get("valid", false)), "迁移后地图通过 v2 校验")

func _test_v2_valid_with_encounters_and_checkpoints() -> void:
	print("\n--- 测试: v2 含遭遇和检查点通过验证 ---")
	var map := {
		"schema_version": 2,
		"mission_id": "ch1_m1",
		"size": {"width": 18, "height": 14},
		"entities": [
			{"id": "player_alpha", "type": "spawn_player", "x": 8, "y": 13, "team": "player"},
			{"id": "east_terminal", "type": "terminal", "x": 15, "y": 6, "state": "inactive"},
		],
		"network_nodes": [
			{"id": "node_camera_east", "type": "camera", "state": "enemy", "x": 13, "y": 5},
		],
		"encounters": [
			{"id": "zone_a", "zone_id": "A", "name": "入口", "trigger_cells": [[8, 13]]},
			{"id": "zone_b", "zone_id": "B", "name": "中段", "trigger_cells": [[11, 7]]},
		],
		"checkpoints": [
			{"id": "cp_a_to_b", "encounter_id": "zone_a", "next_encounter_id": "zone_b", "trigger": "camera_takeover"},
		],
	}
	var result := LockedMapValidator.validate(map)
	_check(bool(result.get("valid", false)), "v2 含遭遇和检查点通过验证")

func _print_summary() -> void:
	print("\n=== 总计: %d 通过, %d 失败 ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)