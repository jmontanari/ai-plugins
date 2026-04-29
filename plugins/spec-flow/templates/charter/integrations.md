---
last_updated: YYYY-MM-DD
---

# Integration Rules

This file configures how spec-flow interacts with your issue tracker.
Skills read these rules but never write to this file — it is team-authored configuration.

Copy this template to `<docs_root>/charter/integrations.md` and fill in each section.
Reference: `plugins/spec-flow/reference/integration-capability-check.md`

---

## Task Naming Conventions

Spec tasks created when a spec is authored:
```
[spec] {piece-slug} — Write specification
```

Plan tasks created when a spec is signed off:
```
[plan] {piece-slug} — Write implementation plan
```

Phase tasks created when a plan is signed off (one per phase):
```
[phase] {piece-slug}/{phase-number} — {phase-name}
```

> Customize the formats above. Use `{piece-slug}`, `{phase-number}`, `{phase-name}`,
> `{prd-slug}` as substitution tokens. Keep them ≤ 80 characters.

---

## Status Transition Rules

Define which issue tracker statuses to use at each pipeline event.
Replace the values with the exact status names from your project.

| Event | Target Status |
|-------|--------------|
| Task created | `To Do` |
| Spec authoring starts | `In Progress` |
| Spec signed off (write-plan task) | `To Do` |
| Plan authoring starts | `In Progress` |
| Phase execute starts | `In Progress` |
| Phase QA passes | `In Review` |
| Final Review Board passes | `Done` |

> **Important:** Skills will NOT transition tasks to `Done` on behalf of the team
> unless the Final Review Board explicitly passes. Agents may only move tasks to
> `In Progress` or `In Review` mid-flight — never to `Done` without a passing gate.

---

## Commit Message Format

Issue key injection format (inserted as commit message prefix):
```
[{issue_key}] {conventional-commit-message}
```

Example: `[PROJ-42] feat(auth): add token refresh endpoint`

> Set `commit_tag_format` in `.spec-flow.yaml` to override. The token `{issue_key}`
> is replaced with the phase task's issue key (e.g., `PROJ-42`).

---

## Issue Hierarchy

Describe how spec-flow-created tasks should fit into your project's issue hierarchy:

```
Epic (per piece — optional, create manually before running spec)
  └─ Story: Write Spec   (created by spec skill at start)
  └─ Story: Write Plan   (created by spec skill at sign-off)
  └─ Task: Phase 1 — {phase-name}   (created by plan skill at sign-off)
  └─ Task: Phase 2 — {phase-name}
  └─ Task: Phase N — ...
```

> If your project uses Epics, create the Epic manually and record its key in
> plan.md front-matter (`epic_key: PROJ-10`) — the plan skill will link tasks
> to it if the MCP tool supports parent assignment.

---

## Additional Notes

<!-- Add any project-specific integration notes here, e.g.:
- Which board or sprint to assign tasks to
- Required labels or components
- Priority defaults
- Assignee rules
-->
