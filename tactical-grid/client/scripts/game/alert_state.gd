## Alert state system
## Tracks alert level (calm/suspicious/alert/combat) and manages consequences.
## Events raise alert; alert decays each turn unless at combat.
extends Node
class_name AlertState

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


## Setup initial state and lookup tables.
func setup() -> void:
	_current_level = LEVEL_CALM
	_turns_at_current_level = 0
	_event_alert_map = {
		"noise_detected": LEVEL_SUSPICIOUS,
		"enemy_spotted": LEVEL_ALERT,
		"combat_started": LEVEL_COMBAT,
		"overload_triggered": LEVEL_SUSPICIOUS,
		"takeover_detected": LEVEL_ALERT,
		"body_found": LEVEL_COMBAT,
	}
	_consequences = {
		0: {
			"description": "Enemies patrol normally",
			"reinforcement_bonus": 0,
			"aggression_bonus": 0.0,
		},
		1: {
			"description": "Enemies investigate last-known positions",
			"reinforcement_bonus": 1,
			"aggression_bonus": 0.1,
		},
		2: {
			"description": "Enemies actively hunt; reinforcements accelerated",
			"reinforcement_bonus": 2,
			"aggression_bonus": 0.3,
		},
		3: {
			"description": "All enemies converge; max reinforcements",
			"reinforcement_bonus": 3,
			"aggression_bonus": 0.5,
		},
	}


## Apply an event. Returns {changed: bool, new_level: int}.
func apply_event(event_name: String) -> Dictionary:
	var target_level: int = int(_event_alert_map.get(event_name, -1))
	if target_level < 0:
		return {"changed": false, "new_level": _current_level}

	var old_level := _current_level
	_current_level = maxi(_current_level, target_level)
	if _current_level != old_level:
		_turns_at_current_level = 0
	return {"changed": _current_level != old_level, "new_level": _current_level}


## Get current alert level.
func get_alert_level() -> int:
	return _current_level


## Get the consequence description for the current alert level.
func get_consequence() -> Dictionary:
	return _consequences.get(_current_level, _consequences[0]).duplicate(true)


## Get the next concrete consequence (what happens if alert rises or at next turn).
func get_next_consequence() -> Dictionary:
	if _current_level >= LEVEL_COMBAT:
		return {
			"description": "Alert at maximum: all enemies active",
			"turns_until": 0,
		}
	var next_level := _current_level + 1
	var next_consequence: Dictionary = _consequences.get(next_level, {}).duplicate(true)
	return {
		"description": next_consequence.get("description", "Unknown"),
		"turns_until": 1,
		"next_level": next_level,
	}


## Called at end of each turn. Alert decays one level unless at combat.
func on_turn_end() -> void:
	if _current_level == LEVEL_COMBAT:
		return
	_turns_at_current_level += 1
	var decay_threshold: int = 1 if _current_level == LEVEL_SUSPICIOUS else 2
	if _turns_at_current_level >= decay_threshold:
		_current_level = maxi(_current_level - 1, LEVEL_CALM)
		_turns_at_current_level = 0


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
	}


## CODE-CH1-020: 从序列化字典恢复警戒状态。
func deserialize(data: Dictionary) -> void:
	_current_level = int(data.get("current_level", LEVEL_CALM))
	_turns_at_current_level = int(data.get("turns_at_current_level", 0))
