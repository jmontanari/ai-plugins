# /spec-flow:plan

Turn an approved spec into an exhaustive phase-by-phase implementation plan. The plan is detailed enough that a Sonnet-tier agent can execute each phase without making design decisions.

## What it does

Produces `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` — a file-level plan with:

- Phases ordered by dependency
- For each phase: file paths, function/class signatures, test file locations, the verification command
- Red/Build/Verify/Refactor checkboxes per phase
- Self-contained **Change Specification Blocks** (MODIFY / CREATE / DELETE) inside each Build/Implement block — verbatim current-state code with line numbers plus an inline pattern excerpt, so the executor implements without re-exploring
- Explicit charter-entry allocation — every NN-C / NN-P / CR the spec cites is allocated to exactly one phase
- Semantic anchors (function and class names) alongside line ranges
- Parallelization hints where safe
- Four required cross-cutting sections introduced v4.7–4.10: **AC Coverage Matrix**, **Executable AC Binding**, **Contracts**, **Architectural Decisions**

By the time this plan is approved, every design decision is captured. The execute command's job becomes mechanical: dispatch agents against the plan.

## When to run it

- After `/spec-flow:spec` has been signed off and the piece's status is `specced`.
- Run from the piece's worktree (`worktrees/prd-<prd-slug>/piece-<piece-slug>/`) on branch `piece/<prd-slug>-<piece-slug>`.

## Prerequisites gate

Before exploration, the plan skill **refuses to proceed if spec.md still contains surviving `[PENDING-DECISION: <area>]` markers** (markers inside fenced code blocks or HTML comments don't count). It lists each surviving marker and tells you to resolve it in spec.md, then re-run. This is the hard handoff from spec: deferred product decisions must be decided before they reach planning.

## The flow

### Phase 1: Read-only exploration

The skill explores the codebase using *only read operations* — Read, Grep, Glob, and read-only bash. It does not touch source files. Purpose: gather facts the plan will reference. A `depends_on:` precondition check (with pull-deps-in / fork / proceed triage) and a charter-drift check run first.

Collected:
- Existing code patterns relevant to the spec
- Function, class, and method names that will be referenced (these become semantic anchors)
- Test framework patterns used in the project
- Import conventions and module structure
- Architecture constraints visible in the code
- Charter files (v4: `<charter_root>/skills/charter-*/SKILL.md` — `.github` or `.claude`, resolved per [reference/charter-location.md](../../../reference/charter-location.md)) as exploration priors
- Significant architectural decisions, recorded as draft ADRs

**`introspection.md` is written during this phase.** Exploration findings (file inventory with verbatim code, dependency map, test landscape, pattern catalog) are written incrementally to `introspection.md` in the piece's working directory — an untracked working artifact, not committed. So Phase 1 is read-only *against the codebase* but does produce this one scratch file, which is the Phase 2 author's primary input and what makes resume cheap.

### Phase 2: Generate the plan

Using the spec, the exploration findings, and the plan template:

1. **Define phases** — each phase is a testable unit of work. Maps to one or more acceptance criteria. Has a clear exit gate.
2. **Pick a track per phase:**
   - **TDD track** — default for behavior-bearing code. Has `[TDD-Red]`, `[Build]`, `[Verify]`, `[Refactor]`, `[QA]` checkboxes.
   - **Implement track** — for config, infra, scaffolding, glue/wiring, docs-as-code. Has `[Implement]`, `[Verify]`, `[QA]` checkboxes.
3. **Fill in details per phase** as numbered, self-contained **Change Specification Blocks** (`T-1`, `T-2`, …). Each MODIFY block carries the verbatim CURRENT-state code (with line numbers from `introspection.md`), the TARGET description, an **inline** pattern excerpt (pasted, not a pointer), done criteria, and a verify command. CREATE and DELETE blocks have their own required fields. The executor can implement each block without reading surrounding context.
   - TDD: exact test file paths, test names, assertions, patterns to mirror.
   - Build: exact source file paths, class/function signatures, implementation approach.
   - Verify: copy-pasteable command with specific expected output (numbers/strings/exit code) — template placeholders must be resolved before sign-off.
4. **Allocate charter entries** — every cited NN-C / NN-P / CR from the spec's "Non-Negotiables Honored" section gets allocated to exactly one phase's "Charter constraints honored in this phase" slot. Drops or duplicates are caught by qa-plan.
5. **Mark parallel-safe phases** with `[P]` — verify no file overlap.
6. **Consider Phase Groups** — for pieces with ≥2 disjoint work units (e.g., N adapters), decompose into a group with parallel `[P]`-marked sub-phases. (Parallel-by-default: a serial chain over disjoint scopes needs a `Why serial:` justification.)
7. **Consider Phase 0 Scaffold** — if multiple phases append to the same shared coordination file, pre-append stubs in a single Scaffold phase first.
8. **Generate the four cross-cutting sections** (see "Required plan sections" below).

### Required plan sections (v4.7–4.10)

Beyond the phases, every plan carries four sections the qa-plan agent checks for completeness:

- **`## AC Coverage Matrix`** — every spec AC mapped to the covering phase, each marked `COVERED` or `NOT COVERED`. Each NOT COVERED row must get a forward pointer (defer to a named future piece, add coverage to a phase, or explicit justification) before the plan can finalize — the skill prompts you per row.
- **`## Executable AC Binding`** — each COVERED AC bound to a concrete verification (shell command, file-check, or agent-step) with an expected result. This is the contract between plan and execute.
- **`## Contracts`** — typed boundary interfaces for TDD-track phases (signature, inputs, outputs, error cases, constraints). A TDD phase with no boundary-crossing interface documents the omission explicitly; an Implement-only plan states the section is present for forward compatibility.
- **`## Architectural Decisions`** — ADR-format entries (Context / Decision / Alternatives considered / Consequences / Charter alignment) for every significant decision recorded during exploration. Always present, even when it's "No significant architectural decisions for this piece."

### Fast mode (`fast:` front-matter)

The plan front-matter records `fast: true` or `fast: false` (default `false`, or inherited from `.spec-flow.yaml`). **`fast: true`** drops the per-phase inline QA agents (`qa-tdd-red`, `qa-phase`, `qa-phase-lite`) and replaces the per-phase verify-agent dispatch with a direct test-command shell call; to compensate, the end-of-piece Final Review board gains a 9th member (`verify Mode: Piece Full`). It saves roughly 60% of QA token cost and suits config/infra/moderate-complexity pieces ≤12 phases — not security-critical, compliance, or cross-phase-dependent work.


### Choosing TDD vs. Implement

When `/spec-flow:plan` runs, it checks the `tdd` key in `.spec-flow.yaml`:

- **`auto` (default):** The user is asked whether to use TDD for this piece. The answer is recorded in the plan front-matter (`tdd: true` or `tdd: false`).
- **`true`:** All phases default to TDD track.
- **`false`:** All phases use Implement track + Write-Tests (non-TDD mode). No `[TDD-Red]`, `[QA-Red]`, or `[Build]`. Tests are written after implementation.

Per-phase overrides are always possible: a phase can use `[Implement]` even when TDD is `true`, and a non-TDD piece (where all phases are `[Implement]`) can still mark individual phases with `[Refactor]` if cleanup is needed.

See [TDD loop concepts](../concepts/tdd-loop.md#non-tdd-mode--the-piece-level-toggle) for the full comparison.

### Phase 3: QA loop

1. **qa-plan agent review** (Opus, adversarial):
   - AC Coverage Matrix bidirectional — every spec AC covered by a phase, and no phantom ACs?
   - Every phase has a clear exit gate? Verb alignment (the phase actually performs the AC's action)?
   - Red/Build/Verify/Refactor pattern complete for TDD phases?
   - Parallelization valid (no file overlap on `[P]` phases)?
   - Semantic anchors + line ranges used; Change Specification Blocks complete?
   - Charter allocations complete and unique?
   - Contracts coverage (every boundary-crossing interface in a TDD phase has a contract, or a documented omission)?
   - Architectural Decisions section complete (ADR fields filled)?
   - Executable AC Binding present with concrete commands per AC?
   - Algorithm-term consistency (dense algorithm prose carries a worked example)?
2. If findings emerge, fix-doc makes targeted fixes, qa-plan re-reviews the delta. Up to 3 iterations.
3. **You sign off.**

### Phase 4: Finalize

- Manifest on the piece branch: status → `planned` (main advances on merge/PR).
- Plan commits to the worktree branch.
- When Jira integration is configured (`auto_create_tasks: true`), per-phase issues are created and their `jira_key:` / `jira_url:` recorded inline in plan.md.

## Loops

- **Exploration loop** — not a retry loop; the skill iterates reads until it has enough to author the plan.
- **QA loop** — qa-plan ↔ fix-doc up to 3 iterations; circuit breaker on iteration 4.

## What you get

`docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` with this shape:

```markdown
---
slug: <piece-slug>
prd: docs/prds/<prd-slug>/prd.md
spec: docs/prds/<prd-slug>/specs/<piece-slug>/spec.md
tdd: true
fast: false
created: <date>
approved: <date>
branch: piece/<prd-slug>-<piece-slug>
charter_snapshot:
  non-negotiables: <date>
  architecture: <date>
  coding-rules: <date>
---

# Plan: <piece-slug>

**Spec:** docs/prds/<prd-slug>/specs/<piece-slug>/spec.md
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

And the manifest shows `<piece-slug>: status: planned`.

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

Plan commits as `plan: add my-product/PI-104-data-export implementation plan` on the `piece/my-product-PI-104-data-export` branch. The manifest update (`status: planned`) commits to the same branch — main's manifest advances when the branch merges or a PR opens. The `plan:` field now points to `docs/prds/my-product/specs/PI-104-data-export/plan.md`.

## Where to go next

- [/spec-flow:execute](./execute.md) — run the plan.
- [TDD loop concepts](../concepts/tdd-loop.md) — the cycle your phases will go through.
- [Orchestrator model](../concepts/orchestrator-model.md) — how execute dispatches agents against this plan.
