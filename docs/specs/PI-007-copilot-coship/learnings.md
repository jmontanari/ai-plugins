# Learnings: PI-007-copilot-coship

## Copilot CLI smoketest

**Tool version:** GitHub Copilot CLI 1.0.34
**Date:** 2026-04-21
**Maintainer:** Joe

### Install command

```
/plugin install jmontanari/ai-plugins:plugins/spec-flow
```

Install succeeded via Copilot CLI's subdirectory syntax (`owner/repo:path/to/plugin`), which discovers `.claude-plugin/plugin.json` at `plugins/spec-flow/.claude-plugin/plugin.json`. No branch pin used — the install resolves against the repo's default branch (`master`).

**Important:** the `#master-copilot` branch-pin syntax the plan specified does NOT work. [Copilot CLI issue #1296](https://github.com/github/copilot-cli/issues/1296) is an open feature request for branch-pinning; branch/ref pinning is not supported in the current Copilot CLI (v1.0.34 confirmed). The subdirectory syntax was the working alternative.

### Skill invocation

```
/status
```

**Not** `/spec-flow:status` — Claude's plugin-prefixed sigil (`/<plugin>:<skill>`) does NOT port to Copilot CLI. Copilot accepts the bare skill name. This is consistent with the [Copilot Agent Skills doc](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) which describes skills as discovered and loaded automatically by relevance rather than explicitly invoked with a plugin sigil.

### Transcript excerpt

Copilot CLI session output after install + `/status`:

```
● Signal gate complete (shell)
  │ touch /tmp/copilot-gate-done-1137bc51
  └ 1 line...

● Search (glob)
  │ ".spec-flow.yaml"
  └ No matches found

◐ No `.spec-flow.yaml` found, so I'll use defaults: `docs/` for docs_root and `worktrees/` for worktrees_root. Let me now check for the manifest files and charter directory in parallel.

● Search (glob)
  │ "docs/prd/manifest.yaml"
  └ No matches found

● Search (glob)
  │ "docs/manifest.yaml"
  └ No matches found

● Search (glob)
  │ "docs/charter/**"
  └ No matches found

● No pipeline initialized. Run the prd skill to import a PRD and create the manifest.

● GitHub Copilot CLI 1.0.34

  You are running the latest version.
```

### Observations

**What went right:**

- Install via subdirectory syntax succeeded; no branch pin needed.
- The `status` skill loaded, invoked, and executed its full discovery logic (globbed for `.spec-flow.yaml`, `docs/prd/manifest.yaml`, `docs/charter/`).
- The skill produced a correct, context-appropriate response for an uninitialized project.
- The whole install-and-invoke flow took seconds.

**What went surprisingly differently from the plan's assumptions:**

- **Branch pinning is not supported.** The plan's whole `master-copilot` mirror-branch premise assumed a `#branch` or `@branch` syntax that does not exist in Copilot CLI v1.0.34. Issue #1296 is an open feature request. This invalidates a core assumption of PI-007's design.
- **Subdirectory install works directly.** `/plugin install jmontanari/ai-plugins:plugins/spec-flow` installs cleanly from master's plugin subdirectory without any mirror. This means the mirror branch is currently architecturally unnecessary for the Copilot install path.
- **Plugin-prefixed invocation sigil does not port.** `/<plugin>:<skill>` is Claude-specific; Copilot uses bare skill names. The rewrite rule in the spec's Phase 5 encoding checklist (bullet 4: "Drop every `/<plugin>:<skill>` sigil … rewrite to a natural-language skill mention") is therefore relevant at a documentation-content level, but the SKILL.md file itself ports as-is because Copilot's skill-invocation uses the file's frontmatter `name` field.
- **CLAUDE.md at the plugin root was not required for skill discovery.** Copilot CLI discovered and invoked the `status` skill without any AGENTS.md or special naming at the plugin level. The `CLAUDE.md → AGENTS.md` rename the spec required may only matter for agent-level files; skill-level discovery is via `skills/<name>/SKILL.md` which is cross-tool.

**Known limitations / future-work items:**

- Agent dispatch was not tested in this smoketest. The status skill doesn't dispatch a subagent. Agents live in `plugins/spec-flow/agents/*.md` (top-level 12 files) and nested `agents/reflection/`, `agents/review-board/` (7 more files). Per Copilot CLI plugin docs, custom agents are expected at `agents/*.agent.md` — with `.agent.md` extension. On master (without the mirror-branch rename), the agents are `.md` not `.agent.md`. Whether Copilot discovers them is unknown and will need a follow-up smoketest invoking a skill that dispatches an agent (e.g., `/spec`).
- Nested agent subdirs (`agents/reflection/`, `agents/review-board/`) may not be discovered by Copilot's flat-glob `agents/*.agent.md` even if the rename were applied. This is a Copilot CLI design constraint, not a spec-flow bug.
- The hook/setup infrastructure from Phases 2–6 is **preserved but currently dead code** with respect to the Copilot install path. It still represents useful groundwork for:
  - When Copilot CLI adds branch-pinning (Issue #1296 merging upstream), the pattern can re-activate.
  - A future sync-to-separate-repo variant (superpowers `sync-to-codex-plugin.sh` pattern applied to a `jmontanari/spec-flow-copilot` repo) would reuse the `sync_plugin_to_mirror` function as its core.
  - If agent discovery turns out to require the `.agent.md` rename, the infrastructure provides that.

**Subtree-split invocation recorded per spec:**

Setup script used `git subtree split --prefix=plugins/spec-flow -b master-copilot` (pinned REQUIRED mechanism per FR-PI-007-003 step 2). Resulting `master-copilot` tip SHA: `8400e27` (pre-renames from the commit `cf0fadb` — the worktree-context fix). Subtree-split history preserved; AC-9 non-orphan check passed with `commit_count=45` and `oldest_subject='Initial repo commit'`.

### Outcome

**Outcome: PASS**

The install-and-invoke smoketest succeeded. Skills install and invoke correctly on Copilot CLI v1.0.34 via the subdirectory-install syntax. AC-8's PASS-required gate is satisfied.

---

## Three in-phase fixes discovered during Phase 6

Phase 6 surfaced three latent bugs that weren't caught during spec/plan QA. All three were fixed in-phase:

1. **Worktree-context bug** (fix commit `cf0fadb`): the setup script's `.git/hooks/post-commit` path fails in a git worktree where `.git` is a file, not a directory. Fixed by resolving HOOK via `git rev-parse --git-common-dir`.

2. **GIT_DIR leakage into sync commit** (fix commit `04a2509`): when the post-commit hook fires, git sets `GIT_DIR`/`GIT_INDEX_FILE`/`GIT_WORK_TREE` pointing at the committing repo. The sync function's inner `git add`/`git commit` inherited these env vars and operated on the wrong repo — corrupting the throwaway sentinel-test branch. Fixed by wrapping the commit block in a subshell that `unset`s the git env vars.

3. **Hook re-firing on master-copilot's own sync commits** (fix commit `623d446`): the shared `.git/hooks/post-commit` fires on every worktree's commits, including master-copilot's own sync commits. On master-copilot there's no `scripts/` tree, so the hook's `source scripts/lib/...` failed noisily. Fixed by adding an early silent no-op guard: if the shared library isn't present at the expected path, exit 0 silently.

None of these showed up in spec or plan QA — all three require runtime context to surface. The plan's Phase 6 was the first opportunity to catch them.

## Copilot CLI smoketest 2 — agent discovery and dispatch

**Tool version:** GitHub Copilot CLI 1.0.34 (same session as smoketest 1)
**Date:** 2026-04-21
**Maintainer:** Joe

### What was tested

Post-redesign (mirror branch removed; dual-path shipped via `.agent.md` symlinks), re-installed spec-flow from the subdirectory syntax and asked Copilot CLI to invoke a plugin-provided agent. User's prompt was generic ("qa-spec … count files in ../").

### Transcript excerpt

```
● Asked user When you say "qa-spec" do you mean the spec-flow:qa-phase agent?
  └ User selected: Yes — use spec-flow:qa-phase (Recommended)

● Running the spec-flow QA agent to count files in ../ (both non-recursive and recursive) and report top results. I'll instruct the agent to run safe shell commands and return counts and samples. Proceeding.

● Spec-flow:qa-phase Count files in parent directory

● Running local shell commands instead because the spec-flow QA agent cannot be invoked directly. Counting non-recursive and recursive regular files in ../ and listing top 10 largest files. Doing this now.
```

### Findings

1. **Agent discovery works.** Copilot CLI recognized the plugin's custom agents and offered disambiguation: user said "qa-spec"; Copilot offered `spec-flow:qa-phase` as a likely match. The `.agent.md` symlinks committed in commit `8e4e2b1` are being picked up by Copilot CLI's plugin loader.

2. **Direct agent invocation is blocked — by design.** Copilot CLI's message "*the spec-flow QA agent cannot be invoked directly*" is the plugin's own guard working correctly. Spec-flow's execute skill's API encapsulation rule explicitly states: *"`spec-flow:execute` is the only supported way to dispatch phase-level and end-of-piece agents (`implementer`, `tdd-red`, `verify`, `refactor`, `qa-phase`, `qa-phase-lite`, `fix-code`, `reflection/*`). Those agents assume orchestrator-injected context (Mode flag, pre-flight snapshot, oracle anchors, AC matrix, session metrics for reflection agents) and have Rule 0 first-turn reject checks that BLOCK when called directly."* This is not a failure — it's working as the spec-flow architecture intends.

3. **Copilot fell back gracefully.** Instead of erroring out, Copilot ran the requested task (file counting) using its own tool-use. From a UX standpoint that's a reasonable fallback; the user got their answer even though the plugin's agent wasn't used.

4. **The nested-dispatch path (skill → agent) is the real test, and it's not exercised here.** The meaningful test of whether spec-flow's agent architecture works on Copilot CLI would be:
   - Install spec-flow on a fresh project
   - Initialize it (`/charter`, `/prd`)
   - Then invoke a skill that dispatches agents, e.g., `/spec` which dispatches `qa-spec` after writing the spec
   - Observe whether the skill-level orchestration correctly dispatches the subagent on Copilot CLI

   That end-to-end test is deferred — it requires a non-trivial setup (charter + PRD + piece) on the Copilot side, and spec-flow's orchestration model also assumes the Agent tool API which Copilot may or may not have. Tracked as a follow-up.

### What this does NOT disprove

- It does not prove that agent dispatch is broken on Copilot CLI. The direct-invocation path the user tried is a path the plugin itself rejects. The nested path (skill dispatches agent from within its own orchestration) was never exercised.
- It does not invalidate the `.agent.md` symlinks — they successfully enabled agent discovery, which is a prerequisite for any future dispatch path.

### Recommendation

**Keep the `.agent.md` symlinks.** They enable discovery even if full dispatch requires more work in a follow-up piece. Removing them would regress the Copilot-side observability of what agents the plugin provides.

**Document the known gap honestly:** skills work on Copilot CLI today; full agent dispatch from within a skill is untested and would require a dedicated follow-up smoketest on a spec-flow-initialized project inside Copilot CLI. Don't over-claim in the README.

### Outcome

**Outcome: PASS (with scope narrowed)**

The redesigned dual-path approach correctly enables Copilot CLI to install spec-flow and discover its plugin contents (skills + agents). The `.agent.md` symlinks work — discovery is visible. Direct agent invocation is intentionally blocked by the plugin's own guards. Full end-to-end agent dispatch through a skill's orchestration is untested and tracked as follow-up.

---

## Recommendations for future pieces that integrate with Copilot CLI

- **Check feature-gate issues on github/copilot-cli before designing around new syntax.** Issue #1296 was 3 clicks of web search away; its absence in the plan cost us the entire master-copilot mirror infrastructure.
- **A live smoketest would have surfaced the branch-pinning gap at spec time, not execute time.** Consider a minimal "is this syntax actually supported?" check during spec brainstorm when the spec relies on an external tool's feature.
- **Subdirectory install is a cleaner pattern than mirror branches** for multi-plugin marketplaces — it eliminates sync machinery entirely. Future Copilot-CLI-targeting pieces should prefer `/plugin install owner/repo:path/to/plugin` first and only fall back to mirror/sync patterns if subdirectory install has a specific limitation.

---

## Copilot CLI smoketest 3 — `/agents` listing and frontmatter hygiene

**Tool version:** GitHub Copilot CLI 1.0.34 (same session as smoketests 1 and 2)
**Date:** 2026-04-21
**Maintainer:** Joe

### What was tested

Ran `/agents` on Copilot CLI after smoketest 2 to list the custom agents the plugin surfaces. Output included both the agents loaded successfully and a set of warnings for files that failed schema validation.

### Finding 1: Copilot CLI scans `.md` AND `.agent.md`

The warnings reported paths ending in `.md` — NOT `.agent.md`. If Copilot CLI only scanned the `.agent.md` extension, the `.md` files would have been invisible and could not have produced schema-validation warnings. This proves empirically what [GitHub's Custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration) documents: *"The configuration file's name (minus `.md` or `.agent.md`) is used for deduplication between levels."* Both extensions are loaded; the loader deduplicates by basename.

Independent corroboration: DwainTR/superpowers-copilot (a production prior-art plugin) ships `plugins/superpowers/agents/<name>.md` with plain `.md` extensions and no symlink indirection. It works on Copilot CLI without translation.

### Finding 2: Five agent files had frontmatter defects

Copilot CLI's stricter YAML parser surfaced real issues that Claude Code's looser parser had been silently tolerating:

- `implementer.md` — the description line contained unquoted colons (`Mode: TDD`, `Mode: Implement`) that YAML tried to parse as nested mappings. Fixed by wrapping the description value in double quotes.
- `fix-doc.md`, `qa-plan.md`, `qa-prd-review.md`, `qa-spec.md` — these four files had NO frontmatter at all. Pre-existing violation of spec-flow's own CR-001 (agents must declare name + description). Added canonical frontmatter matching the tdd-red/verify/refactor/qa-phase/fix-code siblings.

All five were fixed in commit `e2ffd2f` on the spec/PI-007-copilot-coship branch. The fixes benefit Claude Code too — Claude's Agent tool relies on the frontmatter description field to route invocations, so these were latent defects from before PI-007.

### Decision: drop the `.agent.md` symlinks

With both findings in hand, the `.agent.md` symlinks committed in `8e4e2b1` (smoketest 2's follow-up) became pure redundancy. They were removed:

- Remove the 12 `.agent.md` symlinks under `plugins/spec-flow/agents/` (top-level agents)
- Drop the README section advising Windows users to enable `git config --global core.symlinks true` for the `.agent.md` symlinks
- Update CHANGELOG 2.1.0 to reflect the simplification and the frontmatter fix
- Retain nested-subdir limitation note (`agents/reflection/`, `agents/review-board/` remain outside Copilot's flat-glob discovery — that's a Copilot CLI architecture constraint, not addressable by filename tricks)

The final shape: the same `.md` files serve both hosts. No symlinks, no dual extensions, no content translation. Closer to the superpowers-copilot prior art and closer to the "single source of truth" NFR the spec demanded.

### Negative result: marketplace-root install is NOT supported by Copilot CLI

Tested `/plugin install jmontanari/ai-plugins` (no subdirectory suffix) on Copilot CLI v1.0.34. Result:

```
Failed to install plugin: No plugin.json found in repository. Tried:
.plugin/plugin.json, plugin.json, .github/plugin/plugin.json, .claude-plugin/plugin.json
```

**Meaning:** Copilot CLI's `/plugin install owner/repo` probes exactly four root paths for a `plugin.json` file. It does NOT read `.claude-plugin/marketplace.json` — marketplace.json is a Claude Code concept, not a Copilot CLI concept. This contradicts the earlier hypothesis that DwainTR/superpowers-copilot's marketplace.json enables root-install on Copilot; on closer look, that repo ships an `install.sh` script for the marketplace path, and `/plugin install DwainTR/superpowers-copilot` (root-install) likely fails on Copilot for the same reason ours does.

**Implication for spec-flow:** the subdirectory syntax `/plugin install jmontanari/ai-plugins:plugins/spec-flow` is the only working Copilot CLI install path for multi-plugin marketplace repos. This is the syntax the README documents and the smoketest validated. No change required; the negative result confirms the documented install command.

**Future piece opportunity:** if we want `/plugin install jmontanari/ai-plugins` to work on Copilot CLI, we'd need to add a `.claude-plugin/plugin.json` file (or one at `.github/plugin/plugin.json`, etc.) at the repo root. That file can only describe ONE plugin, not a marketplace of plugins — so it would elect spec-flow as the "default" plugin for the repo while other plugins stay at `owner/repo:subdir`. Not in scope for PI-007; worth evaluating if spec-flow becomes the dominant plugin in the marketplace.

### Related but out-of-scope findings from the Copilot CLI research

- **`/fleet`** is a Copilot CLI built-in command that parallelizes plan execution across multiple subagent dispatches (GitHub docs + [Copilot blog post](https://github.blog/ai-and-ml/github-copilot/run-multiple-agents-at-once-with-fleet-in-copilot-cli/)). Plugin agents are discoverable targets for `/fleet`. Spec-flow's execute skill already implements an orchestration mode (the Phase Scheduler + Phase Groups) that could complement or be complemented by `/fleet`. Whether this is an integration opportunity or an orthogonal concern is worth a future piece — NOT in scope for PI-007.
- **Recursive subagent spawning via the `agent` tool** is available to plugin agents when they declare it in their `tools` frontmatter. Spec-flow agents currently don't, because the design uses `spec-flow:execute` as the sole orchestration entrypoint. No change for PI-007; noted as a capability the project could lean on in a future piece if we decide to allow agent-internal delegation.

### Outcome

**Outcome: PASS (simplification)**

The symlink removal makes the dual-path pattern cleaner: one file extension, one discovery mechanism per agent, both hosts load the same file. The frontmatter fixes close pre-existing CR-001 violations that were masking themselves on Claude's looser parser.
