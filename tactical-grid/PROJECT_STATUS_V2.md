# Tactical Grid V2 当前状态

> version: V2 Infiltration
> status: Isolated development scaffold
> branch: `codex/ch1-infiltration-v2`
> baseline: `v1-chapter1-baseline`

## 已完成

- 从 V1 `main` 当前基线建立独立 Git worktree。
- 建立 V2 独立分支，不修改 V1 `main`。
- Godot 项目名称改为 `Tactical Grid V2: Infiltration`。
- Godot 用户数据目录改为 `TacticalGrid_V2_Infiltration`，避免 V1 存档、设置和日志互相覆盖。
- V2 文档、资源、测试和发布产物目录已建立边界。
- V2 正式玩法、内容、美术、技术、测试和发布规格已写入 `docs/v2/V2_MASTER_SPEC.md`，等待用户签核。

## 尚未开始

- V2 逐任务实施计划（在正式规格签核后生成）。
- V2 战斗规则和操作重构。
- V2 M1 灰盒。
- V2 新角色和敌人美术。
- V2 首次玩家测试。
- V2 发布包。

## V1 隔离说明

V1 的 `PROJECT_STATUS.md`、`docs/PROJECT_TAKEOVER_ROADMAP.md` 和 2026-07-30 设计规格属于 V1 历史基线。V2 只读取它们作为素材和技术参考，不在 V2 状态中宣称 V1 测试已经证明 V2 可玩。

## 下一步

先由用户签核 `docs/v2/V2_MASTER_SPEC.md`，再生成包含任务编号、依赖关系、准确文件、测试命令、智能体类型和提交边界的逐任务实施计划。实施时先完成 M1 灰盒和首次玩家门；没有 V2 的真实输入和首次玩家验证，不批量制作 V2 后续关卡和美术资源。
