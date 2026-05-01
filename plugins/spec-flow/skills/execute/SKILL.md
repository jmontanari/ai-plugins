---
name: execute
description: Use when a plan is approved and ready for implementation. Orchestrates each phase via a single implementer agent that runs in TDD mode or Implement mode based on the plan's track (config/infra/glue code uses Implement mode, behavior-bearing code uses TDD), runs QA gates between phases, and triggers a 5-agent final review before merging. The main window writes zero implementation code. Use this whenever the user wants to execute, implement, or run a spec-flow plan — regardless of whether the plan uses TDD or not.
---

# Execute — Orchestrate Plan Implementation

Execute an approved plan phase by phase using dedicated agents for each step. Each phase runs in Mode: TDD or Mode: Implement based on the plan's chosen track, with QA gates at every boundary and a 5-agent final review before merge.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

**Integration config load.** If `integrations.issue_tracker.enabled: true`, read
`<docs_root>/charter/<charter_file>.md` (default `charter/integrations.md`) for transition
rules and commit format. Store as `integration_cfg`. If disabled or absent, set
`integration_cfg = null` and skip all integration steps in this skill.

## Prerequisites

- Piece must have status `planned` in manifest at `docs/prds/<prd-slug>/manifest.yaml`
- `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` must exist and be approved
- Must be on the worktree branch `piece/<prd-slug>-<piece-slug>` at `{{worktree_root}}/` (resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>/` at dispatch time — see `plugins/spec-flow/reference/v3-path-conventions.md`). This branch and worktree are created by the spec skill and persist through plan and execute. Slug validity for both `<prd-slug>` and `<piece-slug>` is enforced by `plugins/spec-flow/reference/slug-validator.md` before any worktree or branch is created — cite, don't restate.
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

Before the first phase runs (and only on a fresh start, not a resume), update the PRD's manifest **on the piece branch** to mark this piece's status as `in-progress` (per the spec's piece-status state machine). Skip if it's already `in-progress` (resumed session). The piece branch is already the active working branch — no checkout is needed.

```bash
# update docs/prds/<prd-slug>/manifest.yaml: set this piece's status to "in-progress"
git add docs/prds/<prd-slug>/manifest.yaml
git commit -m "manifest: mark <prd-slug>/<piece-slug> as in-progress"
```

This commit lives on the piece branch. Main's manifest retains `planned` until the branch is merged (via squash or PR), at which point main receives the correct terminal state in one step. The `status` skill discovers the correct `in-progress` state by scanning active piece-branch worktrees (see Status skill, AC-7).

## Phase 1: Load Context + Charter Drift + Dependency Preconditions

Before the Phase Scheduler dispatches any phase, execute resolves `<prd-slug>` and `<piece-slug>` (from the user argument or by scanning `docs/prds/*/manifest.yaml` for the named piece), loads the plan at `docs/prds/<prd-slug>/specs/<piece-slug>/plan.md` and spec at `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md`, then runs the four gates below in order.

### 1a. Charter-drift check (always applies — runs first)

A piece reaching execute stage already has a spec carrying a `charter_snapshot:` front-matter and a plan aligned to that snapshot. Before any phase dispatch, run the charter-drift check per `plugins/spec-flow/reference/charter-drift-check.md` against the spec's `charter_snapshot:` and the live `<docs_root>/charter/` files. If drift is detected, halt Phase 1 and escalate per the reference doc — do not dispatch phases against stale charter constraints.

### 1b. Path resolution

All paths below resolve against `plugins/spec-flow/reference/v3-path-conventions.md`. In particular:

- Manifest: `docs/prds/<prd-slug>/manifest.yaml`
- Spec / plan: `docs/prds/<prd-slug>/specs/<piece-slug>/spec.md` and `plan.md`
- Worktree: `{{worktree_root}}/` (resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>/` — see `plugins/spec-flow/reference/v3-path-conventions.md`)
- Branch: `piece/<prd-slug>-<piece-slug>`
- Reflection targets (cited for Step 4.5 routing): process-retro findings route to `docs/improvement-backlog.md` (global); future-opportunities findings route to `docs/prds/<prd-slug>/backlog.md` (PRD-local). As of v3.2.0 (pi-010-discovery), reflection agents emit structured findings to the orchestrator — they do NOT write to these paths directly. The orchestrator routes each finding through Step 6c, and only the operator-chosen defer resolution writes to the target path via `/spec-flow:defer`.

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

**Integration — transition phase task to In Progress (if `integration_cfg != null` and `auto_transition: true`):**
Read the `jira_task:` field immediately following this phase's heading in plan.md. If present,
run the capability check (`plugins/spec-flow/reference/integration-capability-check.md`) for
operations `get_transitions` and `transition_task`. If available, transition the task to the
"phase execute starts" status from `integration_cfg` (default: `In Progress`).
Store the issue key as `phase_issue_key` — it will be prepended to commit messages per
`commit_tag_format` from `integration_cfg` (default: `[{issue_key}]`).
On tool unavailable → emit warning → skip. `phase_issue_key` remains null; commit messages are unaffected.

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
    - **Mode: TDD:** After the oracle passes and post-commit gates are clean, validate the Build report's `## AC Coverage Matrix` section. See `plugins/spec-flow/reference/ac-matrix-contract.md` for the schema and parsing rules. The orchestrator enforces every rule documented there, including the `Reason:` field for deferred rows. In short: reject + re-dispatch (within the 2-attempt oracle budget above) per the contract's validation rules — missing matrix, incomplete in-scope coverage, bare `NOT COVERED`, vague `covered` pointer, deferred row missing `Reason:`, or invalid `Reason:` value. Refusal strings for the two `Reason:`-related rejections are defined verbatim in the contract's "Refusal contracts" section and MUST be emitted as written. Clean matrix → proceed to the Reason-routing sub-step below. If validation fails twice, escalate — the plan likely has ambiguity about phase AC assignment. After validation, persist Build's `## AC Coverage Matrix` to orchestrator state as `phase_<id>_ac_matrix`, where `<id>` is the phase identifier (e.g., `phase_2`, `phase_3`, `group_a_subphase_a1`, `phase_group_a` for the union, etc.) — the orchestrator chooses a unique identifier per phase or sub-phase. Keys never collide; multiple phases produce multiple keys. Used by Step 0a's mid-piece dispatch.

      **Reason-field routing (v3.6.0+).** After the matrix passes the validation rules above, scan every accepted row whose `Status` starts with `NOT COVERED — deferred` and dispatch on its `Reason:` value per the contract's "Reason interpretation" section:

      - **`Reason: does-not-block-goal`** — PAUSE the phase and emit the inline operator prompt `Phase claims AC <id> can defer without blocking <piece>'s goals — confirm? (y/n)`. On `y`, accept the deferral and continue scanning further rows. On `n`, treat the matrix as rejected and re-dispatch Build within the existing 2-attempt oracle budget defined above (the same budget that covers oracle retries — `does-not-block-goal` rejection consumes a slot from it; it is not a separate budget).
      - **`Reason: requires-amendment`** — record the row in orchestrator state under the new key `phase_<id>_routed_discoveries` (same `<id>` convention as `phase_<id>_ac_matrix`) with `amend` as the default triage option. Do NOT pause; continue scanning. Step 6c consumes this key during discovery triage.
      - **`Reason: requires-fork`** — record the row under `phase_<id>_routed_discoveries` with `fork` as the default triage option. Do NOT pause; continue scanning. Step 6c consumes this key.

      The persisted `phase_<id>_routed_discoveries` value is a list — multiple rows from the same phase are appended in the order they appear in the matrix; subsequent phases produce sibling keys and Step 6c reads all of them when it runs. If no rows trigger routing the key is simply absent for that phase. Operator confirmation under `does-not-block-goal` is logged in the dispatch log alongside the Audit/Full mode decision so session summaries can report deferral confirmations.

      **Legacy opt-out (`legacy_deferred_rows: true`).** If the plan's front-matter sets `legacy_deferred_rows: true` (per `plugins/spec-flow/templates/plan.md`), the validation rule that requires deferred rows to carry a `Reason:` field is silenced for the duration of that piece — the matrix is accepted with the `Reason:` column empty or absent. All other validation rules remain in force. The Reason-field ROUTING above STILL fires under the legacy flag if a Build agent populates a valid `Reason:` value. The flag silences the *format check*, not the *routing*. The flag is deprecated and will be retired in v3.7.0; see the contract's "Legacy mode" section for the full migration story.

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
   - **Compose fix-code context.** Before dispatching, check whether the spec includes a `## Technology Notes` or `### Behavior Notes` section documenting platform-specific idioms (e.g., for Ansible: "set_fact always returns ok — notify requires a task that reports changed; always: blocks run before rescue"). If such a section exists, prepend it verbatim as a `## Platform behavior` block at the top of the fix-code prompt — before the findings list. This prevents the fix agent from burning iterations on regressions caused by well-known platform idioms it would otherwise have to infer from context. If no such section exists in the spec but the stack is identifiable (from file extensions, tool names in plan, or charter tools.md), inject a one-line reminder of the most common gotcha for that stack.
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

2. **Surface the finding to Step 6c, do NOT auto-write a backlog stub.** Per the CAP-F invariant established in Phase 1 of pi-010-discovery, `/spec-flow:defer` is the sole supported path for backlog writes — there is no orchestrator-side auto-append code path for `Deferred to reflection:` findings. Each parsed finding becomes a record on the per-phase discovery list that Step 6c aggregates (see Step 6c "Aggregation" item 2: `default_triage: "defer"`, `source_agent: "qa-phase"` (or `qa-phase-lite`), `row_text` = the QA finding's one-line summary). The operator triages it at Step 6c — only after the operator chooses `defer` does the orchestrator invoke `/spec-flow:defer`, which writes the backlog entry and commits it itself per Step 6c "Defer dispatch". The same surface-to-Step-6c rule applies when `Deferred to reflection:` findings come out of Step 8's Final Review Triage flow — they flow through Step 6c (re-invoked from Step 8 per finding) and reach the backlog only via `/spec-flow:defer`.

3. **Do not block phase progression.** The iter-until-clean loop terminates when must-fix=None. `Deferred to reflection:` items are NOT counted as must-fix findings. The phase advances normally once all must-fix findings are resolved, regardless of how many deferred items were surfaced to Step 6c.

4. **Convention, not requirement.** The `Deferred to reflection:` marker is a convention that QA agents may emit voluntarily — per CR-008 + NN-C-008, the agent templates are NOT modified to require or instruct this behaviour. The orchestrator-side parser records whatever the agent emits and forwards it to Step 6c; it never mandates the marker.

**Step 4.5 (end-of-piece reflection)** reads the accumulated backlog file (now populated solely by `/spec-flow:defer` invocations triggered from Step 6c and Step 8) and prompts the user to classify each `[Deferred QA finding]` entry as one of: **incorporated** (resolved within this piece), **deferred** (move to active backlog as a future piece candidate), or **obsolete** (no longer applies).

5. When QA returns must-fix=None:

   **Integration — transition phase task to In Review (if `integration_cfg != null` and `auto_transition: true`):**
   Run the capability check for operation `transition_task`. If available and `phase_issue_key`
   is set, transition the task to the "phase QA passes" status from `integration_cfg`
   (default: `In Review`). On tool unavailable → emit warning → skip.

   Proceed to **Step 6b** (then Step 6c, then Step 7).

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

### Step 6c: Discovery Triage

This step consumes the orchestrator state Step 4's Reason-routing sub-step persists (`phase_<id>_routed_discoveries`) together with the per-phase QA gate's deferred-to-reflection findings and any Build oracle escalations citing missing prerequisites. It runs once per phase, after Step 6b's hook sweep is clean and before Step 7's progress commit, so every discovery surfaced during the phase is triaged into one of three outcomes — amend, fork, defer — before the phase is marked done.

**Amendment budget enforcement.** Before any `amend` (or `amend-spec`) dispatch under this step, the orchestrator checks the per-piece amendment budget (2 amendments total per piece, of which at most 1 may be a spec amendment). See "Amendment budget tracking" below for the counters, refusal strings, and budget-exhaustion escalation flow.

#### Aggregation

Read three sources and combine them into a single ordered discovery list keyed by source agent:

1. `phase_<id>_routed_discoveries` — the Reason-field routed rows persisted by Step 4 (see "Reason-field routing (v3.2.0+)" above). Each element is a structured record with the schema:
   ```
   {
     row_text:      "<verbatim AC matrix row text, including the | separators>",
     default_triage: "amend" | "fork",   # set by Step 4 from the Reason: field
     source_agent:  "<agent that produced the matrix, typically `verify` or `implementer`>",
     ac_id:         "<AC-N as parsed from the row's AC ID column>"
   }
   ```
   Multiple rows from the same phase appear in matrix order. The key is absent when no rows triggered routing in this phase — treat absent as the empty list.

2. **QA findings flagged `Deferred to reflection:` from Step 6.** Step 6's per-phase QA gate, instead of auto-writing such findings to the end-of-piece backlog file at flag time, surfaces them here so they are triaged alongside same-phase discoveries. Each finding becomes a record with `default_triage: "defer"`, `source_agent: "qa-phase"` (or `qa-phase-lite`), and `row_text` set to the QA finding's one-line summary.

3. **Build oracle escalations citing missing prerequisite.** When Steps 2/3's oracle iteration budget is exhausted with the implementer escalating that a prerequisite is missing (rather than a TDD-Red test being wrong, which is a different escalation path), the escalation message is captured here as a discovery with `default_triage: "amend"`, `source_agent: "implementer"`, and `row_text` set to the escalation's one-line summary. Pure oracle-budget exhaustion without a missing-prerequisite citation does NOT come here — it remains a phase-level escalation handled by the orchestrator's existing retry/abort logic.

**Defensive defaults.** Phase 7 (Step 4 Reason-field routing) may persist rows without populating `source_agent` and `ac_id` fields if upstream context is lost. Step 6c MUST handle missing fields defensively: when `source_agent` is absent or empty, substitute the literal string `unknown` in the triage prompt and `.discovery-log.md` row; when `ac_id` is absent or empty, substitute `—` (em-dash). Do NOT halt or escalate on missing fields — the operator can still triage the discovery from `row_text` alone.

**Re-dispatch idempotence.** When the orchestrator re-dispatches Build mid-scan (the `does-not-block-goal: n` rejection path defined in Step 4, or any other Build re-dispatch path), it MUST clear `phase_<id>_routed_discoveries` for this phase before re-running Build. Otherwise the rejected attempt's routed rows would accumulate alongside the re-run's rows, double-counting discoveries against the budget and surfacing stale rows in the triage prompt. The clear is unconditional: routed-discoveries state is per-attempt, not per-phase. Step 6c always sees only the currently-accepted attempt's routed rows for the phase.

If the combined discovery list is empty after aggregation, skip directly to Step 7 — there is nothing to triage.

#### Triage prompt

Present a single aggregated prompt enumerating every same-phase discovery with three options per discovery (per NFR-6: one prompt per phase, not per discovery):

```
<N> discoveries surfaced in <phase-id>:
  [1] <type> from <source-agent>: <finding-summary>
      Options: (a) amend  (f) fork  (d) defer
  [2] <type> from <source-agent>: <finding-summary>
      Options: (a) amend  (f) fork  (d) defer
  ...
Choose for each (or 'A' to amend all that fit < 50% threshold, 'D' to defer all):
```

`<type>` is `requires-amendment`, `requires-fork`, `does-not-block-goal-deferred`, `qa-deferred-to-reflection`, or `missing-prerequisite` per the discovery's source. `<source-agent>` is the record's `source_agent` field. `<finding-summary>` is a one-line summary derived from `row_text` (truncate at ~80 columns; the full text remains in `phase_<id>_routed_discoveries` for the dispatched agents to read in full).

A fourth option, `(s) amend-spec`, is offered ONLY for discoveries whose finding text names a missing FR/AC or contradiction in the spec — these are the only discoveries where amending the spec is the correct lever rather than amending the plan. The orchestrator gates this option by inspecting the `row_text` for spec-shaped citations (`FR-`, `AC-`, "contradicts spec", or equivalent); if none are present, `(s)` is not offered for that discovery.

**Aggregate shortcuts decompose into per-discovery dispatches.** The `'A'` (amend all that fit < 50% threshold) and `'D'` (defer all) shortcuts are input sugar — they decompose into the same per-discovery dispatch flow as if the operator had typed `(a)` or `(d)` for each discovery individually. There is no batched-amend or batched-defer code path. `'A'` produces one `plan-amend` (or `spec-amend`) dispatch and one `chore(plan): amend` (or `chore(spec): amend`) commit per amended discovery; `'D'` produces one `/spec-flow:defer` invocation and one `chore: defer` commit per deferred discovery. Per-discovery `.discovery-log.md` rows append per the Resolution-commit cell convention (below) regardless of which input form was used.

#### Auto-mode threshold (FR-17)

When execute is invoked with `--auto`, each discovery in the aggregated triage list is evaluated independently against the auto-amend threshold at the moment the discovery surfaces. **Per-discovery evaluation:** threshold breaches do NOT lock subsequent discoveries into operator-required mode — each subsequent discovery is evaluated independently against the cumulative diff size *as of when that discovery surfaces*, even if an earlier discovery in the same triage event escalated to operator prompt. The auto-mode default state is preserved across discoveries; only the specific discovery whose ratio exceeded the threshold falls back to operator prompt.

**Threshold computation.** For each discovery:

```
ratio = <estimated-absorption-size> / <cumulative-diff-size>
```

where:
- `<estimated-absorption-size>` is the LOC value parsed from the discovery report's `Estimated absorption size` field (the value upstream agents emit when reporting a `requires-amendment` / `requires-fork` / `does-not-block-goal-deferred` / `qa-deferred-to-reflection` / `missing-prerequisite` discovery).
- `<cumulative-diff-size>` is the running total LOC of the piece's diff so far, computed as `git diff --shortstat $piece_start_sha..HEAD` (insertions + deletions) at the moment the discovery surfaces.

**Edge case: `<cumulative-diff-size>` is zero.** When a discovery surfaces before any production-code commits have landed (e.g., a Step 4 Reason-routed discovery during phase 1 before the implementer's unified commit, or a Build oracle "missing prerequisite" escalation from Step 2/3 of the first phase), `git diff --shortstat $piece_start_sha..HEAD` returns 0/0 and the ratio is undefined. In that case the orchestrator treats the ratio as **infinity** (escalate) rather than zero (auto-amend) — the conservative interpretation: with no cumulative work yet, ANY absorption-size LOC value is "large relative to nothing," and the operator should weigh in before auto-amending an empty piece. The orchestrator emits a CARVE-OUT escalation message (NOT the standard ratio-based message at line 674 below) with this verbatim text:

```
Discovery in <phase> surfaced before any cumulative diff exists — auto-amend cannot evaluate threshold. Operator triage required.
```

where `<phase>` is the discovery's source phase ID. After emitting this message the orchestrator falls back to the operator-mode triage prompt for that discovery only; subsequent discoveries in the same triage event remain in auto-mode and are evaluated independently per the per-discovery rule (each subsequent discovery may have a non-zero cumulative diff if the first discovery's resolution committed work in between).

**Auto-amend if `ratio < 0.5`.** The orchestrator dispatches the amend flow (plan-amend by default; spec-amend only when the discovery's `(s) amend-spec` option would have been offered per the Triage prompt rules — i.e., the finding text names a missing FR/AC or contradiction in the spec) without operator prompting. The Amendment budget tracking gate still applies — auto-mode does NOT bypass the 2-total / 1-spec-max budget; if the budget is exhausted the auto-amend dispatch is refused exactly as in operator mode.

**Otherwise (`ratio ≥ 0.5`) auto-mode escalates** with the verbatim message:

```
Discovery in <phase> would expand piece by <X>% — exceeding 50% auto-amend threshold. Operator triage required.
```

where `<phase>` is the discovery's source phase ID and `<X>` is `ratio × 100` rounded to one decimal place. After emitting this message the orchestrator falls back to the operator-mode triage prompt (the Triage prompt block above) for THAT discovery only; subsequent discoveries in the same triage event remain in auto-mode and are evaluated independently per the per-discovery rule above.

**Auto-mode never auto-forks or auto-defers.** Fork and defer always require operator triage, regardless of any threshold computation. The auto-mode default applies exclusively to the `amend` choice (and only when `ratio < 0.5`). When the operator-mode triage prompt fires under auto-mode (because of threshold escalation), the operator's choice can still be fork or defer — auto-mode does not constrain the operator's selection, only the auto-resolution path.

#### Amend dispatch

For each discovery the operator routes `amend` (or `amend-spec`):

1. **Plan amendments — dispatch `plugins/spec-flow/agents/plan-amend.md` (Phase 4 output)** with the current `plan.md`, the structured discovery report (the full record from the aggregation list — `row_text`, `default_triage`, `source_agent`, `ac_id`), and the diff+neighborhood scope. Compute scope by enumerating phases whose `[Implement]` or `[Build]` blocks touch any file the discovery references — exact file path match, not shared directory, per FR-11 (`auth/login.py` does not pull in scope phases that touch `auth/logout.py`).

2. **Extract the unified diff** from the agent's `## Diff of changes` section by parsing everything between that heading and the next `##`-or-EOF boundary (mirroring the `fix-doc` agent's diff-extraction pattern already used elsewhere in execute).

3. **On `(none)`:** the agent determined no plan edit is needed — the discovery is actually a Build correctness issue. Re-dispatch Build for the original phase with the discovery as additional context. This Build re-dispatch follows the same `phase_<id>_routed_discoveries` clear-before-rerun rule defined under Aggregation above.

4. **On non-empty diff:** write the diff to a temporary file and run:
   ```bash
   git apply --check <tmpfile>
   ```
   This validates the diff applies cleanly without modifying the working tree. **On failure**, halt with the exact refusal string:
   ```
   Refused — plan-amend diff did not apply cleanly: <git apply stderr>
   ```
   and prompt the operator to re-dispatch plan-amend. This re-dispatch counts as a fresh dispatch within the same triage event but does NOT consume an additional budget slot for the same discovery (the discovery itself only consumes one slot regardless of how many plan-amend attempts it takes to produce a clean diff).

5. **On success:**
   ```bash
   git apply <tmpfile>
   ```
   **Post-check apply failure.** If `git apply --check` passed but `git apply <tmpfile>` itself fails (concurrent worktree edit, FS race, hook side-effect), halt with `Refused — plan-amend diff failed to apply after passing --check; worktree may be in partial state, manual intervention required.` Do NOT auto-retry; manual intervention is required because the worktree state is undefined. The "no extra budget slot" provision (above) does not extend to this case — recovery requires operator inspection.

   Then dispatch `qa-plan` with `Input Mode: Focused re-review` and the diff as context, iterating until clean per `plugins/spec-flow/reference/qa-iteration-loop.md`. When qa-plan returns clean, append the discovery row to `.discovery-log.md` (see ".discovery-log.md authoring" below — orchestrator stages this file for plan/spec amendments), then commit the amendment with conventional-commits chore type per CR-004:
   ```bash
   git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
   git add docs/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md
   git commit -m "chore(plan): amend — <reason — discovery summary>"
   ```
   The `<reason>` is the discovery's `default_triage`-implied reason (`requires-amendment`, etc.) plus the one-line finding summary. Both files land in the same commit, producing a single coherent amend-with-audit-trail entry in `git log`.

6. **Resume execution at the first amendment phase** using the suffix-form ID convention `phase_<N>_amend_<K>` per FR-13, where `<N>` is the original phase ID and `<K>` is the 1-indexed amendment counter for that phase (`phase_3_amend_1`, `phase_3_amend_2` if the amendment introduced two new phases, etc.). Amendment phases run through the full Per-Phase Loop including their own Step 6 QA gate (see "NN-P-002 preservation" below).

7. **Spec amendments — dispatch `plugins/spec-flow/agents/spec-amend.md` (Phase 5 output)** when the operator chose `amend-spec`. Apply the same extract → `git apply --check` → `git apply` → qa-spec re-dispatch (iter-until-clean) → commit flow, with the commit message:
   ```
   chore(spec): amend — <reason — discovery summary>
   ```
   The `(s) amend-spec` option is only offered when the discovery's finding text names a missing FR/AC or contradiction (see Triage prompt above). After a spec amendment, the orchestrator re-runs the plan-drift check against the amended spec before resuming phase dispatch — a spec edit may invalidate plan assumptions and require a follow-up plan amendment.

   **Multiple-amend batching.** When the operator chooses amend for multiple discoveries in a single triage event, the orchestrator dispatches `plan-amend` (or `spec-amend`) once per discovery, producing one `chore(plan): amend — <reason>` (or `chore(spec): amend — <reason>`) commit per discovery with its corresponding `.discovery-log.md` row appended. No batched-amend code path; each amend dispatch is independent.

#### Fork dispatch

For each discovery the operator routes `fork`:

1. Author a new piece entry in `docs/prds/<prd-slug>/manifest.yaml` with `depends_on: [<current-piece-slug>]` (a qualified manifest reference pointing back at the currently-executing piece). The new piece's slug is operator-supplied at fork time; status starts as `open` per the manifest piece-status state machine.

2. Set the **current piece's** status to `blocked` in the same manifest update, with a notes-line citing the fork reason (the discovery's one-line summary).

3. Append the discovery row to `.discovery-log.md` (see ".discovery-log.md authoring" below — orchestrator stages this file for fork resolutions), then commit the manifest update on the current worktree branch:
   ```bash
   git add docs/prds/<prd-slug>/manifest.yaml
   git add docs/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md
   git commit -m "chore(<piece-slug>): fork — <reason — discovery summary>"
   ```
   Both files land in the same commit — the `.discovery-log.md` row and the manifest update together form the complete fork record.

4. Halt execute with the operator-facing message:
   ```
   Forked: new piece <new-piece-slug> created with depends_on chain. Spec the prerequisite first, then resume <current-piece>.
   ```

#### Defer dispatch

For each discovery the operator routes `defer`:

1. Invoke `/spec-flow:defer` (Phase 1 output of pi-010-discovery) using its structured-invocation form, passing: source piece, source phase, source agent, finding text (full `row_text`), operator-supplied rationale, and `discovery_type` (the discovery's original classification — e.g. `requires-amendment`, `does-not-block-goal` — so the defer skill can populate the Discovery type column of `.discovery-log.md` accurately).

2. The defer skill writes the entry to the active backlog and commits it itself with a message of the form `chore(<piece-slug>): defer <finding-summary>`. The `.discovery-log.md` row append lands as part of THAT commit (the defer skill is responsible for the row append in the defer path, since it owns the resolution commit).

   **Multiple-defer batching.** When the operator chooses defer for multiple discoveries in a single triage event, the orchestrator invokes `/spec-flow:defer` once per discovery, producing one commit per discovery with a single `.discovery-log.md` row appended. No batched-defer code path; each invocation is independent.

3. Execute continues to Step 7 (phase commit) without further state changes — defer does not introduce amendment phases and does not alter the manifest beyond the backlog write the defer skill performs.

#### Amendment budget tracking

Per FR-14, each piece has a hard amendment budget: **2 amendments total per piece, of which at most 1 may be a spec amendment.** The budget is piece-scoped — the counters survive across all phases of the piece (including amendment phases that pi-010-discovery's FR-13 introduces). They are NOT phase-scoped and they are NOT triage-event-scoped; an amendment dispatched in phase 3's Step 6c counts against the same budget as an amendment dispatched in phase 7's Step 6c or via Step 8's Final Review Triage flow.

**Counters.** The orchestrator maintains two integer counters in piece-scoped state:

- `piece_amendment_count` — total amendments dispatched (plan + spec combined). Initialized to `0` at piece start.
- `piece_spec_amendment_count` — spec amendments only. Initialized to `0` at piece start.

**Counter recovery on session resume.** Per Session Resumability conventions (below), in-memory orchestrator state is not persisted across session boundaries. On execute resume mid-piece (the orchestrator finds plan.md checkboxes partially marked), the counters MUST be recovered by counting committed amendments in the worktree branch's history rather than re-zeroed:

- `piece_amendment_count` = `git log --oneline $piece_start_sha..HEAD --grep '^chore(plan): amend' --grep '^chore(spec): amend' | wc -l`
- `piece_spec_amendment_count` = `git log --oneline $piece_start_sha..HEAD --grep '^chore(spec): amend' | wc -l`

This counts only successful amend commits (failed dispatches produce no commit and correctly don't show in the log). Use `--all-match` only if the grep patterns must AND together; for OR semantics (any one of the patterns) the default disjunctive behavior is correct. Run these recovery commands at the same time the orchestrator captures `phase_<n>_start_sha` from `git rev-parse HEAD` — both are lossless reconstructions from the durable worktree.

**Pre-dispatch budget check.** Before invoking `plan-amend` or `spec-amend` for any discovery (whether operator-chosen or auto-resolved under `--auto`), the orchestrator checks the budget:

1. If `piece_amendment_count >= 2`, refuse the dispatch with the budget-exhaustion escalation prompt (below). Do NOT dispatch the amend agent.
2. If the choice is `amend-spec` AND `piece_spec_amendment_count >= 1`, refuse with the verbatim string:
   ```
   Refused — spec-amend budget exhausted (1/1); choose plan-amend, fork, or defer.
   ```
   and re-prompt the operator at the Triage prompt for THIS discovery only (other discoveries in the same triage event are unaffected). The discovery itself does NOT consume a budget slot when refused — only successful dispatches increment counters.

**Counter increment on successful amend.** The counters are incremented only after the amend dispatch produces a successful commit (the `chore(plan): amend — ...` or `chore(spec): amend — ...` commit lands cleanly per Amend dispatch step 5/7). The increment rules:

- For ANY successful amend (plan or spec): `piece_amendment_count++`.
- ADDITIONALLY for a successful spec amend: `piece_spec_amendment_count++`. Spec amendments increment BOTH counters — they consume one slot of the 2-total budget AND the 1-spec-max sub-budget.

A failed amend (diff fails `git apply --check` and the operator chooses not to re-dispatch, or the dispatched agent halts with BLOCKED) does NOT increment either counter. The "no extra budget slot for re-dispatch within the same triage event" provision under Amend dispatch step 4 means: a discovery's amend dispatch consumes one slot total, regardless of how many plan-amend/spec-amend invocations the orchestrator runs to produce a clean diff for that one discovery.

**Budget-exhaustion escalation prompt.** When `piece_amendment_count >= 2` blocks an amend dispatch, the orchestrator prompts the operator with the verbatim string:

```
Amendment budget exhausted — piece scope was inadequate. Escalating: abandon and re-spec from scratch is recommended. Continue anyway? (y/n)
```

This is a y/n confirmation gated by NN-C-006 (operator confirmation required for destructive or piece-state-changing operations).

- **On `y`:** the orchestrator continues execution with **no further amendments allowed**. Subsequent discoveries — whether in the current triage event, later phases, or Step 8's Final Review Triage — may only choose `fork` or `defer`. The `(a) amend` and `(s) amend-spec` options are no longer offered. Auto-mode under `--auto` falls back to the operator prompt (since auto-amend cannot dispatch) and the operator must choose fork or defer.
- **On `n`:** the orchestrator halts execute. It sets the current piece's status to `blocked` in `docs/prds/<prd-slug>/manifest.yaml` with a notes-line citing budget exhaustion (the operator's `n` response constitutes the explicit confirmation NN-C-006 requires; this is therefore not a destructive operation without confirmation). It commits the manifest update on the current worktree branch:
  ```bash
  git add docs/prds/<prd-slug>/manifest.yaml
  git commit -m "chore(<piece-slug>): block — amendment budget exhausted"
  ```
  and exits with the operator-facing message:
  ```
  Halted: piece <piece-slug> status set to blocked (amendment budget exhausted). Re-spec or abandon recommended.
  ```

The budget-exhaustion check fires once per amend dispatch attempt; if the operator answers `y` once in a triage event, the orchestrator does not re-prompt for subsequent amend attempts in the same execute session — but the "no further amendments allowed" lock applies regardless.

#### `.discovery-log.md` authoring

For each triaged discovery, append a row to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md`. The file format, per FR-15, is:

```markdown
# Discovery log — <prd-slug>/<piece-slug>

| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
|---|---|---|---|---|---|
| phase_3 | requires-amendment | qa-phase | Auth helper missing X | amend | abc1234 chore(plan): amend — ... |
| phase_4 | does-not-block-goal | verify | AC-7 deferral confirmed | defer | def5678 chore(<piece-slug>): defer ... |
```

If the file does not exist when the first row is appended, create it with the H1 + table header shown above (the H1 uses the live `<prd-slug>` and `<piece-slug>` values). Subsequent rows append below the existing rows in chronological triage order.

**Resolution-commit cell convention.** The orchestrator does NOT pre-compute or amend SHAs into the row. Instead, the row's `Resolution commit` cell records the commit subject (e.g., `chore(plan): amend — auth helper missing X`) which uniquely identifies the commit when grepped (`git log --grep "<subject>"`). The row append is committed in the SAME commit as the resolution itself, but the actor that stages the row depends on the dispatch type:

- **Amend (plan-amend or spec-amend):** the orchestrator stages both `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` and `plan.md` (or `spec.md`) before invoking `git commit`.
- **Fork:** the orchestrator stages both `.discovery-log.md` and `manifest.yaml` before invoking `git commit`.
- **Defer:** the dispatched `/spec-flow:defer` skill (NOT the orchestrator) stages both `.discovery-log.md` and the target backlog file before invoking `git commit` — the defer skill owns its resolution commit per Defer dispatch step 2 above. The orchestrator does not invoke `git commit` in the defer path.

This produces one commit per discovery containing both the resolution and the audit-trail row, without amend-after-the-fact gymnastics, regardless of which actor stages the row.

#### Recursion semantics (FR-12)

**Triage-event boundary.** A triage event is exactly one Step 6c invocation — it begins when Step 6c is entered (at end of Step 6 or from Step 8's Final Review Triage flow) and ends when Step 6c either advances to Step 7 or halts execute. All discoveries triaged within a single Step 6c invocation belong to the same triage event, regardless of how many there are or whether they were operator-chosen or auto-resolved under `--auto`. Amendment phases run through the standard Per-Phase Loop including their own Step 6 → Step 6c flow, so any discoveries surfaced inside an amendment phase reach Step 6c as a NEW triage event (separate from the event that created the amendment phase). Per FR-12, amendments cannot recursively amend within a single triage event; per FR-14 (defined in Phase 9), amendments DO consume the per-piece budget regardless of which triage event creates them.

#### NN-P-002 preservation

Amendment phases run through their own per-phase QA gate (Step 6) before advancing. There is no auto-bypass of QA on the amendment path. The `--auto` mode's amend-without-prompt behavior described under "Auto-mode default" applies to triage CHOICE only (which option to pick — amend/fork/defer), not to QA gates within the amendment phases themselves. NN-P-002 (the two-human-gate non-negotiable: per-phase QA gate + end-of-piece review board) remains intact across amendment cycles.

### Step 7: Mark Progress

Update plan.md: mark all phase checkboxes [x]. Commit:
```bash
git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
# If phase_issue_key is set, prepend the commit_tag_format to the message:
#   git commit -m "[PROJ-42] progress: Phase N complete"
# Otherwise:
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

### Step G9c: Group Discovery Triage (v3.2.0+)

After the hook sweep completes, aggregate all discoveries accumulated during sub-phase execution and Group Deep QA, then route through the standard Step 6c triage flow:

**Aggregation sources (three, same as flat-phase Step 6c):**

1. **Per-sub-phase routed discoveries.** Collect the union of all `phase_<sub_id>_routed_discoveries` keyed entries accumulated during sub-phase Build steps (AC matrix `Reason: requires-amendment` or `Reason: requires-fork` rows). Sub-phase IDs use the dotted form (e.g., `phase_a1_routed_discoveries`, `phase_a2_routed_discoveries` for sub-phases A.1 and A.2).

2. **Group Deep QA deferred findings.** From G8's QA review, collect any findings flagged `Deferred to reflection:` in the QA agent's output (same as flat-phase Step 6a source 2).

3. **Sub-phase Build oracle escalations.** Any Build oracle escalations that cited missing prerequisites during G4 sub-phase execution.

If the combined list is empty (no discoveries from any source), skip Step G9c entirely and proceed to G10.

**Triage:** Dispatch Step 6c once with the aggregated discovery list. Use the source-phase token `group_<letter>` (e.g., `group_a`) for all `.discovery-log.md` rows from this group. The triage options (amend / fork / defer) and rules apply identically to the flat-phase Step 6c — amendment phases added via `amend` in G9c run through the full Per-Phase Loop (not as sub-phases) and then join the queue before G10's progress commit.

**Fork-halt propagation.** If any discovery in the G9c triage event is resolved as `fork`, Step 6c halts execute per the standard Fork dispatch flow (sets piece status to `blocked`, commits the manifest update, prints the "Forked: new piece created" message, and exits). In this case the orchestrator does NOT proceed to Step G10 — the group progress commit does not land. G10 runs only when Step G9c's triage completes with every discovery resolved as `amend` or `defer` (or when the combined list was empty and G9c was skipped).

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

Before dispatching the review board, record that final review is in progress by
updating `plan.md` on the piece branch:

```bash
# Update the **Status:** field in plan.md:
#   **Status:** <current-value>   →   **Status:** final-review-pending
git add docs/prds/<prd-slug>/specs/<piece-slug>/plan.md
git commit -m "plan: <prd-slug>/<piece-slug> final-review-pending"
```

This lets a human inspect `plan.md` and know the piece is in final review without
counting phase checkboxes.

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
- **Compose fix-code context.** Apply the same technology behavior preamble rule as the per-phase QA loop: if the spec includes a `## Technology Notes` or `### Behavior Notes` section, prepend it as a `## Platform behavior` block at the top of the fix-code prompt before the findings list. Final Review fix dispatches are especially prone to regression cascades when platform idioms are unknown — a preamble here pays for itself if more than one fix iteration fires.
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

### Step 8: Final Review Triage

**Trigger.** When Final Review's iter-loop (Steps 1–3) terminates with must-fix findings remaining (the iter-loop's circuit breaker fired or the operator has chosen to triage residual must-fix items rather than continue iterating), the orchestrator invokes Step 8 once before any merge action — i.e., before Step 4 (Human Sign-Off), Step 4.5 (Reflection), Step 5 (Capture Learnings), or Step 6 (Merge). Step 8 also fires when Final Review surfaces non-must-fix discoveries that nonetheless require triage (`requires-amendment`, `requires-fork`, `does-not-block-goal-deferred`, or `qa-deferred-to-reflection` markers from any of the four end-of-piece reviewers — blind, spec-compliance, architecture, edge-case — even when the iter-loop returned must-fix=None overall). If Final Review returns clean across all four reviewers AND no triage-eligible discoveries surfaced, Step 8 is a no-op and execution proceeds to Step 4.

**Per-finding routing.** For each must-fix finding (or triage-eligible discovery) emerging from Final Review, the orchestrator dispatches the Step 6c triage flow per FR-16a. Each finding is processed as a separate Step 6c invocation (one Step 6c invocation = one triage event per the Recursion semantics defined under Step 6c). The triage prompt's source-phase column for `.discovery-log.md` rows is set to the literal token `final-review` (NOT a numeric phase ID — there is no specific upstream phase in Final Review). The source-agent column names which reviewer flagged the finding: `blind`, `spec-compliance`, `architecture`, or `edge-case` (matching the four end-of-piece reviewer roles; the PRD-alignment reviewer's must-fix findings are also routed through Step 8 with `source_agent: prd-alignment`).

**Amendment phase IDs.** Amendment phases inserted via Step 8 use the suffix-form IDs `phase_final_amend_<K>` where `<K>` is the 1-indexed amendment counter for the Final Review triage event (`phase_final_amend_1`, `phase_final_amend_2`, etc.). The originating phase token is the literal string `final` since there is no specific upstream phase. This naming distinguishes Step 8-induced amendment phases from per-phase Step 6c-induced amendment phases (`phase_<N>_amend_<K>` with `<N>` a numeric phase ID per FR-13).

**Amendment budget applies.** Step 8's amend dispatches consume the same per-piece budget as per-phase Step 6c amendments (see "Amendment budget tracking" under Step 6c). If the budget is exhausted at the moment Step 8 fires, the budget-exhaustion escalation prompt fires; the operator's `y`/`n` decision applies to the entire remaining piece including all subsequent Step 8 findings.

**Per-choice flow.**

- **On `amend` (or `amend-spec`):** the piece **re-opens**. The amendment phase(s) inserted as `phase_final_amend_<K>` run through the full Per-Phase Loop including their own Red/Build/Verify/Refactor cycle (where applicable per the amended plan's track) AND their own per-phase QA gate (Step 6) per NN-P-002 preservation. Amendment phases run through QA-phase, Step 6a (deferred-finding surface-to-Step-6c), Step 6b (hook sweep), Step 6c (their own discovery triage, recursing if discoveries surface — bounded by the amendment budget). **Re-entry to Final Review (explicit hand-off).** When the LAST `phase_final_amend_<K>` phase completes its Step 7 (Mark Progress) commit, the orchestrator does NOT advance to "next plan.md phase" (there is none — amendment phases were inserted post-hoc by Step 8). Instead, the orchestrator detects the just-completed phase's ID matches the `phase_final_amend_<K>` pattern and the next phase ID would advance off the end of the amendment-phase chain, then jumps back to Final Review Step 1 (iter-1 full review across all five reviewers: blind, edge-case, spec-compliance, prd-alignment, architecture) on the new cumulative diff `git diff main..HEAD`. The merge gate (Step 6) fires only after the re-run Final Review returns clean (or after a subsequent Step 8 invocation processes its findings). This guarantees NN-P-002's two-human-gate non-negotiable (per-phase QA + end-of-piece review board) survives Step 8's amendment cycle intact.

- **On `fork`:** a follow-up piece is written to `docs/prds/<prd-slug>/manifest.yaml` with `depends_on: [<current-piece-slug>]`, exactly as Step 6c's Fork dispatch specifies. The current piece **merges as-is** with the discovery deferred to the new piece — Step 8's fork choice does NOT re-open the piece and does NOT re-run Final Review. Execution proceeds to Step 4 (Human Sign-Off) once all Step 8 findings have been routed. The current piece's status remains `executing` (or whatever its pre-Step-8 status was); the operator's sign-off at Step 4 is on the merge-as-is artifact with the forked discovery noted.

- **On `defer`:** `/spec-flow:defer` writes a backlog entry to `<docs_root>/prds/<prd-slug>/backlog.md` with the operator-supplied rationale, exactly as Step 6c's Defer dispatch specifies. The piece **advances to merge** — Step 8's defer choice does not re-open the piece and does not re-run Final Review. Execution proceeds to Step 4 (Human Sign-Off) once all Step 8 findings have been routed. The defer skill stages and commits the backlog entry plus the `.discovery-log.md` row as a single commit on the current worktree branch.

**`.discovery-log.md` authoring.** Step 8's per-finding rows append to `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/.discovery-log.md` per the Step 6c Resolution-commit cell convention, with the `Phase` column set to the literal `final-review` token. The row append lands as part of the same commit as the resolution (amend-with-audit-trail, fork-with-audit-trail, or defer-with-audit-trail) per the Step 6c authoring rules.

### Step 4: Human Sign-Off

Present to user:
- Summary of what was built (phases, files, test counts)
- Final review results (clean or deferred items)
- Request approval to merge

**If human APPROVES:** proceed to Step 4.5.

**If human REJECTS (requests rework):**
1. Ask the human which phase(s) need rework.
2. Reset the piece branch to before the targeted phase ran. Use `phase_N_start_sha`
   captured in orchestrator state (Per-Phase Loop Step 1 for Phase N):
   ```bash
   git reset --hard $phase_N_start_sha
   ```
   This cleanly removes Phase N's implementation commits, all later-phase commits, and all
   Final Review commits (fix-code iterations, final-review-pending marker, learnings, etc.).
   If multiple phases need rework, reset to the earliest one's start SHA.
   Phase N's implementation code is now gone — TDD-Red can run cleanly.

   **If `phase_N_start_sha` is not in memory (session restarted during Final Review):**
   recover it from git log — it equals the `progress: Phase (N-1) complete` commit SHA
   (or the oldest commit on the piece branch for Phase 1):
   ```bash
   # For Phase N > 1: match the PREVIOUS phase's progress marker, print its own SHA
   PREV=$((N - 1))
   git log --oneline | awk "/progress: Phase ${PREV} complete/{print \$1; exit}"

   # For Phase 1: the piece branch diverges from main at its merge-base
   git merge-base origin/main HEAD
   ```

3. plan.md is already in the pre-Phase N state after the reset (checkboxes un-ticked by the
   revert). No separate un-ticking commit is needed.
4. Re-enter the Per-Phase Loop at Phase N. Provide the Final Review board's must-fix findings
   as additional context to the Red/Implement agent for the rework.

### Step 4.5: Reflection

Read the `reflection` key from `.spec-flow.yaml` (valid values: `auto`, `off`; default `auto`). If `off`, skip this step entirely and proceed directly to Step 5 with no reflection inputs (Step 5 falls back to free-form authoring).

In `auto` mode, dispatch two reflection agents concurrently (read-only, Sonnet). Execute dispatches each with the resolved `<prd-slug>` and `<piece-slug>` context. As of v3.2.0 (pi-010-discovery Phase 10), the reflection agents emit STRUCTURED FINDINGS reports back to the orchestrator — they do NOT write to backlog files directly. Per the CAP-F invariant established in Phase 1 of pi-010-discovery, `/spec-flow:defer` is the sole supported path for backlog writes; the orchestrator routes each reflection finding through Step 6c on receipt, and only the operator-chosen resolution (defer / amend / fork) produces a commit.

```
Agent({ description: "Process retro for <prd-slug>/<piece-slug>", prompt: <process-retro composed>, model: "sonnet" })
Agent({ description: "Future opportunities for <prd-slug>/<piece-slug>", prompt: <future-opportunities composed>, model: "sonnet" })
```

**Process-retro prompt context:**
- Session-end metrics summary (per the Measurement section — Build duration, Build token count, Verify mode chosen, Refactor skipped, QA iteration count, Step 6b outcome, Phase Group auto-triage outcomes if any group ran)
- Per-phase escalation log (every circuit-breaker hit, BLOCKED report, contamination event, scope violation observed during the piece)
- Plan structure (plan.md's phase outline)
- Cumulative diff (`git diff $piece_start_sha..HEAD`)
- Findings target: emit a structured `## Findings` report to the orchestrator (Phase Group B's `reflection-process-retro.md` agent rewrite owns the report-shape contract). Do NOT write to `<docs_root>/improvement-backlog.md` directly.

**Future-opportunities prompt context:**
- Final spec for this piece (with acceptance criteria, including any deferred ACs)
- Final plan (with `NOT COVERED` rows from Build's AC matrix)
- Cumulative diff (`git diff $piece_start_sha..HEAD`)
- Current `<docs_root>/prds/<prd-slug>/backlog.md` contents, OR the literal string "(file does not exist yet)" if absent
- `<docs_root>/prds/<prd-slug>/manifest.yaml`
- Findings target: emit a structured `## Findings` report to the orchestrator (Phase Group B's `reflection-future-opportunities.md` agent rewrite owns the report-shape contract). Do NOT write to `<docs_root>/prds/<prd-slug>/backlog.md` directly.

Wait for both agents to complete. Each agent's output is a structured `## Findings` block listing zero or more individual findings. **Empty-findings sentinel:** after stripping leading and trailing blank lines from the `## Findings` section body, if the remaining content consists solely of one line that begins with `(no concrete items surfaced` AND no `### Finding` subheadings appear anywhere in the section, treat N=0 for that agent — skip the Step 6c dispatch entirely for that agent's output. Do NOT pass the sentinel string to Step 6c as a discovery. If any `### Finding` subheadings exist (even if one finding's body happens to begin with the sentinel prefix), the section is NOT treated as empty — process each finding normally. Hold both reflection outputs in orchestrator state for Step 5 synthesis (the Step 5 learnings.md commit consumes the same outputs and is unchanged by this rerouting).

#### Routing reflection findings through Step 6c

For each agent's findings, dispatch the Step 6c triage flow with `.discovery-log.md` rows authored using the literal source-phase token `step-4.5-reflection` (mirroring Step 8's `final-review` token convention — there is no numeric phase ID for end-of-piece reflection). The two agents differ in dispatch shape:

- **`reflection-future-opportunities` — per-finding triage.** For each of the N findings, dispatch a SEPARATE Step 6c invocation. Dispatch shape: the orchestrator calls into Step 6c's aggregation step N times, once per finding, each call with a single-item discovery list. This produces N independent triage events sharing the source-phase token `step-4.5-reflection` — sharing the token is permitted because end-of-piece reflection has no numeric phase ID and each invocation is logically independent (resolutions of one finding do not constrain triage of the next). Each finding becomes a discovery record with:
  - `row_text`: the verbatim finding body from the agent's report
  - `default_triage`: `"defer"` (future-opportunities are by nature deferral candidates; the operator may still choose amend or fork per the standard Step 6c options)
  - `source_agent`: `reflection-future-opportunities`
  - `ac_id`: `—` (em-dash — reflection findings are not tied to a specific AC; Step 6c's Defensive defaults handle this)
  - Source-phase column for the `.discovery-log.md` row: `step-4.5-reflection`

  **Auto-mode behavior for future-opps:** because every future-opps finding has `default_triage: "defer"` and Step 6c's auto-mode rule explicitly never auto-defers (only `amend` choices auto-resolve under the < 0.5 threshold), every future-opps finding always falls through to the operator triage prompt under `--auto`. The auto-mode threshold has no effect on future-opps findings — they are surfaced individually and require operator decision. AC-22's "auto-mode applies the threshold per finding" is satisfied by per-finding evaluation reaching the operator-prompt fallback, not by silent auto-resolution. (Auto-mode threshold DOES apply if the operator subsequently chooses `(a) amend` for a future-opps finding — the standard Step 6c amend-vs-escalate logic kicks in at amend-dispatch time, not at finding surface time.)

- **`reflection-process-retro` — single batched triage prompt.** All N process-retro findings are presented in ONE Step 6c invocation as a single batched prompt enumerating all findings. Dispatch shape: the orchestrator calls Step 6c once with a discovery list of size N — Phase 8's per-phase aggregation rule treats this as one phase's worth of discoveries (the source-phase token is `step-4.5-reflection` for all N), so they all surface in a single aggregated prompt. The operator may select per-finding triage actions or use the `'D'` defer-all shortcut. Each finding becomes a discovery record with:
  - `row_text`: the verbatim finding body
  - `default_triage`: `"defer"` (process-retro findings default to backlog deferral; piece-candidate or observation categories may still be triaged as amend / fork)
  - `source_agent`: `reflection-process-retro`
  - `ac_id`: `—`
  - Source-phase column for the `.discovery-log.md` row: `step-4.5-reflection`

  **`'D'` defer-all shortcut scope.** The `'D'` shortcut defers ALL N findings in the batched prompt regardless of their `type` / `category` field — it is whole-batch input sugar per Phase 8's "Aggregate shortcuts decompose into per-discovery dispatches" rule. Because process-retro findings can include `piece-candidate` or `observation` categories that warrant their own amend / fork triage decisions (per the spec rationale at FR-18), the operator should INSPECT the batched prompt before pressing `D`. The prompt enumeration (per Phase 8's Triage prompt format) shows each finding's `<type>` and `<finding-summary>`, allowing category-based inspection. To preserve the friction-vs-insight balance the spec requires for non-process-improvement findings, operators should treat `D` as appropriate only when ALL listed findings are clearly process-improvement category; when piece-candidate or observation categories appear, choose per-finding `(a)` amend / `(f)` fork / `(d)` defer instead. The shortcut decomposes into per-finding `/spec-flow:defer` dispatches per Step 6c's per-discovery rule — one commit per deferred finding, not one batched commit.

#### What gets committed (and what does not)

- **The reflection step itself produces ZERO commits.** The agents emit findings; the orchestrator routes them through Step 6c; the resolution path commits.
- **On `defer` for any reflection finding:** `/spec-flow:defer` writes the backlog entry and commits it itself with a message of the form `chore(<piece-slug>): defer <finding-summary>` per Step 6c's Defer dispatch step 2. The `.discovery-log.md` row append lands as part of THAT commit. Future-opportunities defer targets the PRD-local `<docs_root>/prds/<prd-slug>/backlog.md`; process-retro defer targets the global `<docs_root>/improvement-backlog.md`. Per AC-24, the resulting backlog entry's `**Source:**` line names the originating phase as `step-4.5-reflection` and the agent as either `reflection-future-opportunities` or `reflection-process-retro`.
- **On `amend` / `amend-spec` for any reflection finding:** the standard Step 6c amend dispatch fires — `plan-amend` (or `spec-amend`) agent runs, the amendment commits with `chore(plan): amend` (or `chore(spec): amend`), and amendment phases run through the full Per-Phase Loop. The amendment budget applies (2 amendments total per piece, of which at most 1 may be a spec amendment; reflection findings consume the same budget as per-phase Step 6c amendments).
- **On `fork` for any reflection finding:** the standard Step 6c fork dispatch fires — a follow-up piece is written to `docs/prds/<prd-slug>/manifest.yaml` with `depends_on: [<current-piece-slug>]`.
- **The Step 5 learnings.md commit remains unchanged.** Step 5 synthesizes a human-readable narrative from the held reflection outputs plus the cumulative diff and produces its own `learnings: <prd-slug>/<piece-slug>` commit.

**Explicit removal note (v3.2.0+).** The previous-version commit-message pattern `reflection: <prd-slug>/<piece-slug> — append findings to backlogs` no longer occurs on the worktree branch. Earlier versions auto-appended both backlog files and produced this single reflection commit before Step 5; under the rerouted flow there is no such commit because no auto-append happens — every backlog entry now lands via `/spec-flow:defer`'s own `chore(<piece-slug>): defer ...` commits, one per deferred finding. (Phase 13's CHANGELOG release notes call out this commit-pattern removal explicitly so downstream automation that grepped worktree history for `reflection: ... append findings to backlogs` can migrate.)

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

### Step 5.5: Update Manifest to Merged (mandatory gate — do not push or open a PR before this)

Commit the terminal manifest state to the piece branch. This step is mandatory for
**both** `merge_strategy` values: for `squash_local` the squash carries it to main;
for `pr` the PR merge carries it. The piece branch must show `status: merged` before
any push or PR is opened — if the branch reaches main with `status: in-progress`, the
next `status` scan will show the piece as stale-active with no worktree.

```bash
# update docs/prds/<prd-slug>/manifest.yaml:
#   status: merged
#   merged_at: <YYYY-MM-DD>   ← today's date
git add docs/prds/<prd-slug>/manifest.yaml
git commit -m "chore(manifest): mark <prd-slug>/<piece-slug> as merged"
```

**Failure path:** If Step 6 subsequently fails (conflicts, hook rejection, empty commit),
revert this commit on the piece branch so it doesn't carry a stale `merged` status:
```bash
git revert HEAD --no-edit   # reverts the Step 5.5 manifest commit
```
After escalation, if the human resolves the issue and retries, **re-run Step 5.5 first**
(re-commit `status: merged` + `merged_at`) before retrying Step 6.

### Step 6: Merge

**Integration — transition all phase tasks to Done (if `integration_cfg != null` and `auto_transition: true`):**
Before merging, run the capability check for operation `transition_task`. If available,
iterate over all `jira_task:` keys from plan.md for this piece and transition each task to
the "Final Review Board passes" status from `integration_cfg` (default: `Done`).
On tool unavailable → emit warning → skip (do NOT block the merge).

Read `merge_strategy` from `.spec-flow.yaml` (valid values: `squash_local`, `pr`;
default: `squash_local` when the key is absent, unset, or unrecognized — per NN-C-003
backward compatibility). Branch on the value:

**If `merge_strategy: squash_local` (default):**
```bash
git checkout main
git merge --squash piece/<prd-slug>-<piece-slug>
git commit -m "piece/<prd-slug>-<piece-slug>: <summary of what was built>"
git worktree remove {{worktree_root}}
git branch -d piece/<prd-slug>-<piece-slug>
```
If Step 6 fails for any reason (conflicts, hook rejection, empty commit, etc.): revert the
Step 5.5 manifest commit on the piece branch before escalating to human, so the branch
does not carry a stale `merged` status (see Step 5.5 failure path above).

**If `merge_strategy: pr`:**
Display the following command for the human to copy-paste and run manually:
```
gh pr create --base main --head piece/<prd-slug>-<piece-slug>
```
Print: "PR-based merge required. Run the command above to open a pull request.
The piece branch already carries `status: merged` + `merged_at` in the manifest (Step 5.5).
When the PR is reviewed and merged, main receives the correct terminal state automatically.
After the PR merges, run these cleanup commands:
  git worktree remove {{worktree_root}}
  git branch -d piece/<prd-slug>-<piece-slug>"
**Halt.** Do NOT execute the `gh` command — no `gh` CLI dependency is introduced.

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
