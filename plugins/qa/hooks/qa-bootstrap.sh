#!/usr/bin/env bash
# qa-bootstrap.sh — QA enforcement bootstrap (SessionStart)
# Scans plans for [VERIFY] items, sets enforcement tier, initializes state
set -euo pipefail
trap 'echo "qa-bootstrap.sh: unexpected failure at line $LINENO (exit $?)" >&2' ERR

# Cross-tool compatible: check QA_STATE_DIR, then Copilot path, then Claude path
STATE_DIR="${QA_STATE_DIR:-${COPILOT_STATE_DIR:-$HOME/.claude/state/qa}}"
PLANS_DIR="${QA_PLANS_DIR:-${COPILOT_PLANS_DIR:-$HOME/.claude/plans}}"
STATE_FILE="$STATE_DIR/session.json"

mkdir -p "$STATE_DIR"

# Determine enforcement tier by scanning plan files for [VERIFY]
TIER=3  # Default: silent (no plans)

if [[ -d "$PLANS_DIR" ]] && ls "$PLANS_DIR"/*.md >/dev/null 2>&1; then
    # Plans exist — check for [VERIFY] markers
    if grep -rl '\[VERIFY\]' "$PLANS_DIR"/*.md >/dev/null 2>&1; then
        TIER=1  # Block: [VERIFY] items found
    else
        TIER=2  # Suggest: plans exist but no [VERIFY]
    fi
fi

# Initialize session state
cat > "$STATE_FILE" << EOF
{
  "enforcement_tier": $TIER,
  "implementer_count": 0,
  "qa_pending": false,
  "validated": false,
  "last_validated_at": null
}
EOF

# Export tier to session environment (Claude Code only — no Copilot equivalent)
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "export QA_ENFORCEMENT_TIER=$TIER" >> "$CLAUDE_ENV_FILE"
fi

# Output tier info for context injection (works in both Claude and Copilot)
case $TIER in
    1) echo "QA Enforcement: Tier 1 (block) — [VERIFY] items found. Exit gate will block until /qa-validate passes." ;;
    2) echo "QA Enforcement: Tier 2 (suggest) — Plans found but no [VERIFY] items. Will suggest validation at exit." ;;
    3) ;; # Silent — no output
esac
