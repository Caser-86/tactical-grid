# Task 4 Fix Round 1 Report

## Implementation

- Integrated `V2HazardController` into the real V2 battle loop with a narrow runtime seam:
  - `_advance_v2_hazard_player_turn()` runs at the V2 player-action boundary and renders warning/active cells.
  - `_consume_v2_hazard_enemy_phase()` runs at the V2 enemy-action boundary and applies each hazard damage event once.
  - `_commit_v2_hazard_close_action()` routes successful interaction action IDs to permanent hazard closure.
- Split hazard presentation from damage consumption:
  - `advance_player_turn()` now returns presentation state only.
  - `consume_enemy_phase_damage()` emits one-time damage events for the enemy phase.
- Made layered V2 restore transactional:
  - `restore_v2_layers()` captures Unit and service snapshots before mutation.
  - Any Unit, encounter, facility, hazard, or mission restore failure rolls runtime state back and returns `enter_battle=false`.
  - V2 battle entry now distinguishes "no pending checkpoint" from "requested checkpoint failed" and routes restore failures to an explicit error/defeat result instead of saving `cp_start`.
  - Staged rescued Units created for checkpoint restore are removed on failure.
- Tightened facility restore validation:
  - Rejects empty snapshots when facilities are configured.
  - Requires the incoming facility ID set to exactly match configured facilities.
  - Requires `id`, `type`, `state`, `used_actions`, and `revision`.
  - Rejects type mismatches, duplicate facility IDs, duplicate actions, stale snapshots, and stale per-facility revisions without partial mutation.
- Preserved schema migration compatibility by normalizing legacy facility type aliases in migrated facility snapshots.
- Restored the existing V2 HUD guide contract by adding display-only "流程 n/m" prefixes when mission data omits them, excluding terminal `mission_completed` bookkeeping steps from the displayed count.

## Focused Final Verification

All commands were run from `tactical-grid/client` with Godot 4.7.1 headless.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_hazard_controller_test.gd
```

Result: PASS

- Passed: 16
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_checkpoint_migration_test.gd
```

Result: PASS

- Passed: 22
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_battle_runtime_contract_test.gd
```

Result: PASS

- Passed: 4
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_checkpoint_test.gd
```

Result: PASS

- Passed: 14
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_interaction_service_test.gd
```

Result: PASS

- Passed: 26
- Failed: 0

## Bounded Regression Verification

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Result: PASS

- Passed: 7
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd
```

Result: PASS

- Passed: 12
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
```

Result: PASS

- Passed: 18
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_interaction_test.gd
```

Result: PASS

- Passed: 23
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_character_test.gd
```

Result: PASS

- Passed: 19
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
```

Result: PASS

- Passed: 6
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_runtime_isolation_contract.tscn
```

Result: PASS

- Passed: 6
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_player_turn_e2e_test.tscn
```

Result: PASS

- Passed: 65
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_rescue_battle_integration_test.tscn
```

Result: PASS

- Passed: 13
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_m1_retry_scene_test.tscn
```

Result: PASS

- Passed: 14
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_encounter_controller_regression_test.tscn
```

Result: PASS

- Passed: 33
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_m1_e2e_test.tscn
```

Result: PASS

- Passed: 63
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_m1_evacuation_bridge_test.tscn
```

Result: PASS

- Passed: 27
- Failed: 0

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_smoke_test.tscn
```

Result: PASS

- Passed: 1816
- Failed: 0

## Warnings

- `v2_runtime_isolation_contract.tscn` emitted the existing teardown warnings: 2 leaked `ObjectDB` instances and 1 resource-in-use error.
- `v2_rescue_battle_integration_test.tscn` emitted V2 save verification warnings for `user://saves_v2/save_0.tmp`, plus teardown leak/resource warnings.
- `v2_m1_retry_scene_test.tscn` emitted a V2 save verification warning for `user://saves_v2/save_0.tmp`, plus teardown leak/resource warnings.
- `v2_encounter_controller_regression_test.tscn` emitted teardown leak/resource warnings.
- `v2_m1_e2e_test.tscn` emitted teardown warnings for leaked CanvasItem RIDs, leaked `ObjectDB` instances, and resources still in use.
- `v2_player_turn_e2e_test.tscn` skipped screenshots in headless mode.
- `battle_smoke_test.tscn` emitted the expected save-corruption-recovery warnings for `save_0` and `save_1` backup tests.
- Git emitted LF-to-CRLF working-copy warnings for touched GDScript files on this Windows checkout.

## Notes

- The broad V2 visual matrix PowerShell runner was not run in this bounded round.
- During development, `v2_player_turn_e2e_test.tscn` initially failed the bottom-guide text assertion after the V2 start override; the final run passed after the V2 mission-flow display prefix fix.
