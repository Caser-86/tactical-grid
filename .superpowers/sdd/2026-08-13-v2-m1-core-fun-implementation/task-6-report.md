# Task 6 Report: Replace Full-Board Overlays With Progressive Affordances

## Status

Implemented and reviewed in commits `be85f0c`, `6cd869e`, `26f1d2f`, `7e43e2f`, and `7495853`.

The final focused review was clean. `7495853` also routes facility-menu entry through the centralized locked-attack cleanup path so a menu cannot retain attack focus, damage numbers, or intent cues.

## Scope

- Added the pure `V2ActionPreview` contract for move and attack previews.
- Replaced broad red attack fills with persistent legal-target outlines and query-backed transient previews.
- Added exact movement paths, destination markers, attack damage/HP-after labels, and separate persistent/transient layers.
- Reused the same query-backed preview for target legality and commit validation, including full-cover rejection.
- Guarded stale context previews and preserved locked attack previews while another enemy is hovered.
- Cleared locked and transient attack visuals before facility interaction menus.
- Preserved one-click legal movement, one-click legal attack, right-click cancellation, camera/input routing, V1 behavior, and V2 release isolation.

## Red Baseline

The pre-Task-6 presenter consumed `attack_query.range_cells` and rendered every cell as a broad red `v2_attack_overlay`. The pre-Task-6 affordance contract explicitly required at least four such overlays. This source/test baseline establishes the old misleading behavior; no standalone numeric baseline run was captured before the interrupted Task 6 worker, so no fabricated baseline count is reported here.

## Verification

All commands below were run from `tactical-grid/client` with Godot `4.7.1.stable.official.a13da4feb`.

| Command | Exit | Actual result |
|---|---:|---|
| `--script res://tests/v2/v2_affordance_contract_test.gd` | `0` | `Passed: 24`, `Failed: 0` |
| `--script res://tests/v2/v2_action_preview_test.gd` | `0` | `Passed: 20`, `Failed: 0` |
| `--script res://tests/v2/v2_direct_move_input_test.gd` | `0` | `Passed: 23`, `Failed: 0` |
| `--script res://tests/v2/v2_attack_input_test.gd` | `0` | `Passed: 27`, `Failed: 0` |
| `res://tests/v2/v2_player_turn_e2e_test.tscn` | `0` | `Passed: 78`, `Failed: 0`; existing shutdown diagnostics remain: 6 CanvasItem RIDs, 16 ObjectDB instances, 2 resources in use |
| `--scene res://tests/v2/v2_m1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=normal --qa-stage=combat` | `0` | `Passed: 10`, `Failed: 0`; headless runner reports no framebuffer |
| `powershell -File tests/v2/run_m1_visual_matrix.ps1 ...` | non-zero | Produced and visually inspected `artifacts/v2/verification/m1-graybox/screenshots/1280x720_normal_combat.png`; combat stage passed 12 checks, then the pre-existing `route_split` assertion failed because the current M1 starts at `search_scout` |
| `--editor --quit-after 1` | `0` | Project scan completed with existing `Scan thread aborted` warning |
| `powershell -File tests/v2/v2_release_isolation_test.ps1` | `0` | `V2 release isolation passed`; V2 entry `scenes/v2_boot.tscn`, isolated user directory `TacticalGrid_V2_Infiltration` |

The actual 1280x720 combat screenshot showed cyan reachable cells, a single legal enemy target outline, query-backed attack damage/HP-after feedback, and no full-board red fill. Headless assertions alone are not treated as visual approval.

## Changed Files

- `tactical-grid/client/scripts/game/battle_controller.gd`
- `tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd`
- `tactical-grid/client/scripts/v2/presentation/v2_action_preview.gd`
- `tactical-grid/client/tests/v2/v2_affordance_contract_test.gd`
- `tactical-grid/client/tests/v2/v2_action_preview_test.gd`
- `tactical-grid/client/tests/v2/v2_direct_move_input_test.gd`
- `tactical-grid/client/tests/v2/v2_attack_input_test.gd`
- `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`
- `tactical-grid/client/tests/v2/gate_manifest.json`

## Remaining Risks

- The player-turn scene still reports the existing shutdown leaks listed above. This task did not expand into test-scene ownership/lifecycle refactoring.
- The legacy visual matrix still expects `route_split`; it must be reconciled with the current three-stage M1 flow in a later task, without weakening the assertion.
- `intent_change` is supported by the presentation contract, but the live V2 attack service does not currently populate it for every attack; future enemy-strategy work can provide meaningful intent-change cues.
- The screenshot matrix is not fully green, so Task 6 establishes the progressive affordance contract but does not by itself grant final visual-release approval.

## User-Owned Changes Preserved

The following were not staged or modified by Task 6:

- `tactical-grid/client/data/levels.json`
- `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`
