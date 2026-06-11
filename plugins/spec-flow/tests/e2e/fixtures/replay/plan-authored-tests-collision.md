# plan fixture — AC-6 qa-plan collision scenario
# Scenario: **Authored-tests:** lists a path that also appears in [TDD-Red].
# Expected qa-plan criterion 32(b) outcome: must-fix (smuggling — collision with Red-manifest path).

tdd: true

### Phase 1 — greet implementation [TDD]

- [ ] **[TDD-Red]** Write failing test for greet behavior.
    tests/unit/test_greet.py

    **Test Data:**
    - g-1: input "world" → expect "hello, world"

    **[Verify]** `pytest tests/unit/test_greet.py` → exit 0

### Phase 2 — config wiring [Implement]

- [ ] **[Implement]** Wire `src/config.py`.
    **Authored-tests:** tests/unit/test_greet.py
    <!-- COLLISION: test_greet.py was Red-authored in Phase 1 — criterion 32(b) must-fix -->

    **[Verify]** `grep -q greet src/config.py` → exit 0
