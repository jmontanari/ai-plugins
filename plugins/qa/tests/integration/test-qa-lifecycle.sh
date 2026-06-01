#!/usr/bin/env bash
# test-qa-lifecycle.sh — Integration tests for QA enforcement lifecycle
set -euo pipefail

source "${HOME}/.claude/tests/scripts/test-helpers.sh"

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Test isolation: use temp directories
TEST_STATE_DIR="$(mktemp -d)"
TEST_PLANS_DIR="$(mktemp -d)"
TEST_AUDIT_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_STATE_DIR" "$TEST_PLANS_DIR" "$TEST_AUDIT_DIR"' EXIT

# Override HOME-based paths in hooks via environment
export QA_STATE_DIR="$TEST_STATE_DIR"
export QA_PLANS_DIR="$TEST_PLANS_DIR"
export QA_AUDIT_DIR="$TEST_AUDIT_DIR"
# Provide CLAUDE_ENV_FILE so bootstrap can write to it
CLAUDE_ENV_FILE="$(mktemp)"
export CLAUDE_ENV_FILE

###############################################################################
section "Lifecycle: Bootstrap with [VERIFY] Plan (Tier 1)"
###############################################################################

# Create a plan file with [VERIFY] items
cat > "$TEST_PLANS_DIR/test-plan.md" << 'PLAN'
# Test Plan

## Verification
[VERIFY] Run unit tests
[VERIFY] Run integration tests
PLAN

# Run bootstrap
BOOTSTRAP_OUTPUT=$("$PLUGIN_DIR/hooks/qa-bootstrap.sh" 2>&1) || true

# Check state file was created
if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    pass "Bootstrap created session.json"
else
    fail "Bootstrap did not create session.json"
fi

# Check tier is 1 (has [VERIFY] items)
if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    TIER=$(jq -r '.enforcement_tier' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$TIER" == "1" ]]; then
        pass "Bootstrap set enforcement_tier=1 for [VERIFY] plan"
    else
        fail "Bootstrap set enforcement_tier=$TIER, expected 1"
    fi

    # Check initial state
    QA_PENDING=$(jq -r '.qa_pending' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$QA_PENDING" == "false" ]]; then
        pass "Bootstrap initialized qa_pending=false"
    else
        fail "Bootstrap set qa_pending=$QA_PENDING, expected false"
    fi

    VALIDATED=$(jq -r '.validated' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$VALIDATED" == "false" ]]; then
        pass "Bootstrap initialized validated=false"
    else
        fail "Bootstrap set validated=$VALIDATED, expected false"
    fi
fi

# Check CLAUDE_ENV_FILE was written to
if grep -q 'QA_ENFORCEMENT_TIER' "$CLAUDE_ENV_FILE" 2>/dev/null; then
    pass "Bootstrap exported QA_ENFORCEMENT_TIER to CLAUDE_ENV_FILE"
else
    fail "Bootstrap did not export to CLAUDE_ENV_FILE"
fi

###############################################################################
section "Lifecycle: Implementer Completes"
###############################################################################

# Run post-implementer hook
POST_IMPL_OUTPUT=$("$PLUGIN_DIR/hooks/qa-post-implementer.sh" 2>&1) || true

# Check implementer_count incremented
if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    COUNT=$(jq -r '.implementer_count' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "0")
    if [[ "$COUNT" -ge 1 ]]; then
        pass "Post-implementer incremented count to $COUNT"
    else
        fail "Post-implementer did not increment count (got $COUNT)"
    fi

    # Check qa_pending set
    QA_PENDING=$(jq -r '.qa_pending' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$QA_PENDING" == "true" ]]; then
        pass "Post-implementer set qa_pending=true"
    else
        fail "Post-implementer set qa_pending=$QA_PENDING, expected true"
    fi
fi

###############################################################################
section "Lifecycle: Exit Gate BLOCKS (No Validation)"
###############################################################################

# Run exit gate - should block (exit 2) because tier 1 and not validated
EXIT_CODE=0
"$PLUGIN_DIR/hooks/qa-exit-gate.sh" 2>&1 || EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 2 ]]; then
    pass "Exit gate BLOCKED (exit 2) — no validation done"
else
    fail "Exit gate returned $EXIT_CODE, expected 2 (block)"
fi

###############################################################################
section "Lifecycle: Validator Agent Completes"
###############################################################################

# Run post-validator hook
POST_VAL_OUTPUT=$("$PLUGIN_DIR/hooks/qa-post-validator.sh" 2>&1) || true

# Check validated set
if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    VALIDATED=$(jq -r '.validated' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$VALIDATED" == "true" ]]; then
        pass "Post-validator set validated=true"
    else
        fail "Post-validator set validated=$VALIDATED, expected true"
    fi

    # Check qa_pending cleared
    QA_PENDING=$(jq -r '.qa_pending' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$QA_PENDING" == "false" ]]; then
        pass "Post-validator cleared qa_pending"
    else
        fail "Post-validator set qa_pending=$QA_PENDING, expected false"
    fi
fi

###############################################################################
section "Lifecycle: Exit Gate PASSES (After Validation)"
###############################################################################

# Run exit gate again - should pass now
EXIT_CODE=0
"$PLUGIN_DIR/hooks/qa-exit-gate.sh" 2>&1 || EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]]; then
    pass "Exit gate PASSED (exit 0) — validation complete"
else
    fail "Exit gate returned $EXIT_CODE, expected 0 (pass)"
fi

###############################################################################
section "Lifecycle: Bootstrap Without [VERIFY] (Tier 2)"
###############################################################################

# Clean state
rm -f "$TEST_STATE_DIR/session.json"
rm -f "$TEST_PLANS_DIR/test-plan.md"
: > "$CLAUDE_ENV_FILE"

# Create plan WITHOUT [VERIFY]
cat > "$TEST_PLANS_DIR/test-plan.md" << 'PLAN'
# Simple Plan

## Steps
1. Do something
2. Do something else
PLAN

# Run bootstrap
"$PLUGIN_DIR/hooks/qa-bootstrap.sh" 2>&1 || true

if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    TIER=$(jq -r '.enforcement_tier' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$TIER" == "2" ]]; then
        pass "Bootstrap set enforcement_tier=2 for non-[VERIFY] plan"
    else
        fail "Bootstrap set enforcement_tier=$TIER, expected 2"
    fi
fi

###############################################################################
section "Lifecycle: Exit Gate Suggest-Only (Tier 2)"
###############################################################################

# Simulate implementer work (set qa_pending)
if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    jq '.qa_pending = true | .implementer_count = 1' "$TEST_STATE_DIR/session.json" > "$TEST_STATE_DIR/tmp.json"
    mv "$TEST_STATE_DIR/tmp.json" "$TEST_STATE_DIR/session.json"
fi

EXIT_CODE=0
"$PLUGIN_DIR/hooks/qa-exit-gate.sh" 2>&1 || EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]]; then
    pass "Exit gate suggest-only (exit 0) for tier 2"
else
    fail "Exit gate returned $EXIT_CODE, expected 0 for tier 2"
fi

###############################################################################
section "Lifecycle: Bootstrap No Plans (Tier 3)"
###############################################################################

# Clean everything
rm -f "$TEST_STATE_DIR/session.json"
rm -f "$TEST_PLANS_DIR/"*.md
: > "$CLAUDE_ENV_FILE"

# Run bootstrap with no plans at all
"$PLUGIN_DIR/hooks/qa-bootstrap.sh" 2>&1 || true

if [[ -f "$TEST_STATE_DIR/session.json" ]]; then
    TIER=$(jq -r '.enforcement_tier' "$TEST_STATE_DIR/session.json" 2>/dev/null || echo "unknown")
    if [[ "$TIER" == "3" ]]; then
        pass "Bootstrap set enforcement_tier=3 for no plans"
    else
        fail "Bootstrap set enforcement_tier=$TIER, expected 3"
    fi
fi

###############################################################################
section "Lifecycle: Exit Gate Silent (Tier 3)"
###############################################################################

EXIT_CODE=0
"$PLUGIN_DIR/hooks/qa-exit-gate.sh" 2>&1 || EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]]; then
    pass "Exit gate silent (exit 0) for tier 3"
else
    fail "Exit gate returned $EXIT_CODE, expected 0 for tier 3"
fi

###############################################################################
section "Loop Prevention"
###############################################################################

# Reset to tier 1 blocking state
rm -f "$TEST_STATE_DIR/session.json"
rm -f "$TEST_AUDIT_DIR/"*
: > "$CLAUDE_ENV_FILE"

cat > "$TEST_PLANS_DIR/verify-plan.md" << 'PLAN'
# Plan
[VERIFY] test
PLAN

"$PLUGIN_DIR/hooks/qa-bootstrap.sh" 2>&1 || true

# Block 3 times, 4th should pass (loop prevention)
for i in 1 2 3; do
    "$PLUGIN_DIR/hooks/qa-exit-gate.sh" 2>&1 || true
done

# 4th attempt should NOT block (loop prevention kicks in)
EXIT_CODE=0
"$PLUGIN_DIR/hooks/qa-exit-gate.sh" 2>&1 || EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]]; then
    pass "Loop prevention: 4th attempt passes (max 3 blocks)"
else
    fail "Loop prevention failed: 4th attempt returned $EXIT_CODE, expected 0"
fi

###############################################################################
section "Summary"
###############################################################################

summary
