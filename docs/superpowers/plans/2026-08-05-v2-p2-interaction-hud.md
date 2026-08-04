# Tactical Grid V2 P2 Interaction and HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让玩家只用选择、地图点击、右键取消和 Space 结束回合就能完成一个清楚、可预览、不会陷入隐藏模式的完整玩家回合。

**Architecture:** `V2BattleInputRouter` 只解释输入，`V2ActionService` 决定合法性，`V2AffordancePresenter` 与 `V2HUDPresenter` 只显示结果，`BattleController` 负责连接信号和生命周期。每次提交行动后用同一事务刷新单位状态、范围、迷雾、意图和 HUD。

**Tech Stack:** Godot 4.7.1、GDScript、Control/CanvasLayer、Camera2D、headless 合同测试和真实窗口输入测试。

## Global Constraints

- 依赖 F01-F12 全部通过；不在 P2 修改 M1 正式目标、美术或后五关内容。
- 左键角色后同时显示蓝色移动范围和红色攻击范围；普通移动和攻击不依赖底部“移动/攻击”按钮。
- 安全移动一次点击提交；攻击第一次点击锁定预览，第二次点击同一目标提交。
- 右键取消当前预览并回到直接选择；Space 在玩家回合始终尝试结束回合。
- 中键拖动平移，滚轮缩放，Home 聚焦当前队员，Tab 切换仍可行动队员。
- HUD 始终显示当前输入状态、主目标、警戒后果和行动预算；不能只靠颜色表达状态。
- 每个任务先写失败测试，再实现、运行局部测试和 V2 完整门。

---

### Task I01: 明确输入状态机

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Create: `tactical-grid/client/tests/v2/v2_input_router_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces enum: `FREE_SELECT/UNIT_SELECTED/ATTACK_LOCKED/ABILITY_TARGETING/INTERACTION_MENU/ENEMY_TURN/PAUSED`。
- Produces signals: `cell_left_clicked(cell: Vector2i)`、`cell_hovered(cell: Vector2i)`、`cancel_requested()`、`end_turn_requested()`、`next_unit_requested()`、`focus_requested()`、`network_overlay_requested()`。
- Produces: `V2BattleInputRouter.set_state(next_state: int) -> Dictionary`、`V2BattleInputRouter.get_state_name() -> String`、`V2BattleInputRouter.handle_event(event: InputEvent, screen_to_cell: Callable) -> bool`。

- [ ] **Step 1: 写状态转换和输入消费测试**

```gdscript
var router := V2BattleInputRouter.new()
t.check(router.get_state_name() == "free_select", "初始为自由选择")
t.check(router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).success, "可进入攻击锁定")
var right := InputEventMouseButton.new()
right.button_index = MOUSE_BUTTON_RIGHT
right.pressed = true
t.check(router.handle_event(right, Callable()), "右键被路由器消费")
t.check(router.get_state_name() == "unit_selected", "右键退回单位选择")
router.set_state(V2BattleInputRouter.State.ENEMY_TURN)
t.check(not router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED).success, "敌方回合拒绝玩家预览")
```

- [ ] **Step 2: 确认测试因输入路由类不存在而失败**

Run: `& $godotExe --headless --path . --script res://tests/v2/v2_input_router_test.gd`

- [ ] **Step 3: 实现允许转换表和输入映射**

```gdscript
extends Node
class_name V2BattleInputRouter

enum State { FREE_SELECT, UNIT_SELECTED, ATTACK_LOCKED, ABILITY_TARGETING,
    INTERACTION_MENU, ENEMY_TURN, PAUSED }

const TRANSITIONS := {
    State.FREE_SELECT: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
    State.UNIT_SELECTED: [State.FREE_SELECT, State.ATTACK_LOCKED, State.ABILITY_TARGETING,
        State.INTERACTION_MENU, State.ENEMY_TURN, State.PAUSED],
    State.ATTACK_LOCKED: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
    State.ABILITY_TARGETING: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
    State.INTERACTION_MENU: [State.UNIT_SELECTED, State.ENEMY_TURN, State.PAUSED],
    State.ENEMY_TURN: [State.FREE_SELECT, State.UNIT_SELECTED, State.PAUSED],
    State.PAUSED: [State.FREE_SELECT, State.UNIT_SELECTED, State.ENEMY_TURN],
}
```

`handle_event` 处理左/右/中键、滚轮和 InputMap 动作；中键拖动与滚轮只发镜头信号，不改变战术状态。每次拒绝转换返回 `{success=false, reason=&"illegal_transition"}`。

- [ ] **Step 4: 运行输入测试并加入 V2 门**

Expected: 所有允许/拒绝转换、右键、Space、Tab、Home、G 和敌方回合输入锁通过。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/input tactical-grid/client/tests/v2
git commit -m "feat(v2): add explicit battle input states"
```

### Task I02: 选择后同时显示移动和攻击范围

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd`
- Create: `tactical-grid/client/tests/v2/v2_affordance_contract_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scenes/battle.tscn`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2AffordancePresenter.show_for_unit(unit: Unit, move_query: Dictionary, attack_query: Dictionary) -> void`。
- Produces: `V2AffordancePresenter.show_path(path: Array[Vector2i], dangerous: bool) -> void`、`clear_preview() -> void`、`clear_all() -> void`。
- Uses groups: `v2_move_overlay`、`v2_attack_overlay`、`v2_path_overlay`、`v2_danger_overlay`。

- [ ] **Step 1: 写选择呈现合同**

```gdscript
battle.select_unit_for_test(battle.player_units[0])
await process_frame
t.check(battle.get_tree().get_nodes_in_group("v2_move_overlay").size() > 0, "选择后显示蓝色移动格")
t.check(battle.get_tree().get_nodes_in_group("v2_attack_overlay").size() > 0, "选择后同时显示红色攻击格")
t.check(battle.hud.get_context_prompt_text().contains("蓝色") and
    battle.hud.get_context_prompt_text().contains("红色"), "文字解释两种范围")
```

- [ ] **Step 2: 确认现有场景只显示一种范围或缺少 V2 分组**

- [ ] **Step 3: 实现独立叠层和控制器连接**

```gdscript
func show_for_unit(unit: Unit, move_query: Dictionary, attack_query: Dictionary) -> void:
    clear_all()
    for cell in move_query.get("reachable", {}).keys():
        _spawn_cell(cell, MOVE_COLOR, "v2_move_overlay", "M")
    for cell in attack_query.get("range_cells", []):
        _spawn_cell(cell, ATTACK_COLOR, "v2_attack_overlay", "A")
    for target in attack_query.get("targets", []):
        _outline_target(target, ATTACK_COLOR)
```

蓝色格带箭头纹理，红色格带准星纹理，保证灰度仍可区分。`BattleController._select_unit` 改为查询 V2ActionService 的 move/attack 无目标预览并调用 presenter；单位移动或行动后重新查询。

- [ ] **Step 4: 运行 720p/1080p 选择合同和灰度快照**

Expected: 两种叠层同时存在且不遮挡单位、意图和设施。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scenes/battle.tscn tactical-grid/client/tests/v2
git commit -m "feat(v2): show movement and attack affordances"
```

### Task I03: 左键安全移动

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_direct_move_input_test.gd`
- Modify: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `BattleController.request_move(cell: Vector2i) -> Dictionary`。
- Safe result: `{success=true, committed=true}`；dangerous result: `{success=true, committed=false, confirmation_required=true, preview}`。

- [ ] **Step 1: 写无需底部按钮的移动测试**

```gdscript
var unit: Unit = battle.player_units[0]
battle.select_unit_for_test(unit)
var destination := battle.first_safe_reachable_cell_for_test(unit)
var result := battle.request_move(destination)
t.check(result.success and result.committed, "蓝色安全格一次点击移动")
t.check(unit.grid_pos == destination, "单位到达目标格")
t.check(not unit.v2_turn_state.move_available, "移动机会消耗")
t.check(unit.v2_turn_state.action_available, "行动机会保留")
t.check(not battle.hud.move_button.visible, "不依赖移动按钮")
```

- [ ] **Step 2: 确认现有逻辑需要 move 模式或按钮而失败**

- [ ] **Step 3: 将地图左键路由到 V2 移动事务**

```gdscript
func request_move(cell: Vector2i) -> Dictionary:
    if selected_unit == null:
        return {"success": false, "reason": &"no_selected_unit"}
    var preview := v2_action_service.query_action({"action": &"move", "unit": selected_unit, "target": cell})
    if not preview.get("valid", false):
        return {"success": false, "reason": preview.get("reason", &"invalid_move")}
    if preview.get("dangerous", false):
        v2_input_router.set_state(V2BattleInputRouter.State.UNIT_SELECTED)
        return {"success": true, "committed": false, "confirmation_required": true, "preview": preview}
    return v2_action_service.commit_action(preview)
```

移动动画结束后同一事务刷新单位位置、迷雾、意图、行动预算、范围和 HUD。点击非蓝格不消费状态，并显示原因。

- [ ] **Step 4: 运行安全、危险、不可达和已移动测试**

Expected: 安全移动一次点击；危险移动仅一次确认；重复移动返回 `move_spent`。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/input tactical-grid/client/scripts/v2/presentation tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): enable direct map movement"
```

### Task I04: 悬停、锁定和二次确认攻击

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_attack_input_test.gd`
- Modify: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_affordance_presenter.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `request_attack_preview(target: Unit) -> Dictionary`、`confirm_locked_attack(target: Unit) -> Dictionary`。
- Locked target is identified by stable `entity_id`, not node reference alone.

- [ ] **Step 1: 写两次点击和精确预览测试**

```gdscript
var hp_before := target.current_hp
var first := battle.request_attack_preview(target)
t.check(first.valid and battle.v2_input_router.get_state_name() == "attack_locked", "第一次点击锁定预览")
t.check(target.current_hp == hp_before, "第一次点击不造成伤害")
t.check(battle.hud.get_attack_preview_text().contains("%d → %d" % [first.hp_before, first.hp_after]), "显示生命变化")
var second := battle.confirm_locked_attack(target)
t.check(second.success and target.current_hp == first.hp_after, "第二次点击同目标提交")
t.check(not attacker.v2_turn_state.action_available, "攻击消费行动")
```

- [ ] **Step 2: 确认现有攻击按钮/隐藏模式合同失败**

- [ ] **Step 3: 实现稳定目标锁定**

```gdscript
func request_attack_preview(target: Unit) -> Dictionary:
    var preview := v2_action_service.query_action({"action": &"attack", "unit": selected_unit, "target": target})
    if not preview.get("valid", false):
        hud.show_action_reason(preview.get("reason", &"invalid_attack"))
        return preview
    _locked_attack_preview = preview
    v2_input_router.set_state(V2BattleInputRouter.State.ATTACK_LOCKED)
    v2_hud_presenter.show_attack_preview(preview)
    return preview

func confirm_locked_attack(target: Unit) -> Dictionary:
    if String(_locked_attack_preview.get("target_id", "")) != target.entity_id:
        return request_attack_preview(target)
    return v2_action_service.commit_action(_locked_attack_preview)
```

悬停只显示临时预览；离开目标清除临时卡但保留已锁定卡。点击另一个红色敌人改锁定对象，不直接开火。

- [ ] **Step 4: 运行悬停、双击、换目标、右键和陈旧预览测试**

Expected: 没有攻击按钮依赖；失去视线、目标移动或行动已消耗时第二次点击被拒绝并刷新范围。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/input tactical-grid/client/scripts/v2/presentation tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): add preview-first attack input"
```

### Task I05: 具体场景交互菜单

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/interaction/v2_interaction_service.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/camera_handler.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/door_handler.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/power_handler.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/rail_handler.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/beacon_handler.gd`
- Create: `tactical-grid/client/scripts/v2/interaction/handlers/boss_terminal_handler.gd`
- Create: `tactical-grid/client/tests/v2/v2_interaction_service_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces main plan `query_actions` and `commit_action`。
- Action dictionary: `{id, label, consequence, duration_turns, raises_alert, enabled, reason}`。

- [ ] **Step 1: 写最多两个自然语言操作测试**

```gdscript
var actions := service.query_actions(scout, "camera_east")
t.check(actions.size() <= 2, "单设施最多两个操作")
t.check(actions[0].label == "查看东侧摄像头", "操作名称描述对象")
t.check(actions[0].consequence.contains("揭示"), "提交前说明结果")
t.check(actions[0].has("raises_alert"), "提交前说明警戒影响")
```

- [ ] **Step 2: 确认现有通用接管菜单不满足合同**

- [ ] **Step 3: 实现类型处理器和 HUD 操作卡**

```gdscript
func query_actions(actor: Unit, entity_id: String) -> Array[Dictionary]:
    var facility := _facilities_by_id.get(entity_id, {})
    if facility.is_empty(): return []
    var handler: RefCounted = _handlers.get(StringName(facility.get("type", "")), null)
    if handler == null: return []
    return handler.query(actor, facility, _context).slice(0, 2)
```

提交先验证相邻/范围、行动预算和设施 revision；成功消费行动并通过 `TacticalNetworkState` 后端改变状态。HUD 显示按钮标签、结果、持续时间和警戒图标。

- [ ] **Step 4: 运行六处理器合同和旧网络状态测试**

Expected: 摄像头、门、电力、轨道、信标、Boss 终端均有明确结果；`tactical_network_state_test.tscn` 通过。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/interaction tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): expose contextual facility actions"
```

### Task I06: 右键取消、Space 结束回合和状态恢复

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_cancel_end_turn_test.gd`
- Modify: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/turn_manager.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `cancel_current_preview() -> Dictionary`、`request_end_turn() -> Dictionary`。

- [ ] **Step 1: 写每种状态取消和结束回合测试**

```gdscript
for state in [V2BattleInputRouter.State.ATTACK_LOCKED,
        V2BattleInputRouter.State.ABILITY_TARGETING,
        V2BattleInputRouter.State.INTERACTION_MENU]:
    battle.v2_input_router.set_state(state)
    t.check(battle.cancel_current_preview().success, "右键取消 %s" % state)
    t.check(battle.v2_input_router.get_state_name() == "unit_selected", "取消回到单位选择")
var end_result := battle.request_end_turn()
t.check(end_result.success, "玩家回合可结束")
t.check(not battle.request_end_turn().success, "敌方回合拒绝重复结束")
```

- [ ] **Step 2: 复现结束回合按钮无响应或动作条消失问题**

- [ ] **Step 3: 统一清理和阶段切换**

`cancel_current_preview` 清除攻击锁、能力目标、交互卡、路径和危险确认，但保留选中单位及其范围。`request_end_turn` 在阻断对话/暂停时返回可读原因，否则锁输入、清预览、提交 TurnManager。敌方回合结束后选择第一名 `move_available || action_available` 的存活队员并重建 HUD。

- [ ] **Step 4: 运行真实 Space 输入、按钮点击和敌方回合恢复测试**

Expected: 两种入口行为一致；敌方行动后底部能力/交互/结束回合区域恢复。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/input tactical-grid/client/scripts/game tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2
git commit -m "fix(v2): unify cancel and end turn flow"
```

### Task I07: 中键平移、滚轮缩放和 Home 聚焦

**Executor:** Terra high。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_camera_input_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_camera_controller.gd`
- Modify: `tactical-grid/client/scripts/v2/input/v2_battle_input_router.gd`
- Modify: `tactical-grid/client/scripts/game/input_bindings.gd`
- Modify: `tactical-grid/client/project.godot`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `BattleCameraController.begin_drag(screen_pos: Vector2) -> void`、`drag_to(screen_pos: Vector2) -> void`、`end_drag() -> void`。
- Produces: `BattleCameraController.zoom_at(direction: float, anchor: Vector2) -> void`、`focus_cell(cell: Vector2i) -> void`。

- [ ] **Step 1: 写镜头输入不改变战术状态测试**

```gdscript
var before_state := router.get_state_name()
camera.begin_drag(Vector2(500, 300))
camera.drag_to(Vector2(450, 260))
camera.end_drag()
t.check(camera.position != Vector2.ZERO, "中键拖动改变镜头")
t.check(router.get_state_name() == before_state, "镜头拖动不改变战术状态")
var before_zoom := camera.zoom
camera.zoom_at(1, Vector2(640, 360))
t.check(camera.zoom != before_zoom, "滚轮改变缩放")
```

- [ ] **Step 2: 确认地图拖动缺失的合同失败**

- [ ] **Step 3: 接入拖动、缩放、边界和聚焦**

中键拖动速度使用屏幕差值除以 zoom；缩放范围保留 `0.65-1.5`；地图小于视口时居中，大于视口时限制不露出大面积空白。Home 聚焦选中队员，Tab 切换后只在“减少动态”关闭时平滑跟随。

- [ ] **Step 4: 运行 720p/1080p 边界、缩放锚点和减少动态测试**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/game/battle_camera_controller.gd tactical-grid/client/scripts/v2/input tactical-grid/client/scripts/game/input_bindings.gd tactical-grid/client/project.godot tactical-grid/client/tests/v2
git commit -m "feat(v2): add direct battle camera controls"
```

### Task I08: UI 方向 3 HUD 和状态提示

**Executor:** Terra high；Sol xhigh 审核信息层级。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd`
- Create: `tactical-grid/client/tests/v2/v2_hud_contract_test.gd`
- Modify: `tactical-grid/client/scenes/battle.tscn`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `render(snapshot: Dictionary) -> void`。
- Snapshot keys: `turn/phase/state/primary_objective/alert/next_consequence/selected/context_prompt/action_budget/ability/interaction/attack_preview`。

- [ ] **Step 1: 写 HUD 内容和布局合同**

```gdscript
presenter.render({"turn": 2, "phase": "玩家回合", "state": "attack_locked",
    "primary_objective": "找到侦察兵并撤离", "alert": "潜伏",
    "next_consequence": "被摄像头识别后进入搜索", "selected": unit,
    "context_prompt": "再次点击哨兵，造成 2 点伤害", "action_budget": {"move": true, "action": true}})
t.check(hud.objective_label.text == "找到侦察兵并撤离", "顶部只有一句主目标")
t.check(hud.context_label.text.contains("再次点击"), "当前状态有文字提示")
t.check(hud.action_budget_label.text.contains("移动") and hud.action_budget_label.text.contains("行动"), "显示两项预算")
t.check(not hud.move_button.visible and not hud.attack_button.visible, "不显示常驻移动攻击按钮")
```

- [ ] **Step 2: 确认现有 HUD 暴露旧动作栏或缺少状态文本**

- [ ] **Step 3: 实现紧凑区域和响应式布局**

顶部左回合/阶段、中央目标、右侧警戒/后果；右侧信息卡无对象时折叠；底部左操作提示；底部中只显示唯一能力、当前交互和结束回合。720p 下不遮挡地图中心 60% 区域，1080p 下不无意义拉伸。

- [ ] **Step 4: 运行 720p、1080p、150% 文字和长中文合同**

Expected: 无裁切、重叠、超界；状态名称始终可见。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_hud_presenter.gd tactical-grid/client/scenes/battle.tscn tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): implement compact contextual HUD"
```

### Task I09: 精确伤害和命中表现

**Executor:** Terra high；Sol high 复核事件顺序。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_damage_presenter.gd`
- Create: `tactical-grid/client/tests/v2/v2_damage_presentation_test.gd`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `play_attack(events: Array[Dictionary], reduce_motion: bool) -> void`。
- Events: `attack_started/hp_prestrip/damage_number/reduction/shield_absorb/unit_downed/attack_finished`。

- [ ] **Step 1: 写事件顺序和显示文本测试**

```gdscript
var events := presenter.build_events(preview, result)
t.check(events.map(func(e): return e.type) == [&"attack_started", &"hp_prestrip",
    &"reduction", &"damage_number", &"attack_finished"], "伤害反馈顺序固定")
t.check(events.any(func(e): return e.get("text", "") == "掩体 -1"), "显示掩体减伤")
t.check(events.any(func(e): return e.get("text", "") == "2"), "显示最终伤害数字")
```

- [ ] **Step 2: 确认现有伤害反馈不能精确解释减伤**

- [ ] **Step 3: 实现 0.15 秒内启动的表现流水线**

普通反馈使用 UnitSprite 的 `attack/hit/down` 状态和现有音频；HP 预切除条先显示目标值，再提交最终值。掩体、护甲和护盾使用不同图标、文字与声音。减少动态模式保留闪光、文字和声音，关闭镜头位移和单位受击位移。

- [ ] **Step 4: 运行无掩体、半掩体、护甲、护盾和倒地合同**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_damage_presenter.gd tactical-grid/client/scripts/game/unit_sprite.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): present exact damage outcomes"
```

### Task I10: 移动后同事务迷雾刷新

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_visibility_transaction_test.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/visibility_state.gd`
- Modify: `tactical-grid/client/scripts/game/visibility_renderer.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `BattleController.refresh_visibility_transaction(reason: StringName) -> Dictionary`。

- [ ] **Step 1: 写移动完成前后可见性合同**

```gdscript
var hidden_cell := Vector2i(8, 4)
t.check(battle.visibility_state.get_cell_state(hidden_cell) == &"unexplored", "移动前未知")
var result := battle.request_move(Vector2i(6, 4))
t.check(result.success, "移动成功")
t.check(battle.visibility_state.get_cell_state(hidden_cell) == &"observed", "移动返回前已揭示")
t.check(battle.visibility_renderer.get_render_state_for_cell(hidden_cell) == &"visible", "渲染状态同步")
```

- [ ] **Step 2: 复现必须等下一帧或下一回合才揭示的问题**

- [ ] **Step 3: 统一可见性事务顺序**

提交移动后顺序固定为：更新单位位置→计算玩家视野→合并受控摄像头→更新 VisibilityState→刷新敌人可见性与最后已知位置→刷新 renderer→重新规划新揭示敌人安全意图→返回移动结果。不得用延迟计时器补刷新。

- [ ] **Step 4: 运行移动、摄像头启停、离开视野和敌人幽灵合同**

Expected: 同一输入事务结束前状态一致；离开视野只保留问号最后位置。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/game/visibility_state.gd tactical-grid/client/scripts/game/visibility_renderer.gd tactical-grid/client/tests/v2
git commit -m "fix(v2): refresh fog within movement transaction"
```

### Task I11: 设置、键位、文字缩放和视觉模式

**Executor:** Terra high。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_visual_mode.gd`
- Create: `tactical-grid/client/tests/v2/v2_settings_contract_test.gd`
- Modify: `tactical-grid/client/scripts/ui/settings_menu.gd`
- Modify: `tactical-grid/client/scenes/settings_menu.tscn`
- Modify: `tactical-grid/client/scripts/game/accessibility_settings.gd`
- Modify: `tactical-grid/client/scripts/game/input_bindings.gd`
- Modify: `tactical-grid/client/project.godot`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Visual modes exact IDs: `normal/grayscale/deuteranopia_assist`。
- Text scales exact values: `1.0/1.25/1.5`。
- Input actions: `pause/end_turn/next_unit/focus_unit/toggle_network`。

- [ ] **Step 1: 写默认值、保存和应用合同**

```gdscript
var defaults := V2VisualMode.default_settings()
t.check(defaults.ui_scale == 1.0, "默认文字 100%")
t.check(defaults.visual_mode == "normal", "默认普通视觉")
var story := defaults.duplicate(true)
story.ui_scale = 1.5
story.visual_mode = "grayscale"
V2VisualMode.apply(story)
t.check(V2VisualMode.current_ui_scale() == 1.5, "应用 150% 文字")
t.check(V2VisualMode.current_mode() == &"grayscale", "应用灰度检查")
```

- [ ] **Step 2: 确认现有布尔大字和四种色盲选项不符合固定规格**

- [ ] **Step 3: 收口为三档文字和三种视觉模式**

设置包含窗口/全屏、分辨率、UI 文字缩放、三路音量、平移速度、震动、减少动态、视觉模式和键位。删除 hard 难度和不在规格中的视觉模式前台选项；保存仍写入 V2 独立配置。恢复默认值使用确认对话。

- [ ] **Step 4: 运行重启持久化、键位冲突和 150% UI 合同**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_visual_mode.gd tactical-grid/client/scripts/ui/settings_menu.gd tactical-grid/client/scenes/settings_menu.tscn tactical-grid/client/scripts/game/accessibility_settings.gd tactical-grid/client/scripts/game/input_bindings.gd tactical-grid/client/project.godot tactical-grid/client/tests/v2
git commit -m "feat(v2): align settings and accessibility"
```

### Task I12: P2 真实输入集成门

**Executor:** Sol xhigh；Terra xhigh 独立审查。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_player_turn_e2e_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_player_turn_e2e_test.tscn`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/action_system.gd`
- Modify: `tactical-grid/client/scripts/ui/hud.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Modify: `tactical-grid/PROJECT_STATUS_V2.md`

**Interfaces:**
- Produces: 正式玩家普通移动与攻击只经过 `V2ActionService`。
- Keeps: 旧 ActionSystem 只供尚未迁移的技能/物品测试，不再由 V2 HUD 暴露。

- [ ] **Step 1: 写完整玩家回合场景测试**

测试实例化 `battle.tscn`，依次发送真实 `InputEventMouseButton`：左键角色、左键蓝格、悬停敌人、两次左键敌人、中键拖动、滚轮、右键、Space。断言选择状态、位置、精确 HP、行动预算、迷雾、镜头、敌方回合和下一玩家回合 HUD。

- [ ] **Step 2: 运行并确认仍有旧按钮或旧模式调用时失败**

Expected failure 必须明确指出 `legacy_action_mode_used`、`move_button_visible` 或 `state_not_restored` 中的实际一项。

- [ ] **Step 3: 切换正式输入并停止注册旧前台动作**

`BattleController._unhandled_input` 只转发给 V2 router；删除普通流程对 `on_move_button/on_attack_button/on_item_button/on_overwatch_button` 的连接。旧函数可以暂留供继承测试，但 V2 HUD 不创建对应可见按钮。每次事件完成后调用单一 `_refresh_v2_presentation()`。

- [ ] **Step 4: 运行 P2 全门和真实窗口检查**

Run: Godot 无头导入、完整 V2 门。随后以窗口模式启动 M1，使用鼠标键盘完整执行两个玩家回合，记录 `artifacts/v2/verification/p2/input-session.md` 和 720p/1080p 截图。

Expected: 0 测试失败、0 非预期错误/警告；不点击任何移动/攻击按钮即可完成；结束回合后动作区恢复。

- [ ] **Step 5: 提交和阶段记录**

```powershell
git add tactical-grid/client/scripts/game tactical-grid/client/scripts/ui/hud.gd tactical-grid/client/tests/v2 tactical-grid/PROJECT_STATUS_V2.md
git commit -m "feat(v2): complete direct player turn interaction"
```

更新主计划 I01-I12 为完成。P2 通过后才开始 M101；若真人操作仍无法在三分钟内独立攻击，问题归入 M108/H1，不恢复旧大动作栏。
