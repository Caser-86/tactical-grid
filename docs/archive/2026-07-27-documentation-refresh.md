# Documentation Refresh Implementation Plan (Historical)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make repository documentation accurate, navigable, and safe to use as the source of truth for current development.

**Architecture:** Keep one concise repository entry point, one project-module runbook, one verified project-status snapshot, and one active documentation index. Preserve earlier design explorations under an archive path so they remain searchable without being mistaken for current commitments.

**Tech Stack:** Markdown, Git, Godot 4.7.1, Node.js/TypeScript.

## Global Constraints

- Treat `docs/PROJECT_TAKEOVER_ROADMAP.md` as the current implementation roadmap.
- Do not claim a feature is complete without a recorded verification result.
- Do not delete historical design material; move it to `docs/archive/design-notes/`.
- Do not stage client, server, scene, test, map, or asset changes in this documentation-only commit.
- Preserve the existing Chinese documentation language.

---

### Task 1: Establish the active documentation entry points

**Files:**
- Modify: `README.md`
- Modify: `tactical-grid/README.md`
- Create: `docs/README.md`
- Create: `docs/DOCUMENTATION_POLICY.md`

**Produces:** A stable entry path from repository overview to runbook, roadmap, status snapshot, active design notes, and archive.

- [x] **Step 1: Replace stale README claims with a verified scope statement**

State that Tactical Grid is a Godot 4.7.1 tactical-game project in active development, not a released game. Link to the project module, roadmap, status snapshot, active design index, and archive.

- [x] **Step 2: Write reproducible development commands**

Document `npm ci`, `npm run build`, `npm test -- --runInBand`, `npm run test:mapgen:stress`, and the Godot headless smoke-test command with their working directories.

- [x] **Step 3: Define documentation ownership**

State which file is authoritative for implementation progress, current status, setup, active design, and historical reference.

### Task 2: Replace the stale status snapshot

**Files:**
- Modify: `tactical-grid/PROJECT_STATUS.md`

**Produces:** A short, dated status report that separates verified functionality from known gaps.

- [x] **Step 1: Record only current, verified facts**

Include the 14 Godot scenes, 34 GDScript files, 30 generated maps, 189 Godot smoke assertions, 29 server tests, and 99.96% map stress-test result.

- [x] **Step 2: Explicitly list release blockers**

List locked-map client integration, objective entities, non-hardcoded skill/item selection, resource leaks, production art/audio, licensing, and export validation.

### Task 3: Archive speculative and superseded design notes

**Files:**
- Move: `docs/design/*.md` to `docs/archive/design-notes/`
- Move: `docs/tools/*` to `docs/archive/initial-audit/`
- Create: `docs/design/README.md`
- Create: `docs/archive/README.md`

**Produces:** An active `docs/design/` directory with one scoped design brief; historical materials remain available under an explicit archive banner.

- [x] **Step 1: Move the 12 legacy design files without content changes**

Use `git mv` so history remains traceable. Do not alter their text in the same commit.

- [x] **Step 2: Create an active design brief**

Define the launch scope as offline single-player, 2AP tactical missions, five chapters/30 missions as the content target, and no PvP, live service, mobile release, MOD support, or roguelike mode as current commitments.

- [x] **Step 3: Add archive guidance**

Explain that archived documents are ideation and historical material, and that conflicts are resolved in favor of the roadmap, source code, and current status snapshot.

- [x] **Step 4: Archive one-off initial-audit scripts and captured output**

Move the obsolete audit scripts and their output out of the active documentation tree. Record that their paths and conclusions reflect the pre-recovery project state and must not be used as current validation commands.

### Task 4: Verify and publish the documentation-only change

**Files:**
- Verify: all changed Markdown files

**Produces:** A documentation-only commit on `codex/docs-refresh`.

- [x] **Step 1: Check all Markdown links and active-file references**

Run a repository link/reference scan and confirm that every link target exists.

- [x] **Step 2: Check the staged scope**

Run `git diff --cached --name-only` and verify it contains only README and `docs/`/`PROJECT_STATUS.md` documentation paths.

- [x] **Step 3: Commit and push**

Commit with `docs: refresh project documentation`, push `codex/docs-refresh`, and create a draft pull request unless direct push to the default branch is explicitly requested.

## Self-Review

- Scope coverage: repository README, project README, status snapshot, active design, archive structure, policy, and roadmap discoverability are covered by Tasks 1-3.
- Placeholder scan: this plan contains no TBD items; every task identifies files and a concrete result.
- Consistency: Task 1 establishes the active links used by Tasks 2 and 3; Task 4 validates that those links and the documentation-only scope are intact.
