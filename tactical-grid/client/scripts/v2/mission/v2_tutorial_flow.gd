extends RefCounted
class_name V2TutorialFlow

## M1 onboarding is a single non-modal hint at a time. The hint is anchored by
## kind/id metadata so the presentation layer can keep it near the relevant
## unit, cell, enemy, or intent without letting it consume map input.
const STEPS: Array[StringName] = [
	&"select",
	&"move",
	&"attack_preview",
	&"attack",
	&"intent",
]

const COPY := {
	&"select": "选择突击兵",
	&"move": "点击青色格移动",
	&"attack_preview": "悬停红框敌人查看伤害",
	&"attack": "点击敌人发动攻击",
	&"intent": "敌人的箭头表示下一步行动",
}

const EXPECTED_EVENTS := {
	&"select": &"unit_selected",
	&"move": &"unit_moved",
	&"attack_preview": &"attack_previewed",
	&"attack": &"attack_committed",
	&"intent": &"enemy_intent_observed",
}

const DEFAULT_ANCHORS := {
	&"select": {"kind": "unit", "id": "selected_unit"},
	&"move": {"kind": "cell", "id": "reachable_cell"},
	&"attack_preview": {"kind": "enemy", "id": "hovered_enemy"},
	&"attack": {"kind": "enemy", "id": "locked_enemy"},
	&"intent": {"kind": "intent", "id": "enemy_intent"},
}

var _step_index := 0
var _skipped := false
var _complete := false
var _safe_tutorial_complete := false
var _safe_turns := 3
var _anchors: Dictionary = {}
var _committed_attack_seen := false
var _intent_seen := false

func setup(config: Dictionary = {}) -> void:
	_step_index = 0
	_skipped = false
	_complete = false
	_safe_tutorial_complete = false
	_safe_turns = maxi(1, int(config.get("safe_turns", 3)))
	_committed_attack_seen = false
	_intent_seen = false
	_anchors = DEFAULT_ANCHORS.duplicate(true)
	var configured_anchors: Variant = config.get("anchors", {})
	if configured_anchors is Dictionary:
		for step in (configured_anchors as Dictionary).keys():
			if configured_anchors[step] is Dictionary:
				_anchors[StringName(step)] = configured_anchors[step].duplicate(true)

func current_step() -> StringName:
	if _complete or _skipped:
		return &""
	return STEPS[_step_index]

func current_text() -> String:
	return String(COPY.get(current_step(), ""))

func get_hint() -> Dictionary:
	var step := current_step()
	if step == &"":
		return {
			"visible": false,
			"anchor_kind": "",
			"anchor_id": "",
			"text": "",
			"step_id": "",
		}
	var anchor: Dictionary = _anchors.get(step, {}).duplicate(true)
	return {
		"visible": true,
		"anchor_kind": String(anchor.get("kind", "")),
		"anchor_id": String(anchor.get("id", "")),
		"text": current_text(),
		"step_id": String(step),
	}

func get_visible_hint_count() -> int:
	return 0 if _complete or _skipped else 1

func is_complete() -> bool:
	return _complete

func is_skipped() -> bool:
	return _skipped

func is_m1_safe_tutorial_complete() -> bool:
	return _safe_tutorial_complete

func restore_m1_safe_tutorial_complete(value: bool) -> void:
	_safe_tutorial_complete = value
	if value:
		_complete = true
		_step_index = STEPS.size()

func is_m1_safety_active(player_turn: int) -> bool:
	return not _skipped and not _safe_tutorial_complete and player_turn >= 1 and player_turn <= _safe_turns

func set_anchor(step_id: StringName, anchor_kind: String, anchor_id: String) -> void:
	if step_id == &"" or anchor_kind.is_empty() or anchor_id.is_empty():
		return
	_anchors[step_id] = {"kind": anchor_kind, "id": anchor_id}

## A matching event advances at most one step. Attack and intent are also
## tracked independently because together they close the M1 safety window.
func on_event(event_name: StringName, payload: Dictionary = {}) -> Dictionary:
	if event_name == &"attack_committed":
		_committed_attack_seen = true
	if event_name == &"enemy_intent_observed":
		_intent_seen = true
	_safe_tutorial_complete = _committed_attack_seen and _intent_seen
	if _complete or _skipped:
		return {
			"advanced": false,
			"reason": &"tutorial_inactive",
			"current_step": current_step(),
			"m1_safe_tutorial_complete": _safe_tutorial_complete,
		}
	var current := current_step()
	var expected: StringName = EXPECTED_EVENTS.get(current, &"")
	if event_name != expected:
		return {
			"advanced": false,
			"reason": &"wrong_step_event",
			"current_step": current_step(),
			"m1_safe_tutorial_complete": _safe_tutorial_complete,
		}
	var completed_step := current
	_step_index += 1
	if payload.has("anchor_id") and _step_index < STEPS.size():
		var next_step := STEPS[_step_index]
		var next_anchor: Dictionary = _anchors.get(next_step, {}).duplicate(true)
		next_anchor["id"] = String(payload.get("anchor_id", next_anchor.get("id", ""))) if next_anchor.get("kind", "") in ["enemy", "intent"] else next_anchor.get("id", "")
		_anchors[next_step] = next_anchor
	if _step_index >= STEPS.size():
		_complete = true
	return {
		"advanced": true,
		"completed_step": completed_step,
		"dismiss_hint": true,
		"show_hint": not _complete,
		"current_step": current_step(),
		"m1_safe_tutorial_complete": _safe_tutorial_complete,
	}

func skip() -> Dictionary:
	if _complete:
		return {"skipped": false, "reason": &"tutorial_complete"}
	_skipped = true
	return {
		"skipped": true,
		"dismiss_hint": true,
		"current_step": &"",
		"m1_safe_tutorial_complete": _safe_tutorial_complete,
	}
