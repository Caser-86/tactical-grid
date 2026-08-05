extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")

var t := Runner.new()

func _initialize() -> void:
	var repo := Repository.new()
	var result := repo.reload_all()
	t.check(not bool(result.get("success", true)), "缺少正式数据时拒绝启动")
	t.check(repo.get_character(&"assault").is_empty(), "未知角色返回空字典")
	repo.free()
	t.finish(self)
