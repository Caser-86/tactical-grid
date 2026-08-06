extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _initialize() -> void:
	var controller_path := "res://scripts/v2/runtime/v2_battle_controller.gd"
	t.check(ResourceLoader.exists(controller_path), "V2 战斗使用独立控制器")
	if ResourceLoader.exists(controller_path):
		var controller_script := ResourceLoader.load(controller_path) as Script
		var has_enemy_turn := false
		if controller_script != null:
			for method_data in controller_script.get_script_method_list():
				if String(method_data.get("name", "")) == "run_v2_enemy_turn":
					has_enemy_turn = true
					break
		t.check(has_enemy_turn, "V2 战斗控制器拥有独立敌方回合入口")
	t.finish(self)
