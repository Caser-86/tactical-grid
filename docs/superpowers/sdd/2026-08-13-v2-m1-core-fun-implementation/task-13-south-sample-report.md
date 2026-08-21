# Task 13 M1 Directional Art Report

Date: 2026-08-15
Branch: `codex/ch1-infiltration-v2`
Status: four-direction integration passed; Task 13 is ready for independent commit review.

## Scope

This task produces and integrates four authored direction views for five V2 unit identities:

- `v2_assault`
- `v2_scout`
- `v2_sentry`
- `v2_drone`
- `v2_shield_guard`

The work is V2-only. Existing V1 assets, directionless V2 fallback assets, and V1 entry points were not overwritten.

## Source And Processing

- Source method: AI-generated with OpenAI ImageGen.
- Source record: `tactical-grid/client/assets/v2/source/units/m1_identity_art_brief.json`.
- Source images: one isolated subject per direction (`north`, `east`, `south`, `west`) under `tactical-grid/client/assets/v2/source/units/player/` and `tactical-grid/client/assets/v2/source/units/enemy/`.
- Processing tool: `tactical-grid/client/tools/process_v2_unit_art.ps1`.
- Processing: true-alpha detection, edge-connected near-black/near-white background cleanup for opaque generator output, transparent-bound crop with padding, bicubic scale into a 112px subject box, and placement on a 128x128 RGBA canvas with a shared bottom anchor.
- License status: project-owned generated source; no external asset license is required.

## Runtime Integration

The twenty runtime files are registered as V2 catalog keys and resolved by `UnitSprite` only when a V2 unit provides `v2_art_key`. Movement and attack vectors select `north`, `east`, `south`, or `west`; a missing directional frame falls back to the approved south frame and then the existing directionless V2 key. V1 units keep the existing directionless path.

The direction snapshot renders all five identities on the existing Echo Yard floor at runtime scale. The visual check confirms the silhouettes remain identifiable without relying on text badges:

- Assault: compact rifle, forward stance, cyan forearm plates.
- Scout: lower profile, asymmetric antenna pack, lime panels.
- Sentry: upright red-black body, long rifle, red shoulder plates.
- Drone: wide disk/wing silhouette, cyan scan lens, warning lights.
- Shield guard: broad grounded body and dominant orange hexagonal shield.

The Windows render is stored at `tactical-grid/client/assets/v2/source/units/m1_identity_direction_contact_sheet.png`. The previously approved south-facing sample remains at `m1_identity_contact_sheet.png` and is not overwritten.

## Verification Evidence

Focused unit-art and direction-selection test:

```text
v2_unit_art_distinction_test.gd
Passed: 184
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

## Completion Boundary

Task 13 covers the five-unit four-direction art sample only. It does not claim that the full M1 art pass, audio pass, or release package is complete. The next gates are the M1 visual matrix, player-turn regression, full V2 gate, audio/feedback sample, and Windows release validation.
