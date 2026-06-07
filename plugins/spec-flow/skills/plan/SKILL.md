---
name: plan
description: Use when a spec is approved and needs a detailed implementation plan. Does read-only codebase exploration, generates an exhaustive phase-by-phase plan where each phase picks a TDD track (for behavior-bearing code) or an Implement track (for config, infra, glue code, docs-as-code), runs QA review, and gets human sign-off. Use whenever the user wants to turn an approved spec into an executable plan — even for non-TDD work.
---

# Plan — Generate Detailed Implementation Plan

Generate an exhaustive implementation plan from an approved spec. The plan is so detailed that a Sonnet-tier agent can execute each task without design decisions.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

**Integration config load.** If `integrations.issue_tracker.enabled: true`, read the integrations charter skill for task naming and transition rules at the active charter root (resolved per `plugins/spec-flow/reference/charter-location.md`) — `<charter_root>/skills/charter-integrations/SKILL.md`, where `<charter_root>` is `.github` or `.claude`. Store as `integration_cfg`. If integration is disabled or the key is absent, set `integration_cfg = null` and skip all integration steps below.

> The plan skill does NOT create or transition any "plan" Jira item. The Epic (created by
> the spec skill) represents the piece. This skill creates per-phase Tasks at sign-off.

### TDD Preference Resolution

Read the `tdd` key from `.spec-flow.yaml` (valid values: `auto`, `true`, `false`; default `auto`).

- **`auto`** (default): Prompt the user before generating the plan: "Do you want to use TDD (test-first, Red/Build/Verify/Refactor) or Implement (straight code, Write-Tests/Verify/Refactor/QA) for this piece?" Record their answer in the plan front-matter as `tdd: true` or `tdd: false`.
- **`true`**: Generate all phases as TDD track (default behavior). Record `tdd: true` in plan front-matter.
- **`false`**: Generate all phases with non-TDD structure (`[Implement]` → `[Write-Tests]` → `[Verify]` → `[Refactor]` (optional) → `[QA]`). Record `tdd: false` in plan front-matter.

This preference is piece-level: the plan front-matter captures the decision, and the execute skill reads it to orchestrate correctly. Per-phase track overrides remain possible (a phase can always use `[Implement]` even when TDD is true).

### Fast Mode Preference

Read the `fast` key from `.spec-flow.yaml` (valid values: `true`, `false`; default `false`).

- **`false`** (default): Standard mode — per-phase QA agents run inline (`qa-tdd-red`, `qa-phase`, `qa-phase-lite`, verify agent dispatch). Record `fast: false` in plan front-matter.
- **`true`**: Fast mode — per-phase QA agents are skipped; a direct test-command shell invocation replaces the verify agent dispatch per phase; the end-of-piece Final Review board gains a 7th member (`verify Mode: Piece Full`) that compensates for all removed inline gates. Record `fast: true` in plan front-matter.

**When to use fast mode (`fast: true`):** removes per-phase QA agent dispatches and consolidates all test-quality review at end-of-piece. Saves ~60% of QA token cost (~$18.50 → ~$7 on a 10-phase piece). Appropriate when: the work is config, infra, scaffolding, or moderate-complexity behavior; the piece is ≤12 phases; and the operator accepts that theater tests and AC gaps are caught at the end rather than phase-by-phase.

**Not appropriate for:** security-critical features (auth, payments, cryptography), compliance work, or pieces with complex cross-phase behavioral dependencies where catching regressions early phase-by-phase is valuable.

Record the decision in plan front-matter as `fast: true` or `fast: false`. If the project-level `.spec-flow.yaml` sets `fast: true`, apply it to this piece unless the plan author explicitly overrides to `false` in the front-matter.

## Prerequisites

- Piece must have status `specced` in manifest at `docs/prds/<prd-slug>/manifest.yaml`
- `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` must exist and be approved
- Must be on the worktree branch `piece/<prd-slug>-<piece-slug>` (created by spec skill via `{{worktree_root}}/`)

- **No surviving `[PENDING-DECISION]` markers:** Scan `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` for any `[PENDING-DECISION` strings. When scanning, skip lines inside fenced code blocks (between opening ``` and closing ``` fences) and skip lines inside HTML comments (between `<!--` and `-->`). Only raw marker text in prose counts as a surviving marker. If any are found, refuse to proceed and list each surviving marker:

  ```
  Plan refused — spec.md contains N surviving [PENDING-DECISION] markers that must be resolved before planning:
    1. [PENDING-DECISION: <decision area>] — found at: <surrounding sentence>
    ...
  Resolve each marker by editing spec.md to replace the marker with the decided text, then re-run the plan skill.
  ```

  If no markers are found, this check is a silent no-op and Phase 1 continues.

## Workflow

### Phase 1: Read-Only Exploration

> Phase 1 includes a **dependency precondition check** (step 1a below) that runs the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list before exploration begins. This step runs BEFORE the charter-drift check.

**1a. Dependency precondition check (FR-5 of pi-010-discovery, AC-9).** Run the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list, read from the piece's manifest entry at `docs/prds/<prd-slug>/manifest.yaml`. For each ref, resolve per the reference doc's "Reference resolution" section (qualified `<dep-prd-slug>/<dep-piece-slug>` against `docs/prds/<dep-prd-slug>/manifest.yaml`; bare `<dep-piece-slug>` against the current PRD's manifest). On resolution failure, refuse with the exact resolution-failure refusal string from the reference doc — do NOT prompt for triage on a malformed/missing ref. On successful resolution, classify each dep's `status:` per the reference doc's "Status interpretation" section. If every resolved dep is `merged` or `done`, this step is a silent no-op (no prompt, no recorded state) and Phase 1 continues to the charter-drift check below (NN-C-005). If any resolved dep has a transient or structural-failure status, render the three-option triage prompt verbatim from the reference doc's "Triage options at spec/plan time" section (literal `(1) pull-deps-in`, `(2) fork`, `(3) proceed` markers; one bullet per unmet dep). Record the operator's choice and the per-dep status snapshot in orchestrator state keyed for Phase 2's plan.md authoring step to read. **Structural-failure statuses (`superseded`, `blocked`) refuse the `(3) proceed` option** — apply that rule symmetrically to the plan-time prompt per the reference doc. The plan-time triage may produce a different choice than spec-time triage (e.g., spec was authored with `proceed --ignore-deps`, but at plan time the operator now wants to `pull-deps-in`); the plan-time choice is recorded independently of any spec-time choice.

**Charter-drift check (always applies — runs after step 1a).** A piece reaching plan stage already has a spec carrying a `charter_snapshot:` front-matter. Before any other exploration, run the charter-drift check per `plugins/spec-flow/reference/charter-drift-check.md` against the spec's `charter_snapshot:` and the live charter skills at the active charter root (resolved per `plugins/spec-flow/reference/charter-location.md`) — `<charter_root>/skills/charter-*/SKILL.md`, where `<charter_root>` is `.github` or `.claude`. If drift is detected, halt Phase 1 and escalate per the reference doc — do not proceed with planning on stale charter constraints.

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
- **Charter skills** — resolve the active charter root per `plugins/spec-flow/reference/charter-location.md` (`<charter_root>` is `.github` or `.claude`). Read each charter skill file present from `<charter_root>/skills/charter-*/SKILL.md` (architecture, non-negotiables, tools, processes, flows, coding-rules, integrations). For `charter_snapshot`, capture last-commit date per domain via `git log -1 --format=%ci <charter_root>/skills/charter-<domain>/SKILL.md` — charter skills have no `last_updated:` front-matter.
  Charter content is exploration priors, same as code — it influences phase decomposition and the per-phase "Charter constraints honored" slots.
  - **If the `charter-integrations` skill exists** (`<charter_root>/skills/charter-integrations/SKILL.md`)**:** read it fully before authoring any phase that touches external services, APIs, SDKs, or third-party libraries. The naming conventions, status transition rules, hierarchy rules, and any additional notes sections define how integrations must be set up and managed. Every phase that creates, configures, or calls an external integration must be consistent with the principles in this file — treat it the same as non-negotiables for that scope.
- **Spec's `### Non-Negotiables Honored` and `### Coding Rules Honored` sections** — these enumerate the NN-C/NN-P/CR entries the piece claims it honors. The plan allocates each entry to the specific phase(s) that implement it via the per-phase "Charter constraints honored in this phase" slot.
- **Architectural decisions** — during Phase 1 exploration, record every significant architectural decision made. A decision is significant if it involves a choice between two or more approaches with non-trivial trade-offs, OR if it constrains future implementation options. Capture each as a draft ADR entry during exploration; these are finalized in Phase 2 step 11 below.

#### Exploration Deliverable: Code Introspection Report → `introspection.md`

Phase 1 writes exploration findings incrementally to `introspection.md` in the piece's working directory (alongside plan.md). The file is a working artifact — not committed, not gitignored, just untracked.

**Research-source branch.** Before running the per-cluster sweep, check whether `docs/prds/<prd-slug>/specs/<piece-slug>/research.md` exists on the piece branch (per `plugins/spec-flow/reference/research-artifact.md`, `## Location`):

**CONSUMED path (`research.md` exists on the piece branch):**

1. **Seed `introspection.md` by structural copy** of `research.md`'s cluster-grouped sections into `introspection.md`. Do not run the full per-cluster sweep below when `research.md` is present; the seed replaces it.
2. For each spec target file that is **not a covered file** (per the covered-file definition in `plugins/spec-flow/reference/research-artifact.md`), perform a **narrow targeted read** and append its four-block entry to `introspection.md`.
3. Resolve the research commit: `git log -1 --format=%H -- docs/prds/<prd-slug>/specs/<piece-slug>/research.md`; for each covered file changed since that commit (`git diff <commit>..HEAD -- <file>` non-empty), re-read it and update its `introspection.md` entry.
4. Define the counts: `N` = covered files; `M` = files processed in steps 2 + 3.
5. Emit `[RESEARCH-CONSUMED: <N> files, <M> re-read]`.

<!-- Example: spec targets = [a.md, b.md, c.md, d.md]. research.md File Inventory blocks cover
[a.md, b.md, c.md] (N=3). d.md is not covered → targeted read of d.md, append its four-block entry.
`git log -1 --format=%H -- docs/prds/<prd-slug>/specs/<piece-slug>/research.md` = e4f1a2c;
`git diff e4f1a2c..HEAD -- a.md` is non-empty (a.md changed since research) → re-read a.md, update its entry.
b.md, c.md unchanged → skipped. Re-reads = {d.md (top-up), a.md (staleness)} → M=2.
Emit: [RESEARCH-CONSUMED: 3 files, 2 re-read]. -->

**ABSENT path (`research.md` does not exist on the piece branch):**

1. Emit `[RESEARCH-ABSENT: running full exploration]`.
2. Run the existing per-cluster sweep (the "Cluster identification" + "Per-cluster exploration loop" below) unchanged.

On both paths, **Phase 2 then reads the resulting `introspection.md` section-by-section with no change to its reader.**

**Cluster identification.** Before exploring, group the spec's target files by functional cohesion (files that share callers, imports, or data types). Each cluster contains ≤ 5 files. If the spec touches ≤ 3 files total, treat the entire scope as a single cluster (no grouping overhead).

**Per-cluster exploration loop.** For each cluster, in dependency order (inner-most first):

1. **Explore** — read the cluster's files, resolve callers/callees, scan test coverage.
2. **Append** — write four sections to `introspection.md` under an H2 heading for the cluster:
   - **File Inventory:** per-file path, line count, key functions/classes with line ranges, and current code blocks (verbatim with line numbers) for all areas the spec requires modification
   - **Dependency Map:** per-file callers (file:line), callees (file:line), shared state, import chains relevant to the spec's scope
   - **Test Landscape:** existing test files, framework/assertion patterns, runner command, and coverage gaps relative to the spec's ACs
   - **Pattern Catalog:** naming conventions, error handling patterns, logging patterns — each with **verbatim code blocks** (3-10 lines) from the codebase, not just file:line pointers. These blocks are pasted into Phase 2's [Build]/[Implement] blocks as the executor's inline pattern reference.
3. **Release** — after appending, the orchestrator may release the cluster's raw file contents from context. The written sections in `introspection.md` carry the information forward.

**Resume.** On resume, check whether `introspection.md` exists. If it does, read it and skip clusters whose H2 headings already appear. This is cheap and always runs.

The Code Introspection Report is the Phase 2 author's primary input. Without it, Phase 2 produces abstract plans that force executor agents to re-explore the codebase.

**Edge cases:** For CREATE-only targets (no existing file to modify), the File Inventory entry documents the target path and intended structure outline instead of verbatim code. For projects with no existing test infrastructure, the Test Landscape notes "No existing tests — the plan's first phase must include test framework setup as an explicit [Implement] task."

### Phase 2: Generate Plan

Using the spec, `introspection.md` (reading section-by-section to manage context — load one cluster's sections at a time, draft its phases, then move to the next cluster), and the plan template at `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`:

1. Define phases — each phase is a testable unit of work:
   - Map each phase to specific acceptance criteria from the spec
   - Define a clear exit gate for each phase
   - Order phases by dependency (inside-out execution)

   **Integration-driven phase ordering.** When the spec's `## Integration Coverage` block declares one or more integrations (see `plugins/spec-flow/reference/spec-flow-doctrine.md` for definitions), apply the following ordering discipline:
   - Declare the outer `[integration]` test up front — at the time you author the phase that introduces the **last in-boundary component** (the completing phase). Do not defer it to a later cleanup phase.
   - Mark that phase with a `completes_in_phase: <phase-number>` annotation on the `[Integration-Test]` block so the execute skill and QA agents can locate the outer test without scanning all phases.
   - For each **doubled true external** in the integration's boundary, allocate a contract test named in that same `[Integration-Test]` block (one contract test per doubled external).
   - Phase ordering consequence: any in-boundary component that the outer integration test exercises must be introduced in an earlier phase than the completing phase — the completing phase is never Phase 1 unless the entire integration fits in one phase.

1a. **Verb alignment check** — extract the primary action verb from each spec AC and verify the covering plan phase PERFORMS that action. Action verbs to check: run, execute, validate, generate, create, modify, delete, deploy, test, migrate, configure, verify.

    A phase description must contain a concrete step that PERFORMS the verb — not documents, reviews, inspects, or scaffolds it.

    **Alignment failure patterns:**
    - AC "X runs and produces output" → phase `[Verify]` says "verify X is documented" ❌
    - AC "pipeline executes end-to-end" → phase `[Build]` says "pipeline structure is reviewed" ❌
    - AC "tests pass with N passing" → phase `[Verify]` says "test structure is valid" ❌

    **Correct alignment examples:**
    - AC "X runs and produces output" → phase `[Verify]`: `run X, expect output Y` ✓
    - AC "pipeline executes end-to-end" → phase `[Verify]`: `execute pipeline, confirm N stages complete` ✓
    - AC "tests pass with N passing" → phase `[Verify]`: `run pytest, expect N passed, 0 failed` ✓

    This check applies BEFORE the QA loop dispatch (Phase 3) and blocks plan finalization on misalignment. If a spec AC's verb cannot be matched to a plan phase's concrete step, the AC is NOT COVERED — update the AC Coverage Matrix accordingly.

2. For each phase, choose ONE track and generate its structure. A phase must have exactly one track marker — the executor branches on it mechanically.

   **TDD track** (default for behavior-bearing code):
   - **[TDD-Red]**: Exact test file paths, test names, assertions, patterns to follow
   - **[QA-Red]**: Theater-pattern review of Red's authored tests before Build (rejects tautology, mock-echo, truthy-only, no-assertion, name/body mismatch, implementation coupling, etc.); verifies adversarial AC binding
   - **[Build]**: Exact source file paths, class/function signatures, implementation approach
   - **[Verify]**: Exact shell command (copy-pasteable) with specific expected output values. **Verify command concreteness requirement:** every `[Verify]` block must contain at minimum: the exact command to run, expected output with specific values (numbers, strings), and a failure indicator (what bad output looks like). Template placeholders (`{{test_command}}`, `{{expected_output}}`) must be resolved before plan sign-off.

     ✓ `Run: pytest tests/auth/test_token.py -v — Expected: 3 passed, 0 failed`
     ✓ `Run: ruff check src/auth/ — Expected: exit code 0, no output`
     ✓ LLM-agent-step: `read src/config.yaml and confirm key "timeout" exists with value 30`
     ✗ `Run tests and verify they pass`
     ✗ `Confirm the implementation works correctly`
     ✗ `Run: {{test_command}} — Expected: all tests pass`
   - **[Refactor]**: Scope constraints (phase files only)
   - **[QA]**: ACs to review against, diff baseline

   **Implement track** (for config, infra, scaffolding, glue/wiring, docs-as-code, fixtures, migrations — where unit-level TDD is ceremony without payoff):
   - **[Implement]**: Exact file paths, signatures/structure, pattern pointers, architecture constraints the phase must honor. **When the phase modifies multiple files of the same class** (e.g., three playbooks that each require FQCN, a `when` guard, and a validation assert), list explicit per-file exit criteria — name each file and state what "done" means for it. A class-level description alone is insufficient; the implementer will finish the first file correctly and skip the constraint on the second.
   **Per-file specificity requirement:** Each `[Implement]` block must enumerate every file as a numbered Change Specification Block per step 3. Each change is self-contained — the executor can implement it without reading surrounding context or chasing pattern pointers.

   **Bad (insufficient):** `edit src/auth/token.py — add refresh logic`

   **Good (sufficient):**
   ```
   T-3: MODIFY src/auth/token.py
   Anchor: class TokenManager (lines 42-67)
   CURRENT:
    42  class TokenManager:
    43      def __init__(self, vault_client):
    44          self.vault_client = vault_client
    45      def validate_token(self, token: str) -> bool:
    46          ...
    67  # end of class
   TARGET: Add refresh_token() after validate_token (line 67).
   Must call self.vault_client.renew() and handle TokenExpiredError.
   Pattern (from src/auth/session.py:23-41):
    23  def renew_session(self):
    24      try:
    25          self.vault_client.renew()
    26      except TokenExpiredError:
    27          self._invalidate()
    28          raise
   Done: refresh_token() exists, calls vault_client, raises on failure.
   Verify: `grep -n "def refresh_token" src/auth/token.py` returns a match.
   ```
   - **[Verify]**: The verification command the plan author chooses (lint, type check, build, smoke run, integration test) and its expected output. For YAML/JSON validation in [Verify] blocks, default to LLM-agent-step framing per the plan template. External parsers (yq, jq, language interpreters) are not preconditions of this pipeline. **When the modified component is consumed by a wrapper or sibling component that has its own test suite** (e.g., an Ansible role consumed by a wrapper role with its own molecule suite), the `[Verify]` block must name ALL test suites that must pass — including those in wrapper/consumer components — not just the test suite of the directly modified component.
   **Verify command concreteness requirement:** every `[Verify]` block must contain the exact command to run with specific expected output (numbers, strings, exit codes), and a failure indicator. Template placeholders must be resolved before plan sign-off.

     ✓ `Run: molecule test -s default — Expected: PLAY RECAP with 0 failed, 0 unreachable`
     ✓ `Run: ansible-lint playbooks/ — Expected: exit code 0`
     ✓ LLM-agent-step: `read plugins/spec-flow/agents/qa-plan.md and confirm criterion 16 contains the string "verb alignment"`
     ✗ `Run the tests and confirm they pass`
     ✗ `Verify the implementation is correct`
     ✗ `Run: {{lint_command}} — Expected: no errors`
   - **[Refactor]** (optional): Include only if cleanup is plausibly needed
   - **[QA]**: ACs to review against, diff baseline

   Pick the track that matches reality. Don't force TDD onto a YAML file; don't skip TDD for a business rule.

   **`[Integration-Test]` block on TDD or Implement track.** An integration test is a real-path wiring verification — it is not inherently TDD or non-TDD. The completing phase may use either track:
   - **TDD-track completing phase:** the outer `[integration]` test is authored in the `[TDD-Red]` step alongside any unit tests for that phase; it is a failing test like any other Red test. The `[Integration-Test]` block documents it as the outer wiring test and carries the `completes_in_phase` marker.
   - **Implement-track completing phase:** the outer `[integration]` test is authored in a dedicated `[Integration-Test]` step (between `[Implement]` and `[Verify]`), which writes and immediately runs the test. The `[Verify]` block confirms the test passes.
   In both cases the `[Integration-Test]` block must declare its boundary (the set of components exercised end-to-end) and list any contract tests for doubled true externals.

   **Non-TDD mode override.** If the plan front-matter declares `tdd: false`:
   - Generate ALL phases with non-TDD structure: `[Implement]` → `[Write-Tests]` → `[Verify]` → `[Refactor]` (optional) → `[QA]`.
   - No `[TDD-Red]`, no `[QA-Red]`, no `[Build]` markers.
   - `[Implement]`: same structure as Implement track (exact file paths, signatures, patterns).
   - `[Write-Tests]`: write tests for what was implemented. No "fail first" requirement. No theater-pattern review. No SHA-256 manifest. Just write tests that verify the implementation is correct, with reasonable coverage of the phase's ACs.
   - Update the Overview section to state: "Non-TDD mode: all phases use Implement track + Write-Tests; AC Coverage Matrix is not required; QA and Final Review remain intact."

   **Non-TDD integration double-loop.** In `tdd: false` mode, the outer `[integration]` test for an integration is authored and greened within its completing phase's `[Write-Tests]`/`[Integration-Test]` step — there is no cross-phase Red step. The completing phase's step sequence is: `[Implement]` → `[Write-Tests]` (unit tests) → `[Integration-Test]` (outer integration test authored and run inline) → `[Verify]` (confirms both unit and integration tests pass). The `completes_in_phase` marker is still required on the `[Integration-Test]` block for the execute skill and QA agents.

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

2c. **Dense algorithm prose guard.** After drafting any `[Implement]` block that edits a paragraph in a `SKILL.md` file encoding a multi-step algorithm — a paragraph where ≥3 sequential steps are encoded in prose, recognizable by ordered-list steps, "then … then …" chains, or "normalize → split → match" notation — the plan MUST require in that same phase:
    1. An inline worked example immediately following the algorithm paragraph: a concrete input→output trace showing the full algorithm at a single representative input. The worked example may use a `<!-- Example: … -->` comment, a markdown code fence, or an inline parenthetical, but MUST show actual values (not `<input>` placeholders).
    2. A `[Verify]` assertion that confirms the worked example is present in the committed file.

    Without a concrete trace, each fix cycle on algorithm prose exposes adjacent latent ambiguity in the surrounding prose — as observed when the contract-injection paragraph in execute/SKILL.md required three sequential revision cycles (NM-1 → NM-B → NM-C) within a single piece.

2d. **Cross-phase schema-consistency oracle (FR-PROC-01, ADR-3).** When a plan declares ≥2 phases that each reference or mutate the same **schema-bearing file** — a file whose internal shape (field names, required keys, structural invariants) is established in one phase and consumed or enforced in another — insert a dedicated **cross-phase** consistency `[Verify]` step after the last schema-touching phase. That `[Verify]` step must:
    1. Name every overlapping schema-bearing file explicitly.
    2. State the invariants each file must satisfy (required keys present, field names match, structural constraints hold).
    3. Provide a concrete verification command (grep, diff, or LLM-agent-step) that confirms the schema consistency holds across all touching phases.

    **Rationale:** per-phase QA is scoped to one phase's file changes and cannot catch contradictions introduced by a later phase that silently redefines a field name or drops a required key. A cross-phase consistency `[Verify]` step makes the schema contract explicit and greppable, catching schema drift that per-phase review misses. Reference `plugins/spec-flow/reference/spec-flow-doctrine.md` for definitions — do not redefine schema terms here.

    **Example trigger:** Phase 2 defines a registry table with columns `path`, `boundary`, `completes_in_phase`; Phase 6 reads those columns. A cross-phase `[Verify]` step in Phase 6 (or a dedicated schema-check phase) should confirm: `grep -E "path.*boundary.*completes_in_phase" plan.md` returns the expected header row, proving the schema is consistent with what Phase 2 declared.

2e. **Superseded-ordinal anti-drift sweep (FR-PROC-03).** When a phase mutates a list-length or count invariant — for example, a board-member count, a numbered-step ordinal, or a "Nth member" reference that appears in prose or comments across multiple files — the anti-drift sweep for that phase MUST enumerate both the **superseded** (prior) ordinal/count strings and the new target pattern. Sweeping only the new target leaves prior-value references silently intact.

    **Required sweep form:** list the **superseded** count/ordinal strings (the values true prior to this phase) alongside the new target, and grep every in-scope file for each superseded token. Any hit on a superseded ordinal/count string in an in-scope file is a must-fix.

    **Example:** A phase changes a board from 7 to 8 members. The anti-drift `[Verify]` block must include:
    - Sweep for superseded count: `grep -rn "7th board member\|7 members\|board.*7" <in-scope files>` — Expected: 0 hits (no prior-count references remain).
    - Sweep for new target: `grep -rn "8th board member\|8 members" <in-scope files>` — Expected: the expected hit count.

    Without enumerating the superseded values, a drift sweep that finds only the new pattern cannot distinguish "already updated" from "never referenced" — it gives a false green on files that still carry the old ordinal.

2f. **Plan concreteness contract (FR-002).** Every phase deliverable must satisfy the per-phase concreteness floor, every genuine unknown must be an explicit `[SPIKE: <unknown>]` marker, and every doc-as-code conditional branch must be a numbered AC — all three defined authoritatively in `plugins/spec-flow/reference/plan-concreteness.md`. As you author each phase:
    1. **Concreteness floor.** Make each Change Specification Block name its target file, its location/anchor, and its concrete content/signatures (reference §1). Do not let a vague verb stand in for the content.
    2. **Mark unknowns.** Any decision you cannot resolve from spec + `research.md`/codebase is written as `[SPIKE: <unknown>]` (reference §2), never hedged in prose.
    3. **Enumerate branches.** For Implement-track / Non-TDD phases, every conditional branch in the deliverable (if/when/unless/otherwise/either, or an enumerated case) gets its own numbered AC (reference §3).
    Reference `plugins/spec-flow/reference/plan-concreteness.md` for all definitions — do not restate them here.

3. **Self-contained Change Specification Blocks.** Every file change inside a [Build]/[Implement] block must be a complete, self-contained specification the executor can implement without reading surrounding context or chasing pattern pointers. Use BOTH semantic anchors AND line ranges. Number each change sequentially within the phase (T-1, T-2, ...) to create a task inventory the executor iterates.

   **MODIFY operations — required fields:**
   (a) Task ID and file path: `T-N: MODIFY <file_path>`
   (b) Semantic anchor: function/class/method name
   (c) Line range from `introspection.md` (e.g. lines 42-67)
   (d) CURRENT state: verbatim code block (5-15 lines) with line numbers showing what exists today
   (e) TARGET state: concrete description of what to change — include function signatures, parameter types, return types, error handling expectations. Specific enough that the executor can write the code.
   (f) Pattern to follow: if the change should follow a pattern from elsewhere in the codebase, paste the **verbatim code block** (3-10 lines) from `introspection.md`'s Pattern Catalog inline — do NOT leave it as a pointer ("follow pattern from X:lines Y-Z")
   (g) Done criteria: what "done" means for this specific change (not for the phase)
   (h) Verify: how to verify this specific change succeeded (may be part of the phase [Verify] or a standalone check)

   **CREATE operations — required fields:**
   (a) Task ID and file path: `T-N: CREATE <file_path>`
   (b) Complete structure outline: sections, key classes/functions, imports, types
   (c) Pattern to follow: verbatim code block from a similar existing file
   (d) Done criteria and Verify

   **DELETE operations — required fields:**
   (a) Task ID and file path: `T-N: DELETE <file_path>`
   (b) Rationale: why this file is being removed
   (c) Impact check: what other files reference it (from Dependency Map)
   (d) Verify: confirm no remaining imports/references

   **Worked example (MODIFY):**
   ```
   T-3: MODIFY src/auth/token.py
   Anchor: class TokenManager (lines 42-67)
   CURRENT:
     42  class TokenManager:
     43      def __init__(self, vault_client):
     44          self.vault_client = vault_client
     45      def validate_token(self, token: str) -> bool:
     46          ...
     67  # end of class
   TARGET: Add refresh_token() method after validate_token (line 67).
   Must call self.vault_client.renew() and handle TokenExpiredError.
   Return the new token string on success.
   Pattern (from src/auth/session.py:23-41):
     23  def renew_session(self):
     24      try:
     25          self.vault_client.renew()
     26      except TokenExpiredError:
     27          self._invalidate()
     28          raise
   Done: refresh_token() exists, calls vault_client.renew(), raises TokenExpiredError on failure.
   Verify: `grep -n "def refresh_token" src/auth/token.py` returns a match.
   ```

   **Note:** Line ranges are from `introspection.md` exploration time — they may shift during execution. The semantic anchor is the primary locator; the line range prevents the executor from searching the entire file.
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

8. **Phase Groups for parallelizable work — parallel-by-default (v3.1.3+).** When a piece contains ≥2 units of work that touch disjoint file scopes and have no symbol dependencies on each other (classic examples: N independent adapters, N independent endpoints, per-table migrations), the **default authoring pattern** is a **Phase Group** with `[P]`-marked **Sub-Phases**. A serial chain of flat phases for the same disjoint work is a deviation from default and requires explicit justification (see `Why serial:` below). Rationale: the executor only dispatches what the plan declares as parallel — flat phases run sequentially regardless of how disjoint their scopes are. Defaulting to Phase Groups when work is genuinely disjoint moves wall-clock time off the table by the fan-out factor.

   **`Why serial:` escape hatch.** When the plan author has a deliberate reason to keep parallelizable work as serial flat phases — preserving per-phase Opus QA for regulatory/audit reasons, anticipating later coupling, sequencing for review-board readability, etc. — declare the rationale via a single-line preamble on at least one of the affected phases:
   ```markdown
   ### Phase 3: <name>
   Why serial: phase 4 imports types defined here; cannot parallelize until <future piece> extracts the shared types.
   ...
   ```
   One `Why serial:` line covers the chain it heads. Multiple distinct reasons → multiple lines on the affected phases. The qa-plan agent reads this line as the "I considered parallel and chose serial deliberately" signal; absence of the line on a flat-phase plan with disjoint scopes is a should-fix finding (criterion 11).


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

9. **AC Coverage Matrix generation (FR-PLAN-001 / FR-PLAN-002).** After all phases are drafted, generate the `## AC Coverage Matrix` section. Steps:

   1. Extract every AC from the spec in AC-ID order (AC-1, AC-2, ...). Parse by scanning **only the `### Acceptance Criteria` section** (or `## Acceptance Criteria` if the spec uses an H2 heading) of spec.md for lines matching the pattern `AC-N:` or `**AC-N**`. Do not scan the full spec document — prose references to ACs in other sections are not definitions.
   2. For each AC, scan every phase's `**ACs Covered:**` field and sub-phase `**ACs:**` field in the plan. Build a mapping: `AC-N → [Phase M, Phase P, ...]`.
   3. Determine status per AC:
      - `COVERED` — appears in at least one phase's ACs Covered/ACs field.
      - `NOT COVERED` — not referenced by any phase.
   4. Render the section as a markdown table:

      ```markdown
      ## AC Coverage Matrix

      | AC ID | Summary | Status | Covered By |
      |-------|---------|--------|------------|
      | AC-1  | <one-line summary from spec> | COVERED | Phase 1 |
      | AC-3  | <one-line summary> | NOT COVERED | — Forward pointer: `<future-piece-slug>` or `<explicit justification>` |
      ```

      The summary column is a one-line extract from the spec's AC text (truncate at 80 chars).

   5. **NOT COVERED prompt (FR-PLAN-002).** For each NOT COVERED row, the plan skill must prompt the user before finalizing:

      ```
      AC-N (<summary>) is NOT COVERED by any phase in this plan. What should we do?
      ```

      Choices:
      - "Defer to future piece: `<piece-slug>`" — record the piece slug as the forward pointer in the NOT COVERED row.
      - "Add coverage to Phase M" — update Phase M's `ACs Covered` field and re-run the matrix.
      - "Explicit justification" — enter free-form text as the forward pointer (e.g., "out of scope by spec decision — see Out of Scope section").

      Do not finalize plan.md until all NOT COVERED rows have a forward pointer.

      If the user provides an empty or unrecognised answer, re-prompt once with: "Please choose: (1) Defer to future piece — provide slug, (2) Add coverage to Phase M — provide phase, or (3) Explicit justification — provide text. An empty answer is not valid." If the second response is also empty, unrecognised, or the session is interrupted, abort plan generation with: "Plan generation halted — all NOT COVERED ACs require a forward-pointer decision before plan.md can be finalized." Do not write a partial plan.md.

   6. Place `## AC Coverage Matrix` after the last phase (or Phase Group) and before `## Parallel Execution Notes` in plan.md.

9a. **Executable AC Binding table (FR-6 of plan-mode-overhaul).** After the AC Coverage Matrix, generate an `## Executable AC Binding` section that maps every COVERED AC to its exact verification. This table is the contract between plan and execute — if a phase cannot fill in the "Command/Check" column with something concrete, the phase's `[Verify]` block is not specific enough.

    ```markdown
    ## Executable AC Binding

    | AC ID | Verification Type | Command/Check | Expected Result |
    |-------|------------------|---------------|-----------------|
    | AC-1  | shell | `pytest tests/auth/ -v` | 3 passed, 0 failed |
    | AC-2  | agent-step | LLM-agent-step: read `src/config.yaml` and confirm key "timeout" is 30 | Key exists with value 30 |
    | AC-3  | agent-step | LLM-agent-step: read `plugins/spec-flow/agents/qa-plan.md` lines 70-90 and confirm criterion 16 exists | Criterion 16 present with verb list |
    ```

    Verification Type values:
    - `shell` — exact shell command, copy-pasteable
    - `file-check` — assert file exists, contains specific string, or has specific structure
    - `agent-step` — LLM-agent reads a file and confirms specific content

9b. **Phase boundary declarations (FR-7 of plan-mode-overhaul).** Each phase must declare explicit scope boundaries to prevent executor scope creep. The execute skill's discovery protocol applies when a sub-agent discovers work not listed in "In scope."

    Each phase must include in its header block:
    - **`In scope:`** explicit list of what this phase does (file changes, behaviors added)
    - **`NOT in scope:`** explicit list of what this phase does NOT do, with forward references to the phase that covers it (e.g., "NOT in scope: qa-plan.md changes — covered by Phase 2")

    The file list with change types (CREATE/MODIFY/DELETE) is captured in the `**File changes:**` table inside each `[Build]`/`[Implement]` block and does not need to be duplicated in the header.

    An executor discovering that implementing a spec AC requires changes to files NOT listed in "In scope" must escalate via the discovery protocol (Step 6c of execute) rather than silently expanding scope.

9c. **P2/P3 cross-step authoring discipline (pi-021).** When a phase edits a *multi-step orchestration file*, the plan author must reason about the steps the change traverses and the agent-dispatch sites it touches, and record that reasoning in the phase header. This defends against changes that introduce a new path through an existing loop/state-machine, or alter an agent-dispatch contract, without accounting for every pre-existing step/site the change interacts with.

    - **Definition (multi-step orchestration file):** a `skills/*/SKILL.md` is a *multi-step orchestration file* if it contains ≥3 headings matching `^#{3,4} (Step|Phase|Sub-Phase)\b`.
    - **P2 (steps traversed):** a phase introducing a new conditional path through an existing multi-step loop/state-machine must enumerate, in a `**Steps traversed (P2):**` header field, every pre-existing step the new path traverses or invalidates.
    - **P3 (dispatch sites):** a piece changing a cross-cutting agent-dispatch contract must enumerate, in a `**Dispatch sites (P3):**` header field, every (re-)dispatch site of the affected agents; if none, state "none."
    - Both header fields are REQUIRED only when the edited file is a multi-step orchestration file (per the Definition above); otherwise they may be omitted.

9d. **Doc-as-code branch-enumeration ACs (FR-002c).** For each Implement-track / Non-TDD phase, before finalizing the AC Coverage Matrix, scan the phase's deliverable prose for conditional branches (if/when/unless/otherwise/either, or an enumerated case) and confirm each has a matching numbered AC. See §3 of `plugins/spec-flow/reference/plan-concreteness.md`. A conditional branch with no covering AC is a concreteness defect the author must fix before the Phase 3 QA dispatch.

10. **Contracts section generation (FR-PLAN-004 / FR-PLAN-005 / FR-PLAN-006 / FR-PLAN-007).** After all phases are drafted, generate the `## Contracts` section. Steps:

    1. Scan every `[TDD-Red]` (or `[Build]`) block in the plan for boundary-crossing interfaces. A boundary-crossing interface is one consumed by code *outside* the defining phase — public API endpoints, exported functions, shared data schemas, event contracts. Internal helpers and private functions are not contracts.

    2. For each identified boundary-crossing interface, define a contract entry:

       ```markdown
       ### C-N: <interface name>
       - **ID:** C-N
       - **Type:** Function | API Endpoint | Event Schema | Data Schema
       - **Phase:** Phase M (or Sub-Phase X.Y)
       - **Signature:** `<function/endpoint signature with types>`
       - **Inputs:** `<param>: <type>` — <description>; (repeat per input)
       - **Outputs:** `<return type>` — <description>
       - **Error cases:** `<error condition>` → `<behavior/exception>`; (repeat)
       - **Constraints:** <any invariants, preconditions, postconditions>
       ```

    3. **TDD phases with no boundary-crossing interfaces (AC-11).** If a TDD-track phase's [TDD-Red] block has no boundary-crossing interfaces, document the omission explicitly:

       ```markdown
       ### Phase M — no boundary-crossing interfaces
       Omission rationale: <e.g., "Phase M refactors internal helpers only; no exported symbols">
       ```

    4. **Non-TDD / Implement-only pieces (AC-13a compatibility).** If the plan has no TDD-track phases at all, include:

       ```markdown
       ## Contracts

       No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs.
       ```

    5. **Reference contract IDs in [TDD-Red] blocks (AC-12).** After the Contracts section is written, go back and add a contract reference line to each [TDD-Red] block that has a corresponding contract. Append to the [TDD-Red] block: `Contract references: C-N (and C-M if applicable). Write tests against these contract signatures.`

    6. Place `## Contracts` immediately after `## Executable AC Binding` in plan.md (which itself follows `## AC Coverage Matrix`).

    **Contracts-vs-integration-boundary distinction (ADR-3).** The `## Contracts` section and the `[Integration-Test]` block are related but distinct concepts — do not conflate them:
    - **`## Contracts`** captures **boundary-crossing API interfaces**: exported function signatures, shared data schemas, event contracts, and API endpoint shapes that code *outside* the defining phase consumes. A contract is a surface — it describes *what* components expose to each other.
    - **Integration boundary** (as defined in `plugins/spec-flow/reference/spec-flow-doctrine.md`) is the **real wired path** that an `[integration]` test exercises end-to-end. A boundary is a scope — it describes *which* components are exercised together by the outer test.
    - A phase may have: a contract but no integration boundary (exports an interface, but no integration test covers it); an integration boundary but no contract (the wired path exercises internal components only); both; or neither. All four combinations are valid.
    - When authoring a completing phase, do not add contracts for internal helpers just because they participate in an integration boundary. Only boundary-crossing interfaces — those consumed by code outside the defining phase — belong in `## Contracts`.

11. **Architectural Decisions section generation (FR-PLAN-008 / FR-PLAN-009 / FR-PLAN-010).** Generate the `## Architectural Decisions` section using ADR format. Steps:

    1. Collect all draft ADR entries recorded during Phase 1 exploration.
    2. For each decision, render an ADR entry:

       ```markdown
       ### ADR-N: <decision title>
       **Context:** <why this decision was needed — what forces are at play>
       **Decision:** <what was decided, stated precisely>
       **Alternatives considered:** <at least two alternatives with one-line rationale each>
       **Consequences:** <what becomes easier, harder, or irreversible as a result>
       **Charter alignment:** <which NN-C/NN-P/CR entries this decision honors or constrains>
       ```

    3. **No-decisions fallback (AC-15).** If no significant architectural decisions were made during Phase 1, include:

       ```markdown
       ## Architectural Decisions

       No significant architectural decisions for this piece.
       ```

       The section is always present — never omit it.

    4. Place `## Architectural Decisions` before `## Phases` (near the top of the plan, after `## Overview`).

Write the plan to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/plan.md`. Populate the `charter_snapshot:` front-matter with charter dates captured during Phase 1 exploration: `git log` last-commit date per domain (charter skills carry no `last_updated:` front-matter). Populate each phase's "Charter constraints honored in this phase" slot with the subset of NN-C/NN-P/CR entries from the spec that the phase implements (every entry must appear in exactly one phase — no drops, no duplicates).

**`## Dependency Triage` section (FR-6 of pi-010-discovery, AC-9).** Read the dependency-triage choice recorded by Phase 1 step 1a from orchestrator state and branch as follows (per the `## Dependency Triage` section format in `plugins/spec-flow/reference/depends-on-precondition.md`). The plan-time choice is recorded independently of any spec-time choice already present in spec.md — operators may revise their triage between spec and plan stages.

- **No unmet deps recorded** (every dep was already `merged`/`done` at the time of step 1a, or the piece had no `depends_on:` entries): write plan.md normally with no `## Dependency Triage` section. The section is required only when at least one dep was unmet at the moment of authoring.
- **Operator chose `(1) pull-deps-in`:** write plan.md and append a `## Dependency Triage` section using the format from the reference doc — one bullet per unmet dep, each rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator chose pull-deps-in; Phase 0 will re-implement / verify.`` (or the spec-coverage variant per the reference doc's "Resolution values" list, depending on whether the absorption is documented as a Phase 0 in the plan body or was already covered in spec.md). The plan must insert a Phase 0 (or earlier phases) that re-implements / verifies the prerequisite before the piece's own work begins — the unmet-dep entry should only be removed from `depends_on:` once the prerequisite is actually covered in this plan.
- **Operator chose `(2) fork`:** halt the skill immediately with the exact refusal string `Refused — fork chosen; plan the prerequisite piece <ref> first.` (substituting each unmet dep's `<ref>` if more than one is unmet, one refusal line per dep). Write NO plan.md, create NO commits, do not advance to Phase 3. The operator's next action is to switch to the prerequisite piece and run `/spec-flow:plan` on it.
- **Operator chose `(3) proceed --ignore-deps`:** write plan.md and append a `## Dependency Triage` section with one bullet per unmet dep rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator override; deps remain unmet at plan time.`` Recall that `(3) proceed` is refused for structural-failure statuses (`superseded`, `blocked`) at step 1a — if execution reaches this branch, every unmet dep is in a transient-status class.

**Worktree/branch naming** (per FR-004 / FR-005): the plan skill operates on the worktree at `{{worktree_root}}/` on branch `piece/<prd-slug>-<piece-slug>` (created by the spec skill). Slug validity for both `<prd-slug>` and `<piece-slug>` is enforced by `plugins/spec-flow/reference/slug-validator.md` before any worktree or branch is created — cite, don't restate.

### Phase 3: QA Loop

Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).

1. Read template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-plan.md`

2. **Iteration 1 (full review):** Dispatch QA agent (Opus) with `Input Mode: Full`, the full plan, spec, PRD sections, and charter skills (all seven if present — architecture, non-negotiables, tools, processes, flows, coding-rules, integrations — at the active charter root resolved per `plugins/spec-flow/reference/charter-location.md`: `<charter_root>/skills/charter-*/SKILL.md`, where `<charter_root>` is `.github` or `.claude`). The QA agent cross-checks that every NN-C/NN-P/CR cited in the spec appears in exactly one phase's "Charter constraints honored" slot, with no drops and no duplicates.
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

**Finalize spike-scan (FR-002e).** Before the commits below, scan plan.md for any surviving `[SPIKE:` marker in prose. When scanning, skip lines inside fenced code blocks (between opening ``` and closing ``` fences) and skip lines inside HTML comments (between `<!--` and `-->`). For multi-line HTML comments (where `<!--` and `-->` appear on different lines), skip every line between and including the opening and closing lines. HTML-comment exclusion takes precedence: a triple-backtick encountered while inside an HTML comment does not open a fenced code block. Only raw marker text in prose counts. If any survive, REFUSE to finalize and list each offending phase:

    Plan finalize refused — N surviving [SPIKE:] marker(s) must be resolved before the plan is approved:
      1. [SPIKE: <description>] — found in Phase <N>: <surrounding sentence>
      ...
    Resolve each marker by either: (a) replacing it with concrete content if the unknown is now
    resolved, or (b) awaiting FR-005 spike-agent resolution, which will issue a plan amendment.

This finalize-block is **interim** per `plugins/spec-flow/reference/plan-concreteness.md` §4: once FR-005 (`spike-agent`) lands, a `[SPIKE]` is resolved by an Opus spike agent emitting a Step 6c plan amendment and this hard block is relaxed. If no markers survive in prose, this scan is a silent no-op and finalize proceeds.

<!-- Worked example: plan.md carries `[SPIKE: real throughput ceiling]` in Phase 3's deliverable sentence (prose) and a second `[SPIKE: x]` inside a ``` fence demonstrating the syntax. Scan result: 1 surviving marker (the prose one) → refuse, listing Phase 3 only; the fenced occurrence is skipped. A marker appearing only inside `<!-- ... -->` is likewise skipped → finalize proceeds. -->

2. Ensure the plan's front-matter includes `tdd: true` or `tdd: false` recording the mode decision for this piece (set during TDD Preference Resolution above; if missing, infer from phase structure: any `[TDD-Red]` → `true`, all `[Implement]` → `false`). Also ensure `fast: true` or `fast: false` is present (default: `fast: false` if absent).
3. **Integration — create per-phase issues (if `integration_cfg != null` and `auto_create_tasks: true`):**
   Run the capability check for operation `create_phase_issue`. If available:
   - From `integration_cfg.hierarchy`, find the entry with `managed_by: plan` → this is the phase level (`phase_level`).
     Let `parent_level` = the entry immediately above it (the `managed_by: spec` entry).
   - Read the parent key: from `parent_level`, resolve `artifact` (e.g. `spec`) and `key_field` (e.g. `jira_key`).
     Read that field from spec.md front-matter. If absent → emit warning and skip issue creation.
   - For each resolved phase (flat phase or sub-phase) in the plan, create an issue of type
     `phase_level.type` in project `integration_cfg.project_key` using the naming convention
     from `phase_level.naming` or the default
     (default: `[phase] {piece-slug}/{phase-number} — {phase-name}`).
     Pass `additional_fields: {"parent": "<parent_key_value>"}` to link each phase issue
     to the piece issue.
   - Apply Task Creation Defaults from `charter-integrations` (the active charter root, resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-integrations/SKILL.md`, where `<charter_root>` is `.github` or `.claude`).
     All Jira calls use MCP tools only (`jira_create_issue`, `jira_update_issue`, `jira_transition_issue`).
     - **Story points:** estimate phase effort in days, compute `ceil(days × 0.5)` (rounded up to next Fibonacci number) per `charter-integrations`.
       Read `story_points_field` from `phase_level` (the `managed_by: plan` hierarchy entry in `integration_cfg`).
       If present, pass `additional_fields: {"<story_points_field>": <computed-value>}` on `jira_create_issue`.
       If absent from config, skip silently.
     - **Assignee:** call `jira_get_user_profile` with `user_identifier: "me"` once before the
       issue creation loop — the MCP server resolves this to the authenticated user’s `accountId`.
       Pass that `accountId` as `assignee` on every `jira_create_issue` call in the batch.
     - **Initial status:** create in `To Do`; after all phase issues are created, move every
       issue that is NOT phase 1 to `Backlog` (phase 1 stays `To Do` as the first to execute).
   - Record each returned issue key inline in plan.md as `<phase_level.key_field>:` (i.e. `jira_key:`)
     immediately after the phase heading, plus a `jira_url:` line. Example:
     ```
     ### Phase 1: Auth Token Model
     jira_key: EIT-42
     jira_url: https://se-ivan.atlassian.net/browse/EIT-42
     ```
     Construct `jira_url` as `<integration_cfg.base_url>/browse/<issue-key>`.
   On tool unavailable → emit warning → skip.
4. Update manifest on the piece branch (the current working branch — no checkout needed):
   ```bash
   # update manifest.yaml status for this piece in its PRD-local manifest
   git add <docs_root>/prds/<prd-slug>/manifest.yaml
   git commit -m "manifest: mark <prd-slug>/<piece-slug> as planned"
   ```
   > **Branch ownership:** The manifest update stays on `piece/<prd-slug>-<piece-slug>`.
   > Main's manifest advances when this branch is merged or a PR is opened.
5. Commit plan on worktree branch:
   ```bash
   git add <docs_root>/prds/<prd-slug>/specs/<piece-slug>/plan.md
   git commit -m "plan: add <prd-slug>/<piece-slug> implementation plan"
   ```
