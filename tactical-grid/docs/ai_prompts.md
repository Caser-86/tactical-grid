# AI 美术生成 Prompt 模板库 v2

> 版本：2.0 | 更新：2026-06-20  
> 风格参考：XCOM 2 / Into the Breach / 暗影战术 低多边形科幻

---

## 色彩规范

| 用途 | 颜色 | Hex | 说明 |
|---|---|---|---|
| 玩家主色 | 电子蓝 | `#33BBEB` | 所有玩家单位装甲主色 |
| 玩家辅色 | 深青灰 | `#1A2B3C` | 装甲阴影/底色 |
| 敌人主色 | 血红 | `#D92635` | 所有敌方单位主色 |
| 敌人辅色 | 暗黑红 | `#2D0A0F` | 敌人底色 |
| 强调色 | 电光橙 | `#FF8C2D` | UI/武器能量/特效 |
| 中性色 | 冷灰白 | `#E6EBF2` | 文字/高光 |
| 背景 | 深蓝黑 | `#0F141E` | 背景基准 |

---

## 通用风格锁（所有 prompt 必加）

### 英文版（Midjourney / Stable Diffusion）
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded, 
dark teal (#33BBEB) and electric orange (#FF8C2D) accent colors, subtle 
emissive glow on joints and weapon tips, isolated on transparent/white background, 
isometric 3/4 view, military cyberpunk aesthetic, sharp silhouette, 
no text, no watermark, no blurry edges, studio lighting from top-left
```

### 中文版（即梦 / 可灵 / 通义万相）
```
低多边形科幻战棋游戏角色，干净硬表面建模，卡通渲染，深青色(#33BBEB)和电光橙(#FF8C2D)配色，
关节和武器尖端有微弱发光，透明背景，等距3/4视角，军事赛博朋克风格，轮廓清晰锐利，
无文字无水印，左上方影棚灯光
```

---

## 通用负面提示词

### Stable Diffusion
```
blurry, low resolution, jpeg artifacts, watermark, text, signature, 
photorealistic, realistic, human face detail, fingers, extra limbs, 
deformed, ugly, noisy, grainy, oversaturated, gradient background, 
busy background, patterned background, border, frame
```

### Midjourney
```
--no blurry text watermark realistic photo fingers deformed 
busy background gradient
```

### 即梦 / 通义万相
```
模糊，低分辨率，水印，文字，签名，写实照片风，多余手指，变形，
过饱和，渐变背景，杂乱背景，边框，噪点
```

---

## 工具参数预设

### Midjourney v6+
| 参数 | 值 | 说明 |
|---|---|---|
| --ar | 1:1 | 角色/图标；2:1 用于横版截图 |
| --s | 300 | 高风格化 |
| --style raw | 否 | 不用 raw，保留 Midjourney 风格化 |
| --q | 1 | 标准质量 |
| --niji | 否 | 不用动漫风格 |
| --chaos | 15 | 适度变化 |

### Stable Diffusion XL
| 参数 | 值 | 说明 |
|---|---|---|
| Sampler | DPM++ 2M Karras | |
| Steps | 35 | |
| CFG | 7.5 | |
| Resolution | 1024×1024 | |
| Clip Skip | 2 | |
| VAE | sdxl-vae-fp16-fix | |

### 即梦
| 参数 | 值 | 说明 |
|---|---|---|
| 风格 | 低多边形 / 3D | |
| 画质 | 高清 | |
| 比例 | 1:1 | |
| 引导强度 | 7-8 | |

---

## 1. 风格锚点（Style Anchor）

### 锚点 1：突击兵（参考基准）

**Midjourney**:
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded, 
dark teal and electric orange accent, subtle glow, isolated on white background, 
isometric 3/4 view, military cyberpunk, no text, no watermark, studio lighting, 
A male tactical assault soldier in blue (#33BBEB) accented heavy combat armor 
with orange (#FF8C2D) glowing joint lines, holding a compact bullpup assault 
rifle, standing in neutral ready pose, facing 3/4 camera right, 
sharp clean silhouette --ar 1:1 --s 300 --no blurry text watermark 
realistic photo busy background
```

**SD XL (正面)**:
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded, 
dark teal and electric orange accent, subtle glow, isolated on white background, 
isometric 3/4 view, military cyberpunk, no text, no watermark, studio lighting, 
a male tactical assault soldier in blue accented heavy combat armor with orange 
glowing joint lines, holding a compact bullpup assault rifle, standing in neutral 
ready pose, facing 3/4 camera right, sharp clean silhouette, game character sprite
```

**SD XL (负面)**:
```
blurry, low resolution, jpeg artifacts, watermark, text, signature, 
photorealistic, realistic, human face detail, fingers, extra limbs, 
deformed, ugly, noisy, grainy, oversaturated, gradient background, 
busy background, patterned background, border, frame
```

**输出目录**：`ai_output/assault/`  
**目标尺寸**：1024×1024 → 裁剪缩放至 128×128  
**验收**：轮廓清晰、蓝色阵营感强、与后续职业可区分

### 锚点 2：狙击手

**Prompt**:
```
[风格锁]，A lithe female sniper in sleek blue-black stealth suit with 
lightweight armor plates, hood down revealing short silver hair, holding an 
extended precision sniper rifle with long barrel, crouched aiming stance, 
facing 3/4 camera, lean athletic build distinguishing from bulky assault soldier,
sharp clean silhouette
```

**区分特征**：身形纤细、武器最长、带兜帽元素、银发

### 锚点 3：医疗兵

**Prompt**:
```
[风格锁]，A combat medic in white and teal tactical gear with red cross 
insignia on shoulder, holding a futuristic med-gun with green glowing tip, 
standing in alert ready stance, medical pouches on belt, slightly shorter 
build, white armor panels making them visually distinct from other blue units,
sharp clean silhouette
```

**区分特征**：白色装甲为主、绿色武器发光、医疗包

### 锚点 4：侦察兵

**Prompt**:
```
[风格锁]，A nimble young scout in lightweight black and dark blue stealth 
armor with minimal plating, holding a compact SMG with suppressor, agile 
catsuit-like silhouette, visor covering eyes, lightest and smallest of all 
player units, dark color scheme with blue accent strips,
sharp clean silhouette
```

**区分特征**：最小最轻、黑色为主、面罩、消音器

### 锚点 5：重装兵

**Prompt**:
```
[风格锁]，A massive bulky heavy gunner in enormous blue-gray powered exo-armor, 
holding a rotary multi-barrel machine gun, the largest and widest of all player 
units, thick armored shoulders and legs, exposed ammo belt, industrial heavy 
military aesthetic, visibly 20% larger than other characters,
sharp clean silhouette
```

**区分特征**：体型最大最宽、多管机枪、弹链、工业感

### 锚点 6：基础哨兵（敌人）

**Prompt**:
```
[风格锁]，A red (#D92635) and black humanoid combat robot, simple angular 
blocky design, single glowing red eye sensor, holding an energy rifle with red 
glowing barrel, mechanical jointed limbs, hostile military drone aesthetic, 
clearly distinct from blue player units through red color scheme,
sharp clean silhouette
```

**区分特征**：红色为主、机械关节、单眼传感器

### 锚点 7：仓库地形

**Prompt**:
```
[风格锁]，Industrial warehouse interior floor tile, concrete ground with 
yellow safety line markings, metal wall panels, scattered supply crates, 
dim overhead fluorescent lights casting pools of light, top-down isometric 
tactical grid view, dark moody atmosphere, sci-fi military storage facility,
game tile texture, seamless
```

**输出目录**：`ai_output/warehouse/`  
**目标尺寸**：1024×1024

### 锚点 8：爆炸特效序列帧

**Prompt** (每帧单独生成):
```
[风格锁]，Explosion VFX frame N of 8, bright orange fireball with 
white-hot center expanding outward, low poly stylized game effect, 
transparent background, cel-shaded fire, sparks flying outward, 
consistent scale across all frames
```

**输出目录**：`ai_output/explosion/`  
**目标尺寸**：512×512 → 缩放至 128×128

---

## 2. 批量出图模板

### 2.1 角色战斗精灵（通用）

```
[风格锁]，[CHARACTER_DESCRIPTION], holding [WEAPON], 
[POSE_DESCRIPTION], facing 3/4 camera, sharp clean silhouette,
[TEAM_COLOR_ACCENT]
```

| 变量 | 说明 |
|---|---|
| `CHARACTER_DESCRIPTION` | 职业/种族/体型/装甲描述 |
| `WEAPON` | 武器类型和外观 |
| `POSE_DESCRIPTION` | idle / crouch_aim / run /受伤闪红 |
| `TEAM_COLOR_ACCENT` | 玩家蓝色 or 敌人红色 |

### 2.2 角色肖像（通用）

```
[风格锁]，Close-up head portrait of [CHARACTER], [EXPRESSION], 
[TEAM_COLOR] rim lighting from below, dark solid background (#0F141E), 
low poly 3D render, face visible, front-facing, no body, 
no text, no watermark, game UI avatar
```

### 2.3 武器图标（通用）

```
[风格锁]，[WEAPON_NAME] weapon icon, centered, 45 degree angle view, 
low poly 3D render, dark background (#0F141E), subtle orange (#FF8C2D) 
rim light on edges, military sci-fi, transparent background, 
no text, no hand holding, clean silhouette
```

### 2.4 技能图标（通用）

```
[风格锁]，[SKILL_NAME] skill ability icon, circular frame, 
[VISUAL_DESCRIPTION], glowing energy effect, dark background, 
game UI element, no text, no watermark, centered composition
```

### 2.5 物品图标（通用）

```
[风格锁]，[ITEM_NAME] game item icon, centered, 
[ITEM_DESCRIPTION], low poly 3D render, dark background, 
subtle highlight, game inventory icon, no text, clean edges
```

---

## 3. 特效序列帧模板

### 通用帧生成规则
- 每组 8 帧，编号 frame_01 到 frame_08
- 所有帧使用相同的 seed 保持一致性
- 帧间变化：大小渐变 + 透明度渐变 + 位移
- 建议先生成 frame_01，再用 img2img + 变化强度生成后续帧

### 爆炸 Explosion
```
[风格锁]，Stylized explosion VFX, bright orange fireball with white center, 
expanding shockwave ring, sparks flying outward, transparent background,
frame [N] of 8, size: [0.2x - 1.0x], opacity: [1.0 - 0.3]
```

### 治疗 Heal
```
[风格锁]，Healing magic VFX, soft teal (#33BBEB) glowing particles rising 
upward, cross/plus symbols floating, gentle spiral energy, transparent background,
frame [N] of 8
```

### 护盾 Shield
```
[风格锁]，Energy shield hexagon barrier VFX, teal (#33BBEB) glowing hex grid, 
semi-transparent force field, pulse animation, transparent background,
frame [N] of 8
```

### 电击 Electro
```
[风格锁]，Lightning electric VFX, bright blue-white (#33BBEB) electric arcs 
branching outward from center, spark particles, transparent background,
frame [N] of 8
```

### 燃烧 Burn
```
[风格锁]，Fire burn VFX, stylized low-poly flames rising from ground, 
orange-red (#FF8C2D) with yellow tips, heat distortion effect, 
transparent background, frame [N] of 8
```

### 冰冻 Freeze
```
[风格锁]，Ice freeze VFX, crystalline ice shards forming hexagonal pattern, 
light blue (#88CCFF) glowing edges, frost particles, 
transparent background, frame [N] of 8
```

---

## 4. 出图后处理流程

1. **检查**：每张图是否符合色彩规范、轮廓是否清晰
2. **裁剪**：用 `art_batch_processor.py` 标准化到目标尺寸
3. **去背景**：如果 AI 未生成透明背景，用 remove.bg 或手动抠图
4. **对比**：与同组其他图并排查看风格一致性
5. **替换**：用 `ai_pipeline.py` 自动替换到项目目录

---

## 5. 常见问题

| 问题 | 解决方案 |
|---|---|
| AI 生成了写实风格 | 负面提示词中加强 `photorealistic, realistic`；正面加 `cel-shaded, low poly, game asset` |
| 颜色不统一 | 在 prompt 中明确 hex 色值，如 `blue (#33BBEB)` |
| 手指/肢体变形 | 负面提示词 `fingers, extra limbs, deformed`；用 `--niji` 关闭人像优化 |
| 背景不透明 | 正面加 `isolated on white background` 或 `transparent background`；后期用 remove.bg |
| 角色之间太像 | 每个角色加入独有的 **区分特征**（见上方锚点描述） |
| 帧动画不连贯 | 使用相同 seed + img2img + 低变化强度（0.3-0.5） |
