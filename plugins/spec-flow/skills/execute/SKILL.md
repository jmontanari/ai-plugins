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

If `.pre-commit-config.yaml` is absent, the hook inventory is empty and the Red `--no-verify` authorization does not fire — Red commits normally.

### Step 2: TDD-Red — Write Failing Tests

*(Mode: TDD only)*

1. Read agent template: `${CLAUDE_PLUGIN_ROOT}/agents/tdd-red.md`
2. Compose prompt with: phase [TDD-Red] tasks from plan, spec ACs, existing test patterns, and the `## Pre-flight snapshot` block from Step 1b. If the snapshot flags a test-running pre-commit hook, the Red agent is already authorized by its template to use `git commit --no-verify` on the Red commit only — no extra instruction needed in the prompt beyond attaching the snapshot.
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
- Pre-flight snapshot and pre-decisions are NOT persisted. On resume before Step 2 or 3, re-run Step 1b — it's cheap and ensures LOC/symbol facts aren't stale from earlier in the session.

## Measurement

At session end, emit a summary with per-phase **Build duration** and **Build token count** from task-notification data (the `duration_ms` field and token counts returned by Agent dispatches). Two observable properties on complex phases after these changes ship:

1. Build token count drops ≥ 30 % vs. a comparable-scope pre-change phase.
2. Build tool-use count drops ≥ 25 %.

If neither holds on two consecutive large phases, something other than the five inefficiencies addressed here is dominating — re-audit before adding more orchestration machinery.

## Known costs and caveats

- **Pre-flight on monorepos.** `git grep` across a very large repo is slow. Scope probes to the phase's declared scope directories and use path filters. If a probe would take more than a few seconds, skip it and let the agent rediscover — pre-flight is an optimization, not a correctness gate.
- **`pre-commit run` cost.** On projects whose pre-commit config runs type-check or the full test suite, the agent self-check (implementer/refactor/fix-code rule) can add minutes. Net positive vs. the hook-failure retry loop, but consider `--hook-stage commit` or a project-configured lightweight hook stage for the self-check if a full run is prohibitive.
- **Phase-size outliers are out of scope here.** These changes reduce *avoidable* work inside Implement. A phase with 1700+ LOC and five new files is expected to be expensive — the root fix for oversized phases lives in the `plan` skill (phase budgeting), not here.

## Graceful Degradation

If the Agent tool is unavailable, perform all steps sequentially in the main window. The mode-specific doctrine (TDD or Implement) and QA checklists still apply. This loses context isolation but preserves workflow gates.
