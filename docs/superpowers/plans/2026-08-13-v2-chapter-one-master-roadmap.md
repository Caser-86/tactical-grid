# Tactical Grid V2 Chapter One Master Roadmap

> **For agentic workers:** This is the portfolio-level dispatcher. Execute only the currently unlocked stage. Each stage receives its own implementation plan before code work begins.

**Goal:** Deliver V2 Chapter One as an independently launchable Windows tactical-adventure game with six main missions, four optional operations, a complete boss ending, formal art/audio, isolated saves, and a single-owner human acceptance gate.

**Architecture:** Preserve the existing V2 data repository, deterministic combat, locked maps, checkpoint system, and V1/V2 isolation. Stabilize M1 first, then extend through bounded V2-only input, camera, presentation, mission, encounter, enemy-strategy, content, and release modules; shared V1 controllers expose integration hooks but do not own new V2 rules.

**Tech Stack:** Godot 4.7.1, GDScript, JSON locked maps/data, PowerShell release gates, Windows x64 export, ImageGen plus deterministic image processing, Git worktree branch `codex/ch1-infiltration-v2`.

## Global Constraints

- Product authority: `docs/superpowers/specs/2026-08-13-v2-chapter-one-production-game-design.md`.
- V1 remains frozen; do not merge save identities, user directories, boot scenes, tests, or release artifacts.
- Front-end actions remain move, normal attack, one active ability per character, and contextual facility operation.
- Each character has one move and one action per player turn; order remains free.
- Normal attacks are deterministic and show exact results before commit.
- Main maps remain authored, locked JSON maps; no runtime-random main layouts.
- M1 must pass its fun, usability, art-sample, automated, package, and single-owner human gates before bulk M2-M6 production.
- Existing dirty changes are user/project work. Audit and integrate them; never discard them with reset or checkout.
- Every implementation task follows red, green, focused regression, full relevant gate, and an independent commit.
- Assertions prove contracts, not fun. Human acceptance remains a separate result.

---

## 1. Authority And Supersession

### Authoritative product documents

1. `docs/superpowers/specs/2026-08-13-v2-chapter-one-production-game-design.md`
2. `docs/v2/V2_MASTER_SPEC.md`, after its conflicting content targets are aligned to the production design
3. The currently unlocked stage implementation plan
4. Focused bug specifications that do not conflict with the production design

### Historical documents

`docs/superpowers/specs/2026-08-06-v2-m1-m2-content-expansion-design.md` remains historical evidence. Its data-driven mission, checkpoint, stable-ID, and isolation work remains reusable, while its 12/13-enemy duration targets, route-choice modal, and forced multi-step M1 flow are superseded.

### Stage plan files

| Stage | Plan file | Creation gate |
|---|---|---|
| 0-2 | `2026-08-13-v2-m1-core-fun-implementation.md` | Created with this roadmap |
| 3A | `v2-content-pipeline-and-modules-implementation.md` | M1 automated and art-sample gates pass |
| 3B | `v2-m2-m3-o1-o2-implementation.md` | Shared content pipeline contracts pass |
| 4 | `v2-m4-m5-o3-o4-implementation.md` | M2/M3 package flows and save migration pass |
| 5 | `v2-m6-boss-and-ending-implementation.md` | Four-character squad and all enemy strategies pass |
| 6 | `v2-chapter-one-art-audio-production.md` | M1 art sample is approved and all runtime slots are measured |
| 7 | `v2-chapter-one-release-hardening.md` | All playable content is integrated |

Future plan filenames receive the actual creation date prefix when written. They are not written now because M1 is expected to change the interfaces that those plans must consume.

## 2. Dependency Graph

```text
Stage 0: dirty-baseline audit + authority alignment
  -> Stage 1: input/camera/affordance/tutorial/enemy vertical slice
  -> Stage 2: M1 map, three encounters, art sample, feedback, package, human gate
     -> Stage 3A: reusable encounter/module/content contracts
        -> Stage 3B: M2 + M3 + O1 + O2
           -> Stage 4: M4 + M5 + O3 + O4
              -> Stage 5: M6 boss + ending
                 -> Stage 6: remaining production art/audio and presentation polish
                    -> Stage 7: full chapter release hardening
```

No downstream stage may compensate for a failed upstream gate by adding content, health, damage, tutorials, or map size.

## 3. Stage Portfolio

### Stage 0: Baseline And Authority

**Deliverables**

- Audit every currently modified V2 file and group it into camera/input, task guidance, movement/occupancy, combat/death, or unrelated work.
- Run focused tests for each group and create coherent baseline commits without mixing groups.
- Reconcile `V2_MASTER_SPEC.md`, README links, document index, and roadmap links with the approved production design.
- Add supersession notices to historical expansion documents without deleting historical evidence.
- Capture the baseline full V2 gate, warning count, Windows package identity, and current M1 screenshots.

**Exit gate**

- No unclassified dirty V2 changes remain.
- Every retained change has a passing focused test or an explicitly documented failing baseline.
- One authority chain is visible from the repository README/document index.
- V1/V2 isolation probe passes.

### Stage 1: M1 Core Fun Vertical Slice

**Deliverables**

- Direct map actions with no move/attack toolbar mode.
- Left-empty, right, and middle drag pan; WASD pan; wheel zoom; `F` focus; reliable facility-view return.
- Progressive movement/path/attack previews without full-board red overlays.
- Non-modal three-turn safe tutorial.
- Distinct sentry, drone, and shield-guard plans and visible intent language.
- Immediate deterministic attack feedback and reliable downed-unit cleanup.

**Exit gate**

- Focused input, camera, action, occupancy, intent, damage, tutorial, and player-turn tests pass.
- A scripted M1 opening uses only public input/action APIs.
- Project owner can complete the opening without external instructions and confirms that each of the first three turns has a clear decision.

### Stage 2: M1 Production Mission

**Deliverables**

- Three encounters and 7-8 enemies on a re-authored Echo Yard map.
- Physical maintenance and cargo routes; no route-choice modal.
- Rescue and two-unit evacuation climax.
- Short optional incident-record branch.
- Formal five-unit art sample, combat VFX sample, UI cleanup, audio sample, checkpoints, results, playtest telemetry, and Windows package.

**Exit gate**

- Story and standard difficulty M1 run from new save to base return.
- M1 target time is 12-18 minutes without empty travel or inflated enemy HP.
- Actual-scale, 75%-zoom, grayscale, and color-assist distinction checks pass for assault, scout, sentry, drone, and shield guard.
- Single-owner M1 acceptance record is signed.
- Full V2 gate, Windows package verification, and V1/V2 isolation pass.

### Stage 3A: Shared Content Pipeline

**Deliverables**

- Encounter-definition validator requiring goal, enemy relationships, environmental affordance, two expected solutions, reveal beat, failure pressure, checkpoint state, and asset/test references.
- Character module data and one-slot loadout persistence.
- Per-enemy strategy registry with shared legality and safe fallback validation.
- Mission challenge records, optional-operation unlocks, and data-driven briefing summaries.
- Visual snapshot registration and public-flow test scaffolds generated from mission IDs.

**Exit gate**

- A content-only agent can add a validated graybox encounter without editing battle controllers.
- Invalid encounter relationships, missing stable IDs, impossible objectives, and absent fallback actions fail at load/test time.
- Save migration and V1 rejection tests pass.

### Stage 3B: M2, M3, O1, O2

**Deliverables**

- M2: sniper rays, power state, doors, sniper rescue.
- M3: shield relationships, rail hazard, squad selection, heavy rescue.
- O1: drone scan and low-alert information mission.
- O2: power, doors, and telegraphed hazard mission.
- Sniper and heavy runtime art samples, relevant environment states, audio, VFX, progression, checkpoint, and package flows.

**Exit gate**

- Three characters and four common enemy classes form at least two accepted solutions in each non-tutorial encounter.
- Story/standard complete flows pass for M2 and M3.
- O1/O2 unlock and module rewards write once and survive reload.
- First three main missions run consecutively from a clean save.

### Stage 4: M4, M5, O3, O4

**Deliverables**

- M4: protocol engineer, prison doors, key objective, technician optional objective.
- M5: hunter tracking, tracking array, reinforcement-beacon option, reverse hunt climax.
- O3: shield/door/protection-target operation.
- O4: hunter bait and regroup operation.
- Four-character squad choice and all eight modules.

**Exit gate**

- Every legal three-character squad can complete M4 and M5.
- No single character is required to submit a main objective.
- Engineer and hunter intents are distinguishable by plan, icon, silhouette, and audio.
- Clean-save progression through M5 plus all unlocked operations passes.

### Stage 5: M6 Boss And Ending

**Deliverables**

- Outer-terminal recap encounter.
- Data Sentinel shield phase with two public terminals.
- Core phase with three deterministic, fully telegraphed area patterns.
- Core archive optional result, ending text, chapter summary, rewards, base/menu return.
- Boss art, phase transition, VFX, music, audio, checkpoint, retry, and result handling.

**Exit gate**

- Boss cannot produce untelegraphed fatal damage.
- Both phases restore exactly from checkpoints.
- Main and archive-preserving endings persist and display correctly.
- New-save six-mission scripted public flow reaches a valid ending.

### Stage 6: Full Production Art And Audio

**Deliverables**

- 48 four-direction runtime unit images specified by the production design.
- Six to eight portraits, intent/ability icons, environment state images, VFX, four music themes, four ambience sets, and formal UI/combat audio.
- Import presets, runtime slot metadata, asset ledger, license evidence, and actual-scene screenshots.
- Removal of placeholder, duplicate, temporary, debug, and unused generated assets from the V2 release set.

**Exit gate**

- Every runtime asset slot resolves to a production asset.
- Grayscale and color-assist visual matrices pass.
- Audio buses, settings persistence, reduced-motion behavior, and key threat cues pass.
- The asset ledger covers every external or generated release asset.

### Stage 7: Release Hardening

**Deliverables**

- Complete automated contract, public-flow, visual, audio, performance, long-session, save-recovery, package, and isolation gates.
- Single-owner full chapter test from clean Windows package.
- Settings, save/continue, fail/retry, victory, ending, return, and exit verification.
- Release notes, known-risk record, credits/licenses, build instructions, tagged release candidate, and clean distributable archive.

**Exit gate**

- All production-design release conditions pass.
- Known warnings are either fixed or individually risk-assessed; no warning is silently ignored.
- The project owner can install/launch without Godot, finish Chapter One, save/continue, see an ending, and exit normally.

## 4. Work Classification By Model And Tool

### Sol xhigh

Use for changes where a mistake can corrupt architecture, state, or full-flow behavior:

- Dirty-baseline classification and integration decisions.
- Shared-controller boundary extraction.
- Input transaction and action-resolution architecture.
- Enemy strategy/fallback architecture.
- Checkpoint/save migration.
- Multi-mission progression and Boss state machine.
- Full-gate failure diagnosis, performance, long-session, and release integration.
- Final balance review after telemetry exists.

### Terra high or xhigh

Use for bounded implementation with explicit interfaces and focused tests:

- Individual GDScript services and presenters.
- HUD and tutorial presentation.
- Locked-map JSON and mission data.
- One enemy strategy after the strategy interface is fixed.
- One mission or optional operation after the content pipeline is fixed.
- Focused Godot tests, visual snapshot scenes, settings, and documentation wiring.

Use `xhigh` when the task crosses runtime, scene, save, and tests; use `high` when files and interfaces are already fixed.

### Luna high

Use only for repetitive, contract-driven work that is independently reviewable:

- Asset catalog entries and import metadata after slots are approved.
- Repeated visual-matrix registration.
- JSON schema-conformant content population.
- Asset ledger and license-table maintenance.
- Mechanical documentation/index cleanup.

Do not use Luna as the sole owner of combat rules, pathfinding, saves, enemy strategy architecture, or release diagnosis.

### ImageGen

Use for raster production only after a measured runtime slot and approved art brief exist:

- Four-direction unit art and portraits.
- Environment landmarks and facility states.
- Ability/intent icons when existing licensed assets do not fit.
- VFX source plates and background illustrations.

Every ImageGen task must be followed by deterministic processing, alpha inspection, crop/scale validation, Godot import, actual-scene screenshots, and a visual acceptance record. Generation alone is not delivery.

### Deterministic image/audio processing

Use bundled/local tools for:

- Alpha cleanup, padding, crop, canvas normalization, file naming, contact sheets, and duplicate detection.
- Loudness normalization, trimming, loop checks, channel/sample-rate conversion, and silence detection.

### Project owner only

- Subjective fun approval.
- Whether interaction feels clear and responsive.
- Actual-scale character/enemy recognition approval.
- Story/standard mission playthroughs.
- Final release-candidate acceptance.

AI may prepare the package, telemetry, checklist, and replay evidence but cannot claim the human gate passed.

## 5. Commit And Branch Discipline

- Continue on `codex/ch1-infiltration-v2`; do not create a new worktree for each task unless a task is explicitly delegated with an isolated write set.
- Each task commit contains one testable responsibility.
- Data, runtime behavior, tests, and documentation required by one behavior may share its commit.
- Art source generation, deterministic processing, runtime integration, and visual acceptance use separate commits when review can reject them independently.
- Never stage unrelated dirty files with `git add -A`.
- Every task's final status must list exact files, focused test result, full relevant gate result, residual warnings, and commit hash.

## 6. Required Evidence Per Deliverable

| Deliverable | Minimum evidence |
|---|---|
| Input/camera | Synthetic event tests plus real-scene input test |
| Combat rule | Unit test plus player-turn scene test |
| Enemy strategy | Plan contract, executor test, and visible intent snapshot |
| Mission/encounter | Schema validation, public-flow route, checkpoint retry, and screenshots |
| Art | Source record, processed runtime file, import check, contact sheet, actual-scene screenshot |
| Audio | Source/license record, technical validation, in-scene playback, settings/mute test |
| Save/progression | Fresh save, migration, rejection, reload, and duplicate-reward tests |
| Release | Gate log, package verifier, cold start, full flow, and isolation report |

## 7. Roadmap Change Control

The following require product-owner approval before implementation:

- Returning to real-time or 3D.
- Adding a fifth Chapter One character.
- Adding AP, random hit chance, inventory, skill tree, or store economy.
- Removing any of the six main missions or the Boss ending.
- Replacing single-owner human acceptance with AI-only acceptance.
- Merging V1 and V2 saves, boot scenes, or release products.

Balance values, exact map coordinates, UI spacing, animation timing, color values, and implementation file splits may change without additional approval when tests and the current stage exit gate remain satisfied.
