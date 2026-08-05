extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const V2CampaignProgress = preload("res://scripts/v2/mission/v2_campaign_progress.gd")
const V2UnitTurnState = preload("res://scripts/v2/combat/v2_unit_turn_state.gd")

func _initialize() -> void:
	var t := Runner.new()
	var repository: Node = get_root().get_node_or_null("V2Data")
	var reload: Dictionary = repository.call("reload_all") if repository != null else {}
	t.check(bool(reload.get("success", false)), "V2 autoload 数据完整")
	var save: Dictionary = V2CampaignProgress.create_default()
	t.check(String(save.get("current_mission", "")) == "ch1_m1", "新档进入 M1")
	var state := V2UnitTurnState.new()
	state.begin_turn()
	t.check(state.can_move() and state.can_act(), "战斗初始行动预算完整")
	t.check(OS.get_user_data_dir().ends_with("TacticalGrid_V2_Infiltration"), "运行目录仍隔离")

	var manager: Node = get_root().get_node_or_null("GameManager")
	if manager != null:
		manager.call("_initialize_v2_boot")
	t.check(manager != null and bool(manager.get("v2_data_ready")), "GameManager 启动时验证 V2 数据")
	t.check(manager != null and manager.get("v2_boot_errors").is_empty(), "V2 启动失败不静默")

	var controller_file := FileAccess.open("res://scripts/game/battle_controller.gd", FileAccess.READ)
	var controller_source: String = controller_file.get_as_text() if controller_file != null else ""
	t.check(controller_source.contains("var v2_action_service"), "BattleController 声明 V2 行动服务槽位")
	t.check(controller_source.contains("var v2_mission_flow"), "BattleController 声明 V2 任务流程槽位")
	t.check(controller_source.contains("var v2_interaction_service"), "BattleController 声明 V2 交互服务槽位")

	t.finish(self)
