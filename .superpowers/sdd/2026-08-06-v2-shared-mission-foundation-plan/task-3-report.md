# Task 3 Report - V2 Encounter Queue and Defeat Persistence

## Summary

Implemented Task 3 only for V2 encounter activation/runtime:

- Added persistent, disjoint active/waiting/defeated/departed enemy ID sets.
- Preserved legacy `active_enemy_ids` compatibility in snapshots.
- Added `active_cap` default `3`, waiting overflow, deterministic promotion, and occupied-spawn deferral.
- Added `spawn_cells`/`retreat_cells` support with authored enemy-position fallback.
- Added idempotent `mark_enemy_defeated()` and `mark_enemy_departed()` results.
- Added V2 battle-controller delta application that uses live enemy IDs, occupied cells, removes defeated/departed visuals/occupancy, and only spawns into free valid cells.
- Repaired Task 3 behavior tests; no V1 files were modified.

## Changed Files

- `tactical-grid/client/scripts/v2/mission/v2_encounter_activation.gd`
- `tactical-grid/client/scripts/v2/runtime/v2_battle_controller.gd`
- `tactical-grid/client/tests/v2/v2_encounter_queue_test.gd`
- `tactical-grid/client/tests/v2/v2_enemy_occupancy_test.gd`

## Baseline / RED Evidence

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd
```

Result before retreat fallback fix: exit `1`; `Passed: 11`, `Failed: 1`.

Expected failing assertion:

```text
[FAIL] 缺少 retreat_cells 时使用敌人原始位置作为确定性撤离回退
```

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
```

Result during an intermediate controller-instantiation test attempt: timed out at bounded `60000 ms` before output. Root cause was the test attempting to preload/instantiate the full V2 battle controller directly from this unit-style script; the test was reshaped to cover the occupancy behavior at the encounter-service boundary and the controller is compiled by `v2_battle_runtime_contract_test.gd`.

## Final Verification

All commands were run from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client` unless noted.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd
```

Result: exit `0`; `Passed: 12`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_enemy_occupancy_test.gd
```

Result: exit `0`; `Passed: 6`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Result: exit `0`; `Passed: 7`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
```

Result: exit `0`; `Passed: 18`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_character_test.gd
```

Result: exit `0`; `Passed: 19`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_progression_test.gd
```

Result: exit `0`; `Passed: 16`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_battle_runtime_contract_test.gd
```

Result: exit `0`; `Passed: 2`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_runtime_isolation_contract.tscn
```

Result: exit `0`; `Passed: 6`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_rescue_battle_integration_test.tscn
```

Result: exit `0`; `Passed: 13`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/v2/v2_base_progression_scene_test.tscn
```

Result: exit `0`; `Passed: 24`, `Failed: 0`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene res://tests/battle_smoke_test.tscn
```

Result: exit `0`; `通过: 1816`, `失败: 0`.

Command from worktree root:

```powershell
git diff --check
```

Result: exit `0`.

## Warnings

- `git diff --check` and diff/status commands emitted line-ending warnings that LF will be replaced by CRLF for the four modified Task 3 files.
- `v2_runtime_isolation_contract.tscn` and `v2_rescue_battle_integration_test.tscn` passed but emitted Godot exit cleanup warnings: `2 ObjectDB instances were leaked at exit` and `1 resources still in use at exit`.
- V1 smoke passed but intentionally emitted save recovery warnings while testing corrupted/missing save fallback for `user://saves/save_0.bak` and `user://saves/save_1.bak`.
- Removed ignored stale temporary artifact `tactical-grid/client/tests/v2/v2_battle_probe.gd.uid`.
