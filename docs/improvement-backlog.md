# Improvement Backlog

Cross-PRD learnings and future work candidates. Items here are surfaced during the brainstorm phase of each new spec and either incorporated, deferred, or marked obsolete.

---

## Ad-hoc "task" work — lightweight spec→plan→execute for out-of-band work

**Status:** concept — awaiting dedicated PRD brainstorm
**Captured:** 2026-04-24
**Depends on:** Multi-PRD support PRD (needs `docs/prds/` to land before `docs/tasks/` can be a clean sibling namespace)

### Problem

Not all work fits a full PRD. Bug fixes, small maintenance items, quick improvements, and items graduating from the backlog shouldn't require:

- A PRD document
- A manifest entry under a PRD
- A full multi-phase plan
- Charter-level non-negotiable scoping

Forcing them through the full pipeline is where teams stop using spec-flow for smaller work — and then discipline erodes on the work that actually ships.

### Starting-discussion shape (from 2026-04-24 brainstorm)

Goal: a lightweight flow that preserves discipline (charter still applies, AC still required, tests still written) but skips the PRD + heavy plan overhead.

Proposed layout (sibling to `docs/prds/`):

```
docs/tasks/
├── <task-slug>/
│   ├── spec.md           # lightweight template: problem, AC, non-goals
│   ├── plan.md           # often single-phase
│   ├── learnings.md
│   └── (no research/, no ac-matrix if trivial)
└── index.yaml            # flat registry with status per task
```

New skill: `/spec-flow:task` — possibly combines brainstorm + spec + plan in one skill since scope is small.
Existing `/spec-flow:execute` consumes task plans the same way it consumes piece plans.

### Design questions to resolve in that PRD's brainstorm

1. Does a task have a `parent_prd:` field for traceability, or is it truly standalone?
2. Do tasks go through the full QA gate stack, or does the lightweight spec template itself carry the discipline?
3. Can a task graduate to a PRD if scope explodes mid-work? What does that migration look like?
4. Do tasks share worktree/branch conventions with pieces (`worktrees/task-<slug>/` + `spec/task-<slug>`), or have their own namespace entirely?
5. Does `/spec-flow:task` combine brainstorm + spec + plan in one skill (since scope is small), or keep them as separate phases like the PRD flow?
6. How do backlog items get promoted into tasks? Manual copy during brainstorm, or a dedicated `/spec-flow:task-from-backlog <item>` helper?
7. Does charter still apply in full, or is there a "charter-light" mode for tasks? (Leaning: charter always applies — no escape hatch.)
8. Task lifecycle states — same as PRD pieces (`open`, `specced`, `planned`, `in-progress`, `merged`), or simpler?

### Non-negotiables inherited from the main discussion

- Charter stays singular and applies to tasks identically to PRD pieces.
- Tasks participate in the global `improvement-backlog.md` (reflection still runs; retros still surface).
- Charter-drift detection from the multi-PRD PRD applies to tasks too once implemented.

### Prerequisite

Multi-PRD support PRD must land first — it establishes `docs/prds/<name>/` as a first-class namespace, which makes `docs/tasks/` a clean sibling. Building tasks on today's single-PRD layout would create a second migration later.

---

## Items incorporated into pi-009-hardening (2026-04-25)

The following process-retro items from PI-008's reflection were specced into `docs/prds/shared/specs/pi-009-hardening/spec.md` as v3.1.0 orchestrator hardening:

- Sharpen Opus QA skip-predicate → ORC-1 / FR-8 (additive markdown/YAML/config skips Opus; control-flow constructs and new skill bodies route to Opus regardless of LOC).
- Mid-piece Opus QA pass for ≥6-phase pieces → ORC-2 / FR-9 (half-way pass on cumulative diff).
- Deferred-finding tracking — orchestrator writes backlog stubs at deferral time → ORC-3 / FR-10.
- Phase sizing rule — split when phase >150 LOC of behavioral prose → ORC-4 / FR-11.
- Phase exit-gate semantics — "X ran" can't downgrade to "X is documented" → ORC-5 / FR-12.
- LLM-native [Verify] default for YAML/JSON validation → ORC-6 / FR-13 (drops `yq`/`jq` shell-outs in favor of LLM-agent-step framing; no specific language runtime mandated).
- Iter-until-clean QA loop, applied universally → ORC-7 / FR-14, FR-15 (added during scoping; retires `qa_iter2: auto` skip predicate, codified in `plugins/spec-flow/reference/qa-iteration-loop.md`).

---

## pi-009-hardening — 2026-04-25

### Process retro for pi-009-hardening

#### must-improve

- **Phase Group A staging-area race — Step 3.7b reconciliation contract is underspecified for concurrent sub-phases:** A.2's commit (`728815b`) silently absorbed A.4's prd.md and migrate/SKILL.md changes due to concurrent staging; A.4 then reported "work already committed" and emitted no commit. The orchestrator accepted this with documentation, but Step 3.7b's strict-mode rejection would have been the correct call. Recommended fix for v3.1.1: tighten Step 3.7b to require the orchestrator to emit a named reconciliation commit (not silently absorb) whenever cross-sub-phase content lands in the wrong commit.
- **Phase B.1 → B.4 collateral damage from shared structural anchor deletion:** Phase B.4 (FR-15) deleted the "Conditional skip of re-dispatch" block in full, taking the FR-8 skip predicate that Phase B.1 had embedded inside it. Final Review iter-1 caught it only after the full piece had executed. Recommended fix: plan.md must carry an explicit "shared concern" annotation listing content blocks that no single phase may delete unilaterally; orchestrator should emit a cross-phase content-dependency warning when ≥2 phases scope the same SKILL.md block.
- **Per-phase QA Opus skip for Phases 4–9 shifted correctness load entirely onto Final Review:** Six of nine phases ran without per-phase qa-phase Opus dispatch. Final Review iter-1 returned 7 critical must-fix items — all attributable to phases B.1–D where per-phase QA was skipped. Recommended fix: per-phase QA dispatch is non-negotiable for any phase that modifies a file already touched by a prior phase in the same piece.
- **Final Review iter-1 must-fix volume (7 critical) signals too much correctness load at the end gate:** Establish a hard budget — if Final Review iter-1 returns ≥4 critical must-fix items on a piece, that piece must be flagged in the improvement backlog as having violated the "correctness-by-phase" doctrine.
- **`{{worktree_root}}/piece-<piece-slug>/` doubled path segment from token-sweep over-eagerness:** Recommended fix — add a post-token-sweep grep step that validates no path segment appears consecutively duplicated as part of Phase D's release-ceremony checklist.

#### worked-well

- **Final Review 4-reviewer board caught the FR-8 predicate deletion before merge.** Multi-reviewer board structure (blind, spec-compliance, architecture, edge-case) provided enough independent angle coverage.
- **Phase 3 QA iter-1 exhausted its 6 must-fix items in a single pass.** Demonstrates that when per-phase QA does run on a sufficiently complex phase, the single-iteration fix pattern holds.
- **Edge-case reviewer's deferred items (4 medium + 3 low) were scoped correctly to v3.1.1 backlog** rather than expanding fix-code scope at the end-of-piece gate.
- **Phase Group A parallel execution delivered real throughput** despite the staging-area race; substance of all 4 sub-phases was correct.

#### metrics

- Build duration: ~3 hours wall clock (outlier; expected ~1.5–2h for Implement-only pieces of this scope).
- Phase commits: 11 phase + 2 fix + 4 progress = 17 total.
- Final Review iter-1 critical findings: 7 (high; baseline 1–3).
- Per-phase QA skip rate: 6/9 phases = 67% (high deviation from doctrine; expected ≤20%).
- Cumulative diff: 18 files, ~315 ins / ~48 del.

### Future opportunities for pi-009-hardening

- **Phase-sizing predicate: filter HTML comments and fenced code blocks** (medium; spec amendment to plan/SKILL.md counting rule).
- **Exit-gate semantics: `exit_gate_override` escape hatch** (medium; spec amendment for legitimate documentation prose that quotes the forbidden patterns).
- **Resume-guard: session-state JSON fallback** when git log is unreliable after squash-merge / rebase (medium; piece candidate v3.1.1).
- **Deferred-finding parser: formal boundary grammar** for nested markdown cases (medium; spec amendment to qa-iteration-loop.md + Step 6a).
- **Mid-piece trigger: document N=7 odd-phase-count behavior** (low; spec amendment).
- **Phase Group N counting: clarify N=#groups vs N=#sub-phases** (low; spec amendment to Step 0a; ship with N=7 amendment).
- **Empty-marker commit + pre-commit hook interaction** (low; tied to session-state fallback above).
- **Charter-drift deep scan: extend citation validity from ID presence to heading content** (medium; piece candidate v3.2.0).
- **Proposal commit workflow: extend to plugin internals** (low; process-improvement / convention update).
- **Phase Group parallelism timing measurement** (low; v3.1.1 candidate; already in PRD-local backlog as deferred).
- **Step 3.7b reconciliation: harden from advisory to hard fail for Implement track** (HIGH; piece candidate). Implement track currently doesn't run reconciliation — Phase Group A's contamination event in this piece would have been caught if the gate covered Implement track.

---

## Synchronous discovery triage — stop silent backlog deferral

**Status:** concept — captured 2026-04-26 from operator feedback; awaiting dedicated PRD brainstorm
**Severity:** HIGH — this is a structural defect in the discovery → resolution flow, not a localized bug

### Problem

Multiple discovery moments in the pipeline silently route newly-discovered work to a backlog file without operator dialogue at discovery time:

- `execute` Step 6a writes deferred QA findings to `<docs_root>/prds/<prd-slug>/backlog.md` as stubs.
- `execute` AC matrix accepts `NOT COVERED — deferred to <pointer>` rows, which feed reflection-future-opportunities at Step 4.5.
- `reflection-future-opportunities` writes findings to the PRD-local `backlog.md` at end-of-piece.
- `reflection-process-retro` writes findings to the global `improvement-backlog.md` at end-of-piece.

In all four cases, the operator does not learn about the deferred work until the **next** session's `spec` brainstorm (Phase 1 step 6 of `skills/spec/SKILL.md`) — and even then only the ~5 most-relevant items surface. Items can sit in backlog files for multiple sessions without an explicit triage decision. The result observed in practice (2026-04-26): a downstream project shipped a piece whose plan referenced "carryover_from_phase_3" prerequisite work, which never made it into the manifest as `depends_on`-gated pieces. Subsequent pieces were freely specced and planned despite real prerequisites being undone, because:

- `spec` and `plan` skills do **not** read `depends_on:` (only `execute` enforces it — `skills/execute/SKILL.md:73`).
- `backlog.md` is purely informational; nothing parses it for gating.
- `carryover_from_phase_*` is not a manifest schema field; the pipeline ignores free-form notes in YAML.

### Operator's desired model

**Synchronous principle:** Discovered work must be resolved synchronously with discussion. It cannot be silently deferred. **The execution that found the work also fixes it** — plan amendment is inline in execute, not a separate skill.

When a discovery moment fires, the orchestrator should pause and offer the operator a triage choice:

1. **Inline plan amendment + sub-phase absorption** (default) — execute edits plan.md in-place to add phases or modify scope, dispatches `qa-plan` against the diff, commits `amend(plan): <reason>` on the worktree branch, and resumes from the affected phase. Budget: 2 amendments per piece. The work that found the gap fixes it without leaving execute.
2. **Fork to new manifest piece** — write a new piece into the manifest with `depends_on:` chains, block the current piece, halt execute. Reserved for discoveries that would change the piece's stated goals (not just its size).
3. **Explicit defer** — operator confirms "this finding does not block the current piece's goals"; invokes `/spec-flow:defer` to write a backlog entry with rationale. Only this path writes to a backlog file.

Today's pipeline implicitly takes option 3 for every discovery moment, and there is no mechanism for option 1 at all.

### Discovery moments that need triage hooks

| Moment | Currently | Should |
|---|---|---|
| `execute` start, unmet `depends_on` | Refuse or `--ignore-deps` | Offer Phase 0 absorption, fork, or explicit refusal |
| Build/QA discovers new prerequisite mid-phase | 2-attempt budget → escalate or backlog stub | Pause; offer amend / sub-phase / fork / defer |
| Verify finds AC matrix "NOT COVERED — deferred" | Accepted; flows to reflection at Step 4.5 | Block phase complete; force triage at the AC matrix gate |
| Step 4.5 reflection-future-opportunities | Always writes to backlog | Triage prompt before write — operator classifies each finding |
| Final review board flags missing scope | Becomes deferred QA finding stub | Same — triage prompt |

The reflection-future-opportunities agent already produces the right shape of finding (rationale, dependencies, candidate piece sketch). The gap is positional: its output goes to a file instead of to a triage prompt at end-of-piece.

### Design questions to resolve in PRD brainstorm

1. Does plan amendment require a full `qa-plan` re-dispatch on the diff, or a lighter-touch `qa-plan-amend` agent that only reviews changed phases?
2. What's the size threshold above which "Phase 0 absorption" is rejected and operator must fork to a new piece? Tied to phase-sizing rule (>150 LOC of behavioral prose).
3. Does the triage prompt fire mid-phase (interrupt Build) or at phase boundaries only? Mid-phase interruption breaks the Implement→Verify atomic unit; phase-boundary triage may let operator miss in-flight discoveries.
4. How do `--ignore-deps` and `--auto` interact with the new triage step? `--auto` should default to "fork to new piece" when prerequisites surface, since absorption is a scope decision.
5. Should `spec` skill also gain a `depends_on` precondition check (currently only `execute` enforces it)? Operator's preference: yes — surface unmet deps at spec time and offer Phase 0 absorption then.
6. Backlog files become **operator-only** writes (via explicit defer) rather than orchestrator writes. Migration question: do existing backlog entries need a one-time triage pass, or grandfather them?
7. How does Final Review iter-1 must-fix volume budget interact with triage? Today's "≥4 critical → flag piece" rule (from pi-009 retro) presumes deferral; the new model would force resolution before the budget gate triggers.

### Why this is HIGH severity

The current pipeline can complete a piece end-to-end with documented prerequisite work undone, and the operator has no signal until they spec the next piece. This violates the operator's mental model of "if execute completed and review-board signed off, the piece is done." The pi-009 retro entry "exit-gate semantics: 'X ran' can't downgrade to 'X is documented'" (FR-12) is a localized version of the same underlying problem — unfinished work being treated as resolved by writing it down.

### Prerequisites

None — this is orthogonal to multi-PRD and the lightweight-task PRDs above. Plan amendment is the load-bearing new mechanism; sub-phase absorption is a scoped extension to existing plan/execute.

---

## shared/pi-011-branch-fix — 2026-04-30

### Process retro for shared/pi-011-branch-fix

#### must-improve

- **Final Review circuit-breaker of 3 iterations is the wrong limit for non-TDD, no-test-harness pieces:** This piece ran 6 Final Review iterations before clean — double the informal circuit-breaker. Each of iterations 2–5 introduced *new* must-fix items rather than re-raising prior ones; fixing one edge in the rejection/rework path exposed an adjacent unchecked edge. The 3-iter limit was calibrated for TDD pieces where per-phase QA already stress-tested most paths. For doc-as-code / non-TDD pieces where Final Review is the *only* adversarial gate, the practical limit should be higher (suggest 6), but more importantly the orchestrator should detect the "each fix opens a new finding" cascade pattern and pause for operator triage rather than silently iterating. Recommended fix: add a cascade-detection heuristic — if Final Review iter N returns ≥1 must-fix item that references a code section first modified in iter N−1's fix, treat this as a scope-explosion signal and offer operator triage before dispatching iter N+1.

- **Edge-case reviewer was doing the work that per-phase QA should have caught:** The edge-case reviewer found 6 of 9 total must-fix items across iterations 2–5 (Edges A–F), all of them in rejection/rework flow logic that was authored in Phase 2. Per-phase QA for Phase 2 ran one iteration with a single fix-code dispatch and was marked clean — but it missed every multi-branch edge case. The root cause: Phase 2's per-phase QA was the only adversarial gate on the most complex logic in the piece, and it used structural grep as its primary Verify mechanism (Full mode, but grep-based). Recommended fix: for any phase whose diff introduces multi-branch control-flow (if/elif chains, rejection paths, rework re-entry) in a bash/shell/doc-as-code context, mandate that per-phase QA explicitly includes an edge-case walkthrough as part of the phase AC matrix, not just at Final Review.

- **Review board composition imbalance for doc-as-code pieces:** The blind reviewer found 0 must-fix items across all 6 iterations; spec-compliance found 1; edge-case found 6. For doc-as-code pieces (skill prose that encodes bash-level logic), "blind code smell detection" adds negligible value because prose style and naming are irrelevant. Recommended fix: for pieces where all diffs are SKILL.md / doc-as-code files, the Final Review board should substitute the blind reviewer's slot with a second edge-case reviewer pass (or a dedicated "bash-path-coverage" reviewer). This is a plan.md-level annotation: `review_board_variant: doc-as-code` to signal the substitution.

- **Specs for non-TDD doc-as-code pieces must enumerate every execution branch as an explicit AC:** The cascade of Final Review edge findings (A–F) maps to execution branches that existed in the plan's prose description but were never stated as testable ACs. Spec-compliance reviewer found only 1 must-fix because the ACs were all technically satisfied — the missing cases were branches *implied* by the logic but not written as ACs. Recommended fix: the `qa-spec` agent must apply a "branch enumeration" check for non-TDD doc-as-code pieces — every conditional in the proposed logic ("if merge strategy is X", "if rejection occurs", "if existing code is present") must have a corresponding AC entry. This is separate from functional ACs and should be in a dedicated "branch coverage" section of the spec.

- **`git checkout main` inside a worktree is a silent failure and should be a linted error:** The root defect this piece fixed — direct-main writes during pipeline execution — persisted across multiple prior pieces because `git checkout main` in a worktree produces no error and appears to succeed while leaving the worktree on the wrong branch. There is no equivalent of a lint gate today. Recommended fix: add a pre-phase shell snippet to the execute Pre-Loop that validates `git -C $worktree rev-parse --abbrev-ref HEAD` equals the expected feature branch; if it returns `main`, abort with a clear error. This should also be a static check in the `spec-flow:execute` Pre-Loop preamble, not just in the skill prose.

#### worked-well

- **No circuit-breaker hits and no escalations across all 5 phases:** Despite the Final Review cascade, every phase completed on first attempt without BLOCKED reports, contamination events, or scope violations. The plan's phase decomposition (especially isolating Phase Group A as parallel sub-phases for spec/plan SKILL.md updates) was well-scoped and clean at the boundary level.

- **Phase Group A (parallel spec + plan sub-phases) produced zero staging conflicts:** Unlike the pi-009 Phase Group A staging-area race, this piece's Phase Group A had genuinely disjoint file scope (spec/SKILL.md vs plan/SKILL.md) and ran to completion without reconciliation overhead. The scope-disjointness upfront check is working as intended.

- **Iter-1 Final Review surfaced 5 must-fix groups in a single pass before any fixes diverged:** Having 5 distinct must-fix groups identified atomically in iter-1 (before any sequential fix dispatches) meant the fix-code agent could address them in a single batch. This is the correct usage pattern — the damage from non-atomic discovery in iter-1 would have been worse if each group had been found separately.

- **All Refactor skips were correctly predicted by the auto predicate:** No refactor-ish defects appeared in QA across any phase. For doc-as-code pieces with no structural refactoring surface, the `refactor: auto` skip predicate is reliably accurate and should remain the default.

#### metrics

- Final Review iterations: 6 (outlier; baseline 1–2 for Implement-only pieces; previous high was pi-009 at ~3).
- Must-fix items by reviewer: edge-case=6, spec-compliance=1, blind=0, architecture=0, prd-alignment=2 (iter-1 only, counted in groups A+E) — edge-case reviewer contributed 67% of total findings.
- Per-phase QA iterations: Phase 2=1+fix-code, Phases 1/3/4/Group A=0 (skipped, structural-only or clean) — 80% skip rate; appropriate given structural diff scope, but Phase 2's single pass proved insufficient for multi-branch logic.
- Escalations / circuit-breaker hits: 0 (expected; consistent with prior Implement-only pieces).
- Cumulative diff: 11 files, ~1074 insertions / ~26 deletions — large insertion count for a correctness-only piece signals doc-as-code verbosity, not scope creep.
- Refactor skips: 5/5 phases (100% auto-skipped; correct for doc-as-code with no behavioral refactoring surface).

---

## Recent findings

### [Deferred via /spec-flow:defer] Phase 8 scope too dense — split at behavioral boundary not LOC — 2026-04-30

**Source:** `shared/pi-010-discovery` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** Phase 8 bundled multiple behaviors into a single Implement phase; the fix required multiple retry iterations. Regression pattern: split at behavioral subsection boundary, not LOC count. Future plans should cap each Implement phase at one behavioral region.
**Why this does not block pi-010-discovery's goals:** Process improvement for future pieces; does not affect pi-010-discovery's shipped artifacts.
**Captured:** 2026-04-30

### [Deferred via /spec-flow:defer] Cross-phase citation-consistency LLM oracle is not a named verify step type — 2026-06-07

**Source:** `exec-ready/plan-concrete` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** Phase 5 of plan-concrete ran a §2d cross-phase schema-consistency LLM oracle (definitional alignment across 4 files: reference doc + 3 citers). It was effective but one-off and undocumented as a pattern. Any future Implement-track piece where N≥3 files must stay semantically aligned (shared terminology, cross-cited criteria numbers, slot naming) should include this as a standard verify step. Without naming it, future orchestrators will either omit it or re-invent it ad hoc. Candidate action: add a named "citation-consistency oracle" verify step type to plan/SKILL.md §9 or the plan template, triggered when a phase touches ≥3 files that cross-reference each other's vocabulary.
**Why this does not block plan-concrete's goals:** Process improvement for future pieces; plan-concrete's citation contract was successfully verified by the oracle. Does not affect shipped artifacts.
**Captured:** 2026-06-07

### [Deferred via /spec-flow:defer] Disjoint consumer phases should use a Phase Group, not serial ordering — 2026-06-07

**Source:** `exec-ready/plan-concrete` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** Phases 2, 3, 4 of plan-concrete touched disjoint files (plan/SKILL.md, qa-plan.md, templates/plan.md) with only a read dependency on Phase 1's output — not a write dependency on each other. Serializing them was safe but wasted ~2/3 wall-time. A plan-authoring heuristic is needed: "if N≥2 phases each read the same completed Phase-K output but do not write to each other's files, model them as a Phase Group with Phase-K as the barrier."
**Why this does not block plan-concrete's goals:** Retroactive plan-structure observation; shipped artifacts are correct. Heuristic is for future piece authoring.
**Captured:** 2026-06-07

### [Deferred via /spec-flow:defer] Phase 9 bundled three behavioral regions — should be three phases — 2026-04-30

**Source:** `shared/pi-010-discovery` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** Phase 9 contained three distinct behavioral areas (AC matrix routing, deferred-finding surface-to-6c, and Build oracle escalations) that should have been three sequential flat phases. The plan skill should flag phases where [Implement] covers more than one AC cluster.
**Why this does not block pi-010-discovery's goals:** Process improvement for future pieces; does not affect pi-010-discovery's shipped artifacts.
**Captured:** 2026-04-30

### [Deferred via /spec-flow:defer] Step 6c not dog-food validated during this piece — 2026-04-30

**Source:** `shared/pi-010-discovery` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** This piece implemented Step 6c (discovery triage) but never actually exercised the flow during its own implementation — no discoveries surfaced during phases 1-13 that required operator triage. The execute skill should include a note that the first piece using a new triage mechanism should explicitly produce one test-case discovery to validate the flow end-to-end.
**Why this does not block pi-010-discovery's goals:** Observation; the triage flow was validated through Final Review instead. Does not affect pi-010-discovery's shipped artifacts.
**Captured:** 2026-04-30

### [Deferred via /spec-flow:defer] Final Review iter-1 >9 must-fix — add pre-filter step — 2026-04-30

**Source:** `shared/pi-010-discovery` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** Nine must-fix findings in Final Review iter-1 is unusually high. Suggestion: dispatch a lightweight Opus triage of the fix-diff after iter-1 before re-running all 5 reviewers, so that trivially incorrect fixes are caught before consuming 5 fresh reviewer dispatches.
**Why this does not block pi-010-discovery's goals:** Process improvement for future pieces; does not affect pi-010-discovery's shipped artifacts.
**Captured:** 2026-04-30

### [Deferred via /spec-flow:defer] Phase Group B.2 schema violation missed by QA-lite — 2026-04-30

**Source:** `shared/pi-010-discovery` phase `step-4.5-reflection` (agent: `reflection-process-retro`)
**Finding (verbatim):** The QA-lite reviewer for sub-phase B.2 approved a schema that used inline agent context (violating the spec's isolation rule) — the violation was caught only in the full group-level QA. The fix: attach the sibling sub-phase's agent schema to QA-lite's prompt context so the narrower reviewer can also detect cross-contamination.
**Why this does not block pi-010-discovery's goals:** Process improvement for future pieces; does not affect pi-010-discovery's shipped artifacts.
**Captured:** 2026-04-30

---

### pi-013-goal-exec process retro — 2026-05-14

#### must-improve

- **Fix-code agents fix the stated branch but miss symmetric sibling branches:** All three Final Review iterations (7→1→1 must-fix) traced to the same failure mode — fix-code applied a state-variable assignment to the fresh-arm branch but not the resume branch (`monitor_armed`). Fix-code dispatch is finding-scoped, not invariant-scoped. Mitigation: add a reminder in the fix-code agent template to check all parallel/sibling branches whenever a state variable assignment is the fix. Alternatively, add an edge-case checklist item: "every state variable assigned in one branch is assigned (or explicitly absent-by-design) in all sibling branches."

- **Dead capability-probe variables signal a broken plan→implement link:** `background_available` was defined in the Capability Probe and consumed downstream, but the plan had no explicit step to "confirm probe variable is guarded at every call site." The dead-variable failure was caught by Final Review rather than plan validation. For any capability-probe pattern, the consuming phase should explicitly require confirming that the probe variable is wired to a conditional guard with no unconditional call sites.

- **FR-8 QA-skip predicate should carve out SKILL.md with conditional orchestration logic:** FR-8 ("prose/YAML additions, no new branching control flow") bypassed Opus QA for all 4 phases. However, SKILL.md prose that says "if X then do A, else do B" expresses conditional orchestration logic equivalent to branching control flow — and the 7 iter-1 must-fix findings all stemmed from incomplete branch handling in skill prose. Recommended carve-out: FR-8 applies only when the deliverable contains NO conditional orchestration statements (if/else/resume/arm/teardown). SKILL.md edits with guard blocks should trigger per-phase Opus QA regardless of deliverable type.

#### worked-well

- **Phase Group A parallel dispatch (A.1 + A.2) ran without staging conflicts:** SKILL.md TeammateIdle prose (A.1) and 12 agent file frontmatter additions (A.2) had genuinely disjoint scopes. No reconciliation overhead, no scope-disjointness violations, no serial fallback. The "large prose edit in one file + N uniform 1-line edits across N isolated files" pattern is a strong Phase Group candidate.

- **Refactor auto-skip was correct for all 4 phases:** Prose-only and frontmatter-only deliverables presented zero refactor surface. No refactor-ish defects appeared in Final Review. The `refactor: auto` skip predicate is reliably accurate for doc-as-code pieces.

#### metrics

- Final Review iterations: 3 (circuit-breaker max; baseline 1 for prose-only pieces; all caused by single branch-symmetry failure thread).
- Must-fix by reviewer: edge-case=6+1+1 across 3 iterations; blind=6 (iter 1); prd-alignment=2 (iter 1). Edge-case reviewer contributed most findings.
- Per-phase QA skips: 4/4 phases (FR-8 predicate — correct per definition, but see must-improve above).
- Escalations / circuit-breaker hits during phases: 0.
- Cumulative diff: 20 files, 817 insertions(+), 4 deletions(-).
- Refactor skips: 4/4 (100% auto-skipped; correct).

### [RESOLVED 2026-06-10 — spec-flow 5.12.0, commit 7a6b924] Agent dispatches carry no worktree-path contract — false review verdicts — 2026-06-10

**Source:** `external/devops` phase `field-report` (agent: `operator`) — 2026-06-10 cross-repo sweep, source-verified against plugins/spec-flow @ 5.8.0
**Finding (verbatim):** BUG (HIGH): No agent template (implementer, verify, qa-phase, review-board-*) and no execute/review-board dispatch site requires an explicit `WORKTREE: <abs-path>` preamble; agents infer paths from the plan and may resolve reads against the MAIN repo. Field impact: devops logged 2 incidents — verify false-FAILed a clean phase (os-common-collection, 2026-05-01) and security+architecture board reviewers produced a false FAIL + misleading PASS by reading main-repo files during focused re-review (jenkins-collection, 2026-05-28). False gate verdicts are the worst failure class for a review system. FIX: add a dispatch-preamble rule to `reference/coordinator-contract.md` — every agent prompt begins with `WORKTREE: <absolute-path>` plus "resolve every read/write from this root"; wire it into all execute + review-board dispatch sites; add the field to each agent's input contract with a `[WORKTREE-ABSENT]` marker escalation when missing. Suggested home: "dispatch-integrity" small-change.
**Why this does not block exec-ready's goals:** No active piece in this repo is affected; plugin-level defect filed from the cross-repo sweep for scheduled pickup (operator-directed batch).
**Captured:** 2026-06-10

### [RESOLVED 2026-06-10 — spec-flow 5.12.0, commit 7a6b924] manifest.yaml ownership is implicit — agent wrote status:merged mid-execute — 2026-06-10

**Source:** `external/prop-firm` phase `field-report` (agent: `operator`) — FO-23, verified vs 5.8.0
**Finding (verbatim):** BUG (HIGH): implementer.agent.md:44 has only generic "do not modify files outside phase scope"; no agent contract names manifest.yaml as orchestrator-owned, and no lint/hook-sweep checks for it. Field impact: prop_firm commit 0640a06 set `status: merged` during a [QA] step, before Final Review — manual revert required; premature piece closure was possible. FIX: (a) explicit "manifest.yaml is orchestrator-owned; agents MUST NOT modify it" line in implementer/tdd-red/fix-code/refactor input contracts and a manifest-ownership row in coordinator-contract.md; (b) Step 6b hook sweep (or coherence linter) flags any agent-produced diff touching manifest.yaml as a blocking violation. Suggested home: "dispatch-integrity" small-change.
**Why this does not block exec-ready's goals:** Plugin-level guard gap; no in-flight piece here exhibits it.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] fix-code gets no sibling-file or call-site context — 3-repo recurrence — 2026-06-10

**Source:** `external/devops+prop-firm` phase `field-report` (agent: `operator`) — also ai-plugins pi-013 retro; verified vs 5.8.0
**Finding (verbatim):** BUG (HIGH, 3-repo recurrence — flywheel-global threshold case): fix-code.agent.md:14–30 scopes the agent to named findings only; the dispatch (execute SKILL.md ~:903) passes findings + plan context with no instruction to (a) apply an established pattern to structurally analogous files in the batch or (b) re-review call sites of changed signatures/exceptions. Field impact: devops — stat-guard applied to 1 of 4 analogous files, iter-2 created 3 unguarded files (extra board iteration); prop_firm FO-25 — iter-1 fixes introduced 2 new bugs (exception propagation at bare call site; init-order regression). FIX: orchestrator enriches every fix-code dispatch with the list of structurally analogous files modified this piece + the pattern-propagation instruction; after fix-code returns, a targeted call-site check (grep call sites of changed symbols; verify new exceptions/init-order handled) runs before any board re-dispatch. Suggested home: FR-018 qa-hardening candidate piece.
**Why this does not block exec-ready's goals:** Correctness-of-the-fix-loop defect observed in consuming repos; filed for the qa-hardening batch.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] Opus QA skip-predicate is per-phase only — cross-phase composition bugs reach Final Review — 2026-06-10

**Source:** `external/prop-firm` phase `field-report` (agent: `operator`) — FO-11/FO-20 (both CRITICAL); devops Pattern B; verified vs 5.8.0
**Finding (verbatim):** BUG (HIGH): the FR-8 skip predicate (execute SKILL.md:847–862) is pure per-phase content analysis (markdown-only / no new SKILL / no branching); the mid-piece Opus pass (Step 0a:324–326) fires only when ALL phases 1..K skipped. Nothing forces integration-scope QA when multiple phases incrementally wire the same module. Field impact: prop_firm — `_persist_breaker` clobber and HC.io env-var bug each emerged from 3-phase interaction, survived per-phase QA (4 of 6 Opus dispatches skipped), caught only at Final Review; devops — 3 cross-role consistency gaps with the same shape. FIX: add a composition trigger — when ≥3 completed phases touch a common module AND ≥2 of their QA gates skipped, force one integration-scope Opus qa-phase at the next phase boundary whose input is the union diff of those phases. Suggested home: FR-018 qa-hardening (predicate change), with an async/integration fixture class in gate-evals (FR-017) to measure it.
**Why this does not block exec-ready's goals:** Predicate logic gap; no current piece in this repo is multi-phase-wiring right now.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] Execute has no pre-flight test-suite baseline — inherited failures misattributed — 2026-06-10

**Source:** `external/prop-firm` phase `field-report` (agent: `operator`) — FO-14, escalated CRITICAL on recurrence; verified vs 5.8.0
**Finding (verbatim):** BUG (HIGH): Step 1b pre-flight (execute SKILL.md:430–453) captures LOC/schema/symbols/hooks but never runs the test suite; Verify treats inherited pre-existing failures as phase failures. Field impact: prop_firm triaged 5 pre-existing failures mid-execute (obs-http-wiring), misattributing cost to the piece; same ordering-sensitive test recurred in prereqs-phase-3-5. FIX: Step 1b optionally runs the project suite once before Phase 1, records the failing-test set to the pre-flight snapshot/journal; per-phase Verify filters baseline failures and reports them separately as `[INHERITED-FAILURE: <test-id>]` (triage-visible, never piece-attributed); skipped gracefully when no suite exists. Suggested home: fold into exec-guardrails (FR-011) spec brainstorm — it is execute pre-flight hardening.
**Why this does not block exec-ready's goals:** Pre-flight gap surfaced downstream; exec-guardrails is open and unstarted, so the fold-in costs nothing now.
**Captured:** 2026-06-10

### [RESOLVED 2026-06-10 — spec-flow 5.12.0, commit 7a6b924] Step 5.5 re-run after failed merge is advisory prose, not a Step 6 precondition — 2026-06-10

**Source:** `external/devops` phase `field-report` (agent: `operator`) — PR #223 stranded manifest commit; verified vs 5.8.0
**Finding (verbatim):** BUG (MEDIUM): execute SKILL.md:1898–1920 orders Step 5.5 (manifest `status: merged` commit) before Step 6, but the re-run-5.5-before-retry rule lives nested in the Failure-path prose; a retried Step 6 (or an operator pushing after a revert) can merge without the manifest commit on the branch. Field impact: devops PR #223 merged with `status: in-progress`; the merged-status commit landed after the PR merge, orphaned on the piece branch. FIX: make "HEAD contains the Step 5.5 manifest commit" an explicit, checked precondition of Step 6 (both merge strategies and every retry path), and add it to the push-ready/PR-open checklist line emitted to the operator. Suggested home: "dispatch-integrity" small-change.
**Why this does not block exec-ready's goals:** Ordering-robustness gap; current pieces here merge via the standard path that usually satisfies it.
**Captured:** 2026-06-10

### [RESOLVED 2026-06-10 — spec-flow 5.12.0, commit 7a6b924] Implementer output truncation on long verify gates is undetectable — 2026-06-10

**Source:** `external/prop-firm` phase `field-report` (agent: `operator`) — FO-16; verified vs 5.8.0
**Finding (verbatim):** BUG (MEDIUM): implementer.agent.md and execute Step 3 (:533–591) have no heartbeat marker, truncation detection, or resume protocol around long-running gate commands (~8-min mypy/test runs). Field impact: 2 implementer dispatches truncated mid-gate; the orchestrator manually staged+committed, silently bypassing the implementer's self-review checklist. FIX: implementer stages work and emits a `READY-TO-COMMIT` marker (self-review complete) BEFORE invoking long gates; the orchestrator treats truncated output lacking the marker as a resumable failure and re-dispatches with prior context — manual-commit bypass is prohibited. Suggested home: "dispatch-integrity" small-change.
**Why this does not block exec-ready's goals:** Robustness gap that fires on long gates; this repo's doc-as-code gates are short.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] qa-phase-lite has no async-lifecycle checks and no routing carve-out — 2026-06-10

**Source:** `external/prop-firm` phase `field-report` (agent: `operator`) — FO-24 (9 async must-fix at board); verified vs 5.8.0
**Finding (verbatim):** GAP (MEDIUM): qa-phase-lite.md:39–46 review focus has no async/state-machine items (lifecycle sequencing, guard positioning, exception-safety ordering) and nothing routes async-heavy diffs to the Opus tier. Field impact: group QA passed Phase Group A; Opus board found 9 async must-fix findings in iter-1. FIX: (a) add async-lifecycle spot-checks to qa-phase-lite's focus list; (b) add a skip/route carve-out — diffs introducing or modifying async lifecycle code route to full Opus qa-phase regardless of group QA-lite; (c) add an async fixture class to gate-evals (FR-017) so the Sonnet-vs-Opus catch-rate gap is measured, per FR-016's no-downgrade-without-evidence rule. Suggested home: FR-018 qa-hardening + gate-evals fixture.
**Why this does not block exec-ready's goals:** This repo's pieces are doc-as-code (no async surface); defect is real for code-bearing consumers.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] No disputed-finding routing — DISMISS requires no disk verification — 2026-06-10

**Source:** `external/devops` phase `field-report` (agent: `operator`) — security-reviewer hallucination; verified vs 5.8.0
**Finding (verbatim):** GAP (MEDIUM): Final Review triage (execute SKILL.md:1736–1759) lets the operator DISMISS a finding with no verification step, and no orchestrator logic flags contradictions between reviewers or between a finding and disk state. Field impact: devops security reviewer asserted files didn't exist / were unchanged — disk said otherwise; the operator had to manually `find`+`cat` before dismissing. FIX: when a finding asserts checkable file/disk state, the orchestrator runs the one-line disk check at triage time and attaches the result to the finding card; a `disputed` flag is set when reviewers contradict each other or disk evidence, and DISMISS on a disputed finding requires the attached evidence in the triage record. Suggested home: FR-018 qa-hardening.
**Why this does not block exec-ready's goals:** Triage-quality gap; operator currently compensates manually.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] Intra-piece QA deferral recurrence is not escalated — 2026-06-10

**Source:** `external/prop-firm` phase `field-report` (agent: `operator`) — FO-4 (predates sync-triage but the recurrence rule is still absent); verified vs 5.8.0
**Finding (verbatim):** GAP (MEDIUM-LOW): Step 6a dedup (execute SKILL.md:919) matches duplicate backlog stubs within a session to avoid double-writing — but a finding deferred in an earlier QA pass that resurfaces in a later pass of the SAME piece gets re-triaged as a fresh discovery with no recurrence signal. The flywheel (5.8.0) counts cross-piece patterns only. Field impact: prop_firm had two findings each survive two QA passes as deferrals (clock bug; hardcoded verdict='pass'). FIX: on Step 6a dedup match, instead of silently skipping the stub, surface a recurrence escalation at triage — "this finding was previously deferred in this piece (phase N); recurrence suggests it blocks after all — recommend promote to must-fix." Suggested home: FR-018 qa-hardening (small predicate addition).
**Why this does not block exec-ready's goals:** Sync-triage already prevents silent deferral; this adds the recurrence teeth.
**Captured:** 2026-06-10

### [Deferred via /spec-flow:defer] Blind reviewer gets zero domain hint — idiom false positives — 2026-06-10

**Source:** `external/devops` phase `field-report` (agent: `operator`) — Ansible idiom false positives; verified vs 5.8.0
**Finding (verbatim):** IMPROVEMENT (LOW): review-board-blind.agent.md:8–10 is diff-only by design — but with zero domain context it flagged mandated Ansible idioms (`changed_when: false` per the repo's CR-030; valid `cacheable: true`) as logic errors / malformed YAML, adding dismissal noise. FIX: permit exactly one line of tech-stack context in the blind input contract — language/framework name only, never spec/PRD/plan content (e.g. "Diff is Ansible YAML; treat idiomatic task constructs as correct unless clearly erroneous") — preserving blindness to intent while removing idiom noise. Complements the FR-012/FR-016 doc-as-code board variant. Suggested home: FR-018 qa-hardening or fold into gate-scaling's board-variant work.
**Why this does not block exec-ready's goals:** Noise-reduction; the reviewer still functions, at extra operator dismissal cost.
**Captured:** 2026-06-10

---

## Process retro — exec-ready/spike-agent (5.7.0, 2026-06-07)

**Source:** end-of-piece reflection, 8 phases, non-TDD Implement track.
**Cumulative diff:** 12 files, 335 insertions(+), 76 deletions(-).

**must-improve: Sub-section anti-drift greps for multi-spec, same-file phases.** Phase 7 targeted `execute/SKILL.md` across 3 change specs (T-1 placement, T-2 budget, T-3 log ref). The implementer correctly rewrote the `**Soft-checkpoint prompt.**` section but left the immediately-prior `**Pre-dispatch budget check.**` step 1 with residual hard-refusal language ("refuse the dispatch / Do NOT dispatch"). The `[Verify]` anti-drift sweep checked for two specific superseded strings (`"no further amendments allowed"`, `"spec-amend budget exhausted"`) but did not include `"refuse the dispatch"` as a third superseded string. Result: 2 MUST-FIX caught at QA time. Fix candidate: when a phase has ≥3 change specs all targeting the same large file, the plan's `[Verify]` anti-drift sweep should enumerate all sub-sections that carry semantically linked language (not just the directly-edited anchor) and include a grep for each superseded sub-section string. The plan author (Opus) should derive these from the change spec's `Current:` fields.

**must-improve: MUST-FIX and SHOULD-FIX QA corrections should produce separate fix commits.** Phase 7 QA produced 2 MUST-FIX + 2 SHOULD-FIX items, all resolved in a single `fix(spike-agent): Phase 7 QA — ...` commit. Bundling MUST-FIX and SHOULD-FIX into one commit obscures severity tiers and complicates bisect. Fix candidate: the execute `fix-code` guidance (or QA-phase output format) should distinguish severity and indicate that MUST-FIX items should be committed before SHOULD-FIX items, producing separate commits when there are both tiers.

**worked-well: Inside-out build order (contract first, consumers second).** All 8 phases completed on first dispatch with no BLOCKED dispatches. Phases 2–7 all cited `reference/spike-agent.md` rather than restating vocabulary. The Phase 1 define-once/cite-everywhere constraint was honored throughout. Pattern worth repeating for any piece introducing a shared vocabulary (classification names, artifact schemas) before wiring consumers.

**worked-well: Cross-phase schema-consistency grep in [Verify].** Phase 7's `for f in` grep confirming `blocking-on-current` appears in all three vocabulary-bearing files served as a regression guard (no defect at verify time) rather than a defect finder. The QA catch on the `Classification:` schema colon-arg mismatch was found by the QA agent reading the schema directly, not the grep — showing that greps are a necessary but not sufficient consistency check. Both layers (structural grep + Opus semantic review) are needed.

**metrics:** QA catch rate — Phase 1: 1 MUST-FIX; Phases 2/3: 0; Phase 4: 1 SHOULD-FIX; Phase 5: 1 SHOULD-FIX; Phase 6: 1 non-issue; Phase 7: 2 MUST-FIX + 2 SHOULD-FIX; Phase 8: 0. Total: 3 MUST-FIX, 3 SHOULD-FIX across 8 phases. Phase 7 (57% of all actionable findings) concentrated defects because it was the third serial phase targeting the same large file — compound target, accumulated complexity.

---

### Process-retro findings (exec-ready/flywheel-repo, 2026-06-09)

**Source:** `exec-ready/flywheel-repo` phase `step-4.5-reflection` (agent: `reflection-process-retro`). Deferred via operator triage 2026-06-09. Category: process-improvement.

**PR-FW-1: spec/plan QA should require "record-this-outcome" behaviors to enumerate their schema field.** The `hardenings` schema gap (board findings F1/F3/F5: no schema home for the accepted/blocked hardening outcome → broken spike `<id>` seam + infinite re-proposal loops) reached Final Review rather than being caught at spec or plan QA. Root: spec SF-6 said "the accepted outcome … is recorded against the pattern in docs/patterns.yaml" but named no concrete schema field and no re-proposal exclusion rule. **Fix:** add a qa-spec/qa-plan check — any AC/FR describing a "record/persist this outcome" behavior must enumerate the schema field(s) carrying it, and the plan's cross-phase schema-consistency [Verify] must confirm every outcome state (approved/rejected/blocked) has a dedicated schema home before the wiring phase ships.

**PR-FW-2: qa-spec should grep `.gitignore` for config-file ACs.** The Phase 2 discovery (`.spec-flow.yaml` gitignored; AC-10 "documented in both files" mis-modeled the committed deliverable) fired at implementation time, costing one spec-amend + one plan-amend before Phase 2 completed. **Fix:** qa-spec for any AC referencing a config file should run a one-line `grep <file> .gitignore` and flag committed-vs-runtime mismatches before sign-off.

**PR-FW-3: plan concreteness — require a grep-verifiable assertion per concrete identifier shipping a new dispatch contract.** Board F1 (broken spike `<id>` seam) occurred because the plan DID specify `<id> = flywheel-<pattern-id>` but the implementer didn't carry it through, and Phase 4's `[Verify]` for that branch was an LLM-agent-step ("confirm both branches present"), not grep-verifiable on the concrete token. **Fix:** when a phase ships a new dispatch contract / concrete identifier, require at least one grep-verifiable `[Verify]` assertion keying on that literal token (e.g. `grep 'flywheel-<pattern-id>'`), not only LLM-agent-step presence checks.

**observation (NN-P-005):** the execute coordinator ran on Opus via operator override of the Sonnet-class pre-flight check. No observable effect on this doc-as-code piece, but the override is an NN-P-005 deviation worth tagging — consider requiring an explicit rationale field in the session log when the pre-flight model check is overridden, for cross-piece comparison.

**Captured:** 2026-06-09

## Process retro from exec-guardrails (2026-06-10)

**PR-EG-1: Plan `[Write-Tests]` must specify ERE syntax when targeting `assert_grep`.** The exec-guardrails piece introduced a `\|` vs `|` ERE alternation bug in 14 `assert_grep` call sites (Phases 2-7), caught only at Final Review. Root cause: plan `[Write-Tests]` task descriptions used BRE syntax (`\|`) copied from adjacent `[Verify]` grep shell commands, and the implementer carried it across the boundary. `assert_grep` uses `grep -E` (ERE), where `|` is alternation and `\|` is a literal two-character string. **Fix:** whenever a plan `[Write-Tests]` task writes calls to `assert_grep`, include an explicit note that alternation uses `|` (not `\|`), and use `|` verbatim in any pattern examples in the task description.

**PR-EG-2: `[Verify]` for phases writing to the e2e test harness must include `run-e2e.sh` execution.** The exec-guardrails `tests/e2e/run-e2e.sh` harness existed throughout the piece but was never invoked in any `[Verify]` step — only file contents were inspected via LLM-agent steps. The 14-occurrence ERE bug survived five phases because no runtime validation fired. **Fix:** for any phase whose `[Write-Tests]` output lands in `tests/e2e/lib/static.sh` or `tests/e2e/lib/contract.sh`, the `[Verify]` step must include a literal `bash plugins/spec-flow/tests/e2e/run-e2e.sh` command (or an equivalent scoped invocation). LLM-agent-step inspection of test file contents does not substitute for harness execution.

**Captured:** 2026-06-10

---

### Process-retro findings (exec-ready/flywheel-refresh, 2026-06-11)

**Source:** `exec-ready/flywheel-refresh` phase `step-4.5-reflection` (agent: `reflection-process-retro`). Deferred via operator triage 2026-06-11. Category: process-improvement.

**FR-1: Citation-norm for plan template — doc-as-code wiring phases must verify section headings verbatim.** The Phase 4 must-fix (commit 64f3fe1) was a citation-truncation defect: the plan's T-1 prose named `## Match + confirm flow` but the actual section heading in `flywheel.md` is `## Match + confirm flow (no silent write)`. The implementer faithfully reproduced the truncated string from the plan. Root cause: the plan author didn't read the target file to verify the heading verbatim before writing the T-step. **Fix:** add a doc-as-code citation norm to the plan template — any `[Implement]` T-step citing a section heading must include a note: "read the target file first and verify this heading verbatim before authoring the citation." This applies to all citation-only wiring phases (common in doc-as-code SSOT+caller-cites patterns). Candidate: add to `plugins/spec-flow/reference/plan-quality.md` (or equivalent) as a named norm, and to the qa-plan rubric.

**FR-2: qa-plan verbatim-heading cross-check for citation-only phases.** qa-plan focuses on AC coverage and phase-boundary ambiguity but does not verify that section headings cited in `[Implement]` T-steps exist verbatim in the referenced SSOT files. For citation-only doc-as-code phases this is a cheap structural check (grep the target file for the exact heading string). The Phase 4 `[Verify]` cross-phase oracle DID catch the defect — but only after the implementer committed the wrong string. Moving the check to qa-plan (pre-execute) would eliminate the extra QA iteration. **Fix:** add a qa-plan heuristic — for `[Implement]` T-steps that contain a `see <file> ## <Heading>` pattern, grep the target file and flag any heading that does not appear verbatim as a must-fix.

**Captured:** 2026-06-11
