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
	t.finish(self)
