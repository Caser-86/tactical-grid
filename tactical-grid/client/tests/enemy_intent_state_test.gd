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
	# CH1-050: extended coverage for stale freezing and threat summary.
	_test_freeze_stale_intents_marks_left_sight()
	_test_freeze_stale_intents_refreshes_observed()
	_test_threat_summary_counts()
	_test_threat_summary_top_threats_ranked()
	_test_stale_intent_remains_public_after_freeze()
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


func _test_freeze_stale_intents_marks_left_sight() -> void:
	print("\n--- Test: freeze_stale_intents marks enemies that left sight ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("e_seen", {"type": "attack", "target_pos": Vector2i(1, 1)})
	var enemy_data := {"entity_id": "e_seen", "pos": Vector2i(5, 5), "hp": 30}
	vs.update_visibility([Vector2i(5, 5)], [enemy_data])
	# Sanity: while observed, intent is not stale.
	var public := eis.get_public_intents()
	_check(not bool(public["e_seen"].get("stale", false)), "Observed enemy intent not stale before freeze")
	# Enemy leaves sight.
	vs.update_visibility([Vector2i(0, 0)], [])
	# Before freeze, intent should be hidden (not yet stale).
	public = eis.get_public_intents()
	_check(not public.has("e_seen"), "Intent hidden before freeze when enemy left sight")
	# Freeze marks the intent as stale so it becomes visible again (outdated).
	eis.freeze_stale_intents()
	public = eis.get_public_intents()
	_check(public.has("e_seen"), "Stale intent visible after freeze")
	_check(bool(public["e_seen"].get("stale", false)), "Stale flag set after freeze")


func _test_freeze_stale_intents_refreshes_observed() -> void:
	print("\n--- Test: freeze_stale_intents refreshes stale flag for observed enemies ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("e_obs", {"type": "attack"})
	var enemy_data := {"entity_id": "e_obs", "pos": Vector2i(4, 4), "hp": 30}
	vs.update_visibility([Vector2i(4, 4)], [enemy_data])
	# Manually mark as stale (simulating a previous freeze), then re-observe.
	eis.freeze_stale_intents()
	vs.update_visibility([Vector2i(4, 4)], [enemy_data])
	eis.freeze_stale_intents()
	var public := eis.get_public_intents()
	_check(public.has("e_obs"), "Observed enemy intent present")
	_check(not bool(public["e_obs"].get("stale", false)), "Observed enemy intent refreshed to not stale")


func _test_threat_summary_counts() -> void:
	print("\n--- Test: threat_summary counts intents by type ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(12, 12)
	eis.setup(vs)
	eis.set_intent("e_atk", {"type": "attack", "target_pos": Vector2i(1, 1)})
	eis.set_intent("e_lethal", {"type": "attack", "target_pos": Vector2i(2, 2), "lethal": true})
	eis.set_intent("e_move", {"type": "move", "target_pos": Vector2i(3, 3)})
	eis.set_intent("e_ow", {"type": "overwatch"})
	eis.set_intent("e_hidden", {"type": "attack"})
	var enemies_data := [
		{"entity_id": "e_atk", "pos": Vector2i(5, 5), "hp": 30},
		{"entity_id": "e_lethal", "pos": Vector2i(6, 6), "hp": 30},
		{"entity_id": "e_move", "pos": Vector2i(7, 7), "hp": 30},
		{"entity_id": "e_ow", "pos": Vector2i(8, 8), "hp": 30},
	]
	# First sight: all enemies become newly revealed, which would suppress
	# lethal intents. Observe once, then re-observe so none are newly revealed
	# and lethal intents are counted at full strength.
	vs.update_visibility(
		[Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7), Vector2i(8, 8)],
		enemies_data
	)
	vs.update_visibility(
		[Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7), Vector2i(8, 8)],
		enemies_data
	)
	var summary := eis.get_threat_summary()
	_check(int(summary.get("attack_count", 0)) == 2, "Attack count == 2")
	_check(int(summary.get("lethal_count", 0)) == 1, "Lethal count == 1")
	_check(int(summary.get("move_count", 0)) == 1, "Move count == 1")
	_check(int(summary.get("overwatch_count", 0)) == 1, "Overwatch count == 1")
	_check(int(summary.get("total", 0)) == 4, "Total == 4 (hidden enemy excluded)")


func _test_threat_summary_top_threats_ranked() -> void:
	print("\n--- Test: threat_summary ranks lethal attacks highest ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(12, 12)
	eis.setup(vs)
	eis.set_intent("e_move", {"type": "move", "target_pos": Vector2i(3, 3)})
	eis.set_intent("e_lethal", {"type": "attack", "target_pos": Vector2i(2, 2), "lethal": true})
	eis.set_intent("e_atk", {"type": "attack", "target_pos": Vector2i(1, 1)})
	var enemies_data := [
		{"entity_id": "e_move", "pos": Vector2i(7, 7), "hp": 30},
		{"entity_id": "e_lethal", "pos": Vector2i(6, 6), "hp": 30},
		{"entity_id": "e_atk", "pos": Vector2i(5, 5), "hp": 30},
	]
	# Observe twice so none are newly revealed (lethal suppression would
	# otherwise flatten the ranking).
	vs.update_visibility(
		[Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7)],
		enemies_data
	)
	vs.update_visibility(
		[Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7)],
		enemies_data
	)
	var summary := eis.get_threat_summary()
	var top_threats: Array = summary.get("top_threats", [])
	_check(top_threats.size() == 3, "Top threats contains all three enemies")
	if top_threats.size() >= 1:
		_check(String(top_threats[0].get("entity_id", "")) == "e_lethal", "Lethal attack ranks first")
	if top_threats.size() >= 2:
		_check(String(top_threats[1].get("entity_id", "")) == "e_atk", "Regular attack ranks second")
	if top_threats.size() >= 3:
		_check(String(top_threats[2].get("entity_id", "")) == "e_move", "Move ranks third")


func _test_stale_intent_remains_public_after_freeze() -> void:
	print("\n--- Test: stale intent remains public after freeze so player can read outdated plan ---")
	var eis := EnemyIntentState.new()
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	eis.setup(vs)
	eis.set_intent("e_gone", {"type": "attack", "target_pos": Vector2i(2, 2)})
	var enemy_data := {"entity_id": "e_gone", "pos": Vector2i(5, 5), "hp": 30}
	vs.update_visibility([Vector2i(5, 5)], [enemy_data])
	# Enemy leaves sight, then we freeze at turn boundary.
	vs.update_visibility([Vector2i(0, 0)], [])
	eis.freeze_stale_intents()
	var public := eis.get_public_intents()
	_check(public.has("e_gone"), "Stale intent still visible after freeze")
	_check(bool(public["e_gone"].get("stale", false)), "Stale flag set")
	# Threat summary should still count the stale intent.
	var summary := eis.get_threat_summary()
	_check(int(summary.get("total", 0)) == 1, "Stale intent counted in summary total")


func _print_summary() -> void:
	print("\n=== EnemyIntentState: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
