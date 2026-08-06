# V2 Resource Manifest

This baseline records the authored data sources introduced by F03. No external art, audio, font, or third-party file is introduced by this task.

| Resource | Kind | Source | License | Runtime path |
|---|---|---|---|---|
| `characters.json` | V2 gameplay data | project-authored JSON | project-owned | `res://data/v2/characters.json` |
| `enemies.json` | V2 gameplay data | project-authored JSON | project-owned | `res://data/v2/enemies.json` |
| `abilities.json` | V2 gameplay data | project-authored JSON | project-owned | `res://data/v2/abilities.json` |
| `modules.json` | V2 progression data | project-authored JSON | project-owned | `res://data/v2/modules.json` |
| `missions.json` | V2 mission data | project-authored JSON | project-owned | `res://data/v2/missions.json` |
| `dialogues.json` | V2 dialogue references | project-authored JSON | project-owned | `res://data/v2/dialogues.json` |

## M1 Runtime Art

| Resource | Kind | Source | License | Runtime path |
|---|---|---|---|---|
| Echo Yard floor/edge/prop/decal/landmark set | environment art | existing project-generated Chapter 1 art, deterministic variant selection | project-owned generated art; no third-party content | `res://assets/generated/chapter1/runtime/environment/echo_yard/` |
| Assault/scout/sentry/drone runtime units | unit art | existing project-generated Chapter 1 art | project-owned generated art; no third-party content | `res://assets/generated/chapter1/runtime/units/` |
| Camera/terminal/evacuation objective icons | objective art | existing project-generated Chapter 1 art | project-owned generated art; no third-party content | `res://assets/generated/chapter1/runtime/network_icons/`, `res://assets/generated/chapter1/runtime/objectives/` |
| Rescue beacon capsule | objective art | OpenAI image generation; post-processed to true alpha and resized to 128x128 by project tooling on 2026-08-06 | project-owned generated art; no third-party content | `res://assets/generated/chapter1/runtime/objectives/rescue_beacon_128.png` |

Processing record for `rescue_beacon_128.png`: source image was generated as a single cyber-industrial rescue capsule, edge-connected white background was removed with a flood-fill alpha pass, the visible object was tightly cropped, and the result was downsampled to 128x128 RGBA PNG. The original generated source remains outside the repository in the Codex generated-image cache.
