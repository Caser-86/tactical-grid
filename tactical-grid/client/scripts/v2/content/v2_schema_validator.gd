extends RefCounted
class_name V2SchemaValidator

const DOCUMENT_KEYS := [
	&"characters",
	&"enemies",
	&"abilities",
	&"modules",
	&"missions",
	&"dialogues",
]

static func validate_all(documents: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in DOCUMENT_KEYS:
		if not documents.has(key):
			continue
		var document: Variant = documents[key]
		if not document is Dictionary:
			errors.append("%s root must be an object" % key)
			continue
		_validate_ids(String(key), document, errors)
	_validate_loaded_references(documents, errors)
	return errors

static func _validate_ids(kind: String, document: Dictionary, errors: Array[String]) -> void:
	for raw_id in document.keys():
		var id := String(raw_id)
		if id.is_empty():
			errors.append("%s contains an empty ID" % kind)
		var record: Variant = document[raw_id]
		if not record is Dictionary:
			errors.append("%s.%s must be an object" % [kind, id])
			continue
		if record.has("id") and String(record.id) != id:
			errors.append("%s.%s has mismatched id" % [kind, id])

static func _validate_loaded_references(documents: Dictionary, errors: Array[String]) -> void:
	var characters: Dictionary = documents.get("characters", {})
	var abilities: Dictionary = documents.get("abilities", {})
	var modules: Dictionary = documents.get("modules", {})
	var missions: Dictionary = documents.get("missions", {})
	var dialogues: Dictionary = documents.get("dialogues", {})
	for raw_id in characters.keys():
		var id := String(raw_id)
		var character: Dictionary = characters[raw_id]
		_validate_reference_if_loaded("characters.%s.ability_id" % id, character.get("ability_id", ""), abilities, errors)
		_validate_reference_if_loaded("characters.%s.passive_id" % id, character.get("passive_id", ""), abilities, errors)
		for module_id in character.get("module_ids", []):
			_validate_reference_if_loaded("characters.%s.module_ids" % id, module_id, modules, errors)
	for raw_id in missions.keys():
		var id := String(raw_id)
		var mission: Dictionary = missions[raw_id]
		for dialogue_id in mission.get("dialogue_ids", []):
			_validate_reference_if_loaded("missions.%s.dialogue_ids" % id, dialogue_id, dialogues, errors)

static func _validate_reference_if_loaded(
		field_name: String,
		reference: Variant,
		document: Dictionary,
		errors: Array[String]
) -> void:
	var reference_id := String(reference)
	if reference_id.is_empty() or document.is_empty():
		return
	if not document.has(reference_id):
		errors.append("%s references missing ID %s" % [field_name, reference_id])
