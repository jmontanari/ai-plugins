#!/usr/bin/env bash
# qa-post-validator.sh — Post-validator QA hook (SubagentStop)
# Sets validated flag, clears qa_pending
set -euo pipefail
trap 'echo "qa-post-validator.sh: unexpected failure at line $LINENO (exit $?)" >&2' ERR

STATE_DIR="${QA_STATE_DIR:-${COPILOT_STATE_DIR:-$HOME/.claude/state/qa}}"
STATE_FILE="$STATE_DIR/session.json"

# Guard: skip if no state
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Set validated and clear qa_pending
TIMESTAMP=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')

jq ".validated = true | .qa_pending = false | .last_validated_at = \"$TIMESTAMP\"" "$STATE_FILE" > "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"

echo "QA validation complete. Exit gate will pass."
