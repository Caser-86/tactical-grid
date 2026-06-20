# AI 美术资源制作路线

## 目标

用 AI 工具（Midjourney / Stable Diffusion / 即梦 / 可灵等）补齐并统一《Tactical Grid》美术资源，确保：
- 风格统一：低多边形军事科幻 + 赛博朋克色调
- 可直接替换代码中的占位资源
- 版权清晰：使用无争议的工作流和提示词
- 可批量迭代：建立标准化 prompt 和验收清单

## 整体流程

```
1. 资源审计 → 2. 风格锚点 → 3. Prompt 模板 → 4. 批量生成 → 5. 后处理 → 6. 替换验收
```

## 阶段划分

### Phase 0：风格锚点（1-2 天）

先不批量生成，而是用统一 prompt 生成 5-10 张核心样本：
- 1 张主角职业（突击兵）战斗立绘
- 1 张敌人（哨兵机器人）
- 1 张武器图标（突击步枪）
- 1 张技能特效（爆炸）
- 1 张地形主题（仓库）

确认风格后，固定以下关键词作为所有 prompt 的 "style lock"：

```
low poly, tactical sci-fi, cyberpunk military, clean edges, cel-shaded, 
dark teal and orange accent, isometric, transparent background, game asset
```

### Phase 1：核心角色与单位（3-5 天）

优先级：
1. 玩家 5 主角职业：assault, sniper, medic, scout, heavy
2. 第一章敌人：sentry_basic, sentry_sniper, drone_assault, shadow_mercenary
3. 第一章 Boss：data_sentinel
4. 其他敌人按章节分批补齐

输出规格：
- 战斗精灵：64×64 或 128×128 PNG，透明背景
- 肖像：256×256 PNG，透明或半身背景
- 每单位 4 种状态：idle / move / attack / hit（可用同一角色不同 pose）

### Phase 2：武器与物品图标（2 天）

- 重绘现有武器的 20% 核心武器
- 统一所有物品图标风格
- 输出：64×64 PNG，透明背景

### Phase 3：技能特效与地图物件（2-3 天）

- 爆炸、枪口火焰、治疗、护盾、传送等特效序列帧
- 每个特效 8 帧，128×128 或 256×256
- 地图装饰物：箱子、车辆、终端、灯光、掩体残片

### Phase 4：UI 与品牌包装（2 天）

- 游戏图标 512×512
- Steam 胶囊图 460×215 / 600×900 / 1920×620
- 商店截图 5 张 1920×1080
- 主视觉 Key Art 1920×1080
- UI 边框/按钮/面板风格素材

### Phase 5：细节打磨（持续）

- 角色立绘表情差分
- 剧情 CG
- 加载画面
- 过场插画

## 工具推荐

| 类型 | 推荐工具 | 用途 |
|---|---|---|
| 文生图 | Midjourney v6 / Stable Diffusion XL / 即梦 | 角色、场景、图标 |
| 图生图 | Stable Diffusion img2img | 统一已有素材风格 |
| 放大/超分 | Upscayl / Real-ESRGAN | 小图放大 |
| 抠图 | remove.bg / Photoshop | 透明背景 |
| 序列帧 | Runway / 可灵 / 自制粒子 | 动态特效 |
| 管理 | 本项目的 `docs/art_assets_checklist.md` | 跟踪进度 |

## 输出规范

- 格式：PNG（透明背景优先）
- 命名：沿用现有规范，如 `player_assault.png`, `theme_warehouse.png`
- 目录：按类别放入 `assets/units/`, `assets/characters/`, `assets/weapons/` 等
- 备份：生成的新图先放 `assets/_ai_raw/`，验收后再替换到正式目录

## 验收标准

1. 风格一致：所有新图放大到同一屏幕看，不能有明显画风跳跃
2. 透明背景：战斗精灵、图标必须有干净透明背景
3. 尺寸正确：按代码引用尺寸输出
4. 可读性：战棋小图要能一眼区分职业/敌我
5. 无水印/无 AI 痕迹：手部、文字、奇怪结构要修掉
6. 性能：单张 PNG 不超过 512KB，特效序列帧单帧不超过 128KB

## 风险控制

- 不要直接复制他人作品作为 prompt 参考
- 避免使用带明确版权角色的 prompt
- 上线前咨询律师或使用 AI 素材免责声明
- 重要角色建议保留原始设计草图/迭代记录

## 下一步执行

1. 运行 `tools/art_audit.gd` 输出资源审计表
2. 根据审计表确定第一批要生成的资源清单
3. 用统一 prompt 生成风格锚点样本
4. 批量生成并替换
