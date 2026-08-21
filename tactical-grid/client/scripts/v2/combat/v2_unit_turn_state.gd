extends RefCounted
class_name V2UnitTurnState

var move_available: bool = true
var action_available: bool = true
var cooldowns: Dictionary = {}

func begin_turn() -> void:
	move_available = true
	action_available = true
	for raw_id in cooldowns.keys():
		var id := String(raw_id)
		cooldowns[id] = maxi(0, int(cooldowns[raw_id]) - 1)

func can_move() -> bool:
	return move_available

func can_act() -> bool:
	return action_available

func spend_move() -> bool:
	if not move_available:
		return false
	move_available = false
	return true

func spend_action() -> bool:
	if not action_available:
		return false
	action_available = false
	return true

func set_cooldown(ability_id: StringName, turns: int) -> void:
	var id := String(ability_id)
	if id.is_empty():
		return
	if turns <= 0:
		cooldowns.erase(id)
		return
	cooldowns[id] = turns

func get_cooldown(ability_id: StringName) -> int:
	return maxi(0, int(cooldowns.get(String(ability_id), 0)))

func is_ability_ready(ability_id: StringName) -> bool:
	return get_cooldown(ability_id) == 0

func serialize() -> Dictionary:
	return {
		"move_available": move_available,
		"action_available": action_available,
		"cooldowns": cooldowns.duplicate(true),
	}

static func deserialize(data: Dictionary) -> RefCounted:
	var state_script: Script = ResourceLoader.load("res://scripts/v2/combat/v2_unit_turn_state.gd") as Script
	var state: RefCounted = state_script.new()
	state.move_available = bool(data.get("move_available", true))
	state.action_available = bool(data.get("action_available", true))
	var raw_cooldowns: Variant = data.get("cooldowns", {})
	if raw_cooldowns is Dictionary:
		for raw_id in raw_cooldowns.keys():
			state.cooldowns[String(raw_id)] = maxi(0, int(raw_cooldowns[raw_id]))
	return state
