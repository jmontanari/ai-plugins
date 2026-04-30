# /spec-flow:execute

Orchestrate implementation of an approved plan phase-by-phase. Each phase dispatches subagents (Red, Build, Verify, Refactor, QA), runs verification oracles, and advances only when gates pass. Ends with a 5-agent final review board and merge to master.

## What it does

The heaviest skill in spec-flow. Walks the plan from Phase 1 to Phase N, for each phase:

1. Dispatches the mode-appropriate agents (TDD or Implement track)
2. Runs the oracle (test suite for TDD, verify command for Implement)
3. Runs Phase QA (Opus adversarial review)
4. Advances to the next phase

At the end of the last phase, runs the Final Review 5-agent board, produces a reflection, and merges the piece to master.

## When to run it

- Piece status is `planned` in the manifest.
- You're on the piece's worktree branch (`spec/<piece-name>`).
- All manifest dependencies are `done`.

## The flow at a high level

![Execute flow](../assets/execute-flow.png)

For the conceptual overview of what happens inside a phase, see [tdd-loop.md](../concepts/tdd-loop.md).

## Pre-loop

Before phase 1 starts (fresh-start only):

- Updates the manifest on master to mark the piece `implementing`.
- Switches back to the worktree branch.

## Per-phase loop

For each phase in plan.md (skips phases where all checkboxes are `[x]`):

### Step 1 — Capture phase-start SHA

Orchestrator records HEAD into working memory as `phase_N_start_sha`. No tag, no commit. Used later for test-integrity diffs.

### Step 1a — Detect phase mode

Reads the phase's checkboxes:

- Has `[TDD-Red]` → **Mode: TDD**
- Has `[Implement]`, no `[TDD-Red]` → **Mode: Implement**
- Both or neither → plan is malformed, escalate.

### Step 1b — Phase pre-flight

Orchestrator collects cheap facts the agents would otherwise rediscover:

- **LOC snapshot** — `wc -l` on each phase-scoped file.
- **Schema shape** — `head -20` of one sibling file if the phase writes a config family.
- **Symbol presence** — `git grep` for each named type/class/function the plan references.
- **Pre-commit hook inventory** — reads `.pre-commit-config.yaml`, flags test-running hooks.
- **Plan conditional resolution** — resolves LOC- and filesystem-based conditionals in the plan's Build/Implement block (e.g., "extract if function exceeds 200 LOC") into binding pre-decisions.

Attached to all subsequent agent prompts as `## Pre-flight snapshot` and `## Orchestrator pre-decisions` blocks.

### Step 2 — TDD-Red (TDD mode only)

- Skipped entirely when the plan's front-matter declares `tdd: false` (non-TDD mode).
- In TDD mode: dispatches **tdd-red** agent with the phase's `[TDD-Red]` tasks + spec ACs + pre-flight snapshot.
- Agent writes failing tests and stages them (does NOT commit — v2.7.0+).
- Orchestrator runs the test suite — expects failures for the *right reasons* (feature missing, not setup broken).
- Captures the verbatim failing output as `phase_N_oracle_block` — Step 3's oracle.
- Post-commit contamination check: reconciles the committed file list against the agent's `## Tests Written` paths to catch concurrent agent work sweeping in.

### Step 3 — Implement (both modes)

- Dispatches **implementer** agent with `Mode: TDD` or `Mode: Implement` flag, the plan's Build/Implement block (by reference, not copy), pre-flight, pre-decisions, and the oracle.
- Agent writes code.
- Parallel phases: if the phase has `[P]` siblings, orchestrator dispatches them concurrently and checks for file-scope overlap on completion.
- **Validation:** runs the mode's oracle.
  - TDD mode: full test suite must be green.
  - Implement mode: the plan's `[Verify]` command must pass with expected output.
- **Circuit breaker:** 2 attempts max; then escalate.
- **AC Coverage Matrix gate:** In TDD mode, Build must return a complete matrix mapping each phase AC to a test file:line. A vague or incomplete matrix forces the next step into Full mode. In non-TDD mode (`tdd: false`), this gate is skipped — the matrix is not required, and Verify defaults to Full mode.

### Step 4 — Verify

- Dispatches **verify** agent in **Audit mode** (fast, ~3 min) if Build reported clean oracle + no deviations + clean matrix.
- Otherwise **Full mode** (~10 min) — re-runs the full oracle.
- **Test-integrity check (TDD mode only):** runs `git diff $phase_N_start_sha..HEAD -- tests/` and rejects the phase if tests were modified since Red. In non-TDD mode, this check is a no-op (no Red manifest exists).

### Step 5 — Refactor (often skipped)

- **Conditional skip:** auto-skipped when Build reported clean first-attempt oracle + no deviations + clean AC matrix. Empirically, Refactor on a clean Build fixes zero correctness defects and only produces cosmetic cleanups — skipping reclaims 10–15 min per phase with no quality loss.
- When run: **refactor** agent cleans up phase files, keeping tests green. Scope: phase files only. Cannot add functionality.

### Step 6 — Phase QA

- **qa-phase** agent (Opus) adversarially reviews the phase diff:
  - Diff + AC Coverage Matrix + phase ACs + non-negotiables.
  - **Not** the full spec or PRD — those are the final review board's job.
- Findings → **fix-code** agent makes targeted fixes → qa-phase re-reviews the delta.
- Up to 3 iterations, then escalate.

### Step 7 — Progress commit

Orchestrator commits a progress marker with the phase's checkboxes marked `[x]`. Ready for the next phase.

## End-of-piece flow

After the final phase:

### Final Review — 5-agent board

Five reviewers dispatched **in parallel**, each with a specialized lens:

| Reviewer | Focus |
|---|---|
| **blind** | Just the diff. Bugs, dead references, broken claims. |
| **edge-case** | Failure modes, stale caches, version floors, boundary conditions. |
| **spec-compliance** | Every AC honored? |
| **prd-alignment** | Advances PRD goals? Respects non-negotiables? |
| **architecture** | Layer boundaries, charter compliance, CR-xxx drift. |

Findings resolved by fix-code/fix-doc, same 3-iteration cap.

### Reflection (optional)

Two reflection agents (if `reflection: on` in `.spec-flow.yaml`):

- **reflection-process-retro** — what worked / what didn't in the pipeline flow for this piece.
- **reflection-future-opportunities** — forward-looking candidates for future pieces or spec amendments.

Findings accumulate in `docs/improvement-backlog.md` for future `/spec-flow:spec` runs to consume.

### Merge to master

- Flips manifest status to `done`.
- Merges `spec/<piece-name>` → `master` (the user's choice of merge commit or squash).
- Cleans up the worktree and feature branch.

## Loops

- **Per-phase oracle loop** — 2 attempts max per implementation, then escalate.
- **Per-phase QA loop** — 3 iterations max per review cycle.
- **Final Review board loop** — 3 iterations max per finding set.

Every loop has a circuit breaker. No loop is unbounded.

## What you get

- Production code committed to the worktree branch, phase-by-phase.
- A clean git history showing each phase's progression.
- A `docs/prds/<prd-slug>/specs/<piece-name>/learnings.md` file if the pipeline surfaced interesting findings (smoketest records, in-phase bug fixes, design pivots).
- Manifest flipped to `status: done`.
- Piece merged to master with full review-board sign-off.

## Handoff

Next: `/spec-flow:status` tells you what's next. If there are more open pieces, pick one and run `/spec-flow:spec`.

## Worked example (high level)

Piece: `PI-104-data-export` with a 6-phase plan.

```
Phase 1 (Implement — schema):             2 min   clean
Phase 2 (TDD — auth):                     5 min   Red → Build (1 attempt) → Audit Verify → auto-skip Refactor → QA clean
Phase 3 (TDD — CSV writer):   [P] with 4: 6 min   clean
Phase 4 (TDD — JSON writer):  [P] with 3: 5 min   clean
Phase 5 (TDD — API endpoint):             11 min  Build needed 2 attempts; Full-mode Verify; QA found 1 must-fix (error-shape doesn't match CR-011); fix-code iter-2 clean
Phase 6 (Implement — docs):               3 min   clean

Final Review:                             8 min   5 agents parallel; prd-alignment flagged missing NN-P-003 dogfood citation; fix-doc added it; iter-2 clean

Reflection:                               4 min   process-retro noted "Phase 5's oracle retry was due to stale mock signature — pattern worth capturing"

Merge:                                    1 min   clean
```

Total: ~45 min of pipeline time. You signed off at every user-gate (spec, plan, final review). You didn't touch the code yourself.

## Common execute-time issues

- **Non-TDD mode, Verify stays in Full mode:** Without an AC Coverage Matrix, Verify cannot use the fast Audit mode. This is expected and correct — the Full mode is the right default when the matrix is absent.
- **Oracle won't turn green after 2 attempts** — escalated. Usually means the plan is ambiguous about what the code should actually do. Revise the plan, or add a missing acceptance criterion to the spec, and retry.
- **Test-integrity check fails** — the implementer modified test files. Rejected as cheating. Re-dispatch the Build with a stricter reminder; if it happens twice, escalate to check what's going on.
- **AC Coverage Matrix forces Full Verify** — happens when Build reports `NOT COVERED` without a reason. Build agent gets re-dispatched with the matrix requirements spelled out; if it still fails, escalate.
- **qa-phase loop won't clear** — 3 iterations hit. Means the fix agent can't resolve the finding with code changes alone. Likely a structural issue — maybe the plan missed a phase, or the spec's AC is ambiguous. Escalate.

## Where to go next

- [TDD loop concepts](../concepts/tdd-loop.md) — the per-phase cycle in detail, including non-TDD mode.
- [TDD vs Implement choosing](../concepts/tdd-loop.md#non-tdd-mode--the-piece-level-toggle) — when to use each mode.
- [QA loop concepts](../concepts/qa-loop.md) — how fix-and-re-review works.
- [Orchestrator model](../concepts/orchestrator-model.md) — the skill-vs-agent separation.
- [Pipeline concepts](../concepts/pipeline.md) — where execute sits in the full chain.
