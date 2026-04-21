---
last_updated: {{date}}
---

# Non-Negotiables (Project)

`NN-C-xxx` — project-wide binding rules. Security, compliance, architecture, tooling. Rarely change. Write-once IDs (never renumber; retired entries become tombstones).

Every entry uses the structured schema below. `Type: Rule` means inline, self-contained. `Type: Reference` means defers to external content (URL or local path) — the `Source` is what specs/plans/agents must consult.

## Example entries

### NN-C-001: {{name}}
- **Type:** Rule
- **Statement:** {{inline_rule_body}}
- **Scope:** {{where_it_applies}}
- **Rationale:** {{why_binding}}
- **How QA verifies:** {{verification_approach}}

### NN-C-002: {{name}}
- **Type:** Reference
- **Source:** {{url_or_local_path}}
- **Scope:** {{where_it_applies}}
- **Rationale:** {{why_binding}}
- **How QA verifies:** {{verification_approach}}

## Retired entries

Retired IDs stay as tombstones so historical references remain traceable.

### ~~NN-C-XXX: {{original_name}}~~ (RETIRED {{date}})
- **Original statement:** {{original_rule_body}}
- **Reason for retirement:** {{why_removed}}
- **Pieces that cited this:** {{affected_pieces}}
