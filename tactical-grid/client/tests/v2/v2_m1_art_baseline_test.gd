extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _initialize() -> void:
	var catalog: Node = get_root().get_node_or_null("ArtCatalog")
	t.check(catalog != null, "V2 ArtCatalog 自动加载存在")
	if catalog == null:
		t.finish(self)
		return
	for key in [&"assault", &"scout", &"sentry_basic", &"attack_drone"]:
		t.check(catalog.has_texture(&"unit", key), "M1 单位美术存在：%s" % key)
	for key in [&"camera"]:
		t.check(catalog.has_texture(&"network_node", key), "M1 设施美术存在：%s" % key)
	for key in [&"evac", &"rescue_beacon"]:
		t.check(catalog.has_texture(&"objective", key), "M1 目标美术存在：%s" % key)
	for component in [&"floor", &"edge", &"prop", &"decal", &"landmark"]:
		var paths: Array = catalog.get_environment_component_paths(&"echo_yard", component)
		t.check(not paths.is_empty(), "Echo Yard 环境组件存在：%s" % component)
		var valid := true
		for path in paths:
			if not String(path).begins_with("res://assets/generated/chapter1/runtime/") or not FileAccess.file_exists(path):
				valid = false
		t.check(valid, "Echo Yard 环境路径保持 V2 资源隔离：%s" % component)
	t.finish(self)
