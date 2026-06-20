# AI 美术生成 Prompt 模板库

## 通用风格锁（所有 prompt 必加）

```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded, 
dark teal and electric orange accent, subtle glow, transparent background, 
isometric view, military cyberpunk, no text, no watermark, high quality render
```

## 1. 角色战斗精灵（Battle Sprite）

### 基础模板

```
A [ROLE_DESCRIPTION] standing in isometric view, [TEAM_COLOR] tactical armor, 
holding [WEAPON], low poly 3D render, game sprite, transparent background, 
neutral pose, facing 3/4 camera, clean silhouette, military sci-fi style
```

### 玩家职业示例

**突击兵 player_assault**
```
A male tactical assault soldier, blue accented heavy armor, holding a bullpup 
assault rifle, isometric game sprite, low poly 3D render, transparent background, 
facing 3/4 view, military cyberpunk, clean silhouette
```

**狙击手 player_sniper**
```
A female sniper in blue stealth suit, hood down, holding a long sniper rifle, 
isometric game sprite, low poly 3D render, transparent background, facing 3/4 view, 
military cyberpunk, clean silhouette
```

**医疗兵 player_medic**
```
A combat medic in white and blue tactical gear, holding a med-gun, isometric 
game sprite, low poly 3D render, transparent background, facing 3/4 view, 
military cyberpunk, clean silhouette
```

**侦察兵 player_scout**
```
A nimble scout in light black and blue armor, holding an SMG, isometric game 
sprite, low poly 3D render, transparent background, facing 3/4 view, military 
cyberpunk, clean silhouette
```

**重装兵 player_heavy**
```
A bulky heavy gunner in massive blue-gray power armor, holding a rotary machine 
gun, isometric game sprite, low poly 3D render, transparent background, facing 
3/4 view, military cyberpunk, clean silhouette
```

### 敌人示例

**哨兵机器人 enemy_sentry_basic**
```
A red and black humanoid combat robot, simple blocky design, glowing red eye, 
holding an energy rifle, isometric game sprite, low poly 3D render, transparent 
background, facing 3/4 view, military sci-fi
```

**隐形刺客 enemy_stealth_assassin**
```
A cloaked assassin in dark red hooded suit, holding an energy dagger, faint 
cloaking shimmer, isometric game sprite, low poly 3D render, transparent background, 
facing 3/4 view, military cyberpunk
```

## 2. 角色肖像（Portrait）

```
Close-up portrait of a [DESCRIPTION], [TEAM_COLOR] lighting from below, dark 
background, low poly 3D render, stoic expression, military sci-fi, clean edges, 
front-facing, no text
```

**突击兵肖像 portrait_assault**
```
Close-up portrait of a male tactical soldier with short hair, blue-lit visor, 
stern expression, dark background, low poly 3D render, military cyberpunk, 
front-facing, no text
```

## 3. 武器图标（Weapon Icon）

```
A [WEAPON_NAME] weapon icon, centered, 45 degree angle, low poly 3D render, 
dark background, subtle rim light, military sci-fi, transparent background, 
no text, clean silhouette
```

**突击步枪 assault_rifle**
```
A futuristic bullpup assault rifle icon, low poly 3D render, dark teal and 
orange accent, transparent background, centered, no text, military sci-fi
```

## 4. 物品图标（Item Icon）

```
A [ITEM_NAME] item icon, top-down view, low poly 3D render, transparent 
background, military sci-fi, clean design, no text
```

**医疗包 med_kit**
```
A compact futuristic medical kit, white with blue cross glow, top-down item 
icon, low poly 3D render, transparent background, military sci-fi, no text
```

## 5. 技能图标（Skill Icon）

```
A skill ability icon showing [EFFECT], circular frame, low poly 3D render, 
[COLOR_THEME], transparent background, military sci-fi, no text, glowing center
```

**技能：快速射击 rapid_fire**
```
Skill icon of three bullets streaking forward inside a hexagonal frame, orange 
and teal glow, low poly 3D render, transparent background, military sci-fi, 
no text
```

## 6. 特效序列帧（Effect Animation）

### 爆炸 explosion

生成 8 张序列帧，每帧 prompt：
```
Explosion frame [N]/8, low poly fireball, bright orange and yellow, expanding 
shockwave, transparent background, game VFX, military sci-fi, no text
```

### 枪口火焰 muzzle_flash

```
Muzzle flash frame [N]/4, bright yellow-white cone burst, transparent background, 
game VFX, low poly, military sci-fi, no text
```

### 治疗光环 heal

```
Heal effect frame [N]/8, rising green/teal energy particles and cross symbol, 
transparent background, game VFX, low poly, military sci-fi, no text
```

### 护盾 barrier

```
Barrier effect frame [N]/8, hexagonal energy shield, blue glow, transparent 
background, game VFX, low poly, military sci-fi, no text
```

## 7. 地图主题（Tile Theme）

```
Isometric tactical grid tileset texture, [THEME] theme, including flat ground, 
road, forest, water, wall, crate, low poly 3D render, top-down view, seamless 
 tiling, military sci-fi, muted colors
```

**仓库 theme_warehouse**
```
Isometric tactical grid tileset, industrial warehouse interior, concrete floor, 
metal walls, yellow safety lines, scattered crates, low poly 3D render, top-down 
view, military sci-fi, muted colors
```

**城市废墟 theme_city_ruins**
```
Isometric tactical grid tileset, post-apocalyptic city ruins, broken asphalt, 
scattered debris, ruined buildings, low poly 3D render, top-down view, military 
sci-fi, muted blue-gray and orange
```

## 8. 地图物件（Objects）

```
A [OBJECT_NAME] prop for tactical grid game, low poly 3D render, transparent 
background, isometric view, military sci-fi, no text
```

**箱子 crate**
```
A metal supply crate with teal accent stripes, closed, low poly 3D render, 
transparent background, isometric view, military sci-fi, no text
```

## 9. UI 与品牌

### 游戏图标 icon

```
Tactical grid game icon, hexagonal grid with glowing crosshair center, dark 
background, teal and orange glow, low poly 3D render, app icon, clean, no text
```

### 主视觉 Key Art

```
Epic key art for tactical turn-based strategy game, three soldiers in dynamic 
poses on a ruined city rooftop, dark teal and orange lighting, low poly 3D 
render, cinematic composition, title area at top, military cyberpunk
```

### Steam 胶囊图

```
Steam capsule art for tactical sci-fi turn-based game, squad of futuristic 
soldiers, hexagonal grid floor, dark teal and orange lighting, low poly 3D 
render, cinematic, no text, 460x215 aspect
```

## 10. 负面提示词（Negative Prompt）

```
realistic, photorealistic, blurry, low quality, watermark, signature, text, 
letters, UI elements, frame, border, cropped, duplicate, mutated hands, extra 
fingers, malformed limbs, messy background, gradient background
```

## 使用建议

1. **先跑风格锚点**：用突击兵肖像/战斗精灵各跑 5 版，选最统一的作为参考图
2. **用 img2img 保持一致性**：后续图都用选定的参考图 + 风格权重
3. **批量跑图时用模板变量替换 `[ROLE]` `[WEAPON]` 等字段**
4. **输出后统一后处理**：抠图、调色、尺寸标准化、压缩
