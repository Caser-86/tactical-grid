# Resource Manifest

> status: Pre-redesign runtime asset baseline
> owner: 项目负责人
> updated: 2026-07-31
> applies_to: 当前客户端运行时资源与来源追溯

This manifest covers resources intentionally included in the current playable
baseline. It does not certify that those resources meet the approved tactical-network
redesign or final release quality. A resource without a documented source and license
must not enter a release build.

| Path | Source | License | Created | Game use | Import / validation |
| --- | --- | --- | --- | --- | --- |
| `assets/audio/bgm/*.wav` | Original procedural PCM synthesis by `tools/generate_chapter1_audio.ps1` | CC0 1.0 | 2026-07-28 | Menu, battle, boss, base, victory and defeat music | Godot WAV import; loaded in smoke test |
| `assets/audio/sfx/*.wav` | Original procedural PCM synthesis by `tools/generate_chapter1_audio.ps1` | CC0 1.0 | 2026-07-28 | UI, movement, combat, skill, item, turn and outcome feedback | Godot WAV import; loaded in smoke test |
| `assets/audio/sfx/sfx_network_scan.wav`, `sfx_network_takeover.wav`, `sfx_network_disable.wav`, `sfx_network_overload.wav`, `sfx_alert_rise.wav`, `sfx_camera_reveal.wav`, `sfx_turret_reversal.wav`, `sfx_beacon_delay.wav` | Original procedural PCM synthesis by `tools/generate_network_audio.ps1` | CC0 1.0 | 2026-07-31 | Network scan, takeover, disable, overload and alert escalation facility feedback | Godot WAV import; polyphonic SFX pool in `audio_manager.gd`; validated by `tools/test_audio_assets.ps1` |
| `assets/generated/chapter1/backgrounds/main_menu_data_district_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-28 | Main-menu background | 16:9 raster; visual inspection for no text/watermark; imported by Godot and referenced by `scenes/main_menu.tscn` |
| `assets/generated/chapter1/backgrounds/base_echo_command_room_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-29 | Base background | Imported by Godot; smoke-tested as `Texture2D` |
| `assets/generated/chapter1/backgrounds/boot_command_network_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-29 | Boot background | Imported by Godot; smoke-tested as `Texture2D` |
| `assets/generated/chapter1/backgrounds/mission_debrief_data_city_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-29 | Mission result background | Imported by Godot; smoke-tested as `Texture2D` |
| `assets/generated/chapter1/runtime/{blockers,effects,hud_icons,icons,objectives,portraits,status_icons,tiles}/` | Original procedural raster generation by project tooling | CC0 1.0 | 2026-07-29 | Blockers, terrain, icons, effects, objectives and first-pass portraits | Godot import and catalog contracts where referenced; individual runtime reachability remains a production audit item |
| `assets/generated/chapter1/runtime/environment/echo_yard/prop/*.png` | Original AI images generated with the Codex built-in Image Generation tool, then chroma-key removal and deterministic 3 x 2 slicing by `tools/process_echo_yard_prop_sheet.ps1` | Project-controlled original asset; no third-party source | 2026-07-30 | Six Echo Freight Yard cover/prop variants | Transparent PNG; imported by Godot; loaded through `ArtCatalog`; verified in the exported Windows battle scene |
| `assets/generated/chapter1/runtime/environment/echo_yard/landmark/*.png` | Original AI images generated with the Codex built-in Image Generation tool, then chroma-key removal and manual-safe slicing by `tools/process_echo_yard_landmark_sheet.ps1` | Project-controlled original asset; no third-party source | 2026-07-30 | Gantry crane and floodlight tower landmarks | Transparent PNG; imported by Godot; loaded through `ArtCatalog`; verified in the exported Windows battle scene |
| `assets/generated/chapter1/source/echo_yard_*.png` | Original AI style board and generation sheets from the Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-30 | Internal environment direction and reproducible processing source | Reference/source only; excluded from Windows export by `export_presets.cfg` |
| `assets/generated/chapter1/runtime/environment/cooling_works/*.png` | Original procedural raster generation by `tools/generate_cooling_works_environment.ps1`; no third-party textures, samples, fonts, or source art | CC0 1.0 | 2026-07-30 | Reusable Cooling Works environment baseline for redesigned M2 | 27 PNG files; imported by Godot; catalog, map and resource loading contracts pass in the old battle smoke test; redesigned map composition still requires validation |
| `assets/generated/chapter1/runtime/environment/transit_hub/*.png` | Original procedural raster generation by `tools/generate_transit_hub_environment.ps1`; no third-party textures, samples, fonts, or source art | CC0 1.0 | 2026-07-30 | Reusable Mag-Rail environment baseline for redesigned M3/M4 | 27 PNG files; imported by Godot; catalog, map and resource loading contracts pass in the old battle smoke test; redesigned map composition still requires validation |
| `assets/generated/chapter1/runtime/environment/sentinel_core/*.png` | Original procedural raster generation by `tools/generate_sentinel_core_environment.ps1`; no third-party textures, samples, fonts, or source art | CC0 1.0 | 2026-07-30 | Reusable Sentinel Core environment baseline for redesigned M5/M6 | 27 PNG files; imported by Godot; catalog, map and resource loading contracts pass in the old battle smoke test; redesigned map composition still requires validation |
| `assets/generated/chapter1/source/ch1_m1_units/*_source_v1.png` | Original AI images generated with the Codex built-in Image Generation tool; flat pure-green chroma background | Project-controlled original asset; no third-party source | 2026-07-30 | Internal unit-art direction and reproducible processing source | Reference/source only; excluded from Windows export by `export_presets.cfg` |
| `assets/generated/chapter1/runtime/units/assault_96.png`, `sniper_96.png`, `heavy_96.png`, `sentry_basic_96.png`, `drone_scout_96.png`, `sentry_sniper_96.png`, `drone_assault_96.png` | Original AI images generated with the Codex built-in Image Generation tool, then green-dominant chroma-key removal, crop, resize and 96x96 compositing by `tools/process_chapter1_unit_art.ps1` | Project-controlled original asset; no third-party source | 2026-07-30 | Seven Chapter 1 unit runtime sprites (assault, sniper, heavy, sentry_basic, drone_scout, sentry_sniper, drone_assault) | Transparent 96x96 PNG; imported by Godot; loaded through `ArtCatalog`; 96x96 size, real alpha, >=0.12 silhouette difference, >=76px render size and no filled token base contracts pass in `unit_animation_contract_test` |
| `default_bus_layout.tres` | Project-authored Godot configuration | Project source license | 2026-07-28 | Master, Music and SFX routing | Loaded at boot; bus contract smoke test |

## Excluded Reference Files

The legacy PNG files in `assets/characters/`, `assets/effects/`,
`assets/tiles/`, and `assets/ui/` are **reference only**. They have no runtime
references and are excluded from the Windows export because their documented
watermarks and missing provenance make them unsuitable for distribution. They
must be replaced by independently generated or clearly licensed production art
before any release that needs character or tile artwork.

## Redesign production note

The following assets are not yet present in this baseline and must receive individual
manifest rows before release: four finalized player silhouettes, protocol engineer,
hunter, network-node states, five facility-state icons, intent/alert feedback, M1-M6
hero landmarks, a Chinese UI font. Network and alert audio is covered by `generate_network_audio.ps1` and the polyphonic SFX pool.
