---
name: qa-spot-check
user-invocable: true
description: >
  Quick targeted QA checks without full ceremony. Use for focused concerns — a single function, a specific edge case, one integration point — when full qa-validate would be overkill. Trigger when the user asks to "check this", "does this look right", or wants a quick second opinion on a specific piece of code or behavior.
argument-hint: "file path or component to check"
---

# /qa:spot-check: Quick Targeted Checks

## Purpose

This skill performs quick targeted QA checks during implementation. It's lighter-weight than `/qa:validate` (no full ceremony).

**When to use:**
- After an implementer completes a file
- To check a specific function or config
- During development (not just at exit gate)
- Automated via SubagentStop hook (optional, disabled by default)

**When NOT to use:**
- For exit gate validation (use `/qa:validate`)
- For pre-implementation plan review (use `/qa:attack-plan`)

## How It Works

1. **Identify target**: User specifies file, function, config, or script to check
2. **Determine focus**: Select focus areas based on target type
3. **Spawn validator-agent**: Pass MODE: SPOT-CHECK with target info
4. **Display findings**: Show concise list of issues found

## Target Types

| Type | Focus Areas |
|------|-------------|
| **File** | Bugs, edge cases, error handling, security issues |
| **Function** | Input validation, error paths, boundary conditions, return values |
| **Config** | Insecure defaults, missing required fields, validation, documentation |
| **Script** | Unhandled errors, unsafe operations (rm, mv), idempotency, rollback |
| **Test** | Assertion substance, implementation alignment, theater patterns, coverage gaps |

## Instructions for Lead

When user invokes `/qa:spot-check [target]` or SubagentStop hook triggers:

1. **Parse target** from user input or detect from git diff (for hook trigger)
2. **Determine target type**:
   - `.sh`, `.bash` → Script
   - `.json`, `.yaml`, `.toml`, `.conf` → Config
   - `.py`, `.js`, `.ts`, `.go` → File (check for function if user specifies)
   - User explicitly says "function" → Function
   - `test_*.py`, `*_test.py`, `*_test.go`, `*.test.ts` → Test
3. **Select focus areas** based on target type (see table above)
4. **Format Task prompt** for validator-agent:
   ```
   MODE: SPOT-CHECK

   ## Target
   Type: [file|function|config|script]
   Path: [absolute path to target]

   ## Focus Areas
   [Comma-separated list based on target type]

   ## Instructions
   Quick targeted review. NO full ceremony — no 4-dimension assessment, no assumption challenge.

   Return concise findings list (3-10 items):
   - What looks wrong or risky
   - Evidence (line numbers, code snippets, tool output)
   - Quick recommendation

   Keep it brief. This is a spot check, not full validation.
   ```
5. **Spawn validator-agent** with the formatted work order
6. **Parse findings** from validator output
7. **Present to user** in organized list format
8. **Extract corrective actions** from validator output (Step 8 below)
9. **Classify and create tasks** from corrective actions (Step 9 below)

## Work Order Template

```
MODE: SPOT-CHECK

## Target
Type: [file|function|config|script]
Path: [absolute path to target]

## Focus Areas
[Based on target type, e.g.:]
- For file: bugs, edge cases, error handling, security issues
- For function: input validation, error paths, boundary conditions
- For config: insecure defaults, missing fields, validation
- For script: unhandled errors, unsafe ops, idempotency
- For test: assertion substance, theater patterns, alignment with implementation, mock abuse

## Instructions
Quick targeted review. NO full ceremony — no 4-dimension assessment, no assumption challenge.

Return concise findings list (3-10 items):
- What looks wrong or risky
- Evidence (line numbers, code snippets, tool output)
- Quick recommendation

Keep it brief. This is a spot check, not full validation.
```

## Corrective Action Pipeline

After presenting findings (step 7), extract and act on corrective actions.

### Step 8: Extract Corrective Actions

Parse validator output between `<!-- CORRECTIVE_ACTIONS_START -->` and `<!-- CORRECTIVE_ACTIONS_END -->` markers. Parse the JSON array. If markers not found or array is empty, skip (no corrective actions needed). If JSON parsing fails, log warning and skip (non-blocking).

### Step 9: Classify and Create Tasks

**Identify changed files:** Run `git diff --name-only main...HEAD` plus `git ls-files --others --exclude-standard`. This is the "changed files set."

Edge cases:
- No git / not a repo → treat ALL findings as current-work (conservative)
- Empty diff → treat ALL findings as pre-existing
- `main` doesn't exist → try `master`, then fall back to `HEAD~1`

**Classify each action:**
- **current-work**: Any `affected_file` in the changed files set
- **pre-existing**: No `affected_files` in the changed files set
- **UNKNOWN files**: classify as current-work (conservative)

**Create tasks for current-work HIGH/MEDIUM items:**
- TaskCreate with subject: `[QA-{id}] {title}`
- Description: dimension, severity, affected files, recommended fix
- activeForm: `Fixing {title}`

**Triage pre-existing issues:** Present to user as a bulleted list:

```
Pre-existing issues (not in your changes):
- [{severity}] {title} ({files}) — fix / defer / ignore?
Bulk: fix all / defer all / ignore all
```

Create tasks for user-selected "fix" items.

**Display summary** (lighter than validate — just a bullet list):
- Created N tasks for current-work issues
- Created M tasks from user triage
- Deferred P items, ignored Q items

## Example Invocations

### Manual Invocation

**User input:**
```
/qa:spot-check scripts/plugin-loader.sh
```

**Lead processing:**
- Determines type: script
- Selects focus: unhandled errors, unsafe operations, idempotency, rollback
- Spawns validator-agent with MODE: SPOT-CHECK

**Validator output:**
```
# Spot Check: scripts/plugin-loader.sh

Found 4 issues:

1. **Missing error check** (line 87)
   - `ln -sfn "$target" "$link"` has no exit code check
   - Recommendation: Add `|| { echo "Symlink failed"; return 1; }`

2. **Unsafe rm operation** (line 143)
   - `rm -f "$HOME/.claude/settings.json.bak"` could delete wrong file if $HOME unset
   - Recommendation: Add `${HOME:?}` to fail if unset

3. **Non-idempotent hook injection** (line 201)
   - Hook check uses string match, could miss duplicates with different whitespace
   - Recommendation: Normalize JSON before comparison using jq

4. **Missing rollback** (install function)
   - If symlink creation fails halfway, no cleanup of partial state
   - Recommendation: Add trap to cleanup on failure
```

**Lead displays to user:**
```
Found 4 issues in scripts/plugin-loader.sh (see details above).
Quick summary:
- Missing error check on ln command (line 87)
- Unsafe rm with unset $HOME (line 143)
- Potential duplicate hooks with whitespace variance (line 201)
- No rollback on partial failure (install function)
```

### Automated Invocation (via SubagentStop Hook)

**Trigger:** Implementer finishes and SubagentStop hook fires

**Lead processing:**
1. Checks if `auto_qa` enabled in session state (default: disabled)
2. If enabled: gets changed files from `git diff --name-only`
3. For each changed file: determines type, spawns validator-agent
4. Collects findings from all validators

**Hook integration pattern:**
```bash
# In SubagentStop hook
if [[ "$AUTO_QA" == "true" ]]; then
  git diff --name-only | while read -r file; do
    # Spawn validator-agent with MODE: SPOT-CHECK
    # Collect and aggregate findings
  done
fi
```

## Output Format

**Concise findings list** (3-10 items typically):
- Each finding has: description, evidence, recommendation
- No severity ratings (simpler than attack-plan)
- No formal assessment structure (simpler than validate)
- Brief format optimized for quick scanning

**Example structure:**
```
# Spot Check: [target]

Found [N] issues:

1. **[Short title]** (location)
   - [What's wrong]
   - Recommendation: [Quick fix]

2. **[Short title]** (location)
   - [What's wrong]
   - Recommendation: [Quick fix]

...
```

## Differences from /qa:validate

| Aspect | /qa:validate | /qa:spot-check |
|--------|--------------|----------------|
| **Ceremony** | Full 4-dimension assessment | None — quick findings only |
| **Scope** | Entire codebase/system | Single target (file/function/config/script) |
| **Findings** | Comprehensive with severity | 3-10 concise items |
| **Timing** | Exit gate (full validation) | During development (quick check) |
| **Assumption challenge** | Yes | No |
| **Use cases** | Verification binding | Iterative development feedback |

## Differences from /qa:attack-plan

| Aspect | /qa:attack-plan | /qa:spot-check |
|--------|-----------------|----------------|
| **Timing** | Before implementation | During/after implementation |
| **Attack vectors** | 7 attack vectors with severity | Simple focused findings |
| **Severity ratings** | Yes (1-5) | No |
| **Format** | Structured assessment | Concise list |
| **Use cases** | Pre-impl risk review | Post-impl quick checks |

## Hook Automation (Optional)

SubagentStop hook can automate spot-check on implementer completion.

**Configuration:**
```json
{
  "auto_qa": false,
  "auto_qa_on_implementer_completion": {
    "enabled": false,
    "focus": ["bugs", "security", "error-handling"]
  }
}
```

**When disabled (default):**
- User must explicitly invoke `/qa:spot-check [target]`
- Lead spawns validator-agent on demand

**When enabled:**
- SubagentStop hook detects implementer completion
- Automatically runs spot-check on changed files
- Results presented to user for immediate feedback
- No user action required
