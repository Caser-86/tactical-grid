## Alert state system.
## V1 keeps the four-level alert ladder. V2 missions can configure a smaller,
## persistent front-state ladder without changing the legacy rules.
extends Node
class_name AlertState

signal level_changed(old_level: int, new_level: int)

## Alert level constants
const LEVEL_CALM := 0
const LEVEL_SUSPICIOUS := 1
const LEVEL_ALERT := 2
const LEVEL_COMBAT := 3

## Event to alert level mapping
var _event_alert_map: Dictionary = {}
## Consequence descriptions per alert level
var _consequences: Dictionary = {}

var _current_level: int = LEVEL_CALM
var _turns_at_current_level: int = 0
var _front_stage_cap: int = LEVEL_COMBAT
var _decay_enabled: bool = true
var _allowed_events: Dictionary = {}
var _grace_events_remaining: int = 0


## Setup initial state and lookup tables.
## Optional V2 config supports a bounded front state, an event allow-list,
## persistent search and a story-difficulty first-event grace.
func setup(config: Dictionary = {}) -> void:
	_current_level = LEVEL_CALM
	_turns_at_current_level = 0
	_front_stage_cap = clampi(int(config.get("front_stage_cap", LEVEL_COMBAT)), LEVEL_CALM, LEVEL_COMBAT)
	_decay_enabled = bool(config.get("decay_enabled", true))
	_grace_events_remaining = maxi(0, int(config.get("story_grace_events", 0)))
	_allowed_events.clear()
	var configured_events: Variant = config.get("allowed_events", [])
	if configured_events is Array:
		for event_name in configured_events:
			_allowed_events[String(event_name)] = true
	_event_alert_map = {
		"noise_detected": LEVEL_SUSPICIOUS,
		"enemy_spotted": LEVEL_ALERT,
		"combat_started": LEVEL_COMBAT,
		"overload_triggered": LEVEL_SUSPICIOUS,
		"takeover_detected": LEVEL_ALERT,
		"body_found": LEVEL_COMBAT,
		"camera_identified_player": LEVEL_SUSPICIOUS,
		"drone_scan_completed": LEVEL_SUSPICIOUS,
	}
	_consequences = {
		0: {
			"description": "敌人按原路线巡逻",
			"reinforcement_bonus": 0,
			"aggression_bonus": 0.0,
		},
		1: {
			"description": "敌人调查最后目击位置",
			"reinforcement_bonus": 1,
			"aggression_bonus": 0.1,
		},
		2: {
			"description": "敌人主动追击，增援提前抵达",
			"reinforcement_bonus": 2,
			"aggression_bonus": 0.3,
		},
		3: {
			"description": "敌军全面集结，增援达到上限",
			"reinforcement_bonus": 3,
			"aggression_bonus": 0.5,
		},
	}


## Apply an event. Unknown or disallowed events are ignored explicitly.
func apply_event(event_name: String) -> Dictionary:
	var event_id := String(event_name)
	if not _allowed_events.is_empty() and not _allowed_events.has(event_id):
		return {
			"changed": false,
			"new_level": _current_level,
			"ignored": true,
			"reason": "event_not_allowed",
			"front_state": get_front_state(),
		}
	var target_level: int = int(_event_alert_map.get(event_id, -1))
	if target_level < 0:
		return {"changed": false, "new_level": _current_level, "front_state": get_front_state()}
	if _grace_events_remaining > 0 and target_level > _current_level:
		_grace_events_remaining -= 1
		return {
			"changed": false,
			"new_level": _current_level,
			"grace": true,
			"front_state": get_front_state(),
		}

	var old_level := _current_level
	_current_level = mini(maxi(_current_level, target_level), _front_stage_cap)
	if _current_level != old_level:
		_turns_at_current_level = 0
		level_changed.emit(old_level, _current_level)
	return {
		"changed": _current_level != old_level,
		"new_level": _current_level,
		"front_state": get_front_state(),
	}


## Get current alert level.
func get_alert_level() -> int:
	return _current_level

## V2 front-state contract: the player only needs to distinguish hidden and
## searching in M1, even though the legacy backend retains numeric levels.
func get_front_state() -> StringName:
	return &"hidden" if _current_level <= LEVEL_CALM else &"searching"

func get_front_state_label() -> String:
	return "潜伏" if get_front_state() == &"hidden" else "搜索"

func get_front_state_description() -> String:
	if get_front_state() == &"hidden":
		return "被识别后进入搜索"
	return "巡逻路线已改变：敌人会调查最后目击位置"


## Get the consequence description for the current alert level.
func get_consequence() -> Dictionary:
	return _consequences.get(_current_level, _consequences[0]).duplicate(true)


## Get the next concrete consequence (what happens if alert rises or at next turn).
func get_next_consequence() -> Dictionary:
	if _front_stage_cap <= LEVEL_SUSPICIOUS:
		if _current_level <= LEVEL_CALM:
			return {
				"description": "被识别后进入搜索",
				"turns_until": 0,
				"next_level": LEVEL_SUSPICIOUS,
			}
		return {
			"description": "巡逻路线已改变：敌人会调查最后目击位置",
			"turns_until": 0,
			"next_level": LEVEL_SUSPICIOUS,
		}
	if _current_level >= LEVEL_COMBAT:
		return {
			"description": "警报已达上限：所有敌人进入战斗",
			"turns_until": 0,
		}
	var next_level := _current_level + 1
	var next_consequence: Dictionary = _consequences.get(next_level, {}).duplicate(true)
	return {
		"description": next_consequence.get("description", "未知后果"),
		"turns_until": 1,
		"next_level": next_level,
	}


## Called at end of each turn. V1 retains decay; V2 M1 can keep search stable
## so the player is not punished by a state that silently changes at a boundary.
func on_turn_end() -> void:
	if not _decay_enabled:
		return
	if _current_level == LEVEL_COMBAT:
		return
	_turns_at_current_level += 1
	var decay_threshold: int = 1 if _current_level == LEVEL_SUSPICIOUS else 2
	if _turns_at_current_level >= decay_threshold:
		var old_level := _current_level
		_current_level = maxi(_current_level - 1, LEVEL_CALM)
		_turns_at_current_level = 0
		if _current_level != old_level:
			level_changed.emit(old_level, _current_level)


## Get reinforcement bonus for current alert level.
func get_reinforcement_bonus() -> int:
	return int(get_consequence().get("reinforcement_bonus", 0))


## Get aggression bonus for current alert level.
func get_aggression_bonus() -> float:
	return float(get_consequence().get("aggression_bonus", 0.0))


## CODE-CH1-020: 序列化警戒状态为可 JSON 化字典（供 EncounterCheckpointState 使用）。
func serialize() -> Dictionary:
	return {
		"current_level": _current_level,
		"turns_at_current_level": _turns_at_current_level,
		"front_stage_cap": _front_stage_cap,
		"decay_enabled": _decay_enabled,
		"grace_events_remaining": _grace_events_remaining,
	}


## CODE-CH1-020: 从序列化字典恢复警戒状态。
func deserialize(data: Dictionary) -> void:
	_front_stage_cap = clampi(int(data.get("front_stage_cap", LEVEL_COMBAT)), LEVEL_CALM, LEVEL_COMBAT)
	_decay_enabled = bool(data.get("decay_enabled", true))
	_grace_events_remaining = maxi(0, int(data.get("grace_events_remaining", 0)))
	_current_level = mini(int(data.get("current_level", LEVEL_CALM)), _front_stage_cap)
	_turns_at_current_level = int(data.get("turns_at_current_level", 0))
