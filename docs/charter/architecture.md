---
last_updated: 2026-04-21
---

# Architecture

Project-wide architectural decisions for the `shared-plugins` marketplace. Binding on every plugin and every spec-flow piece.

## Top-level layers

- **Marketplace layer** — `.claude-plugin/marketplace.json` at repo root. Lists all plugins with their canonical names, relative source paths, descriptions, and declared versions. Authoritative for "what plugins exist here."
- **Plugin layer** — `plugins/<plugin-name>/` directories. Each is self-contained and independently releasable.
- **Plugin-internal layers** — within each plugin:
  - `.claude-plugin/plugin.json` — plugin manifest (name, description, version, keywords)
  - `skills/<name>/SKILL.md` — entry-point orchestrators invoked via `/plugin:skill`
  - `agents/<name>.md` — narrow subagent templates dispatched by skills
  - `templates/` — starting-shape files (PRD, spec, plan, manifest, charter)
  - `hooks/` — session-start and other harness hooks
  - `reference/` — auto-loaded doctrine documents
  - `README.md`, `CHANGELOG.md` — human-facing docs

## Dependency direction

- `marketplace.json` references plugins by relative path; plugins never reference the marketplace.
- **Plugins are isolated.** No plugin imports, embeds, or references another plugin's internals. If cross-plugin behavior is needed, it goes through the Claude Code harness (tool dispatch, session context), not direct references.
- Within a plugin: `skills` dispatch `agents`; `agents` reuse `templates` and `reference` docs; `hooks` run independently at harness events. Skills and agents never call each other outside the dispatch model — skills orchestrate, agents execute.
- **Forbidden:** one plugin's skill referencing another plugin's skill/agent by file path. Forbidden: a plugin reading files in `plugins/<other>/`.

## Component ownership

| Component | Owner | Boundary |
|---|---|---|
| `.claude-plugin/marketplace.json` | repo maintainer | `plugins` list stays in sync with each plugin's `plugin.json` version; entries sorted by plugin name |
| `plugins/spec-flow/` | spec-flow maintainers | self-contained plugin; all changes bounded to this folder + marketplace.json version bump |
| future `plugins/<other>/` | that plugin's maintainers | same isolation contract |

## External References

- Claude Code plugin spec: https://docs.claude.com/en/docs/claude-code/plugins (primary reference for plugin.json schema, hook contracts, skill/agent invocation)
- Keep a Changelog: https://keepachangelog.com/en/1.1.0/ (CHANGELOG format)
- Semantic Versioning: https://semver.org/ (version bumping rules)
