extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Loader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Validator = preload("res://scripts/v2/content/v2_map_validator.gd")

var t := Runner.new()

func _initialize() -> void:
	var canonical := Loader.load_map(&"ch1_m2")
	var formal := Loader.load_map(&"ch1_m2_cooling_works_v1")
	t.check(bool(canonical.get("success", false)), "canonical M2 alias loads Cooling Works")
	t.check(bool(formal.get("success", false)), "formal Cooling Works map loads")
	if not bool(canonical.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = canonical.get("data", {})
	var size: Dictionary = map.get("size", {})
	t.check(String(map.get("map_id", "")) == "ch1_m2_cooling_works_v1", "M2 map ID is stable")
	t.check(int(size.get("width", 0)) == 28 and int(size.get("height", 0)) == 20, "Cooling Works map is 28x20")
	t.check(_enemy_ids(map).size() == 13, "M2 has thirteen fixed enemies")
	t.check((map.get("encounters", []) as Array).size() == 5, "M2 has five encounters")
	t.check((map.get("main_routes", []) as Array).size() >= 2, "M2 has at least two main routes")
	t.check(_has_id(map.get("facilities", []), "facility_cooling_control"), "optional cooling control facility exists")
	t.check(_has_id(map.get("entities", []), "rescue_sniper"), "sniper rescue objective exists")
	t.check(_has_id(map.get("entities", []), "evac_north_gate"), "north evacuation gate exists")
	for id in ["cp_m2_start", "cp_m2_turbine", "cp_m2_rescue", "cp_m2_pre_evac"]:
		t.check(_has_id(map.get("checkpoints", []), id), "checkpoint exists: %s" % id)
	for layer_name in ["base_terrain", "blocker", "vision", "height", "cover"]:
		t.check(_layer_matches(map.get("layers", {}).get(layer_name, []), 28, 20), "layer has 28x20 shape: %s" % layer_name)
	var cap_valid := true
	for encounter in map.get("encounters", []):
		if not encounter is Dictionary or int(encounter.get("active_cap", 0)) > 3 or int(encounter.get("active_count", 0)) > 3:
			cap_valid = false
	t.check(cap_valid, "every M2 encounter stays within three active enemies")
	var schedule_valid := true
	for stage in map.get("activation_schedule", []):
		if not stage is Dictionary or int(stage.get("active_count", 99)) > 3:
			schedule_valid = false
	t.check(schedule_valid, "every M2 activation stage stays within three")
	t.check(Validator.has_route(map, Vector2i(3, 17), Vector2i(14, 9)), "west route reaches turbine")
	t.check(Validator.has_route(map, Vector2i(4, 17), Vector2i(14, 9)), "east route reaches turbine")
	t.check(Validator.has_route(map, Vector2i(14, 9), Vector2i(24, 2)), "rescue route reaches north evacuation gate")
	t.check(String(formal.get("data", {}).get("map_id", "")) == "ch1_m2_cooling_works_v1", "canonical and formal map identities match")
	t.finish(self)

func _enemy_ids(map: Dictionary) -> Dictionary:
	var ids := {}
	for entity in map.get("entities", []):
		if entity is Dictionary and String(entity.get("type", "")) == "spawn_enemy":
			ids[String(entity.get("id", ""))] = true
	return ids

func _has_id(records: Array, id: String) -> bool:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == id:
			return true
	return false

func _layer_matches(layer: Variant, width: int, height: int) -> bool:
	if not layer is Array or (layer as Array).size() != height:
		return false
	for row in layer:
		if not row is Array or (row as Array).size() != width:
			return false
	return true
