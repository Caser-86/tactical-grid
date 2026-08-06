extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const AlertStateScript = preload("res://scripts/game/alert_state.gd")
const VisibilityStateScript = preload("res://scripts/game/visibility_state.gd")

var t := Runner.new()

func _initialize() -> void:
	_test_m1_alert_front()
	_test_story_grace()
	_test_visibility_delta()
	t.finish(self)

func _test_m1_alert_front() -> void:
	var alert := AlertStateScript.new()
	alert.setup({
		"front_stage_cap": 1,
		"allowed_events": ["camera_identified_player", "drone_scan_completed"],
		"decay_enabled": false,
		"story_grace_events": 0,
	})
	for _turn in range(1, 6):
		alert.on_turn_end()
	t.check(alert.get_alert_level() == AlertStateScript.LEVEL_CALM, "M1 警戒不随回合自动升高")
	t.check(alert.get_front_state() == &"hidden", "M1 初始前端状态为潜伏")
	var blocked := alert.apply_event("enemy_spotted")
	t.check(not bool(blocked.get("changed", true)), "M1 未配置事件不会升高警戒")
	var camera := alert.apply_event("camera_identified_player")
	t.check(bool(camera.get("changed", false)), "摄像头完整识别进入搜索")
	t.check(alert.get_alert_level() == AlertStateScript.LEVEL_SUSPICIOUS, "M1 后端警戒上限为搜索级")
	t.check(alert.get_front_state() == &"searching", "M1 搜索状态明确可读")
	t.check(alert.get_front_state_description().contains("巡逻路线"), "搜索状态说明下一后果")
	alert.apply_event("drone_scan_completed")
	t.check(alert.get_alert_level() == AlertStateScript.LEVEL_SUSPICIOUS, "重复识别不进入封锁")
	alert.on_turn_end()
	t.check(alert.get_front_state() == &"searching", "搜索状态不会在回合边界闪回潜伏")

func _test_story_grace() -> void:
	var alert := AlertStateScript.new()
	alert.setup({
		"front_stage_cap": 1,
		"allowed_events": ["camera_identified_player"],
		"decay_enabled": false,
		"story_grace_events": 1,
	})
	var first := alert.apply_event("camera_identified_player")
	t.check(not bool(first.get("changed", true)), "故事难度首个识别事件获得宽限")
	t.check(bool(first.get("grace", false)), "宽限结果明确标记")
	var second := alert.apply_event("camera_identified_player")
	t.check(bool(second.get("changed", false)), "故事难度第二个识别事件进入搜索")

func _test_visibility_delta() -> void:
	var visibility := VisibilityStateScript.new()
	visibility.setup(8, 6)
	visibility.set_turn(1)
	var first: Dictionary = visibility.update_visibility([Vector2i(1, 1)], [])
	t.check(int(first.get("newly_observed_cells", 0)) == 1, "迷雾首次刷新返回新增视野格数")
	visibility.set_turn(2)
	var second: Dictionary = visibility.update_visibility(
		[Vector2i(1, 1), Vector2i(2, 1)],
		[{"entity_id": "enemy_test", "pos": Vector2i(2, 1), "hp": 2}],
	)
	t.check(int(second.get("newly_observed_cells", 0)) == 1, "移动后同事务返回新增视野格数")
	t.check(int(second.get("newly_revealed_enemies", 0)) == 1, "移动后同事务返回新揭示敌人数")
	t.check(visibility.get_last_update_summary().get("observed_enemy_ids", []).has("enemy_test"), "迷雾摘要保留当前可见敌人")
