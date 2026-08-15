# Task 9 Report: Readable Enemy Roles And Intent Shapes

## Status

Complete on `codex/ch1-infiltration-v2` after the implementation commit.

## Scope

- Added a data-only `V2IntentPresenter` that maps attack, telegraph, move,
  scan, protect, and guard intents to stable semantic shapes, target data,
  optional damage text, icon keys, and pulse state.
- V2 enemy planning now stores the presentation payload beside the public
  intent, and the V2 HUD presenter normalizes the same payload for HUD-facing
  snapshots. This keeps the map overlay and HUD on one contract.
- The existing intent overlay now draws V2 scan cones, protection links, and
  non-targeting guard diamonds while retaining the old drawing path for V1 and
  older intents without a presentation payload.
- Unit role markers are larger and have a dedicated outline. Unit rings no
  longer carry a second job-color arc, so rings communicate faction/selection
  while the adjacent marker communicates job identity. Text badges remain as
  optional accessibility support.
- No new bitmap assets were introduced. The change reuses the existing unit
  sprites, role accents, and overlay drawing layer.

## Verification

All commands below were run in the isolated V2 worktree with Godot
`4.7.1-stable`.

| Command | Result |
|---|---:|
| `v2_intent_presentation_test.gd` | `Passed: 11`, `Failed: 0` |
| `v2_hud_contract_test.gd` | `Passed: 13`, `Failed: 0` |
| `gate_manifest_test.gd` | `Passed: 5`, `Failed: 0` |
| `v2_encounter_controller_regression_test.tscn` | `Passed: 33`, `Failed: 0` |
| `v2_m1_visual_snapshot.tscn` | `Passed: 5`, `Failed: 0` |
| All 61 manifest script tests, sequentially | `SCRIPT_FAILURES=0` |
| Godot editor headless parse/import scan | Exit `0`; no parse error |

The visual matrix generated the normal start screenshot successfully. The
matrix stopped at its legacy `route_split` assertion because that fixture still
requires the retired route-selection phase/modal. The screenshot itself was
written successfully; the failure is a stale flow contract, not a parser or
runtime failure.

## Isolation

- V1 battle planning and V1 intent rendering remain unchanged when no V2
  presentation payload is present.
- The existing user-owned changes remain untouched:
  `tactical-grid/client/data/levels.json` and
  `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`.

## Follow-up

Task 10 must reconcile the production M1 mission flow and old visual/checkpoint
fixtures around the locked three-step `find -> rescue -> evacuate` design. In
particular, it should remove the route-choice modal from the production path and
replace the `route_split` visual expectation with a spatial route discovery
state.
