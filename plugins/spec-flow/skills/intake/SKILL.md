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

## Step 1b: Pending Jira transitions

After loading pipeline state, check for any piece that needs a `Done` transition from a
prior PR-based merge. This step runs silently and non-blockingly — it never delays the main
intake flow.

1. From the status output, collect all pieces with manifest `status: merged` that have at
   least one `jira_key:` field in their `spec.md` or `plan.md`.
2. For each such piece, run the capability check for `get_issue` (Jira MCP tool).
   - If available: query the Jira task. If the task's current status is `In Review` (or
     equivalent — the `pr` path transitions to this status at PR open time), prompt:
     > "🔔 **[prd/piece]** was merged. Jira [EIT-NNN] is still `In Review`. Mark as Done?"
     Present choices: `["Yes — transition to Done", "Skip for now"]`
     On "Yes": transition the task to `Done` via `transition_issue`, then continue.
   - If unavailable: skip silently (do NOT block or warn).
3. Process at most 3 pending pieces per intake session to keep startup fast. If more exist,
   note the count and suggest running intake again after the first batch.

**This step is a no-op when all merged pieces have Jira tasks already in `Done`, or when
no `jira_key:` fields are found, or when the Jira tool is unavailable.**

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

**Small-change pre-signals (note — final routing via Q_scale, not here):**
Record in session state whether the user message contains any of these keywords for Q2's "New domain" branch:
- `"fix"`
- `"bug"`
- `"broken"`
- `"regression"`
- `"quick"`
- `"tweak"`
- `"minor"`
- `"patch"`
- `"one-off"`
- `"small feature"`

These signals do NOT trigger auto-routing here. They are surfaced as `small_change_signals_detected` in session state for Q_scale (Q2 "New domain" branch) to consume. No silent routing — operator must explicitly select (AC-IN-5).

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
- **"New domain"** → check `small_change_signals_detected`:

  **If `small_change_signals_detected` is true** → present **Q_scale — scale check**:

  > "Detected signals: [list detected keywords from user message].
  > How would you like to handle this?
  >
  > Options:
  > 1. Full PRD approach — continue to PRD pipeline
  > 2. Small focused change — use /spec-flow:small-change"

  No silent auto-routing — operator must explicitly select (AC-IN-5).

  On operator selecting option 2 ("Small focused change"):
  - Set `work_context.type = "small-change"`
  - Set `pipeline_stage = null`
  - Route recommendation: `"Run /spec-flow:small-change <slug> to begin the focused change workflow."`
  - Skip remaining Q3 questions (no further pipeline classification needed) → proceed to Step 4

  On operator selecting option 1 ("Full PRD approach"):
  - Proceed to existing `type: pipeline-entry`, `stage: prd` routing unchanged (AC-IN-4) → skip to Step 4

  **Worked example for Q_scale routing algorithm** (required — dense-algorithm guard applies to signal detection + two-branch routing):
  ```
  <!-- Example A: user says "quick fix for the button label color"
    Q2 branch: "New domain — no PRD exists yet" (confirmed)
    Signals detected: ["quick", "fix"]
    Q_scale presented: "Detected signals: quick, fix. Full PRD approach or Small focused change?"
    Operator selects option 2 "Small focused change"
    work_context.type = "small-change"
    pipeline_stage = null
    Routing: /spec-flow:small-change <slug>
    Q3 skipped.

    Example B: same input, operator selects option 1 "Full PRD approach"
    work_context.type = "pipeline-entry"
    pipeline_stage = "prd"
    Existing new-domain routing runs unchanged.

    Example C: user says "add payment integration" — no signal keywords
    Q_scale does NOT fire
    Existing new-domain routing runs unchanged from Q2
  -->
  ```

  **If `small_change_signals_detected` is false** → existing routing unchanged: `type: pipeline-entry`, `stage: prd` → skip to Step 4
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
- "Investigation / discovery to triage"

- **Hotfix / regression / CI / infra** → `type: hotfix` → Q5
- **Charter / docs** → `type: charter` → skip to Step 4
- **Exploration** → `type: exploratory` → skip to Step 4
- **Investigation / discovery to triage** → route to `/spec-flow:triage` (operator-selected; do NOT auto-route) → exit intake

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

### 5b — Charter constraint loading

Charter loading varies by work type. Charter is always published as skill files under the
active charter root, resolved per `plugins/spec-flow/reference/charter-location.md` —
`<charter_root>/skills/charter-<domain>/SKILL.md`, `<charter_root>` ∈ {`.github`, `.claude`}.
Resolve the root once (read-only) before loading, then apply the tier matrix below.

**Tier matrix** — which charter domains to load:

| Charter domain | Tier | Load when |
|----------------|------|-----------|
| `non-negotiables` | 1 | Always (all non-exploratory types) |
| `processes` | 1 | Always (all non-exploratory types) |
| `coding-rules` | 1 | Always (all non-exploratory types) |
| `architecture` | 2 | `pipeline-entry`, `plan-scoped`, `hotfix` of type infra/tooling |
| `flows` | 2 | `pipeline-entry`, `plan-scoped` |
| `tools` | 2 | `pipeline-entry`, `plan-scoped`, `hotfix` of type infra/tooling |
| `integrations` | 2 | `pipeline-entry`, `plan-scoped` |

**Type → tier mapping:**

| `work_context.type` | Tiers loaded | Charter domains |
|---------------------|-------------|-----------------|
| `hotfix` (code/test) | Tier 1 | non-negotiables, processes, coding-rules |
| `hotfix` (infra/tooling) | Tier 1 + arch + tools | non-negotiables, processes, coding-rules, architecture, tools |
| `plan-scoped` | Tier 1 + Tier 2 | all 7 domains |
| `pipeline-entry` | Tier 1 + Tier 2 | all 7 domains |
| `charter` | Tier 1 | non-negotiables, processes, coding-rules |
| `exploratory` | none | (skip loading) |
| vague/unclassified | Tier 1 | non-negotiables, processes, coding-rules |

**Charter loading (resolved location):**

Invoke each charter skill matching the tier matrix above from the active charter root. Skills are invoked by reading their `SKILL.md` file into context — they carry their own descriptions and will persist. With `<charter_root>` resolved per `plugins/spec-flow/reference/charter-location.md` (`<charter_root>` ∈ {`.github`, `.claude`}):

```
Invoke:
  <charter_root>/skills/charter-non-negotiables/SKILL.md
  <charter_root>/skills/charter-processes/SKILL.md
  <charter_root>/skills/charter-coding-rules/SKILL.md
  [+ tier 2 domains if applicable]
```

If a charter skill is absent, note it but do not block. If no charter root resolves at all (a
pre-charter project), skip charter loading — there are no project-level NN-C/CR to apply.

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
| `charter` | — | `Run /spec-flow:charter --update, or edit the charter skills under the resolved charter root (<charter_root>/skills/charter-*/SKILL.md) directly.` |
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
