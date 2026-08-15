extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const UnitScript = preload("res://scripts/game/unit.gd")
const UnitSpriteScript = preload("res://scripts/game/unit_sprite.gd")

var t := Runner.new()

func _initialize() -> void:
	var catalog: Node = get_root().get_node_or_null("ArtCatalog")
	t.check(catalog != null, "V2 角色美术目录自动加载")
	if catalog == null:
		t.finish(self)
		return
	var keys := [
		&"v2_assault", &"v2_scout", &"v2_sniper", &"v2_heavy",
		&"v2_sentry", &"v2_drone", &"v2_shield_guard", &"v2_sniper_sentry",
	]
	for key in keys:
		t.check(catalog.has_texture(&"unit", key), "V2 独立角色图存在：%s" % key)
		var texture: Texture2D = catalog.get_texture(&"unit", key)
		t.check(texture != null and texture.get_width() == 128 and texture.get_height() == 128, "V2 角色图统一为 128×128：%s" % key)
		var image := texture.get_image() if texture != null else null
		t.check(image != null and image.get_pixel(0, 0).a < 0.1, "V2 角色图带透明背景：%s" % key)
		var path_ok := FileAccess.file_exists("res://assets/v2/units/%s_128.png" % String(key))
		t.check(path_ok, "V2 角色图不回退到 V1 路径：%s" % key)
	var sample_keys := [
		&"v2_assault_south", &"v2_scout_south", &"v2_sentry_south",
		&"v2_drone_south", &"v2_shield_guard_south",
	]
	for key in sample_keys:
		t.check(catalog.has_texture(&"unit", key), "M1 南向样本角色图存在：%s" % key)
		var texture: Texture2D = catalog.get_texture(&"unit", key)
		t.check(texture != null and texture.get_width() == 128 and texture.get_height() == 128, "M1 南向样本统一为 128×128：%s" % key)
		var image := texture.get_image() if texture != null else null
		var visible_pixels := 0
		var min_x := 128
		var min_y := 128
		var max_x := -1
		var max_y := -1
		if image != null:
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a >= 0.05:
						visible_pixels += 1
						min_x = mini(min_x, x)
						min_y = mini(min_y, y)
						max_x = maxi(max_x, x)
						max_y = maxi(max_y, y)
		t.check(image != null and image.get_pixel(0, 0).a < 0.1, "M1 南向样本带透明背景：%s" % key)
		t.check(visible_pixels >= 400 and min_x > 0 and min_y > 0 and max_x < 127 and max_y < 127, "M1 南向样本可见主体边界有效：%s" % key)
	var direction_suffixes := [&"north", &"east", &"south", &"west"]
	var directional_bases := [&"v2_assault", &"v2_scout", &"v2_sentry", &"v2_drone", &"v2_shield_guard"]
	for base_key in directional_bases:
		for suffix in direction_suffixes:
			var key := StringName("%s_%s" % [String(base_key), String(suffix)])
			t.check(catalog.has_texture(&"unit", key), "M1 四方向角色图存在：%s" % key)
			var texture: Texture2D = catalog.get_texture(&"unit", key)
			t.check(texture != null and texture.get_size() == Vector2(128, 128), "M1 四方向统一为 128×128：%s" % key)
			var image := texture.get_image() if texture != null else null
			t.check(image != null and image.get_pixel(0, 0).a < 0.1 and image.get_pixel(127, 127).a < 0.1, "M1 四方向背景透明：%s" % key)
			t.check(FileAccess.file_exists("res://assets/v2/units/%s_128.png" % key), "M1 四方向资源位于 V2 运行时目录：%s" % key)
	var integration_units := [
		{"key": &"v2_assault", "job": "assault", "team": "player"},
		{"key": &"v2_scout", "job": "scout", "team": "player"},
		{"key": &"v2_sentry", "job": "sentry", "team": "enemy"},
		{"key": &"v2_drone", "job": "drone", "team": "enemy"},
		{"key": &"v2_shield_guard", "job": "shield_guard", "team": "enemy"},
	]
	for entry in integration_units:
		var unit: Unit = UnitScript.new()
		unit.v2_art_key = entry.key
		unit.job = entry.job
		unit.team = entry.team
		var sprite: UnitSprite = UnitSpriteScript.new()
		sprite.update_unit(unit)
		var expected: Texture2D = catalog.get_texture(&"unit", StringName("%s_south" % String(entry.key)))
		t.check(sprite.art_sprite != null and sprite.art_sprite.texture == expected, "V2 M1 角色实际渲染南向样本：%s" % entry.key)
		t.check(sprite.has_method("set_facing_direction"), "V2 M1 UnitSprite 暴露朝向选帧接口：%s" % entry.key)
		if sprite.has_method("set_facing_direction"):
			for suffix in direction_suffixes:
				sprite.set_facing_direction(suffix)
				var directional_expected: Texture2D = catalog.get_texture(&"unit", StringName("%s_%s" % [String(entry.key), String(suffix)]))
				t.check(sprite.art_sprite.texture == directional_expected, "V2 M1 角色实际切换方向帧：%s/%s" % [entry.key, suffix])
			sprite.position = Vector2.ZERO
			sprite.play_move_to(Vector2(0, -64), 0.05)
			t.check(sprite.get_facing_direction() == &"north", "V2 M1 移动到上方时切换北向帧：%s" % entry.key)
			await create_timer(0.08).timeout
			sprite.play_state(&"attack", Vector2.RIGHT, 0.05)
			t.check(sprite.get_facing_direction() == &"east", "V2 M1 攻击右侧目标时切换东向帧：%s" % entry.key)
			await create_timer(0.08).timeout
		sprite.free()
		unit.free()
	for key in [&"v2_protocol_engineer", &"v2_hunter"]:
		t.check(catalog.has_texture(&"unit", key), "V2 扩展敌人角色图存在：%s" % key)
		t.check(FileAccess.file_exists("res://assets/generated/chapter1/runtime/units/%s_96.png" % String(key).trim_prefix("v2_")), "V2 扩展敌人复用已验证资源：%s" % key)
	var badges := {}
	for job in ["sentry", "drone", "sniper_sentry", "shield_guard", "protocol_engineer", "hunter"]:
		var unit: Unit = UnitScript.new()
		unit.team = "enemy"
		unit.job = job
		var sprite: Node = UnitSpriteScript.new()
		sprite.update_unit(unit)
		var badge := String(sprite.call("_get_role_badge"))
		t.check(not badge.is_empty(), "敌方原型有可读徽章：%s" % job)
		badges[badge] = true
		sprite.free()
		unit.free()
	t.check(badges.size() == 6, "六类敌人徽章全部区分")
	t.finish(self)
