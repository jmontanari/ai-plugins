---
charter_snapshot:
  architecture: "{{date}}"
  non-negotiables: "{{date}}"
  tools: "{{date}}"
  processes: "{{date}}"
  flows: "{{date}}"
  coding-rules: "{{date}}"
  integrations: ~          # optional — fill when charter has integration config
jira_key: ~          # optional — populate when MCP configured
jira_url: ~          # optional — populate when MCP configured
---

# Brief: {{slug}} — {{title}}

## Problem Statement

*Describe the problem being solved in one paragraph, including why this change is needed now.*

## Functional Requirements

*List the required change behaviors as bullets.*
- {{requirement_1}}

## Acceptance Criteria

*Capture verifiable outcomes using numbered `AC-N:` statements.*
1. AC-1: {{acceptance_criterion_1}}
2. AC-2: {{acceptance_criterion_2}}

## Non-Negotiables Honored

<!-- Product non-negotiables are not applicable for change-track briefs -->
*List each relevant `NN-C-xxx` entry confirmed during brainstorm and how this brief honors it.*
- {{nn_c_id}} ({{short_name}}): {{how_this_change_honors_it}}

## Coding Rules Honored

*List each relevant `CR-xxx` entry confirmed during brainstorm and how this brief honors it.*
- {{cr_id}} ({{short_name}}): {{how_this_change_honors_it}}

## Out of Scope

*List explicitly excluded work as bullets to keep the change bounded.*
- {{out_of_scope_1}}
