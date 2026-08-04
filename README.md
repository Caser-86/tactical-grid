# Tactical Grid V2: Infiltration

这是 Tactical Grid 的 V2 独立开发线，使用 Godot 4.7.1 制作，方向为 2D 小队潜入探索冒险。V1“战术网络控制版”仍由 `main` 独立维护，本工作区不修改、不读取 V1 的运行存档，也不与 V1 共用开发产物。

V2 的唯一开发入口见 [V2 版本说明](docs/v2/README.md)。V1 文档和旧规格仅作为历史基线，不属于 V2 的执行任务。

## V2 当前状态

- V2 已完成独立 worktree、Git 分支、Godot 项目身份和用户数据目录隔离。
- V2 当前仍继承 V1 的可运行基线，正式总规格已经写入并等待用户签核，玩法代码尚未开始修改。
- V2 的下一步是签核总规格并生成逐任务实施计划，然后按 P1 技术骨架、P2 操作与 HUD、P3 M1 灰盒的顺序执行。

完整的 V2 状态、边界和下一步请见 [V2 项目状态](tactical-grid/PROJECT_STATUS_V2.md) 与 [V2 文档入口](docs/v2/README.md)。

## 仓库结构

```text
.
├── tactical-grid/          # 可运行项目模块
│   ├── client/             # Godot 4.7.1 游戏、数据、资源与测试
│   ├── README.md           # 本地运行、测试和目录说明
│   └── PROJECT_STATUS_V2.md # V2 当前状态
└── docs/                   # V2 文档与路线图
```

## 快速开始

需要：Godot 4.7.1、Git。

在 Godot 中打开 `tactical-grid/client/project.godot` 并运行项目，或从命令行启动：

```powershell
godot --path tactical-grid/client
```

`tactical-grid/start.bat` 是开发启动器，会直接打开 Godot 编辑器。

## V2 文档入口

- [项目模块说明](tactical-grid/README.md)：安装、启动、测试和目录结构。
- [V2 当前状态](tactical-grid/PROJECT_STATUS_V2.md)：V2 当前状态与发布阻断项。
- [V2 版本说明](docs/v2/README.md)：V2 唯一执行入口、边界与后续规格。
- [V2 总规格](docs/v2/V2_MASTER_SPEC.md)：产品、玩法、内容、技术、资源、测试与发布的唯一权威要求。

## 贡献约定

- 功能完成必须包含可复现的验证记录，不以 JSON 条目、界面占位或未接入资源作为完成依据。
- 新增资源必须记录来源、许可证和游戏内用途；来源不明或带水印的资源不得进入发布版本。
- 设计扩展先更新路线图或活跃设计范围；历史设计稿仅供参考，不自动成为开发承诺。
