extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _initialize() -> void:
	var controller_path := "res://scripts/v2/runtime/v2_battle_controller.gd"
	t.check(ResourceLoader.exists(controller_path), "V2 战斗使用独立控制器")
	if ResourceLoader.exists(controller_path):
		var controller_source := FileAccess.get_file_as_string(controller_path)
		t.check(controller_source.contains("func run_v2_enemy_turn()"), "V2 战斗控制器拥有独立敌方回合入口")
		t.check(controller_source.contains("func _start_battle()") and controller_source.contains("_handle_v2_checkpoint_restore_failure"), "V2 控制器接管检查点恢复失败入口，不继承新战斗回退")
		t.check(
			controller_source.contains("func _advance_v2_hazard_player_turn()") \
				and controller_source.contains("func _consume_v2_hazard_enemy_phase()") \
				and controller_source.contains("consume_enemy_phase_damage") \
				and controller_source.contains("func _commit_v2_hazard_close_action"),
			"V2 控制器在真实玩家/敌方回合边界集成危险区状态和关闭动作"
		)
	t.finish(self)
