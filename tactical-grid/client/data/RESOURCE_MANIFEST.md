# Resource Manifest

This manifest covers resources intentionally included in the current playable
slice. A resource without a documented source and license must not enter a
release build.

| Path | Source | License | Created | Game use | Import / validation |
| --- | --- | --- | --- | --- | --- |
| `assets/audio/bgm/*.wav` | Original procedural PCM synthesis by `tools/generate_chapter1_audio.ps1` | CC0 1.0 | 2026-07-28 | Menu, battle, boss, base, victory and defeat music | Godot WAV import; loaded in smoke test |
| `assets/audio/sfx/*.wav` | Original procedural PCM synthesis by `tools/generate_chapter1_audio.ps1` | CC0 1.0 | 2026-07-28 | UI, movement, combat, skill, item, turn and outcome feedback | Godot WAV import; loaded in smoke test |
| `assets/generated/chapter1/backgrounds/main_menu_data_district_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-28 | Main-menu background | 16:9 raster; visual inspection for no text/watermark; imported by Godot and referenced by `scenes/main_menu.tscn` |
| `assets/generated/chapter1/backgrounds/base_echo_command_room_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-29 | Base background | Imported by Godot; smoke-tested as `Texture2D` |
| `assets/generated/chapter1/backgrounds/boot_command_network_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-29 | Boot background | Imported by Godot; smoke-tested as `Texture2D` |
| `assets/generated/chapter1/backgrounds/mission_debrief_data_city_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-29 | Mission result background | Imported by Godot; smoke-tested as `Texture2D` |
| `assets/generated/chapter1/runtime/` except `environment/echo_yard/prop/` and `environment/echo_yard/landmark/` | Original procedural raster generation by project tooling | CC0 1.0 | 2026-07-29 | Runtime units, terrain, icons, effects, objectives and procedural environment components | Catalog completeness and Godot load checks in smoke test |
| `assets/generated/chapter1/runtime/environment/echo_yard/prop/*.png` | Original AI images generated with the Codex built-in Image Generation tool, then chroma-key removal and deterministic 3 x 2 slicing by `tools/process_echo_yard_prop_sheet.ps1` | Project-controlled original asset; no third-party source | 2026-07-30 | Six Echo Freight Yard cover/prop variants | Transparent PNG; imported by Godot; loaded through `ArtCatalog`; verified in the exported Windows battle scene |
| `assets/generated/chapter1/runtime/environment/echo_yard/landmark/*.png` | Original AI images generated with the Codex built-in Image Generation tool, then chroma-key removal and manual-safe slicing by `tools/process_echo_yard_landmark_sheet.ps1` | Project-controlled original asset; no third-party source | 2026-07-30 | Gantry crane and floodlight tower landmarks | Transparent PNG; imported by Godot; loaded through `ArtCatalog`; verified in the exported Windows battle scene |
| `assets/generated/chapter1/source/echo_yard_*.png` | Original AI style board and generation sheets from the Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-30 | Internal environment direction and reproducible processing source | Reference/source only; excluded from Windows export by `export_presets.cfg` |
| `assets/generated/chapter1/runtime/environment/cooling_works/*.png` | Original procedural raster generation by `tools/generate_cooling_works_environment.ps1`; no third-party textures, samples, fonts, or source art | CC0 1.0 | 2026-07-30 | Cooling Works floors, edges, cover props, hazard decals and landmarks for `ch1_m2` | 27 PNG files; imported by Godot; catalog, map and resource loading contracts pass in the battle smoke test |
| `assets/generated/chapter1/runtime/environment/transit_hub/*.png` | Original procedural raster generation by `tools/generate_transit_hub_environment.ps1`; no third-party textures, samples, fonts, or source art | CC0 1.0 | 2026-07-30 | Mag-Rail Transit Hub floors, platform cover, decals and landmarks for `ch1_m3` and `ch1_m4` | 27 PNG files; imported by Godot; catalog, map and resource loading contracts pass in the battle smoke test |
| `assets/generated/chapter1/runtime/environment/sentinel_core/*.png` | Original procedural raster generation by `tools/generate_sentinel_core_environment.ps1`; no third-party textures, samples, fonts, or source art | CC0 1.0 | 2026-07-30 | Sentinel Core floors, phase cover, circuit decals and landmarks for `ch1_m5` and `ch1_m6` | 27 PNG files; imported by Godot; catalog, map and resource loading contracts pass in the battle smoke test |
| `default_bus_layout.tres` | Project-authored Godot configuration | Project source license | 2026-07-28 | Master, Music and SFX routing | Loaded at boot; bus contract smoke test |

## Excluded Reference Files

The legacy PNG files in `assets/characters/`, `assets/effects/`,
`assets/tiles/`, and `assets/ui/` are **reference only**. They have no runtime
references and are excluded from the Windows export because their documented
watermarks and missing provenance make them unsuitable for distribution. They
must be replaced by independently generated or clearly licensed production art
before any release that needs character or tile artwork.
