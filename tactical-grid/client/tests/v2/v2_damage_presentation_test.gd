extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const PresenterScript = preload("res://scripts/v2/presentation/v2_damage_presenter.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	var presenter := PresenterScript.new()
	var attacker := _make_unit("attacker", "player", Vector2i(1, 1), 7)
	var target := _make_unit("target", "enemy", Vector2i(3, 1), 7)

	var covered_preview := {
		"unit": attacker,
		"target_unit": target,
		"attacker_pos": attacker.grid_pos,
		"target_pos": target.grid_pos,
		"hp_before": 7,
		"hp_after": 5,
		"final_damage": 2,
		"hp_damage": 2,
		"cover_reduction": 1,
		"armor_reduction": 0,
		"shield_absorb": 0,
		"context": {"cover": "half"},
	}
	var covered_events: Array[Dictionary] = presenter.build_events(covered_preview, {"damage": 2, "hp_damage": 2})
	t.check(_event_types(covered_events) == ["attack_started", "projectile_or_trace", "hp_prestrip", "reduction", "damage_number", "attack_finished"], "掩体攻击的反馈顺序固定")
	var trace := _event(covered_events, &"projectile_or_trace")
	t.check(trace.get("from", Vector2i(-1, -1)) == attacker.grid_pos and trace.get("to", Vector2i(-1, -1)) == target.grid_pos, "攻击射线在扣血前携带真实起点和终点")
	t.check(_event_text(covered_events, &"reduction").contains("掩体 -1"), "反馈显示掩体减伤来源")
	t.check(_event_text(covered_events, &"damage_number") == "-2", "反馈显示带负号的生命伤害数字")

	var shield_preview := covered_preview.duplicate(true)
	shield_preview["hp_after"] = 7
	shield_preview["hp_damage"] = 0
	shield_preview["final_damage"] = 3
	shield_preview["shield_absorb"] = 3
	var shield_events: Array[Dictionary] = presenter.build_events(shield_preview, {"damage": 3, "hp_damage": 0})
	t.check(&"shield_absorb" in _event_types(shield_events), "反馈单独显示护盾吸收")
	t.check(_event_text(shield_events, &"shield_absorb").contains("护盾 -3"), "反馈显示护盾吸收数值")

	target.is_alive = false
	var down_preview := covered_preview.duplicate(true)
	down_preview["hp_after"] = 0
	down_preview["intent_changed"] = true
	var down_events: Array[Dictionary] = presenter.build_events(down_preview, {"damage": 2, "hp_damage": 2, "occupancy_released": true, "intent_changed": true})
	t.check(&"unit_downed" in _event_types(down_events), "生命归零后显示倒地事件")
	t.check(_event_types(down_events) == ["attack_started", "projectile_or_trace", "hp_prestrip", "reduction", "damage_number", "intent_changed", "unit_downed", "attack_finished"], "倒地攻击在结束前完成意图取消和占位释放链")
	t.check(_event_text(down_events, &"damage_number") == "-2", "倒地攻击仍显示精确伤害数字")
	var intent_change := _event(down_events, &"intent_changed")
	t.check(bool(intent_change.get("cancelled", false)), "倒地时意图明确标记为已取消")
	var down_event := _event(down_events, &"unit_downed")
	t.check(bool(down_event.get("occupancy_released", false)), "倒地完成在攻击结束前释放占位")
	t.check(_event_count(down_events, &"unit_downed") == 1, "一次攻击只发出一次倒地事件")
	presenter.play_attack(covered_events, true)
	t.check(presenter.last_played_events.size() == covered_events.size(), "表现层按事件序列播放")
	t.check(presenter.last_reduce_motion, "减少动态设置被传入表现层")

	attacker.free()
	target.free()
	t.finish(self)

func _make_unit(id: String, team: String, position: Vector2i, hp: int) -> Unit:
	var unit: Unit = UnitScript.new()
	unit.entity_id = id
	unit.unit_name = id
	unit.team = team
	unit.grid_pos = position
	unit.current_hp = hp
	unit.max_hp = hp
	unit.is_alive = true
	return unit

func _event_types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event in events:
		types.append(String(event.get("type", "")))
	return types

func _event_text(events: Array[Dictionary], event_type: StringName) -> String:
	return String(_event(events, event_type).get("text", ""))

func _event(events: Array[Dictionary], event_type: StringName) -> Dictionary:
	for event in events:
		if StringName(String(event.get("type", ""))) == event_type:
			return event
	return {}

func _event_count(events: Array[Dictionary], event_type: StringName) -> int:
	var count := 0
	for event in events:
		if StringName(String(event.get("type", ""))) == event_type:
			count += 1
	return count
