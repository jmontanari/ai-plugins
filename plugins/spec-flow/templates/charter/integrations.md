---
last_updated: YYYY-MM-DD
---

# Integration Rules

This file configures how spec-flow interacts with your issue tracker.
Skills read these rules but never write to this file — it is team-authored configuration.

Copy this template to `<docs_root>/charter/integrations.md` and fill in each section.
Reference: `plugins/spec-flow/reference/integration-capability-check.md`

---

## Issue Hierarchy

Define how spec-flow pipeline concepts map to your tracker's issue types.
Replace the values with the exact issue type names your project uses.

```yaml
# Issue type mappings (fill in your tracker's exact type names)
piece_issue_type: Epic          # Issue type created per piece by the spec skill
phase_issue_type: Task          # Issue type created per phase by the plan skill
parent_issue_type: ~            # Optional: parent type the piece issue links to (e.g. Initiative, Capability)
                                # Set to ~ to disable parent linking
```

```
{parent_issue_type}  (per PRD — create manually; record key as parent_key: in prd.md)
  └─ {piece_issue_type}: {piece-slug} — {piece description}    ← spec skill creates
       └─ {phase_issue_type}: [phase] {piece-slug}/1 — {phase-1-name}   ← plan skill creates
       └─ {phase_issue_type}: [phase] {piece-slug}/2 — {phase-2-name}
       └─ {phase_issue_type}: [phase] {piece-slug}/N — ...
```

**Key fields written by skills:**
- `parent_key:` in `prd.md` → parent issue the piece issue links to
- `epic_key:` in `spec.md` → the piece issue key (written by spec skill)
- `jira_task:` per phase in `plan.md` → the phase issue key (written by plan skill)

---

## Naming Conventions

Piece issue (one per piece, created by spec skill at brainstorm start):
```
{piece-slug} — {piece description from manifest}
```

Phase issues (one per phase, created by plan skill at sign-off):
```
[phase] {piece-slug}/{phase-number} — {phase-name}
```

> Customize the formats above. Supported tokens: `{piece-slug}`, `{phase-number}`,
> `{phase-name}`, `{prd-slug}`. Keep names ≤ 80 characters.

---

## Status Transition Rules

Define which statuses to use at each pipeline event.
Replace the values with the exact status names from your project.

| Event | Issue | Target Status |
|-------|-------|--------------|
| Piece issue created | piece | `To Do` |
| Phase issue created | phase | `To Do` |
| Phase execute starts | phase | `In Progress` |
| Phase QA passes | phase | `In Review` |
| Final Review Board passes | phase | `Done` |

> **Important:** Skills will NOT transition issues to `Done` unless the Final Review Board
> explicitly passes. Agents may only move phase issues to `In Progress` or `In Review`.

---

## Commit Message Format

Issue key injection format (inserted as commit message prefix):
```
[{issue_key}] {conventional-commit-message}
```

Example: `[PROJ-42] feat(auth): add token refresh endpoint`

> Set `commit_tag_format` in `.spec-flow.yaml` to override.

---

## Additional Notes

<!-- Add any project-specific integration notes here, e.g.:
- Which board or sprint to assign issues to
- Required labels or components
- Priority defaults
- Assignee rules
-->
