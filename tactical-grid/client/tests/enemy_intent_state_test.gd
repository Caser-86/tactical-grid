extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CODE-P2-01: EnemyIntentState tests ===")
	_test_hidden_enemy_no_public_intent()
	_test_observed_enemy_has_public_intent()
	_test_newly_observed_no_lethal_same_turn()
	_test_intent_types()
	_test_stale_intent_after_leaving_sight()
	_test_clear_intents()
	_test_get_public_intents_filtered()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _test_hidden_enemy_no_public_intent() -> void:
	print("\n--- Test: hidden enemy cannot produce a public intent ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("enemy_0", {"type": "attack", "target_pos": Vector2i(2, 2)})
	vs.update_visibility([Vector2i(2, 2)], [])
	var public_intents := eis.get_public_intents()
	_check(not public_intents.has("enemy_0"), "Hidden enemy has no public intent")

func _test_observed_enemy_has_public_intent() -> void:
	print("\n--- Test: observed enemy has public intent ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("enemy_1", {"type": "move", "target_pos": Vector2i(4, 4)})
	var enemy_data := {"entity_id": "enemy_1", "pos": Vector2i(5, 5), "hp": 30}
	vs.update_visibility([Vector2i(5, 5)], [enemy_data])
	var public_intents := eis.get_public_intents()
	_check(public_intents.has("enemy_1"), "Observed enemy has public intent")
	_check(public_intents["enemy_1"]["type"] == "move", "Intent type is move")

func _test_newly_observed_no_lethal_same_turn() -> void:
	print("\n--- Test: newly observed enemy cannot deal unannounced lethal damage same reveal turn ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("enemy_2", {"type": "attack", "target_pos": Vector2i(2, 2), "lethal": true})
	var enemy_data := {"entity_id": "enemy_2", "pos": Vector2i(3, 3), "hp": 40}
	vs.update_visibility([Vector2i(3, 3)], [enemy_data])
	_check(vs.is_newly_revealed("enemy_2"), "Enemy is newly revealed")
	var public_intents := eis.get_public_intents()
	if public_intents.has("enemy_2"):
		_check(not bool(public_intents["enemy_2"].get("lethal", false)), "Newly revealed enemy lethal intent suppressed")
	else:
		_check(true, "Newly revealed enemy intent suppressed entirely")

func _test_intent_types() -> void:
	print("\n--- Test: intent types are tracked correctly ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("e_a", {"type": "move", "target_pos": Vector2i(1, 1)})
	eis.set_intent("e_b", {"type": "attack", "target_pos": Vector2i(2, 2)})
	eis.set_intent("e_c", {"type": "overwatch"})
	eis.set_intent("e_d", {"type": "scan", "target_pos": Vector2i(3, 3)})
	var enemies_data := [
		{"entity_id": "e_a", "pos": Vector2i(5, 5), "hp": 30},
		{"entity_id": "e_b", "pos": Vector2i(6, 6), "hp": 30},
		{"entity_id": "e_c", "pos": Vector2i(7, 7), "hp": 30},
		{"entity_id": "e_d", "pos": Vector2i(8, 8), "hp": 30},
	]
	vs.update_visibility([Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7), Vector2i(8, 8)], enemies_data)
	var public_intents := eis.get_public_intents()
	_check(public_intents.has("e_a"), "move intent present")
	_check(public_intents.has("e_b"), "attack intent present")
	_check(public_intents.has("e_c"), "overwatch intent present")
	_check(public_intents.has("e_d"), "scan intent present")

func _test_stale_intent_after_leaving_sight() -> void:
	print("\n--- Test: intent becomes stale after enemy leaves sight ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("enemy_3", {"type": "move", "target_pos": Vector2i(1, 1)})
	var enemy_data := {"entity_id": "enemy_3", "pos": Vector2i(4, 4), "hp": 20}
	vs.update_visibility([Vector2i(4, 4)], [enemy_data])
	_check(eis.get_public_intents().has("enemy_3"), "Intent public when visible")
	vs.update_visibility([Vector2i(0, 0)], [])
	_check(not eis.get_public_intents().has("enemy_3"), "Intent not public when hidden")

func _test_clear_intents() -> void:
	print("\n--- Test: clear removes all intents ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("e", {"type": "move"})
	eis.clear()
	_check(eis.get_public_intents().is_empty(), "No intents after clear")

func _test_get_public_intents_filtered() -> void:
	print("\n--- Test: get_public_intents only returns observed enemies ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("visible_e", {"type": "attack"})
	eis.set_intent("hidden_e", {"type": "attack"})
	var visible_enemy := {"entity_id": "visible_e", "pos": Vector2i(3, 3), "hp": 20}
	vs.update_visibility([Vector2i(3, 3)], [visible_enemy])
	var public_intents := eis.get_public_intents()
	_check(public_intents.has("visible_e"), "Visible enemy intent included")
	_check(not public_intents.has("hidden_e"), "Hidden enemy intent excluded")

func _print_summary() -> void:
	print("\n=== EnemyIntentState: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
