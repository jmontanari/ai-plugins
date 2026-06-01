#!/usr/bin/env bash
# test-qa-hooks.sh — Unit tests for QA enforcement hook scripts
set -euo pipefail

source "${HOME}/.claude/tests/scripts/test-helpers.sh"

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

###############################################################################
section "Hook Scripts Exist and Are Executable"
###############################################################################

for script in qa-bootstrap.sh qa-post-implementer.sh qa-post-validator.sh qa-exit-gate.sh; do
    if [[ -f "$PLUGIN_DIR/hooks/$script" ]]; then
        pass "Hook script exists: $script"
    else
        fail "Hook script missing: $script"
    fi

    if [[ -x "$PLUGIN_DIR/hooks/$script" ]]; then
        pass "Hook script is executable: $script"
    else
        fail "Hook script not executable: $script"
    fi
done

###############################################################################
section "Hook Scripts Have Required Boilerplate"
###############################################################################

for script in qa-bootstrap.sh qa-post-implementer.sh qa-post-validator.sh qa-exit-gate.sh; do
    FILE="$PLUGIN_DIR/hooks/$script"
    [[ -f "$FILE" ]] || continue

    if head -1 "$FILE" | grep -q "^#!/usr/bin/env bash"; then
        pass "$script has bash shebang"
    else
        fail "$script missing bash shebang"
    fi

    if grep -q "set -euo pipefail" "$FILE"; then
        pass "$script has set -euo pipefail"
    else
        fail "$script missing set -euo pipefail"
    fi
done

###############################################################################
section "qa-bootstrap.sh Content"
###############################################################################

BOOTSTRAP="$PLUGIN_DIR/hooks/qa-bootstrap.sh"
if [[ -f "$BOOTSTRAP" ]]; then
    # Scans for [VERIFY] in plan files
    if grep -q '\[VERIFY\]' "$BOOTSTRAP"; then
        pass "qa-bootstrap.sh scans for [VERIFY]"
    else
        fail "qa-bootstrap.sh does not scan for [VERIFY]"
    fi

    # References CLAUDE_ENV_FILE for tier export
    if grep -q 'CLAUDE_ENV_FILE' "$BOOTSTRAP"; then
        pass "qa-bootstrap.sh references CLAUDE_ENV_FILE"
    else
        fail "qa-bootstrap.sh does not reference CLAUDE_ENV_FILE"
    fi

    # Outputs tier information
    if grep -q 'enforcement_tier\|ENFORCEMENT_TIER\|tier' "$BOOTSTRAP"; then
        pass "qa-bootstrap.sh references tier"
    else
        fail "qa-bootstrap.sh does not reference tier"
    fi

    # State directory creation
    if grep -q 'state/qa' "$BOOTSTRAP"; then
        pass "qa-bootstrap.sh uses state/qa directory"
    else
        fail "qa-bootstrap.sh does not use state/qa directory"
    fi

    # Initializes session.json state file
    if grep -q 'session.json' "$BOOTSTRAP"; then
        pass "qa-bootstrap.sh initializes session.json"
    else
        fail "qa-bootstrap.sh does not initialize session.json"
    fi
fi

###############################################################################
section "qa-post-implementer.sh Content"
###############################################################################

POST_IMPL="$PLUGIN_DIR/hooks/qa-post-implementer.sh"
if [[ -f "$POST_IMPL" ]]; then
    # Increments counter
    if grep -q 'implementer_count' "$POST_IMPL"; then
        pass "qa-post-implementer.sh tracks implementer_count"
    else
        fail "qa-post-implementer.sh does not track implementer_count"
    fi

    # Sets qa_pending
    if grep -q 'qa_pending' "$POST_IMPL"; then
        pass "qa-post-implementer.sh sets qa_pending"
    else
        fail "qa-post-implementer.sh does not set qa_pending"
    fi

    # Outputs directive
    if grep -q 'QA\|qa-validate\|validator' "$POST_IMPL"; then
        pass "qa-post-implementer.sh outputs QA directive"
    else
        fail "qa-post-implementer.sh does not output QA directive"
    fi
fi

###############################################################################
section "qa-post-validator.sh Content"
###############################################################################

POST_VAL="$PLUGIN_DIR/hooks/qa-post-validator.sh"
if [[ -f "$POST_VAL" ]]; then
    # Sets validated
    if grep -q 'validated' "$POST_VAL"; then
        pass "qa-post-validator.sh sets validated flag"
    else
        fail "qa-post-validator.sh does not set validated flag"
    fi

    # Clears qa_pending
    if grep -q 'qa_pending' "$POST_VAL"; then
        pass "qa-post-validator.sh clears qa_pending"
    else
        fail "qa-post-validator.sh does not clear qa_pending"
    fi
fi

###############################################################################
section "qa-exit-gate.sh Content"
###############################################################################

EXIT_GATE="$PLUGIN_DIR/hooks/qa-exit-gate.sh"
if [[ -f "$EXIT_GATE" ]]; then
    # Loop prevention
    if grep -q 'attempt\|ATTEMPT\|loop\|max_block\|MAX_BLOCK' "$EXIT_GATE"; then
        pass "qa-exit-gate.sh has loop prevention"
    else
        fail "qa-exit-gate.sh missing loop prevention"
    fi

    # Checks validation state
    if grep -q 'validated' "$EXIT_GATE"; then
        pass "qa-exit-gate.sh checks validated state"
    else
        fail "qa-exit-gate.sh does not check validated state"
    fi

    # Uses exit 2 for blocking
    if grep -q 'exit 2' "$EXIT_GATE"; then
        pass "qa-exit-gate.sh uses exit 2 for blocking"
    else
        fail "qa-exit-gate.sh missing exit 2 blocking"
    fi

    # Tier-based enforcement
    if grep -q 'enforcement_tier\|ENFORCEMENT_TIER\|tier' "$EXIT_GATE"; then
        pass "qa-exit-gate.sh has tier-based enforcement"
    else
        fail "qa-exit-gate.sh missing tier-based enforcement"
    fi
fi

###############################################################################
section "Summary"
###############################################################################

summary
