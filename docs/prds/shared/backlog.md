# shared-plugins backlog

Capability-scoped deferred work for the shared-plugins PRD. Items here are surfaced during the brainstorm phase of each new spec under this PRD and either incorporated, deferred, or marked obsolete. For cross-PRD learnings or spec-flow process findings, use `docs/improvement-backlog.md` instead.

---

## FR-005 branch-design resolution — spec text vs. shipped behavior

**Status:** v3.1.0 candidate
**Type:** spec-amendment
**Captured:** 2026-04-25 (PI-008 reflection — Group A QA deferral)

### Problem

v3.0.0 spec FR-005 prescribes three distinct branches per piece (`spec/<prd>-<piece>`, `plan/<prd>-<piece>`, `execute/<prd>-<piece>`). The shipped SKILL.md updates and v2 reality keep a single shared `spec/...` branch through plan and execute. AC-16/AC-17 only test the `spec/...` form; `plan/...` and `execute/...` are uncovered by acceptance tests, which is how the divergence slipped through Final Review.

### Two paths — pick one

1. Update FR-005 to match single-branch reality (current code); tighten existing ACs.
2. Amend SKILL.md to actually create three branches per phase; add ACs covering all three branch verbs.

### Why-now

Group A QA explicitly deferred this. Shipped major version is internally inconsistent on this point — can't ship a patch release without picking a side.

---

## Charter-drift static analyzer (passive deep scan)

**Status:** v3.1.0 candidate
**Type:** new piece
**Captured:** 2026-04-25 (PI-008 reflection — future opportunity)

### Problem

v3.0.0 ships drift detection only on `last_updated:` timestamp comparison. That catches "charter file was edited" but not "the spec's `### Non-Negotiables Honored` block cites NN-C-007 but NN-C-007's body has changed in a way that contradicts the spec's claim." The current detection treats every charter edit as equivalent, including no-op formatting changes, and misses semantic drift entirely.

### Proposed direction

Extend `/spec-flow:status` with `--include-drift` deep-scan mode that opens each spec, parses NN/CR citations, and verifies them against current charter bodies. Surface semantic drift without requiring spec/plan/execute re-runs.

### Design questions to resolve

- Verbatim string match vs. semantic check — what threshold catches real drift without false-positives on harmless rewording?
- Block status output, or surface as a separate `/spec-flow:status --drift-report` command?
- Performance — does the deep scan run on every `status` invocation, or opt-in only?

---

## Worktree-token sweep across implementer agent prompts

**Status:** v3.1.0 candidate
**Type:** template-level / process-improvement
**Captured:** 2026-04-25 (PI-008 reflection — future opportunity)

### Problem

Implementer prompts repeatedly carry literal `worktrees/...` paths instead of being relative to a single env-derived prefix. v3.0.0's path-token sweep caught hard-coded `docs/` references but not `worktrees/`. Now that worktree convention has changed (v3.0.0: `worktrees/prd-<prd-slug>/piece-<piece-slug>/`), every prompt would need re-templating again on the next convention change.

### Proposed direction

Add `{{worktree_root}}` template token resolved by orchestrator from the current PRD+piece slugs. Sweep all 17 agent prompts for hard-coded `worktrees/` references and replace with the token.

### Design questions to resolve

- Token name — `{{worktree_root}}` vs. `{{piece_worktree}}` vs. `{{worktree_path}}`? Whichever pairs cleanly with the existing `{{docs_root}}` token.
- Resolution timing — at prompt-render time (orchestrator), or inside agent SKILL.md preamble?

---

## Migrate skill environment precondition or embedded helper

**Status:** v3.1.0 candidate (potentially charter-amendment-blocked)
**Type:** tech-debt
**Captured:** 2026-04-25 (PI-008 reflection — future opportunity)

### Problem

`skills/migrate/SKILL.md` (370 LOC, NEW) prescribes `git mv` + grep + sed sequences the implementing LLM/operator runs literally. NN-C-002 forbids new runtime deps. But complex YAML mutations are hard to do safely with grep+sed alone — there is unstated tension between "no runtime deps" and "do safe YAML edits."

### Two paths — pick one

1. Formally document "the migrate skill runs in an LLM environment with `yq`/`python3` available" as a precondition; update NFR-004 (and likely NN-C-002 scope clarification).
2. Ship a tiny embedded Python helper script (NN-C-002 charter amendment required — opens scope question for embedded tooling generally).

### Why-now

Phase 7 explicitly deferred operational runs because the skill assumes a richer environment than NN-C-002 admits. Until resolved, the migrate skill ships in a state where its [Verify] gate can't be reliably executed by spec-flow itself. Path 2 needs a charter brainstorm before it can be specced.

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
