extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const HazardController = preload("res://scripts/v2/mission/v2_hazard_controller.gd")

var t := Runner.new()

func _initialize() -> void:
	var hazards: Variant = HazardController.new()
	hazards.setup([
		{
			"id": "arc_field",
			"cells": [Vector2i(3, 3)],
			"warning_turn": 1,
			"damage_turn": 2,
			"damage": 2,
		},
	], Vector2i(8, 8))

	var warning: Dictionary = hazards.advance_player_turn(1)
	t.check(_has_turn_result_contract(warning), "危险区玩家回合结果包含警告、生效、关闭和周期字段")
	t.check(warning.get("warning_cells", []).has(Vector2i(3, 3)), "危险区在生效前一个完整玩家回合返回警告格")
	t.check((warning.get("active_cells", []) as Array).is_empty(), "警告回合不返回生效危险格")

	var active: Dictionary = hazards.advance_player_turn(2)
	t.check(_has_turn_result_contract(active), "危险区生效回合保持完整结果字段")
	t.check(active.get("active_cells", []).has(Vector2i(3, 3)), "警告后的下一玩家回合返回生效危险格")
	t.finish(self)

func _has_turn_result_contract(result: Dictionary) -> bool:
	return result.has("warning_cells") \
		and result.has("active_cells") \
		and result.has("closed") \
		and result.has("cycle")
