extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

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
	t.finish(self)
