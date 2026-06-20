# AI 美术资源验收与替换 SOP

## 目标

确保 AI 生成的美术资源在替换进项目前经过统一检查，避免画风不一致、规格错误、版权风险。

## 角色

- **AI 美术执行人**：按 prompt 批量出图、抠图、命名
- **美术审核人**：比对风格锚点、验收质量
- **程序对接人**：将资源接入代码、验证运行效果

## 流程

### 1. 生成前准备

1. 确认已阅读 `art_pipeline.md`，选定风格锚点
2. 从 `docs/ai_prompts.md` 复制对应模板
3. 固定以下风格锁，禁止随意改动：

```
low poly tactical sci-fi game asset, clean hardsurface geometry, cel-shaded,
dark teal and electric orange accent, subtle glow, transparent background,
isometric view, military cyberpunk, no text, no watermark, high quality render
```

### 2. 生成与初筛

- 同一角色/物件至少出 4 版，选 1 版最符合锚点的
- 用 remove.bg / Photoshop 处理透明背景
- 按比例裁剪到目标尺寸（如 64×64 / 256×256 / 512×512）
- 文件大小控制在：
  - 图标/精灵：≤ 128 KB
  - 肖像/地形：≤ 512 KB
  - 商店图：≤ 2 MB

### 3. 验收检查表

- [ ] 输出尺寸符合规格（见 `art_pipeline.md`）
- [ ] 透明背景干净（无杂色边缘）
- [ ] 无文字/水印/签名/奇怪结构
- [ ] 与风格锚点对比，无画风跳跃
- [ ] 文件大小在合理范围内
- [ ] 命名符合项目规范

### 4. 替换与注册

1. 将验收通过的文件放入目标目录（如 `assets/units/`）
2. 若替换同名文件，先备份旧文件到 `assets/_backup/`
3. 在 `docs/art_assets_checklist.csv` 中更新对应行状态为 `DONE`
4. 运行 `godot --headless --path . -s tools/art_audit_runner.gd` 重新审计
5. 启动游戏验证替换后的显示效果

### 5. 特效序列帧接入

生成序列帧后，需告知开发人员在代码中改为 `AnimatedSprite2D` 或逐帧切换。例如：

```gdscript
var frames = []
for i in range(1, 9):
	frames.append(load("res://assets/effects/explosion_frames/frame_%02d.png" % i))
```

### 6. 禁止直接覆盖

- 不要直接删除 `generated/` 目录中仍被代码引用的旧图
- 替换前先用 `git diff` 或备份确认差异
- 多人协作时先在独立分支替换美术资源

### 7. 最终上线前检查

- [ ] 所有占位符 PNG 已被 AI 成品替换或明确允许保留
- [ ] `art_assets_checklist.csv` 中无 `MISSING` 或 `PLACEHOLDER`
- [ ] 商店图/图标/字体授权文件齐全
- [ ] 打包后游戏内无拉伸、模糊、丢失贴图
- [ ] 所有 AI 生成素材已做版权风险排查

---

## 附录：目录结构规范

```
tactical-grid/
├── assets/
│   ├── units/              # 战斗精灵
│   ├── characters/         # 角色肖像（AI 成品替换 generated/）
│   ├── weapons/            # 武器图标
│   ├── skills/             # 技能图标
│   ├── items/              # 物品图标
│   ├── effects/            # 特效序列帧
│   ├── tiles/              # 地形主题
│   ├── objects/            # 地图物件
│   ├── ui/                 # UI 素材
│   ├── store_assets/       # 商店图/品牌包装
│   │   ├── placeholders/   # 程序占位图（仅临时使用）
│   │   ├── icon.png        # 游戏图标
│   │   ├── capsule_main.png
│   │   ├── capsule_vertical.png
│   │   └── screenshots/
│   └── fonts/              # 字体文件 + 授权说明
├── docs/
│   ├── art_pipeline.md
│   ├── ai_prompts.md
│   ├── art_assets_checklist.md
│   ├── art_assets_checklist.csv
│   ├── art_assets_sop.md
│   ├── privacy_policy.md
│   └── terms_of_service.md
└── tools/
    ├── art_audit_runner.gd
    └── procedural_placeholders.gd
```
