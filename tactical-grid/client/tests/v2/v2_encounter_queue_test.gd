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
	t.check(supports_queue, "遭遇激活器公开击败和等待队列契约")
	t.check(activation.has_method("get_snapshot") and activation.has_method("restore_snapshot"), "遭遇激活器公开快照恢复契约")
	if not supports_queue:
		t.finish(self)
		return

	t.check(activation.get_active_enemy_ids().has("enemy_two"), "第一遭遇的存活敌人初始激活")
	activation.call("mark_enemy_defeated", &"enemy_one")
	activation.update([], [&"encounter_two"])

	var snapshot: Dictionary = activation.call("get_snapshot")
	var defeated: Array = snapshot.get("defeated_enemy_ids", [])
	t.check(activation.get_active_enemy_ids().has("enemy_two"), "第二遭遇触发后旧存活敌人保持激活")
	t.check(activation.call("get_waiting_enemy_ids").has("enemy_four"), "超过激活上限的新敌人进入等待队列")
	t.check(defeated.has("enemy_one"), "击败敌人进入击败状态")

	var restored := Activation.new()
	restored.setup(_map())
	var restore_result: Dictionary = restored.call("restore_snapshot", snapshot)
	t.check(
		bool(restore_result.get("success", false))
		and restored.get_active_enemy_ids().has("enemy_two")
		and restored.call("get_waiting_enemy_ids").has("enemy_four"),
		"遭遇队列快照恢复保留活跃和等待敌人"
	)
	t.finish(self)

func _map() -> Dictionary:
	return {
		"entities": [
			{"id": "enemy_one", "type": "spawn_enemy"},
			{"id": "enemy_two", "type": "spawn_enemy"},
			{"id": "enemy_three", "type": "spawn_enemy"},
			{"id": "enemy_four", "type": "spawn_enemy"},
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
				"active_enemy_ids": ["enemy_four"],
				"active_cap": 3,
			},
		],
	}
