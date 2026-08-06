# Task 4 Fix Round 2 Report

## Implementation

- Recomputed V2 hazard presentation immediately after a checkpoint installs the saved turn. The restored hazard snapshot is not replaced, so resolved damage-consumption keys remain intact.
- Made hazard overlay replacement synchronous so a restore cannot expose the previous turn's queued overlay nodes in the same frame.
- Added a locked-map V2 hazard fixture and a scene-backed regression through `v2_battle.tscn` and `V2BattleController`. It covers player warning, enemy-phase damage, repeated-phase idempotence, permanent `close_action_id` removal, and restored-turn presentation.
- Added a controller-entry failed-restore regression with an invalid hazard snapshot. It verifies the real V2 scene rejects the restore, does not write a new `cp_start`, routes `checkpoint_restore_failed`, and clears partial units/services.
- Registered the new scene test in `gate_manifest.json`. No V1 files were changed.

## Focused Verification

All commands ran from `tactical-grid/client` with Godot 4.7.1 headless.

| Command | Result |
| --- | --- |
| `--script res://tests/v2/v2_hazard_controller_test.gd` | PASS: 16 passed, 0 failed |
| `--script res://tests/v2/v2_checkpoint_migration_test.gd` | PASS: 22 passed, 0 failed |
| `--script res://tests/v2/v2_interaction_service_test.gd` | PASS: 26 passed, 0 failed |
| `--script res://tests/v2/v2_checkpoint_test.gd` | PASS: 14 passed, 0 failed |
| `--script res://tests/v2/v2_battle_runtime_contract_test.gd` | PASS: 4 passed, 0 failed |
| `res://tests/v2/v2_hazard_runtime_scene_test.tscn` | PASS: 30 passed, 0 failed |
| `res://tests/v2/v2_m1_retry_scene_test.tscn` | PASS: 14 passed, 0 failed |
| `res://tests/v2/v2_player_turn_e2e_test.tscn` | PASS: 65 passed, 0 failed |
| `res://tests/v2/v2_m1_e2e_test.tscn` | PASS: 63 passed, 0 failed |
| `res://tests/battle_smoke_test.tscn` | PASS: 1816 passed, 0 failed |

**Total:** 2070 passed, 0 failed.

## Warnings

- The hazard runtime scene and player-turn E2E emitted the existing teardown warnings: 2 leaked `ObjectDB` instances and 1 resource still in use.
- The M1 E2E emitted existing teardown warnings: 20 leaked CanvasItem RIDs, 46 leaked `ObjectDB` instances, and 3 resources still in use.
- The player-turn E2E skipped screenshots in headless mode.
- V1 smoke emitted its expected save-corruption recovery warnings for `save_0` and `save_1` backup cases.
- The full V2 suite and visual matrix were intentionally not run per the bounded verification request.
