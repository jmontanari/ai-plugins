---
last_updated: {{date}}
---

# Processes

How this team ships. Binding on spec-flow's own pipeline (e.g., merge protocol, review requirements) and on implementer/review agents.

## Branching model

- **Model:** {{trunk_based | gitflow | github_flow | custom}}
- **Main branch:** {{branch_name}}
- **Feature branch convention:** {{pattern}}
- **Worktrees location:** `{{worktrees_root}}` (per `.spec-flow.yaml`)

## Review policy

- **Required reviewers:** {{count_or_names}}
- **Approval count:** {{n}}
- **Who can self-merge:** {{rule}}
- **When review-board runs:** {{trigger_description}}

## Release cadence

- **Frequency:** {{cadence}}
- **Release branch convention:** {{pattern_if_any}}
- **Release checklist location:** `{{path}}`

## CI gates

What must pass to merge. Implementer agents treat these as the "oracle of done" for Implement-track phases.

- {{gate_1}} — Pass criteria: {{criteria}}
- {{gate_2}} — Pass criteria: {{criteria}}

## Incident response / rollback

- **Rollback procedure:** {{summary_or_link}}
- **Oncall runbook:** {{link}}
- **Post-incident review:** {{process_summary}}

## External References

- `.github/workflows/{{name}}.yml` — CI pipeline source of truth
- [{{wiki_or_runbook_name}}]({{url}}) — operational playbook
