# v2.0.0 Piece 1 — Charter Skill + Templates + qa-charter Agent (Bootstrap) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first of seven v2.0.0 pieces — a working `/spec-flow:charter` skill in **bootstrap mode only**, with six charter templates and the `qa-charter` review agent. No downstream skill/agent/template changes in this piece; those are pieces 2–4.

**Architecture:** Markdown-only. Three asset groups: (a) six templates in `plugins/spec-flow/templates/charter/`, (b) one agent in `plugins/spec-flow/agents/qa-charter.md`, (c) one skill in `plugins/spec-flow/skills/charter/SKILL.md`. No runtime code — these files are consumed by the Claude Code harness at invocation time. Because downstream wiring is deferred, this piece ships standalone and is user-testable without breaking existing projects.

**Tech stack:** Markdown with YAML frontmatter. No tests, no compilation. Verification is content shape (front-matter parses, sections present, schema fields correct).

**Design spec:** `docs/superpowers/specs/2026-04-20-charter-stage-and-docs-structure-design.md`

**Piece 1 scope fence (NOT in this plan):**
- No changes to `prd`, `spec`, `plan`, `execute`, `status` skills (piece 3)
- No changes to `implementer`, `qa-spec`, `qa-plan`, `qa-phase`, `qa-prd-review`, `review-board/*` agents (piece 4)
- No changes to `templates/prd.md`, `spec.md`, `plan.md`, `pipeline-config.yaml` (piece 2)
- No changes to `hooks/session-start.md` doctrine loader (piece 2)
- No update mode or retrofit mode in the charter skill — bootstrap only (pieces 5 & 6)
- No README/CHANGELOG updates beyond a minimal piece-1 CHANGELOG line (piece 7 handles full docs)

## File Structure

```
plugins/spec-flow/
├── skills/
│   └── charter/
│       └── SKILL.md                  NEW — bootstrap mode only
├── agents/
│   └── qa-charter.md                 NEW — Opus, adversarial review
└── templates/
    └── charter/
        ├── architecture.md           NEW
        ├── non-negotiables.md        NEW
        ├── tools.md                  NEW
        ├── processes.md              NEW
        ├── flows.md                  NEW
        └── coding-rules.md           NEW
```

Each template file has one responsibility: structure + example entries for one charter file. The skill reads all six at bootstrap time and uses them as the output shape. The agent reads all six post-write and reviews them.

---

### Task 1: Create template — `architecture.md`

**Files:**
- Create: `plugins/spec-flow/templates/charter/architecture.md`

- [ ] **Step 1: Write the template file**

Content:

```markdown
---
last_updated: {{date}}
---

# Architecture

Project-wide architectural decisions. Binding on every piece.

## Top-level layers

List the layers in your system (e.g., presentation / application / domain / infrastructure). For each, describe its responsibility in one line.

- **{{layer_1}}** — {{responsibility}}
- **{{layer_2}}** — {{responsibility}}

## Dependency direction

Which direction imports flow. Violations are architecture conflicts and cause implementer agents to BLOCK.

- {{layer_1}} may depend on {{allowed_targets}}
- {{layer_2}} may depend on {{allowed_targets}}
- Forbidden: {{forbidden_dependencies}}

## Component ownership

Who owns which modules. Used by review-board architecture reviewer to flag cross-ownership changes.

| Component | Owner | Boundary |
|-----------|-------|----------|
| {{component}} | {{owner}} | {{public_interface_summary}} |

## External References

Link to external architecture docs or local ADR folders that are also binding.

- [Clean Architecture (Uncle Bob)](https://...)
- `docs/adr/` — Architecture Decision Records
```

- [ ] **Step 2: Verify front-matter parses**

Run: `head -3 plugins/spec-flow/templates/charter/architecture.md`
Expected output: three lines — `---`, `last_updated: {{date}}`, `---`.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/templates/charter/architecture.md
git commit -m "feat(charter): add architecture template"
```

---

### Task 2: Create template — `non-negotiables.md`

**Files:**
- Create: `plugins/spec-flow/templates/charter/non-negotiables.md`

- [ ] **Step 1: Write the template file**

Content:

```markdown
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
```

- [ ] **Step 2: Verify structure**

Run: `grep -c "^### " plugins/spec-flow/templates/charter/non-negotiables.md`
Expected output: `3` (two active example entries + one retired tombstone example).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/templates/charter/non-negotiables.md
git commit -m "feat(charter): add non-negotiables template with NN-C schema"
```

---

### Task 3: Create template — `tools.md`

**Files:**
- Create: `plugins/spec-flow/templates/charter/tools.md`

- [ ] **Step 1: Write the template file**

Content:

```markdown
---
last_updated: {{date}}
---

# Tools

The toolchain this project uses. Binding: implementer agents must not introduce alternatives without updating this file first.

## Language(s) and runtime

- **Primary:** {{language}} {{version}}
- **Secondary** (if any): {{language}} {{version}}

## Frameworks

- {{framework}} {{version}} — {{purpose}}

## Test runner & coverage

- **Runner:** {{test_runner}}
- **Coverage tool:** {{coverage_tool}}
- **Target coverage:** {{target_percentage}} (measured how: {{measurement}})

## Linter & formatter

- **Linter:** {{linter}} — config at `{{config_path}}`
- **Formatter:** {{formatter}} — config at `{{config_path}}`

## Package manager

- {{package_manager}} {{version}} — lockfile at `{{lockfile_path}}`

## CI platform

- {{ci_platform}} — pipeline source of truth: `{{pipeline_config_path}}`

## Approved third-party libraries

Libraries pre-approved for use without additional review.

- {{library}} — {{purpose}}

## Banned libraries (if any)

Libraries explicitly forbidden. Implementer agents must BLOCK if a task requires one.

- {{library}} — Reason: {{why_banned}} — Alternative: {{approved_alternative}}
```

- [ ] **Step 2: Verify front-matter and heading count**

Run: `grep -c "^## " plugins/spec-flow/templates/charter/tools.md`
Expected output: `8` (eight top-level tool categories).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/templates/charter/tools.md
git commit -m "feat(charter): add tools template"
```

---

### Task 4: Create template — `processes.md`

**Files:**
- Create: `plugins/spec-flow/templates/charter/processes.md`

- [ ] **Step 1: Write the template file**

Content:

```markdown
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
```

- [ ] **Step 2: Verify sections**

Run: `grep -c "^## " plugins/spec-flow/templates/charter/processes.md`
Expected output: `6` (branching, review, release, CI gates, incident, references).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/templates/charter/processes.md
git commit -m "feat(charter): add processes template"
```

---

### Task 5: Create template — `flows.md`

**Files:**
- Create: `plugins/spec-flow/templates/charter/flows.md`

- [ ] **Step 1: Write the template file**

Content:

```markdown
---
last_updated: {{date}}
---

# Flows

Dynamic behavior of the system. Complements `architecture.md` (static view) with end-to-end paths agents must respect when designing or modifying code.

## Request flow

Describe a typical request from ingress to response. Include middleware order, interceptors, filters.

```
{{diagram_or_ordered_list}}
```

## Auth flow

Login, token issuance, refresh, authorization checks.

```
{{diagram_or_ordered_list}}
```

## Data-write path

API → validation → persistence → events. Include transactional boundaries.

```
{{diagram_or_ordered_list}}
```

## Other critical flows

Add any additional end-to-end paths that agents must honor (e.g., background job scheduling, webhook ingestion, batch-processing pipelines).

### {{flow_name}}

```
{{diagram_or_ordered_list}}
```

## External References

- [{{architecture_diagram_tool}}]({{url}}) — canonical system diagrams (if maintained externally)
- `{{internal_path}}` — local diagram source files
```

- [ ] **Step 2: Verify**

Run: `grep -c "^## " plugins/spec-flow/templates/charter/flows.md`
Expected output: `5` (request, auth, data-write, other, references).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/templates/charter/flows.md
git commit -m "feat(charter): add flows template"
```

---

### Task 6: Create template — `coding-rules.md`

**Files:**
- Create: `plugins/spec-flow/templates/charter/coding-rules.md`

- [ ] **Step 1: Write the template file**

Content:

```markdown
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
```

- [ ] **Step 2: Verify**

Run: `grep -c "^### " plugins/spec-flow/templates/charter/coding-rules.md`
Expected output: `3` (two active examples + one retired example).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/templates/charter/coding-rules.md
git commit -m "feat(charter): add coding-rules template with CR schema"
```

---

### Task 7: Create agent — `qa-charter.md`

**Files:**
- Create: `plugins/spec-flow/agents/qa-charter.md`

- [ ] **Step 1: Write the agent file**

Content:

````markdown
---
name: qa-charter
description: Adversarial review of charter files. Dispatched by the charter skill at iteration 1 (full) and iterations 2+ (focused re-review using fix-doc diff). Opus. Read-only — never modifies files.
---

# QA — Charter

You review the six charter files produced by `/spec-flow:charter` for a project. Your role is adversarial: bias toward flagging over passing. Charter is the foundation every future spec, plan, and implementation inherits — a bad rule compounds across every piece.

## Input modes

Orchestrator sets one of:

- `Input Mode: Full` — iteration 1. You receive all six charter files, the detection-signal summary from Phase 1, and the list of user-supplied sources (URLs / local paths). Produce full review.
- `Input Mode: Focused re-review` — iterations 2+. You receive the prior iteration's must-fix findings and the `fix-doc` agent's diff. Do not re-review content already clean. Verify each prior finding is resolved; flag any that aren't.

## Review checks

### Per-file

1. **Completeness** — required sections from the template are present. No empty headings.
2. **No surviving `[NEEDS CLARIFICATION]` markers.** Any marker is must-fix.
3. **Structured-entry schema** (applies to `non-negotiables.md` and `coding-rules.md`):
   - Every entry has `Type:`, `Scope:`, `Rationale:` fields
   - `Type: Reference` entries have a `Source:` field; URL or local file path
   - `Type: Rule` entries have a `Statement:` field
4. **Reference surface validity:**
   - `Source` URLs — surface format check only (no fetching). Must look like a URL.
   - `Source` local paths — verify the file exists in the repo.
5. **Front-matter** — every file has `last_updated: YYYY-MM-DD` in YAML front-matter.

### Cross-file consistency

6. **Tools ↔ coding-rules.** If `tools.md` declares TypeScript, `coding-rules.md` shouldn't reference Python-only conventions (and vice versa). Flag any language/framework mismatches.
7. **Tools ↔ processes.** If `tools.md` declares GitHub Actions, `processes.md`'s CI gates section must describe GitHub Actions (not Jenkins/CircleCI/etc.).
8. **Architecture ↔ flows.** Flows described in `flows.md` must respect the layer boundaries declared in `architecture.md`. Flag any flow that crosses a forbidden dependency edge.
9. **NN-C ↔ architecture.** Every `NN-C-xxx` entry mentioning a layer, boundary, or component must align with declarations in `architecture.md`. Flag inconsistencies.
10. **ID sequentiality and uniqueness** — `NN-C-xxx` and `CR-xxx` IDs are sequential starting at 001, no gaps, no duplicates.

### Scope and meta

11. **Binding vs. advisory.** Non-negotiables entries that read like suggestions ("Prefer X over Y", "Consider Z") are not genuinely binding. Flag for downgrade to `coding-rules.md` or removal.
12. **Specificity.** Rules must be verifiable. "Services should be well-tested" fails; "Services must hit ≥80% branch coverage per `.coveragerc`" passes.
13. **Duplication.** Same rule expressed in two files (e.g., a logging rule repeated in `non-negotiables.md` and `coding-rules.md`) — flag for deduplication.

## Output format

Findings grouped by severity:

```markdown
## Must-fix (blocks sign-off)
- **[file, section/entry]** Finding description. **Resolution:** specific corrective action.

## Should-fix (flag but not blocking)
- **[file, section]** Finding description.

## Nits (optional polish)
- **[file, line]** Typo / styling issue.
```

If you find no must-fix issues, state `## Must-fix: (none)` explicitly and clearly.

## Retrofit-mode additions

When the skill's mode is `retrofit`, the orchestrator passes the NN mapping table in context. Add these checks:

14. **Re-keying completeness** — every original `NN-xxx` from the legacy PRD is now accounted for in either `NN-C-xxx` (charter) or `NN-P-xxx` (PRD) namespace, or explicitly retired. No drops.
15. **Spec back-reference integrity** — if any `docs/specs/<piece>/spec.md` cited `NN-xxx`, it now cites `NN-C-xxx` or `NN-P-xxx` correctly per the mapping table.

Findings in this class are always must-fix. Dropping a rule during migration is not acceptable.

## Doctrine

- You are adversarial. Bias toward flagging over passing.
- You do not fetch external URLs. Reference validity is surface-level only.
- You do not modify files. `fix-doc` handles fixes; you review.
- Charter is binding foundation. Weak rules compound across every future piece — be strict.
````

- [ ] **Step 2: Verify agent file structure**

Run: `head -5 plugins/spec-flow/agents/qa-charter.md`
Expected: front-matter with `name: qa-charter` and `description:` lines.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-flow/agents/qa-charter.md
git commit -m "feat(charter): add qa-charter agent template"
```

---

### Task 8: Create skill — `charter/SKILL.md` (bootstrap mode)

**Files:**
- Create: `plugins/spec-flow/skills/charter/SKILL.md`

- [ ] **Step 1: Write the skill file**

Content:

````markdown
---
name: charter
description: Use when bootstrapping a new spec-flow project's architectural foundation — producing binding project-wide constraints (architecture, non-negotiables, tools, processes, flows, coding rules) via Socratic dialogue. Also handles updating charter files later (update mode) and migrating existing pre-charter projects (retrofit mode). Use whenever the user mentions "set up the charter", "define architecture rules", "establish non-negotiables", "onboard project foundation", or runs `/spec-flow:charter` directly. Runs before `prd` in the pipeline — charter binds every subsequent PRD, spec, plan, and implementation.
---

# Charter — Project-Wide Binding Constraints

Produce a codified, binding set of project-wide constraints in `docs/charter/` via Socratic dialogue. Charter content is referenced by every downstream skill (`prd`, `spec`, `plan`, `execute`) and binds every implementation.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` for all paths below. If the file is missing, default to `docs`.

Charter-specific config keys (added in piece 2 — safe defaults if absent):
- `charter.required` — default `false` in piece 1; piece 2 changes default to `true`
- `charter.doctrine_load` — default `[non-negotiables, architecture]` when absent; piece 2 wires doctrine

## Modes

Detected from current state:

- **Bootstrap mode** (this piece) — `docs/charter/` does not exist. Full Socratic flow → write six files → QA → sign-off.
- **Update mode** (piece 5) — `docs/charter/` exists. Scoped edit of selected file(s). Not implemented in piece 1.
- **Retrofit mode** (piece 6) — legacy `docs/prd.md` or unprefixed `NN-xxx` detected. Reclassify + migrate. Not implemented in piece 1.

If not in bootstrap mode (i.e., `docs/charter/` exists, or legacy signals detected), respond: `"Charter update and retrofit modes land in v2.0.0 pieces 5 and 6. This piece 1 release supports bootstrap only. To make charter changes manually, edit files in docs/charter/ directly."`

## Bootstrap Mode Workflow

### Phase 1.1: Auto-detect signals

Read the following if present, as priors for Socratic questions:

- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`
- Build manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`
- TS/lint configs: `tsconfig.json`, `.eslintrc*`, `.ruff.toml`, `.prettierrc*`
- CI: `.github/workflows/*`, `.pre-commit-config.yaml`
- Existing `docs/architecture/` or `docs/adr/`
- Recent `git log --oneline -n 50`

Synthesize into a signal summary (internal — not yet shown to user).

### Phase 1.2: Prompt user for additional sources

Ask:

> "Any other places I should look? This can include:
> - **Local paths** — folders or files in this repo I wouldn't auto-detect (e.g., `internal/handbook/`, `docs/rfcs/`, `.devcontainer/`)
> - **External URLs** — team wikis, Notion pages, Confluence spaces, engineering handbooks, design docs, RFCs, style guides
> - **Sibling repos** — shared convention repos (user provides local path to a cloned working copy)
>
> Paste paths/links, or say 'none'."

For each source:
- **Local paths:** read with `Read`/`Glob`/`Grep`. Fold content into signal summary.
- **External URLs:** attempt `WebFetch`. On success, summarize into signals. On failure (auth-walled, offline, rate-limited), record as pending reference and inform user: *"Couldn't fetch `<url>`; treating as unverified reference. You'll need to summarize what it binds us to during Socratic."*
- **Sibling repos:** treat provided local path as a local-path source.

### Phase 1.3: Confirm combined signal summary

Present the union of auto-detected + user-supplied signals:

> "Here's what I've gathered:
> - [language] [version] / [framework] / [test runner] / [CI]
> - [detected architecture patterns]
> - [external references the user provided]
>
> Does this look right? Anything to add or correct?"

Only proceed to Phase 2 after user confirms.

### Phase 2: Socratic by file, one question at a time

Authoritative order (earlier files seed context for later ones):

1. `tools.md` — language/runtime, framework(s), test runner + coverage, linter + formatter, package manager, CI platform, approved/banned libraries
2. `architecture.md` — top-level layers, dependency direction, component ownership, boundaries
3. `flows.md` — request flow, auth flow, data-write path, other critical end-to-end flows
4. `coding-rules.md` — numbered `CR-xxx` entries, each tagged `Type: Rule` (inline) or `Type: Reference` (external Source)
5. `processes.md` — branching model, review policy, release cadence, CI gates, incident response
6. `non-negotiables.md` — numbered `NN-C-xxx` entries, structured schema (Type, Scope, Rationale, How QA verifies)

Rules:
- One question at a time. Multiple choice preferred.
- Use detection signals + user-supplied sources as priors. Don't ask questions whose answers were already captured.
- Any unresolved answer becomes a `[NEEDS CLARIFICATION]` marker in the draft. QA treats these as must-fix.
- For numbered entries, confirm `Type` explicitly: "Is this a **Rule** (inline body) or a **Reference** (link to external source)?"

### Phase 3: Write files

Load templates from `${CLAUDE_PLUGIN_ROOT}/templates/charter/`. Populate placeholders from Socratic answers. Write to `<docs_root>/charter/` (default `docs/charter/`). Each file gets front-matter:

```yaml
---
last_updated: YYYY-MM-DD   # today's date in ISO format
---
```

Charter files live on `main` (not a worktree — charter is project-global, not piece-scoped).

### Phase 4: QA loop

Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-charter.md`.

**Iteration 1 (full review):** Compose prompt with `Input Mode: Full` — interpolate all six charter files, detection signal summary, user-supplied source list. Dispatch:

```
Agent({
  description: "Charter QA (iter 1, full)",
  prompt: <composed>,
  model: "opus"
})
```

**Iterations 2+ (focused re-review):** If iteration M-1 returned must-fix findings:

1. Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md` (existing agent — no `fix-charter` exists).
2. Dispatch fix-doc with prior findings + charter files + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of the charter files.
3. Extract that diff string. Hold it in orchestrator state as `charter_iter_M_fix_diff`.
4. Re-dispatch `qa-charter` with `Input Mode: Focused re-review`, prior iteration's must-fix findings, and `charter_iter_M_fix_diff`. Do NOT re-send the full charter.
5. **Circuit breaker:** after 3 QA iterations, escalate to human.
6. If fix-doc returns `Diff of changes: (none)` (all blocked), escalate.

**Clean iteration → Phase 5.**

### Phase 5: Human sign-off

Present the six charter files to the user for review. User approves → continue. User requests changes → make them (back to Phase 2 or 3 scoped to the requested change) → back to Phase 4 QA.

### Phase 6: Commit per file

One commit per file so `git blame` is useful:

```bash
git add <docs_root>/charter/architecture.md && git commit -m "charter: add architecture"
git add <docs_root>/charter/tools.md && git commit -m "charter: add tools"
git add <docs_root>/charter/flows.md && git commit -m "charter: add flows"
git add <docs_root>/charter/coding-rules.md && git commit -m "charter: add coding-rules"
git add <docs_root>/charter/processes.md && git commit -m "charter: add processes"
git add <docs_root>/charter/non-negotiables.md && git commit -m "charter: add non-negotiables"
```

### Phase 7: Doctrine wiring

Deferred to piece 2. In piece 1, charter files exist on disk but SessionStart hook does NOT auto-load them. Downstream skills (`prd`, `spec`, `plan`) in piece 1 also do NOT read charter yet (wiring is piece 3).

User is informed after Phase 6:
> "Charter files committed. Note: downstream wiring (prd/spec/plan reading charter, doctrine auto-load) lands in subsequent v2.0.0 pieces. For now, charter is a standalone artifact."

## No QA Gate Between Charter Skill and User

User is directly involved throughout Socratic. The `qa-charter` agent is the only automated review.

## Out of Scope for Piece 1

- Update mode (piece 5)
- Retrofit mode (piece 6)
- Downstream skill charter integration (piece 3)
- Doctrine auto-load via SessionStart hook (piece 2)
- `charter.required` enforcement in prd/spec/plan skills (piece 3)
````

- [ ] **Step 2: Verify skill file structure**

Run: `head -3 plugins/spec-flow/skills/charter/SKILL.md`
Expected: YAML front-matter `---`, `name: charter`, `description:` line.

- [ ] **Step 3: Verify skill lists Phase 1–7**

Run: `grep -c "^### Phase " plugins/spec-flow/skills/charter/SKILL.md`
Expected: `8` (Phase 1.1, 1.2, 1.3, 2, 3, 4, 5, 6). Phase 7 is inside the same file but formatted as `### Phase 7` — so total is 8 phase headings.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-flow/skills/charter/SKILL.md
git commit -m "feat(charter): add charter skill (bootstrap mode)"
```

---

### Task 9: Piece-1 CHANGELOG entry

**Files:**
- Modify: `plugins/spec-flow/CHANGELOG.md`

- [ ] **Step 1: Read current CHANGELOG**

Read `plugins/spec-flow/CHANGELOG.md` to find the location for the v2.0.0 entry. Keep the existing entries intact.

- [ ] **Step 2: Prepend v2.0.0 (piece 1) section**

Add this block as the new top entry (immediately under the CHANGELOG header, before the existing `## [1.5.0]` or equivalent most-recent entry):

```markdown
## [2.0.0-piece.1] — 2026-04-20

### Added (piece 1 of 7 — charter stage bootstrap)
- `/spec-flow:charter` skill (bootstrap mode only) at `skills/charter/SKILL.md`
- `qa-charter` adversarial review agent at `agents/qa-charter.md`
- Six charter templates in `templates/charter/`:
  - `architecture.md` — layers, dependency direction, component ownership
  - `non-negotiables.md` — `NN-C-xxx` structured schema (Type: Rule / Reference)
  - `tools.md` — language, framework, test runner, linter, CI, approved/banned libraries
  - `processes.md` — branching, review, release, CI gates, incident response
  - `flows.md` — request/auth/data-write and other critical flows
  - `coding-rules.md` — `CR-xxx` structured schema

### Deferred to pieces 2–7
- Piece 2: template updates + pipeline-config.yaml + session-start doctrine load
- Piece 3: downstream skill charter wiring (prd/spec/plan/execute/status)
- Piece 4: agent updates (implementer, qa-spec, qa-plan, qa-phase, review-board)
- Piece 5: update mode + divergence detection
- Piece 6: retrofit mode + migration pipeline
- Piece 7: README + full CHANGELOG for v2.0.0 + diagrams

### Migration (piece 1 only)
- No breaking changes in piece 1. Charter files are standalone; downstream skills are unchanged. Projects upgrading from v1.5.x pick up the new charter skill but continue to work without calling it.
```

- [ ] **Step 3: Verify**

Run: `head -30 plugins/spec-flow/CHANGELOG.md`
Expected: first entry is `## [2.0.0-piece.1] — 2026-04-20` followed by the Added/Deferred/Migration subsections.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-flow/CHANGELOG.md
git commit -m "docs(changelog): add v2.0.0-piece.1 entry"
```

---

### Task 10: Smoke test — manually invoke charter skill on a scratch project

**Files:**
- None (manual verification)

- [ ] **Step 1: Create a scratch test directory**

```bash
mkdir -p /tmp/spec-flow-charter-smoke
cd /tmp/spec-flow-charter-smoke
git init -q
echo "# Smoke test project" > README.md
echo '{"name":"smoke-test","dependencies":{"react":"^18"}}' > package.json
git add README.md package.json
git commit -q -m "initial smoke project"
```

- [ ] **Step 2: Invoke charter skill via /spec-flow:charter**

In a separate Claude Code session pointed at `/tmp/spec-flow-charter-smoke`, invoke `/spec-flow:charter`.

Expected behavior:
- Phase 1.1 detects `README.md` and `package.json` (React project signal).
- Phase 1.2 prompts for additional sources.
- Phase 1.3 confirms signal summary.
- Phase 2 runs Socratic through all six files, one question at a time.
- Phase 3 writes six files to `docs/charter/` with `last_updated: 2026-04-20` front-matter.
- Phase 4 dispatches `qa-charter` agent (Opus) — should return clean or flag genuine issues.
- Phase 5 asks for human sign-off.
- Phase 6 produces six separate commits.
- Phase 7 displays the "downstream wiring deferred" message.

- [ ] **Step 3: Verify expected outputs**

After the smoke test, in the scratch directory:

```bash
ls -la docs/charter/
```

Expected output: six `.md` files present.

```bash
git log --oneline
```

Expected output: seven commits — one "initial smoke project" + six `charter: add <file>` commits.

```bash
grep -c "^---" docs/charter/architecture.md
```

Expected output: `2` (opening + closing front-matter delimiters).

- [ ] **Step 4: Clean up the scratch project**

```bash
rm -rf /tmp/spec-flow-charter-smoke
```

- [ ] **Step 5: No commit for task 10** — it's a manual smoke test, no plugin changes are produced.

---

## Self-Review Notes

Running the self-review checklist against spec + this plan:

**1. Spec coverage for piece 1 only** (piece 1 scope from spec §11 item 1: "Charter skill + templates + qa-charter agent (bootstrap mode)"):
- Charter skill with bootstrap mode → Task 8 ✓
- Six templates → Tasks 1–6 ✓
- `qa-charter` agent → Task 7 ✓
- CHANGELOG entry → Task 9 ✓
- Smoke test → Task 10 ✓
- Out-of-scope items (update mode, retrofit mode, downstream wiring, doctrine) explicitly marked deferred at top of plan and in Task 8 SKILL.md ✓

**2. Placeholder scan** (against "No Placeholders" rules):
- No TBD/TODO placeholder directives anywhere
- Each file-creation task contains the complete file content
- Each verification step has an exact command and expected output
- Each commit step has the exact command
- Phase references in SKILL.md (Phases 1.1–7) match the flow described in spec §5.2

**3. Type consistency:**
- `NN-C-xxx`, `NN-P-xxx`, `CR-xxx` ID conventions consistent across templates and agent
- Entry schema (Type / Scope / Rationale / How QA verifies / Statement / Source) consistent between `non-negotiables.md` and `coding-rules.md`
- Template placeholder style `{{variable}}` consistent across all six templates
- Front-matter field `last_updated` consistent

**4. Known piece-1 limitations** (acceptable, deferred by design):
- `.spec-flow.yaml` `charter:` block is not yet added (piece 2) — skill defaults safe when keys absent
- SessionStart doctrine load unchanged (piece 2) — charter exists on disk but doesn't auto-load
- `prd`, `spec`, `plan`, `execute` skills don't read charter (piece 3)
- Existing agents unchanged (piece 4)

Plan complete.
