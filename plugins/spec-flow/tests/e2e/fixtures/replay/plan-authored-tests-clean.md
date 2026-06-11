# plan fixture — AC-6 qa-plan clean scenario
# Scenario: **Authored-tests:** lists a path cited in the phase body, no collision.
# Expected qa-plan criterion 32 outcome: no finding (valid declaration).

tdd: false

### Phase 1 — config wiring [Implement]

- [ ] **[Implement]** Wire `src/config.py` and author a test for it.

    **Authored-tests:** tests/unit/test_config.py

    **[Verify]** `pytest tests/unit/test_config.py` → exit 0

    **[Write-Tests]** Author `tests/unit/test_config.py`.

    **Test Data:**
    - c-1: input config key "greet_suffix" → expect "hello"
