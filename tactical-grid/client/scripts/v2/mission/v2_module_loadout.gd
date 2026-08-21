extends RefCounted
class_name V2ModuleLoadout

const MODULE_CHARACTER_IDS := {
	"assault_a": "assault", "assault_b": "assault",
	"scout_a": "scout", "scout_b": "scout",
	"sniper_a": "sniper", "sniper_b": "sniper",
	"heavy_a": "heavy", "heavy_b": "heavy",
}

static func get_available_modules(save: Dictionary, character_id: StringName) -> Array[String]:
	var id := String(character_id)
	var result: Array[String] = []
	for raw_module_id in save.get("unlocked_modules", []):
		var module_id := String(raw_module_id)
		if String(MODULE_CHARACTER_IDS.get(module_id, "")) == id:
			result.append(module_id)
	return result

static func equip(save: Dictionary, character_id: StringName, module_id: StringName) -> Dictionary:
	var id := String(character_id)
	var module := String(module_id)
	if id.is_empty() or module.is_empty():
		return {"success": false, "reason": &"missing_id"}
	if not id in save.get("rescued_characters", []):
		return {"success": false, "reason": &"character_locked", "character_id": id}
	if not module in save.get("unlocked_modules", []):
		return {"success": false, "reason": &"module_locked", "module_id": module}
	if String(MODULE_CHARACTER_IDS.get(module, "")) != id:
		return {"success": false, "reason": &"wrong_character", "module_id": module, "character_id": id}
	var equipped: Dictionary = save.get("equipped_modules", {}).duplicate(true)
	equipped[id] = module
	save["equipped_modules"] = equipped
	return {"success": true, "character_id": id, "module_id": module}

static func get_equipped(save: Dictionary, character_id: StringName) -> StringName:
	return StringName(String(save.get("equipped_modules", {}).get(String(character_id), "")))
