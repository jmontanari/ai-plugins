# shared-plugins backlog

Capability-scoped deferred work for the shared-plugins PRD. Items here are surfaced during the brainstorm phase of each new spec under this PRD and either incorporated, deferred, or marked obsolete. For cross-PRD learnings or spec-flow process findings, use `docs/improvement-backlog.md` instead.

---

## Phase Group parallelism — empirical timing measurement

**Status:** v3.1.0+ candidate (data-gathering, not blocking)
**Type:** process-improvement
**Captured:** 2026-04-25 (PI-008 reflection — future opportunity)

### Problem

PI-008 was first piece using Phase Groups (Group A: 5 parallel SKILL.md sub-phases; Group B: 4 parallel agent buckets). Plan has no explicit measurement of wall-clock savings vs. sequential baseline. Group A's Opus dispatch returned 529 Overloaded and fell back to Sonnet — a real-world data point that group-level QA dependency on Opus is a single point of failure, but no timing data to weigh against alternatives.

### Proposed direction

Lightweight telemetry: capture timing in `[Implement]` / `[Verify]` / `[QA]` steps in the next 2 pieces using Phase Groups; report findings here before deciding whether to systematize.

---

## Cross-PRD dependency orchestration (deferred to v4.0)

**Status:** deferred to v4.x
**Type:** future major
**Captured:** 2026-04-25 (PI-008 reflection — future opportunity)

### Note

v3.0.0 ships the *blocking* half of cross-PRD deps (refusing to start `execute` when a `depends_on:` ref is unmerged). The auto-suggesting half ("now that `auth/login-flow` is merged, here are 3 pieces it unblocked") is squarely deferred. Hold for v4.0 PRD when 3+ external projects accumulate enough multi-PRD usage to validate the need.

---

## Items incorporated into pi-009-hardening (2026-04-25)

The following items were specced into `docs/prds/shared/specs/pi-009-hardening/spec.md` and removed from the active backlog:

- FR-005 branch-design resolution → CAP-1 (single-branch path chosen with rationale)
- Charter-drift deep scan → CAP-2 (`/spec-flow:status --include-drift`)
- Worktree-token sweep → CAP-3 (`{{worktree_root}}` token across 6 SKILL.md files)
- Migrate-skill environment precondition → CAP-4 (path-1: documented LLM-agent-native preconditions, no specific language runtime mandated)

---

## Recent findings

## shared/pi-011-branch-fix — 2026-04-30

### Future opportunities for shared/pi-011-branch-fix

- **Derive `--base` branch from remote/config instead of hardcoding `main`** (priority: high)
  - Why it matters now: Step 6 of the `merge_strategy: pr` path emits `gh pr create --base main`. Any repo whose default branch is `master`, `trunk`, `develop`, or a release branch silently creates a PR against the wrong target. PI-011 shipped the `pr` strategy but intentionally hardcoded `main` to keep the scope bounded.
  - Concrete reference: PI-011 plan Step 6 note — "The step should derive the base branch from the remote or config rather than hardcoding." Relevant symbol: `SKILL.md` Step 6 `gh pr create --base main` line in the `merge_strategy: pr` block.
  - Suggested follow-up: Spec amendment to the existing `pr` strategy — read the default branch via `git remote show origin | awk '/HEAD branch/ {print $NF}'` (or from `.spec-flow.yaml` if a `default_branch:` key is added to the schema), then interpolate. One-spec amendment, no new piece needed.
  - Dependencies: none; can be picked up immediately as the next small amendment to the execute skill.

- **Call `git worktree prune` before `git worktree list` in status skill** (priority: high)
  - Why it matters now: The AC-7 / AC-8 implementation checks `git worktree list` to decide whether a piece's feature branch has an active worktree, and demotes stale `merged` entries back to `in-progress` (AC-9). If a user manually deletes a worktree directory without running `git worktree remove`, `git worktree list` still shows the stale entry — keeping the piece locked as `in-progress` indefinitely. This is reproducible any time `rm -rf` is used on a worktree path.
  - Concrete reference: PI-011 implementation gap flagged during advisory review — "stale entries from manually-deleted worktree directories would keep pieces showing as `in-progress` indefinitely." Relevant location: `status` SKILL.md, worktree-discovery block immediately before AC-7 branch-prefix scan.
  - Suggested follow-up: Single-line addition to the status skill — insert `git worktree prune 2>/dev/null || true` before the `git worktree list` call. Qualifies as a micro-amendment (no new piece, fold into next status-skill patch or pi-012-style hardening piece).
  - Dependencies: none.

- **Persist `phase_N_start_sha` as git notes at Step 7** (priority: medium)
  - Why it matters now: The cumulative-diff anchor (`phase_N_start_sha`) lives only in the orchestrator's in-context memory. If the LLM context is lost mid-piece (session crash, token overflow, manual interruption), recovery currently requires the human to manually locate the SHA from `git log`, as documented in the recovery addendum shipped with PI-011. Git notes attached to the Phase 1 commit would make that SHA durable and machine-readable without any separate state file.
  - Concrete reference: PI-011 implementation advisory — "A more robust solution would persist these SHAs as git notes at Step 7. Deferred as advisory." The recovery documentation lives in `docs/prds/shared/specs/pi-011-branch-fix/` (recovery-notes section).
  - Suggested follow-up: New small piece — add a `git notes add -m "spec-flow:phase_start_sha=<sha>" HEAD` call in the execute skill at the end of Step 7 (pre-loop setup), and a corresponding lookup in the recovery runbook. Low implementation cost, high resilience payoff once pieces grow longer.
  - Dependencies: none; can be specced independently.

- **Final Review circuit-breaker: 4-iteration cap with human escalation** (priority: medium)
  - Why it matters now: Per-phase QA has an explicit 3-iteration limit before the orchestrator escalates to human. Final Review has no equivalent guard. PI-011 itself ran 6 review-board iterations before going clean — within the acceptable range for a complex piece, but with no structural upper bound. A runaway Final Review with an unusually strict review board can spin indefinitely.
  - Concrete reference: PI-011 execution session — 6 Final Review iterations observed; no circuit-breaker fired because none exists. Per-phase circuit-breaker precedent is in the execute SKILL.md QA-phase loop.
  - Suggested follow-up: Spec amendment to the execute skill — mirror the per-phase pattern: track `review_board_iteration_count`; after 4 iterations without a clean pass, halt with `FINAL REVIEW BLOCKED — 4-iteration cap reached` and surface all outstanding findings to the human for triage. Does not require a new piece; one targeted amendment to Step 4 of Final Review.
  - Dependencies: none; independent of the `git notes` and `worktree prune` items.

- **`.spec-flow.yaml` `merge_strategy` config update (user action)** (priority: low)
  - Why it matters now: PI-011 shipped `merge_strategy: pr` support, but the repo's own `.spec-flow.yaml` still reads `squash_local`. This means every future piece in this repo will squash-merge locally rather than opening a PR, which is inconsistent with the intended PR-based workflow the user described. This is a one-line config change, not a code change, and was explicitly left for the human during PI-011.
  - Concrete reference: PI-011 deferred gap 1 — "`.spec-flow.yaml` still says `merge_strategy: squash_local` but the user's repo is PR-based. This is a one-line change but was intentionally left for the human."
  - Suggested follow-up: Human action — update `.spec-flow.yaml` `merge_strategy: squash_local` → `merge_strategy: pr` before starting the next piece. No new backlog piece needed; just a pre-flight config check to add to the next spec's brainstorm checklist.
  - Dependencies: Resolving the `--base main` hardcoding item above first would be prudent, so the first real PR opened via the `pr` strategy targets the correct base branch.

---
