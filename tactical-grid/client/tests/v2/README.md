# V2 测试目录

V2 测试、真实输入回归和首次玩家验收记录放在本目录。V1 测试结果不能直接作为 V2 通过证据。

## F01 发布门

从 `tactical-grid/client` 运行：

```powershell
$godotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
& $godotExe --headless --path . --script res://tests/v2/gate_manifest_test.gd
powershell -ExecutionPolicy Bypass -File tests/v2/run_v2_gate.ps1
```

`gate_manifest.json` 是 V2 门的唯一顺序清单。每个 Godot 脚本、场景和 PowerShell 检查都在独立进程中运行；任一非零退出码都会停止发布门。门通过时最后一行必须是 `V2 RELEASE GATE PASSED`。

测试脚本使用 `V2TestRunner` 输出英文 `Passed: N` 和 `Failed: 0`，便于后续阶段的 PowerShell 门稳定解析。V2 门会先检查 V2 用户目录，再运行 V1 已有发布门；它不会修改 V1 的测试、存档或发布目录。
