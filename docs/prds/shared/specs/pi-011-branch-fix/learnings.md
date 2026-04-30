# Learnings: shared/pi-011-branch-fix

## Patterns that worked well

**Phase decomposition was surgical.** Each phase owned a single concern (Pre-Loop, merge strategy, spec/plan skills, status, version), so no phase ever touched files in another's scope. Phase Group A (parallel spec + plan SKILL.md updates) ran with zero staging conflicts — a direct contrast to pi-009's Phase Group A contamination event. The branch-ownership model enforces clean boundaries by construction.

**Iter-1 Final Review was atomic.** All five review agents ran concurrently before any fix was dispatched, surfacing 5 must-fix groups in a single pass. This is the correct way to use the review board — diverging fixes after partial iter-1 results would have compounded the edge-case cascade that followed.

**Auto-skip predicates were 100% accurate for doc-as-code.** Refactor skipped on all 5 phases; per-phase QA skipped on 4 of 5. For a piece where every diff is SKILL.md prose with no structural refactoring surface, these skips are reliably correct. The `refactor: auto` and QA-skip predicates are well-tuned for this piece type.

## Issues QA caught

**Per-phase QA did not catch what it should have.** Phase 2 introduced the piece's most complex logic — the `merge_strategy` branch, the rejection path with `git reset --hard`, and the rework re-entry behavior. Per-phase QA ran one iteration, dispatched one fix, and returned clean. The Final Review edge-case reviewer then found 6 separate must-fix items (Edges A–F) across iterations 2–5, all in that same Phase 2 logic.

The root cause is that per-phase QA used structural grep as its Verify mechanism. For multi-branch control-flow in bash/doc-as-code context, "this section looks right" is insufficient — each conditional arm needs to be walked independently. The edge-case reviewer did that work; per-phase QA did not.

**The Final Review cascade pattern is a process signal.** Iterations 2–5 each introduced a new must-fix item caused by the previous fix changing the rejection path. Fixing Edge-A (wrong revert target) exposed Edge-B (rework re-entry). Fixing Edge-B exposed Edge-C. Fixing Edge-C exposed Edge-D. This is a scope-explosion cascade, not a series of independent oversights — and the orchestrator had no mechanism to detect it or offer human triage.

**Review board composition was mismatched for doc-as-code.** The blind reviewer contributed 0 must-fix items across all 6 iterations. The edge-case reviewer contributed 67%. Blind review is optimized for runtime code smell (naming, resource leaks, security) — none of which surfaces in SKILL.md prose. The current 1:1 board composition assumed "code" pieces; doc-as-code needs a different slot allocation.

**Silent failure was the root defect's mechanism.** `git checkout main` inside a git worktree fails silently — no error, no output, the command appears to succeed while leaving the worktree on the wrong branch. This allowed the Pre-Loop manifest writes to fail invisibly across multiple prior pieces. Silent failures of this kind are only discoverable by the piece that specifically sets out to find them (or by a runtime validation check).

## Recommendations for future specs

1. **For non-TDD doc-as-code pieces, state every execution branch as an explicit AC.** If the plan prose says "if merge strategy is pr" or "if rejection occurs" — those are branches that need to be AC-numbered and independently verifiable. Spec-compliance reviewer checks ACs; if branches aren't ACs, they won't be checked. This is the spec-authoring discipline change that would have prevented the Edge-A through Edge-F cascade.

2. **Add `review_board_variant: doc-as-code` annotation to the plan for pure-SKILL.md pieces.** This signals the orchestrator to substitute the blind reviewer slot with a second edge-case pass (or a dedicated "bash-path-coverage" reviewer). The edge-case reviewer's 67% contribution rate on this piece is a strong empirical case.

3. **Per-phase QA must include an explicit edge-case walkthrough when a phase introduces multi-branch control flow.** The current per-phase QA surface map (files, symbols, callers, diff, AC matrix, non-negotiables) does not have a "walk each conditional arm" requirement. For shell/bash/doc-as-code phases, add this as a mandatory QA prompt element when the diff contains if/elif chains or rejection/rework paths.

4. **Consider a Final Review circuit-breaker at 4 iterations.** Per-phase QA has a 3-iter cap; Final Review has none. Mirroring that pattern with a 4-iter cap (reflecting the higher expected iteration count for Final Review) and a human-escalation signal on the cascade pattern would prevent unbounded review loops on complex pieces.

5. **Add a `git worktree prune` before `git worktree list` in the status skill** (one-line fix). Stale worktree entries from `rm -rf` keep pieces locked as `in-progress` indefinitely without it.

6. **The `--base main` in `merge_strategy: pr`'s `gh pr create` should be derived, not hardcoded.** The current Step 6 emits `--base main`; repos using `master` or `trunk` will silently open PRs against the wrong target. Fix: `git remote show origin | awk '/HEAD branch/ {print $NF}'`.
