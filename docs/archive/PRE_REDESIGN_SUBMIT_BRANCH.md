# Pre-Redesign Submit Branch Archive

> status: Archived
> archived: 2026-07-31
> source commit: `ca64174b935946b111f382c65395401c0f533bce`
> archive tag: `archive/pre-redesign-submit-new-version-2026-07-31`
> superseded by: `main`

The former remote branch `codex/submit-new-version` contained an alternative pre-redesign implementation. It was reviewed during branch unification and was not merged into the current product line.

Reasons:

- It diverged before the approved Chapter One tactical-network design.
- It included an obsolete `1.1.0` version claim, online-service work and placeholder production assets outside the current product boundary.
- Its latest `_get_skill_range()` fix applies to a skill-preview call that no longer exists in `main`.
- Current `main` compiles and passes the 2026-07-31 Godot release gate with 2,639/2,639 assertions, 0 failures and 0 unexpected warnings/errors.
- Relevant interaction, turn, save, map and combat behavior must be implemented and tested against the current architecture instead of cherry-picking legacy controller code.

The archive tag preserves the exact historical commits. It is not a task source and must not be merged wholesale into `main`.
