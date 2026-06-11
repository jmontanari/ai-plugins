# tdd-red Phase 2 manifest fixture — conftest enrichment
# Represents a tdd-red agent's ## Staged test manifest output after Phase 2
# enrichment: the manifest now includes directly-imported fixture/helper files
# and same-tree conftest.py files as protected paths.
# Used by check_red_manifest_conftest (AC-4 manifest half) and Phase 3 trip test (AC-4 trip half).

## Staged test manifest
- tests/unit/test_foo.py: a3f5c891bcd234567890abcdef012345a3f5c891bcd234567890abcdef012345
- tests/unit/conftest.py: 9c2e5f3abcd456789012abcdef3456789c2e5f3abcd456789012abcdef345678 (conftest.py — consumed by tests in this directory)
- tests/unit/_helpers.py: 4d8a1b7cdef0901234abcdef567890124d8a1b7cdef0901234abcdef56789012 (directly imported by test_foo.py)
