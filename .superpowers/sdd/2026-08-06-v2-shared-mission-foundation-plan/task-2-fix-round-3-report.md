# Task 2 Fix Round 3 Report

## Scope

- Base commit: `20b1256`
- Worktree: `ch1-infiltration-v2`
- Engine: Godot `4.7.1.stable.official.a13da4feb`
- V1 paths were not modified.

## Fixes

- Replaced the direct `V2MissionEventBridge` fixture with a scene-driven controller fixture in `tests/v2/v2_m1_evacuation_bridge_test.gd` and `.tscn`.
- The M1 positive case loads shipped `res://data/v2/missions.json` and the shipped M1 locked map. It uses `BattleController.request_move()`, which executes `_finalize_v2_move()`, `_apply_v2_mission_event()`, the production V2 bridge, and `_check_victory_instant()`.
- The M1 case asserts that an unready evacuation does not progress, then asserts that ready evacuation submits the configured `mission_completed` event exactly once, reaches V2 victory, and reaches `TurnManager.BATTLE_OVER` without calling `_end_battle()` from the test.
- The same fixture loads shipped M2 mission data and drives a ready `evac_checked` through `BattleController`, asserting direct completion with no synthetic `mission_completed` event.
- Moved this controller test from `gate_manifest.json.script_tests` to `scene_tests`. Running it as a scene registers the real project autoloads before the controller script compiles; this avoids changing production singleton references or V1 behavior.

## Verification

All commands below were run from `D:\LLM Files\files\tactical-grid\.worktrees\ch1-infiltration-v2\tactical-grid\client`, with a 60-second bound per command.

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
# Exit code: 0; Passed: 7; Failed: 0

& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_flow_test.gd
# Exit code: 0; Passed: 18; Failed: 0

& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_character_test.gd
# Exit code: 0; Passed: 19; Failed: 0

& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_progression_test.gd
# Exit code: 0; Passed: 16; Failed: 0

& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_m1_evacuation_bridge_test.tscn
# Exit code: 0; Passed: 19; Failed: 0

& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/v2/v2_rescue_battle_integration_test.tscn
# Exit code: 0; Passed: 13; Failed: 0
# Godot emitted 2 existing ObjectDB leak warnings during this formal scene teardown.
```

## Standalone Harness Limitation

The old standalone formal commands remain unable to compile because Godot `--script` resolves the test and dependent scripts before registering project autoload identifiers:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_rescue_battle_integration_test.gd
# Exit code: 1; Identifier not found: GameManager in tutorial_hint.gd, pause_menu.gd, battle_controller.gd, battle_camera_controller.gd, and the integration test.

& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_m1_e2e_test.gd
# Exit code: 1; same GameManager errors plus Identifier not found: AudioManager in the E2E test.
```

The scene-driven controller fixture is the equivalent runnable controller-level proof and passes without a direct bridge instantiation or a test-side private `_end_battle()` call.
