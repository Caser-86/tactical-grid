# Chapter One Character Art Bible

This document defines the runtime readability standard for Chapter One units. The production camera displays ordinary units inside a 64 x 64 cell and bosses inside a 96 x 96 to 128 x 128 footprint. Team rings, health and AP remain interface layers; identity must still survive when those layers and all text are removed.

## Shared Runtime Rules

- View: orthographic top-down with shallow painted volume and one consistent upper-left key light.
- Player palette: navy, steel blue and cyan, with one job-specific accent.
- Enemy palette: charcoal, oxidized red and hot orange, with threat-specific light patterns.
- Silhouette: role recognition must rely on body width, weapon length, head/sensor shape, backpack and stance. Recoloring the same body is not accepted.
- Scale: ordinary art fits inside 56 x 56 pixels within the 64 x 64 cell; Chapter One bosses use the 96 x 96 source and a wider base.
- Animation: `idle`, `move`, `attack`, `hit`, `skill` and `death` are required states. Continuous interpolation or four or more visually distinct procedural beats is equivalent to a frame strip.
- Reduced motion: idle bob is disabled and action durations are shortened through `AccessibilitySettings`; important camera feedback is disabled.
- Team readability: the faction base remains visible under art and must not be used as the only player/enemy distinction.

## Player Jobs

| Job | Silhouette | Weapon / equipment | Accent | Motion language |
| --- | --- | --- | --- | --- |
| Assault | Medium shoulders, forward triangular stance | Medium rifle across chest | electric blue | short forward attack snap, decisive straight movement |
| Sniper | Narrow torso and the longest barrel | Long rifle and compact optic | ice blue | low idle motion, long directional recoil |
| Heavy | Widest shoulders and circular rear armor | Heavy weapon, thick forearms | amber-blue | slower weight shift, small recoil, strong hit resistance |
| Medic | Medium-light body with visible medical pack/device | Medical projector and cross-shaped equipment light | white and mint | soft skill pulse, quick support movement |
| Scout | Lightest asymmetrical body with raised sensor | Short weapon and sensor mast | cyan-green | faster bob, compact recoil, agile movement lean |

## Chapter One Enemy Roles

| Runtime key | Tactical role | Required silhouette and signal |
| --- | --- | --- |
| `drone_assault` | fast assault | red star/wing planform, bright central core |
| `sentry_basic` | line infantry | upright angular guard chassis and single weapon arm |
| `sentry_sniper` | ranged threat | narrow guard chassis, long barrel and line-shaped targeting light |
| `shield_bot` | support / protection | broad shield arc that is wider than the body |
| `heavy_gunner` | heavy pressure | low wide chassis and oversized weapon block |
| `jammer` | control | antenna crown and concentric signal lights |

## Data Sentinel

- Source key: `boss_data_sentinel`.
- Source size: 96 x 96; runtime scale must remain visibly larger than ordinary enemies.
- Base: wide mechanical pedestal rather than an ordinary faction disc.
- Phase read: normal cyan core, warning amber transition and restrained red enrage pulse.
- Camera: phase transition uses the `boss_phase` event feedback owned by `BattleCameraController`; reduced-motion mode disables it.

## State Language

| State | Required visual evidence |
| --- | --- |
| `idle` | subtle 1-2 px breathing/hover offset; disabled by reduced motion |
| `move` | continuous cell-center interpolation with a slight directional lean |
| `attack` | anticipation, forward snap and return/recoil |
| `hit` | two-step red/white flash without hiding HP |
| `skill` | cyan/mint scale pulse distinct from weapon recoil |
| `death` | terminal fade, tilt and scale reduction; never returns to idle |

## Current Vertical Slice

- Assault, heavy and assault drone load separate production textures through `ArtCatalog`.
- Their alpha silhouettes pass automated pairwise-difference checks at 64 x 64.
- All six states are available through `UnitSprite`; movement, attack, hit, skill and death are wired into the real battle controller.
- Units and tactical effects are positioned at cell centers rather than grid intersections.
- Five-player black silhouette preview: `res://tests/unit_silhouette_preview.tscn`.
- Automated dynamic contract: `res://tests/unit_animation_contract_test.tscn`.

## Remaining Batch Work

- Perform blind human recognition for all five player silhouettes and record at least 4/5 correct without labels.
- Extend role-specific motion timing beyond the shared procedural baseline.
- Verify six enemy roles together in a dense encounter and replace any texture aliases that fail recognition.
- Add a boss phase preview and 100-unit/effect performance scene before Chapter One Production Gate.

