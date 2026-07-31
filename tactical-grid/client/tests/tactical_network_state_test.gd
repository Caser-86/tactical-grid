extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CODE-P2-02: TacticalNetworkState tests ===")
	_test_node_states()
	_test_takeover_pulse()
	_test_disable_operation()
	_test_overload_damages_facility()
	_test_camera_reveal()
	_test_door_route_change()
	_test_turret_ownership()
	_test_power_hazard()
	_test_beacon_delay()
	_test_operations_cost_1ap()
	_test_unknown_operation_rejected()
	_test_damaged_node_no_operations()
	# CH1-060 tests
	_test_query_operation_preview()
	_test_query_operation_power_cascade()
	_test_door_blocks_pathfinding()
	_test_door_open_after_takeover()
	_test_power_conduit_disables_facilities()
	_test_connections_parsed()
	_test_player_turrets()
	_test_reinforcement_delay_bonus()
	_test_facility_available_checks_power()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _make_test_network() -> TacticalNetworkState:
	var tns := TacticalNetworkState.new()
	var nodes := [
		{"id": "node_cam_1", "type": "camera", "state": "enemy", "x": 3, "y": 3, "reveal_radius": 4},
		{"id": "node_door_1", "type": "door", "state": "enemy", "x": 5, "y": 2},
		{"id": "node_turret_1", "type": "turret", "state": "enemy", "x": 7, "y": 5},
		{"id": "node_power_1", "type": "power_conduit", "state": "neutral", "x": 2, "y": 6},
		{"id": "node_beacon_1", "type": "reinforcement_beacon", "state": "enemy", "x": 8, "y": 1, "delay_turns": 2},
	]
	tns.setup(nodes)
	return tns

## CH1-060: Network with connections for power dependency and overlay tests.
func _make_test_network_with_connections() -> TacticalNetworkState:
	var tns := TacticalNetworkState.new()
	var nodes := [
		{"id": "node_power_1", "type": "power_conduit", "state": "neutral", "x": 2, "y": 6},
		{"id": "node_turret_1", "type": "turret", "state": "enemy", "x": 7, "y": 5, "turret_range": 5, "turret_damage": 3},
		{"id": "node_door_1", "type": "door", "state": "enemy", "x": 5, "y": 2},
		{"id": "node_beacon_1", "type": "reinforcement_beacon", "state": "enemy", "x": 8, "y": 1, "delay_turns": 2},
	]
	var connections := [
		{"from": "node_power_1", "to": "node_turret_1"},
		{"from": "node_power_1", "to": "node_door_1"},
	]
	tns.setup(nodes, connections)
	return tns

## CH1-060: query_operation returns enriched preview with immediate_result, duration, alert_cost.
func _test_query_operation_preview() -> void:
	print("\n--- Test: query_operation returns enriched preview ---")
	var tns := _make_test_network()
	var preview := tns.query_operation("node_cam_1", "takeover", 2)
	_check(bool(preview.get("valid", false)), "Preview is valid")
	_check(preview.has("immediate_result"), "Preview has immediate_result")
	_check(preview.has("duration"), "Preview has duration")
	_check(preview.has("alert_cost"), "Preview has alert_cost")
	_check(String(preview.get("duration", "")) == "while_owned", "Takeover duration is while_owned")
	_check(int(preview.get("alert_cost", -1)) == 0, "Takeover alert_cost is 0")
	# Overload has alert_cost 2
	var ov_preview := tns.query_operation("node_cam_1", "overload", 2)
	_check(int(ov_preview.get("alert_cost", -1)) == 2, "Overload alert_cost is 2")
	_check(String(ov_preview.get("duration", "")) == "permanent", "Overload duration is permanent")

## CH1-060: query_operation on power conduit lists facilities that will be disabled.
func _test_query_operation_power_cascade() -> void:
	print("\n--- Test: query_operation shows power cascade for power conduit ---")
	var tns := _make_test_network_with_connections()
	var preview := tns.query_operation("node_power_1", "disable", 2)
	_check(bool(preview.get("valid", false)), "Power conduit disable preview is valid")
	var disabled: Array = preview.get("facilities_disabled", [])
	_check(disabled.has("node_turret_1"), "Preview lists turret as dependent")
	_check(disabled.has("node_door_1"), "Preview lists door as dependent")
	_check(String(preview.get("immediate_result", "")).find("关联设施") >= 0, "Immediate result mentions facilities")

## CH1-060: Closed doors (enemy/neutral) block pathfinding; player doors don't.
func _test_door_blocks_pathfinding() -> void:
	print("\n--- Test: closed door blocks pathfinding cell ---")
	var tns := _make_test_network()
	# Door at (5,2) is enemy-owned, should block.
	_check(tns.is_cell_blocked_by_door(Vector2i(5, 2)), "Enemy door blocks movement")
	# Random cell without door should not block.
	_check(not tns.is_cell_blocked_by_door(Vector2i(0, 0)), "Cell without door does not block")

## CH1-060: Door becomes open (non-blocking) after takeover.
func _test_door_open_after_takeover() -> void:
	print("\n--- Test: door opens after takeover ---")
	var tns := _make_test_network()
	_check(tns.is_cell_blocked_by_door(Vector2i(5, 2)), "Door blocks before takeover")
	tns.perform_operation("node_door_1", "takeover", "player_0", 2)
	_check(not tns.is_cell_blocked_by_door(Vector2i(5, 2)), "Door does not block after takeover")

## CH1-060: Disabling a power conduit makes connected facilities unavailable.
func _test_power_conduit_disables_facilities() -> void:
	print("\n--- Test: power conduit disable cascades to facilities ---")
	var tns := _make_test_network_with_connections()
	# Before disable, turret is available (powered by neutral conduit).
	_check(tns.is_facility_available("node_turret_1"), "Turret available before power disable")
	# Disable the power conduit.
	var result := tns.perform_operation("node_power_1", "disable", "player_0", 2)
	_check(bool(result.get("success", false)), "Power conduit disable succeeds")
	var disabled: Array = result.get("facilities_disabled", [])
	_check(disabled.has("node_turret_1"), "Result lists turret as disabled")
	# After disable, turret is unavailable (power conduit is damaged).
	_check(not tns.is_facility_available("node_turret_1"), "Turret unavailable after power disable")

## CH1-060: Connections are parsed and available for overlay rendering.
func _test_connections_parsed() -> void:
	print("\n--- Test: connections parsed from setup ---")
	var tns := _make_test_network_with_connections()
	var conns := tns.get_connections()
	_check(conns.size() == 2, "Two connections parsed (got %d)" % conns.size())
	# Verify connection content
	var has_turret_link := false
	var has_door_link := false
	for conn in conns:
		if String(conn.get("to", "")) == "node_turret_1":
			has_turret_link = true
		if String(conn.get("to", "")) == "node_door_1":
			has_door_link = true
	_check(has_turret_link, "Connection to turret exists")
	_check(has_door_link, "Connection to door exists")

## CH1-060: Player-owned turrets are returned for automatic fire.
func _test_player_turrets() -> void:
	print("\n--- Test: player turrets returned for auto-fire ---")
	var tns := _make_test_network_with_connections()
	# Initially enemy-owned, no player turrets.
	_check(tns.get_player_turrets().is_empty(), "No player turrets initially")
	# Takeover the turret (but power conduit is neutral, so it's available).
	tns.perform_operation("node_turret_1", "takeover", "player_0", 2)
	var turrets := tns.get_player_turrets()
	_check(turrets.size() == 1, "One player turret after takeover (got %d)" % turrets.size())
	var turret: Dictionary = turrets[0]
	_check(int(turret.get("range", 0)) == 5, "Turret range is 5")
	_check(int(turret.get("damage", 0)) == 3, "Turret damage is 3")

## CH1-060: Disabled beacons contribute to reinforcement delay bonus.
func _test_reinforcement_delay_bonus() -> void:
	print("\n--- Test: disabled beacons add reinforcement delay ---")
	var tns := _make_test_network()
	# Initially no disabled beacons.
	_check(tns.get_reinforcement_delay_bonus() == 0, "No delay bonus initially")
	# Disable the beacon.
	tns.perform_operation("node_beacon_1", "disable", "player_0", 2)
	_check(tns.get_reinforcement_delay_bonus() > 0, "Delay bonus after beacon disable (got %d)" % tns.get_reinforcement_delay_bonus())

## CH1-060: Facility availability checks power conduit dependency.
func _test_facility_available_checks_power() -> void:
	print("\n--- Test: facility availability checks power dependency ---")
	var tns := _make_test_network_with_connections()
	# Turret is powered by neutral conduit, available.
	_check(tns.is_facility_available("node_turret_1"), "Turret available with powered conduit")
	# Overload the power conduit.
	tns.perform_operation("node_power_1", "overload", "player_0", 2)
	# Turret is now unavailable (conduit damaged).
	_check(not tns.is_facility_available("node_turret_1"), "Turret unavailable after conduit overload")
	# Player turrets should not include the unpowered turret.
	_check(tns.get_player_turrets().is_empty(), "No player turrets when power is cut")

func _test_node_states() -> void:
	print("\n--- Test: node states enemy/player/neutral/damaged ---")
	var tns := _make_test_network()
	_check(tns.get_node_state("node_cam_1") == "enemy", "Camera node starts as enemy")
	_check(tns.get_node_state("node_power_1") == "neutral", "Power node starts as neutral")
	var result := tns.perform_operation("node_cam_1", "takeover", "player_0", 2)
	_check(bool(result.get("success", false)), "Takeover succeeds")
	_check(tns.get_node_state("node_cam_1") == "player", "Node is player after takeover")

func _test_takeover_pulse() -> void:
	print("\n--- Test: one-time takeover pulse ---")
	var tns := _make_test_network()
	var r1 := tns.perform_operation("node_cam_1", "takeover", "player_0", 2)
	_check(bool(r1.get("success", false)), "First takeover succeeds")
	_check(bool(r1.get("pulse", false)), "Takeover produces pulse")
	var r2 := tns.perform_operation("node_cam_1", "takeover", "player_0", 2)
	_check(not bool(r2.get("success", true)), "Second takeover on player node fails")

func _test_disable_operation() -> void:
	print("\n--- Test: disable operation ---")
	var tns := _make_test_network()
	var result := tns.perform_operation("node_turret_1", "disable", "player_0", 2)
	_check(bool(result.get("success", false)), "Disable succeeds")
	_check(tns.get_node_state("node_turret_1") == "damaged", "Node is damaged after disable")

func _test_overload_damages_facility() -> void:
	print("\n--- Test: overload permanently damages facility and raises alert ---")
	var tns := _make_test_network()
	var result := tns.perform_operation("node_power_1", "overload", "player_0", 2)
	_check(bool(result.get("success", false)), "Overload succeeds")
	_check(tns.get_node_state("node_power_1") == "damaged", "Node is damaged after overload")
	_check(bool(result.get("alert_raised", false)), "Overload raises alert")
	_check(bool(result.get("permanent", false)), "Overload damage is permanent")

func _test_camera_reveal() -> void:
	print("\n--- Test: camera reveals area when taken over ---")
	var tns := _make_test_network()
	var result := tns.perform_operation("node_cam_1", "takeover", "player_0", 2)
	_check(bool(result.get("success", false)), "Camera takeover succeeds")
	var reveal_cells: Array = result.get("reveal_cells", [])
	_check(not reveal_cells.is_empty(), "Camera reveals cells")
	_check(reveal_cells.size() > 0, "Reveal area non-empty (got %d cells)" % reveal_cells.size())

func _test_door_route_change() -> void:
	print("\n--- Test: door route changes when taken over ---")
	var tns := _make_test_network()
	var result := tns.perform_operation("node_door_1", "takeover", "player_0", 2)
	_check(bool(result.get("success", false)), "Door takeover succeeds")
	_check(bool(result.get("route_changed", false)), "Door changes route")
	var blocker_open: bool = tns.is_door_open("node_door_1")
	_check(blocker_open, "Door is open after takeover")

func _test_turret_ownership() -> void:
	print("\n--- Test: turret ownership changes when taken over ---")
	var tns := _make_test_network()
	_check(tns.get_turret_owner("node_turret_1") == "enemy", "Turret starts enemy-owned")
	var result := tns.perform_operation("node_turret_1", "takeover", "player_0", 2)
	_check(bool(result.get("success", false)), "Turret takeover succeeds")
	_check(tns.get_turret_owner("node_turret_1") == "player", "Turret is player-owned after takeover")

func _test_power_hazard() -> void:
	print("\n--- Test: power conduit overload creates hazard ---")
	var tns := _make_test_network()
	var result := tns.perform_operation("node_power_1", "overload", "player_0", 2)
	_check(bool(result.get("success", false)), "Power overload succeeds")
	_check(bool(result.get("hazard_created", false)), "Hazard created")
	var hazard_pos: Vector2i = result.get("hazard_pos", Vector2i(-1, -1))
	_check(hazard_pos.x >= 0, "Hazard position valid")

func _test_beacon_delay() -> void:
	print("\n--- Test: beacon delay when disabled ---")
	var tns := _make_test_network()
	var original_delay := tns.get_beacon_delay("node_beacon_1")
	_check(original_delay > 0, "Beacon has initial delay turns")
	var result := tns.perform_operation("node_beacon_1", "disable", "player_0", 2)
	_check(bool(result.get("success", false)), "Beacon disable succeeds")
	var new_delay := tns.get_beacon_delay("node_beacon_1")
	_check(new_delay > original_delay, "Beacon delay increased after disable (was %d, now %d)" % [original_delay, new_delay])

func _test_operations_cost_1ap() -> void:
	print("\n--- Test: takeover, disable, overload each cost 1AP ---")
	var tns := _make_test_network()
	# takeover costs 1 AP (player has 2 AP)
	var r1 := tns.perform_operation("node_cam_1", "takeover", "player_0", 2)
	_check(int(r1.get("ap_cost", 0)) == 1, "Takeover costs 1 AP")
	_check(int(r1.get("ap_remaining", 0)) == 1, "1 AP remaining after takeover")
	# With 1 AP remaining, can do another operation
	var r2 := tns.perform_operation("node_door_1", "disable", "player_0", 1)
	_check(int(r2.get("ap_cost", 0)) == 1, "Disable costs 1 AP")
	_check(int(r2.get("ap_remaining", 0)) == 0, "0 AP remaining after disable")
	# With 0 AP, cannot do another operation
	var r3 := tns.perform_operation("node_turret_1", "overload", "player_0", 0)
	_check(not bool(r3.get("success", true)), "Operation fails with 0 AP")
	_check(r3.get("reason", "") == "no_ap", "Failure reason is no_ap")

func _test_unknown_operation_rejected() -> void:
	print("\n--- Test: unknown operation rejected ---")
	var tns := _make_test_network()
	var result := tns.perform_operation("node_cam_1", "hack", "player_0", 2)
	_check(not bool(result.get("success", true)), "Unknown operation rejected")
	_check(result.get("reason", "") == "unknown_operation", "Reason is unknown_operation")

func _test_damaged_node_no_operations() -> void:
	print("\n--- Test: damaged node rejects operations ---")
	var tns := _make_test_network()
	tns.perform_operation("node_cam_1", "disable", "player_0", 2)
	_check(tns.get_node_state("node_cam_1") == "damaged", "Node is damaged")
	var result := tns.perform_operation("node_cam_1", "takeover", "player_0", 2)
	_check(not bool(result.get("success", true)), "Operation on damaged node rejected")
	_check(result.get("reason", "") == "node_damaged", "Reason is node_damaged")

func _print_summary() -> void:
	print("\n=== TacticalNetworkState: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
