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
| `create_piece_issue` | spec | `create_issue` |
| `create_phase_issue` | plan | `create_issue` |
| `transition_issue` | execute | `transition_issue` |
| `get_issue` | status | `get_issue` |
| `get_transitions` | execute | `get_transitions` |

**Issue hierarchy is defined in `hierarchy:` in `.spec-flow.yaml`** — see `plugins/spec-flow/reference/jira-integration-config.md` for the full schema. Skills resolve issue type, parent key location, and key recording field from that list rather than from flat config values.

**Other config fields read by skills:**
- `project_key:` — **required for Jira** — the Jira project key where all issues are created (e.g. `EIT`, `PROJ`). Read from `integrations.issue_tracker.project_key` in `.spec-flow.yaml`. Passed as the `project_key` parameter to every `create_issue` call.
- `base_url:` — **required for Jira** — base URL of the Jira instance (e.g. `https://se-ivan.atlassian.net`). Read from `integrations.issue_tracker.base_url` in `.spec-flow.yaml`. Used to construct `jira_url` values of the form `<base_url>/browse/<issue-key>` recorded in prd.md, spec.md, and plan.md.

**Standardized key fields written to artifacts:**
- `jira_key:` — single field name used at every hierarchy level (prd.md, spec.md, plan.md per-phase)
- `jira_url:` — browse URL, written alongside `jira_key:` in spec.md and plan.md per-phase

---

## Provider default tool names

### jira (Atlassian MCP server)
```yaml
create_issue:    io-sooperset-mcp-atlassian-jira_create_issue
transition_issue: io-sooperset-mcp-atlassian-jira_transition_issue
get_issue:       io-sooperset-mcp-atlassian-jira_get_issue
get_transitions: io-sooperset-mcp-atlassian-jira_get_transitions
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
- Issue hierarchy (see `hierarchy:` in `.spec-flow.yaml`)

If the charter file is absent:
- If `auto_create_tasks: true` or `auto_transition: true` — emit a one-line note:
  `ℹ️ No charter/integrations.md found — using provider defaults for task naming and transitions.`
- Then proceed with these built-in defaults, deriving issue types from the `hierarchy:` list
  (`managed_by: spec` entry → piece issue type; `managed_by: plan` entry → phase issue type):

**Naming conventions:**

| Issue | Format |
|-------|--------|
| piece issue (`managed_by: spec`) | `{piece-slug} — {piece description from manifest}` |
| phase issue (`managed_by: plan`) | `[phase] {piece-slug}/{phase-number} — {phase-name}` |

**Status transitions** (status names from `integrations.issue_tracker.status_map`):

| Event | Issue | Target Status |
|-------|-------|--------------|
| Piece issue created | piece (`managed_by: spec`) | `status_map.todo` |
| Phase issue created | phase (`managed_by: plan`) | `status_map.todo` |
| Phase execute starts | phase (`managed_by: plan`) | `status_map.in_progress` |
| Phase QA passes | phase (`managed_by: plan`) | `status_map.in_review` |
| Final Review Board passes | phase (`managed_by: plan`) | `status_map.done` |
| Non-active tasks (post-creation) | phase (`managed_by: plan`) | `status_map.backlog` |

> Agents may only move phase issues (`managed_by: plan`) to `in_progress` or `in_review` mid-flight.
> Only the Final Review Board pass gates a `done` transition.

---

## Task Creation Defaults

Applied when creating Tasks for a piece's phases (i.e. during `create_phase_issue`). **Not applied to piece-level issues (Epics).**

**Story Points** (phase issue (`managed_by: plan`) only — not on piece or top-level issues):
> Estimate the human effort to complete the phase in days, then apply: `ceil(estimate × 0.5)` (i.e. half the raw estimate, rounded up to next Fibonacci number). 1 story point ~= 1 human work day.
>
> Example 1: a phase estimated at 6 days → `ceil(6 × 0.5)` = 3, which is a Fibonacci number → **3 points**.
> Example 2: a phase estimated at 11 days → `ceil(11 × 0.5)` = ceil(5.5) = 6, which is not a Fibonacci number → round up to **8 points**.
>
> If the phase has no explicit duration estimate in plan.md, derive from the number of implementation sub-steps or leave unset.

**Assignee:**
> Set to the current user performing the tracking setup (i.e. the person running the spec/plan/manifest workflow).

**Initial Status:**
> Tasks are created in `To Do` by default. Move to `Backlog` for all tasks not actively being worked. Move to `In Progress` only the task currently under execute.

---

## Graceful degradation modes

| Scenario | Behavior |
|----------|----------|
| All create + transition tools present | Full automation |
| Only `get_issue` present | Read-only: surface issue status in `status` skill; skip create/transition |
| No tools present | Skip all integration steps; emit one summary warning per skill invocation (not per step) |
| `enabled: false` | Silent skip — no warnings emitted |
