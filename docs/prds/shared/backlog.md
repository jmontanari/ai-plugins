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
