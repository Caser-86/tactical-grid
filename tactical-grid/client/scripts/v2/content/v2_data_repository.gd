extends Node
class_name V2DataRepository

const FILES := {
	"characters": "res://data/v2/characters.json",
	"enemies": "res://data/v2/enemies.json",
	"abilities": "res://data/v2/abilities.json",
	"modules": "res://data/v2/modules.json",
	"missions": "res://data/v2/missions.json",
	"dialogues": "res://data/v2/dialogues.json",
}

var _documents: Dictionary = {}
var _errors: Array[String] = []

func reload_all() -> Dictionary:
	_documents.clear()
	_errors.clear()
	for key in FILES:
		var path: String = FILES[key]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_errors.append("Missing V2 data file: %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			_errors.append("Invalid V2 JSON object: %s" % path)
			continue
		_documents[key] = parsed
	_errors.append_array(V2SchemaValidator.validate_all(_documents))
	return {"success": _errors.is_empty(), "errors": _errors.duplicate()}

func get_character(id: StringName) -> Dictionary:
	return _get_record("characters", id)

func get_enemy(id: StringName) -> Dictionary:
	return _get_record("enemies", id)

func get_ability(id: StringName) -> Dictionary:
	return _get_record("abilities", id)

func get_module(id: StringName) -> Dictionary:
	return _get_record("modules", id)

func get_mission(id: StringName) -> Dictionary:
	return _get_record("missions", id)

func get_dialogue(id: StringName) -> Dictionary:
	return _get_record("dialogues", id)

func get_errors() -> Array[String]:
	return _errors.duplicate()

func _get_record(kind: String, id: StringName) -> Dictionary:
	var document: Variant = _documents.get(kind, {})
	if not document is Dictionary:
		return {}
	var value: Variant = document.get(String(id), {})
	if not value is Dictionary:
		return {}
	return value.duplicate(true)
