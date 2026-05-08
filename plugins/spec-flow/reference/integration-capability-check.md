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
- `project_key:` — **required for Jira** — the Jira project key where all issues are created (e.g. `EIT`, `PROJ`). Read from `integrations.issue_tracker.project_key` in `.spec-flow.yaml`. Passed as the `project_key` parameter to every `create_issue` call.
- `base_url:` — **required for Jira** — base URL of the Jira instance (e.g. `https://se-ivan.atlassian.net`). Read from `integrations.issue_tracker.base_url` in `.spec-flow.yaml`. Used by skills to construct browsable issue links of the form `<base_url>/browse/<issue-key>` recorded in spec.md, plan.md, and surfaced in status output. NOT passed to MCP tools (the MCP server manages its own connection config).
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
- Issue hierarchy (epic / story / task)

If the charter file is absent:
- If `auto_create_tasks: true` or `auto_transition: true` — emit a one-line note:
  `ℹ️ No charter/integrations.md found — using provider defaults for task naming and transitions.`
- Then proceed with these built-in defaults (`piece_issue_type` = Epic, `phase_issue_type` = Task):

**Naming conventions** (using configured `piece_issue_type` / `phase_issue_type`):

| Issue | Format |
|-------|--------|
| `{piece_issue_type}` (one per piece) | `{piece-slug} — {piece description from manifest}` |
| `{phase_issue_type}` (one per phase) | `[phase] {piece-slug}/{phase-number} — {phase-name}` |

**Status transitions** (status names from `integrations.issue_tracker.status_map`):

| Event | Issue | Target Status |
|-------|-------|--------------|
| `{piece_issue_type}` created | `piece_issue_type` | `status_map.todo` |
| `{phase_issue_type}` created | `phase_issue_type` | `status_map.todo` |
| Phase execute starts | `phase_issue_type` | `status_map.in_progress` |
| Phase QA passes | `phase_issue_type` | `status_map.in_review` |
| Final Review Board passes | `phase_issue_type` | `status_map.done` |
| Non-active tasks (post-creation) | `phase_issue_type` | `status_map.backlog` |

> Agents may only move `{phase_issue_type}` issues to `in_progress` or `in_review` mid-flight.
> Only the Final Review Board pass gates a `done` transition.

---

## Task Creation Defaults

Applied when creating Tasks for a piece's phases (i.e. during `create_phase_issue`). **Not applied to piece-level issues (Epics).**

**Story Points** (Task / `phase_issue_type` only):
> Estimate the human effort to complete the phase in days, then apply: `fib_ceil(estimate × 0.5)` — multiply the day estimate by 0.5, then round up to the next Fibonacci number (1, 2, 3, 5, 8, 13, 21 …). 1 story point ~= 1 human work day.
>
> Example: a phase estimated at 6 days → 6 × 0.5 = 3.0 → next Fibonacci ≥ 3 = **3 points**.
> Example: a phase estimated at 7 days → 7 × 0.5 = 3.5 → next Fibonacci ≥ 3.5 = **5 points**.
>
> If the phase has no explicit duration estimate in plan.md, derive from the number of implementation sub-steps or leave unset.

**Assignee:**
> Set to the current user performing the plan sign-off (i.e. the person running `/spec-flow:plan`).

**Initial Status:**
> All Tasks are created in `To Do`. After creation, move every Task that is **not** currently being executed to `Backlog`. Move a Task to `In Progress` only when its phase begins in execute.

---

## Graceful degradation modes

| Scenario | Behavior |
|----------|----------|
| All create + transition tools present | Full automation |
| Only `get_issue` present | Read-only: surface issue status in `status` skill; skip create/transition |
| No tools present | Skip all integration steps; emit one summary warning per skill invocation (not per step) |
| `enabled: false` | Silent skip — no warnings emitted |
