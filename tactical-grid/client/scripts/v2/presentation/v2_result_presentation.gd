extends RefCounted
class_name V2ResultPresentation

const MISSION_GUIDES := {
	"ch1_m1": "营救侦察兵后，让所有当前存活队员进入绿色撤离区；全员进入后自动完成。",
	"ch1_m2": "关闭封锁、救出狙击手并确认远程火力后，让全部存活队员进入撤离区。",
}

const CHARACTER_NAMES := {
	"assault": "突击兵",
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
	var mission: Dictionary = repository.get_mission(StringName(mission_id)) if repository != null and repository.has_method("get_mission") else {}
	var starting_count := int(data.get("starting_unit_count", (mission.get("starting_roster", []) as Array).size()))
	var rescued_count: int = (data.get("rescued", []) as Array).size()
	var completion_guide := String(MISSION_GUIDES.get(mission_id, "完成当前任务目标并让全部存活队员进入撤离区。"))
	if mission_id == "ch1_m1":
		completion_guide = "本关从 %d 名突击兵出发；营救侦察兵后最多 %d 名队员。撤离时让所有当前存活队员进入绿色撤离区。" % [starting_count, starting_count + rescued_count]
	var phase_line := ""
	var next_action := ""
	match String(data.get("mission_step_id", "")):
		"search_route_split":
			phase_line = "当前阶段：前往路线分叉"
			next_action = "下一步：沿黄色“下一步”标记移动。"
		"select_route":
			phase_line = "当前阶段：选择推进路线"
			next_action = "下一步：选择维修摄像头或货柜突破。"
		"operate_gantry":
			phase_line = "当前阶段：放下吊桥"
			next_action = "下一步：靠近吊机控制台并点击设施。"
		"rescue_scout":
			phase_line = "当前阶段：营救侦察兵"
			next_action = "下一步：靠近青色侦察标记后点击营救。"
		"rescue_sniper":
			phase_line = "当前阶段：营救狙击手"
			next_action = "下一步：靠近狙击手标记后点击营救。"
		"evacuate_squad":
			phase_line = "当前阶段：小队撤离"
			next_action = "下一步：让所有当前存活队员进入绿色撤离区。"

	return {
		"completion_guide": completion_guide,
		"phase_line": phase_line,
		"next_action": next_action,
		"optional_line": optional_line,
		"rescued_lines": rescued_lines,
		"module_lines": module_lines,
	}
