# V2 M2 Cooling Works Content Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 制作 M2“熄灯协议”正式 V2 关卡，提供 28×20 冷却厂、双路线、确定性喷口危险、可选控制室、狙击手营救和 25 至 30 分钟首次体验。

**Architecture:** M2 使用独立 `ch1_m2_cooling_works_v1.json` 锁定地图和数据驱动阶段；西侧维护管廊与东侧高架桥都能解除同一封锁，但设施后果不同；中央涡轮、冷却控制室、隔离区和北侧撤离门组成四段可识别空间。M2 复用 A 阶段通用营救、遭遇队列、设施快照和危险区服务。

**Tech Stack:** Godot 4.7.1、GDScript、JSON 锁定地图、Cooling Works 运行时资源、现有 V2 狙击手 token 和音频。

## Global Constraints

- 地图尺寸 28×20；固定 13 名敌人；五个遭遇；活跃上限 3。
- 首次玩家目标时长 25 至 30 分钟，熟练最短主线不低于 15 分钟。
- 冷却喷口提前一个完整玩家回合预告，不使用随机伤害或随机格。
- 狙击手营救后立即出现一个能展示远程能力的公开高威胁意图。
- 可选冷却控制室只增加独立局面和固定 `assault_b` 奖励，不阻断主线。

---

### Task 1: 建立 M2 锁定地图和数据合同

**Files:**
- Create: `tactical-grid/client/data/v2/locked_maps/ch1_m2_cooling_works_v1.json`
- Modify: `tactical-grid/client/scripts/v2/content/v2_map_loader.gd`
- Modify: `tactical-grid/client/data/v2/missions.json`
- Create: `tactical-grid/client/tests/v2/v2_m2_map_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m2_config_test.gd`

**Interfaces:**
- `V2MapLoader.load_map("ch1_m2")` and `load_map("ch1_m2_cooling_works_v1")` return the same map.
- Map stable ID is `ch1_m2_cooling_works_v1`.
- Mission record includes `objective_steps`, `hazards`, `route_options`, `rescue_character="sniper"`, `enemy_total=13`, `active_cap=3`, `duration_minutes=[25,30]`.

- [ ] **Step 1: 写 M2 地图合同测试**

断言尺寸 28×20、13 个 `spawn_enemy`、五个遭遇、四个检查点、至少两个主路线、一个 `cooling_control` 可选设施、`rescue_sniper` 和北侧撤离区存在；所有图层尺寸准确。

- [ ] **Step 2: 写固定地标和路线**

使用以下坐标：

| 内容 | 坐标/规则 |
|---|---|
| 双人出生 | `(3,17)`、`(4,17)` 南侧装卸口 |
| 西侧电力控制台 | `(7,13)` |
| 东侧安全门旁路 | `(20,12)` |
| 中央涡轮大厅 | `(14,9)`，主地标覆盖 3×2 |
| 冷却控制室 | `(6,5)`，可选 |
| 狙击手隔离区 | `(19,5)` |
| 撤离门 | `(24,2)`，半径 1 |
| 西侧路线 | `(3,17) -> (7,13) -> (10,10) -> (14,9)` |
| 东侧路线 | `(4,17) -> (20,12) -> (18,9) -> (14,9)` |
| 狙击手路线 | `(14,9) -> (19,5) -> (24,2)` |

西侧路线上放置固定喷口危险格；东侧路线放置两条可见狙击预告射线。两条路线均可到达中央涡轮。

- [ ] **Step 3: 写 13 个稳定敌人和五个遭遇**

敌人职责分配：5 名 `sentry`、3 名 `drone`、3 名 `sniper_sentry`、2 名 `protocol_engineer`。遭遇 ID 和预算固定为：

| 遭遇 | 内容 |
|---|---|
| `m2_e01_loading` | 2 名哨兵，装卸口教学 |
| `m2_e02_route` | 1 名哨兵、1 名无人机、1 名狙击哨兵，按路线选择不同意图 |
| `m2_e03_turbine` | 1 名哨兵、1 名无人机、1 名工程师 |
| `m2_e04_isolation` | 1 名狙击哨兵、1 名哨兵、1 名工程师 |
| `m2_e05_exit` | 1 名狙击哨兵、1 名无人机 |

同一时间最多激活 3 名；未激活敌人保留在等待队列，不从地图无反馈消失。

- [ ] **Step 4: 写 M2 任务数据和加载别名**

目标阶段为 `disable_lockdown`、`rescue_sniper`、`show_sniper_ability`、`evacuate_squad`；任一封锁解除路线都推进到下一阶段。

- [ ] **Step 5: 运行 M2 地图和配置测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m2_map_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m2_config_test.gd
```

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m2_cooling_works_v1.json tactical-grid/client/scripts/v2/content/v2_map_loader.gd tactical-grid/client/data/v2/missions.json tactical-grid/client/tests/v2/v2_m2_map_test.gd tactical-grid/client/tests/v2/v2_m2_config_test.gd
git commit -m "feat(v2): author Cooling Works M2 map and mission data"
```

### Task 2: 双路线封锁解除和冷却控制室

**Files:**
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/cooling_control_handler.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/handlers/power_handler.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/handlers/door_handler.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd`
- Create: `tactical-grid/client/tests/v2/v2_m2_route_consequence_test.gd`

**Interfaces:**
- West action `cut_power_grid` returns `power_state="offline"`, `enemy_vision_delta=-2`, `door_id="west_service_door"`.
- East action `bypass_security_door` returns `door_state="open"`, `sniper_lines_visible=true`, `power_state="online"`.
- Optional action `shutdown_cooling_nozzles` returns `hazard_closed=true`, `unlocked_modules=["assault_b"]`.

- [ ] **Step 1: 写路线结果测试**

分别提交西侧和东侧动作，断言两者都产生 `lockdown_cleared`，但只有西侧降低观察范围、只有东侧保留电力并显示狙击线；重复提交返回明确拒绝。

- [ ] **Step 2: 实现路线动作**

两种动作都消耗一次行动并写入 `route_id`；玩家可以继续探索另一侧，但不会重复获得封锁解除奖励。

- [ ] **Step 3: 实现冷却控制室**

进入控制室后先触发独立两名敌人局面，清理后才允许关闭喷口；关闭状态写入危险区快照，并解锁 `assault_b`，跳过房间只失去奖励。

- [ ] **Step 4: 运行交互测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m2_route_consequence_test.gd
```

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/scripts/v2/interaction/handlers/cooling_control_handler.gd tactical-grid/client/scripts/v2/interaction/handlers/power_handler.gd tactical-grid/client/scripts/v2/interaction/handlers/door_handler.gd tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd tactical-grid/client/tests/v2/v2_m2_route_consequence_test.gd
git commit -m "feat(v2): add M2 route consequences and cooling control"
```

### Task 3: 冷却危险、狙击手营救和工程师反制

**Files:**
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m2_cooling_works_v1.json`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd`
- Modify: `tactical-grid/client/data/v2/dialogues.json`
- Create: `tactical-grid/client/tests/v2/v2_m2_expanded_flow_test.gd`

**Interfaces:**
- Events: `lockdown_cleared`, `cooling_warning_started`, `cooling_nozzles_shutdown`, `character_rescued`, `sniper_ability_showcase`, `engineer_countermeasure_started`, `evac_checked`.
- Rescue result uses `character_id="sniper"`, adds `player_sniper`, restores mission-defined HP, and writes `unlocked_modules=["sniper_a"]` once.
- Engineer countermeasure writes `hazard_warning` and `exit_route_changed` before player control resumes.

- [ ] **Step 1: 写 M2 完整流程测试**

通过公开移动、设施预览、设施提交、攻击和结束回合完成西侧路线、东侧路线、冷却控制室、狙击手营救和撤离；禁止直接修改位置、伤害或调用任务完成事件。

- [ ] **Step 2: 接入喷口回合节奏**

喷口在每次敌方阶段只处理固定周期；玩家阶段提前显示下一组危险格，控制室关闭后周期固定停止；检查点恢复后预告与周期一致。

- [ ] **Step 3: 接入狙击手即时教学局面**

狙击手加入后在其可攻击范围内展示一名公开高威胁意图，底栏只提示“选择狙击手并点击红色目标”；完成或取消都不阻断撤离，但完成后记录 `sniper_ability_showcase`。

- [ ] **Step 4: 接入工程师反制**

进入北侧撤离区域前激活两名工程师/狙击组合，改变一组预警格或撤离门状态；所有变化通过地图覆盖、HUD 和短音效同步显示。

- [ ] **Step 5: 补 M2 对话**

新增路线选择、涡轮大厅、控制室、狙击手加入、工程师反制和撤离结算短句；每段都能在一个玩家回合内跳过。

- [ ] **Step 6: 运行流程测试并提交**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m2_expanded_flow_test.gd
```

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m2_cooling_works_v1.json tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd tactical-grid/client/data/v2/dialogues.json tactical-grid/client/tests/v2/v2_m2_expanded_flow_test.gd
git commit -m "feat(v2): complete M2 hazard rescue and countermeasure flow"
```

### Task 4: M2 视觉关卡和基地解锁

**Files:**
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd`
- Create: `tactical-grid/client/tests/v2/v2_m2_progression_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m2_visual_snapshot.gd`
- Create: `tactical-grid/client/tests/v2/run_m2_visual_matrix.ps1`

- [ ] **Step 1: 接入环境构图**

使用 `ArtCatalog` 的 Cooling Works 地面、边界、管线、涡轮和冷却塔组件，确保中央涡轮在初始或首次展开镜头可见；状态层不覆盖角色和网格点击区域。

- [ ] **Step 2: 接入 M2 结算奖励**

完成 M2 后只写一次 `rescued_characters += sniper`、`unlocked_modules += sniper_a` 和 `current_mission = ch1_m3`；可选控制室额外写 `assault_b`，不影响主线解锁。

- [ ] **Step 3: 写视觉快照场景**

阶段固定为 `start`、`route_west`、`route_east`、`turbine`、`hazard_warning`、`cooling_room`、`sniper_rescue`、`exit_countermeasure`、`result`。

- [ ] **Step 4: 运行 M2 视觉矩阵**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m2_visual_matrix.ps1
```

矩阵覆盖 1280×720、1920×1080、normal、grayscale、deuteranopia_assist，并验证危险区同时有形状和颜色编码。

- [ ] **Step 5: 运行进度测试并提交**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m2_progression_test.gd
git add tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd tactical-grid/client/tests/v2/v2_m2_progression_test.gd tactical-grid/client/tests/v2/v2_m2_visual_snapshot.gd tactical-grid/client/tests/v2/run_m2_visual_matrix.ps1
git commit -m "feat(v2): connect M2 presentation and campaign progression"
```

### Task 5: M2 子计划门禁

**Files:**
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Modify: `tactical-grid/client/data/v2/README.md`

- [ ] **Step 1: 将 M2 脚本和场景加入门禁**

加入地图、配置、路线、流程、进度和视觉脚本；场景测试使用独立 `v2_m2_visual_snapshot.tscn`，不调用 V1 场景。

- [ ] **Step 2: 运行 M2 门禁**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

- [ ] **Step 3: 更新 M2 数据说明并提交**

记录 28×20、13 敌人、五遭遇、两路线、危险周期、奖励和验证命令。

```powershell
git add tactical-grid/client/tests/v2/gate_manifest.json tactical-grid/client/data/v2/README.md
git commit -m "test(v2): close expanded M2 content gate"
```
