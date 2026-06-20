# 风格锚点出图任务单

## 目标

生成 8 组风格锚点图，确定《Tactical Grid》最终美术风格。后续所有 AI 批量出图都需参考这些锚点保持统一。

## 通用参数（推荐）

| 工具 | 建议参数 |
|---|---|
| Midjourney v6 | `--ar 1:1 --s 250 --style raw` |
| 即梦 | 风格：低多边形 / 3D；画质：高清；比例：1:1 |
| Stable Diffusion XL | CFG 7-8, Steps 30, Sampler: DPM++ 2M Karras |

## 通用风格锁（所有 prompt 首句）

```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render
```

## 任务清单

### 1. 突击兵战斗精灵

**输出目录**：`ai_output/assault/`  
**目标尺寸**：128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render,
A male tactical assault soldier in blue accented heavy armor, holding a bullpup
assault rifle, neutral pose, facing 3/4 camera, clean silhouette
```
**数量**：至少 4 版，选 1 版最满意的作为锚点  
**验收**：角色轮廓清晰、能一眼识别为突击兵、蓝色阵营感强

### 2. 狙击手战斗精灵

**输出目录**：`ai_output/sniper/`  
**目标尺寸**：128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render,
A female sniper in blue stealth suit, hood down, holding a long sniper rifle,
crouched aim pose, facing 3/4 camera, clean silhouette
```
**数量**：4 版  
**验收**：与突击兵同一场景光照，身形更纤细，武器更长

### 3. 医疗兵战斗精灵

**输出目录**：`ai_output/medic/`  
**目标尺寸**：128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render,
A combat medic in white and blue tactical gear, holding a med-gun, ready stance,
facing 3/4 camera, clean silhouette
```
**数量**：4 版  
**验收**：有医疗兵识别特征，色调偏白但不偏离蓝绿主色

### 4. 侦察兵战斗精灵

**输出目录**：`ai_output/scout/`  
**目标尺寸**：128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render,
A nimble scout in light black and blue armor, holding an SMG, agile pose,
facing 3/4 camera, clean silhouette
```
**数量**：4 版

### 5. 重装兵战斗精灵

**输出目录**：`ai_output/heavy/`  
**目标尺寸**：128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render,
A bulky heavy gunner in massive blue-gray power armor, holding a rotary machine
gun, facing 3/4 camera, clean silhouette
```
**数量**：4 版  
**验收**：体型明显比其他职业大，能体现"重装"感

### 6. 基础哨兵敌人

**输出目录**：`ai_output/enemies/`  
**目标尺寸**：128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render,
A red and black humanoid combat robot, simple blocky design, glowing red eye,
holding an energy rifle, facing 3/4 camera, clean silhouette
```
**数量**：4 版  
**验收**：敌我识别度高（红 vs 玩家蓝），机械感强

### 7. 仓库地形主题

**输出目录**：`ai_output/warehouse/`  
**目标尺寸**：1024×1024 PNG（可裁切）  
**Prompt**：
```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, isometric view,
military cyberpunk, no text, no watermark, high quality render,
industrial warehouse interior, concrete floor, metal walls, yellow safety lines,
scattered supply crates, dim overhead lights, top-down tactical grid tileset
```
**数量**：2 版  
**验收**：能看清网格、有战术场景氛围、不抢角色视觉

### 8. 爆炸特效序列帧

**输出目录**：`ai_output/explosion/`  
**目标尺寸**：每帧 128×128 PNG（透明背景）  
**Prompt**：
```
low poly tactical sci-fi game asset, cel-shaded, dark teal and electric orange
accent, transparent background, military cyberpunk, no text, no watermark,
Explosion frame N/8, low poly fireball, bright orange and yellow, expanding
shockwave, game VFX
```
**数量**：每组 8 帧，出 2 组不同版本  
**验收**：播放 12fps 时连贯、中心发光、边缘消散自然

---

## 出图后操作

1. 从每组选 1 版最满意的，复制到 `ai_output/reference/`
2. 用这些 reference 作为后续所有 img2img / style reference
3. 用 `tools/art_batch_processor.py` 标准化尺寸和文件名
4. 运行 `tools/art_replacement_tracker.py` 更新替换进度

## 风格锚点确定标准

- [ ] 5 个玩家职业一眼能区分职业
- [ ] 敌人和玩家阵营色对比清晰
- [ ] 所有图放大到同一屏幕无明显画风差异
- [ ] 透明背景干净
- [ ] 无文字、无水印、无明显 AI 瑕疵
