# shared-plugins

A cross-host plugin marketplace. One repository hosts one or more plugins that install cleanly on both **Claude Code** and **GitHub Copilot CLI** from the same source tree — no mirror branches, no conversion pipelines, no per-host forks.

## Plugins

| Plugin | Version | Description |
|---|---|---|
| [**spec-flow**](./plugins/spec-flow) | 2.1.0 | PRD-to-code pipeline with TDD agents, adversarial QA gates, and PRD traceability. Turns requirements docs into shipped, reviewed code through a chain of skills (`/prd`, `/spec`, `/plan`, `/execute`, `/status`, `/charter`) and specialized subagents. |

Each plugin has its own README with the full design, pipeline walkthrough, and usage reference. Start there after install.

## Install on Claude Code

Add the marketplace, then install the plugin you want:

```bash
/plugin marketplace add jmontanari/ai-plugins
/plugin install spec-flow@shared-plugins
```

Skills are then invocable with the plugin-prefixed sigil: `/spec-flow:status`, `/spec-flow:spec`, etc.

## Install on GitHub Copilot CLI

Two paths are supported (Copilot CLI v1.0.34+). Pick whichever fits your workflow.

**Option 1 — direct subdirectory install (1 step):**

```text
/plugin install jmontanari/ai-plugins:plugins/spec-flow
```

Installs a single plugin without registering the marketplace. Best if you only need one plugin from this repo.

**Option 2 — marketplace install (2 steps):**

```text
/plugin marketplace add jmontanari/ai-plugins
/plugin install spec-flow@shared-plugins
```

Registers the `shared-plugins` marketplace and then installs a plugin from it. Recommended if you expect to install multiple plugins from this repo over time.

**Skill invocation differs only in the plugin-separator character** — skill names are preserved across hosts. Claude Code uses a colon (`/spec-flow:status`); Copilot CLI uses a slash (`/spec-flow/status`). Substitute the separator when porting commands between hosts.

**Known limitations on Copilot CLI:**

- Copilot CLI does not support branch-pinning in `/plugin install` ([copilot-cli#1296](https://github.com/github/copilot-cli/issues/1296)). Installs always resolve against the repo's default branch.
- Nested subagent directories (`plugins/<plugin>/agents/reflection/`, `agents/review-board/`) are not discovered by Copilot CLI's flat-glob agent loader. Skills that dispatch those nested agents work only on Claude Code. Top-level agents work on both hosts.

## How cross-host co-ship works

One source tree serves both hosts without translation. Three pieces make this possible:

- `plugins/<plugin>/CLAUDE.md` is read by both hosts — Claude Code treats it as the plugin-level overview; Copilot CLI auto-loads it as plugin context.
- `plugins/<plugin>/skills/<name>/SKILL.md` is the cross-tool [Agent Skills open standard](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) — identical file, both hosts.
- `plugins/<plugin>/agents/<name>.md` are plain Markdown with YAML frontmatter. Copilot CLI's loader scans both `*.md` and `*.agent.md` and deduplicates by basename per its [Custom agents configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration) reference, so the same files Claude Code discovers are picked up by Copilot CLI. No symlinks, no dual extensions.

See the spec-flow plugin's [PI-007 learnings](./docs/specs/PI-007-copilot-coship/learnings.md) for the full design journey, smoketest transcripts, and the design-iteration detours that were rejected.

## Repository layout

```
.
├── README.md                    (this file)
├── .claude-plugin/
│   └── marketplace.json         marketplace manifest — lists all plugins
├── plugins/
│   └── spec-flow/               one plugin per directory; self-contained
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── CLAUDE.md            plugin-level overview (both hosts read)
│       ├── README.md            human-facing plugin docs
│       ├── CHANGELOG.md         Keep-a-Changelog-format release notes
│       ├── skills/              entry-point orchestrators
│       ├── agents/              narrow subagent templates
│       ├── templates/           starting-shape files
│       ├── hooks/               harness hooks
│       └── reference/           auto-loaded doctrine
├── docs/
│   ├── charter/                 project-wide binding constraints
│   ├── prd/                     product requirements + piece manifest
│   └── specs/                   per-piece spec + plan + learnings
```

## Doctrine and governance

This marketplace is self-hosting — its own evolution is governed by the `spec-flow` plugin that lives inside it. New work is brainstormed into a PRD, decomposed into pieces in `docs/prd/manifest.yaml`, and each piece goes through `spec → plan → execute → review → merge` with TDD discipline and adversarial QA gates at every boundary.

Binding project-wide rules live under `docs/charter/`:

- `architecture.md` — layer boundaries, plugin isolation, dependency direction.
- `non-negotiables.md` — NN-C-xxx entries the whole marketplace honors (e.g., marketplace/plugin version sync, POSIX-only tooling).
- `coding-rules.md` — CR-xxx conventions applied across all plugins.
- `processes.md`, `flows.md`, `tools.md` — how work gets done in this repo.

## Adding a new plugin

1. Create `plugins/<your-plugin>/` with its own `.claude-plugin/plugin.json`.
2. Add an entry to `.claude-plugin/marketplace.json` under `plugins`. The `source` value is relative to the marketplace.json directory (e.g. `./plugins/your-plugin`). Do **not** add a `metadata.pluginRoot` field — Copilot CLI concatenates it with `source` and produces duplicated paths.
3. Author a `CLAUDE.md` at the plugin root so both hosts can auto-load the plugin overview.
4. Keep the plugin self-contained — no imports from or references to other plugins' internals.
5. Bump the plugin's `version` field on each release in **both** `plugin.json` and the matching `marketplace.json` entry (this is enforced by NN-C-001 and will be CI-checked when PI-002 lands).

## License

MIT (per-plugin — see each plugin's `plugin.json`).
