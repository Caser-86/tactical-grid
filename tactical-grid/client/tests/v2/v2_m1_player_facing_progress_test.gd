extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const FlowScript = preload("res://scripts/v2/mission/v2_mission_flow.gd")
const UnitScript = preload("res://scripts/game/unit.gd")

var t := Runner.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== V2 M1 player-facing progress ===")
	var mission := _load_m1_mission()
	var player: Unit = UnitScript.new()
	player.entity_id = "player_assault"
	player.team = "player"
	player.grid_pos = Vector2i(0, 0)
	player.is_alive = true
	var flow := FlowScript.new()
	flow.setup(mission, {"entities": [{"type": "evac", "x": 0, "y": 0, "radius": 0}]}, [player], [])

	t.check(flow.get_objective_step_count() == 3, "M1 原始目标数保持三个")
	_check_progress(flow, 0, "流程 1/3", "初始营救目标向玩家显示 1/3")

	var rescue := flow.apply_event(&"character_rescued", {"character_id": "scout"})
	t.check(bool(rescue.get("success", false)), "真实营救事件进入撤离阶段")
	_check_progress(flow, 1, "流程 2/3", "营救后护送目标向玩家显示 2/3")

	var evac := flow.apply_event(&"evac_checked")
	t.check(bool(evac.get("success", false)), "真实撤离检查进入最终撤离确认阶段")
	t.check(flow.get_current_step_id() == "evacuate", "撤离检查后当前目标为最终撤离确认")
	_check_progress(flow, 2, "流程 3/3", "最终撤离确认向玩家显示 3/3")

	player.free()
	t.finish(self)

func _check_progress(flow: RefCounted, expected_index: int, expected_guide: String, message: String) -> void:
	t.check(
		int(flow.call("get_display_objective_step_index")) == expected_index
		and int(flow.call("get_display_objective_step_count")) == 3
		and flow.get_current_guide_text().contains(expected_guide),
		message
	)

func _load_m1_mission() -> Dictionary:
	var mission_file := FileAccess.open("res://data/v2/missions.json", FileAccess.READ)
	if mission_file == null:
		return {}
	var missions: Variant = JSON.parse_string(mission_file.get_as_text())
	mission_file.close()
	return missions.get("ch1_m1", {}) if missions is Dictionary else {}
