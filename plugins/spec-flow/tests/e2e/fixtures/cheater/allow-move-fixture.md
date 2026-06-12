# Gate allow-move-fixture allow fixture — moving a non-manifest fixture file

# Scenario: Build agent moves a test fixture data file to a subdirectory
# Expected gate behavior: → pass (no false rejection)

## Scenario
- **Change:** A new fixture file `tests/fixtures/data.txt` added (non-manifest helper)
- **Manifest path:** `tests/test_red.py` (unchanged)
- **Expected verdict:** ALLOWED (gate passes)

## Why this should pass
Gate(a) checks only files in the Red manifest. A fixture data file (`tests/fixtures/data.txt`)
added or moved by the Build agent is not in the Red manifest. The Red test file itself is
not modified, so its hash is stable.

## Expected gate (a) outcome
`_predicate_gate_a "tests/test_red.py" <original_hash> <repo>` returns 0. Non-manifest
fixture files are outside the scope of the content-hash integrity check.
