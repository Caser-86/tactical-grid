# Tactical Grid V2 P1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 V2 可独立验证的数据、地图、存档、行动预算、确定性战斗、能力、检查点和敌方意图技术骨架。

**Architecture:** 新规则先作为 `scripts/v2/` 下的小型类实现并由独立测试直接调用，随后通过 F12 适配到现有 Godot 单例和战斗场景。旧系统在替代合同通过前保留，P1 不修改正式 M1 流程和美术。

**Tech Stack:** Godot 4.7.1、GDScript、JSON、PowerShell、Godot headless `--script` 测试。

## Global Constraints

- 分支必须是 `codex/ch1-infiltration-v2`，Godot 用户目录必须以 `TacticalGrid_V2_Infiltration` 结尾。
- 新代码、数据和测试分别只写入 `res://scripts/v2/`、`res://data/v2/`、`res://tests/v2/`；必要适配才修改现有文件。
- 每人每回合一次移动和一次行动，基础攻击确定命中并精确预览。
- 第一章数据只有四名玩家角色、五类通用敌人、猎手和 Boss；不读取 V1 职业、物品和武器作为运行时权威。
- 每个任务先运行失败测试，再实现、运行局部测试和 `tests/v2/run_v2_gate.ps1`。
- 每个任务独立提交，不修改 V1 文档、存档和发布目录。

---

## Shared Test Pattern

所有 P1 脚本测试使用相同入口：

```gdscript
extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
var t := Runner.new()

func _initialize() -> void:
    t.check(true, "example")
    t.finish(self)
```

PowerShell 命令从 `tactical-grid/client` 运行：

```powershell
$godotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
& $godotExe --headless --path . --script res://tests/v2/gate_manifest_test.gd
```

### Task F01: V2 发布门和共享测试运行器

**Executor:** Terra high；Sol high 复核 PowerShell 退出码。

**Files:**
- Create: `tactical-grid/client/tests/v2/test_runner.gd`
- Create: `tactical-grid/client/tests/v2/gate_manifest.json`
- Create: `tactical-grid/client/tests/v2/gate_manifest_test.gd`
- Create: `tactical-grid/client/tests/v2/run_v2_gate.ps1`
- Modify: `tactical-grid/client/tests/v2/README.md`

**Interfaces:**
- Produces: `V2TestRunner.check(condition: bool, message: String)`、`finish(tree: SceneTree)`。
- Produces: `gate_manifest.json` 中按顺序列出的 `script_tests`、`scene_tests` 和 `powershell_tests`。

- [ ] **Step 1: 写失败的门清单测试**

```gdscript
extends SceneTree

func _initialize() -> void:
    var file := FileAccess.open("res://tests/v2/gate_manifest.json", FileAccess.READ)
    if file == null:
        push_error("V2 gate manifest missing")
        quit(1)
        return
    var data = JSON.parse_string(file.get_as_text())
    var ok := data is Dictionary and data.has("script_tests") and data.has("scene_tests")
    if not ok:
        push_error("V2 gate manifest schema invalid")
    quit(0 if ok else 1)
```

- [ ] **Step 2: 确认测试因清单不存在而失败**

Run: `& $godotExe --headless --path . --script res://tests/v2/gate_manifest_test.gd`

Expected: exit code `1`，日志包含 `V2 gate manifest missing`。

- [ ] **Step 3: 实现共享运行器、初始清单和发布门**

```gdscript
extends RefCounted
class_name V2TestRunner

var passed := 0
var failed := 0

func check(condition: bool, message: String) -> void:
    if condition:
        passed += 1
        print("  [PASS] ", message)
    else:
        failed += 1
        print("  [FAIL] ", message)

func finish(tree: SceneTree) -> void:
    print("Passed: %d" % passed)
    print("Failed: %d" % failed)
    tree.quit(0 if failed == 0 else 1)
```

初始 `gate_manifest.json`：

```json
{
  "script_tests": [
    "res://tests/v2/user_data_path_probe.gd",
    "res://tests/v2/gate_manifest_test.gd"
  ],
  "scene_tests": [],
  "powershell_tests": ["tests/run_release_gate.ps1"]
}
```

`run_v2_gate.ps1` 必须逐项启动新进程、在任一非零退出码时立即退出 1，并在末尾输出 `V2 RELEASE GATE PASSED`。Godot 路径默认值固定为 `D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe`，同时保留 `-GodotExe` 参数覆盖。

- [ ] **Step 4: 验证清单测试和 V2 门通过**

Run: `& $godotExe --headless --path . --script res://tests/v2/gate_manifest_test.gd`

Run: `powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1`

Expected: 两个命令 exit code `0`；V2 门仍运行继承的 V1 发布门且失败数为 0。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tests/v2
git commit -m "test(v2): establish isolated release gate"
```

### Task F02: V2 数据仓库和模式校验

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/content/v2_data_repository.gd`
- Create: `tactical-grid/client/scripts/v2/content/v2_schema_validator.gd`
- Create: `tactical-grid/client/tests/v2/v2_data_repository_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2DataRepository.reload_all() -> Dictionary`，成功为 `{success=true}`，失败包含 `errors: Array[String]`。
- Produces: `V2DataRepository.get_character(id: StringName) -> Dictionary`、`get_enemy(id: StringName) -> Dictionary`、`get_ability(id: StringName) -> Dictionary`、`get_module(id: StringName) -> Dictionary`、`get_mission(id: StringName) -> Dictionary`、`get_dialogue(id: StringName) -> Dictionary`。
- Produces: `V2SchemaValidator.validate_all(documents: Dictionary) -> Array[String]`。

- [ ] **Step 1: 写失败的数据仓库测试**

```gdscript
extends SceneTree
const Runner = preload("res://tests/v2/test_runner.gd")
const Repository = preload("res://scripts/v2/content/v2_data_repository.gd")
var t := Runner.new()

func _initialize() -> void:
    var repo := Repository.new()
    var result := repo.reload_all()
    t.check(not bool(result.get("success", true)), "缺少正式数据时拒绝启动")
    t.check(repo.get_character(&"assault").is_empty(), "未知角色返回空字典")
    t.finish(self)
```

- [ ] **Step 2: 确认测试因仓库类不存在而失败**

Run: `& $godotExe --headless --path . --script res://tests/v2/v2_data_repository_test.gd`

Expected: parse error 指向 `v2_data_repository.gd` 不存在。

- [ ] **Step 3: 实现加载与引用校验**

```gdscript
extends Node
class_name V2DataRepository

const FILES := {
    "characters": "res://data/v2/characters.json",
    "enemies": "res://data/v2/enemies.json",
    "abilities": "res://data/v2/abilities.json",
    "modules": "res://data/v2/modules.json",
    "missions": "res://data/v2/missions.json",
    "dialogues": "res://data/v2/dialogues.json",
}

var _documents: Dictionary = {}
var _errors: Array[String] = []

func reload_all() -> Dictionary:
    _documents.clear()
    _errors.clear()
    for key in FILES:
        var file := FileAccess.open(FILES[key], FileAccess.READ)
        if file == null:
            _errors.append("Missing V2 data file: %s" % FILES[key])
            continue
        var parsed = JSON.parse_string(file.get_as_text())
        if not parsed is Dictionary:
            _errors.append("Invalid V2 JSON object: %s" % FILES[key])
            continue
        _documents[key] = parsed
    _errors.append_array(V2SchemaValidator.validate_all(_documents))
    return {"success": _errors.is_empty(), "errors": _errors.duplicate()}

func _get(kind: String, id: StringName) -> Dictionary:
    return _documents.get(kind, {}).get(String(id), {}).duplicate(true)
```

为六个公开 getter 调用 `_get`。校验器检查根键、重复 ID、角色引用的能力/模块、任务引用的地图/对话和模块解锁来源；错误字符串必须包含文件种类和 ID。

- [ ] **Step 4: 运行失败语义测试并加入发布门**

Run: `& $godotExe --headless --path . --script res://tests/v2/v2_data_repository_test.gd`

Expected: `Passed: 2`、`Failed: 0`。将测试路径追加到 `script_tests` 后运行 V2 门。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/content tactical-grid/client/tests/v2
git commit -m "feat(v2): add authoritative data repository"
```

### Task F03: 四角色、敌人、能力、模块和任务基础数据

**Executor:** Terra high；Sol xhigh 复核规格一致性。

**Files:**
- Create: `tactical-grid/client/data/v2/characters.json`
- Create: `tactical-grid/client/data/v2/enemies.json`
- Create: `tactical-grid/client/data/v2/abilities.json`
- Create: `tactical-grid/client/data/v2/modules.json`
- Create: `tactical-grid/client/data/v2/missions.json`
- Create: `tactical-grid/client/data/v2/dialogues.json`
- Create: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/v2_data_repository_test.gd`

**Interfaces:**
- Consumes: F02 数据仓库和校验器。
- Produces: 角色 ID `assault/scout/sniper/heavy`；敌人 ID `sentry/drone/sniper_sentry/shield_guard/protocol_engineer/hunter/data_sentinel`。

- [ ] **Step 1: 把数据测试改为要求完整固定集合**

```gdscript
var result := repo.reload_all()
t.check(bool(result.get("success", false)), "六份 V2 数据通过模式校验")
t.check([&"assault", &"scout", &"sniper", &"heavy"].all(
    func(id): return not repo.get_character(id).is_empty()), "四名角色齐全")
t.check(int(repo.get_character(&"assault").get("hp", 0)) == 7, "突击兵 HP 基线为 7")
t.check(int(repo.get_enemy(&"sentry").get("damage", 0)) == 2, "哨兵伤害基线为 2")
t.check(repo.get_mission(&"ch1_m6").get("boss_id", "") == "data_sentinel", "M6 引用数据哨兵")
```

- [ ] **Step 2: 确认测试因六份数据不存在而失败**

Expected: `reload_all.success == false`，错误列出六个 `res://data/v2/*.json`。

- [ ] **Step 3: 写入规格中的确定数据**

`characters.json` 单项格式：

```json
{
  "assault": {
    "name": "突击兵", "hp": 7, "move": 5, "vision": 5,
    "attack_range": [1, 3], "damage": 3, "armor": 0,
    "passive_id": "close_armor", "ability_id": "impact_advance",
    "module_ids": ["assault_a", "assault_b"], "art_key": "assault"
  }
}
```

其余三个角色严格使用总规格 9.3 与 10 节数值。`enemies.json` 写入五类敌人、猎手和 Boss 的 HP、移动、射程、伤害、职责与 `art_key`。`abilities.json` 固定四个主动能力的 `cooldown`、`range`、`radius`、`damage`、`push`、`shield`。`modules.json` 固定八个模块和 M1-M4 解锁来源。`missions.json` 写入 M1-M6 名称、地图 ID、编队、总敌人、活跃上限、主目标、可选目标和时长。`dialogues.json` 先建立每关 `brief/intro/rescue/outro` 空数组以满足引用，具体文案在 M111/C11 填充；空数组是合法初始数据，不作为发布完成内容。

- [ ] **Step 4: 运行数据测试和完整门**

Expected: 数据仓库无错误，四角色和固定 ID 断言通过；`run_v2_gate.ps1` exit 0。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/data/v2 tactical-grid/client/tests/v2/v2_data_repository_test.gd
git commit -m "feat(v2): define chapter one authoritative data"
```

### Task F04: schema v3 地图加载与校验

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/content/v2_map_loader.gd`
- Create: `tactical-grid/client/scripts/v2/content/v2_map_validator.gd`
- Create: `tactical-grid/client/tests/v2/v2_map_schema_test.gd`
- Create: `tactical-grid/client/data/v2/locked_maps/.gitkeep`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2MapLoader.load_map(map_id: StringName) -> Dictionary`。
- Produces: `V2MapValidator.validate(map_data: Dictionary) -> Dictionary` 返回 `{valid, errors, warnings}`。

- [ ] **Step 1: 写失败的 schema v3 验证测试**

```gdscript
var valid_map := {
    "schema_version": 3, "map_id": "test", "mission_id": "ch1_m1", "seed": 1,
    "size": {"width": 8, "height": 8},
    "layers": {"base_terrain": [], "blocker": [], "vision": [], "height": [], "cover": []},
    "entities": [
        {"id": "spawn_assault", "type": "spawn_player", "role": "assault", "x": 1, "y": 1},
        {"id": "evac", "type": "evac", "x": 6, "y": 6}
    ],
    "encounters": [], "checkpoints": [], "facilities": []
}
t.check(bool(V2MapValidator.validate(valid_map).get("valid", false)), "最小 v3 地图有效")
var duplicate := valid_map.duplicate(true)
duplicate.entities.append({"id": "evac", "type": "terminal", "x": 5, "y": 5})
t.check(not bool(V2MapValidator.validate(duplicate).get("valid", true)), "重复稳定 ID 被拒绝")
```

- [ ] **Step 2: 确认测试因 V2MapValidator 不存在而失败**

- [ ] **Step 3: 实现严格验证和加载**

```gdscript
extends RefCounted
class_name V2MapLoader

const ROOT := "res://data/v2/locked_maps/"

static func load_map(map_id: StringName) -> Dictionary:
    var path := ROOT + String(map_id) + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"success": false, "reason": &"map_missing", "path": path}
    var data = JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        return {"success": false, "reason": &"invalid_json", "path": path}
    var validation := V2MapValidator.validate(data)
    if not validation.valid:
        return {"success": false, "reason": &"invalid_schema", "validation": validation}
    return {"success": true, "data": data}
```

验证器必须检查：schema 恰为 3；尺寸与五个层矩阵一致；所有对象在边界内；ID 不重复；玩家出生点存在；主目标和撤离可达；检查点引用有效；每个遭遇激活数不超过任务上限；设施动作属于 `camera/door/power/rail/beacon/boss_terminal/record`；每条主路线至少有可达主目标。

- [ ] **Step 4: 运行地图测试并追加到发布门**

Expected: 有效地图、重复 ID、越界、不可达、未知设施和激活上限测试全部通过。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/content tactical-grid/client/data/v2/locked_maps tactical-grid/client/tests/v2
git commit -m "feat(v2): enforce locked map schema v3"
```

### Task F05: V2 存档身份和三槽恢复

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd`
- Create: `tactical-grid/client/tests/v2/v2_save_identity_test.gd`
- Modify: `tactical-grid/client/scripts/network/save_manager.gd`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: 存档字段 `game_line="v2_infiltration"`、`save_version="2.0.0"`。
- Produces: `V2CampaignProgress.create_default() -> Dictionary`、`V2CampaignProgress.validate(data: Dictionary) -> Dictionary`、`V2CampaignProgress.complete_mission(data: Dictionary, mission_id: StringName, result: Dictionary) -> Dictionary`。

- [ ] **Step 1: 写 V1 拒绝和 V2 默认存档测试**

```gdscript
var created := V2CampaignProgress.create_default()
t.check(created.get("game_line", "") == "v2_infiltration", "默认存档写入 V2 身份")
t.check(created.get("save_version", "") == "2.0.0", "默认存档版本为 2.0.0")
t.check(created.get("rescued_characters", []) == ["assault"], "新档只有突击兵")
var v1 := {"save_version": "1.0.0", "campaign_progress": {}}
t.check(not bool(V2CampaignProgress.validate(v1).get("valid", true)), "V1 存档被拒绝")
```

- [ ] **Step 2: 确认测试因 V2CampaignProgress 不存在而失败**

- [ ] **Step 3: 实现默认结构和 SaveManager 身份门**

```gdscript
static func create_default() -> Dictionary:
    return {
        "game_line": "v2_infiltration",
        "save_version": "2.0.0",
        "current_mission": "ch1_m1",
        "completed_missions": [],
        "rescued_characters": ["assault"],
        "unlocked_modules": ["assault_a"],
        "equipped_modules": {"assault": "assault_a"},
        "story_flags": {}, "settings": {}, "encounter_checkpoint": {},
        "statistics": {}, "chapter_complete": false
    }
```

`SaveManager._read_and_validate` 在 JSON 成功解析后先检查 `game_line`；缺失或不等于 `v2_infiltration` 返回空字典并记录明确拒绝原因。保留临时文件、备份恢复、未来版本拒绝和三个槽位。`GameManager.new_game` 改用 `V2CampaignProgress.create_default()`，不再创建 V1 资源、库存和技能树。

- [ ] **Step 4: 运行身份、损坏恢复和用户目录测试**

Run: V2 save test、`res://tests/save_recovery_test.tscn`、`user_data_path_probe.gd`。

Expected: V2 三槽读写与备份通过，V1 被拒绝，用户目录仍隔离。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd tactical-grid/client/scripts/network/save_manager.gd tactical-grid/client/scripts/game/game_manager.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): isolate campaign save identity"
```

### Task F06: 一次移动、一次行动和能力冷却状态

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/combat/v2_unit_turn_state.gd`
- Create: `tactical-grid/client/tests/v2/v2_unit_turn_state_test.gd`
- Modify: `tactical-grid/client/scripts/game/unit.gd`
- Modify: `tactical-grid/client/scripts/game/turn_manager.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `Unit.v2_turn_state: V2UnitTurnState`。
- Produces: `begin_turn/can_move/can_act/spend_move/spend_action/set_cooldown/get_cooldown/serialize/deserialize`。

- [ ] **Step 1: 写行动顺序和冷却测试**

```gdscript
var state := V2UnitTurnState.new()
state.begin_turn()
t.check(state.spend_action(), "可先行动")
t.check(state.spend_move(), "行动后仍可移动")
t.check(not state.spend_action(), "不能第二次行动")
state.set_cooldown(&"scan", 2)
state.begin_turn()
t.check(state.get_cooldown(&"scan") == 1, "下一回合冷却剩余一")
state.begin_turn()
t.check(state.get_cooldown(&"scan") == 0, "第三个玩家回合恢复")
```

- [ ] **Step 2: 确认测试因新类不存在而失败**

- [ ] **Step 3: 实现布尔行动预算**

```gdscript
extends RefCounted
class_name V2UnitTurnState

var move_available := true
var action_available := true
var cooldowns: Dictionary = {}

func begin_turn() -> void:
    move_available = true
    action_available = true
    for id in cooldowns.keys():
        cooldowns[id] = maxi(0, int(cooldowns[id]) - 1)

func spend_move() -> bool:
    if not move_available: return false
    move_available = false
    return true

func spend_action() -> bool:
    if not action_available: return false
    action_available = false
    return true
```

补齐查询、冷却和序列化。`Unit.setup` 创建状态；V2 路径的 `can_move/can_act` 读取该状态，保留旧字段仅供尚未迁移测试。`TurnManager` 在玩家回合开始调用存活角色 `v2_turn_state.begin_turn()`。

- [ ] **Step 4: 运行状态测试和旧 TurnManager 合同**

Expected: 移动→行动、行动→移动、重复消费、冷却和序列化全部通过；继承测试无回归。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/combat/v2_unit_turn_state.gd tactical-grid/client/scripts/game/unit.gd tactical-grid/client/scripts/game/turn_manager.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): add one-move one-action budget"
```

### Task F07: 确定性战斗和精确攻击预览

**Executor:** Sol xhigh；Terra xhigh 独立复核边界用例。

**Files:**
- Create: `tactical-grid/client/scripts/v2/combat/v2_combat_rules.gd`
- Create: `tactical-grid/client/tests/v2/v2_combat_rules_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2CombatRules.preview_attack(attacker: Unit, target: Unit, context: Dictionary) -> Dictionary`。
- Context exact keys: `has_los: bool`、`distance: int`、`cover: StringName`、`flanked: bool`、`state_revision: int`。

- [ ] **Step 1: 写确定性伤害矩阵测试**

```gdscript
var plain := V2CombatRules.preview_attack(attacker, target, {
    "has_los": true, "distance": 3, "cover": &"none", "flanked": false, "state_revision": 1})
t.check(plain.final_damage == 3 and plain.hp_after == 1, "无掩体造成固定三伤")
var half := V2CombatRules.preview_attack(attacker, target, {
    "has_los": true, "distance": 3, "cover": &"half", "flanked": false, "state_revision": 1})
t.check(half.cover_reduction == 1 and half.final_damage == 2, "半掩体减一")
var full := V2CombatRules.preview_attack(attacker, target, {
    "has_los": true, "distance": 3, "cover": &"full", "flanked": false, "state_revision": 1})
t.check(not full.valid and full.reason == &"full_cover", "全掩体阻挡正面攻击")
var flank := V2CombatRules.preview_attack(attacker, target, {
    "has_los": true, "distance": 3, "cover": &"full", "flanked": true, "state_revision": 1})
t.check(flank.valid and flank.final_damage == 3, "侧翼忽略掩体")
```

- [ ] **Step 2: 确认测试因规则类不存在而失败**

- [ ] **Step 3: 实现固定整数结算**

```gdscript
static func preview_attack(attacker: Unit, target: Unit, context: Dictionary) -> Dictionary:
    var distance := int(context.get("distance", -1))
    if not bool(context.get("has_los", false)):
        return {"valid": false, "reason": &"no_line_of_sight"}
    if distance < int(attacker.weapon_range[0]) or distance > int(attacker.weapon_range[1]):
        return {"valid": false, "reason": &"out_of_range"}
    var cover: StringName = context.get("cover", &"none")
    var flanked := bool(context.get("flanked", false))
    if cover == &"full" and not flanked:
        return {"valid": false, "reason": &"full_cover"}
    var base_damage := int(attacker.weapon_damage[0])
    var cover_reduction := 1 if cover == &"half" and not flanked else 0
    var armor_reduction := mini(maxi(0, target.armor), 2)
    var after_reduction := maxi(1, base_damage - cover_reduction - armor_reduction)
    var shield_absorb := mini(target.current_shield, after_reduction)
    var hp_damage := after_reduction - shield_absorb
    return {"valid": true, "base_damage": base_damage,
        "cover_reduction": cover_reduction, "armor_reduction": armor_reduction,
        "shield_absorb": shield_absorb, "final_damage": after_reduction,
        "hp_before": target.current_hp, "hp_after": maxi(0, target.current_hp - hp_damage),
        "state_revision": int(context.get("state_revision", 0)), "cost": {"action": true}}
```

补齐攻击者/目标 ID、护盾后生命、非法自身/同阵营/死亡目标、伤害最低 1 和无随机字段测试。

- [ ] **Step 4: 重复运行同一攻击 100 次**

Expected: 100 次预览 JSON 完全一致，不包含 `hit_chance`、`critical`、`dodge` 和随机浮动。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/combat/v2_combat_rules.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): add deterministic combat preview"
```

### Task F08: query-preview-validate-commit 行动服务

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/combat/v2_action_service.gd`
- Create: `tactical-grid/client/tests/v2/v2_action_service_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Consumes: F06 `V2UnitTurnState`、F07 `V2CombatRules`、现有 `Pathfinding/VisionSystem/GridSystem`。
- Produces: 主计划第 3 节 `V2ActionService` 五个接口。

- [ ] **Step 1: 写移动、攻击和陈旧预览测试**

```gdscript
var service := V2ActionService.new()
service.setup(map_data, [attacker], [target])
var move := service.query_action({"action": &"move", "unit": attacker, "target": Vector2i(2, 1)})
t.check(move.valid and move.preview_id > 0, "移动预览有效")
t.check(service.validate_action(move).valid, "未变化预览可提交")
var attack := service.query_action({"action": &"attack", "unit": attacker, "target": target})
target.grid_pos = Vector2i(7, 7)
t.check(service.validate_action(attack).reason == &"stale_preview", "目标变化后拒绝提交")
t.check(not attacker.v2_turn_state.action_available or not bool(service.commit_action(attack).success), "拒绝结果不消费第二次行动")
```

- [ ] **Step 2: 确认测试因服务类不存在而失败**

- [ ] **Step 3: 实现事务和状态修订号**

```gdscript
func query_action(request: Dictionary) -> Dictionary:
    match StringName(request.get("action", &"")):
        &"move": return _query_move(request)
        &"attack": return _query_attack(request)
        &"ability": return _query_ability(request)
        &"interaction": return _query_interaction(request)
        _: return {"valid": false, "reason": &"unknown_action"}

func validate_action(preview: Dictionary) -> Dictionary:
    var id := int(preview.get("preview_id", 0))
    if not _previews.has(id): return {"valid": false, "reason": &"unknown_preview"}
    if int(preview.get("state_revision", -1)) != _state_revision:
        return {"valid": false, "reason": &"stale_preview"}
    return {"valid": true}
```

`commit_action` 必须先验证，再消费一次预算并应用位置或精确伤害，成功后增加 `_state_revision`、删除预览并返回表现事件；失败不能改变 HP、位置、护盾、冷却或预算。双重提交返回 `already_committed`。

- [ ] **Step 4: 运行事务测试与继承 ActionSystem 合同**

Expected: V2 测试通过；旧 `action_system_test.tscn` 继续通过，直到 I12 正式切换调用方。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/combat/v2_action_service.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): add transactional action service"
```

### Task F09: 四角色能力、被动和八模块规则

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/combat/v2_ability_rules.gd`
- Create: `tactical-grid/client/tests/v2/v2_ability_rules_test.gd`
- Modify: `tactical-grid/client/scripts/v2/combat/v2_action_service.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2AbilityRules.query(actor: Unit, ability_id: StringName, target_data: Dictionary, context: Dictionary) -> Dictionary`。
- Produces: `V2AbilityRules.commit(actor: Unit, preview: Dictionary, context: Dictionary) -> Dictionary`。
- Produces: `V2AbilityRules.apply_passive(event_name: StringName, actor: Unit, context: Dictionary) -> Array[Dictionary]`。

- [ ] **Step 1: 写四个能力和模块参数测试**

```gdscript
t.check(V2AbilityRules.query(assault, &"impact_advance", {"position": Vector2i(4, 1)}, ctx).valid,
    "突击可直线推进三格")
t.check(V2AbilityRules.query(scout, &"area_scan", {"position": Vector2i(5, 5)}, ctx).reveal_radius == 3,
    "侦察扫描半径三")
t.check(V2AbilityRules.query(sniper, &"interrupt_shot", {"target_unit": enemy}, ctx).cancel_intent,
    "截断射击取消攻击意图")
t.check(V2AbilityRules.query(heavy, &"barrier_projection", {}, ctx).shield == 2,
    "屏障提供两点护盾")
```

- [ ] **Step 2: 确认测试因能力类不存在而失败**

- [ ] **Step 3: 实现数据驱动规则分派**

```gdscript
static func query(actor: Unit, ability_id: StringName, target_data: Dictionary, context: Dictionary) -> Dictionary:
    if actor.v2_turn_state.get_cooldown(ability_id) > 0:
        return {"valid": false, "reason": &"on_cooldown"}
    match ability_id:
        &"impact_advance": return _query_impact_advance(actor, target_data, context)
        &"area_scan": return _query_area_scan(actor, target_data, context)
        &"interrupt_shot": return _query_interrupt_shot(actor, target_data, context)
        &"barrier_projection": return _query_barrier(actor, context)
        _: return {"valid": false, "reason": &"unknown_ability"}
```

实现 A/B 模块参数覆盖、一次行动消费、冷却 2/3 回合、突击推开、侦察揭示与摄像头关闭、狙击固定 2 伤与意图取消、重装自身和相邻友军护盾。被动只响应具名事件：`turn_ended/enemy_revealed/before_attack_taken/before_attack_preview`。

- [ ] **Step 4: 运行能力矩阵和行动服务测试**

Expected: 每个能力合法、非法、冷却、模块 A、模块 B、序列化恢复均有通过断言。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/combat tactical-grid/client/tests/v2
git commit -m "feat(v2): implement four role abilities"
```

### Task F10: V2 检查点完整序列化

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/mission/v2_checkpoint_adapter.gd`
- Create: `tactical-grid/client/tests/v2/v2_checkpoint_test.gd`
- Modify: `tactical-grid/client/scripts/game/encounter_checkpoint_state.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2CheckpointAdapter.capture(context: Dictionary) -> Dictionary`、`V2CheckpointAdapter.validate(snapshot: Dictionary) -> Dictionary`、`V2CheckpointAdapter.restore(snapshot: Dictionary, context: Dictionary) -> Dictionary`。
- Checkpoint schema version fixed to `3`。

- [ ] **Step 1: 写往返等价测试**

```gdscript
var snapshot := V2CheckpointAdapter.capture(context)
t.check(snapshot.schema_version == 3, "V2 检查点 schema 为 3")
t.check(snapshot.player_units[0].turn_state.action_available == false, "保存行动状态")
t.check(snapshot.player_units[0].turn_state.cooldowns.area_scan == 2, "保存冷却")
var restored := V2CheckpointAdapter.restore(snapshot, fresh_context)
t.check(restored.success, "检查点恢复成功")
t.check(V2CheckpointAdapter.capture(fresh_context).hash == snapshot.hash, "恢复后状态哈希一致")
```

- [ ] **Step 2: 确认测试因适配器不存在而失败**

- [ ] **Step 3: 实现完整快照和 SHA-256 状态哈希**

快照固定包含 `level_id/encounter_id/turn/player_units/enemy_units/alert_state/visibility_state/facilities/mission_flow/enemy_intents/turn_state/extra/hash`。生成哈希前删除 `timestamp` 和 `hash`，使用 `JSON.stringify` 后 `HashingContext.HASH_SHA256`。恢复前验证 schema、V2 game line、实体 ID 唯一和哈希；失败不修改当前场景。

- [ ] **Step 4: 运行检查点、存档恢复和十次往返测试**

Expected: 十次 capture→restore→capture 哈希一致；篡改 HP、冷却或设施状态时验证失败。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/mission/v2_checkpoint_adapter.gd tactical-grid/client/scripts/game/encounter_checkpoint_state.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): serialize complete encounter state"
```

### Task F11: 五类敌人意图和安全后备行为

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/ai/v2_enemy_brain.gd`
- Create: `tactical-grid/client/scripts/v2/ai/v2_intent_executor.gd`
- Create: `tactical-grid/client/tests/v2/v2_enemy_intent_contract_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2EnemyBrain.plan_intent(enemy: Unit, context: Dictionary) -> Dictionary`。
- Produces: `V2IntentExecutor.execute(intent: Dictionary, context: Dictionary) -> Dictionary`。
- Intent keys: `enemy_id/type/target_id/target_cell/path/damage/telegraph/revision`。

- [ ] **Step 1: 写五类意图和后备安全测试**

```gdscript
t.check(V2EnemyBrain.plan_intent(sentry, ctx).type in [&"move", &"attack"], "哨兵巡逻或攻击")
t.check(V2EnemyBrain.plan_intent(drone, ctx).type == &"scan", "无人机优先扫描")
t.check(V2EnemyBrain.plan_intent(sniper_enemy, ctx).telegraph == &"charge_line", "狙击蓄力一回合")
t.check(V2EnemyBrain.plan_intent(shield_guard, ctx).type == &"protect", "盾卫保护高优先单位")
t.check(V2EnemyBrain.plan_intent(engineer, ctx).type == &"operate", "工程师操作具名设施")
var fallback := V2IntentExecutor.execute(blocked_attack, ctx)
t.check(fallback.type in [&"move", &"guard", &"wait"] and int(fallback.get("damage", 0)) == 0,
    "阻断后备行为不比原意图更致命")
```

- [ ] **Step 2: 确认测试因 AI 类不存在而失败**

- [ ] **Step 3: 实现职责模板和已公开意图执行器**

`V2EnemyBrain` 从 `enemy.role` 分派；目标选择稳定排序为威胁值、距离、实体 ID，确保相同状态产生同一意图。`V2IntentExecutor` 验证目标存活、路径、设施和 revision；无效时只允许移动、警戒或等待。首次揭示回合将致命攻击改为可见蓄力或移动。

- [ ] **Step 4: 运行意图测试 100 次和现有渲染合同**

Expected: 相同输入 100 次 JSON 相同；`enemy_intent_state_test.tscn` 与 `enemy_intent_renderer_test.tscn` 继续通过。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/ai tactical-grid/client/tests/v2
git commit -m "feat(v2): add deterministic enemy intent roles"
```

### Task F12: P1 集成和基础门

**Executor:** Sol xhigh；Terra xhigh 独立审查。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_foundation_integration_test.gd`
- Modify: `tactical-grid/client/project.godot`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Modify: `tactical-grid/PROJECT_STATUS_V2.md`

**Interfaces:**
- Consumes: F02-F11 所有公开接口。
- Produces: Autoload `V2Data="*res://scripts/v2/content/v2_data_repository.gd"`。
- Produces: `BattleController.v2_action_service`、`v2_mission_flow`、`v2_interaction_service` 依赖槽位；P1 只初始化，不切换正式输入。

- [ ] **Step 1: 写从新档加载数据和建立战斗服务的集成测试**

```gdscript
var reload := V2Data.reload_all()
t.check(reload.success, "V2 autoload 数据完整")
var save := V2CampaignProgress.create_default()
t.check(save.current_mission == "ch1_m1", "新档进入 M1")
var state := V2UnitTurnState.new()
state.begin_turn()
t.check(state.can_move() and state.can_act(), "战斗初始行动预算完整")
t.check(OS.get_user_data_dir().ends_with("TacticalGrid_V2_Infiltration"), "运行目录仍隔离")
```

- [ ] **Step 2: 确认测试因 autoload 和控制器槽位不存在而失败**

- [ ] **Step 3: 接入 autoload 和只读依赖槽位**

在 `project.godot` 添加 V2Data。`GameManager._ready` 检查 `V2Data.reload_all()`，失败时进入 boot 错误而不是静默读取 V1 数据。`BattleController` 预加载并实例化 P1 服务，但现有输入仍调用旧 ActionSystem，保证 P2 可以逐合同切换。

- [ ] **Step 4: 运行 P1 全门**

Run: Godot 无头导入、`v2_foundation_integration_test.gd`、`tests/v2/run_v2_gate.ps1`。

Expected: 所有 V2 P1 测试通过；继承发布门失败数 0；0 非预期错误；0 非预期警告；V1 worktree `git status --short` 为空。

- [ ] **Step 5: 提交和阶段记录**

```powershell
git add tactical-grid/client/project.godot tactical-grid/client/scripts/game tactical-grid/client/tests/v2 tactical-grid/PROJECT_STATUS_V2.md
git commit -m "feat(v2): integrate foundation services"
```

在 `artifacts/v2/verification/p1/summary.md` 记录 commit、命令、通过数、失败数、警告数、错误数和运行时长。更新主计划 F01-F12 为完成；P1 未满足全部证据时不得开始 I01。
