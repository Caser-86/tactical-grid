extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const RepositoryScript = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var script_path := "res://scripts/v2/presentation/v2_result_presentation.gd"
	t.check(ResourceLoader.exists(script_path), "V2 存在独立结算文案呈现器")
	if not ResourceLoader.exists(script_path):
		t.finish(self)
		return
	var presentation = load(script_path)
	var repository := RepositoryScript.new()
	root.add_child(repository)
	var loaded: Dictionary = repository.reload_all()
	t.check(bool(loaded.get("success", false)), "V2 结算测试加载正式数据仓库")
	var m1: Dictionary = presentation.build_summary({
		"level_id": "ch1_m1",
		"result": "victory",
		"optional_record": true,
		"rescued": ["scout"],
		"unlocked_modules": ["scout_a", "scout_b"],
	}, repository)
	t.check("两名" in String(m1.get("completion_guide", "")), "M1 结算说明两名队员撤离条件")
	t.check(m1.get("module_lines", []) == ["扩展扫描", "静默扫描"], "M1 模块名称按数据本地化")

	var m2: Dictionary = presentation.build_summary({
		"level_id": "ch1_m2",
		"result": "victory",
		"optional_record": true,
		"optional_objective": "进入冷却控制室",
		"rescued": ["sniper"],
		"unlocked_modules": ["sniper_a", "assault_b"],
	}, repository)
	t.check("关闭封锁" in String(m2.get("completion_guide", "")) and "狙击手" in String(m2.get("completion_guide", "")), "M2 使用本关专属通关回顾")
	t.check(not "侦察兵" in String(m2.get("completion_guide", "")), "M2 不复用 M1 侦察兵文案")
	t.check(m2.get("module_lines", []) == ["深穿截断", "冲击护盾"], "M2 模块名称按数据本地化")
	t.check("进入冷却控制室" in String(m2.get("optional_line", "")) and "已完成" in String(m2.get("optional_line", "")), "M2 结算显示本关可选目标而非事故记录")

	var failed_after_rescue: Dictionary = presentation.build_summary({
		"level_id": "ch1_m2",
		"result": "defeat",
		"rescued": ["sniper"],
		"unlocked_modules": ["sniper_a"],
	}, repository)
	t.check(failed_after_rescue.get("rescued_lines", []).is_empty(), "V2 失败结算不宣称临时营救角色已加入基地")
	t.check(failed_after_rescue.get("module_lines", []).is_empty(), "V2 失败结算不宣称未持久化模块已解锁")
	repository.free()
	t.finish(self)
