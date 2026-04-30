# shared-plugins

A cross-host plugin marketplace. One repository hosts one or more plugins that install cleanly on both **Claude Code** and **GitHub Copilot CLI** from the same source tree — no mirror branches, no conversion pipelines, no per-host forks.

## Plugins

| Plugin | Version | Description |
|---|---|---|
| [**spec-flow**](./plugins/spec-flow) | 3.0.0 | PRD-to-code pipeline with TDD agents, adversarial QA gates, and PRD traceability. |

More plugins will live here over time. Each is self-contained and independently versioned.

---

# What is spec-flow (and why)

spec-flow is the flagship plugin in this marketplace. It turns a product requirements document into shipped, reviewed code through a chain of AI skills and specialized subagents. The sections below are the high-level pitch; for the full walkthrough, concepts, and per-command drill-downs see **[the user guide](./plugins/spec-flow/docs/userguide/README.md)**.

## The problem

AI coding agents are excellent at code but terrible at ambiguity. A vague PRD ("let users export their data") becomes a confident-but-wrong implementation — the agent guesses about format, scope, error handling, authorization, and cheerfully ships something that looks right and fails in production. Once ambiguity is baked into code, review catches syntax, not conceptual drift.

The usual remedy is discipline: write a spec, review it, write tests first, do adversarial review. The trouble is that *discipline-by-intention* collapses under deadline pressure, especially with an AI pair that is always ready to skip ahead.

## The core idea — progressive narrowing

Every pipeline stage takes an ambiguous artifact and produces a less ambiguous one.

```
charter → prd → spec → plan → execute
(constraints) (requirements) (criteria) (paths + signatures) (code + tests)
```

A PRD is ambiguous by nature. A spec resolves it into acceptance criteria. A plan resolves the spec into file paths and function signatures. By the time code is written, the implementer is a narrow executor — every design decision was already made, reviewed, and signed off.

## The three principles

1. **Progressive narrowing.** Ambiguity gets squeezed out one stage at a time, never allowed to skip ahead into code.
2. **Adversarial review at every boundary.** Each artifact (charter, spec, plan, phase diff, final worktree) passes through a dedicated reviewer agent with no context from the conversation that produced it. Reviewers find problems; they don't confirm hunches.
3. **Context isolation via subagents.** Implementation agents never see brainstorming history, spec rationale, or each other's conversations. They see the plan and their oracle of done, nothing more. Main-window context never leaks into code.

## What you get

- **PRD-to-code traceability.** Every line of code maps back to a spec acceptance criterion, which maps to a PRD requirement, which maps to a charter-level non-negotiable.
- **TDD discipline baked in.** Red/Build/Verify/Refactor is enforced by the orchestrator, not the human's memory.
- **Adversarial QA at every stage** — spec review, plan review, per-phase review, final 5-reviewer board before merge.
- **Circuit breakers everywhere.** Agents that loop on the same failure hit a retry cap, then escalate to you. The pipeline is designed not to waste your compute on doomed loops.
- **Charter governance.** Project-wide constraints (architecture, non-negotiables, coding rules) are cited by ID in every spec and enforced at every review gate.
- **Cross-host support.** Runs on Claude Code and GitHub Copilot CLI from the same installation. Same skills, same agents, same workflow.

## What it's not

- **Not a "build this app for me" button.** It won't turn a two-line feature request into shipped code without input. You still brainstorm the PRD, you still sign off on every artifact, you still make judgment calls.
- **Not a replacement for design taste.** The pipeline catches ambiguity and enforces process. It can't tell you whether the product decision is right.
- **Not a silver bullet for trivial work.** Overkill for one-line bug fixes or throwaway experiments.

## Who it's for

Individuals and teams shipping non-trivial features where **correctness**, **traceability**, or **multi-stage review** actually matters. Projects where "tests pass and CI is green" isn't strong enough evidence that the code does what the PRD asked for. Anyone who has watched an AI pair confidently implement the wrong thing and wants structural prevention rather than vigilance.

## When NOT to use it

- One-line bug fixes or single-file tweaks — the pipeline's overhead exceeds the problem's size.
- Exploratory prototypes and throwaway spikes — rigor slows discovery.
- Work that doesn't survive past the current week — the traceability investment doesn't pay back.

---

## Install on Claude Code

Add the marketplace, then install the plugin you want:

```bash
/plugin marketplace add jmontanari/ai-plugins
/plugin install spec-flow@shared-plugins
```

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

## Skills

Once spec-flow is installed, these skills are available on either host via the same slash-command form:

| Command | Description | Details |
|---|---|---|
| `/spec-flow:status` | Pipeline dashboard — start here. Shows which pieces are in which stage and what to work on next. | [guide](./plugins/spec-flow/docs/userguide/commands/status.md) |
| `/spec-flow:charter` | Bootstrap, update, or retrofit the project charter (six binding constraint files). | [guide](./plugins/spec-flow/docs/userguide/commands/charter.md) |
| `/spec-flow:prd` | Import or normalize a PRD and decompose it into implementable pieces. Supports one or more PRDs per project. | [guide](./plugins/spec-flow/docs/userguide/commands/prd.md) |
| `/spec-flow:spec` | Author a detailed specification for one piece from the manifest. | [guide](./plugins/spec-flow/docs/userguide/commands/spec.md) |
| `/spec-flow:plan` | Turn an approved spec into an exhaustive phase-by-phase implementation plan. | [guide](./plugins/spec-flow/docs/userguide/commands/plan.md) |
| `/spec-flow:execute` | Orchestrate implementation of an approved plan phase-by-phase via subagents. | [guide](./plugins/spec-flow/docs/userguide/commands/execute.md) |

New to spec-flow? Start with **[the user guide](./plugins/spec-flow/docs/userguide/README.md)** for the pipeline narrative, concepts, and per-command walkthroughs. Want to see what files the pipeline creates? **[Project layout and artifacts](./plugins/spec-flow/docs/userguide/concepts/project-layout.md)** has the full annotated directory tree and file examples.

**Known limitations on Copilot CLI:**

- Copilot CLI does not support branch-pinning in `/plugin install` ([copilot-cli#1296](https://github.com/github/copilot-cli/issues/1296)). Installs always resolve against the repo's default branch.
- Copilot CLI's custom-agent loader is flat-glob (does not recurse into subdirectories). spec-flow ships all agents flat at `plugins/spec-flow/agents/*.md` with prefixed names (e.g., `review-board-blind.md`, `reflection-process-retro.md`) so every agent is discovered on both hosts.

## How cross-host co-ship works

One source tree serves both hosts without translation. Three pieces make this possible:

- `plugins/<plugin>/CLAUDE.md` is read by both hosts — Claude Code treats it as the plugin-level overview; Copilot CLI auto-loads it as plugin context.
- `plugins/<plugin>/skills/<name>/SKILL.md` is the cross-tool [Agent Skills open standard](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) — identical file, both hosts.
- `plugins/<plugin>/agents/<name>.md` are plain Markdown with YAML frontmatter. Copilot CLI's loader scans both `*.md` and `*.agent.md` and deduplicates by basename per its [Custom agents configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration) reference, so the same files Claude Code discovers are picked up by Copilot CLI. No symlinks, no dual extensions.

See the spec-flow plugin's [PI-007 learnings](./docs/prds/shared/specs/PI-007-copilot-coship/learnings.md) for the full design journey, smoketest transcripts, and the design-iteration detours that were rejected.

## Repository layout

```
.
├── README.md                    (this file)
├── .claude-plugin/
│   └── marketplace.json         marketplace manifest — lists all plugins
├── plugins/
│   └── spec-flow/               one plugin per directory; self-contained
│       ├── .claude-plugin/plugin.json
│       ├── CLAUDE.md            plugin-level overview (both hosts read)
│       ├── README.md            technical reference
│       ├── CHANGELOG.md         Keep-a-Changelog release notes
│       ├── docs/userguide/      human-facing walkthrough (start here)
│       ├── skills/              entry-point orchestrators
│       ├── agents/              narrow subagent templates
│       ├── templates/           starting-shape files
│       ├── hooks/               harness hooks
│       └── reference/           auto-loaded doctrine
├── docs/
│   ├── charter/                 project-wide binding constraints
│   ├── improvement-backlog.md   cross-PRD process learnings
│   └── prds/                    one directory per PRD (multi-PRD layout)
│       └── <prd-slug>/          PRD root — currently `shared/`
│           ├── prd.md           product requirements
│           ├── manifest.yaml    piece enumeration with status + dependencies
│           ├── backlog.md       PRD-scoped deferred work
│           └── specs/<piece>/   per-piece spec + plan + learnings
```

## Doctrine and governance

This marketplace is self-hosting — its own evolution is governed by the `spec-flow` plugin that lives inside it. New work is brainstormed into a PRD, decomposed into pieces in `docs/prds/<prd-slug>/manifest.yaml` (currently `docs/prds/shared/manifest.yaml`), and each piece goes through `spec → plan → execute → review → merge` with TDD discipline and adversarial QA gates at every boundary.

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
