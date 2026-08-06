# Tactical Grid V2 P10 Release and Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 H2 内容锁版本验证、打包为干净 Windows 账户可独立启动、保存、继续和完成 M1 的第一章候选版，并形成可审计的发布证据。

**Architecture:** `run_v2_gate.ps1` 汇总代码、数据、场景、资源和日志门；视觉、音频、性能、长时、干净克隆和人工测试生成独立证据。`build_v2_windows.ps1` 只从已验证 commit 导出，复制法律文件、验证包结构并生成 SHA-256，不把源码、测试或内部计划装入发布包。

**Tech Stack:** Godot 4.7.1 Windows Desktop x64 export、PowerShell、GL Compatibility、Windows 10/11、SHA-256。

## Global Constraints

- 依赖 H2 `decision: PASS`，玩法和内容已冻结。
- 发布目标 Windows 10/11 x64、鼠标键盘、Godot 4.7.1、GL Compatibility；手柄不是第一章阻断项。
- 发布文件名固定 `TacticalGridV2-Infiltration.exe`，目录固定仓库级 `artifacts/v2/windows/`。
- 发布包不得包含 V1 存档、测试、工具、源图、生成提示、内部路线图、未授权参考资源或调试日志。
- 游戏无网络请求、无遥测、无账号和隐私数据收集。
- 候选版要求 0 崩溃、0 数据损坏、0 流程阻断、0 核心操作失效、0 严重或主要缺陷。
- 每个缺陷先有复现证据和测试；最终签核必须由项目负责人执行。

---

### Task R01: 完整可访问性矩阵

**Executor:** Terra high；项目负责人视觉与操作验收。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_accessibility_matrix_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_accessibility_matrix_test.tscn`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_visual_mode.gd`
- Modify: `tactical-grid/client/scripts/ui/settings_menu.gd`
- Modify: `tactical-grid/client/scenes/settings_menu.tscn`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Output: `artifacts/v2/verification/p10/accessibility_matrix.csv`

**Interfaces:**
- Resolutions: `1280×720/1920×1080`。
- UI scales: `100%/125%/150%`。
- Visual modes: `normal/grayscale/deuteranopia_assist`。
- Motion: `normal/reduce_motion`；shake: `on/off`。

- [ ] **Step 1: 写 2×3×3×2 组合场景合同**

```gdscript
for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
    for scale in [1.0, 1.25, 1.5]:
        for mode in [&"normal", &"grayscale", &"deuteranopia_assist"]:
            for reduce_motion in [false, true]:
                apply_case(resolution, scale, mode, reduce_motion)
                t.check(no_control_outside_viewport(), "控件不越界")
                t.check(primary_objective_visible(), "主目标可见")
                t.check(move_and_attack_shapes_distinct(), "蓝红范围有形状差异")
```

- [ ] **Step 2: 运行并保存每个失败组合**

- [ ] **Step 3: 修复缩放、裁切、只靠颜色和动态设置遗漏**

设置必须重启保持；暂停菜单随时显示目标和操作。键位重映射冲突显示明确错误，不覆盖另一个动作。

- [ ] **Step 4: 运行 36 组合自动合同和人工抽查**

人工至少抽查 720p 150% 灰度减少动态、1080p 100% 普通和 1080p 125% 绿色盲辅助。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tests/v2 tactical-grid/client/scripts/v2/presentation tactical-grid/client/scripts/ui tactical-grid/client/scenes/settings_menu.tscn
git commit -m "fix(v2): close accessibility matrix"
```

### Task R02: 存档损坏、备份、未来版本和 V1 拒绝

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_save_release_test.gd`
- Modify: `tactical-grid/client/scripts/network/save_manager.gd`
- Modify: `tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Output: `artifacts/v2/verification/p10/save_matrix.md`

**Interfaces:**
- Supported version: `2.0.0`；game line: `v2_infiltration`；slots: `0..2`。

- [ ] **Step 1: 写三槽和拒绝矩阵测试**

测试：正常 V2；主文件损坏/备份正常；主/备份都损坏；`save_version=99.0.0`；缺 `game_line`；`game_line=v1_tactical_network`；M3 检查点；章节完成存档。每个槽位使用唯一 mission 标记，断言不串档。

- [ ] **Step 2: 运行并记录每个错误的当前行为**

- [ ] **Step 3: 修复为明确且可恢复的结果**

损坏主文件自动尝试备份并显示一次恢复提示；双损坏不覆盖原文件，允许新建或选择其他槽；未来版本和 V1 存档只拒绝，不迁移、不删除。临时文件写成功后再原子替换主文件。

- [ ] **Step 4: 运行存档矩阵、退出重启和检查点恢复**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tests/v2/v2_save_release_test.gd tactical-grid/client/scripts/network/save_manager.gd tactical-grid/client/scripts/v2/mission/v2_campaign_progress.gd tactical-grid/client/tests/v2/gate_manifest.json
git commit -m "fix(v2): harden release save recovery"
```

### Task R03: 全视觉矩阵和 UI 重叠检查

**Executor:** Terra high 自动截图；项目负责人人工审图。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_release_visual_matrix.gd`
- Create: `tactical-grid/client/tests/v2/v2_release_visual_matrix.tscn`
- Create: `tactical-grid/client/tools/v2/run_visual_matrix.ps1`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Output: `artifacts/v2/verification/p10/visual/**.png`
- Output: `artifacts/v2/verification/p10/visual_review.md`

**Interfaces:**
- Stages: M1 `start/selected/attack/rescue/evac`；base four characters；five enemy intents；M6 `shielded/exposed`；dialogue/result/settings/pause。

- [ ] **Step 1: 写截图文件、尺寸、alpha 和锚点检查**

每张图必须非空、尺寸准确；顶部目标、底部状态和右侧信息卡在可视区；关键地图区域未被全屏不透明 UI 遮挡。文件名使用固定组合，例如 `1280x720_normal_m1_start.png`、`1920x1080_grayscale_m6_exposed.png`。

- [ ] **Step 2: 生成矩阵并列出缺图或布局失败**

- [ ] **Step 3: 修复 z-index、Control 锚点、肖像、长中文和状态叠层**

- [ ] **Step 4: 人工逐张审查并记录 PASS/FAIL 和问题坐标**

截图只验证构图和资源存在；至少实际运行 M1 和 M6 各一次观察动画与状态切换。

- [ ] **Step 5: 提交工具和修复，不提交截图产物**

```powershell
git add tactical-grid/client/tests/v2 tactical-grid/client/tools/v2 tactical-grid/client/scripts tactical-grid/client/scenes
git commit -m "fix(v2): close release visual matrix"
```

### Task R04: 音频格式、峰值、循环和混音

**Executor:** Terra high 技术检查；项目负责人听感验收。

**Files:**
- Create: `tactical-grid/client/tools/v2/test_v2_audio_release.ps1`
- Create: `tactical-grid/client/tests/v2/v2_audio_mix_test.gd`
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Modify: `tactical-grid/client/default_bus_layout.tres`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`
- Output: `artifacts/v2/verification/p10/audio_report.csv`
- Output: `artifacts/v2/verification/p10/listening_review.md`

**Interfaces:**
- Buses: `Master/Music/SFX`；all settings persist independently。

- [ ] **Step 1: 写 WAV 格式、峰值、近静音、重复哈希和循环差测试**

脚本读取 RIFF/WAVE fmt/data，拒绝峰值超过 0 dBFS、峰值低于可听阈值、重复内容和环境循环首尾明显跳变。

- [ ] **Step 2: 运行并输出每个文件的峰值与时长**

- [ ] **Step 3: 重混超限文件和总线音量**

同时八个 SFX 播放无削波；对话/提示不被音乐掩盖；潜伏、交战、Boss 护盾、暴露和胜利切换无空白或硬截断。

- [ ] **Step 4: 人工耳机与扬声器各听一次 M1/M6**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tools/v2 tactical-grid/client/tests/v2 tactical-grid/client/scripts/game/audio_manager.gd tactical-grid/client/default_bus_layout.tres tactical-grid/client/assets/v2/runtime/audio
git commit -m "audio(v2): close release mix checks"
```

### Task R05: 720p/1080p 性能和敌方回合时长

**Executor:** Sol high。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_performance_probe.gd`
- Create: `tactical-grid/client/tests/v2/v2_performance_scenario.gd`
- Create: `tactical-grid/client/tests/v2/v2_performance_scenario.tscn`
- Create: `tactical-grid/client/tools/v2/run_performance_matrix.ps1`
- Output: `artifacts/v2/verification/p10/performance.csv`
- Output: `artifacts/v2/verification/p10/test_machine.json`

**Interfaces:**
- CSV columns: `scenario/resolution/frame_count/avg_ms/p95_ms/min_fps/max_memory_mb/enemy_turn_ms`。

- [ ] **Step 1: 写性能记录完整性测试**

场景固定为 M1 最大三敌、M4 最大四敌、M6 Boss+四敌和 150% UI。每场预热 300 帧、采样 1800 帧，不把加载帧算入。

- [ ] **Step 2: 运行基线并记录测试机 CPU/GPU/内存/系统/渲染器**

- [ ] **Step 3: 优化持续低于 55 FPS、p95 超过 18.2 ms 或敌方回合超过 8 秒的问题**

优先减少重复范围重建、纹理加载、意图重复规划和每帧 UI 布局；不降低范围、意图、迷雾和伤害信息。

- [ ] **Step 4: 在 720p/1080p 重跑并确认普通战斗目标 60 FPS**

最低配置只能在 Windows 10 x64、四核、8 GB 和兼容集显或等价环境实测后公布。

- [ ] **Step 5: 提交探针和优化**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_performance_probe.gd tactical-grid/client/tests/v2 tactical-grid/client/tools/v2 tactical-grid/client/scripts
git commit -m "fix(v2): meet release performance targets"
```

### Task R06: 两小时长时和 M1 十次重载

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/tests/v2/v2_soak_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_soak_test.tscn`
- Create: `tactical-grid/client/tests/v2/v2_reload_stress_test.gd`
- Create: `tactical-grid/client/tests/v2/v2_reload_stress_test.tscn`
- Create: `tactical-grid/client/tools/v2/run_soak_tests.ps1`
- Output: `artifacts/v2/verification/p10/soak.csv`
- Output: `artifacts/v2/verification/p10/reload_stress.md`

**Interfaces:**
- Soak samples every 60 seconds: process memory、node count、orphan count、audio players、turn count、scene transitions。

- [ ] **Step 1: 写十次 M1 加载/卸载残留测试**

每次加载 M1、完成一个回合、返回基地、等待两帧；断言单位组为空、信号未重复、AudioStreamPlayer 数回到基线、保存当前任务正确。

- [ ] **Step 2: 运行十次并修复首个残留**

- [ ] **Step 3: 运行两小时自动回合长时场景**

内存预热后不得持续上升；末尾相对第 15 分钟稳定值增长不超过 5%，无崩溃、无播放器耗尽、无重复信号。

- [ ] **Step 4: 重跑完整长时并保存退出码和摘要**

- [ ] **Step 5: 提交测试和修复**

```powershell
git add tactical-grid/client/tests/v2 tactical-grid/client/tools/v2 tactical-grid/client/scripts
git commit -m "fix(v2): pass soak and reload stress"
```

### Task R07: Windows V2 产品身份和导出路径

**Executor:** Sol high。

**Files:**
- Modify: `tactical-grid/client/export_presets.cfg`
- Modify: `tactical-grid/client/project.godot`
- Create: `tactical-grid/client/tools/v2/build_v2_windows.ps1`
- Create: `tactical-grid/client/tests/v2/verify_v2_windows_package.ps1`
- Create: `tactical-grid/client/assets/v2/runtime/ui/v2_icon.ico`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`

**Interfaces:**
- Preset name: `Windows Desktop x64`。
- Product/file version: `0.9.0.0`；project version: `0.9.0-v2`；save schema remains `2.0.0`；product name: `Tactical Grid V2: Infiltration`。
- Export: `../../artifacts/v2/windows/TacticalGridV2-Infiltration.exe`。

- [ ] **Step 1: 写导出配置失败检查**

```powershell
$preset = Get-Content export_presets.cfg -Raw
if ($preset -notmatch 'export_path="\.\./\.\./artifacts/v2/windows/TacticalGridV2-Infiltration.exe"') { throw 'Wrong V2 export path' }
if ($preset -notmatch 'application/product_name="Tactical Grid V2: Infiltration"') { throw 'Wrong product name' }
if ($preset -notmatch 'application/product_version="0.9.0.0"') { throw 'Wrong product version' }
if ((Get-Content project.godot -Raw) -notmatch 'config/version="0.9.0-v2"') { throw 'Wrong project version' }
if ($preset -match 'build/TacticalGrid.exe') { throw 'V1 export path remains' }
```

- [ ] **Step 2: 运行并确认当前 V1 产品名/路径导致失败**

- [ ] **Step 3: 更新 preset、图标、过滤和构建脚本**

exclude 至少包含 `assets/v2/source/*,tests/*,tools/*,build/*`；runtime 资源必须包含。构建脚本先运行完整 V2 门，再 export-release，失败立即停止。

- [ ] **Step 4: 导出并验证 PE 文件名、版本资源、PCK 和禁入目录**

Run: `powershell -ExecutionPolicy Bypass -File tools/v2/build_v2_windows.ps1`

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/export_presets.cfg tactical-grid/client/project.godot tactical-grid/client/tools/v2 tactical-grid/client/tests/v2 tactical-grid/client/assets/v2/runtime/ui tactical-grid/client/data/v2/resource_manifest.md
git commit -m "build(v2): isolate Windows product identity"
```

### Task R08: 许可证、第三方声明、隐私和资源清单

**Executor:** Terra high；Sol xhigh 审核缺项。法律内容为项目事实记录，不替代专业法律意见。

**Files:**
- Create: `tactical-grid/client/release/v2/LICENSE.txt`
- Create: `tactical-grid/client/release/v2/THIRD_PARTY_NOTICES.txt`
- Create: `tactical-grid/client/release/v2/PRIVACY.txt`
- Create: `tactical-grid/client/release/v2/README.txt`
- Modify: `tactical-grid/client/tools/v2/build_v2_windows.ps1`
- Modify: `tactical-grid/client/tools/v2/verify_resource_manifest.ps1`
- Output: `artifacts/v2/verification/p10/legal_audit.md`

**Interfaces:**
- Build copies four text files and a generated `RESOURCE_MANIFEST.txt` next to exe。

- [ ] **Step 1: 写发布法律文件存在和禁用词检查**

检查无“来源不明”“许可证未确认”等条目；第三方声明逐项对应清单中的 open_source；隐私文件明确离线、本地存档、无遥测、无账号、无网络请求。

- [ ] **Step 2: 运行资源清单和许可证交叉校验**

- [ ] **Step 3: 写正式文本并让构建脚本复制**

README 包含系统要求、启动方式、控制、存档位置、卸载说明、版本和问题报告信息。不得把内部路线图或生成提示放进发布包。

- [ ] **Step 4: 重新构建并检查五个文本文件可读取**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/release/v2 tactical-grid/client/tools/v2
git commit -m "docs(v2): add release legal notices"
```

### Task R09: 干净克隆和干净 Windows 账户验证

**Executor:** Sol xhigh；项目负责人执行真实账户部分。

**Files:**
- Create: `tactical-grid/client/tools/v2/verify_clean_clone.ps1`
- Create: `docs/v2/release/CLEAN_ACCOUNT_PROTOCOL.md`
- Output: `artifacts/v2/verification/p10/clean_clone.md`
- Output: `artifacts/v2/verification/p10/clean_account.md`

**Interfaces:**
- Temporary clone root fixed under `artifacts/v2/clean-clone/` after resolving absolute path inside worktree。

- [ ] **Step 1: 写干净克隆脚本的路径保护和步骤**

脚本验证目标绝对路径以当前 worktree 的 `artifacts\v2\clean-clone` 开头后才清理旧目录；从当前 commit 克隆，运行 Godot import、V2 门、构建和包验证。不复制 `.godot`、用户存档或现有 artifacts。

- [ ] **Step 2: 运行干净克隆并记录 commit 与命令退出码**

- [ ] **Step 3: 在新 Windows 本地账户执行人工协议**

启动、创建槽位、选择标准难度、完成 M1、修改音量/文字、退出、重新启动、继续基地、删除一个槽位、退出。确认 V1 存档不出现，窗口和任务管理器产品名带 V2。

- [ ] **Step 4: 记录账户环境、截图和 PASS/FAIL**

- [ ] **Step 5: 提交脚本和协议，不提交账户数据**

```powershell
git add tactical-grid/client/tools/v2/verify_clean_clone.ps1 docs/v2/release/CLEAN_ACCOUNT_PROTOCOL.md
git commit -m "test(v2): verify clean release environments"
```

### Task R10: 发布缺陷分级和清零

**Executor:** Sol xhigh。

**Files:**
- Create: `docs/v2/release/DEFECT_POLICY.md`
- Create: `docs/v2/release/RELEASE_DEFECT_TRIAGE.md`
- Output: `artifacts/v2/verification/p10/defects.csv`

**Interfaces:**
- Severities: `blocker/critical/major/minor`。
- CSV: `id/severity/area/reproduction/expected/actual/test/owner/fix_commit/status/retest_evidence`。
- Produces `RELEASE_DEFECT_TRIAGE.md`, mapping every defect ID to one source task and prohibiting unscoped fixes。

- [ ] **Step 1: 汇总 H2、R01-R09 的所有缺陷**

- [ ] **Step 2: 为 blocker/critical/major 和可自动化 minor 写失败测试**

- [ ] **Step 3: 将每个缺陷退回来源任务并独立最小修复**

`RELEASE_DEFECT_TRIAGE.md` 记录缺陷 ID、来源任务和对应的准确 Files/验证命令。修复者回到来源任务增加回归测试并使用该任务文件边界；提交信息描述可观察行为，例如 `fix(v2): restore end-turn controls after enemy phase`，CSV 写入 fix commit。纯文字、单像素或不影响理解的 minor 也必须记录处理结论。

- [ ] **Step 4: 重跑缺陷复现、直接合同和完整 V2 门**

- [ ] **Step 5: 确认 0 blocker、0 critical、0 major**

未达到时不得执行 R11。

```powershell
git add docs/v2/release/DEFECT_POLICY.md docs/v2/release/RELEASE_DEFECT_TRIAGE.md
git commit -m "docs(v2): define release defect policy"
```

### Task R11: 候选版完整发布门和 SHA-256

**Executor:** Sol xhigh；Terra xhigh 独立审查。

**Files:**
- Modify: `tactical-grid/client/tests/v2/run_v2_gate.ps1`
- Modify: `tactical-grid/client/tools/v2/build_v2_windows.ps1`
- Create output: `artifacts/v2/windows/SHA256SUMS.txt`
- Create output: `artifacts/v2/verification/p10/RC_GATE_SUMMARY.md`

**Interfaces:**
- Gate stages exact order: import、unit/contract、E2E、resource manifest、audio、visual generation、save、performance smoke、package verification、log gate。

- [ ] **Step 1: 将 R01-R09 自动检查加入唯一 V2 门**

每一阶段显示 `[n/total]`，任一失败立即 exit 1。人工证据只检查文件存在、日期、commit 和 decision，不伪造人工结果。

- [ ] **Step 2: 从干净工作树运行完整门并保存原始日志**

Run: `powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1 *> artifacts/v2/verification/p10/rc_gate.log`

- [ ] **Step 3: 运行 release build 和包验证**

Run: `powershell -ExecutionPolicy Bypass -File tools/v2/build_v2_windows.ps1`

- [ ] **Step 4: 生成 SHA-256 并核对包内文件**

```powershell
Get-ChildItem ..\..\artifacts\v2\windows -File | Where-Object Name -ne 'SHA256SUMS.txt' |
    Get-FileHash -Algorithm SHA256 | ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" }
```

Expected: 0 测试失败、0 非预期错误、0 非预期警告；exe、pck、五个发布文本和哈希清单存在；包中无 tests/tools/source/plans。

- [ ] **Step 5: 提交发布门变更**

```powershell
git add tactical-grid/client/tests/v2/run_v2_gate.ps1 tactical-grid/client/tools/v2/build_v2_windows.ps1
git commit -m "build(v2): pass release candidate gate"
```

### Task R12: 发布说明、版本标签和归档

**Executor:** Terra high；Sol xhigh 复核。

**Files:**
- Create: `docs/v2/release/RELEASE_NOTES_0.9.0.md`
- Create: `docs/v2/release/FINAL_ACCEPTANCE_CHECKLIST.md`
- Modify: `README.md`
- Modify: `docs/v2/README.md`
- Modify: `tactical-grid/PROJECT_STATUS_V2.md`
- Modify: `docs/superpowers/plans/2026-08-05-v2-master-implementation.md`

**Interfaces:**
- Candidate tag: `v2-chapter1-0.9.0-rc1`；final chapter tag: `v2-chapter1-0.9.0`。

- [ ] **Step 1: 写基于真实 commit 和证据的发布说明**

包含六关、四角色、两难度、控制、存档位置、系统要求、已知 minor、许可证入口、SHA-256 和 V1/V2 兼容说明。产品版本固定写入 project `0.9.0-v2` 和 Windows `0.9.0.0`；存档模式继续使用 `2.0.0`，不因产品版本变化而迁移。

- [ ] **Step 2: 更新入口文档为候选状态并运行链接检查**

- [ ] **Step 3: 运行最终文档、配置和 Git 状态审查**

- [ ] **Step 4: 在 H3 通过后创建带注释标签**

```powershell
git tag -a v2-chapter1-0.9.0-rc1 -m "Tactical Grid V2 Chapter One 0.9.0 release candidate 1"
```

只有项目负责人明确批准正式章版本后才创建最终 `v2-chapter1-0.9.0` 标签并推送。

- [ ] **Step 5: 提交文档**

```powershell
git add README.md docs/v2 tactical-grid/PROJECT_STATUS_V2.md docs/superpowers/plans/2026-08-05-v2-master-implementation.md
git commit -m "docs(v2): prepare chapter one release candidate"
```

### Task H3: 第一章候选版签核

**Executor:** 项目负责人；AI 只汇总证据。

**Files:**
- Output: `artifacts/v2/verification/p10/H3_SIGNOFF.md`

**Acceptance:**

- [ ] 六关从新档连续可完成并出现明确结局。
- [ ] H1 与 H2 均有真实玩家 PASS 证据。
- [ ] 四角色、五类通用敌人、猎手、Boss、正式 UI、VFX 和音频均无占位。
- [ ] 自动测试、视觉矩阵、音频、性能、两小时长时、十次重载、存档恢复通过。
- [ ] 干净克隆和干净 Windows 账户通过。
- [ ] 资源来源、许可证、隐私和第三方声明完整。
- [ ] Windows 包名、产品名、版本、用户目录和产物目录全部是 V2。
- [ ] 0 blocker、0 critical、0 major；已知 minor 全部有处理结论。
- [ ] 发布包 SHA-256 与 `SHA256SUMS.txt` 一致。
- [ ] V1 worktree、存档、文档和发布产物未被修改或覆盖。

全部满足时 `H3_SIGNOFF.md` 写签核日期、commit、包哈希、测试摘要和 `decision: APPROVED`。任何一项缺证据时写 `decision: NOT APPROVED` 并返回对应 R 任务；不得仅因计划任务已勾选而声明游戏完成。
