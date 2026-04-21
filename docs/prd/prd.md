# Product Requirements Document — `shared-plugins` Marketplace

**Project:** shared-plugins
**Date:** 2026-04-21
**Status:** active (v2.0.0 just shipped for the spec-flow plugin)
**Charter:** docs/charter/ (NN-C namespace — project-wide binding rules; applies to every piece)

## Goals

- **G-1:** Provide a self-hostable Claude Code plugin marketplace that teams can fork and extend with their own plugins.
- **G-2:** Ship `spec-flow` as a flagship plugin that turns a PRD into merged, reviewed code through a disciplined pipeline (charter → prd → spec → plan → execute → merge).
- **G-3:** Make the marketplace mechanism so low-friction that a new plugin is a `plugins/<name>/` directory with a `plugin.json` and an entry in `marketplace.json` — no build step, no runtime deps.
- **G-4:** Dog-food every process change on this repo first (e.g., applying charter to this repo before recommending it to others).

## Non-Goals

- Not a public plugin registry. No central directory, no search, no install analytics, no sandboxing.
- Not tied to any one framework or language. Plugins are content, not code.
- Not a replacement for Claude Code. This extends it; it depends on it.
- Not a commercial product. MIT-licensed, single-maintainer, hobby-scale.

## Functional Requirements

- **FR-001:** Root `.claude-plugin/marketplace.json` lists all plugins with `name`, `source` (relative path), `description`, `version`, and `author` fields.
- **FR-002:** Each plugin ships with `.claude-plugin/plugin.json` containing `name`, `description`, `version`, `author`, `license`, `keywords`.
- **FR-003:** Users install any plugin with `claude plugin install <plugin>` after adding the marketplace via `claude plugin marketplace add <git-url>`.
- **FR-004:** The `spec-flow` plugin implements the full charter → prd → spec → plan → execute pipeline per `plugins/spec-flow/README.md`.
- **FR-005:** Plugins expose skills via `/<plugin>:<skill>` slash-command invocation (handled by Claude Code's skill discovery).
- **FR-006:** Plugins expose agents via the Agent tool dispatch pattern (fresh-context per-invocation per NN-C-008).
- **FR-007:** Plugins may register harness hooks (SessionStart, etc.) via `plugins/<name>/hooks/hooks.json`.

## Non-Functional Requirements

- **NFR-001:** Plugin installation and session-start are both fast — SessionStart hook output under 500ms on a warm cache; no blocking network calls.
- **NFR-002:** Plugins work fully offline. No network access is required for any core skill or agent.
- **NFR-003:** Plugin upgrades within a major version preserve user-project compatibility (per NN-C-003).
- **NFR-004:** Documentation is the source of truth. No hidden behavior outside what a user can read in `README.md`, `CHANGELOG.md`, and the `SKILL.md` / agent files they invoke.

## Success Metrics

- **SC-001:** A new spec-flow user can complete a charter → PRD → spec → plan → execute cycle on a greenfield project in under a day, without hitting undocumented behavior. Target: 100% of bootstrap attempts on an empty repo.
- **SC-002:** `claude plugin install spec-flow` succeeds on any Claude Code-compatible harness (CC CLI, Cursor plugin mode, Copilot CLI with skill shim). Target: reported-issue rate <1 per quarter for install-time failures.
- **SC-003:** Charter stage (v2.0.0) reduces per-spec NN-citation must-fix findings compared to v1.5.x — measured at a future milestone by comparing `qa-spec` iteration counts before and after charter adoption on at least three real projects.
- **SC-004:** The marketplace hosts a second plugin (beyond spec-flow) within six months of v2.0.0 — validates that the extension mechanism generalizes.

## Non-Negotiables (Product)

Product-specific binding rules. Project-wide rules live in `docs/charter/non-negotiables.md` (`NN-C-xxx`).

### NN-P-001: spec-flow pipeline artifacts are human-readable
- **Type:** Rule
- **Statement:** All pipeline artifacts (charter files, PRD, manifest, specs, plans, learnings, backlog) are plain markdown or YAML. Never binary formats. Never obfuscated representations. A user with `less` and five minutes must be able to audit what the pipeline has produced.
- **Scope:** All spec-flow-produced artifacts under `docs/` on any user project
- **Rationale:** Trust through transparency. If users can't read what the pipeline writes, they can't check its work.
- **How QA verifies:** Review-board spec-compliance reviewer flags any binary file or non-text artifact introduced by a spec-flow skill.

### NN-P-002: No auto-merge to main without explicit human sign-off at two gates
- **Type:** Rule
- **Statement:** spec-flow's execute skill must require human sign-off at (a) each phase's QA completion and (b) the end-of-piece review-board completion. Neither gate can be configured to auto-approve. A piece never merges to main without the human having typed approval at the review-board gate.
- **Scope:** `plugins/spec-flow/skills/execute/SKILL.md` and its review-board dispatch
- **Rationale:** The pipeline's value is the combination of machine speed and human judgment. An auto-merging pipeline is just fast mediocrity.
- **How QA verifies:** Review-board architecture reviewer scans the execute skill's flow for any path that bypasses human sign-off. Any such path is a must-fix.

### NN-P-003: Dog-food before recommend
- **Type:** Rule
- **Statement:** Significant process changes to spec-flow (new stages, new required artifacts, new config keys) must first be applied to this repo itself (or another maintainer-controlled real project) before being documented as recommended-user-behavior. Internal spec-flow v-bump work is allowed to use a previous version's process for its own planning — but the new process must run end-to-end on a real project before users are directed to adopt it.
- **Scope:** Any v-bumping change to spec-flow
- **Rationale:** Documentation drift and unexamined assumptions. The first project to adopt a new process finds the bugs; that project should be maintainer-owned so bug-fixes don't burn external-user goodwill.
- **How QA verifies:** Release commit messages for spec-flow major/minor versions must reference a dog-food run on at least one real project (this repo's `docs/charter/` + `docs/prd/` was the v2.0.0 dog-food run).

## Open Questions

- **OQ-1:** Should `marketplace.json` gain an automated version-sync check via CI? (Charter bootstrap surfaced the drift — PI-001 in backlog. Default: yes, implement in PI-002.)
- **OQ-2:** Does the marketplace need a "deprecation" mechanism for retired plugins, parallel to charter's retirement tombstones? (Default: defer until second plugin exists.)
