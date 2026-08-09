# V2 M1/M2 当前验收报告

状态：`NOT_READY`

本报告只记录已经在当前 V2 worktree 中实际执行并获得输出的证据。真人试玩和完整逐图人工审查尚未执行，因此不能写入“可发布”。

## 构建与版本

- 分支：`codex/ch1-infiltration-v2`
- 最新提交：`3fdbe35 release(v2): isolate Windows package output`
- Godot：4.7.1-stable
- V2 入口：`res://scenes/v2_boot.tscn`
- V2 用户目录：`TacticalGrid_V2_Infiltration`
- Windows 包：`build/TacticalGrid_V2_Infiltration/`
- 可执行文件：109080576 bytes
- 资源包：19497224 bytes

## 已通过证据

| 检查 | 命令/证据 | 结果 |
|---|---|---|
| V2 总闸门 | `tests/v2/run_v2_gate.ps1` | 71/71 项通过，1592/1592 断言通过 |
| M1 视觉矩阵 | `tests/v2/run_m1_visual_matrix.ps1` | 42/42 PNG 通过 |
| M2 视觉矩阵 | `tests/v2/run_m2_visual_matrix.ps1` | 54/54 PNG 通过 |
| 结算页可见性 | M1/M2 两分辨率结果阶段断言 | 结算层可见、覆盖当前视口、奖励文本不与按钮重叠 |
| Windows 构建 | `tools/build_windows.ps1` | 导出成功 |
| Windows 包校验 | `tests/verify_windows_package.ps1` | exe、pck、版本元数据和冷启动通过 |
| V2 隔离校验 | `tests/v2/v2_release_isolation_test.ps1` | V2 入口、用户目录、旧版文件残留、冷启动通过 |
| 首次试玩材料 | `docs/v2_first_time_playtest_form.json` | JSON 可解析，模板已准备 |

## 非致命残余

总闸门报告了 244 条 Godot 退出清理警告，分布在 18 类消息，主要是 `ObjectDB`、`CanvasItem RID` 和资源仍在使用。它们没有造成测试失败，但在最终发布前应继续收敛，特别是长时间运行和真实导出包退出路径。

## 尚未满足的发布硬门

1. 三名未参与实现的玩家首次完成 M1 和 M2，并记录真实时长、目标理解、卡点和可选内容使用率。
2. M1 中位时长达到 20–25 分钟，M2 中位时长达到 25–30 分钟，且无人 5 分钟内通关。
3. 96 张视觉截图完成逐张人工审查。目前只完成自动矩阵和代表性 M1/M2 结果页复核。
4. 不打开 Godot 编辑器，从 Windows 包完整走通启动、基地、任务选择、失败重试、胜利结算、返回基地和退出。
5. 资源退出警告完成风险评估或修复，并把结论补回本报告。

## 下一条执行任务

1. 使用 `v2_first_time_playtest_form.json` 组织 P01/P02/P03 的无指导 M1/M2 试玩。
2. 将原始记录保存在未纳入 Git 的 `artifacts/v2/verification/h1/`，填写 `v2_first_time_playtest_results.md`。
3. 根据真实卡点调整提示、路线后果和遭遇节奏，不用堆血量凑时长。
4. 使用独立 Windows 包复核完整流程，再决定是否可以把结论改为 `RELEASE_READY`。
