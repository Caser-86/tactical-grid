# AI 驱动的平面回合制战棋游戏 - 开发执行方案

> 基于设计全案文档，规划全 AI 制作流程（美术 + 音乐 + 前端 + 后端 + 玩法）

---

## 一、项目总览

### 1.1 游戏定位
- **类型**：平面格子回合制战术战棋（参考 XCOM 2 + Fire Emblem + Into the Breach）
- **平台**：PC + 移动双端
- **核心循环**：目标驱动的掩体战术战 + 2AP 回合制 + 混合信息制
- **节奏**：小图 8-12 分钟 / 中图 12-18 分钟 / 大图 18-25 分钟

### 1.2 技术栈选择（AI 友好）

| 模块 | 推荐技术 | AI 适配理由 |
|------|---------|------------|
| 前端引擎 | **Godot 4.x**（GDScript）| 开源、2D 强、AI 生成 GDScript 准确率高 |
| 后端 | **Node.js + Express** 或 **Python FastAPI** | 大模型代码生成成熟 |
| 数据库 | **SQLite**（开发）/ **PostgreSQL**（生产）| 结构简单 |
| 地图编辑 | **Tiled**（.tmx/.json）| 文本格式，AI 可直接生成 |
| 部署 | **CloudBase / EdgeOne Pages** | 一键部署 |

---

## 二、AI 制作全流程分工

### 2.1 美术（AI 生成）

| 资产类型 | AI 工具 | 规格 | 批量策略 |
|---------|--------|------|---------|
| 角色立绘/肖像 | Stable Diffusion / Midjourney | 512×512 PNG | 生成 + 去背 + 统一风格 LoRA |
| Tile 贴图集 | Stable Diffusion + Tileable 插件 | 64×64 / 128×128 | 生成无缝贴图，切片为 tileset |
| UI 图标 | AI 图像生成 + 图标化处理 | 64×64 SVG/PNG | 功能图标库批量生成 |
| 地图场景概念 | Midjourney | 参考用 | 指导 tileset 风格统一 |
| 特效贴图 | AI 生成粒子素材 | 序列帧 | 爆炸/烟雾/光效 |

**风格统一关键**：训练一个低多边形半写实风格的 LoRA，所有美术资产走同一 prompt 模板。

### 2.2 音乐音效（AI 生成）

| 资产类型 | AI 工具 | 规格 |
|---------|--------|------|
| BGM | Suno AI / Udio | 战斗/菜单/剧情 3 套 |
| UI 音效 | ElevenLabs SFX / Freesound AI | 0.2-0.6 秒短音 |
| 战斗音效 | AI 生成 + 混音 | 枪声/爆炸/脚步 |
| 环境音 | AI 生成氛围音 | 风声/雨声/城市 |

### 2.3 前端（AI 编码）

| 模块 | 实现要点 |
|------|---------|
| 网格系统 | 方格逻辑坐标，10×8 / 14×10 / 18×12 三档 |
| 渲染层 | Godot TileMapLayer，俯视优先 |
| 战斗系统 | 2AP 回合 + 移动点 + A* 寻路 |
| 视野系统 | Bresenham 视线 + 三层高度 |
| 掩体系统 | 半掩体/全掩体/软遮蔽/硬阻挡 |
| UI 系统 | 移动预览 + 危险区高亮 + 敌方意图预告 |
| 存档系统 | JSON 序列化 + 种子记录 |

### 2.4 后端（AI 编码）

| 模块 | 实现要点 |
|------|---------|
| 用户系统 | 注册/登录/JWT |
| 存档同步 | 云存档 + 种子回放 |
| 关卡数据 | REST API 提供 JSON 地图 |
| 遥测系统 | 记录胜率/路径/时长 |
| 匹配/排行 | 可选 PvP 对战 |
| AI 对局 | 后端跑自动 playtesting bot |

---

## 三、开发阶段与里程碑（28 周）

### Phase 1: 基础规则闭环（第 1-6 周）
- [ ] 网格坐标系统 + 渲染分离
- [ ] A* 寻路 + 成本矩阵
- [ ] 视线计算 + 高度层
- [ ] 掩体判定 + 命中公式
- [ ] 2AP 回合流程状态机
- [ ] 单张可玩测试图

### Phase 2: 内容生产管线（第 7-14 周）
- [ ] Tiled 地图导入器
- [ ] AI 美术资产生成管线
- [ ] AI 音乐音效生成管线
- [ ] 敌人 AI（Utility AI + Director）
- [ ] 交互点状态机
- [ ] 三张代表性地图（小/中/大）

### Phase 3: 后端与数据（第 15-20 周）
- [ ] 用户系统 + 云存档
- [ ] 关卡数据 API
- [ ] 遥测采集
- [ ] 自动对局 bot
- [ ] 策展式随机化生成器

### Phase 4: 垂直切片（第 21-28 周）
- [ ] 完整一章内容（5-8 关）
- [ ] 平衡调优
- [ ] UI 打磨
- [ ] 双平台适配
- [ ] 回归测试套件

---

## 四、AI 工具调用方案

### 4.1 美术生成 Prompt 模板

```
角色肖像（统一风格）：
"low poly semi-realistic portrait, [角色职业], [阵营颜色] uniform,
clean silhouette, game asset, white background, 512x512, top-down RPG style"

Tile 贴图：
"seamless tileable texture, [地形类型], low poly, top-down view,
64x64, game tile, clean edges, [主色调]"
```

### 4.2 Tiled 地图 AI 生成

AI 可直接生成 Tiled 的 JSON 格式地图，示例结构：

```json
{
  "width": 10, "height": 8,
  "layers": [
    {"name": "BaseTerrain", "data": [...]},
    {"name": "Blocker", "data": [...]},
    {"name": "Vision", "data": [...]},
    {"name": "Objects", "objects": [
      {"type": "spawn_player", "x": 0, "y": 0},
      {"type": "spawn_enemy", "x": 8, "y": 6},
      {"type": "terminal", "x": 5, "y": 3},
      {"type": "evac", "x": 8, "y": 0}
    ]}
  ]
}
```

### 4.3 可直接调用的 AI 服务

| 用途 | 服务 | 调用方式 |
|------|------|---------|
| 文生图 | Stable Diffusion API / 混元文生图 | HTTP API |
| 文生音乐 | Suno API | HTTP API |
| 代码生成 | CodeBuddy / Claude | IDE 集成 |
| 文本/剧情 | LLM | API |
| 语音 | TTS API | HTTP API |

---

## 五、数据规范（关键配置表）

### 5.1 地形表（AI 可直接生成）

| terrain_id | move_cost | cover | vision | effect |
|-----------|-----------|-------|--------|--------|
| plain | 1 | none | none | - |
| road | 1 | none | none | +1 dash |
| forest | 2 | half | soft | stealth+10% |
| sand | 2 | none | none | dash-1 |
| highland | 1 | none | +1 | hit+10% |
| water | 3/forbid | none | none | electric spread |
| wall | forbid | full | block | destructible HP3-6 |
| crate | forbid | half/full | block | explodable |
| poison | 2 | none | none | end-turn damage |
| bridge | 1 | none | - | connect height |

### 5.2 职业表

| job | move | hp | role | terrain_pref |
|-----|------|----|------|-------------|
| assault | 5 | 100 | flank | road+ |
| sniper | 3 | 70 | highground | highland++ |
| heavy | 3 | 140 | suppress | crate cover |
| medic | 4 | 80 | support | - |
| scout | 7 | 60 | recon | forest+ |

### 5.3 胜利条件模板

```yaml
victory:
  primary: "activate_terminals + evac"
  secondary: "zero_casualty + loot_count >= 1"
  bonus: 0.2
defeat:
  - "all_units_down"
  - "npc_dead"
  - "turn_clock_zero"
```

---

## 六、立即可执行的下一步

### 第一步：搭建 Godot 项目骨架
我将生成一个包含以下内容的最小可运行原型：
1. 网格渲染系统
2. A* 寻路
3. 单位移动
4. 基础回合流程
5. 一张测试地图

### 第二步：生成 AI 美术资产
用 image_gen 工具生成首批 tileset 和角色立绘。

### 第三步：实现后端 API
用 Node.js/FastAPI 搭建最小后端。

---

**你希望我从哪一步开始执行？**
建议优先级：
1. **A) 先搭 Godot 前端原型**（最快看到可玩东西）
2. **B) 先生成美术资产**（需要风格定调）
3. **C) 先做后端数据结构**（适合先定规范）
4. **D) 全部并行启动**（用 team 模式多 agent 协作）
