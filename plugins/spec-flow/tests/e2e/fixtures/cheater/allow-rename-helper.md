# Gate allow-rename-helper allow fixture — production helper rename

# Scenario: Build agent renames a production helper not in any Red manifest
# Expected gate behavior: → pass (no false rejection)

## Scenario
- **Change:** `src/math_util.py` renamed to `src/math_helpers.py` via `git mv`
- **Manifest path:** `tests/test_red.py` (unchanged)
- **Expected verdict:** ALLOWED (gate passes)

## Why this should pass
Gate(a) checks only files listed in the Red manifest. `src/math_util.py` is a production
file — it is never listed in the Red manifest (which contains only test files the Red agent
authored). Renaming it does not change the hash of any manifest-listed file.

## Expected gate (a) outcome
`_predicate_gate_a "tests/test_red.py" <original_hash> <repo>` returns 0 because the
test file was not touched. The rename of a production file is invisible to gate(a).
