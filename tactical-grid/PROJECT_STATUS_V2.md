# Tactical Grid V2 当前状态

> version: V2 Infiltration
> status: P0 approved; implementation ready
> branch: `codex/ch1-infiltration-v2`
> baseline: `v1-chapter1-baseline`

## 已完成

- 从 V1 `main` 当前基线建立独立 Git worktree。
- 建立 V2 独立分支，不修改 V1 `main`。
- Godot 项目名称改为 `Tactical Grid V2: Infiltration`。
- Godot 用户数据目录改为 `TacticalGrid_V2_Infiltration`，避免 V1 存档、设置和日志互相覆盖。
- V2 文档、资源、测试和发布产物目录已建立边界。
- V2 正式玩法、内容、美术、技术、测试和发布规格已于 2026-08-05 获用户批准。
- 已创建保护标签 `v2-spec-approved`，指向规格提交 `5e2f167`。
- 主实施计划和六份阶段计划已建立，共 78 个可提交任务与 H1-H3 三个真人硬门。
- P1 技术骨架 F01-F12 已完成：独立门禁、权威数据、地图 schema v3、V2 存档身份、行动预算、确定性战斗、事务行动、角色能力、检查点、敌人意图和运行入口集成。
- V2 P1 release gate 已通过：V2 脚本测试 10 组全部通过；继承 V1 release gate 1816 个稳定断言、章节一 E2E 190 个断言，失败数为 0。
- V2Data 已作为独立 autoload 启动；GameManager 会在启动时硬校验 V2 数据，失败不会静默回退到 V1 数据。
- BattleController 已创建 V2 行动、任务流程和交互依赖槽位，但正式输入仍保留 V1 ActionSystem，等待 P2 按合同切换。

## 尚未开始

- V2 正式输入与战斗 HUD 重构。
- V2 M1 灰盒。
- V2 新角色和敌人美术。
- V2 首次玩家测试。
- V2 发布包。

## V1 隔离说明

V1 的 `PROJECT_STATUS.md`、`docs/PROJECT_TAKEOVER_ROADMAP.md` 和 2026-07-30 设计规格属于 V1 历史基线。V2 只读取它们作为素材和技术参考，不在 V2 状态中宣称 V1 测试已经证明 V2 可玩。

## 下一步

P1 已完成。下一步从 `docs/superpowers/plans/2026-08-05-v2-p2-interaction-hud.md` 的 I01 开始，先实现单击选择、移动/攻击范围、目标预览、取消和结束回合，再接入 V2 HUD。P2 通过前不开始 M1 正式美术批量制作；H1 通过前不扩展后续章节正式内容。
