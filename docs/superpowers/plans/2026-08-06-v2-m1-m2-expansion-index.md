# V2 M1/M2 内容扩充执行总索引

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement these plans task-by-task. Every sub-plan uses checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 V2 的 M1 和 M2 从当前可运行灰盒扩充为两关可独立游玩、路线有差异、目标清楚、内容密度达标并通过发布验收的正式任务。

**Architecture:** 先实现共享任务基础，再分别实现 M1 和 M2 内容，随后接入状态美术与音频，最后执行自动化、视觉和真人硬门。V1 目录、资源、存档和发布流程保持冻结；V2 只在 `codex/ch1-infiltration-v2` 工作树中演进。

**Tech Stack:** Godot 4.7.1、GDScript、JSON 锁定地图、PowerShell 内容/资源工具、Godot headless 测试、Windows Compatibility 视觉快照。

## Global Constraints

- M1 首次游玩中位时长为 20 至 25 分钟，熟练最短主线不低于 12 分钟。
- M2 首次游玩中位时长为 25 至 30 分钟，熟练最短主线不低于 15 分钟。
- 每关包含 8 至 10 个玩法节点、两条有结果差异的主路线、一个可选房间、4 至 5 个遭遇、10 至 14 名稳定 ID 敌人。
- 同时活跃敌人最多 3 名；击倒敌人不复活，存活敌人不会被遭遇切换无反馈隐藏。
- 不增加基础操作、弹药、随机掉落、背包整理、武器耐久、技能树或实时操作模式。
- V2 继续使用左键选择/移动/攻击/设施、右键取消、中键拖图、滚轮缩放、Space 结束回合。
- 所有新增图像、音频和数据必须登记到 `tactical-grid/client/data/v2/resource_manifest.md`，明确来源和许可证。
- V1 工作区、V1 发布目录、V1 存档和 V1 测试不参与 V2 实现。

## 执行顺序

```text
A 共享任务基础
  ├── B M1 回声失联扩充版
  └── C M2 熄灯协议正式版
        └── D 状态美术与音频整合
              └── E 测试、平衡、真人验收与发布
```

`B` 依赖 `A`；`C` 依赖 `A`，但可以和 `B` 并行；`D` 依赖 B/C 的稳定状态 ID；`E` 依赖 A-D 全部完成。

## 子计划

1. [A 共享任务基础](<D:/LLM Files/files/tactical-grid/.worktrees/ch1-infiltration-v2/docs/superpowers/plans/2026-08-06-v2-shared-mission-foundation-plan.md>)
2. [B M1 内容扩充](<D:/LLM Files/files/tactical-grid/.worktrees/ch1-infiltration-v2/docs/superpowers/plans/2026-08-06-v2-m1-content-expansion-plan.md>)
3. [C M2 正式关卡](<D:/LLM Files/files/tactical-grid/.worktrees/ch1-infiltration-v2/docs/superpowers/plans/2026-08-06-v2-m2-content-expansion-plan.md>)
4. [D 美术与音频整合](<D:/LLM Files/files/tactical-grid/.worktrees/ch1-infiltration-v2/docs/superpowers/plans/2026-08-06-v2-art-audio-integration-plan.md>)
5. [E 测试与发布验收](<D:/LLM Files/files/tactical-grid/.worktrees/ch1-infiltration-v2/docs/superpowers/plans/2026-08-06-v2-release-qa-plan.md>)

## 提交边界

- A：`feat(v2): generalize mission stages and encounter state`
- B：`feat(v2): expand M1 echo yard mission`
- C：`feat(v2): add M2 cooling works mission`
- D：`feat(v2): integrate mission state presentation and audio`
- E：`test(v2): pass M1 and M2 release gates`

每个子计划完成后先运行自身命令，再提交；不得把未完成子计划的文件混入前一个提交。

## 工具分工

- 代码和 JSON：Godot/GDScript 智能体执行 A、B、C、E。
- 程序化状态图形和导入验证：D 的代码部分由 Godot/GDScript 智能体执行。
- 新图像生成：只有视觉矩阵确认现有 token 或环境套件在 76 像素缩放下不可读时，才调用图像生成工具；生成后必须裁切、去背景、导入并测试，不允许只提交源图。
- 真人试玩：E 的时长、目标理解和可选内容数据必须由未参与实现的首次玩家提供，不能由自动化脚本代替。

## 总体验收

- A-E 的门禁全部通过。
- M1 两条路线、可选记录室、营救和撤离反制均可实际完成。
- M2 两条路线、冷却控制室、狙击手营救和工程师反制均可实际完成。
- 1280×720、1920×1080、普通、灰阶和色觉辅助视觉矩阵通过。
- 三名首次玩家均能说明当前目标和撤离条件，没有 5 分钟内通关、单位重合、尸体残留、不可达路径或检查点软锁。
