# Tactical Grid 文档索引

本目录只保留当前开发需要的文档入口。旧设计稿、一次性审计输出和已失效的实现假设已移入 [archive/](archive/README.md)，仍可查阅，但不应被当作当前开发承诺。

## 活跃文档

| 文档 | 用途 | 权威级别 |
|---|---|---|
| [PROJECT_TAKEOVER_ROADMAP.md](PROJECT_TAKEOVER_ROADMAP.md) | 开发任务、优先级、测试证据和发布门槛 | 最高 |
| [design/README.md](design/README.md) | 首发范围、玩法边界和非目标 | 高 |
| [DOCUMENTATION_POLICY.md](DOCUMENTATION_POLICY.md) | 文档维护、资源记录和归档规则 | 高 |
| [../tactical-grid/PROJECT_STATUS.md](../tactical-grid/PROJECT_STATUS.md) | 最近一次实测状态快照 | 中 |
| [../tactical-grid/README.md](../tactical-grid/README.md) | 本地运行、测试和模块目录 | 中 |
| [../README.md](../README.md) | 仓库总览与快速入口 | 中 |

## 信息冲突时的取舍顺序

1. 当前源代码、场景、项目配置和实际测试输出。
2. [接管路线图](PROJECT_TAKEOVER_ROADMAP.md) 中带验证记录的任务状态。
3. [当前状态快照](../tactical-grid/PROJECT_STATUS.md)。
4. [活跃设计范围](design/README.md)。
5. 历史归档文档。

## 文档维护

- 每次完成任务，更新路线图中的任务状态和实际验证命令。
- 每次改变首发范围，更新 `design/README.md` 并同步路线图。
- 每次新增外部或 AI 资源，按 [文档政策](DOCUMENTATION_POLICY.md) 记录来源、许可证与游戏内用途。
- 已过时但具有决策价值的材料移动到 `archive/`，不要在活跃文档中保留与当前状态冲突的完成宣称。
