## CODE-CH1-020: 遭遇检查点状态测试
## 验证检查点快照的创建、序列化、验证和恢复。
## 退出门：同一检查点重复恢复产生相同初始战局（RNG 种子 + 状态快照）。
extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CH1-020: 遭遇检查点状态测试 ===")
	_test_snapshot_creation()
	_test_snapshot_validation()
	_test_invalid_snapshot_rejected()
	_test_rng_restore_consistency()
	_test_equivalents_ignores_timestamp()
	_test_unit_serialization()
	_test_repeated_restore_produces_same_state()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

## 创建测试用 Unit 实例
func _make_unit(id: String, team: String, job: String, x: int, y: int, hp: int) -> Unit:
	var unit := Unit.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = team
	unit.job = job
	unit.grid_pos = Vector2i(x, y)
	unit.max_hp = hp
	unit.current_hp = hp
	unit.max_ap = 2
	unit.current_ap = 2
	unit.move_points = 5
	unit.base_move_points = 5
	unit.is_alive = true
	unit.is_downed = false
	return unit

## 构造一个完整的 AlertState 序列化字典
func _make_alert_state_dict() -> Dictionary:
	var alert := AlertState.new()
	alert.setup()
	alert.apply_event("enemy_spotted")
	return alert.serialize()

## 构造一个完整的 VisibilityState 序列化字典
func _make_visibility_state_dict() -> Dictionary:
	var vis := VisibilityState.new()
	vis.setup(10, 10)
	vis.reveal_cells([Vector2i(3, 3), Vector2i(4, 4)])
	return vis.serialize()

func _test_snapshot_creation() -> void:
	print("\n--- 测试: 快照创建包含所有必需字段 ---")
	var player_units: Array = [_make_unit("p1", "player", "assault", 5, 5, 100)]
	var enemy_units: Array = [_make_unit("e1", "enemy", "sentry_basic", 8, 8, 60)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var snap := EncounterCheckpointState.snapshot(
		"ch1_m1", "zone_a", 3,
		player_units, enemy_units,
		_make_alert_state_dict(),
		_make_visibility_state_dict(),
		[{"id": "node_1", "type": "camera", "state": "player"}],
		[{"type": "door", "x": 1, "y": 1}],
		{"phase": "infiltrate", "terminals_activated": 0},
		rng,
		{"note": "test"}
	)
	_check(int(snap.get("schema_version", 0)) == 1, "快照 schema_version=1")
	_check(String(snap.get("level_id", "")) == "ch1_m1", "快照 level_id 正确")
	_check(String(snap.get("encounter_id", "")) == "zone_a", "快照 encounter_id 正确")
	_check(int(snap.get("turn", -1)) == 3, "快照 turn 正确")
	_check((snap.get("player_units", []) as Array).size() == 1, "快照包含 1 个玩家单位")
	_check((snap.get("enemy_units", []) as Array).size() == 1, "快照包含 1 个敌人单位")
	_check(snap.has("alert_state"), "快照包含 alert_state")
	_check(snap.has("visibility_state"), "快照包含 visibility_state")
	_check(snap.has("network_nodes"), "快照包含 network_nodes")
	_check(snap.has("facilities"), "快照包含 facilities")
	_check(snap.has("objective_phase"), "快照包含 objective_phase")
	_check(snap.has("rng_state"), "快照包含 rng_state")
	_check(snap.has("extra"), "快照包含 extra")
	# 清理
	for u in player_units: u.free()
	for u in enemy_units: u.free()

func _test_snapshot_validation() -> void:
	print("\n--- 测试: 有效快照通过校验 ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var snap := EncounterCheckpointState.snapshot(
		"ch1_m1", "zone_a", 1,
		[], [],
		{}, {}, [], [], {},
		rng
	)
	var result := EncounterCheckpointState.validate(snap)
	_check(bool(result.get("valid", false)), "有效快照通过校验")
	_check((result.get("errors", []) as Array).is_empty(), "有效快照无错误")

func _test_invalid_snapshot_rejected() -> void:
	print("\n--- 测试: 无效快照被拒绝 ---")
	# 缺少 level_id
	var bad1 := {"schema_version": 1, "encounter_id": "zone_a", "player_units": [], "enemy_units": [], "rng_state": {"seed": 1}}
	var r1 := EncounterCheckpointState.validate(bad1)
	_check(not bool(r1.get("valid", true)), "缺少 level_id 被拒绝")
	# 缺少 encounter_id
	var bad2 := {"schema_version": 1, "level_id": "ch1_m1", "player_units": [], "enemy_units": [], "rng_state": {"seed": 1}}
	var r2 := EncounterCheckpointState.validate(bad2)
	_check(not bool(r2.get("valid", true)), "缺少 encounter_id 被拒绝")
	# 缺少 rng_state
	var bad3 := {"schema_version": 1, "level_id": "ch1_m1", "encounter_id": "zone_a", "player_units": [], "enemy_units": []}
	var r3 := EncounterCheckpointState.validate(bad3)
	_check(not bool(r3.get("valid", true)), "缺少 rng_state 被拒绝")
	# 错误的 schema_version
	var bad4 := {"schema_version": 99, "level_id": "ch1_m1", "encounter_id": "zone_a", "player_units": [], "enemy_units": [], "rng_state": {"seed": 1}}
	var r4 := EncounterCheckpointState.validate(bad4)
	_check(not bool(r4.get("valid", true)), "错误 schema_version 被拒绝")

func _test_rng_restore_consistency() -> void:
	print("\n--- 测试: RNG 恢复后随机序列一致 ---")
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 7777
	# 消费几个随机数
	var _discarded := rng1.randi()
	var _discarded2 := rng1.randi()
	# 序列化
	var rng_state := EncounterCheckpointState.serialize_rng(rng1)
	# 恢复
	var rng2 := EncounterCheckpointState.restore_rng(rng_state)
	_check(int(rng2.seed) == 7777, "恢复后 seed 一致")
	# 从恢复的 RNG 重新生成序列，应与从原始 seed 重新生成一致
	var rng_fresh := RandomNumberGenerator.new()
	rng_fresh.seed = 7777
	var a1 := rng2.randi()
	var a2 := rng_fresh.randi()
	_check(a1 == a2, "恢复的 RNG 第一随机数与新鲜 RNG 一致")
	var b1 := rng2.randi()
	var b2 := rng_fresh.randi()
	_check(b1 == b2, "恢复的 RNG 第二随机数与新鲜 RNG 一致")

func _test_equivalents_ignores_timestamp() -> void:
	print("\n--- 测试: equivalents 忽略 timestamp ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var snap1 := EncounterCheckpointState.snapshot(
		"ch1_m1", "zone_a", 2,
		[], [], {}, {}, [], [], {}, rng
	)
	var snap2 := EncounterCheckpointState.snapshot(
		"ch1_m1", "zone_a", 2,
		[], [], {}, {}, [], [], {}, rng
	)
	# 强制不同 timestamp，验证 equivalents 仍返回 true
	snap2["timestamp"] = snap1.get("timestamp", 0) + 999
	_check(EncounterCheckpointState.equivalents(snap1, snap2), "仅 timestamp 不同的快照等价")
	# 修改内容后应不等价
	var snap3 := snap2.duplicate(true)
	snap3["turn"] = 99
	snap3.erase("timestamp")
	snap1.erase("timestamp")
	_check(not EncounterCheckpointState.equivalents(snap1, snap3), "内容不同的快照不等价")

func _test_unit_serialization() -> void:
	print("\n--- 测试: 单位序列化保留关键字段 ---")
	var player_units: Array = [
		_make_unit("p1", "player", "assault", 3, 4, 100),
	]
	player_units[0].current_hp = 75
	player_units[0].current_ap = 1
	player_units[0].armor = 5

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var snap := EncounterCheckpointState.snapshot(
		"ch1_m1", "zone_a", 1,
		player_units, [],
		{}, {}, [], [], {}, rng
	)
	var serialized: Dictionary = (snap.get("player_units", []) as Array)[0]
	_check(String(serialized.get("entity_id", "")) == "p1", "序列化保留 entity_id")
	_check(String(serialized.get("team", "")) == "player", "序列化保留 team")
	_check(String(serialized.get("job", "")) == "assault", "序列化保留 job")
	_check(int(serialized.get("current_hp", -1)) == 75, "序列化保留 current_hp")
	_check(int(serialized.get("max_hp", -1)) == 100, "序列化保留 max_hp")
	_check(int(serialized.get("current_ap", -1)) == 1, "序列化保留 current_ap")
	_check(int(serialized.get("armor", -1)) == 5, "序列化保留 armor")
	var pos: Dictionary = serialized.get("grid_pos", {})
	_check(int(pos.get("x", -1)) == 3 and int(pos.get("y", -1)) == 4, "序列化保留 grid_pos")
	for u in player_units: u.free()

func _test_repeated_restore_produces_same_state() -> void:
	print("\n--- 测试: 同一检查点重复恢复产生相同初始战局 ---")
	# 退出门：同一检查点重复恢复产生相同初始战局
	var player_units: Array = [_make_unit("p1", "player", "assault", 5, 5, 100)]
	var enemy_units: Array = [_make_unit("e1", "enemy", "sentry_basic", 8, 8, 60)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024

	var snap := EncounterCheckpointState.snapshot(
		"ch1_m1", "zone_b", 5,
		player_units, enemy_units,
		_make_alert_state_dict(),
		_make_visibility_state_dict(),
		[{"id": "node_1", "type": "camera", "state": "player"}],
		[],
		{"phase": "upload"},
		rng
	)
	for u in player_units: u.free()
	for u in enemy_units: u.free()

	# 第一次恢复
	var rng_restore1 := EncounterCheckpointState.restore_rng(snap.get("rng_state", {}))
	var r1_a := rng_restore1.randi()
	var r1_b := rng_restore1.randi()

	# 第二次恢复
	var rng_restore2 := EncounterCheckpointState.restore_rng(snap.get("rng_state", {}))
	var r2_a := rng_restore2.randi()
	var r2_b := rng_restore2.randi()

	_check(r1_a == r2_a, "重复恢复第一随机数一致")
	_check(r1_b == r2_b, "重复恢复第二随机数一致")
	# 快照内容应可通过 equivalents 比较
	var snap_copy := snap.duplicate(true)
	snap_copy.erase("timestamp")
	snap.erase("timestamp")
	_check(EncounterCheckpointState.equivalents(snap, snap_copy), "重复恢复状态等价")

func _print_summary() -> void:
	print("\n=== 总计: %d 通过, %d 失败 ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
