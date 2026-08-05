extends RefCounted
class_name V2MapLoader

const V2MapValidator = preload("res://scripts/v2/content/v2_map_validator.gd")
const ROOT := "res://data/v2/locked_maps/"

static func load_map(map_id: StringName) -> Dictionary:
	var id := String(map_id)
	var path := ROOT + id + ".json"
	if id.is_empty() or not FileAccess.file_exists(path):
		return {"success": false, "reason": &"map_missing", "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "reason": &"map_open_failed", "path": path}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"success": false, "reason": &"invalid_json", "path": path}
	var data: Dictionary = parsed
	var validation: Dictionary = V2MapValidator.validate(data)
	if not bool(validation.get("valid", false)):
		return {
			"success": false,
			"reason": &"invalid_schema",
			"path": path,
			"validation": validation,
		}
	return {"success": true, "data": data, "path": path, "validation": validation}
