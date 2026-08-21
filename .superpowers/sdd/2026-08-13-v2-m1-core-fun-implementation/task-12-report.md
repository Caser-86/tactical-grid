# Task 12 Report: Complete The Deterministic Combat Feedback Chain

## Status

Complete on `codex/ch1-infiltration-v2` in this changeset.

## Scope

- Added a deterministic `projectile_or_trace` semantic event between
  `attack_started` and `hp_prestrip`. It carries the authoritative attacker and
  target cells; the existing battle-world presenter continues to render the
  camera-transformed trace and impact effect.
- Changed the damage event text to the explicit `-N` form while retaining the
  numeric damage fields used by HUD and telemetry.
- Added an optional `intent_changed` event when a defeated enemy had a public
  intent. The V2 battle controller removes that intent before presenting the
  terminal feedback and refreshes the intent display.
- Added explicit `occupancy_released` to V2 attack results when a target is
  downed. The corresponding `unit_downed` presentation event carries the same
  contract before `attack_finished`.
- Returned `hp_after` and `shield_after` from committed V2 attacks so semantic
  feedback can use the authoritative post-commit values without recalculating
  combat rules.
- Added an idempotence guard to V2 dead-sprite cleanup. A unit-died signal and
  the attack finalizer may both request cleanup, but only one timer is allowed
  to own the sprite removal.
- Kept reduced-motion behavior on the existing short state timings and
  world-feedback duration; no new shake or rules-side damage calculation was
  introduced.

## Test-first evidence

The extended presentation contract was run against the previous implementation
before production changes. It correctly failed 7 assertions: missing trace,
missing `-N` text, missing intent cancellation, and missing occupancy release
in the event chain. After the minimal implementation, the same test passed
`14/0`.

## Verification

All commands were run with Godot `4.7.1-stable` in the isolated V2 worktree.

| Command | Result |
|---|---:|
| `v2_damage_presentation_test.gd` | `Passed: 14`, `Failed: 0` |
| `v2_unit_sprite_sync_test.tscn` | `Passed: 1`, `Failed: 0` |
| `v2_enemy_occupancy_test.gd` | `Passed: 6`, `Failed: 0` |
| `v2_action_service_test.gd` | `Passed: 19`, `Failed: 0` |
| `v2_encounter_controller_regression_test.tscn` | `Passed: 33`, `Failed: 0` |
| `v2_rescue_battle_integration_test.tscn` | `Passed: 22`, `Failed: 0` |
| `v2_player_turn_e2e_test.tscn` | `Passed: 78`, `Failed: 0` |
| `v2_objective_hud_runtime_scene_test.tscn` | `Passed: 48`, `Failed: 0` |

The rescue integration exercised the real V2 action service and formal battle
controller: a defeated active enemy returned `occupancy_released`, its old
intent was removed, and duplicate cleanup requests left no enemy sprite.

One initial parallel smoke run produced a shared-save collision because two
Godot processes wrote the same `user://saves_v2/save_0` fixture at once. The
affected rescue and HUD scenes were then run sequentially and both passed with
exit code 0. The release gate remains sequential by design.

The scene runs still print the repository's existing Godot shutdown cleanup
diagnostics (`CanvasItem` RIDs/ObjectDB/resources in use). They occur after
successful test completion and did not produce a non-zero exit code.

## Isolation

The implementation intentionally excludes these pre-existing user-owned
changes:

- `tactical-grid/client/data/levels.json`
- `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`

V1 combat and presentation paths remain unchanged. This task adds no new
raster or audio assets; its visual feedback continues to use the existing legal
unit/effect catalog and world trace implementation. Asset and audio work stay
in Tasks 13 and 14.

## Acceptance Notes

An attack now has one inspectable chain: start, trace, show the old and new HP,
show reductions/shield absorption, show `-N`, cancel a defeated enemy's intent,
release its cell, and finish. The chain is deterministic in headless tests and
still readable in the actual player-turn E2E path, including reduced-motion
input coverage.
