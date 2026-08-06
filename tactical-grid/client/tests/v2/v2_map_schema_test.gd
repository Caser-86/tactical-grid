extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2MapValidator = preload("res://scripts/v2/content/v2_map_validator.gd")
const V2MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")

var t := Runner.new()

func _initialize() -> void:
	var valid_map := _minimal_map()
	t.check(bool(V2MapValidator.validate(valid_map).get("valid", false)), "最小 v3 地图有效")

	var duplicate: Dictionary = valid_map.duplicate(true)
	duplicate.entities.append({"id": "evac", "type": "terminal", "x": 5, "y": 5})
	t.check(not bool(V2MapValidator.validate(duplicate).get("valid", true)), "重复稳定 ID 被拒绝")

	var out_of_bounds: Dictionary = valid_map.duplicate(true)
	out_of_bounds.entities[0]["x"] = 8
	t.check(not bool(V2MapValidator.validate(out_of_bounds).get("valid", true)), "越界实体被拒绝")

	var unreachable: Dictionary = _minimal_map()
	unreachable.size = {"width": 5, "height": 1}
	unreachable.entities = [
		{"id": "spawn_assault", "type": "spawn_player", "role": "assault", "x": 0, "y": 0},
		{"id": "primary", "type": "objective_primary", "x": 4, "y": 0},
		{"id": "evac", "type": "evac", "x": 4, "y": 0}
	]
	unreachable.layers = {
		"base_terrain": [[0, 0, 0, 0, 0]],
		"blocker": [[0, 1, 1, 1, 0]],
		"vision": [[0, 0, 0, 0, 0]],
		"height": [[0, 0, 0, 0, 0]],
		"cover": [[0, 0, 0, 0, 0]],
	}
	var unreachable_result: Dictionary = V2MapValidator.validate(unreachable)
	t.check(not bool(unreachable_result.get("valid", true)), "不可达主路线被拒绝")

	var unknown_facility: Dictionary = valid_map.duplicate(true)
	unknown_facility.facilities = [{"id": "machine_a", "type": "teleporter", "x": 2, "y": 2}]
	t.check(not bool(V2MapValidator.validate(unknown_facility).get("valid", true)), "未知设施动作被拒绝")

	var active_cap: Dictionary = valid_map.duplicate(true)
	active_cap.encounters = [{"id": "enc_a", "active_count": 4, "active_cap": 3}]
	t.check(not bool(V2MapValidator.validate(active_cap).get("valid", true)), "遭遇激活数超过上限被拒绝")

	var missing_map: Dictionary = V2MapLoader.load_map(&"missing_v2_map")
	t.check(not bool(missing_map.get("success", true)), "缺失锁定地图加载失败")
	t.check(missing_map.get("reason", &"") == &"map_missing", "缺失地图返回明确原因")
	t.finish(self)

func _minimal_map() -> Dictionary:
	return {
		"schema_version": 3,
		"map_id": "test",
		"mission_id": "ch1_m1",
		"seed": 1,
		"size": {"width": 8, "height": 8},
		"layers": {"base_terrain": [], "blocker": [], "vision": [], "height": [], "cover": []},
		"entities": [
			{"id": "spawn_assault", "type": "spawn_player", "role": "assault", "x": 1, "y": 1},
			{"id": "evac", "type": "evac", "x": 6, "y": 6},
		],
		"encounters": [],
		"checkpoints": [],
		"facilities": [],
	}
