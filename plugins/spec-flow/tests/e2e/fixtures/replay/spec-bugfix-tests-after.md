# Scenario: regression spec commits to tests-after (tdd:false without red-first obligation).
# Expected qa-spec criterion 18 outcome: must-fix.

## Goal

Fix a login regression: broken behavior (login fails for valid users) no longer happens.

## Acceptance Criteria

- AC-1: Login succeeds for valid users (regression: broken behavior no longer happens).

## Testing Strategy

tdd: false
Tests are written after the fix; red-first is not required.
