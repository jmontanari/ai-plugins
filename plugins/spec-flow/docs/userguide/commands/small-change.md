# /spec-flow:small-change

One-session track for a small, focused change that doesn't warrant a full PRD. Brainstorm → change brief + inline plan → worktree → hand off to execute.

## What it does

The full pipeline (charter → prd → spec → plan → execute) is the right tool for a feature. It's overkill for a one-line bug fix or a config tweak. `small-change` collapses the design stages into a single session for bounded work:

- A **coverage-based brainstorm** — just enough questions to draft the brief, no theater.
- A **change brief** (`brief.md`) and an **inline plan** (`plan.md`) under `docs/changes/<slug>/`.
- A **worktree** on a `change/<slug>` branch.
- A **handoff** to `/spec-flow:execute change/<slug>` — run as a separate session.

It writes nothing to a manifest and creates no PRD. It is designed to converge in one sitting; if scope grows, it pushes you toward the full pipeline.

## When to run it

- Triggers: "small feature", "quick fix", "minor change", "one-off", "tweak", "patch", "small bug fix".
- When intake's scale check offers the focused track and you pick it.
- When `/spec-flow:review-board --fix` routes its findings here for disciplined remediation.

If the work is genuinely PRD-sized, use `/spec-flow:prd` instead — and the skill's scope gate will nudge you there if it detects that.

## The flow

1. **Load config** — `docs_root`, `worktrees_root`, charter context, and the Jira capability check.
2. **Slug guard** — validates `<slug>` (lowercase, hyphens, ≤20 chars), and checks for an existing `change/<slug>` branch or `docs/changes/<slug>/`. An existing branch routes to the resume path.
3. **Resume warning** — if a brief already exists from a prior session, a non-suppressible warning fires (planning is meant to be one sitting; consider converting to a PRD if scope grew).
4. **Jira gate** — when issue tracking is enabled, prompts for an existing key or `new`. A `new` issue is created later, after the problem statement is approved.
5. **Charter + convention scan** — validates the charter snapshot and runs an L-10 scan of 2–3 peer components so the brief reflects real codebase conventions.
6. **Focused brainstorm** — coverage-based questions to make the four brief sections draftable (problem statement, functional requirements, acceptance criteria, out-of-scope), plus the always-run C-2 security and C-3 floor checks. A review-board findings digest is treated as authoritative requirements, not a blank-slate topic.
7. **Charter constraint identification** — infers the applicable NN/CR set with rationale.
8. **Brief sign-off** — presents the assembled `brief.md` draft for your approval before any write.
9. **Inline plan** — generates `plan.md` (1–4 phases), recommends TDD or Implement per phase, and lets you override before writing.
10. **Deferred-item disposition** — surfaces any out-of-scope items, each with one disposition (address now / defer to backlog via `/spec-flow:defer` / Jira ticket / drop).
11. **Worktree creation** — creates `<worktrees_root>/<slug>` on `change/<slug>`.
12. **Write artifacts** — writes and commits `brief.md` + `plan.md` on the worktree branch.
13. **Route to execute** — prints the handoff command.

## Loops

None — no QA fix-and-re-review cycle. The discipline comes downstream: when you run `/spec-flow:execute change/<slug>`, the change passes through the per-phase TDD/QA gates and the change-track review board before it can merge.

## The scope gate

This is the safety valve. Before any artifact is written, if the brainstorm implies **4+ implementation phases or multiple independent subsystems**, the skill stops and asks: continue as a small change, or switch to the full pipeline? If you stop, nothing is created — no brief, no plan, no worktree, no Jira issue. The gate re-fires if later steps expand the planned work (e.g. 5+ phases emerge while drafting `plan.md`).

## What you get

- `docs/changes/<slug>/brief.md` — problem statement, functional requirements, acceptance criteria, out-of-scope list, the honored NN/CR set, and (if applicable) a `## Source` provenance line, `## Jira Context`, or `## Scope Gate Override` section.
- `docs/changes/<slug>/plan.md` — a 1–4 phase plan with per-phase track selections, same structure the full pipeline's `plan` produces.
- A `change/<slug>` worktree, both artifacts committed (`small-change(<slug>): add brief and plan`).

## Handoff

The skill prints exactly:

```
Brief and plan ready. Run: /spec-flow:execute change/<slug>
```

Execute is a separate operator-started session — `small-change` never invokes it directly.

## Worked example

You run `/spec-flow:small-change fix-login-timeout`:

```
Slug 'fix-login-timeout' valid. No existing change/ branch.
Jira: existing issue? > EIT-4821  (loaded summary + AC)

Brainstorm (4 questions):
  - What's the current timeout vs. desired?   30s → 120s
  - Configurable or hard-coded?                config (auth.session_ttl)
  - Any downstream that assumes 30s?           no
  - C-2 security: does extending TTL widen a window?  reviewed — acceptable

Scope check: 1 subsystem, ~2 phases. Within small-change bounds.

Brief draft presented... approved.

Plan (2 phases):
  Phase 1 (TDD)       — config read + clamp to [30s, 300s]
  Phase 2 (Implement) — wire auth middleware to new TTL

Worktree created: worktrees/fix-login-timeout (change/fix-login-timeout)
Committed brief.md + plan.md.

Brief and plan ready. Run: /spec-flow:execute change/fix-login-timeout
```

You open a fresh session and run the execute command.

## Where to go next

- [/spec-flow:execute](./execute.md) — where the change is built, QA-gated, and board-reviewed.
- [/spec-flow:review-board](./review-board.md) — its `--fix` flow routes findings here.
- [/spec-flow:prd](./prd.md) — the full pipeline, for work the scope gate flags as too big.
