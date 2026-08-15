# V2 M1/M2 当前验收报告

状态：`AUTOMATION_READY / HUMAN_NOT_READY`

本报告只记录已经在当前 V2 worktree 中实际执行并获得输出的证据。真人试玩和完整逐图人工审查尚未执行，因此不能写入“可发布”。

## 构建与版本

- 分支：`codex/ch1-infiltration-v2`
- 源码自动化验证基线：`b074af4 build(v2): remove stale export temporary files`
- Godot：4.7.1-stable
- V2 入口：`res://scenes/v2_boot.tscn`
- V2 用户目录：`TacticalGrid_V2_Infiltration`
- Windows 包目录：`build/TacticalGrid_V2_Infiltration/`
- 当前候选包：2026-08-15 基于 `b074af4` 重建；EXE `109080576` bytes，PCK `44296564` bytes。SHA-256 记录于构建生成的 `build/TacticalGrid_V2_Infiltration/release_manifest.json`：EXE `41385b33ed2f43f0f4cbb1781ebd4873f931c5763a07d6e46b31f723d43b1d62`，PCK `9eb1c0a2657c211f7f93045b5ed0b3ab63e892f7b6195c0d18f7d43f1b3c0b49`。

## 已通过证据

| 检查 | 命令/证据 | 结果 |
|---|---|---|
| V2 总闸门 | `tests/v2/run_v2_gate.ps1` | 84/84 项通过，2116/2116 断言通过；97 条非致命退出清理警告，21 类 |
| M1 路线 E2E | `tests/v2/run_m1_e2e_process_matrix.ps1 -GodotExe <Godot>` | `main_direct`、`optional_record`、`checkpoint_retry` 各在独立 Godot 进程运行，共 68/68 断言通过 |
| M1 视觉矩阵 | `tests/v2/run_m1_visual_matrix.ps1` | 36/36 PNG 通过，2 分辨率 x 3 显示模式 x 6 阶段 |
| M2 视觉矩阵 | `tests/v2/run_m2_visual_matrix.ps1` | 54/54 PNG 通过 |
| V2 四职业能力入口 | `v2_input_router_test.gd`、`v2_ability_rules_test.gd`、`v2_player_turn_e2e_test.tscn`、`v2_playtest_runtime_wiring_test.gd` | Q 键进入能力目标选择，金色目标格和悬停预览可见，左键提交、右键/Q 取消；输入 52/0、规则 22/0、实战 85/0、接线 12/0 |
| 结算页可见性 | M1/M2 两分辨率结果阶段断言 | 结算层可见、覆盖当前视口、奖励文本不与按钮重叠 |
| Windows 构建 | `tools/build_windows.ps1 -GodotPath <Godot>` | 2026-08-15 基于 `b074af4` 重新导出成功，退出码 0；构建脚本会清理旧导出 `*.TMP` |
| Windows 包校验 | `tests/verify_windows_package.ps1` | 当前候选包的 EXE、PCK、版本元数据和冷启动通过，退出码 0 |
| V2 隔离校验 | `tests/v2/v2_release_isolation_test.ps1` | 当前候选包的 V2 入口、用户目录、旧版文件残留和冷启动通过，退出码 0 |
| 单人验收遥测 | `v2_playtest_recorder_test.gd`、`v2_playtest_integration_contract_test.gd`、`v2_playtest_runtime_wiring_test.gd` | 42/0、10/0、8/0；运行时已接入无效点击、取消、镜头、伤害、倒地、敌方意图和重试事件；OWNER 记录默认不含截图或个人标识，AI 不能写入 `approved` |
| 首次试玩材料 | `docs/v2_first_time_playtest_form.json` | JSON 可解析，模板已准备 |
| 基地 fresh save | `v2_base_progression_scene_test.tscn` | M1 默认预览、主目标和 20-25 分钟预计时长可读 |
| V2 难度入口 | `v2_settings_contract_test.gd`、`v2_settings_scene_test.tscn` | 故事/标准两档可见、可保存，困难档不对 V2 开放 |
| 结算内容 | `v2_result_presentation_test.gd`、M1/M2 result PNG | 关卡专属回顾、中文模块名，无 V1 信用点/经验值 |
| 战术范围层 | `v2_affordance_contract_test.gd`、M1/M2 PNG | 移除每格 M/A，保留路径箭头和攻击目标标牌 |
| 路线选择 | M1 `route_split` PNG | 选择按钮直接显示侦察、警戒和路线长短后果 |

## 非致命残余

总闸门报告了 97 条 Godot 退出清理警告，分布在 21 类消息。无头音频播放引用已通过独立契约测试消除；剩余问题来自部分战斗场景测试的 `ObjectDB`、`CanvasItem RID` 和脚本资源仍在使用。剩余测试清理警告没有造成断言失败，但仍应在发布前完成风险评估或收敛。本轮新增的 V2 战斗所有权清理断言已通过，但没有宣称已经消除引擎退出告警。

### M1 E2E 进程隔离（2026-08-15）

- 门禁不再把三条 M1 E2E 路线放在同一个场景树内连续运行。`run_m1_e2e_process_matrix.ps1` 对每条路线单独启动 Godot，场景通过 `--v2-m1-e2e-route=<route>` 只执行请求路线。
- 无参数启动 `v2_m1_e2e_test.tscn` 仍保留三路线聚合回归，便于本地调试；门禁清单只登记进程矩阵，避免跨路线对象生命周期相互影响。
- 本轮三条路线分别报告 `12/14/7 CanvasItem RID`、`28/32/18 ObjectDB` 和各 `2 resources still in use`。因此该重构已消除多路线共用运行时这一混杂因素，但未宣称已经修复单路线资源清理；后续应按独立路线继续定位。

### NX-020 最小复现记录（2026-08-10）

- 命令：`Godot_v4.7.1-stable_win64_console.exe --verbose --headless --path . res://tests/v2/v2_rescue_battle_integration_test.tscn`。
- 结果：场景断言通过，但退出时仍有 10 个 `CanvasItem RID`、24 个 `ObjectDB` 和 `res://scripts/game/unit.gd`、`res://scripts/v2/combat/v2_unit_turn_state.gd` 两项脚本资源仍在使用。
- 已否定方向：在 `UnitSprite._exit_tree()` 中主动断开单位信号、终止补间并清空单位引用会使同一最小复现从原有 8/20 增至 10/24，因此该改动已撤回。
- 已修复根因：营救场景测试的 `_cleanup_battle()` 是协程，但三个调用点没有 `await`；清理在第一帧等待时被 `finish()` 越过。测试现在先显式释放脱离场景树的单位数据，再等待战斗根节点销毁，并断言突击兵与侦察兵均已失效。该场景 18/18 断言通过，退出告警回到原有 8 个 `CanvasItem RID`、20 个 `ObjectDB`、2 个脚本资源。
- 影响结论：这是自动场景退出的未收敛风险，不得当作已修复，也不得阻止已验证 Windows 包的自动构建；完整包内人工流程仍须在 H3 前单独确认。

## 尚未满足的发布硬门

1. 三名未参与实现的玩家首次完成 M1 和 M2，并记录真实时长、目标理解、卡点和可选内容使用率。
2. M1 中位时长达到 20–25 分钟，M2 中位时长达到 25–30 分钟，且无人 5 分钟内通关。
3. 96 张视觉截图完成逐张人工审查。目前已完成自动矩阵，并人工复核路线、范围层、危险预警和 M1/M2 结算代表画面。
4. 不打开 Godot 编辑器，从基于 `b074af4` 的 Windows 包完整走通启动、基地、任务选择、失败重试、胜利结算、返回基地和退出。
5. 剩余 97 条测试场景退出警告完成风险评估或修复，并把结论补回本报告。

## 本轮收口结果

1. V2 结算不再显示 V1 信用点、经验值或内部模块 ID。
2. M1/M2 使用各自的通关回顾、营救角色和模块名称。
3. fresh save 基地立即显示任务主目标、可选目标、预计时长、编队与行动流程。
4. 设置界面开放故事/标准难度，故事难度继续使用现有敌人弱化、回合奖励和首次识别宽限规则。
5. 路线后果不再依赖悬停提示；战术范围移除重复 M/A 字母。
6. V2 主菜单设置使用独立文件，冷启动设置不再借用或改写 V1 当前存档。
7. 失败结算不再宣称临时营救角色或模块已经解锁；M2 可选目标使用本关文案。
8. 无头冷启动跳过主菜单 BGM，音频单例退出时主动释放播放流；Windows 包冷启动无资源错误。
9. V2 设置以独立设置文件为权威：载入旧存档不会覆盖主菜单选择，冷启动会立即应用视觉、音频、输入、窗口和无障碍设置。
10. 项目负责人已完成当前 Windows 候选包试玩，并确认可以继续开发；由于未提供逐项时长和首次玩家样本，本报告仍不把该结果视为公开发布签核。
11. 本轮将四职业的已有能力接入统一的 `Q -> 金色目标格 -> 悬停预览 -> 左键提交` 路径：突击兵冲击推进、侦察兵区域扫描、狙击手截断射击、重装兵屏障投射；能力规则仍由 V2 行动服务统一查询和提交，V1 输入路径没有接入该信号。
12. 项目负责人试玩确认当前候选包已能继续试玩；这属于继续开发检查点，不等同于首次玩家理解度或公开发布签核。

## 下一条执行任务

1. 由项目负责人从当前候选包完成 OWNER 单人试玩，并填写 `tactical-grid/client/docs/v2_m1_single_owner_acceptance.md`；在此之前不得写入 `approved`。
2. 组织 P01/P02/P03 的无指导 M1/M2 试玩，并将原始记录保存在未纳入 Git 的 `artifacts/v2/verification/h1/`。
3. 根据真实卡点调整提示、路线后果和遭遇节奏，不用堆血量凑时长。
4. 在发布前评估或收敛 97 条 Godot 退出清理警告，并把结论回填本报告。
5. 继续验证四职业能力在 M1/M2 正式内容中的实际使用率和教学价值；当前只确认能力入口可用，不把一次能力实战通过当作数值平衡完成。
