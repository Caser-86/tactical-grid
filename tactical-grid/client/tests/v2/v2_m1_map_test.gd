extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Loader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Validator = preload("res://scripts/v2/content/v2_map_validator.gd")

var t := Runner.new()

func _initialize() -> void:
	var loaded := Loader.load_map(&"ch1_m1")
	var formal_loaded := Loader.load_map(&"ch1_m1_echo_yard_v3")
	t.check(bool(loaded.get("success", false)), "M1 v3 地图加载")
	t.check(bool(formal_loaded.get("success", false)), "正式地图 ID 可加载同一锁定地图")
	if not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	var size: Dictionary = map.get("size", {})
	var entities: Array = map.get("entities", [])
	var entity_ids := _ids(entities)
	var enemy_ids := {}
	for entity in entities:
		if entity is Dictionary and String(entity.get("type", "")) == "spawn_enemy":
			enemy_ids[String(entity.get("id", ""))] = true
	var encounter_ids := _ids(map.get("encounters", []))
	var checkpoint_ids := _ids(map.get("checkpoints", []))
	var facility_ids := _ids(map.get("facilities", []))

	t.check(String(map.get("map_id", "")) == "ch1_m1_echo_yard_v3", "M1 地图稳定 ID 固定")
	t.check(int(map.get("schema_version", 0)) == 3, "M1 使用 schema v3")
	t.check(int(size.get("width", 0)) == 22 and int(size.get("height", 0)) == 16, "M1 尺寸 22×16")
	for id in ["spawn_assault", "rescue_scout", "evac_northeast", "camera_console_south", "camera_east", "optional_record", "landmark_crane"]:
		t.check(entity_ids.has(id), "存在稳定对象 %s" % id)
	t.check(enemy_ids.size() == 6, "M1 固定六名敌人")
	for id in ["enemy_sentry_south", "enemy_drone_south", "enemy_sentry_rescue", "enemy_drone_rescue", "enemy_sentry_record", "enemy_sentry_evac"]:
		t.check(enemy_ids.has(id), "存在敌人实体 %s" % id)
	for id in ["encounter_south", "encounter_rescue", "encounter_evac"]:
		t.check(encounter_ids.has(id), "存在遭遇 %s" % id)
	for id in ["cp_start", "cp_rescue", "cp_pre_evac"]:
		t.check(checkpoint_ids.has(id), "存在检查点 %s" % id)
	t.check(facility_ids.has("facility_optional_record"), "存在可选记录设施")

	var layers: Dictionary = map.get("layers", {})
	for layer_name in ["base_terrain", "blocker", "vision", "height", "cover"]:
		var rows: Array = layers.get(layer_name, [])
		var rows_valid := rows.size() == 16
		for row in rows:
			if not row is Array or (row as Array).size() != 22:
				rows_valid = false
		t.check(rows_valid, "图层 %s 为 16×22" % layer_name)
	t.check(_count_cover(layers.get("cover", []), 1) > 0, "地图包含半掩体边界")
	t.check(_count_cover(layers.get("cover", []), 2) > 0, "地图包含全掩体边界")

	var encounters: Array = map.get("encounters", [])
	var encounter_caps_valid := true
	for encounter in encounters:
		if int(encounter.get("active_cap", 0)) > 3 or int(encounter.get("active_count", 0)) > int(encounter.get("active_cap", 0)):
			encounter_caps_valid = false
	t.check(encounter_caps_valid, "每个遭遇最多三名活跃敌人")
	var schedule_valid := true
	t.check(map.get("activation_schedule", []).size() == 4, "M1 有四个分阶段激活节点")
	for stage in map.get("activation_schedule", []):
		if int(stage.get("active_count", 99)) > 3:
			schedule_valid = false
	t.check(schedule_valid, "四个阶段的同时活跃敌人均不超过三名")

	t.check(Validator.has_route(map, Vector2i(3, 14), Vector2i(13, 7)), "出生点可达营救点")
	t.check(Validator.has_route(map, Vector2i(13, 7), Vector2i(19, 2)), "营救点可达撤离点")
	t.check(Validator.has_route(map, Vector2i(3, 14), Vector2i(4, 4)), "出生点可达可选记录点")

	var baseline_hash := JSON.stringify(map).hash()
	var deterministic := true
	for _i in range(100):
		var repeat := Loader.load_map(&"ch1_m1")
		if not bool(repeat.get("success", false)) or JSON.stringify(repeat.get("data", {})).hash() != baseline_hash:
			deterministic = false
	t.check(deterministic, "100 次固定加载规范化哈希一致")
	t.finish(self)

func _ids(records: Array) -> Dictionary:
	var result := {}
	for record in records:
		if record is Dictionary:
			result[String(record.get("id", ""))] = true
	return result

func _count_cover(rows: Array, value: int) -> int:
	var count := 0
	for row in rows:
		if row is Array:
			for cell in row:
				if int(cell) == value:
					count += 1
	return count
