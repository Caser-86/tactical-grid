# Tactical Grid V2 P4-P6 Art and Shared Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 H1 通过后制作并接入统一、可辨认、无占位的四方向角色、敌人、环境、肖像、图标、VFX 和音频，并把 M1 提升为正式垂直切片。

**Architecture:** IMAGE2 只生成带明确来源记录的高分辨率源图；PowerShell 工具完成色键、裁切、缩放、透明边缘和命名，Godot Catalog 只加载 `assets/v2/runtime/`。先做 M1 五项小样和五人辨识门，之后才批量生成共享内容；环境优先审计复用现有合法资源，再程序化补齐结构类别。

**Tech Stack:** IMAGE2、PowerShell、System.Drawing、Godot 4.7.1 Image/Texture2D、现有 UnitSprite、程序化 CanvasItem VFX、PCM WAV 生成器。

## Global Constraints

- A02 之前必须有 H1 `decision: PASS` 证据。
- 保持 2D 正交俯视、浅体积科幻工业风；不制作 3D、等距斜视或透视微缩场景。
- 普通单位运行时图固定 96×96 透明 PNG，核心轮廓约 56×56；Boss 至少 128×128。
- 每个方向必须是独立绘制，不得只旋转同一张图。
- 阵营底环和职业颜色只辅助辨识，移除底环和名称后仍能区分角色职责。
- 禁止来源不明、带水印、商业游戏提取或许可证不明资源；不在提示词中要求模仿在世艺术家或具体商业游戏。
- 源图、运行时图、处理命令和清单同批提交；运行时截图与辨识结果写入 `artifacts/v2/verification/`。
- 发布包排除 `assets/v2/source/`、生成提示、内部计划和测试工具。

---

## Runtime Naming Contract

```text
assets/v2/source/units/player/assault_four_view_v01.png
assets/v2/source/units/enemy/sentry_four_view_v01.png
assets/v2/runtime/units/player/assault/north.png
assets/v2/runtime/units/enemy/sentry/east.png
assets/v2/runtime/portraits/assault.png
assets/v2/runtime/landmarks/ch1_m1_echo_crane.png
assets/v2/runtime/icons/abilities/impact_advance.png
assets/v2/runtime/icons/passives/close_armor.png
assets/v2/runtime/icons/modules/assault_a.png
assets/v2/runtime/icons/intents/attack.png
assets/v2/runtime/icons/objectives/rescue.png
assets/v2/runtime/environment/echo_yard/half_cover/cargo_barrier.png
assets/v2/runtime/vfx/shield_absorb.png
assets/v2/runtime/audio/abilities/impact_advance.wav
```

上述文件分别示范每种目录的确定命名；A02、A06-A11 列出的固定资源 ID 按同一规则展开。方向坐标约定：north 面向屏幕上方，east 面向右侧，south 面向下方，west 面向左侧。源图四象限顺序固定为 north/east/south/west。

### Task A01: 风格板、资源命名和清单模式

**Executor:** Sol xhigh。

**Files:**
- Create: `docs/v2/art/V2_ART_BIBLE.md`
- Create: `docs/v2/art/V2_IMAGE_PROMPTS.md`
- Create: `docs/v2/art/V2_RECOGNITION_PROTOCOL.md`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Create: `tactical-grid/client/tools/v2/verify_resource_manifest.ps1`
- Create: `tactical-grid/client/tests/v2/v2_resource_manifest_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Manifest table columns: `asset_id/source_path/runtime_path/source_type/generator_or_origin/license/generated_or_acquired_at/dimensions/import_settings/game_use/verified_by`。
- Source types: `ai_generated/procedural/existing_project/open_source`。

- [ ] **Step 1: 写清单缺项失败测试**

```gdscript
var manifest := FileAccess.get_file_as_string("res://data/v2/resource_manifest.md")
t.check(manifest.contains("| asset_id | source_path | runtime_path |"), "清单有固定列")
t.check(not manifest.contains("unknown"), "清单不允许未知来源")
t.check(not manifest.contains("license pending"), "清单不允许未核实许可证")
```

- [ ] **Step 2: 运行并确认当前清单缺少正式模式而失败**

- [ ] **Step 3: 写风格板与自动校验器**

风格板锁定：正交俯视、相机无透视、冷青主光从左上、暖橙设施辅光、炭黑工业材质、单位核心轮廓 56×56、背景色 `#00FF66` 只用于源图色键。`verify_resource_manifest.ps1` 枚举 `assets/v2/runtime` 所有文件，要求每个相对路径在清单中恰好出现一次，源路径存在，许可证非空，尺寸与文件匹配。

- [ ] **Step 4: 运行空运行时目录合同和 V2 门**

Expected: 当前无正式 runtime 文件时校验通过；以后新增任何未登记文件时失败。

- [ ] **Step 5: 提交**

```powershell
git add docs/v2/art tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tools/v2 tactical-grid/client/tests/v2
git commit -m "docs(v2): lock art direction and provenance"
```

### Task A02: M1 五项 IMAGE2 小样

**Executor:** IMAGE2 最高质量；Sol xhigh 负责提示和筛选。

**Files:**
- Create: `tactical-grid/client/assets/v2/source/units/player/assault_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/units/player/scout_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/units/enemy/sentry_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/units/enemy/drone_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/landmarks/ch1_m1_echo_crane_v01.png`
- Modify: `docs/v2/art/V2_IMAGE_PROMPTS.md`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`

**Interfaces:**
- Produces four-view sheets at 1024×1024 or tool nearest supported square size。
- Produces landmark source at 1536×1024 or nearest landscape size。

- [ ] **Step 1: 将以下基础提示写入提示记录**

```text
Original 2D orthographic top-down tactical game unit sprite source sheet, four isolated views in a strict 2x2 grid: north, east, south, west. Camera directly above with only a slight readable body volume, no perspective floor, no horizon, no environment. Compact science-fiction industrial armor, charcoal metal, cyan edge light from upper-left, warm amber secondary reflections. Entire body visible, centered in each quadrant, identical scale and equipment across views, crisp silhouette readable at 56 pixels. Flat chroma background #00FF66, no shadows outside the body, no text, no letters, no UI, no watermark, no border.
```

角色附加描述固定：

- 突击：`medium broad shoulders, short compact firearm, cyan forearm light strips, forward breach stance`。
- 侦察：`lowest crouched profile, short weapon, asymmetric antenna backpack, green leg armor and antenna light`。
- 哨兵：`upright angular machine body, single weapon arm, red front sensor, narrow legs`。
- 无人机：`flat wing silhouette, central circular scanner core, no humanoid legs, red-orange scanning ring`。
- 起重地标：`orthographic top-down cargo gantry crane, dark steel, weathered orange beams, cyan work lights, isolated object on #00FF66, no floor, no text`。

- [ ] **Step 2: 用 IMAGE2 分别生成五个源图，不在一个请求中混合角色**

每个请求只包含基础提示与对应附加描述。失败标准：透视地面、切掉身体、方向重复、比例变化、武器换型、文字、水印或背景非纯色。最多保留一个通过版本，不把失败候选放入 runtime。

- [ ] **Step 3: 检查源图技术条件**

使用图像查看工具逐张确认分辨率、四象限顺序、身体完整、光向一致和背景可色键。将实际工具名称、生成日期和文件 SHA-256 写入清单。

- [ ] **Step 4: 运行来源清单校验**

Run: `powershell -ExecutionPolicy Bypass -File tools/v2/verify_resource_manifest.ps1 -IncludeSource`

Expected: 五个源图均有 `ai_generated`、`OpenAI generated asset; project-owned output` 许可证说明和用途。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/assets/v2/source docs/v2/art/V2_IMAGE_PROMPTS.md tactical-grid/client/data/v2/resource_manifest.md
git commit -m "art(v2): add M1 directional source samples"
```

### Task A03: 小样透明、裁切、尺寸和导入处理

**Executor:** Terra high。

**Files:**
- Create: `tactical-grid/client/tools/v2/process_unit_art.ps1`
- Create: `tactical-grid/client/tools/v2/process_landmark_art.ps1`
- Create: `tactical-grid/client/assets/v2/runtime/units/player/assault/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/player/scout/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/enemy/sentry/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/enemy/drone/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/landmarks/ch1_m1_echo_crane.png`
- Create: `tactical-grid/client/tests/v2/v2_art_asset_contract_test.gd`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- `process_unit_art.ps1 -SourcePath assets/v2/source/units/player/assault_four_view_v01.png -Faction player -UnitId assault` writes four 96×96 PNGs；其余固定 ID 使用同一参数约定。
- `process_landmark_art.ps1` writes a 384×256 transparent PNG preserving base anchor。

- [ ] **Step 1: 写尺寸、alpha、轮廓占用和方向差异测试**

```gdscript
for path in expected_unit_paths:
    var image := Image.load_from_file(path)
    t.check(image.get_size() == Vector2i(96, 96), "%s 为 96×96" % path)
    t.check(image.detect_alpha() != Image.ALPHA_NONE, "%s 具有透明通道" % path)
    t.check(alpha_bounds(image).size.x >= 44 and alpha_bounds(image).size.x <= 72, "%s 轮廓宽度合格" % path)
t.check(file_sha256(assault_north) != file_sha256(assault_east), "方向不是同图复制")
```

- [ ] **Step 2: 确认 runtime 文件不存在而失败**

- [ ] **Step 3: 复用现有色键算法并固定处理参数**

脚本按四象限裁切，背景像素与 `#00FF66` 色差小于 90 时透明；保留半透明边缘，裁到主体边界后按最长边 64 像素缩放，放入 96×96 中心并使脚底锚点位于 `(48,78)`。PNG 使用 32-bit RGBA，不做有损压缩。Godot import 使用 filter on、mipmaps off、lossless。

- [ ] **Step 4: 处理五个源图、运行 Godot 导入和资产合同**

Expected: 16 个单位方向图、1 个地标通过；无绿色边缘和越界。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tools/v2 tactical-grid/client/assets/v2/runtime tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tests/v2
git commit -m "art(v2): process M1 runtime samples"
```

### Task A04: 四方向运行时映射和程序动画

**Executor:** Sol xhigh。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_unit_art_catalog.gd`
- Create: `tactical-grid/client/tests/v2/v2_unit_direction_test.gd`
- Modify: `tactical-grid/client/scripts/game/unit_sprite.gd`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces: `V2UnitArtCatalog.get_unit_texture(faction: StringName, art_key: StringName, direction: StringName) -> Texture2D`。
- Direction IDs: `north/east/south/west`。
- Unit states: `idle/move/attack/hit/ability/down`。

- [ ] **Step 1: 写移动和攻击方向切换测试**

```gdscript
sprite.set_art_identity(&"player", &"assault")
sprite.face_vector(Vector2.UP)
t.check(sprite.current_direction == &"north", "向上使用 north")
var north_texture := sprite.texture
sprite.face_vector(Vector2.RIGHT)
t.check(sprite.current_direction == &"east" and sprite.texture != north_texture, "向右切换独立 east")
sprite.play_state(&"attack", Vector2.LEFT)
t.check(sprite.current_direction == &"west", "攻击按目标方向转向")
```

- [ ] **Step 2: 确认现有旋转或单图映射不满足合同**

- [ ] **Step 3: 接入方向目录和程序动画**

主轴判定取绝对值更大的 x/y；无移动时保留上次方向。移动 0.16-0.24 秒插值；普攻 0.10 准备、0.08 后坐、0.12 恢复；受击短闪；能力使用角色色脉冲；倒地 0.25-0.4 秒缩小。减少动态关闭位移但保留状态时长和信息。

- [ ] **Step 4: 运行六状态、四方向、减少动态和 M1 场景合同**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation/v2_unit_art_catalog.gd tactical-grid/client/scripts/game/unit_sprite.gd tactical-grid/client/scripts/game/battle_controller.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): render independent unit directions"
```

### Task A05: 小样辨识和视觉模式门

**Executor:** 项目负责人组织五名观察者；Sol xhigh 汇总。

**Files:**
- Create output: `artifacts/v2/verification/art-sample/normal_720.png`
- Create output: `artifacts/v2/verification/art-sample/normal_1080.png`
- Create output: `artifacts/v2/verification/art-sample/grayscale_720.png`
- Create output: `artifacts/v2/verification/art-sample/deuteranopia_720.png`
- Create output: `artifacts/v2/verification/art-sample/recognition_results.csv`
- Create output: `artifacts/v2/verification/art-sample/decision.md`
- Create: `docs/v2/art/V2_ART_SAMPLE_DECISION.md`

**Interfaces:**
- Consumes A02-A04 runtime sample screenshots with all names, role labels, faction rings, and selection markers hidden.
- Produces `recognition_results.csv` with columns `participant_id,mode,assault,scout,sentry,drone,scout_role,landmark`.
- Produces `decision.md` with `decision: PASS|FAIL`, sample SHA-256 hashes, participant count, and failed criteria.
- Produces the tracked decision record `V2_ART_SAMPLE_DECISION.md`; only a `PASS` record unlocks A06-A13.

- [ ] **Step 1: 生成普通 720p、普通 1080p、灰度 720p 和绿色盲模拟 720p 四张固定截图**

- [ ] **Step 2: 由五名未参与制作的观察者按盲测协议填写逐项辨识结果**

- [ ] **Step 3: 计算所有通过指标并写入原始结果、哈希和失败项**

- [ ] **Step 4: 失败则回到 A02-A04 修正对应资产；通过则冻结样品哈希和视觉模式**

- [ ] **Step 5: 提交通过决策、最终样品哈希和必要的正式源图修正**

**Acceptance:**

- [ ] 隐藏名称、职业文字和阵营底环截图。
- [ ] 五人中至少四人区分突击与侦察。
- [ ] 五人中至少四人区分哨兵与无人机。
- [ ] 五人中至少四人能指出侦察具有低姿态和天线背包。
- [ ] 灰度模式至少四人仍区分突击与侦察。
- [ ] 720p 和 1080p 默认缩放下单位不糊成同一轮廓。
- [ ] 地标能被五人中四人指出为地图方向参照物。

任一指标失败时回到 A02 重新生成对应源图；旧失败源图按 SHA-256 命名移到 `artifacts/v2/rejected-art/`，通过版本统一写回固定 `v01` 源路径并在清单记录最终哈希。`decision.md` 只有所有指标通过时写 `PASS`。

```powershell
git add docs/v2/art/V2_ART_SAMPLE_DECISION.md tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/assets/v2/source tactical-grid/client/assets/v2/runtime
git commit -m "art(v2): approve M1 visual samples"
```

### Task A06: 四名玩家正式方向图

**Executor:** IMAGE2 最高质量生成；Terra high 处理；Sol xhigh 验收。

**Files:**
- Modify: `tactical-grid/client/assets/v2/source/units/player/assault_four_view_v01.png`
- Modify: `tactical-grid/client/assets/v2/source/units/player/scout_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/units/player/sniper_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/units/player/heavy_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/player/assault/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/player/scout/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/player/sniper/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/player/heavy/{north,east,south,west}.png`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/v2_art_asset_contract_test.gd`

**Interfaces:**
- Produces exactly 16 player direction textures。

- [ ] **Step 1: 使用 A02 基础提示和以下固定附加描述生成最终源图**

- 狙击：`tall narrow silhouette, longest rifle barrel, ice-white optical scope, stable low-motion firing posture`。
- 重装：`widest shoulders and forearms, large back-mounted shield projector, orange shoulder armor, heavy stance`。

突击与侦察只在 A05 通过版本基础上做光向和比例统一，不改变已验证轮廓。

- [ ] **Step 2: 逐图检查四方向装备一致和职业差异**

- [ ] **Step 3: 用 A03 工具处理并更新 Catalog/清单**

- [ ] **Step 4: 运行 16 图合同和五人四角色辨识测试**

Expected: 隐藏名称和底环时至少 4/5 正确区分四角色；灰度同样至少 4/5。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/assets/v2/source/units/player tactical-grid/client/assets/v2/runtime/units/player tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tests/v2
git commit -m "art(v2): complete four player directions"
```

### Task A07: 五类敌人、猎手和 Boss 正式方向图

**Executor:** IMAGE2 最高质量生成；Terra high 处理；Sol xhigh 验收。

**Files:**
- Modify: `tactical-grid/client/assets/v2/source/units/enemy/sentry_four_view_v01.png`
- Modify: `tactical-grid/client/assets/v2/source/units/enemy/drone_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/source/units/enemy/{sniper_sentry,shield_guard,protocol_engineer,hunter}_four_view_v01.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/enemy/{sentry,drone,sniper_sentry,shield_guard,protocol_engineer,hunter}/{north,east,south,west}.png`
- Create: `tactical-grid/client/assets/v2/runtime/units/boss/data_sentinel/{shielded,exposed,core_hit}.png`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/v2_art_asset_contract_test.gd`

**Interfaces:**
- Produces 20 common-enemy directions、4 hunter directions、3 Boss images。

- [ ] **Step 1: 使用固定职责描述生成每类独立源图**

- 狙击哨兵：`long rail barrel, tripod-like narrow base, white-red targeting optic`。
- 盾卫：`body-wide curved shield arc, low heavy chassis, orange-red shield rim`。
- 协议工程师：`slender maintenance arms, exposed data cable bundle, node tool pack, minimal weapon`。
- 猎手：`forward swept pursuit frame, long digitigrade legs, directional tracking antenna, distinct black-red chevron`。
- Boss：`large stationary data sentinel core, concentric shield petals, exposed cyan central core in phase two`。

- [ ] **Step 2: 处理方向图和三张 Boss 图**

- [ ] **Step 3: 接入敌人 art_key 与方向切换**

- [ ] **Step 4: 运行资源合同和五人敌人辨识测试**

Expected: 至少 4/5 能区分五类通用敌人中的四类；猎手与普通敌人不混淆。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/assets/v2/source/units/enemy tactical-grid/client/assets/v2/runtime/units tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tests/v2
git commit -m "art(v2): complete enemy and boss directions"
```

### Task A08: 七张肖像、六个地标和至少 27 个图标

**Executor:** IMAGE2 生成肖像/地标；Terra high 程序生成图标与处理。

**Files:**
- Create: `tactical-grid/client/assets/v2/runtime/portraits/*.png`
- Create: `tactical-grid/client/assets/v2/runtime/landmarks/*.png`
- Create: `tactical-grid/client/assets/v2/runtime/icons/**/*.png`
- Create: `tactical-grid/client/tests/v2/v2_portrait_icon_contract_test.gd`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Portrait IDs: `assault/scout/sniper/heavy/commander/medic/data_sentinel`。
- Landmark IDs: one for each `ch1_m1` through `ch1_m6`。
- Icons: 4 active、4 passive、8 module、5 intent、6 objective/status。

- [ ] **Step 1: 写准确数量、尺寸和透明合同**

肖像固定 768×1024 源、384×512 runtime；地标最长边 384；图标 64×64。测试枚举固定 ID，不只检查目录数量。

- [ ] **Step 2: 生成七张一致制服/光向肖像和六个任务地标**

人物提示沿用同一世界、炭黑制服、青色边光和中性纯色背景；角色年龄、发型、脸型、装备装饰不同。数据哨兵肖像使用机械核心，不生成人脸。地标分别为起重机、冷却塔、磁轨道岔、监区钥匙门、追踪阵列、零号终端核心。

- [ ] **Step 3: 程序生成 27 个形状优先图标**

每个图标使用不同主形状和内部符号，灰度可辨；不使用字母。输出清单记录 `procedural` 和生成脚本参数。

- [ ] **Step 4: 运行数量、布局、对话和灰度合同**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/assets/v2 tactical-grid/client/tests/v2 tactical-grid/client/data/v2/resource_manifest.md
git commit -m "art(v2): add portraits landmarks and icons"
```

### Task A09: 四套环境资源审计与补齐

**Executor:** Terra high；IMAGE2 只补独特地标和程序化方式无法满足的结构。

**Files:**
- Create: `docs/v2/art/V2_ENVIRONMENT_AUDIT.md`
- Create: `tactical-grid/client/tools/v2/generate_environment_variants.ps1`
- Create: `tactical-grid/client/assets/v2/runtime/environment/{echo_yard,cooling_works,transit_hub,sentinel_core}/**/*.png`
- Create: `tactical-grid/client/tests/v2/v2_environment_kit_test.gd`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Each kit categories: `floor/wall/half_cover/full_cover/device/decor/landmark`。

- [ ] **Step 1: 审计现有四套环境的来源和类别**

逐文件记录能否复用、原路径、许可证和视觉问题。只有项目自有程序生成或已记录合法来源的资源可复制到 V2 runtime；复制后更新 V2 清单。

- [ ] **Step 2: 写最低类别数量失败测试**

每套至少 6 floor、3 wall/boundary、4 cover、2 device、4 decor、1 landmark；单纯换色不计为不同结构。

- [ ] **Step 3: 程序化补齐地板、墙、掩体和装置变体**

复用现有生成器的纹理语言，但输出到 V2。M3/M4 共用 transit 材料但地标和构图不同；M5/M6 共用 core 材料但 M6 使用更冷色温、Boss 危险区和背景脉冲。

- [ ] **Step 4: 运行四套合同并生成每套 720p 组合预览**

- [ ] **Step 5: 提交**

```powershell
git add docs/v2/art/V2_ENVIRONMENT_AUDIT.md tactical-grid/client/tools/v2 tactical-grid/client/assets/v2/runtime/environment tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tests/v2
git commit -m "art(v2): complete environment kits"
```

### Task A10: 正式 VFX

**Executor:** Terra high。

**Files:**
- Create: `tactical-grid/client/scripts/v2/presentation/v2_vfx_player.gd`
- Create: `tactical-grid/client/assets/v2/runtime/vfx/*.png`
- Create: `tactical-grid/client/tests/v2/v2_vfx_contract_test.gd`
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_damage_presenter.gd`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- VFX IDs: `muzzle/hit/cover_hit/shield_absorb/scan/interrupt/impact_advance/barrier/facility_success/alert_raise/evac/boss_shield_break/boss_core_hit`。

- [ ] **Step 1: 写 13 项存在、时长和减少动态测试**

- [ ] **Step 2: 确认缺少正式 VFX 时失败**

- [ ] **Step 3: 使用程序化环、线、粒子和短 sprite strip 制作**

所有 VFX 时长 0.08-0.8 秒，不使用全屏强闪；危险区持续显示形状和边界。减少动态关闭大位移与屏幕震动但保留命中、护盾和危险信息。

- [ ] **Step 4: 运行灰度、绿色盲、720p/1080p 和八个同时效果测试**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation tactical-grid/client/assets/v2/runtime/vfx tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tests/v2
git commit -m "art(v2): add readable combat VFX"
```

### Task A11: 至少 20 个新增或重混音频事件

**Executor:** Terra high 生成；项目负责人听感验收。

**Files:**
- Create: `tactical-grid/client/tools/v2/generate_v2_audio.ps1`
- Create: `tactical-grid/client/assets/v2/runtime/audio/**/*.wav`
- Create: `tactical-grid/client/tests/v2/v2_audio_contract_test.gd`
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Modify: `tactical-grid/client/tools/test_audio_assets.ps1`
- Modify: `tactical-grid/client/data/v2/resource_manifest.md`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Events: 4 ability、5 intent、4 ambient loop、3 boss state、4 damage layer。

- [ ] **Step 1: 写 20 事件、格式和非重复哈希测试**

固定格式 PCM WAV、44.1 kHz、16-bit、mono 或 stereo 记录于清单。测试要求至少 20 个独立事件、非静音、非削波、哈希不重复。

- [ ] **Step 2: 确认新增 V2 音频不存在而失败**

- [ ] **Step 3: 从现有 43 个原创 PCM 基线生成独立层**

能力 4 项、意图 5 项、环境 4 条、Boss 3 状态、生命/掩体/护甲/护盾 4 层。循环文件首尾幅度差低于阈值；同时八 SFX 总线不削波。AudioManager 以事件 ID 触发，不在规则代码写文件路径。

- [ ] **Step 4: 运行技术测试并人工听取状态切换**

记录耳机/扬声器、主音量、音乐与 SFX 平衡；无突兀截断、对话不被掩盖。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/tools/v2 tactical-grid/client/assets/v2/runtime/audio tactical-grid/client/scripts/game/audio_manager.gd tactical-grid/client/tools/test_audio_assets.ps1 tactical-grid/client/data/v2/resource_manifest.md tactical-grid/client/tests/v2
git commit -m "audio(v2): add chapter one event sound set"
```

### Task A12: V2 Catalog、AudioManager 和资源清单合同

**Executor:** Sol high。

**Files:**
- Modify: `tactical-grid/client/scripts/v2/presentation/v2_unit_art_catalog.gd`
- Modify: `tactical-grid/client/scripts/game/audio_manager.gd`
- Create: `tactical-grid/client/tests/v2/v2_runtime_resource_contract_test.gd`
- Modify: `tactical-grid/client/tests/v2/gate_manifest.json`

**Interfaces:**
- Produces `missing_assets() -> Array[String]` and `preload_required() -> Dictionary`。

- [ ] **Step 1: 写所有数据 art_key/audio_event 可解析测试**

枚举 characters、enemies、abilities、missions 和 dialogues 中的资源键；每个必须加载为正确 Texture2D/AudioStream，且 `missing_assets()` 为空。

- [ ] **Step 2: 运行并记录首个未解析键**

- [ ] **Step 3: 完成 Catalog 映射和预加载缓存**

不允许运行时回退到圆形、字母、默认 icon.svg 或 V1 单位图。缺失资源在开发构建中启动失败，在发布门中非零退出。

- [ ] **Step 4: 运行资源合同、清单校验和 Godot 无头导入**

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/scripts/v2/presentation tactical-grid/client/scripts/game/audio_manager.gd tactical-grid/client/tests/v2
git commit -m "feat(v2): enforce formal runtime resources"
```

### Task A13: M1 正式表现整合

**Executor:** Sol xhigh。

**Files:**
- Modify: `tactical-grid/client/data/v2/locked_maps/ch1_m1.json`
- Modify: `tactical-grid/client/scripts/game/battle_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/base_controller.gd`
- Modify: `tactical-grid/client/scripts/ui/dialogue_system.gd`
- Modify: `tactical-grid/client/scripts/v2/presentation/*.gd`
- Modify: `tactical-grid/client/tests/v2/v2_m1_visual_snapshot.gd`

**Interfaces:**
- Produces M1 final visual stages at all required resolutions/modes。

- [ ] **Step 1: 将 M1 视觉快照断言升级为正式资源键**

断言突击、侦察、哨兵、无人机使用 V2 runtime；起重机地标可见；攻击、扫描、护盾、撤离 VFX 与音频事件触发；不存在 default/fallback/placeholder 标记。

- [ ] **Step 2: 运行并确认灰盒资源合同失败**

- [ ] **Step 3: 接入环境构图、单位、肖像、VFX 和音频**

保持 H1 已验证坐标和操作，不因美术改变可达格、视线或掩体。处理 z_index、脚底锚点、迷雾着色和 HUD 对比度。

- [ ] **Step 4: 运行 M1 E2E、视觉矩阵和一次负责人完整试玩**

记录 12-18 分钟目标、帧率、音量和所有明显表现问题。

- [ ] **Step 5: 提交**

```powershell
git add tactical-grid/client/data/v2/locked_maps/ch1_m1.json tactical-grid/client/scripts tactical-grid/client/tests/v2
git commit -m "feat(v2): finish M1 presentation slice"
```

### Task A14: P5/P6 共享内容锁

**Executor:** Sol xhigh；Terra xhigh 独立审查。

**Files:**
- Modify: `docs/superpowers/plans/2026-08-05-v2-master-implementation.md`
- Modify: `tactical-grid/PROJECT_STATUS_V2.md`
- Create: `tactical-grid/client/tools/v2/build_content_inventory.ps1`
- Output: `artifacts/v2/verification/p6/content_inventory.json`
- Output: `artifacts/v2/verification/p6/visual_review.md`
- Output: `artifacts/v2/verification/p6/audio_review.md`

**Interfaces:**
- Consumes the accepted outputs of A01-A13 and the M1 runtime presentation from M114.
- Produces `content_inventory.json` with top-level keys `player_directions`, `enemy_directions`, `portraits`, `landmarks`, `icons`, `environment_kits`, `vfx`, `audio_events`, and `manifest_errors`.
- Produces `visual_review.md` and `audio_review.md` with `decision: PASS|FAIL`, reviewer, evidence paths, and unresolved defects.
- A `PASS` lock authorizes C02-C10 to reuse this shared content; it does not permit unreviewed replacement assets.

**Acceptance:**

- [ ] 16 玩家方向图、20 通用敌人方向图、4 猎手方向图、至少 3 Boss 图。
- [ ] 7 肖像、6 地标、至少 27 图标。
- [ ] 四环境套件达到类别最低数量。
- [ ] 13 类正式 VFX 和至少 20 个新增/重混音频事件。
- [ ] 所有 runtime 资源均有清单记录，清单校验通过。
- [ ] M1 全流程无占位单位、默认图标、绿色边缘、方向跳变或 UI 重叠。
- [ ] 五人辨识门、灰度和绿色盲辅助门通过。
- [ ] V2 完整门 0 失败、0 非预期错误/警告。

- [ ] **Step 1: 运行资源库存脚本并核对准确数量**
- [ ] **Step 2: 运行 Godot 导入、资源合同、视觉矩阵、音频测试和 V2 完整门**
- [ ] **Step 3: 独立审查 manifest、runtime 目录和发布排除规则**
- [ ] **Step 4: 更新主计划 A01-A14 与项目状态**
- [ ] **Step 5: 提交共享内容锁**

```powershell
git add docs/superpowers/plans/2026-08-05-v2-master-implementation.md tactical-grid/PROJECT_STATUS_V2.md tactical-grid/client/tools/v2/build_content_inventory.ps1
git commit -m "docs(v2): lock shared presentation content"
```

A14 完成后才能将同一正式资源用于 C02-C10；后续地图任务不得临时生成风格不一致的新单位冒充关卡完成。
