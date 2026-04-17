---
name: execute
description: Use when a plan is approved and ready for implementation. Orchestrates TDD phases with dedicated agents per step (red, build, verify, refactor), runs QA gates between phases, and triggers a 5-agent final review before merging. The main window writes zero implementation code.
---

# Execute — Orchestrate TDD Implementation

Execute an approved plan phase by phase using dedicated agents for each TDD step, with QA gates at every boundary and a 5-agent final review before merge.

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

## Per-Phase Loop

For each phase in plan.md (skip phases where all checkboxes are [x]):

### Step 1: Tag Phase Start

```bash
git tag spec/<piece-name>-phase-N-start
```

### Step 2: TDD-Red — Write Failing Tests

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

### Step 3: Build — Write Minimal Code

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/builder.md`
2. Compose prompt with: failing test output (verbatim), plan [Build] tasks, architecture constraints
3. For tasks marked [P] (parallel): dispatch multiple Agent calls concurrently
   - **Merge check:** After all parallel agents complete, verify no file conflicts. If conflicts: reject, re-dispatch sequentially, flag as plan defect.
4. Dispatch:
   ```
   Agent({
     description: "Build: implement Phase N",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
5. **Validate:** Run full test suite. Confirm GREEN.
   - **Circuit breaker:** If not green after 2 attempts, escalate to human.

### Step 4: Verify — Confirm Correctness

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/verify.md`
2. Compose prompt with: full pytest output, spec ACs for this phase
3. Dispatch:
   ```
   Agent({
     description: "Verify: check Phase N correctness",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Validate test integrity:** Diff test files between the Red step tag and now:
   ```bash
   git diff spec/<piece-name>-phase-N-start..HEAD -- tests/
   ```
   If test files were modified since the Red step (and not by the Red agent): REJECT. Agent cheating detected.
5. Parse verify report. If gaps found: decide whether to loop back to Red (add tests) or escalate.

### Step 5: Refactor — Clean Up

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/refactor.md`
2. Compose prompt with: list of phase files, test suite command, quality principles
3. Dispatch:
   ```
   Agent({
     description: "Refactor: clean up Phase N",
     prompt: <composed>,
     model: "sonnet"
   })
   ```
4. **Validate:**
   - Run test suite: still green?
   - Check scope: `git diff --name-only` shows only phase files changed?
   - If out-of-scope files modified: reject the refactor, revert.

### Step 6: Phase QA

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-phase.md`
2. Get phase diff:
   ```bash
   git diff spec/<piece-name>-phase-N-start..HEAD
   ```
3. Compose prompt with: diff, spec, plan (current phase section), PRD sections, non-negotiables
4. Dispatch:
   ```
   Agent({
     description: "QA: review Phase N",
     prompt: <composed>,
     model: "opus"
   })
   ```
5. **QA Loop:** If must-fix findings:
   - Read fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-code.md`
   - Dispatch fix agent (Sonnet) with findings + plan context
   - Re-dispatch QA agent (fresh, Opus)
   - **Circuit breaker:** 3 iterations max, then escalate

### Step 7: Mark Progress

Update plan.md: mark all phase checkboxes [x]. Commit:
```bash
git add docs/specs/<piece-name>/plan.md
git commit -m "progress: Phase N complete"
```

Advance to next phase.

## Final Review

Triggered automatically when the last phase's QA passes.

### Step 1: Dispatch 5 Parallel Review Agents

Get full worktree diff:
```bash
git diff main..spec/<piece-name>
```

Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board/` and dispatch ALL FIVE concurrently:

```
Agent({ description: "Blind review", prompt: <blind.md + diff only>, model: "opus" })
Agent({ description: "Edge case review", prompt: <edge-case.md + diff + codebase note>, model: "opus" })
Agent({ description: "Spec compliance review", prompt: <spec-compliance.md + diff + spec + plan>, model: "opus" })
Agent({ description: "PRD alignment review", prompt: <prd-alignment.md + diff + spec + PRD + manifest>, model: "opus" })
Agent({ description: "Architecture review", prompt: <architecture.md + diff + arch docs + non-negotiables>, model: "opus" })
```

### Step 2: Triage

Collect findings from all 5 agents. Deduplicate (same issue reported by multiple reviewers). Classify:
- `must-fix` — blocks merge
- `defer` — pre-existing issue, not introduced by this spec
- `dismiss` — false positive or noise

### Step 3: Fix Loop

If must-fix findings exist:
- Dispatch fix agent (Sonnet, `agents/fix-code.md`) with all must-fix findings
- Re-dispatch ALL 5 reviewers (fresh)
- **Circuit breaker:** 3 full review cycles maximum

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
- Builder can't go green in 2 attempts → escalate
- Test files modified during Build/Refactor → reject and escalate
- Parallel agents modify shared file → reject, re-dispatch sequentially
- Merge conflicts → escalate

## Session Resumability

Progress tracked via [x] checkboxes in plan.md:
- Resume reads plan.md, finds first unchecked checkbox
- Completed phases skip
- In-progress phase resumes from first unchecked step
- Phase start tags enable correct diff baselines on resume

## Graceful Degradation

If the Agent tool is unavailable, perform all steps sequentially in the main window. The TDD doctrine and QA checklists still apply. This loses context isolation but preserves workflow gates.
