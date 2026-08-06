# Task 2 Report: Data-Driven Objective Steps and Generic Rescue

## Implementation

- `V2MissionFlow` now reads `mission.objective_steps`, exposes stable step ID/index/count and guide APIs, and persists objective progress in snapshots.
- Missions without `objective_steps` use the legacy M1 search/escort compatibility steps, retaining `SEARCH_SCOUT` and `ESCORT_TO_EVAC` state names and legacy `scout_rescued` input support.
- Event progression validates the current step event and required flags, returns explicit duplicate and unknown-event failures, and includes step metadata, guide text, and configured checkpoints in results.
- `V2RescueController` submits `character_rescued` with the rescued character ID. If the mission flow rejects it, the new Unit, action availability, recovery HP, player membership, and captive state are restored.
- `missions.json` defines M1 steps `search_scout`, `escort_scout`, and `evacuate`, plus M2 steps `disable_lockdown`, `rescue_sniper`, and `evacuate_squad`.

## Required Verification

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

  [PASS] 任务流公开目标步骤读取契约
  [PASS] 任务流公开快照恢复契约
  [PASS] 设置后从第一个目标步骤开始
  [PASS] 第一个目标步骤索引为零
  [PASS] 目标步骤总数为二
  [PASS] 完成事件推进到第二个步骤并返回索引和总数
  [PASS] 快照恢复保留当前目标步骤
Passed: 7
Failed: 0
```

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

  [PASS] M1 开场进入搜索状态
  [PASS] 开场目标简短
  [PASS] 开场持续指示目标标记和终点
  [PASS] 未营救不能撤离胜利
  [PASS] 营救后进入护送状态
  [PASS] 营救后目标更新
  [PASS] 营救后持续指示终点位置和自动完成
  [PASS] 重复营救被拒绝
  [PASS] 只有一名角色到达时不能撤离
  [PASS] 两名存活角色进入撤离区后胜利
  [PASS] 胜利状态不可误判为失败
  [PASS] 部分失能不立即判负
  [PASS] 全队失能判负
  [PASS] 不可逆主线失败判负
  [PASS] 未知事件返回明确错误
Passed: 15
Failed: 0
```

## Additional Investigation

`v2_rescue_character_test.gd` was attempted as an extra guard but did not emit output and exceeded the 120-second command timeout. This test is outside the task's required verification commands; no changes were made in response to the timeout.
