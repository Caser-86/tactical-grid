extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2ActionService = preload("res://scripts/v2/combat/v2_action_service.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var map_data := {
		"size": {"width": 8, "height": 8},
		"layers": {"base_terrain": [], "blocker": [], "vision": [], "height": [], "cover": []},
	}
	var attacker = _make_unit("attacker", "player", Vector2i(1, 1), 6)
	var target = _make_unit("target", "enemy", Vector2i(3, 1), 4)
	attacker.weapon_range = [1, 5]
	attacker.weapon_damage = [3, 3]
	var service = V2ActionService.new()
	service.setup(map_data, [attacker], [target])

	var move: Dictionary = service.query_action({"action": &"move", "unit": attacker, "target": Vector2i(2, 1)})
	t.check(bool(move.get("valid", false)) and int(move.get("preview_id", 0)) > 0, "移动预览有效")
	t.check(bool(service.validate_action(move).get("valid", false)), "未变化移动预览可提交")
	var moved: Dictionary = service.commit_action(move)
	t.check(bool(moved.get("success", false)) and attacker.grid_pos == Vector2i(2, 1), "移动提交更新位置")
	t.check(not attacker.can_move() and attacker.can_act(), "移动只消费移动预算")
	var moved_again: Dictionary = service.commit_action(move)
	t.check(not bool(moved_again.get("success", true)) and moved_again.get("reason", &"") == &"already_committed", "移动预览不能重复提交")

	var attack: Dictionary = service.query_action({"action": &"attack", "unit": attacker, "target": target})
	t.check(bool(attack.get("valid", false)), "攻击预览有效")
	target.grid_pos = Vector2i(7, 7)
	var stale: Dictionary = service.validate_action(attack)
	t.check(not bool(stale.get("valid", true)) and stale.get("reason", &"") == &"stale_preview", "目标变化后拒绝提交")
	t.check(attacker.can_act() and target.current_hp == 4, "陈旧预览不消费行动或伤害")
	var stale_commit: Dictionary = service.commit_action(attack)
	t.check(not bool(stale_commit.get("success", true)) and stale_commit.get("reason", &"") == &"stale_preview", "提交陈旧预览返回失败")

	target.grid_pos = attacker.grid_pos
	var overlap_result: Dictionary = service.query_action({"action": &"attack", "unit": attacker, "target": target})
	t.check(not bool(overlap_result.get("valid", true)) and overlap_result.get("reason", &"") == &"same_position", "同格攻击被明确拒绝")

	target.grid_pos = Vector2i(3, 1)
	var valid_attack: Dictionary = service.query_action({"action": &"attack", "unit": attacker, "target": target})
	var attack_result: Dictionary = service.commit_action(valid_attack)
	t.check(bool(attack_result.get("success", false)) and target.current_hp == 1, "攻击提交应用确定性伤害")
	t.check(not attacker.can_act() and not attacker.can_move(), "移动后攻击消费行动预算")
	var duplicate_attack: Dictionary = service.commit_action(valid_attack)
	t.check(not bool(duplicate_attack.get("success", true)) and duplicate_attack.get("reason", &"") == &"already_committed", "攻击预览不能重复提交")

	var unknown: Dictionary = service.query_action({"action": &"teleport", "unit": attacker, "target": Vector2i(4, 4)})
	t.check(not bool(unknown.get("valid", true)) and unknown.get("reason", &"") == &"unknown_action", "未知动作被拒绝")
	var cancelled: Dictionary = service.query_action({"action": &"move", "unit": attacker, "target": Vector2i(2, 2)})
	service.cancel_preview(int(cancelled.get("preview_id", 0)))
	t.check(service.validate_action(cancelled).get("reason", &"") == &"unknown_preview", "取消预览后不能提交")

	attacker.queue_free()
	target.queue_free()
	t.finish(self)

func _make_unit(id: String, team: String, position: Vector2i, hp: int):
	var unit = UnitScript.new()
	unit.entity_id = id
	unit.team = team
	unit.grid_pos = position
	unit.max_hp = hp
	unit.current_hp = hp
	unit.is_alive = true
	unit.enable_v2_turn_mode()
	return unit
