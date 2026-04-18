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

## The Orchestrator Role

You (the main window) are a PURE CONDUCTOR. You:
- Read the plan and construct agent prompts
- Dispatch agents via the Agent tool
- Run verification commands (test suite, type checker, linter)
- Evaluate agent reports and QA findings
- Decide: proceed / retry / escalate
- Track progress via plan.md checkboxes

You write ZERO implementation code. All code comes from subagents.

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

### Step 2: TDD-Red — Write Failing Tests

*(Mode: TDD only)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/tdd-red.md`
2. Compose prompt with: phase [TDD-Red] tasks from plan, spec ACs, existing test patterns
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

### Step 3: Implement — Write the Code

*(Both modes. The mode flag determines the agent's oracle of done.)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/implementer.md`
2. Compose prompt. The FIRST line MUST be the mode flag:
   - `Mode: TDD` — include verbatim failing-test output as the oracle, plan [Build] tasks, spec ACs, architecture constraints, pattern pointers
   - `Mode: Implement` — include the plan's `[Verify]` command and expected output as the oracle, plan [Implement] tasks, spec ACs, architecture constraints, pattern pointers
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
6. **Circuit breaker:** If the oracle does not pass after 2 attempts in either mode, escalate to human. If the agent reports BLOCKED (e.g. ambiguous plan, architecture conflict), escalate — do not retry blindly.

### Step 4: Verify — Confirm Correctness

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/verify.md`
2. Compose prompt with: the verification output for this phase (full test suite output for Mode: TDD, or the plan's `[Verify]` command output for Mode: Implement) and spec ACs for this phase
3. Dispatch:
   ```
   Agent({
     description: "Verify: check Phase N correctness",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Validate test integrity (Mode: TDD only):** Diff test files between the phase-start SHA and now:
   ```bash
   git diff $phase_N_start_sha..HEAD -- tests/
   ```
   (Substitute the SHA captured in Step 1.) If test files were modified since the Red step (and not by the Red agent): REJECT. Agent cheating detected.
5. Parse verify report. If gaps found:
   - Mode: TDD — decide whether to loop back to Red (add tests) or escalate.
   - Mode: Implement — loop back to Step 3 with the gaps as additional context, or escalate.

### Step 5: Refactor — Clean Up

*(Mode: TDD always; Mode: Implement only if the phase has a `[Refactor]` checkbox)*

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

2. **Iteration 1 (full review):** Get the full phase diff using the phase-start SHA from Step 1:
   ```bash
   git diff $phase_N_start_sha..HEAD
   ```
   Compose prompt with: `Input Mode: Full`, the diff, spec, plan (current phase section), PRD sections, non-negotiables. Dispatch:
   ```
   Agent({
     description: "QA: review Phase N (iter 1, full)",
     prompt: <composed>,
     model: "opus"
   })
   ```

3. **QA Loop (iterations 2+, focused):** If iteration M-1 returned must-fix findings:
   - Read fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-code.md`
   - Dispatch fix agent (Sonnet) with prior findings + plan context. The fix agent does NOT commit; it ends its report with a `## Diff of changes` section containing its `git diff`.
   - Extract that diff string from the fix agent's report and hold it in orchestrator state as `iter_M_fix_diff`.
   - Re-dispatch QA agent (fresh, Opus) with `Input Mode: Focused re-review`, the prior iteration's must-fix findings, and `iter_M_fix_diff`. No full phase diff, no spec/plan re-sent unless referenced in findings.
   - **Circuit breaker:** 3 iterations max, then escalate.
   - If the fix agent returns `Diff of changes: (none)` (all blocked), escalate — no point re-running QA.

4. When QA returns must-fix=None, proceed to Step 7.

### Step 7: Mark Progress

Update plan.md: mark all phase checkboxes [x]. Commit:
```bash
git add docs/specs/<piece-name>/plan.md
git commit -m "progress: Phase N complete"
```

Advance to next phase.

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
- Re-dispatch ALL 5 reviewers (fresh) with `Input Mode: Focused re-review`, that reviewer's own prior must-fix findings, and `review_iter_M_fix_diff`. Do NOT re-send the full worktree diff.
- Re-triage the new findings (still deduplicate across reviewers).
- **Circuit breaker:** 3 full review cycles maximum.
- If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.

### Step 4: Human Sign-Off

Present to user:
- Summary of what was built (phases, files, test counts)
- Final review results (clean or deferred items)
- Request approval to merge

### Step 5: Capture Learnings

Write `docs/specs/<piece-name>/learnings.md` on the worktree branch:
- Patterns that worked well
- Issues QA caught
- Recommendations for future specs

Commit on worktree branch before merge.

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

## Graceful Degradation

If the Agent tool is unavailable, perform all steps sequentially in the main window. The mode-specific doctrine (TDD or Implement) and QA checklists still apply. This loses context isolation but preserves workflow gates.
