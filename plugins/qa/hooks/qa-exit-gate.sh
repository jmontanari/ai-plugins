#!/usr/bin/env bash
# qa-exit-gate.sh — QA exit gate reminder (Stop)
# Non-blocking: outputs a reminder once per session when validation is pending.
# Stop fires every assistant turn, so blocking (exit 2) is not viable.
set -euo pipefail
trap 'echo "qa-exit-gate.sh: unexpected failure at line $LINENO (exit $?)" >&2' ERR

STATE_DIR="${QA_STATE_DIR:-${COPILOT_STATE_DIR:-$HOME/.claude/state/qa}}"
STATE_FILE="$STATE_DIR/session.json"

# Guard: skip if no state
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

TIER=$(jq -r '.enforcement_tier // 3' "$STATE_FILE" 2>/dev/null || echo "3")
VALIDATED=$(jq -r '.validated // false' "$STATE_FILE" 2>/dev/null || echo "false")
IMPL_COUNT=$(jq -r '.implementer_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")

# Tier 3 or already validated: silent exit
if [[ "$TIER" == "3" ]] || [[ "$VALIDATED" == "true" ]]; then
    exit 0
fi

# Skip if no implementation work yet
if [[ "$IMPL_COUNT" -eq 0 ]]; then
    exit 0
fi

# Debounce: only remind once per session (not every turn)
REMINDED=$(jq -r '.exit_gate_reminded // false' "$STATE_FILE" 2>/dev/null || echo "false")
if [[ "$REMINDED" == "true" ]]; then
    exit 0
fi

# Mark as reminded so we don't fire again
jq '.exit_gate_reminded = true' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

# Non-blocking reminder (exit 0, message to stderr)
echo "QA reminder: $IMPL_COUNT implementation task(s) completed. Run /qa:validate before ending session." >&2
exit 0
