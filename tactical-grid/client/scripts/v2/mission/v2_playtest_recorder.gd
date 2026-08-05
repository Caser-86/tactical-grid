extends RefCounted
class_name V2PlaytestRecorder

const SCHEMA_VERSION := "1.0"
const MISSION_ID := "ch1_m1"
const OUTPUT_ROOT := "user://playtests/m1"
const EVENT_TYPES := [
	&"session_started",
	&"unit_selected",
	&"move_committed",
	&"attack_committed",
	&"hint_shown",
	&"stuck_marked",
	&"scout_rescued",
	&"mission_failed",
	&"mission_completed",
	&"session_ended",
]
const FORBIDDEN_FIELD_PARTS := [
	"player_name",
	"machine_name",
	"account",
	"username",
	"email",
	"ip_address",
	"device_id",
	"os_user",
	"system_name",
]

var _session: Dictionary = {}
var _started_ticks := 0
var _event_sequence := 0
var _active := false
var _last_save: Dictionary = {"success": false, "path": "", "error": "not_saved"}

func start(participant_id: String, difficulty: String = "standard") -> Dictionary:
	var normalized_id := participant_id.strip_edges().to_upper()
	if normalized_id.is_empty():
		return _failure("participant_id_required")
	if not _is_anonymous_id(normalized_id):
		return _failure("participant_id_must_match_PNN")
	if difficulty.strip_edges().is_empty():
		return _failure("difficulty_required")

	_started_ticks = Time.get_ticks_msec()
	_event_sequence = 0
	_active = true
	_last_save = {"success": false, "path": "", "error": "not_saved"}
	_session = {
		"schema_version": SCHEMA_VERSION,
		"mission_id": MISSION_ID,
		"participant_id": normalized_id,
		"difficulty": difficulty.strip_edges().to_lower(),
		"events": [],
		"result": {},
		"completed": false,
	}
	var started_result := record(&"session_started", {"difficulty": _session["difficulty"]})
	if not bool(started_result.get("success", false)):
		_active = false
		_session = {}
		return _failure("session_started_event_failed")
	return {"success": true, "participant_id": normalized_id, "mission_id": MISSION_ID}

func start_from_cmdline(args: Array, difficulty: String = "standard") -> Dictionary:
	var participant_id := participant_id_from_cmdline(args)
	if participant_id.is_empty():
		return {"success": false, "enabled": false, "error": "playtest_disabled"}
	var result := start(participant_id, difficulty)
	result["enabled"] = bool(result.get("success", false))
	return result

static func participant_id_from_cmdline(args: Array) -> String:
	for raw_arg in args:
		var arg := String(raw_arg)
		if not arg.begins_with("--v2-playtest-id="):
			continue
		var candidate := arg.trim_prefix("--v2-playtest-id=").strip_edges().to_upper()
		return candidate if _is_anonymous_id(candidate) else ""
	return ""

func record(event_type: StringName, payload: Dictionary = {}) -> Dictionary:
	if not _active:
		return _failure("session_not_active")
	if not event_type in EVENT_TYPES:
		return _failure("unknown_event")
	if _contains_forbidden_field(payload):
		return _failure("privacy_field_rejected")

	var event_payload := payload.duplicate(true)
	var event := {
		"sequence": _event_sequence,
		"type": String(event_type),
		"elapsed_ms": maxi(0, Time.get_ticks_msec() - _started_ticks),
		"payload": event_payload,
	}
	_event_sequence += 1
	(_session["events"] as Array).append(event)
	return {"success": true, "event": event.duplicate(true)}

func finish(result: Dictionary = {}) -> Dictionary:
	if not _active:
		return _session.duplicate(true)
	if _contains_forbidden_field(result):
		result = {"finish_error": "privacy_field_rejected"}
	var end_event := record(&"session_ended", {"completed": bool(result.get("completed", false))})
	if not bool(end_event.get("success", false)):
		return _session.duplicate(true)
	_session["result"] = result.duplicate(true)
	_session["completed"] = true
	_session["ended_elapsed_ms"] = maxi(0, Time.get_ticks_msec() - _started_ticks)
	_active = false
	_last_save = save()
	return _session.duplicate(true)

func get_session() -> Dictionary:
	return _session.duplicate(true)

func save(path: String = "") -> Dictionary:
	if _session.is_empty():
		_last_save = _failure("session_not_started")
		return _last_save.duplicate(true)
	var target_path := path.strip_edges()
	if target_path.is_empty():
		target_path = "%s/%s.json" % [OUTPUT_ROOT, String(_session.get("participant_id", "UNKNOWN"))]
	var directory_path := target_path.get_base_dir()
	var directory := DirAccess.open("user://")
	if directory == null:
		_last_save = _failure("user_directory_unavailable")
		return _last_save.duplicate(true)
	var make_dir_error := directory.make_dir_recursive(directory_path.trim_prefix("user://"))
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_last_save = {"success": false, "path": target_path, "error": error_string(make_dir_error)}
		return _last_save.duplicate(true)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		_last_save = {"success": false, "path": target_path, "error": error_string(FileAccess.get_open_error())}
		return _last_save.duplicate(true)
	file.store_string(JSON.stringify(_session, "  "))
	file.close()
	_last_save = {"success": true, "path": target_path, "error": ""}
	return _last_save.duplicate(true)

func get_last_save() -> Dictionary:
	return _last_save.duplicate(true)

static func _is_anonymous_id(value: String) -> bool:
	if value.length() < 3 or value.length() > 8 or not value.begins_with("P"):
		return false
	for index in range(1, value.length()):
		if not value[index] in "0123456789":
			return false
	return true

func _contains_forbidden_field(value: Variant) -> bool:
	if value is Dictionary:
		for key in value.keys():
			var normalized_key := String(key).to_lower()
			for forbidden in FORBIDDEN_FIELD_PARTS:
				if normalized_key.contains(forbidden):
					return true
			if _contains_forbidden_field(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_field(item):
				return true
	return false

func _failure(error_code: String) -> Dictionary:
	return {"success": false, "error": error_code}
