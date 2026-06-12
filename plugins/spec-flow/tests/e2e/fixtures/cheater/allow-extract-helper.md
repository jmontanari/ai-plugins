# Gate allow-extract-helper allow fixture — extracting a production helper function

# Scenario: Build agent extracts a validation helper into a new module during refactor
# Expected gate behavior: → pass (no false rejection)

## Scenario
- **Change:** `src/math_util.py` refactored to import from new `src/_helpers.py`; `src/_helpers.py` created with `_validate()` function
- **Manifest path:** `tests/test_red.py` (unchanged)
- **Expected verdict:** ALLOWED (gate passes)

## Why this should pass
Gate(a) checks only Red manifest files. `src/_helpers.py` is a new production module;
`src/math_util.py` is an existing production file. Neither is in the Red manifest.
The Red test file `tests/test_red.py` was not modified.

## Expected gate (a) outcome
`_predicate_gate_a "tests/test_red.py" <original_hash> <repo>` returns 0. Production
refactoring — even when it creates new files or rewrites existing ones — is invisible to
gate(a) as long as no manifest-listed test file is touched.
