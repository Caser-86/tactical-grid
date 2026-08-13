extends RefCounted
class_name V2TutorialFlow

## M1 onboarding is a soft hint track. It explains the controls in a useful
## order, but optional combat/observation hints never block the mission path.
const STEPS: Array[StringName] = [
	&"select",
	&"move",
	&"attack",
	&"intent",
	&"camera",
	&"evac",
]

const COPY := {
	&"select": "点击角色：蓝色可移动，红色可攻击",
	&"move": "点击蓝色格移动；右键取消预览",
	&"attack": "想攻击时点击红色敌人，悬停先看预计伤害",
	&"intent": "敌人头顶箭头是下一步动作（可选观察）",
	&"camera": "摄像头可揭示大片区域（可选操作）",
	&"evac": "沿黄色下一步标记推进；撤离时带上所有存活队员",
}

const EXPECTED_EVENTS := {
	&"select": &"unit_selected",
	&"move": &"unit_moved",
	&"attack": &"attack_committed",
	&"intent": &"enemy_intent_observed",
	&"camera": &"camera_viewed",
	&"evac": &"evac_completed",
}

const OPTIONAL_STEPS := [&"attack", &"intent", &"camera"]

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

## A matching event may complete a later hint: combat, intent and camera are
## optional teaching, not gates in the actual mission. Evacuation always closes
## the tutorial because it is the real end-of-mission action.
func on_event(event_name: StringName, _payload: Dictionary = {}) -> Dictionary:
	if _complete or _skipped:
		return {
			"advanced": false,
			"reason": &"tutorial_inactive",
			"current_step": current_step(),
		}
	if event_name == &"evac_completed":
		var completed_step := current_step()
		_complete = true
		return {
			"advanced": true,
			"completed_step": completed_step,
			"dismiss_hint": true,
			"show_hint": false,
			"current_step": &"",
		}
	var current := current_step()
	var expected_current: StringName = EXPECTED_EVENTS.get(current, &"")
	# Selection and movement teach the two primary actions in order. Only the
	# optional combat/observation hints may be reached by a later event.
	if current not in OPTIONAL_STEPS and event_name != expected_current:
		return {
			"advanced": false,
			"reason": &"wrong_step_event",
			"current_step": current_step(),
		}
	var matching_index := -1
	for index in range(_step_index, STEPS.size()):
		if StringName(EXPECTED_EVENTS.get(STEPS[index], &"")) == event_name:
			matching_index = index
			break
	if matching_index < 0:
		return {
			"advanced": false,
			"reason": &"wrong_step_event",
			"current_step": current_step(),
		}
	var completed_step := STEPS[matching_index]
	_step_index = matching_index + 1
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
