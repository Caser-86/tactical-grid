extends RefCounted
class_name V2TutorialFlow

## M1 onboarding is a small deterministic state machine, not a queue of long
## keybind paragraphs. Each action unlocks exactly one next instruction.
const STEPS: Array[StringName] = [
	&"select",
	&"move",
	&"attack",
	&"intent",
	&"camera",
	&"evac",
]

const COPY := {
	&"select": "点击突击兵查看可行动范围",
	&"move": "点击蓝色格移动",
	&"attack": "悬停查看伤害，点击红色敌人攻击",
	&"intent": "箭头显示敌人下一步",
	&"camera": "靠近控制台查看摄像头",
	&"evac": "两名队员进入撤离区",
}

const EXPECTED_EVENTS := {
	&"select": &"unit_selected",
	&"move": &"unit_moved",
	&"attack": &"attack_committed",
	&"intent": &"enemy_intent_observed",
	&"camera": &"camera_viewed",
	&"evac": &"evac_completed",
}

var _step_index := 0
var _skipped := false
var _complete := false

func setup(_config: Dictionary = {}) -> void:
	_step_index = 0
	_skipped = false
	_complete = false

func current_step() -> StringName:
	if _complete or _skipped:
		return &""
	return STEPS[_step_index]

func current_text() -> String:
	return String(COPY.get(current_step(), ""))

func get_visible_hint_count() -> int:
	return 0 if _complete or _skipped else 1

func is_complete() -> bool:
	return _complete

func is_skipped() -> bool:
	return _skipped

## Advance only when the event belongs to the current step. Payload is kept in
## the contract so future steps can require a specific unit or facility.
func on_event(event_name: StringName, _payload: Dictionary = {}) -> Dictionary:
	if _complete or _skipped:
		return {
			"advanced": false,
			"reason": &"tutorial_inactive",
			"current_step": current_step(),
		}
	var expected: StringName = EXPECTED_EVENTS.get(current_step(), &"")
	if event_name != expected:
		return {
			"advanced": false,
			"reason": &"wrong_step_event",
			"current_step": current_step(),
		}
	var completed_step := current_step()
	_step_index += 1
	if _step_index >= STEPS.size():
		_complete = true
	return {
		"advanced": true,
		"completed_step": completed_step,
		"dismiss_hint": true,
		"show_hint": not _complete,
		"current_step": current_step(),
	}

func skip() -> Dictionary:
	if _complete:
		return {"skipped": false, "reason": &"tutorial_complete"}
	_skipped = true
	return {
		"skipped": true,
		"dismiss_hint": true,
		"current_step": &"",
	}
