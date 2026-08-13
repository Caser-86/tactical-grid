# Tactical Grid V2 文档入口

> version: V2
> name: Infiltration
> status: M1/M2 automation ready; H1-R2 player and package gates pending
> branch: `codex/ch1-infiltration-v2`
> worktree: `.worktrees/ch1-infiltration-v2`

## 版本边界

V2 是独立的 2D 小队潜入探索冒险版本。V1“战术网络控制版”保留在 `main` 和 `v1-chapter1-baseline` 标签中，V2 不修改 V1 的玩法、文档、存档、资源和发布产物。

V2 可以复制 V1 的稳定代码和合法资源作为起点，但复制后在 V2 分支内独立维护。禁止使用跨 worktree 的相对路径、软链接、共享可写资源目录和共享导出目录。

## 当前状态

- 隔离 worktree：已建立。
- 独立 Git 分支：已建立。
- Godot 项目名称：`Tactical Grid V2: Infiltration`。
- Godot 用户目录：`TacticalGrid_V2_Infiltration`。
- 第一章当前权威：2026-08-13 正式游戏设计 -> 第一章主路线图 -> 当前 M1 核心乐趣实施计划。
- 2026-08-05 V2 玩法规格和主实施计划保留为实现历史，不是当前执行队列。
- P1、P2、M101-M113、C02、C03：已完成并通过 V2 独立门禁。
- M1/M2：均可从 V2 新档完整游玩，包含移动、攻击、敌方回合、迷雾、营救、撤离、失败重试和进度保存。
- 当前质量状态：自动化 E2E、场景契约和视觉矩阵已通过；结算呈现、设置持久化、范围层、移动路径和死亡实体清理均有回归测试。
- V2 自动化发布门：已通过（75/75 项，1640/1640 断言；M1 42/42、M2 54/54 视觉快照）。
- H1-R2 三名首次玩家门：待项目负责人组织真实玩家执行，AI 不代替该验收。
- V2 发布资格：`NOT_READY`；当前提交的 Windows 包已自动重建和校验，完整包内人工流程、真人试玩和逐图人工审查仍待执行。

## Windows 发布包

V2 发布包必须由客户端目录下的 `tools/build_windows.ps1` 生成到：

```text
tactical-grid/client/build/TacticalGrid_V2_Infiltration/
```

包入口由 `project.godot` 固定为 `res://scenes/v2_boot.tscn`，可执行文件和资源包名称均为 `TacticalGrid_V2_Infiltration`。构建后依次运行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/verify_windows_package.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/v2_release_isolation_test.ps1
```

在真实 H1/H2 玩家试玩和 Windows 包启动链路完成前，V2 仍不得标记为可发布。

## 执行顺序

1. 以 [第一章正式游戏设计](../superpowers/specs/2026-08-13-v2-chapter-one-production-game-design.md) 为产品权威。
2. 按 [第一章主路线图](../superpowers/plans/2026-08-13-v2-chapter-one-master-roadmap.md) 确认当前已解锁阶段。
3. 执行 [当前 M1 核心乐趣实施计划](../superpowers/plans/2026-08-13-v2-m1-core-fun-implementation.md) 的当前任务。

## 计划文件

- [第一章正式游戏设计](../superpowers/specs/2026-08-13-v2-chapter-one-production-game-design.md)：产品权威。
- [第一章主路线图](../superpowers/plans/2026-08-13-v2-chapter-one-master-roadmap.md)：组合调度与阶段解锁。
- [当前 M1 核心乐趣实施计划](../superpowers/plans/2026-08-13-v2-m1-core-fun-implementation.md)：当前执行队列。
- [2026-08-05 主实施计划](../superpowers/plans/2026-08-05-v2-master-implementation.md)：实现历史，不是当前执行队列。
- [P1 技术基础](../superpowers/plans/2026-08-05-v2-p1-foundation.md)：数据、地图、存档、战斗、能力、检查点和敌方意图。
- [P2 操作与 HUD](../superpowers/plans/2026-08-05-v2-p2-interaction-hud.md)：地图点击、攻击预览、镜头、迷雾、HUD 和设置。
- [P3-P5 M1](../superpowers/plans/2026-08-05-v2-p3-p5-m1-vertical-slice.md)：第一关灰盒、教学、真人门和正式垂直切片。
- [P4-P6 美术与共享内容](../superpowers/plans/2026-08-05-v2-p4-p6-art-shared-content.md)：IMAGE2、资源处理、四方向图、环境、VFX 和音频。
- [P7-P9 M2-M6](../superpowers/plans/2026-08-05-v2-p7-p9-missions.md)：后五关、角色救援、猎手、Boss、结局和平衡。
- [P10 发布验收](../superpowers/plans/2026-08-05-v2-p10-release-acceptance.md)：无障碍、存档、视觉、音频、性能、长时和 Windows 发布。
- [当前验收报告](../../tactical-grid/client/docs/v2_m1_m2_release_report.md)：自动化证据、发布包证据和剩余硬门。

## 禁止事项

- 不在 V2 分支修改 V1 的正式文档内容。
- 不把 V2 的玩法功能直接合并到 `main`。
- 不使用 V1 的存档、截图、日志和导出包作为 V2 的验证结果。
- 不把 V1 测试结果写成 V2 已通过。

## 文件归属

| 内容 | V1 | V2 |
|---|---|---|
| Git 分支 | `main` | `codex/ch1-infiltration-v2` |
| 保护标签 | `v1-chapter1-baseline` | `v2-spec-approved` |
| Godot 用户目录 | 原 Tactical Grid 目录 | `TacticalGrid_V2_Infiltration` |
| 资源新增位置 | V1 原目录 | `client/assets/v2/` |
| 测试新增位置 | V1 原测试目录 | `client/tests/v2/` |
| 导出产物 | V1 独立目录 | `artifacts/v2/` |
