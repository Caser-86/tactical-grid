# AI 生成资源声明

> status: Active compliance record
> owner: 项目负责人
> updated: 2026-07-31
> applies_to: `tactical-grid/client/assets/` 内的 AI 生成源图和运行时资源

本文件记录 AI 资源的来源边界。它不把资源文件存在、目录契约通过或旧版本曾接入，写成重设计后美术已经完成。

## 当前结论

- `tactical-grid/client/assets/characters/`、`effects/`、`tiles/`、`ui/` 中 2026-06-17 的 16 张 SDXL 图片仅作内部参考，存在水印、无 Alpha 或不能安全切图的问题，不进入发行包。
- `tactical-grid/client/assets/generated/chapter1/source/` 中的风格板和生成拼版是源材料，必须由导出预设排除。
- `tactical-grid/client/assets/generated/chapter1/runtime/` 中已处理资源是可复用的重设计前资产基线，不自动满足新角色辨识、网络设施、动画或关卡地标要求。
- 当前 Codex 图像生成工具没有向项目暴露精确后端模型 ID，因此统一记录为“Codex 内置 Image Generation”，不虚构模型版本。

## 已登记资源类别

| 路径 | 来源 | 当前用途与状态 |
|---|---|---|
| `tactical-grid/client/assets/characters/` 等四个遗留目录 | SDXL，2026-06-17 | 仅风格参考，导出排除，禁止恢复为运行时资源 |
| `assets/generated/chapter1/backgrounds/*.png` | Codex 内置 Image Generation，2026-07-28 至 29 | 重设计前菜单、基地、启动与结算背景基线；新 UI 流程接入后复验 |
| `assets/generated/chapter1/source/echo_yard_*.png` | Codex 内置 Image Generation，2026-07-30 | Echo Yard 视觉源材料，导出排除 |
| `assets/generated/chapter1/runtime/environment/echo_yard/{prop,landmark}/*.png` | 生成拼版经色键、裁切和切图 | 可复用环境组件；M1 新地图必须重新进行构图和可读性验收 |
| `assets/generated/chapter1/source/ch1_m1_units/*_source_v1.{png,jpg}` | Codex 内置 Image Generation，2026-07-30/31 | 单位源图（含 scout/protocol_engineer/hunter），导出排除 |
| `assets/generated/chapter1/runtime/units/*.png` | 上述源图经 `process_chapter1_unit_art.ps1` 色键、裁切、96x96 合成 | 10 个单位精灵（含 scout/protocol_engineer/hunter）；已接入 ArtCatalog |

| `assets/generated/chapter1/source/network_icons/*_node_v1.jpg` | Codex 内置 Image Generation，2026-07-31 | 5 个网络节点图标源图（camera/door/turret/power_conduit/beacon），导出排除 |
| `assets/generated/chapter1/runtime/network_icons/*_64.png` | 上述源图经 `process_network_icons.ps1` 色键、裁切、64x64 合成 | 5 个网络节点运行时图标；已接入 ArtCatalog 和网络覆盖层 |
| `assets/generated/chapter1/source/landmarks/echo_yard_gantry_crane_v1.jpg` | Codex 内置 Image Generation，2026-07-31 | Echo Yard 门式起重机地标源图，导出排除 |
| `assets/generated/chapter1/runtime/environment/echo_yard/landmark/gantry_crane_192x128.png` | 上述源图经 `process_landmark_source.ps1` 色键、裁切、192x128 合成 | 运行时地标精灵；已接入 ArtCatalog |

Cooling Works、Transit Hub 和 Sentinel Core 的运行时环境组件由项目脚本程序化生成，不属于 AI 图像资源；它们的详细来源见 [资源清单](tactical-grid/client/data/RESOURCE_MANIFEST.md)。

## 运行时接入门

任何新增 AI 资源必须同时满足：

1. 在本文件和资源清单中记录最终路径、生成工具、日期和用途。
2. 记录去背、裁切、切图、调色或转码等修改。
3. 验证尺寸、Alpha、导入设置、缩放、动画、碰撞和实际游戏触发。
4. 在 1280×720、灰度和色觉缺陷模式下检查可读性。
5. 完成一个 M1 遭遇区小样后，才允许批量生产同类资产。
6. 商业发布前复核生成服务届时条款与目标发行范围。

外部第三方资源还必须在 [第三方通知](THIRD_PARTY_NOTICES.md) 中登记来源和许可证。

## 重设计缺口

- 四名玩家角色的终版轮廓、职业色饰和动画。
- 协议工程师与猎手敌人。
- 节点四状态、五类设施、敌方意图、警戒和网络反馈。
- 每关一个主地标，以及符合简体中文 UI 的正式字体。

详细资产生产顺序见 [成品化总路线图](docs/PROJECT_TAKEOVER_ROADMAP.md)。

## 变更记录

- 2026-07-27：登记遗留 AI 参考图。
- 2026-07-30：登记第一章背景、Echo Yard 源图、环境组件和单位处理流程。
- 2026-07-30：改为重设计资产基线记录，移除“旧资源即最终完成”的暗示。
