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

## A-1 Fix Round 1

### Status

Corrected only the three reviewed A-1 V2 contract scripts. No production code
or V1 files changed.

### Changed Files

- `tactical-grid/client/tests/v2/v2_hazard_controller_test.gd`
- `tactical-grid/client/tests/v2/v2_encounter_queue_test.gd`
- `tactical-grid/client/tests/v2/v2_checkpoint_migration_test.gd`

### Commit Hashes

- `08e0227 test(v2): correct shared mission contracts`

### Commands And Outputs

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_hazard_controller_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

SCRIPT ERROR: Parse Error: Preload file "res://scripts/v2/mission/v2_hazard_controller.gd" does not exist.
   at: GDScript::reload (res://tests/v2/v2_hazard_controller_test.gd:4)
ERROR: Failed to load script "res://tests/v2/v2_hazard_controller_test.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
```

Exit code: `1`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

  [FAIL] 遭遇激活器公开击败和等待队列契约
  [FAIL] 遭遇激活器公开快照恢复契约
Passed: 0
Failed: 2
```

Exit code: `1`.

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_checkpoint_migration_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

  [PASS] schema 3 检查点夹具通过现有校验并含有效哈希
  [FAIL] 检查点适配器公开 schema 3 到 4 的迁移契约
Passed: 1
Failed: 1
```

Exit code: `1`.

Command:

```powershell
git diff --check
```

Output: no whitespace errors; Git reported only the repository's existing LF-to-CRLF checkout warnings.

### Self-Review Notes

- The hazard test now calls `setup(hazard_data, map_size)` and
  `advance_player_turn(turn)`, asserts `warning_cells`, `active_cells`,
  `closed`, and `cycle`, and does not create player Units or inspect HP.
- The encounter test keeps a live first-encounter enemy active while requesting
  two new enemies under `active_cap = 3`, making at least one new enemy wait.
  It also gates all dynamic snapshot calls behind explicit method-contract
  checks.
- The migration fixture uses `V2CheckpointAdapter.capture()` with valid V2
  identity, level, encounter, unit, state, and legacy mission-phase data. Its
  `validate()` assertion confirms the generated schema-3 hash before testing
  migration preservation.

### Concerns

- The three scripts remain red against the current branch because the planned
  hazard controller file, encounter queue/snapshot APIs, and schema-4
  migration API have not been implemented yet. The checkpoint fixture itself
  is now validated successfully.

## A-1 Fix Round 2

### Status

Corrected only the encounter queue snapshot-restoration assertion. No
production code or V1 files changed.

### Changed Files

- `tactical-grid/client/tests/v2/v2_encounter_queue_test.gd`

### Commit Hashes

- `59c63df test(v2): preserve encounter snapshot sets`

### Commands And Outputs

Command:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/v2/v2_encounter_queue_test.gd
```

Output:

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

  [FAIL] 遭遇激活器公开击败和等待队列契约
  [FAIL] 遭遇激活器公开快照恢复契约
Passed: 0
Failed: 2
```

Exit code: `1`.

Command:

```powershell
git diff --check
```

Output: no whitespace errors. Git emitted only the repository's existing
LF-to-CRLF checkout warnings.

### Self-Review Notes

- The test captures active and waiting enemy IDs before creating the snapshot.
- Restoration compares the captured active, waiting, and defeated enemy sets
  against the restored state using order-independent comparisons.
- The restored waiting assertion no longer depends on `enemy_four`; it checks
  the exact pre-snapshot waiting set.

### Concerns

- The affected test remains red because the current production activation
  class does not yet expose the queue and snapshot APIs required by this
  contract. The update was limited to making the restoration assertion honest.
