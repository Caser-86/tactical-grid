# Task 2 Fix Round 1 Report

## Files Changed

- `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- `tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd`
- `tactical-grid/client/tests/v2/v2_m1_flow_test.gd`
- `tactical-grid/client/tests/v2/v2_rescue_character_test.gd`

## Root Causes And Fixes

- Configured M1 objective steps were bypassed by a special `evac_checked` branch. After advancing `escort_scout`, it inspected the new current `evacuate` step and completed the mission instead of waiting for that step's configured `mission_completed` event. The special completion branch was removed. The legacy two-step fallback still completes on `evac_checked`, while the configured three-step M1 now advances to `evacuate` and completes only on `mission_completed`.
- `V2RescueController` added the rescued Unit to the owning player list and invoked its runtime registration callback before the mission flow accepted `character_rescued`. A rejected flow could therefore leave a freed Unit in TurnManager, sprites, or other callback-owned registries. The controller now asks the flow first; rejected rescues restore the actor's action/HP and free the unregistered Unit. Only accepted events update the captive state and invoke the runtime registration callback.
- `v2_rescue_character_test.gd` had already timed out on the base implementation. It still times out after the code fix even after terminating stale V2 test Godot child processes, so this regression is not verified as resolved in this round. The test now includes a focused assertion that a rejected rescue leaves the owning player array, mission flow player array, registration callback, and created Unit clean.

## Commands And Exact Results

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Exit code: `0`

```text
Passed: 7
Failed: 0
```

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_m1_flow_test.gd
```

Exit code: `0`

```text
Passed: 17
Failed: 0
```

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_rescue_character_test.gd
```

Bounded at 60 seconds. Exact tool result:

```text
Exit code: 124
Wall time: 64.1 seconds
command timed out after 64051 milliseconds
```

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_rescue_battle_integration_test.gd
```

Exit code: `1`. Compilation failed before the test because existing scripts could not resolve `GameManager` (`tutorial_hint.gd:55`, `pause_menu.gd:77`, `battle_controller.gd:277`, and `battle_camera_controller.gd:198`).

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_checkpoint_migration_test.gd
```

Exit code: `1`

```text
Passed: 1
Failed: 1
```

The failing migration contract is a Task 4 schema 3-to-4 implementation dependency outside Task 2.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_encounter_queue_test.gd
```

Exit code: `1`

```text
Passed: 0
Failed: 2
```

The failing encounter queue contracts are Task 3 dependencies outside Task 2.

## Completion Update

This section supersedes the interrupted status above for this fix round.

### Root Causes

- The salvaged configured-M1 implementation had an earlier `evac_checked` completion bypass removed, so the first evacuation check now advances `escort_scout` to the configured `evacuate` step without victory. `missions.json` already defines that final step with `complete_event: "mission_completed"`; the subsequent event completes the mission. Legacy fixtures without `objective_steps` continue to use the two-step fallback.
- A completed final event was checked after terminal-state rejection, returning `mission_finished` instead of the required idempotent `event_already_completed`. Completion history is now checked before terminal-state handling.
- The rescue controller was correctly salvaged to submit `character_rescued` before any live registration. The timed-out script exposed a separate parser regression: GDScript could not infer the type of `action_available_before` from the V2 turn state. The script then continued after its dependent preload failed and never reached its test runner `quit`. The variable is explicitly typed as `bool`.

### Files Changed

- `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- `tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd`
- `tactical-grid/client/tests/v2/v2_m1_flow_test.gd`
- `tactical-grid/client/tests/v2/v2_rescue_character_test.gd`
- `.superpowers/sdd/2026-08-06-v2-shared-mission-foundation-plan/task-2-fix-round-1-report.md`

The temporary `v2_rescue_character_probe.gd` used to isolate the timeout was removed. The existing tracked `user_data_path_probe.gd` predates this fix round and was left unchanged.

### Final Verification

All commands were run from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2` with a 60-second command timeout.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Exit code: `0`; `Passed: 7`, `Failed: 0`.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_m1_flow_test.gd
```

Exit code: `0`; `Passed: 18`, `Failed: 0`. This includes configured `evac_checked` progression, final `mission_completed` victory, and duplicate-final-event idempotence.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_rescue_character_test.gd
```

Exit code: `0`; `Passed: 19`, `Failed: 0`. This includes the rejected-rescue assertion for player, mission-flow, action-service, callback, and object-lifetime registries.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path tactical-grid/client --script res://tests/v2/v2_m1_progression_test.gd
```

Exit code: `0`; `Passed: 16`, `Failed: 0`.

### Remaining Concerns

- `v2_rescue_battle_integration_test.gd` still exits `1` before its assertions because standalone `--script` compilation cannot resolve the project `GameManager` autoload in existing UI and battle scripts. This is unrelated to the rescue transaction and was not changed here.
- `v2_checkpoint_migration_test.gd` remains `Passed: 1`, `Failed: 1` (Task 4 schema migration not implemented), and `v2_encounter_queue_test.gd` remains `Passed: 0`, `Failed: 2` (Task 3 encounter queue not implemented). Both are outside this Task 2 fix round.
