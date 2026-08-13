# Task 5 Production Fix Report: M1 Three-Stage HUD Progress

## Scope

Focused commit scope:

- `tactical-grid/client/data/v2/missions.json`
- `tactical-grid/client/tests/v2/v2_m1_player_facing_progress_test.gd`
- `tactical-grid/client/tests/v2/v2_objective_hud_contract_test.gd`
- `.superpowers/sdd/2026-08-13-v2-m1-core-fun-implementation/task-5-hud-progress-report.md`

No V1 file, user-dirty `tactical-grid/client/data/levels.json`, untracked
`docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`, input,
camera, combat, player E2E, or legacy expanded-flow runtime test was changed.

## Root Cause

`ch1_m1.objective_steps[2]` (`evacuate`) was explicitly marked
`player_facing: false`. `V2MissionFlow` correctly preserves all three raw
steps, but its display-progress API filters data-only steps. The shipped HUD
therefore showed `1/2` and `2/2` despite the approved three-stage M1 contract:
`找到失联侦察兵 -> 带侦察兵抵达撤离点 -> 完成撤离`.

## Red Regression

Before the production data fix, the new focused regression was run from
`tactical-grid/client`:

```powershell
$godot = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/v2/v2_m1_player_facing_progress_test.gd
```

Result: exit `1`, `Passed: 4`, `Failed: 3`.

The failures were the intended production assertions for `流程 1/3`, `流程
2/3`, and `流程 3/3`. This proved the data flag, rather than the generic
mission-flow filter, was the defect.

## Minimal Production Fix

Removed only the incorrect `player_facing: false` field from M1's `evacuate`
objective. The generic display-progress filtering API remains unchanged for
future missions that legitimately contain data-only bookkeeping steps. The
existing compatible M1 HUD contract assertions now require `1/3` and `2/3`.

## Green Verification

All commands ran from `tactical-grid/client`:

| Command | Exit | Result |
|---|---:|---|
| `--headless --path . --editor --quit-after 1` | `0` | Editor scan completed; no parse errors. Godot emitted its existing `Scan thread aborted...` shutdown warning. |
| `--script res://tests/v2/v2_m1_player_facing_progress_test.gd` | `0` | `Passed: 7`, `Failed: 0` |
| `--script res://tests/v2/v2_objective_hud_contract_test.gd` | `0` | `Passed: 35`, `Failed: 0` |
| `res://tests/v2/v2_player_turn_e2e_test.tscn` | `0` | `Passed: 78`, `Failed: 0` |
| `--script res://tests/v2/v2_context_action_resolver_test.gd` | `0` | `Passed: 29`, `Failed: 0` |
| `--script res://tests/v2/v2_direct_move_input_test.gd` | `0` | `Passed: 21`, `Failed: 0` |
| `--script res://tests/v2/v2_attack_input_test.gd` | `0` | `Passed: 19`, `Failed: 0` |
| `--script res://tests/v2/v2_enemy_occupancy_test.gd` | `0` | `Passed: 6`, `Failed: 0` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tests/v2/v2_release_isolation_test.ps1` | `0` | `V2 release isolation passed` |

The HUD contract was hardened after review to render the final `3/3` state
directly, using a rescued player unit in the evacuation zone rather than only
checking the mission-flow string.

## E2E Shutdown Diagnostics

The successful player E2E still emitted the following existing lifecycle
diagnostics after `Passed: 78`, `Failed: 0`:

```text
WARNING: 6 RIDs of type "CanvasItem" were leaked.
WARNING: 16 ObjectDB instances were leaked at exit.
ERROR: 2 resources still in use at exit.
```

They are recorded separately from the gameplay pass and are not reclassified
as clean shutdown behavior by this task.
