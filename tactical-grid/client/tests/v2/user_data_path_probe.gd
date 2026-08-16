extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const EXPECTED_DIR_NAME := "TacticalGrid_V2_Infiltration"

func _initialize() -> void:
	var t := Runner.new()
	var user_data_dir := OS.get_user_data_dir()
	print("V2 user data directory: %s" % user_data_dir)
	var isolated := user_data_dir.ends_with("/%s" % EXPECTED_DIR_NAME) or user_data_dir.ends_with("\\%s" % EXPECTED_DIR_NAME)
	t.check(isolated, "V2 user data directory is isolated")
	t.finish(self)
