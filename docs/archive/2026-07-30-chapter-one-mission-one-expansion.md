# Chapter One Mission One Expansion Implementation Plan (Historical)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `ch1_m1` into a 25 to 35 minute, three-stage tactical mission with a larger map, event-driven pressure, an optional resource branch, a readable camera, and non-token unit presentation.

**Architecture:** `MissionObjectiveState` owns the approach, upload, evacuation, and completion state machine and emits typed mission events. `EnemyDirector` consumes event names without knowing mission rules, while `BattleController` binds the state, scene interaction, reinforcement spawning, HUD, and result payload. Map data, camera behavior, and unit presentation remain independently testable.

**Tech Stack:** Godot 4.7.1, GDScript, Godot scene tests, JSON locked-map data, PowerShell asset processing, Codex Image Generation, Windows Desktop x64 export.

## Global Constraints

- Standard difficulty target duration is 25 to 35 minutes and 10 to 15 turns.
- `ch1_m1` is exactly 18×14, uses three player units, five initial enemies, and at most three reinforcements.
- The mission order is terminal activation, two controlled upload rounds, then full-team evacuation.
- Standard difficulty has an 18-turn limit and an 11-turn three-star threshold.
- Three stars require no casualties, completion within 11 turns, and collection of the optional resource cache.
- First-turn enemy passivity, disabled items, and disabled overwatch remain active.
- New unit runtime images are transparent 96×96 PNG files with no text, watermark, baked background, or checkerboard.
- Normal unit art renders at 76px or larger and must not use a filled circular token base.
- Existing tests may be extended but not weakened or deleted to make the release gate pass.
- All external or generated resources must be registered in `AI_RESOURCES_STATEMENT.md` and `client/data/RESOURCE_MANIFEST.md`.
- Work remains on branch `codex/battle-camera-composition` in the existing linked worktree.

---

## Execution Lanes and Model/Tool Routing

Model names below are routing recommendations, not claims that a named model is currently available. If the UI exposes `Sol xhigh` or `5.6 Terra`, use the mapping below; otherwise select a model with the equivalent capability and reasoning level.

### Workstream Matrix

| Lane | Scope | Plan Tasks | Recommended Executor | Reasoning Level | Required Tools | Deliverable |
| --- | --- | --- | --- | --- | --- | --- |
| `CODE-CORE` | Mission state, event integration, rewards, camera, regression fixes | 1, 2, 3, 5 | Strong coding model; `Sol xhigh` if available | `xhigh` | `apply_patch`, PowerShell, Godot headless tests, Git | Tested GDScript and scene integration |
| `LEVEL-DATA` | Map layout, encounter scripting, turn budgets, balance data | 4 | Strong coding/game-design model; `5.6 Terra high/xhigh` if available | `high`, raise to `xhigh` for balance failures | JSON inspection, Godot tests, map validators | Valid 18×14 authored mission data |
| `ART-GEN` | Generate the seven approved unit source illustrations | Task 6 Step 3 only | Image generation model/tool such as Codex Image Generation or `IMAGE2` | Image quality mode | Image generation, visual inspection | Seven unprocessed source PNGs |
| `ART-PIPELINE` | Alpha cleanup, crop, resize, import, catalog wiring, runtime presentation | Task 6 Steps 1, 2, 4-7, 9 | Coding model with image-processing experience; `Sol xhigh` if available | `high` | PowerShell, image inspection, Godot importer/tests, `apply_patch` | Seven transparent 96×96 runtime assets integrated in-game |
| `VISUAL-QA` | Judge silhouette separation, scale, clipping, combat readability, UI obstruction | Task 6 Step 8; Task 7 Step 7 visual checks | Vision-capable model plus Computer Use; human signs off final quality | `high` | Windowed Godot run, screenshots, image viewer | Screenshot evidence and issue list |
| `CODE-QA` | E2E tests, release gate, export, deterministic regression diagnosis | Task 7 Steps 1-6 | Strong coding/debugging model; `Sol xhigh` if available | `xhigh` for failures, `high` for clean reruns | Godot headless, PowerShell release gate, export preset, Git | Passing release logs and runnable Windows build |
| `PLAYTEST` | Duration, pacing, tactical choice, frustration, fun, victory/failure clarity | Task 7 Step 7 | AI may execute and collect telemetry; a human must make the final experience judgment | Human judgment | Windowed build, screen recording or screenshots, playtest sheet | Actual turn count, duration, defects, and signed-off experience notes |
| `DOCS-PROVENANCE` | Resource licenses, AI-generation record, status and QA evidence | Task 6 Step 6; Task 7 Steps 8-9 | General or coding model | `medium/high` | Repository search, Git diff, verified test logs | Accurate manifests, status, and QA documents |

### What Counts as Art Work

- **Pure art generation:** only Task 6 Step 3. The image model creates seven source illustrations from the approved visual brief.
- **Art engineering:** Task 6 Steps 1, 2, 4, 5, 6, 7, and 9. These are code/tool tasks, not image-generation tasks: tests, deterministic processing, transparency, sizing, catalog registration, import behavior, runtime composition, and provenance.
- **Visual acceptance:** Task 6 Step 8 and the visual part of Task 7 Step 7. A vision-capable model can identify defects, but the final "looks like a finished game" decision needs human review.
- An image is not complete merely because it was generated. It becomes a game asset only after processing, registration, in-game rendering, visual QA, and licensing/provenance documentation pass.

### What Counts as Code, Data, or Tool Work

- **Code:** Tasks 1, 2, 3, and 5; Task 6 art processing/integration; Task 7 automated QA and release work.
- **Level and balance data:** Task 4. A general reasoning model may draft layout and numbers, but a coding-capable model must validate schemas, coordinates, triggers, and runtime behavior.
- **Automated testing:** all RED/GREEN test steps and the release gate. These must be executed by tools; model reasoning alone is not test evidence.
- **Documentation:** provenance and status updates may use a lower-cost model after implementation, but every factual claim must come from repository state, test output, or captured playtest evidence.
- **Release:** export and smoke testing require the installed Godot executable and the generated build. No model may mark release complete from source review alone.

### Recommended Model Assignment

- Use **`Sol xhigh` or an equivalent strongest coding/reasoning model** for Tasks 1, 2, 3, 5, Task 6 runtime integration, and any failing release-gate diagnosis.
- Use **`5.6 Terra high/xhigh` or an equivalent strong general/coding model** for Task 4 map authoring, balance-data iteration, test-log consolidation, and documentation. Escalate Task 4 to the strongest coding model if map triggers or scene integration fail.
- Use **Codex Image Generation, `IMAGE2`, or an equivalent image model** only for Task 6 Step 3. It must not edit GDScript, manifests, import settings, or claim in-game completion.
- Use a **vision-capable model with Computer Use** for windowed visual inspection and mechanical playthrough execution. Use a human for the final fun, pacing, and commercial-quality judgment.
- Use **deterministic tools instead of a model** for PNG conversion, alpha cleanup, dimensions, file hashes, Godot import, tests, export, and Git operations.

### Delegation and Merge Rules

- Tasks 1 through 3 are sequential because they establish the mission interfaces and share `battle_controller.gd`.
- Task 4 begins only after Tasks 1 and 2 freeze the mission-flow and event-trigger contracts.
- Task 5 must not edit `battle_controller.gd` concurrently with Tasks 2 or 3. Run it afterward, or use an isolated worktree and review the cherry-pick manually.
- Task 6 Step 3 may run in parallel with code work because source images live in an isolated directory. Task 6 integration begins only after all seven source files exist.
- Task 7 begins only after Tasks 1 through 6 are integrated.
- No two workers may concurrently modify `battle_controller.gd`, `battle_smoke_test_runner.gd`, or `battle_hud_contract_test.gd`.
- Every delegated lane returns a focused commit, exact commands run, pass/fail output, changed-file list, and unresolved risks. The integration owner reviews each diff before merging.
- A visual-generation worker returns source art only. The integration owner remains responsible for crop, alpha, dimensions, import settings, rendering, collisions where applicable, tests, and provenance.

### Execution Order

1. `CODE-CORE`: Task 1.
2. `CODE-CORE`: Task 2.
3. `CODE-CORE`: Task 3.
4. `LEVEL-DATA`: Task 4.
5. `CODE-CORE`: Task 5.
6. `ART-GEN`: Task 6 Step 3 may start in parallel as soon as the approved prompts are available.
7. `ART-PIPELINE` and `VISUAL-QA`: finish the remaining Task 6 steps.
8. `CODE-QA`, `PLAYTEST`, and `DOCS-PROVENANCE`: Task 7 and final evidence.

---

## File Structure

- `client/scripts/game/mission_objective_state.gd`: mission phase, upload progress, resource state, victory gating, result modifiers.
- `client/scripts/ai/enemy_director.gd`: time and named-event reinforcement trigger evaluation.
- `client/scripts/game/battle_controller.gd`: scene input, mission event bridge, resource interaction, result composition, stage feedback.
- `client/scripts/game/battle_camera_controller.gd`: readable default zoom, drag, edge pan, overview, focus restore.
- `client/scripts/game/unit_sprite.gd`: larger art, soft shadow, thin faction ring, row-based draw order.
- `client/data/locked_maps/ch1_m1.json`: exact 18×14 authored mission layout and event scripts.
- `client/data/levels.json`: mission type, force size, turn limits, rewards, and tutorials.
- `client/data/chapter1_playtest_matrix.json`: revised story, standard, and hard turn targets.
- `client/scripts/data/art_catalog.gd`: new 96px unit asset paths.
- `client/tools/process_chapter1_unit_art.ps1`: deterministic alpha cleanup, crop, resize, and validation.
- `client/tests/chapter_one_objectives_test.gd`: state-machine and resource tests.
- `client/tests/battle_smoke_test_runner.gd`: locked-map, reward, map-validity, and integration contracts.
- `client/tests/battle_hud_contract_test.gd`: camera, mission stage, resource UI, and scene interaction.
- `client/tests/unit_animation_contract_test.gd`: texture dimensions, rendered size, silhouette, and animation regressions.
- `client/tests/chapter_one_balance_test.gd`: revised turn budgets and rating requirements.
- `client/tests/chapter_one_e2e_test.gd`: full first-mission production path.
- `client/scripts/ui/tutorial_hint.gd`: camera, interaction, upload, and evacuation teaching order.
- `docs/qa/CHAPTER1_RELEASE_CANDIDATE_QA.md`: actual automated and manual evidence.

---

### Task 1: Mission Phase State Machine `[CODE-CORE / xhigh]`

**Executor:** Strong coding model (`Sol xhigh` if available). Do not delegate implementation to an image model.

**Files:**
- Modify: `tactical-grid/client/tests/chapter_one_objectives_test.gd`
- Modify: `tactical-grid/client/scripts/game/mission_objective_state.gd`

**Interfaces:**
- Consumes: map-level `mission_flow: Dictionary`, terminal/resource/evac objects, player unit positions.
- Produces:
  - `signal mission_event(name: StringName, payload: Dictionary)`
  - `const STAGE_APPROACH := &"approach"`
  - `const STAGE_UPLOAD := &"upload"`
  - `const STAGE_EVACUATE := &"evacuate"`
  - `const STAGE_COMPLETE := &"complete"`
  - `func get_stage() -> StringName`
  - `func on_enemy_turn_completed() -> Dictionary`
  - `func on_resource_interacted(unit: Node, resource_pos: Vector2i) -> Dictionary`
  - `func get_result_modifiers() -> Dictionary`

- [ ] **Step 1: Add failing state-machine tests**

Add these calls to `_ready()`:

```gdscript
_test_infiltrate_requires_terminal_upload_and_evac()
_test_upload_pauses_without_terminal_control()
_test_optional_resource_is_idempotent()
```

Add a focused fixture:

```gdscript
func _make_infiltrate_state() -> Dictionary:
	var mos := _make_state()
	var players := [
		_make_unit("player", Vector2i(8, 8)),
		_make_unit("player", Vector2i(7, 8)),
		_make_unit("player", Vector2i(6, 8)),
	]
	var map_data := _make_map_data("infiltrate", [
		{"type": "terminal", "x": 8, "y": 7},
		{"type": "resource", "x": 2, "y": 5, "reward": "credit_150"},
		{"type": "evac", "x": 1, "y": 0, "radius": 1},
	], 18, 14)
	map_data["mission_flow"] = {
		"terminal_required": true,
		"upload_turns_required": 2,
		"upload_hold_radius": 1,
		"evac_locked_until_upload": true,
		"optional_resource_credit": 150,
	}
	mos.setup({"mission_type": "infiltrate", "max_turns": 18}, map_data, players, [])
	return {"state": mos, "players": players}
```

The first test must assert this exact sequence:

```gdscript
_check(mos.get_stage() == &"approach", "first mission starts in approach")
_check(not mos.is_victory(), "evacuation cannot bypass the terminal")
var terminal_result := mos.on_terminal_interacted(players[0], Vector2i(8, 7))
_check(terminal_result.get("success", false), "terminal activates once")
_check(mos.get_stage() == &"upload", "terminal starts upload")
_check(mos.on_enemy_turn_completed().get("progress", -1) == 1, "controlled upload advances to 1/2")
_check(mos.on_enemy_turn_completed().get("progress", -1) == 2, "controlled upload advances to 2/2")
_check(mos.get_stage() == &"evacuate", "completed upload unlocks evacuation")
for index in players.size():
	players[index].grid_pos = Vector2i(index, 0)
_check(mos.is_victory(), "all survivors evacuate after upload")
_check(mos.get_stage() == &"complete", "victory records complete stage")
```

The pause test moves every player outside Manhattan distance 1 before `on_enemy_turn_completed()` and expects `paused == true` with progress unchanged. The resource test calls `on_resource_interacted()` twice and expects the first call to return `credit_bonus == 150`, the second to return `reason == "already_collected"`, and `get_result_modifiers()` to return:

```gdscript
{"optional_resource_collected": true, "optional_credit": 150}
```

- [ ] **Step 2: Run the objective test and verify RED**

Run from `tactical-grid/client`:

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/chapter_one_objectives_test.tscn
```

Expected: FAIL because `get_stage`, `on_enemy_turn_completed`, `on_resource_interacted`, and `get_result_modifiers` do not exist.

- [ ] **Step 3: Implement the phase state in `MissionObjectiveState`**

Add typed state:

```gdscript
signal mission_event(name: StringName, payload: Dictionary)

const STAGE_APPROACH := &"approach"
const STAGE_UPLOAD := &"upload"
const STAGE_EVACUATE := &"evacuate"
const STAGE_COMPLETE := &"complete"

var mission_stage: StringName = STAGE_APPROACH
var mission_flow: Dictionary = {}
var upload_progress := 0
var upload_turns_required := 0
var upload_hold_radius := 1
var resource_positions: Array[Vector2i] = []
var collected_resources: Dictionary = {}
var activated_terminals: Dictionary = {}
var optional_credit := 0
```

During `setup()`, duplicate `map_data.mission_flow`, extract resource positions, and initialize upload fields. `on_terminal_interacted()` first rejects `activated_terminals.has(term_pos)`, then records `activated_terminals[term_pos] = true`. For `infiltrate`, successful activation sets `mission_stage = STAGE_UPLOAD` and emits:

```gdscript
mission_event.emit(&"terminal_activated", {
	"position": term_pos,
	"upload_required": upload_turns_required,
})
```

Implement upload control with a Manhattan-distance check:

```gdscript
func _has_upload_control() -> bool:
	for player in _players:
		if player and player.is_alive:
			for terminal_pos in terminals:
				if GridSystem.manhattan_distance(player.grid_pos, terminal_pos) <= upload_hold_radius:
					return true
	return false
```

`on_enemy_turn_completed()` advances only in `STAGE_UPLOAD`. At the threshold it sets `STAGE_EVACUATE` and emits `&"upload_completed"`. `_check_data_victory()` requires `STAGE_EVACUATE` before checking survivors in `evac_cells`, then sets `STAGE_COMPLETE`.

`get_status_text()` must return:

```gdscript
match mission_stage:
	STAGE_APPROACH:
		return "阶段 1/3：接近并激活数据终端"
	STAGE_UPLOAD:
		var control := "控制稳定" if _has_upload_control() else "无人控制，上传暂停"
		return "阶段 2/3：上传数据 %d/%d（%s）" % [upload_progress, upload_turns_required, control]
	STAGE_EVACUATE:
		return "阶段 3/3：全员转移至西北撤离区域"
	_:
		return "任务完成"
```

- [ ] **Step 4: Run the objective test and verify GREEN**

Run the command from Step 2.

Expected: all objective assertions pass, including existing extract, destroy, escort, defend, and repeat-interaction coverage.

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/scripts/game/mission_objective_state.gd `
  tactical-grid/client/tests/chapter_one_objectives_test.gd
git commit -m "feat(chapter1): add staged opening mission objective"
```

---

### Task 2: Event Reinforcements and Battle Integration `[CODE-CORE / xhigh]`

**Executor:** Strong coding model (`Sol xhigh` if available). Keep this sequential with Tasks 1 and 3 because they share runtime interfaces.

**Files:**
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`
- Modify: `tactical-grid/client/scripts/ai/enemy_director.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`

**Interfaces:**
- Consumes: `MissionObjectiveState.mission_event`, map scripts with `trigger.type == "event"`.
- Produces:
  - `func EnemyDirector.on_event(event_name: StringName) -> Array`
  - `func BattleController._on_mission_event(event_name: StringName, payload: Dictionary) -> void`

- [ ] **Step 1: Add failing named-event tests**

In the reinforcement test group, add:

```gdscript
func _test_reinforcement_event_trigger() -> void:
	var director := EnemyDirector.new()
	add_child(director)
	director.setup([
		{
			"trigger_id": "terminal_wave",
			"trigger": {"type": "event", "name": "terminal_activated"},
			"action": "spawn_reinforcement",
			"data": {"units": [
				{"type": "sentry_basic", "position": [16, 12]},
				{"type": "drone_assault", "position": [17, 11]},
			]},
			"repeat": false,
		},
	])
	director.max_reinforcements = 3
	director.enemy_cap_per_wave = 7
	director.set_alive_counts(3, 5)
	_check(director.on_event(&"wrong_event").is_empty(), "unrelated event does not spawn")
	var waves := director.on_event(&"terminal_activated")
	_check(waves.size() == 1 and waves[0].units.size() == 2, "terminal event spawns configured wave")
	_check(director.on_event(&"terminal_activated").is_empty(), "one-shot event cannot repeat")
	_check(director.reinforcements_spawned == 2, "event wave counts against reinforcement cap")
	director.queue_free()
```

Add an integration assertion to `battle_hud_contract_test.gd` that `BattleController` connects `mission_event` and that an emitted `terminal_activated` event increases `enemy_units` by 2 after one frame.

- [ ] **Step 2: Run smoke and HUD tests and verify RED**

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_smoke_test.tscn
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_hud_contract_test.tscn
```

Expected: FAIL because `EnemyDirector.on_event()` and the mission-event bridge do not exist.

- [ ] **Step 3: Implement a shared trigger evaluator**

Refactor `_check_reinforcements()` into:

```gdscript
func _trigger_matches(entry: Dictionary, turn: int, event_name: StringName) -> bool:
	var trigger: Dictionary = entry.get("trigger", {})
	match String(trigger.get("type", "turn")):
		"event":
			return StringName(trigger.get("name", "")) == event_name
		_:
			return event_name.is_empty() and _check_condition(String(trigger.get("condition", "")), turn)
```

Both `on_turn_start()` and `on_event()` call one `_evaluate_triggers(turn, event_name)` implementation so cap, repeat, signal, and counter logic cannot diverge.

In `_setup_objective_state()`, connect:

```gdscript
mission_objective_state.mission_event.connect(_on_mission_event)
```

The bridge updates alive counts, invokes `enemy_director.on_event(event_name)`, refreshes the objective, and focuses the relevant location. It must not spawn units directly because `EnemyDirector.reinforcement_spawned` already drives `_spawn_reinforcement_units()`.

At the end of the enemy turn, before starting the next player turn, call:

```gdscript
var upload_result := mission_objective_state.on_enemy_turn_completed()
if upload_result.get("changed", false):
	hud.update_objective(mission_objective_state.get_status_text())
```

- [ ] **Step 4: Run smoke, HUD, and objective tests and verify GREEN**

Run both commands from Step 2 and the Task 1 objective test.

Expected: event waves spawn once, old turn triggers still pass, upload completion generates the second event.

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/scripts/ai/enemy_director.gd `
  tactical-grid/client/scripts/game/battle_controller.gd `
  tactical-grid/client/tests/battle_smoke_test_runner.gd `
  tactical-grid/client/tests/battle_hud_contract_test.gd
git commit -m "feat(chapter1): trigger reinforcements from mission stages"
```

---

### Task 3: Optional Resource Interaction, Rating, and Rewards `[CODE-CORE / xhigh]`

**Executor:** Strong coding model (`Sol xhigh` if available). This task spans battle, save/reward, result UI, and E2E contracts.

**Files:**
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`
- Modify: `tactical-grid/client/tests/chapter_one_e2e_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Modify: `tactical-grid/client/scripts/ui/mission_result.gd`

**Interfaces:**
- Consumes: `MissionObjectiveState.on_resource_interacted()` and `get_result_modifiers()`.
- Produces:
  - battle result fields `optional_resource_collected: bool`, `optional_credit: int`
  - reward field `rewards.optional_credit: int`
  - result display line `可选资源 +150 信用点`
  - `func BattleController._calculate_stars(victory: bool, survived: int, total: int, turns: int, optional_complete: bool) -> int`

- [ ] **Step 1: Add failing interaction and reward tests**

In `chapter_one_e2e_test.gd`, instantiate the real `BattleScene`, wait two frames, and test the extracted star function:

```gdscript
var battle := BattleScene.instantiate()
add_child(battle)
await get_tree().process_frame
await get_tree().process_frame
_check(battle._calculate_stars(true, 3, 3, 11, false) == 2,
	"fast no-casualty clear without cache is two stars")
_check(battle._calculate_stars(true, 3, 3, 11, true) == 3,
	"cache completes the three-star contract")
_check(battle._calculate_stars(true, 2, 3, 9, true) == 1,
	"a casualty prevents the second and third stars")
battle._cleanup_units()
battle.free()
```

In the E2E fixture, record starting credits, complete the mission with `optional_credit = 150`, and assert the saved credits increase by base reward plus 150 exactly once. Repeat the mission and assert the optional bonus is paid when collected but the first-clear bonus remains one-time.

- [ ] **Step 2: Run smoke and E2E tests and verify RED**

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_smoke_test.tscn
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/chapter_one_e2e_test.tscn
```

Expected: FAIL because optional resource state does not affect stars, rewards, or persistence.

- [ ] **Step 3: Wire resource interaction into the battle scene**

Extract resource object positions during map setup. In move mode, treat resource clicks like terminal clicks:

```gdscript
if grid_pos in resource_positions and selected_unit and selected_unit.team == "player":
	if _try_interact_resource(selected_unit, grid_pos):
		_show_move_range(selected_unit)
		hud.update_unit_info(selected_unit)
		return
```

`_try_interact_resource()` must require adjacency, consume 1 AP, call the objective state, play a pickup effect/SFX, and redraw the objective text.

Extract the rating logic:

```gdscript
func _calculate_stars(
	victory: bool,
	survived: int,
	total: int,
	turns: int,
	optional_complete: bool
) -> int:
	if not victory:
		return 0
	if survived != total:
		return 1
	if turns > int(level_config.get("three_star_turns", 10)) or not optional_complete:
		return 2
	return 3
```

In `_finish_battle()`, merge modifiers and call the helper:

```gdscript
var modifiers := mission_objective_state.get_result_modifiers()
var optional_required := bool(level_config.get("three_star_requires_optional", false))
var optional_complete := not optional_required or bool(modifiers.get("optional_resource_collected", false))
stars = _calculate_stars(
	victory,
	survived,
	total,
	turn_manager.turn_number,
	optional_complete
)
```

Add `optional_credit` to `rewards.credit` before `GameManager.complete_mission()` and preserve it in `battle_result`.

- [ ] **Step 4: Show the optional reward in mission results**

Append a result line only when the bonus is positive:

```gdscript
if int(data.get("optional_credit", 0)) > 0:
	reward_lines.append("可选资源 +%d 信用点" % int(data.optional_credit))
```

- [ ] **Step 5: Run smoke and E2E tests and verify GREEN**

Run Step 2.

Expected: two stars without the cache, three with it, no reward on failure, exact reward persistence on victory.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/game/battle_controller.gd `
  tactical-grid/client/scripts/game/game_manager.gd `
  tactical-grid/client/scripts/ui/mission_result.gd `
  tactical-grid/client/tests/battle_smoke_test_runner.gd `
  tactical-grid/client/tests/chapter_one_e2e_test.gd
git commit -m "feat(chapter1): add optional salvage objective and reward"
```

---

### Task 4: Author the 18×14 Echo Yard Mission `[LEVEL-DATA / high]`

**Executor:** Strong coding/game-design model (`5.6 Terra high/xhigh` if available), with Godot validation owned by the integration worker.

**Files:**
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`
- Modify: `tactical-grid/client/tests/chapter_one_balance_test.gd`
- Modify: `tactical-grid/client/data/locked_maps/ch1_m1.json`
- Modify: `tactical-grid/client/data/locked_maps/_index.json`
- Modify: `tactical-grid/client/data/levels.json`
- Modify: `tactical-grid/client/data/chapter1_playtest_matrix.json`

**Interfaces:**
- Consumes: mission state and event trigger formats from Tasks 1 and 2.
- Produces: a deterministic `ch1_m1_echo_yard_v2` locked map and updated balance contract.

- [ ] **Step 1: Change map tests first**

Replace the old 14×10 assertion with:

```gdscript
_check(map.size == {"width": 18, "height": 14}, "MapSample: ch1_m1 fixed at 18x14")
_check(MapLoader.get_player_spawns(map).size() == 3, "MapSample: three-player deployment")
_check(MapLoader.get_enemy_spawns(map).size() == 5, "MapSample: five initial enemies")
_check((map.environment.route_anchors as Array).size() >= 3, "MapSample: three tactical routes")
_check(map.objects.filter(func(o): return o.type == "terminal").size() == 1, "MapSample: one upload terminal")
_check(map.objects.filter(func(o): return o.type == "resource").size() == 1, "MapSample: one optional cache")
_check(map.objects.filter(func(o): return o.type == "evac").size() == 1, "MapSample: one locked evacuation anchor")
_check(map.scripts.filter(func(s): return s.trigger.get("type") == "event").size() == 2, "MapSample: two event waves")
```

Add exact configuration assertions:

```gdscript
_check(level.player_units == 3 and level.enemy_count == 5, "ch1_m1 force size is 3v5")
_check(level.max_turns == 18 and level.three_star_turns == 11, "ch1_m1 standard turn contract")
_check(level.max_reinforcements == 3 and level.enemy_cap == 7, "ch1_m1 pressure caps")
_check(level.mission_type == "infiltrate", "ch1_m1 uses staged infiltrate objective")
_check(level.three_star_requires_optional == true, "ch1_m1 cache is required for three stars")
```

In the balance suite, update standard target range to `[10, 15]`, story to `[8, 13]`, and hard to `[11, 15]`.

- [ ] **Step 2: Run smoke and balance tests and verify RED**

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_smoke_test.tscn
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/chapter_one_balance_test.tscn
```

Expected: FAIL on old map dimensions, force size, mission type, and turn targets.

- [ ] **Step 3: Replace the locked map with the authored layout**

Use these fixed anchors and objects:

```json
{
  "map_id": "ch1_m1_echo_yard_v2",
  "size": {"width": 18, "height": 14},
  "mission_type": "infiltrate",
  "environment": {
    "kit": "echo_yard",
    "route_anchors": [[3, 9], [9, 8], [14, 7], [12, 4], [5, 3]]
  },
  "mission_flow": {
    "terminal_required": true,
    "upload_turns_required": 2,
    "upload_hold_radius": 1,
    "evac_locked_until_upload": true,
    "optional_resource_credit": 150
  }
}
```

Use exact object locations:

```json
[
  {"id": "player_alpha", "type": "spawn_player", "x": 8, "y": 13, "team": "player"},
  {"id": "player_bravo", "type": "spawn_player", "x": 9, "y": 13, "team": "player"},
  {"id": "player_charlie", "type": "spawn_player", "x": 10, "y": 13, "team": "player"},
  {"id": "enemy_west", "type": "spawn_enemy", "x": 4, "y": 8, "job": "sentry_basic"},
  {"id": "enemy_center", "type": "spawn_enemy", "x": 9, "y": 7, "job": "drone_scout"},
  {"id": "enemy_terminal", "type": "spawn_enemy", "x": 14, "y": 6, "job": "sentry_basic"},
  {"id": "enemy_sniper", "type": "spawn_enemy", "x": 15, "y": 3, "job": "sentry_sniper"},
  {"id": "enemy_assault", "type": "spawn_enemy", "x": 12, "y": 8, "job": "drone_assault"},
  {"id": "east_terminal", "type": "terminal", "x": 15, "y": 6, "state": "inactive"},
  {"id": "northwest_evac", "type": "evac", "x": 2, "y": 1, "radius": 1},
  {"id": "west_salvage", "type": "resource", "x": 2, "y": 8, "reward": "credit_150"}
]
```

Use two event scripts:

```json
[
  {
    "trigger_id": "terminal_counterattack",
    "trigger": {"type": "event", "name": "terminal_activated"},
    "action": "spawn_reinforcement",
    "data": {
      "units": [
        {"type": "sentry_basic", "position": [16, 12]},
        {"type": "drone_assault", "position": [17, 11]}
      ],
      "message": "警报升级：敌军从东南侧切断退路。"
    },
    "repeat": false
  },
  {
    "trigger_id": "evac_intercept",
    "trigger": {"type": "event", "name": "upload_completed"},
    "action": "spawn_reinforcement",
    "data": {
      "units": [{"type": "sentry_sniper", "position": [4, 1]}],
      "message": "上传完成，但北侧拦截手已就位。"
    },
    "repeat": false
  }
]
```

Author all four 14-row, 18-column layer matrices. Keep the three spawn cells, event spawn cells, terminal-adjacent cells, cache-adjacent cells, and at least three evac cells walkable. Place cover so west, center, and east routes remain independently connected. Add at least three landmarks at south deployment, east terminal, and northwest evacuation.

- [ ] **Step 4: Update level and playtest data**

Set:

```json
{
  "mission_type": "infiltrate",
  "size": "large",
  "player_units": 3,
  "enemy_count": 5,
  "max_turns": 18,
  "three_star_turns": 11,
  "three_star_requires_optional": true,
  "max_reinforcements": 3,
  "enemy_cap": 7,
  "tutorial_flags": [
    "teach_camera",
    "teach_movement",
    "teach_attack",
    "teach_cover",
    "teach_interaction",
    "teach_upload_hold",
    "teach_evac"
  ]
}
```

Update the `ch1_m1` map index entry using its existing schema:

```json
{
  "level_id": "ch1_m1",
  "name": "初次接触",
  "map_file": "data/generated_maps/ch1_m1.json",
  "seed": 1001,
  "size": "large",
  "theme": "echo_yard",
  "mission_type": "infiltrate"
}
```

- [ ] **Step 5: Run smoke, balance, and objective tests and verify GREEN**

Run Step 2 and the Task 1 objective test.

Expected: all paths and objects validate; assertions show 18×14, 3v5, two event waves, and revised target ranges.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/data/locked_maps/ch1_m1.json `
  tactical-grid/client/data/locked_maps/_index.json `
  tactical-grid/client/data/levels.json `
  tactical-grid/client/data/chapter1_playtest_matrix.json `
  tactical-grid/client/tests/battle_smoke_test_runner.gd `
  tactical-grid/client/tests/chapter_one_balance_test.gd
git commit -m "feat(chapter1): expand echo yard into a three-stage mission"
```

---

### Task 5: Readable Large-Map Camera `[CODE-CORE / xhigh]`

**Executor:** Strong coding model (`Sol xhigh` if available) plus windowed visual verification. Do not merge from source review alone.

**Files:**
- Modify: `tactical-grid/client/tests/battle_hud_contract_test.gd`
- Modify: `tactical-grid/client/tests/unit_animation_contract_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_camera_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/tutorial_hint.gd`

**Interfaces:**
- Consumes: map bounds, HUD safe viewport, player spawn centers, selected unit view.
- Produces:
  - `func setup(map_bounds: Rect2, safe_viewport: Rect2, initial_focus: Vector2 = Vector2(INF, INF)) -> void`
  - `func toggle_overview() -> void`
  - `func focus_home(target: Vector2) -> void`
  - `func begin_drag(screen_pos: Vector2) -> void`
  - `func drag_to(screen_pos: Vector2) -> void`
  - `func end_drag() -> void`
  - `func BattleController.get_player_deployment_center() -> Vector2`

- [ ] **Step 1: Replace full-map-fit assertions with readable-camera assertions**

Add:

```gdscript
_check(is_equal_approx(camera.zoom.x, 1.0), "large map starts at readable 1.0 zoom")
var deployment_center := _battle.get_player_deployment_center()
_check(camera.position.distance_to(deployment_center + camera._get_safe_viewport_offset()) < 2.0,
	"camera opens on the three-unit deployment")
```

Exercise drag and overview directly:

```gdscript
var before_drag := camera.position
camera.begin_drag(Vector2(500, 350))
camera.drag_to(Vector2(420, 300))
camera.end_drag()
_check(camera.position.distance_to(before_drag) > 1.0, "middle-drag pans the battlefield")

var readable_zoom := camera.zoom
camera.toggle_overview()
_check(camera.zoom.x < readable_zoom.x, "Tab overview fits more of the map")
camera.toggle_overview()
_check(camera.zoom.is_equal_approx(readable_zoom), "second Tab restores readable zoom")
```

Verify all four map corners are reachable:

```gdscript
for corner in [
	camera._map_bounds.position,
	camera._map_bounds.position + Vector2(camera._map_bounds.size.x, 0),
	camera._map_bounds.position + Vector2(0, camera._map_bounds.size.y),
	camera._map_bounds.end,
]:
	camera.focus_home(corner)
	var safe_world_center := camera.position - camera._get_safe_viewport_offset()
	var safe_world_size := camera._safe_viewport.size / camera.zoom
	var visible_world := Rect2(safe_world_center - safe_world_size * 0.5, safe_world_size)
	_check(visible_world.grow(1.0).has_point(corner), "camera can reach map corner %s" % corner)
```

- [ ] **Step 2: Run HUD and unit presentation tests and verify RED**

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_hud_contract_test.tscn
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/unit_animation_contract_test.tscn
```

Expected: FAIL because setup still fits the full map and drag/overview methods do not exist.

- [ ] **Step 3: Implement readable setup and navigation**

Set `DEFAULT_ZOOM := 1.0`, preserve `MIN_ZOOM := 0.65`, and compute `fit_zoom` only for overview. `setup()` uses `initial_focus` when finite and otherwise the map center.

Middle-mouse input calls drag methods. Mouse motion while dragging moves by:

```gdscript
position -= (screen_pos - _last_drag_screen_pos) / zoom
```

Update `_edge_pan` each frame from a 16px viewport margin. Handle:

```gdscript
KEY_HOME:
	focus_home(_home_target)
KEY_TAB:
	toggle_overview()
```

Store `_saved_zoom` and `_saved_position` before overview and restore both on the second toggle. All paths end in `_clamp_to_bounds()`.

In `BattleController`, expose and use:

```gdscript
func get_player_deployment_center() -> Vector2:
	if player_units.is_empty():
		return Rect2(Vector2.ZERO, Vector2(map_width, map_height) * CELL_SIZE).get_center()
	var total := Vector2.ZERO
	for unit in player_units:
		total += _get_cell_center(unit.grid_pos)
	return total / float(player_units.size())
```

Pass this result to camera setup. When selection changes, update the camera home target without forcing continuous follow.

- [ ] **Step 4: Update tutorial copy**

Add:

```gdscript
"teach_camera": "战场大于屏幕。按住鼠标中键拖动画面，滚轮缩放，WASD 或方向键平移；Tab 查看全图，Home 返回当前单位。",
"teach_upload_hold": "终端上传需要连续控制 2 个敌方回合。至少一名队员留在终端一格范围内，否则上传暂停。",
```

- [ ] **Step 5: Run HUD and unit presentation tests and verify GREEN**

Run Step 2.

Expected: readable default zoom, legal bounds, drag, overview restore, and existing event feedback all pass.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/game/battle_camera_controller.gd `
  tactical-grid/client/scripts/game/battle_controller.gd `
  tactical-grid/client/scripts/ui/tutorial_hint.gd `
  tactical-grid/client/tests/battle_hud_contract_test.gd `
  tactical-grid/client/tests/unit_animation_contract_test.gd
git commit -m "feat(camera): keep large battlefields readable and navigable"
```

---

### Task 6: Replace Token-Like Units with Readable 96px Art `[ART-GEN + ART-PIPELINE + VISUAL-QA]`

**Executor split:** Image generation model for Step 3 only; coding model for Steps 1, 2, 4-7, and 9; vision-capable model plus human review for Step 8.

**Files:**
- Create: `tactical-grid/client/assets/generated/chapter1/source/ch1_m1_units/`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/assault_96.png`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/sniper_96.png`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/heavy_96.png`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/sentry_basic_96.png`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/drone_scout_96.png`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/sentry_sniper_96.png`
- Create: `tactical-grid/client/assets/generated/chapter1/runtime/units/drone_assault_96.png`
- Create: `tactical-grid/client/tools/process_chapter1_unit_art.ps1`
- Modify: `tactical-grid/client/tests/unit_animation_contract_test.gd`
- Modify: `tactical-grid/client/scripts/data/art_catalog.gd`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `AI_RESOURCES_STATEMENT.md`
- Modify: `tactical-grid/client/data/RESOURCE_MANIFEST.md`

**Interfaces:**
- Consumes: seven generated source images with flat chroma background and the existing ArtCatalog unit keys.
- Produces: seven transparent 96×96 runtime textures and `UnitSprite.get_rendered_art_size() -> float`.

- [ ] **Step 1: Add failing art-size and presentation tests**

Extend `unit_animation_contract_test.gd`:

```gdscript
var required_keys: Array[StringName] = [
	&"assault", &"sniper", &"heavy", &"sentry_basic",
	&"drone_scout", &"sentry_sniper", &"drone_assault",
]
for key in required_keys:
	var texture := ArtCatalog.get_texture(&"unit", key)
	_check(texture is Texture2D, "%s loads through ArtCatalog" % key)
	if texture:
		_check(texture.get_size() == Vector2(96, 96), "%s is a 96x96 runtime sprite" % key)
		_check(_has_real_alpha(texture), "%s has transparent background" % key)

_check(assault_view.get_rendered_art_size() >= 76.0, "normal unit art renders at least 76px")
_check(not assault_view.uses_filled_token_base(), "normal units do not use a filled token base")
```

Add alpha and grayscale silhouette helpers. Require pairwise alpha-mask difference of at least 0.12 for assault/sniper/heavy and sentry/drone/sniper samples.

Use this alpha check:

```gdscript
func _has_real_alpha(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null:
		return false
	var transparent := 0
	var opaque := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.05:
				transparent += 1
			elif image.get_pixel(x, y).a > 0.90:
				opaque += 1
	return transparent > 0 and opaque > 0
```

- [ ] **Step 2: Run unit presentation test and verify RED**

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/unit_animation_contract_test.tscn
```

Expected: FAIL because catalog paths still use 64px art and presentation methods do not exist.

- [ ] **Step 3: Generate seven source images**

Use the `imagegen` skill and the Image Generation tool. Generate one source image per final key with this shared direction:

```text
Single tactical sci-fi game unit, three-quarter top-down view at roughly 55 degrees,
full body centered, oversized readable head/shoulders/weapon silhouette, painterly
real-time strategy unit art, hard rim lighting, no circular base, no text, no symbols,
no watermark, flat pure green chroma background, one character only, consistent camera
and scale with the Tactical Grid Echo Yard roster.
```

Apply the role-specific visual descriptions from Section 9.1 of the approved design. Save exact source names under `source/ch1_m1_units/`:

```text
assault_source_v1.png
sniper_source_v1.png
heavy_source_v1.png
sentry_basic_source_v1.png
drone_scout_source_v1.png
sentry_sniper_source_v1.png
drone_assault_source_v1.png
```

Inspect every source at original detail. Regenerate any source with multiple characters, baked scenery, unreadable weapon silhouette, watermark, or cropped body.

- [ ] **Step 4: Implement deterministic processing**

`process_chapter1_unit_art.ps1` must:

1. Load each exact source path.
2. Convert pixels close to the corner chroma color to alpha with a soft 18-value edge tolerance.
3. Find non-transparent bounds with 12px source padding.
4. Resize the bounded art to fit inside a 90×90 box.
5. Place it at bottom center of a transparent 96×96 canvas, leaving 3px foot margin.
6. Save the seven exact runtime paths.
7. Fail if dimensions differ from 96×96, corner alpha exceeds 0.02, or opaque bounds touch the canvas edge.

Use bundled .NET `System.Drawing` because existing project asset processors already use PowerShell and no new runtime dependency is permitted.

- [ ] **Step 5: Update ArtCatalog and UnitSprite**

Map the seven keys to the `_96.png` files. In `UnitSprite`:

```gdscript
const ART_MAX_SIZE := 76.0
const HEAVY_ART_MAX_SIZE := 82.0

func get_rendered_art_size() -> float:
	if not art_sprite or not art_sprite.texture:
		return 0.0
	return maxf(art_sprite.texture.get_width(), art_sprite.texture.get_height()) * art_sprite.scale.x

func uses_filled_token_base() -> bool:
	return false
```

Replace the two filled circles for normal units with a soft ellipse and a 2px faction arc. Keep Boss-specific rings. Set row draw order whenever the view is created or moved:

```gdscript
z_index = 100 + unit.grid_pos.y
```

Heavy uses 82px; other normal jobs use 76px. HP, shield, and AP indicators remain above the art and selection uses an outer ring only.

- [ ] **Step 6: Register provenance**

Add each source family, processing script, runtime paths, generation date, tool name, purpose, and validation to both resource documents. State that source images are export-excluded and runtime images are project-controlled generated assets.

- [ ] **Step 7: Run unit presentation and smoke tests and verify GREEN**

Run Step 2 and:

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_smoke_test.tscn
```

Expected: seven 96×96 textures load, alpha/silhouette/render-size contracts pass, and all animation states remain green.

- [ ] **Step 8: Perform visual sample review**

Run `unit_silhouette_preview.tscn` in windowed mode at 1280×720. Capture player and enemy rows on both light and dark terrain. Reject the batch if any pair is distinguishable only by color or if the ground ring dominates the body.

- [ ] **Step 9: Commit**

```powershell
git add AI_RESOURCES_STATEMENT.md `
  tactical-grid/client/data/RESOURCE_MANIFEST.md `
  tactical-grid/client/assets/generated/chapter1/source/ch1_m1_units `
  tactical-grid/client/assets/generated/chapter1/runtime/units `
  tactical-grid/client/tools/process_chapter1_unit_art.ps1 `
  tactical-grid/client/scripts/data/art_catalog.gd `
  tactical-grid/client/scripts/game/unit_sprite.gd `
  tactical-grid/client/tests/unit_animation_contract_test.gd
git commit -m "feat(art): replace opening mission token units"
```

---

### Task 7: Production E2E, Tutorial Order, and Release Evidence `[CODE-QA + PLAYTEST + DOCS-PROVENANCE]`

**Executor split:** Strong coding/debugging model for Steps 1-6; vision-capable model and human playtester for Step 7; documentation model for Steps 8-9 after evidence exists.

**Files:**
- Modify: `tactical-grid/client/tests/chapter_one_e2e_test.gd`
- Modify: `tactical-grid/client/tests/battle_hud_contract_test.gd`
- Modify: `tactical-grid/client/tests/run_release_gate.ps1` only if a new standalone test scene is added
- Modify: `tactical-grid/client/data/dialogues.json`
- Modify: `tactical-grid/client/scripts/ui/tutorial_hint.gd`
- Modify: `tactical-grid/PROJECT_STATUS.md`
- Modify: `docs/PROJECT_TAKEOVER_ROADMAP.md`
- Modify: `docs/qa/CHAPTER1_RELEASE_CANDIDATE_QA.md`

**Interfaces:**
- Consumes: completed mission systems, map, camera, art, and result payload from Tasks 1 through 6.
- Produces: full production path evidence and updated reader-facing status.

- [ ] **Step 1: Add a failing first-mission E2E path**

The E2E test must instantiate the real battle scene and verify:

```gdscript
_check(battle.map_width == 18 and battle.map_height == 14, "M1 production map is expanded")
_check(battle.player_units.size() == 3, "M1 deploys three distinct player jobs")
_check(battle.enemy_units.size() == 5, "M1 starts with five authored enemies")
_check(battle.mission_objective_state.get_stage() == &"approach", "M1 begins in approach")
```

Drive the public mission state methods and real event bridge through terminal activation, one paused upload round, two controlled rounds, both reinforcement events, resource collection, and evacuation. Assert the final result has 3 stars only when all three conditions are met and `optional_credit == 150`.

- [ ] **Step 2: Run E2E and HUD tests and verify RED**

```powershell
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/chapter_one_e2e_test.tscn
& "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless --path . res://tests/battle_hud_contract_test.tscn
```

Expected: any incomplete stage feedback, tutorial order, or result integration fails visibly.

- [ ] **Step 3: Finalize tutorial and dialogue copy**

The first mission intro must state the actual plan: reach the east terminal, hold upload, then cross to northwest evacuation. Remove any line implying immediate extraction.

Tutorial queue order must exactly match:

```gdscript
[
	"teach_camera",
	"teach_movement",
	"teach_attack",
	"teach_cover",
	"teach_interaction",
	"teach_upload_hold",
	"teach_evac",
]
```

Stage-change messages must remain visible even when tutorials are skipped.

- [ ] **Step 4: Run E2E and HUD tests and verify GREEN**

Run Step 2.

Expected: real scenes reflect the full three-stage mission and all result fields persist.

- [ ] **Step 5: Run the complete release gate**

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_release_gate.ps1 `
  -GodotPath "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe"
```

Expected: every suite passes, zero failures, exactly two expected corruption-recovery warnings, zero unexpected warnings, zero unexpected errors.

- [ ] **Step 6: Export and verify Windows package**

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1 `
  -GodotPath "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File tests/verify_windows_package.ps1
```

Expected: EXE and PCK exist, metadata checks pass, and the package cold-starts headlessly.

- [ ] **Step 7: Complete windowed manual QA**

Use a new standard-difficulty save and real mouse/keyboard input:

1. Record start time before entering battle.
2. Use at least two of the three tactical routes.
3. Activate the terminal and observe exactly two upload rounds.
4. Deliberately leave terminal control for one round and confirm upload pauses.
5. Observe both event reinforcement waves.
6. Collect the west resource cache.
7. Evacuate all three survivors.
8. Record elapsed time, turns, casualties, cache state, stars, and final credits.
9. Repeat visual checks at 1280×720, 1920×1080, and 2560×1440.
10. Capture deployment, upload defense, and cross-map evacuation screenshots.

Acceptance: 25 to 35 minutes, 10 to 15 turns, no input dead ends, no unreadable unit pair, no HUD overlap, and no camera-inaccessible map edge. If the run is under 20 minutes, adjust positions and pressure rather than HP. If over 40 minutes, shorten upload or route distance without deleting a mission phase.

- [ ] **Step 8: Update evidence documents with actual results**

Record exact assertion totals, package sizes/hashes, manual elapsed time, turns, casualties, cache state, stars, tested resolutions, screenshot paths, and any remaining limitations. Do not retain the old claim that the first mission is 14×10 or can be validated by the prior 3-turn sample.

- [ ] **Step 9: Commit**

```powershell
git add tactical-grid/client/data/dialogues.json `
  tactical-grid/client/scripts/ui/tutorial_hint.gd `
  tactical-grid/client/tests/chapter_one_e2e_test.gd `
  tactical-grid/client/tests/battle_hud_contract_test.gd `
  tactical-grid/client/tests/run_release_gate.ps1 `
  tactical-grid/PROJECT_STATUS.md `
  docs/PROJECT_TAKEOVER_ROADMAP.md `
  docs/qa/CHAPTER1_RELEASE_CANDIDATE_QA.md
git commit -m "test(chapter1): verify expanded opening mission release path"
```

---

## Plan Self-Review Checklist

- Every approved design section maps to a task: mission flow 1, reinforcements 2, resources 3, map/balance 4, camera 5, art 6, tutorials and release QA 7.
- Event interfaces use the same `StringName` names in objective state, director, map JSON, and battle bridge.
- Reward fields use `optional_resource_collected` and `optional_credit` consistently from mission state through battle result, save, UI, and tests.
- The map coordinates are unique, in bounds, and reserve three deployment slots.
- Existing turn triggers, non-first-mission objective types, Boss camera feedback, and animation states remain covered.
- No task uses enemy HP inflation, infinite reinforcement, or full-framework replacement to create playtime.
- Every task is assigned to a workstream with an executor, reasoning level, required tools, and evidence boundary.
- Image generation is isolated to source-art creation; processing, import, runtime integration, tests, and provenance remain explicit.
- Automated QA, visual QA, and human experience acceptance are separate gates and cannot substitute for one another.
