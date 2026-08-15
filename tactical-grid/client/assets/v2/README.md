# V2 资源目录

V2 新增或复制后的资源放在本目录及其子目录中。资源必须在 V2 资源清单中记录来源、许可证、尺寸、导入设置和游戏内用途。

禁止从 V2 运行时通过相对路径读取 V1 worktree 的资源。

M1 美术整合约束：运行时角色、目标图标和 Echo Yard 环境组件统一由 `ArtCatalog` 查找，资源实际文件位于 `assets/generated/chapter1/runtime`。新增图像必须使用真实透明背景，标注处理尺寸，并在 `data/v2/resource_manifest.md` 登记来源和许可证结论。

M1 额外复用 `echo_yard`、`cooling_works`、`transit_hub` 和 `sentinel_core` 四套项目自有生成式环境套件。锁定地图通过确定性矩形选择地面套件，并逐个放置已处理的道具和贴花；源图集和风格板不直接渲染进战斗地图。

V2 角色图使用专属 `v2_*` 视觉键，不覆盖 V1 的同名角色键。玩家和敌人各有四张 128×128 RGBA token 图，按大色块、轮廓和装备特征设计，保证缩小到约 76 像素时仍可区分；原始生成板保存在 `assets/v2/source/`，运行时只加载裁切后的 PNG。

## M1 角色身份样本

`source/units/player/` 和 `source/units/enemy/` 保存五个南向样本的原始透明 PNG；`m1_identity_art_brief.json` 记录身份、镜头、锚点、配色和处理约束。`tools/process_v2_unit_art.ps1` 会把源图裁切为统一的 `128x128` RGBA 运行时图，并写入 `assets/v2/units/`。本轮只增加南向键：`v2_assault_south`、`v2_scout_south`、`v2_sentry_south`、`v2_drone_south`、`v2_shield_guard_south`；其余方向继续使用旧的方向无关 V2 资源，避免未经验收的方向帧进入游戏。

`m1_identity_contact_sheet.png` 是基于真实 Echo Yard 地面和真实运行时 PNG 的验收快照，不是游戏运行时资源。快照同时检查实际运行尺寸、75% 尺寸、灰度和色彩辅助状态。
