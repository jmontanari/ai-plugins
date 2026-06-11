# plan fixture — AC-6 qa-plan no-field scenario (conditional-absence)
# Scenario: Phase has no **Authored-tests:** field at all.
# Expected qa-plan criterion 32 outcome: no finding (absence is never a finding).

tdd: false

### Phase 1 — config wiring [Implement]

- [ ] **[Implement]** Wire `src/config.py`.

    **[Verify]** `grep -q greet src/config.py` → exit 0
