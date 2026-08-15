# V2 资源目录

V2 新增或复制后的资源放在本目录及其子目录中。资源必须在 V2 资源清单中记录来源、许可证、尺寸、导入设置和游戏内用途。

禁止从 V2 运行时通过相对路径读取 V1 worktree 的资源。

M1 美术整合约束：运行时角色、目标图标和 Echo Yard 环境组件统一由 `ArtCatalog` 查找，资源实际文件位于 `assets/generated/chapter1/runtime`。新增图像必须使用真实透明背景，标注处理尺寸，并在 `data/v2/resource_manifest.md` 登记来源和许可证结论。

M1 额外复用 `echo_yard`、`cooling_works`、`transit_hub` 和 `sentinel_core` 四套项目自有生成式环境套件。锁定地图通过确定性矩形选择地面套件，并逐个放置已处理的道具和贴花；源图集和风格板不直接渲染进战斗地图。

V2 角色图使用专属 `v2_*` 视觉键，不覆盖 V1 的同名角色键。M1 五类身份各有北/东/南/西四张 128×128 RGBA 运行时图，按大色块、轮廓和装备特征设计，保证缩小到约 76 像素时仍可区分；原始生成图保存在 `assets/v2/source/units/`，运行时只加载裁切后的 PNG。`UnitSprite` 仅在单位具有 `v2_art_key` 时按移动或攻击方向选帧，V1 继续使用原来的单图映射。

## M1 角色身份样本

`source/units/player/` 和 `source/units/enemy/` 保存五类身份的四方向源图；`m1_identity_art_brief.json` 记录身份、镜头、锚点、配色和处理约束。`tools/process_v2_unit_art.ps1` 会自动发现源图，对边缘连通的烘入背景做确定性提取，再把源图裁切为统一的 `128x128` RGBA 运行时图，并写入 `assets/v2/units/`。当前已接入键：`v2_{assault,scout,sentry,drone,shield_guard}_{north,east,south,west}`。

`m1_identity_contact_sheet.png` 是南向样本的历史验收快照；`m1_identity_direction_contact_sheet.png` 是五类身份四方向的 Windows 实际渲染验收快照。两者都基于真实 Echo Yard 地面和真实运行时 PNG，不是游戏运行时资源。方向快照用于检查比例、锚点、方向差异和小尺寸可读性。
