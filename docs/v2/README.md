# Tactical Grid V2 文档入口

> version: V2
> name: Infiltration
> status: Isolated development line
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
- V2 玩法规格：已写入，等待用户签核。
- V2 M1 灰盒：未开始。
- V2 发布资格：未评估。

## 执行顺序

1. 审阅并确认 [V2 总规格](V2_MASTER_SPEC.md)。
2. 生成带任务编号、依赖、文件、测试命令和代理类型的逐任务实施计划。
3. 先实现 V2 技术骨架、操作与 HUD，再用现有资源制作 M1 灰盒。
4. 完成真实输入与首次玩家测试；M1 通过硬门后再批量制作正式美术和后续关卡。

## 禁止事项

- 不在 V2 分支修改 V1 的正式文档内容。
- 不把 V2 的玩法功能直接合并到 `main`。
- 不使用 V1 的存档、截图、日志和导出包作为 V2 的验证结果。
- 不把 V1 测试结果写成 V2 已通过。

## 文件归属

| 内容 | V1 | V2 |
|---|---|---|
| Git 分支 | `main` | `codex/ch1-infiltration-v2` |
| 保护标签 | `v1-chapter1-baseline` | 规格签核后创建 `v2-spec-approved` |
| Godot 用户目录 | 原 Tactical Grid 目录 | `TacticalGrid_V2_Infiltration` |
| 资源新增位置 | V1 原目录 | `client/assets/v2/` |
| 测试新增位置 | V1 原测试目录 | `client/tests/v2/` |
| 导出产物 | V1 独立目录 | `artifacts/v2/` |
