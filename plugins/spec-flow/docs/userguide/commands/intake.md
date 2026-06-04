# /spec-flow:intake

Session-start triage. Classifies incoming work, sets the working directory, loads charter constraints, and routes you to the right pipeline skill.

## What it does

Intake is the front door. Before any file read, any edit, any pipeline command, it answers four questions:

- **What kind of work is this?** (`plan-scoped`, `pipeline-entry`, `hotfix`, `charter`, or `exploratory`)
- **Where does it belong?** (which PRD, which piece, which branch/worktree)
- **What's the right working directory?** (so grep/glob/edit resolve from the correct branch)
- **Which charter constraints apply?** (loads the binding non-negotiables and coding rules for this work type)

It ends by recommending the next pipeline command — and stops. It never auto-invokes the target skill, so you always get a chance to correct the classification.

## When to run it

**Run this first, every session.** Intake is mandatory whenever a session starts without an explicit, fully-qualified pipeline command:

- The user describes work in prose: "fix this test", "update X", "why is CI failing", "help me with Y".
- A bare "continue execute" — still ambiguous, still needs intake.
- Any time the type or scope of the work is unclear.

Skip it only when the message already carries full context, e.g. `/spec-flow:execute ansible-platform/vault-layer`.

## The flow

1. **Load config** — reads `.spec-flow.yaml` for `docs_root`, `worktrees_root`, and `layout_version` (defaults: `docs`, `worktrees`, `3`).
2. **Load pipeline state** — invokes the `status` skill to learn the active PRDs, in-progress pieces (with worktrees), and ready-to-advance pieces. This state powers the question tree, so you pick from offered choices instead of typing names from memory.
3. **Pending Jira transitions** (silent, non-blocking) — surfaces any `merged` piece whose Jira task is still `In Review` and offers to mark it `Done`. Skipped entirely when the Jira tool is unavailable or nothing is pending.
4. **Auto-classify** — checks the message for unambiguous signals (names the active piece, references a spec path, says "status", "hotfix", "explore", etc.). A clear signal short-circuits the questions. Small-change keywords ("fix", "bug", "quick", "tweak", "patch", "one-off"…) are recorded but never auto-route — you choose explicitly.
5. **Question tree** — one question at a time, stopping at the first definitive classification: active-piece check → PRD scope → piece scope → standalone type → (hotfix only) branch strategy and tracking.
6. **Build work_context** — writes the classification (type, prd, piece, stage, branch, worktree, cwd, charter scope, tracking) to session state.
7. **Set up session context** — `cd`s into the correct worktree if needed, loads the charter constraints for the work type, and (for plan-scoped work) skims the active spec/plan to surface the current ACs and phase.
8. **Route** — prints a single next-action recommendation and waits for you.

## Loops

None. Intake asks the minimum number of questions to classify, then exits with a recommendation. No QA cycle, no iteration.

## What you get

- A `work_context` record in session state with the resolved type, PRD/piece, pipeline stage, branch, worktree, and CWD.
- The correct working directory set — with a prominent `⚡ SESSION SETUP REQUIRED` block when a `cd` into a worktree is required.
- The charter constraints for this work type loaded into context. Under `layout_version: 4`, the relevant `charter-*` skills are invoked by tier; under v3, a compact NN/CR digest is emitted.
- For plan-scoped work: the active AC list and current phase, ready to resume.
- A clear next-action recommendation. No files are modified beyond the session-state write.

## Handoff

Whatever the route line says — one of:

- `Resume /spec-flow:execute <prd>/<piece>` (plan-scoped, mid-flight)
- `/spec-flow:prd` (new domain, full pipeline)
- `/spec-flow:spec <prd>/<piece>` (open piece)
- `/spec-flow:plan <prd>/<piece>` (specced piece)
- `/spec-flow:execute <prd>/<piece>` (planned piece)
- `/spec-flow:small-change <slug>` (you chose the focused track on a new-domain change)
- "Work directly" (hotfix — branch ready, constraints active)
- `/spec-flow:charter --update` (charter/docs work)

## Worked example

You open a session and type: *"the export endpoint is returning 500s, can you look?"*

```
Loading pipeline state... 1 active PRD (my-product, 12 pieces, 1 in-progress).

Q1 — Is this work part of your active piece my-product/PI-012-user-export?
> No

Q2 — Which of these best describes where this work belongs?
> Not a PRD-level change

Q4 — What best describes this work?
> Hotfix / regression / CI failure

Q5 — Which branch should this work target?
> New hotfix branch off main

Q6 — Should this work be tracked?
> Create a Jira ticket

Charter constraints active (Tier 1): NN-C-001..006, CR-001..009.

Branch hotfix/export-500 ready. Work directly — charter constraints are active.
```

You confirm, and start debugging on the hotfix branch with the right constraints already loaded.

## Where to go next

- [Pipeline concepts](../concepts/pipeline.md) — where each routed stage sits in the chain.
- [/spec-flow:status](./status.md) — the pure-query dashboard intake builds on.
- [Charter system](../concepts/charter-system.md) — what the loaded NN/CR constraints mean.
