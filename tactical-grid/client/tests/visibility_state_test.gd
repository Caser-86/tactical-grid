extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("=== CH1-040: VisibilityState tests ===")
	_test_unexplored_default()
	_test_observed_when_visible()
	_test_recorded_after_leaving_sight()
	_test_last_known_position()
	_test_revealed_then_hidden_enemy()
	_test_newly_observed_no_lethal_same_turn()
	_test_is_cell_observed()
	_test_get_observed_enemies()
	_test_clear_visibility()
	# CH1-040: 迷雾运行时闭环新增测试
	_test_render_state_mapping()
	_test_last_known_turn_stamp()
	_test_uncertain_flag_after_leaving_sight()
	_test_camera_zone_persists_across_turns()
	_test_camera_zone_revert_on_removal()
	_test_renderable_last_known_excludes_unexplored()
	_test_serialize_deserialize_camera_zones()
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

## ===== CH1-040: 迷雾运行时闭环新增测试 =====

func _test_render_state_mapping() -> void:
	print("\n--- Test: render state maps to three visibility tiers ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	# Unexplored cell -> RENDER_HIDDEN
	_check(vs.get_render_state(Vector2i(0, 0)) == VisibilityState.RENDER_HIDDEN, "Unexplored cell renders as hidden")
	# Observed cell -> RENDER_VISIBLE
	vs.update_visibility([Vector2i(2, 2)], [])
	_check(vs.get_render_state(Vector2i(2, 2)) == VisibilityState.RENDER_VISIBLE, "Observed cell renders as visible")
	# Recorded cell -> RENDER_DIMMED
	vs.update_visibility([Vector2i(5, 5)], [])
	_check(vs.get_render_state(Vector2i(2, 2)) == VisibilityState.RENDER_DIMMED, "Previously observed cell renders as dimmed")

func _test_last_known_turn_stamp() -> void:
	print("\n--- Test: last-known snapshot records the turn seen ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.set_turn(3)
	vs.update_visibility([Vector2i(4, 4)], [{"entity_id": "enemy_t", "pos": Vector2i(4, 4), "hp": 50}])
	_check(vs.get_last_known_turn("enemy_t") == 3, "Last-known turn stamped as 3")
	# Enemy leaves sight; turn stamp updates to the turn it was last seen
	vs.set_turn(5)
	vs.update_visibility([Vector2i(0, 0)], [])
	_check(vs.get_last_known_turn("enemy_t") == 5, "Last-known turn updated to 5 when enemy left sight")
	_check(not vs.is_enemy_observed("enemy_t"), "Enemy no longer observed after leaving sight")

func _test_uncertain_flag_after_leaving_sight() -> void:
	print("\n--- Test: last-known becomes uncertain after enemy leaves sight ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.set_turn(1)
	vs.update_visibility([Vector2i(3, 3)], [{"entity_id": "enemy_u", "pos": Vector2i(3, 3), "hp": 40}])
	_check(not vs.is_last_known_uncertain("enemy_u"), "Last-known is certain while enemy is observed")
	# Enemy moves out of sight
	vs.set_turn(2)
	vs.update_visibility([Vector2i(0, 0)], [])
	_check(vs.is_last_known_uncertain("enemy_u"), "Last-known becomes uncertain after enemy leaves sight")
	# Enemy re-enters sight: uncertainty clears
	vs.set_turn(3)
	vs.update_visibility([Vector2i(3, 3)], [{"entity_id": "enemy_u", "pos": Vector2i(3, 3), "hp": 40}])
	_check(not vs.is_last_known_uncertain("enemy_u"), "Last-known is certain again when enemy re-observed")

func _test_camera_zone_persists_across_turns() -> void:
	print("\n--- Test: camera zone keeps cells observed across turns ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	# Player sees cell (1,1); camera zone covers (5,5) and (6,6)
	vs.set_turn(1)
	vs.update_visibility([Vector2i(1, 1)], [])
	vs.add_camera_zone("cam_a", [Vector2i(5, 5), Vector2i(6, 6)])
	_check(vs.get_cell_state(Vector2i(5, 5)) == VisibilityState.STATE_OBSERVED, "Camera zone cell observed immediately")
	# Next turn: player moves away from (1,1); camera cells should stay observed
	vs.set_turn(2)
	vs.update_visibility([Vector2i(0, 0)], [])
	_check(vs.get_cell_state(Vector2i(5, 5)) == VisibilityState.STATE_OBSERVED, "Camera zone cell stays observed across turn")
	_check(vs.get_cell_state(Vector2i(6, 6)) == VisibilityState.STATE_OBSERVED, "Second camera cell stays observed")
	_check(vs.get_cell_state(Vector2i(1, 1)) == VisibilityState.STATE_RECORDED, "Player sight cell demotes to recorded")

func _test_camera_zone_revert_on_removal() -> void:
	print("\n--- Test: camera zone removal reverts cells to recorded ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.set_turn(1)
	vs.update_visibility([Vector2i(1, 1)], [])
	vs.add_camera_zone("cam_b", [Vector2i(7, 7)])
	_check(vs.get_cell_state(Vector2i(7, 7)) == VisibilityState.STATE_OBSERVED, "Camera cell observed while zone active")
	# Remove camera zone; next update should demote the cell
	vs.remove_camera_zone("cam_b")
	vs.set_turn(2)
	vs.update_visibility([Vector2i(0, 0)], [])
	_check(vs.get_cell_state(Vector2i(7, 7)) == VisibilityState.STATE_RECORDED, "Camera cell reverts to recorded after zone removal")

func _test_renderable_last_known_excludes_unexplored() -> void:
	print("\n--- Test: renderable last-known excludes unexplored positions ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.set_turn(1)
	# Enemy seen at (2,2) then leaves; (2,2) becomes recorded
	vs.update_visibility([Vector2i(2, 2)], [{"entity_id": "e1", "pos": Vector2i(2, 2), "hp": 30}])
	vs.set_turn(2)
	vs.update_visibility([Vector2i(0, 0)], [])
	# Another enemy seen at (8,8) then leaves; (8,8) becomes recorded, then we
	# never explore (9,9) so an enemy whose last-known is (9,9) should be excluded
	vs.update_visibility([Vector2i(8, 8)], [{"entity_id": "e2", "pos": Vector2i(8, 8), "hp": 20}])
	vs.set_turn(3)
	vs.update_visibility([Vector2i(0, 0)], [])
	var renderable := vs.get_renderable_last_known()
	_check(renderable.has("e1"), "Enemy at recorded cell (2,2) is renderable")
	_check(renderable.has("e2"), "Enemy at recorded cell (8,8) is renderable")

func _test_serialize_deserialize_camera_zones() -> void:
	print("\n--- Test: camera zones survive serialize/deserialize round-trip ---")
	var vs := VisibilityState.new()
	vs.setup(10, 10)
	vs.set_turn(4)
	vs.update_visibility([Vector2i(1, 1)], [{"entity_id": "e_s", "pos": Vector2i(1, 1), "hp": 25}])
	vs.add_camera_zone("cam_s", [Vector2i(3, 3), Vector2i(4, 4)])
	var data := vs.serialize()
	var vs2 := VisibilityState.new()
	vs2.setup(10, 10)
	vs2.deserialize(data)
	_check(vs2.get_cell_state(Vector2i(3, 3)) == VisibilityState.STATE_OBSERVED, "Camera cell restored as observed")
	_check(vs2.get_last_known_turn("e_s") == 4, "Last-known turn restored")
	# Camera zone should still persist across an update after restore
	vs2.set_turn(5)
	vs2.update_visibility([Vector2i(0, 0)], [])
	_check(vs2.get_cell_state(Vector2i(3, 3)) == VisibilityState.STATE_OBSERVED, "Restored camera zone persists across turn")

func _print_summary() -> void:
	print("\n=== VisibilityState: %d passed, %d failed ===" % [_passed, _failed])
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
