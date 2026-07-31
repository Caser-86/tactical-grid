# Tactical Grid

Tactical Grid 是一个使用 Godot 4.7.1 制作中的单机回合制战术游戏项目。当前仓库包含第一章重设计前的可运行技术基线；新的“战术网络控制”第一章尚在生产，整部五章战役仍未完成，**不是已发布或内容完整的游戏**。

## 当前状态

- Godot 客户端可从 `boot.tscn` 启动，包含主菜单、基地、战斗、设置、暂停、结算和对话流程。
- 重设计前六关已接入锁定地图、任务目标、Boss、运行时美术和程序化音频；现存 Windows x64 技术基线包可独立冷启动。
- 2026-07-30 重新运行 Godot 发布门禁为 2,293/2,293 通过，0 失败。
- 本轮服务端依赖未安装，`npm run build` 因找不到 `tsc` 失败；历史 Jest 数字不是本轮验证。
- 新核心玩法、M1 真人门、可复现导出、三难度通关、长时/多硬件 QA、代码签名及第二至第五章仍未完成。

完整的已验证状态、限制和下一步请见 [项目状态](tactical-grid/PROJECT_STATUS.md) 与 [接管路线图](docs/PROJECT_TAKEOVER_ROADMAP.md)。

## 仓库结构

```text
.
├── tactical-grid/          # 可运行项目模块
│   ├── client/             # Godot 4.7.1 客户端
│   ├── server/             # 可选 Node.js 地图与 API 开发工具
│   ├── README.md           # 本地运行、测试和目录说明
│   └── PROJECT_STATUS.md   # 当前实测状态
└── docs/                   # 活跃文档、路线图与历史归档
```

## 快速开始

需要：Godot 4.7.1、Git；只有运行服务端和地图工具时才需要 Node.js 20+。

在 Godot 中打开 `tactical-grid/client/project.godot` 并运行项目，或从命令行启动：

```powershell
godot --path tactical-grid/client
```

`tactical-grid/start.bat` 是开发启动器：它会打开 Godot 编辑器；传入 `--with-server` 时会额外启动本地 Node 服务。

## 文档入口

- [项目模块说明](tactical-grid/README.md)：安装、启动、测试和目录结构。
- [当前状态](tactical-grid/PROJECT_STATUS.md)：当前实测结果与发布阻断项。
- [接管路线图](docs/PROJECT_TAKEOVER_ROADMAP.md)：唯一的开发任务、优先级与验收记录。
- [文档索引](docs/README.md)：活跃文档和历史参考的完整导航。
- [活跃设计范围](docs/design/README.md)：首发版本的边界与玩法原则。

## 贡献约定

- 功能完成必须包含可复现的验证记录，不以 JSON 条目、界面占位或未接入资源作为完成依据。
- 新增资源必须记录来源、许可证和游戏内用途；来源不明或带水印的资源不得进入发布版本。
- 设计扩展先更新路线图或活跃设计范围；历史设计稿仅供参考，不自动成为开发承诺。
