---
last_updated: 2026-04-21
---

# Coding Rules

`CR-xxx` — numbered, citable conventions for the `shared-plugins` marketplace. Specs and plans cite specific `CR-xxx` entries in their "Coding Rules Honored" sections.

## Entries

### CR-001: Agent frontmatter schema — `name` + `description` in YAML
- **Type:** Rule
- **Statement:** Every agent file starts with a YAML frontmatter block containing at minimum `name:` (the bare agent name per NN-C-004) and `description:` (one-line trigger-criteria + dispatch-contract summary). Additional optional keys: `model:` (for tier declarations like `opus`/`sonnet`), `tools:` (to restrict toolset). Blank lines inside the frontmatter block are allowed; the block itself is delimited by `---` on its own lines.
- **Scope:** `plugins/*/agents/**.md`
- **Rationale:** Claude Code's agent discovery keys off frontmatter. Missing or malformed frontmatter means the agent won't register.

### CR-002: Skill frontmatter schema
- **Type:** Rule
- **Statement:** Every `SKILL.md` starts with YAML frontmatter containing `name:` (matching the skill's directory name) and `description:` (when-to-use triggers in third person, e.g., "Use when the user wants..."). The description acts as the skill-selection heuristic Claude uses at invocation time; make it specific.
- **Scope:** `plugins/*/skills/*/SKILL.md`
- **Rationale:** Skills with vague descriptions get selected erratically or not at all.

### CR-003: Template placeholder syntax
- **Type:** Rule
- **Statement:** Template files (under `plugins/*/templates/`) use `{{variable_name}}` for placeholders that skills interpolate at authoring time. `snake_case` for multi-word names. Never nest placeholders. Never use `{%` or other syntaxes — Claude's skills do literal string replacement, not template engines.
- **Scope:** All template files
- **Rationale:** Consistent syntax lets skills use simple search-and-replace without parsing ambiguity.

### CR-004: Conventional-commits format with plugin scope
- **Type:** Reference
- **Source:** https://www.conventionalcommits.org/en/v1.0.0/
- **Scope:** All commit messages
- **Rationale:** Consistent commit messages make the git log usable as changelog material and auto-extractable for release notes. Use `<type>(<scope>): <summary>` where `scope = plugin name` (e.g., `spec-flow`) for plugin-specific changes, or omit scope for repo-level changes. Types in use: `feat`, `fix`, `docs`, `chore`, `refactor`, `release`.

### CR-005: Absolute file paths in documentation when pointing to repo files
- **Type:** Rule
- **Statement:** When documentation references a file in this repo, use a path relative to the repo root (e.g., `plugins/spec-flow/skills/charter/SKILL.md`). Don't use user-home absolute paths (`/home/joe/...`) or relative paths with `../` that depend on the reader's cwd.
- **Scope:** All markdown files in `plugins/*/` and repo-root docs
- **Rationale:** Documentation gets read from many contexts (GitHub web UI, local clones, `cat` on a server). Repo-root-relative paths work everywhere.

### CR-006: CHANGELOG format — Keep a Changelog
- **Type:** Reference
- **Source:** https://keepachangelog.com/en/1.1.0/
- **Scope:** `plugins/*/CHANGELOG.md`
- **Rationale:** Users upgrading need a consistent read. See NN-C-007 for the binding rule; this CR handles the specific format choice.

### CR-007: Config keys documented inline via comments
- **Type:** Rule
- **Statement:** Config keys in `pipeline-config.yaml` and any future plugin config files have inline `# <key-name>:` comments explaining the key's purpose, valid values, default, and — where non-obvious — the rationale behind the default. Comments precede the key-value line; multi-paragraph rationale is fine.
- **Scope:** `plugins/*/templates/pipeline-config.yaml` and any other committed YAML config
- **Rationale:** Users don't read README when they're editing config. The comment next to the key is where they look.

### CR-008: Separation of concerns — thin-orchestrator skills, narrow-executor agents
- **Type:** Rule
- **Statement:** Skills orchestrate: they read config, dispatch agents, evaluate reports, commit state. Skills write minimal code. Agents execute: they perform one narrow task (write failing tests, implement per plan, review artifact). Agents don't dispatch other agents; the skill is the sole orchestrator. A skill that contains implementation logic beyond orchestration, or an agent that spawns sub-agents, is a separation-of-concerns violation.
- **Scope:** `plugins/*/skills/*/SKILL.md` and `plugins/*/agents/*.md`
- **Rationale:** This is spec-flow's load-bearing design principle. Violating it cascades into scope creep (agents start designing) and context pollution (skills start containing implementation detail). Documented in `plugins/spec-flow/README.md`.

### CR-009: Markdown section headings follow semantic hierarchy
- **Type:** Rule
- **Statement:** Every document has exactly one H1 (the title). H2 for top-level sections. H3 for subsections. H4+ used sparingly and only when deep nesting is unavoidable. Never skip levels (no H2 → H4 jumps). In `templates/plan.md` specifically, `### Phase N:` (H3) and `#### Sub-Phase N.m:` (H4) are the Phase Scheduler's detection anchors — changing their levels breaks detection (spec-flow README: "deviating breaks detection").
- **Scope:** All markdown in the repo
- **Rationale:** Parsers (including Claude when reading SKILL.md) key off heading levels. Inconsistent hierarchy produces unreliable section extraction.

## Categories

Entries are organized as a flat numbered list, not grouped by category — but loose groupings are:

- **Schema** (CR-001, CR-002, CR-003): frontmatter + placeholder syntax
- **Commit hygiene** (CR-004)
- **Documentation** (CR-005, CR-006, CR-009)
- **Config** (CR-007)
- **Architecture discipline** (CR-008)

## Retired entries

(none yet)
