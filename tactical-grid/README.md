# Tactical Grid - 平面回合制战棋游戏

> 基于设计全案《平面回合制游戏地图设计与设计思路全案》开发的全 AI 制作战术战棋游戏

## 快速开始

### 环境要求

- Node.js 18+
- Godot 4.2+
- Git

### 后端启动

```bash
cd server
npm install
cp .env.example .env  # 编辑配置
npm run dev            # 开发模式 http://localhost:3000
```

### 前端启动

```bash
# 用 Godot 编辑器打开 client/project.godot
# F5 运行主场景
```

### 生成测试地图

```bash
cd server
npx tsx src/mapgen/cli.ts --size small --seed 12345 --visualize
```

输出示例：
```
   0123456789
  +----------+
 0|.. H   c X|
 1|.E.c . ..c|
 2|.# Tcc E# |
 3|.c.##. c#c|
 4|.E..c# H..|
 5|#H$.  #cc#|
 6|.. . . .c |
 7|c .PPPP#..|
  +----------+
```

### 运行测试

```bash
cd server
npm test                      # 单元测试
npm run test:mapgen:stress    # 10000张地图压力测试
```

## 项目结构

```
tactical-grid/
├── server/                 # Node.js 后端
│   ├── src/
│   │   ├── mapgen/         # 地图生成器
│   │   ├── routes/         # API 路由
│   │   ├── models/         # 数据库
│   │   ├── middleware/     # 中间件
│   │   └── index.ts        # 入口
│   ├── data/               # 配置 JSON
│   ├── tests/              # 测试
│   └── package.json
├── client/                 # Godot 前端
│   ├── scripts/
│   │   ├── core/           # 核心系统
│   │   ├── game/           # 游戏逻辑
│   │   ├── map/            # 地图
│   │   ├── ui/             # 界面
│   │   └── network/        # 网络
│   ├── scenes/             # 场景
│   ├── assets/             # 资源
│   └── project.godot
├── docs/                   # 文档
└── README.md
```

## 核心系统

| 系统 | 文件 | 说明 |
|------|------|------|
| 网格坐标 | `core/grid_system.gd` | 逻辑坐标与世界坐标转换 |
| A* 寻路 | `core/pathfinding.gd` | 移动路径和可达范围 |
| 视线计算 | `core/vision_system.gd` | Bresenham 视线、掩体判定 |
| 战斗公式 | `core/combat_formulas.gd` | 命中、伤害、暴击 |
| 回合管理 | `game/turn_manager.gd` | 2AP 回合状态机 |
| 单位系统 | `game/unit.gd` | 属性、状态、装备 |
| 地图生成 | `mapgen/generator.ts` | 自动生成可玩地图 |
| 地图校验 | `mapgen/validator.ts` | 连通性、公平性、安全性 |
| API 服务 | `routes/*.ts` | REST API |

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/register | 注册 |
| POST | /api/auth/login | 登录 |
| POST | /api/auth/guest | 游客登录 |
| GET | /api/maps/campaign | 战役列表 |
| GET | /api/maps/:id | 关卡详情（含地图） |
| POST | /api/maps/generate | 随机生成关卡 |
| POST | /api/maps/:id/complete | 上报结果 |
| GET/POST | /api/saves | 存档管理 |
| POST | /api/telemetry | 遥测上报 |

## 开发进度

### 已完成 ✅

- [x] 后端项目搭建
- [x] 地图生成器（种子可复现、自动校验）
- [x] A* 寻路算法
- [x] 地图校验器（连通性/公平性/安全性/密度）
- [x] API 服务器（认证/关卡/存档/遥测）
- [x] 数据库（sql.js）
- [x] 单元测试（29 个，全部通过）
- [x] 压力测试框架（10000 张地图）
- [x] 前端核心系统（网格/寻路/视线/战斗公式）
- [x] 单位系统
- [x] 回合管理器
- [x] 地图加载器
- [x] API 客户端
- [x] 战斗场景控制器

### 进行中 🔄

- [ ] Godot 场景文件（.tscn）
- [ ] UI 界面布局
- [ ] 美术资产生成

### 待开发 📋

- [ ] 敌人 AI（Utility AI + Director）
- [ ] 完整 UI 界面
- [ ] 美术资源接入
- [ ] 音乐音效接入
- [ ] 存档系统完善
- [ ] 基地系统
- [ ] 剧情系统
- [ ] Roguelike 模式

## 文档

设计文档位于 [`../docs/design/`](../docs/design/) 目录：

| 文档 | 内容 |
|------|------|
| [完整开发规范文档](../docs/design/完整开发规范文档.md) | 总体架构与玩法 |
| [角色装备物品系统设计](../docs/design/角色装备物品系统设计.md) | RPG 系统 |
| [补充系统设计文档](../docs/design/补充系统设计文档.md) | 剧情/经济/PvP |
| [正式版补充设计文档](../docs/design/正式版补充设计文档.md) | 关卡/敌人/技能 |
| [工程交付文档集](../docs/design/工程交付文档集.md) | API/测试/CI-CD |
| [角色池装备扩充设计](../docs/design/角色池装备扩充设计.md) | 角色池扩充 |
| [终极补充设计文档](../docs/design/终极补充设计文档.md) | 天气/载具/MOD |
| [正式版内容深度补充](../docs/design/正式版内容深度补充.md) | Roguelike/NG+ |
| [AI游戏开发方案](../docs/design/AI游戏开发方案.md) | AI 全流程开发方案 |
| [项目文档完整性检查报告](../docs/design/项目文档完整性检查报告.md) | 文档完整度审计 |

## 技术栈

| 模块 | 技术 |
|------|------|
| 前端 | Godot 4.2 + GDScript |
| 后端 | Node.js + Express + TypeScript |
| 数据库 | sql.js（纯 WASM SQLite） |
| 测试 | Jest |
| 地图格式 | JSON（Tiled 兼容） |
