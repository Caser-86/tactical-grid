# Tactical Grid

Tactical Grid 是一个使用 Godot 4.7.1 制作中的单机回合制战术游戏项目。新的“战术网络控制”系统垂直切片和 M1 初版已经进入 `main`；整部第一章和五章战役仍未完成，**不是已发布或内容完整的游戏**。

后续开发、测试、文档和发布只以 `main` 为准。过期分支、服务端实验和旧路线图已经清理。

## 当前状态

- Godot 客户端可从 `boot.tscn` 启动，包含主菜单、基地、战斗、设置、暂停、结算和对话流程。
- 任务单一权威、战术网络、警戒、迷雾状态、敌方意图状态和 M1 分阶段流程已进入主线。
- 2026-08-02 重新运行 Godot 发布门禁为 2,955/2,955 通过，0 失败；移动后迷雾即时刷新、真实鼠标结束回合、中键拖动镜头、自动选中玩家单位、攻击范围提示、角色详情面板、对话布局和两个选项的真实鼠标输入均已通过回归契约。Windows 发布包在 200% 系统缩放下已核验为完整 1280×720 内容布局。
- 敌方意图真实执行、完整迷雾人工表现验收、M1 真人门、干净克隆导出、三难度通关、长时/多硬件 QA、代码签名及 M2-M6 重做仍未完成。

完整的已验证状态、限制和下一步请见 [项目状态](tactical-grid/PROJECT_STATUS.md) 与 [接管路线图](docs/PROJECT_TAKEOVER_ROADMAP.md)。

## 仓库结构

```text
.
├── tactical-grid/          # 可运行项目模块
│   ├── client/             # Godot 4.7.1 游戏、数据、资源与测试
│   ├── README.md           # 本地运行、测试和目录说明
│   └── PROJECT_STATUS.md   # 当前实测状态
└── docs/                   # 活跃文档、规格与唯一路线图
```

## 快速开始

需要：Godot 4.7.1、Git。

在 Godot 中打开 `tactical-grid/client/project.godot` 并运行项目，或从命令行启动：

```powershell
godot --path tactical-grid/client
```

`tactical-grid/start.bat` 是开发启动器，会直接打开 Godot 编辑器。

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
