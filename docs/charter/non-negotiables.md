---
last_updated: 2026-04-21
---

# Non-Negotiables (Project)

`NN-C-xxx` — project-wide binding rules for the `shared-plugins` marketplace. Applies to every plugin. Write-once IDs; retired entries become tombstones.

### NN-C-001: Plugin version and marketplace entry must stay in sync
- **Type:** Rule
- **Statement:** Every change to a plugin's `.claude-plugin/plugin.json` `version` field requires a matching update to the plugin's entry in the root `.claude-plugin/marketplace.json`. A release is not complete until both are updated in the same commit (or consecutive commits on the same branch).
- **Scope:** `plugin.json` and `marketplace.json` of any plugin
- **Rationale:** Users install via marketplace entries. Drift causes install-time confusion and wrong-version bug reports. (Finding noted during charter bootstrap 2026-04-21: `marketplace.json` lists spec-flow at 1.1.1 while `plugin.json` is 2.0.0 — backlog item PI-001.)
- **How QA verifies:** `diff <(jq -r .version plugins/<p>/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "<p>") | .version' .claude-plugin/marketplace.json)` must produce no output.

### NN-C-002: Plugins are markdown + config only — no runtime code dependencies
- **Type:** Rule
- **Statement:** A plugin must work on a fresh machine with nothing installed beyond Claude Code, `git`, and a POSIX shell. No `node_modules`, no `pip install`, no Docker, no compiled binaries. Bash scripts in `hooks/` are allowed; anything heavier than bash requires an explicit exception documented in this file.
- **Scope:** Any file committed under `plugins/<plugin>/`
- **Rationale:** The appeal of Claude Code plugins is zero-install. Adding runtime dependencies breaks that promise and fragments adoption.
- **How QA verifies:** Review-board architecture reviewer inspects the diff for `package.json`, `requirements.txt`, `Dockerfile`, `Makefile`, or binary artifacts. Any of these require a documented exception.

### NN-C-003: Backward compatibility within a major version
- **Type:** Rule
- **Statement:** Within a single major version (e.g., all 2.x.y releases), plugins must not break existing user projects. Config keys may gain new optional fields; existing fields must retain their meaning. Skills and agents may gain new behavior; existing invocation patterns must continue to work. Breaking changes require a major-version bump.
- **Scope:** All plugin skills, agents, templates, config schemas, and hook contracts
- **Rationale:** Plugins live in user repos. A silent break costs the user hours. Users trust the semver contract.
- **How QA verifies:** review-board reviewers flag any diff that removes or renames public-surface items (config keys, skill names, template section headers, hook output schema) without a major bump + migration notes in CHANGELOG.

### NN-C-004: Agent frontmatter `name:` is the bare agent name — no plugin prefix
- **Type:** Rule
- **Statement:** An agent file's YAML frontmatter `name:` field contains only the agent's local name (e.g., `name: implementer`), not the plugin-prefixed form (`spec-flow:implementer`). The harness composes the full identifier from `<plugin>:<name>`.
- **Scope:** Every file under `plugins/*/agents/**.md`
- **Rationale:** Prefixing the name field produces doubled identifiers (`spec-flow:spec-flow-implementer`) and breaks short-form invocations. This was the v1.5.0 regression-fix that shipped in commit 38735a6 — the rule codifies the fix so it doesn't regress again.
- **How QA verifies:** `grep -E "^name:\s*<plugin-name>-" plugins/<plugin>/agents/*.md` must return nothing.

### NN-C-005: Hooks silently no-op when their optional dependencies are absent
- **Type:** Rule
- **Statement:** SessionStart (and any other harness-invoked) hooks must not fail or produce user-visible errors when an optional resource is missing. Missing `.spec-flow.yaml` → use template defaults. Missing `docs/charter/` → skip charter doctrine load. Missing `reference/doctrine.md` → inject a short fallback string. Log nothing on missing-optional-input; log to stderr on genuine errors.
- **Scope:** Every script under `plugins/*/hooks/`
- **Rationale:** Hooks run on every session start for every user. A single noisy failure mode degrades trust across the whole plugin.
- **How QA verifies:** Smoke-test the hook in three scenarios: (a) all dependencies present, (b) optional dependencies absent, (c) config file absent. All three must exit 0 with valid JSON on stdout.

### NN-C-006: No destructive operations without explicit user confirmation
- **Type:** Rule
- **Statement:** Skills and agents must not run `git reset --hard`, `rm -rf`, `git push --force`, `git branch -D`, or equivalent destructive operations against repo state without the user having affirmed that specific action in the current conversation. File writes and commits to the current branch are NOT destructive and don't require special confirmation beyond the normal skill flow.
- **Scope:** Any skill or agent markdown file that instructs the harness to run shell commands or file operations
- **Rationale:** Lost work is expensive. "The skill said to" is not an acceptable cause of data loss.
- **How QA verifies:** Review-board scans skill/agent content for the listed dangerous command patterns. Any occurrence must be preceded by a confirmation flow or `--force` user-flag gate.

### NN-C-007: Each plugin ships with a CHANGELOG.md in Keep a Changelog format
- **Type:** Reference
- **Source:** https://keepachangelog.com/en/1.1.0/
- **Scope:** Every plugin at `plugins/<plugin>/CHANGELOG.md`
- **Rationale:** Users need to understand what changed when upgrading. The format provides a consistent structure across plugins in the marketplace.
- **How QA verifies:** File exists; entries have `## [X.Y.Z] — YYYY-MM-DD` headings; uses Added / Changed / Deprecated / Removed / Fixed / Security groupings.

### NN-C-008: Agent prompts are self-contained — no conversation-history assumption
- **Type:** Rule
- **Statement:** A subagent's prompt must carry all context needed for the task. Agents must not rely on seeing the brainstorming conversation, user's earlier messages, previous subagent outputs, or any state outside what the orchestrator explicitly attaches to the prompt. The fresh-context-per-dispatch invariant is load-bearing.
- **Scope:** Every agent template and every skill that dispatches agents
- **Rationale:** Fresh context is how spec-flow prevents scope creep and lets reruns be cheap. If an agent starts assuming conversation history, the discipline collapses.
- **How QA verifies:** Agent templates must not contain phrases like "as we discussed," "you already know," "from the brainstorm above," "per my previous response." Skill dispatch code must interpolate every needed input block into the agent prompt, not rely on implicit memory.

### NN-C-009: Always bump plugin version on changes — per-semver scope, all version-bearing files
- **Type:** Rule
- **Statement:** Every commit (or coherent commit series) that modifies the content of a plugin (any file under `plugins/<plugin>/`) must bump that plugin's version per SemVer in **all version-bearing files for that plugin**. No silent updates. No "small tweak, skip the bump" — the bump is how users know something changed when they `claude plugin update`.
- **Scope:** Any change under `plugins/<plugin>/` affecting behavior, public surface, or documentation. Pure repo-level changes outside `plugins/*/` (root `README.md`, `docs/`, `.gitignore`) do NOT require a plugin bump — they affect the marketplace repo, not any individual plugin.
- **Rationale:** Version numbers are the user's signal that something changed. Unbumped changes are invisible upgrades — users don't know to read the CHANGELOG, don't know to retest, don't know to investigate new behavior. This rule protects the upgrade-awareness contract. Plugins that co-ship for multiple hosts (e.g., Claude Code + Copilot CLI) have more than one plugin descriptor — all must match.

- **Semver scope guidance — pick exactly one tier per change:**

  | Tier | When | Examples |
  |---|---|---|
  | **Patch** (X.Y.`Z+1`) | Bug fixes, typo fixes, documentation clarifications that don't change behavior, internal refactors with identical public surface | Fix a broken link in SKILL.md; clarify a rule in doctrine.md; fix a hook script bug that was producing wrong output |
  | **Minor** (X.`Y+1`.0) | New features, new config keys (with safe defaults), new skills or agents, new templates, new optional capabilities. Backward-compatible additions. | Add a new config key with a default; add a new optional skill; extend a template with an optional section |
  | **Major** (`X+1`.0.0) | Breaking changes. Removed or renamed config keys. Removed or renamed skills/agents/templates. Changed behavior of existing features. Changed file-layout expectations affecting existing user projects. Any change that requires a user to update their project or their project's CLAUDE.md to continue working. | Rename `docs/prd.md` → `docs/prd/prd.md` (v2.0.0 did this via retrofit). Remove a deprecated agent. Flip a config default from `auto` → `off`. |

  When uncertain, go up one tier. Semver violations cost users more than conservative bumps do.

- **All version-bearing files to update for every bump (generic rule):**

  1. **`plugins/<plugin>/.claude-plugin/plugin.json`** — set `"version": "<new-version>"` (Claude Code host descriptor)
  2. **All additional host plugin descriptors** — any `plugins/<plugin>/plugin.json` or equivalent co-shipped for other hosts (e.g., Copilot CLI) must also be bumped to the same version. Check `plugins/<plugin>/docs/releasing.md` for the authoritative per-plugin list.
  3. **`.claude-plugin/marketplace.json`** at repo root — find the plugin's entry in the `plugins` array and update its `"version"` field to match. (This is also enforced by NN-C-001 for sync; NN-C-009 is the rule that you MUST bump, NN-C-001 is the rule that the two places MUST match.)
  4. **`plugins/<plugin>/CHANGELOG.md`** — prepend a new `## [<new-version>] — YYYY-MM-DD` section at the top (below the `# Changelog` title line), following Keep a Changelog groupings (Added / Changed / Deprecated / Removed / Fixed / Security / Migration / Notes for upgraders). At minimum one non-empty grouping; a bump with nothing to document violates this rule — if there's nothing to document, the change didn't warrant a bump in the first place.

  Each plugin maintains a `plugins/<plugin>/docs/releasing.md` that lists the exact file paths for that plugin. Always consult it before cutting a release.

- **How QA verifies:**
  1. `git diff <base>..HEAD -- plugins/<plugin>/.claude-plugin/plugin.json` shows a `-  "version":` / `+  "version":` diff hunk touching the version field.
  2. All additional host descriptors listed in `plugins/<plugin>/docs/releasing.md` show matching version bumps.
  3. `git diff <base>..HEAD -- .claude-plugin/marketplace.json` shows a matching version bump for that plugin's entry.
  4. `git diff <base>..HEAD -- plugins/<plugin>/CHANGELOG.md` shows an added `## [<new-version>]` section at the top with at least one Added/Changed/Fixed/etc. bullet.
  5. All version strings across all descriptors and CHANGELOG match exactly.

  Absence of any file's bump, or mismatch between them, is must-fix — either bump and document properly, or revert the plugin changes entirely.

- **Exception:** Version-bump commits that are themselves the "I'm releasing X.Y.Z" commit are allowed to be a single coherent commit that touches all version-bearing files as its primary purpose. The rule is about the end-state of any branch merging to main, not about per-commit granularity within a feature branch.
