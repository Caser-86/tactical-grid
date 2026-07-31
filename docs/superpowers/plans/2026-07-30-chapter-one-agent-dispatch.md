# Chapter One Agent Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dispatch the approved Chapter One tactical-network redesign into independently testable code, art, audio, document, and human-validation work.

**Architecture:** Preserve the Godot client and the tested grid, pathfinding, turn, and base battle systems. First remove P0 interaction and state-authority blockers, then establish serialized battle state and visibility, then implement one M1 network encounter before producing later missions or bulk art. Node tooling remains development-only; locked client maps are the runtime authority.

**Tech Stack:** Godot 4.7.1 GDScript, JSON locked maps, PowerShell build/test tools, Image Generation plus deterministic processing scripts, PCM WAV synthesis.

## Global Constraints

- Platform: Windows desktop, offline single-player.
- Runtime authority: `tactical-grid/client`; Node server is not a player dependency.
- Controls: left-click context action, right-click cancel, `Tab` next unit, `Space` end turn, `G` network overlay, `Home` focus current unit, `Esc` pause.
- First chapter roster: assault, sniper, heavy, scout. Medic is not a Chapter One deployable unit.
- First chapter facilities: camera, door, turret, power conduit, reinforcement beacon.
- M1 target: 22×16, three encounters, one player then two players, 7-9 enemies, at most three active at once, 15-20 minutes.
- Do not implement per-turn rollback, revive turns, permanent death, lift/platform facilities, random main-story maps, or a hacking minigame.
- Every code task adds a focused test before updating the release gate.
- No generated asset enters runtime without provenance, alpha/size/import validation, and an in-game check.
- No task claims final playability without human evidence.

---

## 2026-07-31 Execution Status

This document is the historical dispatch specification. Live priority and completion authority now belongs to `docs/PROJECT_TAKEOVER_ROADMAP.md`; future agents must work from `main`.

| Task | Current status | Remaining gate |
|---|---|---|
| CODE-P0-01 | Code and automated contracts implemented | 720p/1080p runtime screenshots |
| CODE-P0-02 | Context HUD, names and portraits implemented | Real first-player input evidence |
| CODE-P0-03 | Complete | Keep regression tests green |
| CODE-P0-04 | Save/export code implemented | Clean-clone export verification |
| CODE-P1-01 | Partial | Route all production actions through query/validate/commit |
| CODE-P1-02 | Partial | Require schema version, facilities, connections and data-stable IDs |
| CODE-P2-01 | Partial | Wire planner/intents and render fog memory/last-known markers |
| CODE-P2-02 | System slice implemented | Complete runtime facility/alert presentation |
| CONTENT-01 | Partial | 22×16 three-encounter M1, checkpoint retry and manual flow |
| ART-GEN/INTEGRATE-01 | Runtime unit batch integrated | Human grayscale recognition |
| ART-GEN/INTEGRATE-02 | Facility icons integrated | Node-state, intent and alert visual set |
| ART-GEN/INTEGRATE-03 | Landmark integrated | Exported 720p/1080p evidence |
| AUDIO-01 | Technical integration complete | Human listening/mix gate |
| DOC-QA-01 | Updated to unified main baseline | Keep evidence synchronized |
| HUMAN-01/02 | Not started | Human participants and release hardware |

All checkboxes below describe the original task contract and are not a second live backlog.

---

## Dispatch Rules

| Queue | What belongs here | Recommended model | Can run now? |
|---|---|---|---|
| CODE-P0 | Input, camera, dialogue, objective authority, save/export correctness | Terra high or Sol xhigh | Yes, sequential inside the queue |
| CODE-P1 | Action contract, stable IDs, RNG, map schema | Sol xhigh | After CODE-P0 objective task |
| CODE-P2 | Visibility, AI planning/intents, network/alert state | Sol xhigh | After CODE-P1 |
| CONTENT | M1 map/data/tutorial/encounter integration | Terra xhigh | After CODE-P2 network vertical slice |
| ART-GEN | Source image generation only | Image Generation | Style tests can begin now; batch work waits for M1 slice |
| ART-INTEGRATE | Chroma cleanup, sprites, import/catalog/effects wiring | Terra high | After each ART-GEN batch |
| AUDIO | Procedural or original audio creation and wiring | Terra high plus human listen | Network state names must be stable first |
| DOC-QA | Documentation, manifests, CI/release evidence | Terra medium/high | P0 docs finished; remaining tasks follow code |
| HUMAN | New-player playtests, visual recognition, listening, hardware/release checks | Human | At their listed gates only |

Never give the same file to two agents. An agent must commit only its assigned files and must not include `.superpowers/` runtime screenshots.

## Code and Documentation Tasks

### CODE-P0-01: Battle viewport and camera composition

**Type:** Pure Godot code and tests. No image generation.

**Files:**

- Modify: `tactical-grid/client/scripts/game/battle_camera_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scenes/battle.tscn`
- Modify: `tactical-grid/client/tests/battle_hud_contract_test.gd`
- Test: `tactical-grid/client/tests/battle_hud_contract_test.tscn`

**Produces:** `BattleCameraController.configure_bounds(map_pixel_rect, hud_safe_rect)` and a 720p-safe playable battle viewport.

- [ ] Add a failing test asserting that a loaded 18×14 baseline map and a future 22×16 map both fill the tactical viewport at 1280×720 without a lower-half empty region.
- [ ] Clamp camera pan and min/max zoom against the map rectangle minus the top and bottom HUD safe areas.
- [ ] Keep `Home` focus behavior and move overview to a dedicated remappable action; remove `Tab` from overview.
- [ ] Capture 1280×720 and 1920×1080 battle screenshots with no selected unit and a selected unit.
- [ ] Run `battle_hud_contract_test.tscn` and `run_release_gate.ps1`.

**Acceptance:** The map, not unused black canvas, occupies the entire tactical viewport at both resolutions; HUD never overlaps the clickable map.

### CODE-P0-02: Direct interaction, contextual HUD, tutorial, and dialogue

**Type:** Pure Godot code and text. No image generation.

**Files:**

- Modify: `tactical-grid/client/scripts/game/input_bindings.gd`
- Modify: `tactical-grid/client/scripts/game/targeting_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/scripts/ui/tutorial_hint.gd`
- Modify: `tactical-grid/client/scripts/ui/dialogue_system.gd`
- Modify: `tactical-grid/client/scenes/dialogue.tscn`
- Modify: `tactical-grid/client/tests/targeting_controller_test.gd`
- Modify: `tactical-grid/client/tests/battle_hud_contract_test.gd`

**Produces:** A context state enum `none`, `unit_selected`, `move_preview`, `attack_preview`, `facility_preview`; a clear next-step prompt; translated display names rather than raw speaker IDs.

- [ ] Add failing tests for `Space` ending turn, `Tab` selecting next available player, `G` toggling only the future network overlay action, and `Esc` opening pause.
- [ ] Add a HUD state for no selected unit: show one short prompt and hide irrelevant action buttons.
- [ ] Make safe left-click movement and primary-weapon attacks execute from the current preview; retain one explicit risk confirmation for reaction fire, alert, or objective-range departure.
- [ ] Replace multi-page camera tutorial with contextual one-action hints shown only when that action is required.
- [ ] Map dialogue IDs such as `alpha` and `commander` to localized display names; wire portrait slots with a safe fallback until ART-INTEGRATE-01 delivers final portraits.
- [ ] Run targeting, HUD, and real-mouse/manual smoke verification from menu to one moved unit, one attack, cancel, pause, and end turn.

**Acceptance:** A first-time player can identify the currently valid action without opening external instructions; no raw dialogue ID appears in the battle flow.

### CODE-P0-03: Single mission-objective authority

**Type:** Pure architecture code and tests. No image generation.

**Files:**

- Modify: `tactical-grid/client/scripts/game/mission_objective_state.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Modify: `tactical-grid/client/tests/chapter_one_objectives_test.gd`
- Modify: `tactical-grid/client/tests/chapter_one_e2e_test.gd`
- Modify: `tactical-grid/client/tests/run_release_gate.ps1`

**Produces:** `MissionObjectiveState.apply_event(event_name, payload) -> Dictionary` as the only mutation path for mission phase, main objective, and optional objectives.

- [ ] Write a failing objective test that activates a terminal through the real battle interaction path and asserts the same state that direct objective test setup observes.
- [ ] Move duplicate objective phase fields out of `BattleController`; keep read-only derived UI accessors only.
- [ ] Route terminal activation, upload completion, evacuation, victory, and failure events through `apply_event`.
- [ ] Add a test that invalid event names and impossible phase transitions return an error dictionary without silently changing mission state.
- [ ] Add standalone objective and targeting suites to `run_release_gate.ps1` with explicit assertion totals.

**Acceptance:** Tests and player interaction mutate one state object; no mission event depends on controller mirror state.

### CODE-P0-04: Save recovery and reproducible Windows export

**Type:** Pure code, PowerShell, configuration, and release documentation. No image generation.

**Files:**

- Modify: `tactical-grid/client/scripts/network/save_manager.gd`
- Modify: `tactical-grid/client/tests/assert_no_save_parse_error.ps1`
- Modify: `tactical-grid/client/tools/build_windows.ps1`
- Modify: `tactical-grid/client/tests/verify_windows_package.ps1`
- Add/track: `tactical-grid/client/export_presets.cfg`
- Modify: `tactical-grid/README.md`
- Modify: `THIRD_PARTY_NOTICES.md`

**Produces:** One shared release directory and filename contract, safe primary/backup save behavior, future-save refusal.

- [ ] Write a failing save fixture test: corrupt primary, retain valid `.bak`, load recovery, save again, then assert the valid backup was not replaced by corrupt bytes.
- [ ] Refuse a save with version newer than `SAVE_VERSION`; show a clear error and do not rewrite the file.
- [ ] Track a portable `export_presets.cfg` without machine-private paths.
- [ ] Make build script and verifier share one default directory and one `TacticalGrid.exe`/`.pck` naming convention.
- [ ] Make the verifier include notices, privacy, resource manifest and SHA-256 manifest checks.
- [ ] Validate from a clean clone after this task, not from an existing build directory.

**Acceptance:** A clean clone can import, test, export, and verify a new package without checking an old artifact.

### CODE-P1-01: Unified action query, preview, validation, and commit

**Type:** Pure architecture code and tests. No image generation.

**Files:**

- Modify: `tactical-grid/client/scripts/game/action_system.gd`
- Modify: `tactical-grid/client/scripts/game/targeting_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/unit.gd`
- Modify: `tactical-grid/client/tests/targeting_controller_test.gd`
- Add: `tactical-grid/client/tests/action_system_test.gd`
- Add: `tactical-grid/client/tests/action_system_test.tscn`

**Produces:** `ActionSystem.query_action(request)`, `validate_action(preview)`, and `commit_action(preview)` dictionaries shared by move, attack, skill, item, overwatch, and future facility actions.

- [ ] Write a failing test that a previewed safe move commits to the same final grid cell and cost.
- [ ] Write a failing test that a stale preview or invalid target cannot commit.
- [ ] Route movement through `ActionSystem`; preserve independent movement allowance and 2AP semantics.
- [ ] Route attack, skills, items, and overwatch through the same validation/commit contract.
- [ ] Update HUD to render only values returned by `query_action`.
- [ ] Add the suite to the release gate.

**Acceptance:** Preview is not guessed independently by HUD; every action has one validation path.

### CODE-P1-02: Stable IDs, RNG, and locked-map schema

**Type:** Pure code, JSON, and tests. No image generation.

**Files:**

- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/action_system.gd`
- Modify: `tactical-grid/client/scripts/game/unit.gd`
- Modify: `tactical-grid/client/scripts/map/map_loader.gd`
- Modify: `tactical-grid/client/data/locked_maps/_index.json`
- Modify: `tactical-grid/client/data/locked_maps/ch1_m1.json`
- Add: `tactical-grid/client/scripts/core/locked_map_validator.gd`
- Add: `tactical-grid/client/tests/locked_map_validator_test.gd`
- Add: `tactical-grid/client/tests/locked_map_validator_test.tscn`

**Produces:** Stable `entity_id`, injectible `BattleRng`, and a versioned map schema with `schema_version`, `nodes`, `facilities`, and `connections` preserved by the loader.

- [ ] Write a map validator test that rejects duplicate IDs, invalid grid coordinates, unknown facility IDs, and dangling connection IDs.
- [ ] Write a deterministic combat test where a fixed seed yields identical serialized outcomes.
- [ ] Assign stable IDs on map load; never use array index as persistence identity.
- [ ] Replace local random calls in action resolution with the injected battle RNG.
- [ ] Make `MapLoader` preserve validated network fields instead of discarding unknown top-level keys.
- [ ] Add the validator suite to the release gate.

**Acceptance:** A later encounter checkpoint can serialize references safely; the network map has one explicit schema.

### CODE-P2-01: Visibility memory and enemy intent

**Type:** Pure Godot systems and tests. No image generation yet.

**Files:**

- Add: `tactical-grid/client/scripts/game/visibility_state.gd`
- Add: `tactical-grid/client/scripts/game/enemy_intent_state.gd`
- Modify: `tactical-grid/client/scripts/core/vision_system.gd`
- Modify: `tactical-grid/client/scripts/ai/enemy_director.gd`
- Add: `tactical-grid/client/scripts/ai/enemy_planner.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Add: `tactical-grid/client/tests/visibility_state_test.gd`
- Add: `tactical-grid/client/tests/visibility_state_test.tscn`
- Add: `tactical-grid/client/tests/enemy_intent_state_test.gd`
- Add: `tactical-grid/client/tests/enemy_intent_state_test.tscn`

**Produces:** `VisibilityState.get_cell_state(cell)` and `EnemyIntentState.get_public_intents()` filtered by current observation.

- [ ] Test unseen cells return `unexplored`, previously visible cells return `recorded`, and active sight returns `observed`.
- [ ] Test a hidden enemy cannot produce a public intent and a newly observed enemy cannot deal unannounced lethal damage that same reveal turn.
- [ ] Split AI planning from execution; plan with vision and line-of-sight constraints.
- [ ] Render last-known markers as stale information, not live unit data.
- [ ] Add visibility/intent tests to the release gate.

**Acceptance:** Information is a tactical resource, not a cosmetic fog overlay.

### CODE-P2-02: Tactical network and alert vertical slice

**Type:** Pure Godot systems, data, UI wiring, tests. Uses placeholder-safe procedural markers until ART-INTEGRATE tasks deliver final assets.

**Files:**

- Add: `tactical-grid/client/scripts/game/tactical_network_state.gd`
- Add: `tactical-grid/client/scripts/game/alert_state.gd`
- Modify: `tactical-grid/client/scripts/game/action_system.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/data/locked_maps/ch1_m1.json`
- Add: `tactical-grid/client/tests/tactical_network_state_test.gd`
- Add: `tactical-grid/client/tests/tactical_network_state_test.tscn`
- Add: `tactical-grid/client/tests/alert_state_test.gd`
- Add: `tactical-grid/client/tests/alert_state_test.tscn`

**Produces:** `TacticalNetworkState.perform_operation(node_id, operation, actor_id)` and `AlertState.apply_event(event_name)`.

- [ ] Test node states `enemy`, `player`, `neutral`, `damaged` and one-time takeover pulse.
- [ ] Test camera reveals, door route changes, turret ownership, power hazard, and beacon delay separately.
- [ ] Test takeover, disable, and overload each cost 1AP and overload permanently damages its selected facility while raising alert.
- [ ] Test `G` only toggles network visualization; it never changes gameplay state.
- [ ] Display next concrete alert consequence in HUD.
- [ ] Add both suites to the release gate.

**Acceptance:** One M1 encounter can be won by changing information, route, fire, hazard, or reinforcement behavior through a node.

### CONTENT-01: Rebuild M1 after the vertical slice

**Type:** Locked-map JSON, mission data, dialogue/tutorial text, integration tests. No new image generation is required to start; uses ART-INTEGRATE assets when ready.

**Files:**

- Modify: `tactical-grid/client/data/locked_maps/ch1_m1.json`
- Modify: `tactical-grid/client/data/locked_maps/_index.json`
- Modify: `tactical-grid/client/data/chapter1_playtest_matrix.json`
- Modify: `tactical-grid/client/tests/chapter_one_e2e_test.gd`
- Modify: `tactical-grid/client/tests/chapter_one_balance_test.gd`
- Modify: `tactical-grid/client/tests/chapter_one_objectives_test.gd`
- Modify: dialogue/mission data files identified by current `ch1_m1` references

- [ ] Write tests for a one-unit start, scout rescue, two-unit second half, 7-9 total enemies, and no more than three simultaneously active enemies.
- [ ] Author three compact encounters: opening movement/attack, camera-node rescue reveal, changed-route extraction.
- [ ] Keep all node operations discoverable through contextual tutorial hints.
- [ ] Replace star wording with mission/intel/squad badge labels while retaining the integer save field.
- [ ] Run the full release gate and a real mouse/keyboard M1 flow at 720p and 1080p.

**Acceptance:** M1 is the only content gate for starting M2-M6 reauthoring.

## Image Generation Tasks

### ART-GEN-01: M1 character and enemy visual test batch

**Type:** Image generation only. Do not wire into Godot in this task.

**Outputs:** Source sheets for assault, scout, patrol sentry, scout drone, protocol engineer, and hunter. Produce each subject separately, not in a shared uncut collage.

**Art direction:** 3/4 top-down tactical sprite concept, shallow painted volume, transparent or flat chroma background, no text, no watermark, no UI frame. Match the existing industrial cyber-tactical palette. Preserve readable silhouettes at 56×56 inside a 64×64 cell.

- [ ] Generate one source image per role at at least 512×512.
- [ ] Assault: wide shoulders, short rifle, cyan forearm lamps, triangular advance stance.
- [ ] Scout: low profile, asymmetric antenna backpack, short weapon, green leg armor.
- [ ] Patrol sentry: angular upright chassis, single weapon arm, red front sensor.
- [ ] Scout drone: wing planform, central scan core, circular scan ring.
- [ ] Protocol engineer: slim maintenance arm, data cables, node tool case.
- [ ] Hunter: low forward stance, long legs or propulsion rig, directional tracking light.
- [ ] Save only source files under `assets/generated/chapter1/source/`; record tool, date, prompt, and intended runtime ID in `AI_RESOURCES_STATEMENT.md`.

**Acceptance:** A reviewer can identify each role in grayscale without faction rings; no image is placed in runtime folders yet.

### ART-INTEGRATE-01: Process and wire the M1 visual test batch

**Type:** Godot asset processing and code integration. Requires ART-GEN-01.

**Files:**

- Add/modify: `tactical-grid/client/tools/process_chapter1_unit_art.ps1`
- Add: `tactical-grid/client/assets/generated/chapter1/runtime/units/<role>_96.png`
- Modify: `tactical-grid/client/scripts/data/art_catalog.gd`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `tactical-grid/client/data/RESOURCE_MANIFEST.md`
- Modify: `tactical-grid/client/tests/unit_animation_contract_test.gd`

- [ ] Deterministically remove chroma background, crop with padding, resize/composite to 96×96, and preserve alpha.
- [ ] Validate every runtime image is 96×96, has alpha, does not touch canvas edges, and differs from every mapped alias by a documented silhouette threshold.
- [ ] Map the six runtime IDs through `ArtCatalog`; do not silently reuse `cyber_guard` for unrelated roles.
- [ ] Add unit-specific idle, attack, hit, skill, and death motion parameters.
- [ ] Verify in a dense M1 battle at default 720p zoom and at 1080p.

**Acceptance:** Generated images become tested runtime sprites, not unused files.

### ART-GEN-02: Network and facility visual language

**Type:** Image generation only. May start after CODE-P2-02 interfaces are named.

**Outputs:** Source art for node states and facility glyphs, designed as a coherent small-icon system.

- [ ] Generate four node-state motifs: enemy control, player control, neutral, damaged.
- [ ] Generate five facility motifs: camera, door, turret, power conduit, reinforcement beacon.
- [ ] Generate intent motifs: move, attack, scan, reclaim, reinforce, suppress, special hazard.
- [ ] Generate alert/network feedback motifs: detected, alert rise, takeover pulse, disable, overload.
- [ ] Use simple high-contrast geometry suitable for 24-48 pixel runtime display, no text baked in.
- [ ] Store source files only; update AI statement with each batch.

### ART-INTEGRATE-02: Node, facility, intent, and alert integration

**Type:** Asset processing, Godot UI/effect wiring. Requires CODE-P2-02 and ART-GEN-02.

**Files:**

- Add: runtime node/facility/intent/alert PNG files under `assets/generated/chapter1/runtime/`
- Modify: `tactical-grid/client/scripts/data/art_catalog.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/scripts/game/tactical_effect.gd`
- Modify: `tactical-grid/client/data/RESOURCE_MANIFEST.md`
- Modify: `tactical-grid/client/tests/battle_hud_contract_test.gd`

- [ ] Process every image to exact runtime dimensions and alpha.
- [ ] Render node/facility state on map, intent beside observed enemies, and alert consequence in HUD.
- [ ] Ensure lines and overlays remain hidden by default and only show relevant connections under `G` or node hover.
- [ ] Test 720p readability, grayscale differentiation, and reduced-motion behavior.

### ART-GEN-03: M1 environment landmark test

**Type:** Image generation only. Can start now, but only one landmark batch.

**Outputs:** One Echo Freight Yard hero landmark chosen from gantry crane or floodlight tower, with a matching damaged/active state if the facility design requires it.

- [ ] Generate one isolated landmark source at 1024×1024 with a clean chroma or transparent background.
- [ ] Keep top-down perspective, shallow depth, no text, no decorative collision ambiguity.
- [ ] Do not generate six mission landmark sets before M1 passes human testing.

### ART-INTEGRATE-03: M1 landmark processing and map placement

**Type:** Asset integration and map composition. Requires ART-GEN-03 and CONTENT-01.

- [ ] Process landmark to transparent runtime sprite with safe padding.
- [ ] Place it so it creates orientation but never hides nodes, units, click targets, or blocker truth.
- [ ] Add the asset to manifest and validate it in exported 720p/1080p M1 screenshots.

## Audio Tasks

### AUDIO-01: Network and alert first-pass feedback

**Type:** Procedural/original audio generation and Godot integration. Requires CODE-P2-02 event names.

**Files:**

- Modify: `tactical-grid/client/tools/generate_chapter1_audio.ps1`
- Add: WAV files under `tactical-grid/client/assets/audio/sfx/`
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Modify: `tactical-grid/client/data/RESOURCE_MANIFEST.md`
- Modify: `tactical-grid/client/assets/audio/README.md`

- [ ] Create scan, takeover, disable, overload, alert rise, camera reveal, turret reversal and beacon delay sounds.
- [ ] Add polyphonic SFX playback or a small player pool so combat sounds do not interrupt each other.
- [ ] Route all sounds through existing SFX bus and respect volume/reduced-motion settings.
- [ ] Verify concurrent attack, alert, and facility effects without clipping or dropped feedback.

## Documentation and Release Tasks

### DOC-QA-01: Keep evidence synchronized through P0-P4

**Type:** Documentation and test-record maintenance. No generation.

**Files:**

- Modify: `docs/PROJECT_TAKEOVER_ROADMAP.md`
- Modify: `tactical-grid/PROJECT_STATUS.md`
- Modify: `docs/qa/2026-07-30-project-wide-redesign-audit.md`
- Modify: `tactical-grid/client/data/RESOURCE_MANIFEST.md`
- Modify: `AI_RESOURCES_STATEMENT.md`
- Modify: `THIRD_PARTY_NOTICES.md`

- [ ] After each code task, record command, date, suite totals, known limits, and the exact task exit gate.
- [ ] After each art/audio task, record final paths, source/process, license, import test, and runtime screenshot/listening evidence.
- [ ] Keep pre-network QA immutable; add new QA records rather than overwriting old package hashes.
- [ ] Do not call a package release candidate until clean-clone, human, license, performance, and package gates pass.

## Human-Only Gates

### HUMAN-01: M1 first-player understanding gate

**Cannot be delegated to an AI agent.** Run after CONTENT-01 and ART-INTEGRATE-02.

- [ ] Recruit three people who have not read the design documentation.
- [ ] Ask each to start M1 without external instructions.
- [ ] Record completion, elapsed time, turns, failed actions, restarts, alert peak, node use, and what they think the core loop is.
- [ ] Require all three to complete selection, movement, attack, takeover, and end turn; record failures rather than coaching around them.
- [ ] Do not begin bulk M2-M6 content work until the project lead reviews results.

### HUMAN-02: Production gates

**Cannot be delegated to an AI agent.**

- [ ] Five-person grayscale role-recognition test for four players and five enemies.
- [ ] One player completes all six redesigned missions.
- [ ] At least three samples per mission and difficulty.
- [ ] 720p, 1080p, 1440p, ultrawide, keyboard and controller matrix.
- [ ] Two-hour soak, clean Windows account, final loudness/listening, and license/package review.

## Recommended Execution Order

1. CODE-P0-01 through CODE-P0-04.
2. CODE-P1-01 and CODE-P1-02.
3. CODE-P2-01 and CODE-P2-02.
4. ART-GEN-01 may run during CODE-P0/P1; ART-INTEGRATE-01 after its source batch.
5. ART-GEN-02 only after facility interfaces stabilize; ART-INTEGRATE-02 after CODE-P2-02.
6. CONTENT-01, ART-GEN-03, ART-INTEGRATE-03, and AUDIO-01.
7. HUMAN-01.
8. Only after HUMAN-01 passes: M2-M6, Boss, chapter balance, and full release work.

## Self-Review

- Scope covered: P0 interaction/reproducibility, P1 action/state architecture, P2 information/network systems, M1 content, art generation/integration, audio, documentation, and human gates all map to tasks above.
- Deliberate exclusions: rollback, revive turns, permanent death, lift platforms, random maps, hacking minigame, and later chapter production are not assigned before the M1 human gate.
- Cross-task contracts: CODE-P1-01 defines action requests; CODE-P1-02 defines map fields and IDs; CODE-P2-01 defines observation; CODE-P2-02 defines facilities; art and audio only consume stable IDs after their code tasks.
- No bulk image generation is authorized before a runtime M1 visual test validates the style.
