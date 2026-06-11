# Gate AC-4 trip fixture — conftest.py in manifest is protected
# Scenario: Build commit edits a manifest-listed conftest.py.
# Expected gate behavior: integrity fail — conftest.py named in reject.
# Cross-checks: tdd-red manifest fixture (Phase 2, AC-4 manifest half).

## Scenario
- phase_N_red_stage_manifest: {tests/unit/test_foo.py, tests/unit/conftest.py, tests/unit/_helpers.py}
- Authored-tests: (none — TDD phase)
- exempt_authored: ∅
- Build commit touches: tests/unit/conftest.py (hash drifts)

## Expected gate (a) outcome
integrity fail: tests/unit/conftest.py
→ reject (fixture enrichment path is not in exempt_authored; hard stop)
