# Task 1 Report: Shared State Contract Tests

## Status

Implemented the four requested V2 shared-mission contract tests and registered
them in the V2 gate manifest before the existing M1 tests. The required
mission-flow contract test was run and failed as expected because the current
production `V2MissionFlow` implementation does not expose the objective-step
reader APIs.

## Changed Files

- `tactical-grid/client/tests/v2/v2_mission_flow_contract_test.gd`
- `tactical-grid/client/tests/v2/v2_encounter_queue_test.gd`
- `tactical-grid/client/tests/v2/v2_hazard_controller_test.gd`
- `tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd`
- `tactical-grid/client/tests/v2/gate_manifest.json`

## Commit Hashes

- `3bb1e94 test(v2): add shared mission contract coverage`

## Commands And Outputs

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_mission_flow_contract_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

  [FAIL] 任务流公开目标步骤读取契约
  [PASS] 任务流公开快照恢复契约
Passed: 1
Failed: 1
```

Exit code: `1`.

Additional review command:

```powershell
git diff --cached --check
```

Output: no whitespace errors.

## Self-Review Notes

- The mission-flow contract uses two literal `objective_steps`, asserts the
  initial step, count, event-driven advance result, and snapshot restoration.
- The encounter contract uses four fresh enemy fixtures with two encounters
  and `active_cap = 3`; it asserts a surviving old enemy remains active, a new
  enemy waits, and the defeated enemy is retained in the snapshot.
- The hazard contract keeps the player in the configured hazard cell for both
  turns. It verifies a warning-only turn followed by configured damage without
  changing a unit position or altering enemy damage.
- The migration contract verifies schema `3` to `4` while retaining player,
  enemy, and legacy mission-phase data.
- All four paths are listed before `v2_m1_config_test.gd`, the first existing
  M1 entry in `gate_manifest.json`.

## Concerns

- The checked-in production code currently lacks the objective-step reader
  methods, so the specified test deliberately remains red until the follow-up
  implementation task supplies them.
- `v2_hazard_controller.gd`, encounter queue methods, and the schema-3-to-4
  migration method are also production work expected from later tasks. Their
  contract scripts are registered but were not independently executed because
  those production contracts do not yet exist.
