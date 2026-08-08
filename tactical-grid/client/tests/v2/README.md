# V2 测试目录

V2 测试、真实输入回归和首次玩家验收记录放在本目录。V1 测试结果不能直接作为 V2 通过证据。

## F01 发布门

从 `tactical-grid/client` 运行：

```powershell
$godotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
& $godotExe --headless --path . --script res://tests/v2/gate_manifest_test.gd
powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

`gate_manifest.json` 是 V2 门的唯一顺序清单。每个 Godot 脚本、场景和 PowerShell 检查都在独立进程中运行；runner 会收集所有项目后统一判断，任一非零退出码都会使发布门失败。门通过时最后一行必须是 `V2 RELEASE GATE PASSED`。

测试脚本使用 `V2TestRunner` 输出英文 `Passed: N` 和 `Failed: 0`，便于后续阶段的 PowerShell 门稳定解析。V2 门会先检查 V2 用户目录，再运行 V1 已有发布门；它不会修改 V1 的测试、存档或发布目录。

## 共享任务基础合同

当前 V2 检查点 schema 为 `4`。schema `3` 的 V2 检查点仍可读：迁移会把旧的 `cp_start`、`cp_rescue`、`cp_pre_evac` 映射到稳定任务/遭遇 ID，补齐 `encounter_state`、`hazard_state` 和 `facility_state`，并保留玩家、敌人、击倒集合和任务阶段。`game_line` 不是 `v2_infiltration` 的 V1 存档仍会被拒绝，不会跨产品线迁移。

遭遇控制器把敌人分成互斥的四态：`active`（当前场上）、`waiting`（超过 `active_cap` 或出生格被占用）、`defeated`（已击倒，不得复活）和 `departed`（已撤离，不得重新占位）。

共享服务的公开合同包括：

- `V2MissionFlow.get_current_step_id()`、`get_objective_step_index()`、`get_objective_step_count()`、`get_current_guide_text()`、`apply_event()`、`get_snapshot()`、`restore_snapshot()`。
- `V2EncounterActivation.mark_enemy_defeated()`、`mark_enemy_departed()`、`get_waiting_enemy_ids()`、`get_defeated_enemy_ids()`、`get_departed_enemy_ids()`、`update()`、`get_snapshot()`、`restore_snapshot()`。
- `V2HazardController.setup()`、`advance_player_turn()`、`consume_enemy_phase_damage()`、`commit_close_action()`、`get_snapshot()`、`restore_snapshot()`。
- `V2InteractionService.get_snapshot()`、`restore_snapshot()`；`V2CheckpointAdapter.capture()` 负责保存共享任务状态。
- `V2HudPresenter.render(snapshot)` 是唯一的 V2 HUD 入口，`HUD.render_v2_snapshot(snapshot)` 负责非模态显示目标进度、行动、路线、危险区和检查点。

manifest 覆盖任务流、遭遇队列/占位/控制器、危险区控制器和运行时、schema 3 迁移与 schema 4 检查点恢复、目标 HUD 合同和真实 HUD 场景、M1 路线/对话/重试/legacy evacuation、救援、V2 主菜单与运行时隔离，以及 V2 battle runtime 和玩家回合输入场景。当前仓库没有独立的 M2 运行时测试文件；M1 完成后进入 M2 的存档身份由 `v2_save_identity_test.gd` 覆盖，新增 M2 测试必须显式加入 manifest。

V1/V2 隔离证据包括专用 `TacticalGrid_V2_Infiltration` 用户目录、`v2_infiltration` 存档身份、V2 专用启动/主菜单、V1 存档拒绝和不调用 V1 release gate。V1 smoke 仍单独运行，不能把 V1 结果当作 V2 通过证据。

## Exact Gate Command

从 `tactical-grid/client` 运行唯一的完整门禁命令：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

runner 会为 manifest 中每一项输出显式 `PASS`/`FAIL`、退出码和 `Passed`/`Failed` 断言计数；失败项不会阻止后续项执行。Godot teardown 的 ObjectDB/resource 输出和 V1 save-recovery 输出会列在 `Warnings (non-fatal)`，但仍保留原始文本；任何非零退出码或失败断言都会使门最终退出 `1`。

## M113 首次玩家记录

普通启动不会创建试玩记录。需要进行 H1 时，负责人为每名测试者分配匿名编号，并显式传入 QA 参数：

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64.exe' --path . --v2-playtest-id=P01
```

有效编号仅限 `P01` 到 `P03` 形式。记录器只写入本地 `user://playtests/m1/Pxx.json`；测试者拒绝录屏时仍可只使用事件表。H1 的 PASS/FAIL 必须由真实玩家记录决定，不能由这个参数或自动测试生成。
