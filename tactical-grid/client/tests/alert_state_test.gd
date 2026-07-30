extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CODE-P2-02: AlertState tests ===")
	_test_alert_levels()
	_test_apply_event_raises_alert()
	_test_alert_consequences()
	_test_alert_decay()
	_test_max_alert()
	_test_unknown_event_ignored()
	_test_get_next_consequence()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _test_alert_levels() -> void:
	print("\n--- Test: alert levels calm/suspicious/alert/combat ---")
	var astate := AlertState.new()
	astate.setup()
	_check(astate.get_alert_level() == AlertState.LEVEL_CALM, "Starts at calm")
	astate.apply_event("noise_detected")
	_check(astate.get_alert_level() == AlertState.LEVEL_SUSPICIOUS, "Noise raises to suspicious")
	astate.apply_event("enemy_spotted")
	_check(astate.get_alert_level() == AlertState.LEVEL_ALERT, "Spotting raises to alert")
	astate.apply_event("combat_started")
	_check(astate.get_alert_level() == AlertState.LEVEL_COMBAT, "Combat raises to combat")

func _test_apply_event_raises_alert() -> void:
	print("\n--- Test: apply_event raises alert ---")
	var astate := AlertState.new()
	astate.setup()
	var result := astate.apply_event("overload_triggered")
	_check(bool(result.get("changed", false)), "Overload event changes alert")
	_check(astate.get_alert_level() != AlertState.LEVEL_CALM, "Alert is no longer calm")

func _test_alert_consequences() -> void:
	print("\n--- Test: alert consequences escalate with level ---")
	var astate := AlertState.new()
	astate.setup()
	var calm_consequence := astate.get_consequence()
	_check(calm_consequence.has("description"), "Calm has consequence description")
	astate.apply_event("noise_detected")
	var susp_consequence := astate.get_consequence()
	_check(susp_consequence.has("description"), "Suspicious has consequence description")
	# Consequences should differ at different alert levels
	_check(susp_consequence["description"] != calm_consequence["description"], "Consequences differ by level")

func _test_alert_decay() -> void:
	print("\n--- Test: alert decays each turn ---")
	var astate := AlertState.new()
	astate.setup()
	astate.apply_event("noise_detected")
	_check(astate.get_alert_level() == AlertState.LEVEL_SUSPICIOUS, "At suspicious after noise")
	astate.on_turn_end()
	_check(astate.get_alert_level() == AlertState.LEVEL_CALM, "Decays to calm after turn end")

func _test_max_alert() -> void:
	print("\n--- Test: alert cannot exceed combat level ---")
	var astate := AlertState.new()
	astate.setup()
	astate.apply_event("combat_started")
	astate.apply_event("combat_started")
	astate.apply_event("combat_started")
	_check(astate.get_alert_level() == AlertState.LEVEL_COMBAT, "Stays at combat (max)")

func _test_unknown_event_ignored() -> void:
	print("\n--- Test: unknown event is ignored ---")
	var astate := AlertState.new()
	astate.setup()
	var result := astate.apply_event("nonexistent_event")
	_check(not bool(result.get("changed", true)), "Unknown event does not change alert")
	_check(astate.get_alert_level() == AlertState.LEVEL_CALM, "Alert stays calm")

func _test_get_next_consequence() -> void:
	print("\n--- Test: get_next_consequence returns actionable info ---")
	var astate := AlertState.new()
	astate.setup()
	astate.apply_event("enemy_spotted")
	var next := astate.get_next_consequence()
	_check(next.has("description"), "Next consequence has description")
	_check(next.has("turns_until"), "Next consequence has turns_until")
	_check(int(next.get("turns_until", -1)) >= 0, "Turns until is non-negative")

func _print_summary() -> void:
	print("\n=== AlertState: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
