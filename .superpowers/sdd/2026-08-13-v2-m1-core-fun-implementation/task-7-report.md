# Task 7 Report: Non-Modal M1 Onboarding And Safety Window

## Status

Complete on `codex/ch1-infiltration-v2`.

Implementation commit: `fa8945a` (`feat(v2): add non-modal M1 onboarding safety window`).

## Scope

- Replaced the V2 M1 six-step modal-style tutorial flow with five short, sequential hints:
  `选择突击兵` -> `点击青色格移动` -> `悬停红框敌人查看伤害` -> `点击敌人发动攻击` -> `敌人的箭头表示下一步行动`.
- Added stable `anchor_kind`, `anchor_id`, `text`, and `step_id` fields to the tutorial hint contract.
- Added one non-modal HUD card with a skip button. The card uses the existing V2 panel/button styling, ignores mouse input except for its own button, and is rendered from the V2 snapshot.
- Kept automatic unit selection for usability, but does not consume the first tutorial event, so the first hint remains visible while the assault unit is already focused.
- Added a three-player-turn M1 safety window. Enemy intent planning and movement remain observable; tutorial sentries cannot reduce the assault unit below 1 HP during the window. Hazards are also suppressed during the window.
- The window closes only after an attack is committed and an enemy intent is observed. Skipping the tutorial does not leave an invisible safety rule behind.
- Persisted the safety-complete flag in the V2 mission snapshot and restored it with checkpoints.
- Updated the production M1 HUD test from the retired five-stage route-split contract to the current three-stage rescue/escort/evacuation contract.

## Red Baseline

Before implementation, the new tutorial contract failed immediately because
`V2TutorialFlow` had no `get_hint()` method:

```text
SCRIPT ERROR: Invalid call. Nonexistent function 'get_hint' in base 'RefCounted (V2TutorialFlow)'.
```

This was an intentional failing baseline for the new contract.

## Verification

All commands were run from `tactical-grid/client` in the isolated V2 worktree.

| Command | Result |
|---|---:|
| `--headless --path . --script res://tests/v2/v2_m1_tutorial_test.gd` | `Passed: 19`, `Failed: 0` |
| `--headless --path . res://tests/v2/v2_objective_hud_runtime_scene_test.tscn` | `Passed: 48`, `Failed: 0` |
| `--headless --path . res://tests/v2/v2_player_turn_e2e_test.tscn` | `Passed: 78`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_m1_config_test.gd` | `Passed: 20`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_schema_reference_test.gd` | `Passed: 2`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_affordance_contract_test.gd` | `Passed: 24`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_action_preview_test.gd` | `Passed: 20`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_direct_move_input_test.gd` | `Passed: 23`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_attack_input_test.gd` | `Passed: 27`, `Failed: 0` |
| `--headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd` | `Passed: 6`, `Failed: 0` |
| `tests/v2/v2_release_isolation_test.ps1` | `V2 release isolation passed` |
| `--headless --editor --path . --quit-after 1` | Exit `0`; editor scan emitted its existing `Scan thread aborted...` shutdown diagnostic |

The scene-based tests still report the repository's existing Godot shutdown
diagnostics (`CanvasItem` RIDs/ObjectDB/resources in use). They do not produce
test failures and were not introduced by this task.

## Isolation And Uncommitted Files

The implementation commit intentionally excludes the pre-existing user-owned
changes:

- `tactical-grid/client/data/levels.json`
- `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md`

V1 tutorial and V1 battle presentation paths were not changed; the new HUD
method is called only by the V2 snapshot presenter.

## Remaining Risk

The full Windows visual matrix still needs a fresh run after Task 7. Its prior
combat stage passed, but the old route-split assertion was stale against the
current production three-stage M1 flow. Headless tests cannot provide a visual
framebuffer, so this task does not claim visual-matrix completion.
