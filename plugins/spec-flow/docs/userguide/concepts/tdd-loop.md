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

## The four agents

| Agent | Role |
|---|---|
| **tdd-red** | Writes a single failing test (or a small set of tests for one behavior). The failure output is captured verbatim by the orchestrator as the oracle. |
| **implementer** | Given the failing test output, writes the simplest code that turns it green. Cannot modify test files. |
| **verify** | Independently confirms the test actually passes and that the test integrity wasn't violated (no test edits during Build). |
| **refactor** | Cleans up phase-scoped files while keeping tests green. Cannot add new functionality. |

The execute orchestrator dispatches them in sequence, runs validation between steps, and only advances when each oracle is clean.

## The cycle, step by step

For a TDD-track phase (behavior-bearing code):

### Step 1 — Red
- **tdd-red** writes failing tests for this phase.
- Orchestrator runs the test suite.
- **Validation:** tests fail for the *right reason* (feature missing, not setup broken).
- The verbatim failing output becomes the oracle for Step 2.

### Step 2 — Build
- **implementer** receives `Mode: TDD`, the failing-test output, the plan's `[Build]` block, and pre-flight snapshots (LOC, existing patterns, symbol presence, pre-commit hook inventory).
- Implementer writes the simplest code that turns the failing tests green.
- Orchestrator runs the full test suite.
- **Validation:** suite is fully green AND no test files were modified since Red (caught by a `git diff tests/` check).

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

The most common failure mode in AI-driven TDD is the agent silently editing tests to make them pass. spec-flow guards against this:

- `tdd-red` writes tests, then the orchestrator captures the failing output verbatim.
- After Build, the orchestrator runs `git diff $phase_start_sha..HEAD -- tests/` and rejects the phase if any test file changed.
- `implementer` has an explicit rule: *"Do NOT modify test files. If a test looks wrong, report BLOCKED — do not 'fix' it."*

If the implementer really does find a broken test, it escalates to you rather than touching the test file.

## AC Coverage Matrix — the gate between phases

After Build completes, the implementer must return an **AC Coverage Matrix** — a table mapping every phase-scoped acceptance criterion to the test file:line (TDD mode) or verify-command assertion (Implement mode) that covers it.

```
| AC ID | Test file:line (TDD) / [Verify] assertion (Implement) | Status |
|-------|------------------------------------------------------|--------|
| AC-1  | tests/path/to/test_file.py:42                        | covered |
| AC-2  | —                                                    | NOT COVERED — deferred to Phase N+1 per plan.md:L120 |
```

A clean matrix — every AC row filled, specific file:line references, no bare `NOT COVERED` — unlocks Verify's fast Audit mode. A vague or incomplete matrix forces Full re-verification.

## Where to go next

- [QA loop](./qa-loop.md) — how must-fix findings get resolved at every boundary.
- [Orchestrator model](./orchestrator-model.md) — why the orchestrator never writes code.
- [commands/execute.md](../commands/execute.md) — the full execute command walkthrough.
