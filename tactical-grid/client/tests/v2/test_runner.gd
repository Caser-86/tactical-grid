extends RefCounted
class_name V2TestRunner

var passed := 0
var failed := 0

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] ", message)
	else:
		failed += 1
		print("  [FAIL] ", message)

func finish(tree: SceneTree) -> void:
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	tree.quit(0 if failed == 0 else 1)
