# Tactical Grid V2 项目模块

本目录是纯 Godot 4.7.1 离线单机项目。正式关卡只读取 `client/data/locked_maps/`，运行、测试和导出均不依赖 Node、服务器、账号或网络。

V2 当前状态见 [PROJECT_STATUS_V2.md](PROJECT_STATUS_V2.md)，唯一执行入口见 [V2 版本说明](../docs/v2/README.md)。根目录的 `PROJECT_STATUS.md` 和 `docs/PROJECT_TAKEOVER_ROADMAP.md` 属于 V1 历史基线，不属于 V2 执行范围。

## 环境

- Godot 4.7.1 stable
- Git
- Windows 10/11 x64

## 运行

在 Godot 中打开 `client/project.godot` 并运行 `res://scenes/boot.tscn`，或执行：

```powershell
godot --path client
```

`start.bat` 只负责查找 Godot 4.7.1 并打开编辑器。

## 测试

从 `client/` 运行：

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_release_gate.ps1
```

该门禁执行 Godot 导入、音频技术检查、核心烟雾、第一章流程、HUD、存档、行动、地图、迷雾、敌方意图、网络和警戒测试。自动化通过不能替代真人操作、趣味性和发布环境验收。

## Windows 导出

从 `client/` 运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
powershell -ExecutionPolicy Bypass -File tests/verify_windows_package.ps1
```

正式发布前还必须完成干净克隆、干净 Windows 账户、分辨率矩阵、许可证、哈希和两小时长时运行。

## 目录

```text
client/
  assets/                   # 已记录来源的运行时与源资源
  data/                     # 游戏数据、锁定地图和资源清单
  scenes/                   # Godot 场景
  scripts/                  # 核心、战斗、AI、UI、地图和存档
  tests/                    # 自动化契约、E2E 与发布门
  tools/                    # 资源处理、音频生成和 Windows 构建
```
