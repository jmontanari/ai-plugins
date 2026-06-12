# Gate allow-reformat-production allow fixture — production file reformatting

# Scenario: Build agent reformats a production file (adds docstring, blank lines)
# Expected gate behavior: → pass (no false rejection)

## Scenario
- **Change:** `src/math_util.py` reformatted with added docstring and blank lines; test file untouched
- **Manifest path:** `tests/test_red.py` (unchanged)
- **Expected verdict:** ALLOWED (gate passes)

## Why this should pass
Gate(a) pins hashes on Red manifest files (test files), not on production source files.
Reformatting `src/math_util.py` does not change the hash of `tests/test_red.py`.
This is a legitimate code quality improvement the Build agent may apply.

## Expected gate (a) outcome
`_predicate_gate_a "tests/test_red.py" <original_hash> <repo>` returns 0. The production
file's hash is not checked by gate(a) — only manifest-listed test files are checked.
