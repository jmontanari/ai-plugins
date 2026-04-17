# TDD Doctrine

This document governs all implementation work in the TDD Pipeline. It is loaded automatically at session start and referenced by all agent prompts.

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
- Detect over-engineering: did the builder add code beyond what tests require?
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
| Minimal implementation only | Verify agent checks for over-engineering beyond test requirements |
| No test modification to pass | Orchestrator diffs test files between Red and Verify — modified tests = rejection |
| Circuit breaker | 2 failed build attempts → escalate to human |
| No mock abuse | Real object > fake > stub > mock. Agent must justify any mock in report |
| Full error feedback | Failed test output passed verbatim to next agent — no summarizing |
| No agent cheating | Hard-coded return values, over-fitted tests, trivial implementations flagged by QA |
| Refactor scope | Refactor agent may only touch files created/changed in current phase |

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

## First Action

Run the `status` skill to see current pipeline state and what to work on next.
