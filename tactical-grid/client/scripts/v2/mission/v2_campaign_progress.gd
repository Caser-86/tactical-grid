extends RefCounted
class_name V2CampaignProgress

const GAME_LINE := "v2_infiltration"
const SAVE_VERSION := "2.0.0"
const MISSION_ORDER := ["ch1_m1", "ch1_m2", "ch1_m3", "ch1_m4", "ch1_m5", "ch1_m6"]
const ROLE_IDS := ["assault", "scout", "sniper", "heavy"]

static func create_default() -> Dictionary:
	return {
		"game_line": GAME_LINE,
		"save_version": SAVE_VERSION,
		"current_mission": "ch1_m1",
		"completed_missions": [],
		"rescued_characters": ["assault"],
		"unlocked_modules": ["assault_a"],
		"equipped_modules": {"assault": "assault_a"},
		"story_flags": {},
		"settings": {
			"ui_scale": 1.0,
			"visual_mode": "normal",
			"fullscreen": false,
			"resolution": "1280x720",
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"pan_speed": 1.0,
			"screen_shake": true,
			"reduce_motion": false,
			"subtitle_speed": 1.0,
			"keybindings": {},
		},
		"encounter_checkpoint": {},
		"statistics": {},
		"chapter_complete": false,
	}

static func validate(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if String(data.get("game_line", "")) != GAME_LINE:
		errors.append("game_line must be %s" % GAME_LINE)
	if String(data.get("save_version", "")) != SAVE_VERSION:
		errors.append("save_version must be %s" % SAVE_VERSION)
	for key in ["current_mission", "completed_missions", "rescued_characters", "unlocked_modules", "equipped_modules", "story_flags", "settings", "encounter_checkpoint", "statistics", "chapter_complete"]:
		if not data.has(key):
			errors.append("missing field: %s" % key)
	if not data.get("completed_missions", []) is Array:
		errors.append("completed_missions must be an array")
	if not data.get("rescued_characters", []) is Array:
		errors.append("rescued_characters must be an array")
	if not data.get("unlocked_modules", []) is Array:
		errors.append("unlocked_modules must be an array")
	var current_mission := String(data.get("current_mission", ""))
	if not current_mission.is_empty() and not current_mission in MISSION_ORDER:
		errors.append("unknown current mission: %s" % current_mission)
	var rescued: Array = data.get("rescued_characters", [])
	if rescued is Array and not "assault" in rescued:
		errors.append("assault must remain available")
	return {"valid": errors.is_empty(), "errors": errors}

static func complete_mission(data: Dictionary, mission_id: StringName, result: Dictionary) -> Dictionary:
	var next: Dictionary = data.duplicate(true)
	var validation: Dictionary = validate(next)
	if not bool(validation.get("valid", false)):
		return next
	var mission := String(mission_id)
	var completed: Array = next.get("completed_missions", []).duplicate()
	if mission in MISSION_ORDER and not mission in completed:
		completed.append(mission)
	next["completed_missions"] = completed
	var ratings: Dictionary = next.get("mission_ratings", {}).duplicate(true)
	ratings[mission] = int(result.get("rating", 0))
	next["mission_ratings"] = ratings
	var rescue_character := String(result.get("rescue_character", ""))
	var rescued: Array = next.get("rescued_characters", []).duplicate()
	if rescue_character in ROLE_IDS and not rescue_character in rescued:
		rescued.append(rescue_character)
	next["rescued_characters"] = rescued
	var unlocked: Array = next.get("unlocked_modules", []).duplicate()
	for module_id in result.get("unlocked_modules", []):
		var module := String(module_id)
		if not module.is_empty() and not module in unlocked:
			unlocked.append(module)
	next["unlocked_modules"] = unlocked
	var index := MISSION_ORDER.find(mission)
	if index >= 0 and index + 1 < MISSION_ORDER.size():
		next["current_mission"] = MISSION_ORDER[index + 1]
	elif mission == "ch1_m6":
		next["current_mission"] = mission
		next["chapter_complete"] = true
	var statistics: Dictionary = next.get("statistics", {}).duplicate(true)
	statistics["missions_completed"] = int(statistics.get("missions_completed", 0)) + 1
	next["statistics"] = statistics
	return next
