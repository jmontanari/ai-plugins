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
