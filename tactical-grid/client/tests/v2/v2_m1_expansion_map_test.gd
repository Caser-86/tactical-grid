extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Loader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Validator = preload("res://scripts/v2/content/v2_map_validator.gd")

var t := Runner.new()

func _initialize() -> void:
	var canonical := Loader.load_map(&"ch1_m1")
	var formal := Loader.load_map(&"ch1_m1_echo_yard_v4")
	var fixture := Loader.load_map(&"ch1_m1_echo_yard_v3")
	t.check(bool(canonical.get("success", false)), "canonical M1 alias loads v4")
	t.check(bool(formal.get("success", false)), "formal v4 map loads")
	t.check(bool(fixture.get("success", false)), "legacy v3 fixture loads explicitly")
	if not bool(canonical.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = canonical.get("data", {})
	var size: Dictionary = map.get("size", {})
	t.check(String(map.get("map_id", "")) == "ch1_m1_echo_yard_v4", "canonical map ID is v4")
	t.check(int(size.get("width", 0)) == 26 and int(size.get("height", 0)) == 18, "expanded map is 26x18")
	t.check(_enemy_ids(map).size() == 8, "production map has eight fixed enemies")
	t.check((map.get("encounters", []) as Array).size() == 3, "production map has three encounters")
	t.check((map.get("main_routes", []) as Array).size() >= 2, "expanded map has at least two main routes")
	t.check(_has_id(map.get("facilities", []), "facility_record"), "optional record facility exists")
	t.check(_has_id(map.get("facilities", []), "facility_gantry"), "gantry facility exists")
	var record := _find_by_id(map.get("facilities", []), "facility_record")
	t.check(String(record.get("requires_encounter_clear", "")).is_empty(), "record remains optional in production")
	t.check(int(map.get("optional_record_round_trip_turns", 99)) <= 2, "record detour remains a short optional loop")
	for entity in map.get("entities", []):
		if entity is Dictionary and String(entity.get("type", "")) == "route_choice":
			t.check(false, "production map does not place route-choice entities")
	for id in ["cp_start", "cp_rescue", "cp_pre_evac"]:
		t.check(_has_id(map.get("checkpoints", []), id), "checkpoint exists: %s" % id)
	for layer_name in ["base_terrain", "blocker", "vision", "height", "cover"]:
		t.check(_layer_matches(map.get("layers", {}).get(layer_name, []), 26, 18), "layer has 26x18 shape: %s" % layer_name)
	var cap_valid := true
	for encounter in map.get("encounters", []):
		if not encounter is Dictionary:
			cap_valid = false
			continue
		if int(encounter.get("active_cap", 0)) > 3 or int(encounter.get("active_count", 0)) > 3:
			cap_valid = false
	t.check(cap_valid, "every encounter active count stays within three")
	var schedule_valid := true
	for stage in map.get("activation_schedule", []):
		if not stage is Dictionary or int(stage.get("active_count", 99)) > 3:
			schedule_valid = false
	t.check(schedule_valid, "every activation stage stays within three")
	t.check(Validator.has_route(map, Vector2i(3, 16), Vector2i(16, 8)), "maintenance route reaches rescue")
	t.check(Validator.has_route(map, Vector2i(3, 16), Vector2i(23, 2)), "cargo route reaches evacuation")
	t.check(Validator.has_route(map, Vector2i(3, 16), Vector2i(4, 5)), "record branch is reachable")
	var first_hash := JSON.stringify(map).hash()
	var deterministic := true
	for _i in range(25):
		var repeated := Loader.load_map(&"ch1_m1")
		if not bool(repeated.get("success", false)) or JSON.stringify(repeated.get("data", {})).hash() != first_hash:
			deterministic = false
	t.check(deterministic, "v4 alias load is deterministic")
	t.check(String(fixture.get("data", {}).get("map_id", "")) == "ch1_m1_echo_yard_v3", "v3 fixture identity remains unchanged")
	t.check(int(fixture.get("data", {}).get("size", {}).get("width", 0)) == 22, "v3 fixture retains 22-wide layout")
	t.check(int(fixture.get("data", {}).get("size", {}).get("height", 0)) == 16, "v3 fixture retains 16-high layout")
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

func _find_by_id(records: Array, id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == id:
			return record
	return {}

func _layer_matches(layer: Variant, width: int, height: int) -> bool:
	if not layer is Array or (layer as Array).size() != height:
		return false
	for row in layer:
		if not row is Array or (row as Array).size() != width:
			return false
	return true
