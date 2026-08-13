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
