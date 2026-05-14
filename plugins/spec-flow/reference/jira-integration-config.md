# Jira Integration Configuration

Reference for projects using Jira with the spec-flow pipeline. Skills read these rules but never write to this file — it is team-authored configuration.

Reference: `plugins/spec-flow/reference/integration-capability-check.md`

---

## Issue Hierarchy

Define the full parent-to-child chain of Jira issue types as an ordered `hierarchy:` list in
`.spec-flow.yaml`. Each entry's parent is the entry immediately above it in the list.

```yaml
# hierarchy: ordered parent-to-child chain of issue types.
# managed: false  — exists before spec-flow; key recorded manually in the named artifact.
# managed_by: <skill> — created and key recorded by that skill.
# artifact: which spec-flow file holds this level's key (prd | spec | plan).
# key_field: field name written into that artifact's front-matter (standardized: jira_key).
# naming: override default title format; ~ uses built-in default.
hierarchy:
  - type: Epic              # or Initiative, Theme, Capability — whatever your top level is
    managed: false          # create manually in Jira; record key in prd.md front-matter
    artifact: prd
    key_field: jira_key

  - type: Story             # or Epic, Feature — the per-piece issue type
    managed_by: spec        # spec skill creates this and writes jira_key to spec.md
    artifact: spec
    key_field: jira_key
    naming: ~               # ~ = default: "{piece-slug} — {piece description from manifest}"

  - type: SubTask           # or Task — the per-phase issue type
    managed_by: plan        # plan skill creates one per phase and writes jira_key to plan.md
    artifact: plan
    key_field: jira_key
    naming: ~               # ~ = default: "[phase] {piece-slug}/{phase-number} — {phase-name}"
```

The resolved chain for the example above:
```
Epic    (managed: false — key at prd.md[jira_key])
  └─ Story    (managed_by: spec — spec skill creates; key at spec.md[jira_key])
       └─ SubTask  (managed_by: plan — plan creates one per phase; key at plan.md[jira_key])
```

**Parent enforcement rule:** when a `managed: false` entry sits above a `managed_by:` entry,
the parent key is **required**. The managing skill reads the artifact and field from the entry
above, checks that the key is present, and passes `additional_fields: {"parent": "<key>"}` to
`create_issue`. If the key is absent, the skill refuses with a clear error — it does not
silently create a parentless issue.

**Key fields written by skills (standardized field name `jira_key`):**
- `jira_key:` in `prd.md` → key of the manually-created top-level issue (was `parent_key:`)
- `jira_key:` in `spec.md` → key of the piece issue created by the spec skill (was `epic_key:`)
- `jira_url:` in `spec.md` → browse URL for the piece issue (was `epic_url:`)
- `jira_key:` per phase in `plan.md` → key of the phase issue created by plan skill (was `jira_task:`)
- `jira_url:` per phase in `plan.md` → browse URL for the phase issue

---

## Naming Conventions

Per-level naming overrides live in each hierarchy entry's `naming:` key. Set to `~` to use
the built-in default for that level.

Piece-level issue (created by spec skill — the `managed_by: spec` hierarchy entry):
```
{piece-slug} — {piece description from manifest}
```

Phase-level issues (created by plan skill — the `managed_by: plan` hierarchy entry):
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
