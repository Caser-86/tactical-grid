extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const HazardController = preload("res://scripts/v2/mission/v2_hazard_controller.gd")

var t := Runner.new()

func _initialize() -> void:
	var hazards: Variant = HazardController.new()
	hazards.setup([
		{
			"id": "arc_field",
			"cells": [Vector2i(3, 3), [3, 4]],
			"warning_turn": 1,
			"damage_turn": 2,
			"cycle_length": 3,
			"damage": 2,
			"close_action_id": "seal_arc_field",
		},
	], Vector2i(8, 8))

	var warning: Dictionary = hazards.advance_player_turn(1)
	t.check(_has_turn_result_contract(warning), "危险区玩家回合结果包含警告、生效、关闭和周期字段")
	t.check(warning.get("warning_cells", []).has(Vector2i(3, 3)), "危险区在生效前一个完整玩家回合返回警告格")
	t.check((warning.get("active_cells", []) as Array).is_empty(), "警告回合不返回生效危险格")
	t.check((warning.get("damage_events", []) as Array).is_empty(), "警告回合不结算伤害")

	var active: Dictionary = hazards.advance_player_turn(2)
	t.check(_has_turn_result_contract(active), "危险区生效回合保持完整结果字段")
	t.check(active.get("active_cells", []).has(Vector2i(3, 3)), "警告后的下一玩家回合返回生效危险格")
	t.check(active.get("damage_events", []).size() == 1 and int(active.damage_events[0].get("damage", 0)) == 2, "生效危险区只登记一次敌方阶段伤害")

	var active_repeat: Dictionary = hazards.advance_player_turn(2)
	t.check(active_repeat.get("active_cells", []).has(Vector2i(3, 3)), "同一回合重复查询仍保留生效危险格用于表现")
	t.check((active_repeat.get("damage_events", []) as Array).is_empty(), "同一危险周期重复查询不会重复结算伤害")

	var close_result: Dictionary = hazards.commit_close_action("seal_arc_field")
	t.check(bool(close_result.get("success", false)) and close_result.get("closed", []).has("arc_field"), "关闭动作永久关闭对应危险区")
	var closed_warning: Dictionary = hazards.advance_player_turn(4)
	var closed_active: Dictionary = hazards.advance_player_turn(5)
	t.check((closed_warning.get("warning_cells", []) as Array).is_empty(), "关闭后后续周期不再显示预警")
	t.check((closed_active.get("active_cells", []) as Array).is_empty(), "关闭后后续周期不再生效")

	var snapshot: Dictionary = hazards.get_snapshot()
	var restored_hazards: Variant = HazardController.new()
	restored_hazards.setup([
		{
			"id": "arc_field",
			"cells": [Vector2i(3, 3), [3, 4]],
			"warning_turn": 1,
			"damage_turn": 2,
			"cycle_length": 3,
			"damage": 2,
			"close_action_id": "seal_arc_field",
		},
	], Vector2i(8, 8))
	var restore_result: Dictionary = restored_hazards.restore_snapshot(snapshot)
	t.check(bool(restore_result.get("success", false)) and bool(restored_hazards.get_snapshot().closed_ids.get("arc_field", false)), "危险区快照恢复保留永久关闭状态")

	var before_invalid: Dictionary = restored_hazards.get_snapshot()
	var invalid_snapshot: Dictionary = before_invalid.duplicate(true)
	invalid_snapshot.closed_ids = {"unknown_arc": true}
	var invalid_restore: Dictionary = restored_hazards.restore_snapshot(invalid_snapshot)
	t.check(not bool(invalid_restore.get("success", true)) and restored_hazards.get_snapshot() == before_invalid, "危险区恢复拒绝未知 ID 并回滚状态")
	t.finish(self)

func _has_turn_result_contract(result: Dictionary) -> bool:
	return result.has("warning_cells") \
		and result.has("active_cells") \
		and result.has("closed") \
		and result.has("cycle") \
		and result.has("damage_events")
