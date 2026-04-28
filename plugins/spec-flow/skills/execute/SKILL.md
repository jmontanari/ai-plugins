---
name: execute
description: Use when a plan is approved and ready for implementation. Orchestrates each phase via a single implementer agent that runs in TDD mode or Implement mode based on the plan's track (config/infra/glue code uses Implement mode, behavior-bearing code uses TDD), runs QA gates between phases, and triggers a 5-agent final review before merging. The main window writes zero implementation code. Use this whenever the user wants to execute, implement, or run a spec-flow plan — regardless of whether the plan uses TDD or not.
---

# Execute — Orchestrate Plan Implementation

Execute an approved plan phase by phase using dedicated agents for each step. Each phase runs in Mode: TDD or Mode: Implement based on the plan's chosen track, with QA gates at every boundary and a 5-agent final review before merge.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- Piece must have status `planned` in manifest at `docs/prds/<prd-slug>/manifest.yaml`
- `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` must exist and be approved
- Must be on the worktree branch `execute/<prd-slug>-<piece-slug>` at `{{worktree_root}}/` (resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>/` at dispatch time — see `plugins/spec-flow/reference/v3-path-conventions.md`). Slug validity for both `<prd-slug>` and `<piece-slug>` is enforced by `plugins/spec-flow/reference/slug-validator.md` before any worktree or branch is created — cite, don't restate.
- All manifest dependencies for this piece must have `status: merged` or `status: done` (per the spec's piece-status state machine). The `depends_on:` precondition in Phase 1 (below) enforces this before any phase dispatch. The `--ignore-deps` flag (FR-021) bypasses this precondition only; it does NOT bypass per-phase QA or end-of-piece review-board (NN-P-002).

## API encapsulation — this skill is the sole entrypoint for internal agents

`spec-flow:execute` is the only supported way to dispatch phase-level and end-of-piece agents (`implementer`, `tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`, `reflection-process-retro`, `reflection-future-opportunities`). Those agents assume orchestrator-injected context (Mode flag, pre-flight snapshot, oracle anchors, AC matrix, session metrics for reflection agents) and have Rule 0 first-turn reject checks that BLOCK when called directly. Do not dispatch them from outside this skill. If a task appears to need direct agent invocation, route through a spec + plan + execute cycle instead — the extra structure exists to prevent the class of contamination bugs where agents run with broken invariants.

## The Orchestrator Role

You (the main window) are a PURE CONDUCTOR. You:
- Read the plan and construct agent prompts
- Gather read-only pre-flight facts (LOC, schema samples, symbol presence, hook inventory) to avoid pushing cheap discovery work into agents — see Step 1b
- Resolve plan conditionals the orchestrator can evaluate (LOC- and filesystem-based) into binding pre-decisions before dispatch
- Dispatch agents via the Agent tool
- Run verification commands (test suite, type checker, linter)
- Evaluate agent reports and QA findings
- Decide: proceed / retry / escalate
- Track progress via BOTH plan.md checkboxes AND a harness task list (`TaskCreate` once at start, `TaskUpdate` per phase) — see "Pre-Loop: Build Task List" below. Both are required; neither alone is sufficient.

You write ZERO implementation code. Fact-gathering probes (`wc`, `head`, `git grep`, reading `.pre-commit-config.yaml`) are explicitly part of the conductor role — they are cheap reads that collapse 5–15 agent tool calls per dispatch. Synthesis and code-writing still come from subagents.

## Pre-Loop: Mark Piece as In-Progress

Before the first phase runs (and only on a fresh start, not a resume), update the PRD's manifest on `main` to mark this piece's status as `in-progress` (per the spec's piece-status state machine). Skip if it's already `in-progress` (resumed session).

```bash
git checkout main
# update docs/prds/<prd-slug>/manifest.yaml: set this piece's status to "in-progress"
git add docs/prds/<prd-slug>/manifest.yaml
git commit -m "manifest: mark <prd-slug>/<piece-slug> as in-progress"
git checkout execute/<prd-slug>-<piece-slug>
```

This makes `status` report an accurate picture — a piece is `in-progress` while execute is in progress, and flips to `merged` (or the `done` alias) after the final merge.

## Phase 1: Load Context + Charter Drift + Dependency Preconditions

Before the Phase Scheduler dispatches any phase, execute resolves `<prd-slug>` and `<piece-slug>` (from the user argument or by scanning `docs/prds/*/manifest.yaml` for the named piece), loads the plan at `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` and spec at `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`, then runs the four gates below in order.

### 1a. Charter-drift check (always applies — runs first)

A piece reaching execute stage already has a spec carrying a `charter_snapshot:` front-matter and a plan aligned to that snapshot. Before any phase dispatch, run the charter-drift check per `plugins/spec-flow/reference/charter-drift-check.md` against the spec's `charter_snapshot:` and the live `<docs_root>/charter/` files. If drift is detected, halt Phase 1 and escalate per the reference doc — do not dispatch phases against stale charter constraints.

### 1b. Path resolution

All paths below resolve against `plugins/spec-flow/reference/v3-path-conventions.md`. In particular:

- Manifest: `docs/prds/<prd-slug>/manifest.yaml`
- Spec / plan: `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` and `plan.md`
- Worktree: `{{worktree_root}}/` (resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>/` — see `plugins/spec-flow/reference/v3-path-conventions.md`)
- Branch: `execute/<prd-slug>-<piece-slug>`
- Reflection targets (consumed in Final Review Step 4.5): `docs/improvement-backlog.md` for process-retro, `docs/prds/<prd-slug>/backlog.md` for future-opportunities. Execute dispatches with the correct PRD slug context; the reflection agents themselves own the writes.

Slug validity for both `<prd-slug>` and `<piece-slug>` is enforced by `plugins/spec-flow/reference/slug-validator.md` before any worktree or branch is created — cite, don't restate.

### 1c. `depends_on:` precondition (FR-011, AC-11)

After the manifest has been loaded and before any phase is dispatched, check the current piece's dependency declarations:

1. Read the current piece's `depends_on:` list from its entry in `docs/prds/<prd-slug>/manifest.yaml`.
2. For each entry, resolve it to a target piece:
   - **Qualified ref** `<dep-prd-slug>/<dep-piece-slug>` — look up the entry in `docs/prds/<dep-prd-slug>/manifest.yaml`.
   - **Bare ref** `<dep-piece-slug>` — resolve against the current PRD's manifest (i.e. `docs/prds/<prd-slug>/manifest.yaml`).
3. For each resolved dependency, read its `status:` field. Per the spec's piece-status state machine, only `merged` or `done` (the backward-compatible alias) permit a downstream piece to start `execute`. All other statuses — `open`, `specced`, `planned`, `in-progress`, `superseded`, `blocked` — fail the precondition.
4. If any dependency's status is not `merged` and not `done`, refuse to start. Print a blocking-deps list naming each unsatisfied dependency and its current status verbatim, then exit. Example:

   ```
   REFUSED — unmet depends_on preconditions:
     - auth/login-flow   status: planned   (needs: merged or done)
     - billing/invoices  status: blocked   (needs: merged or done)
   Re-run once these dependencies are merged, or pass --ignore-deps to proceed anyway (see FR-021).
   ```

5. **NN-P-002 preservation:** this precondition is a BLOCKER ONLY. It never bypasses the per-phase QA gate (Step 6) or the end-of-piece review-board sign-off (Final Review Step 4). Both human gates remain mandatory regardless of dependency state — `depends_on:` and `--ignore-deps` do NOT bypass per-phase QA or review-board.

### 1d. `--ignore-deps` flag (FR-021)

When invoked as `/spec-flow:execute <piece> --ignore-deps`, execute skips the refusal in 1c but does NOT skip the check itself — the list of unmet dependencies is still computed and surfaced loudly before any phase dispatches. Per NN-C-006's "explicit confirmation" posture for deliberate deviations, print a multi-line yellow warning (≥ 5 lines, bracketed by separator characters) naming each ignored dependency and its current status. Example format:

```
════════════════════════════════════════════════════════════════════
WARNING — --ignore-deps active. The following depends_on preconditions
are UNMET but will be bypassed for this execute run (FR-021, NN-C-006):
  - auth/login-flow   status: planned   (expected: merged or done)
  - billing/invoices  status: blocked   (expected: merged or done)
Proceeding anyway at the operator's explicit request. Cross-piece
integration issues introduced by running against unmerged dependencies
are the operator's responsibility to triage.
════════════════════════════════════════════════════════════════════
```

The flag bypasses the 1c precondition only. It does NOT bypass per-phase QA (Step 6) or end-of-piece review-board (Final Review Step 4) — those two human sign-off gates remain mandatory per NN-P-002. The flag also does not bypass the charter-drift check (1a), the AC matrix gate (Step 3 item 8), the post-commit integrity gates (Step 3 item 7), or any other gate described elsewhere in this skill.

**Structural-failure deps refuse even with `--ignore-deps`.** Two dependency statuses signal *structural* failure rather than transient blocking:
- `superseded` — the dep was abandoned and replaced by another piece. It will never reach `merged`. Running against a superseded dep almost always indicates the operator is looking at a stale `depends_on:` entry that should be rewritten or removed.
- `blocked` — the dep has external blockers preventing progress. Running against a blocked dep risks compounding the blocker downstream.

For both statuses, refuse even when `--ignore-deps` is passed, with: `dep <ref> status: <superseded|blocked> — --ignore-deps does not apply to structural-failure statuses; update depends_on or unblock the dependency before re-running.` The transient statuses (`open`, `specced`, `planned`, `in-progress`) ARE bypassable via `--ignore-deps`; structural failures are not.

**Refusal contract for malformed/missing depends_on refs.** If any entry in `depends_on:` cannot be resolved, refuse before reaching the status check:
- Malformed qualified ref (e.g. `auth/`, `/login`, `auth//login`) → `malformed depends_on ref '<ref>' — expected <prd-slug>/<piece-slug> or bare <piece-slug>. Fix the manifest entry.`
- Qualified ref names a PRD that doesn't exist → `unmet depends_on — PRD '<prd-slug>' not found at docs/prds/<prd-slug>/. Check spelling.`
- Qualified or bare ref names a piece that isn't in the resolved manifest → `unmet depends_on — '<ref>' does not resolve to any known piece. Check spelling.`
- Self-reference (the current piece's own slug appears in its own `depends_on:`) → `self-referential depends_on — '<ref>' is the piece you're trying to execute. Remove the entry.`

These refusals fire BEFORE the status-based 1c check and are NOT bypassable via `--ignore-deps`.

## Phase Scheduler — detection

The orchestrator begins each piece by scanning plan.md for Phase Group headings (`## Phase Group <letter>:`). For each top-level unit in plan.md, determine whether it is a flat phase or a phase group:

- **Flat phase** (current model) — starts with `### Phase <N>` — run through the Per-Phase Loop below (Steps 1–7).
- **Phase Group** — starts with `## Phase Group <letter>:` and contains ≥2 `#### Sub-Phase <letter>.<n>` subheadings — run through the Phase Group Loop (below the Per-Phase Loop).

Read the `phase_groups` key from `.spec-flow.yaml` (valid values: `auto`, `always`, `off`; default `auto`):

- `auto` — recognize Phase Groups from plan headings; fall back to flat phase handling when the plan uses `### Phase <N>`.
- `always` — recognize Phase Groups and error if the plan has only flat phases when the piece has multiple obviously-parallelizable files. Used to catch over-flat plans during v1.4.0 rollout.
- `off` — treat every top-level unit as a flat phase, ignoring Phase Group headings. Escape hatch for rollback or for plans authored before v1.4.0.

Scope validation before dispatching any sub-phases in a group: parse each sub-phase's `**Scope:**` declaration (literal file paths only, no globs) and check for pairwise overlap. If two sibling sub-phases declare overlapping files, fall back to serial execution for that group (each sub-phase runs as a flat phase in declaration order) and log a warning naming the overlap.

## Pre-Loop: Build Task List

> **Platform note:** `TaskCreate`, `TaskUpdate`, and `TaskList` are Claude Code MCP tools. In Copilot CLI they are unavailable — use the built-in `sql` tool instead: `INSERT INTO todos (id, title, status) VALUES (...)` to create, `UPDATE todos SET status = '...' WHERE id = '...'` to update, `SELECT * FROM todos` to list.

Before the Per-Phase Loop dispatches anything, build a complete harness task list mirroring plan.md's structure. Using the unit list the Phase Scheduler resolved above, call `TaskCreate` once per dispatch unit, in plan order, all marked `pending`. A "dispatch unit" is:

- Each `### Phase <N>` (flat phase) → one task.
- Each `#### Sub-Phase <letter>.<n>` inside a `## Phase Group` → one task. The group heading itself does NOT get a task; the sub-phases ARE the dispatched units.

This rule is binding. Do NOT create tasks lazily one phase at a time, do NOT create only the first task, and do NOT skip the task list when a piece has only one phase. A complete list up front makes the work visible to the user, the run resumable, and interruption recovery unambiguous.

Suggested task title format: `Phase <N>: <plan heading title>` for flat phases, `Sub-Phase <letter>.<n>: <plan heading title>` for sub-phases. Keep titles ≤ 80 chars.

Update task status as the loop runs:
- `in_progress` when the phase enters **Step 1: Capture Phase Start SHA**.
- `completed` when **Step 7** finishes (plan.md checkbox tick + phase commit landed).
- On phase circuit-breaker escalation (oracle 2-attempt budget exhausted, agent BLOCKED, post-commit gate rejected twice, etc.), leave the task `in_progress` and surface to human — do NOT mark `completed`.

Resume case: if `TaskList` already returns tasks for this piece (a prior session created them), do NOT call `TaskCreate` again. Reconcile against plan.md's current checkbox state: phases with all boxes `[x]` → `completed`; the next unchecked phase → `in_progress` when its Step 1 begins. A mismatch between the existing task list and the plan's current unit list (plan edited mid-flight) surfaces to human — do NOT auto-rebuild silently.

## Per-Phase Loop

For each phase in plan.md (skip phases where all checkboxes are [x]):

Sub-steps per phase, in order: **Step 0a** (mid-piece Opus QA pass, FR-9 — runs only at the half-way phase boundary of ≥6-phase pieces), then **Steps 1–7** (the standard per-phase pipeline).

### Step 0a: Mid-piece Opus QA pass (FR-9)

At the start of each phase iteration, evaluate the mid-piece trigger before doing any other work for this phase.

**Resume guard (v3.1.1+ two-source check):** before evaluating conditions 1-3, the orchestrator consults TWO independent sources for whether a prior mid-piece dispatch has already fired this piece. EITHER source positive → skip the dispatch.

  1. **Session-state file** (primary, survives history rewrites): read `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.orchestra-state.json`. If it contains `{"mid_piece_opus_pass_dispatched": true, "at_phase": <N>}`, the dispatch already fired in a prior session — set `mid_piece_opus_pass: not-triggered (resumed-after-prior-dispatch via state file)` and proceed to Step 1. The state file is gitignored or removed by Step 6 merge; it persists across orchestrator session restarts but not across squash-merge to master.
  2. **Marker commit** (secondary, falls back when state file is absent): check whether a `chore(<piece-slug>): mid-piece Opus QA pass dispatched at phase <N>` commit (regex: `chore\(<piece-slug>\): mid-piece Opus QA pass dispatched at phase [0-9]+`) already exists in `git log --oneline $(git merge-base origin/main HEAD)..HEAD`. If so, set `mid_piece_opus_pass: not-triggered (resumed-after-prior-dispatch via marker commit)` and proceed to Step 1.

The marker-commit message embeds the resolved phase number (not the literal 'K+1') for unambiguous detection. The state-file source is checked FIRST because it survives interactive rebases / squash-merges that would erase the marker commit. If neither source returns positive, the trigger evaluation proceeds.

**Pre-commit hook compatibility (v3.1.1+):** if the project's pre-commit configuration rejects empty commits (some configs enforce a "commits must touch at least one file" rule), the `git commit --allow-empty` marker commit at step 4 below will fail. In that case, the state-file source above is mandatory — write `.orchestra-state.json` BEFORE attempting the marker commit; if the marker commit fails, the state file alone carries the resume signal.

**Trigger evaluation:**

**Phase counting clarification (v3.1.1+):** N counts each top-level scheduler unit as 1. A `## Phase Group <letter>` heading wrapping ≥2 `[P]`-marked sub-phases is **one** unit (sub-phases are internal to the group). Phases declared with individual `### Phase <num>` headings — even when titled `Group B.1`, `Group B.2`, etc. for AC-tracking purposes — each count as **one** unit because they have their own `### Phase` heading and dispatch sequentially. So pi-009-hardening with 1 Phase Group + 8 sequential `Group B.x`/`Group C.x`/`Phase D` flat phases = N=9, K=⌈9/2⌉=5.

**Odd-N timing (v3.1.1+):** for odd N, K=⌈N/2⌉ means ⌊N/2⌋ phases run pre-half and ⌈N/2⌉ run post-half. The asymmetry is intentional — earlier dispatch is safer than later. Example: N=7 → K=4 → trigger fires before phase 5; phases 1-4 are reviewed by the mid-piece pass; phases 5-7 are post-mid-piece.

- Let `N` = total number of phases declared in `plan.md`. Count `### Phase <num>` headings plus `## Phase Group <letter>` headings, where each Phase Group heading counts as one phase from the scheduler's view (its sub-phases are internal to that group).
- Let `K` = ⌈N / 2⌉ (ceiling of N divided by 2).
- The trigger fires **if and only if all three conditions hold:**
  1. `N ≥ 6`
  2. The current phase is phase number `K + 1` (i.e., the first phase strictly past the half-way point).
  3. Every phase from 1 through K returned `skip` from the Opus skip-predicate defined in `### Step 6: Phase QA` (the (a)/(b)/(c) structured predicate that decides whether to dispatch Opus QA for the phase, sharpened in this same release per FR-8). Phases that routed to Opus QA — for any reason — disqualify the trigger.

If the trigger does NOT fire, set `mid_piece_opus_pass: not-triggered` for this phase and proceed immediately to **Step 1**.

**Mid-piece pass dispatch (when trigger fires):**

1. Compose a self-contained prompt from `${CLAUDE_PLUGIN_ROOT}/agents/qa-phase.md` with `Input Mode: Mid-piece full review` on line 1. The prompt MUST include — and only these inputs (NN-C-008: no conversation history, no per-phase QA reports):
   - **Cumulative diff:** `git diff $(git merge-base origin/main HEAD)..HEAD` output (the full diff from piece start through the last completed phase). The cumulative diff baseline is computed at dispatch time as `git merge-base origin/main HEAD` — the piece's branch point from main. Resume-safe because it's recomputed each time.
   - **Full spec:** the complete text of `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`.
   - **AC matrix:** the union of `## AC Coverage Matrix` rows from all completed phase Build reports, held in orchestrator state since Step 3.8's validation gate captured them per-phase as `phase_<id>_ac_matrix` keys (one per phase / sub-phase). Format: phase-N | AC-id | status | pointer.
   - **Charter raw text (always-attach):** verbatim contents of `<docs_root>/charter/non-negotiables.md` and the `## Non-Negotiables (Product)` section from `<docs_root>/prds/<prd-slug>/prd.md`. Plus, if the spec's `### Coding Rules Honored` block cites any `CR-xxx` entries, attach those specific entries (not the full file) extracted from `<docs_root>/charter/coding-rules.md`. Match Step 6's existing extraction pattern.

2. Dispatch:
   ```
   Agent({
     description: "Mid-piece QA for <piece-name> (phase <resolved-phase-number>)",
     prompt: <composed self-contained prompt>,
     model: "opus"
   })
   ```

3. **Iter-until-clean** (see `### Step 6: Phase QA` iter-until-clean fix-code dispatch pattern; same loop semantics)**:** if the mid-piece pass returns must-fix findings:
   - Dispatch `fix-code` (Sonnet) with the findings and plan context. The fix agent does NOT commit; it ends with `## Diff of changes`.
   - Commit the fix diff: `git add -- <files>; git commit -m "fix: mid-piece QA iter M"`. Hooks run normally.
   - Re-dispatch `qa-phase.md` with `Input Mode: Focused re-review`, the prior must-fix findings, and the fix diff.
   - **Circuit breaker:** 3 iterations maximum. On third circuit-breaker hit, surface to human and do NOT auto-resume.

4. On clean (must-fix = None): append a marker commit to record the dispatch (enables the resume guard above):
   ```bash
   git commit --allow-empty -m "chore(<piece-slug>): mid-piece Opus QA pass dispatched at phase 5"
   # (replace 5 with the actual resolved phase number at commit time — e.g. K+1 resolved to 5)
   ```
   Then log `mid_piece_opus_pass: dispatched` with iteration count for the session summary; proceed to **Step 1**.

5. On circuit-breaker escalation: log `mid_piece_opus_pass: escalated`; surface to human; halt.

### Step 1: Capture Phase Start SHA

Record the current HEAD into orchestrator state as `phase_N_start_sha`. No tag, no commit — this lives in your (the orchestrator's) working memory.

```bash
# orchestrator captures the output of this into phase_N_start_sha
git rev-parse HEAD
```

On resume mid-phase (phase not yet marked complete in plan.md), recover the SHA the same way: `git rev-parse HEAD`. Under the v2.7.0 unified-commit model, the phase produces at most two work-commits before Step 7 — the implementer's unified commit (Red's staged tests + Build's production code) and the optional Refactor commit. If the phase is resumed AFTER the implementer's commit lands, `git rev-parse HEAD` will return that commit, not the pre-Red SHA — and that's fine, because the post-commit integrity and reconciliation gates have already run. The `phase_N_start_sha` used for diff-baseline calculations (Verify inputs, QA surface map, Step 6b hook sweep) is always computed from the resume-time HEAD minus the commits produced by this phase's already-completed steps, inferred from plan.md's checked boxes.

### Step 1a: Detect Phase Mode

Inspect the phase's checkboxes in plan.md to determine the mode flag passed to the implementer agent:

- Phase contains `[TDD-Red]` → **Mode: TDD**. Run Step 2 (Red) first, then Step 3 (Implement in TDD mode), then Steps 4 → 5 → 6.
- Phase contains `[Implement]` and NO `[TDD-Red]` → **Mode: Implement**. Skip Step 2. Run Step 3 (Implement in Implement mode), then Step 4, then Step 5 only if the phase has a `[Refactor]` checkbox, then Step 6.
- Both markers present, or neither: plan is malformed. Escalate to human.

The orchestrator branches mechanically on the checkbox; it does not decide which mode applies. The mode decision was made by the plan author. The Implement mode exists for phases where TDD doesn't fit (config, infra, scaffolding, glue code, docs-as-code) **and** for all phases when the plan uses non-TDD mode (`tdd: false` in plan front-matter).

### Step 1b: Phase Pre-Flight (read-only)

Before dispatching Red or Implement, the orchestrator collects facts the agents would otherwise rediscover. Scope every probe to the phase's declared scope — files and symbols named in the plan's [TDD-Red], [Build], or [Implement] blocks. Pre-flight should take seconds; if any probe is slow (e.g. `git grep` on a monorepo), use path filters targeting scope directories or skip it.

1. **LOC snapshot** — for each file the phase touches, run `wc -l <file>`. Attach as "LOC headroom" context.
2. **Schema shape** — if the plan references a config family (`configs/<X>/`, schemas, templates), sample one existing sibling: `head -20 configs/<X>/<any_existing>`. Attach as "Existing schema" context.
3. **Symbol presence** — for each type/class/function the plan names that isn't already defined inside the phase's own scope, `git grep -l -E '^(class|def|function) <Name>\b'` (or equivalent scoped to likely source directories). Attach the hit paths or "(not found — define in Build)".
4. **Pre-commit hook inventory** — if `.pre-commit-config.yaml` exists, read it. For each hook, check whether its `id` or `entry` invokes a test runner (substring match on `pytest`, `unittest`, `go test`, `jest`, `vitest`, or the project's declared test command from CLAUDE.md). Flag any matches. **Err on surfacing** — false positives only give the Red agent information it doesn't need; false negatives stall the pipeline when Red hits a hook wall.
5. **TDD mode flag** — check the plan's front-matter `tdd:` field. If `tdd: false`, note that this is a non-TDD piece (no AC matrix required; Verify defaults to Full mode; Write-Tests step applies).
6. **Plan conditional resolution** — scan the phase's [Build]/[Implement] block for ONLY these two phrase patterns:
   - "extract ... if ... exceeds <N>" — evaluate using the LOC snapshot.
   - "if <file/symbol> exists, reuse; otherwise create ..." — evaluate using symbol presence.
   Resolve each into a bullet under `## Orchestrator pre-decisions`. Other conditional phrasings (runtime-state conditions, fuzzy natural-language conditionals) pass through unchanged — the orchestrator is not a general-purpose plan interpreter.

Compose two attachments for later steps:

- `## Pre-flight snapshot` — items 1–5 above, verbatim. Attached to BOTH the Red prompt (Step 2) and the Implement prompt (Step 3) — Red benefits from symbol presence and schema samples too.
- `## Orchestrator pre-decisions` — item 6, one resolved decision per bullet. Attached only to the Implement prompt. Empty section OK (include the heading with "(none)" if no conditionals matched).

If `.pre-commit-config.yaml` is absent, the hook inventory is empty — agents commit normally without any hooks running.

### Step 2: TDD-Red — Write Failing Tests (Stage, Don't Commit)

*(Mode: TDD only. Skip this step entirely when the plan uses non-TDD mode (`tdd: false` in plan front-matter). As of v2.7.0, Red stages its tests via `git add` but does NOT commit. The implementer in Step 3 creates the unified commit containing Red's staged tests + Build's production code. This makes each TDD cycle land as one commit in git history.)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/tdd-red.md`
2. Compose prompt with: phase [TDD-Red] tasks from plan, spec ACs, existing test patterns, and the `## Pre-flight snapshot` block from Step 1b. Red does NOT commit — the pre-commit hook does not run during its turn. The `--no-verify` test-running-hook carve-out from pre-v2.7.0 is obsolete (there's no Red commit for the hook to block).
3. Dispatch:
   ```
   Agent({
     description: "TDD-Red: write failing tests for Phase N",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Validate against two invariants.** Both must hold or the Red phase is rejected:
   - **(a) All new tests are in the FAILED list.** Every test ID the agent listed in `## Tests Written` must appear in its `## Oracle block` FAILED list (or SKIPPED with an explicit reason). Diff the two sets; any `## Tests Written` entry missing from FAILED/SKIPPED is a violation.
   - **(b) Zero passing new tests.** Re-run the test suite scoped to the paths in `## Tests Written` (e.g. `pytest <paths>`, `vitest run <paths>`, `go test <pkgs>`, whatever the project's runner supports). The re-run reads from the working tree + staging area, no commit required. The summary must report `0 passed`. If the runner cannot be scoped, parse the full run's per-test results and confirm none of the `## Tests Written` IDs are in the passed set.
   - **Failure-reason sanity:** for each FAILED test, check the message indicates a missing feature (good), not a typo / import error / fixture error (bad).
   - **On any violation:** the agent wrote a Red phase that breaks discipline. Before retry, clean up the staging area from the failed attempt:
     ```bash
     git restore --staged --worktree -- <paths from failed Red's ## Tests Written>
     ```
     This unstages the rejected tests and reverts working-tree changes, giving the retry a clean slate. Retry once with the specific offense appended (passing test IDs, setup-error output, or missing FAILED entries). A passing new test in Red means either the feature already exists (wrong phase — escalate, the plan needs correction) or the assertion is tautological (rewrite). If the second attempt still violates either invariant: escalate to human.
5. **Capture the Oracle block:** extract the Red agent's `## Oracle block` section verbatim. Hold in orchestrator state as `phase_N_oracle_block` — Step 3 splices it into the implementer prompt without paraphrase.
6. **Capture the stage manifest.** Extract Red's `## Staged test manifest` section verbatim. Hold in orchestrator state as `phase_N_red_stage_manifest` — a dict of `path → sha256`. This replaces the old post-commit contamination check: the orchestrator uses it after the implementer's unified commit to (a) re-hash each test file in HEAD and detect tampering, and (b) reconcile the commit's file list against the expected union of Red's staged paths + Build's reported paths.

   **Defensive re-hash at capture time.** Before trusting Red's self-reported manifest, re-hash each listed file in the working tree (where the staged content lives) and compare:
   ```bash
   for path in <paths from manifest>; do
     actual=$(sha256sum "$path" | cut -d' ' -f1)
     reported=<hash from Red's manifest for this path>
     [ "$actual" = "$reported" ] || echo "manifest mismatch: $path"
   done
   ```
   If any path's self-reported hash does not match the file content, reject Red's output — the manifest is either stale or wrong. Retry once with the mismatch reported. Also sanity-check that every `## Tests Written` path appears in the manifest (and vice versa); a divergence here means Red's output is internally inconsistent and the orchestrator should reject before proceeding.

   Also persist the stage manifest to a temp file (e.g. `/tmp/spec-flow/phase-N-red-manifest.json`) so that if the worktree is clobbered externally before Step 3 completes, the orchestrator can detect it on resume and escalate with a clear signal.

### Step 2.5: QA-TDD-Red — Reject Theater Tests

*(Mode: TDD only. Skip this step when the plan uses non-TDD mode (`tdd: false` in plan front-matter). Runs between Red's commit and the implementer dispatch. Catches theater tests — tautology, mock-echo, assert-the-assignment, truthy-only, exception swallowing, no-assertion, name/body mismatch, implementation coupling, redundant clusters — before Build writes production code fit to weak assertions.)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-tdd-red.md`
2. Compose prompt with:
   - Red's `## Tests Written` list
   - The phase's `[TDD-Red]` block from plan.md (reference by file path + line range)
   - The phase's spec ACs
   - The FAILED IDs from `phase_N_oracle_block` (captured in Step 2.5)

   The qa-tdd-red agent reads the authored test files directly; do not paste their contents into the prompt.
3. Dispatch:
   ```
   Agent({
     description: "QA-TDD-Red: review Phase N tests for theater patterns",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Parse the verdict:**
   - **PASS** — proceed to Step 3 (Implement/Build).
   - **FAIL** — re-dispatch `tdd-red` once with the qa findings appended (pattern IDs, AC-binding weaknesses, coverage gaps). Use the 1-attempt retry budget: if the second Red attempt ALSO fails qa-tdd-red, escalate to human with both reports attached. Two consecutive failures means the phase's ACs are too vague (spec defect) or the plan's `[TDD-Red]` block is directing Red toward un-testable surface (plan defect).
5. On PASS, Red's oracle block is unchanged — no new state to capture. Proceed to Step 3 with `phase_N_oracle_block` as captured in Step 2.5.

### Step 3: Implement — Write the Code

*(Both modes. The mode flag determines the agent's oracle of done.)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/implementer.md`
2. Compose prompt using the canonical template below. **Reference plan.md by file path and line range rather than restating its contents** — the agent reads plan.md directly. The prompt supplies only what plan.md doesn't: pre-flight facts, pre-decisions, and the mode oracle.

   ```markdown
   Mode: TDD | Implement

   ## Plan reference
   Execute `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` Phase <N>
   [Build] | [Implement] block verbatim (lines <X>-<Y>). The plan is
   binding; this prompt only supplies context the plan doesn't.

   ## Pre-flight snapshot
   <LOC snapshot, schema samples, symbol presence, hook inventory from Step 1b>

   ## Orchestrator pre-decisions
   <one bullet per resolved plan conditional from Step 1b item 5, or "(none)">

   ## Oracle (Mode: TDD) | Verify command (Mode: Implement)
   - Mode: TDD — splice `phase_N_oracle_block` from Step 2 verbatim.
   - Mode: Implement — include the plan's `[Verify]` command and
     expected output.

   ## Red staged test manifest (Mode: TDD only)
   <splice `phase_N_red_stage_manifest` from Step 2.6 verbatim — paths
   with SHA-256 hashes. The implementer must NOT modify these files;
   the orchestrator's post-commit gate re-hashes them against this manifest.>

   ## Commit
   The implementer creates ONE unified commit containing:
   - Mode: TDD — Red's staged tests (already in the staging area when you
     start) + your production code (stage with `git add -- <literal paths>`).
   - Mode: Implement — only your authored files (no prior staging).
   Message references phase N and mode.
   ```

3. For tasks marked [P] (parallel): dispatch multiple Agent calls concurrently, each with the same mode flag.
   - **Merge check:** After all parallel agents complete, verify no file conflicts. If conflicts: reject, re-dispatch sequentially, flag as plan defect.
4. Dispatch:
   ```
   Agent({
     description: "Implement (Mode: TDD|Implement): Phase N",
     prompt: <composed, with Mode: flag on line 1>,
     model: "sonnet"
   })
   ```
5. **Validate oracle:** Run the mode's oracle.
   - Mode: TDD — three invariants, all required:
     - **(a) Full suite green** — `0 failed` across the whole test suite.
     - **(b) Every Red ID is in PASSED** — parse the current run's PASSED set and diff against the FAILED IDs captured in `phase_N_oracle_block` from Step 2.5. Every Red test ID must appear in the PASSED set. Missing IDs (collection errors, empty parameterize, deleted tests) are a rejection signal.
     - **(c) Zero Red IDs in SKIPPED** — any Red ID marked `@pytest.mark.skip`, `.skip()`, `t.Skip()`, `xfail`, or otherwise non-run is a rejection signal. This catches silent skip decorators added during Build.
     - On violation of (b) or (c): retry within the 2-attempt budget with the specific offending IDs surfaced to the agent (e.g. "tests X, Y were SKIPPED in your run; you cannot pass Red tests by skipping them"). Escalate on second failure — a Red test that cannot go green without skipping means the plan or the Red tests themselves are wrong.
   - Mode: Implement — the plan's `[Verify]` command must pass with the plan's expected output.
6. **Circuit breaker:** If the oracle does not pass after 2 attempts in either mode, escalate to human. If the agent reports BLOCKED (e.g. ambiguous plan, architecture conflict, pre-decision vs. filesystem mismatch), escalate — do not retry blindly.
7. **Post-commit integrity and reconciliation gates (Mode: TDD + Implement, v3.1.1+).** After the implementer's commit lands (HEAD now points to it), run cheap checks before accepting the phase. Gate (a) is TDD-only (uses Red's manifest); gate (b) is HARD FAIL on BOTH modes — strays or missings reject the phase. The Implement-track extension was added in v3.1.1 per pi-009-hardening's Phase Group A contamination event, where A.2 silently swept in A.4's staged files because the gate was previously gated `Mode: TDD only`.

   - **(a) Content-hash integrity (Mode: TDD only).** For every path in `phase_N_red_stage_manifest`, re-hash the file AS COMMITTED in HEAD and compare against the manifest:
     ```bash
     for path in <manifest paths>; do
       commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
       manifest_hash=<manifest hash for path>
       [ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
     done
     ```
     Any mismatch means the implementer modified one of Red's tests — the anti-cheat safeguard replacing pre-v2.7.0's `git diff tests/` check. Reject the phase and retry within the 2-attempt budget (the retry must recreate the commit without touching Red's tests). Escalate on second failure.

     For Mode: Implement, this gate is skipped (no Red manifest exists); proceed directly to (b).

   - **(b) Unified commit reconciliation (Mode: TDD AND Mode: Implement).** The commit's file list must equal the **expected file set**:
     - **Mode: TDD:** `expected = Red's manifest paths ∪ Build's `## Files Created/Modified` paths`.
     - **Mode: Implement:** `expected = Build's `## Files Created/Modified` paths` only (no Red manifest).

     ```bash
     git show --name-only --pretty= HEAD | sort > /tmp/commit_files.txt
     # Compose expected per the mode above; write sorted list to /tmp/expected_files.txt
     diff /tmp/commit_files.txt /tmp/expected_files.txt
     ```
     Any stray file (in commit but not in expected) or missing file (in expected but not in commit) rejects the phase. Strays typically mean a concurrent agent's uncommitted changes were swept in via `git commit -a` or `git add -A` — for Phase Group sub-phases dispatching concurrently, this is the staging-area race the gate is built to detect. Missings typically mean the implementer forgot to stage one of its own files. On rejection: for Mode: Implement, escalate immediately — strays on Implement track usually mean a sibling sub-phase swept in, which is unrecoverable by re-dispatching the same agent. Mode: TDD retries within the 2-attempt budget.

8. **AC Coverage Matrix validation gate.**
    - **Mode: TDD:** After the oracle passes and post-commit gates are clean, validate the Build report's `## AC Coverage Matrix` section. See `references/ac-matrix-contract.md` for the schema and parsing rules. In short: reject + re-dispatch (within the 2-attempt oracle budget above) if the section is missing, missing an in-scope AC row, contains a bare `NOT COVERED`, or a vague `covered` pointer. Clean matrix → proceed to Step 2.7. If validation fails twice, escalate — the plan likely has ambiguity about phase AC assignment. After validation, persist Build's `## AC Coverage Matrix` to orchestrator state as `phase_<id>_ac_matrix`, where `<id>` is the phase identifier (e.g., `phase_2`, `phase_3`, `group_a_subphase_a1`, `phase_group_a` for the union, etc.) — the orchestrator chooses a unique identifier per phase or sub-phase. Keys never collide; multiple phases produce multiple keys. Used by Step 0a's mid-piece dispatch.
    - **Mode: Implement (non-TDD mode):** This gate is skipped. The AC Coverage Matrix is not required in non-TDD mode (`tdd: false` in plan front-matter). If the implementer provides one, it may be used to unlock Audit mode (see Step 4), but its absence does not reject the phase. Proceed to Step 2.7.

### Step 2.7: Write-Tests (Non-TDD Mode Only)

*(Skip this step when the plan uses TDD mode (`tdd: true` or no `tdd:` front-matter). This step exists only for non-TDD pieces where tests are written after implementation.)*

1. Dispatch an agent to write tests for what was implemented in Step 3. The agent should:
    - Read the phase's `[Implement]` block from plan.md and the implementation diff.
    - Write tests that verify the implementation is correct, with reasonable coverage of the phase's ACs.
    - No "fail first" requirement — tests are written for existing code.
    - No theater-pattern review, no SHA-256 manifest.
    - Stage tests via `git add` (do NOT commit) so the Verify step can run them.
2. **Validate:** Run the test suite scoped to the authored test paths. All new tests should pass (they're written for existing code). If tests don't pass, the agent should fix them within the same turn.
3. **No AC Coverage Matrix required.** Unlike TDD mode, there's no hard gate here. Just reasonable test coverage.
4. Proceed to Step 4 (Verify).

### Step 4: Verify — Confirm Correctness

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/verify.md`
2. **Pick the Verify input mode.** Inspect the Implement agent's report for three conditions:
   - **`## Oracle Outcome`** — does it say the oracle ran clean on first attempt (no retries)?
   - **`## Plan Adherence`** — is `Deviations from plan: none`?
   - **`## AC Coverage Matrix`** — is it present, complete (every in-scope AC listed), and free of `NOT COVERED` entries?
     - **Non-TDD override:** If the plan declares `tdd: false` in its front-matter, Condition 3 is treated as "not applicable" (the AC matrix is not expected in non-TDD mode). Only Conditions 1 and 2 determine the mode.

   If **all applicable conditions** are true, pick **Mode: Audit** — dispatch a narrow agent that sanity-checks the AC matrix without re-running the oracle (~3 min). If any is false, pick **Mode: Full** — dispatch the full verifier (~10 min).

   Record the decision in the dispatch log so session summaries can report the Audit/Full mix.
3. Compose prompt. Line 1 is the mode flag:
   - **Mode: Audit** — attach Build's `## AC Coverage Matrix` verbatim, the implementation diff (`git diff $phase_N_start_sha..HEAD -- <non-test files>`), and spec ACs for this phase. Do NOT attach test output — Audit does not re-run tests.
   - **Mode: Full** — attach the full oracle output (the project's test-runner output for Mode: TDD, or the plan's `[Verify]` command output for Mode: Implement), the full phase diff, and spec ACs.
4. Dispatch:
   ```
   Agent({
     description: "Verify (Mode: Audit|Full): check Phase N correctness",
     prompt: <composed, with Mode: flag on line 1>,
     model: "sonnet"
   })
   ```
5. **Test integrity (Mode: TDD only; non-TDD mode: no-op).** As of v2.7.0, the primary anti-tampering safeguard runs at Step 3.7a (content-hash check of Red's staged test manifest against Red's test files in HEAD). By the time Step 4 runs, that gate has already passed — so no additional diff is needed here. In non-TDD mode (`tdd: false`), there is no Red manifest, so this check is a no-op. If the phase produces a Refactor commit in Step 5, re-run the content-hash check against HEAD after Refactor lands (Refactor is phase-scoped and must not touch test files the Red agent authored; re-hashing catches drift). If any hash drifts at Refactor time: REJECT, revert the refactor commit, and flag the Refactor agent for re-dispatch with the offending paths surfaced.
6. Parse verify report.
   - **Audit Mode returned PASS** — proceed to Refactor (Step 5).
   - **Audit Mode returned FAIL** with `Recommend: Full mode re-verify` — re-dispatch as Mode: Full, treat that result as authoritative.
   - **Full Mode returned PASS** — proceed to Refactor.
   - **Full Mode returned FAIL** — if gaps: Mode: TDD can loop back to Red (add tests); Mode: Implement can loop back to Step 3 with gaps as context. Otherwise escalate.

### Step 5: Refactor — Clean Up

*(Mode: TDD by default; Mode: Implement only if the phase has a `[Refactor]` checkbox. Conditional skip applies to both modes — see below.)*

**Conditional skip.** Read the `refactor` key from `.spec-flow.yaml` (valid values: `auto`, `always`, `never`; default `auto`). If the key is absent, default to `auto`.

- `never` — skip this step unconditionally. Proceed to Step 6.
- `always` — run this step unconditionally.
- `auto` — inspect the Build agent's report. Skip this step if **all** of:
  - `## Oracle Outcome` reports `Oracle ran clean on first attempt: yes`
  - `## Plan Adherence` reports `Deviations from plan: none`
  - `## AC Coverage Matrix` is clean (all rows `covered`, no `NOT COVERED` rows — already validated by Step 3's gate, but re-check here)

  Otherwise run the step.

Log the skip decision (`refactor_skipped: auto|never` with the reason) for the session summary. Observed yield from Phases 5a–11: 8 Refactor passes produced only comment cleanups / −3 to −48 LOC dedup and fixed zero correctness defects. Skipping when Build is clean reclaims 10–15 min per phase with no observed quality loss.

If skipped, proceed directly to Step 6. Otherwise:

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/refactor.md`
2. Compose prompt with: list of phase files, the mode's verification command (full test suite for Mode: TDD, plan's `[Verify]` command for Mode: Implement), quality principles
3. Dispatch:
   ```
   Agent({
     description: "Refactor: clean up Phase N",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Validate:**
   - Re-run the phase's verification command: still passing?
   - Check scope: `git diff --name-only` shows only phase files changed?
   - If out-of-scope files modified: reject the refactor, revert.

### Step 6: Phase QA

**Opus QA dispatch decision (FR-8 — sharpened skip predicate):** before composing the iter-1 prompt, evaluate whether to dispatch Opus QA for this phase or skip Opus entirely. Skip Opus only when ALL three conditions hold for the phase diff:

  - **(a)** Diff content is composed exclusively of: added markdown sections / paragraphs / lists, added or modified YAML keys with literal scalar values, or added comments and whitespace.
  - **(b)** No file in the diff is under `plugins/*/skills/*/SKILL.md` AND newly created (a new skill body always routes to Opus regardless of LOC).
  - **(c)** No file in the diff contains a script in any procedural language with branching control-flow constructs (conditionals, loops, short-circuit operators). The detection pattern set targets shell-style constructs (since spec-flow's hooks are shell scripts today) — extensible if spec-flow ever adopts hooks in another language.

Otherwise route to Opus. "Small LOC" is no longer sufficient justification for skipping; control-flow density is the actual risk signal.

Worked examples:
- **Example A (skip):** a phase that adds three new H3 sections to a SKILL.md file with no code blocks. → all three conditions hold → skip Opus.
- **Example B (do not skip):** a phase that adds a 14-line bash hook with one `if` block to `plugins/spec-flow/hooks/`. → condition (c) fails → route to Opus.
- **Example C (do not skip):** a phase that creates a new `plugins/spec-flow/skills/<name>/SKILL.md` file. → condition (b) fails → route to Opus.

Record the decision (`opus_dispatched: true|false (reason)`) for the session summary and for Step 0a's mid-piece trigger evaluation.

Iter-until-clean per plugins/spec-flow/reference/qa-iteration-loop.md (no skip; 3-iter circuit breaker).

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-phase.md`

2. **Iteration 1 (full review):** Build a structured surface map instead of dumping the raw diff + full spec + PRD. The goal is to hand Opus pre-digested context so it does adversarial review, not re-discovery.

   Compose the iter-1 prompt with the following blocks, in order:

   - **`## Files changed`** — one row per file: `path | +adds/-dels | role (test/impl/config/docs)`. Generated from `git diff --numstat $phase_N_start_sha..HEAD` plus path-based role inference.

   - **`## Public symbols added or modified`** — list of class/function/type names the diff introduces or modifies in non-test files. Use `git diff $phase_N_start_sha..HEAD -- <impl paths>` and grep for added/changed lines matching the project's symbol declarations (e.g. `^[+-]\s*(class|def|function|type)\s+\w+`). One line per symbol: `path:symbol`.

   - **`## Integration callers`** — for each public symbol above, run `git grep -l <symbol>` scoped to source directories. Paths only, no bodies. Opus can `Read` specific callers if it needs to inspect them. If a symbol has zero callers, mark it "(new — no callers yet)".

   - **`## Diff`** — changed-line hunks only (default `git diff` output). If the total diff is > 500 LOC, collapse to per-file summaries with a pointer: "Full hunks available; Read <path> or request via targeted diff if you need specific ranges." Do not attach full file bodies ever.

   - **`## AC Coverage Matrix (from Build)`** — splice Build's `## AC Coverage Matrix` table verbatim. This was already validated clean by Step 3's gate. Opus's job is to adversarially verify the claimed coverage is real and find gaps, NOT to re-derive the matrix from scratch.

   - **`## Phase ACs`** — attach ONLY the acceptance criteria for this phase (mapped via plan.md), not the full spec. Use the plan's "AC map" section or the spec's AC sections that the plan references for this phase.

   - **`## Non-negotiables`** — project constraints. Attach `<docs_root>/charter/non-negotiables.md` (NN-C, project-wide) and the `## Non-Negotiables (Product)` section from `<docs_root>/prds/<prd-slug>/prd.md` (NN-P, product-specific). If `<docs_root>/charter/` is absent (pre-charter project), attach only the legacy NN section from the PRD.

   - **`## Coding rules cited by this phase`** — if the plan's phase block's "Charter constraints honored in this phase" slot cites any `CR-xxx` entries from `<docs_root>/charter/coding-rules.md`, attach those specific entries (not the full file). Absent slot or no citations → skip this block.

   **Do NOT attach:** full spec, PRD sections, full plan, or full test-runner output. PRD alignment is the Final Review board's job (`review-board-prd-alignment.md`). Per-phase QA is about correctness against the plan, not PRD compliance.

   Dispatch:
   ```
   Agent({
     description: "QA: review Phase N (iter 1, full)",
     prompt: <composed blocks above, with "Input Mode: Full" on line 1>,
     model: "opus"
   })
   ```

3. **QA Loop (iterations 2+, focused):** If iteration M-1 returned must-fix findings:
   - Read fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-code.md`
   - Dispatch fix agent (Sonnet) with prior findings + plan context. The fix agent does NOT commit; it ends its report with a `## Diff of changes` section containing its `git diff`.
   - Extract that diff string from the fix agent's report and hold it in orchestrator state as `iter_M_fix_diff`.
   - Commit the fix diff so HEAD advances and the next QA iteration reviews a real commit boundary rather than a dirty worktree:
     ```bash
     git add -- <files touched in iter_M_fix_diff>
     git commit -m "fix: Phase N QA iter M"
     ```
     Hooks run on the commit. If a hook fails, re-dispatch the fix agent with the hook error appended to its context; do not bypass with `--no-verify`.

   - **Re-dispatch:** QA agent (fresh, Opus) with `Input Mode: Focused re-review`, the prior iteration's must-fix findings, and `iter_M_fix_diff`. No full phase diff, no spec/plan re-sent unless referenced in findings. The agent template's iter-2 rules hard-cap out-of-scope reads (return BLOCKED rather than fetching).
   - **Circuit breaker:** 3 iterations max, then escalate.
   - If the fix agent returns `Diff of changes: (none)` (all blocked), escalate — no point re-running QA.

### Step 6a: Deferred-finding tracking (FR-10)

**Dedup check:** before appending a stub, scan the existing PRD-local backlog for any `## [Deferred QA finding]` entry whose `Finding (verbatim)` body matches the about-to-be-appended finding (case-insensitive substring match) within the current piece's session. If a duplicate is found, skip the append; do NOT create a second stub for the same finding.

After each QA iteration (regardless of whether must-fix findings remain), scan the QA agent's full report for `Deferred to reflection:` markers (case-insensitive match). If any are found:

1. **Parse each occurrence:**
   - **Deferring reviewer:** the agent name from the dispatch context — `qa-phase`, `qa-phase-lite`, or `qa-spec` / `qa-plan` / `qa-charter` for spec/plan/charter QA gates.
   - **Finding text (v3.1.1+ formal boundary grammar):** the verbatim prose immediately following `Deferred to reflection:` up to the FIRST line that is either: (a) entirely whitespace (a blank line), or (b) a new list item AT THE SAME OR LESSER INDENT than the line where `Deferred to reflection:` appeared, or (c) a markdown heading (`^#+ `). Whichever comes first terminates the capture. Sub-bullets at GREATER indent than the marker line are part of the same finding (captured verbatim). Preserve the original wording exactly.

   Worked example — nested case:

   ```
   - Deferred to reflection: spec FR-005 ambiguity unresolved
     - sub-bullet adding context that's part of the same finding
     - another supporting sub-bullet
   - Next sibling bullet (terminates capture — same indent as marker line)
   ```

   Captured finding: "spec FR-005 ambiguity unresolved\n  - sub-bullet adding context that's part of the same finding\n  - another supporting sub-bullet" (the first two sub-bullets are at greater indent and are included; the third bullet at same indent terminates).
   - **Commit SHA:** run `git rev-parse HEAD` at deferral time — before any subsequent fix-code or progress commits — to capture the state the finding refers to.

2. **Append a stub** to `<docs_root>/prds/<prd-slug>/backlog.md`:

   ```markdown
   ## [Deferred QA finding] <YYYY-MM-DD> — <piece-slug>

   - **Deferring reviewer:** <agent-name>
   - **Captured at commit:** <sha>
   - **Finding (verbatim):** <prose>
   - **Status:** unresolved — reflection step (4.5) classifies as incorporated / deferred / obsolete.
   ```

   Use today's date (`date +%F`) for `<YYYY-MM-DD>`. If the backlog file does not yet exist, create it using `plugins/spec-flow/templates/backlog.md` as the template (replacing `{{prd_name}}` and `{{date}}` placeholders) before appending.

3. **Commit the backlog edit** on the piece branch:

   ```bash
   git add <docs_root>/prds/<prd-slug>/backlog.md
   git commit -m "chore(<piece-slug>): record deferred QA finding"
   ```

   One commit per QA iteration that contains at least one `Deferred to reflection:` marker. If an iteration has N markers, append all N stubs in a single commit.

4. **Do not block phase progression.** The iter-until-clean loop terminates when must-fix=None. `Deferred to reflection:` items are NOT counted as must-fix findings. The phase advances normally once all must-fix findings are resolved, regardless of how many deferred items were recorded.

5. **Convention, not requirement.** The `Deferred to reflection:` marker is a convention that QA agents may emit voluntarily — per CR-008 + NN-C-008, the agent templates are NOT modified to require or instruct this behaviour. The orchestrator-side parser records whatever the agent emits; it never mandates the marker.

**Step 4.5 (end-of-piece reflection)** reads the accumulated backlog file and prompts the user to classify each `[Deferred QA finding]` entry as one of: **incorporated** (resolved within this piece), **deferred** (move to active backlog as a future piece candidate), or **obsolete** (no longer applies).

4. When QA returns must-fix=None, proceed to **Step 7**.

### Step 6b: Phase Hook Sanity Check

Every intermediate commit in the phase already ran hooks (the implementer's unified commit, Refactor, and fix-code commits all trigger pre-commit normally — Red does not commit and therefore does not trigger hooks, but its tests ride along in the implementer's commit where the hook DOES run over the unified diff), so the cumulative phase diff has been lint/format/type-check-clean at each commit. This step is a single defensive sweep against any autofix residue or staging-area drift that might have slipped through.

1. Run pre-commit over the phase's changed files:
   ```bash
   git diff --name-only $phase_N_start_sha..HEAD > /tmp/phase_N_files.txt
   pre-commit run --files $(cat /tmp/phase_N_files.txt)
   ```
   If `.pre-commit-config.yaml` is absent or the file list is empty, skip to Step 7.

2. **Exit 0:** proceed to Step 7.

3. **Non-zero exit, files modified** (autofix residue): commit the autofix and re-run once. If the second run also modifies files, escalate — hooks are fighting each other; narrow the hook config.

4. **Non-zero exit, no files modified** (real error the hooks couldn't autofix): dispatch fix-code once with the hook output as context. If fix-code's diff doesn't resolve the complaint on the next hook run, escalate — the hook is flagging something out-of-scope for the phase (pre-existing debt surfaced by a global hook, or architecture/type issue).

**Why this step is usually a no-op.** Per-commit hooks catch lint/format/type issues at the commit that introduced them, so nothing accumulates. If this step becomes expensive in practice (multiple fix-code dispatches per phase, or autofix cycles that don't converge), the likely cause is that the project's pre-commit config includes checks requiring full-repo context (whole-repo mypy, global lint rules). Move those to `pre-push` or run them as explicit orchestrator gates — per-commit hooks should be diff-scoped and cheap.

### Step 7: Mark Progress

Update plan.md: mark all phase checkboxes [x]. Commit:
```bash
git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
git commit -m "progress: Phase N complete"
```

Advance to next phase.

## Phase Group Loop

When Phase Scheduler detects a Phase Group:

### Step G1: Capture group-start SHA

Record the current HEAD as `group_start_sha` in orchestrator state. Used later as the diff baseline for group-level Refactor and Opus QA.

### Step G2: Validate sub-phase disjointness

For each Sub-Phase in the group, parse its `**Scope:**` block. Cross-check for pairwise file-path overlap. If overlap exists, log a warning and fall back to serial execution (each sub-phase runs as a flat phase through the Per-Phase Loop).

### Step G3: Per-sub-phase pre-flight

For each sub-phase (in parallel — pre-flight is read-only and cheap), run the existing Step 1b pre-flight against the sub-phase's scope. Produce per-sub-phase `## Pre-flight snapshot` and `## Orchestrator pre-decisions` attachments. These are scoped to the sub-phase only — a Phase Group's pre-flight is not a union.

### Step G4: Dispatch sub-phase pipelines concurrently

For each `[P]`-marked sub-phase in the group, launch its full internal pipeline concurrently. Each pipeline runs independently through its own Red → Build → Verify → QA-lite cycle, anchored at its own `sub_phase_start_sha`.

Dispatch mechanism: issue all sub-phase Red agent dispatches in the same orchestrator turn. When a sub-phase's Red completes, immediately dispatch its Build agent (do not wait for sibling Reds). Same for Build → Verify → QA-lite. Each sub-phase progresses independently; sibling sub-phases are not sync barriers except at the group-end barrier (Step G5).

Rate limiting: dispatch all `[P]` sub-phases in parallel by default. If you hit inference-provider rate limits on large groups (observed when 8+ sub-phases fire concurrently against Opus/Sonnet tiers simultaneously), fall back to serial execution for that group and log the cause. No config knob is exposed today — rate-limit handling is the orchestrator's responsibility, not the plan author's.

Per-sub-phase internal flow — each sub-phase runs the same checks as the Per-Phase Loop:
- Red step (Step 2) — stages tests (sub-phase-scoped), emits its own `phase_N_red_stage_manifest` keyed by sub-phase id
- Build step (Step 3) with Step 3 item 7 AC matrix validation gate + item 8 post-commit integrity + reconciliation gates
- Verify step (Step 4) with Audit/Full mode selection
- QA-lite step — dispatch `qa-phase-lite.md`, Sonnet. Iter-until-clean per `plugins/spec-flow/reference/qa-iteration-loop.md` — full review on iter-1, focused re-review on iter-2+, 3-iter circuit breaker.
- Sub-phase Progress is implicit (no separate progress commit per sub-phase — the group progress commit covers all)

**Shared staging area safety (v2.7.0).** Parallel sub-phases share the same git index, but scope disjointness is enforced at Step G2 (pairwise literal-path check) and literal-path staging discipline in Rule 6 (tdd-red) + Rule 8 (implementer) means each sub-phase's `git add` + `git commit` references only its own paths. A sibling sub-phase's staged-but-uncommitted tests remain in the index but are NOT swept into another sub-phase's unified commit because the implementer commits by literal path. The orchestrator's Step 3.7b reconciliation (commit file list = sub-phase's Red manifest ∪ sub-phase's Build reported files) catches any cross-contamination.

### Step G5: Barrier — wait for all sub-phases

Wait for all sub-phase pipelines to complete (success OR circuit-breaker failure). Do NOT abort early on first failure. Collect each sub-phase's terminal status (success / failure + failure signature).

### Step G6: Auto-triage and two-pass recovery

See the **Auto-triage decision matrix** section below. This step runs the matrix against each failed sub-phase, dispatches appropriate recovery, and (if any recovery actions ran) executes a pass-2 focused re-check.

If all sub-phases ultimately succeed (either in pass 1 or after pass 2 recovery), proceed to Step G7. If any sub-phase remains failed after pass 2, escalate to human with a batched failure report.

### Step G7: Group Refactor (optional, auto-skip predicate)

Read the `refactor` key from `.spec-flow.yaml` (valid values: `auto`, `always`, `never`; default `auto`). Match flat-phase Step 5's three-way branching, scoped to the group:

- `never` — skip this step unconditionally. Proceed to Step G8.
- `always` — run the group Refactor unconditionally (preserves pre-v1.4 behavior for operators who want it).
- `auto` — skip this step if ALL sub-phases in the group reported `Oracle ran clean on first attempt: yes` + `Deviations from plan: none` + clean AC matrix; otherwise dispatch the Refactor agent.

When dispatching the Refactor agent at group level:

- Scope: union of all sub-phase scope declarations
- Prompt notes that "phase files" for this dispatch means the union (see `agents/refactor.md` Rule 1's group-level clarification)

Validate post-Refactor: tests still green (run oracle once over the union), no files outside the union modified.

### Step G8: Group Deep QA (Opus)

Dispatch the `qa-phase.md` agent at Opus tier. Compose the prompt using the existing Step 6 surface-map composition, but scoped to the group:

- `## Files changed` — from `git diff --numstat $group_start_sha..HEAD`
- `## Public symbols added or modified` — union across all sub-phase impl files
- `## Integration callers` — resolved for the union of public symbols
- `## Diff` — collapsed per-sub-phase if total > 500 LOC
- `## AC Coverage Matrix (from Build)` — union of all sub-phases' matrices, sectioned by sub-phase
- `## Phase ACs` — union of all sub-phase ACs
- `## Non-negotiables` — unchanged

If Group Deep QA returns must-fix: run the iter-until-clean loop per plugins/spec-flow/reference/qa-iteration-loop.md (no skip; 3-iter circuit breaker), dispatching fix-code agents for findings. Each fix-code dispatch operates on the specific sub-phase scope the finding points to.

### Step G9: Step 6b hook sweep over the group diff

Run `pre-commit run --files $(git diff --name-only $group_start_sha..HEAD)`. Same autofix-or-fix-code recovery as the flat-phase Step 6b, once across the group.

### Step G10: Group Progress commit

```bash
git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
git commit -m "progress: Phase Group <letter> complete"
```

Advance to next top-level unit in plan.md (another group, or a flat phase, or end-of-piece → Final Review).

## Auto-triage decision matrix (used by Step G6)

When Step G5 ends with any failed sub-phases, the orchestrator auto-triages each failure against this matrix. One recovery action per sub-phase per pass; matrix categories marked "escalate immediately" bypass recovery.

### Pass 1 triage table

| Failure signature | Detection signal | Recovery action | Iterations |
|-------------------|------------------|-----------------|------------|
| Oracle defect — one file, one function, clear error | Test output names a single file + function; fix-code trial stays < 50 LOC | Dispatch fix-code targeting the implementation | 1 |
| Oracle defect — multi-file or repeated-pattern failure | Multiple impl files implicated OR fix-code attempted 2× without progress during the original Build | Dispatch Refactor at sub-phase scope to restructure the approach | 1 |
| Hook failure — lint/format/type-check | Pre-commit output names tool + rule; diff < 20 LOC | Inline autofix if ruff/mypy suggest a concrete patch; otherwise fix-code | 1 |
| Contamination — implementer modified test files during Build (Mode: TDD) | Orchestrator's test-file diff check flagged modified tests | Reset sub-phase to `sub_phase_start_sha`; re-dispatch Build with explicit "do not modify tests" reminder | 1 |
| Scope violation — Build touched files outside declared `**Scope:**` | `git diff --name-only` shows paths outside the sub-phase scope block | Reset sub-phase to `sub_phase_start_sha`; re-dispatch Build with explicit scope violation called out in the prompt | 1 |
| QA-lite must-fix — plan misalignment or local defect | QA-lite `### must-fix` names file:line inside the sub-phase | Dispatch fix-code targeting the finding | 1 |
| QA-lite must-fix — cross-sub-phase concern | QA-lite finding names files in another sub-phase | Escalate immediately — group decomposition is wrong | — |
| BLOCKED — plan ambiguity | Agent returned BLOCKED with ambiguity reason | Escalate immediately | — |
| BLOCKED — architecture conflict | Agent returned BLOCKED citing non-negotiable | Escalate immediately | — |
| BLOCKED — pre-decision mismatch | LOC estimate or symbol-presence pre-decision contradicted by filesystem | Re-run Step 1b pre-flight for this sub-phase; re-dispatch with fresh pre-decisions | 1 |
| All sub-phases in group failed | Pass 1 has zero successes | Escalate immediately — likely spec or plan problem | — |
| Majority share a root cause | ≥50% of failures share a common error signature (same missing type, same fixture path issue) | Escalate immediately — group-level structural issue | — |

Recovery actions for different sub-phases run in parallel when their scopes remain disjoint. Reset-and-re-dispatch (contamination, scope violation) runs serially with the sub-phase's re-dispatched Build.

### Pass 2 — focused re-check on recovered sub-phases only

After pass-1 recovery actions complete:

1. Capture `pass1_end_sha` at the moment pass 2 begins (HEAD after recovery fixes landed).
2. For each sub-phase that had a recovery action, dispatch QA-lite with `Input Mode: Focused re-review` and the fix delta (`git diff $pass1_end_sha..HEAD -- <sub-phase scope>`).
3. Successful sub-phases from pass 1 are NOT re-reviewed — they are locked in.
4. Fix-code within pass 2 still respects the standard 2-attempt orchestrator circuit breaker per sub-phase.

### Hard cap

**2 total passes.** If any sub-phase still fails after pass 2, escalate to human. No pass 3. Either the sub-phase has a genuine blocker (spec ambiguity, architecture conflict) or the group decomposition was wrong — either way, more iteration likely wastes tokens.

### What stays committed during failures

- Successful sub-phases' commits stay live
- Pass-1 recovery commits stay live (each runs hooks and passes before landing)
- If the group ultimately escalates to human, the human inspects the worktree's partial state
- `git reset $group_start_sha` cleanly rolls back the whole group if the human decides to abort

### Escalation report format

When escalating to human, the orchestrator produces a batched report:

```
## Phase Group <letter> — escalation required

### Sub-phase status
- A.1 ✓ succeeded (pass 1)
- A.2 ✓ succeeded after pass-1 recovery (fix-code)
- A.3 ✗ failed — <category from matrix>
  - Pass 1 attempt: <recovery action taken>
  - Pass 2 result: <what still fails>
  - Recommended human action: retry with revised plan | skip sub-phase | abort group

### Worktree state
- group_start_sha: <sha>
- HEAD: <sha>
- Files modified: <list>

### Next step
<blocking ask to human>
```

One review session handles the whole batch — no per-sub-phase interruptions.

## Final Review

Triggered automatically when the last phase's QA passes.

### Step 1: Iteration 1 — Full Review (5 Parallel Agents)

Get the full worktree diff:
```bash
git diff main..HEAD
```

Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<role>.md` and dispatch ALL FIVE concurrently with `Input Mode: Full`:

```
Agent({ description: "Blind review (iter 1, full)", prompt: <review-board-blind.md + Input Mode: Full + diff only>, model: "opus" })
Agent({ description: "Edge case review (iter 1, full)", prompt: <review-board-edge-case.md + Input Mode: Full + diff + codebase note>, model: "opus" })
Agent({ description: "Spec compliance review (iter 1, full)", prompt: <review-board-spec-compliance.md + Input Mode: Full + diff + spec + plan + (charter NN-C/CR + prd NN-P for claim verification)>, model: "opus" })
Agent({ description: "PRD alignment review (iter 1, full)", prompt: <review-board-prd-alignment.md + Input Mode: Full + diff + spec + PRD + manifest>, model: "opus" })
Agent({ description: "Architecture review (iter 1, full)", prompt: <review-board-architecture.md + Input Mode: Full + diff + charter (all six files if present; else legacy arch docs) + NN-C + NN-P>, model: "opus" })
```

### Step 2: Triage

Collect findings from all 5 agents. Deduplicate (same issue reported by multiple reviewers). Classify:
- `must-fix` — blocks merge
- `defer` — pre-existing issue, not introduced by this spec
- `dismiss` — false positive or noise

Record each reviewer's must-fix list separately in orchestrator state — iteration 2+ needs to tell each reviewer which of its own prior findings to verify.

### Step 3: Fix Loop (iterations 2+, focused)

If must-fix findings exist:
- Dispatch fix agent (Sonnet, `agents/fix-code.md`) with all must-fix findings. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff`.
- Extract that diff string and hold it in orchestrator state as `review_iter_M_fix_diff`.
- Commit the fix so HEAD advances for the next review cycle:
  ```bash
  git add -- <files from review_iter_M_fix_diff>
  git commit -m "fix: final-review iter M must-fix"
  ```
  Hooks run normally. If a hook fails, re-dispatch the fix agent with the hook output appended; don't bypass.
- Re-dispatch ALL 5 reviewers (fresh) with `Input Mode: Focused re-review`, that reviewer's own prior must-fix findings, and `review_iter_M_fix_diff`. Do NOT re-send the full worktree diff.
- Re-triage the new findings (still deduplicate across reviewers).
- **Circuit breaker:** 3 full review cycles maximum.
- If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.

### Step 4: Human Sign-Off

Present to user:
- Summary of what was built (phases, files, test counts)
- Final review results (clean or deferred items)
- Request approval to merge

### Step 4.5: Reflection

Read the `reflection` key from `.spec-flow.yaml` (valid values: `auto`, `off`; default `auto`). If `off`, skip this step entirely and proceed directly to Step 5 with no reflection inputs (Step 5 falls back to free-form authoring).

In `auto` mode, dispatch two reflection agents concurrently (read-only, Sonnet). Execute dispatches each with the resolved `<prd-slug>` and `<piece-slug>` context — the reflection agents themselves own the writes to their respective backlog targets per the v3 path conventions:

- **Process-retro** writes to the global `<docs_root>/improvement-backlog.md` (cross-PRD process learnings).
- **Future-opportunities** writes to the PRD-local `<docs_root>/prds/<prd-slug>/backlog.md` (PRD-scoped deferred work).

```
Agent({ description: "Process retro for <prd-slug>/<piece-slug>", prompt: <process-retro composed>, model: "sonnet" })
Agent({ description: "Future opportunities for <prd-slug>/<piece-slug>", prompt: <future-opportunities composed>, model: "sonnet" })
```

**Process-retro prompt context:**
- Session-end metrics summary (per the Measurement section — Build duration, Build token count, Verify mode chosen, Refactor skipped, QA iteration count, Step 6b outcome, Phase Group auto-triage outcomes if any group ran)
- Per-phase escalation log (every circuit-breaker hit, BLOCKED report, contamination event, scope violation observed during the piece)
- Plan structure (plan.md's phase outline)
- Cumulative diff (`git diff $piece_start_sha..HEAD`)
- Target: `<docs_root>/improvement-backlog.md` (the agent appends here)

**Future-opportunities prompt context:**
- Final spec for this piece (with acceptance criteria, including any deferred ACs)
- Final plan (with `NOT COVERED` rows from Build's AC matrix)
- Cumulative diff (`git diff $piece_start_sha..HEAD`)
- Current `<docs_root>/prds/<prd-slug>/backlog.md` contents, OR the literal string "(file does not exist yet)" if absent
- `<docs_root>/prds/<prd-slug>/manifest.yaml`
- Target: `<docs_root>/prds/<prd-slug>/backlog.md` (the agent appends here)

Wait for both agents to complete. Each reflection agent appends its findings to its own target file in this format:

```
## <prd-slug>/<piece-slug> — <YYYY-MM-DD>

<reflection output verbatim — emits ### Process retro for <prd-slug>/<piece-slug> or ### Future opportunities for <prd-slug>/<piece-slug> at H3>

---
```

Commit the backlog appends as a single reflection commit on the worktree branch (this lands BEFORE Step 5's learnings.md commit so that even if Step 5 fails, the raw findings are preserved):

```bash
git add <docs_root>/improvement-backlog.md <docs_root>/prds/<prd-slug>/backlog.md
git commit -m "reflection: <prd-slug>/<piece-slug> — append findings to backlogs"
```

Hold both reflection outputs in orchestrator state for Step 5 synthesis.

### Step 5: Capture Learnings

Synthesize a human-readable `learnings.md` from the reflection findings (Step 4.5 outputs) + the cumulative diff. The synthesized doc focuses on narrative — what worked, what to repeat, what to change next time — not raw findings (those live in the improvement backlog from Step 4.5).

Write `docs/prds/<prd-slug>/specs/<piece-slug>/learnings.md` on the worktree branch with sections:
- Patterns that worked well
- Issues QA caught
- Recommendations for future specs

If Step 4.5 was skipped (`reflection: off`), fall back to pre-v1.5 behavior: orchestrator (or human) authors `learnings.md` directly without reflection-agent input, using the cumulative diff and any session-end observations as the only inputs.

Commit on worktree branch before merge:

```bash
git add docs/prds/<prd-slug>/specs/<piece-slug>/learnings.md
git commit -m "learnings: <prd-slug>/<piece-slug>"
```

### Step 6: Merge

```bash
git checkout main
git merge --squash execute/<prd-slug>-<piece-slug>
git commit -m "execute/<prd-slug>-<piece-slug>: <summary of what was built>"
git worktree remove {{worktree_root}}
git branch -d execute/<prd-slug>-<piece-slug>
```

If merge conflicts: escalate to human.

### Step 7: Update Manifest

Update `docs/prds/<prd-slug>/manifest.yaml` on main: piece status → `merged` (or the `done` alias), update coverage section. Commit.

## Escalation Rules

- Agent reports BLOCKED → escalate to human
- 3+ QA loops on same finding → escalate (architectural issue)
- Implementer can't pass its oracle (green tests in Mode: TDD, plan `[Verify]` command in Mode: Implement) after 2 attempts → escalate
- Missing or invalid `Mode:` flag in the implementer's prompt → the orchestrator must not dispatch; fix the composition
- Phase has both `[TDD-Red]` and `[Implement]` markers, or neither → escalate (malformed plan)
- Test files modified during Implement (Mode: TDD) or Refactor (detected via the Step 3.7a content-hash integrity check against `phase_N_red_stage_manifest`, re-run after Refactor) → reject and escalate
- Parallel agents modify shared file → reject, re-dispatch sequentially
- Merge conflicts → escalate

## Session Resumability

Progress tracked via [x] checkboxes in plan.md:
- Resume reads plan.md, finds first unchecked checkbox
- Completed phases skip
- In-progress phase resumes from first unchecked step
- Phase-start SHA is recovered on resume via `git rev-parse HEAD` — phases do not commit internally, so HEAD stays anchored at phase start until Step 7 runs. For phase 1, the phase-start SHA equals the HEAD when execute began (also the current HEAD on resume). Progress commits from prior phases advance HEAD, so each resumed phase still sees its own phase-start SHA at HEAD.
- Mid-QA-iteration state (fix diffs from prior iterations) is NOT persisted. On resume inside a QA loop, restart at iteration 1 (full review) rather than reconstructing.
- Pre-flight snapshot and pre-decisions are NOT persisted. On resume before Step 2 or 3, re-run Step 1b — it's cheap and ensures LOC/symbol facts aren't stale from earlier in the session.

## Measurement

At session end, emit a summary with per-phase **Build duration**, **Build token count**, **Verify mode chosen** (Audit vs Full), **Refactor skipped** (auto-skip predicate matched), **QA iteration count** (iter-1 / iter-2 / iter-3 mix per phase), **Step 6b outcome** (pass / autofix / fix-code dispatched), **mid_piece_opus_pass** (`dispatched` with iteration count / `not-triggered` / `escalated`), and **deferred_findings_recorded** (count of `Deferred to reflection:` stubs written to backlog across all QA iterations for this piece). Observable properties:

1. Build token count is materially lower than a comparable-scope phase would have been without pre-flight digests and scoped QA prompts — pre-flight facts + pitfall checklist reduce agent rediscovery and self-iteration.
2. Build tool-use count drops commensurately.
3. Verify: majority of clean-Build phases use Audit mode (3–5 min) rather than Full (10–15 min). Driven by Step 3's AC matrix gate — a clean matrix unlocks Audit.
4. Step 6b passes cleanly on the majority of phases (no-op), because per-commit hooks caught issues at each intermediate commit rather than letting them accumulate.
5. Refactor is skipped on clean-Build phases; QA iterations run until reviewer returns must-fix=None or the 3-iter circuit breaker fires.

If (1)/(2) don't hold on two consecutive large phases, something other than the pre-flight inefficiencies is dominating — re-audit before adding more machinery. If (3) doesn't hold, inspect Implement's AC coverage matrix — the matrix is likely incomplete or inconsistent, forcing Full mode unnecessarily. If Step 6b consistently dispatches fix-code, the project's pre-commit config includes checks that depend on full-repo context (e.g. global mypy or whole-repo type checking); move those to pre-push.

## Known costs and caveats

- **Pre-flight on monorepos.** `git grep` across a very large repo is slow. Scope probes to the phase's declared scope directories and use path filters. If a probe would take more than a few seconds, skip it and let the agent rediscover — pre-flight is an optimization, not a correctness gate.
- **Per-commit hook cost.** Every intermediate commit runs hooks, so the project's pre-commit config needs to be cheap: lint + format + type-check on small diffs, not whole-repo or test-suite runs. A ~5s/commit hook cost × 5 intermediate commits/phase = negligible. Move expensive checks (full test suites, whole-repo type checks, documentation builds) to `pre-push` or run them as explicit orchestrator gates between phases. The README covers pre-commit config shape.
- **Phase-size outliers are out of scope here.** These changes reduce *avoidable* work inside Implement. A phase with 1700+ LOC and five new files is expected to be expensive — the root fix for oversized phases lives in the `plan` skill (phase budgeting), not here.

## Graceful Degradation

If the Agent tool is unavailable, perform all steps sequentially in the main window. The mode-specific doctrine (TDD or Implement) and QA checklists still apply. This loses context isolation but preserves workflow gates.
