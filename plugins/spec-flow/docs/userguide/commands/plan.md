# /spec-flow:plan

Turn an approved spec into an exhaustive phase-by-phase implementation plan. The plan is detailed enough that a Sonnet-tier agent can execute each phase without making design decisions.

## What it does

Produces `docs/specs/<piece-name>/plan.md` — a file-level plan with:

- Phases ordered by dependency
- For each phase: file paths, function/class signatures, test file locations, the verification command
- Red/Build/Verify/Refactor checkboxes per phase
- Explicit charter-entry allocation — every NN-C / NN-P / CR the spec cites is allocated to exactly one phase
- Semantic anchors (function and class names) instead of line numbers
- Parallelization hints where safe

By the time this plan is approved, every design decision is captured. The execute command's job becomes mechanical: dispatch agents against the plan.

## When to run it

- After `/spec-flow:spec` has been signed off and the piece's status is `specced`.
- Run from the piece's worktree (`worktrees/<piece-name>/`).

## The flow

### Phase 1: Read-only exploration

The skill explores the codebase using *only read operations* — Read, Grep, Glob, and read-only bash. No files are written or modified in this phase. Purpose: gather facts the plan will reference.

Collected:
- Existing code patterns relevant to the spec
- Function, class, and method names that will be referenced (these become semantic anchors)
- Test framework patterns used in the project
- Import conventions and module structure
- Architecture constraints visible in the code

### Phase 2: Generate the plan

Using the spec, the exploration findings, and the plan template:

1. **Define phases** — each phase is a testable unit of work. Maps to one or more acceptance criteria. Has a clear exit gate.
2. **Pick a track per phase:**
   - **TDD track** — default for behavior-bearing code. Has `[TDD-Red]`, `[Build]`, `[Verify]`, `[Refactor]`, `[QA]` checkboxes.
   - **Implement track** — for config, infra, scaffolding, glue/wiring, docs-as-code. Has `[Implement]`, `[Verify]`, `[QA]` checkboxes.
3. **Fill in details per phase:**
   - TDD: exact test file paths, test names, assertions, patterns to mirror.
   - Build: exact source file paths, class/function signatures, implementation approach.
   - Verify: test command, expected output.
4. **Allocate charter entries** — every cited NN-C / NN-P / CR from the spec's "Non-Negotiables Honored" section gets allocated to exactly one phase's "Charter constraints honored in this phase" slot. Drops or duplicates are caught by qa-plan.
5. **Mark parallel-safe phases** with `[P]` — verify no file overlap.
6. **Consider Phase Groups** — for pieces with ≥2 disjoint work units (e.g., N adapters), decompose into a group with parallel `[P]`-marked sub-phases.
7. **Consider Phase 0 Scaffold** — if multiple phases append to the same shared coordination file, pre-append stubs in a single Scaffold phase first.


### Choosing TDD vs. Implement

When `/spec-flow:plan` runs, it checks the `tdd` key in `.spec-flow.yaml`:

- **`auto` (default):** The user is asked whether to use TDD for this piece. The answer is recorded in the plan front-matter (`tdd: true` or `tdd: false`).
- **`true`:** All phases default to TDD track.
- **`false`:** All phases use Implement track + Write-Tests (non-TDD mode). No `[TDD-Red]`, `[QA-Red]`, or `[Build]`. Tests are written after implementation.

Per-phase overrides are always possible: a phase can use `[Implement]` even when TDD is `true`, and a non-TDD piece (where all phases are `[Implement]`) can still mark individual phases with `[Refactor]` if cleanup is needed.

See [TDD loop concepts](../concepts/tdd-loop.md#non-tdd-mode--the-piece-level-toggle) for the full comparison.

### Phase 3: QA loop

1. **qa-plan agent review** (Opus, adversarial):
   - Every spec AC covered by a phase?
   - Every phase has a clear exit gate?
   - Red/Build/Verify/Refactor pattern complete for TDD phases?
   - Parallelization valid (no file overlap on `[P]` phases)?
   - Semantic anchors used (not line numbers)?
   - Charter allocations complete and unique?
2. If findings emerge, fix-doc makes targeted fixes, qa-plan re-reviews the delta. Up to 3 iterations.
3. **You sign off.**

### Phase 4: Finalize

- Manifest on master: piece status → `planned`.
- Plan commits to the worktree branch.

## Loops

- **Exploration loop** — not a retry loop; the skill iterates reads until it has enough to author the plan.
- **QA loop** — qa-plan ↔ fix-doc up to 3 iterations; circuit breaker on iteration 4.

## What you get

`docs/specs/<piece-name>/plan.md` with this shape:

```markdown
# Plan: <piece-name>

**Spec:** docs/specs/<piece-name>/spec.md
**Status:** draft

charter_snapshot:
  NN-C-001: "plugin.json / marketplace.json sync"
  CR-006: "Keep a Changelog format"

## Overview
<dependency ordering, track choices, why this structure>

## Phase 1: <name>
**Exit gate:** <concrete verification>
**ACs covered:** AC-1, AC-2

- [ ] [TDD-Red] Write failing test at tests/<path>/<name>_test.py — asserts <behavior>
- [ ] [Build] Implement MyClass.my_method in src/<path>/my_module.py (signature: my_method(self, x: int) -> str)
- [ ] [Verify] Run `pytest tests/<path>/<name>_test.py` — expect 1 test passing
- [ ] [Refactor] Scope: phase files only
- [ ] [QA] Opus review against AC-1, AC-2; diff baseline: phase-1-start

**Charter constraints honored in this phase:**
- NN-C-001: no drift introduced (plugin.json not touched)
- CR-006: N/A — no CHANGELOG edit in this phase

## Phase 2: ...
```

And the manifest shows `<piece-name>: status: planned`.

## Phase Groups — when to use them

A **Phase Group** is a parent phase with 2+ parallel-executable sub-phases. Good fit when:

- Multiple adapters / endpoints / handlers are each self-contained (separate files, no cross-references)
- Per-entity migrations
- Any decomposable work where sub-units are genuinely disjoint

Bad fit when:

- Sub-phase N+1 references types/functions from sub-phase N (coupled, not parallel)
- Work needs per-unit Opus deep review (Phase Groups defer Opus review to group level)

The execute orchestrator's scheduler detects `## Phase Group` headings and dispatches the sub-phases in parallel (or falls back to serial if sub-phase file scopes overlap).

## Phase 0 Scaffold — the coordination-file trick

If ≥2 phases each append to the same shared coordination file (e.g., an `__init__.py` + `__all__`, a `conftest.py`, a lint allowlist), the plan should author a **Phase 0: Scaffold** as an Implement-track phase that pre-appends stubs for every subsequent phase's additions in one commit.

Each stub entry must be defensive — valid before the code it references exists (conditional skips, guarded imports, tolerant manifest overrides).

Phase 0 Scaffold lets all subsequent phases write ONLY their own files (no edits to shared infrastructure), which enables true `[P]` parallel dispatch without races.

## Handoff

Next: `/spec-flow:execute` to run the plan phase-by-phase.

## Worked example

Spec: `PI-104-data-export` with 9 ACs, 7 FRs, citing NN-C-003 and CR-011.

After read-only exploration:
- `src/export/` directory exists with `__init__.py` and `legacy_csv.py`
- Test framework: pytest with fixtures in `tests/conftest.py`
- Auth pattern: decorator `@requires_auth` defined in `src/auth/decorators.py`

Plan authored with 6 phases:

```
Phase 1: data-export schema (Implement track — YAML schema, no TDD)
Phase 2: auth integration (TDD — decorator usage, 2 failing tests)
Phase 3: CSV writer (TDD — 3 failing tests)
Phase 4: JSON writer (TDD — 2 failing tests)
Phase 5: API endpoint (TDD — 4 failing tests, end-to-end)
Phase 6: CHANGELOG + README (Implement track — docs)
```

Phases 3 and 4 are marked `[P]` — disjoint file scopes (`csv_writer.py` vs `json_writer.py`). Phase 5 depends on both.

qa-plan flags two issues in iteration 1: Phase 2's Refactor scope was vague, and CR-011 wasn't allocated to any phase. fix-doc resolves both. Iteration 2 clears. You sign off.

Plan commits as `plan: add PI-104-data-export implementation plan` on the worktree branch. Manifest on master shows `PI-104-data-export: status: planned`.

## Where to go next

- [/spec-flow:execute](./execute.md) — run the plan.
- [TDD loop concepts](../concepts/tdd-loop.md) — the cycle your phases will go through.
- [Orchestrator model](../concepts/orchestrator-model.md) — how execute dispatches agents against this plan.
