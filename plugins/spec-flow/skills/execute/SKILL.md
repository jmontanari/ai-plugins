---
name: execute
description: >-
  Implement an approved plan phase-by-phase. Dispatches TDD or Implement track agents per phase,
  QA gates between phases, final review board (8-9 agents) before merge. Main window writes zero
  code. Triggers: "execute", "implement", "run the plan".
---

# Execute — Orchestrate Plan Implementation

Execute an approved plan phase by phase using dedicated agents for each step. Each phase runs in Mode: TDD or Mode: Implement based on the plan's chosen track, with QA gates at every boundary and a final review board (8 agents in standard mode; 9 in fast mode) before merge.

## Pre-flight: Model Check

Before any other step, verify the active model is a Sonnet-class model.

Determine the active model using the platform-appropriate method:

- **Copilot CLI** — read the `<model_information>` system tag injected into this session's context. The model name and ID are present there explicitly.
- **Claude Code** — no equivalent tag is injected. Use Claude's self-knowledge: introspect your own model identity (Claude reliably knows which model variant it is from training) and treat that as the model name for the check below.

If the active model name does **not** contain `sonnet` (case-insensitive):

1. Use `ask_user` to block and prompt the user:

   > ⚠️ **Model mismatch.** Execute is tuned for a Sonnet-class model for reliable multi-agent orchestration, but the active model appears to be **[model-name]**.

   Choices:
   - "Override — proceed on [model-name]"
   - "Change now — I'll switch models"
   - "Cancel execute"

2. If the user selects **"Cancel execute"** → stop immediately and emit:
   `Execute cancelled. Re-run after switching to a Claude Sonnet model.`

3. If the user selects **"Override — proceed on [model-name]"** → proceed to Step 0 immediately on the current model. Emit a one-line acknowledgment first:
   `Overriding model check — proceeding on [model-name]. Orchestration reliability may be reduced.`

4. If the user selects **"Change now — I'll switch models"** → **close the prompt and return control to the user.** The model cannot be switched while an `ask_user` prompt is blocking, and there is no programmatic model-change event to listen for — so leave the dialog and wait for the user to signal. Emit:
   `Switch to a Claude Sonnet model now. When ready, type "proceed" to resume, or "cancel" to stop.`
   Then wait for the user's free-text reply:
   - On `proceed` (or any "I've switched / continue" phrasing) → re-run this model check (re-introspect your model identity on Claude Code, or re-read the `<model_information>` tag on Copilot CLI). If the model now contains `sonnet`, proceed to Step 0. If it still does not, re-present the three choices above.
   - On `cancel` → stop and emit the cancellation line from step 2.

If the model already contains `sonnet` → proceed to Step 0 immediately with no prompt.

### Per-stage model policy report

When `model_policy: auto` (the default), after the Sonnet-class check passes, emit a per-stage model-assignment report from the table in `plugins/spec-flow/reference/coordinator-contract.md` `## Model Policy`. The report lists each in-execute stage → its model and **flags only the two sanctioned exceptions**: (1) **spike phase → Opus** — a `[SPIKE]` phase triggers the Step 1c resolve dispatch on Opus (FR-005); (2) **operator override → Opus** — the `--opus=<phase-id|all>` invocation flag forces Opus for the named phase(s) (absent flag → silent no-op, NN-C-005). A non-`[SPIKE]`, non-`--opus` stage never upgrades to Opus (NN-P-005).

**`--opus` flag parse (pre-flight):** If the user invokes execute with `--opus=<phase-id>` or `--opus=all`, parse it at Step 0 (config load) and store as `opus_override_phases` (a list of phase IDs, or `["all"]`). When dispatching any phase listed in `opus_override_phases`, use `model: "opus"` and surface it as the operator-override exception in the model-policy report. Absent `--opus` → `opus_override_phases = []` (no override, silent no-op).

When `model_policy: off`, skip the report entirely — only the Pre-flight Model Check prompt above runs (legacy behavior).

**Why Sonnet.** Execute orchestrates multi-agent, multi-phase work: it builds task lists, manages QA gates, routes discoveries, tracks SHA-256 manifests, and dispatches up to 9 review-board agents in sequence (8 standard; 9 in fast mode). Opus adds latency and cost with no orchestration benefit (Opus is dispatched by sub-agents when deep review is warranted). Haiku or mini-class models lack the reasoning capacity to reliably evaluate agent reports, parse AC matrices, and route findings through the Step 6c discovery tree.

## Step 0: Load Config

**Change-track detection.** First, check the user argument:

If the argument matches the pattern `change/<slug>` (i.e., starts with `change/` followed by
lowercase alphanumeric characters and hyphens):
- Set: `track = "change"`
- Set: `slug = <extracted value after "change/">`
- Set: `spec_path = "<docs_root>/changes/<slug>/brief.md"`
- Set: `plan_path = "<docs_root>/changes/<slug>/plan.md"`
- Set: `worktree = "<worktrees_root>/<slug>"`
- Set: `branch = "change/<slug>"`

Otherwise:
- Set: `track = "piece"`
- `[All existing Step 0 path-resolution logic runs unchanged]`

**Worked example for change-track detection:**
```
<!-- Example A: user invokes `execute change/fix-button-label`
  Argument "change/fix-button-label" matches pattern change/[a-z0-9-]+
  track    = "change"
  slug     = "fix-button-label"
  spec_path  = "docs/changes/fix-button-label/brief.md"
  plan_path  = "docs/changes/fix-button-label/plan.md"
  worktree   = "worktrees/fix-button-label"
  branch     = "change/fix-button-label"
  → proceed to precondition checks below

  Example B: user invokes `execute small-change/auth-token-refresh`
  "small-change/auth-token-refresh" does NOT match pattern change/[a-z0-9-]+
  track = "piece"
  → existing resolution logic runs unchanged
-->
```

**Precondition checks for change-track** (when `track = "change"`):
- Verify `spec_path` (`<docs_root>/changes/<slug>/brief.md`) exists. If absent → halt: `"Error: brief.md not found at <docs_root>/changes/<slug>/brief.md. Run /spec-flow:small-change <slug> first."`
- Verify `plan_path` (`<docs_root>/changes/<slug>/plan.md`) exists. If absent → halt: `"Error: plan.md not found at <docs_root>/changes/<slug>/plan.md. Run /spec-flow:small-change <slug> first."`
- Skip: manifest status check (`specced` / `planned` gate) — no manifest entry exists for change-track pieces
- Use `spec_path` (brief.md) wherever the standard path uses `spec.md` for context injection throughout execution

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

**Integration config load.** If `integrations.issue_tracker.enabled: true`, read the
integrations charter skill for transition rules and commit format. Resolve the active charter
root per `plugins/spec-flow/reference/charter-location.md`, then read
`<charter_root>/skills/charter-integrations/SKILL.md` (`<charter_root>` ∈ {`.github`, `.claude`}).

If the file is absent, proceed with built-in defaults (see `plugins/spec-flow/reference/integration-capability-check.md`). Store as `integration_cfg`. If disabled or absent, set
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

### Coordinator Return Discipline

To stay lean over long pieces (G-4), the coordinator consumes **bounded, structured** agent returns. Every agent return to the coordinator MUST be a bounded summary; raw artifacts — full diffs, full test output, file bodies — live on disk or git and are referenced by path, never pasted into the coordinator's context. See `plugins/spec-flow/reference/coordinator-contract.md` `## Coordinator Return Discipline`.

| Dispatch | Return shape today | Compliant? |
|----------|--------------------|-----------|
| research (pre-spec) | ≤2K structured digest; richer artifact on disk | ✓ |
| tdd-red | staged-test manifest (paths + SHA) + summary | ✓ |
| qa-tdd-red | theater-pattern verdict list | ✓ |
| implementer | unified-commit SHA + AC matrix + deviations summary | ✓ |
| verify | pass/fail + AC coverage summary | ✓ |
| refactor | changed-files summary | ✓ |
| qa-phase / qa-phase-lite / mid-piece | must-fix/should-fix finding list | ✓ |
| fix-code | `## Diff of changes` (bounded diff the orchestrator applies) | ✓ |
| review-board (×8–9) | per-reviewer finding list by severity | ✓ |
| reflection (×2) | findings appended to backlog file; short summary returned | ✓ |

Any dispatch that instructs an agent to paste a raw full diff, full test output, or a file body into its return is a defect — convert it to a bounded summary + on-disk reference. (Audit on authoring: all current dispatches return bounded summaries.)

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

A piece reaching execute stage already has a spec carrying a `charter_snapshot:` front-matter and a plan aligned to that snapshot. Before any phase dispatch, run the charter-drift check per `plugins/spec-flow/reference/charter-drift-check.md` against the spec's `charter_snapshot:` and the live charter skills at the active charter root (resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-*/SKILL.md`, `<charter_root>` ∈ {`.github`, `.claude`}). If drift is detected, halt Phase 1 and escalate per the reference doc — do not dispatch phases against stale charter constraints.

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

### 1e. Integration-Test Registry — M1 load/carry (ADR-3)

After the plan has been loaded (1b) and before any phase is dispatched, read the `## Integration-Test Registry` table from `plan.md` (if present). Hold its rows in orchestrator state as `integration_registry` — a list of records with fields: `path`, `boundary`, `doubled_externals`, `ac`, `registered_in_phase`, `completes_in_phase`. Carry `integration_registry` across every phase unchanged — no phase agent may add, remove, or mutate rows.

**Field origins (M1 doctrine).** Every field in a registry row has one of two origins:

- **Plan-authored (present in `plan.md` at plan-authoring time):** `path`, `boundary`, `doubled_externals`, `ac`, `registered_in_phase`, `completes_in_phase`. These are written by the plan author and are present in the table as authored — the orchestrator reads them verbatim at load time.
- **Runtime-populated (recorded into orchestrator state, NOT plan-authored):** `skeleton_sha256` and `completed_sha256`. The plan author cannot know test-file hashes before Red writes the skeleton. These fields are left blank (or `—`) in the `plan.md` table and are filled by the orchestrator at runtime: `skeleton_sha256` is recorded when Red authors the skeleton in its `registered_in_phase`; `completed_sha256` is recorded by the orchestrator at the `completes_in_phase` window (per the M3 "closure hashes live in orchestrator state" paragraph in Step 3.7a). The orchestrator holds both hashes in per-row orchestrator state, NOT in the `plan.md` table.

**M1 invariant (ADR-3):** `integration_registry` rows are built from plan + Red only, never written from Build. This invariant is the foundation for Phase 6's anti-cheat assertion. Any orchestrator step that reads the registry must source it from the plan-load snapshot recorded here; Build agents never write to it.

**Absent-table degradation (NFR-INT-02):** If `plan.md` contains no `## Integration-Test Registry` table, set `integration_registry = []`. When `integration_registry` is empty, all integration-test gates in later steps are skipped silently — no error, no warning. This ensures pieces that predate the integration-test registry continue to execute without modification.

## Phase Scheduler — detection

The orchestrator begins each piece by scanning plan.md for Phase Group headings (`## Phase Group <letter>:`). For each top-level unit in plan.md, determine whether it is a flat phase or a phase group:

- **Flat phase** (current model) — starts with `### Phase <N>` — run through the Per-Phase Loop below (Steps 1–7).
- **Phase Group** — starts with `## Phase Group <letter>:` and contains ≥2 `#### Sub-Phase <letter>.<n>` subheadings — run through the Phase Group Loop (below the Per-Phase Loop).

Read the `phase_groups` key from `.spec-flow.yaml` (valid values: `auto`, `always`, `off`; default `auto`):

- `auto` — recognize Phase Groups from plan headings; fall back to flat phase handling when the plan uses `### Phase <N>`.
- `always` — recognize Phase Groups and error if the plan has only flat phases when the piece has multiple obviously-parallelizable files. Used to catch over-flat plans during v1.4.0 rollout.
- `off` — treat every top-level unit as a flat phase, ignoring Phase Group headings. Escape hatch for rollback or for plans authored before v1.4.0.

Read the `deferred_commit` key from `.spec-flow.yaml` in the SAME pass (valid values: `auto`, `off`; default `auto` when the key is absent or unset — per NN-C-003 backward-compat). Hold it in orchestrator state alongside `phase_groups`; the Phase Group Loop (Step G1 onward) branches on it:

- `auto` — Phase Groups run the **concurrent** git-free section (Step G4) — sub-phases dispatch in parallel on the git-free foundation when `phase_groups: auto`/`always` — and the barrier work-commit (Step G9b); the journal is written. (Serial dispatch remains the fallback when `phase_groups: off` or a single sub-phase.)
- `off` — Phase Groups run the legacy concurrent dispatch (each sub-phase commits its own work); no journal, no barrier work-commit.

`deferred_commit` only governs how a recognized Phase Group is executed; whether a unit is recognized as a Phase Group at all is governed by `phase_groups` above.

Read the `model_policy` key from `.spec-flow.yaml` in the SAME pass (valid values: `auto`, `off`; default `auto` when absent/unset — NN-C-003 backward-compat). A malformed value emits a one-line warning and falls back to `auto`. Hold it in orchestrator state for the Pre-flight report branch (see `### Per-stage model policy report` above).

Read the `qa_max_iterations` key from `.spec-flow.yaml` in the SAME pass (valid values: `auto`, or a positive integer; default `auto` when absent/unset — NN-C-003; malformed → one-line warning + `auto`). Resolve `auto` from the plan front-matter `tdd:` field: `tdd: false` → 5, `tdd: true` → 3. If the `tdd:` key is absent from the plan front-matter (pre-front-matter plans), treat it as `tdd: true` → `L = 3` (TDD assumed by default, consistent with Step 1b doctrine; emit no warning). Hold the resolved integer `L` in orchestrator state; all five QA-agent fix-loops use `L` as their circuit-breaker limit. This does NOT govern the oracle 2-attempt build budget or the mechanical SKILL self-lint loop.

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
   - **Charter raw text (always-attach):** verbatim contents of the active charter root's `charter-non-negotiables/SKILL.md` (resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-non-negotiables/SKILL.md`, `<charter_root>` ∈ {`.github`, `.claude`}) and the Step 6 track-aware NN-P payload. If `track = "piece"`, attach the `## Non-Negotiables (Product)` section from `<docs_root>/prds/<prd-slug>/prd.md` unchanged. If `track = "change"`, skip NN-P injection silently — no warning, no error. Plus, if the spec's `### Coding Rules Honored` block cites any `CR-xxx` entries, attach those specific entries (not the full file) extracted from `<charter_root>/skills/charter-coding-rules/SKILL.md`. Match Step 6's existing extraction pattern.

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
   - **Circuit breaker:** `qa_max_iterations` (`L`) iterations maximum. On the `L`-th circuit-breaker hit, surface to human and do NOT auto-resume.

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
Read the `jira_key:` field immediately following this phase's heading in plan.md. If present, use it.
If `track = "change"` and the plan.md phase heading has no `jira_key:` field, fall back to reading `jira_key:` from `spec_path` (brief.md) front-matter.
Run the capability check (`plugins/spec-flow/reference/integration-capability-check.md`) for
operations `get_transitions` and `transition_issue`. If available, transition the task to the
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

### Step 1c: [SPIKE]-phase resolution (FR-005)

*(Runs before Step 1b when triggered — the spike resolves the unknown before pre-flight gathers facts.)*

If the current phase carries a `[SPIKE:]` marker in its prose (detected before mode-dispatch and outside fenced code / HTML comments per `plugins/spec-flow/reference/plan-concreteness.md` §2 scan-scoping), the orchestrator runs the spike agent in `resolve` mode BEFORE the implementer:

**Guard — skip if already resolved:** Check whether `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<phase-id>.md` already exists. If it does, the spike was previously resolved — skip the dispatch and proceed to Step 1b with the existing artifact. If the file exists, read the first `STATUS:` line. If `STATUS:` is absent or its value is neither `OK` nor `BLOCKED`, the artifact is malformed — log a warning and re-dispatch the spike resolve rather than silently advancing.

**Resolve dispatch:**
```
Agent({
  description: "Resolve [SPIKE] unknown for phase <phase-id>",
  prompt: "<inject: mode:resolve + the [SPIKE] marker text + full phase plan context + (if the phase has a [TDD-Red] or [Write-Tests] step) the Test Data skeleton from the plan>",
  model: "opus"
})
```
Dispatch is isolated — no shared history. All inputs injected by the orchestrator.

**On `STATUS: OK`:**
1. Read the spike artifact at `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<phase-id>.md`.
2. If the artifact carries a `**Test Data:**` block, write it into the phase's `Test Data` block in `plan.md` (so Step 2.7 / `tdd-red` transcribes it verbatim — both already consume `plan.md` per `plugins/spec-flow/reference/plan-concreteness.md` §5). If the phase has a `[TDD-Red]` or `[Write-Tests]` step (i.e., it requires test data) AND the spike artifact carries no `**Test Data:**` block, treat this as a BLOCKED response: surface a `requires-amendment` discovery row with reason 'spike resolved OK but produced no Test Data for TDD phase' and route to Step 6c. Do NOT proceed to the implementer.
3. Record the artifact path in orchestrator state.
4. Proceed to Step 1b (pre-flight) then the phase's normal track (TDD or Implement).

**On `STATUS: BLOCKED`:**
Surface a discovery row:
```
Type: requires-amendment
Source: spike-agent (resolve mode, phase <phase-id>)
Why this blocks: spike could not resolve [SPIKE: <description>]. Reason: <agent reason>.
Proposed amendment scope: operator must supply the resolution or redefine the unknown.
Estimated absorption size: unknown
```
Route to Step 6c discovery triage. Do NOT proceed to the implementer for this phase.

See `plugins/spec-flow/reference/spike-agent.md` `## Agent modes` for the full mode contract.

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

7. **Fast mode flag** — check the plan's front-matter `fast:` field. If `fast: true`, record `orchestrator_fast_mode: true` in session state. Fast mode skips all per-phase inline QA agent dispatches (`qa-tdd-red`, `qa-phase`, `qa-phase-lite`, Group Deep QA) and replaces per-phase verify agent dispatch with a direct test-command shell invocation. The end-of-piece Final Review board gains a 9th member (`verify Mode: Piece Full`) to compensate. Log once: `"Fast mode: ENABLED — inline QA skipped, end-of-piece board +1 (verify-piece-full)"`. If `fast:` is absent or `false`, record `orchestrator_fast_mode: false` and proceed normally.

8. **Introspection context** — if `introspection.md` exists in the piece's working directory (alongside plan.md), read it. For the current phase's declared file scope, extract the Dependency Map and Test Landscape sections from the relevant cluster(s). Match phase file paths against the File Inventory entries in each cluster's H2 section. Append matching sections to `## Pre-flight snapshot` as `### Codebase context`. Skip the File Inventory and Pattern Catalog — the plan's Change Specification Blocks already embed their verbatim code from those sections. If `introspection.md` is absent (pre-v4.10 plans or CREATE-only phases), skip silently — no warning, no error.

Compose two attachments for later steps:

- `## Pre-flight snapshot` — items 1–5 above plus item 8 (codebase context from `introspection.md`), verbatim. Attached to BOTH the Red prompt (Step 2) and the Implement prompt (Step 3) — Red benefits from symbol presence and schema samples too.
- `## Orchestrator pre-decisions` — item 6, one resolved decision per bullet. Attached only to the Implement prompt. Empty section OK (include the heading with "(none)" if no conditionals matched).

If `.pre-commit-config.yaml` is absent, the hook inventory is empty — agents commit normally without any hooks running.

### Step 2: TDD-Red — Write Failing Tests (Stage, Don't Commit)

*(Mode: TDD only. Skip this step entirely when the plan uses non-TDD mode (`tdd: false` in plan front-matter). As of v2.7.0, Red stages its tests via `git add` but does NOT commit. The implementer in Step 3 creates the unified commit containing Red's staged tests + Build's production code. This makes each TDD cycle land as one commit in git history.)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/tdd-red.md`
2. Compose prompt with: phase [TDD-Red] tasks from plan, spec ACs, existing test patterns, and the `## Pre-flight snapshot` block from Step 1b. Red does NOT commit — the pre-commit hook does not run during its turn. The `--no-verify` test-running-hook carve-out from pre-v2.7.0 is obsolete (there's no Red commit for the hook to block).

   **Contract injection (AC-13 / graceful degradation).** Before dispatching, check whether `plan.md` contains a `## Contracts` section:
   - **Section present:** Scan the `## Contracts` section for entries whose `**Phase:**` field matches the current phase (or sub-phase). Phase matching uses **token-based whole-word comparison** (case-insensitive): normalize both strings by stripping leading `###`/`####` and surrounding whitespace, then split into whitespace-delimited tokens, then strip trailing colons from each individual token (e.g., `"2:"` → `"2"`, `"a.1:"` → `"a.1"`). A contract entry matches the current phase if the contract's `**Phase:**` token sequence is a contiguous prefix match of the current phase's heading tokens, starting at position 0 (e.g., contract `**Phase:** Phase 2` tokens `["phase","2"]` match heading `### Phase 2: Authentication Module` tokens `["phase","2","authentication","module"]` — `"phase"=="phase"` and `"2"=="2"` at positions 0–1 ✓; but would NOT match `### Phase 10: Indexing` tokens `["phase","10","indexing"]` since `"2" ≠ "10"`). Sub-phase identifiers like `Sub-Phase A.1` are matched by the same rule applied to `["sub-phase","a.1"]`. If no contracts match for a TDD phase that does have a Contracts section with entries for other phases, emit a warning in the prompt: "Note: No contracts matched phase [normalized heading] by name — verify Phase field values in plan.md `## Contracts` section." Extract the full entry text for each matching contract. Append to the tdd-red prompt as a structured block:

     ```
     ## Contracts for this phase
     The following interface contracts have been defined for this phase. Write tests that verify the implementation honors each contract's signature, inputs, outputs, and error cases.

     <paste full C-N entry text for each matching contract>
     ```

   - **Section absent:** Do not add the `## Contracts for this phase` block. tdd-red operates as today with no error. The `## Context Provided` section of tdd-red.md already handles this gracefully — contracts input is absent but not required.

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
     actual=$(sha256sum -- "$path" | cut -d' ' -f1)
     reported=<hash from Red's manifest for this path>
     [ "$actual" = "$reported" ] || echo "manifest mismatch: $path"
   done
   ```
   If any path's self-reported hash does not match the file content, reject Red's output — the manifest is either stale or wrong. Retry once with the mismatch reported. Also sanity-check that every `## Tests Written` path appears in the manifest (and vice versa); a divergence here means Red's output is internally inconsistent and the orchestrator should reject before proceeding.

   Also persist the stage manifest to a temp file (e.g. `/tmp/spec-flow/phase-N-red-manifest.json`) so that if the worktree is clobbered externally before Step 3 completes, the orchestrator can detect it on resume and escalate with a clear signal.

### Step 2.5: QA-TDD-Red — Reject Theater Tests

*(Mode: TDD only. Skip this step when the plan uses non-TDD mode (`tdd: false` in plan front-matter). **Fast mode skip:** if `orchestrator_fast_mode: true`, skip this step entirely — `qa-tdd-red` is replaced by `verify Mode: Piece Full` at end-of-piece. Proceed directly to Step 3. Runs between Red's commit and the implementer dispatch. Catches theater tests — tautology, mock-echo, assert-the-assignment, truthy-only, exception swallowing, no-assertion, name/body mismatch, implementation coupling, redundant clusters — before Build writes production code fit to weak assertions.)*

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
     - **(a) Non-integration suite green** — `0 failed` across the **non-integration suite**. The run behavior depends on whether `integration_registry` is non-empty (M2 tag-separation, per ADR-3):
       - **`integration_registry` is non-empty:** log the exclusion before running (e.g. `"Oracle: running non-integration suite (-m 'not integration'); [integration] tests gated by M4 sub-cycle"`) — never silent (NN-C-005) — then run the suite with an explicit `[integration]` marker exclusion: `-m 'not integration'` (pytest) or the project's equivalent marker convention. For runners that lack marker support, fall back to the path-dir fallback: exclude the integration test directory if one exists; if no integration test directory exists, exclude the registry's declared `path` values by name (log the exclusion explicitly per NN-C-005 — never run unmodified when registry rows exist). An `[integration]` test registered in `integration_registry` with a future `completes_in_phase` is NOT part of the per-phase non-integration oracle until that completing phase runs. (The due-integration invariant that checks completed rows is added in Phase 6's M4 oracle split.)
       - **`integration_registry` is empty** (pre-4.12 piece / no integration tests, per NFR-INT-02): run the bare test command with no `-m 'not integration'` flag and no exclusion log line — the suite runs exactly as it did before M2 was introduced.
     - **(b) Every Red ID is in PASSED** — parse the current run's PASSED set and diff against the FAILED IDs captured in `phase_N_oracle_block` from Step 2.5. Every Red test ID must appear in the PASSED set. Missing IDs (collection errors, empty parameterize, deleted tests) are a rejection signal.
     - **(c) Zero Red IDs in SKIPPED** — any Red ID marked `@pytest.mark.skip`, `.skip()`, `t.Skip()`, `xfail`, or otherwise non-run is a rejection signal. This catches silent skip decorators added during Build.
     - **(d) Every due `[integration]` test green** — for every `integration_registry` row with `completes_in_phase ≤ current_phase` (compared by ordinal — see phase ordinal mapping in Step 3.7a; `completes_in_phase` is always authored as a top-level integer ordinal), that `[integration]` test (and its contract tests) must be in PASSED. Rows with `completes_in_phase > current_phase` are expected absent/red and are NOT a violation. (Per-phase invariants (a)–(c) apply to the non-integration suite per Phase 5's M2 split; this (d) is the integration half of the M4 oracle split per ADR-3.)
     - On violation of (b) or (c): retry within the 2-attempt budget with the specific offending IDs surfaced to the agent (e.g. "tests X, Y were SKIPPED in your run; you cannot pass Red tests by skipping them"). Escalate on second failure — a Red test that cannot go green without skipping means the plan or the Red tests themselves are wrong. On violation of (d): escalate immediately — a due `[integration]` test that is not green means the completing-phase `[Integration-Test]` sub-cycle did not run or failed.
   - Mode: Implement — the plan's `[Verify]` command must pass with the plan's expected output.
6. **Circuit breaker:** If the oracle does not pass after 2 attempts in either mode, escalate to human. If the agent reports BLOCKED (e.g. ambiguous plan, architecture conflict, pre-decision vs. filesystem mismatch), escalate — do not retry blindly.
7. **Post-commit integrity and reconciliation gates (Mode: TDD + Implement, v3.1.1+).** After the implementer's commit lands (HEAD now points to it), run cheap checks before accepting the phase. Gate (a) is TDD-only (uses Red's manifest); gate (b) is HARD FAIL on BOTH modes — strays or missings reject the phase. The Implement-track extension was added in v3.1.1 per pi-009-hardening's Phase Group A contamination event, where A.2 silently swept in A.4's staged files because the gate was previously gated `Mode: TDD only`.

   > **Deferred Phase Group note (`deferred_commit: auto`).** The HEAD-hash form of both gates below — gate (a) content-hash integrity and gate (b) reconciliation — applies to flat phases and to `deferred_commit: off`, where each phase/sub-phase makes its own commit and HEAD points at that work. Under `deferred_commit: auto` the sub-phases do NOT commit individually, so these gates do NOT run per sub-phase. Instead they run ONCE at the group barrier (Step G9b: Barrier work-commit), evaluated against the **working tree** (gate (a): re-hash each sub-phase's Red tests in the working tree against the journal `red_manifest_hashes`) and the **barrier work-commit** (gate (b): reconcile the work-commit `--name-only` against the union of all sub-phase scopes). The per-sub-phase HEAD-hash form does not apply under `auto` because there is no per-sub-phase HEAD commit to hash.

   - **(a) Content-hash integrity (Mode: TDD only).** For every path in `phase_N_red_stage_manifest`, re-hash the file AS COMMITTED in HEAD and compare against the manifest:
     ```bash
     for path in <manifest paths>; do
       commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
       manifest_hash=<manifest hash for path>
       [ "$commit_hash" = "$manifest_hash" ] || echo "integrity fail: $path"
     done
     ```
     Any mismatch means the implementer modified one of Red's tests — the anti-cheat safeguard replacing pre-v2.7.0's `git diff tests/` check. Reject the phase and retry within the 2-attempt budget (the retry must recreate the commit without touching Red's tests). Escalate on second failure.

     **M3 edit window for registered `[integration]` paths.** In addition to Red's manifest, the orchestrator enforces immutability on all paths listed in `integration_registry` (and their declared fixture/helper dependency-closure):

     - **Before `registered_in_phase`** (i.e. `current_phase < registered_in_phase`): the skeleton does not yet exist in HEAD — `git show HEAD:"$path"` would error; this is "not yet authored", NOT an integrity failure. Skip this registry row entirely for M3 checks this phase.
     - **From `registered_in_phase` to before `completes_in_phase`** (i.e. `registered_in_phase ≤ current_phase < completes_in_phase`): the path is immutable at `skeleton_sha256`. Re-hash against `skeleton_sha256`; any deviation is rejected.
     - **At `completes_in_phase`** (i.e. `current_phase == completes_in_phase`): exactly **one** plan-authorized edit is permitted — the skeleton→completed transition. The window is single-shot, plan-authorized (derived from the registry's `skeleton_sha256` / `completed_sha256` fields), path-confined (incl. fixture/helper closure), and phase-gated to `completes_in_phase` (NFR-INT-01). The orchestrator records `completed_sha256` after the edit; the path (and its declared fixture/helper closure) is immutable at `completed_sha256` from this point forward. **When `registered_in_phase == completes_in_phase` (same-phase register+complete):** Red authors the skeleton in this phase (the M3 window opens) and the Step 4.5 completing-phase sub-cycle greens it in the same phase (the M3 window closes). In this case: the orchestrator checks the Red commit against `skeleton_sha256` (intra-phase, after Red stages and the unified commit lands) and then checks the Step 4.5 completing edit against `completed_sha256` — both within the single phase, in that order.
     - **After `completes_in_phase`**: the path is immutable at `completed_sha256`. Re-hash against `completed_sha256`; any deviation is rejected.

     **Phase ordinal comparison.** The comparisons above (`<`, `≤`, `==`, `>`) compare phase ordinals, not raw IDs. Map every phase/sub-phase/amendment ID to a monotonic top-level ordinal: a sub-phase inherits its group's ordinal; amendment phases (`phase_N_amend_K`, `phase_final_amend_K`) take the ordinal of the phase they extend. `completes_in_phase` and `registered_in_phase` are authored as top-level integers and serve directly as ordinals.

     Hash the declared fixture/helper closure for each registered path (closes the refactor real→double blind spot — Refactor cannot swap a real in-boundary dependency for a test double in a helper file).

     **Closure hashes live in orchestrator state — not as registry columns.** At skeleton time (when the Red snapshot is captured and `skeleton_sha256` is recorded), the orchestrator also hashes each declared closure file and stores those hashes in orchestrator state, keyed to the registry row (e.g. as a `fixture_helper_skeleton_hashes` map per row). At the `completes_in_phase` window (when `completed_sha256` is recorded), the orchestrator likewise records the closure files' completed hashes in orchestrator state (e.g. `fixture_helper_completed_hashes` per row). The registry table schema (`path`, `boundary`, `doubled_externals`, `ac`, `registered_in_phase`, `completes_in_phase`) is unchanged from the plan.md columns — `skeleton_sha256` and `completed_sha256` are runtime orchestrator state only, never plan.md columns.

     ```bash
     for entry in <integration_registry entries>; do
       path=<entry.path>
       current_ord=<monotonic ordinal for current_phase>
       registered_ord=<monotonic ordinal for entry.registered_in_phase>
       completing_ord=<monotonic ordinal for entry.completes_in_phase>

       # Skip entirely if skeleton has not been authored yet
       if [ "$current_ord" -lt "$registered_ord" ]; then
         continue
       fi

       # Determine expected hash based on phase window.
       # N2: In the same-phase case (registered_in_phase == completes_in_phase), current_ord
       # equals completing_ord at BOTH the post-Red checkpoint and the Step 4.5 completing-edit
       # checkpoint. The else-branch (completed_sha256) is only correct once completed_sha256
       # has been recorded (i.e. after the Step 4.5 edit lands). At the post-Red checkpoint in
       # the same phase, the skeleton is still the current file and expected_hash must be
       # skeleton_sha256. See prose above ("When registered_in_phase == completes_in_phase")
       # and Step 4.5 for the intra-phase ordering: post-Red → check skeleton_sha256; after
       # Step 4.5 completing edit recorded → check completed_sha256.
       if [ "$current_ord" -lt "$completing_ord" ]; then
         expected_hash=<state: skeleton_sha256 for this entry>
       else
         # current_ord == completing_ord: use completed_sha256 only after Step 4.5 edit has
         # landed and completed_sha256 has been recorded; use skeleton_sha256 at the earlier
         # post-Red checkpoint within the same phase (see prose for intra-phase ordering).
         expected_hash=<state: completed_sha256 for this entry>
       fi

       # N1: Use git cat-file -e to check presence before hashing. Piping git show into
       # sha256sum always produces a non-empty hash (SHA-256 of empty input for absent paths),
       # so [ -z "$commit_hash" ] is dead code with the pipe form. Check presence separately.
       if ! git cat-file -e HEAD:"$path" 2>/dev/null; then
         echo "M3 integrity fail: $path absent in HEAD at phase $current_ord (expected after registered phase $registered_ord)"
       else
         commit_hash=$(git show HEAD:"$path" | sha256sum | cut -d' ' -f1)
         [ "$commit_hash" = "$expected_hash" ] || echo "M3 integrity fail: $path"
       fi

       # Also hash declared fixture/helper closure paths for this entry
       for helper in <entry.fixture_helper_closure>; do
         # N1: Use git cat-file -e for presence check (same reason as above — piped sha256sum
         # never produces an empty string, so the old [ -z "$helper_hash" ] was dead code).
         if ! git cat-file -e HEAD:"$helper" 2>/dev/null; then
           echo "M3 fixture/helper closure integrity fail: $helper absent in HEAD"
         else
           helper_hash=$(git show HEAD:"$helper" | sha256sum | cut -d' ' -f1)
           expected_helper_hash=<state: fixture_helper expected hash for helper, skeleton-or-completed by ordinal>
           [ "$helper_hash" = "$expected_helper_hash" ] || echo "M3 fixture/helper closure integrity fail: $helper"
         fi
       done
     done
     ```

     Any out-of-window edit, or an edit not matching the recorded `completed_sha256`, is rejected. This is an anti-cheat gate: **Build cannot self-authorize an integration edit.** The implementer may NOT create a registry row, move a `completes_in_phase` or `registered_in_phase` marker, or edit a registered `[integration]` test outside its single plan-authorized window — registry rows come only from plan + Red (M1 invariant), and the edit window is plan-derived, qa-plan-reviewed, single-shot, path-confined, and phase-gated (NFR-INT-01). Any such attempt is rejected. The M3 window is a gate *tightening* mechanism, never a merge path (NN-P-002). Build cannot self-authorize — the orchestrator enforces this invariant and will reject any phase where these rules are violated.

     For Mode: Implement, the Red-manifest half of this gate is skipped (no Red manifest exists); the M3 integration-registry sub-check still applies if `integration_registry` is non-empty. Proceed directly to (b).

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
    - **Transcribe the phase's `Test Data` block — invent nothing** (`plugins/spec-flow/reference/plan-concreteness.md` §5). Author each test's inputs and expected assertions from the phase's `Test Data` block; author no input or expected outcome absent from it. If the block is **present but incomplete** (a named behavior with no covering case, or a case missing its input or expected outcome and not marked `[SPIKE]`), STOP and report `BLOCKED — Test Data gap: <case>` — write no partial test set; the orchestrator routes to plan amendment (Step 6c). If the phase carries **no `Test Data` block at all** (a plan predating this contract), emit `[TEST-DATA-ABSENT: no Test Data block in phase]` and fall back to writing reasonable-coverage tests from the `[Implement]` block as below, without blocking.
    - Write tests that verify the implementation is correct, with reasonable coverage of the phase's ACs.
    - No "fail first" requirement — tests are written for existing code.
    - No theater-pattern review, no SHA-256 manifest.
    - Stage tests via `git add` (do NOT commit) so the Verify step can run them.
2. **Validate:** Run the test suite scoped to the authored test paths. All new tests should pass (they're written for existing code). If tests don't pass, the agent should fix them within the same turn.
3. **No AC Coverage Matrix required.** Unlike TDD mode, there's no hard gate here. Just reasonable test coverage.
4. Proceed to Step 4 (Verify).

### Step 4: Verify — Confirm Correctness

**Fast mode — direct test execution (no agent dispatch):** if `orchestrator_fast_mode: true`, skip the verify agent dispatch entirely. Instead, run the project test command directly. The run behavior depends on whether `integration_registry` is non-empty (M2 tag-separation, per ADR-3):

- **`integration_registry` is non-empty:** log the exclusion before running (e.g. `"Fast mode: running non-integration suite (-m 'not integration'); [integration] tests gated by M4 sub-cycle"`) — never silent (NN-C-005) — then scope the run to the **non-integration suite** via an explicit `[integration]` marker exclusion:

  ```bash
  # Use the [Verify] command from the plan's current phase block, or fall back to CLAUDE.md test command
  # Log exclusion before running (NN-C-005); path-dir fallback when marker support is unavailable
  <test command> -m 'not integration'   # pytest example; adapt to project marker convention
  ```

  For runners that lack marker support, fall back to the path-dir fallback: exclude the integration test directory if one exists; if no integration test directory exists, exclude the registry's declared `path` values by name (log the exclusion explicitly per NN-C-005 — never run unmodified when registry rows exist). Due `[integration]` tests registered in `integration_registry` are NOT checked by this raw exit-code run — they are gated by the M4 sub-cycle (Phase 6), not by fast-mode.

- **`integration_registry` is empty** (pre-4.12 piece / no integration tests, per NFR-INT-02): run the bare test command with no `-m 'not integration'` flag and no exclusion log line — the suite runs exactly as it did before M2 was introduced.

Check exit code. If `0`: log `"Phase N tests: GREEN"` and proceed to Step 4.5 (completing-phase [Integration-Test] sub-cycle) if the current phase completes any registry row, then Step 5 (Refactor). If non-zero: surface the failure output, dispatch a `fix-code` agent scoped to the failing test paths, re-run the test command. Repeat up to 2 attempts. If still failing after 2 attempts: escalate to human. Do NOT dispatch a verify agent in fast mode.

---

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
5. **Test integrity (Mode: TDD only; non-TDD mode: no-op).** As of v2.7.0, the primary anti-tampering safeguard runs at Step 3.7a (content-hash check of Red's staged test manifest against Red's test files in HEAD). By the time Step 4 runs, that gate has already passed — so no additional diff is needed here. In non-TDD mode (`tdd: false`), there is no Red manifest, so this check is a no-op. If the phase produces a Refactor commit in Step 5, re-run the content-hash check against HEAD after Refactor lands (Refactor is phase-scoped and must not touch test files the Red agent authored; re-hashing catches drift). For registered `[integration]` paths, re-hash against `skeleton_sha256` (for phases before `completes_in_phase`) or `completed_sha256` (at/after `completes_in_phase`) — AND re-hash their declared fixture/helper closure — so that Refactor cannot swap a real in-boundary dependency for a test double in a helper file after Refactor (the integration-preservation backstop for Phase 7's refactor.md rule). If any hash drifts at Refactor time: REJECT, revert the refactor commit, and flag the Refactor agent for re-dispatch with the offending paths surfaced.
6. Parse verify report.
   - **Audit Mode returned PASS** — proceed to Refactor (Step 5).
   - **Audit Mode returned FAIL** with `Recommend: Full mode re-verify` — re-dispatch as Mode: Full, treat that result as authoritative.
   - **Full Mode returned PASS** — proceed to the `[Integration-Test]` sub-cycle (below) if applicable, then Refactor.
   - **Full Mode returned FAIL** — if gaps: Mode: TDD can loop back to Red (add tests); Mode: Implement can loop back to Step 3 with gaps as context. Otherwise escalate.

### Step 4.5: Completing-phase [Integration-Test] sub-cycle

*(Runs only when the current phase is a `completes_in_phase` for at least one `integration_registry` row — i.e., some row has `completes_in_phase == current_phase` (by ordinal comparison; see phase ordinal mapping in Step 3.7a). This sub-cycle is positioned between [Verify] and [Refactor], running after Step 4 Verify passes and before Step 5 Refactor begins. Non-completing phases skip it entirely and proceed directly to Step 5.)*

This sub-cycle is the sole execution path for the M3 skeleton→completed edit window. It is additive — it does not replace any prior step, and it does not bypass per-phase QA or the end-of-piece review-board sign-off (NN-P-002).

**Same-phase register+complete (`registered_in_phase == completes_in_phase`).** When a registry row's `registered_in_phase` equals its `completes_in_phase`, both the skeleton authoring (Red in `registered_in_phase`) and the skeleton→completed transition (this sub-cycle) occur within the same phase. Intra-phase ordering: (1) Red authors and stages the skeleton; the orchestrator records `skeleton_sha256` and verifies the unified commit against it; (2) this Step 4.5 sub-cycle applies the completing edit and records `completed_sha256`; (3) the M3 integrity re-check in sub-step 4 below verifies the completed state. The `==` case is not a special code path — the standard sub-cycle below applies; the sole difference is that `skeleton_sha256` was just recorded this same phase rather than a prior one.

**Check:** does any `integration_registry` row have `completes_in_phase == current_phase` (by ordinal)?

- **No:** skip this step. Proceed to Step 5 (Refactor).
- **Yes:** for each such row, run the following sub-cycle:

  1. **Apply the M3 single-shot edit window.** The implementer (or the non-TDD `[Integration-Test]` block's agent) may edit the registered `[integration]` test path (and its declared fixture/helper dependency-closure) from `skeleton_sha256` to `completed_sha256`. This is the only authorized edit: single-shot, plan-authorized (derived from the registry's `completed_sha256`), path-confined (incl. fixture/helper closure), and phase-gated to `completes_in_phase` (NFR-INT-01). The orchestrator records `completed_sha256` after the edit; the path is immutable at `completed_sha256` from this point forward.

     **Non-TDD-mode dispatch path:** when the current phase is non-TDD (`tdd: false`), the completing-phase `[Write-Tests]`/`[Integration-Test]` block's agent authors and greens the outer integration test in its turn. The M3 window still applies — the edit must match `completed_sha256` and the fixture/helper closure is hashed.

  2. **Run the outer `[integration]` test.** Execute the completing test (and its contract tests) in isolation. It must pass. If it fails: dispatch a `fix-code` agent scoped to the integration test path, re-run. Up to 2 attempts; escalate on second failure.

  3. **Gate on M4 invariant (d).** Re-run the oracle with both suites: the non-integration suite (invariant (a)) and the due-integration rows (invariant (d)). Every registry row with `completes_in_phase ≤ current_phase` (by ordinal) must be in PASSED. Any violation escalates.

  4. **M3 integrity re-check.** Re-hash the edited path and its declared fixture/helper closure against `completed_sha256`. Any mismatch rejects the sub-cycle.

  5. **Proceed to Step 5 (Refactor).** The sub-cycle is complete. The completing-phase `[integration]` test is now locked at `completed_sha256`.

### Step 5: Refactor — Clean Up

*(Mode: TDD by default; Mode: Implement only if the phase has a `[Refactor]` checkbox. Conditional skip applies to both modes — see below.)*

**Conditional skip.** Read the `refactor` key from `.spec-flow.yaml` (valid values: `auto`, `always`, `never`; default `auto`). If the key is absent, default to `auto`.

- `never` — skip this step unconditionally. Proceed to Step 5.7.
- `always` — run this step unconditionally.
- `auto` — inspect the Build agent's report. Skip this step if **all** of:
  - `## Oracle Outcome` reports `Oracle ran clean on first attempt: yes`
  - `## Plan Adherence` reports `Deviations from plan: none`
  - `## AC Coverage Matrix` is clean (all rows `covered`, no `NOT COVERED` rows — already validated by Step 3's gate, but re-check here)

  Otherwise run the step.

Log the skip decision (`refactor_skipped: auto|never` with the reason) for the session summary. Observed yield from Phases 5a–11: 8 Refactor passes produced only comment cleanups / −3 to −48 LOC dedup and fixed zero correctness defects. Skipping when Build is clean reclaims 10–15 min per phase with no observed quality loss.

If skipped, proceed directly to Step 5.7. Otherwise:

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

### Step 5.7: Verify-scope union before QA dispatch (AC-14 — pi-014 Phase 11 rationale)

**This step runs unconditionally** — whether Refactor was run or skipped, and including in `orchestrator_fast_mode`. In fast mode (where Step 6 QA dispatch is skipped), the union check runs here before **Step 6b** (the hook sweep) instead of before QA dispatch; it is a mandatory gate regardless of mode.

Before dispatching QA (Step 6), the orchestrator MUST verify the phase oracle and phase-level sweep against the **union** of two file sets:

1. **Implementer's actual-modified file list** — the complete list of files the implementer actually touched or modified during this phase, as reported in the implementer's `## Files Created/Modified` section and confirmed by `git diff --name-only $phase_N_start_sha..HEAD`.
2. **Plan's declared scope** for this phase — the file paths listed in the phase's `**In scope:**` block.

**Rationale (ADR-3).** The plan's declared scope is the pre-flight contract; the implementer's actual-modified list is the ground truth of what changed. A file may appear in one set but not the other: an implementer may touch a file the plan did not enumerate (out-of-declared-scope), or the plan may declare a file the implementer left unmodified. Any file in either set that is NOT covered by the phase's `[Verify]` oracle is a **scope-verification gap** — the orchestrator must resolve each gap before dispatching QA:

- **File in actual but not declared scope:** surface to the implementer for confirmation (was this touch intentional? does the plan need amendment?). If the file's change is load-bearing for the phase's ACs, it MUST be added to the `[Verify]` sweep before QA sees the diff.
- **File in declared scope but not actually modified:** note the absence (the plan may have over-declared scope, or the implementer may have missed a required change). If the plan required the file to be modified and it was not, surface as a plan-adherence gap — do not silently skip it.

**Implementation.** The implementer's agent report includes a `## Files Created/Modified` section listing only the files it authored. The orchestrator computes the **union of actual-modified ∪ declared scope** and runs `git diff --name-only $phase_N_start_sha..HEAD` as the authoritative ground-truth check. Proceed to Step 6 only after all union-gap items are resolved or acknowledged.

### Step 6: Phase QA

**Fast mode skip:** if `orchestrator_fast_mode: true`, skip Step 6 entirely. No `qa-phase` dispatch. No iter-until-clean loop. No Step 6a deferred-finding tracking. Proceed directly to Step 6b (hook sweep) then Step 6c if discoveries exist from other sources (e.g. implementer escalations).

---

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

Iter-until-clean per plugins/spec-flow/reference/qa-iteration-loop.md (no skip; `qa_max_iterations`-limited circuit breaker).

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-phase.md`

2. **Iteration 1 (full review):** Build a structured surface map instead of dumping the raw diff + full spec + PRD. The goal is to hand Opus pre-digested context so it does adversarial review, not re-discovery.

   Compose the iter-1 prompt with the following blocks, in order:

   - **`## Files changed`** — one row per file: `path | +adds/-dels | role (test/impl/config/docs)`. Generated from `git diff --numstat $phase_N_start_sha..HEAD` plus path-based role inference.

   - **`## Public symbols added or modified`** — list of class/function/type names the diff introduces or modifies in non-test files. Use `git diff $phase_N_start_sha..HEAD -- <impl paths>` and grep for added/changed lines matching the project's symbol declarations (e.g. `^[+-]\s*(class|def|function|type)\s+\w+`). One line per symbol: `path:symbol`.

   - **`## Integration callers`** — for each public symbol above, run `git grep -l <symbol>` scoped to source directories. Paths only, no bodies. Opus can `Read` specific callers if it needs to inspect them. If a symbol has zero callers, mark it "(new — no callers yet)".

   - **`## Diff`** — changed-line hunks only (default `git diff` output). If the total diff is > 500 LOC, collapse to per-file summaries with a pointer: "Full hunks available; Read <path> or request via targeted diff if you need specific ranges." Do not attach full file bodies ever.

   - **`## AC Coverage Matrix (from Build)`** — splice Build's `## AC Coverage Matrix` table verbatim. This was already validated clean by Step 3's gate. Opus's job is to adversarially verify the claimed coverage is real and find gaps, NOT to re-derive the matrix from scratch.

   - **`## Phase ACs`** — attach ONLY the acceptance criteria for this phase (mapped via plan.md), not the full spec. Use the plan's "AC map" section or the spec's AC sections that the plan references for this phase.

   - **`## Non-negotiables`** — project constraints.
     - **NN-P injection (track-aware):**
       - If `track = "piece"`: attach the active charter root's `charter-non-negotiables/SKILL.md` (NN-C, project-wide — resolved per `plugins/spec-flow/reference/charter-location.md` as `<charter_root>/skills/charter-non-negotiables/SKILL.md`, `<charter_root>` ∈ {`.github`, `.claude`}) and the `## Non-Negotiables (Product)` section from `<docs_root>/prds/<prd-slug>/prd.md` (NN-P, product-specific).
       - If `track = "change"`: attach the resolved `<charter_root>/skills/charter-non-negotiables/SKILL.md` when available, and skip NN-P injection silently — no warning, no error (no PRD in change-track).

   - **`## Coding rules cited by this phase`** — if the plan's phase block's "Charter constraints honored in this phase" slot cites any `CR-xxx` entries from the active charter root's `charter-coding-rules/SKILL.md` (resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-coding-rules/SKILL.md`, `<charter_root>` ∈ {`.github`, `.claude`}), attach those specific entries (not the full file). Absent slot or no citations → skip this block.

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
   - **Widened-window rule:** Before dispatching, count the number of times each file:location (file path + hunk context line) appears in the cumulative piece diff (`git diff $piece_start_sha..HEAD -- <phase-scope-files>`). If any file:location has been revised ≥2 times within this piece, add a `Widened context: ±10 lines` directive to the focused re-review dispatch — the QA agent must expand its review window to ±10 lines around each changed line in that location rather than the default narrower context used for first-time focused re-review.
   - **Circuit breaker:** `qa_max_iterations` (`L`) iterations max, then escalate.
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
   Run the capability check for operation `transition_issue`. If available and `phase_issue_key`
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

**Amendment budget enforcement.** Before any `amend` (or `amend-spec`) dispatch under this step, the orchestrator checks the per-piece amendment budget (5 amendments total per piece, of which at most 1 may be a spec amendment). See "Amendment budget tracking" below for the counters, refusal strings, and budget-exhaustion escalation flow.

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

#### Operator-initiated change admission (FR-008)

When a free-form operator turn (NOT a structured answer to an active execute prompt — triage choice, QA sign-off, BLOCKED escalation response, etc.) reads as a behavior or scope change — imperative phrasing such as "add…", "change…", "we should…", "what if we…", "can you also…" — the coordinator emits ONE confirmation prompt:

```
That reads as a scope change: "<one-line summary of the change>". Route it through scope → amend → execute? (y/n)
```

- **On `y`:** append the change to the Step 6c discovery list with:
  - `source_agent: operator`
  - `default_triage: amend`
  - `row_text` = the operator's change text verbatim (used as input to the scope spike if threshold exceeded)
  Proceed through the normal triage + amend flow for that discovery.

- **On `n`:** treat the operator turn as a comment; no routing, no discovery appended.

**Detection is SUPPRESSED while the coordinator is awaiting a structured answer** — a y/n triage choice, a model-policy confirmation, a QA sign-off, or any active prompt the coordinator emitted that expects a constrained response. Free-form input during these windows is treated as a structured answer, not as a potential scope change.

This path does NOT bypass the 50% threshold gate (T-2 below) or the no-bypass gate (T-3 below) — operator-admitted changes enter Step 6c and are evaluated by the same threshold and spike logic as agent-discovered changes.

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

**Severity label shown in prompt (Final Review findings).** When a finding originates from a Final Review board reviewer, its severity (`must-fix` or `should-fix`) is displayed in the triage prompt so the operator can weigh it. Severity does NOT suppress options — the full menu `(a) amend  (f) fork  (d) defer` is always presented. The operator decides whether a should-fix finding warrants an amendment cycle.

**Aggregate shortcuts decompose into per-discovery dispatches.** The `'A'` (amend all that fit < 50% threshold) and `'D'` (defer all) shortcuts are input sugar — they decompose into the same per-discovery dispatch flow as if the operator had typed `(a)` or `(d)` for each discovery individually. There is no batched-amend or batched-defer code path. `'A'` produces one `plan-amend` (or `spec-amend`) dispatch and one `chore(plan): amend` (or `chore(spec): amend`) commit per amended discovery; `'D'` produces one `/spec-flow:defer` invocation and one `chore: defer` commit per deferred discovery. Per-discovery `.discovery-log.md` rows append per the Resolution-commit cell convention (below) regardless of which input form was used.

#### Auto-mode threshold (FR-17)

**Universal threshold (spike-vs-direct decision).** For every admitted change — whether in operator mode or `--auto` mode — the 50% diff-ratio gate determines whether a scope spike runs before `plan-amend` (see T-3 below). This gate is orthogonal to the auto-amend-vs-escalate decision: the scope-spike decision is evaluated first; the auto-mode amend-vs-escalate semantics (below) are a SEPARATE, subsequent decision layered on top.

- `ratio ≥ 0.5` (and the undefined-ratio / zero-cumulative-diff case — treated as infinity per the edge case below) → dispatch scope spike before `plan-amend` (see `plugins/spec-flow/reference/spike-agent.md` `## Threshold reuse`).
- `ratio < 0.5` → direct `plan-amend` without a scope spike.

No new config key. Reuses the 0.5 value from the threshold computation below.

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

**Auto-amend if `ratio < 0.5`.** The orchestrator dispatches the amend flow (plan-amend by default; spec-amend only when the discovery's `(s) amend-spec` option would have been offered per the Triage prompt rules — i.e., the finding text names a missing FR/AC or contradiction in the spec) without operator prompting. The Amendment budget tracking gate still applies — auto-mode does NOT bypass the 5-total / 1-spec-max budget; if the budget is exhausted the auto-amend dispatch is refused exactly as in operator mode.

**Otherwise (`ratio ≥ 0.5`) auto-mode escalates** with the verbatim message:

```
Discovery in <phase> would expand piece by <X>% — exceeding 50% auto-amend threshold. Operator triage required.
```

where `<phase>` is the discovery's source phase ID and `<X>` is `ratio × 100` rounded to one decimal place. After emitting this message the orchestrator falls back to the operator-mode triage prompt (the Triage prompt block above) for THAT discovery only; subsequent discoveries in the same triage event remain in auto-mode and are evaluated independently per the per-discovery rule above.

**Auto-mode never auto-forks or auto-defers.** Fork and defer always require operator triage, regardless of any threshold computation. The auto-mode default applies exclusively to the `amend` choice (and only when `ratio < 0.5`). When the operator-mode triage prompt fires under auto-mode (because of threshold escalation), the operator's choice can still be fork or defer — auto-mode does not constrain the operator's selection, only the auto-resolution path.

#### Amend dispatch

For each discovery the operator routes `amend` (or `amend-spec`):

**Scope-spike pre-step (when threshold exceeded).** When the threshold computation (above) determined `ratio ≥ 0.5` (or undefined-ratio) for this discovery, dispatch the spike agent in `scope` mode before invoking `plan-amend`:

```
Agent({
  description: "Scope change for discovery in <phase-id>",
  prompt: "<inject: mode:scope + the change text (row_text) + current plan.md + diff/neighborhood scope>",
  model: "opus"
})
```

- **On `STATUS: OK`:** read the scoping artifact at `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/<discovery-id>.md`. Extract `Classification:` and `Scope / Task list:` from the artifact. Before passing the classification to `plan-amend`, validate it against the three-value allowlist (`blocking-on-current`, `blocking-on-later: <phase-id>`, `additive: <after-phase-id>`). If the `Classification:` prefix (before any `:`) is not one of `blocking-on-current`, `blocking-on-later`, `additive`, reject with: `Refused — spike artifact Classification field is not a recognized value; re-dispatch spike or escalate.` Do NOT pass an unrecognized value to plan-amend. Pass the classification to `plan-amend` as the placement directive (consumed by Phase 3's `agents/plan-amend.md` `## Context Provided` contract). Proceed to step 1 (plan-amend dispatch).
- **On `STATUS: BLOCKED`:** Before escalating, append a `.discovery-log.md` row for this discovery with `Triage choice: blocked — scope spike BLOCKED` and commit it as `chore(<piece-slug>): block — scope spike BLOCKED (<discovery-id>)`. Then escalate — surface a new `requires-amendment` discovery row with the spike's blocking reason; do NOT dispatch `plan-amend` for this discovery.

**No-bypass gate.** No above-threshold admitted change (ratio ≥ 0.5 or undefined-ratio) may reach `plan-amend` without a completed scope spike — this invariant is enforced by the pre-step above and verified by qa-plan + review-board spec-compliance per NN-P-002 (see `plugins/spec-flow/reference/spike-agent.md` `## No-bypass gate`).

Below-threshold changes (ratio < 0.5) skip the scope spike and proceed directly to step 1.

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
   The `<reason>` is the discovery's `default_triage`-implied reason (`requires-amendment`, etc.) plus the one-line finding summary. When the amend path ran a scope spike before `plan-amend`, append the spike artifact path to the commit subject: `chore(plan): amend — <reason> (spike: spikes/<discovery-id>.md)`. Both files land in the same commit, producing a single coherent amend-with-audit-trail entry in `git log`.

6. **Block-aware placement and resume** — The resume position is determined by the `Classification` field from the scope spike's artifact (passed to `plan-amend` as the placement directive). When no scope spike ran (below-threshold direct amend), classify as `additive` unless the discovery explicitly names a dependent later phase:

   - `blocking-on-current` → the change targets the in-progress phase's own deliverable. Re-open the in-progress phase as `phase_<N>_amend_<K>` (superseding its remainder); resume at that amendment phase immediately.
   - `blocking-on-later: <phase-id>` → a not-yet-started phase depends on the change. Insert `phase_<N>_amend_<K>` before `<phase-id>`; let current WIP finish first, then resume at the amendment phase before `<phase-id>`.
   - `additive: <after-phase-id>` → no existing phase depends on it. Append `phase_<N>_amend_<K>` after `<after-phase-id>` at the dependency-correct slot; current WIP finishes first.

   No amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop. An operator force-stop means the operator explicitly overrides the triage prompt to treat the discovery as `blocking-on-current` — use the same preempt path as that class regardless of what the scope spike returned. Resume re-derives placement from `plan.md` checkboxes + amendment IDs on disk (so a fresh context re-enters at the correct position without in-memory state). The `phase_<N>_amend_<K>` suffix-ID convention (FR-13) is unchanged. Amendment phases run through the full Per-Phase Loop including their own Step 6 QA gate (see "NN-P-002 preservation" below).

   See `plugins/spec-flow/reference/spike-agent.md` `## Placement rule` for the canonical definition.

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

Per FR-14, each piece has a hard amendment budget: **5 amendments total per piece, of which at most 1 may be a spec amendment.** The budget is piece-scoped — the counters survive across all phases of the piece (including amendment phases that pi-010-discovery's FR-13 introduces). They are NOT phase-scoped and they are NOT triage-event-scoped; an amendment dispatched in phase 3's Step 6c counts against the same budget as an amendment dispatched in phase 7's Step 6c or via Step 8's Final Review Triage flow.

**Counters.** The orchestrator maintains two integer counters in piece-scoped state:

- `piece_amendment_count` — total amendments dispatched (plan + spec combined). Initialized to `0` at piece start.
- `piece_spec_amendment_count` — spec amendments only. Initialized to `0` at piece start.

**Counter recovery on session resume.** Per Session Resumability conventions (below), in-memory orchestrator state is not persisted across session boundaries. On execute resume mid-piece (the orchestrator finds plan.md checkboxes partially marked), the counters MUST be recovered by counting committed amendments in the worktree branch's history rather than re-zeroed:

- `piece_amendment_count` = `git log --oneline $piece_start_sha..HEAD --grep '^chore(plan): amend' --grep '^chore(spec): amend' | wc -l`
- `piece_spec_amendment_count` = `git log --oneline $piece_start_sha..HEAD --grep '^chore(spec): amend' | wc -l`

This counts only successful amend commits (failed dispatches produce no commit and correctly don't show in the log). Use `--all-match` only if the grep patterns must AND together; for OR semantics (any one of the patterns) the default disjunctive behavior is correct. Run these recovery commands at the same time the orchestrator captures `phase_<n>_start_sha` from `git rev-parse HEAD` — both are lossless reconstructions from the durable worktree.

**Pre-dispatch budget check.** Before invoking `plan-amend` or `spec-amend` for any discovery (whether operator-chosen or auto-resolved under `--auto`), the orchestrator checks the budget:

When both step 1 (total budget) and step 2 (spec sub-cap) would fire simultaneously for the same dispatch — i.e. `piece_amendment_count >= 5` AND the choice is `amend-spec` AND `piece_spec_amendment_count >= 1` — surface a single merged soft-checkpoint prompt: `Hit spec sub-cap AND total amendment budget — this piece may be under-scoped. Choose: (c) continue / (f) fork / (d) defer / (b) block`. Do not fire two sequential prompts.

1. If `piece_amendment_count >= 5`, route to the soft-checkpoint prompt (below) — the total-budget cap uses the same four-option checkpoint, not a hard refuse. The discovery itself does NOT consume a budget slot unless the operator chooses `(c)` and the dispatch succeeds — only successful dispatches increment counters.
2. If the choice is `amend-spec` AND `piece_spec_amendment_count >= 1`, route to the soft-checkpoint prompt (below) — the spec-amend sub-cap uses the same four-option checkpoint as the total budget, not a hard refuse. The discovery itself does NOT consume a budget slot unless the operator chooses `(c)` and the dispatch succeeds — only successful dispatches increment counters.

**Counter increment on successful amend.** The counters are incremented only after the amend dispatch produces a successful commit (the `chore(plan): amend — ...` or `chore(spec): amend — ...` commit lands cleanly per Amend dispatch step 5/7). The increment rules:

- For ANY successful amend (plan or spec): `piece_amendment_count++`.
- ADDITIONALLY for a successful spec amend: `piece_spec_amendment_count++`. Spec amendments increment BOTH counters — they consume one slot of the 5-total budget AND the 1-spec-max sub-budget.

A failed amend (diff fails `git apply --check` and the operator chooses not to re-dispatch, or the dispatched agent halts with BLOCKED) does NOT increment either counter. The "no extra budget slot for re-dispatch within the same triage event" provision under Amend dispatch step 4 means: a discovery's amend dispatch consumes one slot total, regardless of how many plan-amend/spec-amend invocations the orchestrator runs to produce a clean diff for that one discovery.

**Soft-checkpoint prompt.** When `piece_amendment_count >= 5` (or `piece_spec_amendment_count >= 1` for a spec amendment) would block an amend dispatch, the orchestrator emits a soft-checkpoint prompt rather than a hard refusal. The count is at threshold — the piece may be under-scoped — but the operator decides:

```
Hit <N> amendments — this piece may be under-scoped. Choose:
  (c) continue amending
  (f) fork remaining must-fix work into a new piece
  (d) defer this finding
  (b) block piece
```

Per NN-C-006 (operator confirmation for piece-state-changing operations):

- **On `c` (continue):** dispatch the amendment. Re-surface this same four-option prompt on each subsequent amendment attempt — the count never resets and never hard-blocks. Auto-mode under `--auto` falls back to operator prompt at this juncture (auto-amend cannot dispatch without explicit confirmation above threshold). When no operator is present (unattended `--auto` run), auto-mode defaults to `(d)` defer for the current finding and continues execution.
- **On `f` (fork):** execute the Fork dispatch flow for this discovery, creating a new piece. Halt the current piece's execute and set status to `blocked` (discovery is forked, not deferred).
- **On `d` (defer):** execute the Defer dispatch flow for this discovery. Continue executing the current piece.
- **On `b` (block):** operator-chosen halt. Set the current piece's status to `blocked` in `docs/prds/<prd-slug>/manifest.yaml` with a notes-line citing budget exhaustion, commit the manifest update:
  ```bash
  git add docs/prds/<prd-slug>/manifest.yaml
  git commit -m "chore(<piece-slug>): block — amendment budget exhausted"
  ```
  and exit with: `Halted: piece <piece-slug> status set to blocked (amendment budget exhausted). Re-spec or abandon recommended.`

The count never resets within a piece and never hard-blocks. The soft checkpoint re-surfaces on each subsequent amendment; the operator's `(c)` choice is per-amendment (not a session-wide unlock). See `plugins/spec-flow/reference/spike-agent.md` `## Soft-checkpoint budget` for the canonical definition.

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

**Resolution-commit cell convention.** The orchestrator does NOT pre-compute or amend SHAs into the row. Instead, the row's `Resolution commit` cell records the commit subject (e.g., `chore(plan): amend — auth helper missing X`) which uniquely identifies the commit when grepped (`git log --grep "<subject>"`). When the amend path ran a scope spike before `plan-amend`, the orchestrator appends the spike artifact path to the commit subject inside the cell: `abc1234 chore(plan): amend — auth helper missing X (spike: spikes/<id>.md)`. No new column is added — the reference is embedded in the existing `Resolution commit` cell. The row append is committed in the SAME commit as the resolution itself, but the actor that stages the row depends on the dispatch type:

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

Under `deferred_commit: auto` (read at Step 0 / Phase Scheduler), initialize the Phase Group journal — the durable, git-free checkpoint defined in `reference/deferred-commit-journal.md` (schema Tier 1). Write the journal with `group_start_sha` set to this HEAD, `group_letter` set to the active group's letter, and an empty `sub_phases` map (`{}`). The journal is then updated incrementally as each sub-phase transitions — its `sub_phases` entry records the per-sub-phase status `pending` → `red-done` → `green` / `failed` (and, at `red-done`, the sub-phase's `red_manifest_hashes`). The journal is never committed and is removed after the barrier work-commit (see `reference/deferred-commit-journal.md` Lifecycle). Under `deferred_commit: off` no journal is written — the legacy concurrent path (Step G4) does not use one.

### Step G2: Validate sub-phase disjointness

For each Sub-Phase in the group, parse its `**Scope:**` block. Cross-check for pairwise file-path overlap. If overlap exists, log a warning and fall back to serial execution (each sub-phase runs as a flat phase through the Per-Phase Loop).

### Step G3: Per-sub-phase pre-flight

For each sub-phase (in parallel — pre-flight is read-only and cheap), run the existing Step 1b pre-flight against the sub-phase's scope. Produce per-sub-phase `## Pre-flight snapshot` and `## Orchestrator pre-decisions` attachments. These are scoped to the sub-phase only — a Phase Group's pre-flight is not a union.

### Step G4: Dispatch sub-phase pipelines (concurrent git-free under deferred_commit: auto)

Branch on the `deferred_commit` knob the orchestrator read at Step 0 / Phase Scheduler (declared in `templates/pipeline-config.yaml`). `deferred_commit: auto` is the **default** and selects the concurrent git-free section immediately below; `deferred_commit: off` selects the legacy per-sub-phase-commit dispatch (gated further down).

#### Concurrent git-free section (`deferred_commit: auto` + `phase_groups: auto`/`always`)

Dispatch the group's `[P]` sub-phases **concurrently** on the git-free foundation — each runs its full Red → Build cycle writing to the working tree with **NO `git add` and NO `git commit`**. Because nothing stages until the barrier (Step G9b), the shared-index race (Race-1) cannot occur even under concurrency (the git-free constraint is what removes the race, not serialization). Disjointness of sub-phase `**Scope:**` is validated at dispatch (overlap → serial fallback, existing rule).

**INV-9 runtime isolation.** Each concurrently-dispatched sub-phase receives an **isolation envelope** in its dispatch prompt: a unique `TMPDIR` (e.g. `$TMPDIR/sf-<group>-<n>`, where `<group>` is the Phase Group letter and `<n>` is the sub-phase index) — and, only when the plan/phase explicitly declares them, isolated port and DB-name values. The envelope also includes a stated **parallel-safety contract**: the sub-phase's tests must not assume a shared mutable global resource beyond what the envelope isolates. **File-disjoint is NOT runtime-disjoint (INV-9)**: two sub-phases may write to different files yet collide on a shared `/tmp` path, port, or database — the envelope makes them runtime-disjoint. If a concurrent group fails in a manner attributable to a runtime resource collision (non-deterministic, sibling-dependent failure that passes in isolation), the orchestrator performs a **serial replay** of the whole group before declaring a real failure — see the G6 `Runtime collision` triage row. The worst case degrades to *slower*, never to *wrong* or *silently-green*.

**Deferred-group flag injection (REQUIRED — NN-C-008 self-contained prompts).** `agents/tdd-red.md` and `agents/implementer.md` gate their git-free behavior on a deferred-group flag the orchestrator passes in their prompt; without it they fall back to their normal `git add` / `git commit`, which would defeat the git-free constraint. The orchestrator MUST inject an explicit deferred-group flag — a `Deferred Phase Group: yes` line, placed alongside the existing `Mode:` flag on/near line 1 — into BOTH the sub-phase's Red (tdd-red) prompt and its Build (implementer) prompt. This tells Red to write-without-staging (no `git add`) and tells Build to write-without-staging-or-committing (no `git add`, no `git commit`); all staging/commit is deferred to the barrier (Step G9b). Under `deferred_commit: off` (the legacy concurrent section below) this flag is NOT set — those agents stage/commit per sub-phase as before.

**This rule is cross-cutting — it applies to EVERY (re-)dispatch of `tdd-red` / `implementer` for a sub-phase of a group running under `deferred_commit: auto`, not just the initial dispatch here.** Concretely, the `Deferred Phase Group: yes` flag MUST be re-injected on ALL of the following dispatch sites alike: (1) the initial G4 sub-phase dispatch in this section; (2) the Step G6 auto-triage recovery re-dispatches (the Contamination and Scope-violation matrix rows' re-run-from-Red, and the G9b barrier anti-cheat reject path's "re-dispatch the offending sub-phase's Build"); (3) the Session-Resumability mid-group resume re-run (the incomplete-sub-phase "re-run from Red"); and (4) the Step G6 auto-triage "BLOCKED — pre-decision mismatch" recovery re-dispatch (re-run Step 1b pre-flight, then re-dispatch with fresh pre-decisions). A flagless re-dispatch makes the agent fall back to per-sub-phase `git add` / `git commit`, reintroducing the shared-index race and breaking the G9b barrier (the path would already be committed, so the union `git add` and the working-tree anti-cheat would operate on already-committed state). Treat the flag as mandatory on every (re-)dispatch for the lifetime of the deferred group, never only on first dispatch. Under `deferred_commit: auto` with concurrent dispatch, each (re-)dispatch MUST ALSO carry the concurrency mode and the sub-phase's isolation envelope (see Phase 3 / FR-7 — `TMPDIR` per sub-phase, and optionally port/DB-name). A flagless or envelope-less re-dispatch reverts to serial/per-commit behavior and breaks the barrier.

For each sub-phase, concurrently:

- **Red** writes its failing tests to the working tree and emits its SHA-256 manifest, but does **not** stage them (no `git add`). The orchestrator does NOT record Red's self-reported hashes directly; instead, for each Red test file the orchestrator runs `git hash-object -w -- "$path"` (writes the blob to the object store and returns the blob SHA), records `{path: blob_sha}` in the journal `red_manifest_hashes`, sets the journal top-level `anchor: blob` marker, and flips the sub-phase to `red-done` (transitioning it from `pending`). Red's emitted manifest is retained only as an advisory cross-check — a mismatch between Red's self-reported SHA-256 and the orchestrator's blob SHA is a soft warning, not a hard stop. The orchestrator-produced blob SHA is authoritative; the agent's self-reported manifest is not the integrity baseline (FR-1).
- **Build** writes production code and runs its oracle **against the working tree**, **scoped to THIS sub-phase's own Red test IDs** (the FAILED set captured in `phase_N_oracle_block`, re-run path-scoped per Step 3 invariant (b) at line 509 / the path-scoped re-run idiom at line 408). Scoping is required under concurrency: a sibling sub-phase's still-red tests are on the shared working tree, and an unscoped whole-suite oracle would fail spuriously (Race-2). The **whole-non-integration-suite green** invariant (Step 3 invariant (a), line 506) is re-asserted **ONCE at the barrier (Step G9b)** after every sub-phase is individually green — never per sub-phase under concurrency. Build does **not** commit (no `git commit`).
- The orchestrator flips the sub-phase to `green` on oracle pass, or `failed` on oracle/QA failure, writing the transition to the journal (`reference/deferred-commit-journal.md` Lifecycle Step 2) before dispatching the next sub-phase.

Each sub-phase runs the **same Verify (Step 4, Audit/Full selection) and QA-lite checks as the legacy per-sub-phase internal flow below** — including the `orchestrator_fast_mode: true` skip of the `qa-phase-lite` dispatch. The Verify/QA-lite gates are NOT removed here; only the commit timing differs (every `git add`/`git commit` is deferred to the barrier, per the git-free constraint above).

No sub-phase stages or commits anything; all staging is deferred to the group barrier (Step G5), where the union of all sub-phase scopes is committed once (see `reference/deferred-commit-journal.md` Barrier commit recipe).

**Worked example (3-sub-phase concurrent trace).** Group `A` with sub-phases `A.1`, `A.2`, `A.3`. Journal initialized at G1 with empty `sub_phases`. Concurrent dispatch — `A.1`, `A.2`, and `A.3` all dispatched together, each advancing independently:

- `A.1`: `pending` → Red writes `tests/.../test_a1.py` (unstaged), orchestrator blob-anchors → `red-done` → Build writes `src/.../a1.py` (unstaged), oracle **scoped to A.1's Red IDs** green → `green`. **No `git add`, no `git commit`.**
- `A.2`: `pending` → Red writes `tests/.../test_a2.py` (unstaged), orchestrator blob-anchors → `red-done` → Build writes `src/.../a2.py` (unstaged), oracle **scoped to A.2's Red IDs** green (A.1's still-red tests do not pollute A.2's oracle — no Race-2) → `green`. **No commit.**
- `A.3`: same pattern, oracle scoped to A.3's Red IDs → `green`. **No commit.**

Journal writes are per-sub-phase and incremental (one entry at a time, concurrency-safe). Net: **zero per-sub-phase commits**, journal records `pending` → `red-done` → `green` for each sub-phase independently. All staging/commit happens once at the barrier (Step G9b). Contrast with `deferred_commit: off` below, which commits per sub-phase.

#### Legacy concurrent section (`deferred_commit: off`)

For each `[P]`-marked sub-phase in the group, launch its full internal pipeline concurrently. Each pipeline runs independently through its own Red → Build → Verify → QA-lite cycle, anchored at its own `sub_phase_start_sha`.

Dispatch mechanism: issue all sub-phase Red agent dispatches in the same orchestrator turn. When a sub-phase's Red completes, immediately dispatch its Build agent (do not wait for sibling Reds). Same for Build → Verify → QA-lite. Each sub-phase progresses independently; sibling sub-phases are not sync barriers except at the group-end barrier (Step G5).

Rate limiting: dispatch all `[P]` sub-phases in parallel by default. If you hit inference-provider rate limits on large groups (observed when 8+ sub-phases fire concurrently against Opus/Sonnet tiers simultaneously), fall back to serial execution for that group and log the cause. No config knob is exposed today — rate-limit handling is the orchestrator's responsibility, not the plan author's.

Per-sub-phase internal flow — each sub-phase runs the same checks as the Per-Phase Loop:
- Red step (Step 2) — stages tests (sub-phase-scoped), emits its own `phase_N_red_stage_manifest` keyed by sub-phase id
- Build step (Step 3) with Step 3 item 7 AC matrix validation gate + item 8 post-commit integrity + reconciliation gates
- Verify step (Step 4) with Audit/Full mode selection
- QA-lite step — **fast mode skip:** if `orchestrator_fast_mode: true`, skip the `qa-phase-lite` dispatch for this sub-phase. Proceed to the next sub-phase pipeline step. Otherwise: dispatch `qa-phase-lite.md`, Sonnet. Iter-until-clean per `plugins/spec-flow/reference/qa-iteration-loop.md` — full review on iter-1, focused re-review on iter-2+, `qa_max_iterations`-limited circuit breaker (per qa-iteration-loop.md).
- Sub-phase Progress is implicit (no separate progress commit per sub-phase — the group progress commit covers all)

**Shared staging area safety — `deferred_commit: off` only (v2.7.0).** This paragraph describes the legacy concurrent shared-index path and applies only under `deferred_commit: off`. Parallel sub-phases share the same git index, but scope disjointness is enforced at Step G2 (pairwise literal-path check) and literal-path staging discipline in Rule 6 (tdd-red) + Rule 8 (implementer) means each sub-phase's `git add` + `git commit` references only its own paths. A sibling sub-phase's staged-but-uncommitted tests remain in the index but are NOT swept into another sub-phase's unified commit because the implementer commits by literal path. The orchestrator's Step 3.7b reconciliation (commit file list = sub-phase's Red manifest ∪ sub-phase's Build reported files) catches any cross-contamination.

Under `deferred_commit: auto` the section is git-free (concurrent) — there is no shared-index staging race; see `reference/deferred-commit-journal.md`.

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

Validate post-Refactor: tests still green (run oracle once over the union), no files outside the union modified. **Under `deferred_commit: auto`** the sub-phase files are untracked (nothing committed until Step G9b), so a committed `git diff` would show nothing — compute "modified" against the **working tree** over the journal `sub_phases` scope union per `reference/deferred-commit-journal.md` §Working-tree enumeration over an untracked union (deferred_commit: auto). Reject any working-tree path outside the union.

### Step G8: Group Deep QA (Opus)

**Fast mode skip:** if `orchestrator_fast_mode: true`, skip Step G8 entirely. No Opus Group Deep QA dispatch. Proceed to Step G9 (hook sweep).

---

Dispatch the `qa-phase.md` agent at Opus tier. Compose the prompt using the existing Step 6 surface-map composition, but scoped to the group:

- `## Files changed` — from `git diff --numstat $group_start_sha..HEAD`. **Under `deferred_commit: auto`** the sub-phase files are untracked until the Step G9b work-commit, so `git diff --numstat $group_start_sha..HEAD` is empty pre-barrier; in that case derive the file list (and numstat) from the **journal `sub_phases` scope union** read against the **working tree**, computed per `reference/deferred-commit-journal.md` §Working-tree enumeration over an untracked union (deferred_commit: auto).
- `## Public symbols added or modified` — union across all sub-phase impl files
- `## Integration callers` — resolved for the union of public symbols
- `## Diff` — collapsed per-sub-phase if total > 500 LOC
- `## AC Coverage Matrix (from Build)` — union of all sub-phases' matrices, sectioned by sub-phase
- `## Phase ACs` — union of all sub-phase ACs
- `## Non-negotiables` — unchanged

If Group Deep QA returns must-fix: run the iter-until-clean loop per plugins/spec-flow/reference/qa-iteration-loop.md (no skip; `qa_max_iterations`-limited circuit breaker), dispatching fix-code agents for findings. Each fix-code dispatch operates on the specific sub-phase scope the finding points to.

### Step G9: Step 6b hook sweep over the group diff

Run `pre-commit run --files $(git diff --name-only $group_start_sha..HEAD)`. Same autofix-or-fix-code recovery as the flat-phase Step 6b, once across the group.

> **Coherence note (`deferred_commit: auto`).** Under `deferred_commit: auto` the sub-phase files are untracked until the Step G9b work-commit lands, so `git diff $group_start_sha..HEAD` is empty pre-commit; in that case the hook-sweep file list is the working-tree union (the journal `sub_phases` scope) rather than the committed group diff — enumerate it per `reference/deferred-commit-journal.md` §Working-tree enumeration over an untracked union (deferred_commit: auto).

### Step G9b: Barrier work-commit (deferred_commit: auto)

This step runs ONLY under `deferred_commit: auto`. Under `deferred_commit: off` (and for flat phases) there is no barrier work-commit — each phase commits its own work, and this step is skipped. See `plugins/spec-flow/reference/deferred-commit-journal.md` `## Barrier commit recipe` for the canonical recipe; this step is its orchestration in the group barrier.

At the barrier every sub-phase is `green` in the journal. The deferred commits now collapse into a single work-commit covering the union of every sub-phase's scope:

> **Ordering guard (hook-autofix vs anti-cheat — SF3).** The Step G9 hook sweep runs BEFORE this G9b re-hash. If a formatter hook (the trusted sweep) autofixes a Red test file during G9, the working-tree content will no longer match the journal `red_manifest_hashes` captured at `red-done`, and this re-hash would FALSELY trip the anti-cheat. Guard: **after the G9 sweep applies any autofix, re-anchor via `git hash-object -w` for every Red test file the (trusted) sweep modified** (re-writes the post-sweep blob to the object store and updates the journal entry) — so this re-hash compares against the post-sweep baseline. (The sweep is trusted by construction; the anti-cheat targets Build-agent tampering, not formatter autofixes.) Equivalent alternative: run this G9b anti-cheat re-hash BEFORE the G9 sweep. The pipeline uses the re-anchor-after-sweep guard.

1. **Re-hash each sub-phase's Red tests in the working tree against the journal `red_manifest_hashes`.** For every sub-phase entry in the journal `sub_phases`, re-hash each Red test file (the keys of that sub-phase's `red_manifest_hashes`) **as it sits in the working tree** (not as committed in HEAD — there is no per-sub-phase HEAD commit) and compare against the orchestrator-written blob SHA recorded at `red-done` (FR-2):

   ```bash
   for path in <this sub-phase's red_manifest_hashes keys>; do
     wt_blob=$(git hash-object -- "$path")
     manifest_blob=<journal red_manifest_hashes[path]>
     [ "$wt_blob" = "$manifest_blob" ] || echo "barrier integrity fail: $path"
   done
   ```

   If the journal lacks the `anchor: blob` marker (written by ≤5.1.0), verify with `sha256sum` instead (see resume fallback).

   Any mismatch means a Build agent modified one of Red's tests to make it pass. This gate re-hashes the Red **test files only** — production files in each sub-phase's scope are **trusted by association** (NOT re-hashed — ADR-5), the same trust model the flat-phase gate uses for production code. It detects test-file tampering during Build; it does NOT detect production-file drift across a resume (a known limitation — deeper integrity anchoring is deferred to the Tier-2 / `journal_tier` future in `reference/deferred-commit-journal.md`). It is the working-tree analogue of the flat-phase content-hash gate (evaluated against the working tree instead of HEAD because there is no per-sub-phase HEAD commit), not a strictly stronger check. Reject within the 2-attempt budget (re-dispatch the offending sub-phase's Build without touching Red's tests — re-inject the `Deferred Phase Group: yes` flag on this re-dispatch, see the G4 flag-injection rule); escalate on second failure.

2. **Run the whole-non-integration-suite oracle over the union working tree.** After every sub-phase is `green` and the anti-cheat blob verify (step 1) passes, run the **whole-non-integration-suite** oracle ONCE over the union working tree (all sub-phase files coexist for the first time at this point). Require `0 failed` across the non-integration suite, composing with pi-014's M2/M4 integration/non-integration split (if `integration_registry` is non-empty, exclude `[integration]`-marked tests per the M2 rule). A failure here is a group reject — route to the existing G9b integrity-failure/recovery path (re-dispatch the failing sub-phase from Red under the 2-attempt budget; escalate on second failure).

3. **Compute the union.** Union = ⋃ sub-phases of (Red manifest paths ∪ Build files), read from the journal `sub_phases` `scope` arrays (each `scope` is already Red manifest ∪ Build production paths, literal paths only).

   **Empty-union precondition.** If the computed union is empty, do NOT run `git add` / `git commit` — an empty pathspec is unsafe and meaningless (`git add` with no paths is a no-op or stages everything depending on form; `git commit -- ` with no paths errors). An empty union at the barrier when every sub-phase is `green` is a logic error (a green sub-phase must have produced files): skip the work-commit and log/escalate to human rather than committing.

4. **Stage then commit the union.** A bare `git commit -- <union>` fails with `did not match any file(s) known to git`, because the git-free sub-phase files were never staged — they are untracked. So `git add` first, then commit with the same pathspec:

   ```bash
   git add -- <union>
   git commit -m "<work msg>" -- <union>
   ```

   The explicit `git add -- <union>` is required (it tracks the previously-untracked files); the pathspec on `git commit` keeps the commit scoped to exactly the union and keeps the journal — never in `<union>` — out of the commit.

5. **Reconcile the work-commit against the union.** `git show --name-only --pretty= HEAD | sort` must equal the sorted union; reject any stray (in commit but not in union) or missing (in union but not in commit):

   ```bash
   git show --name-only --pretty= HEAD | sort > /tmp/work_commit_files.txt
   # write the sorted union to /tmp/union_files.txt
   diff /tmp/work_commit_files.txt /tmp/union_files.txt
   ```

6. **Remove the journal.** Once the work-commit lands and reconciles clean, remove the journal file (`rm .phase-group-journal.json`) — Lifecycle Step 3. After deletion there is no journal until the next deferred group starts.

**Worked example (guard 2c — 3 sub-phases → ONE work-commit = exact union, journal excluded).** Group `A` with three green sub-phases whose journal `scope` arrays are `A.1 = [src/parser/tokens.py, tests/parser/test_tokens.py]`, `A.2 = [src/parser/ast.py, tests/parser/test_ast.py]`, `A.3 = [src/parser/eval.py, tests/parser/test_eval.py]`. The union is the six files concatenated:

```bash
git add -- src/parser/tokens.py tests/parser/test_tokens.py \
           src/parser/ast.py tests/parser/test_ast.py \
           src/parser/eval.py tests/parser/test_eval.py
git commit -m "feat(parser): group A — tokens, ast, eval" -- \
           src/parser/tokens.py tests/parser/test_tokens.py \
           src/parser/ast.py tests/parser/test_ast.py \
           src/parser/eval.py tests/parser/test_eval.py
```

These 3 sub-phases produce exactly ONE work-commit whose `--name-only` file list equals the exact union of all six files; the journal `.phase-group-journal.json` is excluded from the commit (it is never in the pathspec) and is removed afterward.

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

Under `deferred_commit: auto` this plan.md progress commit is the **second, separate commit** of the group — it lands AFTER the Step G9b barrier work-commit, for a net of 2 commits per group (one work-commit covering the sub-phase union, then this progress commit). The barrier work-commit is NOT folded into G10: the pathspec here stays `plan.md` only, and the sub-phase code/test files belong to the G9b work-commit, never to this commit. (Under `deferred_commit: off` and for flat phases there is no G9b work-commit; G10 is the sole group commit.)

Advance to next top-level unit in plan.md (another group, or a flat phase, or end-of-piece → Final Review).

## Auto-triage decision matrix (used by Step G6)

When Step G5 ends with any failed sub-phases, the orchestrator auto-triages each failure against this matrix. One recovery action per sub-phase per pass; matrix categories marked "escalate immediately" bypass recovery.

### Pass 1 triage table

| Failure signature | Detection signal | Recovery action | Iterations |
|-------------------|------------------|-----------------|------------|
| Oracle defect — one file, one function, clear error | Test output names a single file + function; fix-code trial stays < 50 LOC | Dispatch fix-code targeting the implementation | 1 |
| Oracle defect — multi-file or repeated-pattern failure | Multiple impl files implicated OR fix-code attempted 2× without progress during the original Build | Dispatch Refactor at sub-phase scope to restructure the approach | 1 |
| Hook failure — lint/format/type-check | Pre-commit output names tool + rule; diff < 20 LOC | Inline autofix if ruff/mypy suggest a concrete patch; otherwise fix-code | 1 |
| Contamination — implementer modified test files during Build (Mode: TDD) | Orchestrator's test-file diff check flagged modified tests | File-scoped reset (SPLIT form — see recovery note below): `git restore --source=$group_start_sha --worktree -- <MODIFIED paths only>` (files that existed at `group_start_sha`) AND, separately, `rm -f -- <CREATED paths>` + `git rm --cached --ignore-unmatch -- <CREATED paths>` for files the sub-phase created. NEVER a single `git restore` over the mixed full scope. Then reset the sub-phase's journal entry to `status: pending` (clear stale `red_manifest_hashes`) and re-run the sub-phase from Red with the explicit "do not modify tests" reminder (re-inject the `Deferred Phase Group: yes` flag on this re-dispatch under `deferred_commit: auto` — see the G4 flag-injection rule), advancing the journal entry through `red-done`/`green` as the re-run progresses | 1 |
| Scope violation — Build touched files outside declared `**Scope:**` | `git diff --name-only` shows paths outside the sub-phase scope block | File-scoped reset (SPLIT form — see recovery note below): `git restore --source=$group_start_sha --worktree -- <MODIFIED paths only>` (files that existed at `group_start_sha`) AND, separately, `rm -f -- <CREATED paths>` + `git rm --cached --ignore-unmatch -- <CREATED paths>` for files the sub-phase created. NEVER a single `git restore` over the mixed full scope. Then reset the sub-phase's journal entry to `status: pending` (clear stale `red_manifest_hashes`) and re-run the sub-phase from Red with the scope violation called out in the prompt (re-inject the `Deferred Phase Group: yes` flag on this re-dispatch under `deferred_commit: auto` — see the G4 flag-injection rule), advancing the journal entry through `red-done`/`green` as the re-run progresses | 1 |
| QA-lite must-fix — plan misalignment or local defect | QA-lite `### must-fix` names file:line inside the sub-phase | Dispatch fix-code targeting the finding | 1 |
| QA-lite must-fix — cross-sub-phase concern | QA-lite finding names files in another sub-phase | Escalate immediately — group decomposition is wrong | — |
| BLOCKED — plan ambiguity | Agent returned BLOCKED with ambiguity reason | Escalate immediately | — |
| BLOCKED — architecture conflict | Agent returned BLOCKED citing non-negotiable | Escalate immediately | — |
| BLOCKED — pre-decision mismatch | LOC estimate or symbol-presence pre-decision contradicted by filesystem | Re-run Step 1b pre-flight for this sub-phase; re-dispatch with fresh pre-decisions (under `deferred_commit: auto`, re-inject the `Deferred Phase Group: yes` flag on this re-dispatch — see the G4 flag-injection rule) | 1 |
| Runtime collision — concurrent group failed in a manner attributable to a shared runtime resource (e.g. identical `/tmp` path, port, or DB collision; non-deterministic sibling-dependent failure) | Heuristic: the group failed but each sub-phase passes in isolation (re-run the failing sub-phase alone and it succeeds) | **Serial-replay backstop**: re-run the whole group **serially** (dispatching sub-phases one at a time, in order, git-free — the same Step G4 protocol but sequential rather than concurrent, with no per-sub-phase `git add` or `git commit`) before declaring failure. Only a failure that PERSISTS under serial replay is a real failure — escalate. A failure that disappears under serial replay was a collision; the replay result is the authoritative outcome. The replay is logged (NN-C-006 passive surface). Degrades to *slower-never-wrong*: the worst case is slower, never wrong or silently-green. | 1 |
| All sub-phases in group failed | Pass 1 has zero successes | Escalate immediately — likely spec or plan problem | — |
| Majority share a root cause | ≥50% of failures share a common error signature (same missing type, same fixture path issue) | Escalate immediately — group-level structural issue | — |

Recovery actions for different sub-phases run in parallel when their scopes remain disjoint. Reset-and-re-dispatch (contamination, scope violation) runs serially with the sub-phase's re-dispatched Build.

> **File-scoped recovery note (split form + re-entrancy + journal write-back).** The Contamination and Scope-violation rows above use the SPLIT recovery form from `reference/deferred-commit-journal.md` §File-scoped recovery recipe. This is mandatory, not stylistic: `git restore --source=<sha> --worktree -- <pathspec>` ABORTS the entire operation (restores nothing) if the pathspec includes a path that did not exist at `<sha>` — i.e. any file the sub-phase CREATED (a Red sub-phase almost always creates its test file). So the restore pathspec must be the **modified subset only** (paths that existed at `group_start_sha`); created files are removed separately. Recovery must be **re-entrant / idempotent** (a crash between the `rm` and the re-run must not hard-error on re-entry): use `rm -f -- <created paths>` and `git rm --cached --ignore-unmatch -- <created paths>`, never bare `rm` / `git rm --cached`. **Scope-path sanitization (defense for interpolated paths):** before using any journal `scope` entry in an `rm` / `git restore` pathspec, reject any entry that is empty, `.`, `/`, absolute, or contains a `..` segment. **Journal write-back (closes the recovery→resume loop):** before re-running, reset the recovering sub-phase's journal entry to `status: pending` and clear its stale `red_manifest_hashes`; then advance it through `red-done` (Red re-stages, new manifest recorded) → `green` (Build oracle passes) as the re-run progresses. Without this, the entry stays `failed`, and a later mid-group resume (Session Resumability) re-resets the now-good sub-phase and re-runs it — wasting work and clobbering any G7 refactor.

### Pass 2 — focused re-check on recovered sub-phases only

After pass-1 recovery actions complete:

1. Capture `pass1_end_sha` at the moment pass 2 begins (HEAD after recovery fixes landed). **Under `deferred_commit: auto`** there is no recovery commit (recovery re-dispatches Build git-free; nothing lands until the Step G9b barrier), so `pass1_end_sha` equals `group_start_sha` and the commit-range delta below is empty — see the working-tree fallback in step 2.
2. For each sub-phase that had a recovery action, dispatch QA-lite with `Input Mode: Focused re-review` and the fix delta (`git diff $pass1_end_sha..HEAD -- <sub-phase scope>`). **Under `deferred_commit: auto`** there is no recovery commit, so the focused re-review delta is the **working-tree change over the sub-phase scope** — NOT a commit-range diff; compute it (scoped to the single sub-phase's scope) per `reference/deferred-commit-journal.md` §Working-tree enumeration over an untracked union (deferred_commit: auto), or pass the re-dispatched Build's reported file list verbatim.
3. Successful sub-phases from pass 1 are NOT re-reviewed — they are locked in.
4. Fix-code within pass 2 still respects the standard 2-attempt orchestrator circuit breaker per sub-phase.

### Hard cap

**2 total passes.** If any sub-phase still fails after pass 2, escalate to human. No pass 3. Either the sub-phase has a genuine blocker (spec ambiguity, architecture conflict) or the group decomposition was wrong — either way, more iteration likely wastes tokens.

### What stays committed during failures

**Under `deferred_commit: off` (legacy concurrent path — per-sub-phase commits exist):**
- Successful sub-phases' commits stay live
- Pass-1 recovery commits stay live (each runs hooks and passes before landing)
- If the group ultimately escalates to human, the human inspects the worktree's partial state

**Under `deferred_commit: auto` (concurrent git-free — NO per-sub-phase or per-recovery commits exist until the Step G9b barrier):**
- There are no sub-phase commits and no recovery commits to "stay live" — all sub-phase/recovery work is **uncommitted in the working tree** until the barrier work-commit lands. On abort, the working tree holds the partial state and the **journal** records per-sub-phase progress (`green` / `failed` / etc.), so a resume knows what to trust and what to recover (see Session Resumability + `reference/deferred-commit-journal.md` §Resume algorithm).
- If the group escalates to human, the human inspects the worktree's partial state plus the journal.

**Whole-group human-abort (both modes):** `git reset $group_start_sha` cleanly rolls back the whole group if the human decides to abort. This SHA-targeted `git reset` is used ONLY for a whole-group human-abort (tearing down the entire group); it is NEVER used for in-group sub-phase recovery — sub-phase recovery is always file-scoped, in the SPLIT form: `git restore --source=$group_start_sha --worktree -- <MODIFIED paths only>` for files that existed at the baseline, plus `rm -f -- <created paths>` + `git rm --cached --ignore-unmatch -- <created paths>` for files the sub-phase created (never a single `git restore` over the mixed full scope, which aborts on created paths) per the Contamination and Scope-violation rows above, so a recovered sub-phase never clobbers its green siblings' work.

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

### Step 1: Iteration 1 — Full Review (8 Parallel Agents; 9 in fast mode)

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

**Resolve the diff base once** (used by every `git diff <base>..HEAD` below):

```bash
# Try origin/HEAD (fastest — works for most GitHub repos)
default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
# If that's empty, try the remote's advertised HEAD branch
if [ -z "$default_branch" ]; then
  default_branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
fi
# If still empty, read from .spec-flow.yaml
if [ -z "$default_branch" ]; then
  default_branch=$(grep '^default_branch:' .spec-flow.yaml 2>/dev/null | awk '{print $2}')
fi
# All sources exhausted — refuse to guess
if [ -z "$default_branch" ]; then
  echo "ERROR: cannot resolve default branch (no origin/HEAD, no origin remote, no .spec-flow.yaml default_branch:) — set default_branch: in .spec-flow.yaml" >&2
  exit 1
fi
```

(execute uses a strict 4-tier resolver: `git symbolic-ref` → `git remote show origin` → `.spec-flow.yaml default_branch:` → loud error. It does NOT fall back to `main` or `master` guesses — see ADR-3.)

```bash
git diff "$default_branch"..HEAD
```

### Step 1a: Pre-board coherence linter self-check

Before dispatching the review board, run a mechanical coherence self-check over any `SKILL.md` this piece touched. This is a deterministic gate that runs **BEFORE** — and never replaces — the human review board (NN-P-002); it mechanizes detection of step-reference, pointer/cross-ref, and config-branch-parity defects so the board's human read isn't spent on issues a linter can catch.

1. **Scope detection.** Compute the changed-file set:
   ```bash
   git diff "$default_branch"..HEAD --name-only
   ```
   Filter it for paths matching `skills/*/SKILL.md` (any `skills/<name>/SKILL.md` path, whatever the leading directory). When the piece's diff touches **no** `SKILL.md`, this self-check is a **silent no-op** — skip directly to the board dispatch below.
2. **Run the linter** over exactly those changed `SKILL.md` paths:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/hooks/lint-skill-coherence" <the changed SKILL.md paths>
   ```
3. **Non-zero exit (invariant-1–3 violation) is must-fix.** This self-check runs **before** the board, so it does not reuse Step 3's board-reviewer re-dispatch loop — it reuses only the **`fix-code` dispatch + 3-iteration circuit-breaker mechanics** that Step 3's fix loop uses, driven by the **linter** rather than by board findings: dispatch `fix-code` (Sonnet, `agents/fix-code.md`) with the linter findings, commit the fix, then **re-run the linter** over the changed `SKILL.md` paths. Repeat until the linter exits `0` or the same **3-iteration circuit breaker** fires (escalate to a human on the 3rd cycle without a clean exit). Do not dispatch the board while the linter is still red.
4. **`WARNING:` lines (invariant-4, state-field producer→consumer) are advisory only** — surface them for visibility, but they do NOT change the exit code and do NOT block the board.

Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<role>.md` and dispatch ALL EIGHT concurrently with `Input Mode: Full`:

```
Agent({ description: "Blind review (iter 1, full)", prompt: <review-board-blind.md + Input Mode: Full + diff only>, model: "opus" })
Agent({ description: "Edge case review (iter 1, full)", prompt: <review-board-edge-case.md + Input Mode: Full + diff + codebase note>, model: "opus" })
Agent({ description: "Spec compliance review (iter 1, full)", prompt: <review-board-spec-compliance.md + Input Mode: Full + diff + spec + plan + (charter NN-C/CR + prd NN-P for claim verification)>, model: "opus" })
Agent({ description: "PRD alignment review (iter 1, full)", prompt: <review-board-prd-alignment.md + Input Mode: Full + diff + spec + PRD + manifest>, model: "opus" })
Agent({ description: "Architecture review (iter 1, full)", prompt: <review-board-architecture.md + Input Mode: Full + diff + charter (all charter skills at the active charter root resolved per plugins/spec-flow/reference/charter-location.md — <charter_root>/skills/charter-*/SKILL.md, <charter_root> ∈ {.github, .claude}, if present) + NN-C + NN-P>, model: "opus" })
Agent({ description: "Security review (iter 1, full)", prompt: <review-board-security.md + Input Mode: Full + diff + spec (for trust boundary context)>, model: "opus" })
Agent({ description: "Ground-truth review (iter 1, full)", prompt: <review-board-ground-truth.md + Input Mode: Full + diff + spec (for known/expected results and worked examples)>, model: "opus" })
Agent({ description: "Integration/path-coverage review (iter 1, full)", prompt: <review-board-integration.md + Input Mode: Full + diff + "read beyond the diff to enumerate every wired path across an integration boundary">, model: "opus" })
```

**Change-track Final Review (when `track = "change"`):**
When `track = "change"`, dispatch exactly **7 agents** (not 8 or 9):
- `review-board-architecture` (with all charter files)
- `review-board-blind`
- `review-board-edge-case`
- `review-board-security`
- `review-board-spec-compliance` (with `spec_path` = `brief.md` as the spec reference)
- `review-board-ground-truth` (with `spec_path` = `brief.md` for any known/expected results)
- `review-board-integration` (with diff + "read beyond the diff to enumerate every wired path across an integration boundary")

SKIP: `review-board-prd-alignment` — no PRD in change-track; this agent is explicitly excluded for `track = "change"`.

When `track = "piece"`, the existing 8-standard-agent dispatch runs unchanged.

**Fast mode — 9th board member:** if `orchestrator_fast_mode: true`, additionally dispatch concurrently:

```
Agent({
  description: "Test quality review — Piece Full (fast mode compensation, iter 1)",
  prompt: <verify.md + "Mode: Piece Full\n\n" + full piece diff (git diff $default_branch..HEAD) + all spec ACs (all phases, from spec.md) + "Tests verified per-phase — do NOT re-run the test suite.">,
  model: "opus"
})
```

This 9th agent compensates for the per-phase `qa-tdd-red`, `qa-phase`, and `qa-phase-lite` dispatches that fast mode skips.

### Step 2: Triage

Collect findings from all board agents (8 in standard mode; 9 in fast mode — the 9th is `verify-piece-full`). Deduplicate (same issue reported by multiple reviewers). Classify:
- `must-fix` — blocks merge; amendment-eligible in Step 8 triage
- `should-fix` — non-blocking improvement; addressed via fix-code loop (same iter loop) if capacity allows, otherwise deferred; NOT amendment-eligible
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
- Re-dispatch reviewers (fresh) with `Input Mode: Focused re-review`, that reviewer's own prior must-fix findings, and `review_iter_M_fix_diff`. Do NOT re-send the full worktree diff. For `track = "change"` pieces: re-dispatch the same 7-agent set (security, blind, architecture, edge-case, spec-compliance, ground-truth, integration) — do NOT include review-board-prd-alignment. For piece-track: re-dispatch all 8 standard agents. Note: the 9th board member (`verify-piece-full`) does NOT participate in the fix loop — test quality findings from that reviewer route to Step 8 triage rather than through fix-code, since test file rewrites require plan amendments, not production code fixes.
- Re-triage the new findings (still deduplicate across reviewers).
- **Circuit breaker:** `qa_max_iterations` (`L`) full review cycles maximum (`L` = the piece-wide resolved value from Step 0; `auto` resolves to 5 for `tdd: false` pieces and 3 for `tdd: true` pieces).
- If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.

### Post-CHANGELOG fix re-verification (AC-16 — pi-014 rationale)

**Trigger.** Whenever a fix iteration (Final Review fix loop, Step 3 above) or an amendment phase (`phase_final_amend_<K>` via Step 8) lands AFTER the piece's CHANGELOG/version phase has already run (i.e., the piece contains a phase whose `**In scope:**` includes `CHANGELOG.md` or a `plugin.json` / version file, and that phase's `progress: …` commit is already in HEAD), the orchestrator MUST **re-verify** the CHANGELOG entry before the piece completes.

**What to re-check.** After each such fix commit, verify that:

1. The `## [<version>]` CHANGELOG header accurately describes the shipped artifact as it now stands — not as it stood when the CHANGELOG phase ran.
2. Any feature, agent, mechanic, or behavior that the fix **adds, removes, or materially alters** is reflected (or intentionally omitted with rationale) in the CHANGELOG entry. A fix that changes a shipped artifact without a corresponding CHANGELOG update is a **must-fix** — the CHANGELOG is a contract with downstream users.
3. The version number in `CHANGELOG.md` still matches the version fields in `plugin.json` and any other version-bearing files the piece declared. A fix that bumps a file without updating the CHANGELOG version header is also a must-fix.

**How.** After the fix commit lands, run:
```bash
git diff "$default_branch"..HEAD -- CHANGELOG.md
```
Compare the CHANGELOG diff against the full cumulative piece diff (`git diff $default_branch..HEAD`) to identify any artifact-level change not reflected in the CHANGELOG. If a discrepancy is found, dispatch a targeted fix-code agent scoped to `CHANGELOG.md` with the discrepancy listed as its sole finding. The fix does NOT count against the `[Verify]` oracle for the phase that originally authored the CHANGELOG — it is a separate targeted correction. After the CHANGELOG fix lands, re-run the version-sync check (`grep -h '"version"'` across version-bearing files) to confirm all version strings still agree.

**Scope.** This rule applies to every post-CHANGELOG fix path: Final Review Step 3 fix iterations, Step 8 amendment phases (`phase_final_amend_<K>`), and any human-directed rework via Step 4 (Human Sign-Off) that touches behavior after the CHANGELOG phase. It does NOT apply to fixes that land before the CHANGELOG phase runs — those are covered by the normal phase `[Verify]` oracle and CHANGELOG-phase QA gate.

### Step 8: Final Review Triage

**Trigger.** When Final Review's iter-loop (Steps 1–3) terminates with must-fix findings remaining (the iter-loop's circuit breaker fired or the operator has chosen to triage residual must-fix items rather than continue iterating), the orchestrator invokes Step 8 once before any merge action — i.e., before Step 4 (Human Sign-Off), Step 4.5 (Reflection), Step 5 (Capture Learnings), or Step 6 (Merge). Step 8 also fires when Final Review surfaces non-must-fix discoveries that nonetheless require triage (`requires-amendment`, `requires-fork`, `does-not-block-goal-deferred`, or `qa-deferred-to-reflection` markers from any of the end-of-piece reviewers — blind, spec-compliance, architecture, edge-case, prd-alignment, security, ground-truth, integration, and in fast mode also verify-piece-full — even when the iter-loop returned must-fix=None overall). If Final Review returns clean across all board reviewers AND no triage-eligible discoveries surfaced, Step 8 is a no-op and execution proceeds to Step 4.

**Per-finding routing.** For each finding emerging from Final Review, the orchestrator routes by severity before dispatching Step 6c:

- **`must-fix` and `should-fix`:** dispatches the Step 6c triage flow with the full options menu — `(a) amend`, `(s) amend-spec` (where spec-eligible), `(f) fork`, `(d) defer`. The finding's severity label is surfaced in the triage prompt so the operator can weigh whether a should-fix warrants reopening the piece. Amendment budget applies to any amend choice regardless of severity.
- **`defer` and `dismiss`:** no Step 6c invocation; the finding is either discarded (`dismiss`) or written directly to the backlog without operator triage (`defer` — pre-existing issues require no new rationale).

Each finding is processed as a separate Step 6c invocation (one Step 6c invocation = one triage event per the Recursion semantics defined under Step 6c). The triage prompt's source-phase column for `.discovery-log.md` rows is set to the literal token `final-review` (NOT a numeric phase ID — there is no specific upstream phase in Final Review). The source-agent column names which reviewer flagged the finding: `blind`, `spec-compliance`, `architecture`, `edge-case`, `prd-alignment`, `security`, `ground-truth`, `integration`, or (in fast mode) `verify-piece-full` — matching the active end-of-piece reviewer roles.

**Amendment phase IDs.** Amendment phases inserted via Step 8 use the suffix-form IDs `phase_final_amend_<K>` where `<K>` is the 1-indexed amendment counter for the Final Review triage event (`phase_final_amend_1`, `phase_final_amend_2`, etc.). The originating phase token is the literal string `final` since there is no specific upstream phase. This naming distinguishes Step 8-induced amendment phases from per-phase Step 6c-induced amendment phases (`phase_<N>_amend_<K>` with `<N>` a numeric phase ID per FR-13).

**Amendment budget applies.** Step 8's amend dispatches consume the same per-piece budget as per-phase Step 6c amendments (see "Amendment budget tracking" under Step 6c). If the budget is exhausted at the moment Step 8 fires, the budget-exhaustion escalation prompt fires; the operator's `y`/`n` decision applies to the entire remaining piece including all subsequent Step 8 findings.

**Per-choice flow.**

- **On `amend` (or `amend-spec`):** the piece **re-opens**. The amendment phase(s) inserted as `phase_final_amend_<K>` run through the full Per-Phase Loop including their own Red/Build/Verify/Refactor cycle (where applicable per the amended plan's track) AND their own per-phase QA gate (Step 6) per NN-P-002 preservation. Amendment phases run through QA-phase, Step 6a (deferred-finding surface-to-Step-6c), Step 6b (hook sweep), Step 6c (their own discovery triage, recursing if discoveries surface — bounded by the amendment budget). **Re-entry to Final Review (explicit hand-off).** When the LAST `phase_final_amend_<K>` phase completes its Step 7 (Mark Progress) commit, the orchestrator does NOT advance to "next plan.md phase" (there is none — amendment phases were inserted post-hoc by Step 8). Instead, the orchestrator detects the just-completed phase's ID matches the `phase_final_amend_<K>` pattern and the next phase ID would advance off the end of the amendment-phase chain, then jumps back to Final Review Step 1 on the new cumulative diff `git diff $default_branch..HEAD`. For `track = "change"` pieces: re-dispatch the same 7-agent set (security, blind, architecture, edge-case, spec-compliance, ground-truth, integration) — do NOT include review-board-prd-alignment. For piece-track: re-dispatch all 8 standard agents (blind, edge-case, spec-compliance, prd-alignment, architecture, security, ground-truth, integration, and verify-piece-full in fast mode). The merge gate (Step 6) fires only after the re-run Final Review returns clean (or after a subsequent Step 8 invocation processes its findings). This guarantees NN-P-002's two-human-gate non-negotiable (per-phase QA + end-of-piece review board) survives Step 8's amendment cycle intact.

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

**Reflection track routing (track-aware):**
- If `track = "piece"`: existing per-PRD reflection behavior remains unchanged — route future-opportunities to `<docs_root>/prds/<prd-slug>/backlog.md` and process-retro to `docs/improvement-backlog.md`.
- If `track = "change"`: use `docs/improvement-backlog.md` for all deferred findings (no per-change backlog file; no manifest status update). Where Step 4.5 below references the PRD-local backlog or manifest, substitute `docs/improvement-backlog.md` and omit the manifest input.

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
- If `track = "piece"`: current `<docs_root>/prds/<prd-slug>/backlog.md` contents, OR the literal string "(file does not exist yet)" if absent
- If `track = "piece"`: `<docs_root>/prds/<prd-slug>/manifest.yaml`
- If `track = "change"`: current `docs/improvement-backlog.md` contents, OR the literal string "(file does not exist yet)" if absent; do not load a per-change backlog or manifest
- Findings target: emit a structured `## Findings` report to the orchestrator (Phase Group B's `reflection-future-opportunities.md` agent rewrite owns the report-shape contract). Do NOT write to the resolved backlog target directly.

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
- **On `defer` for any reflection finding:** `/spec-flow:defer` writes the backlog entry and commits it itself with a message of the form `chore(<piece-slug>): defer <finding-summary>` per Step 6c's Defer dispatch step 2. The `.discovery-log.md` row append lands as part of THAT commit. If `track = "piece"`, future-opportunities defer targets the PRD-local `<docs_root>/prds/<prd-slug>/backlog.md` and process-retro defer targets the global `<docs_root>/improvement-backlog.md`. If `track = "change"`, all reflection defers target `docs/improvement-backlog.md`. Per AC-24, the resulting backlog entry's `**Source:**` line names the originating phase as `step-4.5-reflection` and the agent as either `reflection-future-opportunities` or `reflection-process-retro`.
- **On `amend` / `amend-spec` for any reflection finding:** the standard Step 6c amend dispatch fires — `plan-amend` (or `spec-amend`) agent runs, the amendment commits with `chore(plan): amend` (or `chore(spec): amend`), and amendment phases run through the full Per-Phase Loop. The amendment budget applies (5 amendments total per piece, of which at most 1 may be a spec amendment; reflection findings consume the same budget as per-phase Step 6c amendments).
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
**Integration — transition task to Done after squash commit (if `integration_cfg != null` and `auto_transition: true`):**
After the squash commit succeeds, run the capability check for `transition_issue`. If available,
iterate over all `jira_key:` fields from plan.md and transition each task to the "merge complete"
status from `integration_cfg` (default: `Done`).
On tool unavailable → emit warning → skip (do NOT block cleanup).

If Step 6 fails for any reason (conflicts, hook rejection, empty commit, etc.): revert the
Step 5.5 manifest commit on the piece branch before escalating to human, so the branch
does not carry a stale `merged` status (see Step 5.5 failure path above).

**If `merge_strategy: pr`:**
**Integration — transition task to In Review before opening PR (if `integration_cfg != null` and `auto_transition: true`):**
Before displaying the PR command, run the capability check for `transition_issue`. If available,
iterate over all `jira_key:` fields from plan.md to collect task keys. If `track = "change"` and plan.md has no `jira_key:` fields, fall back to reading `jira_key:` from `spec_path` (brief.md) front-matter.
Transition each collected task key to the "PR opened" status from `integration_cfg` (default: `In Review`).
On tool unavailable → emit warning → skip (do NOT block the merge).

Display the following command for the human to copy-paste and run manually:
```
gh pr create --base main --head piece/<prd-slug>-<piece-slug>
```
Print: "PR-based merge required. Run the command above to open a pull request.
The piece branch already carries `status: merged` + `merged_at` in the manifest (Step 5.5).
When the PR is reviewed and merged, main receives the correct terminal state automatically.
Jira task(s) are now In Review — run intake at the start of your next session to mark them Done once the PR merges.
After the PR merges, run these cleanup commands:
  git worktree remove {{worktree_root}}
  git branch -d piece/<prd-slug>-<piece-slug>"
**Halt.** Do NOT execute the `gh` command — no `gh` CLI dependency is introduced.

## Escalation Rules

- Agent reports BLOCKED → escalate to human
- `qa_max_iterations`+ QA loops on same finding → escalate (architectural issue)
- Resume-critical state missing/corrupt when expected-present (tier-1 per `reference/coordinator-contract.md`) → emit `[STATE-INCOMPLETE: <field>]` and escalate; do NOT guess. (Valid absences and cosmetic fields do not escalate — see the field-tier table.)
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
- **Mid-group resume (`deferred_commit: auto`).** When the interrupted phase is a deferred Phase Group, the deferred commits never landed, so HEAD alone cannot tell which sub-phases finished. Resume from the group journal instead, per `reference/deferred-commit-journal.md` §Resume algorithm:
  - **Read the journal** for the active group (matched by `group_letter`) and take `group_start_sha` as the file-scoped recovery baseline.
  - **No/corrupt journal WHILE a group is in flight → `[STATE-INCOMPLETE: journal]`, escalate.** Per the field-tier table in `plugins/spec-flow/reference/coordinator-contract.md` `## Resume-Critical State — Field Tiers`, a journal is *expected-present* when the active group is *in flight* — plan.md shows ≥1 checked sub-phase step under the group AND the group-level `[Progress]` checkbox is unchecked. If the journal is then missing or corrupt, the coordinator MUST emit `[STATE-INCOMPLETE: journal]` and escalate to the operator rather than guessing which sub-phases are green. Worked trace: group B with `B.1 [Build] = [x]` and group `[Progress] = [ ]` ⇒ in flight ⇒ missing journal ⇒ escalate; group B with no checked sub-phase steps ⇒ not in flight ⇒ missing journal ⇒ fresh start (next bullet).
  - **No journal AND no group in flight → fresh group start (tier-3 valid absence)** (NN-C-005). This is not an error — it is the normal case for a group that never began. Proceed to Step G1 (write a fresh journal) and run the group from scratch.
  - **Stale `group_letter` → depends on whether the active group is in flight.** A journal whose on-disk `group_letter` does NOT equal the active group's letter is STALE. Log the orphan (NN-C-006, e.g. `NN-C-006: orphaned journal for group <on-disk letter> ignored; active group is <active letter>`). Then branch on the active group's in-flight state: (a) if the active group IS in flight (≥1 checked sub-phase step under the active group AND the group `[Progress]` checkbox is unchecked), the active group's own journal is missing — emit `[STATE-INCOMPLETE: journal]` and escalate (tier-1); (b) if the active group is NOT in flight (no checked sub-phase steps), treat it as no-journal and proceed to fresh group start (tier-3 valid absence, per next bullet), overwriting the stale journal at Step G1. This preserves the single-fixed-filename safety: a resume only ever trusts a journal that matches the active group.
  - **`green` sub-phases → trust after a hash re-check.** For each sub-phase with `status: green`, re-hash ONLY its Red test files (the keys of its `red_manifest_hashes`) against the stored digests. The production files in that sub-phase's `scope` are trusted by association and are NOT independently re-hashed — a matching Red-test hash is taken as proof the whole sub-phase is intact. On an exact match for every Red test file, trust the sub-phase as done: do not re-run it and do not touch its files. (A mismatch demotes it to incomplete — fall through to the next bullet.) **FR-4 resume fallback:** if the journal carries `anchor: blob`, re-verify green sub-phases with `git hash-object` (comparing working-tree blob SHAs against the journal's `red_manifest_hashes`); if the `anchor:` marker is ABSENT (journal written by ≤5.1.0), re-verify with `sha256sum` instead and do NOT re-anchor or refuse — honor the old format as-is for this in-flight piece.
  - **Incomplete sub-phases (`pending` / `red-done` / `failed`) → file-scoped reset, then re-run from Red.** Apply the FR-6 file-scoped recovery recipe to that sub-phase's recorded `scope` in the SPLIT form: `git restore --source=$group_start_sha --worktree -- <MODIFIED paths only>` to restore files that existed at the baseline, plus `rm -f -- <created paths>` + `git rm --cached --ignore-unmatch -- <created paths>` for files the sub-phase created (`git restore --source` does not remove created files, and aborts the whole operation if the pathspec includes a created path — so the restore pathspec is the modified subset only). The `-f` / `--ignore-unmatch` flags keep recovery re-entrant/idempotent across a crash-and-resume. The reset touches ONLY the incomplete sub-phase's recorded `scope` — sibling `green` sub-phases' files stay byte-identical — and the reset is logged (NN-C-006 passive surface). Re-inject the `Deferred Phase Group: yes` flag on this resume re-dispatch — see the G4 flag-injection rule — so the re-run stays git-free like the initial dispatch.
  - **Sub-phases absent from the journal → not started.** A `<letter>.<n>` key missing from `sub_phases` was never dispatched; run it fresh, no recovery needed (its files were never written).

## Measurement

At session end, emit a summary with per-phase **Build duration**, **Build token count**, **Verify mode chosen** (Audit vs Full), **Refactor skipped** (auto-skip predicate matched), **QA iteration count** (iter-1 / iter-2 / iter-3 mix per phase), **Step 6b outcome** (pass / autofix / fix-code dispatched), **mid_piece_opus_pass** (`dispatched` with iteration count / `not-triggered` / `escalated`), and **deferred_findings_recorded** (count of `Deferred to reflection:` stubs written to backlog across all QA iterations for this piece). For a deferred Phase Group (`deferred_commit: auto`), also emit the **Phase Group commit model** (`deferred` vs the legacy per-phase model), the **group wall-clock duration** (Red→Build→barrier across all sub-phases), and the **group commit count** (`2` under `deferred` — one barrier work-commit covering the group's Red∪Build union plus one separate plan.md progress commit — vs the `N+1` commits a flat / `deferred_commit: off` run of the same N sub-phases produces). Observable properties:

1. Build token count is materially lower than a comparable-scope phase would have been without pre-flight digests and scoped QA prompts — pre-flight facts + pitfall checklist reduce agent rediscovery and self-iteration.
2. Build tool-use count drops commensurately.
3. Verify: majority of clean-Build phases use Audit mode (3–5 min) rather than Full (10–15 min). Driven by Step 3's AC matrix gate — a clean matrix unlocks Audit.
4. Step 6b passes cleanly on the majority of phases (no-op), because per-commit hooks caught issues at each intermediate commit rather than letting them accumulate.
5. Refactor is skipped on clean-Build phases; QA iterations run until reviewer returns must-fix=None or the `qa_max_iterations`-limited circuit breaker fires.

If (1)/(2) don't hold on two consecutive large phases, something other than the pre-flight inefficiencies is dominating — re-audit before adding more machinery. If (3) doesn't hold, inspect Implement's AC coverage matrix — the matrix is likely incomplete or inconsistent, forcing Full mode unnecessarily. If Step 6b consistently dispatches fix-code, the project's pre-commit config includes checks that depend on full-repo context (e.g. global mypy or whole-repo type checking); move those to pre-push.

## Known costs and caveats

- **Pre-flight on monorepos.** `git grep` across a very large repo is slow. Scope probes to the phase's declared scope directories and use path filters. If a probe would take more than a few seconds, skip it and let the agent rediscover — pre-flight is an optimization, not a correctness gate.
- **Per-commit hook cost.** Every intermediate commit runs hooks, so the project's pre-commit config needs to be cheap: lint + format + type-check on small diffs, not whole-repo or test-suite runs. A ~5s/commit hook cost × 5 intermediate commits/phase = negligible. Move expensive checks (full test suites, whole-repo type checks, documentation builds) to `pre-push` or run them as explicit orchestrator gates between phases. The README covers pre-commit config shape.
- **Phase-size outliers are out of scope here.** These changes reduce *avoidable* work inside Implement. A phase with 1700+ LOC and five new files is expected to be expensive — the root fix for oversized phases lives in the `plan` skill (phase budgeting), not here.

## Graceful Degradation

If the Agent tool is unavailable, perform all steps sequentially in the main window. The mode-specific doctrine (TDD or Implement) and QA checklists still apply. This loses context isolation but preserves workflow gates.
