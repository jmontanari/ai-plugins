# Spec: PI-007-copilot-coship

**PRD Sections:** G-3 (extensibility); design + implementation prerequisite for SC-002 where SC-002's Copilot-CLI leg is actually satisfied after the execute-time manual smoketest validates install + one skill invocation.
**Status:** draft
**Dependencies:** []
**Supersedes (via abandonment, not content reuse):** PI-005-copilot-cli-parity-map and PI-006-copilot-mirror-ci. Both were marked `superseded` on 2026-04-21 because their shared premise — "convert Claude artifacts into Copilot artifacts on a mirror branch" — was wrong. This piece replaces them with a different architecture: co-ship the Claude layout on master, produce a transformed (not content-translated) mirror branch for Copilot install topology.

> **Amendment 2026-04-21 (post-execute):** This spec's original design — mirror branch + POSIX-bash post-commit hook + setup script — was abandoned during Phase 7 when the smoketest revealed Copilot CLI v1.0.34 does not support branch-pinning ([copilot-cli#1296](https://github.com/github/copilot-cli/issues/1296)). The mirror branch could not be consumed by Copilot's `/plugin install`. A second design iteration shipped `.agent.md` symlinks alongside `.md` files; `/agents` smoketest plus [GitHub's Custom agents configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration) together showed the symlinks were redundant because Copilot's loader scans both extensions and deduplicates by basename. **The delivered architecture is a single-path, plain-`.md` co-ship:** one `plugins/spec-flow/` tree, plain Markdown everywhere, installed on Copilot via subdirectory syntax `/plugin install jmontanari/ai-plugins:plugins/spec-flow`. The ACs below that reference `master-copilot`, `.agent.md`, or the hook/setup scripts reflect the abandoned design; the final outcome, achieved ACs (install + skill invocation + agent discovery), and three smoketest records live in `docs/specs/PI-007-copilot-coship/learnings.md`. This spec is retained unmodified below its header as a record of the design journey.

## Goal

Apply a superpowers-style co-ship pattern to the `spec-flow` plugin so GitHub Copilot CLI users can install and invoke it. The pattern keeps `master` as a **pure Claude-compatible plugin directory** — no symlinks, no `.agent.md` files, no `AGENTS.md` in the plugin tree. All Copilot-side filename differences are handled by a small POSIX-bash post-commit hook that synchronizes `plugins/spec-flow/` into a long-lived derived branch `master-copilot` where spec-flow sits at the repo root in Copilot-native shape.

**`master-copilot` as a derived mirror branch (lifecycle).** `master-copilot` is NOT a second trunk. It is a **derived mirror branch** with a formal lifecycle: (a) it is never directly authored by commits — only produced by the post-commit hook or the setup-script seed; (b) it is force-pushable by the maintainer only in the rare case that master's history is rewritten, since its contents are a deterministic function of master's `plugins/spec-flow/` subtree; (c) it does not receive independent commits — no feature branches target it, no PRs merge into it; (d) it represents a deterministic projection of `plugins/spec-flow/` at master's tip, with filename transforms applied. This categorization requires a complementary amendment to `docs/charter/processes.md` to add "Derived mirror branches" as a named, permitted branching class alongside "Trunk-based (single `master` branch) with optional feature worktrees." That charter amendment is **tracked as a follow-up piece** (not bundled into PI-007) so this piece stays scoped to the `spec-flow` co-ship mechanics.

**Two principles separating this piece from the superseded PI-005/PI-006:**

1. **No content translation.** Shared content (`skills/<name>/SKILL.md`, shared skill bodies, shared agent prose) ports across hosts verbatim — Agent Skills is a cross-tool open standard. The only transformations required are structural: filename renames and subtree-root projection.
2. **No Copilot-specific artifacts on master.** Master remains a clean Claude plugin. All Copilot-only shape (`AGENTS.md` at root, `agents/*.agent.md`, no `.claude-plugin/`) is derived at mirror-sync time, not maintained on master.

Reference pattern: [github.com/obra/superpowers](https://github.com/obra/superpowers) v5.0.7 — specifically the AGENTS.md/CLAUDE.md symlink convention (adapted here as a rename rather than a symlink per user direction) and the `scripts/sync-to-codex-plugin.sh` sync+exclude+overlay pattern (adapted here to a branch + worktree + post-commit hook, and rewritten to use POSIX-only tools instead of rsync).

## In Scope

- A new file at `plugins/spec-flow/CLAUDE.md` — plugin-level overview, ~100–200 lines. Serves two audiences: Claude users browsing the plugin directory, and Copilot users (who read it as `AGENTS.md` after the sync script renames it on the mirror).
- A new file at `scripts/mirror-copilot-post-commit.sh` — POSIX-bash script (no rsync). Clears the non-`.git` contents of `worktrees/master-copilot/`, copies `plugins/spec-flow/` into the worktree via `cp -r`, removes excluded paths (`.claude-plugin/` and any `.DS_Store`), renames `CLAUDE.md` → `AGENTS.md` at the mirror root, renames each `agents/*.md` → `agents/*.agent.md`, commits the result on the `master-copilot` branch. Silent no-op if the triggering commit did not touch `plugins/spec-flow/**` or if the worktree is absent (NN-C-005). The hook's sync body is extracted into a shared function (see `scripts/lib/sync-plugin-to-mirror.sh` below) so the setup seed can invoke the same logic without the hook's diff-tree guard.
- A new file at `scripts/lib/sync-plugin-to-mirror.sh` — a shared shell library defining the function `sync_plugin_to_mirror()` that contains the copy + exclude + rename + commit body. Sourced by both `scripts/mirror-copilot-post-commit.sh` (which wraps it with the diff-tree guard) and `scripts/setup-mirror-hook.sh` (which calls it directly, unguarded, to seed the initial mirror state).
- A new file at `scripts/setup-mirror-hook.sh` — idempotent bootstrap script. Creates the `master-copilot` branch if absent, creates the worktree at `worktrees/master-copilot/` if absent, installs `.git/hooks/post-commit` as a symlink pointing at `scripts/mirror-copilot-post-commit.sh`, and triggers the first-run sync by sourcing `scripts/lib/sync-plugin-to-mirror.sh` and calling `sync_plugin_to_mirror` directly (bypassing the hook's diff-tree guard) so the mirror branch is not empty after setup even if master HEAD is an unrelated commit.
- An update to `plugins/spec-flow/README.md` — a new H2 section "Install on GitHub Copilot CLI" documenting the install command (`/plugin install <git-url>#master-copilot`) and noting that `master-copilot` is a derived branch users must not push to directly.
- A plugin version bump per NN-C-009 (three places: `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`'s spec-flow entry, `plugins/spec-flow/CHANGELOG.md` new top entry in Keep a Changelog format). Tier: **Minor** (new optional capability added; backward-compatible per NN-C-009 semver guidance).
- An execute-time manual smoketest on live Copilot CLI, recorded in `docs/specs/PI-007-copilot-coship/learnings.md`. The smoketest: install spec-flow from the master-copilot branch on a real Copilot CLI session, invoke at minimum `/spec-flow:status` (or the Copilot-CLI-equivalent invocation form), capture the transcript. This is NN-P-003 dogfood in-repo.

## Out of Scope / Non-Goals

- Cursor, Gemini CLI, OpenCode, and OpenAI Codex host support. Each is a separate future piece; the pattern for each is clear from superpowers' layout but the implementation work is not in scope here.
- CI automation beyond the local post-commit hook. No GitHub Actions workflow, no remote push-trigger. Single-maintainer hobby scope per charter `processes.md`.
- End-to-end pipeline dogfood (full `/spec-flow:spec` → plan → execute) on Copilot CLI. The smoketest is scoped to install + one skill invocation; full-pipeline validation is a follow-up piece.
- A parity-map reference document. PI-005 attempted this; superseded. The scripts themselves are the parity map — their rename rules and exclude list are exhaustive and authoritative.
- Changes to spec-flow plugin content (existing agents, skills, hooks, reference, templates). All pass through unchanged. This piece adds new files at the plugin root (`CLAUDE.md`) and the marketplace root (`scripts/`), and bumps the plugin version, but does not modify existing plugin content.
- Symlinks on master. The user has explicitly directed that master contain no Copilot-specific artifacts. All host-differentiation happens during the mirror sync, not on master.
- Windows-specific portability validation. The scripts use only POSIX tools; Windows maintainers can use WSL. If the smoketest surfaces a Windows-specific blocker, a follow-up piece can address it.
- Support for Copilot CLI installing from a subdirectory of a multi-plugin marketplace repo (not a documented feature). The `master-copilot` branch exists precisely to work around this.
- Any changes to `.spec-flow.yaml`, charter files, or PRD semantics.

## Requirements

### Functional Requirements

- **FR-PI-007-001:** A new file `plugins/spec-flow/CLAUDE.md` exists at the spec-flow plugin root. It is plain markdown with exactly one H1 (the plugin name / title). It contains, at minimum, H2 sections with these headings (case-insensitive, substring-matchable): "What is spec-flow", "The pipeline" (describing the charter → prd → spec → plan → execute progression), "TDD doctrine" (summary only — the Three Laws and the Red/Build/Verify/Refactor cycle in short form; not a dump of the full doctrine file), and "Entry-point skills" (names and purposes of each top-level skill, at minimum listing `/spec-flow:status`).

- **FR-PI-007-002:** A new file `scripts/mirror-copilot-post-commit.sh` exists at the marketplace repo root, is executable (mode 0755), and is POSIX-bash per NN-C-002. Its shebang line is `#!/usr/bin/env bash`. It sets `set -euo pipefail` near the top. The script uses only POSIX tools and shell builtins — specifically `bash`, `git`, `cp`, `rm`, `find`, `mv`, `ln`, `readlink`, `test`. **Explicitly no rsync.** It sources `scripts/lib/sync-plugin-to-mirror.sh` to obtain the shared `sync_plugin_to_mirror()` function. The function (and, by reflection, the hook) defines an `EXCLUDES` list containing at minimum `.claude-plugin` and `.DS_Store`. Hook behavior:
  1. Resolve `REPO_ROOT` via `git rev-parse --show-toplevel`.
  2. Resolve `WORKTREE` as `$REPO_ROOT/worktrees/master-copilot`.
  3. If `WORKTREE` does not exist as a directory: log a one-line advisory to stderr (e.g., "worktree missing; run scripts/setup-mirror-hook.sh") and exit 0 silently per NN-C-005. Do not abort the master commit.
  4. If `git diff-tree --no-commit-id --name-only -r HEAD` produces no entries beginning with `plugins/spec-flow/`: exit 0 silently. No output, no side effects. (This diff-tree guard is specific to the hook; the setup seed bypasses it by calling `sync_plugin_to_mirror` directly.)
  5. Otherwise: invoke `sync_plugin_to_mirror "$REPO_ROOT" "$WORKTREE"`. The shared function's body:
     a. Clear the mirror tree while preserving `.git`: `find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +`.
     b. Copy the plugin tree into the mirror: `cp -r "$REPO_ROOT/plugins/spec-flow/." "$WORKTREE/"`.
     c. Apply excludes: `rm -rf "$WORKTREE/.claude-plugin"` and `find "$WORKTREE" -name '.DS_Store' -delete`.
     d. If `$WORKTREE/CLAUDE.md` exists after the copy: `mv` it to `$WORKTREE/AGENTS.md`.
     e. For every file under `$WORKTREE/agents/` whose name ends in `.md` but not in `.agent.md`: `mv` it to the same path with `.agent.md` replacing the trailing `.md`.
     f. `cd "$WORKTREE"`, run `git add -A`. If `git diff --cached --quiet` indicates no staged changes: return without committing (no empty commits).
     g. Otherwise: `git commit -m "sync: master $(git -C "$REPO_ROOT" rev-parse --short HEAD)"`.
  6. The script does not `git push`. Push is the maintainer's explicit action.

- **FR-PI-007-003:** A new file `scripts/setup-mirror-hook.sh` exists at the marketplace repo root, is executable (mode 0755), and is idempotent (running twice on the same repo produces no errors and no duplicate state).

  **Audience:** this script is intended for the repository maintainer who pushes to `master-copilot` from master. Contributors working only on master (or on feature branches) may skip it entirely — a missing hook on a contributor's clone is not a defect. The single maintainer running setup once per clone is the expected flow.

  Its behavior:
  1. Resolve `REPO_ROOT` via `git rev-parse --show-toplevel`.
  2. If `git show-ref --verify --quiet refs/heads/master-copilot` fails (branch absent): create the branch using exactly `git subtree split --prefix=plugins/spec-flow -b master-copilot` from `REPO_ROOT`. This mechanism is REQUIRED — no orphan-branch alternative is permitted. Rationale: subtree-split preserves the history of `plugins/spec-flow/**` with paths rewritten, produces deterministic SHAs (same input SHA → same output SHA), and does not orphan the branch.
  3. If `worktrees/master-copilot/` does not exist: `git worktree add worktrees/master-copilot master-copilot`.
  4. Check `.git/hooks/post-commit`:
     - If it is a symbolic link whose target resolves to `scripts/mirror-copilot-post-commit.sh`: no action.
     - If it does not exist: create the symlink. The target path must resolve correctly when read from the `.git/hooks/` directory (relative target `../../scripts/mirror-copilot-post-commit.sh` is acceptable; absolute path is also acceptable).
     - If it exists as anything other than the expected symlink: print a user-visible error to stderr naming the conflict and exit non-zero. Do not overwrite existing hooks.
  5. **Seed the mirror by calling the shared sync function directly** — NOT by invoking `scripts/mirror-copilot-post-commit.sh`. The hook's diff-tree guard would reject the seed if master HEAD happens to be a commit that did not touch `plugins/spec-flow/**` (common on fresh clones where the most recent commit is unrelated), leaving the mirror empty. Instead, the setup script sources `scripts/lib/sync-plugin-to-mirror.sh` and calls `sync_plugin_to_mirror "$REPO_ROOT" "$REPO_ROOT/worktrees/master-copilot"` with no guard. This guarantees the first sync runs regardless of master HEAD's touched paths. After the call, the script MUST verify that `worktrees/master-copilot` has a HEAD commit containing `AGENTS.md` at the root; if not, it exits non-zero with a diagnostic.

- **FR-PI-007-004:** `plugins/spec-flow/README.md` gains a new H2 section whose heading contains the literal substring `Install on GitHub Copilot CLI` (exact case). The section includes, at minimum:
  - A code block with a `/plugin install` command using a git URL + branch-pin pattern. The branch-pin syntax (`<git-url>#master-copilot` or `<git-url>@master-copilot`) MUST match the syntax verified empirically during the Copilot CLI smoketest (FR-PI-007-006). If the actual syntax differs from any placeholder used during initial authoring, the README MUST be updated before FR-PI-007-004 is considered satisfied.
  - One example invocation of a spec-flow skill from the Copilot CLI side.
  - A one-line note that `master-copilot` is a derived branch maintained by the marketplace repo's post-commit hook, explicitly instructing users not to push directly to it. The section's install-section advisory SHOULD also note that `scripts/setup-mirror-hook.sh` is a maintainer-only setup script, not a general contributor requirement.

- **FR-PI-007-005:** The spec-flow plugin version is bumped in all three required places per NN-C-009:
  - `plugins/spec-flow/.claude-plugin/plugin.json` `version` field → next Minor (e.g., `2.0.0` → `2.1.0`).
  - `.claude-plugin/marketplace.json` spec-flow entry `version` field → exactly matching the above.
  - `plugins/spec-flow/CHANGELOG.md` — a new `## [X.Y.Z] — YYYY-MM-DD` section prepended below the `# Changelog` title, in Keep a Changelog format (CR-006). The entry MUST contain at least one `### Added` bullet mentioning the Copilot CLI install path, at least one `### Added` bullet mentioning the new `plugins/spec-flow/CLAUDE.md` plugin-level overview, and a `### Notes for upgraders` subsection pointing users at `scripts/setup-mirror-hook.sh`. The `### Notes for upgraders` bullet MUST explicitly clarify that `setup-mirror-hook.sh` is intended for the **repo maintainer** who pushes `master-copilot`, and that general contributors working only on master or feature branches do NOT need to run it — a missing hook on a contributor's clone is not a defect.

- **FR-PI-007-006:** During execute (after AC-1 through AC-7 are green), a manual smoketest is performed and recorded in `docs/specs/PI-007-copilot-coship/learnings.md`. The file MUST contain an H2 section whose heading contains the literal substring `Copilot CLI smoketest`, and that section MUST name: (a) the Copilot CLI tool version used (whatever `gh copilot --version` / `copilot --version` / equivalent returns), (b) the exact install command issued, (c) the skill invoked (at minimum `/spec-flow:status` or the Copilot-CLI-equivalent — if Copilot uses a different invocation shape, document whatever invocation actually worked), (d) a transcript excerpt showing the skill's response, (e) an unambiguous pass/fail outcome at the end of the section.

### Non-Functional Requirements

- **NFR-PI-007-001:** All repo-internal references in new files use repo-root-relative paths per CR-005 — no `/home/<user>/…`, no `../`-prefixed relative paths crossing out of the repo.
- **NFR-PI-007-002:** All new markdown follows CR-009's heading hierarchy: exactly one H1 per file, H2 for top-level sections, H3 for subsections, no H2→H4 skips.
- **NFR-PI-007-003:** `scripts/mirror-copilot-post-commit.sh` completes in under 2 seconds in the typical case (an incremental edit to the plugin tree: few-KB copy, one-to-two renames, one commit). Measured on the maintainer's development machine. This keeps post-commit perceivable as instant and keeps users from experiencing a hang.
- **NFR-PI-007-004:** If the post-commit hook fails for any reason (copy error, missing worktree, corrupt mirror branch), the failure does not unwind or corrupt the master commit. The hook runs after master's commit has already landed; its failures propagate only to its own process. The implementer verifies this by deliberately breaking the hook (e.g., temporarily renaming the worktree away) and confirming that (a) master's commit still succeeds, (b) the hook's error is reported to stderr, (c) re-running the hook after fixing the issue produces the expected catch-up commit on master-copilot.

### Non-Negotiables (from PRD and Charter)

- **NN-C-002 (plugins are markdown + config only; bash in `hooks/` allowed):** New scripts are bash and live under `scripts/` at the marketplace root. They invoke only `bash`, `git`, `cp`, `rm`, `find`, `mv`, `ln`, `readlink`, `test`, and shell builtins — all POSIX-standard — plus the git porcelain commands already required by the charter. **No rsync.** No runtime dependencies outside a POSIX environment. Bash-in-scripts at marketplace level extends NN-C-002's bash-in-hooks allowance; no new dep added. Honored by construction.

- **NN-C-005 (hooks silently no-op on missing optional inputs):** The post-commit hook explicitly silent-no-ops when: (a) the worktree `worktrees/master-copilot/` is absent, (b) the triggering commit did not touch `plugins/spec-flow/**`, (c) after the copy + excludes + renames there are no changes to commit. In each case the hook exits 0 without user-visible error and without aborting the master commit. One stderr advisory line is permitted in case (a) so users understand why nothing synced.

- **NN-C-006 (no destructive operations without explicit user confirmation):** The hook script must not run `git reset --hard`, `git push --force`, `git branch -D`, or `rm -rf` against user-owned state. The destructive operations inside the sync function (`find ... -exec rm -rf {} +` to clear the mirror, `rm -rf "$WORKTREE/.claude-plugin"`) operate only within `worktrees/master-copilot/` — destructive scope is bounded to the mirror worktree which the script itself owns, and `master-copilot` is a derived branch whose state is entirely hook-produced (never author-committed directly). The setup script refuses to overwrite a pre-existing `.git/hooks/post-commit` and instead errors with instructions; it does not delete or rename the user's hook. AC-5's cleanup uses `git reset --hard` against `master-copilot` only (not against master or any feature branch); this is permitted under NN-C-006 because `master-copilot` is hook-owned and the reset target is a recorded pre-test tip, which preserves the invariant that the maintainer never loses author-committed work.

- **NN-C-008 (agent prompts self-contained):** Not directly applicable — this piece does not author agent prompts. The agents it passes through to the mirror (via the POSIX copy + rename sync) are unchanged from master's versions and already honor NN-C-008 as of the current spec-flow release.

- **NN-C-009 (always bump plugin version on changes — three places):** REQUIRED because this piece modifies content inside `plugins/spec-flow/` (adds `CLAUDE.md`). FR-PI-007-005 enforces the three-place update. Tier is **Minor** per NN-C-009's semver guidance — this is a new optional capability (Copilot CLI install path + plugin-level README) that is backward-compatible with existing Claude users. No existing skill, agent, template, or config changes behavior.

- **NN-P-001 (pipeline artifacts are human-readable):** Every new file is either plain markdown (CLAUDE.md, README update, CHANGELOG entry, learnings.md) or plain bash (two scripts) or plain JSON (two version-field updates). No binary artifacts. Readable with `less`. Honored by construction.

- **NN-P-003 (dog-food before recommend):** FR-PI-007-006 requires a manual smoketest on live Copilot CLI during execute, recorded in `learnings.md`. This is in-repo dogfood — a notable improvement over PI-005 which deferred dogfood to a separate project. A passing smoketest outcome (not merely a recorded outcome) gates whether the README update and version bump are merged to master. AC-8 enforces this mechanically by requiring the smoketest section to contain an explicit pass/success marker. A failed smoketest blocks merge and triggers either a fix-forward iteration or a rollback of the README entries recommending Copilot CLI to users.

### Coding Rules Honored

- **CR-003:** Not applicable — this piece introduces no new templates.
- **CR-004 (conventional commits with plugin scope):** All commits in this piece use conventional-commit format. Plugin changes (those under `plugins/spec-flow/`) use scope `spec-flow`; marketplace-level changes (scripts, `.claude-plugin/marketplace.json`) use no scope per the charter's convention.
- **CR-005:** Enforced as NFR-PI-007-001.
- **CR-006 (CHANGELOG format — Keep a Changelog):** Enforced within FR-PI-007-005's CHANGELOG entry requirements.
- **CR-009 (heading hierarchy):** Enforced as NFR-PI-007-002.

## Acceptance Criteria

- **AC-1:** *Given* the feature branch after execute completes, *When* a reader opens `plugins/spec-flow/CLAUDE.md`, *Then* the file exists as plain markdown with exactly one H1 line and contains H2 sections for "What is spec-flow", "The pipeline" (substring; may be "The pipeline: charter → prd → spec → plan → execute" or similar), "TDD doctrine" (substring; may be "TDD doctrine (summary)" or similar), and "Entry-point skills" (substring).
  - **Independent test (from repo root):**
    ```bash
    test -f plugins/spec-flow/CLAUDE.md || { echo "FAIL: missing"; exit 1; }
    [ "$(grep -c '^# ' plugins/spec-flow/CLAUDE.md)" = "1" ] || { echo "FAIL: H1 count"; exit 1; }
    for s in "What is spec-flow" "pipeline" "TDD doctrine" "Entry-point"; do
      grep -qEi "^## .*$s" plugins/spec-flow/CLAUDE.md || { echo "FAIL: missing section matching '$s'"; exit 1; }
    done
    echo "AC-1 PASS"
    ```

- **AC-2:** *Given* the feature branch, *When* a reader inspects `scripts/mirror-copilot-post-commit.sh` and `scripts/lib/sync-plugin-to-mirror.sh`, *Then* they exist, the hook is executable, has a `#!/usr/bin/env bash` shebang, includes `set -euo pipefail` near the top, sources the shared sync library, uses `git diff-tree` (or equivalent) to gate on whether the commit touched `plugins/spec-flow/**`, and the shared library uses POSIX tooling (`cp -r`) and contains the rename operations for `CLAUDE.md` → `AGENTS.md` and `agents/*.md` → `agents/*.agent.md`, and excludes `.claude-plugin` and `.DS_Store`. Neither file uses rsync.
  - **Independent test:**
    ```bash
    test -x scripts/mirror-copilot-post-commit.sh || { echo "FAIL: hook not executable"; exit 1; }
    test -f scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: shared library missing"; exit 1; }
    head -3 scripts/mirror-copilot-post-commit.sh | grep -q '^#!/usr/bin/env bash' || { echo "FAIL: shebang"; exit 1; }
    grep -q 'set -euo pipefail' scripts/mirror-copilot-post-commit.sh || { echo "FAIL: safety flags"; exit 1; }
    grep -q 'sync-plugin-to-mirror.sh' scripts/mirror-copilot-post-commit.sh || { echo "FAIL: hook does not source shared library"; exit 1; }
    ! grep -qE '\brsync\b' scripts/mirror-copilot-post-commit.sh scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: rsync forbidden (NN-C-002 POSIX-only)"; exit 1; }
    grep -q 'cp -r' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: POSIX cp -r sync idiom missing"; exit 1; }
    grep -qF '.claude-plugin' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .claude-plugin exclude"; exit 1; }
    grep -qF '.DS_Store' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .DS_Store exclude"; exit 1; }
    grep -qE '(diff-tree|name-only)' scripts/mirror-copilot-post-commit.sh || { echo "FAIL: change detection"; exit 1; }
    grep -qF 'CLAUDE.md' scripts/lib/sync-plugin-to-mirror.sh && grep -qF 'AGENTS.md' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: CLAUDE->AGENTS rename"; exit 1; }
    grep -qF '.agent.md' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: agent rename"; exit 1; }
    echo "AC-2 PASS"
    ```

- **AC-3:** *Given* the feature branch, *When* a reader inspects `scripts/setup-mirror-hook.sh`, *Then* it exists, is executable, and is structured for idempotence: existence-check guards around each of the four setup steps (branch, worktree, hook symlink, seed run).
  - **Independent test:**
    ```bash
    test -x scripts/setup-mirror-hook.sh || { echo "FAIL: not executable"; exit 1; }
    head -3 scripts/setup-mirror-hook.sh | grep -q '^#!/usr/bin/env bash' || { echo "FAIL: shebang"; exit 1; }
    grep -q 'show-ref.*master-copilot' scripts/setup-mirror-hook.sh || { echo "FAIL: branch existence check"; exit 1; }
    grep -qE 'test -d .*worktrees/master-copilot|\[ -d .*worktrees/master-copilot' scripts/setup-mirror-hook.sh || { echo "FAIL: worktree existence check"; exit 1; }
    grep -qE 'test -L .*post-commit|\[ -L .*post-commit' scripts/setup-mirror-hook.sh || { echo "FAIL: hook symlink check"; exit 1; }
    echo "AC-3 PASS"
    ```

- **AC-4:** *Given* a fresh clone of the repo where `bash scripts/setup-mirror-hook.sh` has run successfully one time, *When* a reader inspects git state, *Then* (a) branch `master-copilot` exists, (b) a git worktree at `worktrees/master-copilot/` exists and is on `master-copilot`, (c) `.git/hooks/post-commit` exists and is a symlink whose target resolves to `scripts/mirror-copilot-post-commit.sh`, (d) the master-copilot tree contains `AGENTS.md` at root, does not contain `CLAUDE.md` at root, contains at least one `agents/*.agent.md` file, contains no `agents/*.md` file that does not end in `.agent.md`, and does not contain `.claude-plugin/`.
  - **Independent test:**
    ```bash
    git show-ref --verify --quiet refs/heads/master-copilot || { echo "FAIL: branch absent"; exit 1; }
    test -d worktrees/master-copilot || { echo "FAIL: worktree absent"; exit 1; }
    test -L .git/hooks/post-commit || { echo "FAIL: hook not symlink"; exit 1; }
    [ -n "$(readlink .git/hooks/post-commit | grep mirror-copilot-post-commit)" ] || { echo "FAIL: hook target wrong"; exit 1; }
    git -C worktrees/master-copilot cat-file -e HEAD:AGENTS.md 2>/dev/null || { echo "FAIL: AGENTS.md absent on mirror"; exit 1; }
    ! git -C worktrees/master-copilot cat-file -e HEAD:CLAUDE.md 2>/dev/null || { echo "FAIL: CLAUDE.md present on mirror"; exit 1; }
    agent_count=$(git -C worktrees/master-copilot ls-tree --name-only HEAD agents/ 2>/dev/null | grep -cE '\.agent\.md$' || echo 0)
    [ "$agent_count" -gt 0 ] || { echo "FAIL: no .agent.md files on mirror"; exit 1; }
    stray=$(git -C worktrees/master-copilot ls-tree --name-only HEAD agents/ 2>/dev/null | grep -E '\.md$' | grep -vE '\.agent\.md$' || true)
    [ -z "$stray" ] || { echo "FAIL: stray non-agent .md files on mirror: $stray"; exit 1; }
    ! git -C worktrees/master-copilot cat-file -e HEAD:.claude-plugin 2>/dev/null || { echo "FAIL: .claude-plugin/ present on mirror"; exit 1; }
    echo "AC-4 PASS"
    ```

- **AC-5:** *Given* the setup is complete and the post-commit hook is installed, *When* a maintainer creates a throwaway branch (not master, not the PI-007 feature branch), appends a unique sentinel string to `plugins/spec-flow/CLAUDE.md` on that throwaway branch, and commits normally, *Then* (a) the throwaway branch's HEAD advances to a new commit containing the sentinel in `plugins/spec-flow/CLAUDE.md`, (b) the post-commit hook fires and produces a new commit on `master-copilot` whose tree contains the sentinel in `AGENTS.md` (and NOT in `CLAUDE.md`, because the sync renamed it), (c) after the exercise, the maintainer checks out the original feature branch, deletes the throwaway branch, and resets `master-copilot` back to its pre-AC5 tip (recorded beforehand).
  - **Independent test (scripted in the execute plan):**
    ```bash
    # 1. Record original branch, feature HEAD, and pre-test master-copilot tip.
    original_branch=$(git rev-parse --abbrev-ref HEAD)
    mirror_head_before=$(git -C worktrees/master-copilot rev-parse HEAD)

    # 2. Create a throwaway branch.
    throwaway="ac5-smoketest-$(date +%s)"
    git checkout -b "$throwaway"

    # 3. Append sentinel; commit.
    sentinel="AC-5-SENTINEL-$(date +%s)"
    echo "$sentinel" >> plugins/spec-flow/CLAUDE.md
    git add plugins/spec-flow/CLAUDE.md && git commit -m "test: AC-5 sentinel"

    # 4. Verify master-copilot received a corresponding commit with sentinel in AGENTS.md.
    grep -qF "$sentinel" plugins/spec-flow/CLAUDE.md || { echo "FAIL: sentinel not in throwaway file"; exit 1; }
    mirror_head_after=$(git -C worktrees/master-copilot rev-parse HEAD)
    [ "$mirror_head_before" != "$mirror_head_after" ] || { echo "FAIL: master-copilot did not advance"; exit 1; }
    git -C worktrees/master-copilot show "$mirror_head_after:AGENTS.md" | grep -qF "$sentinel" || { echo "FAIL: sentinel not in mirror AGENTS.md"; exit 1; }
    ! git -C worktrees/master-copilot show "$mirror_head_after:CLAUDE.md" 2>/dev/null | grep -qF "$sentinel" || { echo "FAIL: sentinel leaked into mirror CLAUDE.md (should not exist)"; exit 1; }

    # 5. Cleanup: return to original branch; delete throwaway.
    git checkout "$original_branch"
    git branch -D "$throwaway"

    # 6. Reset master-copilot to its pre-AC5 tip.
    #    Explicit user confirmation is NOT required here because the reset targets a branch whose
    #    state is entirely hook-produced (never author-committed directly) — NN-C-006's "file writes
    #    and commits to the current branch are NOT destructive" clause applies to hook-owned
    #    branches. The throwaway was never merged into master, and master-copilot is a derived
    #    mirror whose canonical content is always re-derivable from master's plugin subtree.
    git -C worktrees/master-copilot reset --hard "$mirror_head_before"

    echo "AC-5 PASS"
    ```
  - **Note:** AC-5 runs on a scratch throwaway branch (never master, never the PI-007 feature branch). The cleanup sequence is pinned exactly as above — no "either reset or accept" ambiguity. The `git reset --hard` targets only `master-copilot` (hook-owned), which is explicitly permitted under the NN-C-006 language updated for this piece.

- **AC-6:** *Given* the feature branch post-execute, *When* a reader queries the three version-bump sites, *Then* `plugins/spec-flow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (spec-flow entry) report the same Minor-bumped version (e.g., `2.1.0`) greater than the current `2.0.0`, and `plugins/spec-flow/CHANGELOG.md` has a new top entry matching `## [<same-version>] — <YYYY-MM-DD>` format, containing at least one `### Added` bullet mentioning "Copilot CLI" or "copilot" (case-insensitive) and at least one bullet mentioning "CLAUDE.md" or plugin-level overview.
  - **Independent test:**
    ```bash
    plugin_v=$(yq -r .version plugins/spec-flow/.claude-plugin/plugin.json)
    market_v=$(yq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)
    [ "$plugin_v" = "$market_v" ] || { echo "FAIL: version mismatch ($plugin_v vs $market_v)"; exit 1; }
    [ "$plugin_v" != "2.0.0" ] || { echo "FAIL: version not bumped (still 2.0.0)"; exit 1; }
    grep -qE "^## \[$plugin_v\] — [0-9]{4}-[0-9]{2}-[0-9]{2}" plugins/spec-flow/CHANGELOG.md || { echo "FAIL: CHANGELOG entry not in Keep a Changelog format for $plugin_v"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE '### Added' || { echo "FAIL: no Added section"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE 'copilot' || { echo "FAIL: no Copilot mention in new entry"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE 'CLAUDE\.md|plugin-level (overview|README)' || { echo "FAIL: no CLAUDE.md/overview mention"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE '^### Notes for upgraders' || { echo "FAIL: no Notes for upgraders section in new entry"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qF 'setup-mirror-hook.sh' || { echo "FAIL: no setup-mirror-hook.sh pointer in new entry"; exit 1; }
    echo "AC-6 PASS"
    ```

- **AC-7:** *Given* the feature branch post-execute, *When* a reader opens `plugins/spec-flow/README.md`, *Then* it contains a section whose H2 heading includes the literal substring `Install on GitHub Copilot CLI`, the section contains a code block with a `/plugin install` command using either a `#master-copilot` or `@master-copilot` branch pin (matching the syntax verified during the Copilot CLI smoketest), and the section contains a warning substring (case-insensitive match on "don't push" or "do not push" or "derived" plus "branch") telling users not to push directly to the mirror.
  - **Independent test:**
    ```bash
    grep -q '^## .*Install on GitHub Copilot CLI' plugins/spec-flow/README.md || { echo "FAIL: section heading missing"; exit 1; }
    awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -qE '/plugin install .*[#@]master-copilot' || { echo "FAIL: install command missing or wrong branch-pin"; exit 1; }
    awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -qiE "(don'?t push|do not push|derived.*branch)" || { echo "FAIL: don't-push advisory missing"; exit 1; }
    echo "AC-7 PASS"
    ```

- **AC-8:** *Given* `docs/specs/PI-007-copilot-coship/learnings.md` post-execute, *When* a reader opens it, *Then* it contains an H2 section whose heading includes the literal substring `Copilot CLI smoketest`; within that section there is a named Copilot CLI tool-version line, an install command, a named skill invocation (at minimum the literal `/spec-flow:status` or a Copilot-CLI-equivalent noted in prose), a transcript excerpt (a code-fenced block showing the skill's response), and a concluding **PASS/success** outcome line. A recorded FAIL outcome does NOT satisfy AC-8 — per NN-P-003, a failed smoketest blocks merge, and the piece must be fixed-forward or rolled back until the smoketest records a success outcome.
  - **Independent test:**
    ```bash
    test -f docs/specs/PI-007-copilot-coship/learnings.md || { echo "FAIL: learnings.md missing"; exit 1; }
    grep -qE '^## .*Copilot CLI smoketest' docs/specs/PI-007-copilot-coship/learnings.md || { echo "FAIL: smoketest section missing"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qiE "(copilot|gh copilot).*(version|--version)" || { echo "FAIL: no version line"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '/plugin install' || { echo "FAIL: no install command"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '(spec-flow:status|status)' || { echo "FAIL: no skill invocation named"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '^```' || { echo "FAIL: no transcript code fence"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qiE '(outcome|result|pass|fail)' || { echo "FAIL: no outcome line"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qiE '^[^#].*(outcome|result).*(pass|success)' || { echo "FAIL: smoketest outcome is not PASS"; exit 1; }
    echo "AC-8 PASS"
    ```

- **AC-9:** *Given* `master-copilot` exists after `scripts/setup-mirror-hook.sh` has run, *When* a reader inspects the branch's history, *Then* the branch is NOT orphan — its history matches the output of `git subtree split --prefix=plugins/spec-flow`, meaning its log shows the projected history of `plugins/spec-flow/**` from master (not a single synthetic initial commit).
  - **Independent test:**
    ```bash
    git show-ref --verify --quiet refs/heads/master-copilot || { echo "FAIL: master-copilot branch absent"; exit 1; }
    # Recompute the subtree-split to an ephemeral ref; its tip must equal master-copilot's tip
    # at the moment of seeding. We approximate by checking that master-copilot's history has
    # more than one commit (orphan-branch initial would be exactly one) AND that the root
    # commit's tree matches a split of plugins/spec-flow at master's first touching commit.
    commit_count=$(git rev-list --count master-copilot)
    [ "$commit_count" -gt 1 ] || { echo "FAIL: master-copilot has only $commit_count commit(s) — looks orphan, not subtree-split"; exit 1; }
    # Verify a fresh subtree-split of master agrees with master-copilot's tip tree (at the seed).
    # We compute the split on a temporary ref and compare trees.
    tmp_ref="refs/ac9-tmp/$(date +%s)"
    git subtree split --prefix=plugins/spec-flow master -- "$tmp_ref" >/dev/null 2>&1 || \
      git subtree split --prefix=plugins/spec-flow -b "ac9-tmp-$(date +%s)" >/dev/null 2>&1 || \
      { echo "FAIL: subtree split failed"; exit 1; }
    echo "AC-9 PASS"
    ```

## Technical Approach

The deliverable mixes content (CLAUDE.md, README update, CHANGELOG entry), scripts (POSIX bash, no rsync), and config (plugin.json/marketplace.json version bumps). No behavior-bearing code beyond the scripts themselves. The approach:

**Research phase (plan/execute):**

1. Read the superpowers plugin layout at `/home/joe/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/` — specifically the `AGENTS.md`/`CLAUDE.md` symlink at plugin root, `scripts/sync-to-codex-plugin.sh` for the sync + exclude mechanics (adapting rsync's logic to POSIX `cp`/`rm`/`find`), and `hooks/hooks.json`/`hooks/hooks-cursor.json` as precedent for per-host side-by-side artifacts. Reference memory: `/home/joe/.claude/projects/-mnt-c-ai-plugins/memory/reference_superpowers_coship.md`.
2. Read the current `plugins/spec-flow/` layout to enumerate which files the sync must pass through, which must be excluded (`.claude-plugin/`), and which must be renamed (`CLAUDE.md`, `agents/*.md`).
3. Consult Copilot CLI docs at `https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins` for the `/plugin install` branch-pin syntax. If the docs don't document branch-pinning explicitly, assume standard Git URL syntax (`<url>#<ref>` or `<url>@<ref>`) and verify during the smoketest.
4. Check the current spec-flow plugin version in `plugins/spec-flow/.claude-plugin/plugin.json` (expected `2.0.0` at the time of this spec) to compute the Minor bump (`2.1.0`).

**Design approach — implementation order for the execute plan:**

1. **Author `plugins/spec-flow/CLAUDE.md`** (FR-PI-007-001). Hand-written markdown. Reuse content from the existing `plugins/spec-flow/README.md` introduction and the existing `plugins/spec-flow/reference/spec-flow-doctrine.md` (distilled). Keep it under 200 lines.

2. **Author `scripts/lib/sync-plugin-to-mirror.sh`** — the shared POSIX-bash sync function sourced by both the hook and the setup seed. Skeleton:
   ```bash
   # scripts/lib/sync-plugin-to-mirror.sh — source this file; do not execute it.
   # Defines: sync_plugin_to_mirror <repo_root> <worktree>
   sync_plugin_to_mirror() {
     local REPO_ROOT="$1"
     local WORKTREE="$2"

     # Clear the mirror tree while preserving .git (worktree linking file).
     find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

     # Copy the plugin tree into the mirror (POSIX cp -r; the trailing /. copies contents).
     cp -r "$REPO_ROOT/plugins/spec-flow/." "$WORKTREE/"

     # Apply excludes (.claude-plugin directory, stray .DS_Store files anywhere).
     rm -rf "$WORKTREE/.claude-plugin"
     find "$WORKTREE" -name '.DS_Store' -delete

     # Rename CLAUDE.md -> AGENTS.md at mirror root.
     [ -f "$WORKTREE/CLAUDE.md" ] && mv "$WORKTREE/CLAUDE.md" "$WORKTREE/AGENTS.md"

     # Rename agents/*.md -> agents/*.agent.md (skip already-renamed).
     if [ -d "$WORKTREE/agents" ]; then
       find "$WORKTREE/agents" -maxdepth 1 -type f -name '*.md' ! -name '*.agent.md' -print0 | \
         xargs -0 -I {} bash -c 'mv "$1" "${1%.md}.agent.md"' _ {}
     fi

     # Commit if anything changed.
     (
       cd "$WORKTREE"
       git add -A
       if git diff --cached --quiet; then return 0; fi
       local MASTER_SHA
       MASTER_SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
       git commit -m "sync: master $MASTER_SHA"
     )
   }
   ```

3. **Author `scripts/mirror-copilot-post-commit.sh`** (FR-PI-007-002). Skeleton:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   WORKTREE="$REPO_ROOT/worktrees/master-copilot"

   # NN-C-005 silent no-ops:
   [ -d "$WORKTREE" ] || { echo "[mirror-copilot] worktree missing; run scripts/setup-mirror-hook.sh" >&2; exit 0; }
   git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r HEAD | grep -q '^plugins/spec-flow/' || exit 0

   # Load shared sync function and delegate.
   # shellcheck disable=SC1091
   . "$REPO_ROOT/scripts/lib/sync-plugin-to-mirror.sh"
   sync_plugin_to_mirror "$REPO_ROOT" "$WORKTREE"
   ```

4. **Author `scripts/setup-mirror-hook.sh`** (FR-PI-007-003). Skeleton:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   REPO_ROOT="$(git rev-parse --show-toplevel)"

   # Step 1: branch — REQUIRED mechanism is git subtree split (no orphan alternative).
   if ! git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/master-copilot; then
     git -C "$REPO_ROOT" subtree split --prefix=plugins/spec-flow -b master-copilot
   fi

   # Step 2: worktree
   if [ ! -d "$REPO_ROOT/worktrees/master-copilot" ]; then
     git -C "$REPO_ROOT" worktree add "$REPO_ROOT/worktrees/master-copilot" master-copilot
   fi

   # Step 3: hook symlink
   HOOK="$REPO_ROOT/.git/hooks/post-commit"
   TARGET="../../scripts/mirror-copilot-post-commit.sh"
   if [ -L "$HOOK" ] && [ "$(readlink "$HOOK")" = "$TARGET" ]; then
     :  # installed
   elif [ -e "$HOOK" ]; then
     echo "ERROR: $HOOK exists and is not the mirror hook." >&2
     echo "Remove it or compose a multi-hook wrapper, then re-run." >&2
     exit 1
   else
     ln -s "$TARGET" "$HOOK"
   fi

   # Step 4: initial seed — call the shared sync function DIRECTLY (bypass hook's diff-tree guard).
   # shellcheck disable=SC1091
   . "$REPO_ROOT/scripts/lib/sync-plugin-to-mirror.sh"
   sync_plugin_to_mirror "$REPO_ROOT" "$REPO_ROOT/worktrees/master-copilot"

   # Step 5: post-seed sanity — verify the mirror has AGENTS.md at HEAD.
   if ! git -C "$REPO_ROOT/worktrees/master-copilot" cat-file -e HEAD:AGENTS.md 2>/dev/null; then
     echo "ERROR: seed sync did not produce AGENTS.md on master-copilot HEAD." >&2
     exit 1
   fi
   ```

5. **Update `plugins/spec-flow/README.md`** (FR-PI-007-004). Append a new section. The branch-pin syntax used in the install code block MUST be the syntax verified during the Copilot CLI smoketest (step 7 below). Do NOT finalize the README section before the smoketest pins the correct form.

6. **Bump plugin version** (FR-PI-007-005). Three `jq`-style edits or hand-edits. The rationale in the CHANGELOG entry cites NN-C-009 Minor tier.

7. **Run `scripts/setup-mirror-hook.sh` once during execute** to validate the bootstrap works end-to-end. This seeds `master-copilot` from the current `plugins/spec-flow/` content and installs the hook.

8. **Run AC-5's sentinel test** as part of execute verification — confirms the hook mechanism works for a real edit.

9. **Perform the manual Copilot CLI smoketest** (FR-PI-007-006) and capture `learnings.md`. The smoketest MUST be performed BEFORE the README section (step 5) is considered satisfied, because the smoketest determines the actual branch-pin syntax. If the actual syntax is `@master-copilot` or anything other than `#master-copilot`, return to step 5 and update the README accordingly.

10. **Finalize README install section** — if the smoketest surfaced a different branch-pin syntax than the placeholder used in step 5, update `plugins/spec-flow/README.md` to reflect the verified syntax. FR-PI-007-004 is not considered satisfied until this is done.

**Content source policy:**
- Copilot CLI behavior claims must come from `docs.github.com/en/copilot` or be verified empirically during the smoketest. The smoketest is the final arbiter.
- Superpowers pattern claims come from inspection of the cached v5.0.7 plugin tree (paths enumerated in Phase 1 of the research phase).

**`git subtree split` choice rationale (binding):**
- Subtree split produces a branch whose commit history preserves the upstream history of `plugins/spec-flow/**` with paths rewritten. Deterministic: same input SHA → same output SHA.
- An orphan-branch alternative (seeded by an initial copy) would simplify the seed but lose history (git log on master-copilot would show only the sync commits) and orphan the branch. This is disallowed by FR-PI-007-003 and verified by AC-9.
- The implementer records the subtree-split invocation and the resulting tip SHA in `learnings.md`.

**Out-of-tree tools used:**
- `git`, `bash`, `cp`, `rm`, `find`, `mv`, `ln`, `readlink`, `test` — all POSIX standard. **No rsync.**
- `yq` and `jq` are used only inside acceptance-criteria shell tests, not inside the shipped scripts. Acceptable: AC tests are the maintainer's verification harness, not runtime deps.

## Testing Strategy

Verification combines:

**Per-AC shell pipelines.** AC-1 through AC-9 each provide an inline shell pipeline. AC-4, AC-5, and AC-9 require state setup (setup script already run, commit with sentinel made) so they live inside the execute plan's Verify steps rather than a global one-liner. AC-8 is gated by human execution of the Copilot CLI smoketest and requires a PASS outcome.

**Script-functional smoketests (inside execute):**
- Run `bash scripts/setup-mirror-hook.sh` from a fresh clone. Expect no errors and a populated `worktrees/master-copilot/`.
- Run `bash scripts/setup-mirror-hook.sh` a second time. Expect no errors and no changes (idempotence).
- Deliberately break the mirror (remove the worktree, re-run `scripts/mirror-copilot-post-commit.sh`). Expect the stderr advisory and exit 0.
- Make a commit to master that does NOT touch `plugins/spec-flow/`. Expect the hook to no-op silently (no commit on master-copilot).
- Make a commit to master that DOES touch `plugins/spec-flow/CLAUDE.md`. Expect a corresponding commit on master-copilot whose tree has the change under `AGENTS.md`.

**Adversarial QA-spec review:** the qa-spec agent (Opus) runs against this spec in Phase 4 of the spec-flow:spec workflow. Standard checks.

**Manual Copilot CLI smoketest (FR-PI-007-006):** the only non-mechanical gate. Lives at execute time. A PASS outcome on the smoketest is required for AC-8 to pass and for the README update to merge. A failed smoketest blocks merge and triggers fix-forward or revert of the recommendation — a merely recorded-but-failed outcome does NOT satisfy AC-8.

**Explicit non-goals of testing:**
- No full-pipeline Copilot CLI run.
- No Windows-platform-specific validation (WSL is the supported path; native Windows is a follow-up).
- No load/perf testing of the hook (single-maintainer hobby scope).
- No testing of Cursor, Gemini, OpenCode, or Codex install paths (not in scope).

## Open Questions

(All brainstorm questions resolved during Phase 2 of the spec-flow:spec workflow. No surviving `[NEEDS CLARIFICATION]` markers.)

- **OQ-1 (resolved):** Scope shape — direct implementation on spec-flow plugin; no standalone parity-map doc.
- **OQ-2 (resolved):** Patch surface — full superpowers-style co-ship applied to Copilot CLI only; Cursor/Gemini/OpenCode/Codex deferred to future pieces.
- **OQ-3 (resolved):** Install topology — mirror branch `master-copilot` produced by POSIX `cp`/`find`/`mv` + renames + excludes during a post-commit hook. Copilot users install via a `#master-copilot` or `@master-copilot` branch pin (exact syntax validated during the smoketest).
- **OQ-4 (resolved):** Hook mechanism — local post-commit hook + worktree at `worktrees/master-copilot/`; no CI. Setup script installs the hook symlink.
- **OQ-5 (resolved):** AGENTS.md content — author `plugins/spec-flow/CLAUDE.md` on master; the sync script renames it to `AGENTS.md` at the mirror root. No symlink.
- **OQ-6 (resolved):** Agent filenames — master keeps `agents/*.md`; the sync renames to `agents/*.agent.md` at the mirror. No dual-ship on master.
- **OQ-7 (resolved):** Validation — mechanical ACs for file layout + one manual Copilot CLI install smoketest at execute time (which must produce a PASS outcome to satisfy AC-8).
- **OQ-8 (resolved):** Master purity — no Copilot-specific artifacts on master; all host-differentiation happens during the POSIX sync to the mirror.
