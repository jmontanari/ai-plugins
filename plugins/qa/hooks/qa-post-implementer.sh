#!/usr/bin/env bash
# qa-post-implementer.sh — Post-implementer QA hook (SubagentStop)
# Increments implementer count, sets qa_pending flag, outputs QA directive
set -euo pipefail
trap 'echo "qa-post-implementer.sh: unexpected failure at line $LINENO (exit $?)" >&2' ERR

STATE_DIR="${QA_STATE_DIR:-${COPILOT_STATE_DIR:-$HOME/.claude/state/qa}}"
STATE_FILE="$STATE_DIR/session.json"

# Guard: skip if no state (bootstrap didn't run or tier 3)
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

TIER=$(jq -r '.enforcement_tier // 3' "$STATE_FILE" 2>/dev/null || echo "3")
if [[ "$TIER" == "3" ]]; then
    exit 0
fi

# Increment implementer count and set qa_pending
CURRENT_COUNT=$(jq -r '.implementer_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")
NEW_COUNT=$((CURRENT_COUNT + 1))

jq ".implementer_count = $NEW_COUNT | .qa_pending = true" "$STATE_FILE" > "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"

# Output QA directive
echo "Implementation task #$NEW_COUNT complete. QA validation pending — run /qa:validate before session exit."
