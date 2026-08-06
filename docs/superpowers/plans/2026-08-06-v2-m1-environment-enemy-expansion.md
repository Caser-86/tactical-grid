# V2 M1 Environment and Enemy Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make V2 M1 visually varied and tactically readable by reusing the existing V1-generated environment kits and introducing three additional enemy roles without increasing simultaneous enemies beyond three.

**Architecture:** Keep V1 untouched. V2 map rendering will select an environment kit per cell from deterministic rectangular overrides and render explicit prop placements from the existing generated runtime assets. V2 M1 will expand from six to nine stable enemy entities, while `V2EnemyBrain` already provides the role behaviors for sniper sentry, shield guard, and protocol engineer.

**Tech Stack:** Godot 4.7.1, GDScript, locked V2 JSON data, existing transparent PNG runtime art, PowerShell/Godot release gate.

## Global Constraints

- V1 files, V1 save data, and V1 map rules must not change behavior.
- V2 M1 simultaneous active enemies remain capped at 3.
- New enemy entities use stable IDs and deterministic encounter activation.
- Reuse project-owned generated art before generating new images.
- Every new or reused runtime dependency must be recorded in `resource_manifest.md`.
- Verify at 1280x720 and 1920x1080 through the M1 visual matrix.

---

### Task 1: Add failing expansion contracts

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_m1_expansion_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_map_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_art_baseline_test.gd`

**Interfaces:**
- Consumes: `V2Data.get_enemy`, `ArtCatalog.get_environment_component_paths`, and `MapLoader.load_locked_map`.
- Produces: assertions for five enemy roles, three environment kits, nine stable enemy entities, and active-cap compliance.

- [x] **Step 1: Add failing assertions** for `sniper_sentry`, `shield_guard`, and `protocol_engineer` data plus their art keys.
- [x] **Step 2: Add failing assertions** that M1 contains 9 enemy IDs and never activates more than 3 in any schedule or encounter.
- [x] **Step 3: Add failing assertions** that `cooling_works`, `transit_hub`, and `sentinel_core` have complete floor/edge/prop/decal/landmark runtime sets.
- [x] **Step 4: Run the focused test** and record the expected failures before changing data.

### Task 2: Recompose M1 with reused environment kits and props

**Files:**
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m1.json`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/assets/v2/README.md`

**Interfaces:**
- Consumes: `environment.kit`, `environment.decorations`, `ArtCatalog.get_environment_component_texture`, and `_draw_tactical_tile`.
- Produces: `_get_environment_kit_for_cell(cell, default_kit) -> String` and deterministic multi-kit M1 rendering with explicit prop placements.

- [x] **Step 1: Add `kit_overrides` and 15 fixed prop/decal placements** to the locked M1 map without changing blockers, routes, or objective coordinates.
- [x] **Step 2: Implement `_get_environment_kit_for_cell`** using rectangle records `{x, y, width, height, kit}` and defaulting to `echo_yard`.
- [x] **Step 3: Render each tile with its selected kit** and allow each decoration to specify an optional kit and scale, defaulting to the map kit and `1.0`.
- [x] **Step 4: Run the map and art tests** and confirm all component textures load from `res://assets/generated/chapter1/runtime/`.
- [x] **Step 5: Run the visual matrix** and inspect start, selected, rescue, and evac screenshots for prop overlap with units, objectives, and HUD.

### Task 3: Activate additional enemy models and roles

**Files:**
- Modify: `tactical-grid/client/scripts/data/art_catalog.gd`
- Modify: `tactical-grid/client/data/v2/enemies.json`
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m1.json`
- Modify: `tactical-grid/client/scripts/v2/ai/v2_enemy_brain.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_enemy_activation_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_enemy_intent_contract_test.gd`

**Interfaces:**
- Consumes: existing `sentry_sniper_96.png`, `shield_bot_64.png`, and `protocol_engineer_96.png` assets plus existing V2 intent types `telegraph`, `protect`, and `operate`.
- Produces: stable M1 entities `enemy_sniper_east`, `enemy_shield_rescue`, and `enemy_engineer_record` with distinct art and deterministic stage activation.

- [x] **Step 1: Add stable art aliases** for `sniper_sentry` and `shield_guard` so their runtime job IDs resolve to distinct textures.
- [x] **Step 2: Add the three new enemy entities** and assign them to rescue, record, and pre-evac schedules while keeping every active count at or below 3.
- [x] **Step 3: Make the V2 brain explicitly classify the three roles** with the existing telegraph/protect/operate intent contracts and safe movement fallback.
- [x] **Step 4: Run enemy activation and intent tests** and require deterministic output over repeated calls.
- [x] **Step 5: Run the player-turn E2E** and confirm the additional unit textures render only when their encounter activates.

### Task 4: Balance, documentation, and release verification

**Files:**
- Modify: `tactical-grid/client/data/v2/missions.json`
- Modify: `tactical-grid/client/data/v2/README.md`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `docs/v2/V2_MASTER_SPEC.md`
- Modify: `docs/superpowers/plans/2026-08-06-v2-m1-environment-enemy-expansion.md`

**Interfaces:**
- Consumes: the expanded map and enemy contracts from Tasks 1-3.
- Produces: updated M1 content counts, documented art provenance, and release evidence.

- [x] **Step 1: Update M1 content counts and role descriptions** without changing the 12-18 minute target or 3-enemy active cap.
- [x] **Step 2: Document reused V1-generated source sheets and runtime kits** with project-owned provenance.
- [x] **Step 3: Run `git diff --check`, focused expansion tests, and the full `tests/v2/run_v2_gate.ps1` gate.**
- [x] **Step 4: Review the 42-snapshot matrix** for clipping, hidden objective markers, indistinguishable enemies, and unreadable props.
- [ ] **Step 5: Commit** with `art(v2): expand M1 environment and enemy variety`.
