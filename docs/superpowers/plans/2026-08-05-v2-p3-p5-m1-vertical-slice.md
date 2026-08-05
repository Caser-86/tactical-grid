# Tactical Grid V2 P3-P5 M1 Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用现有合法资源完成可从新档独立理解、营救侦察兵并撤离的 M1，先通过首次玩家门，再在美术计划完成后达到公开试玩质量。

**Architecture:** M1 使用 schema v3 固定地图、V2MissionFlow 事件状态机和三个分批遭遇；主线不要求上传，事故记录是可选探索。教学由玩家行为触发，检查点只在输入稳定时写入；真人测试数据决定是否允许进入正式批量资源阶段。

**Tech Stack:** Godot 4.7.1、GDScript、22×16 JSON 锁定地图、现有 Echo Yard 资源、Godot 场景 E2E、人工首次玩家测试。

## Global Constraints

- 依赖 F01-F12 和 I01-I12 全部通过。
- M1 主目标固定为“找到失联侦察兵并一起撤离”；事故记录始终可选。
- 单人突击开场，营救后侦察兵立即加入本关；敌人总数 6，任何时刻最多 3 名活跃。
- M1 只使用哨兵与侦察无人机，只出现潜伏和搜索警戒。
- M1 只教学选择、移动、攻击、敌方意图、摄像头和撤离；一次一条，正文不超过 28 个汉字。
- 首次目标时长 12-18 分钟；H1 前只使用现有资源，不批量生成 M2-M6 正式美术。
- 每个任务先写失败测试，任务结束运行 M1 E2E 和 V2 完整门。

---

## M1 Locked Layout Contract

地图 ID 固定为 `ch1_m1_echo_yard_v3`，尺寸 `22×16`，以下对象 ID 与坐标不可在后续任务中自行改名：

| ID | 类型 | 坐标 | 用途 |
|---|---|---:|---|
| `spawn_assault` | 玩家出生 | `(3,14)` | 突击兵开场 |
| `rescue_scout` | 营救对象 | `(13,7)` | 主目标中点 |
| `evac_northeast` | 撤离中心 | `(19,2)` | 营救后开放 |
| `camera_console_south` | 摄像头控制台 | `(7,11)` | 查看中段区域 |
| `camera_east` | 摄像头 | `(15,5)` | 观察 `(13..18,3..8)` |
| `optional_record` | 事故记录 | `(4,4)` | 可选目标与侦察模块 B |
| `landmark_crane` | 地标 | `(10,1)` | 关卡方向识别 |
| `enemy_sentry_south` | 哨兵 | `(8,12)` | 遭遇 A |
| `enemy_drone_south` | 无人机 | `(10,10)` | 遭遇 A |
| `enemy_sentry_rescue` | 哨兵 | `(14,8)` | 遭遇 B |
| `enemy_drone_rescue` | 无人机 | `(16,7)` | 遭遇 B |
| `enemy_sentry_record` | 哨兵 | `(6,5)` | 可选路线 |
| `enemy_sentry_evac` | 哨兵 | `(18,3)` | 遭遇 C |

主要路线一：`(3,14) → (7,11) → (10,9) → (13,7) → (16,5) → (19,2)`。

主要路线二：`(3,14) → (2,10) → (4,4) → (9,5) → (13,7) → (17,4) → (19,2)`。

地图必须用半掩体和全掩体形成路线边界，不用不可见墙。连续四回合内必须遇到新信息、交互、敌人或目标变化。

### Task M101: M1 任务数据与初始编队

**Executor:** Terra high。

**Files:**
- Modify: `tactical-grid/client/data/v2/missions.json`
- Verify: `tactical-grid/client/data/v2/characters.json`
- Create: `tactical-grid/client/tests/v2/v2_m1_config_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces mission fields: `id/map_id/name/starting_roster/rescue_character/deployment_limit/primary/optional/enemy_total/active_cap/duration_minutes/tutorial_steps`。

- [x] **Step 1: 写 M1 固定配置测试**

```gdscript
var m1 := V2Data.get_mission(&"ch1_m1")
t.check(m1.starting_roster == ["assault"], "M1 单人突击开场")
t.check(m1.rescue_character == "scout", "M1 营救侦察兵")
t.check(m1.primary == "找到失联侦察兵并一起撤离", "主目标文案固定")
t.check(m1.optional == "上传事故记录", "事故记录为可选目标")
t.check(m1.enemy_total == 6 and m1.active_cap == 3, "六敌且同时最多三敌")
t.check(m1.duration_minutes == [12, 18], "首次时长目标固定")
```

- [x] **Step 2: 审核当前基础数据，确认正式地图 ID 仍需锁定**

- [x] **Step 3: 写入确定配置并删除旧强制上传字段**

`missions.json.ch1_m1` 不包含 `upload_turns_required`、`evac_locked_until_upload`、信用点和三星回合字段。`characters.json.scout.unlock` 固定为 `{mission="ch1_m1", event="scout_rescued"}`。

- [x] **Step 4: 运行配置测试和数据仓库测试**

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/data/v2 tactical-grid/client/tests/v2
git commit -m "feat(v2): lock M1 mission contract"
```

### Task M102: 22×16 两路线地图和遭遇分区

**Executor:** Terra high；Sol xhigh 复核可达性。

**Files:**
- Create: `tactical-grid/client/data/v2/locked_maps/ch1_m1.json`
- Create: `tactical-grid/client/tests/v2/v2_m1_map_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Consumes: F04 schema v3。
- Produces encounter IDs: `encounter_south/encounter_rescue/encounter_evac`。
- Produces checkpoint IDs: `cp_start/cp_rescue/cp_pre_evac`。

- [x] **Step 1: 写地图对象、路线和激活上限测试**

```gdscript
var loaded := V2MapLoader.load_map(&"ch1_m1")
t.check(loaded.success, "M1 v3 地图加载")
var map: Dictionary = loaded.data
t.check(map.size == {"width": 22, "height": 16}, "M1 尺寸 22×16")
for id in ["spawn_assault", "rescue_scout", "evac_northeast", "camera_console_south",
        "camera_east", "optional_record", "landmark_crane"]:
    t.check(map.entities.any(func(e): return e.id == id), "存在稳定对象 %s" % id)
t.check(map.encounters.all(func(e): return int(e.active_cap) <= 3), "每个遭遇最多三名活跃敌人")
t.check(V2MapValidator.has_route(map, Vector2i(3,14), Vector2i(13,7)), "出生点可达营救点")
t.check(V2MapValidator.has_route(map, Vector2i(13,7), Vector2i(19,2)), "营救点可达撤离点")
```

- [x] **Step 2: 确认地图不存在而失败**

- [x] **Step 3: 按 Locked Layout Contract 写完整矩阵和对象**

`layers` 必须有 16 行、每行 22 项的 `base_terrain/blocker/vision/height/cover`。遭遇 A 初始激活南侧两敌；进入以 `(13,7)` 为中心半径 5 的触发区激活营救两敌；营救完成且进入 `(16,5)` 触发区后激活撤离敌人；事故记录哨兵只在西路进入 `(4,4)` 半径 4 时激活。任何组合同时不超过 3。

- [x] **Step 4: 运行地图验证、两路线寻路和 100 次固定加载哈希测试**

Expected: 100 次 JSON 规范化哈希一致，所有主目标可达。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m1.json tactical-grid/client/tests/v2
git commit -m "feat(v2): build M1 two-route graybox map"
```

### Task M103: 营救并撤离的主目标流

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_flow_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- States: `SEARCH_SCOUT/ESCORT_TO_EVAC/COMPLETE/FAILED`。
- Events: `mission_started/scout_rescued/unit_moved/unit_downed/evac_checked/primary_irreversible_failure`。

- [x] **Step 1: 写主目标状态转换测试**

```gdscript
flow.setup(mission, map, [assault], enemies)
t.check(flow.get_primary_text() == "找到失联侦察兵", "开场目标简短")
t.check(not flow.apply_event(&"evac_checked").get("victory", false), "未营救不能撤离胜利")
flow.apply_event(&"scout_rescued", {"character_id": "scout"})
t.check(flow.get_primary_text() == "带侦察兵抵达撤离点", "营救后目标更新")
flow.apply_event(&"unit_moved", {"unit_id": "assault", "position": Vector2i(19,2)})
flow.apply_event(&"unit_moved", {"unit_id": "scout", "position": Vector2i(18,2)})
t.check(flow.apply_event(&"evac_checked").victory, "两名存活角色进入撤离区后胜利")
```

- [x] **Step 2: 确认现有 infiltrate 强制上传流程已被 V2 主目标替换**

- [x] **Step 3: 实现单一主目标状态机**

```gdscript
func apply_event(event_name: StringName, payload: Dictionary = {}) -> Dictionary:
    match event_name:
        &"scout_rescued":
            if state != State.SEARCH_SCOUT: return _fail(&"invalid_transition")
            rescued_characters["scout"] = true
            state = State.ESCORT_TO_EVAC
        &"evac_checked":
            if state != State.ESCORT_TO_EVAC: return {"success": true, "victory": false}
            if _all_conscious_players_in_evac(): state = State.COMPLETE
        &"unit_downed":
            if _all_controlled_players_downed(): state = State.FAILED
        _: return _fail(&"unknown_event")
    return {"success": true, "victory": state == State.COMPLETE, "defeat": state == State.FAILED}
```

- [x] **Step 4: 运行非法转换、全队失能、部分失能和撤离测试**

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): implement rescue and extraction flow"
```

### Task M104: 侦察兵营救和同关加入

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_rescue_character_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_rescue_battle_integration_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_rescue_battle_integration_test.tscn`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/data/game_data.gd`
- Modify: `tactical-grid/client/scripts/game/turn_manager.gd`
- Modify: `tactical-grid/client/scripts/v2/combat/v2_action_service.gd`
- Modify: `tactical-grid/client/tests/v2/v2_player_turn_e2e_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2RescueController.query_rescue(actor: Unit, rescue_id: StringName) -> Dictionary`、`V2RescueController.commit_rescue(preview: Dictionary) -> Dictionary`。
- Rescue preview cost: `{action=true}`；result includes `new_unit: Unit` and `character_id="scout"`。

- [x] **Step 1: 写相邻营救与立即可选测试**

```gdscript
var preview := rescue.query_rescue(assault, "rescue_scout")
t.check(preview.valid and preview.cost.action, "相邻突击可营救")
var result := rescue.commit_rescue(preview)
t.check(result.success and result.character_id == "scout", "营救成功")
t.check(battle.player_units.size() == 2, "侦察兵加入当前任务")
t.check(result.new_unit.v2_turn_state.can_move() and result.new_unit.v2_turn_state.can_act(), "加入时获得完整本回合")
t.check(not battle.v2_action_service.query_action({"action": &"attack", "unit": assault, "target": captive}).valid,
    "未营救对象不能被攻击")
```

- [x] **Step 2: 确认当前地图无可营救角色而失败**

- [x] **Step 3: 实现环境保护、角色创建和系统注册**

营救前显示侦察轮廓和名字但不属于任何战斗阵营。提交后从 `V2Data.get_character("scout")` 创建 Unit，稳定 ID 为 `player_scout`，注册 ActionService、Visibility、TurnManager、UnitSprite 和 HUD；触发 `scout_rescued` 并保存检查点。重复营救返回 `already_rescued`。

- [x] **Step 4: 运行营救距离、重复提交、检查点恢复和存档测试**

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/data/game_data.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): rescue scout into active squad"
```

### Task M105: 摄像头和事故记录可选目标

**Executor:** Terra high；Sol xhigh 复核状态事务。

**Files:**
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/record_handler.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_interaction_test.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/handlers/camera_handler.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m1.json`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Camera action ID: `view_camera_east`，reveals zone `camera_east_zone` until disabled。
- Record action ID: `upload_incident_record`，one-time optional completion and module `scout_b` reward flag。

- [x] **Step 1: 写摄像头揭示和可选记录测试**

```gdscript
var camera_actions := service.query_actions(assault, "camera_console_south")
t.check(camera_actions[0].id == "view_camera_east", "摄像头操作明确")
var camera_result := service.commit_action(assault, &"view_camera_east", "camera_console_south")
t.check(camera_result.success and visibility.is_cell_observed(Vector2i(15,5)), "摄像头揭示东区")
var record := service.commit_action(scout, &"upload_incident_record", "optional_record")
t.check(record.success and flow.optional_complete, "事故记录完成可选目标")
t.check(not flow.is_victory(), "可选目标不直接完成主线")
```

- [x] **Step 2: 确认 V2 主线不恢复旧的强制上传流程**

- [x] **Step 3: 实现两个具体操作**

事故记录要求任意存活角色相邻并消耗行动；完成后只设置 `optional_record_uploaded=true`，不锁撤离。摄像头控制台允许查看并在侦察模块 B 装备时额外关闭摄像头一回合。结果卡明确显示持续时间与警戒影响。

- [x] **Step 4: 运行完成/跳过两条 M1 路径和重复交互测试**

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/interaction tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): add M1 camera and optional record"
```

### Task M106: 哨兵、无人机和分批激活

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_encounter_activation.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_enemy_activation_test.gd`
- Modify: `tactical-grid/client/scripts/data/game_data.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2EncounterActivation.update(player_positions: Array[Vector2i], mission_events: Array[Dictionary]) -> Dictionary` with `activated_ids/deactivated_ids/active_count`。

- [x] **Step 1: 写六敌总数、三敌上限和角色意图测试**

```gdscript
t.check(activation.get_total_enemy_ids().size() == 6, "M1 固定六名敌人")
var start := activation.update([Vector2i(3,14)], [])
t.check(start.active_count == 2, "开场激活南区两敌")
var rescue := activation.update([Vector2i(12,8)], [])
t.check(rescue.active_count <= 3, "进入营救区仍不超过三敌")
t.check(brain.plan_intent(drone, ctx).type == &"scan", "无人机优先扫描")
t.check(brain.plan_intent(sentry, ctx).type in [&"move", &"attack"], "哨兵巡逻或攻击")
```

- [x] **Step 2: 确认旧 V1 敌人队伍不再直接进入 V2 正式战斗**

- [x] **Step 3: 实现遭遇激活和稳定优先级**

未激活敌人以稳定实体 ID 保留在 V2 数据和运行时队伍中，但不进入存活单位、精灵、行动服务和可见性集合；新激活敌人按遭遇阶段替换集合，任意阶段最多三名。敌人行为职责由既有 `V2EnemyBrain` 合同提供：哨兵近距离优先攻击，无人机优先扫描。

- [x] **Step 4: 模拟两条路线并断言任意帧活跃数不超过三**

验证结果：M106 独立合同 18/18；玩家回合真实输入 38/38；救援正式场景 13/13；完整 V2 门禁通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_encounter_activation.gd tactical-grid/client/scripts/data/game_data.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): stage M1 enemy encounters"
```

### Task M107: M1 潜伏/搜索警戒和即时迷雾

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_m1_stealth_state_test.gd`
- Modify: `tactical-grid/client/scripts/game/alert_state.gd`
- Modify: `tactical-grid/client/scripts/game/visibility_state.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Front states: `hidden/searching` mapped from backend 0/1；M1 backend level cannot exceed 1。

- [x] **Step 1: 写非自动增长和 M1 上限测试**

```gdscript
alert.setup({"front_stage_cap": 1, "story_grace_events": 0})
for turn in range(1, 6): alert.on_turn_end()
t.check(alert.get_alert_level() == 0, "警戒不随回合自动增长")
alert.apply_event("camera_identified_player")
t.check(alert.get_alert_level() == 1, "摄像头识别进入搜索")
alert.apply_event("camera_identified_player")
t.check(alert.get_alert_level() == 1, "M1 不进入封锁")
```

- [x] **Step 2: 确认旧警戒按回合或可升至 3 的行为被 V2 配置隔离**

- [x] **Step 3: 增加任务配置上限和具体下一后果**

M1 事件只有摄像头完整识别和无人机扫描完成可升警戒，后端上限为搜索级；HUD 潜伏时显示“被识别后进入搜索”，搜索时显示“巡逻路线已改变”；不显示封锁。移动、扫描和摄像头操作后立即刷新迷雾，并返回本次新增探索格和新揭示敌人摘要。故事难度首个识别事件宽限一次，标准难度不宽限。

- [x] **Step 4: 运行标准/故事难度首事件宽限与摄像头测试**

验证结果：M107 独立契约 16/16；V1 AlertState 17/17；V2 HUD 11/11；迷雾事务 9/9；玩家回合真实输入 41/41；救援集成 13/13；完整 V2 门禁通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/game/alert_state.gd tactical-grid/client/scripts/game/visibility_state.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): simplify M1 stealth states"
```

### Task M108: 六步行为教学

**Executor:** Terra high；Sol high 复核触发顺序。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_tutorial_flow.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_tutorial_test.gd`
- Modify: `tactical-grid/client/scripts/ui/tutorial_hint.gd`
- Modify: `tactical-grid/client/scenes/tutorial_hint.tscn`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Steps: `select/move/attack/intent/camera/evac`。
- Produces: `V2TutorialFlow.on_event(name: StringName, payload: Dictionary) -> Dictionary` with `show_hint/dismiss_hint/completed_step`。

- [x] **Step 1: 写顺序、字数和一次一条测试**

```gdscript
var flow := V2TutorialFlow.new()
t.check(flow.current_step() == &"select", "首先教学选择")
t.check(flow.current_text().length() <= 28, "提示不超过 28 字")
t.check(not flow.on_event(&"unit_moved").advanced, "未选择不能跳过步骤")
t.check(flow.on_event(&"unit_selected").advanced, "完成选择后推进")
t.check(flow.current_step() == &"move", "第二步教学移动")
t.check(flow.get_visible_hint_count() <= 1, "一次只显示一条")
```

- [x] **Step 2: 确认现有长键位列表或点击继续叠加问题失败**

- [x] **Step 3: 实现行为触发短提示**

固定文案：`点击突击兵查看可行动范围`、`点击蓝色格移动`、`红色敌人可攻击，再点一次确认`、`箭头显示敌人下一步`、`靠近控制台查看摄像头`、`两名队员进入撤离区`。完成行为立即消失；只在首次需要时暂停一次；跳过教学仅关闭提示，不改变规则。

- [x] **Step 4: 运行新档、跳过教学和 UI 重叠测试**

实际结果：M108 教学流合同 31/31；V1 教学/HUD 合同 136/136；V2 玩家回合真实输入 41/41；救援场景 13/13；完整 V2 门禁通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。正式 `battle_hud_contract.tscn` 已确认新增上下文提示节点可挂载，教学提示不阻塞地图输入；Godot 退出时的临时场景资源回收警告仍由发布门禁按已知项排除，不计为异常失败。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_tutorial_flow.gd tactical-grid/client/scripts/ui/tutorial_hint.gd tactical-grid/client/scenes/tutorial_hint.tscn tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): teach M1 through player actions"
```

提交边界：`v2_tutorial_flow.gd` 只负责六步行为状态，不改变战斗规则；`tutorial_hint.gd` 和 `tutorial_hint.tscn` 只新增 V2 上下文短提示与非阻塞跳过入口，V1 模态教学路径保持原样；`battle_controller.gd` 在真实选择、移动、攻击、敌人意图、摄像头和撤离事件上推进教学。未把教学完成误当作 H1 首次玩家验收。

### Task M109: 失败、检查点和三种重试出口

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_m1_retry_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_retry_scene_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_retry_scene_test.tscn`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_checkpoint_adapter.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/network/save_manager.gd`
- Modify: `tactical-grid/client/scripts/ui/mission_result.gd`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Checkpoints: task start, `scout_rescued`, `evac_route_opened`。
- Failure actions: `retry_checkpoint/restart_mission/return_base`。

- [x] **Step 1: 写稳定点保存和失败菜单测试**

```gdscript
battle.emit_mission_event_for_test(&"scout_rescued")
t.check(not SaveManager.get_encounter_checkpoint(GameManager.current_save).is_empty(), "营救后写检查点")
battle.force_all_players_downed_for_test()
t.check(battle.mission_flow.is_defeat(), "全队失能失败")
t.check(result_screen.has_action(&"retry_checkpoint"), "提供检查点重试")
t.check(result_screen.has_action(&"restart_mission"), "提供重新开始")
t.check(result_screen.has_action(&"return_base"), "提供返回基地")
```

- [x] **Step 2: 复现动作未完成时写快照或菜单缺按钮问题**

- [x] **Step 3: 只在玩家稳定控制点写检查点**

检查 `TurnManager` 为玩家阶段、输入不是动画/对话/暂停、无待执行表现事件。检查点重试恢复所有 V2 状态；重新开始清检查点并加载地图初始状态；返回基地不结算奖励且保留任务未完成。

- [x] **Step 4: 运行三种出口、损坏检查点回退和营救后恢复测试**

实际结果：M109 纯合同 15/15；正式结算/战斗重试场景 14/14；V2 检查点合同 13/13；营救集成 13/13；玩家回合 41/41；完整 V2 门禁通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。正式 battle 已验证快照恢复位置、生命、行动状态、警戒、迷雾和任务阶段；损坏或无法恢复的快照会清除并安全回到 `cp_start`，不会卡死在失败页。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission tactical-grid/client/scripts/ui/mission_result.gd tactical-grid/client/scenes/mission_result.tscn tactical-grid/client/scripts/game/game_manager.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): close M1 failure and retry flow"
```

提交边界：V2 通过 `SaveManager` 的游戏线分流和 `GameManager` 专属 API 写入顶层 `encounter_checkpoint`，不再把 V2 检查点写进 V1 `campaign_progress`；结算页只负责出口与跳转，快照恢复由 `BattleController`、`V2CheckpointAdapter`、`V2MissionFlow` 和营救状态共同完成。V1 失败、V1 检查点和 V1 结算路径保持原行为。

### Task M110: 基地解锁、编队、模块和结算

**Executor:** Terra high。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_squad_selection.gd`
- Create: `tactical-grid/client/scripts/v2/mission/v2_module_loadout.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_progression_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_base_progression_scene_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_base_progression_scene_test.tscn`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd`
- Modify: `tactical-grid/client/scripts/ui/base_controller.gd`
- Modify: `tactical-grid/client/scenes/base.tscn`
- Modify: `tactical-grid/client/scripts/ui/character_panel.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/mission_result.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2SquadSelection.get_available_characters(save: Dictionary) -> Array[String]`。
- Produces: `V2SquadSelection.validate_squad(mission: Dictionary, character_ids: Array[String]) -> Dictionary`。
- Produces: `V2ModuleLoadout.equip(save: Dictionary, character_id: StringName, module_id: StringName) -> Dictionary`。

- [x] **Step 1: 写 M1 完成后的角色和模块测试**

```gdscript
var save := V2CampaignProgress.create_default()
V2CampaignProgress.complete_mission(save, &"ch1_m1", {"rescued": ["scout"], "optional_record": true})
t.check(save.rescued_characters == ["assault", "scout"], "侦察永久加入")
t.check("scout_a" in save.unlocked_modules and "scout_b" in save.unlocked_modules, "侦察 A/B 模块按条件解锁")
t.check(save.current_mission == "ch1_m2", "完成后解锁 M2")
t.check(V2SquadSelection.validate_squad(V2Data.get_mission(&"ch1_m2"), ["assault", "scout"]).valid,
    "M2 固定两人编队有效")
t.check(V2ModuleLoadout.equip(save, &"scout", &"scout_b").success, "已解锁侦察模块可装备")
t.check(not V2ModuleLoadout.equip(save, &"scout", &"assault_b").success, "突击模块不能装给侦察")
```

- [x] **Step 2: 确认旧基地仍显示商店、军械库和六属性而失败**

- [x] **Step 3: 收口基地流程**

基地只显示短对话、下一任务、队员、模块和开始。隐藏商店、军械库、信用点、技能树和六属性柱；角色面板显示身份、HP、移动、射程、被动、主动和当前模块。M1 结算显示主目标、可选记录、侦察加入和新模块。

- [x] **Step 4: 运行完成/跳过可选目标、保存重启和基地 UI 合同**

验证结果：M110 进度合同 16/16；基地/角色面板/结算正式场景合同 24/24；V2 玩家真实输入 41/41；营救场景 13/13；M109 重试合同 15/15、正式场景 14/14；完整 V2 release gate 通过，V1 稳定断言 1816、失败 0，意外警告/错误 0。V2 基地复用原有外壳但隐藏旧商店、军械库、信用点、六属性和技能树；队员编队、模块装备和结算摘要使用 V2 独立数据与存档字段。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission tactical-grid/client/scripts/ui/base_controller.gd tactical-grid/client/scenes/base.tscn tactical-grid/client/scripts/ui/character_panel.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): unlock scout through M1 progression"
```

提交结果：`feat(v2): unlock scout through M1 progression`。

### Task M111: M1 短对话和事故记录

**Executor:** Terra high。

**Files:**
- Modify: `tactical-grid/client/data/v2/dialogues.json`
- Modify: `tactical-grid/client/data/v2/missions.json`
- Create: `tactical-grid/client/tests/v2/v2_m1_dialogue_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_dialogue_scene_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_dialogue_scene_test.tscn`
- Modify: `tactical-grid/client/scripts/ui/dialogue_system.gd`
- Modify: `tactical-grid/client/scripts/ui/base_controller.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Dialogue IDs: `ch1_m1_brief/ch1_m1_intro/ch1_m1_rescue/ch1_m1_record/ch1_m1_outro`。

- [x] **Step 1: 写节点数、字数和选项可点击测试**

```gdscript
for id in ["ch1_m1_brief", "ch1_m1_intro", "ch1_m1_rescue", "ch1_m1_record", "ch1_m1_outro"]:
    var lines := V2Data.get_dialogue(StringName(id)).get("lines", [])
    t.check(not lines.is_empty(), "%s 有正式内容" % id)
t.check(V2Data.get_dialogue(&"ch1_m1_brief").lines.size() <= 6, "战前不超过六节点")
t.check(V2Data.get_dialogue(&"ch1_m1_outro").lines.size() <= 8, "战后不超过八节点")
t.check(V2Data.get_dialogue(&"ch1_m1_record").full_text.length() <= 120, "记录不超过 120 字")
```

- [x] **Step 2: 确认 F03 空对话数组导致失败**

- [x] **Step 3: 写入正式短文本并绑定事件**

剧情内容只解释失联、侦察兵被困、数据哨兵正在观察设施和两人撤离，不一次介绍后五关系统。对话头像位于右侧安全区，选项始终在头像左下且可点击；不显示“点击继续”覆盖选项。

- [x] **Step 4: 运行对话布局和两选项输入合同；720p/1080p 全视觉快照统一由 M112 矩阵生成**

验证结果：空数据 RED 合同失败 15 项；填入内容后 M111 对话内容合同 29/29、正式对话场景合同 7/7；M110 基地场景 24/24；V2 玩家真实输入 41/41；营救场景 13/13；重试场景 14/14；完整 V2 release gate 通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。战前简报提供两个可点击方针；V2 选项写入独立 `story_flags`；V2 存档优先读取 `V2Data`，缺失时不回退到 V1；营救和事故记录事件分别显示短对话。

- [x] **Step 5: 提交**

```powershell
git add tactical-grid/client/data/v2/dialogues.json tactical-grid/client/scripts/ui/dialogue_system.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): write concise M1 narrative"
```

提交结果：`feat(v2): write concise M1 narrative`。

### Task M112: M1 自动 E2E 和视觉矩阵

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_m1_e2e_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_e2e_test.tscn`
- Create: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`
- Create: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.tscn`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- E2E test routes: `main_direct/optional_record/checkpoint_retry`。
- Snapshot stages: `start/selected/attack_preview/rescue/evac/dialogue/result`。

- [ ] **Step 1: 写从新档到 M2 解锁的失败 E2E**

测试使用公开输入和行动事务，不直接设置 `mission_flow.state`。主路线选择突击、移动、攻击、查看意图、使用摄像头、营救、切换侦察、撤离；可选路线额外上传记录；重试路线在营救后失能并恢复检查点。

- [ ] **Step 2: 运行三条路线并记录首个真实失败点**

Expected initial failure 必须来自未接通的流程或数据，不允许通过测试内直接改状态绕过。

- [ ] **Step 3: 只修复 E2E 揭示的集成缺口**

每个修复先增加对应局部断言；不要在本任务增加新机制。

- [ ] **Step 4: 生成视觉矩阵并运行完整门**

生成 1280×720 与 1920×1080、normal/grayscale/deuteranopia_assist 的七阶段截图到 `artifacts/v2/verification/m1-graybox/screenshots/`。检查图像非空、尺寸正确、主目标可见、范围颜色与形状存在、无 UI 超界。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tests/v2 tactical-grid/client/scripts tactical-grid/client/data/v2
git commit -m "test(v2): cover complete M1 graybox flow"
```

### Task M113: 首次玩家记录工具

**Executor:** Terra high。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_playtest_recorder.gd`
- Create: `tactical-grid/client/tests/v2/v2_playtest_recorder_test.gd`
- Create: `docs/v2/playtests/M1_FIRST_PLAYER_PROTOCOL.md`
- Create: `docs/v2/playtests/M1_FIRST_PLAYER_FORM.md`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Recorder events: `session_started/unit_selected/move_committed/attack_committed/hint_shown/stuck_marked/scout_rescued/mission_failed/mission_completed/session_ended`。
- Output examples: `user://playtests/m1/P01.json`、`P02.json`、`P03.json`，不含姓名、账号或系统隐私数据。

- [ ] **Step 1: 写时间戳和匿名字段测试**

```gdscript
var recorder := V2PlaytestRecorder.new()
recorder.start("P01", "standard")
recorder.record(&"unit_selected", {"unit_id": "player_assault"})
recorder.finish({"would_continue": true})
var data := recorder.get_session()
t.check(data.participant_id == "P01", "只保存匿名编号")
t.check(data.events[0].elapsed_ms >= 0, "保存相对时间")
t.check(not data.has("player_name") and not data.has("machine_name"), "不收集身份信息")
```

- [ ] **Step 2: 确认记录器不存在而失败**

- [ ] **Step 3: 实现本地匿名记录和两份人工表格**

协议明确：不给口头指导；记录 30 秒选择、90 秒移动、3 分钟攻击、蓝红范围解释、意图解释、迷雾、营救、撤离、总时长、卡住次数和继续意愿。测试者签署是否允许录屏；不同意录屏时只填写事件表。

- [ ] **Step 4: 用负责人自测一局验证文件写入和汇总脚本**

负责人自测只验证记录工具，不计入 H1 三名首次玩家样本。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_playtest_recorder.gd tactical-grid/client/tests/v2 docs/v2/playtests
git commit -m "test(v2): add M1 first-player protocol"
```

### Task H1: 三名首次玩家门

**Executor:** 项目负责人组织三名从未接触 V1/V2 的真实玩家；AI 负责整理数据，不能替代玩家。

**Files:**
- Output only: `artifacts/v2/verification/h1/P01.json`
- Output only: `artifacts/v2/verification/h1/P02.json`
- Output only: `artifacts/v2/verification/h1/P03.json`
- Output only: `artifacts/v2/verification/h1/H1_SUMMARY.md`

**Acceptance:**

- [ ] 三名玩家均未得到口头操作指导。
- [ ] 每人 30 秒内知道应选择突击兵。
- [ ] 每人 90 秒内完成首次移动。
- [ ] 每人 3 分钟内独立完成首次攻击。
- [ ] 每人能解释蓝色、红色和敌方箭头。
- [ ] 每人观察到移动后迷雾立即揭开。
- [ ] 每人能营救侦察兵并撤离，或失败后能独立重试。
- [ ] 每人首次流程在 12-18 分钟目标附近；超出时记录具体卡点。
- [ ] 至少两人选择“愿意继续 M2”。
- [ ] 没有人因攻击方式、攻击范围或结束回合永久卡住。

若同一概念有一名玩家连续卡住两次，创建一个 `fix(v2)` 任务并先写复现测试。所有硬指标满足后在 `H1_SUMMARY.md` 写 `decision: PASS`；否则写 `decision: FAIL` 和返回的任务编号。

### Task M114: H1 修正和 M1 灰盒锁

**Executor:** Sol xhigh。

**Files:**
- Modify: H1 揭示问题对应的最小代码、测试或文案文件
- Modify: `docs/superpowers/plans/2026-08-05-v2-master-implementation.md`
- Modify: `tactical-grid/PROJECT_STATUS_V2.md`

**Interfaces:**
- Produces milestone: `m1_graybox_locked=true` 仅存在于状态文档，不写入运行时存档。

- [ ] **Step 1: 为 H1 每个失败概念建立自动复现测试**

例如两名玩家未理解第一次点击只预览时，测试必须断言 HUD 文案含“再次点击确认”且目标不扣血。

- [ ] **Step 2: 运行测试确认在修复前失败**

- [ ] **Step 3: 做最小交互、布局或教学修正**

不得通过增加常驻动作栏、长键位说明或跳过规则来取得指标。

- [ ] **Step 4: 重测受影响玩家概念并运行完整 V2 门**

H1 原样本保持不改；补测使用 `P04` 起的新编号。最终 `H1_SUMMARY.md` 必须明确 PASS，Godot 门 0 失败、0 非预期错误/警告。

- [ ] **Step 5: 提交并锁定灰盒**

```powershell
git add tactical-grid/client docs/v2/playtests docs/superpowers/plans/2026-08-05-v2-master-implementation.md tactical-grid/PROJECT_STATUS_V2.md
git commit -m "feat(v2): lock validated M1 graybox"
```

H1 PASS 和 M114 提交完成后才允许执行 A02 之后的正式资源生产。P5 的正式表现出口由 A13-A14 完成。
