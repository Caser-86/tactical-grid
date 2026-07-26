# Tactical Grid 项目模块

本目录包含 Godot 客户端和用于开发、地图生成与可选 API 的 Node.js 服务端。游戏采取离线优先设计：日常运行不应依赖本地 Node 服务。

当前实现仍是开发版本。实测状态与发布阻断项见 [PROJECT_STATUS.md](PROJECT_STATUS.md)。

## 环境

- Godot 4.7.1
- Node.js 20+（服务端、地图生成和服务端测试）
- npm 与 Git

## 运行客户端

在 Godot 中打开 `client/project.godot`，运行主场景 `res://scenes/boot.tscn`。

也可以从本目录运行：

```powershell
godot --path client
```

`start.bat` 会打开 Godot 编辑器。传入 `--with-server` 时，它会在单独窗口启动本地开发服务器；这不是玩家发行版所需步骤。

## 服务端与地图工具

```powershell
cd server
npm ci
npm run build
npm test -- --runInBand
npm run test:mapgen:stress
npx tsx tests/mapgen_seeds.ts
```

开发服务器可用下列命令启动：

```powershell
cd server
npm run dev
```

默认地址为 `http://localhost:3000`。客户端默认使用离线模式；不要把本地服务当作发布版依赖。

## Godot 验证

从仓库根目录运行：

```powershell
godot --headless --editor --path tactical-grid/client --quit
godot --headless --path tactical-grid/client res://tests/battle_smoke_test.tscn
```

第二条命令执行当前核心测试。通过测试不等同于发布验收：资源泄漏、完整场景输入流程和导出包仍需单独验证。

## 目录

```text
client/
  scenes/                   # Godot 场景，入口为 boot.tscn
  scripts/                  # 核心规则、战斗、UI、数据和网络代码
  data/                     # 客户端配置数据
  tests/                    # Godot 无头测试场景与运行脚本
server/
  src/                      # Express API 与地图生成器
  data/                     # 配置与锁定地图生成产物
  tests/                    # Jest、压力和固定种子测试
```

## 文档

- [仓库总览](../README.md)
- [当前状态](PROJECT_STATUS.md)
- [接管路线图](../docs/PROJECT_TAKEOVER_ROADMAP.md)
- [文档索引](../docs/README.md)
- [活跃设计范围](../docs/design/README.md)
