# Task 3 Fix Round 2 Report

## Scope

- Base commit: `346dbaf`
- Worktree: `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2`
- V1 files and V1 runtime paths changed: none
- Fix scope: replace direct controller-regression departure mutation with real encounter-trigger coverage, report trigger departures in the V2 delta, and verify controller cleanup/promotion/no-respawn behavior.

## RED Evidence

Command from `tactical-grid\client`:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_encounter_controller_regression_test.tscn
```

Result before the production delta change: exit `1`; `Passed: 30`, `Failed: 1`.

Expected failure:

```text
[FAIL] 真实遭遇 delta 报告 waiting 离场 deactivated_ids
```

The same run already proved the real `enter_record_radius` trigger cleaned the waiting Units and released their occupancy; only the returned `deactivated_ids` contract was missing the trigger-departed waiting IDs.

## Implementation

- `V2EncounterActivation._apply_encounter()` now includes every encounter-triggered departure in `deactivated_ids`, including waiting IDs, while preserving live-ID protection and the persistent departed state.
- The V2 controller comment now documents that both active and waiting trigger departures are reported and that the authoritative departed set remains the repeated-refresh cleanup source.
- The controller regression now uses real `enter_record_radius` and `pre_evac` events through `_update_v2_encounters()`; it does not call `mark_enemy_departed()`.
- The regression retains an additional waiting enemy after trigger departure, proves occupancy/sprite cleanup and stable roster identity, defeats an active Unit through the real death signal to promote a waiting Unit, checks defeated/departed IDs do not reactivate, checks active sprite/service parity, and repeats a later trigger update for no-respawn.

## Verification

All commands below were run from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client`; Godot commands were individually bounded at `60000 ms`.

| Command | Result |
|---|---|
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_encounter_controller_regression_test.tscn` | exit `0`; Passed `33`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd` | exit `0`; Passed `12`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd` | exit `0`; Passed `6`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd` | exit `0`; Passed `7`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd` | exit `0`; Passed `18`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_character_test.gd` | exit `0`; Passed `19`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_progression_test.gd` | exit `0`; Passed `16`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_battle_runtime_contract_test.gd` | exit `0`; Passed `2`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_runtime_isolation_contract.tscn` | exit `0`; Passed `6`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_rescue_battle_integration_test.tscn` | exit `0`; Passed `13`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_base_progression_scene_test.tscn` | exit `0`; Passed `24`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/gate_manifest_test.gd` | exit `0`; Passed `3`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/battle_smoke_test.tscn` | exit `0`; Passed `1816`; Failed `0` |
| `& powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1` | exit `1` at pre-existing missing `res://scripts/v2/mission/v2_hazard_controller.gd` while loading `v2_hazard_controller_test.gd`; earlier gate items passed |
| `git diff --check` | exit `0`; only existing LF-to-CRLF working-copy warnings |

## Warnings

- Controller regression emitted `4 ObjectDB instances were leaked at exit` and `2 resources still in use at exit`.
- V2 runtime isolation emitted `2 ObjectDB instances were leaked at exit` and `1 resources still in use at exit`.
- V2 rescue integration emitted `2 ObjectDB instances were leaked at exit` and `1 resources still in use at exit`.
- V1 smoke emitted the expected save-recovery warnings for `user://saves/save_0.bak` and `user://saves/save_1.bak` while exercising corrupted/missing save fallback.
- The full V2 gate remains blocked by the existing Task 4 hazard-controller preload; this is not introduced by round 2.

## Changed Files

- `.superpowers/sdd/2026-08-06-v2-shared-mission-foundation-plan/task-3-fix-round-2-report.md`
- `tactical-grid/client/scripts/v2/mission/v2_encounter_activation.gd`
- `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- `tactical-grid/client/tests/v2/v2_encounter_controller_regression_test.gd`

The existing regression scene did not require structural changes; it already loads the formal V2 controller fixture and remains unchanged.
