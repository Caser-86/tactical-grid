# Tactical Grid - 平面回合制战棋游戏

> 全 AI 制作的战术战棋游戏，基于 Godot 4 + Node.js + TypeScript

## 项目简介

Tactical Grid 是一款平面格子回合制战术战棋游戏（参考 XCOM 2 + Fire Emblem + Into the Breach），包含完整的后端 API、地图生成器、AI 系统和 Godot 前端。游戏采用 2AP 回合制、混合信息制（友方透明/敌方迷雾），支持 PC 和移动双端。

## 技术栈

| 模块 | 技术 |
|------|------|
| 前端 | Godot 4.2 + GDScript |
| 后端 | Node.js + Express + TypeScript |
| 数据库 | sql.js（纯 WASM SQLite） |
| 测试 | Jest |
| 地图格式 | JSON（Tiled 兼容） |

## 项目结构

```
├── tactical-grid/           # 主项目
│   ├── server/              # Node.js 后端
│   ├── client/              # Godot 前端
│   ├── docs/                # 项目文档
│   ├── tools/               # 开发工具
│   └── README.md
├── docs/                    # 顶层设计文档
└── README.md
```

## 快速开始

```bash
# 后端启动
cd tactical-grid/server
npm install
npm run dev            # http://localhost:3000

# 运行测试
npm test               # 29 个单元测试

# 生成地图
npx tsx src/mapgen/cli.ts --size small --seed 12345 --visualize

# 前端启动
# 用 Godot 4.2 编辑器打开 tactical-grid/client/project.godot
# 按 F5 运行
```

## 核心系统

| 系统 | 说明 |
|------|------|
| 网格坐标系统 | 逻辑坐标与世界坐标转换 |
| A* 寻路算法 | 移动路径和可达范围计算 |
| 视线计算 | Bresenham 视线、掩体判定 |
| 战斗公式 | 命中、伤害、暴击、闪避 |
| 回合管理 | 2AP 回合状态机 |
| 单位系统 | 属性、状态、装备、HP/AP |
| Utility AI | 评分决策 AI 系统 |
| 地图生成器 | 种子可复现、自动校验 |

## 开发进度

- ✅ 核心系统完成（29/29 测试通过）
- ✅ 地图生成器（三档尺寸/五主题/六任务类型）
- ✅ 后端 API（认证/关卡/存档/遥测）
- ✅ AI 系统（Utility AI + Director）
- ✅ UI 系统（主菜单/战斗HUD/结算/设置）
- ✅ 数据系统（全量 JSON 配置）
- ✅ 美术资产基础（AI 生成）
- 🔄 场景文件细节调优
- 📋 音效/动画/剧情完善

## 设计文档

详细设计文档见 [`docs/`](docs/) 目录。
