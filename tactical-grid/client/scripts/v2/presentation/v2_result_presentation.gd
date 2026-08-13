extends RefCounted
class_name V2ResultPresentation

const MISSION_GUIDES := {
	"ch1_m1": "救出侦察兵后，让两名存活队员进入绿色撤离区；全员进入后自动完成。",
	"ch1_m2": "关闭封锁、救出狙击手并确认远程火力后，让全部存活队员进入撤离区。",
}

const CHARACTER_NAMES := {
	"scout": "侦察兵",
	"sniper": "狙击手",
	"heavy": "重装兵",
}

static func build_summary(data: Dictionary, repository: Node) -> Dictionary:
	var mission_id := String(data.get("level_id", data.get("mission_id", "")))
	var is_victory := String(data.get("result", "defeat")) == "victory"
	var rescued_lines: Array[String] = []
	if is_victory:
		for raw_character_id in data.get("rescued", []):
			var character_id := String(raw_character_id)
			rescued_lines.append("%s已加入基地" % CHARACTER_NAMES.get(character_id, character_id))

	var module_lines: Array[String] = []
	if is_victory:
		for raw_module_id in data.get("unlocked_modules", []):
			var module_id := String(raw_module_id)
			var module_name := module_id
			if repository != null and repository.has_method("get_module"):
				var module: Dictionary = repository.get_module(StringName(module_id))
				module_name = String(module.get("name", module_id))
			module_lines.append(module_name)

	var optional_name := String(data.get("optional_objective", ""))
	if optional_name.is_empty() and repository != null and repository.has_method("get_mission"):
		var mission: Dictionary = repository.get_mission(StringName(mission_id))
		optional_name = String(mission.get("optional", "可选目标"))
	var optional_done := bool(data.get("optional_record", false))
	var optional_line := "可选记录：%s" % ("已上传" if optional_done else "未上传")
	if mission_id != "ch1_m1":
		optional_line = "可选目标：%s · %s" % [optional_name, "已完成" if optional_done else "未完成"]

	return {
		"completion_guide": String(MISSION_GUIDES.get(mission_id, "完成当前任务目标并让全部存活队员进入撤离区。")),
		"optional_line": optional_line,
		"rescued_lines": rescued_lines,
		"module_lines": module_lines,
	}
