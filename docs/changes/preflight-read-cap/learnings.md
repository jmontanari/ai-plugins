# Learnings: preflight-read-cap (5.19.0)

**Change:** Cap execute pre-flight (Step 1b) to bounded probes; forbid full source/test file body reads into coordinator context.
**Captured:** 2026-06-13

---

## What worked well

**Implement-track on a doc-as-code change is extremely low-friction.** Single phase, grep-based `[Verify]` assertions, zero escalations, zero amendments, 7/7 Final Review board PASS on first pass. Reference data point for future prose/metadata changes: the full execute pipeline (pre-flight → implement → verify → QA → Final Review → reflection → merge) ran in one session with no retries.

**FR-8 skip predicate fired correctly.** The `[QA-SKIP]` skip predicate evaluated cleanly: condition (a) failed because the Orchestrator Role bullet was a paragraph *replacement* rather than a pure addition — correctly routing Opus QA. No false-skip. QA returned PASS on first dispatch.

---

## What to improve

### Security agent false-negative from worktree path confusion

The Final Review security agent ran against the main repo root instead of the active worktree, reporting 0 matches for "Probe budget" and claiming versions were still 5.18.0 — contradicted by 6 other board agents. The WORKTREE dispatch preamble exists as a rule but was not injected explicitly enough into individual board-agent prompts. Required re-dispatch with explicit path anchoring.

**Deferred to improvement-backlog.md:** "Final Review board WORKTREE anchoring (security agent false-negative)"

**Fix direction:** Each of the 7–9 Final Review board agent prompts should carry a `WORKTREE: <absolute-path>` first-line assertion; the security-agent Rule 0 should verify the path before proceeding.

---

## Future opportunity

### qa-plan needs a Change Specification Block completeness criterion

Now that Step 1b forbids coordinator file-body reads, the plan's Change Specification Block is the only sanctioned source for signatures the implementer needs up front. qa-plan has no criterion enforcing this: a plan with silent coordinator-read dependencies (e.g. "orchestrator can look up the constructor at pre-flight") can pass qa-plan today and block only at execute time when the coordinator refuses to do the read.

**Deferred to improvement-backlog.md:** "qa-plan criterion: Change Specification Block signature completeness"

**Fix direction:** Add a qa-plan criterion verifying that each phase's Change Specification Block explicitly names any constructor/method signatures needed, with no implicit "coordinator reads it during pre-flight" dependency.
