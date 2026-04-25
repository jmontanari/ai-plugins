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
