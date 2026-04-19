---
name: execute
description: Use when a plan is approved and ready for implementation. Orchestrates each phase via a single implementer agent that runs in TDD mode or Implement mode based on the plan's track (config/infra/glue code uses Implement mode, behavior-bearing code uses TDD), runs QA gates between phases, and triggers a 5-agent final review before merging. The main window writes zero implementation code. Use this whenever the user wants to execute, implement, or run a spec-flow plan — regardless of whether the plan uses TDD or not.
---

# Execute — Orchestrate Plan Implementation

Execute an approved plan phase by phase using dedicated agents for each step. Each phase runs in Mode: TDD or Mode: Implement based on the plan's chosen track, with QA gates at every boundary and a 5-agent final review before merge.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- Piece must have status `planned` in manifest
- `docs/specs/<piece-name>/plan.md` must exist and be approved
- Must be on the worktree branch `spec/<piece-name>`
- All manifest dependencies for this piece must have status `done`

## API encapsulation — this skill is the sole entrypoint for internal agents

`spec-flow:execute` is the only supported way to dispatch phase-level and end-of-piece agents (`implementer`, `tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`, `reflection/process-retro`, `reflection/future-opportunities`). Those agents assume orchestrator-injected context (Mode flag, pre-flight snapshot, oracle anchors, AC matrix, session metrics for reflection agents) and have Rule 0 first-turn reject checks that BLOCK when called directly. Do not dispatch them from outside this skill. If a task appears to need direct agent invocation, route through a spec + plan + execute cycle instead — the extra structure exists to prevent the class of contamination bugs where agents run with broken invariants.

## The Orchestrator Role

You (the main window) are a PURE CONDUCTOR. You:
- Read the plan and construct agent prompts
- Gather read-only pre-flight facts (LOC, schema samples, symbol presence, hook inventory) to avoid pushing cheap discovery work into agents — see Step 1b
- Resolve plan conditionals the orchestrator can evaluate (LOC- and filesystem-based) into binding pre-decisions before dispatch
- Dispatch agents via the Agent tool
- Run verification commands (test suite, type checker, linter)
- Evaluate agent reports and QA findings
- Decide: proceed / retry / escalate
- Track progress via plan.md checkboxes

You write ZERO implementation code. Fact-gathering probes (`wc`, `head`, `git grep`, reading `.pre-commit-config.yaml`) are explicitly part of the conductor role — they are cheap reads that collapse 5–15 agent tool calls per dispatch. Synthesis and code-writing still come from subagents.

## Pre-Loop: Mark Piece as Implementing

Before the first phase runs (and only on a fresh start, not a resume), update the manifest on `main` to mark this piece's status as `implementing`. Skip if it's already `implementing` (resumed session).

```bash
git checkout main
# update manifest.yaml: set this piece's status to "implementing"
git add docs/manifest.yaml
git commit -m "manifest: mark <piece-name> as implementing"
git checkout spec/<piece-name>
```

This makes `status` report an accurate picture — a piece is `implementing` while execute is in progress, and flips to `done` after the final merge.

## Phase Scheduler — detection

The orchestrator begins each piece by scanning plan.md for Phase Group headings (`## Phase Group <letter>:`). For each top-level unit in plan.md, determine whether it is a flat phase or a phase group:

- **Flat phase** (current model) — starts with `### Phase <N>` — run through the Per-Phase Loop below (Steps 1–7).
- **Phase Group** — starts with `## Phase Group <letter>:` and contains ≥2 `#### Sub-Phase <letter>.<n>` subheadings — run through the Phase Group Loop (below the Per-Phase Loop).

Read the `phase_groups` key from `.spec-flow.yaml` (valid values: `auto`, `always`, `off`; default `auto`):

- `auto` — recognize Phase Groups from plan headings; fall back to flat phase handling when the plan uses `### Phase <N>`.
- `always` — recognize Phase Groups and error if the plan has only flat phases when the piece has multiple obviously-parallelizable files. Used to catch over-flat plans during v1.4.0 rollout.
- `off` — treat every top-level unit as a flat phase, ignoring Phase Group headings. Escape hatch for rollback or for plans authored before v1.4.0.

Scope validation before dispatching any sub-phases in a group: parse each sub-phase's `**Scope:**` declaration (literal file paths only, no globs) and check for pairwise overlap. If two sibling sub-phases declare overlapping files, fall back to serial execution for that group (each sub-phase runs as a flat phase in declaration order) and log a warning naming the overlap.

## Per-Phase Loop

For each phase in plan.md (skip phases where all checkboxes are [x]):

### Step 1: Capture Phase Start SHA

Record the current HEAD into orchestrator state as `phase_N_start_sha`. No tag, no commit — this lives in your (the orchestrator's) working memory.

```bash
# orchestrator captures the output of this into phase_N_start_sha
git rev-parse HEAD
```

On resume mid-phase (phase not yet marked complete in plan.md), recover the SHA the same way: `git rev-parse HEAD`. Phase steps do not commit, so HEAD stays anchored at phase start until Step 7 runs.

### Step 1a: Detect Phase Mode

Inspect the phase's checkboxes in plan.md to determine the mode flag passed to the implementer agent:

- Phase contains `[TDD-Red]` → **Mode: TDD**. Run Step 2 (Red) first, then Step 3 (Implement in TDD mode), then Steps 4 → 5 → 6.
- Phase contains `[Implement]` and NO `[TDD-Red]` → **Mode: Implement**. Skip Step 2. Run Step 3 (Implement in Implement mode), then Step 4, then Step 5 only if the phase has a `[Refactor]` checkbox, then Step 6.
- Both markers present, or neither: plan is malformed. Escalate to human.

The orchestrator branches mechanically on the checkbox; it does not decide which mode applies. The mode decision was made by the plan author. The Implement mode exists for phases where TDD doesn't fit (config, infra, scaffolding, glue code, docs-as-code).

### Step 1b: Phase Pre-Flight (read-only)

Before dispatching Red or Implement, the orchestrator collects facts the agents would otherwise rediscover. Scope every probe to the phase's declared scope — files and symbols named in the plan's [TDD-Red], [Build], or [Implement] blocks. Pre-flight should take seconds; if any probe is slow (e.g. `git grep` on a monorepo), use path filters targeting scope directories or skip it.

1. **LOC snapshot** — for each file the phase touches, run `wc -l <file>`. Attach as "LOC headroom" context.
2. **Schema shape** — if the plan references a config family (`configs/<X>/`, schemas, templates), sample one existing sibling: `head -20 configs/<X>/<any_existing>`. Attach as "Existing schema" context.
3. **Symbol presence** — for each type/class/function the plan names that isn't already defined inside the phase's own scope, `git grep -l -E '^(class|def|function) <Name>\b'` (or equivalent scoped to likely source directories). Attach the hit paths or "(not found — define in Build)".
4. **Pre-commit hook inventory** — if `.pre-commit-config.yaml` exists, read it. For each hook, check whether its `id` or `entry` invokes a test runner (substring match on `pytest`, `unittest`, `go test`, `jest`, `vitest`, or the project's declared test command from CLAUDE.md). Flag any matches. **Err on surfacing** — false positives only give the Red agent information it doesn't need; false negatives stall the pipeline when Red hits a hook wall.
5. **Plan conditional resolution** — scan the phase's [Build]/[Implement] block for ONLY these two phrase patterns:
   - "extract ... if ... exceeds <N>" — evaluate using the LOC snapshot.
   - "if <file/symbol> exists, reuse; otherwise create ..." — evaluate using symbol presence.
   Resolve each into a bullet under `## Orchestrator pre-decisions`. Other conditional phrasings (runtime-state conditions, fuzzy natural-language conditionals) pass through unchanged — the orchestrator is not a general-purpose plan interpreter.

Compose two attachments for later steps:

- `## Pre-flight snapshot` — items 1–4 above, verbatim. Attached to BOTH the Red prompt (Step 2) and the Implement prompt (Step 3) — Red benefits from symbol presence and schema samples too.
- `## Orchestrator pre-decisions` — item 5, one resolved decision per bullet. Attached only to the Implement prompt. Empty section OK (include the heading with "(none)" if no conditionals matched).

If `.pre-commit-config.yaml` is absent, the hook inventory is empty — agents commit normally without any hooks running.

### Step 2: TDD-Red — Write Failing Tests

*(Mode: TDD only)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/tdd-red.md`
2. Compose prompt with: phase [TDD-Red] tasks from plan, spec ACs, existing test patterns, and the `## Pre-flight snapshot` block from Step 1b. Red commits normally — the commit triggers hooks like any other. The one exception: when the pre-flight hook inventory flagged a test-running hook, Red's template is authorized to use `--no-verify` for its own commit (Red's tests are expected to fail; a test-running pre-commit hook would block it).
3. Dispatch:
   ```
   Agent({
     description: "TDD-Red: write failing tests for Phase N",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Validate:** Run the test suite. Confirm tests FAIL.
   - Check failure messages: do they indicate missing features (good) or setup errors (bad)?
   - If setup errors: the agent wrote bad tests. Retry once with error output. If still failing for wrong reason: escalate.
5. **Capture the Oracle block:** extract the Red agent's `## Oracle block` section verbatim. Hold in orchestrator state as `phase_N_oracle_block` — Step 3 splices it into the implementer prompt without paraphrase.
6. **Post-commit contamination check.** After the Red commit lands, reconcile the committed file list against the agent's `## Tests Written` paths:
   ```bash
   git show --name-only --pretty= HEAD | sort > /tmp/red_committed.txt
   # Extract paths from the agent's ## Tests Written section into /tmp/red_reported.txt (sorted).
   diff /tmp/red_committed.txt /tmp/red_reported.txt
   ```
   If the two lists diverge, the commit is contaminated — most often because a concurrent agent's uncommitted work in the same worktree was swept in. Pause and ask the human whether to split the commit. Do NOT auto-reset.

### Step 3: Implement — Write the Code

*(Both modes. The mode flag determines the agent's oracle of done.)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/implementer.md`
2. Compose prompt using the canonical template below. **Reference plan.md by file path and line range rather than restating its contents** — the agent reads plan.md directly. The prompt supplies only what plan.md doesn't: pre-flight facts, pre-decisions, and the mode oracle.

   ```markdown
   Mode: TDD | Implement

   ## Plan reference
   Execute `docs/specs/<piece>/plan.md` Phase <N> [Build] | [Implement]
   block verbatim (lines <X>-<Y>). The plan is binding; this prompt
   only supplies context the plan doesn't.

   ## Pre-flight snapshot
   <LOC snapshot, schema samples, symbol presence, hook inventory from Step 1b>

   ## Orchestrator pre-decisions
   <one bullet per resolved plan conditional from Step 1b item 5, or "(none)">

   ## Oracle (Mode: TDD) | Verify command (Mode: Implement)
   - Mode: TDD — splice `phase_N_oracle_block` from Step 2 verbatim.
   - Mode: Implement — include the plan's `[Verify]` command and
     expected output.

   ## Commit
   <concise message referencing phase N and mode>
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
5. **Validate:** Run the mode's oracle.
   - Mode: TDD — full test suite must be GREEN.
   - Mode: Implement — the plan's `[Verify]` command must pass with the plan's expected output.
6. **Circuit breaker:** If the oracle does not pass after 2 attempts in either mode, escalate to human. If the agent reports BLOCKED (e.g. ambiguous plan, architecture conflict, pre-decision vs. filesystem mismatch), escalate — do not retry blindly.
7. **AC Coverage Matrix validation gate.** After the oracle passes, validate the Build report's `## AC Coverage Matrix` section. See `references/ac-matrix-contract.md` for the schema and parsing rules. In short: reject + re-dispatch (within the 2-attempt oracle budget above) if the section is missing, missing an in-scope AC row, contains a bare `NOT COVERED`, or a vague `covered` pointer. Clean matrix → proceed to Step 4. If validation fails twice, escalate — the plan likely has ambiguity about phase AC assignment.

### Step 4: Verify — Confirm Correctness

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/verify.md`
2. **Pick the Verify input mode.** Inspect the Implement agent's report for three conditions:
   - **`## Oracle Outcome`** — does it say the oracle ran clean on first attempt (no retries)?
   - **`## Plan Adherence`** — is `Deviations from plan: none`?
   - **`## AC Coverage Matrix`** — is it present, complete (every in-scope AC listed), and free of `NOT COVERED` entries?

   If **all three** are true, pick **Mode: Audit** — dispatch a narrow agent that sanity-checks the AC matrix without re-running the oracle (~3 min). If any is false, pick **Mode: Full** — dispatch the full verifier (~10 min).

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
5. **Validate test integrity (Mode: TDD only):** Diff test files between the phase-start SHA and now:
   ```bash
   git diff $phase_N_start_sha..HEAD -- tests/
   ```
   (Substitute the SHA captured in Step 1.) If test files were modified since the Red step (and not by the Red agent): REJECT. Agent cheating detected. This check applies under both Audit and Full — it's a cheap orchestrator-side diff, unrelated to the Verify agent.
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

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-phase.md`

2. **Iteration 1 (full review):** Build a structured surface map instead of dumping the raw diff + full spec + PRD. The goal is to hand Opus pre-digested context so it does adversarial review, not re-discovery.

   Compose the iter-1 prompt with the following blocks, in order:

   - **`## Files changed`** — one row per file: `path | +adds/-dels | role (test/impl/config/docs)`. Generated from `git diff --numstat $phase_N_start_sha..HEAD` plus path-based role inference.

   - **`## Public symbols added or modified`** — list of class/function/type names the diff introduces or modifies in non-test files. Use `git diff $phase_N_start_sha..HEAD -- <impl paths>` and grep for added/changed lines matching the project's symbol declarations (e.g. `^[+-]\s*(class|def|function|type)\s+\w+`). One line per symbol: `path:symbol`.

   - **`## Integration callers`** — for each public symbol above, run `git grep -l <symbol>` scoped to source directories. Paths only, no bodies. Opus can `Read` specific callers if it needs to inspect them. If a symbol has zero callers, mark it "(new — no callers yet)".

   - **`## Diff`** — changed-line hunks only (default `git diff` output). If the total diff is > 500 LOC, collapse to per-file summaries with a pointer: "Full hunks available; Read <path> or request via targeted diff if you need specific ranges." Do not attach full file bodies ever.

   - **`## AC Coverage Matrix (from Build)`** — splice Build's `## AC Coverage Matrix` table verbatim. This was already validated clean by Step 3's gate. Opus's job is to adversarially verify the claimed coverage is real and find gaps, NOT to re-derive the matrix from scratch.

   - **`## Phase ACs`** — attach ONLY the acceptance criteria for this phase (mapped via plan.md), not the full spec. Use the plan's "AC map" section or the spec's AC sections that the plan references for this phase.

   - **`## Non-negotiables`** — project constraints (short file).

   **Do NOT attach:** full spec, PRD sections, full plan, or full test-runner output. PRD alignment is the Final Review board's job (`review-board/prd-alignment.md`). Per-phase QA is about correctness against the plan, not PRD compliance.

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

   - **Conditional skip of re-dispatch.** Read the `qa_iter2` key from `.spec-flow.yaml` (valid values: `auto`, `always`; default `auto`). In `auto` mode, skip the iter-M+1 QA re-dispatch if **all** of:
     - `iter_M_fix_diff` line count (excluding diff headers) < 50 LOC
     - The fix agent reported all findings resolved (no `## Blocked findings` section or it's empty)
     - The mode's oracle is green after the fix commit (re-run it; cheap vs. another Opus dispatch)

     When skipped, treat the fix agent's self-verification as the gate and proceed to Step 7. Log `qa_iter2_skipped: true` with the fix diff line count for the session summary. Rationale: across observed sessions iter-2 found new must-fix in roughly 1 out of 6 runs — low yield for a 15–30 min Opus dispatch, and the class of finding that hits (cross-file semantic issues like stale fixture references) tends to get caught by Final Review's board anyway. The small-diff + self-verified heuristic is conservative enough to not mask genuine regressions.

     In `always` mode, always re-dispatch.

   - **Re-dispatch (when not skipped):** QA agent (fresh, Opus) with `Input Mode: Focused re-review`, the prior iteration's must-fix findings, and `iter_M_fix_diff`. No full phase diff, no spec/plan re-sent unless referenced in findings. The agent template's iter-2 rules hard-cap out-of-scope reads (return BLOCKED rather than fetching).
   - **Circuit breaker:** 3 iterations max, then escalate.
   - If the fix agent returns `Diff of changes: (none)` (all blocked), escalate — no point re-running QA.

4. When QA returns must-fix=None (or iter-2 re-dispatch was skipped by the conditional above), proceed to **Step 7**.

### Step 6b: Phase Hook Sanity Check

Every intermediate commit in the phase already ran hooks (Red, Build, Refactor, and fix-code commits all trigger pre-commit normally), so the cumulative phase diff has been lint/format/type-check-clean at each step. This step is a single defensive sweep against any autofix residue or staging-area drift that might have slipped through.

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
git add docs/specs/<piece-name>/plan.md
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
- Red step (Step 2)
- Build step (Step 3) with Step 3 item 7 AC matrix validation gate
- Verify step (Step 4) with Audit/Full mode selection
- QA-lite step — dispatch `qa-phase-lite.md`, Sonnet. Same iter-1/iter-2 loop as the current full QA, with Step 6's `qa_iter2` skip predicate still applying (small self-verified fix-diffs skip the iter-2 re-dispatch).
- Sub-phase Progress is implicit (no separate progress commit per sub-phase — the group progress commit covers all)

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

If Group Deep QA returns must-fix: run the same iter-2 loop as the flat-phase QA does (Step 6's `qa_iter2` skip predicate applies — small self-verified fix-diffs skip the iter-2 re-dispatch), dispatching fix-code agents for findings. Each fix-code dispatch operates on the specific sub-phase scope the finding points to.

### Step G9: Step 6b hook sweep over the group diff

Run `pre-commit run --files $(git diff --name-only $group_start_sha..HEAD)`. Same autofix-or-fix-code recovery as the flat-phase Step 6b, once across the group.

### Step G10: Group Progress commit

```bash
git add docs/specs/<piece-name>/plan.md
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

Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board/` and dispatch ALL FIVE concurrently with `Input Mode: Full`:

```
Agent({ description: "Blind review (iter 1, full)", prompt: <blind.md + Input Mode: Full + diff only>, model: "opus" })
Agent({ description: "Edge case review (iter 1, full)", prompt: <edge-case.md + Input Mode: Full + diff + codebase note>, model: "opus" })
Agent({ description: "Spec compliance review (iter 1, full)", prompt: <spec-compliance.md + Input Mode: Full + diff + spec + plan>, model: "opus" })
Agent({ description: "PRD alignment review (iter 1, full)", prompt: <prd-alignment.md + Input Mode: Full + diff + spec + PRD + manifest>, model: "opus" })
Agent({ description: "Architecture review (iter 1, full)", prompt: <architecture.md + Input Mode: Full + diff + arch docs + non-negotiables>, model: "opus" })
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

In `auto` mode, dispatch two reflection agents concurrently (read-only, Sonnet):

```
Agent({ description: "Process retro for <piece>", prompt: <process-retro composed>, model: "sonnet" })
Agent({ description: "Future opportunities for <piece>", prompt: <future-opportunities composed>, model: "sonnet" })
```

**Process-retro prompt context:**
- Session-end metrics summary (per the Measurement section — Build duration, Build token count, Verify mode chosen, Refactor skipped, QA iter-2 skipped, Step 6b outcome, Phase Group auto-triage outcomes if any group ran)
- Per-phase escalation log (every circuit-breaker hit, BLOCKED report, contamination event, scope violation observed during the piece)
- Plan structure (plan.md's phase outline)
- Cumulative diff (`git diff $piece_start_sha..HEAD`)

**Future-opportunities prompt context:**
- Final spec for this piece (with acceptance criteria, including any deferred ACs)
- Final plan (with `NOT COVERED` rows from Build's AC matrix)
- Cumulative diff (`git diff $piece_start_sha..HEAD`)
- Current `<docs_root>/improvement-backlog.md` contents, OR the literal string "(file does not exist yet)" if absent
- `<docs_root>/manifest.yaml`

Wait for both agents to complete. Collect their structured outputs.

**Append findings to `<docs_root>/improvement-backlog.md`** (create the file if it does not exist):

```
## <piece-name> — <YYYY-MM-DD>

<process-retro output verbatim — emits ### Process retro for <piece-name> at H3>

<future-opportunities output verbatim — emits ### Future opportunities for <piece-name> at H3>

---
```

Commit the backlog append as a separate commit on the worktree branch (this lands BEFORE Step 5's learnings.md commit so that even if Step 5 fails, the raw findings are preserved):

```bash
git add <docs_root>/improvement-backlog.md
git commit -m "reflection: <piece-name> — append findings to improvement backlog"
```

Hold both reflection outputs in orchestrator state for Step 5 synthesis.

### Step 5: Capture Learnings

Synthesize a human-readable `learnings.md` from the reflection findings (Step 4.5 outputs) + the cumulative diff. The synthesized doc focuses on narrative — what worked, what to repeat, what to change next time — not raw findings (those live in the improvement backlog from Step 4.5).

Write `docs/specs/<piece-name>/learnings.md` on the worktree branch with sections:
- Patterns that worked well
- Issues QA caught
- Recommendations for future specs

If Step 4.5 was skipped (`reflection: off`), fall back to pre-v1.5 behavior: orchestrator (or human) authors `learnings.md` directly without reflection-agent input, using the cumulative diff and any session-end observations as the only inputs.

Commit on worktree branch before merge:

```bash
git add docs/specs/<piece-name>/learnings.md
git commit -m "learnings: <piece-name>"
```

### Step 6: Merge

```bash
git checkout main
git merge --squash spec/<piece-name>
git commit -m "spec/<piece-name>: <summary of what was built>"
git worktree remove worktrees/<piece-name>
git branch -d spec/<piece-name>
```

If merge conflicts: escalate to human.

### Step 7: Update Manifest

Update `docs/manifest.yaml` on main: piece status → `done`, update coverage section. Commit.

## Escalation Rules

- Agent reports BLOCKED → escalate to human
- 3+ QA loops on same finding → escalate (architectural issue)
- Implementer can't pass its oracle (green tests in Mode: TDD, plan `[Verify]` command in Mode: Implement) after 2 attempts → escalate
- Missing or invalid `Mode:` flag in the implementer's prompt → the orchestrator must not dispatch; fix the composition
- Phase has both `[TDD-Red]` and `[Implement]` markers, or neither → escalate (malformed plan)
- Test files modified during Implement (Mode: TDD) or Refactor (detected via `git diff $phase_N_start_sha..HEAD -- tests/`) → reject and escalate
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

At session end, emit a summary with per-phase **Build duration**, **Build token count**, **Verify mode chosen** (Audit vs Full), **Refactor skipped** (auto-skip predicate matched), **QA iter-2 skipped** (small-diff predicate matched), and **Step 6b outcome** (pass / autofix / fix-code dispatched). Observable properties:

1. Build token count is materially lower than a comparable-scope phase would have been without pre-flight digests and scoped QA prompts — pre-flight facts + pitfall checklist reduce agent rediscovery and self-iteration.
2. Build tool-use count drops commensurately.
3. Verify: majority of clean-Build phases use Audit mode (3–5 min) rather than Full (10–15 min). Driven by Step 3's AC matrix gate — a clean matrix unlocks Audit.
4. Step 6b passes cleanly on the majority of phases (no-op), because per-commit hooks caught issues at each intermediate commit rather than letting them accumulate.
5. Refactor is skipped on clean-Build phases; QA iter-2 is skipped when the fix-diff is small and self-verified.

If (1)/(2) don't hold on two consecutive large phases, something other than the pre-flight inefficiencies is dominating — re-audit before adding more machinery. If (3) doesn't hold, inspect Implement's AC coverage matrix — the matrix is likely incomplete or inconsistent, forcing Full mode unnecessarily. If Step 6b consistently dispatches fix-code, the project's pre-commit config includes checks that depend on full-repo context (e.g. global mypy or whole-repo type checking); move those to pre-push.

## Known costs and caveats

- **Pre-flight on monorepos.** `git grep` across a very large repo is slow. Scope probes to the phase's declared scope directories and use path filters. If a probe would take more than a few seconds, skip it and let the agent rediscover — pre-flight is an optimization, not a correctness gate.
- **Per-commit hook cost.** Every intermediate commit runs hooks, so the project's pre-commit config needs to be cheap: lint + format + type-check on small diffs, not whole-repo or test-suite runs. A ~5s/commit hook cost × 5 intermediate commits/phase = negligible. Move expensive checks (full test suites, whole-repo type checks, documentation builds) to `pre-push` or run them as explicit orchestrator gates between phases. The README covers pre-commit config shape.
- **Phase-size outliers are out of scope here.** These changes reduce *avoidable* work inside Implement. A phase with 1700+ LOC and five new files is expected to be expensive — the root fix for oversized phases lives in the `plan` skill (phase budgeting), not here.

## Graceful Degradation

If the Agent tool is unavailable, perform all steps sequentially in the main window. The mode-specific doctrine (TDD or Implement) and QA checklists still apply. This loses context isolation but preserves workflow gates.
