extends RefCounted
class_name V2DamagePresenter

## V2 确定性伤害表现层。
## 规则服务负责数值，本层只把预览和提交结果转换为可读、可测试的事件序列。

var last_played_events: Array[Dictionary] = []
var last_reduce_motion := false

func build_events(preview: Dictionary, result: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var attacker: Unit = preview.get("unit", null)
	var target: Unit = preview.get("target_unit", null)
	var context: Dictionary = preview.get("context", {})
	var hp_before := int(preview.get("hp_before", target.current_hp if target else 0))
	var hp_after := int(result.get("hp_after", preview.get("hp_after", target.current_hp if target else 0)))
	var final_damage := int(result.get("damage", preview.get("final_damage", 0)))
	var hp_damage := int(result.get("hp_damage", preview.get("hp_damage", 0)))
	var shield_absorb := int(preview.get("shield_absorb", 0))

	events.append({
		"type": &"attack_started",
		"attacker": attacker,
		"target": target,
		"text": "",
	})
	events.append({
		"type": &"hp_prestrip",
		"hp_before": hp_before,
		"hp_after": hp_after,
		"text": "HP %d → %d" % [hp_before, hp_after],
	})

	var reductions: Array[String] = []
	var cover_reduction := int(preview.get("cover_reduction", 0))
	var armor_reduction := int(preview.get("armor_reduction", 0))
	if cover_reduction > 0:
		reductions.append("掩体 -%d" % cover_reduction)
	if armor_reduction > 0:
		reductions.append("护甲 -%d" % armor_reduction)
	if not reductions.is_empty():
		events.append({
			"type": &"reduction",
			"text": " · ".join(reductions),
			"cover_reduction": cover_reduction,
			"armor_reduction": armor_reduction,
		})

	if shield_absorb > 0:
		events.append({
			"type": &"shield_absorb",
			"amount": shield_absorb,
			"text": "护盾 -%d" % shield_absorb,
		})
	events.append({
		"type": &"damage_number",
		"amount": hp_damage,
		"final_damage": final_damage,
		"text": str(hp_damage),
		"display_text": "-%d" % hp_damage,
	})
	if hp_after <= 0 or (target != null and not target.is_alive):
		events.append({
			"type": &"unit_downed",
			"target": target,
			"text": "倒地",
		})
	events.append({
		"type": &"attack_finished",
		"attacker": attacker,
		"target": target,
		"text": "",
	})
	return events

func play_attack(events: Array[Dictionary], reduce_motion: bool) -> void:
	last_played_events = events.duplicate(true)
	last_reduce_motion = reduce_motion
	for event in events:
		var event_type := StringName(String(event.get("type", "")))
		var attacker_sprite: Node = event.get("attacker_sprite", null) as Node
		var target_sprite: Node = event.get("target_sprite", null) as Node
		match event_type:
			&"attack_started":
				if attacker_sprite and attacker_sprite.has_method("play_state"):
					var attacker: Unit = event.get("attacker", null)
					var target: Unit = event.get("target", null)
					var direction := Vector2.RIGHT
					if attacker and target:
						direction = Vector2(target.grid_pos - attacker.grid_pos)
					attacker_sprite.play_state(&"attack", direction, 0.12 if reduce_motion else -1.0)
			&"hp_prestrip":
				if target_sprite and target_sprite.has_method("show_hp_prestrip"):
					target_sprite.show_hp_prestrip(int(event.get("hp_before", 0)), int(event.get("hp_after", 0)))
			&"reduction":
				_show_feedback(target_sprite, String(event.get("text", "")), Color(1.0, 0.76, 0.30))
			&"shield_absorb":
				_show_feedback(target_sprite, String(event.get("text", "")), Color(0.30, 0.88, 1.0))
			&"damage_number":
				if target_sprite and target_sprite.has_method("play_state"):
					target_sprite.play_state(&"hit", Vector2.LEFT, 0.10 if reduce_motion else -1.0)
				_show_feedback(target_sprite, String(event.get("display_text", event.get("text", ""))), Color(1.0, 0.38, 0.28))
			&"unit_downed":
				if target_sprite and target_sprite.has_method("play_death"):
					target_sprite.play_death(0.18 if reduce_motion else -1.0)

func _show_feedback(sprite: Node, text: String, color: Color) -> void:
	if sprite and sprite.has_method("show_combat_feedback") and text != "":
		sprite.show_combat_feedback(text, color)
