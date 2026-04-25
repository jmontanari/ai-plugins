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

## Sharpen Opus QA skip-predicate — LOC heuristic mis-targets behavioral risk

**Status:** v3.1.0 candidate (high severity)
**Captured:** 2026-04-25 (PI-008 reflection — process retro)

### Problem

Today's skip-predicate skips Opus QA when the phase diff is "small or structural / mechanical / N-LOC change." On PI-008, all 7 flat phases auto-skipped — but Phase 2 (a 14-LOC SessionStart hook with real bash logic) and Phase 4 (a 275-LOC migrate skill with `git mv` orchestration) produced ~80% of the Final Review fix-up footprint. LOC correlates poorly with risk; control-flow density does. Phase 6's 3-line version bump was clearly skip-correct; Phase 2's 14-LOC bash regex clearly wasn't.

### Proposed direction

Skip Opus only when the phase is *additive markdown/YAML or pure config*. Any phase touching shell logic, branching control flow, or shipping a new skill body defaults to Opus QA regardless of LOC. Bash hooks count as control-flow.

### Design questions to resolve

- Where does the predicate live — execute SKILL.md text, or hard-coded in the orchestrator's QA dispatch step?
- Does this raise total Opus dispatch volume meaningfully, or is the previously-skipped set mostly markdown anyway?

---

## Mid-piece Opus QA pass for long pieces (≥6 phases)

**Status:** v3.1.0 candidate (high severity)
**Captured:** 2026-04-25 (PI-008 reflection — process retro)

### Problem

Per-phase Sonnet QA-lite reviewers see only their own file's diff. Integration-level ambiguities (e.g., a hook regex inconsistent with a manifest example written 3 phases earlier) are structurally invisible until Final Review — where fix-up is expensive and review-board reviewers are rate-limited. PI-008's Final Review surfaced 11 must-fix items that per-phase QA missed.

### Proposed direction

For pieces with ≥6 phases that all skip Opus, insert one mid-piece Opus pass at the half-way commit. The reviewer reads the cumulative diff against the spec, not just one phase's diff. Estimated to eliminate ~60% of Final Review fix-up volume by catching cross-phase divergence at half-time.

### Design questions to resolve

- How is "half-way" defined — phase count, commit count, or LOC?
- Does the mid-piece reviewer block, or surface as advisory like the deferred-finding flow?
- Pairs naturally with the skip-predicate change above — same execute SKILL section, likely one piece.

---

## Orchestrator captures "deferred to reflection" findings at deferral time

**Status:** v3.1.0 candidate (high severity)
**Captured:** 2026-04-25 (PI-008 reflection — process retro)

### Problem

When a QA gate produces a "deferred to reflection" finding (PI-008 Group A's FR-005 branch-design ambiguity), the deferral exists only in commit-message free-text. Final Review's PRD-alignment + spec-compliance reviewers don't see it as a tracked item, deferred findings can fall off the radar, and reflection agents have to re-extract them from history.

### Proposed direction

At deferral time, the orchestrator appends a stub item to the PRD-local backlog. Reflection agents see it as input rather than re-discovering it. End-of-piece reflection promotes (to a follow-on piece) or closes it.

### Design questions to resolve

- Stub format — link to commit + deferring reviewer + verbatim finding text? Single line vs. structured block matching the existing PRD-local backlog template?
- Who writes — the QA agent itself, or the orchestrator after receiving the agent's report?

---

## Phase sizing rule — split when single phase exceeds ~150 LOC of new behavioral prose

**Status:** v3.1.0 candidate (medium severity)
**Captured:** 2026-04-25 (PI-008 reflection — process retro)

### Problem

PI-008 Phase 4 (the migrate skill, 370 LOC NEW) was the largest non-group commit and accumulated the largest Final Review correction (109 added lines, 30% of original). Behaviorally it had 8 sub-procedures, 2 flags, 3 detection branches, 3 safety checks, and a notes-format spec — each a candidate sub-phase. The plan flattened it to one Implementer dispatch with one verify pass.

### Proposed direction

Plan-skill rule: when a single phase's deliverable exceeds ~150 LOC of new behavioral prose, split into a Phase Group. Each sub-phase gets independent verification.

---

## Phase exit-gate semantics: "X ran" cannot downgrade to "X is documented to run later"

**Status:** v3.1.0 candidate (medium severity)
**Captured:** 2026-04-25 (PI-008 reflection — process retro)

### Problem

PI-008 Phase 7's exit gate originally read "the migrate skill ran successfully against a clean clone" — but in practice the skill never ran. AC-15 was marked covered while only documented-to-run-later. Final Review's spec-compliance reviewer didn't flag this because the deliverable file existed.

### Proposed direction

Plan-skill rule: when a phase's exit gate is "X ran successfully," the plan must not be allowed to swap that for "X is documented to run later." If pre-merge execution truly isn't possible, split the piece (PI-008 → PI-008a + PI-008b).

---

## Standardize Python-based YAML/JSON validation in [Verify] commands

**Status:** v3.1.0 candidate (medium severity)
**Captured:** 2026-04-25 (PI-008 reflection — process retro)

### Problem

PI-008 hit `yq` absent (Phase 1, substituted python3 + PyYAML which then rejected `{{date}}` template placeholders) and `jq` absent (Phase 6, substituted python3 + json.load). Both substitutions worked but were improvised mid-flight, and the plan's [Verify] commands never updated even after Phase 1's lesson.

### Proposed direction

Plan templates default to `python3 -c` for YAML/JSON validation in [Verify] commands. spec-flow itself is markdown+config-only (NN-C-002 forbids new runtime deps), so no reason to depend on `yq`/`jq` in pipeline self-checks.
