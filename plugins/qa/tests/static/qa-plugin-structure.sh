#!/usr/bin/env bash
# qa-plugin-structure.sh — Test suite for QA plugin marketplace structure
set -euo pipefail

# Source test helpers from Claude protocol test infrastructure
source "${HOME}/.claude/tests/scripts/test-helpers.sh"

# Plugin and repo directories
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_DIR="$(cd "$PLUGIN_DIR/../.." && pwd)"

###############################################################################
section "Setup and Initialization"
###############################################################################

if [[ ! -d "$PLUGIN_DIR" ]]; then
    fail "QA plugin directory not found: $PLUGIN_DIR"
    exit 1
fi
pass "QA plugin directory exists: $PLUGIN_DIR"

###############################################################################
section "Marketplace Structure"
###############################################################################

# Root marketplace manifest
if [[ -f "$REPO_DIR/.claude-plugin/marketplace.json" ]]; then
    pass "Marketplace manifest exists: .claude-plugin/marketplace.json"
else
    fail "Missing marketplace manifest: .claude-plugin/marketplace.json"
fi

if jq empty "$REPO_DIR/.claude-plugin/marketplace.json" 2>/dev/null; then
    pass "marketplace.json is valid JSON"
else
    fail "marketplace.json is not valid JSON"
fi

# Check marketplace lists qa plugin
if jq -e '.plugins[] | select(.name == "qa")' "$REPO_DIR/.claude-plugin/marketplace.json" >/dev/null 2>&1; then
    pass "marketplace.json lists qa plugin"
else
    fail "marketplace.json does not list qa plugin"
fi

###############################################################################
section "Plugin Manifest (Official Format)"
###############################################################################

MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ -f "$MANIFEST" ]]; then
    pass "Plugin manifest exists: .claude-plugin/plugin.json"
else
    fail "Missing plugin manifest: .claude-plugin/plugin.json"
fi

if jq empty "$MANIFEST" 2>/dev/null; then
    pass "plugin.json is valid JSON"
else
    fail "plugin.json is not valid JSON"
fi

# Required fields (official schema)
for field in name description version author; do
    if jq -e ".$field" "$MANIFEST" >/dev/null 2>&1; then
        pass "plugin.json has field: $field"
    else
        fail "plugin.json missing required field: $field"
    fi
done

# No old 'provides' field
if jq -e '.provides' "$MANIFEST" >/dev/null 2>&1; then
    fail "plugin.json still has old 'provides' field (should use official schema)"
else
    pass "plugin.json uses official schema (no 'provides' field)"
fi

NAME=$(jq -r '.name' "$MANIFEST")
if [[ "$NAME" == "qa" ]]; then
    pass "Plugin name is correct: qa"
else
    fail "Plugin name incorrect: expected 'qa', got '$NAME'"
fi

###############################################################################
section "Directory Structure"
###############################################################################

# Required directories
for dir in agents skills hooks tests; do
    if [[ -d "$PLUGIN_DIR/$dir" ]]; then
        pass "Directory exists: $dir"
    else
        fail "Missing directory: $dir"
    fi
done

# Skill directories (new names)
for skill_dir in validate attack-plan spot-check; do
    if [[ -d "$PLUGIN_DIR/skills/$skill_dir" ]]; then
        pass "Skill directory exists: skills/$skill_dir"
    else
        fail "Missing skill directory: skills/$skill_dir"
    fi
done

# No old skill directory names
for old_dir in qa-validate qa-attack-plan qa-spot-check qa-router; do
    if [[ -d "$PLUGIN_DIR/skills/$old_dir" ]]; then
        fail "Old skill directory still exists: skills/$old_dir"
    else
        pass "Old skill directory removed: skills/$old_dir"
    fi
done

# No old rules directory
if [[ -d "$PLUGIN_DIR/rules" ]]; then
    fail "Old rules/ directory still exists (content should be embedded in agent/skills)"
else
    pass "No rules/ directory (content embedded in agent/skills)"
fi

###############################################################################
section "Required Files"
###############################################################################

# Agent file
if [[ -f "$PLUGIN_DIR/agents/validator-agent.md" ]]; then
    pass "agents/validator-agent.md exists"
else
    fail "agents/validator-agent.md not found"
fi

# Skill SKILL.md files
for skill in validate attack-plan spot-check; do
    if [[ -f "$PLUGIN_DIR/skills/$skill/SKILL.md" ]]; then
        pass "skills/$skill/SKILL.md exists"
    else
        fail "skills/$skill/SKILL.md not found"
    fi
done

# Hooks
if [[ -f "$PLUGIN_DIR/hooks/hooks.json" ]]; then
    pass "hooks/hooks.json exists"
else
    fail "hooks/hooks.json not found"
fi

if jq empty "$PLUGIN_DIR/hooks/hooks.json" 2>/dev/null; then
    pass "hooks.json is valid JSON"
else
    fail "hooks.json is not valid JSON"
fi

# README
if [[ -f "$PLUGIN_DIR/README.md" ]]; then
    pass "README.md exists"
else
    fail "README.md not found"
fi

###############################################################################
section "Hooks Configuration"
###############################################################################

HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"

# Lifecycle hooks exist
if jq -e '.hooks.SessionStart' "$HOOKS_JSON" >/dev/null 2>&1; then
    pass "hooks.json has SessionStart hook"
else
    fail "hooks.json missing SessionStart hook"
fi

if jq -e '.hooks.SubagentStop' "$HOOKS_JSON" >/dev/null 2>&1; then
    pass "hooks.json has SubagentStop hook"
else
    fail "hooks.json missing SubagentStop hook"
fi

if jq -e '.hooks.Stop' "$HOOKS_JSON" >/dev/null 2>&1; then
    pass "hooks.json has Stop hook"
else
    fail "hooks.json missing Stop hook"
fi

# Hook scripts exist
for script in qa-bootstrap.sh qa-post-implementer.sh qa-post-validator.sh qa-exit-gate.sh; do
    if [[ -f "$PLUGIN_DIR/hooks/$script" ]]; then
        pass "Hook script exists: $script"
    else
        fail "Missing hook script: $script"
    fi
done

# hooks.json uses portable ${CLAUDE_PLUGIN_ROOT}
if grep -q 'CLAUDE_PLUGIN_ROOT' "$HOOKS_JSON"; then
    pass "hooks.json uses \${CLAUDE_PLUGIN_ROOT} for portable paths"
else
    fail "hooks.json does not use \${CLAUDE_PLUGIN_ROOT}"
fi

# hooks.json does NOT use PLUGIN_DIR
if ! grep -q 'PLUGIN_DIR' "$HOOKS_JSON" 2>/dev/null; then
    pass "hooks.json has no \$PLUGIN_DIR references"
else
    fail "hooks.json contains \$PLUGIN_DIR references (should use \${CLAUDE_PLUGIN_ROOT})"
fi

# No inline echo commands (all script-backed)
if ! grep -q '"echo ' "$HOOKS_JSON" 2>/dev/null; then
    pass "hooks.json has no inline echo commands (all script-backed)"
else
    fail "hooks.json still has inline echo commands"
fi

###############################################################################
section "Skill Frontmatter"
###############################################################################

for skill_dir in validate attack-plan spot-check; do
    SKILL_FILE="$PLUGIN_DIR/skills/$skill_dir/SKILL.md"

    # Map directory name to skill name
    case "$skill_dir" in
        validate) expected_name="qa-validate" ;;
        attack-plan) expected_name="qa-attack-plan" ;;
        spot-check) expected_name="qa-spot-check" ;;
    esac

    if grep -q "^name: $expected_name" "$SKILL_FILE"; then
        pass "Skill $skill_dir has name: $expected_name"
    else
        fail "Skill $skill_dir missing or incorrect name frontmatter"
    fi

    if grep -q "^user-invocable: true" "$SKILL_FILE"; then
        pass "Skill $skill_dir is user-invocable"
    else
        fail "Skill $skill_dir should be user-invocable"
    fi
done

###############################################################################
section "Namespace Verification"
###############################################################################

# No old-style command references in plugin files
OLD_REFS_FOUND=0
for pattern in "/qa-validate" "/qa-attack-plan" "/qa-spot-check"; do
    if grep -rn "$pattern" "$PLUGIN_DIR/" --include="*.md" --include="*.json" 2>/dev/null | grep -v "^Binary" | head -3; then
        fail "Old namespace reference found: $pattern"
        OLD_REFS_FOUND=1
    fi
done

if [[ $OLD_REFS_FOUND -eq 0 ]]; then
    pass "No old-style /qa-{name} references in plugin files"
fi

# New-style references exist
for pattern in "/qa-validate" "/qa-attack-plan" "/qa-spot-check"; do
    if grep -rq "$pattern" "$PLUGIN_DIR/skills/" 2>/dev/null; then
        pass "New namespace reference found: $pattern"
    else
        fail "Missing new namespace reference: $pattern"
    fi
done

###############################################################################
section "Embedded QA Content (Self-Contained Plugin)"
###############################################################################

AGENT="$PLUGIN_DIR/agents/validator-agent.md"

# qa-triggers.md content embedded in validator-agent.md
if grep -q "Test Failure Investigation" "$AGENT"; then
    pass "validator-agent.md has Test Failure Investigation (from qa-triggers.md)"
else
    fail "validator-agent.md missing Test Failure Investigation"
fi

if grep -q "Concern Fix Validation Pattern" "$AGENT"; then
    pass "validator-agent.md has Concern Fix Validation Pattern (from qa-triggers.md)"
else
    fail "validator-agent.md missing Concern Fix Validation Pattern"
fi

if grep -q "Verification Delta" "$AGENT"; then
    pass "validator-agent.md has Verification Delta (from qa-triggers.md)"
else
    fail "validator-agent.md missing Verification Delta"
fi

# Plan verification binding in validate skill
VALIDATE_SKILL="$PLUGIN_DIR/skills/validate/SKILL.md"
if grep -q "Plan Verification Binding" "$VALIDATE_SKILL"; then
    pass "validate skill has Plan Verification Binding (from qa-triggers.md)"
else
    fail "validate skill missing Plan Verification Binding"
fi

###############################################################################
section "Agent Integrity"
###############################################################################

# Paranoid philosophy
if grep -qi "paranoid" "$AGENT"; then
    pass "validator-agent mentions paranoid philosophy"
else
    fail "validator-agent missing paranoid philosophy"
fi

# 4 dimensions
for dimension in MISSING BROKEN FRAGILE EXPLOITABLE; do
    if grep -q "$dimension" "$AGENT"; then
        pass "validator-agent includes dimension: $dimension"
    else
        fail "validator-agent missing dimension: $dimension"
    fi
done

# Modes
for mode in "MODE: VERIFY" "MODE: ATTACK-PLAN" "MODE: SPOT-CHECK" "MODE: RE-VERIFY"; do
    if grep -q "$mode" "$AGENT"; then
        pass "validator-agent defines mode: $mode"
    else
        fail "validator-agent missing mode: $mode"
    fi
done

# Required frontmatter
if grep -q "^name: validator-agent" "$AGENT"; then
    pass "validator-agent has correct name frontmatter"
else
    fail "validator-agent missing name frontmatter"
fi

if grep -q "^model: sonnet" "$AGENT"; then
    pass "validator-agent specifies model: sonnet"
else
    fail "validator-agent should specify model: sonnet"
fi

# BM-free: no Basic Memory tools
BM_TOOLS=("write_note" "edit_note" "search_notes" "read_note")
FOUND_BM=0
for bm_tool in "${BM_TOOLS[@]}"; do
    if grep -qi "$bm_tool" "$AGENT" 2>/dev/null; then
        fail "validator-agent contains Basic Memory tool: $bm_tool"
        FOUND_BM=1
    fi
done
if [[ $FOUND_BM -eq 0 ]]; then
    pass "validator-agent is BM-free (no Basic Memory tools)"
fi

###############################################################################
section "Summary"
###############################################################################

summary
