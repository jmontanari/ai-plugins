---
name: qa-attack-plan
user-invocable: true
description: >
  Pre-implementation plan review with adversarial attack vectors. Use before writing any code when a plan exists — surfaces ambiguous requirements, missing error paths, security assumptions, and integration risks BEFORE they become bugs. Trigger whenever the user has a plan ready for review or says "is this approach sound".
argument-hint: "paste or describe the plan to review"
---

# /qa-attack-plan: Adversarial Plan Review

## Purpose

This skill performs pre-implementation plan review using 7 attack vectors. It is purely analytical — no test execution.

**When to use:**
- Before approving a plan (user invokes manually)
- When plan seems complex or risky
- To surface hidden assumptions and missing steps

**When NOT to use:**
- After implementation (use `/qa-validate` instead)
- For quick targeted checks (use `/qa-spot-check` instead)

## How It Works

1. **Get plan**: Read from context/plan if available, or prompt user to paste plan text
2. **Spawn validator-agent**: Pass MODE: ATTACK-PLAN with plan content
3. **Display attack report**: Show findings organized by severity
4. **User decides**: Address CRITICAL/HIGH items before proceeding, optionally defer MEDIUM/LOW

## 7 Attack Vectors

Attack vectors assess different categories of plan vulnerabilities. Each vector asks a distinct question to surface risks.

| Vector | Question |
|--------|----------|
| Assumption audit | What unstated assumptions does this plan make? |
| Missing steps | What prerequisite or cleanup steps are missing? |
| Dependency fragility | What breaks if a dependency is unavailable? |
| Rollback analysis | How do you undo this if it fails halfway? |
| Verification adequacy | Are the [VERIFY] items sufficient to catch failures? |
| Scope creep risk | Where might this plan expand beyond intended scope? |
| Ordering vulnerabilities | What happens if steps run out of order? |

## Severity Ratings

Findings are classified by the likelihood and impact of failure:

- **CRITICAL**: Plan will likely fail without addressing this vulnerability
- **HIGH**: Significant risk of failure or rework if not addressed
- **MEDIUM**: Could cause issues in some scenarios; should be reviewed
- **LOW**: Minor concern; easily addressed if discovered

## Instructions for Lead

When user invokes `/qa-attack-plan`:

### Step 1: Obtain Plan Text

Try to auto-detect the plan:
- Attempt to read `context/plan` from Basic Memory at `memory://projects/{repo}/{branch}/context/plan` (project="knowledge")
- If successful, use the plan content
- If unavailable or fails, prompt user: "No plan found in context. Please paste the plan text you'd like reviewed:"

### Step 2: Format Task for Validator-Agent

Create a work order with MODE: ATTACK-PLAN containing:

```
MODE: ATTACK-PLAN

## Plan Text
[Full plan content from context/plan OR user-provided text]

## Instructions
Review this plan using 7 attack vectors. NO test execution — analytical only.

For each attack vector, identify vulnerabilities and rate severity:
- CRITICAL: Plan will likely fail without addressing
- HIGH: Significant risk of failure or rework
- MEDIUM: Could cause issues in some scenarios
- LOW: Minor concern, easily addressed

Attack vectors:
1. **Assumption audit**: What unstated assumptions does the plan make?
2. **Missing steps**: What prerequisites or cleanup steps are missing?
3. **Dependency fragility**: What breaks if dependencies are unavailable?
4. **Rollback analysis**: How do you undo this if it fails halfway?
5. **Verification adequacy**: Are the [VERIFY] items sufficient to catch failures?
6. **Scope creep risk**: Where might scope expand beyond intent?
7. **Ordering vulnerabilities**: What if steps run out of order?

Return attack report with findings organized by severity (CRITICAL first, then HIGH, MEDIUM, LOW).
Each finding should include: vector name, description, impact, and recommendation.
```

### Step 3: Spawn Validator-Agent

Delegate the review to validator-agent with the work order above.

### Step 4: Parse and Present Attack Report

Once validator-agent returns the attack report:

1. **Extract summary**: Total findings count, highest severity level, top recommendations
2. **Organize findings**: Group by severity (CRITICAL, HIGH, MEDIUM, LOW)
3. **Display to user** in markdown format (see Example Output Format below)
4. **Provide decision guidance**:
   - CRITICAL/HIGH: "These must be addressed before proceeding"
   - MEDIUM: "Consider addressing these; risks are scenario-dependent"
   - LOW: "These are minor; can be addressed if time permits"

### Step 5: Support User Decision

- If user wants to revise the plan: Offer to re-run attack review after changes
- If user wants to proceed: Confirm understanding of CRITICAL/HIGH risks
- If unclear: Ask validator-agent for clarification on specific vectors

## Work Order Template

Use this template when spawning validator-agent for an attack review:

```
MODE: ATTACK-PLAN

## Plan Text
[Full plan content from context/plan OR user-provided text]

## Instructions
Review this plan using 7 attack vectors. NO test execution — analytical only.

For each vector, identify vulnerabilities and rate severity:
- CRITICAL: Plan will likely fail without addressing
- HIGH: Significant risk of failure or rework
- MEDIUM: Could cause issues in some scenarios
- LOW: Minor concern, easily addressed

Attack vectors:
1. **Assumption audit**: What unstated assumptions does the plan make?
2. **Missing steps**: What prerequisites or cleanup steps are missing?
3. **Dependency fragility**: What breaks if dependencies are unavailable?
4. **Rollback analysis**: How do you undo this if it fails halfway?
5. **Verification adequacy**: Are the [VERIFY] items sufficient to catch failures?
6. **Scope creep risk**: Where might scope expand beyond intent?
7. **Ordering vulnerabilities**: What if steps run out of order?

Return attack report with findings organized by severity (CRITICAL first, then HIGH, MEDIUM, LOW).
```

## Example Output Format

Attack reports follow this structure:

```
# Attack Report: [Plan Name or Identifier]

## Summary
- Total findings: 12
- Highest severity: HIGH
- Recommendation: Address 2 CRITICAL and 4 HIGH items before proceeding

## CRITICAL (2)

### 1. Dependency fragility
- **Vector**: Dependency fragility
- **Description**: Plan assumes jq is installed; plugin-loader.sh will fail without it
- **Impact**: Complete plugin installation operation will fail if jq is unavailable
- **Recommendation**: Add jq installation check in Phase 1.3 before plugin processing

### 2. Rollback analysis
- **Vector**: Rollback analysis
- **Description**: No uninstall step defined if Phase 4.2 symlink creation fails
- **Impact**: Partial state left on disk; manual cleanup required; broken symlinks remain
- **Recommendation**: Add rollback logic to plugin-loader.sh uninstall sequence; document manual cleanup steps

## HIGH (4)

### 1. Missing steps
- **Vector**: Missing steps
- **Description**: Phase 2.1 assumes plugin directory structure exists; no creation step
- **Impact**: Phase 2.2+ will fail if directory structure must be created first
- **Recommendation**: Add Phase 2.1a: Create plugin directory structure with proper permissions

### 2. Verification adequacy
- **Vector**: Verification adequacy
- **Description**: Phase 3 [VERIFY] only checks file existence; doesn't validate syntax or permissions
- **Impact**: Plugin files may exist but not be executable; verification passes but runtime fails
- **Recommendation**: Add validation steps: syntax check (jq -e), permission check (test -x), content validation

### 3. Ordering vulnerabilities
- **Vector**: Ordering vulnerabilities
- **Description**: Phase 4 depends on Phase 3 completion, but Phase 3's dependencies not explicit
- **Impact**: If Phase 3 sub-steps run out of order, Phase 4 may fail without clear cause
- **Recommendation**: Explicit dependency markers in plan: Phase 4.1 requires Phase 3.1-3.3 complete

### 4. Assumption audit
- **Vector**: Assumption audit
- **Description**: Plan assumes bash 4.0+ features available; doesn't specify minimum version
- **Impact**: Installation fails on systems with bash 3.x (e.g., macOS default bash)
- **Recommendation**: Add Phase 1.1: Verify bash version; document minimum requirements

## MEDIUM (5)

### 1. Scope creep risk
- **Vector**: Scope creep risk
- **Description**: Phase 2 mentions "optional" feature toggles but no decision point documented
- **Impact**: Developers may add feature flags beyond intended scope
- **Recommendation**: Define exactly which toggles are in scope; document decision process

### 2. Missing steps
- **Vector**: Missing steps
- **Description**: Phase 5 cleanup doesn't mention log rotation or temporary file cleanup
- **Impact**: Long-running installations may accumulate disk usage; no documented cleanup
- **Recommendation**: Add cleanup steps for logs and temp files created during phases 1-4

### 3. Dependency fragility
- **Vector**: Dependency fragility
- **Description**: Phase 2.3 uses git; fails silently if git is not in PATH
- **Impact**: Phase 2.3 appears to complete but actually skips; phase 3 detects inconsistency
- **Recommendation**: Add explicit git availability check before Phase 2.3

### 4. Verification adequacy
- **Vector**: Verification adequacy
- **Description**: Phase 4 [VERIFY] checks only success path; no negative test cases
- **Impact**: Plan may work for happy-path but fail in error scenarios
- **Recommendation**: Add error-case verification: invalid input, missing files, permission errors

### 5. Assumption audit
- **Vector**: Assumption audit
- **Description**: Plan assumes writable home directory; doesn't account for restricted environments
- **Impact**: Installation fails in sandboxed environments or read-only filesystems
- **Recommendation**: Detect environment constraints in Phase 1; document supported environments

## LOW (1)

### 1. Ordering vulnerabilities
- **Vector**: Ordering vulnerabilities
- **Description**: Phase 3.2 and Phase 3.3 could run in either order; documentation ambiguous
- **Impact**: Developers may run in unexpected order; results consistent either way but risky
- **Recommendation**: Clarify intended order in documentation or add ordering constraint
```

## Anti-Theater Enforcement

Every finding requires analysis grounded in plan content:
- **No speculation** — Identify specific plan sections that create the vulnerability
- **Evidence-based** — Explain how the plan assumption or gap leads to failure
- **Actionable** — Provide specific recommendations, not vague concerns
- **Severity justified** — Explain why severity rating applies (likelihood + impact)

## Key Behaviors

**Protocol Mode:**
- If context/plan exists in Basic Memory: Use it as input (no user paste required)
- If context/plan fails to load: Fall back to standalone mode

**Standalone Mode:**
- Prompt user to provide plan text
- Proceed with analysis even without Basic Memory access

**No Test Execution:**
- This skill is purely analytical
- Do NOT attempt to run code, install packages, or execute scripts
- Do NOT read implementation files unless needed to understand plan dependencies

**User-Invoked Only:**
- Attack reviews happen explicitly when user types `/qa-attack-plan`
- Not part of the automated verification pipeline
- Complements (but doesn't replace) `/qa-validate` for post-implementation verification

## Related Skills

- **qa/commands/qa.md** — QA router and philosophy guide
- **qa/skills/validate/SKILL.md** — Full paranoid validation implementation (post-implementation, `/qa-validate`)
- **qa/skills/spot-check/SKILL.md** — Quick targeted checks during implementation (`/qa-spot-check`)
