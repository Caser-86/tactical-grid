# V2 M1 Echo Yard Content Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 M1“回声失联”扩展为 26×18、两条有真实差异路线、五个遭遇、可选事故记录室、营救后撤离反制和 20 至 25 分钟首次体验的正式关卡。

**Architecture:** 将当前旧 `ch1_m1.json` 复制为明确的 `ch1_m1_echo_yard_v3.json` 兼容夹具，新增 `ch1_m1_echo_yard_v4.json` 作为 V2 正式地图；`V2MapLoader` 将 `ch1_m1` 和正式 map ID 指向 v4。路线、设施、遭遇和检查点全部由 JSON 稳定 ID 驱动，战斗控制器只消费共享基础返回的状态差量。

**Tech Stack:** Godot 4.7.1、GDScript、JSON 锁定地图、现有 Echo Yard/Transit Hub/Sentinel Core 运行时资源。

## Global Constraints

- 地图尺寸 26×18；固定 12 名敌人；五个遭遇；活跃上限 3。
- 首次玩家目标时长 20 至 25 分钟，熟练最短主线不低于 12 分钟。
- 事故记录室可跳过，但必须提供独立敌人局面和 `scout_b` 固定奖励。
- 吊机必须改变可见通路或敌方意图；营救后东北直通路线必须关闭并显示替代路线。
- 不能通过增加敌人 HP、降低玩家伤害或扩大空白步行凑时长。

---

### Task 1: 建立 M1 扩充地图合同

**Files:**
- Create: `tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json`
- Create: `tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v3.json`
- Modify: `tactical-grid/client/scripts/v2/content/v2_map_loader.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_map_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_expansion_map_test.gd`

**Interfaces:**
- `V2MapLoader.load_map("ch1_m1")` and `load_map("ch1_m1_echo_yard_v4")` both return the v4 data.
- Copy the current V2 `ch1_m1.json` content into `ch1_m1_echo_yard_v3.json` before changing the canonical alias; `load_map("ch1_m1_echo_yard_v3")` must continue loading the 22×16 fixture only when explicitly requested by migration tests.
- Map stable ID for the runtime map is `ch1_m1_echo_yard_v4`; the legacy fixture keeps its original `ch1_m1_echo_yard_v3` map ID.

- [ ] **Step 1: 写地图合同测试**

断言尺寸 26×18、12 名敌人、五个遭遇、至少两个 `main_routes`、一个可选 `record` 设施、三个检查点、主目标和撤离点存在；五个遭遇的 `active_count` 都不超过 3。

- [ ] **Step 2: 写地图数据**

使用以下固定地标和路线坐标：

| 内容 | 坐标/规则 |
|---|---|
| 玩家出生 | `(3,16)` 南侧货运坪 |
| 维修摄像头 | `(7,13)` |
| 事故记录室 | `(4,5)`，可选 |
| 吊机控制点 | `(13,5)` |
| 侦察兵 | `(16,8)` |
| 撤离区 | `(23,2)`，半径 1 |
| 维修道 | `(3,16) -> (7,13) -> (10,9) -> (13,5) -> (16,8)` |
| 货柜突破线 | `(3,16) -> (8,14) -> (12,13) -> (13,5) -> (16,8)` |
| 记录支线 | `(7,13) -> (4,5) -> (9,5) -> (16,8)` |

所有五层图层均为 26×18；阻挡层只封闭货柜、墙和营救后东北直通线，不能切断两条主路线。

- [ ] **Step 3: 写 12 个稳定敌人和五个遭遇**

敌人 ID 与职责固定为：

| 遭遇 | 敌人 ID | 职责 |
|---|---|---|
| `m1_e01_start` | `m1_sentry_south`, `m1_drone_south` | 哨兵、无人机 |
| `m1_e02_route` | `m1_sentry_route`, `m1_drone_route`, `m1_sentry_cargo` | 路线压力 |
| `m1_e03_record` | `m1_sentry_record`, `m1_engineer_record` | 可选记录室 |
| `m1_e04_rescue` | `m1_sentry_rescue`, `m1_shield_rescue`, `m1_drone_rescue` | 营救保护 |
| `m1_e05_evac` | `m1_sniper_evac_a`, `m1_sniper_evac_b` | 撤离拦截 |

`m1_e02_route` 根据 `route_camera_selected` 或 `route_cargo_selected` 激活不同出生点；记录室遭遇只在进入记录区域后触发。

- [ ] **Step 4: 接入地图加载别名并运行校验**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_expansion_map_test.gd
```

Expected: PASS; explicit v3 fixture remains unchanged and v4 becomes the `ch1_m1` runtime map.

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json tactical-grid/client/scripts/v2/content/v2_map_loader.gd tactical-grid/client/tests/v2/v2_m1_map_test.gd tactical-grid/client/tests/v2/v2_m1_expansion_map_test.gd
git commit -m "feat(v2): author expanded Echo Yard M1 map contract"
```

### Task 2: 实现 M1 路线和设施后果

**Files:**
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json`
- Modify: `tactical-grid/client/scripts/v2/interaction/handlers/camera_handler.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/handlers/record_handler.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/gantry_crane_handler.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_route_consequence_test.gd`

**Interfaces:**
- Facility actions: `view_rescue_zone`, `disable_camera`, `lower_gantry`, `upload_incident_record`.
- Crane result includes `route_id="gantry_bridge"`, `map_changes=[{"cell":[x,y],"state":"open"}]` and `enemy_intent_changes`; it does not create an extra checkpoint beyond `cp_m1_start`, `cp_m1_rescue` and `cp_m1_pre_evac`.
- Route selection event is `route_selected` with payload `route_id="camera_maintenance"` or `route_id="cargo_breakthrough"`.

- [ ] **Step 1: 写路线结果测试**

断言摄像头路线能获得营救区预览但提高警戒，货柜路线不获得预览但保留较短的可通行路径；两者都能操作吊机并到达营救区。

- [ ] **Step 2: 实现路线选择状态**

第一次进入路线分叉区域时只显示两句结果摘要；提交路线后写入 `route_id`，重复提交返回 `route_already_selected`，不会打开复杂菜单。

- [ ] **Step 3: 实现吊机设施**

吊机操作消耗一次行动，打开一组预先封闭格并把一组撤离敌人意图从 `hold` 改为 `intercept`。地图、HUD 和音效同时显示“通路已放下”。

- [ ] **Step 4: 实现记录室奖励**

记录终端只在事故记录室敌人被处理后可用；操作后写入 `optional_record_uploaded`、`scout_b`，并保持可跳过不阻断营救与撤离。

- [ ] **Step 5: 运行路线测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_route_consequence_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_interaction_test.gd
```

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m1_echo_yard_v4.json tactical-grid/client/scripts/v2/interaction/handlers/camera_handler.gd tactical-grid/client/scripts/v2/interaction/handlers/record_handler.gd tactical-grid/client/scripts/v2/interaction/handlers/gantry_crane_handler.gd tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd tactical-grid/client/tests/v2/v2_m1_route_consequence_test.gd
git commit -m "feat(v2): add M1 route and gantry consequences"
```

### Task 3: M1 营救、撤离反制和目标流程

**Files:**
- Modify: `tactical-grid/client/data/v2/missions.json`
- Modify: `tactical-grid/client/data/v2/dialogues.json`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_expanded_flow_test.gd`

**Interfaces:**
- M1 stages: `search_scout`, `select_route`, `operate_gantry`, `rescue_scout`, `evacuate_squad`.
- Events: `entered_route_split`, `route_selected`, `gantry_lowered`, `character_rescued`, `evac_intercept_started`, `evac_checked`.
- `get_guide_text()` must identify current location/action and the final green evacuation marker.

- [ ] **Step 1: 写流程测试**

用公开事件和合法设施提交依次走完两条路线，断言路线选择、吊机、营救、中段封锁、撤离反制和两人撤离均产生阶段更新；记录室跳过时主线仍能完成。

- [ ] **Step 2: 接入中段转折**

营救成功后锁定旧东北直通线，打开吊机通路，激活 `m1_e05_evac`；HUD 同时显示新目标和替代路径，玩家重新获得控制后才能继续行动。

- [ ] **Step 3: 接入正式结算**

两名存活角色进入 `(23,2)` 半径 1 区域后自动提交 `evac_checked`；结果写入 `rescue_character="scout"`、`optional_record`、`unlocked_modules` 和 `checkpoint_id="cp_m1_pre_evac"`。

- [ ] **Step 4: 补 M1 对话短句**

新增开场路线提示、吊机结果、营救转折、撤离反制和结算提示；每段只传达一个决定或结果，不遮挡地图超过一个完整玩家回合。

- [ ] **Step 5: 运行流程测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_expanded_flow_test.gd
```

Expected: both routes and the optional room pass without direct position writes or direct mission completion calls.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/data/v2/missions.json tactical-grid/client/data/v2/dialogues.json tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_m1_expanded_flow_test.gd
git commit -m "feat(v2): complete expanded M1 rescue and extraction flow"
```

### Task 4: M1 灰盒节奏和视觉接入

**Files:**
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`
- Modify: `tactical-grid/client/tests/v2/run_m1_visual_matrix.ps1`
- Modify: `tactical-grid/client/data/v2/README.md`

- [ ] **Step 1: 让 M1 灰盒显示六个关键地点**

在现有环境套件上放置货运坪、维修道、记录室、吊机、营救区和撤离台；不直接渲染 source/styleboard，只使用 `ArtCatalog` 运行时组件。

- [ ] **Step 2: 扩展快照阶段**

视觉阶段固定为 `start`、`route_split`、`record_room`、`gantry_open`、`rescue`、`evac_intercept`、`result`；每个阶段验证目标栏、设施状态、地图标记和单位不重合。

- [ ] **Step 3: 运行 M1 视觉矩阵**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

Expected: 1280×720 和 1920×1080 的普通、灰阶、色觉辅助快照均生成且尺寸正确。

- [ ] **Step 4: 更新 M1 数据说明**

在 `data/v2/README.md` 写入 v4 地图尺寸、路线、敌人预算、遭遇上限、可选奖励和当前验证命令。

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd tactical-grid/client/tests/v2/run_m1_visual_matrix.ps1 tactical-grid/client/data/v2/README.md
git commit -m "test(v2): verify expanded M1 graybox presentation"
```

### Task 5: M1 子计划门禁

**Files:**
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Test: `tactical-grid/client/tests/v2/v2_m1_expanded_flow_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_m1_expansion_map_test.gd`

- [ ] **Step 1: 运行 M1 脚本门禁**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

- [ ] **Step 2: 用现有界面手动完成一次最短路线和一次可选路线**

记录回合数、实际遭遇数、设施操作数、是否出现敌人消失、单位重合、路径不可达和营救后目标是否更新。

- [ ] **Step 3: Commit**

```powershell
git add tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "test(v2): close expanded M1 content gate"
```
