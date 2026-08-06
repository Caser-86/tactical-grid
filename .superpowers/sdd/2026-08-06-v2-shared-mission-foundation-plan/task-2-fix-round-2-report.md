# Task 2 Fix Round 2 Report

## Scope

- Base commit: `2c640f7`
- Engine: Godot `4.7.1.stable.official.a13da4feb`
- Worktree: `ch1-infiltration-v2`
- No V1 mission data, V1 mission flow, or V1 tests were modified. The shared `BattleController` change is limited to its V2 mission-event path.

## Root Cause

Configured M1 contains three objective steps: `search_scout`, `escort_scout`, and terminal `evacuate`. The real movement path called `BattleController._apply_v2_mission_event("evac_checked")`, and `V2MissionFlow` correctly advanced `escort_scout` to `evacuate`. The runtime then stopped because `BattleController` had no follow-up `apply_event("mission_completed")`, leaving the mission short of victory and leaving `TurnManager` active.

## Fix

- Added `V2MissionEventBridge`, a V2-only production seam used by `BattleController._apply_v2_mission_event()`.
- After a successful `evac_checked` changes the flow to the final configured step, the bridge checks that the configured `complete_event` is exactly `mission_completed` and submits that event once.
- Readiness remains owned by `V2MissionFlow.apply_event("evac_checked")`; it rejects the bridge before progression unless every conscious controlled player is in the evacuation area.
- The bridge does not auto-complete legacy two-step fallback flows or terminal steps configured with `evac_checked` (including the current M2 data).
- Added `get_current_step_complete_event()` so the bridge is data-driven rather than mission-ID-specific.
- Duplicate terminal events remain rejected by the flow's existing `event_already_completed` contract.
- Added `v2_m1_evacuation_bridge_test.gd`, which exercises the production bridge seam, not a flow-only direct `mission_completed` fixture. It verifies not-ready evacuation, M1 victory, one terminal event, TurnManager `BATTLE_OVER`, duplicate suppression, and legacy two-step compatibility.

## Required Test Results

All commands were run from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client` with a 60-second command bound.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Exit code: `0`; `Passed: 7`; `Failed: 0`.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
```

Exit code: `0`; `Passed: 18`; `Failed: 0`.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_character_test.gd
```

Exit code: `0`; `Passed: 19`; `Failed: 0`.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_progression_test.gd
```

Exit code: `0`; `Passed: 16`; `Failed: 0`.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_evacuation_bridge_test.gd
```

Exit code: `0`; `Passed: 8`; `Failed: 0`.

## Formal Integration Harness Limitation

The existing formal BattleController harness was also attempted:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_battle_integration_test.gd
```

Exit code: `1`. Standalone script compilation fails before assertions because the project autoload identifier `GameManager` is unavailable in `tutorial_hint.gd:55`, `pause_menu.gd:77`, `battle_controller.gd:279`, `battle_camera_controller.gd:198`, and the integration test at line 57. The new bridge regression is therefore intentionally scoped to the production `V2MissionEventBridge` seam plus the real `TurnManager` completion handoff, and is not a flow-only direct terminal-event fixture.
