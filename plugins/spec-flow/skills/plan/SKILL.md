---
name: plan
description: Use when a spec is approved and needs a detailed implementation plan. Does read-only codebase exploration, generates an exhaustive phase-by-phase plan where each phase picks a TDD track (for behavior-bearing code) or an Implement track (for config, infra, glue code, docs-as-code), runs QA review, and gets human sign-off. Use whenever the user wants to turn an approved spec into an executable plan — even for non-TDD work.
---

# Plan — Generate Detailed Implementation Plan

Generate an exhaustive implementation plan from an approved spec. The plan is so detailed that a Sonnet-tier agent can execute each task without design decisions.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- Piece must have status `specced` in manifest at `docs/prds/<prd-slug>/manifest.yaml`
- `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` must exist and be approved
- Must be on the worktree branch `spec/<prd-slug>-<piece-slug>` (created by spec skill via `{{worktree_root}}/`)

## Workflow

### Phase 1: Read-Only Exploration

**Charter-drift check (always applies — runs first).** A piece reaching plan stage already has a spec carrying a `charter_snapshot:` front-matter. Before any other exploration, run the charter-drift check per `plugins/spec-flow/reference/charter-drift-check.md` against the spec's `charter_snapshot:` and the live `<docs_root>/charter/` files. If drift is detected, halt Phase 1 and escalate per the reference doc — do not proceed with planning on stale charter constraints.

Then extensively explore the codebase using ONLY read operations:
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
- **Charter files** at `<docs_root>/charter/` if present (architecture, non-negotiables, tools, processes, flows, coding-rules). Record each file's `last_updated` date for the plan's `charter_snapshot:` front-matter. Charter content is exploration priors, same as code — it influences phase decomposition and the per-phase "Charter constraints honored" slots.
- **Spec's `### Non-Negotiables Honored` and `### Coding Rules Honored` sections** — these enumerate the NN-C/NN-P/CR entries the piece claims it honors. The plan allocates each entry to the specific phase(s) that implement it via the per-phase "Charter constraints honored in this phase" slot.

### Phase 2: Generate Plan

Using the spec, exploration findings, and the plan template at `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`:

1. Define phases — each phase is a testable unit of work:
   - Map each phase to specific acceptance criteria from the spec
   - Define a clear exit gate for each phase
   - Order phases by dependency (inside-out execution)

2. For each phase, choose ONE track and generate its structure. A phase must have exactly one track marker — the executor branches on it mechanically.

   **TDD track** (default for behavior-bearing code):
   - **[TDD-Red]**: Exact test file paths, test names, assertions, patterns to follow
   - **[QA-Red]**: Theater-pattern review of Red's authored tests before Build (rejects tautology, mock-echo, truthy-only, no-assertion, name/body mismatch, implementation coupling, etc.); verifies adversarial AC binding
   - **[Build]**: Exact source file paths, class/function signatures, implementation approach
   - **[Verify]**: Test command to run, expected output
   - **[Refactor]**: Scope constraints (phase files only)
   - **[QA]**: ACs to review against, diff baseline

   **Implement track** (for config, infra, scaffolding, glue/wiring, docs-as-code, fixtures, migrations — where unit-level TDD is ceremony without payoff):
   - **[Implement]**: Exact file paths, signatures/structure, pattern pointers, architecture constraints the phase must honor
   - **[Verify]**: The verification command the plan author chooses (lint, type check, build, smoke run, integration test) and its expected output. For YAML/JSON validation in [Verify] blocks, default to LLM-agent-step framing per the plan template. External parsers (yq, jq, language interpreters) are not preconditions of this pipeline.
   - **[Refactor]** (optional): Include only if cleanup is plausibly needed
   - **[QA]**: ACs to review against, diff baseline

   Pick the track that matches reality. Don't force TDD onto a YAML file; don't skip TDD for a business rule.

2a. **Phase-sizing check (FR-11; v3.1.1+ filter rules).** After defining each phase's or sub-phase's `[Implement]` (or `[Build]`) block, count the **behavioral-prose lines** inside it — the actionable bullets and ordered-list items that prescribe what the implementer agent does. If the count exceeds 150 for any single phase or sub-phase, emit a warning:

    ```
    WARNING: Phase <num> (<title>): <N> lines of behavioral prose exceeds 150-line threshold; recommend split into a Phase Group with 2-3 sub-phases.
    ```

    **Counting rules (v3.1.1+):** a line counts toward the total if and only if it is non-blank AND not filtered by any of:
    - **Checkbox markers:** lines beginning with `- [ ] **[` or `- [x] **[` (the block-boundary markers themselves).
    - **HTML comments:** lines matching `^\s*<!--` through their closing `-->` (multi-line comments span their full extent and do not count).
    - **Fenced code blocks:** every line between an opening `` ``` `` (or `` ~~~ ``) fence and its closing fence does not count, including the fence lines themselves. Example shell snippets, YAML examples, and synthetic plan fragments quoted inside the `[Implement]` block are therefore excluded.
    - **Markdown horizontal rules and table separator lines** (`^---+$`, `|---|`).

    The plan author may suppress the warning by adding `phase_size_override: <reason>` as a single-line preamble to the offending phase's body (between the phase heading line and the `**Exit Gate:**` line). When an override is present the warning is suppressed but logged for posterity. The check counts from the start of the `[Implement]` (or `[Build]`) block inclusive to the next checkbox marker (`- [ ] **[`) exclusive.

2b. **Exit-gate semantics check (FR-12).** After all phases are drafted, scan each phase's `**Exit Gate:**` line and each `[Verify]` step's expected-output prose for the following patterns (case-insensitive):
    - `is documented to run`
    - `documented to run later`
    - `deferred to release`
    - `deferred to release time`
    - `documented for release`

    If any pattern matches, plan validation FAILS immediately with:

    ```
    ERROR: Phase <num> (<title>): exit-gate downgrade not allowed — string "<matched>" implies "X is documented" rather than "X ran." Per FR-12, this is rejected. If pre-merge execution truly is not possible, split the piece into PI-N (the artifact ships) and PI-Nb (the artifact is run on a real project).
    ```

    Plan authoring cannot proceed until the offending phase is rewritten or the piece is split. This check runs BEFORE the QA-loop dispatch in Phase 3 — structural validation precedes adversarial review.

    **Escape hatch (v3.1.1+):** the plan author may suppress the validator on a phase by adding `exit_gate_override: <reason>` as a single-line preamble to the offending phase's body (same convention as `phase_size_override`). Use ONLY when the matched pattern is legitimate quoted prose — e.g., a `[Verify]` block that asserts the absence of the forbidden pattern in some target file, or a meta-plan whose body documents the rejected pattern itself. The override is logged for posterity and surfaces in the plan's QA-loop input as `exit_gate_override active: <phase> — <reason>`. Per CR-008 the validator stays orchestrator-side; the override is a plan-author declaration, not an agent-side decision.

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

   **Structure a Phase Group as:** (note heading levels — the execute skill's Phase Scheduler detects `## Phase Group` at H2 and `#### Sub-Phase` at H4; deviating breaks detection)
   ```markdown
   ## Phase Group <letter>: <logical name>
   **Exit Gate:** all sub-phases pass oracle + group-level Deep QA clean
   **ACs Covered:** <union of sub-phase ACs>

   #### Sub-Phase <letter>.<n> [P]: <sub-phase name>
   **Scope:** <file paths, comma-separated — must be disjoint from sibling sub-phases>
   **ACs:** <subset of group ACs>
   - [ ] [TDD-Red] ...
   - [ ] [QA-Red] theater-pattern + AC-binding review of Red's tests
   - [ ] [Build] ...
   - [ ] [Verify] ...
   - [ ] [QA-lite] Sonnet narrow review, scope: this sub-phase only

   #### Sub-Phase <letter>.<n+1> [P]: <next sub-phase>
   ...

   #### Group-level
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

Write the plan to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/plan.md`. Populate the `charter_snapshot:` front-matter with each charter file's `last_updated` date captured during Phase 1 exploration. Populate each phase's "Charter constraints honored in this phase" slot with the subset of NN-C/NN-P/CR entries from the spec that the phase implements (every entry must appear in exactly one phase — no drops, no duplicates).

**Worktree/branch naming** (per FR-004 / FR-005): the plan skill operates on the worktree at `{{worktree_root}}/` on branch `spec/<prd-slug>-<piece-slug>` (created by the spec skill). Slug validity for both `<prd-slug>` and `<piece-slug>` is enforced by `plugins/spec-flow/reference/slug-validator.md` before any worktree or branch is created — cite, don't restate.

### Phase 3: QA Loop

Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).

1. Read template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-plan.md`

2. **Iteration 1 (full review):** Dispatch QA agent (Opus) with `Input Mode: Full`, the full plan, spec, PRD sections, and charter files (if present — all six; otherwise legacy `docs/architecture/`). The QA agent cross-checks that every NN-C/NN-P/CR cited in the spec appears in exactly one phase's "Charter constraints honored" slot, with no drops and no duplicates.
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
   # update manifest.yaml status for this piece in its PRD-local manifest
   git add <docs_root>/prds/<prd-slug>/manifest.yaml
   git commit -m "manifest: mark <prd-slug>/<piece-slug> as planned"
   git checkout spec/<prd-slug>-<piece-slug>
   ```
3. Commit plan on worktree branch:
   ```bash
   git add <docs_root>/prds/<prd-slug>/specs/<piece-slug>/plan.md
   git commit -m "plan: add <prd-slug>/<piece-slug> implementation plan"
   ```
