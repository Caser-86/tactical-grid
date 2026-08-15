# Task 11 Report: Re-author Echo Yard As Three Purposeful Encounters

## Status

Complete on `codex/ch1-infiltration-v2` in this changeset.

## Scope

- Re-authored the locked production M1 map around exactly three encounters:
  `m1_e01_tutorial`, `m1_e02_rescue_routes`, and `m1_e03_evac_guard`.
- Reduced the production enemy budget to eight living enemy entities with a
  maximum of three active enemies at a time:
  one tutorial sentry; a route/rescue pool of two sentries and two drones; and
  an evacuation pool of one shield guard, one sentry, and one drone.
- Limited production M1 enemy classes to `sentry`, `drone`, and
  `shield_guard`, while retaining the existing art catalog mappings and Echo
  Yard environment kit.
- Made the route/rescue encounter spatially triggered and bounded its gap to
  at most two player turns. The evacuation guard activates only after rescue,
  with the existing camera cue and a full player response turn.
- Added evacuation activation cleanup for waiting route/rescue enemies so the
  production roster does not accumulate inactive threats after the rescue
  beat. Live protected enemies are not deactivated by this cleanup.
- Kept maintenance and cargo routes physically authored and reachable without
  introducing a route-choice entity or production modal. The optional record is
  reachable from the main-route junction and is no longer gated by a dedicated
  mandatory encounter; its round trip remains capped at two turns.
- Preserved the explicit expanded-flow fixtures and legacy route IDs for
  compatibility tests. Production data defaults to the direct, no-choice flow.
- Updated map, activation, interaction, route-consequence, expansion, HUD,
  player-turn, and encounter-lifecycle tests to assert the new production
  budget and the legal ghost-versus-real-sprite distinction.

## Test-first evidence

The new budget assertions were run against the old authored map before the
content change. The expected failures were recorded as:

| Fixture | Before re-authoring |
|---|---:|
| `v2_m1_map_test.gd` | `57 passed`, `13 failed` |
| `v2_m1_expansion_map_test.gd` | `25 passed`, `4 failed` |
| `v2_m1_enemy_activation_test.gd` | `14 passed`, `12 failed` |

## Verification

All commands were run from `tactical-grid/client` in the isolated V2 worktree
with Godot `4.7.1-stable`.

| Command | Result |
|---|---:|
| `v2_m1_map_test.gd` | `Passed: 62`, `Failed: 0` |
| `v2_m1_expansion_map_test.gd` | `Passed: 29`, `Failed: 0` |
| `v2_m1_enemy_activation_test.gd` | `Passed: 26`, `Failed: 0` |
| `v2_m1_interaction_test.gd` | `Passed: 26`, `Failed: 0` |
| `v2_m1_route_consequence_test.gd` | `Passed: 23`, `Failed: 0` |
| `v2_m1_expansion_test.gd` | `Passed: 36`, `Failed: 0` |
| `v2_m1_production_flow_test.gd` | `Passed: 10`, `Failed: 0` |
| `v2_m1_public_flow_test.gd` | `Passed: 25`, `Failed: 0` |
| `v2_encounter_controller_regression_test.gd` | `Passed: 33`, `Failed: 0` |
| `v2_player_turn_e2e_test.gd` | `Passed: 78`, `Failed: 0` |
| `v2_objective_hud_runtime_scene_test.tscn` | `Passed: 48`, `Failed: 0` |
| `run_m1_visual_matrix.ps1` | `36/36` PNG snapshots, 2 resolutions x 3 modes x 6 stages |
| `run_m2_visual_matrix.ps1` | `54/54` PNG snapshots, 2 resolutions x 3 modes x 9 stages |
| `run_m1_e2e_process_matrix.ps1` | `68` assertions, `0` failures across 3 isolated processes |
| Full `gate_manifest.json` script + scene tests, sequentially | `81` passed items, `0` failed; `1873` passed assertions, `0` failed |

The three isolated E2E routes were `main_direct`, `optional_record`, and
`checkpoint_retry`. The encounter regression explicitly ignores the legal
last-known-position fog ghost when counting real `UnitSprite` instances.

The scene runs still print the repository's existing Godot shutdown cleanup
diagnostics (`CanvasItem` RIDs/ObjectDB/resources in use). They occur after
successful test completion, did not produce a non-zero exit code, and remain a
follow-up cleanup item rather than a gameplay failure.

## Isolation

The implementation intentionally excludes these pre-existing user-owned
changes:

- `tactical-grid/client/data/levels.json`
- `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`

V1 mission and battle paths remain unchanged. No new raster or audio assets
were introduced in this task; the map continues to reuse the existing legal
Echo Yard environment and unit art catalog. Asset production and presentation
polish remain assigned to Tasks 13 and 14.

## Acceptance Notes

Echo Yard now has three readable tactical beats rather than a five-encounter
roster that front-loads too many enemies: learn movement against one sentry,
enter a spatially triggered rescue pressure zone, then face a bounded
evacuation guard after the rescue. The optional record adds a short detour
without blocking the main flow, and the retained expanded fixtures cannot
change the production route because they require an explicit compatibility
flag.
