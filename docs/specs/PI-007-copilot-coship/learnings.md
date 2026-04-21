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

## Recommendations for future pieces that integrate with Copilot CLI

- **Check feature-gate issues on github/copilot-cli before designing around new syntax.** Issue #1296 was 3 clicks of web search away; its absence in the plan cost us the entire master-copilot mirror infrastructure.
- **A live smoketest would have surfaced the branch-pinning gap at spec time, not execute time.** Consider a minimal "is this syntax actually supported?" check during spec brainstorm when the spec relies on an external tool's feature.
- **Subdirectory install is a cleaner pattern than mirror branches** for multi-plugin marketplaces — it eliminates sync machinery entirely. Future Copilot-CLI-targeting pieces should prefer `/plugin install owner/repo:path/to/plugin` first and only fall back to mirror/sync patterns if subdirectory install has a specific limitation.
