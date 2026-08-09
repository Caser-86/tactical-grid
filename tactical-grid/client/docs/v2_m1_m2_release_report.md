# V2 M1/M2 当前验收报告

状态：`AUTOMATION_READY / HUMAN_NOT_READY`

本报告只记录已经在当前 V2 worktree 中实际执行并获得输出的证据。真人试玩和完整逐图人工审查尚未执行，因此不能写入“可发布”。

## 构建与版本

- 分支：`codex/ch1-infiltration-v2`
- 源码自动化验证基线：`a1efb3c test(v2): prevent headless audio resource leaks`
- Godot：4.7.1-stable
- V2 入口：`res://scenes/v2_boot.tscn`
- V2 用户目录：`TacticalGrid_V2_Infiltration`
- Windows 包目录：`build/TacticalGrid_V2_Infiltration/`
- 当前候选包：2026-08-10 基于 `a1efb3c` 重建；EXE `109080576` bytes，PCK `19519700` bytes。SHA-256 记录于未纳入 Git 的 `artifacts/v2/verification/h1/BUILD_ID.txt`。

## 已通过证据

| 检查 | 命令/证据 | 结果 |
|---|---|---|
| V2 总闸门 | `tests/v2/run_v2_gate.ps1` | 75/75 项通过，1637/1637 断言通过 |
| M1 视觉矩阵 | `tests/v2/run_m1_visual_matrix.ps1` | 42/42 PNG 通过 |
| M2 视觉矩阵 | `tests/v2/run_m2_visual_matrix.ps1` | 54/54 PNG 通过 |
| 结算页可见性 | M1/M2 两分辨率结果阶段断言 | 结算层可见、覆盖当前视口、奖励文本不与按钮重叠 |
| Windows 构建 | `tools/build_windows.ps1` | 2026-08-10 基于 `a1efb3c` 重新导出成功 |
| Windows 包校验 | `tests/verify_windows_package.ps1` | 当前候选包的 EXE、PCK、版本元数据和冷启动通过 |
| V2 隔离校验 | `tests/v2/v2_release_isolation_test.ps1` | 当前候选包的 V2 入口、用户目录、旧版文件残留和冷启动通过 |
| 首次试玩材料 | `docs/v2_first_time_playtest_form.json` | JSON 可解析，模板已准备 |
| 基地 fresh save | `v2_base_progression_scene_test.tscn` | M1 默认预览、主目标和 20-25 分钟预计时长可读 |
| V2 难度入口 | `v2_settings_contract_test.gd`、`v2_settings_scene_test.tscn` | 故事/标准两档可见、可保存，困难档不对 V2 开放 |
| 结算内容 | `v2_result_presentation_test.gd`、M1/M2 result PNG | 关卡专属回顾、中文模块名，无 V1 信用点/经验值 |
| 战术范围层 | `v2_affordance_contract_test.gd`、M1/M2 PNG | 移除每格 M/A，保留路径箭头和攻击目标标牌 |
| 路线选择 | M1 `route_split` PNG | 选择按钮直接显示侦察、警戒和路线长短后果 |

## 非致命残余

总闸门报告了 70 条 Godot 退出清理警告，分布在 12 类消息。无头音频播放引用已通过独立契约测试消除；剩余问题来自部分战斗场景测试的 `ObjectDB`、`CanvasItem RID` 和脚本资源仍在使用。剩余测试清理警告没有造成断言失败，但仍应在 H3 前完成风险评估或收敛。

### NX-020 最小复现记录（2026-08-10）

- 命令：`Godot_v4.7.1-stable_win64_console.exe --verbose --headless --path . res://tests/v2/v2_rescue_battle_integration_test.tscn`。
- 结果：场景断言通过，但退出时仍有 10 个 `CanvasItem RID`、24 个 `ObjectDB` 和 `res://scripts/game/unit.gd`、`res://scripts/v2/combat/v2_unit_turn_state.gd` 两项脚本资源仍在使用。
- 已否定方向：在 `UnitSprite._exit_tree()` 中主动断开单位信号、终止补间并清空单位引用会使同一最小复现从原有 8/20 增至 10/24，因此该改动已撤回。
- 影响结论：这是自动场景退出的未收敛风险，不得当作已修复，也不得阻止已验证 Windows 包的自动构建；完整包内人工流程仍须在 H3 前单独确认。

## 尚未满足的发布硬门

1. 三名未参与实现的玩家首次完成 M1 和 M2，并记录真实时长、目标理解、卡点和可选内容使用率。
2. M1 中位时长达到 20–25 分钟，M2 中位时长达到 25–30 分钟，且无人 5 分钟内通关。
3. 96 张视觉截图完成逐张人工审查。目前已完成自动矩阵，并人工复核路线、范围层、危险预警和 M1/M2 结算代表画面。
4. 不打开 Godot 编辑器，从基于 `a1efb3c` 的 Windows 包完整走通启动、基地、任务选择、失败重试、胜利结算、返回基地和退出。
5. 剩余 70 条测试场景退出警告完成风险评估或修复，并把结论补回本报告。

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

## 下一条执行任务

1. 执行 NX-020/NX-025，补齐 M1/M2 主目标、可选目标和撤离状态的地图断言。
2. 对当前候选包完成启动、基地、进入 M1、退出的人工技术烟雾检查，然后冻结为 H1 试玩包。
3. 使用 `v2_first_time_playtest_form.json` 组织 P01/P02/P03 的无指导 M1/M2 试玩，并将原始记录保存在未纳入 Git 的 `artifacts/v2/verification/h1/`。
4. 根据真实卡点调整提示、路线后果和遭遇节奏，不用堆血量凑时长。
