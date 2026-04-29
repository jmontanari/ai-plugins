# Integration Capability Check

This reference defines the **MCP capability check** pattern that every spec-flow skill
must execute before attempting any issue tracker integration step.

The contract is absolute: skills NEVER fail because of integration unavailability.
Missing tools → named warning → skip → continue.

---

## Algorithm (run at every integration step)

**Step 1 — Check flag**

Read `integrations.issue_tracker.enabled` from `.spec-flow.yaml`. If `false`, `null`, or
the `integrations:` key is entirely absent → skip all integration blocks silently. ✓

**Step 2 — Resolve required tool names**

For the specific operation being attempted (see "Operations" below), resolve each required
tool name using this priority order:
1. Explicit override in `integrations.issue_tracker.mcp_tools.<operation>` in `.spec-flow.yaml`
2. Provider default from the table below

**Step 3 — Check tool availability**

For each required tool name: check whether it is available in your current tool set.

**Step 4a — ALL present** → proceed with the integration step normally.

**Step 4b — ANY missing** → emit the warning block below, skip the integration step,
and continue with the rest of the skill. Do NOT fail, do NOT retry.

---

## Warning format (emit verbatim when tools are missing)

```
⚠️ INTEGRATION WARNING: Required MCP tools not available.
  Missing:   [<tool-name-1>, <tool-name-2>]
  Operation: <operation-name>
  Provider:  <provider>
  Fix:       Ensure the <provider> MCP server is configured and exposes these tools.
  → Skipping integration step — pipeline continues without issue tracker interaction.
```

---

## Operations and required tools

| Operation | Used by | Tools required |
|-----------|---------|---------------|
| `create_task` | spec (pre-brainstorm, sign-off), plan (sign-off) | `create_issue` |
| `transition_task` | spec (sign-off), plan (start), execute (phase start/QA/final review) | `transition_issue` |
| `get_task` | status (issue status display) | `get_issue` |
| `get_transitions` | execute (to resolve valid next status before transitioning) | `get_transitions` |

---

## Provider default tool names

### jira (Atlassian MCP server)
```yaml
create_issue:    io-sooperset-mcp-atlassian-docker-jira_create_issue
transition_issue: io-sooperset-mcp-atlassian-docker-jira_transition_issue
get_issue:       io-sooperset-mcp-atlassian-docker-jira_get_issue
get_transitions: io-sooperset-mcp-atlassian-docker-jira_get_transitions
```

### linear
```yaml
create_issue:    linear_create_issue
transition_issue: linear_update_issue
get_issue:       linear_get_issue
get_transitions: ~                     # linear uses enum states; no transitions API needed
```

### github-issues
```yaml
create_issue:    github_create_issue
transition_issue: github_update_issue
get_issue:       github_get_issue
get_transitions: ~                     # github uses open/closed + labels; no transitions API
```

### azure-devops
```yaml
create_issue:    azure_devops_create_work_item
transition_issue: azure_devops_update_work_item
get_issue:       azure_devops_get_work_item
get_transitions: azure_devops_get_work_item_states
```

### custom
No defaults — all four `mcp_tools:` overrides must be provided in `.spec-flow.yaml`.
If any is null/absent, treat it as an unavailable tool and emit the warning.

---

## Reading the integration rules file

When `integrations.issue_tracker.charter_file` is set (default: `integrations`), read
`<docs_root>/charter/<charter_file>.md` for project-specific rules:
- Task naming conventions
- Status transition rules (which statuses to use at each pipeline event)
- Commit message format
- Issue hierarchy (epic / story / task)

If the charter file is absent:
- If `auto_create_tasks: true` or `auto_transition: true` — emit a one-line note:
  `ℹ️ No charter/integrations.md found — using provider defaults for task naming and transitions.`
- Then proceed with these built-in defaults:

| Event | Default status transition |
|-------|--------------------------|
| Spec starts | Create task → `To Do` |
| Spec signed off | Transition → `Done`; create plan task → `To Do` |
| Plan authoring starts | Transition plan task → `In Progress` |
| Plan signed off | Create phase tasks → `To Do` |
| Phase execute starts | Transition phase task → `In Progress` |
| Phase QA passes | Transition → `In Review` |
| Final Review passes | Transition all phase tasks → `Done` |

---

## Graceful degradation modes

| Scenario | Behavior |
|----------|----------|
| All create + transition tools present | Full automation |
| Only `get_issue` present | Read-only: surface issue status in `status` skill; skip create/transition |
| No tools present | Skip all integration steps; emit one summary warning per skill invocation (not per step) |
| `enabled: false` | Silent skip — no warnings emitted |
