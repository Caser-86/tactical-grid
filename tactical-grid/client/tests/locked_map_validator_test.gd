extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CODE-P1-02: 锁定地图验证器测试 ===")
	_test_valid_map()
	_test_duplicate_ids()
	_test_out_of_bounds()
	_test_dangling_connections()
	_test_unknown_facility()
	_test_deterministic_rng()
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

func _print_summary() -> void:
	print("\n=== 总计: %d 通过, %d 失败 ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)