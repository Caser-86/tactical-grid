# Tactical Grid V2 文档入口

> version: V2
> name: Infiltration
> status: Approved specification; implementation planned
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
- V2 玩法规格：已于 2026-08-05 获用户批准。
- V2 实施计划：78 个可提交任务与 H1-H3 三个真人硬门已写入。
- V2 M1 灰盒：未开始。
- V2 发布资格：未评估。

## 执行顺序

1. 从 [V2 主实施计划](../superpowers/plans/2026-08-05-v2-master-implementation.md) 的 F01 建立独立发布门。
2. 按 F01-F12 完成技术骨架，按 I01-I12 完成操作与 HUD。
3. 按 M101-M114 制作 M1 灰盒并完成 H1 首次玩家门。
4. H1 通过后执行 A01-A14 和 C01-C14，最后执行 R01-R12 与 H3。

## 计划文件

- [主实施计划](../superpowers/plans/2026-08-05-v2-master-implementation.md)：唯一顺序、依赖、模型分工和状态索引。
- [P1 技术基础](../superpowers/plans/2026-08-05-v2-p1-foundation.md)：数据、地图、存档、战斗、能力、检查点和敌方意图。
- [P2 操作与 HUD](../superpowers/plans/2026-08-05-v2-p2-interaction-hud.md)：地图点击、攻击预览、镜头、迷雾、HUD 和设置。
- [P3-P5 M1](../superpowers/plans/2026-08-05-v2-p3-p5-m1-vertical-slice.md)：第一关灰盒、教学、真人门和正式垂直切片。
- [P4-P6 美术与共享内容](../superpowers/plans/2026-08-05-v2-p4-p6-art-shared-content.md)：IMAGE2、资源处理、四方向图、环境、VFX 和音频。
- [P7-P9 M2-M6](../superpowers/plans/2026-08-05-v2-p7-p9-missions.md)：后五关、角色救援、猎手、Boss、结局和平衡。
- [P10 发布验收](../superpowers/plans/2026-08-05-v2-p10-release-acceptance.md)：无障碍、存档、视觉、音频、性能、长时和 Windows 发布。

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
