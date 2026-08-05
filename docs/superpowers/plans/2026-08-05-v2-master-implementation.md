# Tactical Grid V2 Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已批准的 V2 规格实现为可在 Windows 10/11 独立启动、完成 M1-M6、保存进度并看到明确结局的 2D 小队潜入探索冒险第一章。

**Architecture:** 保留 V1 已验证的网格、寻路、三态迷雾、敌方意图、检查点和存档恢复能力，在 `res://scripts/v2/` 增加职责单一的规则、输入、任务、交互、表现和内容模块。现有大控制器只通过适配器调用 V2 模块，并按测试保护逐步移出职责；V2 数据、资源、测试、存档和发布产物始终与 V1 隔离。

**Tech Stack:** Godot 4.7.1、GDScript、JSON 锁定地图、PowerShell 发布门、Godot headless 场景测试、IMAGE2 图像生成、现有程序化 PCM WAV 工具。

## Global Constraints

- 权威规格是 `docs/v2/V2_MASTER_SPEC.md`，签核日期为 2026-08-05。
- 只在分支 `codex/ch1-infiltration-v2` 和 worktree `.worktrees/ch1-infiltration-v2` 工作。
- Godot 项目名固定为 `Tactical Grid V2: Infiltration`，用户目录固定为 `TacticalGrid_V2_Infiltration`。
- 新代码放在 `res://scripts/v2/`，新数据放在 `res://data/v2/`，新资源放在 `res://assets/v2/`，新测试放在 `res://tests/v2/`。
- V2 发布验证产物放在仓库级 `artifacts/v2/`，不得提交 Git。
- 保持 2D 正交俯视、64×64 格子和 Godot `gl_compatibility` 渲染器。
- 每名角色每回合一次移动和一次行动，顺序自由；普通攻击、唯一能力和场景交互消耗行动。
- 基础攻击确定命中并显示精确伤害；第一章不使用随机闪避、随机暴击或随机伤害。
- 第一章固定四名可部署角色、五类通用敌人、M5 猎手和 M6 Boss；最多三名角色出战。
- M1 未通过 H1 首次玩家门前，不批量生产 M2-M6 正式美术。
- 不加入商店、随机掉落、装备词条、复杂技能树、治疗物品、战斗复活、实时战斗或 3D。
- 所有外部或生成资源必须记录来源、许可证、生成方式、日期、尺寸、导入设置和游戏用途。
- 每个规则或缺陷任务先写失败测试，确认失败原因，再做最小实现、运行局部测试和完整阶段门。
- 不把 V1 测试结果写成 V2 已验收；继承测试只证明未发生已知回归。
- 不整分支合并 V2 到 `main`；通用修复只能独立审查后选择性移植。

---

## 1. 计划权威和文件集

本文件是 V2 实施顺序、依赖、代理分工和阶段状态的唯一索引。具体代码步骤只出现在下列六份子计划中：

计划共包含 78 个可独立提交的实施任务，以及 H1、H2、H3 三个必须由真实玩家或项目负责人完成的硬门。

| 子计划 | 任务 | 退出结果 |
|---|---|---|
| [P1 技术基础](2026-08-05-v2-p1-foundation.md) | F01-F12 | V2 数据、存档、地图 v3、行动预算、确定性战斗和发布门可独立验证 |
| [P2 操作与 HUD](2026-08-05-v2-p2-interaction-hud.md) | I01-I12 | 选择、移动、攻击、取消、镜头、迷雾、HUD 和设置形成完整玩家回合 |
| [P3-P5 M1 垂直切片](2026-08-05-v2-p3-p5-m1-vertical-slice.md) | M101-M114、H1 | M1 从新档可完成并通过首次玩家门，达到公开试玩质量 |
| [P4-P6 美术与共享内容](2026-08-05-v2-p4-p6-art-shared-content.md) | A01-A14 | 四角色、敌人、环境、肖像、图标、VFX 和音频全部正式接入 |
| [P7-P9 M2-M6](2026-08-05-v2-p7-p9-missions.md) | C01-C14、H2 | 六关连续可通关，Boss、结局、重玩和两档难度闭环 |
| [P10 发布与验收](2026-08-05-v2-p10-release-acceptance.md) | R01-R12、H3 | Windows 候选包、法律文件、性能、长时与干净环境验收通过 |

其他 V1 路线图、2026-07-30 计划和历史状态文档不再提供 V2 任务。若它们与本计划冲突，以本计划和 V2 总规格为准。

## 2. 固定目录和文件职责

### 2.1 新代码

| 路径 | 唯一职责 |
|---|---|
| `scripts/v2/content/v2_data_repository.gd` | 加载并查询 V2 角色、敌人、能力、模块、任务和对话数据 |
| `scripts/v2/content/v2_schema_validator.gd` | 验证六份 V2 JSON 数据的必需字段、ID 和引用 |
| `scripts/v2/content/v2_map_loader.gd` | 只加载 `data/v2/locked_maps/` 的 schema v3 地图 |
| `scripts/v2/content/v2_map_validator.gd` | 校验稳定 ID、可达目标、编队出生点、设施和激活上限 |
| `scripts/v2/combat/v2_unit_turn_state.gd` | 保存一次移动、一次行动、冷却和回合刷新状态 |
| `scripts/v2/combat/v2_combat_rules.gd` | 计算射程、视线、方向掩体、侧翼、护甲、护盾和精确伤害 |
| `scripts/v2/combat/v2_action_service.gd` | 执行 query-preview-validate-commit 行动事务 |
| `scripts/v2/combat/v2_ability_rules.gd` | 四名角色唯一主动、被动和八个模块规则 |
| `scripts/v2/input/v2_battle_input_router.gd` | 将鼠标键盘输入转换为明确的选择、移动、攻击、交互和取消意图 |
| `scripts/v2/mission/v2_mission_flow.gd` | 管理主目标、可选目标、营救、撤离、失败和任务完成 |
| `scripts/v2/mission/v2_checkpoint_adapter.gd` | 将 V2 单位、任务、设施、迷雾和意图写入/恢复检查点 |
| `scripts/v2/mission/v2_campaign_progress.gd` | 管理角色救援、模块、任务解锁、章节完成和重玩 |
| `scripts/v2/interaction/v2_interaction_service.gd` | 查询并提交最多两个具体场景操作 |
| `scripts/v2/interaction/handlers/*.gd` | 摄像头、门、电力、轨道、信标和 Boss 终端各自效果 |
| `scripts/v2/presentation/v2_affordance_presenter.gd` | 绘制蓝色移动、红色攻击、路径、危险、选择和交互范围 |
| `scripts/v2/presentation/v2_hud_presenter.gd` | 把规则状态映射到 HUD，不自行计算合法性 |
| `scripts/v2/presentation/v2_damage_presenter.gd` | 处理动作、生命预切除、伤害数字、减伤和倒地反馈 |
| `scripts/v2/presentation/v2_unit_art_catalog.gd` | 查询四方向单位图、肖像、地标、图标和 VFX 资源 |
| `scripts/v2/presentation/v2_visual_mode.gd` | 统一文字缩放、减少动态、震动和视觉检查模式 |
| `scripts/v2/ai/v2_enemy_brain.gd` | 按五类敌人和猎手角色产生可公开意图 |
| `scripts/v2/ai/v2_intent_executor.gd` | 执行已公开意图和不更致命的安全后备行为 |

### 2.2 新数据

| 路径 | 内容 |
|---|---|
| `data/v2/characters.json` | 四名角色基础整数属性、被动、主动、方向美术键 |
| `data/v2/enemies.json` | 五类通用敌人、猎手和 Boss 阶段数据 |
| `data/v2/abilities.json` | 四个主动能力的范围、冷却和规则参数 |
| `data/v2/modules.json` | 八个固定模块、解锁来源和效果参数 |
| `data/v2/missions.json` | M1-M6 简报、编队、目标、敌人上限、时长和奖励 |
| `data/v2/dialogues.json` | 基地、战前、战后、营救和结局短对话 |
| `data/v2/locked_maps/ch1_m1.json` 至 `ch1_m6.json` | schema v3 固定地图 |
| `data/v2/resource_manifest.md` | 正式资源来源、许可证、技术处理和用途 |

### 2.3 新测试与工具

| 路径 | 内容 |
|---|---|
| `tests/v2/run_v2_gate.ps1` | V2 唯一完整发布门 |
| `tests/v2/test_runner.gd` | 共享断言、摘要和退出码辅助 |
| `tests/v2/*_test.gd/.tscn` | 单元、合同、E2E、视觉和性能场景测试 |
| `tools/v2/process_unit_art.ps1` | 色键、裁切、缩放、透明边缘和命名检查 |
| `tools/v2/generate_v2_audio.ps1` | 生成能力、意图、环境、Boss 和伤害音频 |
| `tools/v2/verify_resource_manifest.ps1` | 校验每个正式资源均有清单条目 |
| `tools/v2/build_v2_windows.ps1` | 导出、打包、哈希和包结构验证 |

## 3. 公开接口契约

后续任务不得自行改名。接口需要变化时，先修改本文件和所有消费任务，再提交代码。

```gdscript
# V2DataRepository
func reload_all() -> Dictionary
func get_character(id: StringName) -> Dictionary
func get_enemy(id: StringName) -> Dictionary
func get_ability(id: StringName) -> Dictionary
func get_module(id: StringName) -> Dictionary
func get_mission(id: StringName) -> Dictionary
func get_dialogue(id: StringName) -> Dictionary
func get_errors() -> Array[String]

# V2UnitTurnState
func begin_turn() -> void
func can_move() -> bool
func can_act() -> bool
func spend_move() -> bool
func spend_action() -> bool
func set_cooldown(ability_id: StringName, turns: int) -> void
func get_cooldown(ability_id: StringName) -> int
func serialize() -> Dictionary
func deserialize(data: Dictionary) -> Dictionary

# V2CombatRules
static func preview_attack(attacker: Unit, target: Unit, context: Dictionary) -> Dictionary

# V2ActionService
func setup(map_data: Dictionary, players: Array, enemies: Array) -> void
func query_action(request: Dictionary) -> Dictionary
func validate_action(preview: Dictionary) -> Dictionary
func commit_action(preview: Dictionary) -> Dictionary
func cancel_preview(preview_id: int) -> void

# V2MissionFlow
func setup(mission: Dictionary, map_data: Dictionary, players: Array, enemies: Array) -> Dictionary
func apply_event(event_name: StringName, payload: Dictionary = {}) -> Dictionary
func get_primary_text() -> String
func get_optional_text() -> String
func is_victory() -> bool
func is_defeat() -> bool
func serialize() -> Dictionary
func deserialize(data: Dictionary) -> Dictionary

# V2InteractionService
func setup(map_data: Dictionary, mission_flow: V2MissionFlow) -> void
func query_actions(actor: Unit, entity_id: String) -> Array[Dictionary]
func commit_action(actor: Unit, action_id: StringName, entity_id: String) -> Dictionary

# V2EnemyBrain
func plan_intent(enemy: Unit, context: Dictionary) -> Dictionary

# V2IntentExecutor
func execute(intent: Dictionary, context: Dictionary) -> Dictionary
```

标准攻击预览必须包含以下字段：

```gdscript
{
    "valid": true,
    "reason": "",
    "preview_id": 1,
    "state_revision": 12,
    "attacker_id": "player_assault",
    "target_id": "enemy_sentry_a",
    "base_damage": 3,
    "cover_reduction": 1,
    "armor_reduction": 0,
    "shield_absorb": 0,
    "final_damage": 2,
    "hp_before": 4,
    "hp_after": 2,
    "intent_changes": [],
    "cost": {"action": true}
}
```

失败结果统一使用 `{success = false, reason = StringName}` 或 `{valid = false, reason = StringName}`，禁止只返回 `false` 丢失原因。

## 4. 任务依赖和顺序

```text
P0 approved
  -> F01-F05 data/save/map identity
  -> F06-F10 turn/combat/action/ability/checkpoint
  -> F11-F12 AI contract and foundation gate
  -> I01-I06 input transaction
  -> I07-I12 camera/HUD/feedback/fog/settings/integration
  -> M101-M113 M1 graybox and instrumentation
  -> H1 first-player gate
  -> M114 graybox lock
  -> A01-A05 art sample and recognition gate
  -> A06-A14 full art/audio/shared content and M1 polish
  -> C01-C05 M2-M3
  -> C06-C09 M4-M5
  -> C10-C13 M6/endings/balance
  -> C14 + H2 chapter content lock
  -> R01-R11 release integration
  -> R12 + H3 release candidate sign-off
```

### 4.1 精确前置矩阵

下表是任务调度的唯一前置合同。逗号表示所有条件都必须完成，`X01-X05` 表示该闭区间内每个任务都必须完成；未列出的任务不得被解释为隐含前置。`P0` 表示已批准规格 commit `5e2f167` 和标签 `v2-spec-approved`。

| Task | Direct prerequisites |
|---|---|
| F01 | P0 |
| F02 | F01 |
| F03 | F02 |
| F04 | F02, F03 |
| F05 | F01, F02 |
| F06 | F03 |
| F07 | F03, F06 |
| F08 | F04, F06, F07 |
| F09 | F03, F06-F08 |
| F10 | F04-F06, F09 |
| F11 | F03, F04, F07, F08 |
| F12 | F01-F11 |
| I01 | F12 |
| I02 | I01, F08 |
| I03 | I01, I02 |
| I04 | I01, I02, F07, F08 |
| I05 | I01, F08 |
| I06 | I01, I03-I05 |
| I07 | I01 |
| I08 | I01, I02 |
| I09 | I04, F07 |
| I10 | I03, F04 |
| I11 | I07, I08 |
| I12 | I01-I11 |
| M101 | I12, F03 |
| M102 | M101, F04 |
| M103 | M101, M102, F10 |
| M104 | M103, F09 |
| M105 | M102, M103, I05 |
| M106 | M102, F11 |
| M107 | M106, I10, F11 |
| M108 | M103-M107, I12 |
| M109 | M103, F10 |
| M110 | M104, M105, F05, F09 |
| M111 | M103-M105 |
| M112 | M101-M111 |
| M113 | M112 |
| H1 | M112, M113 |
| M114 | H1 |
| A01 | M114 |
| A02 | A01 |
| A03 | A02 |
| A04 | A03, I09 |
| A05 | A04 |
| A06 | A05 |
| A07 | A05 |
| A08 | A05 |
| A09 | A05 |
| A10 | A05, I09 |
| A11 | A05 |
| A12 | A06-A11 |
| A13 | A12, M114 |
| A14 | A13 |
| C01 | A14, F05, F09 |
| C02 | A14, C01 |
| C03 | C02 |
| C04 | A14, C01 |
| C05 | C04 |
| C06 | C03, C05 |
| C07 | C06 |
| C08 | C07 |
| C09 | C08 |
| C10 | C09 |
| C11 | C03, C05, C07, C09, C10 |
| C12 | C02-C11 |
| C13 | C01-C12 |
| C14 | C13 |
| H2 | C14 |
| R01 | H2 |
| R02 | H2, F05 |
| R03 | H2, A14 |
| R04 | H2, A14 |
| R05 | H2 |
| R06 | R02, R05 |
| R07 | H2 |
| R08 | H2, A14 |
| R09 | R07, R08 |
| R10 | R01-R09 |
| R11 | R10 |
| R12 | R11 |
| H3 | R12 |

允许并行的唯一批次：

- F02 数据仓库与 F05 存档身份可以并行，但 F12 前必须合并验证。
- I07 镜头与 I08 HUD 可以并行，但都依赖 I01 输入状态。
- H1 通过后，A06 玩家角色、A07 敌人、A08 肖像图标和 A09 环境可以并行生成；运行时接入仍按 A10-A14 顺序。
- C02 M2 地图数据和 C04 M3 地图数据可以并行；任务机制、进度和 E2E 必须顺序集成。
- R03 视觉矩阵、R04 音频技术检查和 R05 性能记录可以并行；R11 候选门统一汇总。

除此之外不得为了并行修改同一个控制器、场景、JSON 或发布脚本。

## 5. 执行模型和工具分工

| 任务类别 | 首选执行者 | 强度 | 复核者 |
|---|---|---:|---|
| F06-F12、I01-I06、C10 Boss、R02 存档 | Sol | xhigh | Terra xhigh |
| BattleController 提取、迷雾、敌方意图、检查点 | Sol | xhigh | 独立 Sol/Terra xhigh |
| JSON、对话、文案、资源清单、常规合同测试 | Terra | high | Sol high |
| 地图数据与任务脚本 | Terra | high；机制耦合时 xhigh | Sol xhigh |
| 图像风格板、方向图、肖像、地标 | IMAGE2 | 最高质量 | Sol xhigh + 五人辨识测试 |
| 图像处理、导入和 ArtCatalog 接入 | Terra | high | Sol high |
| 程序化 VFX 和 PCM WAV | Terra | high | 人工视觉/听感验收 |
| 发布整合、缺陷收口、最终审计 | Sol | xhigh | Terra xhigh |
| H1、H2、H3 真人门 | 项目负责人组织真实玩家 | 人工 | AI 只记录和分析 |

模型名称表示任务路由，不表示自动验收。任何模型执行后都必须提供本任务测试日志和 diff 证据。

## 6. 每个任务的固定执行协议

- [ ] 读取本主计划、对应子计划任务和 V2 总规格相关章节。
- [ ] 在仓库根运行 `git branch --show-current`，结果必须是 `codex/ch1-infiltration-v2`。
- [ ] 运行 `git status --short`；若出现不属于当前任务的改动，保留并避开，发生文件冲突时停止并报告。
- [ ] 只添加任务列出的失败测试，运行并记录准确失败原因。
- [ ] 实现使该测试通过的最小代码，不提前实现后续任务。
- [ ] 运行任务列出的局部测试和所有直接消费接口的合同测试。
- [ ] 运行 `git diff --check`，检查无空白错误、调试输出、绝对用户路径和无来源资源。
- [ ] 用 `git diff --` 查看完整任务差异，再按任务列出的准确文件逐个复核，确认没有修改 V1 文档和不相关功能。
- [ ] 使用任务指定提交信息提交；一个提交只包含一个任务。
- [ ] 阶段末运行完整 V2 门；P1 首份摘要写入 `artifacts/v2/verification/p1/summary.md`，其余阶段使用各子计划列出的准确证据路径。

禁止执行 `git reset --hard`、`git checkout --`、整分支合并和跨 worktree 递归移动。不得删除用户改动来取得干净状态。

## 7. 标准测试命令

所有 Godot 命令从 `tactical-grid/client` 运行：

```powershell
$godotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
& $godotExe --headless --editor --quit --path .
& $godotExe --headless --path . --script res://tests/v2/v2_foundation_integration_test.gd
powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

阶段测试顺序固定为：

1. Godot 无头导入。
2. 当前任务场景测试。
3. 直接依赖合同测试。
4. `tests/v2/run_v2_gate.ps1`。
5. 阶段需要时运行真实窗口输入、视觉截图、音频、性能或导出验证。

局部测试必须通过进程退出码报告失败。测试输出末尾必须包含英文 `Passed: N` 和 `Failed: 0`，使 PowerShell 门稳定解析。

### 7.1 逐任务主验证命令

每个执行者先在 `tactical-grid/client` 的同一个 PowerShell 会话运行以下定义。包装函数不会吞掉退出码；表中多条命令必须全部通过。表中是最低主验证，子计划 Step 4 列出的直接消费者、视觉、听感或人工验收仍必须执行。

```powershell
$godotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'

function Invoke-V2Script([string] $Path) {
    & $godotExe --headless --path . --script ("res://" + $Path)
    if ($LASTEXITCODE -ne 0) { throw "Godot script failed: $Path ($LASTEXITCODE)" }
}

function Invoke-V2Scene([string] $Path) {
    & $godotExe --headless --path . ("res://" + $Path)
    if ($LASTEXITCODE -ne 0) { throw "Godot scene failed: $Path ($LASTEXITCODE)" }
}

function Invoke-V2PowerShell([string] $Path) {
    & powershell -ExecutionPolicy Bypass -File $Path
    if ($LASTEXITCODE -ne 0) { throw "PowerShell gate failed: $Path ($LASTEXITCODE)" }
}
```

#### P1 基础

| Task | Run from `tactical-grid/client` |
|---|---|
| F01 | `Invoke-V2Script 'tests/v2/gate_manifest_test.gd'; Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'` |
| F02 | `Invoke-V2Script 'tests/v2/v2_data_repository_test.gd'` |
| F03 | `Invoke-V2Script 'tests/v2/v2_data_repository_test.gd'` |
| F04 | `Invoke-V2Script 'tests/v2/v2_map_schema_test.gd'` |
| F05 | `Invoke-V2Script 'tests/v2/v2_save_identity_test.gd'` |
| F06 | `Invoke-V2Script 'tests/v2/v2_unit_turn_state_test.gd'` |
| F07 | `Invoke-V2Script 'tests/v2/v2_combat_rules_test.gd'` |
| F08 | `Invoke-V2Script 'tests/v2/v2_action_service_test.gd'` |
| F09 | `Invoke-V2Script 'tests/v2/v2_ability_rules_test.gd'` |
| F10 | `Invoke-V2Script 'tests/v2/v2_checkpoint_test.gd'` |
| F11 | `Invoke-V2Script 'tests/v2/v2_enemy_intent_contract_test.gd'` |
| F12 | `Invoke-V2Script 'tests/v2/v2_foundation_integration_test.gd'; Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'` |

#### P2 操作与 HUD

| Task | Run from `tactical-grid/client` |
|---|---|
| I01 | `Invoke-V2Script 'tests/v2/v2_input_router_test.gd'` |
| I02 | `Invoke-V2Script 'tests/v2/v2_affordance_contract_test.gd'` |
| I03 | `Invoke-V2Script 'tests/v2/v2_direct_move_input_test.gd'` |
| I04 | `Invoke-V2Script 'tests/v2/v2_attack_input_test.gd'` |
| I05 | `Invoke-V2Script 'tests/v2/v2_interaction_service_test.gd'` |
| I06 | `Invoke-V2Script 'tests/v2/v2_cancel_end_turn_test.gd'` |
| I07 | `Invoke-V2Script 'tests/v2/v2_camera_input_test.gd'` |
| I08 | `Invoke-V2Script 'tests/v2/v2_hud_contract_test.gd'` |
| I09 | `Invoke-V2Script 'tests/v2/v2_damage_presentation_test.gd'` |
| I10 | `Invoke-V2Script 'tests/v2/v2_visibility_transaction_test.gd'` |
| I11 | `Invoke-V2Script 'tests/v2/v2_settings_contract_test.gd'` |
| I12 | `Invoke-V2Scene 'tests/v2/v2_player_turn_e2e_test.tscn'; Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'` |

#### P3-P5 M1

| Task | Run from `tactical-grid/client` |
|---|---|
| M101 | `Invoke-V2Script 'tests/v2/v2_m1_config_test.gd'` |
| M102 | `Invoke-V2Script 'tests/v2/v2_m1_map_test.gd'` |
| M103 | `Invoke-V2Script 'tests/v2/v2_m1_flow_test.gd'` |
| M104 | `Invoke-V2Script 'tests/v2/v2_rescue_character_test.gd'` |
| M105 | `Invoke-V2Script 'tests/v2/v2_m1_interaction_test.gd'` |
| M106 | `Invoke-V2Script 'tests/v2/v2_m1_enemy_activation_test.gd'` |
| M107 | `Invoke-V2Script 'tests/v2/v2_m1_stealth_state_test.gd'` |
| M108 | `Invoke-V2Script 'tests/v2/v2_m1_tutorial_test.gd'` |
| M109 | `Invoke-V2Script 'tests/v2/v2_m1_retry_test.gd'` |
| M110 | `Invoke-V2Script 'tests/v2/v2_m1_progression_test.gd'` |
| M111 | `Invoke-V2Script 'tests/v2/v2_m1_dialogue_test.gd'` |
| M112 | `Invoke-V2Scene 'tests/v2/v2_m1_e2e_test.tscn'; Invoke-V2Scene 'tests/v2/v2_m1_visual_snapshot.tscn'` |
| M113 | `Invoke-V2Script 'tests/v2/v2_playtest_recorder_test.gd'` |
| H1 | `$h1 = Get-Content '..\..\artifacts\v2\verification\h1\H1_SUMMARY.md' -Raw; if ($h1 -notmatch 'decision:\s*PASS') { throw 'H1 real-player gate is not PASS' }` |
| M114 | `Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'` |

#### P4-P6 美术与共享内容

| Task | Run from `tactical-grid/client` |
|---|---|
| A01 | `Invoke-V2PowerShell 'tools/v2/verify_resource_manifest.ps1'` |
| A02 | `$samples = @(Get-ChildItem 'assets/v2/source/samples' -File -Filter '*.png'); if ($samples.Count -ne 5) { throw "Expected 5 samples, got $($samples.Count)" }; $samples | Get-FileHash -Algorithm SHA256` |
| A03 | `Invoke-V2Script 'tests/v2/v2_art_asset_contract_test.gd'` |
| A04 | `Invoke-V2Script 'tests/v2/v2_unit_direction_test.gd'` |
| A05 | `$decision = Get-Content '..\..\artifacts\v2\verification\art-sample\decision.md' -Raw; if ($decision -notmatch 'decision:\s*PASS') { throw 'Art sample recognition gate is not PASS' }` |
| A06 | `Invoke-V2Script 'tests/v2/v2_art_asset_contract_test.gd'` |
| A07 | `Invoke-V2Script 'tests/v2/v2_art_asset_contract_test.gd'` |
| A08 | `Invoke-V2Script 'tests/v2/v2_portrait_icon_contract_test.gd'` |
| A09 | `Invoke-V2Script 'tests/v2/v2_environment_kit_test.gd'` |
| A10 | `Invoke-V2Script 'tests/v2/v2_vfx_contract_test.gd'` |
| A11 | `Invoke-V2Script 'tests/v2/v2_audio_contract_test.gd'` |
| A12 | `Invoke-V2Script 'tests/v2/v2_runtime_resource_contract_test.gd'; Invoke-V2PowerShell 'tools/v2/verify_resource_manifest.ps1'` |
| A13 | `Invoke-V2Scene 'tests/v2/v2_m1_e2e_test.tscn'; Invoke-V2Scene 'tests/v2/v2_m1_visual_snapshot.tscn'` |
| A14 | `Invoke-V2PowerShell 'tools/v2/build_content_inventory.ps1'; Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'` |

#### P7-P9 M2-M6

| Task | Run from `tactical-grid/client` |
|---|---|
| C01 | `Invoke-V2Script 'tests/v2/v2_squad_loadout_test.gd'` |
| C02 | `Invoke-V2Script 'tests/v2/v2_m2_map_flow_test.gd'` |
| C03 | `Invoke-V2Scene 'tests/v2/v2_m2_e2e_test.tscn'` |
| C04 | `Invoke-V2Script 'tests/v2/v2_m3_map_flow_test.gd'` |
| C05 | `Invoke-V2Scene 'tests/v2/v2_m3_e2e_test.tscn'` |
| C06 | `Invoke-V2Script 'tests/v2/v2_m4_map_flow_test.gd'` |
| C07 | `Invoke-V2Scene 'tests/v2/v2_m4_e2e_test.tscn'` |
| C08 | `Invoke-V2Script 'tests/v2/v2_m5_map_flow_test.gd'` |
| C09 | `Invoke-V2Scene 'tests/v2/v2_m5_e2e_test.tscn'` |
| C10 | `Invoke-V2Script 'tests/v2/v2_m6_boss_test.gd'; Invoke-V2Scene 'tests/v2/v2_m6_e2e_test.tscn'` |
| C11 | `Invoke-V2Script 'tests/v2/v2_chapter_narrative_test.gd'` |
| C12 | `Invoke-V2Script 'tests/v2/v2_difficulty_balance_test.gd'` |
| C13 | `Invoke-V2Scene 'tests/v2/v2_chapter_e2e_test.tscn'; Invoke-V2Scene 'tests/v2/v2_replay_flow_test.tscn'` |
| C14 | `Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'` |
| H2 | `$h2 = Get-Content '..\..\artifacts\v2\verification\h2\H2_SUMMARY.md' -Raw; if ($h2 -notmatch 'decision:\s*PASS') { throw 'H2 chapter playthrough gate is not PASS' }` |

#### P10 发布

| Task | Run from `tactical-grid/client` |
|---|---|
| R01 | `Invoke-V2Scene 'tests/v2/v2_accessibility_matrix_test.tscn'` |
| R02 | `Invoke-V2Script 'tests/v2/v2_save_release_test.gd'` |
| R03 | `Invoke-V2PowerShell 'tools/v2/run_visual_matrix.ps1'` |
| R04 | `Invoke-V2PowerShell 'tools/v2/test_v2_audio_release.ps1'` |
| R05 | `Invoke-V2PowerShell 'tools/v2/run_performance_matrix.ps1'` |
| R06 | `Invoke-V2PowerShell 'tools/v2/run_soak_tests.ps1'` |
| R07 | `Invoke-V2PowerShell 'tools/v2/build_v2_windows.ps1'` |
| R08 | `Invoke-V2PowerShell 'tools/v2/verify_resource_manifest.ps1'; Invoke-V2PowerShell 'tools/v2/build_v2_windows.ps1'` |
| R09 | `Invoke-V2PowerShell 'tools/v2/verify_clean_clone.ps1'` |
| R10 | `Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'; $open = @(Import-Csv '..\..\artifacts\v2\verification\p10\defects.csv' | Where-Object { $_.status -ne 'closed' -and $_.severity -in @('blocker','critical','major') }); if ($open.Count -gt 0) { throw "$($open.Count) release-blocking defects remain" }` |
| R11 | `powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1 *> '..\..\artifacts\v2\verification\p10\rc_gate.log'; if ($LASTEXITCODE -ne 0) { throw 'RC gate failed' }; Invoke-V2PowerShell 'tools/v2/build_v2_windows.ps1'` |
| R12 | `Invoke-V2PowerShell 'tests/v2/run_v2_gate.ps1'; Invoke-V2PowerShell 'tools/v2/build_v2_windows.ps1'; git diff --check` |
| H3 | `$h3 = Get-Content '..\..\artifacts\v2\verification\p10\H3_SIGNOFF.md' -Raw; if ($h3 -notmatch 'decision:\s*APPROVED') { throw 'H3 release sign-off is not APPROVED' }` |

若表中资源或测试尚不存在，首次运行的准确预期就是文件不存在或合同失败；任务实现后同一命令必须退出 0。H1/H2/H3 的命令只验证已经由真实玩家或项目负责人签署的证据，不得由 AI 自动写入通过结果。

## 8. 提交边界

提交前缀固定如下：

- `test(v2):` 仅用于建立测试门或复现缺陷。
- `feat(v2):` 新规则、内容和正式资源接入。
- `refactor(v2):` 在行为测试不变时提取职责。
- `fix(v2):` 修复已复现缺陷。
- `art(v2):` 正式图像、处理配置和资源清单。
- `audio(v2):` 正式音频、生成工具和音频清单。
- `docs(v2):` 规格、计划、测试记录模板和发布说明。
- `build(v2):` 导出、打包、哈希和发布门。

每个子计划任务已经给出准确提交信息。执行者不得把多个任务压成一个大提交，也不得修改历史提交。

## 9. 阶段状态清单

### P0 规格签核

- [x] V2 worktree、分支、项目身份和用户目录隔离。
- [x] V2 总规格完成并由用户于 2026-08-05 批准。
- [x] V2 实施计划文件集建立。
- [x] 创建保护标签 `v2-spec-approved`，指向规格提交 `5e2f167`。

### P1 技术骨架

- [x] F01 V2 发布门和共享测试运行器。
- [x] F02 V2 数据仓库和模式校验。
- [x] F03 四角色、敌人、能力、模块和任务基础数据。
- [x] F04 schema v3 地图加载与校验。
- [x] F05 V2 存档身份和三槽恢复。
- [x] F06 一次移动、一次行动和冷却状态。
- [x] F07 确定性战斗和精确攻击预览。
- [x] F08 query-preview-validate-commit 行动服务。
- [x] F09 四角色能力、被动和八模块规则。
- [x] F10 V2 检查点完整序列化。
- [x] F11 五类敌人意图与安全后备行为。
- [x] F12 P1 集成和基础门。

### P2 操作与 HUD

- [x] I01 明确输入状态机。
- [x] I02 选择后同时显示移动与攻击范围。
- [x] I03 左键安全移动。
- [x] I04 悬停、锁定、二次确认攻击。
- [x] I05 具体场景交互菜单。
- [x] I06 右键取消、Space 结束回合和状态恢复。
- [x] I07 中键平移、滚轮缩放和 Home 聚焦。
- [x] I08 UI 方向 3 HUD 和状态提示。
- [x] I09 精确伤害和命中表现。
- [x] I10 移动后同事务迷雾刷新。
- [x] I11 设置、键位、文字缩放和视觉模式。
- [x] I12 P2 真实输入集成门。

### P3-P5 M1

- [x] M101 M1 任务数据与初始编队。
- [x] M102 22×16 两路线地图和敌人激活区。
- [x] M103 营救侦察兵并撤离的主目标流。
- [x] M104 角色营救和同关加入。
- [x] M105 摄像头和事故记录可选目标。
- [x] M106 哨兵、无人机和最多三名活跃敌人。M106 契约 18/18；玩家回合 38/38；救援集成 13/13；完整 V2 门禁通过。
- [x] M107 M1 潜伏/搜索警戒和即时迷雾。契约 16/16；真实输入 41/41；完整 V2 门禁通过。
- [x] M108 六步行为教学。教学流合同 31/31；V1 教学/HUD 合同 136/136；V2 玩家回合 41/41；救援场景 13/13；完整 V2 门禁通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。
- [x] M109 失败、检查点和三种重试出口。纯合同 15/15；正式重试场景 14/14；V2 检查点 13/13；完整 V2 门禁通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。
- [x] M110 基地解锁、编队、模块和结算。进度合同 16/16；基地/角色面板/结算正式场景合同 24/24；完整 V2 release gate 通过，V1 稳定断言 1816，失败 0，意外警告/错误 0。
- [ ] M111 M1 短对话和事故记录。
- [ ] M112 M1 自动 E2E 和视觉矩阵。
- [ ] M113 首次玩家记录工具。
- [ ] H1 三名首次玩家门。
- [ ] M114 H1 修正和 M1 灰盒锁。

### P4-P6 美术和共享内容

- [ ] A01 风格板、资源命名和清单模式。
- [ ] A02 M1 五项 IMAGE2 小样。
- [ ] A03 小样透明、裁切、尺寸和导入处理。
- [ ] A04 四方向运行时映射和程序动画。
- [ ] A05 小样辨识、720p/1080p 和视觉模式门。
- [ ] A06 四名玩家正式方向图。
- [ ] A07 五类敌人、猎手和 Boss 正式方向图。
- [ ] A08 七张肖像、六个地标和至少 27 个图标。
- [ ] A09 四套环境资源审计与补齐。
- [ ] A10 正式 VFX。
- [ ] A11 至少 20 个新增或重混音频事件。
- [ ] A12 V2 ArtCatalog、AudioManager 和资源清单合同。
- [ ] A13 M1 正式表现整合。
- [ ] A14 P5/P6 共享内容锁。

### P7-P9 六关内容

- [ ] C01 基地任务选择、四选三和模块配置。
- [ ] C02 M2 熄灯协议。
- [ ] C03 M2 狙击营救、门和电力。
- [ ] C04 M3 断轨营救。
- [ ] C05 M3 重装营救、盾卫和轨道。
- [ ] C06 M4 囚笼密钥。
- [ ] C07 M4 协议工程师和牢门组合。
- [ ] C08 M5 反向猎杀。
- [ ] C09 M5 猎手、追踪阵列和信标。
- [ ] C10 M6 零号终端和 Boss 两阶段。
- [ ] C11 章节剧情、图鉴、徽章和结局差异。
- [ ] C12 故事/标准难度和平衡矩阵。
- [ ] C13 M1-M6 E2E、存档继续和重玩。
- [ ] C14 内容锁缺陷修复。
- [ ] H2 第一章连续通关门。

### P10 发布

- [ ] R01 完整可访问性矩阵。
- [ ] R02 存档损坏、备份、未来版本和 V1 拒绝。
- [ ] R03 全视觉矩阵和 UI 重叠检查。
- [ ] R04 音频格式、峰值、循环和混音。
- [ ] R05 720p/1080p 性能和敌方回合时长。
- [ ] R06 两小时长时和 M1 十次重载。
- [ ] R07 Windows V2 产品身份和导出路径。
- [ ] R08 许可证、第三方声明、隐私和资源清单。
- [ ] R09 干净克隆和干净 Windows 账户验证。
- [ ] R10 发布缺陷分级和清零。
- [ ] R11 候选版完整发布门和 SHA-256。
- [ ] R12 发布说明、版本标签和归档。
- [ ] H3 第一章候选版签核。

## 10. 硬门记录

### H1 M1 首次玩家门

必须使用三名从未接触 V1/V2 的玩家。记录表必须包含玩家编号、开始时间、首次选择、首次移动、首次攻击、首次卡住、提示触发、完成时长、失败次数、是否理解蓝红范围、是否理解敌方意图和是否愿意继续 M2。三人中至少两人愿意继续，且没有人因攻击或结束回合永久卡住。

### H2 第一章内容锁

至少一名玩家从新档连续完成 M1-M6；每关标准难度至少三份完成样本、故事难度至少一份。记录回合、受伤、失能、重试、警戒峰值、角色、能力、交互、可选目标和放弃原因。未达到规格中的 70% 目标理解与系统使用率时返回对应任务修正。

### H3 候选版签核

项目负责人核对产品流程、自动测试、真人记录、资源、许可证、Windows 包和已知缺陷。0 崩溃、0 数据损坏、0 流程阻断、0 核心操作失效、0 严重或主要缺陷后才创建候选标签。

## 11. 停止和升级条件

遇到以下任一情况，执行者停止当前任务并报告，不自行扩大范围：

- 需要删除大量 V1 可用代码或资源才能继续。
- 当前 worktree 分支不是 `codex/ch1-infiltration-v2`。
- 发现 V1 与 V2 使用同一可写存档、产物或资源目录。
- 需要付费资源、账号、密钥或来源不明资源。
- 任务实现会改变已批准的游戏类型、回合规则、角色数量或六关结构。
- 同一文件存在无法安全合并的用户改动。
- 自动测试与总规格发生真实冲突。
- H1/H2/H3 缺少真实玩家或最低测试环境，导致无法形成验收证据。

普通实现细节、数值微调、UI 布局和资源处理不属于升级条件，只要不突破总规格即可由执行者决定并记录。

## 12. 完成条件

主计划只有在 F01-R12 全部完成、H1-H3 有真实证据、完整 V2 发布门通过、Windows 候选包在干净账户可启动并继续存档、V1 工作区保持不变时才能标记完成。任务数量、断言数量、生成图像数量和提交数量都不能单独证明游戏完成。

## 13. 总规格覆盖矩阵

| 总规格章节 | 实施任务与验收 |
|---|---|
| 1-5 版本边界、产品目标、体验支柱、非目标 | P0、F01、F05、R07-R09、主计划停止条件 |
| 6-9 核心循环、输入、行动经济、确定性战斗 | F06-F09、I01-I06、I12 |
| 10-11 四角色、编队、八模块和成长 | F03、F09、M104、M110、C01、C03、C05 |
| 12-15 迷雾、警戒、敌方意图、五类敌人与设施 | F11、I05、I10、M105-M107、C03、C05、C07、C09 |
| 16-17 地图标准与 M1-M6 | F04、M101-M112、C02-C10 |
| 18 基地、剧情与结局 | M110-M111、C01、C11、C13 |
| 19-20 HUD、完整界面和可访问性 | I02-I11、R01、R03 |
| 21-24 美术、生产流程、动画、VFX 和音频 | A01-A14、R04 |
| 25 技术架构和大控制器收口 | F02、F06-F12、I01-I12；每次只提取一种职责 |
| 26 数据、地图 v3 和存档 | F02-F05、F10、R02 |
| 27 自动测试体系 | F01、所有任务局部测试、M112、C13、R01-R11 |
| 28-29 真人验收与教学 | M108、M113、H1、H2、H3 |
| 30 发布与法律 | R07-R12、H3 |
| 31-35 生产门、代理、风险、完成定义和冻结决策 | 本主计划、六份子计划、H1-H3 和 R10 缺陷门 |

矩阵中的每一行都必须至少有一项自动证据和规格要求的人工证据。后续修改总规格时，先更新本矩阵并增加对应任务，不能只修改描述。
