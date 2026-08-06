extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Loader = preload("res://scripts/v2/content/v2_map_loader.gd")

var t := Runner.new()

func _initialize() -> void:
	var catalog: Node = get_root().get_node_or_null("ArtCatalog")
	t.check(catalog != null, "M1 扩展测试使用 V2 ArtCatalog")
	if catalog != null:
		for key in [&"sniper_sentry", &"shield_guard", &"protocol_engineer"]:
			t.check(catalog.has_texture(&"unit", key), "敌人职责拥有独立美术映射：%s" % key)

	var loaded := Loader.load_map(&"ch1_m1")
	t.check(bool(loaded.get("success", false)), "M1 扩展地图加载")
	if not bool(loaded.get("success", false)):
		t.finish(self)
		return
	var map: Dictionary = loaded.get("data", {})
	var environment: Dictionary = map.get("environment", {})
	var overrides: Array = environment.get("kit_overrides", [])
	t.check(overrides.size() >= 3, "M1 至少包含三个可辨识环境分区")
	var kits := {}
	for override in overrides:
		if override is Dictionary:
			kits[String(override.get("kit", ""))] = true
	for kit in [&"echo_yard", &"cooling_works", &"transit_hub", &"sentinel_core"]:
		t.check(kits.has(kit) or String(environment.get("kit", "")) == String(kit), "M1 使用环境套件：%s" % kit)
		for component in [&"floor", &"edge", &"prop", &"decal", &"landmark"]:
			var paths: Array = catalog.get_environment_component_paths(kit, component)
			var valid := not paths.is_empty()
			for path in paths:
				if not String(path).begins_with("res://assets/generated/chapter1/runtime/") or not FileAccess.file_exists(path):
					valid = false
			t.check(valid, "环境套件 %s 组件可加载：%s" % [kit, component])
	t.check(environment.get("decorations", []).size() >= 15, "M1 固定环境装饰不少于十五处")

	var enemy_ids := {}
	for entity in map.get("entities", []):
		if entity is Dictionary and String(entity.get("type", "")) == "spawn_enemy":
			enemy_ids[String(entity.get("id", ""))] = true
	t.check(enemy_ids.size() == 9, "M1 敌人总实体扩展为九名")
	for id in [&"enemy_shield_rescue", &"enemy_engineer_record", &"enemy_sniper_evac"]:
		t.check(enemy_ids.has(id), "M1 存在新增敌人实体：%s" % id)

	var caps_valid := true
	for encounter in map.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("active_count", 99)) > 3:
			caps_valid = false
	for stage in map.get("activation_schedule", []):
		if stage is Dictionary and int(stage.get("active_count", 99)) > 3:
			caps_valid = false
	t.check(caps_valid, "M1 扩展后同时活跃敌人仍不超过三名")
	t.finish(self)
