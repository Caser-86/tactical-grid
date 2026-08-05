extends RefCounted
class_name V2SquadSelection

const ROLE_ORDER := ["assault", "scout", "sniper", "heavy"]

static func get_available_characters(save: Dictionary) -> Array[String]:
	var rescued: Array = save.get("rescued_characters", [])
	var result: Array[String] = []
	for character_id in ROLE_ORDER:
		if character_id in rescued:
			result.append(character_id)
	return result

static func get_default_squad(mission: Dictionary, save: Dictionary) -> Array[String]:
	var available := get_available_characters(save)
	var allowed: Array = mission.get("starting_roster", [])
	var result: Array[String] = []
	for character_id in allowed:
		var id := String(character_id)
		if id in available and not id in result:
			result.append(id)
		if result.size() >= int(mission.get("deployment_limit", result.size())):
			break
	if result.is_empty() and "assault" in available:
		result.append("assault")
	return result

static func validate_squad(mission: Dictionary, character_ids: Array) -> Dictionary:
	var allowed: Array = mission.get("starting_roster", [])
	var limit := maxi(1, int(mission.get("deployment_limit", allowed.size())))
	if character_ids.is_empty():
		return {"valid": false, "reason": &"empty_squad"}
	if character_ids.size() > limit:
		return {"valid": false, "reason": &"deployment_limit", "limit": limit}
	var seen: Dictionary = {}
	for raw_id in character_ids:
		var id := String(raw_id)
		if id.is_empty() or seen.has(id):
			return {"valid": false, "reason": &"duplicate_character", "character_id": id}
		if not id in allowed:
			return {"valid": false, "reason": &"character_not_in_mission", "character_id": id}
		seen[id] = true
	return {"valid": true, "character_ids": seen.keys(), "limit": limit}

static func validate_squad_for_save(mission: Dictionary, character_ids: Array, save: Dictionary) -> Dictionary:
	var result := validate_squad(mission, character_ids)
	if not bool(result.get("valid", false)):
		return result
	var available := get_available_characters(save)
	for raw_id in character_ids:
		if not String(raw_id) in available:
			return {"valid": false, "reason": &"character_locked", "character_id": String(raw_id)}
	return result
