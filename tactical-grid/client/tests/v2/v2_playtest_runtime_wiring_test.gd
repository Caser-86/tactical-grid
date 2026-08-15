extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

var t := Runner.new()

func _initialize() -> void:
	var battle_source := FileAccess.get_file_as_string("res://scripts/game/battle_controller.gd")
	var v2_source := FileAccess.get_file_as_string("res://scripts/v2/runtime/v2_battle_controller.gd")
	t.check(battle_source.contains('_record_v2_playtest_event(&"invalid_click"'), "V2 无效点击进入实际记录路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"action_cancelled"'), "V2 取消动作进入实际记录路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"camera_pan"'), "摄像头平移进入实际记录路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"camera_focus_returned"'), "回到队员进入实际记录路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"damage_resolved"'), "伤害结算进入实际记录路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"unit_downed"'), "倒地进入实际记录路径")
	t.check(battle_source.contains('v2_input_router.ability_requested.connect(_on_v2_ability_requested)'), "Q 能力请求接入共享战斗控制器")
	t.check(battle_source.contains('State.ABILITY_TARGETING') and battle_source.contains('_on_v2_ability_cell_clicked'), "能力目标状态接入地图点击路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"ability_targeting_started"'), "能力目标选择进入实际记录路径")
	t.check(battle_source.contains('_record_v2_playtest_event(&"ability_committed"'), "能力提交进入实际记录路径")
	t.check(v2_source.contains('_record_v2_playtest_event(&"intent_resolved"'), "敌方意图结算进入实际记录路径")
	t.check(v2_source.contains('_record_v2_playtest_event(&"retry_started"'), "检查点重试进入实际记录路径")
	t.finish(self)
