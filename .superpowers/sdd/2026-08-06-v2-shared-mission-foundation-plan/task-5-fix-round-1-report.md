# Task 5 Fix Round 1 Report

## Scope

- Base: `6ba5a32`
- Worktree: `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2`
- Fixed all three findings from `reviews/task-5-review.md`.
- V2-only changes; no V1-specific source paths were modified.

## Fixes

- Added data-driven `player_facing: false` metadata for M1's terminal `mission_completed` bookkeeping step. `V2MissionFlow` now exposes separate display index/count methods while preserving raw objective index/count APIs for saves and tests. The controller uses display progress for HUD snapshots and raw progress for route lookup. Real M1 assertions cover rescue `1/2` and pre-evac `2/2` states.
- Added `v2_objective_hud_runtime_scene_test.tscn`, which instantiates the shipped `v2_battle.tscn`, inspects `V2HudPresenter.last_snapshot`, and checks actual HUD controls after controller mapping populates mission, objective/guide, route, hazard, checkpoint, and turn fields. The same scene enters real M1 rescue and pre-evac transitions.
- Canonical V2 HUD rendering now writes `回合 -` when both `turn` and `current_turn` are absent, preventing a stale restored label. The unit contract asserts the transition from `回合 4` to the safe default.
- V2 encounter refresh now checks encounter-zone boundaries for live player positions, allowing the real V2 movement path to write `cp_pre_evac` without changing the shared V1 movement path.

## TDD Evidence

Initial RED runs before the production changes:

- `v2_objective_hud_contract_test.gd`: exit `1`; Passed `23`; Failed `2` for the missing turn fallback and missing player-facing progress API.
- `v2_objective_hud_runtime_scene_test.tscn`: exit `1`; Passed `15`; Failed `4` for the raw M1 `1/3`/`2/3` mapping and resulting control text.
- After the test was tightened to enter the real pre-evac trigger, the scene remained RED at Passed `19`; Failed `2` until the V2 encounter-zone hook was added.

## Bounded Verification

All commands ran from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client` with:

`D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe`

| Test | Exact result |
| --- | --- |
| `v2_objective_hud_contract_test.gd` | exit `0`; Passed `28`; Failed `0` |
| `v2_hud_contract_test.gd` | exit `0`; Passed `13`; Failed `0` |
| `v2_objective_hud_runtime_scene_test.tscn` | exit `0`; Passed `21`; Failed `0` |
| `v2_hazard_runtime_scene_test.tscn` | exit `0`; Passed `31`; Failed `0` |
| `v2_hazard_controller_test.gd` | exit `0`; Passed `16`; Failed `0` |
| `v2_checkpoint_migration_test.gd` | exit `0`; Passed `22`; Failed `0` |
| `v2_checkpoint_test.gd` | exit `0`; Passed `14`; Failed `0` |
| `v2_mission_flow_contract_test.gd` | exit `0`; Passed `7`; Failed `0` |
| `v2_m1_flow_test.gd` | exit `0`; Passed `18`; Failed `0` |
| `v2_m1_progression_test.gd` | exit `0`; Passed `16`; Failed `0` |
| `v2_rescue_character_test.gd` | exit `0`; Passed `19`; Failed `0` |
| `v2_rescue_battle_integration_test.tscn` | exit `0`; Passed `13`; Failed `0` |
| `v2_m1_evacuation_bridge_test.tscn` | exit `0`; Passed `27`; Failed `0` |
| `v2_encounter_queue_test.gd` | exit `0`; Passed `12`; Failed `0` |
| `v2_enemy_occupancy_test.gd` | exit `0`; Passed `6`; Failed `0` |
| `v2_runtime_isolation_contract.tscn` | exit `0`; Passed `6`; Failed `0` |
| `v2_battle_runtime_contract_test.gd` | exit `0`; Passed `4`; Failed `0` |
| `tests/battle_smoke_test.tscn` | exit `0`; Passed `1816`; Failed `0` |

`git diff --check`: exit `0`.

## Warnings

- `v2_objective_hud_runtime_scene_test.tscn`, `v2_hazard_runtime_scene_test.tscn`, and `v2_runtime_isolation_contract.tscn` each emitted exactly: `WARNING: 2 ObjectDB instances were leaked at exit (run with --verbose for details).` and `ERROR: 1 resources still in use at exit (run with --verbose for details).` Their exit codes were `0` and all assertions passed.
- V1 smoke emitted exactly: `WARNING: Save file corrupted or missing, trying backup: user://saves/save_0.bak` and `WARNING: Save file corrupted or missing, trying backup: user://saves/save_1.bak`; it reported Passed `1816`, Failed `0`, exit `0`.
- `git diff --check` emitted Windows working-copy notices that LF will be replaced by CRLF for touched files; it exited `0` and reported no whitespace errors.

## Cleanup

- No generated artifacts were added or modified by this fix round; existing artifact directories remain unchanged.
- No V1-specific source paths were changed.
