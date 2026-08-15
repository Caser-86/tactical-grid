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

## M1 环境和敌人扩展

| Resource | Kind | Source | License | Runtime path |
|---|---|---|---|---|
| Echo Yard、Cooling Works、Transit Hub、Sentinel Core 环境套件 | environment art | 现有项目自有的第一章生成式运行时资源，复用自 V1 美术生产阶段并复制到隔离的 V2 项目 | project-owned generated art; no third-party content | `res://assets/generated/chapter1/runtime/environment/{echo_yard,cooling_works,transit_hub,sentinel_core}/` |
| M1 道具和贴花摆放 | composition data | 使用上述运行时套件的项目自有确定性地图数据 | project-owned data | `res://data/v2/locked_maps/ch1_m1.json` |
| 狙击哨兵和盾卫角色图 | enemy art | 现有项目自有的第一章生成式运行时单位图，通过 V2 职责 ID 映射 | project-owned generated art; no third-party content | `res://assets/generated/chapter1/runtime/units/sentry_sniper_96.png`, `res://assets/generated/chapter1/runtime/units/shield_bot_64.png` |
| V2 玩家 token 图集和四张运行时角色图 | player art | 2026-08-06 使用 OpenAI image generation 生成；项目裁切、连通背景移除并处理为 128x128 RGBA PNG | project-owned generated art; no third-party content | `res://assets/v2/source/v2_player_token_sheet_2026-08-06.png`, `res://assets/v2/units/v2_{assault,scout,sniper,heavy}_128.png` |
| V2 敌方 token 图集和四张运行时角色图 | enemy art | 2026-08-06 使用 OpenAI image generation 生成；项目裁切、连通背景移除并处理为 128x128 RGBA PNG | project-owned generated art; no third-party content | `res://assets/v2/source/v2_enemy_token_sheet_2026-08-06.png`, `res://assets/v2/units/v2_{sentry,drone,shield_guard,sniper_sentry}_128.png` |
| M1 五类四方向角色身份样本源图 | player/enemy art source | 2026-08-15 使用 OpenAI ImageGen 按 `res://assets/v2/source/units/m1_identity_art_brief.json` 分别生成 20 张单角色方向 PNG；无外部素材 | project-owned generated art; no third-party content | `res://assets/v2/source/units/player/`, `res://assets/v2/source/units/enemy/` |
| M1 五类四方向运行时角色图 | player/enemy art | 2026-08-15 使用 `tools/process_v2_unit_art.ps1` 识别真实 alpha，对边缘连通近黑/近白背景做确定性提取，裁切透明边界、缩放至 112px 主体框并放置到 128x128 透明画布，底部统一保留 6px 锚点边距 | project-owned generated art; no third-party content | `res://assets/v2/units/v2_{assault,scout,sentry,drone,shield_guard}_{north,east,south,west}_128.png` |
| M1 四方向角色身份验收图 | review artifact | 2026-08-15 使用 Godot `v2_unit_art_direction_snapshot.tscn`，复用真实 Echo Yard 地面和上述运行时图生成；仅用于验收，不在战斗运行时加载 | project-owned generated art composition; no third-party content | `res://assets/v2/source/units/m1_identity_direction_contact_sheet.png` |
| M1 南向角色身份样本验收图 | review artifact | 2026-08-15 使用 Godot `v2_unit_art_sample_snapshot.tscn`，复用真实 Echo Yard 地面和上述运行时图生成；仅用于验收，不在战斗运行时加载 | project-owned generated art composition; no third-party content | `res://assets/v2/source/units/m1_identity_contact_sheet.png` |

V1 源图集仍仅作为制作参考。V2 战斗场景不直接叠加整张 source/styleboard，而是使用已处理的运行时组件，以保持格子尺寸、透明度、迷雾和层级顺序可验证。

处理记录：20 张方向源图均为单角色 PNG，不使用源图集或外部下载素材。处理脚本对已有 alpha 的图像保留主体透明度；对生成器烘入的近黑/近白背景，只处理边缘连通区域，避免按颜色全图抠除装甲高光。随后使用高质量双三次缩放，不改变主体颜色；四角透明度、128x128 尺寸、运行时方向选帧和可见主体边界由 `v2_unit_art_distinction_test.gd` 检查。

Processing record for `rescue_beacon_128.png`: source image was generated as a single cyber-industrial rescue capsule, edge-connected white background was removed with a flood-fill alpha pass, the visible object was tightly cropped, and the result was downsampled to 128x128 RGBA PNG. The original generated source remains outside the repository in the Codex generated-image cache.
