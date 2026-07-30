extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CODE-P2-01: VisibilityState tests ===")
	_test_unexplored_default()
	_test_observed_when_visible()
	_test_recorded_after_leaving_sight()
	_test_last_known_position()
	_test_revealed_then_hidden_enemy()
	_test_newly_observed_no_lethal_same_turn()
	_test_is_cell_observed()
	_test_get_observed_enemies()
	_test_clear_visibility()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		print("  [FAIL] ", msg)

func _test_unexplored_default() -> void:
	print("\n--- Test: unseen cells return unexplored ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	var state := vs.get_cell_state(Vector2i(5, 5))
	_check(state == VisibilityState.STATE_UNEXPLORED, "Default cell is unexplored (got %s)" % state)

func _test_observed_when_visible() -> void:
	print("\n--- Test: active sight returns observed ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	# Player at (2,2) with vision range 5 sees surrounding cells
	var visible_cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 1)]
	vs.update_visibility(visible_cells, [])
	for cell in visible_cells:
		_check(vs.get_cell_state(cell) == VisibilityState.STATE_OBSERVED, "Cell %s is observed" % str(cell))

func _test_recorded_after_leaving_sight() -> void:
	print("\n--- Test: previously visible cells return recorded ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	# Turn 1: see cells
	var visible_cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2)]
	vs.update_visibility(visible_cells, [])
	# Turn 2: move away, those cells no longer visible
	vs.update_visibility([Vector2i(8, 8)], [])
	_check(vs.get_cell_state(Vector2i(2, 2)) == VisibilityState.STATE_RECORDED, "Cell (2,2) is recorded after leaving sight")
	_check(vs.get_cell_state(Vector2i(3, 2)) == VisibilityState.STATE_RECORDED, "Cell (3,2) is recorded after leaving sight")
	_check(vs.get_cell_state(Vector2i(8, 8)) == VisibilityState.STATE_OBSERVED, "Cell (8,8) is observed")

func _test_last_known_position() -> void:
	print("\n--- Test: last-known position stored for recorded cells ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	# Create a mock enemy position
	var enemy_data := {"entity_id": "enemy_0", "pos": Vector2i(4, 4), "hp": 50}
	vs.update_visibility([Vector2i(4, 4)], [enemy_data])
	# Enemy moves away (no longer visible)
	vs.update_visibility([Vector2i(0, 0)], [])
	var last_known := vs.get_last_known("enemy_0")
	_check(last_known.has("pos"), "Last-known position stored")
	_check(last_known["pos"] == Vector2i(4, 4), "Last-known position is (4,4)")
	_check(last_known.has("hp"), "Last-known HP stored")

func _test_revealed_then_hidden_enemy() -> void:
	print("\n--- Test: revealed then hidden enemy is recorded, not observed ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	var enemy_data := {"entity_id": "enemy_1", "pos": Vector2i(5, 5), "hp": 30}
	vs.update_visibility([Vector2i(5, 5)], [enemy_data])
	# Enemy moves behind cover
	vs.update_visibility([], [])
	_check(not vs.is_enemy_observed("enemy_1"), "Hidden enemy is not observed")
	_check(vs.get_last_known("enemy_1").has("pos"), "Hidden enemy has last-known position")

func _test_newly_observed_no_lethal_same_turn() -> void:
	print("\n--- Test: newly observed enemy cannot deal unannounced lethal damage same reveal turn ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	# Enemy was not visible before
	var enemy_data := {"entity_id": "enemy_2", "pos": Vector2i(3, 3), "hp": 40}
	# Just revealed this turn
	vs.update_visibility([Vector2i(3, 3)], [enemy_data])
	_check(vs.is_newly_revealed("enemy_2"), "Enemy is newly revealed on the turn it first appears")
	_check(vs.is_enemy_observed("enemy_2"), "Newly revealed enemy is observed")
	# Next turn: no longer newly revealed
	vs.update_visibility([Vector2i(3, 3)], [enemy_data])
	_check(not vs.is_newly_revealed("enemy_2"), "Enemy is not newly revealed on second turn")

func _test_is_cell_observed() -> void:
	print("\n--- Test: is_cell_observed helper ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.update_visibility([Vector2i(1, 1), Vector2i(2, 2)], [])
	_check(vs.is_cell_observed(Vector2i(1, 1)), "Cell (1,1) is observed")
	_check(not vs.is_cell_observed(Vector2i(9, 9)), "Cell (9,9) is not observed")

func _test_get_observed_enemies() -> void:
	print("\n--- Test: get_observed_enemies returns only currently visible enemies ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	var e1 := {"entity_id": "enemy_a", "pos": Vector2i(2, 2), "hp": 40}
	var e2 := {"entity_id": "enemy_b", "pos": Vector2i(8, 8), "hp": 30}
	vs.update_visibility([Vector2i(2, 2)], [e1])
	var observed := vs.get_observed_enemies()
	_check(observed.has("enemy_a"), "enemy_a is in observed enemies")
	_check(not observed.has("enemy_b"), "enemy_b is not in observed enemies")

func _test_clear_visibility() -> void:
	print("\n--- Test: clear resets all state ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.update_visibility([Vector2i(1, 1)], [{"entity_id": "e", "pos": Vector2i(1, 1), "hp": 10}])
	vs.clear()
	_check(vs.get_cell_state(Vector2i(1, 1)) == VisibilityState.STATE_UNEXPLORED, "Cell reset to unexplored after clear")
	_check(not vs.is_enemy_observed("e"), "Enemy not observed after clear")

func _print_summary() -> void:
	print("\n=== VisibilityState: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
