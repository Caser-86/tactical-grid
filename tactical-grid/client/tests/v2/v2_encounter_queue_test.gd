extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Activation = preload("res://scripts/v2/mission/v2_encounter_activation.gd")

var t := Runner.new()

func _initialize() -> void:
	var activation := Activation.new()
	activation.setup(_map())
	activation.update([], [])

	var supports_queue := activation.has_method("mark_enemy_defeated") \
		and activation.has_method("get_waiting_enemy_ids")
	var supports_snapshot := activation.has_method("get_snapshot") \
		and activation.has_method("restore_snapshot")
	t.check(supports_queue, "遭遇激活器公开击败和等待队列契约")
	t.check(supports_snapshot, "遭遇激活器公开快照恢复契约")
	if not supports_queue or not supports_snapshot:
		t.finish(self)
		return

	t.check(activation.get_active_enemy_ids().has("enemy_two"), "第一遭遇的存活敌人初始激活")
	activation.call("mark_enemy_defeated", &"enemy_one")
	activation.update([], [&"encounter_two"])

	var active_enemy_ids: Array = activation.get_active_enemy_ids()
	var waiting_enemy_ids: Array = activation.call("get_waiting_enemy_ids")
	var snapshot: Dictionary = activation.call("get_snapshot")
	var defeated_enemy_ids: Array = snapshot.get("defeated_enemy_ids", [])
	t.check(active_enemy_ids.has("enemy_two"), "第二遭遇触发后旧存活敌人保持激活")
	t.check(
		waiting_enemy_ids.has("enemy_four") or waiting_enemy_ids.has("enemy_five"),
		"活跃上限填满后至少一名新请求敌人进入等待队列"
	)
	t.check(defeated_enemy_ids.has("enemy_one"), "击败敌人进入击败状态")

	var restored := Activation.new()
	restored.setup(_map())
	var restore_result: Dictionary = restored.call("restore_snapshot", snapshot)
	var restored_snapshot: Dictionary = restored.call("get_snapshot")
	t.check(
		bool(restore_result.get("success", false))
		and _same_ids(restored.get_active_enemy_ids(), active_enemy_ids)
		and _same_ids(restored.call("get_waiting_enemy_ids"), waiting_enemy_ids)
		and _same_ids(restored_snapshot.get("defeated_enemy_ids", []), defeated_enemy_ids),
		"遭遇队列快照恢复保留活跃、等待和击败敌人集合"
	)
	t.finish(self)

func _same_ids(left: Array, right: Array) -> bool:
	var sorted_left: Array = left.duplicate()
	var sorted_right: Array = right.duplicate()
	sorted_left.sort()
	sorted_right.sort()
	return sorted_left == sorted_right

func _map() -> Dictionary:
	return {
		"entities": [
			{"id": "enemy_one", "type": "spawn_enemy"},
			{"id": "enemy_two", "type": "spawn_enemy"},
			{"id": "enemy_three", "type": "spawn_enemy"},
			{"id": "enemy_four", "type": "spawn_enemy"},
			{"id": "enemy_five", "type": "spawn_enemy"},
		],
		"encounters": [
			{
				"id": "encounter_one",
				"trigger": "start",
				"active_enemy_ids": ["enemy_one", "enemy_two", "enemy_three"],
				"active_cap": 3,
			},
			{
				"id": "encounter_two",
				"trigger": "encounter_two",
				"active_enemy_ids": ["enemy_four", "enemy_five"],
				"active_cap": 3,
			},
		],
	}
