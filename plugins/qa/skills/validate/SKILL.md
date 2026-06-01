---
name: qa-validate
user-invocable: true
description: >
  Full paranoid QA validation with 4-dimension adversarial assessment (MISSING / BROKEN / FRAGILE / EXPLOITABLE). Use as an exit gate after any implementation phase, before opening a PR, or whenever the user needs to know what could still go wrong. Trigger when the user says "validate", "qa this", "what did I miss", or implementation is complete.
argument-hint: "describe what to validate or leave blank for auto-detect"
---

# /qa:validate: Paranoid Validation (Exit Gate)

## Purpose

This skill runs **full paranoid QA validation** after all implementation is complete. It is the **EXIT GATE** for the session — the final check before declaring work done.

The skill operates in two modes:
- **Protocol mode**: Reads context/plan and context/todo from Basic Memory, extracts [VERIFY] items
- **Standalone mode**: Prompts user for verification scope when Basic Memory unavailable

In either mode, it spawns the paranoid validator-agent with MODE: VERIFY to execute adversarial assessment across 4 dimensions (MISSING/BROKEN/FRAGILE/EXPLOITABLE) and return structured findings.

## How It Works

### Step 1: Acquire Verification Context

The lead gathers [VERIFY] items and implementation summary. Use the cheapest source available:

**Priority order (use first that applies):**

1. **Session context (preferred):** If the lead managed this session (ran RULE 0.5, tracked implementation, received implementer results), it already has the plan, [VERIFY] items, and implementation summary in its context window. Use what you have — do NOT re-read from Basic Memory.

2. **Basic Memory (session resumption):** If resuming a session or context was compacted, read context/plan and context/todo from `memory://projects/{repo}/{branch}/context/` (project="knowledge") to reload [VERIFY] items.

3. **Standalone (no BM):** Prompt user for verification scope (file paths, test commands, checklist).

### Step 2: Build Context Summary

Compile a concise summary: plan name, files modified, [VERIFY] items. Keep under 20 lines.

### Step 3: Spawn Validator-Agent

Create a Task with MODE: VERIFY and pass all context gathered in steps 1-2:

```
MODE: VERIFY

## Context
[Plan summary or user description from step 2]

## Verification Items
[VERIFY] items from context/todo (protocol mode) OR
[User-provided checklist] (standalone mode)

## Target Files
[List of files that were modified/created]

## Instructions
Execute all verification items with full paranoid assessment:

1. **4-dimension adversarial assessment:**
   - MISSING: What should exist but doesn't?
   - BROKEN: What looks right but doesn't work?
   - FRAGILE: What works today but breaks under stress or edge cases?
   - EXPLOITABLE: What can be misused, abused, or bypassed?

2. **Assumption challenge protocol:**
   - Identify top 3-5 assumptions the implementation makes
   - For each assumption: test it explicitly
   - Report which assumptions held and which failed

3. **Gap analysis:**
   - Compare [VERIFY] items to actual coverage achieved
   - Identify verification gaps (missing checks, edge cases not covered)
   - Recommend missing [VERIFY] items

4. **Anti-theater enforcement:**
   - Use Read/Bash/Glob/Grep tool calls to back every claim
   - Never report "X is correct" without evidence
   - If you cannot test something, report "CANNOT TEST: reason"

Return a structured findings report with:
- Summary (pass/fail/review)
- Dimension results (MISSING/BROKEN/FRAGILE/EXPLOITABLE with evidence)
- Assumptions tested and results
- Gaps identified
- Severity ratings (CRITICAL/HIGH/MEDIUM/LOW)
- Recommendation (approve/rework/defer)
```

### Step 3b: Re-Validation (After Concern Fixes)

When validator returned REVIEW/FAIL and the lead has applied fixes, spawn validator with lighter mode:

**Use MODE: RE-VERIFY instead of MODE: VERIFY when ALL true:**
- First validation already completed (findings report exists)
- Specific concerns were identified and addressed
- Fixes are localized (not architectural rework)

**RE-VERIFY work order includes:**
- Original concerns from first validation (with severity)
- What was changed to address each concern
- Targeted [VERIFY] items to re-check (not all items, just affected ones)
- Regression test commands (full test suites still run)

**RE-VERIFY does NOT include:**
- Full 4-dimension assessment (already done)
- Assumption challenge protocol (already done)
- Gap analysis (already done)

### Step 4: Parse Validator-Agent Output

When validator-agent returns findings:

1. **Extract structured data**: findings report, severity ratings, recommendation
2. **Parse severity summary**: Count CRITICAL, HIGH, MEDIUM, LOW ratings
3. **Determine escalation threshold**:
   - CRITICAL found → escalate immediately
   - 2+ HIGH ratings → escalate
   - MULTIPLE SOME coverage → flag for review
   - Otherwise → present as informational

### Step 5: Extract and Classify Corrective Actions

**Step 5a — Extract:** Parse validator output between `<!-- CORRECTIVE_ACTIONS_START -->` and `<!-- CORRECTIVE_ACTIONS_END -->` markers. Parse the JSON array between the markers. If markers not found or array is empty, skip to Step 7. If JSON parsing fails, log a warning and skip (non-blocking).

**Step 5b — Identify changed files:** Run `git diff --name-only main...HEAD` to get files changed on the current branch. Also include untracked files via `git ls-files --others --exclude-standard`. This is the "changed files set."

Edge cases:
- No git / not a repo → treat ALL findings as current-work (conservative)
- Empty diff → treat ALL findings as pre-existing
- `main` doesn't exist → try `master`, then fall back to `HEAD~1`

**Step 5c — Classify each action:**
- **current-work**: Any item in `affected_files` is in the changed files set
- **pre-existing**: No `affected_files` entries are in the changed files set
- **mixed** (some changed, some not): classify as current-work (conservative)
- **UNKNOWN files**: classify as current-work (conservative)

Partition into `current_work_actions` and `pre_existing_actions`.

### Step 6: Create Tasks from Corrective Actions

**Step 6a — Auto-create tasks for current-work issues:**

For each item in `current_work_actions`:
- Use TaskCreate with subject: `[QA-{id}] {title}`
- Description includes: dimension, severity, affected files, recommended fix, evidence
- activeForm: `Fixing {title}`

Display summary table of created tasks.

**Step 6b — Triage pre-existing issues with user:**

If `pre_existing_actions` is non-empty, present to user via AskUserQuestion:

```
## Pre-Existing Issues Found

{N} issues in files you did NOT modify:

| # | Severity | Title | Files |
|---|----------|-------|-------|
| 1 | HIGH     | ...   | ...   |

Options per item: fix (create task) / defer (log only) / ignore (dismiss)
Bulk options: "fix all", "defer all", "ignore all"
```

Wait for user response, then create tasks for "fix" items.

**Step 6c — No actions needed:** If both lists empty, display "No corrective actions needed" and proceed to Step 7.

**Step 6d — Large finding count:** If corrective actions exceed 10 items, suggest using TaskMaster for structured tracking (indicates systemic issues requiring coordinated remediation).

### Step 7: Display Results to User

Format findings for readability:

```
## Validation Results

[Validator-agent findings report here]

### Summary
- Status: [PASS|REVIEW|FAIL]
- Severity breakdown: X CRITICAL, Y HIGH, Z MEDIUM
- Coverage: [dimension results]
- Recommendation: [validator's recommendation]

### Corrective Actions
- Auto-created: N tasks (current-work issues)
- User-triaged: M tasks (pre-existing, user chose "fix")
- Deferred: P items (pre-existing, user chose "defer")
- Ignored: Q items (pre-existing, user chose "ignore")

### Next Steps
[Escalation if needed, or approval]
```

### Step 8: Optionally Persist to Basic Memory

If Basic Memory available (protocol mode):

1. Offer to write findings to `memory://projects/{repo}/{branch}/team/outbox/validator/findings-{timestamp}.md` (project="knowledge")
2. If user accepts: Write formatted findings with relations back to context/plan
3. If user declines: Proceed to completion

## Work Order Template for Validator-Agent

When spawning validator-agent, use this template (already populated by skill):

```
MODE: VERIFY

## Context
[Plan or implementation summary]

## Verification Items
[VERIFY] items extracted from context/todo (protocol mode) OR
User-provided verification scope (standalone mode)

## Target Files
[List of modified/created files from git diff or user specification]

## Instructions

Execute all verification items with full paranoid assessment:

### 1. Four-Dimension Adversarial Assessment

For each [VERIFY] item and target file:

- **MISSING**: What should exist but doesn't?
  - Use Read/Glob/Bash to check for expected files, functions, config keys
  - Test that required components are present with correct structure
  - Example: Verify config.json exists AND contains required fields

- **BROKEN**: What looks right but doesn't work?
  - Run executable tests (bash scripts, pytest, etc.)
  - Check that functions/APIs return expected values
  - Test error handling and edge cases
  - Example: File exists but contains syntax errors, test runs but fails

- **FRAGILE**: What works today but breaks under stress?
  - Test boundary conditions (empty inputs, very large inputs)
  - Test with missing optional dependencies
  - Test concurrent/parallel execution if applicable
  - Example: Works with 1 item but crashes with 100 items

- **EXPLOITABLE**: What can be misused or abused?
  - Check for injection vulnerabilities (unsanitized inputs)
  - Verify permission/access controls
  - Test with malicious or unexpected input formats
  - Example: API accepts untrusted input without validation

### 2. Assumption Challenge Protocol

- **Identify top 3-5 assumptions** the implementation makes about:
  - Dependencies (which tools/libraries are required)
  - Environment (OS, permissions, available disk space)
  - Input validity (format/structure of user input)
  - Success conditions (what does "correct" mean?)
  - Integration points (how this fits with existing systems)

- **For each assumption, test explicitly:**
  - Try violating the assumption (missing dependency, wrong OS, etc.)
  - Observe what happens (graceful fail vs crash vs silent bug)
  - Report whether assumption is critical or relaxable

- **Example:**
  Assumption: "pytest is installed"
  Test: Run pytest when not installed → observe error message
  Result: Clean error telling user to install pytest (OK)

### 3. Gap Analysis

- **Coverage check**: Which [VERIFY] items are addressed? Which are missing?
- **Execution check**: Can all [VERIFY] items be executed, or are some blocked?
- **Scope check**: Are there verification areas not covered by [VERIFY] items?
- **Recommendation**: Should additional [VERIFY] items be added?

Example output:
```
[VERIFY] items: 5 total
  ✓ 4 executed successfully
  ✗ 1 cannot execute (test suite not found)
Gap: No verification for rollback scenarios
```

### 3b. Test Strategy Verification

For each implementation task in the validation scope:
1. Read the task via TaskMaster (`get_task`) to obtain its `testStrategy` field
2. Check the task's update history (subtask updates or completion messages) for evidence
   that the testStrategy commands were actually executed
3. Look for: exact commands run, exit codes, PASS/FAIL output
4. Flag as MISSING if:
   - Task has a testStrategy but no test evidence in updates
   - Test commands in testStrategy don't match commands in evidence
   - Evidence shows FAIL but task is marked done
5. Severity: CRITICAL — a task marked done without executing its testStrategy is
   untested code and must be flagged

### 3c. Test Substance Analysis

Cross-reference implementation changes against test coverage:

- **Alignment check**: Do tests actually assert on the changed behavior?
  - Map changed files → test files → assertions
  - Flag gaps where changes have no corresponding test assertions

- **Theater detection**: Do tests validate anything meaningful?
  - Flag: no-assertion tests, trivial assertions, mock-only tests, exception swallowing
  - Use Grep for patterns: `def test_` without `assert`, `assert True`, bare `except`
  - Read flagged functions to confirm before reporting

Report alignment rating and any theater tests found.

### 4. Anti-Theater Enforcement

- **Every finding requires evidence** from Read/Bash/Glob/Grep tool calls
- **No "probably" or "should be"** — only confirmed observations
- **Uncertainty explicit** — If you cannot test something, report:
  "CANNOT TEST: {reason} — requires {what's needed}"
- **Examples:**
  - BAD: "The config looks correct"
  - GOOD: "Read config.json, verified keys present: api_key, timeout, retries"
  - BAD: "The API probably handles errors"
  - GOOD: "Tested missing API_KEY env var: code raises ValueError with message 'API_KEY required'"

### 5. Structured Findings Report

Return findings in this format:

```
## Validation Findings

### Summary
- Overall: [PASS | REVIEW | FAIL]
- Items verified: X/Y
- Severity: {X CRITICAL, Y HIGH, Z MEDIUM, W LOW}

### 4-Dimension Results

#### MISSING Assessment
[Evidence from Read/Glob/Grep/Bash]
Status: [OK | CONCERN | CRITICAL]

#### BROKEN Assessment
[Evidence from test execution, API checks]
Status: [OK | CONCERN | CRITICAL]

#### FRAGILE Assessment
[Evidence from boundary testing]
Status: [OK | CONCERN | CRITICAL]

#### EXPLOITABLE Assessment
[Evidence from injection/abuse testing]
Status: [OK | CONCERN | CRITICAL]

### Assumption Tests
1. Assumption: {description}
   Test: {what you tested}
   Result: {passed | failed | cannot test}

2. [Repeating for top 3-5 assumptions]

### Verification Gaps
- Gaps identified: {list}
- Missing [VERIFY] items: {recommendations}

### Recommendation
[APPROVE | REVIEW_CONCERNS | REWORK | DEFER with reason]
```

## Example Invocation

### Protocol Mode Example

**User input:**
```
/qa:validate
```

**Skill execution:**
```
1. Read memory://projects/claude/main/context/plan → found (protocol mode active)
2. Read memory://projects/claude/main/context/todo
3. Extract [VERIFY] items (e.g., "SKILL.md exists", "frontmatter correct")
4. Extract plan: "Phase 2: Create QA plugin skills"
5. Create context summary
6. Spawn validator-agent with MODE: VERIFY
7. Receive findings report
8. Display findings to user
9. Offer to persist findings to Basic Memory
```

**Output to user:**
```
## Validation Results

[Validator findings report]

### Summary
- Overall: PASS
- Severity: 0 CRITICAL, 1 HIGH, 1 MEDIUM, 2 LOW
- Recommendation: APPROVE with minor notes

### Next Steps
Validation passed. Ready for session completion.
```

### Standalone Mode Example

**User input:**
```
/qa:validate
```

**Skill execution (no Basic Memory):**
```
1. Try to read context/plan → fails (no Basic Memory)
2. Enter standalone mode
3. Prompt: "What should I validate?"
4. User response: "Run pytest tests/, verify config.py has SSL enabled"
5. Create context summary from user input
6. Spawn validator-agent with MODE: VERIFY
7. Receive findings report
8. Display findings to user
```

**Output to user:**
```
## Validation Results

[Validator findings report from user scope]

### Summary
- Test pass rate: 48/50 (96%)
- SSL check: PASS
- Recommendation: APPROVE (2 pre-existing test failures confirmed)
```

## Protocol Compatibility

This skill is designed to work seamlessly with the ~/.claude/ protocol:

- **No Basic Memory dependency**: Falls back to standalone mode gracefully
- **Context/todo awareness**: Extracts [VERIFY] items for focused verification
- **Context/plan reading**: Uses plan summary to frame validation scope
- **Validator-agent integration**: Spawns as Task with MODE: VERIFY
- **Anti-theater**: Uses Read/Bash/Glob/Grep only — no speculation
- **Findings persistence**: Optional write to team/outbox/validator/ for record

## VERIFY Trigger Conditions

This skill serves as the **exit gate** for sessions. It should be invoked when ALL of these conditions are met:

**When:**
- All TODO tasks marked complete
- All [EXPAND] markers resolved
- Implementation phase finished

**How:**
- Lead spawns validator-agent with MODE: VERIFY
- Agent receives [VERIFY] items from context/todo via Task prompt
- Agent executes full paranoid validation
- Agent returns findings report (including Corrective Actions Appendix)
- Lead extracts corrective actions, classifies via git diff, creates tasks
- Lead displays findings to user

**Post-validation:**
- If corrective actions are created, the session is NOT complete
- CRITICAL/HIGH actions MUST be addressed before session end
- Route corrective action tasks to implementer
- After fixes, consider RE-VERIFY to confirm resolution

## Plan Verification Binding

[VERIFY] items from the approved plan are the acceptance criteria — not the lead's judgment.
If verification steps cannot run, ask user for alternative approval.

## Retry and Escalation

**VERIFY-RETRY:**
- Max 2 retries on verification failure
- Each retry must have distinct diagnosis
- Use MODE: RE-VERIFY for re-validation after fixes (not full VERIFY)
- RE-VERIFY follows the 5-step Concern Fix Validation Pattern (in validator-agent.md)

**ESCALATE:**
- After 2 failed retries, validator-agent escalates to lead
- Lead decides: retry with different approach, adjust plan, or ask user
- Lead NEVER proceeds to Completion without addressing escalation

## Related Skills

- **qa/commands/qa.md** — Router skill (entry point)
- **qa/skills/attack-plan/SKILL.md** — Pre-implementation plan review (`/qa:attack-plan`)
- **qa/skills/spot-check/SKILL.md** — Quick targeted checks during implementation (`/qa:spot-check`)
