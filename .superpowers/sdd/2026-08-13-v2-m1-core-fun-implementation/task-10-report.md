# Task 10 Report: Simplify Production M1 To Find, Rescue, Evacuate

## Status

Complete on `codex/ch1-infiltration-v2` in this changeset.

## Scope

- Locked production `ch1_m1` to one readable three-step objective chain:
  `find_scout` -> `rescue_scout` -> `evacuate_squad`.
- Removed route selection, gantry operation, and evacuation interception from
  the production path. The authored expanded route remains available only when
  a test or caller explicitly sets `expanded_flow: true`, so the old content is
  preserved without mixing it into the shipped M1 onboarding.
- Added a real proximity transition: reaching the rescue marker advances the
  mission to the rescue step; rescue is still an explicit action and cannot be
  completed early.
- Made the final production event `squad_evacuated`, requiring every conscious
  controlled unit to be inside the evacuation zone. The controller now uses the
  configured step event instead of synthesizing a legacy terminal event.
- Refreshed the HUD checkpoint timing so `cp_rescue` is visible immediately
  after rescue, and removed the stale old-route HUD/test assumptions.
- Updated production E2E, rescue bridge, checkpoint, HUD, base-duration, and
  visual-matrix fixtures. The visual matrix now covers `start`, `combat`,
  `search`, `rescue`, `evac`, and `result` rather than the retired route split.
- Fixed a Godot 4.7 runtime error caused by passing `Vector2i` through the
  `String(...)` constructor in drone scan planning and execution logs.
- Added the production-flow contract test to the V2 gate manifest.
- Event history now records whether an event attempt succeeded, allowing
  bridge tests to distinguish a rejected evacuation attempt from a committed
  terminal event.

## Verification

All commands were run from `tactical-grid/client` in the isolated V2 worktree
with Godot `4.7.1-stable`.

| Command | Result |
|---|---:|
| `v2_m1_production_flow_test.gd` | `Passed: 10`, `Failed: 0` |
| `v2_objective_hud_runtime_scene_test.tscn` | `Passed: 48`, `Failed: 0` |
| `v2_base_progression_scene_test.tscn` | `Passed: 33`, `Failed: 0` |
| `v2_m1_e2e_test.tscn --v2-m1-e2e-route=main_direct` | `Passed: 21`, `Failed: 0` |
| `v2_m1_e2e_test.tscn --v2-m1-e2e-route=optional_record` | `Passed: 23`, `Failed: 0` |
| `v2_m1_e2e_test.tscn --v2-m1-e2e-route=checkpoint_retry` | `Passed: 24`, `Failed: 0` |
| `run_m1_visual_matrix.ps1` | `36/36` PNG snapshots, 2 resolutions x 3 modes x 6 stages |
| Full `gate_manifest.json` script + scene tests, sequentially | `78` passed, `0` failed |

The scene runs still print the repository's existing Godot shutdown cleanup
diagnostics (`CanvasItem` RIDs/ObjectDB/resources in use). They occur after
successful test completion and did not produce a non-zero exit code. The
headless visual tests validate contracts; the Windows compatibility visual
matrix produced all 36 non-empty, correctly sized PNGs.

## Isolation

The implementation commit intentionally excludes these pre-existing
user-owned changes:

- `tactical-grid/client/data/levels.json`
- `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`

V1 mission and battle paths remain unchanged. Legacy expanded M1 fixtures keep
their explicit `expanded_flow: true` contract, while production data defaults
to the simplified chain.

## Acceptance Notes

Production M1 now teaches one path without a route modal: move toward the
cyan scout marker, rescue when adjacent, then move every conscious squad member
into the green evacuation zone. The main objective stays visible as `1/3`,
`2/3` only while the rescue step is active, and `3/3` after rescue while the
squad evacuates; the final HUD switches to an explicit completion message.
