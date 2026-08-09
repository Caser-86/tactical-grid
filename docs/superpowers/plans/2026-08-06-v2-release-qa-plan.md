# V2 M1/M2 Release QA and Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用公开接口自动测试、视觉矩阵、存档重试、长时稳定性、首次玩家试玩和 Windows 打包门，证明 M1/M2 是可完成的正式内容，而不是只在脚本里瞬间完成的演示。

**Architecture:** 自动化测试验证数据、状态和公开交互接口；视觉测试验证关键阶段；真人测试验证时长、目标理解和趣味密度；发布脚本验证 V2 包只包含 V2 入口和资源。任何自动测试不得直接修改单位位置、敌人伤害或调用任务完成事件。

**Tech Stack:** Godot 4.7.1、PowerShell、Windows Compatibility renderer、现有 V2 test runner、CSV/JSON 试玩记录。

## Global Constraints

- M1 首次玩家中位时长 20 至 25 分钟，M2 首次玩家中位时长 25 至 30 分钟。
- 没有玩家在 5 分钟内完成任一关。
- 三名玩家均能不询问开发者说明当前目标和撤离条件。
- 至少两名玩家主动使用非必需设施或进入可选房间。
- 没有单位重合、尸体残留、路径指向不可达格、迷雾不同步或检查点软锁。

---

### Task 1: 公开接口流程测试

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_m1_public_flow_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m2_public_flow_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_m2_stability_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Tests may call public `V2MapLoader`, `V2MissionFlow`, `V2RescueController.query_rescue/commit_rescue`, `V2InteractionService.query_actions/commit_action`, public battle input actions and `end_turn`.
- Tests may not assign `Unit.grid_pos`, `enemy.weapon_damage`, `mission_flow.state` or call `mission_complete` directly.

- [x] **Step 1: 写 M1 两路线流程测试**

分别通过 camera maintenance 和 cargo breakthrough 完成 M1；每个动作通过公开预览/提交接口，断言总时长数据、遭遇数、设施结果和胜利结果。

- [x] **Step 2: 写 M2 两路线流程测试**

分别通过 west maintenance 和 east catwalk 完成 M2，覆盖喷口预告、狙击预告、路线互斥结果、狙击手营救和撤离反制。

- [x] **Step 3: 写稳定性回归测试**

连续启动、结束回合、保存、恢复和失败重试 20 次；每次检查 active/waiting/defeated 集合、单位坐标唯一性、任务阶段和 HUD snapshot 非空。

- [x] **Step 4: 运行测试确认无作弊路径**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_public_flow_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m2_public_flow_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_m2_stability_test.gd
```

- [x] **Step 5: Commit**

```powershell
git add tactical-grid/client/tests/v2/v2_m1_public_flow_test.gd tactical-grid/client/tests/v2/v2_m2_public_flow_test.gd tactical-grid/client/tests/v2/v2_m1_m2_stability_test.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "test(v2): cover M1 and M2 public interaction flows"
```

### Task 2: 视觉矩阵和截图审查

**Files:**
- Create: `tactical-grid/client/tests/v2/run_v2_m1_m2_visual_matrix.ps1`
- Modify: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m2_visual_snapshot.gd`
- Create: `tactical-grid/client/docs/v2_visual_acceptance_matrix.md`

- [x] **Step 1: 统一矩阵参数**

覆盖 `1280x720`、`1920x1080`、`normal`、`grayscale`、`deuteranopia_assist`；M1 阶段为 start/route/record/gantry/rescue/evac/result，M2 阶段为 start/west/east/turbine/hazard/control/rescue/countermeasure/result。

- [x] **Step 2: 运行快照脚本**

每张图必须检查文件存在、非空、宽高匹配；Godot headless 只能执行合同检查，Windows Compatibility renderer 必须生成真实 PNG。

- [ ] **Step 3: 按清单人工审查**

逐张检查单位区分度、目标和撤离标记、危险预告、路线状态、设施文字、迷雾边界、底栏说明、攻击/移动范围和结算页面。

- [x] **Step 4: Commit**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_m1_m2_visual_matrix.ps1
git add tactical-grid/client/tests/v2/run_v2_m1_m2_visual_matrix.ps1 tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd tactical-grid/client/tests/v2/v2_m2_visual_snapshot.gd tactical-grid/client/docs/v2_visual_acceptance_matrix.md
git commit -m "test(v2): add M1 and M2 visual acceptance matrix"
```

### Task 3: 存档、失败、重试和进度测试

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_m1_m2_checkpoint_scene_test.tscn`
- Create: `tactical-grid/client/tests/v2/v2_m1_m2_checkpoint_scene_test.gd`
- Modify: `tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd`

- [x] **Step 1: 测试 M1 三个检查点**

分别在开场、营救完成、撤离反制后保存；恢复后检查任务目标、单位坐标、敌人击倒状态、设施状态和撤离路线。

- [x] **Step 2: 测试 M2 三个稳定检查点和阶段内反制状态**

分别在开场、封锁解除后的推进阶段、狙击手营救、撤离反制后保存；恢复后喷口周期、狙击预告、工程师反制和角色加入状态一致。M2 的“封锁解除”与开场共用 `cp_start`，不人为增加一个不存在的检查点 ID。

- [x] **Step 3: 测试失败重试**

全队失能后分别选择检查点重试、重新开始任务和返回基地；三个按钮都可用，返回基地不污染当前任务或 V1 存档。

- [x] **Step 4: 运行场景测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_m1_m2_checkpoint_scene_test.tscn
```

- [x] **Step 5: Commit**

```powershell
git add tactical-grid/client/tests/v2/v2_m1_m2_checkpoint_scene_test.tscn tactical-grid/client/tests/v2/v2_m1_m2_checkpoint_scene_test.gd tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd
git commit -m "test(v2): verify M1 and M2 checkpoint retry flows"
```

### Task 4: 真人首次游玩硬门

**Files:**
- Create: `tactical-grid/client/docs/v2_first_time_playtest_form.json`
- Create: `tactical-grid/client/docs/v2_first_time_playtest_results.md`
- Modify: `tactical-grid/client/docs/v2_visual_acceptance_matrix.md`

- [x] **Step 1: 准备试玩版本**

已准备 V2 首次试玩记录模板和未执行结果模板；真实试玩仍必须使用 Windows 导出包或 V2 独立入口，关闭 Godot 编辑器提示、调试快捷键和开发者日志，不向试玩者解释操作。

- [ ] **Step 2: 让三名未参与实现的玩家首次完成 M1**

记录开始/结束时间、回合数、遭遇数、设施数、可选房间、第一次迷失的位置、失败原因和是否理解撤离条件。

- [ ] **Step 3: 让同三名玩家首次完成 M2**

记录路线选择、喷口预告是否被理解、狙击手能力是否被使用、控制室进入率、目标理解和撤离条件。

- [ ] **Step 4: 应用硬门**

只有在 M1 中位 20 至 25 分钟、M2 中位 25 至 30 分钟、无人 5 分钟内通关、三人都能复述目标/撤离、至少两人使用可选内容且无列出的稳定性问题时通过。失败时只调整玩法节点、路线后果、提示或遭遇节奏，不用堆血量凑时间。

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/docs/v2_first_time_playtest_form.json tactical-grid/client/docs/v2_first_time_playtest_results.md tactical-grid/client/docs/v2_visual_acceptance_matrix.md
git commit -m "docs(v2): record first-time M1 and M2 playtest gate"
```

### Task 5: Windows 发布包和隔离验收

**Files:**
- Modify: `tactical-grid/client/tools/build_windows.ps1`
- Modify: `tactical-grid/client/tests/verify_windows_package.ps1`
- Modify: `tactical-grid/client/tests/v2/run_v2_gate.ps1`
- Create: `tactical-grid/client/tests/v2/v2_release_isolation_test.ps1`
- Modify: `docs/v2/README.md`

- [x] **Step 1: 构建 V2 包**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

已将导出预设和构建脚本固定为 `build/TacticalGrid_V2_Infiltration/TacticalGrid_V2_Infiltration.exe`；实际导出、包元数据检查和冷启动已通过。输出包必须以 `TacticalGrid_V2_Infiltration` 为用户目录，入口为 `scenes/v2_boot.tscn`，不把 V1 发布包复制到 V2 目录。

- [x] **Step 2: 检查发布包隔离**

已通过 `tests/v2/v2_release_isolation_test.ps1` 检查 V2 入口、用户目录、产品线、包文件名、旧版残留和冷启动；V2 存档身份与配置名由总闸门继续覆盖。

- [ ] **Step 3: 从包启动并完成最短 M1/M2**

不打开 Godot 编辑器，验证启动、基地、任务选择、游戏、失败重试、胜利结算、返回基地和退出。

- [x] **Step 4: 运行完整 V2 门禁**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/v2_release_isolation_test.ps1
```

已通过完整 V2 总闸门（71/71 项、1592/1592 断言）和 Windows 包隔离冷启动检查；Task 5 Step 3 的包内完整 M1/M2 流程仍待真人执行。

- [x] **Step 5: 更新发布文档并提交**

已在 `docs/v2/README.md` 记录 V2 构建命令、运行入口、测试命令、已验收关卡和 V1/V2 分离规则。

```powershell
git add tactical-grid/client/export_presets.cfg tactical-grid/client/tools/build_windows.ps1 tactical-grid/client/tests/verify_windows_package.ps1 tactical-grid/client/tests/v2/v2_release_isolation_test.ps1 docs/v2/README.md
git commit -m "release(v2): close M1 and M2 Windows release gate"
```

### Task 6: 最终验收报告

**Files:**
- Create: `tactical-grid/client/docs/v2_m1_m2_release_report.md`
- Modify: `tactical-grid/client/docs/v2/README.md`

- [ ] **Step 1: 汇总自动化证据**

记录每条命令、提交哈希、通过数量、失败数量和生成的视觉矩阵目录；没有实际执行的项目写明未执行，不能用计划替代结果。

- [ ] **Step 2: 汇总真人证据**

记录三名玩家的原始表单、M1/M2 中位时长、目标理解、可选内容进入率和剩余问题。

- [ ] **Step 3: 给出发布结论**

只有所有硬门满足时写入“可发布”；若未满足，报告必须列出具体失败门和下一条可执行任务。

- [ ] **Step 4: Commit**

```powershell
git add tactical-grid/client/docs/v2_m1_m2_release_report.md tactical-grid/client/docs/v2/README.md
git commit -m "docs(v2): publish M1 and M2 release acceptance report"
```
