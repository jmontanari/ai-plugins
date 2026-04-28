# The TDD loop

spec-flow enforces strict TDD discipline on every behavior-bearing code phase inside `/spec-flow:execute`. The loop is Red → Build → Verify → Refactor, orchestrated by the execute skill and run by four dedicated agents.

## The Three Laws

1. **No production code without a failing test first.**
2. **No more test than sufficient to fail** (one behavior per test).
3. **No more production code than sufficient to pass the one failing test.**

These are load-bearing. They prevent the two failure modes that normally emerge when an AI writes code:

- **"Code first, tests later"** — produces tests that confirm whatever the agent already wrote. Looks green; doesn't prove correctness.
- **"One big implementation, many tests"** — produces code that handles imagined cases. Looks thorough; ships dead branches.

By writing exactly one failing test, then exactly the code to pass it, and repeating, the resulting code can only contain behavior that has a test behind it.

## The five agents

| Agent | Role |
|---|---|
| **tdd-red** | Writes a single failing test (or a small set of tests for one behavior), **stages them via `git add` but does NOT commit** (v2.7.0+). The failure output is captured verbatim by the orchestrator as the oracle, and the orchestrator snapshots a SHA-256 manifest of each staged file for the anti-tampering check later. |
| **qa-tdd-red** | Reviews Red's authored tests against the 11-pattern theater catalog (tautology, mock-echo, truthy-only, no-assertion, name/body mismatch, implementation coupling, etc.) + an AC-binding check. Runs between Red and Build. Rejects theater tests before Build writes production code fit to weak assertions. |
| **implementer** | Given the failing test output, writes the simplest code that turns it green. Cannot modify test files (enforced by SHA-256 content-hash integrity check). In Mode: TDD, creates the SINGLE unified commit containing Red's staged tests + its own production code (v2.7.0+). |
| **verify** | Independently confirms the test actually passes and that the test integrity wasn't violated (no test edits during Build). Full mode re-runs the full theater catalog as Opus-tier backstop; Audit mode spot-checks the top 5 patterns. |
| **refactor** | Cleans up phase-scoped files while keeping tests green. Cannot add new functionality. |

The execute orchestrator dispatches them in sequence, runs validation between steps, and only advances when each oracle is clean.

## The cycle, step by step

For a TDD-track phase (behavior-bearing code):

### Step 1 — Red (stage, don't commit)
- **tdd-red** writes failing tests for this phase and `git add`s them by literal path. Does NOT commit.
- Orchestrator runs the test suite against the staged tests (no commit needed — the runner reads from the working tree).
- Orchestrator captures a `## Staged test manifest` (path → SHA-256) for the anti-tampering check later.
- **Validation (two invariants, both required):**
  - **Zero passing new tests** — a re-run scoped to the authored test paths must report `0 passed`. A passing new test means the feature already exists (wrong phase) or the assertion is tautological.
  - **Right failure reason** — each failing test fails because the feature is missing, not from a typo / import / fixture error.
- The verbatim failing output becomes the oracle for Step 2.

### Step 1.5 — QA-Red
- **qa-tdd-red** reviews Red's authored tests before Build is dispatched.
- Applies the 11-pattern theater catalog (tautology, self-referential, mock-echo, call-count only, assert-the-assignment, truthy-only, exception swallowing, no-assertion, name/body mismatch, implementation coupling, redundant cluster) + an AC-binding check ("if I implemented this AC wrong, would this test catch it?").
- **Validation:** PASS advances to Build; FAIL re-dispatches `tdd-red` once with findings surfaced. Two consecutive FAIL verdicts escalate — the phase's ACs are likely too vague (spec defect) or the plan's `[TDD-Red]` block directs Red toward un-testable surface (plan defect).
- Runs Sonnet-tier; scope is narrow (just the authored test files).

### Step 2 — Build (unified commit)
- **implementer** receives `Mode: TDD`, the failing-test output, Red's `## Staged test manifest`, the plan's `[Build]` block, and pre-flight snapshots (LOC, existing patterns, symbol presence, pre-commit hook inventory). Red's test files are in the staging area when implementer starts.
- Implementer writes the simplest code that turns the failing tests green, `git add`s its production files by literal path, then creates ONE unified commit containing Red's staged tests + its own code.
- Orchestrator runs the full test suite.
- **Validation (three invariants, all required):**
  - **Full suite green** — zero failures across the project.
  - **Every Red ID is in PASSED** — the orchestrator set-diffs the Red oracle block's FAILED IDs against the Build run's PASSED set; any Red test missing from PASSED rejects the phase.
  - **Zero Red IDs in SKIPPED** — catches silent `@skip` / `.skip()` / `t.Skip()` / xfail decorators added during Build, plus collection errors and empty parameterize lists that would otherwise let a Red test quietly disappear.
- **Post-commit integrity and reconciliation gates** (v2.7.0+):
  - **Content-hash integrity** — orchestrator re-hashes each test file in HEAD against Red's stage manifest. Any drift = rejection (implementer modified Red's tests).
  - **Unified commit reconciliation** — commit's file list must equal (Red manifest paths ∪ implementer's reported Build paths). Strays or missings = rejection.

### Step 3 — Verify
- **verify** re-runs the oracle, checks AC coverage, scans for over-engineering.
- **Two modes:**
  - **Audit** (~3 min) — used when Build reported clean first-attempt oracle + no deviations + complete AC matrix. Sanity-checks the matrix without re-running tests.
  - **Full** (~10 min) — re-runs the full oracle. Triggered if Build's report has any concern.
- If Verify fails: loop back to Red (add tests) or Build (add impl), up to the retry cap.

### Step 4 — Refactor *(conditional — often skipped)*
- **refactor** cleans up duplication, names, helpers. Scope is *phase files only*.
- Tests must stay green throughout.
- **Auto-skip rule:** if Build produced a clean first-attempt oracle with no deviations and a clean AC matrix, Refactor is skipped. Observed yield from empirical runs: Refactor on a clean Build phase produces only cosmetic cleanups and fixes zero correctness defects, so skipping reclaims 10–15 min with no quality loss.

### Step 5 — Phase QA (every phase)
- **qa-phase** (Opus) adversarially reviews the phase diff against the mapped acceptance criteria.
- If findings emerge, the fix-code agent makes targeted fixes, QA re-reviews the delta only. Up to 3 iterations, then escalate.

## Implement mode — the non-TDD track

Some phases don't fit TDD: YAML configs, infrastructure scaffolding, glue wiring, docs-as-code, fixtures, migrations. Forcing a failing test for a `.gitignore` update is ceremony without payoff.

For those phases, the plan marks them `[Implement]` instead of `[TDD-Red]` + `[Build]`. The implementer runs in `Mode: Implement` with a `[Verify]` command the plan author chose (lint, type check, build, smoke run) as the oracle of done.

- Same implementer agent, same rules, same QA.
- No test-file-integrity check (there may be no tests).
- Refactor step runs only if the plan has an explicit `[Refactor]` checkbox.

The plan author picks the track per phase. Behavior-bearing code → TDD. Config, scaffolding, glue → Implement.

## Test integrity — the anti-cheat

The most common failure mode in AI-driven TDD is the agent silently editing tests to make them pass. spec-flow guards against this with a SHA-256 content-hash check (v2.7.0+):

- `tdd-red` writes tests and `git add`s them (no commit). The orchestrator captures both the failing test output verbatim AND a `## Staged test manifest` listing every path with its SHA-256 content hash.
- After the implementer's unified commit lands, the orchestrator re-hashes each test file in HEAD against the stage manifest. Any drift = rejection (agent cheating detected).
- If Refactor runs, the same re-hash check runs again against HEAD after Refactor's commit.
- `implementer` has an explicit rule: *"Do NOT modify test files. If a test looks wrong, report BLOCKED — do not 'fix' it."*

If the implementer really does find a broken test, it escalates to you rather than touching the test file. The integrity check is strict and unforgiving by design — even an auto-format or whitespace change trips it.

Pre-v2.7.0, integrity was checked via `git diff $red_sha..HEAD -- tests/`. Under the unified-commit model there's no intermediate Red SHA (Red no longer commits), so the check moved to path-keyed SHA-256. Same detection power, different mechanism.

## AC Coverage Matrix — the gate between phases

After Build completes, the implementer must return an **AC Coverage Matrix** — a table mapping every phase-scoped acceptance criterion to the test file:line (TDD mode) or verify-command assertion (Implement mode) that covers it.

```
| AC ID | Test file:line (TDD) / [Verify] assertion (Implement) | Status |
|-------|------------------------------------------------------|--------|
| AC-1  | tests/path/to/test_file.py:42                        | covered |
| AC-2  | —                                                    | NOT COVERED — deferred to Phase N+1 per plan.md:L120 |
```

A clean matrix — every AC row filled, specific file:line references, no bare `NOT COVERED` — unlocks Verify's fast Audit mode. A vague or incomplete matrix forces Full re-verification.


## Non-TDD mode — the piece-level toggle

Non-TDD mode is a piece-level decision, declared in the plan's front-matter as `tdd: false`. It is not per-phase: when a piece uses non-TDD mode, ALL phases in that piece use the Implement track with an added `[Write-Tests]` step.

**Why choose non-TDD mode:**
- The work is largely glue/wiring/config where unit-level TDD adds ceremony without value.
- Rapid prototyping or exploratory work where the specification may change.
- Legacy code modification where TDD discipline is impractical.
- Team policy preference (not all teams use TDD).

**What changes in non-TDD mode:**
- `[TDD-Red]` is absent from all phases.
- `[QA-Red]` (theater-pattern gate) does not run.
- `[Build]` is replaced by `[Implement]` + `[Write-Tests]` in every phase.
- No AC Coverage Matrix is required.
- Verify defaults to Full mode (since Audit mode is unlocked by a clean AC matrix, which is absent).

**What stays the same:**
- Phase QA (`qa-phase`) runs on every phase.
- Final Review (5-agent board) runs after all phases.
- Reflection (Step 4.5) runs normally.
- Circuit breakers, escape hatches, and escalation rules are identical.
- The `implementer` agent still runs, but in `Mode: Implement`.
- The `refactor` agent still runs when the phase has a `[Refactor]` checkbox.

Non-TDD mode is a valid, complete choice. It is not a "reduced" version of TDD -- it is a different strategy with different trade-offs. The pipeline remains rigorous: every phase still gets adversarial QA review and the final piece still gets a 5-agent review board.

## Where to go next

- [QA loop](./qa-loop.md) — how must-fix findings get resolved at every boundary.
- [Orchestrator model](./orchestrator-model.md) — why the orchestrator never writes code.
- [commands/execute.md](../commands/execute.md) — the full execute command walkthrough.
