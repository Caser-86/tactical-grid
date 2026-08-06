# V2 Shared Mission Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 V2 的目标阶段、营救、遭遇队列、设施状态、危险区和检查点统一为可复用且向后兼容的任务基础。

**Architecture:** `V2MissionFlow` 读取任务数据中的 `objective_steps`，用稳定事件推进阶段；`V2EncounterActivation` 管理 active、waiting、defeated、departed 四类敌人状态；`V2InteractionService` 和新增危险区服务提供可序列化状态；`V2CheckpointAdapter` 保存并恢复所有状态。旧 M1 v3 数据和旧 `scout_rescued` 事件继续可读。

**Tech Stack:** Godot 4.7.1、GDScript、V2 JSON、Godot SceneTree 单元测试。

## Global Constraints

- 事件必须幂等或返回明确拒绝原因。
- 活跃敌人总数不超过遭遇的 `active_cap`，默认上限为 3。
- 任何遇敌切换不得删除仍存活敌人的状态。
- 保存使用 `game_line = "v2_infiltration"`，不读取 V1 存档。
- 所有新增公共方法必须有脚本测试或场景测试。

---

### Task 1: 写共享状态合同测试

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_mission_flow_contract_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_encounter_queue_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_hazard_controller_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Tests consume `V2MissionFlow`, `V2EncounterActivation`, `V2HazardController`, `V2CheckpointAdapter`.
- Later tasks must satisfy `get_current_step_id()`, `get_objective_step_index()`, `get_objective_step_count()`, `mark_enemy_defeated()`, `get_waiting_enemy_ids()`, `get_snapshot()`, `restore_snapshot()`.

- [ ] **Step 1: 写阶段数据合同的失败测试**

构造含两个 `objective_steps` 的任务，断言 `setup()` 从第一阶段开始，`get_objective_step_count()` 返回 2，提交第一阶段的 `complete_event` 后 `get_current_step_id()` 变为第二阶段，并返回 `step_index`、`step_count`。

- [ ] **Step 2: 写遭遇队列的失败测试**

构造四名敌人、两个遭遇且 `active_cap=3`；先启动第一遭遇并击倒一名敌人，再触发第二遭遇。断言仍存活的旧敌人保留在 `active_ids`，新敌人进入 `waiting_ids`，击倒敌人进入 `defeated_ids`。

- [ ] **Step 3: 写危险区和检查点失败测试**

断言危险区在喷发前一个完整玩家回合返回 `warning_cells`，喷发后返回 `active_cells`；构造 schema 3 的 M1 检查点，断言可迁移到 schema 4 且保留玩家、敌人和旧阶段。

- [ ] **Step 4: 运行新增测试确认当前实现失败**

Run from `tactical-grid/client`:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Expected: FAIL because generic objective steps, waiting IDs and `V2HazardController` do not yet exist.

- [ ] **Step 5: 将测试加入 V2 门禁**

在 `gate_manifest.json` 的 `script_tests` 中加入四个新脚本，保持它们位于现有 M1 测试之前。

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/tests/v2/v2_mission_flow_contract_test.gd tactical-grid/client/tests/v2/v2_encounter_queue_test.gd tactical-grid/client/tests/v2/v2_hazard_controller_test.gd tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "test(v2): define shared mission foundation contracts"
```

### Task 2: 数据驱动目标阶段和通用营救

**Files:**
- Modify: `tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd`
- Modify: `tactical-grid/client/data/v2/missions.json`
- Test: `tactical-grid/client/tests/v2/v2_mission_flow_contract_test.gd`

**Interfaces:**
- Add `get_current_step_id() -> String`.
- Add `get_objective_step_index() -> int` and `get_objective_step_count() -> int`.
- Add `get_current_guide_text() -> String`.
- `apply_event(event_name: StringName, payload: Dictionary) -> Dictionary` accepts `character_rescued` and legacy `scout_rescued`; result includes `step_id`, `step_index`, `step_count`.
- `V2RescueController.commit_rescue()` emits `character_rescued` with `character_id` and keeps `scout_rescued` only as a compatibility alias.

- [ ] **Step 1: 以阶段 ID 替代固定 M1 enum**

在 `setup()` 读取 `mission.objective_steps`；无该字段时构造旧 M1 的 `search_scout` 和 `escort_to_evac` 两阶段。保留 `get_state_name()` 返回旧名称，新增方法返回稳定阶段 ID。

- [ ] **Step 2: 为事件推进加入幂等和依赖检查**

只在当前阶段的 `complete_event` 与事件名相同、`required_flags` 满足时推进；重复事件返回 `success=false, reason="event_already_completed"`；未知事件返回 `reason="unknown_event"`。每次成功推进返回 `step_id`、`guide_text` 和可写入的 `checkpoint_id`。

- [ ] **Step 3: 把营救事件改成通用事件**

在 `V2RescueController.commit_rescue()` 提交 `character_rescued`；任务流拒绝时回滚新 Unit、行动点、地图 captive 状态。旧测试提交 `scout_rescued` 时得到相同阶段结果。

- [ ] **Step 4: 写回 M1/M2 阶段数据**

在 `missions.json` 为 M1 写入 `search_scout -> escort_scout -> evacuate`，为 M2 写入 `disable_lockdown -> rescue_sniper -> evacuate_squad`。每项包含 `objective_text`、`guide_text`、`complete_event`、`checkpoint_id` 和 `required_flags`。

- [ ] **Step 5: 运行合同测试和现有 M1 流程测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
```

Expected: PASS; old `SEARCH_SCOUT` compatibility assertions remain valid.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_mission_flow.gd tactical-grid/client/scripts/v2/mission/v2_rescue_controller.gd tactical-grid/client/data/v2/missions.json tactical-grid/client/tests/v2/v2_mission_flow_contract_test.gd
git commit -m "feat(v2): generalize mission stages and rescue events"
```

### Task 3: 遭遇等待队列和击倒持久化

**Files:**
- Modify: `tactical-grid/client/scripts/v2/mission/v2_encounter_activation.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Test: `tactical-grid/client/tests/v2/v2_encounter_queue_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_enemy_occupancy_test.gd`

**Interfaces:**
- Add `mark_enemy_defeated(entity_id: String) -> Dictionary`.
- Add `mark_enemy_departed(entity_id: String) -> Dictionary`.
- Add `get_waiting_enemy_ids() -> Array` and `get_defeated_enemy_ids() -> Array`.
- Change `update(player_positions, mission_events, live_enemy_ids = []) -> Dictionary` to return `active_ids`, `waiting_ids`, `defeated_ids`, `activated_ids`, `deactivated_ids`.
- Add controller method `_apply_encounter_delta(delta: Dictionary) -> void` that only spawns waiting/activated enemies into free cells and never frees live units.

- [ ] **Step 1: 分离状态集合**

维护 `_active_ids`、`_waiting_ids`、`_defeated_ids` 和 `_departed_ids`。`_apply_encounter()` 只把新敌人放入 waiting，再由 `_promote_waiting(live_enemy_ids)` 按稳定 ID 顺序填充空位。

- [ ] **Step 2: 保留旧地图字段并加入入口信息**

继续接受 `active_enemy_ids`，新增可选 `spawn_cells` 和 `retreat_cells`。若没有入口数据，使用敌人原始位置；若入口被占用，敌人保持 waiting 并返回 `spawn_cell_occupied`。

- [ ] **Step 3: 在敌人被击倒时登记状态**

战斗控制器检测 `enemy.is_alive` 从 true 变为 false 时调用 `mark_enemy_defeated()`；精灵隐藏、尸体占位释放、队列更新必须在同一个刷新事务内完成。

- [ ] **Step 4: 在遭遇变化时应用差量**

删除当前会把 `_active_ids` 直接替换成新集合的行为。`_apply_encounter_delta()` 对 `deactivated_ids` 只记录离场；对仍活着的敌人保留 Unit；对 `activated_ids` 通过稳定出生点生成；超过三名的敌人进入 waiting。

- [ ] **Step 5: 运行遭遇和占位测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
```

Expected: PASS; no live enemy disappearance, no resurrection, no player/enemy shared cell.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_encounter_activation.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_encounter_queue_test.gd tactical-grid/client/tests/v2/v2_enemy_occupancy_test.gd
git commit -m "feat(v2): persist encounter queue and defeated enemies"
```

### Task 4: 设施快照、确定性危险区和检查点迁移

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_hazard_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_checkpoint_adapter.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Test: `tactical-grid/client/tests/v2/v2_hazard_controller_test.gd`
- Test: `tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd`

**Interfaces:**
- `V2HazardController.setup(hazard_data: Array, map_size: Vector2i) -> void`.
- `V2HazardController.advance_player_turn(turn: int) -> Dictionary` returns `warning_cells`, `active_cells`, `closed`, `cycle`.
- `V2HazardController.get_snapshot() -> Dictionary` and `restore_snapshot(snapshot: Dictionary) -> Dictionary`.
- `V2InteractionService.get_snapshot() -> Dictionary` and `restore_snapshot(snapshot: Dictionary) -> Dictionary`.
- `V2CheckpointAdapter.capture()` stores `encounter_state`, `hazard_state`, and `facility_state` in addition to current fields.

- [ ] **Step 1: 写危险区控制器**

每个喷口记录 `warning_turns = 1`、固定 `damage`、固定 `cells` 和 `close_action_id`。预告阶段返回 `warning_cells`，敌方阶段只对 `active_cells` 结算一次；`close_action_id` 后 `closed=true`，后续周期不再生成危险格。

- [ ] **Step 2: 为设施服务加入快照**

序列化每个设施的 `id`、`type`、`state`、`used_actions`、`revision`，恢复时拒绝未知设施 ID、重复 action 和旧 revision；成功恢复后递增 `_state_revision` 并返回 `restored=true`。

- [ ] **Step 3: 扩展检查点字段和旧数据迁移**

`SCHEMA_VERSION` 升至 4；读取 schema 3 时将 `cp_start/cp_rescue/cp_pre_evac` 映射到当前任务对应的稳定 ID，补空的 encounter/hazard/facility 状态，不丢失 Unit、击倒和任务阶段。V1 `game_line` 仍拒绝。

- [ ] **Step 4: 把恢复流程接到战斗控制器**

恢复顺序固定为地图加载、Unit 恢复、遭遇恢复、设施恢复、危险区恢复、任务流恢复、视觉刷新；任一步失败返回基地错误面板，不进入缺少目标的战斗场景。

- [ ] **Step 5: 运行危险区和迁移测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_hazard_controller_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_checkpoint_migration_test.gd
```

Expected: PASS; danger cells are visible one full player turn before damage, and v3 M1 checkpoints remain readable.

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_hazard_controller.gd tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd tactical-grid/client/scripts/v2/mission/v2_checkpoint_adapter.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_hazard_controller_test.gd tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd
git commit -m "feat(v2): add deterministic hazards and checkpoint state"
```

### Task 5: 共享 HUD 状态接口

**Files:**
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_objective_hud_contract_test.gd`

**Interfaces:**
- Snapshot fields: `mission_id`, `step_id`, `step_index`, `step_count`, `objective_text`, `guide_text`, `route_hint`, `hazard_warning`, `checkpoint_id`.
- `V2HudPresenter.render(snapshot: Dictionary) -> void` remains the sole presentation entry point.
- `hud.render_v2_snapshot(snapshot: Dictionary)` displays current step and next concrete action without opening a modal dialog.

- [ ] **Step 1: 写 HUD 合同测试**

构造含 `step_index=2`、`step_count=10`、`guide_text="前往冷却控制室"` 的 snapshot，断言目标栏和底栏分别包含步骤计数与具体动作。

- [ ] **Step 2: 扩展快照构建**

在战斗控制器的 `_render_v2_hud()` 统一写入新字段；不再从 `get_state_name()` 推断 M2 目标。

- [ ] **Step 3: 扩展 HUD 排版和提示优先级**

优先级为任务失败/胜利、当前目标、危险区预告、路线提示、普通操作提示。长文本截断前先降低字号，不能覆盖战场中央。

- [ ] **Step 4: 运行 HUD 测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_objective_hud_contract_test.gd
```

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_objective_hud_contract_test.gd
git commit -m "feat(v2): expose objective progress in HUD snapshots"
```

### Task 6: 共享基础回归门

**Files:**
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Modify: `tactical-grid/client/tests/v2/README.md`

- [ ] **Step 1: 运行所有当前 V2 脚本门禁**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

Expected: existing V2 gate and new shared foundation tests all pass.

- [ ] **Step 2: 记录 A 阶段边界**

在 `tests/v2/README.md` 记录 schema 4、旧 schema 3 迁移、活跃/等待/击倒/撤离四态和公共方法名。

- [ ] **Step 3: Commit**

```powershell
git add tactical-grid/client/tests/v2/gate_manifest.json tactical-grid/client/tests/v2/README.md
git commit -m "test(v2): close shared mission foundation gate"
```
