# Scenario: regression spec commits to red-first (tdd:true, red-first obligation present).
# Expected qa-spec criterion 18 outcome: clean.

## Goal

Fix a login regression: broken behavior (login fails for valid users) no longer happens.

## Acceptance Criteria

- AC-1: Login succeeds for valid users (regression: broken behavior no longer happens) [outcome:result].

## Testing Strategy

tdd: true (red-first: reproduce the regression with a failing test before fixing — NN-P-006).
