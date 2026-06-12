# Gate allow-new-test allow fixture — adding a new test not in the Red manifest

# Scenario: Build agent adds an additional test file alongside the Red manifest tests
# Expected gate behavior: → pass (no false rejection)

## Scenario
- **Change:** `tests/test_new.py` added with a new test case (`test_sub`)
- **Manifest path:** `tests/test_red.py` (unchanged)
- **Expected verdict:** ALLOWED (gate passes)

## Why this should pass
Gate(a) only checks files explicitly listed in the Red manifest. `tests/test_new.py` is
a new file added by the Build agent — it is not in the manifest, so no hash comparison
is triggered for it. The Red manifest test `tests/test_red.py` was not modified, so its
hash still matches.

## Expected gate (a) outcome
`_predicate_gate_a "tests/test_red.py" <original_hash> <repo>` returns 0 because only the
manifest-listed file is checked. Extra test files added by Build are allowed.
