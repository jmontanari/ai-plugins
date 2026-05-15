# Learnings: pi-013-goal-exec (spec-flow v4.7.0)

**Piece:** GoalCreate / background agents / PushNotification / Monitor integration into execute skill
**Completed:** 2026-05-14
**Track:** Implement (non-TDD, prose-only deliverables)

## Patterns that worked well

**Phase Group parallelism for disjoint file sets.** Phase Group A ran Sub-Phase A.1 (SKILL.md TeammateIdle prose) and A.2 (12 agent file `background: true` additions) concurrently with zero conflict — genuinely disjoint scopes, no staging-area race, no serial fallback. The "large prose edit in one file + N uniform 1-line edits across N isolated files" shape is a repeatable Phase Group candidate.

**Refactor auto-skip on prose-only pieces.** All 4 phases correctly skipped the Refactor step. No refactor-ish defects surfaced in Final Review. The auto-skip predicate is reliable for doc-as-code pieces with no structural refactoring surface.

**Capability probe independence (FR-7).** The four-way independent probe pattern (probe → store in orchestrator state → gate each feature independently) is clean and composable. Adding a fifth probe variable later requires only adding a new `x_available = (tool is present)` line and gating the new feature block — no other changes.

**Resume guard via manifest status.** Using `status: in-progress` as the `resuming_session` signal is cheap, already-canonical state. Requires no additional persistence layer and is consistent with how the Pre-Loop already detects resumed sessions.

## Issues QA caught

**Dead capability-probe variable.** `background_available` was defined in Phase 1 and consumed in Phase Group A.1, but Phase A.1 lacked an explicit "wire probe to guard" step. The TeammateIdle block was armed unconditionally, creating a guaranteed false 10-minute hard stop on foreground hosts. Final Review iter-1 caught this. Prevention: for every capability-probe variable, the consuming phase's [Implement] block should explicitly require "guard at all call sites — no unconditional invocations."

**Branch-symmetry failure in fix-code.** The 3-iteration Final Review cycle traced entirely to one failure mode: fix-code set `monitor_armed = true` in the fresh-arm branch (iter 2) but left the resume branch as a comment (not an assignment). The iter-3 re-review caught the residual. Fix-code is finding-scoped, not invariant-scoped — it addresses the stated finding but does not automatically apply symmetric fixes to sibling branches. Future fix-code dispatches involving state-variable assignments should explicitly ask: "apply the same fix to all parallel branches."

**FR-8 skip predicate over-broad for orchestration prose.** The "no new branching control flow" condition in the FR-8 QA-skip predicate was applied to all 4 phases. But SKILL.md prose that says "if X then do A, else do B" expresses conditional orchestration logic — and all 7 iter-1 must-fix findings stemmed from incomplete branch handling in that prose. For future pieces: SKILL.md edits containing if/else/guard blocks should not be classified as "no branching control flow" — they warrant per-phase Opus QA even when the deliverable is markdown.

**NN-P-002 citation missing from spec.** The spec's "Non-Negotiables Honored (Product)" section omitted NN-P-002, despite the GoalCreate integration directly implementing the two-human-gate constraint. Caught by PRD alignment reviewer in iter-1. Reminder: any piece that interacts with a gating or approval mechanism should audit all relevant NN-P entries, not just the obvious ones.

## Recommendations for future specs

1. **Capability-probe pieces need explicit "wire to guard" tasks.** Any spec introducing a probe variable (`x_available`) must have a plan task in each consuming phase that says: "confirm `x_available` gates the feature block; verify no unconditional call sites." This collapses the dead-variable class.

2. **SKILL.md edits with conditional blocks bypass the FR-8 skip predicate.** Treat conditional orchestration prose (if/elif/else, arm/teardown pairs, resume guards) as equivalent to branching control flow for QA purposes. Add this carve-out to the next execute SKILL.md amendment.

3. **Fix-code prompts for multi-branch state variables should include sibling-branch instruction.** When the must-fix is "set variable X in branch Y," the fix-code prompt should add: "also verify that variable X is set (or explicitly absent-by-design) in all sibling branches." This avoids the iteration-3 residual pattern.

4. **Review-board agent files are a natural Phase Group A.2 target.** 12 files, 1 line each, fully disjoint — this pattern will recur whenever agent frontmatter evolves. Established as a working Phase Group shape.

5. **Orphan goal/monitor lifecycle needs a follow-up piece.** The `goal_id` and `monitor_id` variables are held only in session-local orchestrator state. Pre-commit-crash scenarios leave permanent orphans. Persistence via git note + orphan detection at Step 0 is the clean fix (see backlog items deferred from this piece).
