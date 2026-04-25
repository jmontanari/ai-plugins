# Learnings — PI-008-multi-prd-v3.0.0

End-of-piece reflection for the spec-flow v3.0.0 multi-PRD migration. Captured at the close of execute, before squash-merge to master. Two reviewers contributed: process-retro (orchestration mechanics) and future-opportunities (forward-looking spec/process candidates).

---

## Process retro — PI-008-multi-prd-v3.0.0

### Final Review surfaced 11 must-fix items across 11 files — too much leaked past per-phase QA

**Severity:** high

**Description:** The Final Review fix-up commit (`40876e6`) touched 11 files and added 150 lines, including substantive correctness fixes: a hook regex that didn't reject non-numeric `layout_version` values (Phase 2), an inline manifest-status example out of sync with the state machine (Phase 1), missing `--ignore-deps` warning detail (Sub-Phase A.4), and ~109 lines of additional safety/contract text in the migrate skill (Phase 4). All five Final Reviewers ran on the *finished* piece, but architecture/edge-case/blind together found 11 distinct issues that were structurally invisible to per-phase Sonnet QA-lite reviews because each sub-phase only saw its own file's diff. This indicates per-phase QA is well-scoped for in-file correctness but blind to integration-level ambiguities.

**Recommendation:** For pieces with ≥6 phases that all skip Opus QA, insert one mid-piece Opus pass at the half-way commit reviewing the cumulative diff against the spec, not just one phase. Phase 2's regex bug and Phase 1's state-machine inconsistency would both have been caught at that gate, eliminating ~60% of the Final Review fix-up workload.

### Skip-predicate for Opus QA fired on every flat phase — the rationale was uniform but the outcomes weren't

**Severity:** high

**Description:** Phases 1, 2, 3, 4, 5, 6, 7 all auto-skipped formal Opus QA dispatch with rationale "structural-only / mechanical / N-LOC change / verify gates passed." But Phases 2 and 4 produced the largest fix-up footprint (10 hook lines + 109 migrate-skill lines = ~80% of the Final Review fix-up). The skip-predicate's heuristic — "small or structural diff" — is not a reliable proxy for "low risk," because behavioral phases (the hook = real bash logic; the migrate skill = real `git mv` orchestration) are exactly where ambiguities hide regardless of LOC. Phase 6 (3-line version bump) skipping was clearly correct; Phase 2 (14-LOC hook) skipping clearly wasn't.

**Recommendation:** Sharpen the skip-predicate: skip Opus only when the phase is *additive markdown/YAML or pure config*. Any phase touching shell logic, branching control flow, or a new skill body should default to Opus QA regardless of LOC.

### Group-level Sonnet fallback worked, but the design ambiguity it surfaced was deferred without a tracking mechanism

**Severity:** medium

**Description:** When Opus returned 529 mid-Phase-Group-A, the orchestrator fell back to Sonnet, which flagged 4 must-fix items: 3 mechanical (applied) and 1 design ambiguity (FR-005 lists 3 branches per piece vs v2's single-branch reality). The design item was deferred to "end-of-piece reflection" per the Group A commit message — but Final Review's PRD-alignment + spec-compliance reviewers (which would naturally re-check spec coherence) both came back clean, and it was never explicitly re-raised. The branch-count ambiguity is now baked into a shipped major version with no follow-up issue captured.

**Recommendation:** When a QA gate produces a "deferred to reflection" finding, the orchestrator should append a stub item to the PRD-local backlog at deferral time (not at end-of-piece), so reflection agents see it as input rather than the orchestrator needing to re-surface it from commit history.

### Phase 4 (migrate skill, 275 LOC NEW) was undersized as a single phase

**Severity:** medium

**Description:** Phase 4 produced the single largest non-group commit (~370 lines in `skills/migrate/SKILL.md`) and accumulated the largest Final Review correction (109 added lines, 30% of the original file). Behaviorally it has 8 sub-procedures, `--inspect` and `--force` flags, 3 detection branches (v0/v1/v2), 3 safety checks, and a MIGRATION_NOTES.md format spec — each of which is a candidate sub-phase. The plan flattened all of this into one Implementer dispatch with one verify pass.

**Recommendation:** When a single phase's deliverable exceeds ~150 LOC of new behavioral prose, split into a Phase Group: detection-and-safety as Sub-Phase 1, mutation-and-commit as Sub-Phase 2, MIGRATION_NOTES + dry-run as Sub-Phase 3. Each sub-phase gets independent verification.

### Phase 7 dog-food was deferred to release time, but the plan claimed AC-15 as covered

**Severity:** medium

**Description:** Phase 7's [Implement] block explicitly states "Steps 2-4 (--inspect dry-run + real migration + AC-15 assertions) are operationally deferred to the human releaser per the AC-18 procedure." The phase exit gate originally read "the migrate skill ran successfully against a clean clone" — but in practice the migrate skill never ran. AC-15 (clean-clone migration verification) is marked covered in the plan but is actually only *documented*, not *executed*. Final Review's spec-compliance reviewer didn't flag this, presumably because the deliverable file (`release-v3.0.0.md`) exists.

**Recommendation:** When a phase's exit gate is "X ran successfully," the plan should not be allowed to swap that for "X is documented to run later." If pre-merge execution truly isn't possible, the plan author should split the piece — ship the skill in PI-008, run the dog-food in a follow-on PI-008b.

### Tool-availability lessons (yq/jq) recurred and forced ad-hoc substitutions mid-execute

**Severity:** medium

**Description:** Phase 1 hit `yq` absent (substituted `python3 + PyYAML`, which then rejected `{{date}}` template placeholders) and Phase 6 hit `jq` absent (substituted `python3 + json.load`). Both substitutions worked but were improvised mid-flight. The plan's [Verify] commands assume `yq` and `jq` are present, and the per-phase verify commands were not adjusted in the plan even after the Phase 1 lesson was learned.

**Recommendation:** Plan templates should prefer Python-based YAML/JSON validation in [Verify] commands by default for spec-flow's own pipeline (since spec-flow is markdown+config-only, there's no reason to depend on yq/jq), and the orchestrator should standardize on `python3 -c` invocations for these checks.

### Compact-then-resume mid-execute went smoothly — pattern worth keeping

**Severity:** low (worked-well)

**Description:** Phase 1 ran in the original session; the orchestrator compacted between Phase 1 and Phase 2, then resumed and executed Phases 2-7 + Final Review in the compacted session without state-loss artifacts in any commit. The piece's MEMORY.md note (`project_pi008_execute_state.md`) captured the resume state including worktree-path and yq lessons, which fed forward correctly into Phase 2+.

**Recommendation:** Document this compact-resume protocol explicitly in the execute SKILL: "compact between flat phases (not mid-Phase-Group), persist key environmental lessons to a memory note keyed on the piece slug." This piece is the working evidence pattern.

### Spec authoring required 2 QA fix iterations — bigger spec ≠ more iterations

**Severity:** low (worked-well)

**Description:** Spec went 47b627d → 407d9e1 (QA iter-1 fixes) → e3bb916 (added AC-19/AC-20 for FR-022/FR-023). Two iterations to converge on a 395-line spec covering 23 FRs and 20 ACs is healthy throughput — by contrast, plan authoring converged in a single iteration (1a8f419, 653 lines).

**Recommendation:** Keep the current spec-QA discipline (2-iter cap before escalation). The PI-008 spec is a good exemplar for "how detailed should a v3.0.0-class breaking-change spec be."

### Orchestration metrics

- **Active execution wall time excluding overnight gap:** ~3h 30m across spec + plan + 7 phases + 2 phase groups + Final Review.
- **Total commits:** 23 (3 spec, 1 plan, 7 phase commits + 7 progress markers, 2 group commits + 2 progress markers, 1 Final Review fix-up).
- **Cumulative diff:** 27 files, ~2287 insertions / ~170 deletions.
- **Final Review fix-up footprint:** 11 files / 150 insertions / 21 deletions = 7.5% of the cumulative diff was correction.
- **Phase Group A QA fallback chain:** Opus 529 → Sonnet → 4 must-fix returned (3 applied, 1 deferred). Net cycle time ~20 minutes for the group.
- **Opus skip rate:** 7 of 7 flat phases skipped Opus QA. Sonnet group QA used as fallback in 1 of 2 groups; Group B skipped entirely.
- **Slowest single phase:** Phase Group A at ~20m (5 sub-phases + Refactor + Sonnet group QA).
- **Fastest substantive phase:** Phase 6 (version bump) at ~2m — single correct skip-predicate decision.

---

## Future opportunities — PI-008-multi-prd-v3.0.0

### 1. Resolve FR-005 vs SKILL.md branch-design ambiguity

- **Type:** spec-amendment (follow-on piece in v3.x)
- **Description:** Spec FR-005 prescribes three distinct branches per piece — `spec/<prd-slug>-<piece-slug>`, `plan/<prd-slug>-<piece-slug>`, `execute/<prd-slug>-<piece-slug>`. Phase Group A QA caught (and deferred) the conflict that the actual SKILL.md updates and v2 reality use a single shared `spec/...` branch through plan and execute. v3.0.0 ships with the single-branch model in code while the spec text says otherwise — that is unsustainable across patch releases.
- **Why-now (PI-008-specific):** Group A QA explicitly deferred this. AC-16 / AC-17 only test the `spec/<prd>-<piece>` form; the `plan/...` and `execute/...` variants in FR-005 are uncovered by acceptance tests, which is how the divergence slipped through.
- **Proposed-next-step:** v3.1.0 spec amendment that picks one model: either update FR-005 to match the single-branch reality, or amend SKILL.md to actually create three branches; add ACs covering all three branch verbs.

### 2. Charter-drift static analyzer (passive deep scan)

- **Type:** piece-candidate (new PRD piece in v3.x)
- **Description:** v3.0.0 ships drift detection only on `last_updated:` timestamp comparison. That catches "charter file was edited" but not "the citation list in the spec's `### Non-Negotiables Honored` block points at NN-C-007 but NN-C-007's body has changed in a way that contradicts the spec's claim." A passive `/spec-flow:status --include-drift` deeper-scan mode could read every spec's NN/CR citations and verify the cited entries still exist verbatim in the charter file, surfacing semantic drift without requiring spec/plan/execute re-runs.
- **Why-now (PI-008-specific):** PI-008 introduced the FR-009 input-bundle drift dispatch but it's only triggered runtime. The deeper "citation still valid" check is a natural next step now that the snapshot/drift plumbing exists.
- **Proposed-next-step:** New piece in v3.1.0 PRD: extend status skill with `--include-drift` deep-scan mode that opens each spec, parses citations, and grep-verifies them against current charter bodies.

### 3. Replace prescribed-shell migration with a YAML helper or formalized environment precondition

- **Type:** piece-candidate / tech-debt
- **Description:** `skills/migrate/SKILL.md` (370 LOC, NEW) prescribes `git mv` + grep + sed sequences the implementing LLM/operator runs literally. NN-C-002 forbids new runtime deps. But complex YAML mutations are hard to do safely with grep+sed alone. There is unstated tension between "no runtime deps" and "do safe YAML edits."
- **Why-now (PI-008-specific):** Phase 7 explicitly deferred operational runs because the skill assumes a richer environment than NN-C-002 admits. The mid-execute state memory also flags worktree-path + yq lessons as recurring friction.
- **Proposed-next-step:** v3.1.0 piece that either (a) formally documents "the migrate skill runs in an LLM environment with yq/python available" as a precondition and updates NFR-004 accordingly, or (b) ships a tiny embedded Python helper script (charter NN-C-002 amendment required if so).

### 4. Auto-resolve worktree-prefixed paths in implementer agent prompts

- **Type:** process-improvement (template-level)
- **Description:** Implementer prompts repeatedly carry literal worktree paths instead of being relative to a single env-derived prefix. Every new piece that ships in a worktree pays this cost again — and when worktree directory naming changes (which it does in v3.0.0 to `worktrees/prd-<prd-slug>/piece-<piece-slug>/` per FR-004), every prompt needs re-templating.
- **Why-now (PI-008-specific):** This piece is the one that's *changing* the worktree path convention. The path-token sweep in Sub-Phase B.4 caught hard-coded `docs/` paths but not hard-coded `worktrees/` paths.
- **Proposed-next-step:** v3.1.0 piece: add a `{{worktree_root}}` template token resolved by the orchestrator from the current piece's PRD+piece slugs; sweep all 17 agent prompts for hard-coded `worktrees/` references and replace with the token.

### 5. Phase Group parallelism: empirical elapsed-time measurement and ergonomics

- **Type:** process-improvement
- **Description:** PI-008 is the first piece to use Phase Groups in earnest (Group A: 5 parallel SKILL.md sub-phases; Group B: 4 parallel agent buckets). Plan has no explicit measurement of wall-clock savings vs. the sequential baseline, and the `[Refactor]` step was auto-skipped in both groups. There's no signal yet on whether the 5×/4× parallelism delivers proportional time savings or whether the group-level QA bottleneck dominates.
- **Why-now (PI-008-specific):** PI-008 is the canonical proof-of-concept for the pattern. Both groups completed cleanly with auto-skipped Refactor and degraded QA (Group A's Opus dispatch returned 529 Overloaded and fell back to Sonnet — a real-world data point that the group-level QA dependency on Opus is a single point of failure).
- **Proposed-next-step:** Lightweight telemetry piece: add timing capture to `[Implement]` / `[Verify]` / `[QA]` steps in the next 2 pieces using Phase Groups; report findings in `docs/improvement-backlog.md`.

### 6. Cross-PRD dependency orchestration (v4.0 scope)

- **Type:** piece-candidate (future major)
- **Description:** Spec line 41 explicitly defers cross-PRD orchestration: "v3 only records the declaration; execution decisions remain human." But FR-011 / AC-11 ship the *blocking* half of the contract (refusing to start `execute` when a `depends_on:` ref is unmerged). The next logical step — auto-suggesting "now that `auth/login-flow` is merged, here are the 3 pieces it unblocked" in `/spec-flow:status` — is squarely deferred.
- **Why-now (PI-008-specific):** v3.0.0 ships the declarative half. The orchestrator side is untouched. The `--ignore-deps` flag is the deliberate-deviation escape hatch for v3.x; auto-orchestration is the next major's territory.
- **Proposed-next-step:** v4.0 PRD when 3+ external projects accumulate enough multi-PRD usage to validate the need; adds `/spec-flow:status --unblocked` to surface dependency-graph deltas after each merge.

---

## Routing note

These reflections are captured in this `learnings.md` rather than being appended to `docs/improvement-backlog.md` (global) and `docs/prds/<prd-slug>/backlog.md` (PRD-local) because:

- The PRD-local target does not exist in this worktree — PI-008 itself is the piece introducing the v3 layout, so `docs/prds/PI-008/backlog.md` would be circular.
- The global `docs/improvement-backlog.md` exists on master but not in this worktree (it was added on master after this branch was cut). Persisting reflection findings into a learnings.md inside the piece folder ensures they squash-merge cleanly.

After PI-008 merges to master, the global `docs/improvement-backlog.md` should be updated with the high-severity process-retro findings (skip-predicate calibration, mid-piece Opus pass, deferred-finding tracking) and the PRD-local backlog convention takes effect for subsequent pieces.
