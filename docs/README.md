# Tactical Grid 文档索引

> status: Active
> owner: 项目负责人
> updated: 2026-07-31

仓库唯一开发基线为 `main`。旧功能分支已经并入主线；后续智能体只能从本索引和总路线图领取任务，不得从归档计划自行恢复旧方向。

本目录只保留当前开发需要的入口。旧设计、一次性审计和已失效计划位于
[archive/](archive/README.md)，可用于追溯，但不是当前开发承诺。

## 活跃文档

| 文档 | 状态 | 用途 |
|---|---|---|
| [PROJECT_TAKEOVER_ROADMAP.md](PROJECT_TAKEOVER_ROADMAP.md) | Active | 唯一任务入口、阶段、优先级和退出门 |
| [superpowers/specs/2026-07-30-chapter-one-tactical-network-redesign.md](superpowers/specs/2026-07-30-chapter-one-tactical-network-redesign.md) | Approved | 第一章核心设计规格 |
| [superpowers/plans/2026-07-30-chapter-one-agent-dispatch.md](superpowers/plans/2026-07-30-chapter-one-agent-dispatch.md) | Active | 可直接派发给智能体的代码、图片、音频与真人验收任务 |
| [qa/2026-07-30-project-wide-redesign-audit.md](qa/2026-07-30-project-wide-redesign-audit.md) | Current audit | 全项目事实、风险、参考与发布判断 |
| [qa/CHAPTER1_PRE_NETWORK_BASELINE_QA.md](qa/CHAPTER1_PRE_NETWORK_BASELINE_QA.md) | Frozen baseline | 重设计前自动化和窗口化证据 |
| [design/README.md](design/README.md) | Active | 产品范围和非目标 |
| [DOCUMENTATION_POLICY.md](DOCUMENTATION_POLICY.md) | Active | 文档生命周期、完成状态和资源记录 |
| [../tactical-grid/PROJECT_STATUS.md](../tactical-grid/PROJECT_STATUS.md) | Derived | 最近一次实测状态摘要 |
| [../tactical-grid/README.md](../tactical-grid/README.md) | Derived | 本地运行、测试和模块目录 |
| [../README.md](../README.md) | Derived | 仓库总览 |

## 信息冲突时的顺序

1. 当前源代码、场景、资源、配置和本轮实际命令输出。
2. 带日期、版本、哈希和命令的不可变 QA 记录。
3. 已批准规格和架构决策。
4. 活跃路线图。
5. 状态页和 README 等派生摘要。
6. 许可证、隐私和资源清单等独立合规门。
7. 历史归档。

## 生命周期

- `Draft`：讨论中，不可作为实现承诺。
- `Approved`：已批准，可拆分实现计划。
- `Active`：当前持续维护。
- `Frozen baseline`：不可变历史证据，只能新增后继记录。
- `Superseded`：已由新文档取代。
- `Archived`：只用于追溯。

活跃规格应声明 `status`、`owner`、`updated`、`applies_to`、`supersedes` 和 `superseded_by`。

## 维护规则

- 每次执行任务更新路线图状态和实际验证命令。
- 每次改变玩法边界同步规格、设计范围和路线图。
- 每次新增外部、AI 或程序化资源，按
  [文档政策](DOCUMENTATION_POLICY.md)记录来源、许可证与运行时用途。
- 构建哈希只记录在不可变 QA 快照中，不在 README 复制。
- 历史文档保留 Git 追溯，不继续维护其中的完成宣称。
