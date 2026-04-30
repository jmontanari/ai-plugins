---
name: intake
description: >
  Work intake and triage for spec-flow projects. Invoke this skill at the start
  of every work session before any file operations or pipeline commands — even
  when the user seems to know what they want. Classifies incoming work through
  a short decision tree, sets up the correct working directory, loads charter
  constraints, and routes to the right pipeline skill. Handles all work types:
  resuming an active piece, entering the pipeline at the right stage (spec/plan/execute),
  hotfixes, regressions, CI failures, charter updates, and exploratory investigation.
  Use this whenever a session starts without an explicit pipeline command, whenever
  a user says "fix this", "update X", "help with Y", or any time the type or scope
  of work is unclear. Do not skip intake even if the user's intent seems obvious —
  it ensures CWD, charter constraints, and branch context are correct before any
  work begins.
---

# Work Intake

Classify incoming work, establish session context, and route to the right place.
Run before any file operations, pipeline skill invocations, or code changes.

## When to invoke

- **Always** at session start when the user describes work to do
- Any message that implies work without naming an explicit pipeline command
- "Fix this test", "update X", "why is CI failing", "help me with Y"

Skip only when the user uses an explicit, fully-qualified pipeline command:
`/spec-flow:execute ansible-platform/vault-layer` already carries full context.
A bare "continue execute" is still ambiguous — run intake.

---

## Step 0: Load config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/`
and `worktrees_root` in place of `worktrees/` throughout. If absent, default to
`docs` and `worktrees`.

---

## Step 1: Load pipeline state

Invoke the `status` skill to discover:
- Active PRDs and their piece counts by status
- Pieces currently `in-progress` (these have active worktrees)
- Pieces that are `planned` or `specced` (ready to advance)
- Any active git worktrees (`git worktree list`)

Hold this state — the question tree uses it to offer specific choices rather
than forcing the user to type names from memory.

---

## Step 2: Attempt auto-classification

Check the user's message for unambiguous signals before asking any questions.

| Signal | Classification |
|---|---|
| Names the active `in-progress` piece or its branch explicitly | `plan-scoped` — skip to Step 4 |
| References a spec file path, plan phase number, or piece AC | `plan-scoped` — skip to Step 4 |
| "status", "where are we", "what's next", "pipeline status" | Informational — run status and stop; no intake needed |
| "hotfix", "regression", "CI failure" with no plan reference | `hotfix` — skip to Q4 |
| "explore", "look at", "investigate", "understand" (no changes implied) | `exploratory` — skip to Step 4 |

If no signal is clear, proceed to the question tree.

---

## Step 3: Question tree

Use `ask_user` with structured choices. Ask one question at a time.
Stop at the first question that yields a definitive classification — never
ask a question whose answer is already determined by a previous answer.

### Q1 — Active piece check
*(Only ask if at least one piece is currently `in-progress`)*

> "Is this work part of your active piece **[prd/piece-name]**?"

- **Yes** → `type: plan-scoped`, piece = active piece → skip to Step 4
- **No** → Q2

### Q2 — PRD scope

> "Which of these best describes where this work belongs?"

Choices (build dynamically from pipeline state):
- One entry per active PRD: "[prd-name] — [N pieces, M in-progress]"
- "New domain — no PRD exists yet"
- "Not a PRD-level change"

- **PRD selected** → Q3 with that PRD
- **"New domain"** → `type: pipeline-entry`, `stage: prd` → skip to Step 4
- **"Not a PRD-level change"** → Q4

### Q3 — Piece scope
*(Only ask if a PRD was selected in Q2)*

> "Does a spec/piece already exist for this work?"

Choices (build from that PRD's manifest):
- One entry per `open`, `specced`, or `planned` piece in that PRD
- "New piece — doesn't exist yet"
- "Quick fix — not spec-level work"

- **Existing piece** → `type: pipeline-entry`, route to correct stage (see routing table) → skip to Step 4
- **"New piece"** → `type: pipeline-entry`, `stage: spec` → skip to Step 4
- **"Quick fix"** → Q4

### Q4 — Standalone type

> "What best describes this work?"

Choices:
- "Hotfix / regression / CI failure"
- "Infrastructure or tooling change"
- "Charter or documentation update"
- "Exploration — read-only, no changes"

- **Hotfix / regression / CI / infra** → `type: hotfix` → Q5
- **Charter / docs** → `type: charter` → skip to Step 4
- **Exploration** → `type: exploratory` → skip to Step 4

### Q5 — Branch strategy
*(Hotfix track only)*

> "Which branch should this work target?"

Choices (build from `git branch --list` and worktree state):
- "Current branch ([current-branch-name])"
- "New hotfix branch off main"
- "Existing branch — I'll specify"

Record choice → Q6.

### Q6 — Tracking
*(Hotfix track only)*

> "Should this work be tracked?"

Choices:
- "Create a Jira ticket"
- "Already tracked — I'll provide the key"
- "No tracking needed"

Record choice → Step 4.

---

## Step 4: Build work_context

Assemble the classification result and write it to session state:

**Path:** `~/.copilot/session-state/<session-id>/work-context.yaml`
*(If session-id is unavailable, write to `/tmp/spec-flow-work-context.yaml`)*

```yaml
work_context:
  classified_at: <ISO-8601 timestamp>
  type: plan-scoped | pipeline-entry | hotfix | charter | exploratory
  prd: <prd-slug>              # null if not applicable
  piece: <piece-slug>          # null if not applicable
  pipeline_stage: spec | plan | execute | resume | prd | null
  branch: <branch-name>        # active branch if not overridden
  worktree: <absolute-path>    # null if not applicable
  cwd: <absolute-path>         # the root to operate from this session
  charter_constraints: all | none
  tracking: jira | existing | none
  tracking_ref: <key>          # Jira key or other ref, null if none
```

**CWD rules:**
| type | cwd |
|---|---|
| `plan-scoped` with active worktree | worktree absolute path |
| `plan-scoped` without worktree | `<docs_root>` root (piece not yet in execute) |
| `pipeline-entry` | worktree will be created by target skill; use main repo root for now |
| `hotfix` | main repo root (or hotfix branch root if a new branch was specified) |
| `charter` | main repo root |
| `exploratory` | current working directory — no constraint |

**Charter constraint rules:**
- All types except `exploratory` → `charter_constraints: all`
- `exploratory` → `charter_constraints: none`

**Pipeline stage routing** (for `pipeline-entry` type, piece exists):
| piece status | pipeline_stage |
|---|---|
| `open` | `spec` |
| `specced` | `plan` |
| `planned` | `execute` |
| `in-progress` | `resume` |

---

## Step 5: Set up session context

### 5a — CWD setup (plan-scoped with active worktree)

When `work_context.cwd` differs from the current working directory, emit this
block prominently and run the `cd` before proceeding:

```
⚡ SESSION SETUP REQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Worktree root: <worktree-path>
Branch:        <branch-name>
Piece:         <prd>/<piece>

REQUIRED ACTION: cd <worktree-path>
  Confirm with: pwd

All file reads and edits must resolve from this root.
Grep, glob, and view calls without this prefix will
return stale results from the wrong branch.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Run `cd <worktree-path>` and confirm `pwd` before any further file operations.

### 5b — Charter constraint digest (all types except `exploratory`)

Load the charter from `<docs_root>/charter/`:

1. Read `non-negotiables.md` — extract all `### NN-C-NNN:` headings that are **not**
   under a `RETIRED` marker
2. Read `coding-rules.md` — extract all `### CR-NNN:` headings that are **not** retired
3. Emit the compact digest:

```
Charter constraints active for this session (N NNs, M CRs):

Non-Negotiables:
  NN-C-001: <title>
  NN-C-002: <title>  ...

Coding Rules:
  CR-001: <title>
  CR-002: <title>
  ...

These apply to ALL work regardless of type. To read a full rule:
  view <docs_root>/charter/non-negotiables.md
  view <docs_root>/charter/coding-rules.md
```

If a charter file is absent, note it but do not block.

### 5c — Piece context (plan-scoped only)

Load the active spec and plan:
1. Skim `<docs_root>/prds/<prd>/specs/<piece>/spec.md` — extract the AC list
2. Skim `<docs_root>/prds/<prd>/specs/<piece>/plan.md` — identify current phase and its status
3. Emit: "Active ACs: [list]" and "Current phase: Phase N — [title] ([status])"

---

## Step 6: Route

After context is loaded, emit a clear next-action recommendation:

| type | stage | Recommended action |
|---|---|---|
| `plan-scoped` | `resume` | `Resume /spec-flow:execute <prd>/<piece> — Phase N: <title>` |
| `pipeline-entry` | `prd` | `Run /spec-flow:prd to define the new PRD` |
| `pipeline-entry` | `spec` | `Run /spec-flow:spec <prd>/<piece>` |
| `pipeline-entry` | `plan` | `Run /spec-flow:plan <prd>/<piece>` |
| `pipeline-entry` | `execute` | `Run /spec-flow:execute <prd>/<piece>` |
| `hotfix` | — | `Branch [branch] ready. Work directly — charter constraints are active.` |
| `charter` | — | `Run /spec-flow:charter --update, or edit <docs_root>/charter/ directly.` |
| `exploratory` | — | `No branch or constraint requirements. Proceed with read-only exploration.` |

Do not invoke the target skill automatically — present the recommendation and
let the user confirm before routing. This gives them a chance to correct the
classification if something is off.

---

## Reference: work_context types at a glance

| type | Charter | Spec/plan | Worktree CWD | Typical trigger |
|---|---|---|---|---|
| `plan-scoped` | All NNs + CRs | Yes — AC list + current phase | Required | "Continue vault-layer", CI fail on active PR |
| `pipeline-entry` | All NNs + CRs | Being created | New (by target skill) | "Add OAuth support", "we need a new piece for X" |
| `hotfix` | All NNs + CRs | No | Main or hotfix branch | "Fix regression in prod", "CI failing on main" |
| `charter` | All NNs + CRs | No | Main repo | "Add a new NN", "update the coding rules" |
| `exploratory` | None | No | Anywhere | "How does X work", "show me the auth flow" |
