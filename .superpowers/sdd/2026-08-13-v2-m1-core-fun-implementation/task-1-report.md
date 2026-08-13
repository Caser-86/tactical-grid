# Task 1 Report: Classify And Seal The Existing Dirty Baseline

## Status

The pre-existing baseline was snapshotted before inspection. Every original
dirty path is classified in
`tactical-grid/client/docs/v2_m1_baseline_audit_2026-08-13.md`. No production
correction was made because all required focused tests passed before a fix could
be proven necessary.

## Exact Commands And Results

```powershell
New-Item -ItemType Directory -Force -Path 'tactical-grid/client/artifacts/v2'
git status --short > tactical-grid/client/artifacts/v2/baseline-2026-08-13-status.txt
git diff --no-ext-diff > tactical-grid/client/artifacts/v2/baseline-2026-08-13.diff
git diff --no-ext-diff --numstat > tactical-grid/client/artifacts/v2/baseline-2026-08-13-numstat.txt
```

Snapshot capture exit code: 0.

From `tactical-grid/client`, seven independent Godot processes were run:

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_camera_input_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_input_router_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_action_service_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_enemy_occupancy_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_m1_tutorial_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_result_presentation_test.gd
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/v2/v2_unit_art_distinction_test.gd
```

Every Godot process exited 0. Their concise results were 9, 28, 19, 6, 18, 12,
and 44 passed checks respectively, with `Failed: 0` in every output.

```powershell
& '.\tests\v2\v2_release_isolation_test.ps1'
```

The isolation process exited 0 and printed `V2 release isolation passed`.
Raw output for every required process is retained at
`tactical-grid/client/artifacts/v2/baseline-2026-08-13-v2_*.log`.

## Classification

The audit contains the required classified file table: 28 original paths,
exactly one category per path, with intended behavior, focused test, and
keep/fix/defer decision. Totals are: `camera_input` 10,
`movement_occupancy` 2, `tutorial_objective` 8, `combat_death` 3,
`art_identity` 3, and `unrelated` 2.

## Files Changed By Task 1

- `tactical-grid/client/artifacts/v2/baseline-2026-08-13-status.txt`
- `tactical-grid/client/artifacts/v2/baseline-2026-08-13.diff`
- `tactical-grid/client/artifacts/v2/baseline-2026-08-13-numstat.txt`
- `tactical-grid/client/artifacts/v2/baseline-2026-08-13-v2_*.log`
- `tactical-grid/client/docs/v2_m1_baseline_audit_2026-08-13.md`
- `.superpowers/sdd/2026-08-13-v2-m1-core-fun-implementation/task-1-report.md`

## Commits

- Verified V2 baseline: `f2619791edb77ba2829185c6636b2ae4bad151ef`
- Task 1 audit: `dc11fb54afacebe79b64e684b5a025b2e95104f3`
- Task 1 snapshots and raw process evidence: `7455227b810ffcb50c704d83e3368083974d8626`

## Remaining Failures And Concerns

No required focused-test failure remains. Git printed LF-to-CRLF warnings while
reading tracked files. `tactical-grid/client/data/levels.json` has no textual
diff and, together with the user-owned P01 specification, is intentionally
unstaged as unrelated work.
