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
| `create_piece_issue` | spec (Phase 2 — creates piece issue, linked to parent if `parent_key:` set in prd.md) | `create_issue` |
| `create_phase_issue` | plan (sign-off — creates per-phase issues linked to piece issue) | `create_issue` |
| `transition_issue` | execute (phase start/QA/final review) | `transition_issue` |
| `get_issue` | status (issue status display) | `get_issue` |
| `get_transitions` | execute (resolve valid next status before transitioning) | `get_transitions` |

**Issue type mapping is project-defined in `charter/integrations.md`** via:
- `piece_issue_type:` — issue type for each piece (e.g. Epic, Story, Feature)
- `phase_issue_type:` — issue type for each phase (e.g. Task, Sub-task, Story)
- `parent_issue_type:` — optional parent above the piece (e.g. Capability, Initiative, Theme)

**Key fields written by skills (provider-agnostic names):**
- `parent_key:` in `prd.md` → parent issue the piece issue links to
- `epic_key:` in `spec.md` → the piece issue key (written by spec skill regardless of actual type name)
- `jira_task:` per phase in `plan.md` → the phase issue key (written by plan skill regardless of actual type name)

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
- Then proceed with these built-in defaults (`piece_issue_type` = Epic, `phase_issue_type` = Task):

| Event | Default action |
|-------|----------------|
| Spec Phase 2 starts | Create piece issue (type from `piece_issue_type`): `{piece-slug} — {description}`; link to `parent_key:` if set in prd.md |
| Plan signed off | Create phase issues (type from `phase_issue_type`): `[phase] {piece-slug}/{N} — {phase-name}`; link to piece issue |
| Phase execute starts | Transition phase issue → `In Progress` |
| Phase QA passes | Transition phase issue → `In Review` |
| Final Review passes | Transition all phase issues → `Done` |

---

## Graceful degradation modes

| Scenario | Behavior |
|----------|----------|
| All create + transition tools present | Full automation |
| Only `get_issue` present | Read-only: surface issue status in `status` skill; skip create/transition |
| No tools present | Skip all integration steps; emit one summary warning per skill invocation (not per step) |
| `enabled: false` | Silent skip — no warnings emitted |
