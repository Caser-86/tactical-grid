# V2 Visual Acceptance Matrix

## Automated Coverage

The release matrix uses Windows Compatibility rendering and validates every PNG
for existence, non-zero file size, and exact dimensions.

| Mission | Resolutions | Modes | Stages | Snapshots |
| --- | --- | --- | --- | ---: |
| M1 Echo Yard | 1280x720, 1920x1080 | normal, grayscale, deuteranopia_assist | start, route_split, record_room, gantry_open, rescue, evac_intercept, result | 42 |
| M2 Cooling Works | 1280x720, 1920x1080 | normal, grayscale, deuteranopia_assist | start, route_west, route_east, turbine, hazard_warning, cooling_room, sniper_rescue, exit_countermeasure, result | 54 |

Run the unified entry point from `client`:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/v2/run_v2_m1_m2_visual_matrix.ps1
```

The two source matrices remain separate so a failure identifies M1 or M2:

- `tests/v2/run_m1_visual_matrix.ps1`
- `tests/v2/run_m2_visual_matrix.ps1`

## Manual Review Gate

Automated PNG generation is not a substitute for visual review. Mark each item
only after inspecting the generated screenshots at both resolutions and all
three modes.

- [ ] Player and enemy silhouettes remain distinct at normal gameplay scale.
- [ ] M1 route, gantry, rescue, evacuation interception, and result states are readable.
- [ ] M2 route consequences, hazard warning, cooling control, sniper rescue, countermeasure, and result states are readable.
- [ ] Primary objective and evacuation marker remain visible without covering units.
- [ ] Fog-of-war boundary reveals newly observed cells without stale hidden cells.
- [ ] Movement cells, attack cells, and invalid destinations use different affordances.
- [ ] Hazard warning cells are distinguishable from attack cells in grayscale and deuteranopia assist.
- [ ] Facility labels and action previews fit within the HUD without text overlap.
- [ ] Bottom control guide remains readable and does not cover the action bar.
- [ ] Failure and victory screens expose the correct next action without clipped text.

## Evidence

The automated release gate records the latest result in its console summary. A
passing automated matrix confirms `96/96` snapshots; the manual checklist above
must still be completed before the Windows release gate can be marked complete.
