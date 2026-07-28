# Resource Manifest

This manifest covers resources intentionally included in the current playable
slice. A resource without a documented source and license must not enter a
release build.

| Path | Source | License | Created | Game use | Import / validation |
| --- | --- | --- | --- | --- | --- |
| `assets/audio/bgm/*.wav` | Original procedural PCM synthesis by `tools/generate_chapter1_audio.ps1` | CC0 1.0 | 2026-07-28 | Menu, battle, boss, base, victory and defeat music | Godot WAV import; loaded in smoke test |
| `assets/audio/sfx/*.wav` | Original procedural PCM synthesis by `tools/generate_chapter1_audio.ps1` | CC0 1.0 | 2026-07-28 | UI, movement, combat, skill, item, turn and outcome feedback | Godot WAV import; loaded in smoke test |
| `assets/generated/chapter1/backgrounds/main_menu_data_district_v1.png` | Original AI image generated in Codex built-in Image Generation tool | Project-controlled original asset; no third-party source | 2026-07-28 | Main-menu background | 16:9 raster; visual inspection for no text/watermark; imported by Godot and referenced by `scenes/main_menu.tscn` |
| `default_bus_layout.tres` | Project-authored Godot configuration | Project source license | 2026-07-28 | Master, Music and SFX routing | Loaded at boot; bus contract smoke test |

## Excluded Reference Files

The legacy PNG files in `assets/characters/`, `assets/effects/`,
`assets/tiles/`, and `assets/ui/` are **reference only**. They have no runtime
references and are excluded from the Windows export because their documented
watermarks and missing provenance make them unsuitable for distribution. They
must be replaced by independently generated or clearly licensed production art
before any release that needs character or tile artwork.
