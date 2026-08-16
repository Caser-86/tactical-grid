extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")

func _initialize() -> void:
	var t := Runner.new()
	var runner_path := "res://tests/v2/run_v2_gate.ps1"
	t.check(FileAccess.file_exists(runner_path), "V2 门 runner 文件存在")
	if FileAccess.file_exists(runner_path):
		var source := FileAccess.get_file_as_string(runner_path)
		t.check(
			source.contains("$requiresAssertions = $Kind -eq 'Godot script' -or $Kind -eq 'Godot scene'"),
			"V2 门区分需要断言输出的 Godot 测试与发布检查"
		)
		t.check(
			source.contains("$hasAssertionResult = $passedAssertions -ge 0 -and $failedAssertions -ge 0") \
				and source.contains("$requiresAssertions -and (-not $hasAssertionResult -or $failedAssertions -ne 0)"),
			"V2 门拒绝无 Passed/Failed 断言或存在失败断言的 Godot 测试"
		)
	t.finish(self)
