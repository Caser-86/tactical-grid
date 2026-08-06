# V2 Mission Art and Audio Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 M1/M2 的路线、设施、危险区、营救和中段变化接入可读的正式场内反馈，并复用现有合法资源，避免只生成图片不接入游戏。

**Architecture:** 优先使用现有 `ArtCatalog` 运行时组件和程序化 `Polygon2D`/`Line2D` 状态覆盖；只有缩放验证证明现有资源无法区分时，才生成新的小型透明资源。音频使用现有项目自有 WAV 和程序化短提示音，所有资源在 V2 manifest 中登记。

**Tech Stack:** Godot 4.7.1、GDScript、现有 PNG/WAV、PowerShell 资源处理脚本、Windows Compatibility 视觉矩阵。

## Global Constraints

- 不直接渲染 V1 source/styleboard；运行时只使用处理后的组件。
- 状态不能只用红绿颜色表达，危险区至少同时使用形状、纹理或方向符号。
- 角色 token 在约 76 像素缩放下仍可区分；新增图像必须是 RGBA、透明背景、明确尺寸。
- 每个资源都要记录来源、许可证、处理方式、运行时路径和用途。

---

### Task 1: 程序化设施状态表现

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_facility_state_presenter.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_facility_state_visual_test.gd`

**Interfaces:**
- `V2FacilityStatePresenter.render(facility: Dictionary, cell_size: Vector2) -> Node2D`。
- States: `neutral`, `available`, `selected`, `offline`, `open`, `closed`, `uploaded`, `destroyed`。
- Facility overlay must expose `facility_id`, state glyph, and interaction range without blocking map input.

- [ ] **Step 1: 写状态视觉合同测试**

构造摄像头、吊机、电力、门、记录终端和冷却控制台的每种状态，断言节点存在、颜色之外还有符号或线型、节点 `mouse_filter` 不阻断地图点击。

- [ ] **Step 2: 实现程序化覆盖层**

用 `Polygon2D` 绘制方向箭头、`Line2D` 绘制通路和狙击线、`Label` 绘制短状态词；不同状态修改透明度和纹理方向，不创建新的复杂菜单。

- [ ] **Step 3: 接入战斗控制器刷新事务**

设施提交后只更新对应设施节点和 HUD 快照；地图状态变化通过同一 `state_revision` 刷新，避免视觉显示与逻辑状态错帧。

- [ ] **Step 4: 运行视觉合同测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_facility_state_visual_test.gd
```

- [ ] **Step 5: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_facility_state_presenter.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_facility_state_visual_test.gd
git commit -m "feat(v2): render readable facility state overlays"
```

### Task 2: M1 吊机、封锁和撤离状态

**Files:**
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_facility_state_presenter.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`

- [ ] **Step 1: 接入吊机两态**

未放下显示断开的黄色通路和“吊机未放下”；放下显示连续通路、方向箭头和“撤离替代路线”。

- [ ] **Step 2: 接入营救后封锁**

旧东北通道显示斜纹封锁覆盖，吊机通路保持可读；撤离拦截敌人显示预警边框但不提前暴露战争迷雾外单位。

- [ ] **Step 3: 运行 M1 快照阶段**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m1_visual_matrix.ps1
```

重点人工检查路线差异、吊机结果、记录奖励和撤离区是否在 1280×720 下仍可见。

- [ ] **Step 4: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_facility_state_presenter.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd
git commit -m "feat(v2): present M1 route and evacuation consequences"
```

### Task 3: M2 涡轮、喷口、电力和狙击预告状态

**Files:**
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_facility_state_presenter.gd`
- Create: `tactical-grid/client/scripts/v2/presentation/v2_hazard_presenter.gd`
- Modify: `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- Create: `tactical-grid/client/tests/v2/v2_hazard_visual_test.gd`

**Interfaces:**
- `V2HazardPresenter.render(snapshot: Dictionary) -> Node2D`.
- Hazard states: `safe`, `warning`, `active`, `closed`.
- Warning display includes a triangular icon, striped cell overlay and countdown text such as `下回合喷发`.

- [ ] **Step 1: 写危险区视觉测试**

断言四种状态分别可渲染、warning 有倒计时、active 有方向纹理、closed 保留关闭标记；灰阶模式仍可区分。

- [ ] **Step 2: 实现危险区覆盖层**

使用固定网格层和 `Line2D`，在战斗逻辑提供 `warning_cells` 时渲染一回合预告；敌方阶段结算后切换为 active，再在下一玩家阶段清理。

- [ ] **Step 3: 实现狙击预告线**

用黄白虚线表示敌方预瞄方向，用三角警告符表示危险端点；不依赖红色单色，也不显示迷雾外真实单位位置。

- [ ] **Step 4: 接入中央涡轮地标**

使用现有 Cooling Works `cooling_tower_base_192x128.png` 和 `turbine_manifold_128.png`，通过环境 kit 和地图装饰数据组合，不生成新大图。

- [ ] **Step 5: 运行危险视觉测试**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_hazard_visual_test.gd
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_m2_visual_matrix.ps1
```

- [ ] **Step 6: Commit**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_facility_state_presenter.gd tactical-grid/client/scripts/v2/presentation/v2_hazard_presenter.gd tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd tactical-grid/client/tests/v2/v2_hazard_visual_test.gd
git commit -m "feat(v2): integrate M2 hazard and sniper telegraphs"
```

### Task 4: 音频反馈整合

**Files:**
- Create: `tactical-grid/client/tools/generate_v2_mission_audio.ps1`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_gantry_open.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_hazard_warning.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_hazard_active.wav`
- Create: `tactical-grid/client/assets/audio/sfx/sfx_v2_facility_confirm.wav`
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Modify: `tactical-grid/client/assets/audio/README.md`

- [ ] **Step 1: 先复用并验证现有音频**

将 `sfx_network_takeover.wav`、`sfx_alert_rise.wav`、`sfx_overwatch_trigger.wav` 和 `sfx_network_disable.wav` 分别映射到路线提交、警戒变化、狙击预告和设施关闭；只有缺少可区分反馈时才运行生成脚本。

- [ ] **Step 2: 生成短提示音**

生成脚本固定输出 PCM WAV、44.1 kHz、单声道或立体声、0.2 至 1.2 秒，并在重复执行时覆盖同名 V2 文件，不改 V1 音频。

- [ ] **Step 3: 接入事件映射**

事件映射固定为 `gantry_lowered`、`cooling_warning_started`、`cooling_active`、`facility_action_committed`、`character_rescued`；每个事件只播放一次，检查点恢复不重复播放历史事件。

- [ ] **Step 4: 运行音频资产检查**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/test_audio_assets.ps1
```

- [ ] **Step 5: 更新资源清单并提交**

在 `data/v2/resource_manifest.md` 和 `assets/audio/README.md` 记录每个 WAV 的来源、许可证、格式、用途和运行时路径。

```powershell
git add tactical-grid/client/tools/generate_v2_mission_audio.ps1 tactical-grid/client/assets/audio tactical-grid/client/scripts/game/audio_manager.gd tactical-grid/client/data/v2/resource_manifest.md
git commit -m "feat(v2): add mission state audio feedback"
```

### Task 5: 资源缩放和导入验收

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_art_import_contract_test.gd`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/assets/v2/README.md`

- [ ] **Step 1: 检查图像规格**

断言 V2 token 为 128×128 RGBA、环境状态图为明确尺寸、所有运行时文件存在；source 图不被任何运行时脚本直接加载。

- [ ] **Step 2: 运行缩放快照**

在 M1/M2 视觉矩阵中检查 76 像素左右单位的轮廓、主色块、武器/盾牌/无人机结构；若不可读，先修改程序化轮廓或缩放，再决定是否调用图像生成工具。

- [ ] **Step 3: 提交导入验收**

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_art_import_contract_test.gd
git add tactical-grid/client/tests/v2/v2_art_import_contract_test.gd tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/assets/v2/README.md
git commit -m "test(v2): validate mission art import and provenance"
```
