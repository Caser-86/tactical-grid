extends SceneTree

const EXPECTED_DIR_NAME := "TacticalGrid_V2_Infiltration"

func _initialize() -> void:
	var user_data_dir := OS.get_user_data_dir()
	print("V2 user data directory: %s" % user_data_dir)
	if not user_data_dir.ends_with("/%s" % EXPECTED_DIR_NAME) and not user_data_dir.ends_with("\\%s" % EXPECTED_DIR_NAME):
		push_error("V2 user data directory is not isolated: %s" % user_data_dir)
		quit(1)
		return
	print("V2 user data isolation: PASS")
	quit(0)
