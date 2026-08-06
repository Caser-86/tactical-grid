# Task 4 Fix Round 3 Report

## Scope

- Base commit: `c0843be97b825e3f37ed19a681fd7d5c02c21d6f`
- Finding fixed: V2 checkpoint restore could leave the HUD showing `回合 1` while the restored turn and hazard overlay were on turn 3.
- Production change: V2 `_start_battle()` now passes `turn_manager.turn_number` to `hud.update_turn_display()`.
- Regression: the formal V2 hazard runtime scene asserts the restored HUD label is `回合 3` alongside the restored turn and turn-3 hazard overlay.
- V1 files and the shared battle controller were not changed.

## Focused Verification

All commands were attempted from `tactical-grid/client` in this worktree.

| Command | Exact result |
| --- | --- |
| `godot --headless --path . res://tests/v2/v2_hazard_runtime_scene_test.tscn` | **BLOCKED**: PowerShell error `The term 'godot' is not recognized as a name of a cmdlet, function, script file, or operable program.` |
| `godot --headless --path . --script res://tests/v2/v2_hazard_controller_test.gd` | **BLOCKED**: same missing `godot` executable error |
| `godot --headless --path . --script res://tests/v2/v2_checkpoint_migration_test.gd` | **BLOCKED**: same missing `godot` executable error |
| `godot --headless --path . --script res://tests/v2/v2_checkpoint_test.gd` | **BLOCKED**: same missing `godot` executable error |
| `godot --headless --path . res://tests/battle_smoke_test.tscn` | **BLOCKED**: same missing `godot` executable error |
| `git diff --check` | PASS: no whitespace errors |

## Test Limitation

The red-green runtime execution could not be completed because Godot 4.7.1 is not installed or available on `PATH` in this environment. The new assertion was added before the production change, but the pre-fix and post-fix scene runs both remain unverified for this reason. No historical test result is reported as a round-3 result.

## Worktree Review

Only the V2 battle controller, the V2 hazard runtime regression, and this report are focused changes. No accidental reviewer artifacts or unrelated untracked files are present.
