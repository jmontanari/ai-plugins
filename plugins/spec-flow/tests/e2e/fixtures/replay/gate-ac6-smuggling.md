# Gate AC-6 smuggling fixture — Authored-tests cannot exempt a Red-manifest path
# Scenario: Authored-tests lists a path that is also in the Red-manifest.
# Expected gate behavior: HARD REJECT — exemption ignored (smuggling guard fires).

## Scenario
- phase_N_red_stage_manifest: {tests/unit/test_foo.py, tests/unit/conftest.py}
- Authored-tests: tests/unit/test_foo.py  ← also in Red manifest (smuggling attempt)
- exempt_authored: {tests/unit/test_foo.py}
- Build commit touches: tests/unit/test_foo.py (hash drifts)

## Expected gate (a) outcome
tests/unit/test_foo.py is in BOTH phase_N_red_stage_manifest AND exempt_authored
→ HARD REJECT (smuggling guard — exemption ignored, per T-1 precedence rule)
→ reject (named: tests/unit/test_foo.py), hard stop, no exemption path
