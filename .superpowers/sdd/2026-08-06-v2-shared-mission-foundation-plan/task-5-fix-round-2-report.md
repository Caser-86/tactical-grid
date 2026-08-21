# Task 5 Fix Round 2 Report

## Scope

- Base: `efff544`
- Worktree: `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2`
- Focused fix: deterministic lifecycle for `tactical-grid/client/tests/v2/v2_objective_hud_contract_test.gd`.
- No production HUD, V2 runtime, or V1 source files changed.

## Root Cause

The standalone `SceneTree` contract started its work in `_initialize()` and awaited `process_frame` before the test tree had a stable active lifecycle. It also called `_assert_v1_isolation()` without awaiting its coroutine, so that helper could suspend while the parent test reached `Runner.finish()` and quit the tree. This made completion timing dependent on SceneTree scheduling and could leave the headless process without a deterministic assertion result.

## Fix

- Defer one `_run()` entry from `_initialize()` until the SceneTree is active.
- Remove both `await process_frame` calls from the standalone contract.
- Run V1 isolation synchronously after the deferred entry, then use the existing `Runner.finish(self)` path, which prints counts and calls `tree.quit(0)` on success or `tree.quit(1)` when assertions fail.
- Preserve all 31 meaningful assertions, including generic progress, priority, long text, missing-turn fallback, M1 display progress, and V1 isolation.
- The contract does not start audio, editor services, or a process loop.

## Verification

All commands ran from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client` with `D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe`.

| Test | Exact command | Bound | Exact result |
| --- | --- | --- | --- |
| HUD lifecycle invariant | PowerShell source check for `await` statements in `tests/v2/v2_objective_hud_contract_test.gd` | 10 s | exit `0`; `await_count=0`; `lifecycle_contract=PASS` |
| V2 objective HUD contract | `D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/v2/v2_objective_hud_contract_test.gd` | 30 s | `timed_out=false`; exit `0`; Passed `31`; Failed `0`; stderr empty |
| Real objective HUD runtime scene | `D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --scene res://tests/v2/v2_objective_hud_runtime_scene_test.tscn` | 60 s | `timed_out=false`; exit `0`; Passed `21`; Failed `0` |
| V1 smoke | `D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --scene res://tests/battle_smoke_test.tscn` | 120 s | `timed_out=false`; exit `0`; Passed `1816`; Failed `0` |
| Whitespace check | `git diff --check` | n/a | exit `0`; no whitespace errors |

## Warnings

- Real objective HUD runtime scene emitted exactly: `WARNING: 2 ObjectDB instances were leaked at exit (run with --verbose for details).` and `ERROR: 1 resources still in use at exit (run with --verbose for details).` Exit code remained `0` and all 21 assertions passed.
- V1 smoke emitted exactly two save-recovery warnings: `WARNING: Save file corrupted or missing, trying backup: user://saves/save_0.bak` and the same message for `user://saves/save_1.bak`. Exit code remained `0` and all 1816 assertions passed.
- `git diff --check` emitted the Windows working-copy notice that LF will be replaced by CRLF for the touched GDScript file; it reported no whitespace errors.

## Cleanup

- No generated artifacts were added or modified by this round.
- The existing `tactical-grid/client/artifacts/v2/verification/p2/` images remain unchanged.
- The pre-existing untracked `reviews/task-5-fix-round-1-review.md` was not staged or committed.
