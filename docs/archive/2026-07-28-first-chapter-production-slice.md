# 第一章成品垂直切片 Implementation Plan（历史已执行计划）

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付可从 Windows 启动、创建存档、连续完成 Tactical Grid 第一章六关并可靠保存的发布候选切片。

**Architecture:** 保持 `GameManager` 为流程与存档唯一入口，`CampaignRepository` 管理顺序和解锁，`BattleController` 管理每场战斗的唯一运行时状态。先把真实场景流变为可自动验证流程，再逐层接入第一章任务、教程、Boss、表现、音频与发布构建。

**Tech Stack:** Godot 4.7.1、GDScript、Godot headless 场景测试、PowerShell、TypeScript/Jest、Windows x64 Godot export。

## Global Constraints

- 保留可用的现有场景、脚本、锁定地图和存档格式，不推倒重写。
- 每个 GDScript 功能变更先在 `client/tests/battle_smoke_test_runner.gd` 写失败断言。
- 同一时间只运行一份会写入 `user://saves/` 的 Godot 测试进程。
- 新资源必须可商用且可追溯；已有带水印图片不得进入运行时引用或导出包。
- 每任务完成前运行专用测试、完整 Godot 冒烟测试和 `git diff --check`。
- 每次提交只暂存任务明确列出的文件，不提交现有工作区的其他改动。

---

## 文件边界

| 路径 | 职责 |
|---|---|
| `client/tests/battle_smoke_test_runner.gd` | 无头逻辑、流程、内容和资源回归入口 |
| `client/scripts/game/game_manager.gd` | 存档、奖励、流程、章节完成状态 |
| `client/scripts/game/battle_controller.gd` | 锁定地图、任务目标、Boss、结算 |
| `client/scripts/game/action_system.gd` | 技能、物品、陷阱、投掷物、武器效果 |
| `client/scripts/ui/*.gd`、`client/scenes/*.tscn` | 菜单、基地、教程、结算、设置 |
| `client/data/levels.json`、`bosses.json` | 第一章任务、奖励、教程与 Boss 数据 |
| `client/data/RESOURCE_MANIFEST.md` | 新资源来源、许可证、用途和导入信息 |
| `client/export_presets.cfg` | Windows 候选包导出配置 |

## Task 1: TG-214 菜单到下一关流程契约

**Files:**
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Test: `tactical-grid/client/tests/battle_smoke_test.tscn`

**Consumes:** `GameManager.new_game(slot)`、`complete_mission(result)`、`go_to_battle(level_id)`、`CampaignRepository.get_next_level(level_id)`。

**Produces:** `GameManager.begin_new_game_for_test(slot: int) -> Dictionary` 与 `_test_scene_flow_state_contract()`。

- [ ] **Step 1: 写失败测试**

在测试运行器中加入以下关键断言，并在进出测试时备份、恢复 GameManager 状态，使用槽位 2：

```gdscript
_check(GameManager.current_state == GameManager.GameState.BASE, "Flow: 新游戏进入基地")
_check(GameManager.current_level_id == "ch1_m1", "Flow: 选择任务保存当前关卡")
_check(GameManager.battle_result.get("level_id") == "ch1_m1", "Flow: 结算保存第一关结果")
_check(CampaignRepository.get_next_level("ch1_m1") == "ch1_m2", "Flow: 第一关下一关正确")
```

- [ ] **Step 2: 确认红灯**

Run: `& 'D:\\Program Files\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_smoke_test.tscn` in `tactical-grid/client`.

Expected: FAIL，缺失测试辅助入口或流程状态不符合断言。

- [ ] **Step 3: 最小实现**

在 `game_manager.gd` 添加无场景切换、只供回归使用的初始化入口：

```gdscript
func begin_new_game_for_test(slot: int) -> Dictionary:
	current_slot = slot
	current_save = SaveManager.create_default_save()
	current_save.characters = progression.create_starter_roster()
	current_save.resources.credit = 500
	current_state = GameState.BASE
	SaveManager.save_game(current_save, current_slot)
	return current_save
```

测试通过生产的 `complete_mission`、`go_to_mission_result` 和 `CampaignRepository` 验证状态交接，不复制生产逻辑。

- [ ] **Step 4: 确认绿灯并人工检查**

Run: Step 2 命令。随后运行 Godot 项目，手动检查新游戏、基地任务确认、战斗加载、结算“下一关”按钮。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/tests/battle_smoke_test_runner.gd tactical-grid/client/scripts/game/game_manager.gd docs/PROJECT_TAKEOVER_ROADMAP.md
git commit -m "test: cover campaign scene flow contract"
```

## Task 2: 第一章六关内容契约

**Files:**
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`
- Modify: `tactical-grid/client/data/levels.json`
- Modify: `tactical-grid/client/data/bosses.json`
- Modify: `tactical-grid/client/data/locked_maps/*.json`
- Test: `tactical-grid/client/tests/battle_smoke_test.tscn`

**Consumes:** `CampaignRepository.get_level(id)`、`MapLoader.load_locked_map(id)`、`GameData.get_boss(id)`。

**Produces:** `_test_chapter_one_content_contract()`，覆盖 `ch1_m1` 至 `ch1_m6` 的类型、地图目标、对话、奖励和 Boss 数据。

- [ ] **Step 1: 写失败测试**

定义期望类型：

```gdscript
var expected_types := ["extract", "destroy", "extract", "escort", "steal_data", "assassinate"]
```

循环断言六关均有名称、intro/outro 对话、正奖励、可加载锁定地图和所需对象；对 `ch1_m6` 断言 `boss_id == "data_sentinel"`、Boss 存在且有三阶段。验证所有 `first_clear.loot` ID 为空或可由 `GameData.get_weapon`/`GameData.get_item` 解析。

- [ ] **Step 2: 确认红灯**

Run: Task 1 Step 2 命令。

Expected: FAIL，显示当前关卡类型、对象、奖励或 Boss 数据不一致项。

- [ ] **Step 3: 修正数据**

只修正失败关联的 `levels.json`、`bosses.json` 和锁定地图。无效 loot 改为存在的物品 ID 或删除，不写不可显示的库存值。

- [ ] **Step 4: 确认绿灯**

Run:

```powershell
& 'D:\\Program Files\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_smoke_test.tscn
npm test -- --runInBand
npx tsx tests/mapgen_seeds.ts
```

Godot 在 `client`；Node 命令在 `server`。Expected: Godot 全绿、Jest 29/29、锁定种子 30/30。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/tests/battle_smoke_test_runner.gd tactical-grid/client/data/levels.json tactical-grid/client/data/bosses.json tactical-grid/client/data/locked_maps tactical-grid/server/data/generated_maps
git commit -m "test: validate chapter one mission contracts"
```

## Task 3: 可跳过、可持久化的第一章教程

**Files:**
- Create: `tactical-grid/client/scenes/tutorial_hint.tscn`
- Create: `tactical-grid/client/scripts/ui/tutorial_hint.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`

**Consumes:** `level_config.tutorial_flags`、`GameManager.get_story_flag`、`GameManager.set_story_flag`。

**Produces:** `BattleController._show_tutorial_flag(flag: String)` 与 `TutorialHint.show_hint(flag, copy, on_closed)`。

- [ ] **Step 1: 写失败测试**

对 `teach_movement` 和 `teach_evac` 断言：首次未读、标记后已读、保存/加载后仍已读；未知 flag 返回空文本且调用回调。

- [ ] **Step 2: 确认红灯**

Run: Task 1 Step 2 命令。

Expected: FAIL，缺失教程读取或存档状态。

- [ ] **Step 3: 最小实现**

在 `tutorial_hint.gd` 用静态文案表保存第一章提示。已读状态使用 `campaign_progress.story_flags["tutorial_" + flag]`。场景只提供继续与跳过按钮；关闭必须恢复回调，未知 flag 直接回调，不阻断无头测试。

- [ ] **Step 4: 确认绿灯**

Run: Task 1 Step 2 命令；手动在 `ch1_m1` 检查移动、攻击、撤离提示只出现一次，Esc 不会软锁。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/scenes/tutorial_hint.tscn tactical-grid/client/scripts/ui/tutorial_hint.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/battle_smoke_test_runner.gd
git commit -m "feat: add persistent chapter one tutorials"
```

## Task 4: 第一章战斗效果完整性

**Files:**
- Modify: `tactical-grid/client/scripts/game/action_system.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/game/unit.gd`
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`

**Consumes:** `ActionSystem.execute_skill`、`use_item`、`Unit.grid_pos`。

**Produces:** 可查询 `ActionSystem.traps`、范围效果和第一章武器效果的实际结果。

- [ ] **Step 1: 写失败测试**

断言陷阱放置后有目标格状态、敌人进入后触发并移除；投掷物只影响曼哈顿距离不大于半径的单位；第一章使用的 `silent`、`close_range_bonus_1.3x_at_2_tiles`、`setup_bonus_30_hit` 都改变可观察结果；未实现技能不显示为可用。

- [ ] **Step 2: 确认红灯**

Run: Task 1 Step 2 命令。

Expected: FAIL，指出状态、范围或可用技能列表错误。

- [ ] **Step 3: 最小实现**

陷阱以 `Dictionary[Vector2i, Dictionary]` 保存，单位移动结束后由 BattleController 调用触发检查。范围效果使用 `GridSystem.manhattan_distance`。只实现第一章实际引用的 weapon special；其他效果在 UI 中隐藏或禁用，并输出可读日志。

- [ ] **Step 4: 确认绿灯**

Run: Task 1 Step 2 命令与 `git diff --check`。Expected: 无失败、无 Godot ERROR、无资源泄漏。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/scripts/game/action_system.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/game/unit.gd tactical-grid/client/tests/battle_smoke_test_runner.gd
git commit -m "feat: complete chapter one combat effects"
```

## Task 5: 数据哨兵 Boss 与第一章完成状态

**Files:**
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ai/enemy_director.gd`
- Modify: `tactical-grid/client/scripts/game/game_manager.gd`
- Modify: `tactical-grid/client/data/bosses.json`
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`

**Consumes:** `GameData.get_boss("data_sentinel")`、`_check_boss_phase_transition(unit)`、`GameManager.complete_mission(result)`。

**Produces:** `boss_phase_changed(phase_index, phase_data)`、`chapter_1_completed` story flag 和章节完成通知。

- [ ] **Step 1: 写失败测试**

创建 Boss 测试单位，跨越每个 HP 阈值，断言阶段只触发一次、出现预警、阶段能力标志改变。完成 `ch1_m6` 后断言 `chapter_1_completed`、`chapter_1_clear` 和通知队列存在。

- [ ] **Step 2: 确认红灯**

Run: Task 1 Step 2 命令。

Expected: FAIL，报告重复阶段、缺失阶段反馈或章节状态未保存。

- [ ] **Step 3: 最小实现**

Boss 保存 `boss_phase_index` 和 `boss_phase_triggered`，只允许从高血量阶段向低血量阶段推进。第一章实现一次预警、一次增援或压制效果和阶段胜利反馈。首通 `ch1_m6` 写入 `story_flags.chapter_1_completed = true` 并安排章节完成对话。

- [ ] **Step 4: 确认绿灯**

Run: Task 1 Step 2 命令；手动运行 `ch1_m6`，验证阶段预警、失败重试和胜利结算。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scripts/ai/enemy_director.gd tactical-grid/client/scripts/game/game_manager.gd tactical-grid/client/data/bosses.json tactical-grid/client/tests/battle_smoke_test_runner.gd
git commit -m "feat: complete chapter one boss flow"
```

## Task 6: 正式表现小样与资源清单

**Files:**
- Create: `tactical-grid/client/assets/generated/chapter1/`
- Create: `tactical-grid/client/data/RESOURCE_MANIFEST.md`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scenes/battle.tscn`
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`

**Consumes:** 64x64 网格、`UnitSprite` 队伍/职业信息、Battle 效果层。

**Produces:** 可追溯的地形、玩家、敌人、目标物、枪口/命中/爆炸小样，替代第一章默认纯色方块。

- [ ] **Step 1: 写失败测试**

读取 manifest 中每个 `path`，断言文件存在、PNG 有 alpha、尺寸为 64x64 或声明精灵表尺寸；断言运行时场景没有引用历史带水印目录。

- [ ] **Step 2: 确认红灯**

Run: Task 1 Step 2 命令。

Expected: FAIL，缺 manifest 或生成资源。

- [ ] **Step 3: 生成并接入资源**

使用程序化 SVG/PNG 或原创 AI 资源，只制作一个玩家、一个敌人、六种地形、三个特效和一套 HUD 色板。为每项写路径、来源类型、许可证/生成说明、日期、用途、导入设置。将 UnitSprite 和地图层切换到小样资源。

- [ ] **Step 4: 确认绿灯**

Run: Task 1 Step 2 命令；以 1080p 运行 `ch1_m1` 与 `ch1_m6` 并截图。检查透明边缘、锚点、阵营可读性和效果层释放。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/assets/generated/chapter1 tactical-grid/client/data/RESOURCE_MANIFEST.md tactical-grid/client/scripts/game/unit_sprite.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/scenes/battle.tscn tactical-grid/client/tests/battle_smoke_test_runner.gd
git commit -m "feat: add chapter one visual slice assets"
```

## Task 7: 音频总线与关键反馈

**Files:**
- Create: `tactical-grid/client/assets/audio/chapter1/`
- Create: `tactical-grid/client/default_bus_layout.tres`
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Modify: `tactical-grid/client/scripts/ui/boot.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/battle_smoke_test_runner.gd`
- Modify: `tactical-grid/client/data/RESOURCE_MANIFEST.md`

**Consumes:** `settings.master_volume`、`music_volume`、`sfx_volume`。

**Produces:** Master/Music/SFX 总线与 `AudioManager.play_sfx(event_id)`，覆盖菜单、战斗、Boss、胜负和关键操作。

- [ ] **Step 1: 写失败测试**

断言 `AudioServer.get_bus_index("Music")` 和 `"SFX"` 不为 -1；第一章关键事件 ID 都映射 manifest 中存在音频；设置音量后对应总线 dB 改变。

- [ ] **Step 2: 确认红灯**

Run: Task 1 Step 2 命令。

Expected: FAIL，缺总线或事件映射。

- [ ] **Step 3: 实施音频**

创建短 UI、脚步、枪击、命中、爆炸、治疗、胜利、失败音效及菜单/普通战斗/Boss 循环音乐。配置总线，Boot 分别应用三条音量设置，播放器通过 AudioManager 创建和回收。

- [ ] **Step 4: 确认绿灯**

Run: Task 1 Step 2 命令；手动检查音量即时生效、切场景不叠加音乐、暂停不丢失 UI 音效。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/assets/audio/chapter1 tactical-grid/client/default_bus_layout.tres tactical-grid/client/scripts/game/audio_manager.gd tactical-grid/client/scripts/ui/boot.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/battle_smoke_test_runner.gd tactical-grid/client/data/RESOURCE_MANIFEST.md
git commit -m "feat: add chapter one audio feedback"
```

## Task 8: Windows 第一章候选构建与验收

**Files:**
- Modify: `tactical-grid/client/export_presets.cfg`
- Create: `tactical-grid/BUILDING_WINDOWS.md`
- Create: `tactical-grid/client/tests/verify_export.ps1`
- Modify: `docs/PROJECT_TAKEOVER_ROADMAP.md`

**Consumes:** export preset、第一章资源、Godot 4.7.1 export templates。

**Produces:** Windows x64 exe、构建说明、导出检查脚本和验收记录。

- [ ] **Step 1: 写失败导出检查**

`verify_export.ps1` 检查 exe、文件版本、产品名、资源清单；检查导出目录不含 node_modules、服务器源码、测试数据库和带水印历史图片。缺项必须非零退出。

- [ ] **Step 2: 确认红灯**

Run: `& .\\tests\\verify_export.ps1 -ExportPath ..\\export\\TacticalGrid-Windows-x64.exe`。

Expected: FAIL，因为候选包尚未导出。

- [ ] **Step 3: 导出候选包**

设置正式版本、版权、产品说明与图标，然后运行：

```powershell
& 'D:\\Program Files\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop x64' '..\\export\\TacticalGrid-Windows-x64.exe'
```

在 `BUILDING_WINDOWS.md` 记录 Godot 版本、命令、存档位置与验收步骤。

- [ ] **Step 4: 发布回归**

Run:

```powershell
& .\\tests\\verify_export.ps1 -ExportPath ..\\export\\TacticalGrid-Windows-x64.exe
& 'D:\\Program Files\\Godot\\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_smoke_test.tscn
```

在干净目录启动 exe，创建存档、进入 `ch1_m1`、返回主菜单、继续存档，并更新路线图证据。

- [ ] **Step 5: 提交**

```powershell
git add -- tactical-grid/client/export_presets.cfg tactical-grid/BUILDING_WINDOWS.md tactical-grid/client/tests/verify_export.ps1 docs/PROJECT_TAKEOVER_ROADMAP.md
git commit -m "build: package chapter one windows candidate"
```

## Plan Self-Review

- 第一章规格中的流程、成长、教程、规则、Boss、资源、音频和发布条件分别由 Task 1 至 Task 8 覆盖。
- 第二至第五章、Roguelike、全结局与全战役平衡不在本计划内，符合已批准规格。
- 每个任务都定义了失败测试、红灯命令、最小实现、绿灯验证和限定提交范围。
- 所有新接口都在其消费任务之前的相同任务中定义，或已在现有项目中存在。
