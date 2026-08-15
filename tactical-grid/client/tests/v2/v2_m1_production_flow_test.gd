extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")
const MapLoader = preload("res://scripts/v2/content/v2_map_loader.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var repository := Repository.new()
	repository.reload_all()
	var mission: Dictionary = repository.get_mission(&"ch1_m1")
	var loaded := MapLoader.load_map(&"ch1_m1")
	var map: Dictionary = loaded.get("data", {}) if bool(loaded.get("success", false)) else {}
	var assault := _unit("assault_1", Vector2i(3, 14))
	var flow := Flow.new()
	flow.setup(mission, map, [assault], [])

	var expected_ids := ["find_scout", "rescue_scout", "evacuate_squad"]
	var actual_ids: Array[String] = []
	for raw_step in mission.get("objective_steps", []):
		if raw_step is Dictionary:
			actual_ids.append(String(raw_step.get("id", "")))
	t.check(actual_ids == expected_ids, "生产 M1 只公开找到、营救、撤离三个目标")
	t.check(flow.get_current_step_id() == "find_scout", "生产 M1 从找到侦察兵开始")
	t.check(flow.get_current_guide_text().contains("流程 1/3") and flow.get_current_guide_text().contains("青色"), "找到阶段明确显示位置和阶段进度")

	var premature_rescue := flow.apply_event(&"character_rescued", {"character_id": "scout"})
	t.check(not bool(premature_rescue.get("success", false)), "未找到目标时不能直接营救")
	var located := flow.apply_event(&"scout_located", {"position": Vector2i(15, 8)})
	t.check(bool(located.get("success", false)) and flow.get_current_step_id() == "rescue_scout", "抵达侦察兵附近后进入营救阶段")

	var scout := _unit("player_scout", Vector2i(15, 8))
	var rescued := flow.apply_event(&"character_rescued", {"character_id": "scout", "new_unit": scout, "unit_id": scout.get("entity_id", ""), "position": scout.get("position", Vector2i(-1, -1))})
	t.check(bool(rescued.get("success", false)) and flow.get_current_step_id() == "evacuate_squad", "营救成功后进入撤离阶段")
	t.check(flow.get_current_guide_text().contains("流程 3/3") and flow.get_current_guide_text().contains("绿色"), "撤离阶段明确显示终点和阶段进度")

	var not_ready := flow.apply_event(&"squad_evacuated")
	t.check(not bool(not_ready.get("success", false)) and not bool(not_ready.get("victory", false)), "未全员进入撤离区时不能结束任务")
	assault["position"] = Vector2i(23, 2)
	scout["position"] = Vector2i(23, 2)
	flow.apply_event(&"unit_moved", {"unit": assault, "unit_id": "assault_1", "position": Vector2i(23, 2)})
	flow.apply_event(&"unit_moved", {"unit": scout, "unit_id": "player_scout", "position": Vector2i(23, 2)})
	var completed := flow.apply_event(&"squad_evacuated")
	t.check(bool(completed.get("victory", false)) and flow.is_victory(), "所有清醒队员进入撤离区后完成任务")

	var optional_flow := Flow.new()
	optional_flow.setup(mission, map, [_unit("optional_assault", Vector2i(3, 14))], [])
	var optional := optional_flow.apply_event(&"optional_record_uploaded")
	t.check(bool(optional.get("success", false)) and optional_flow.get_current_step_id() == "find_scout", "可选事故记录不改变主线目标")

	for unit in [assault, scout]:
		if unit is Dictionary:
			unit.clear()
	repository.free()
	t.finish(self)

func _unit(entity_id: String, position: Vector2i) -> Dictionary:
	return {"entity_id": entity_id, "position": position, "is_alive": true, "is_downed": false}
