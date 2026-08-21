extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Flow = preload("res://scripts/v2/mission/v2_mission_flow.gd")

var t := Runner.new()

func _initialize() -> void:
	var mission := {
		"id": "ch1_m1",
		"rescue_character": "scout",
		"primary": "找到失联侦察兵并一起撤离",
	}
	var map := {
		"entities": [
			{"id":"rescue_scout", "type":"objective_primary", "x":13, "y":7},
			{"id":"evac_northeast", "type":"evac", "x":19, "y":2, "radius":1},
		],
	}
	var assault := _unit("assault_1", Vector2i(3, 14))
	var enemies := [_unit("enemy_1", Vector2i(8, 12), false)]
	var flow := Flow.new()
	flow.setup(mission, map, [assault], enemies)
	t.check(flow.get_state_name() == &"SEARCH_SCOUT", "M1 开场进入搜索状态")
	t.check(flow.get_primary_text() == "找到失联侦察兵", "开场目标简短")
	t.check(flow.get_guide_text().contains("流程 1/2") and flow.get_guide_text().contains("青色侦察标记") and flow.get_guide_text().contains("绿色菱形撤离点"), "开场持续指示目标标记和终点")
	t.check(not flow.apply_event(&"evac_checked").get("victory", false), "未营救不能撤离胜利")
	var scout := _unit("player_scout", Vector2i(13, 7))
	var rescued := flow.apply_event(&"scout_rescued", {"character_id":"scout", "unit":scout})
	t.check(bool(rescued.get("success", false)) and flow.get_state_name() == &"ESCORT_TO_EVAC", "营救后进入护送状态")
	t.check(flow.get_primary_text() == "带侦察兵抵达撤离点", "营救后目标更新")
	t.check(flow.get_guide_text().contains("流程 2/2") and flow.get_guide_text().contains("地图右上方") and flow.get_guide_text().contains("自动完成"), "营救后持续指示终点位置和自动完成")
	t.check(not flow.apply_event(&"scout_rescued", {"character_id":"scout"}).get("success", false), "重复营救被拒绝")
	flow.apply_event(&"unit_moved", {"unit_id":"assault_1", "position":Vector2i(19, 2)})
	flow.apply_event(&"unit_moved", {"unit_id":"player_scout", "position":Vector2i(17, 2)})
	t.check(not flow.apply_event(&"evac_checked").get("victory", false), "只有一名角色到达时不能撤离")
	flow.apply_event(&"unit_moved", {"unit_id":"player_scout", "position":Vector2i(19, 2)})
	t.check(bool(flow.apply_event(&"evac_checked").get("victory", false)), "两名存活角色进入撤离区后胜利")
	t.check(flow.is_victory() and not flow.is_defeat(), "胜利状态不可误判为失败")

	var partial_flow := Flow.new()
	var second := _unit("assault_2", Vector2i(19, 2))
	partial_flow.setup(mission, map, [assault, second], enemies)
	partial_flow.apply_event(&"scout_rescued", {"character_id":"scout", "unit":_unit("scout_2", Vector2i(19, 2))})
	var partial_unit := _unit("assault_2", Vector2i(19, 2), false)
	var partial := partial_flow.apply_event(&"unit_downed", {"unit":partial_unit, "unit_id":"assault_2"})
	t.check(not bool(partial.get("defeat", false)) and not partial_flow.is_defeat(), "部分失能不立即判负")

	var failed_flow := Flow.new()
	var doomed := _unit("doomed", Vector2i(3, 14), false)
	failed_flow.setup(mission, map, [doomed], enemies)
	var defeated := failed_flow.apply_event(&"unit_downed", {"unit":doomed})
	t.check(bool(defeated.get("defeat", false)) and failed_flow.is_defeat(), "全队失能判负")

	var irreversible := Flow.new()
	irreversible.setup(mission, map, [_unit("safe", Vector2i(3, 14))], enemies)
	var irreversible_result := irreversible.apply_event(&"primary_irreversible_failure")
	t.check(bool(irreversible_result.get("defeat", false)), "不可逆主线失败判负")
	t.check(not irreversible.apply_event(&"unknown_event").get("success", false), "未知事件返回明确错误")

	var configured_flow := Flow.new()
	var configured_mission := mission.duplicate(true)
	configured_mission["objective_steps"] = [
		{"id": "search_scout", "complete_event": "character_rescued", "required_flags": []},
		{"id": "escort_scout", "complete_event": "evac_checked", "required_flags": ["scout_rescued"]},
		{"id": "evacuate", "complete_event": "mission_completed", "required_flags": ["scout_rescued"]},
	]
	var configured_assault := _unit("configured_assault", Vector2i(19, 2))
	var configured_scout := _unit("configured_scout", Vector2i(19, 2))
	configured_flow.setup(configured_mission, map, [configured_assault], enemies)
	configured_flow.apply_event(&"character_rescued", {"character_id": "scout", "unit": configured_scout})
	var evac_advanced := configured_flow.apply_event(&"evac_checked")
	t.check(bool(evac_advanced.get("success", false)) and not bool(evac_advanced.get("victory", true)) and configured_flow.get_current_step_id() == "evacuate", "配置化 M1 撤离检查只推进到最终目标")
	var completed := configured_flow.apply_event(&"mission_completed")
	t.check(bool(completed.get("success", false)) and bool(completed.get("victory", false)) and configured_flow.is_victory(), "配置化 M1 仅由最终完成事件胜利")
	var duplicate_completion := configured_flow.apply_event(&"mission_completed")
	t.check(not bool(duplicate_completion.get("success", true)) and duplicate_completion.get("reason") == &"event_already_completed", "配置化 M1 重复最终完成事件被幂等拒绝")
	t.finish(self)

func _unit(entity_id: String, position: Vector2i, alive: bool = true) -> Dictionary:
	return {"entity_id": entity_id, "position": position, "is_alive": alive, "is_downed": not alive}
