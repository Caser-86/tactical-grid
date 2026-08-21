# Task 8 Report: Distinct M1 Enemy Tactical Plans

## Status

Complete on `codex/ch1-infiltration-v2` after the implementation commit.

## Scope

- Added independent, deterministic strategy classes for sentries, drones, and
  shield guards, plus a registry used by the stable `V2EnemyBrain` entry point.
- Sentries attack only from a legal line, otherwise reposition to a legal
  line-improving cell or guard instead of pursuing the nearest player.
- Drones prioritize high-value or unobserved scan cells, show a scan telegraph,
  and only use direct attack as an explicit safe fallback.
- Shield guards protect a priority ally, otherwise claim an authored choke cell,
  and attack only when neither protection nor blocking is available.
- The V2 controller now previews the same strategy result that the executor
  commits. Protect, scan, telegraph, and guard intents have readable map
  markers, while the V1 planner path remains unchanged.
- Executor validation now rechecks scan cells, scan radius, protect target
  identity/position, occupancy, line of sight, and state revision. Every
  invalid result is non-damaging and reports a `fallback_reason` plus the next
  fallback revision.
- Enemy data declares the strategy and intent label for the three M1 roles.

## Verification

All commands below were run in the isolated V2 worktree with Godot
`4.7.1-stable`.

| Command | Result |
|---|---:|
| `v2_enemy_strategy_test.gd` | `Passed: 24`, `Failed: 0` |
| `v2_enemy_intent_contract_test.gd` | `Passed: 21`, `Failed: 0` |
| `v2_enemy_occupancy_test.gd` | `Passed: 6`, `Failed: 0` |
| `v2_m1_enemy_activation_test.gd` | `Passed: 25`, `Failed: 0` |
| `v2_encounter_controller_regression_test.tscn` | `Passed: 33`, `Failed: 0` |
| All manifest script tests, sequentially | Every listed test exited successfully with `Failed: 0` |
| Godot editor headless parse/import scan | Exit `0`; no parse error |

The full scene manifest was also run. The newly touched formal encounter
controller scene passed. Three unrelated legacy fixtures still fail because
they assert retired M1 contracts:

- `v2_rescue_battle_integration_test.tscn`: expects the retired route-split
  flow before rescue, while production `ch1_m1` currently uses the locked
  three-stage rescue/escort/evacuation flow.
- `v2_m1_m2_checkpoint_scene_test.tscn`: its M1 checkpoint expectations still
  use the retired route/gantry step IDs and flags; all M2 checkpoint cases pass.
- `v2_base_progression_scene_test.tscn`: expects the old `20-25 分钟` M1 base
  copy, while production M1 data declares `12-18` minutes.

These failures are recorded rather than hidden. They belong to the later
legacy-fixture reconciliation task and are not caused by the enemy strategy
files; the current M1 config tests already assert the production contract.
Scene shutdown output also retains the repository's existing resource-leak
diagnostics, with no additional test failures.

## Isolation

The commit excludes pre-existing user-owned changes:

- `tactical-grid/client/data/levels.json`
- `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`

No V1 AI, V1 map, or V1 battle execution path was changed. The shared intent
renderer only adds cases for intent types produced by the V2 strategy bridge;
existing V1 intent types retain their original rendering.

## Follow-up

Task 9 should expose enemy identity and role feedback in the V2 HUD without
requiring the player to read Chinese labels. The three stale scene fixtures
should be reconciled against the locked production M1 flow before the release
gate is called fully green.
