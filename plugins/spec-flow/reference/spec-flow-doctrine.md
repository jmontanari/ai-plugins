# TDD Doctrine

This document governs all implementation work in the spec-flow plugin. It is loaded automatically at session start and referenced by all agent prompts.

## The Three Laws

1. No production code without a failing test first
2. No more test than sufficient to fail
3. No more production code than sufficient to pass the one failing test

## Red-Build-Verify-Refactor Cycle

### RED — Write Failing Test
- One behavior per test ("and" in test name → split it)
- Clear name describing behavior, not implementation
- Arrange-Act-Assert structure
- Must fail for the right reason: feature is missing, not typo/setup error
- Agent reports the failure message; orchestrator validates it

### BUILD — Minimal Code
- Simplest possible code to pass the test
- No optional parameters not required by the test
- No multiple strategies when one is needed
- No infrastructure before behavior is needed
- If test won't go green in 2 attempts → escalate to human

### VERIFY — Confirm Correctness
- Run full test suite, confirm all pass
- Check AC coverage: does each spec AC have a corresponding passing test?
- Detect over-engineering: did the implementer add code beyond what the mode's oracle requires?
- Detect test tampering: were test files modified since the Red step?

### REFACTOR — Clean Up
- Remove duplication, improve names, extract helpers
- Tests stay green throughout (run after every change)
- No new behavior added
- No changing what code does — only how it's organized
- Scope: current phase files only — do not reorganize other phases

## Agent-Specific Safeguards

| Safeguard | Enforcement |
|-----------|-------------|
| Test must fail for right reason | Orchestrator reads failure output, validates it matches expected missing feature |
| Red commit has zero passing new tests | Orchestrator re-runs the suite scoped to paths in `## Tests Written` and reconciles against the oracle block's FAILED list; any `passed` among new tests rejects the phase and triggers one retry before escalation |
| Build run has every Red test in PASSED | Orchestrator diffs the Red oracle block's FAILED IDs against the Build run's PASSED set; any Red ID that is SKIPPED, xfailed, or missing from the run (collection error, empty parameterize, deleted test) rejects the phase. Symmetric to the Red-side invariant above — catches silent skip decorators and test disappearance that "full suite green" alone permits |
| Red tests pass theater review before Build | `qa-tdd-red` agent (Sonnet, read-only) dispatched between Red and Build scores every authored test against the 11-pattern Theater Pattern Catalog + AC-binding check. FAIL verdict re-dispatches Red once with findings surfaced; second consecutive fail escalates. Verify Full-mode runs the full catalog as Opus-tier backstop; Verify Audit-mode spot-checks the top 5 patterns. `qa-phase` runs the full catalog end-of-phase as final Opus backstop |
| Minimal implementation only | Verify agent checks for over-engineering beyond test requirements |
| No test modification to pass | Orchestrator snapshots a path-keyed SHA-256 manifest of Red's staged tests at Step 2.6, then re-hashes each test file in the implementer's unified commit (and again after Refactor if it runs). Any hash drift = rejection. Replaces the pre-v2.7.0 `git diff $red_sha..HEAD -- tests/` check since Red no longer commits. |
| Circuit breaker | 2 failed build attempts → escalate to human |
| No mock abuse | Real object > fake > stub > mock. Agent must justify any mock in report |
| Full error feedback | Failed test output passed verbatim to next agent — no summarizing |
| No agent cheating | Hard-coded return values, over-fitted tests, trivial implementations flagged by QA |
| Refactor scope | Refactor agent may only touch files created/changed in current phase |

## Commit Cadence

**Default: one commit per TDD cycle.** Each TDD cycle (Red → Build → green) lands as a SINGLE commit in git history — the implementer's unified commit containing Red's staged tests + Build's production code. An optional Refactor commit may follow on clean-up phases.

| Agent-step | Commits produced | What's in the commit |
|---|---|---|
| Red | 0 (stages only) | Authored tests are `git add`-ed with literal paths; NOT committed. A `## Staged test manifest` with SHA-256 per path is emitted for the orchestrator to snapshot. |
| Build (Mode: TDD) | 1 (unified) | Red's staged tests + Build's production code, committed together. File list must equal (Red manifest paths ∪ Build reported paths). |
| Build (Mode: Implement) | 1 | Build's authored files only (no prior staging). |
| Refactor (if run) | 1 | All cleanups that preserve behavior. |

**Net per TDD phase:** 1 commit (happy path, no refactor), 2 commits (with refactor). Down from pre-v2.6.0's 3–5+ commits (per-file) and pre-v2.7.0's 2–3 (per-agent-step).

**Why unified, not separate Red and Build commits.** A TDD cycle represents one complete behavior addition. Splitting it into a "failing-tests" commit followed by a "production-code" commit split the narrative: each half of the cycle was individually incoherent (tests-without-code broke CI; code-without-tests preceded its own justification). Merging them into one commit makes each commit in git history represent one complete green behavior delta, and runs the pre-commit hook once per cycle instead of twice (~3–5s saved per phase; across 10 phases, 30–50s saved).

**Why not per-file.** Checkpointing per file was the original default (pre-v2.6.0), rationalized by "faster error surfacing, bisect-within-phase, intermediate recovery." For AI-driven TDD these benefits are theoretical: the agent processes hook errors in the same turn regardless of when they surface, the orchestrator retries at phase scope not commit scope, and nobody navigates intra-phase git history. The cost of per-file commits was real — pre-commit hooks (~3–5s each) ran N times per step, adding 10–25s of pure overhead per phase with no corresponding benefit.

**Integrity preserved via SHA-256.** The pre-v2.7.0 anti-cheat check was `git diff $red_sha..HEAD -- tests/` to detect test-file edits during Build. Under the unified-commit model there's no intermediate Red SHA — so the orchestrator snapshots a path-keyed SHA-256 manifest of Red's staged tests before dispatching the implementer, and re-hashes each test file in the unified commit against the manifest. Any drift = rejection + retry. Content-hash integrity is equivalent to diff-based detection in power and is cheaper to compute.

**Opt-out (rare).** Agents MAY split into multiple commits at sub-step boundaries if:
- Phase delta exceeds ~200 LOC
- A hook failure on the batched diff would be hard to debug (e.g. a refactor touching 10 files where tracing which change broke the type-check would take longer than the hook-amortization savings)
- The agent explicitly reasons about the tradeoff in its report

Otherwise, the default is the single unified commit. Per-file commits are not the baseline.

**Contamination discipline preserved.** `Rule: literal file list when staging` (tdd-red agent) and `ONE unified commit` (implementer agent Rule 8) both require literal-path discipline: stage and commit by exact path, never by pattern. The cadence rule is about commit count per cycle, not about staging shortcuts — `git add .`, `git add -A`, and `git commit -a` remain banned.

## Testing Strategy

**Ratios (guideline, not rigid):**
- ~60% unit tests (behavior of individual components)
- ~30% integration tests (component interaction, data flow)
- ~10% E2E / acceptance tests (critical paths from spec ACs)

**Test doubles hierarchy (preferred order):**
1. Real object (best — if fast and deterministic)
2. Fake (working but simplified — e.g., in-memory database)
3. Stub (returns predetermined values)
4. Mock (tracks interactions — only when verifying side effects)

**Approach:** Outside-in specification (spec ACs define behavior from user perspective), inside-out execution (plan builds components bottom-up per dependency order).

## Verification Checklist

Used by QA agents and the orchestrator before marking any phase complete:

- [ ] Every new function/method has a test
- [ ] Each test was watched failing before implementation
- [ ] Each test failed for expected reason (feature missing, not typo)
- [ ] Minimal code written to pass each test
- [ ] All tests pass, output clean (no warnings)
- [ ] Tests use real code (mocks justified where used)
- [ ] Edge cases and error paths covered
- [ ] No over-engineering beyond test requirements
- [ ] Refactoring stayed within phase scope

## Theater Pattern Catalog

Theater tests are tests that pass by trivia, mock-echoing, or assertion omission rather than by exercising real behavior. They are the AI-generated TDD failure mode this pipeline spends a Sonnet dispatch specifically to prevent (the `qa-tdd-red` agent, Step 2.5 of `execute`).

The catalog is the authoritative list. `qa-tdd-red` applies all 11 patterns pre-Build; `verify` Full mode re-applies all 11 as Opus-tier backstop; `verify` Audit mode spot-checks the top 5; `qa-phase` applies all 11 end-of-phase.

Examples are Python/pytest because it's the reference stack — adapt the syntax for Jest, Vitest, Go, Rust, RSpec, etc.

1. **Tautology as sole assertion** — `assert True`, `assert 1 == 1`, `assert result is not None` as the only assertion. Passes regardless of the production code.
2. **Self-referential** — `assert foo(5) == foo(5)`. Always true whatever `foo` does.
3. **Mock-echo assertion** — `m = Mock(return_value=42); assert subject(m) == 42`. Tests the mock's configured return, not the production code path.
4. **Call-count only** — `assert mock.called` or `mock.assert_called()` without verifying args, return, or call order. Passes if the function is called for any reason — including an error path.
5. **Assert-the-assignment** — `obj.x = 5; assert obj.x == 5` with no intervening behavior. Tests attribute setting, not any logic.
6. **Truthy-only** — `result = do_thing(); assert result` where `result` could be a wrong type, empty dict, string `"False"`, etc. and still pass.
7. **Exception swallowing** — `try: do_thing(); assert <something>; except: pass` or overly broad `except Exception` wrapping the assertion. Swallows `AssertionError` itself — test reports pass regardless.
8. **No assertion at all** — test invokes the code but never asserts. Runners count these as passed (pytest, Jest, Vitest all do).
9. **Name-vs-body mismatch** — `test_handles_empty_list` that passes `[1]`. `test_rejects_negative` that passes `1`. Name implies a case the body doesn't exercise.
10. **Implementation-coupled** — asserting on private attributes (`_internal_state`), class names, specific exception message strings unlikely to stay stable, or call order of private methods. Passes until any refactor; fails for reasons unrelated to the AC.
11. **Redundant cluster** — 3+ tests asserting the same invariant with permuted inputs that don't exercise different branches. One test would cover it; the extras are inflation.

**AC-binding check (applied by `qa-tdd-red` alongside the catalog):** for each test, answer "If I implemented [the AC] incorrectly in some specific way, would this test catch it?" If the answer is "no" or "I can't tell," the test fails AC binding — regardless of whether it matched any catalog pattern.

## First Action

Run the `status` skill to see current pipeline state and what to work on next.
