# V2 M1 Single-Owner Acceptance

## Status

`incomplete`

This document is the human acceptance record for the V2 M1 candidate. Automated tests may validate contracts and record telemetry, but only the project owner may choose `approved` or `rejected` after playing the exported build. Until that happens, the result remains `incomplete`.

## Owner Checkpoint

On 2026-08-15 the project owner reported that the exported candidate was playable enough to continue development. This is a continuation checkpoint, not a public-release approval: no detailed run duration, per-check result, or defect list was supplied, so the checklist below remains available for the later multi-player H1 gate.

## Candidate

- Mission: `ch1_m1`
- Mission version: `v2_m1`
- Difficulty: `story` or `standard`
- Playtest ID: `OWNER`
- Build identifier: fill after Task 16 creates the candidate
- Date/time: fill after the owner run

## Run Procedure

1. Start from a clean V2 save. Do not open the Godot editor during the run.
2. Launch the exported candidate with `--v2-playtest-id=OWNER`.
3. Play the complete M1 flow: locate the rescue signal, rescue the scout, then move the surviving squad into the evacuation zone.
4. Keep the local record at `user://playtests/m1/OWNER.json`; it is runtime output and must not be committed.
5. If the run fails, record the checkpoint/retry used and the first reproducible symptom.

## Acceptance Checklist

| Check | Result | Notes |
|---|---|---|
| First legal move understood and completed within 60 seconds | `[ ]` | |
| First attack understood and completed within 90 seconds | `[ ]` | |
| Current objective and next destination understood without external instructions | `[ ]` | |
| Three meaningful decisions available before the end of M1 | `[ ]` | |
| Player can distinguish assault, scout, sentry, drone, and shield roles at a glance | `[ ]` | |
| No three-turn dead travel or forced route with no decision | `[ ]` | |
| Camera pan and return-to-unit controls are discoverable and repeatable | `[ ]` | |
| Damage, enemy intent, downed state, rescue, and evacuation feedback are readable | `[ ]` | |
| Full run fits the 12-18 minute M1 target on the selected difficulty | `[ ]` | |
| Victory, failure, retry, and return-to-base exits are understandable | `[ ]` | |

## Observed Issues

| Severity | Reproduction | Expected | Actual | Owner |
|---|---|---|---|---|
| P0/P1/P2/P3 | | | | |

## Telemetry Sanity

The recorder is opt-in. A normal launch without `--v2-playtest-id` must not create a playtest session. The `OWNER` session is append-only JSON and may contain mission/version/difficulty, relative and UTC timestamps, turns, action counters, camera recovery counts, damage/intent/downed/retry/soft-lock events, and completion state. It must not contain screenshots, names, machine names, accounts, network identifiers, or other personal identifiers.

## Human Decision

- Human result: `incomplete`
- Owner name/signature: fill manually if the project process requires it; do not put it in telemetry
- Decision date: fill manually
- Release note: fill manually after reviewing all observed issues

`approved` is not a value that AI or an automated test may write into this record.
