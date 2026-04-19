---
name: plan
description: Use when a spec is approved and needs a detailed implementation plan. Does read-only codebase exploration, generates an exhaustive phase-by-phase plan where each phase picks a TDD track (for behavior-bearing code) or an Implement track (for config, infra, glue code, docs-as-code), runs QA review, and gets human sign-off. Use whenever the user wants to turn an approved spec into an executable plan — even for non-TDD work.
---

# Plan — Generate Detailed Implementation Plan

Generate an exhaustive implementation plan from an approved spec. The plan is so detailed that a Sonnet-tier agent can execute each task without design decisions.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- Piece must have status `specced` in manifest
- `docs/specs/<piece-name>/spec.md` must exist and be approved
- Must be on the worktree branch `spec/<piece-name>`

## Workflow

### Phase 1: Read-Only Exploration

Extensively explore the codebase using ONLY read operations:
- `Read` — examine source files, test files, existing patterns
- `Grep` — find function signatures, class definitions, import patterns
- `Glob` — discover file structure and naming conventions
- `Bash` — read-only commands: `ls`, `git log`, `git diff`, `find`

**No files are written or edited during this phase.**

Gather:
- Existing code patterns relevant to this spec
- Function/class/method names that will be referenced (semantic anchors)
- Test framework patterns used in the project
- Import conventions and module structure
- Architecture constraints visible in the code

### Phase 2: Generate Plan

Using the spec, exploration findings, and the plan template at `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`:

1. Define phases — each phase is a testable unit of work:
   - Map each phase to specific acceptance criteria from the spec
   - Define a clear exit gate for each phase
   - Order phases by dependency (inside-out execution)

2. For each phase, choose ONE track and generate its structure. A phase must have exactly one track marker — the executor branches on it mechanically.

   **TDD track** (default for behavior-bearing code):
   - **[TDD-Red]**: Exact test file paths, test names, assertions, patterns to follow
   - **[Build]**: Exact source file paths, class/function signatures, implementation approach
   - **[Verify]**: Test command to run, expected output
   - **[Refactor]**: Scope constraints (phase files only)
   - **[QA]**: ACs to review against, diff baseline

   **Implement track** (for config, infra, scaffolding, glue/wiring, docs-as-code, fixtures, migrations — where unit-level TDD is ceremony without payoff):
   - **[Implement]**: Exact file paths, signatures/structure, pattern pointers, architecture constraints the phase must honor
   - **[Verify]**: The verification command the plan author chooses (lint, type check, build, smoke run, integration test) and its expected output
   - **[Refactor]** (optional): Include only if cleanup is plausibly needed
   - **[QA]**: ACs to review against, diff baseline

   Pick the track that matches reality. Don't force TDD onto a YAML file; don't skip TDD for a business rule.

3. Use semantic anchors (function names, class names) NOT line numbers
4. Mark parallel-eligible tasks with `[P]` — verify no file overlap
5. **Order the bullets inside `[Build]` / `[Implement]` blocks in checkpoint progression.** The implementer agent commits at each logical checkpoint during its dispatch; a well-ordered bullet list gives the agent natural checkpoint boundaries. Good order: data model or types first → public constructors / factories → public methods/functions → internal helpers → error paths and edge cases. Bad order: leaf helpers first, then the public API that calls them. Each bullet (or small group of bullets) should be a point where the code in-flight is lint-clean and internally consistent even if not yet feature-complete. This is guidance for readability and checkpoint quality, not a hard structural requirement — the agent will infer checkpoints regardless.
6. Include the agent context summary table
7. **Scaffold-first phase for coordination-file contention.** If ≥2 phases in this plan each append entries to the same shared coordination file(s), author a **Phase 0: Scaffold** as an Implement-track phase that pre-appends stub entries for *every* subsequent phase's additions in a single commit.

   "Coordination files" are any shared files that multiple phases will need to touch. Examples vary by ecosystem:
   - Test infrastructure: shared test config or fixture files (e.g. pytest `conftest.py`, Jest `setup.ts`, Go `testmain_test.go`, RSpec `spec_helper.rb`)
   - Module surface / re-exports: package index files (e.g. Python `__init__.py` + `__all__`, TypeScript/JS `index.ts` barrel, Rust `mod.rs`/`lib.rs`, Go `doc.go`)
   - Build/type/lint manifests: project config that lists modules or applies overrides (e.g. `pyproject.toml` + mypy overrides, `tsconfig.json` paths, `Cargo.toml` features, `go.mod` replaces, ESLint override blocks)
   - Allow/deny lists: dep or symbol allowlists the lint/static-analysis step reads
   - Test-discovery tables or registry tuples the test runner references

   Each stub entry must be defensive and valid before the code it references exists. The exact mechanism depends on the file type and language — pick whichever idiom the ecosystem supports:
   - Conditional skip when the target module is missing (e.g. Python `pytest.skip(...)` in an `except ModuleNotFoundError:` branch; Jest `describe.skip` around a missing-import guard; Go build tags or `t.Skip`; Rust `#[cfg(feature = "x")]`)
   - Guarded re-exports (e.g. `try: from .X import Y; except ImportError: pass` in Python; conditional `export` behind an env-gated dynamic import in JS; feature-flagged `pub use` in Rust)
   - Tolerant manifest entries (mypy `[[tool.mypy.overrides]]`, TypeScript `paths`, Cargo features — all permit entries for modules that don't exist yet)
   - Allowlist entries for the expected names (most linters tolerate unused entries)

   The Scaffold phase runs once before any adapter/subsystem phase. Its existence lets every subsequent phase write ONLY its own files — no edits to shared infrastructure — which unlocks true `[P]` parallel dispatch across those phases and eliminates the race where concurrent agents contend on the same coordination file.

   If only one phase touches the coordination files, skip Scaffold — it's overhead without payoff.

8. **Phase Groups for parallelizable work.** When a piece contains ≥2 units of work that touch disjoint file scopes and have no symbol dependencies on each other (classic examples: N independent adapters, N independent endpoints, per-table migrations), decompose them into a **Phase Group** with `[P]`-marked **Sub-Phases** instead of a single combined phase or a serial chain of flat phases.

   **Structure a Phase Group as:**
   ```markdown
   ## Phase Group <letter>: <logical name>
   **Exit gate:** all sub-phases pass oracle + group-level Deep QA clean
   **ACs covered:** <union of sub-phase ACs>

   ### Sub-Phase <letter>.<n> [P]: <sub-phase name>
   **Scope:** <file paths, comma-separated — must be disjoint from sibling sub-phases>
   **ACs:** <subset of group ACs>
   - [ ] [TDD-Red] ...
   - [ ] [Build] ...
   - [ ] [Verify] ...
   - [ ] [QA-lite] Sonnet narrow review, scope: this sub-phase only

   ### Sub-Phase <letter>.<n+1> [P]: <next sub-phase>
   ...

   ### Group-level
   - [ ] [Refactor] scope: union of sub-phase files (auto-skip if all Builds clean)
   - [ ] [QA] Opus deep review, diff baseline: group_start_sha
   - [ ] [Progress]
   ```

   **When to use Phase Groups:**
   - Adapter-pattern work (N adapters, each a separate file)
   - Independent endpoints, routes, or handlers
   - Per-entity migrations or transformations
   - Any decomposable work where sub-units are genuinely disjoint

   **When NOT to use Phase Groups:**
   - Single-file work — degenerate case, use a flat phase
   - Tightly-coupled code where sub-phase N+1 references types or functions defined in sub-phase N — the phases are not truly disjoint; keep them as a flat phase or sequential flat phases
   - Work that needs per-unit deep Opus review for regulatory/audit reasons — flat phases preserve per-phase Opus QA; Phase Groups defer it to group level

   **Scope discipline:** each Sub-Phase MUST declare its `**Scope:**` as a literal file path list (glob patterns rejected). The orchestrator validates disjointness at dispatch time — if two sibling sub-phases declare overlapping file paths, the whole group falls back to serial execution (parallelism would race on the overlap).

   **Phase 0 Scaffold interacts with Phase Groups.** If sub-phases in a group each need to append entries to a shared coordination file (a common `__init__.py`, a shared fixtures file, a test registry), author a Phase 0 Scaffold BEFORE the Phase Group to pre-create the entries. Otherwise concurrent sub-phases will race on the shared file. The existing Scaffold guidance above (previous rule) covers this pattern.

Write the plan to `docs/specs/<piece-name>/plan.md`

### Phase 3: QA Loop

1. Read template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-plan.md`

2. **Iteration 1 (full review):** Dispatch QA agent (Opus) with `Input Mode: Full`, the full plan, spec, and PRD sections:
   ```
   Agent({
     description: "Plan QA for <piece-name> (iter 1, full)",
     prompt: <composed>,
     model: "opus"
   })
   ```

3. **QA loop (iterations 2+, focused):** If iteration M-1 returned must-fix findings:
   - Dispatch fix agent (using `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md`) with prior findings + plan + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of plan.md.
   - Extract that diff string and hold it in orchestrator state as `plan_iter_M_fix_diff`.
   - Re-dispatch QA agent (fresh) with `Input Mode: Focused re-review`, the prior iteration's must-fix findings, and `plan_iter_M_fix_diff`. Do NOT re-send the full plan.
   - **Circuit breaker:** 3 iterations max, then escalate.
   - If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.

4. Present to user for sign-off.

### Phase 4: Finalize

1. User approves → continue
2. Update manifest on main: piece status → `planned`
   ```bash
   git checkout main
   # update manifest.yaml status for this piece
   git add docs/manifest.yaml
   git commit -m "manifest: mark <piece-name> as planned"
   git checkout spec/<piece-name>
   ```
3. Commit plan on worktree branch:
   ```bash
   git add docs/specs/<piece-name>/plan.md
   git commit -m "plan: add <piece-name> implementation plan"
   ```
