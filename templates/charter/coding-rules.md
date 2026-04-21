---
last_updated: {{date}}
---

# Coding Rules

`CR-xxx` — numbered, citable coding conventions. Specs and plans cite specific `CR-xxx` entries in their "Coding Rules Honored" sections. Review-board architecture reviewer checks CR compliance at final review.

Same entry types as non-negotiables: `Rule` (inline, self-contained) or `Reference` (defers to external content via `Source`).

## Example entries

### CR-001: {{name}}
- **Type:** Rule
- **Statement:** {{inline_rule_body}}
- **Scope:** {{where_it_applies}}
- **Rationale:** {{why_binding}}

### CR-002: {{name}}
- **Type:** Reference
- **Source:** {{url_or_local_path}}
- **Scope:** {{where_it_applies}}
- **Rationale:** {{why_binding}}

## Categories (suggested structure)

Organize entries by category for readability. Common categories:

- **Naming** — file, class, function, test naming
- **Error handling** — exception vs. Result types, logging-on-catch discipline
- **Logging** — structured fields, levels, PII handling
- **Style deltas** — project-specific deviations from linter defaults
- **Comments** — when to write, when not
- **Test conventions** — arrange/act/assert, fixture organization, integration vs. unit

## Retired entries

### ~~CR-XXX: {{original_name}}~~ (RETIRED {{date}})
- **Original statement:** {{original_rule_body}}
- **Reason for retirement:** {{why_removed}}
- **Pieces that cited this:** {{affected_pieces}}
