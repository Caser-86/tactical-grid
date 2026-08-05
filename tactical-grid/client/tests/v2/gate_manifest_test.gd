extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

func _initialize() -> void:
	var t := Runner.new()
	var file := FileAccess.open("res://tests/v2/gate_manifest.json", FileAccess.READ)
	if file == null:
		t.check(false, "V2 gate manifest exists")
		t.finish(self)
		return
	var data = JSON.parse_string(file.get_as_text())
	var ok: bool = data is Dictionary and data.has("script_tests") and data.has("scene_tests") and data.has("powershell_tests")
	t.check(ok, "V2 gate manifest schema is valid")
	if ok:
		var manifest: Dictionary = data
		var scene_tests: Array = manifest.get("scene_tests", [])
		var powershell_tests: Array = manifest.get("powershell_tests", [])
		t.check(not scene_tests.has("res://tests/v2/v2_main_menu_contract.tscn"), "V2 门禁不执行旧 V1 主菜单兼容测试")
		t.check(not powershell_tests.has("tests/run_release_gate.ps1"), "V2 门禁不调用 V1 发布门禁")
	t.finish(self)
