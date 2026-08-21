# Task 1 Report: Classify And Seal The Existing Dirty Baseline

## Status

The pre-existing baseline was snapshotted before inspection. Every original
dirty path is classified in
`tactical-grid/client/docs/v2_m1_baseline_audit_2026-08-13.md`. No production
correction was made because all required focused tests passed before a fix could
be proven necessary.

## Exact Commands And Results

```powershell
New-Item -ItemType Directory -Force -Path 'tactical-grid/client/artifacts/v2'
git status --short > tactical-grid/client/artifacts/v2/baseline-2026-08-13-status.txt
git diff --no-ext-diff > tactical-grid/client/artifacts/v2/baseline-2026-08-13.diff
git diff --no-ext-diff --numstat > tactical-grid/client/artifacts/v2/baseline-2026-08-13-numstat.txt
```

Snapshot capture exit code: 0.

From `tactical-grid/client`, seven independent Godot processes were run:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_camera_input_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_input_router_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_action_service_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_enemy_occupancy_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_m1_tutorial_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_result_presentation_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_unit_art_distinction_test.gd
```

Every Godot process exited 0. Their concise results were 9, 28, 19, 6, 18, 12,
and 44 passed checks respectively, with `Failed: 0` in every output.

```powershell
& '.\tests\v2\v2_release_isolation_test.ps1'
```

The isolation process exited 0 and printed `V2 release isolation passed`.
Raw output for every required process is retained at
`tactical-grid/client/artifacts/v2/baseline-2026-08-13-v2_*.log`.

## Classification

The complete classified file table follows. It covers all 28 paths in the
original dirty status snapshot; every path has exactly one category and an
intended behavior, focused test, and keep/fix/defer decision.

| Path | Category | Intended behavior | Focused test | Decision |
| --- | --- | --- | --- | --- |
| `tactical-grid/client/data/levels.json` | unrelated | No semantic V2 M1 behavior identified; tracked content diff is empty. | `git diff --numstat` returned no row. | defer |
| `tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json` | camera_input | M1 camera facilities reveal a larger persistent area. | `v2_m1_interaction_test.gd` | keep |
| `tactical-grid/client/data/v2/missions.json` | tutorial_objective | M1 provides objective locations, a 24-turn budget, and three-turn grace period. | `v2_m1_config_test.gd`, `v2_objective_hud_runtime_scene_test.gd` | keep |
| `tactical-grid/client/scripts/data/art_catalog.gd` | art_identity | V2 enemy roles resolve distinct approved art keys. | `v2_unit_art_distinction_test.gd` | keep |
| `tactical-grid/client/scripts/game/battle_controller.gd` | camera_input | V2 camera actions, preview cancellation, safe path prompts, focus, and result context reach the runtime. | `v2_player_turn_e2e_test.gd`, `v2_camera_input_test.gd` | keep |
| `tactical-grid/client/scripts/game/mission_objective_state.gd` | tutorial_objective | V2-only turn budget and passive-enemy onboarding rules avoid changing V1 data. | `v2_objective_hud_runtime_scene_test.gd` | keep |
| `tactical-grid/client/scripts/game/unit_sprite.gd` | art_identity | Enemy roles have distinct size, accent, shape, and badge treatment. | `v2_unit_art_distinction_test.gd` | keep |
| `tactical-grid/client/scripts/game/visibility_renderer.gd` | camera_input | Persistent camera observation zones have a visible tint and border. | `v2_m1_interaction_test.gd` | keep |
| `tactical-grid/client/scripts/ui/hud.gd` | tutorial_objective | V2 HUD presents current goal, destination, completion condition, and controls. | `v2_objective_hud_runtime_scene_test.gd` | keep |
| `tactical-grid/client/scripts/ui/mission_result.gd` | combat_death | V2 failure UI states current phase and realistic next action. | `v2_result_presentation_test.gd` | keep |
| `tactical-grid/client/scripts/v2/combat/v2_action_service.gd` | movement_occupancy | Movement uses actual paths and treats live units as impassable occupants. | `v2_action_service_test.gd`, `v2_enemy_occupancy_test.gd` | keep |
| `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd` | camera_input | Middle-drag/wheel/Home input works while right-click cancels only active preview. | `v2_camera_input_test.gd`, `v2_input_router_test.gd` | keep |
| `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd` | tutorial_objective | Expanded M1 steps expose player-action copy and map guide cells. | `v2_m1_tutorial_test.gd`, `v2_objective_hud_runtime_scene_test.gd` | keep |
| `tactical-grid/client/scripts/v2/mission/v2_tutorial_flow.gd` | tutorial_objective | Tutorial hints teach primary actions but optional hints never block evacuation. | `v2_m1_tutorial_test.gd` | keep |
| `tactical-grid/client/scripts/v2/presentation/v2_result_presentation.gd` | combat_death | Result summaries reflect actual roster and failure phase. | `v2_result_presentation_test.gd` | keep |
| `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd` | camera_input | V2 captures camera gestures before UI consumption, focuses camera actions, and renders objective guidance. | `v2_camera_input_test.gd`, `v2_player_turn_e2e_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_action_service_test.gd` | movement_occupancy | Regression coverage rejects crossing an enemy and accepts a legal detour. | `v2_action_service_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_camera_input_test.gd` | camera_input | Regression coverage selects a valid player focus target after deselection. | `v2_camera_input_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_input_router_test.gd` | camera_input | Regression coverage preserves selection after right-click preview cancellation. | `v2_input_router_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_m1_config_test.gd` | tutorial_objective | Regression coverage reads M1 budget and onboarding grace configuration. | `v2_m1_config_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_m1_interaction_test.gd` | camera_input | Regression coverage asserts large M1 camera reveal and persistent zone cells. | `v2_m1_interaction_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_m1_tutorial_test.gd` | tutorial_objective | Regression coverage verifies soft hints and direct evacuation completion. | `v2_m1_tutorial_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_objective_hud_runtime_scene_test.gd` | tutorial_objective | Runtime coverage asserts guidance card, beacon, route, budget, and passive turns. | `v2_objective_hud_runtime_scene_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_player_turn_e2e_test.gd` | camera_input | Runtime coverage exercises camera interaction, front-door input, and cancellation. | `v2_player_turn_e2e_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_result_presentation_test.gd` | combat_death | Regression coverage verifies dynamic roster wording and failure phase lines. | `v2_result_presentation_test.gd` | keep |
| `tactical-grid/client/tests/v2/v2_unit_art_distinction_test.gd` | art_identity | Regression coverage verifies V2 art keys and six unique enemy role badges. | `v2_unit_art_distinction_test.gd` | keep |
| `docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md` | unrelated | User-owned P01 specification describing the baseline, not a Task 1 artifact. | Document inspection only. | defer |
| `tactical-grid/client/scripts/v2/runtime/v2_camera_focus.gd` | camera_input | Focus prefers a live selected player and otherwise finds a live player. | `v2_camera_input_test.gd` | keep |

## Files Changed By Task 1

- `tactical-grid/client/artifacts/v2/baseline-2026-08-13-status.txt`
- `tactical-grid/client/artifacts/v2/baseline-2026-08-13.diff`
- `tactical-grid/client/artifacts/v2/baseline-2026-08-13-numstat.txt`
- `tactical-grid/client/artifacts/v2/baseline-2026-08-13-v2_*.log`
- `tactical-grid/client/docs/v2_m1_baseline_audit_2026-08-13.md`
- `.superpowers/sdd/2026-08-13-v2-m1-core-fun-implementation/task-1-report.md`

## Commits

- Verified V2 baseline: `f2619791edb77ba2829185c6636b2ae4bad151ef`
- Task 1 audit: `dc11fb54afacebe79b64e684b5a025b2e95104f3`
- Task 1 snapshots and raw process evidence: `7455227b810ffcb50c704d83e3368083974d8626`

## Remaining Failures And Concerns

No required focused-test failure remains. Git printed LF-to-CRLF warnings while
reading tracked files. `tactical-grid/client/data/levels.json` has no textual
diff and, together with the user-owned P01 specification, is intentionally
unstaged as unrelated work.

## Fix Round 1: Category Commit Reconstruction

### Root Cause And Method

Review found that `f261979` mixed all retained baseline categories. No file
behavior defect was found. To preserve exact retained content without amending,
resetting, checking out, or touching unrelated work, this sequence was used:

```powershell
git revert --no-edit f2619791edb77ba2829185c6636b2ae4bad151ef
git cherry-pick --no-commit f2619791edb77ba2829185c6636b2ae4bad151ef
git commit --only -m "feat(v2): retain camera and input baseline" -- `
  'tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json' `
  'tactical-grid/client/scripts/game/battle_controller.gd' `
  'tactical-grid/client/scripts/game/visibility_renderer.gd' `
  'tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd' `
  'tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd' `
  'tactical-grid/client/scripts/v2/runtime/v2_camera_focus.gd' `
  'tactical-grid/client/tests/v2/v2_camera_input_test.gd' `
  'tactical-grid/client/tests/v2/v2_input_router_test.gd' `
  'tactical-grid/client/tests/v2/v2_m1_interaction_test.gd' `
  'tactical-grid/client/tests/v2/v2_player_turn_e2e_test.gd'
git commit --only -m "feat(v2): retain movement occupancy baseline" -- `
  'tactical-grid/client/scripts/v2/combat/v2_action_service.gd' `
  'tactical-grid/client/tests/v2/v2_action_service_test.gd'
git commit --only -m "feat(v2): retain tutorial objective baseline" -- `
  'tactical-grid/client/data/v2/missions.json' `
  'tactical-grid/client/scripts/game/mission_objective_state.gd' `
  'tactical-grid/client/scripts/ui/hud.gd' `
  'tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd' `
  'tactical-grid/client/scripts/v2/mission/v2_tutorial_flow.gd' `
  'tactical-grid/client/tests/v2/v2_m1_config_test.gd' `
  'tactical-grid/client/tests/v2/v2_m1_tutorial_test.gd' `
  'tactical-grid/client/tests/v2/v2_objective_hud_runtime_scene_test.gd'
git commit --only -m "feat(v2): retain combat death baseline" -- `
  'tactical-grid/client/scripts/ui/mission_result.gd' `
  'tactical-grid/client/scripts/v2/presentation/v2_result_presentation.gd' `
  'tactical-grid/client/tests/v2/v2_result_presentation_test.gd'
git commit --only -m "feat(v2): retain art identity baseline" -- `
  'tactical-grid/client/scripts/data/art_catalog.gd' `
  'tactical-grid/client/scripts/game/unit_sprite.gd' `
  'tactical-grid/client/tests/v2/v2_unit_art_distinction_test.gd'
```

The revert and no-commit reapplication completed without conflicts. The five
`--only` commits used the exact audited path sets; neither
`tactical-grid/client/data/levels.json` nor
`docs/superpowers/specs/2026-08-12-v2-p01-playtest-blockers.md` was staged.

### Fresh Verification

From `tactical-grid/client`, seven independent Godot processes were rerun
with the same `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script`
commands listed above, followed by:

```powershell
& '.\\tests\\v2\\v2_release_isolation_test.ps1'
```

All eight processes exited 0. Godot output was: camera/input `Passed: 9`,
input router `Passed: 28`, action service `Passed: 19`, enemy occupancy
`Passed: 6`, M1 tutorial `Passed: 18`, result presentation `Passed: 12`,
and unit art distinction `Passed: 44`; every script printed `Failed: 0`.
Isolation printed `V2 release isolation passed`.

Final retained-file equivalence was checked with:

```powershell
$retained = git show --format= --name-only f2619791edb77ba2829185c6636b2ae4bad151ef
git diff --exit-code f2619791edb77ba2829185c6636b2ae4bad151ef HEAD -- $retained
```

Exit code: 0. No retained-file diff was produced.

### Fix Round 1 Commits

- Targeted revert: `9fe875b7e802bdec236539756fb937120079b749`
- Camera input: `65d780c`
- Movement occupancy: `d285d4a`
- Tutorial objective: `b45bc86`
- Combat death: `ef8e448`
- Art identity: `d536121`
