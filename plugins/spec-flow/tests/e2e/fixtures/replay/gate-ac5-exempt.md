# Gate AC-5 exempt fixture — Authored-tests passes reconciliation
# Scenario: Implement-track phase with **Authored-tests:** declaring the test it writes.
# Expected gate behavior: reconciliation passes — declared authored test is not a stray file.

## Scenario
- phase_N_red_stage_manifest: (none — Implement-track, no Red phase)
- Authored-tests: tests/unit/test_bar.py
- exempt_authored: {tests/unit/test_bar.py}
- Build commit creates: tests/unit/test_bar.py, src/bar.py

## Expected gate (b) outcome
expected = Build's Files Created/Modified ∪ exempt_authored
         = {tests/unit/test_bar.py, src/bar.py} ∪ {tests/unit/test_bar.py}
         = {tests/unit/test_bar.py, src/bar.py}
commit file list = {tests/unit/test_bar.py, src/bar.py}
→ pass (no stray file, no missing file; declared authored test whitelisted)
