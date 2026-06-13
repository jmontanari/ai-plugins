# Scenario: bug-fix/regression phase uses red-first track under tdd:true.
# Expected qa-plan criterion 34 outcome: clean (red-first).

tdd: true

### Phase 1: fix login regression

**ACs Covered:** AC-1
**Phase type:** regression

- [ ] **[TDD-Red]** Write a failing test reproducing the regression.
    **Test Data:**
    - g-1: broken login input → expect authentication failure
- [ ] **[Build]** Fix the regression.
- [ ] **[Verify]** Run tests.
