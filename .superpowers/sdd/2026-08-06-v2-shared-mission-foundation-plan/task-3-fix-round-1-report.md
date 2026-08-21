# Task 3 Fix Round 1 Report

## Scope

- Base commit: `2303988`
- Worktree: `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2`
- V1 files changed: none
- Fix: V2 controller cleanup now processes the authoritative departed set, marks departed Units occupancy-free, removes departed sprites, and refreshes V2 occupancy for both active and waiting departures.
- Regression: added a real `v2_battle.tscn` controller-level scene test covering second-encounter retention, defeat/departure cleanup, waiting promotion, occupancy, stable roster identity, and repeated updates.

## RED Evidence

Command from `tactical-grid\client`:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_encounter_controller_regression_test.tscn
```

Initial result before the production fix: exit `1`; `Passed: 17`, `Failed: 8`. The failing assertions included departed active/waiting lifecycle flags and V2ActionService occupancy release. The first test revision also exposed two fixture assumptions, so the final regression uses the real death signal, derives the actually live second-encounter Unit, and waits one frame for deferred sprite deletion.

## Verification

All commands below were run from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client`; every Godot command was individually bounded by the agent command timeout.

| Command | Result |
|---|---|
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd` | exit `0`; Passed `12`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd` | exit `0`; Passed `6`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_encounter_controller_regression_test.tscn` | exit `0`; Passed `25`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd` | exit `0`; Passed `7`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd` | exit `0`; Passed `18`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_character_test.gd` | exit `0`; Passed `19`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_progression_test.gd` | exit `0`; Passed `16`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_battle_runtime_contract_test.gd` | exit `0`; Passed `2`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_runtime_isolation_contract.tscn` | exit `0`; Passed `6`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_rescue_battle_integration_test.tscn` | exit `0`; Passed `13`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_base_progression_scene_test.tscn` | exit `0`; Passed `24`; Failed `0` |
| `& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/battle_smoke_test.tscn` | exit `0`; Passed `1816`; Failed `0` |
| `git diff --check` | exit `0` |

## Warnings

- The controller regression emitted `4 ObjectDB instances were leaked at exit` and `2 resources still in use at exit`.
- `v2_runtime_isolation_contract.tscn` emitted `2 ObjectDB instances were leaked at exit` and `1 resources still in use at exit`.
- `v2_rescue_battle_integration_test.tscn` emitted `2 ObjectDB instances were leaked at exit` and `1 resources still in use at exit`.
- V1 smoke emitted the expected save-recovery warnings for `user://saves/save_0.bak` and `user://saves/save_1.bak` while testing corrupted/missing save fallback.
- Git reported the existing LF-to-CRLF working-copy warnings for modified text files during diff inspection.

## Changed Files

- `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- `tactical-grid/client/tests/v2/gate_manifest.json`
- `tactical-grid/client/tests/v2/v2_encounter_controller_regression_test.gd`
- `tactical-grid/client/tests/v2/v2_encounter_controller_regression_test.tscn`
