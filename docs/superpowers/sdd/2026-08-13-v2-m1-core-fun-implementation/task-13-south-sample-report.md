# Task 13 South-Facing Art Sample Report

Date: 2026-08-15
Branch: `codex/ch1-infiltration-v2`
Status: south-facing sample checkpoint passed; four-direction integration remains pending.

## Scope

This checkpoint produces and integrates one south-facing runtime sample for five V2 unit identities:

- `v2_assault`
- `v2_scout`
- `v2_sentry`
- `v2_drone`
- `v2_shield_guard`

The work is V2-only. Existing V1 assets, directionless V2 fallback assets, and V1 entry points were not overwritten.

## Source And Processing

- Source method: AI-generated with OpenAI ImageGen.
- Source record: `tactical-grid/client/assets/v2/source/units/m1_identity_art_brief.json`.
- Source images: one isolated south-facing subject per PNG under `tactical-grid/client/assets/v2/source/units/player/` and `tactical-grid/client/assets/v2/source/units/enemy/`.
- Processing tool: `tactical-grid/client/tools/process_v2_unit_art.ps1`.
- Processing: edge-connected alpha cleanup, transparent-bound crop with padding, bicubic scale into a 112px subject box, and placement on a 128x128 RGBA canvas with a shared bottom anchor.
- License status: project-owned generated source; no external asset license is required.

## Runtime Integration

The five runtime files are registered as V2 catalog keys and resolved by `UnitSprite` only when a V2 unit provides `v2_art_key`. V1 units keep the existing directionless path.

The sample snapshot renders all five units on the existing Echo Yard floor at 100%, 75%, grayscale, and color-assist presentations. The visual check confirms the silhouettes remain identifiable without relying on text badges:

- Assault: compact rifle, forward stance, cyan forearm plates.
- Scout: lower profile, asymmetric antenna pack, lime panels.
- Sentry: upright red-black body, long rifle, red shoulder plates.
- Drone: wide disk/wing silhouette, cyan scan lens, warning lights.
- Shield guard: broad grounded body and dominant orange hexagonal shield.

## Verification Evidence

Focused unit-art test:

```text
v2_unit_art_distinction_test.gd
Passed: 69
Failed: 0
```

Player-turn regression after updating the approved south-facing texture assertion:

```text
v2_player_turn_e2e_test.tscn
Passed: 78
Failed: 0
```

Full V2 release gate after the correction:

```text
Items: 82; Passed items: 82; Failed items: 0
Assertions: 81 result lines; Passed: 1912; Failed: 0
M1 visual matrix: 36/36
M2 visual matrix: 54/54
isolated M1 E2E: 68/0
V2 RELEASE GATE PASSED
```

Godot still reports non-fatal teardown diagnostics about leaked RIDs, ObjectDB instances, and resources in some isolated test processes. They do not produce a failed test item in this gate and remain a later test-harness cleanup task.

## Remaining Work

This is deliberately not the completion of Task 13. The following remain pending:

1. Generate north, east, and west views for the five approved identities.
2. Preserve each identity's equipment, color blocks, asymmetric details, lighting, and anchor across directions.
3. Extend the catalog, runtime selection, image checks, and snapshot coverage to all four directions.
4. Re-run the M1 visual matrix after direction integration.
5. Commit the four-direction integration separately from this south-facing sample checkpoint.
