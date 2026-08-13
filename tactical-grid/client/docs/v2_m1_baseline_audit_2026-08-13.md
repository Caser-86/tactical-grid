# V2 M1 Baseline Audit (2026-08-13)

## Scope

This audit seals the pre-existing dirty V2 M1 baseline on branch
`codex/ch1-infiltration-v2`. The original baseline contained 28 paths. Before
inspection or changes, its status, tracked diff, and numstat were captured in:

- `artifacts/v2/baseline-2026-08-13-status.txt`
- `artifacts/v2/baseline-2026-08-13.diff`
- `artifacts/v2/baseline-2026-08-13-numstat.txt`

Each original path is assigned exactly one category. `keep` means focused
evidence retained the behavior; `defer` means the user-owned path stays
unstaged. No `fix` decision was made: all required focused tests passed before
any corrective edit could be justified.

## Classification

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

## Baseline Verification

All Godot tests were launched as independent processes from
`tactical-grid/client`:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script <test path>
```

| Command target | Exit code | Output summary |
| --- | ---: | --- |
| `tests/v2/v2_camera_input_test.gd` | 0 | `Passed: 9`, `Failed: 0` |
| `tests/v2/v2_input_router_test.gd` | 0 | `Passed: 28`, `Failed: 0` |
| `tests/v2/v2_action_service_test.gd` | 0 | `Passed: 19`, `Failed: 0` |
| `tests/v2/v2_enemy_occupancy_test.gd` | 0 | `Passed: 6`, `Failed: 0` |
| `tests/v2/v2_m1_tutorial_test.gd` | 0 | `Passed: 18`, `Failed: 0` |
| `tests/v2/v2_result_presentation_test.gd` | 0 | `Passed: 12`, `Failed: 0` |
| `tests/v2/v2_unit_art_distinction_test.gd` | 0 | `Passed: 44`, `Failed: 0` |

The independent isolation command was:

```powershell
& '.\tests\v2\v2_release_isolation_test.ps1'
```

It exited 0 and reported verbatim:

```text
V2 release isolation passed
  Build: D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client\build\TacticalGrid_V2_Infiltration
  Entry: scenes/v2_boot.tscn
  User directory: TacticalGrid_V2_Infiltration
```

No test emitted failure output. Full raw process output is retained in
`artifacts/v2/baseline-2026-08-13-v2_*.log`.

## Retention Decision

No baseline correction was made. The focused evidence showed intended V2 M1
behavior already works, so a production edit would be unproven scope growth.
Retain verified V2 baseline paths in an explicit commit; leave the two unrelated
original paths unstaged.

## Concerns

- Git emitted LF-to-CRLF warnings while reading tracked changes. The unrelated
  `levels.json` modification has no textual diff and remains unstaged.
- The required focused tests and isolation test are green. Broader V2 scene
  tests were not mandated by Task 1 and are not represented as a full-suite claim.

