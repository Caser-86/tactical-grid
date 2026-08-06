extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const HazardController = preload("res://scripts/v2/mission/v2_hazard_controller.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var player: Unit = UnitScript.new()
	player.entity_id = "player_assault"
	player.team = "player"
	player.grid_pos = Vector2i(3, 3)
	player.max_hp = 6
	player.current_hp = 6
	player.is_alive = true
	var hp_before := player.current_hp

	var hazards := HazardController.new()
	hazards.setup([
		{
			"id": "arc_field",
			"cells": [Vector2i(3, 3)],
			"warning_turn": 1,
			"damage_turn": 2,
			"damage": 2,
		},
	], [player])

	var warning: Dictionary = hazards.advance_player_turn()
	t.check(warning.get("warning_hazard_ids", []).has("arc_field"), "危险区在伤害前一个完整玩家回合发出警告")
	t.check(player.current_hp == hp_before, "警告回合不造成伤害")

	var active: Dictionary = hazards.advance_player_turn()
	t.check(active.get("active_hazard_ids", []).has("arc_field"), "警告后的下一玩家回合危险区生效")
	t.check(player.current_hp == hp_before - 2, "生效危险区对位于区域内的玩家造成配置伤害")
	player.queue_free()
	t.finish(self)
