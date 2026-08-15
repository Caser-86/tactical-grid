# Tactical Grid V2 M1 Core Fun Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert M1 from a technically complete but modal, repetitive flow into a clear 12-18 minute production mission with direct map actions, reliable camera control, three distinct enemy problems, three purposeful encounters, readable feedback, and a formal five-unit art sample.

**Architecture:** Keep existing deterministic combat, mission/checkpoint services, locked map loader, and V2 isolation. Add V2-only gesture, context-action, camera-navigation, enemy-strategy, and intent-presentation boundaries; integrate them through narrow hooks in the existing battle scene, then simplify M1 data and map content after the runtime contracts pass.

**Tech Stack:** Godot 4.7.1, GDScript, JSON, PowerShell, Windows x64 export, ImageGen for approved raster samples, local deterministic image processing.

## Global Constraints

- Product authority: `docs/superpowers/specs/2026-08-13-v2-chapter-one-production-game-design.md`.
- Execute in `D:/LLM Files/files/tactical-grid/.worktrees/ch1-infiltration-v2` on branch `codex/ch1-infiltration-v2`.
- Godot console: `D:/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe`.
- Godot project root: `tactical-grid/client`.
- Every PowerShell block that uses `$godot` begins from `tactical-grid/client` with `$godot = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'`; this prelude applies even when a task is executed in a fresh agent session.
- Do not discard existing dirty changes; Task 1 classifies and integrates them first.
- Do not modify V1 product data, save identity, boot scene, main menu, release directory, or release package.
- No route-choice modal, AP display, hit percentage, move/attack toolbar mode, or blocking center-screen tutorial.
- Every behavior task starts with a failing focused test and ends with a focused pass plus an independent commit.
- M1 bulk art work stops after the five-unit sample until the owner approves actual-scene screenshots.

---

### Task 1: Classify And Seal The Existing Dirty Baseline

**Owner:** Sol xhigh

**Files:**
- Inspect: every path returned by `git status --short`
- Modify: only dirty files assigned to a named audit category and proven broken by that category's existing focused test; do not introduce interfaces or behavior owned by Tasks 2-16
- Create: `tactical-grid/client/docs/v2_m1_baseline_audit_2026-08-13.md`
- Test: existing modified tests under `tactical-grid/client/tests/v2/`

**Interfaces:**
- Consumes: current uncommitted camera, input, occupancy, tutorial, mission, HUD, result, and art changes
- Produces: a cleanly classified baseline with each retained behavior committed separately and a written list of remaining known failures

- [ ] **Step 1: Capture the unmodified dirty state**

Run from the worktree root:

```powershell
New-Item -ItemType Directory -Force tactical-grid/client/artifacts/v2 | Out-Null
git status --short | Set-Content tactical-grid/client/artifacts/v2/baseline-2026-08-13-status.txt
git diff -- tactical-grid/client/scripts tactical-grid/client/data tactical-grid/client/tests | Set-Content tactical-grid/client/artifacts/v2/baseline-2026-08-13.diff
git diff --numstat | Set-Content tactical-grid/client/artifacts/v2/baseline-2026-08-13-numstat.txt
```

Expected: artifacts contain the exact pre-integration state; no source file changes.

- [ ] **Step 2: Classify each modified file**

Write `v2_m1_baseline_audit_2026-08-13.md` with one row per dirty file and exactly one category: `camera_input`, `movement_occupancy`, `tutorial_objective`, `combat_death`, `art_identity`, or `unrelated`. Each row records the intended behavior, focused test, and keep/fix/defer decision.

- [ ] **Step 3: Run the focused tests for every retained category**

From `tactical-grid/client` run:

```powershell
$godot = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/v2/v2_camera_input_test.gd
& $godot --headless --path . --script res://tests/v2/v2_input_router_test.gd
& $godot --headless --path . --script res://tests/v2/v2_action_service_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_tutorial_test.gd
& $godot --headless --path . --script res://tests/v2/v2_result_presentation_test.gd
& $godot --headless --path . --script res://tests/v2/v2_unit_art_distinction_test.gd
```

Expected: each process exits `0` and reports `Failed: 0`, or its actual failure is copied verbatim into the audit before any fix.

- [ ] **Step 4: Fix only proven baseline regressions**

For each failed focused test, make the smallest change inside its audit category. Do not redesign M1 or introduce interfaces from later tasks.

- [ ] **Step 5: Re-run focused tests and the isolation probe**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/v2_release_isolation_test.ps1
```

Expected: focused tests report `Failed: 0`; isolation exits `0`.

- [ ] **Step 6: Commit coherent baseline groups**

Stage explicit category files only. Suggested commit sequence:

```powershell
git commit -m "fix(v2): stabilize camera and input baseline"
git commit -m "fix(v2): stabilize movement and occupancy baseline"
git commit -m "fix(v2): stabilize tutorial and result baseline"
git commit -m "docs(v2): record M1 baseline audit"
```

Expected: the audit lists every remaining dirty file; no file is silently discarded.

---

### Task 2: Align Repository Authority And Retire Conflicting Targets

**Owner:** Terra high

**Files:**
- Modify: `README.md`
- Modify: `docs/v2/README.md`
- Modify: `docs/v2/V2_MASTER_SPEC.md`
- Modify: `tactical-grid/PROJECT_STATUS_V2.md`
- Modify: `docs/superpowers/specs/2026-08-06-v2-m1-m2-content-expansion-design.md`
- Test: `tactical-grid/client/tests/v2/v2_m1_config_test.gd`

**Interfaces:**
- Consumes: approved production design and master roadmap
- Produces: one visible authority chain and M1 targets of 3 encounters, 7-8 enemies, and 12-18 minutes

- [ ] **Step 1: Write a failing authority check**

Add assertions to `v2_m1_config_test.gd` that load M1 and require:

```gdscript
t.check(int(mission.get("enemy_total", 0)) >= 7 and int(mission.get("enemy_total", 0)) <= 8, "M1 production enemy budget is 7-8")
t.check(int(mission.get("encounter_count", 0)) == 3, "M1 production flow has three encounters")
t.check(String(mission.get("flow_mode", "")) == "m1_production", "M1 uses production flow identity")
```

- [ ] **Step 2: Run the test and verify the old expanded configuration fails**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_config_test.gd
```

Expected: FAIL on `enemy_total`, `encounter_count`, or `flow_mode` because M1 still uses the expanded-flow targets.

- [ ] **Step 3: Add clear supersession notices and update the master summary**

At the top of the 2026-08-06 document, state that its 12/13-enemy duration plan and route modal are superseded by the 2026-08-13 production design, while implemented infrastructure remains historical/reusable. Update `V2_MASTER_SPEC.md` M1 content values. Update root `README.md`, `docs/v2/README.md`, and `tactical-grid/PROJECT_STATUS_V2.md` so the 2026-08-13 production design is the product authority, the master roadmap is the portfolio dispatcher, and this M1 plan is the only unlocked execution plan. Keep the 2026-08-05 plan linked as implementation history, not the current queue.

- [ ] **Step 4: Update only M1 identity fields required by the test**

Modify `data/v2/missions.json` M1 summary fields to:

```json
"flow_mode": "m1_production",
"enemy_total": 8,
"encounter_count": 3,
"target_duration_minutes": [12, 18]
```

Do not yet rewrite objective steps or map entities; those belong to Tasks 9 and 10.

- [ ] **Step 5: Re-run the config and schema tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_config_test.gd
& $godot --headless --path . --script res://tests/v2/v2_schema_reference_test.gd
```

Expected: both exit `0` and report `Failed: 0`.

- [ ] **Step 6: Commit**

```powershell
git add README.md docs/v2/README.md docs/v2/V2_MASTER_SPEC.md tactical-grid/PROJECT_STATUS_V2.md docs/superpowers/specs/2026-08-06-v2-m1-m2-content-expansion-design.md tactical-grid/client/data/v2/missions.json tactical-grid/client/tests/v2/v2_m1_config_test.gd
git commit -m "docs(v2): align M1 with production design"
```

---

### Task 3: Implement A Gesture-Safe Camera Input Contract

**Owner:** Sol xhigh

**Files:**
- Modify: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_camera_focus.gd`
- Modify: `tactical-grid/client/scripts/game/battle_camera_controller.gd`
- Modify: `tactical-grid/client/project.godot`
- Test: `tactical-grid/client/tests/v2/v2_camera_input_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_input_router_test.gd`

**Interfaces:**
- Replaces: `handle_event(event: InputEvent, screen_to_cell: Callable) -> bool`
- Produces: `handle_event(event: InputEvent, screen_to_cell: Callable, pointer_context: Callable = Callable()) -> bool`; `pointer_context.call(position)` returns `{ "drag_allowed": bool, "over_map": bool, "over_hud": bool }`
- Produces: `signal camera_pan_requested(delta: Vector2)`, `signal focus_requested()`, `signal camera_inspect_cancel_requested()`, and `func is_camera_panning() -> bool`
- Input actions: `camera_up`, `camera_down`, `camera_left`, `camera_right`, and `focus_unit`
- Gesture rule: left/right release becomes a click only when accumulated drag distance is below 8 pixels; otherwise it is pan only

- [ ] **Step 1: Add failing gesture tests**

Extend `v2_camera_input_test.gd` with event sequences that assert:

```gdscript
t.check(left_empty_drag_pan_count == 1 and left_click_count == 0, "Dragging empty terrain pans without committing a cell click")
t.check(right_drag_pan_count == 1 and cancel_count == 0, "Right drag pans without cancelling selection")
t.check(right_short_cancel_count == 1, "Short right click still cancels")
t.check(focus_key_count == 1, "F focuses the current living player")
t.check(wasd_pan_delta != Vector2.ZERO, "WASD pans while tactical selection remains unchanged")
```

- [ ] **Step 2: Run both input tests and verify failure**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_camera_input_test.gd
& $godot --headless --path . --script res://tests/v2/v2_input_router_test.gd
```

Expected: new assertions fail because only middle drag and Home focus exist.

- [ ] **Step 3: Replace button-specific drag flags with a pointer gesture record**

Implement this V2-only record in the router:

```gdscript
var _drag_button := MOUSE_BUTTON_NONE
var _drag_origin := Vector2.ZERO
var _last_pointer_position := Vector2.ZERO
var _drag_distance := 0.0
const DRAG_THRESHOLD := 8.0

func _begin_pointer_gesture(button: MouseButton, position: Vector2) -> void
func _update_pointer_gesture(position: Vector2) -> bool
func _finish_pointer_gesture(button: MouseButton, position: Vector2, screen_to_cell: Callable) -> bool
```

Left drag starts only when the initial cell has no selectable unit, facility, or active contextual target. Add a callable parameter or a `pointer_context` callable returning `{ "drag_allowed": bool }`; do not infer scene ownership inside the router.

- [ ] **Step 4: Add F and WASD actions without changing tactical state**

Add `focus_unit` on physical `F` and `camera_up/down/left/right` on WASD in `project.godot`. Emit pan deltas from key handling and keep `get_state_name()` unchanged.

- [ ] **Step 5: Re-run focused tests**

Expected: all synthetic gesture cases report `Failed: 0`; no cell click or cancel is emitted after a drag.

- [ ] **Step 6: Run the real player-turn scene**

```powershell
& $godot --headless --path . res://tests/v2/v2_player_turn_e2e_test.tscn
```

Expected: process exits `0`; movement/attack input still works after pan and focus.

- [x] **Step 7: Commit**

```powershell
git add tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd tactical-grid/client/scripts/v2/runtime/v2_camera_focus.gd tactical-grid/client/scripts/game/battle_camera_controller.gd tactical-grid/client/project.godot tactical-grid/client/tests/v2/v2_camera_input_test.gd tactical-grid/client/tests/v2/v2_input_router_test.gd
git commit -m "feat(v2): add gesture-safe battle camera controls"
```

---

### Task 4: Add Reliable Inspect-And-Return Camera Navigation

**Owner:** Terra xhigh

**Files:**
- Create: `tactical-grid/client/scripts/v2/runtime/v2_camera_navigation.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Create: `tactical-grid/client/tests/v2/v2_camera_navigation_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_camera_input_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces class `V2CameraNavigation`
- `func begin_inspect(center: Vector2i, radius: int, return_cell: Vector2i) -> Dictionary`
- `func cancel_inspect() -> Dictionary`
- `func focus_player(cell: Vector2i) -> Dictionary`
- `func is_inspecting() -> bool`
- Result shape: `{success: bool, mode: StringName, focus_cell: Vector2i, zoom_hint: float, show_return: bool}`

- [ ] **Step 1: Write the failing navigation unit test**

Test that a camera inspection stores the player's cell, requests a zoom that can show a radius-7 area, exposes `show_return`, and that cancel/focus restore the stored/current player cell without changing tactical selection.

- [ ] **Step 2: Run and confirm the class is missing**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_camera_navigation_test.gd
```

Expected: FAIL because `v2_camera_navigation.gd` does not exist.

- [ ] **Step 3: Implement the pure navigation state**

Use only cells and mode state; do not reference HUD or scene nodes from `V2CameraNavigation`.

- [ ] **Step 4: Integrate camera inspection through V2 runtime hooks**

Camera facilities call `begin_inspect`. `Esc`, repeated facility click, `F`, and the HUD return control call `cancel_inspect` or `focus_player`. The result is applied through existing `battle_camera_controller` focus/zoom APIs.

- [ ] **Step 5: Add a compact HUD return control**

Show `返回队员 [F]` only while `show_return` is true. It must not cover the map center or consume map drag outside its own bounds.

- [ ] **Step 6: Register and run tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_camera_navigation_test.gd
& $godot --headless --path . --script res://tests/v2/v2_camera_input_test.gd
& $godot --headless --path . res://tests/v2/v2_objective_hud_runtime_scene_test.tscn
```

Expected: all exit `0`; the HUD runtime test proves the return control appears only in inspect mode.

- [ ] **Step 7: Commit**

```powershell
git add tactical-grid/client/scripts/v2/runtime/v2_camera_navigation.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2/v2_camera_navigation_test.gd tactical-grid/client/tests/v2/v2_camera_input_test.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "feat(v2): make facility camera inspection reversible"
```

---

### Task 5: Centralize Direct Context Actions

**Owner:** Sol xhigh

**Files:**
- Create: `tactical-grid/client/scripts/v2/input/v2_context_action_resolver.gd`
- Modify: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_context_action_resolver_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_direct_move_input_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_attack_input_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- `func resolve_click(cell: Vector2i, context: Dictionary) -> Dictionary`
- `context` keys: `selected_unit`, `friendly_at`, `enemy_at`, `facility_at`, `move_query`, `attack_query`, `interaction_query`
- Result `kind` is exactly one of `select`, `move`, `attack`, `interact`, `invalid`
- Result includes `reason: StringName`, `cell: Vector2i`, and the relevant unit/facility/preview

- [ ] **Step 1: Write a failing resolver matrix**

Cover these ordered cases:

```gdscript
friendly cell -> select
selected unit + reachable empty cell -> move
selected unit + legal enemy -> attack
selected unit + usable facility -> interact
occupied friendly/enemy move destination -> invalid
unreachable or blocked cell -> invalid
```

- [ ] **Step 2: Run and verify missing resolver failure**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_context_action_resolver_test.gd
```

- [ ] **Step 3: Implement the pure precedence rules**

The resolver returns intent only. It must not mutate units, move the camera, open UI, or spend actions.

- [ ] **Step 4: Replace the V2 click branch with resolver dispatch**

`_on_v2_cell_left_clicked` builds context once, calls the resolver, and dispatches to existing select/move/attack/interaction commit functions. Remove double-click attack confirmation and route-modal assumptions from the V2 branch only.

- [ ] **Step 5: Run direct move, attack, occupancy, and player-turn tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_context_action_resolver_test.gd
& $godot --headless --path . --script res://tests/v2/v2_direct_move_input_test.gd
& $godot --headless --path . --script res://tests/v2/v2_attack_input_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
& $godot --headless --path . res://tests/v2/v2_player_turn_e2e_test.tscn
```

Expected: `Failed: 0`; one legal target click commits one attack, and occupied cells never resolve as movement.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/input/v2_context_action_resolver.gd tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_context_action_resolver_test.gd tactical-grid/client/tests/v2/v2_direct_move_input_test.gd tactical-grid/client/tests/v2/v2_attack_input_test.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "refactor(v2): resolve map clicks as direct context actions"
```

---

### Task 6: Replace Full-Board Overlays With Progressive Affordances

**Owner:** Terra xhigh

**Files:**
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd`
- Create: `tactical-grid/client/scripts/v2/presentation/v2_action_preview.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Test: `tactical-grid/client/tests/v2/v2_affordance_contract_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_action_preview_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- `V2ActionPreview.build_move(unit, cell, move_query) -> Dictionary`
- `V2ActionPreview.build_attack(unit, target, attack_query) -> Dictionary`
- Move preview keys: `valid`, `path`, `destination`, `dangerous`, `reason`
- Attack preview keys: `valid`, `target`, `damage`, `hp_after`, `intent_change`, `reason`
- Presenter methods: `show_reachable(cells)`, `show_move_preview(preview)`, `show_attackable(targets)`, `show_attack_preview(preview)`, `clear_transient()`, `clear_all()`

- [ ] **Step 1: Write failing presentation contracts**

Require selected-unit state to render reachable cyan cells and only outline legal enemy targets. Require hover to render exactly the returned path or one target preview. Assert that attackable area cells do not create a full red fill layer.

- [ ] **Step 2: Run and confirm current presenter fails the no-full-red-area contract**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_affordance_contract_test.gd
& $godot --headless --path . --script res://tests/v2/v2_action_preview_test.gd
```

- [ ] **Step 3: Split persistent and transient presentation**

Persistent: soft reachable cells and attackable target outlines. Transient: one path, destination marker, damage card, and intent-change line. Use shape plus color; do not rely on `M`/`A` glyphs as primary communication.

- [ ] **Step 4: Wire hover previews to the same query used for commit**

The preview path must come from the legal move query. Never draw a direct line to an unreachable hover cell. Attack preview uses the deterministic combat preview object that the commit validates.

- [ ] **Step 5: Run contracts and capture M1 start/combat snapshots**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_affordance_contract_test.gd
& $godot --headless --path . --script res://tests/v2/v2_action_preview_test.gd
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

Expected: no path points to an illegal cell; no full-board red overlay; snapshots are generated for review.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd tactical-grid/client/scripts/v2/presentation/v2_action_preview.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2/v2_affordance_contract_test.gd tactical-grid/client/tests/v2/v2_action_preview_test.gd tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "feat(v2): present progressive move and attack affordances"
```

---

### Task 7: Make M1 Tutorial Non-Modal And Safe

**Owner:** Terra high

**Files:**
- Modify: `tactical-grid/client/scripts/v2/mission/v2_tutorial_flow.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/data/v2/missions.json`
- Test: `tactical-grid/client/tests/v2/v2_m1_tutorial_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_objective_hud_runtime_scene_test.gd`

**Interfaces:**
- Tutorial events: `unit_selected`, `unit_moved`, `attack_previewed`, `attack_committed`, `enemy_intent_seen`
- `get_hint() -> Dictionary` returns `visible`, `anchor_kind`, `anchor_id`, `text`, `step_id`
- `on_event(event_name, payload) -> Dictionary` advances at most one tutorial step
- Tutorial safety flag: `m1_safe_tutorial_complete`

- [ ] **Step 1: Replace modal-count assertions with anchored-hint assertions**

Tests require one visible hint maximum, no input lock, immediate dismissal on matching event, and a three-player-turn safety window that ends after the first committed attack and observed enemy intent.

- [ ] **Step 2: Run and verify the current modal tutorial fails**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_tutorial_test.gd
```

- [ ] **Step 3: Implement the five-event tutorial sequence**

Use these exact short texts:

```text
选择突击兵
点击青色格移动
悬停红框敌人查看伤害
点击敌人发动攻击
敌人的箭头表示下一步行动
```

Hints anchor to the unit, reachable cell, enemy, or enemy intent. None creates a full-screen panel or consumes map input.

- [ ] **Step 4: Enforce tutorial safety in M1 enemy-turn context**

Before `m1_safe_tutorial_complete`, the tutorial sentry may aim or reposition but cannot reduce the assault below 1 HP. Remove the exception immediately after the flag is set; do not apply it to later enemies or other missions.

- [ ] **Step 5: Run tutorial, HUD, and enemy-turn tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_tutorial_test.gd
& $godot --headless --path . res://tests/v2/v2_objective_hud_runtime_scene_test.tscn
& $godot --headless --path . res://tests/v2/v2_player_turn_e2e_test.tscn
```

Expected: no modal input lock; tutorial safety ends deterministically.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_tutorial_flow.gd tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/data/v2/missions.json tactical-grid/client/tests/v2/v2_m1_tutorial_test.gd tactical-grid/client/tests/v2/v2_objective_hud_runtime_scene_test.gd
git commit -m "feat(v2): teach M1 through non-modal safe turns"
```

---

### Task 8: Split M1 Enemy Plans Into Three Tactical Problems

**Owner:** Sol xhigh

**Files:**
- Create: `tactical-grid/client/scripts/v2/ai/strategies/v2_sentry_strategy.gd`
- Create: `tactical-grid/client/scripts/v2/ai/strategies/v2_drone_strategy.gd`
- Create: `tactical-grid/client/scripts/v2/ai/strategies/v2_shield_guard_strategy.gd`
- Create: `tactical-grid/client/scripts/v2/ai/v2_enemy_strategy_registry.gd`
- Modify: `tactical-grid/client/scripts/v2/ai/v2_enemy_brain.gd`
- Modify: `tactical-grid/client/scripts/v2/ai/v2_intent_executor.gd`
- Modify: `tactical-grid/client/data/v2/enemies.json`
- Create: `tactical-grid/client/tests/v2/v2_enemy_strategy_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_enemy_intent_contract_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Each strategy implements `static func plan(enemy: Unit, context: Dictionary, revision: int) -> Dictionary`
- Registry implements `static func plan(enemy: Unit, context: Dictionary, revision: int) -> Dictionary`
- Shared result keys: `type`, `enemy_id`, `revision`, `target_id`, `target_cell`, `path`, `damage`, `telegraph`, `fallback_reason`
- Valid M1 intent types: `move`, `attack`, `scan`, `protect`, `guard`

- [ ] **Step 1: Write failing behavior matrices**

Require:

```text
Sentry: attacks from a legal line; otherwise chooses a guard/line-improving cell, not unconditional nearest-player pursuit.
Drone: scans an unobserved or high-value area; avoids occupying attack-line roles; direct attack is only a safe fallback.
Shield guard: protects an exposed priority ally; otherwise blocks a narrow legal route; attacks only when no protection/block action exists.
```

Also assert every invalidated intent produces `guard` or legal `move`, never a more damaging surprise attack.

- [ ] **Step 2: Run and verify current shared move-toward behavior fails**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_enemy_strategy_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_intent_contract_test.gd
```

- [ ] **Step 3: Implement the registry and three strategy classes**

Strategies may consume shared path/line/occupancy callables from `context`, but cannot mutate units or facilities. `V2EnemyBrain.plan_intent` becomes a compatibility wrapper around the registry.

- [ ] **Step 4: Extend the executor for guard and explicit scan/protect results**

Execution validates target/path occupancy again. If validation fails, return a non-damaging fallback and increment intent revision.

- [ ] **Step 5: Run strategy, executor, occupancy, and encounter tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_enemy_strategy_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_intent_contract_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
& $godot --headless --path . res://tests/v2/v2_encounter_controller_regression_test.tscn
```

Expected: all plans are legal, distinct, deterministic, and safe on invalidation.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/ai tactical-grid/client/data/v2/enemies.json tactical-grid/client/tests/v2/v2_enemy_strategy_test.gd tactical-grid/client/tests/v2/v2_enemy_intent_contract_test.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "feat(v2): give M1 enemies distinct tactical plans"
```

---

### Task 9: Present Enemy Identity And Intent Without Text Dependence

**Owner:** Terra xhigh

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_intent_presenter.gd`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_intent_presentation_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- `func build(intent: Dictionary) -> Dictionary`
- Result keys: `shape`, `color_role`, `line_cells`, `target_cell`, `target_id`, `damage_text`, `icon_key`, `pulse`
- Shape values: `arrow`, `cone`, `link`, `shield`, `guard`

- [ ] **Step 1: Write failing intent-shape tests**

Require attack to produce arrow/line, scan to produce cone, protect to produce shield link, and guard to produce a non-targeting guard marker. Assert every intent remains distinct when color values are ignored.

- [ ] **Step 2: Run and verify no dedicated presenter exists**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_intent_presentation_test.gd
```

- [ ] **Step 3: Implement data-only presentation mapping**

Do not draw inside the mapper. Return semantic shape data consumed by the existing overlay layer.

- [ ] **Step 4: Replace tiny role-letter dependence**

Keep text badges as optional accessibility support, but add large silhouette-adjacent role markers and unique intent shapes. Ensure unit rings indicate team only.

- [ ] **Step 5: Run intent and visual matrix tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_intent_presentation_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_intent_contract_test.gd
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

Expected: default and grayscale snapshots preserve shape distinctions.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_intent_presenter.gd tactical-grid/client/scripts/game/unit_sprite.gd tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2/v2_intent_presentation_test.gd tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "feat(v2): render readable enemy roles and intent shapes"
```

---

### Task 10: Simplify M1 Mission Flow To Find, Rescue, Evacuate

**Owner:** Sol xhigh

**Files:**
- Modify: `tactical-grid/client/data/v2/missions.json`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Test: `tactical-grid/client/tests/v2/v2_m1_flow_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_m1_public_flow_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_m1_route_consequence_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_m1_retry_test.gd`

**Interfaces:**
- Public M1 objective steps: `find_scout`, `rescue_scout`, `evacuate_squad`
- Optional event: `incident_record_collected`
- Route discovery is spatial state, not an objective step or modal selection
- Camera and gantry interactions may set flags but never gate rescue unless the locked map has a visible alternate path

- [ ] **Step 1: Rewrite flow tests before mission data**

Require exactly three public steps, no `route_selected` completion event, no `show_route_choice` result, optional record independence, rescue checkpoint, pre-evac checkpoint, and victory only when all conscious controlled units are inside evac.

- [ ] **Step 2: Run and verify expanded five-step flow fails**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_public_flow_test.gd
```

- [ ] **Step 3: Replace M1 objective data**

Use these public texts:

```json
[
  {"id":"find_scout","objective_text":"找到失联侦察兵","guide_text":"沿任一路线搜索侦察兵信号","complete_event":"scout_located","checkpoint_id":""},
  {"id":"rescue_scout","objective_text":"救出侦察兵","guide_text":"接近侦察兵并清除身边威胁","complete_event":"character_rescued","checkpoint_id":"cp_m1_rescue"},
  {"id":"evacuate_squad","objective_text":"两人一起撤离","guide_text":"让所有清醒队员进入绿色撤离区","complete_event":"squad_evacuated","checkpoint_id":"cp_m1_pre_evac"}
]
```

- [ ] **Step 4: Remove runtime route-modal calls**

Delete or stop invoking `_show_v2_route_choice` for M1 production flow. Route-specific effects trigger from physical facility/cell events and update the HUD with one short result.

- [ ] **Step 5: Run flow, retry, checkpoint, HUD, and result tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_public_flow_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_route_consequence_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_retry_test.gd
& $godot --headless --path . res://tests/v2/v2_m1_m2_checkpoint_scene_test.tscn
```

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/data/v2/missions.json tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2/v2_m1_flow_test.gd tactical-grid/client/tests/v2/v2_m1_public_flow_test.gd tactical-grid/client/tests/v2/v2_m1_route_consequence_test.gd tactical-grid/client/tests/v2/v2_m1_retry_test.gd
git commit -m "refactor(v2): simplify M1 to rescue and evacuation"
```

---

### Task 11: Re-Author Echo Yard As Three Purposeful Encounters

**Owner:** Terra xhigh for data, Sol xhigh for final review

**Files:**
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json`
- Modify: `tactical-grid/client/data/v2/missions.json`
- Modify: `tactical-grid/client/tests/v2/v2_m1_map_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_expansion_map_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_enemy_activation_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_e2e_test.gd`

**Interfaces:**
- Encounter IDs: `m1_e01_tutorial`, `m1_e02_rescue_routes`, `m1_e03_evac_guard`
- Active cap: 3
- Enemy budget: 8 total
- Main path gaps between decision beats: at most two player turns
- Optional record round trip from the nearest main-route junction: at most two player turns

- [ ] **Step 1: Write map-budget and route tests**

Require:

```text
8 enemy entities total
3 encounters total
M1 enemy classes limited to sentry, drone, shield_guard
both maintenance and cargo routes reach rescue and evac
no route-choice entity or modal trigger
optional record is reachable and not required
all living spawn cells are unique
all main objectives remain reachable with enemy cells treated as occupied
```

- [ ] **Step 2: Run and verify current 12-enemy/5-encounter map fails**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_map_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_expansion_map_test.gd
```

- [ ] **Step 3: Re-author entities and encounters**

Use this fixed budget:

```text
Tutorial: 1 sentry
Route/rescue area: 2 sentries + 2 drones
Evacuation: 1 shield guard + 1 sentry + 1 drone
Total: 8
```

The tutorial sentry starts active. Route/rescue enemies activate on visible spatial triggers. Evac enemies activate only after rescue and appear with a camera cue and full player response turn.

- [ ] **Step 4: Rebuild physical routes with existing environment kits**

Maintenance route contains cover and one camera reveal. Cargo route is shorter with difficult cells and a drone scan risk. Both remain visible parts of the map; neither is chosen through UI. Keep Echo Yard as the dominant kit and restrict overrides to coherent named regions.

- [ ] **Step 5: Update checkpoints and optional record**

Keep start, post-rescue, and pre-evac checkpoints. Place the record facility in a short alcove and remove its dedicated mandatory encounter.

- [ ] **Step 6: Run map, activation, public-flow, E2E, and visual tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_m1_map_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_expansion_map_test.gd
& $godot --headless --path . --script res://tests/v2/v2_m1_enemy_activation_test.gd
& $godot --headless --path . res://tests/v2/v2_m1_e2e_test.tscn
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_e2e_process_matrix.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

- [ ] **Step 7: Review generated screenshots at 1920x1080**

Reject the layout if the player, current goal, rescue target, route distinction, or active threat cannot be found within three seconds; revise map positions rather than adding more instructional text.

- [ ] **Step 8: Commit**

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json tactical-grid/client/data/v2/missions.json tactical-grid/client/tests/v2/v2_m1_map_test.gd tactical-grid/client/tests/v2/v2_m1_expansion_map_test.gd tactical-grid/client/tests/v2/v2_m1_enemy_activation_test.gd tactical-grid/client/tests/v2/v2_m1_e2e_test.gd
git commit -m "content(v2): rebuild M1 around three tactical encounters"
```

---

### Task 12: Complete The Deterministic Combat Feedback Chain

**Owner:** Terra xhigh

**Files:**
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_damage_presenter.gd`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Test: `tactical-grid/client/tests/v2/v2_damage_presentation_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_unit_sprite_sync_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_rescue_battle_integration_test.gd`

**Interfaces:**
- Feedback event order: `attack_started`, `projectile_or_trace`, `hp_prestrip`, optional reduction/shield, `damage_number`, optional `intent_changed`, optional `unit_downed`, `attack_finished`
- Downed completion emits or returns `occupancy_released: true`
- Reduced motion preserves state clarity while shortening motion and disabling shake

- [ ] **Step 1: Extend the failing feedback-sequence test**

Assert projectile/trace before damage, exact `-N` text, visible HP before/after, intent cancellation when applicable, one downed event, and occupancy release before attack finish.

- [ ] **Step 2: Run and verify the current sequence lacks trace/intent/release evidence**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_damage_presentation_test.gd
```

- [ ] **Step 3: Build semantic events without changing damage rules**

`V2DamagePresenter` receives the validated combat preview/result and generates events only. Do not recalculate damage in the presenter.

- [ ] **Step 4: Play attack, hit, HP, intent, and downed feedback**

Use existing sprite transform/flash APIs. Default total duration target is 0.5-0.8 seconds; reduced motion uses immediate facing, short flash, number, and fade without shake.

- [ ] **Step 5: Make death cleanup idempotent**

The first downed transition disables input, AI, collision, occupancy, and intent. Repeated death callbacks return without recreating sprites or leaving occupied cells.

- [ ] **Step 6: Run feedback, occupancy, sprite, and rescue integration tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_damage_presentation_test.gd
& $godot --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
& $godot --headless --path . res://tests/v2/v2_unit_sprite_sync_test.tscn
& $godot --headless --path . res://tests/v2/v2_rescue_battle_integration_test.tscn
```

- [ ] **Step 7: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_damage_presenter.gd tactical-grid/client/scripts/game/unit_sprite.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_damage_presentation_test.gd tactical-grid/client/tests/v2/v2_unit_sprite_sync_test.gd tactical-grid/client/tests/v2/v2_rescue_battle_integration_test.gd
git commit -m "feat(v2): make combat outcomes immediate and readable"
```

---

### Task 13: Produce And Integrate The Five-Unit Art Sample

**Owner:** ImageGen for source art, Luna high for deterministic processing/catalog, Terra high for runtime integration, project owner for approval

**Files:**
- Create: `tactical-grid/client/assets/v2/source/units/player/`
- Create: `tactical-grid/client/assets/v2/source/units/enemy/`
- Create: `tactical-grid/client/assets/v2/source/units/m1_identity_contact_sheet.png`
- Create: `tactical-grid/client/assets/v2/source/units/m1_identity_direction_contact_sheet.png`
- Create: `tactical-grid/client/assets/v2/source/units/m1_identity_art_brief.json`
- Create: `tactical-grid/client/assets/v2/units/v2_assault_{north,east,south,west}_128.png`
- Create: `tactical-grid/client/assets/v2/units/v2_scout_{north,east,south,west}_128.png`
- Create: `tactical-grid/client/assets/v2/units/v2_sentry_{north,east,south,west}_128.png`
- Create: `tactical-grid/client/assets/v2/units/v2_drone_{north,east,south,west}_128.png`
- Create: `tactical-grid/client/assets/v2/units/v2_shield_guard_{north,east,south,west}_128.png`
- Modify: `tactical-grid/client/scripts/data/art_catalog.gd`
- Modify: `tactical-grid/client/tests/v2/v2_unit_art_distinction_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_unit_art_sample_snapshot.gd`
- Create: `tactical-grid/client/tests/v2/v2_unit_art_sample_snapshot.tscn`
- Create: `tactical-grid/client/tests/v2/v2_unit_art_direction_snapshot.gd`
- Create: `tactical-grid/client/tests/v2/v2_unit_art_direction_snapshot.tscn`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/assets/v2/README.md`

**Interfaces:**
- Unit IDs: `v2_assault`, `v2_scout`, `v2_sentry`, `v2_drone`, `v2_shield_guard`
- Directions: `north`, `east`, `south`, `west`
- Runtime canvas: 128x128 transparent PNG, consistent feet/hover anchor and lighting
- Catalog key format: `<unit_id>_<direction>`

- [x] **Step 1: Measure the runtime slot and write the art brief**

`m1_identity_art_brief.json` records canvas, visible subject bounds, anchor, light direction, camera angle, palette, and silhouette requirements. Use these identity requirements:

```text
Assault: medium-wide shoulders, short rifle, large cyan forearm plates, forward stance.
Scout: lowest human posture, short weapon, asymmetric antenna backpack, large green leg panels.
Sentry: upright rigid body, long rifle, large red shoulder plates.
Drone: wide horizontal wing/disc silhouette, white-purple scan emitter, no humanoid torso.
Shield guard: widest ground silhouette, dominant hexagonal shield, large orange armor fields.
```

- [x] **Step 2: Generate one south-facing source sample for each unit**

Use ImageGen with the brief and existing approved V2 unit images as style references. Generate one isolated subject per image on a transparent background when supported, otherwise on the brief's single edge-connected chroma background for deterministic removal. Do not ask ImageGen to create a sprite sheet or UI labels.

- [x] **Step 3: Process samples deterministically**

Normalize to 128x128, remove only edge-connected background, inspect alpha, align anchors, and generate `m1_identity_contact_sheet.png` at actual 100% and 75% display scales on representative Echo Yard terrain. Record source as `AI-generated with OpenAI ImageGen`, generation date, prompt brief path, processing command, and modifications in `resource_manifest.md`.

- [x] **Step 4: Add failing actual-image distinction checks**

Tests must check all five runtime files, alpha, dimensions, non-empty bounds, minimum visible-subject area, and unique catalog keys. The snapshot scene renders actual scale, 75% scale, grayscale, and color-assist rows.

- [x] **Step 5: Integrate samples into the M1-only catalog mapping**

Do not overwrite V1 assets or the current directionless V2 fallback files. M1 resolves approved files such as `v2_assault_south_128.png` through V2 catalog keys; missing directions continue using the current `v2_assault_128.png`-style fallback until Step 8.

- [x] **Step 6: Generate and inspect the snapshot**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_unit_art_distinction_test.gd
& $godot --headless --path . res://tests/v2/v2_unit_art_sample_snapshot.tscn
```

Project owner approves only if each type can be named at actual and 75% scale without reading badges.

- [x] **Step 7: Revise rejected samples before direction expansion**

If recognition fails, enlarge silhouette features or accent areas. Do not solve recognition by adding text, thicker team circles, or higher source resolution alone.

- [x] **Step 8: Generate north/east/west directions from the approved identity set**

Each direction is a separately composed view with the same armor, equipment, color blocks, anchor, and lighting. Mirroring is allowed only for symmetric drone elements, not for asymmetric character equipment.

- [x] **Step 9: Re-run snapshots and visual matrix**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_unit_art_distinction_test.gd
& $godot --headless --path . res://tests/v2/v2_unit_art_sample_snapshot.tscn
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

- [x] **Step 10: Commit source record, runtime assets, catalog, tests, and approval evidence separately**

```powershell
git commit -m "art(v2): add approved M1 unit identity samples"
git commit -m "feat(v2): integrate four-direction M1 unit art"
```

---

### Task 14: Add M1 Presentation And Audio Samples

**Owner:** Terra high for procedural audio and integration

**Files:**
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Modify: `tactical-grid/client/scripts/data/art_catalog.gd`
- Modify: `tactical-grid/client/tools/generate_chapter1_audio.ps1`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_shield_protect.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_shield_absorb.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_objective_update.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_rescue.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_evac.wav`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_damage_presenter.gd`
- Modify after Task 9 creates it: `tactical-grid/client/scripts/v2/presentation/v2_intent_presenter.gd`
- Test: `tactical-grid/client/tests/v2/v2_audio_headless_contract_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_damage_presentation_test.gd`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`

**Interfaces:**
- Required M1 cues: assault shot, scout shot, sentry shot, drone scan, shield protect, hit, shield absorb, downed, objective update, rescue, evac
- Required M1 visual cues: muzzle/trace, hit, scan cone pulse, shield link/pulse, rescue, evac

- [x] **Step 1: Inventory existing legal assets before generating replacements**

Record keep/replace decision for every required cue. Reuse assets that are licensed, technically valid, and visibly/audibly distinct.

- [x] **Step 2: Create only missing source cues**

Reuse `sfx_combat_smg`, `sfx_combat_pistol`, `sfx_combat_sniper`, `sfx_network_scan`, `sfx_hit_flesh`, and `sfx_unit_down`. Extend `tools/generate_chapter1_audio.ps1` with the five exact V2 cue files listed above, keeping the existing project-owned procedural PCM WAV approach. Do not imitate identifiable commercial-game audio. Record generator parameters and runtime paths in `resource_manifest.md`. M1 muzzle, trace, hit, scan, shield, rescue, and evac visuals remain presenter-driven in this task; raster source generation is deferred unless an actual-scene review produces a separately approved art brief.

- [x] **Step 3: Normalize and validate**

Trim silence, normalize loudness, convert to the project's accepted format, confirm no clipping, and ensure repeated enemy-turn playback does not overlap indefinitely.

- [x] **Step 4: Add failing cue-registration and sequence tests**

Require every M1 semantic event to resolve to one cue and reduced-motion/mute settings to preserve logic while suppressing optional motion/audio.

- [x] **Step 5: Integrate through semantic events**

Presenters request cue IDs; they do not hard-code file paths. Audio settings continue through existing buses.

- [x] **Step 6: Run headless, presentation, settings, and visual tests**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_audio_headless_contract_test.gd
& $godot --headless --path . --script res://tests/v2/v2_damage_presentation_test.gd
& $godot --headless --path . res://tests/v2/v2_settings_runtime_test.tscn
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

Evidence: the five new WAV files validate as 22050 Hz, mono, 16-bit PCM with no clipping; the focused audio contract passed 21/0, damage presentation passed 19/0, settings runtime passed 3/0, player-turn E2E passed 78/0, the evacuation bridge passed 30/0 with no `SCRIPT ERROR`, M1 visual matrix passed 36/36, M2 visual matrix passed 54/54, and the full V2 gate passed 83/83 items with 2053/0 assertions. The gate still reports only the known non-fatal Godot teardown diagnostics.

- [ ] **Step 7: Commit**

```powershell
git commit -m "audio(v2): add distinct M1 tactical cues"
git commit -m "feat(v2): integrate M1 combat and objective effects"
```

Completed in commit `faf36c2` (`feat(v2): add M1 semantic audio and presentation cues`). The implementation and evidence records were committed without staging the user-owned `levels.json` or the existing untracked playtest-blocker specification.

---

### Task 15: Expand Single-Owner Telemetry And M1 Acceptance

**Owner:** Terra high for telemetry, project owner for human run

**Files:**
- Modify: `tactical-grid/client/scripts/v2/mission/v2_playtest_recorder.gd`
- Modify: `tactical-grid/client/tests/v2/v2_playtest_recorder_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_playtest_integration_contract_test.gd`
- Create: `tactical-grid/client/docs/v2_m1_single_owner_acceptance.md`
- Create runtime-only output: `user://playtests/m1/OWNER.json`

**Interfaces:**
- Playtest ID accepts `OWNER` in addition to legacy anonymous IDs
- Event schema records mission/version/difficulty, timestamps, turns, actions, invalid clicks, cancels, pans, focus returns, damage, intent resolutions, inactivity, downed, retries, soft locks, completion
- Human result is one of `approved`, `rejected`, `incomplete`; AI cannot set `approved`

- [ ] **Step 1: Write failing recorder tests for the production fields**

Assert session start, first move/attack timestamps, action counters, 10-second inactivity event, camera recovery count, completion, and private local path. Ensure no screenshots or personal identifiers are recorded by default.

- [ ] **Step 2: Run and verify missing fields fail**

```powershell
& $godot --headless --path . --script res://tests/v2/v2_playtest_recorder_test.gd
& $godot --headless --path . --script res://tests/v2/v2_playtest_integration_contract_test.gd
```

- [ ] **Step 3: Implement the append-only local session schema**

Keep runtime records out of Git. Export a sanitized summary into the acceptance document only after the owner run.

- [ ] **Step 4: Re-run recorder and integration tests**

Expected: `Failed: 0`; normal game launches without `--v2-playtest-id` create no playtest file.

- [ ] **Step 5: Build and launch the M1 candidate for the owner**

Use the release export task from Task 16, then launch:

```powershell
& '.\build\TacticalGrid_V2_Infiltration\TacticalGrid_V2_Infiltration.exe' --v2-playtest-id=OWNER
```

The owner plays from a clean V2 save without Godot or external instructions.

- [ ] **Step 6: Fill the human acceptance document**

Record pass/fail for first move within 60 seconds, first attack within 90 seconds, current-goal understanding, three meaningful decisions, enemy recognition, no three-turn dead travel, 12-18 minute target, and all observed bugs. Only the owner marks subjective approval.

- [ ] **Step 7: Commit telemetry code and sanitized acceptance outcome**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_playtest_recorder.gd tactical-grid/client/tests/v2/v2_playtest_recorder_test.gd tactical-grid/client/tests/v2/v2_playtest_integration_contract_test.gd tactical-grid/client/docs/v2_m1_single_owner_acceptance.md
git commit -m "test(v2): add single-owner M1 acceptance telemetry"
```

---

### Task 16: Run The M1 Production Gate And Build Candidate

**Owner:** Sol xhigh

**Files:**
- Update: `tactical-grid/client/docs/v2_m1_m2_release_report.md`
- Update after Task 15 creates it: `tactical-grid/client/docs/v2_m1_single_owner_acceptance.md`
- Output: `tactical-grid/client/build/TacticalGrid_V2_Infiltration/TacticalGrid_V2_Infiltration.exe`

**Interfaces:**
- Gate success line: `V2 RELEASE GATE PASSED`
- Package identity: `Tactical Grid V2: Infiltration`, user directory `TacticalGrid_V2_Infiltration`, product line `v2_infiltration`

- [ ] **Step 1: Ensure no V2 game or gate process is running**

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'TacticalGrid_V2_Infiltration*' -or $_.ProcessName -like 'Godot*' }
```

Expected: no active V2 client and no competing gate. Stop only processes started for this task; do not kill unrelated Godot sessions without confirmation.

- [ ] **Step 2: Run the M1 route and visual matrices**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_e2e_process_matrix.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

Expected: every route/process exits `0`; accepted screenshots match production flow.

- [ ] **Step 3: Run the complete V2 gate once**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

Expected: final line `V2 RELEASE GATE PASSED`. Record assertion totals and every non-fatal warning category.

- [ ] **Step 4: Diagnose any failure from the first failing item, not from the final summary**

Reproduce that item in its isolated command and return to the task that owns the failing contract. Add the regression and correction to that task's existing commit boundary, rerun the isolated item, then resume this gate and rerun the complete gate once. Do not make source-code fixes inside Task 16 and do not loop the full gate while a focused failure is reproducible.

- [ ] **Step 5: Export and verify the Windows candidate**

Run the isolated V2 build and package checks:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1 -GodotPath 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/verify_windows_package.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/v2_release_isolation_test.ps1
```

Expected: EXE/PCK/version/cold-start and V2 isolation pass.

- [ ] **Step 6: Update release evidence**

Record commit, gate totals, warning counts, package path, cold-start result, single-owner result, residual risk, and the explicit statement that one familiar human tester does not prove stranger first-time comprehension.

- [ ] **Step 7: Commit release evidence**

```powershell
git add tactical-grid/client/docs/v2_m1_m2_release_report.md tactical-grid/client/docs/v2_m1_single_owner_acceptance.md
git commit -m "test(v2): record M1 production gate evidence"
```

---

## M1 Plan Completion Gate

Do not create or execute the Stage 3 content-pipeline plan until all items below are true:

- Existing dirty baseline is classified and committed without data loss.
- M1 has exactly three public objectives, three encounters, and 7-8 enemies.
- Route choice is spatial and no route modal appears.
- Direct left-click move/attack and contextual facility use pass real-scene tests.
- Left/right/middle drag, WASD, wheel, and `F` camera recovery work without accidental actions.
- Sentry, drone, and shield guard have distinct deterministic strategies and intent shapes.
- M1 five-unit art sample is approved at actual scale, 75% scale, grayscale, and color-assist.
- Combat feedback and death cleanup are visibly complete.
- Full V2 gate, Windows package verification, and V1/V2 isolation pass.
- Project owner completes M1 from a clean package and signs the single-owner acceptance record.

## Specification Coverage

| Production-design requirement | Implemented by |
|---|---|
| One authority chain and protected V1/V2 boundary | Tasks 1-2, 16 |
| Direct context actions with no toolbar mode | Task 5 |
| Reliable drag/WASD/zoom/focus/inspect-return camera | Tasks 3-4 |
| Progressive move, path, attack, damage, and intent previews | Tasks 6, 9, 12 |
| Non-modal three-turn safe teaching | Task 7 |
| Distinct sentry, drone, and shield-guard tactics | Tasks 8-9 |
| Three public objectives with spatial route choice | Task 10 |
| Three encounters, 7-8 enemies, 12-18 minute target | Tasks 2, 11, 15 |
| Deterministic combat feedback and reliable death cleanup | Task 12 |
| Five-unit actual-scale art gate and four directions | Task 13 |
| Legal, registered M1 VFX and audio cues | Task 14 |
| Local telemetry and owner-only subjective acceptance | Task 15 |
| Automated gate, Windows package, cold start, and V1/V2 isolation | Task 16 |

The remaining Chapter One requirements for M2-M6, optional operations, modules, portraits, complete art/audio inventory, Boss, ending, accessibility, save migration, and release hardening remain scheduled in the master roadmap. They are deliberately not expanded into file-level tasks until M1 freezes the shared interfaces they depend on.
