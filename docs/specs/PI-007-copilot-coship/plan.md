# Plan: PI-007-copilot-coship

**Spec:** docs/specs/PI-007-copilot-coship/spec.md
**Status:** draft

## Overview

The deliverable mixes content (one new markdown file, one README update, one CHANGELOG entry), scripts (three bash files plus a shared library), and config (version bumps in two JSON files). There is no behavior-bearing code, no test suite, no runtime language. Every phase is **Implement-track**; `[Verify]` on each phase runs either a shell pipeline from the spec's AC or a purpose-built validation command.

Phase ordering is constrained by three real dependencies:

1. **Shared-library-then-consumer order.** The post-commit hook and the setup script both `source scripts/lib/sync-plugin-to-mirror.sh`. The library must be authored before either of its consumers can be validated as working.
2. **Setup-then-validate order.** AC-4 (branch/worktree/hook existence), AC-5 (sentinel-round-trip), and AC-9 (non-orphan subtree-split history) cannot run before the setup script has executed once — they validate the runtime state setup produces. So setup execution precedes those ACs.
3. **Smoketest-then-README-final order.** FR-PI-007-004's branch-pin syntax (`#master-copilot` vs `@master-copilot`) must match the syntax verified empirically during the smoketest. Therefore a placeholder README is authored early for structural-check purposes, the smoketest runs, and the README's install syntax is finalized after the smoketest's verdict.

**No Phase Groups and no `[P]` markers.** The piece's files are disjoint (CLAUDE.md, three scripts, a README, CHANGELOG, two JSON version bumps, learnings.md) but the dependency chain above serializes them. Parallel dispatch would deliver no meaningful throughput gain — the longest wall-clock segment is the human-gated Phase 7 smoketest, not any machine-dispatched phase.

**No Phase 0 Scaffold.** There is exactly one coordination file (`scripts/lib/sync-plugin-to-mirror.sh`) and it is authored by exactly one phase (Phase 2). Later phases `source` it at runtime rather than editing it. The Scaffold rule ("≥2 phases each appending to the same shared coordination file") does not apply.

Key facts from Phase 1 exploration that the plan assumes and the implementer must honor:

- **Feature-branch execution.** Execute runs on `spec/PI-007-copilot-coship`. Running `scripts/setup-mirror-hook.sh` during Phase 6 creates `master-copilot` + `worktrees/master-copilot/` using the feature branch's `plugins/spec-flow/` subtree (which includes Phase 1–5's new CLAUDE.md). The state persists across merge. Post-merge, the hook self-heals on the next master commit touching `plugins/spec-flow/**`; no special cleanup is needed in this plan.
- **Nested agent subdirs.** `plugins/spec-flow/agents/` has 12 top-level `.md` files PLUS two subdirs: `reflection/` (2 files) and `review-board/` (5 files). The spec's FR-PI-007-002 step 5.e rename is **flat** (`find -maxdepth 1`). Nested agent files keep their `.md` extension on the mirror, which means Copilot CLI's custom-agent discovery (which scans `agents/*.agent.md`) will not see them. This is a known limitation documented in learnings.md during Phase 7 and left as a future-piece item (Copilot's discovery semantics for nested dirs are not documented; handling is out of scope here).
- **Current spec-flow version is `2.0.0`.** The Minor bump target is `2.1.0`. Three places to update per NN-C-009: `plugins/spec-flow/.claude-plugin/plugin.json`, the spec-flow entry in `.claude-plugin/marketplace.json` at repo root, and a new top entry in `plugins/spec-flow/CHANGELOG.md`.
- **`scripts/` directory does not exist at marketplace root today.** Phases 2–4 create it (Phase 2 creates `scripts/lib/`, which implicitly creates `scripts/`).
- **`.gitignore` already contains `worktrees/`** from PI-005's workflow.

## Phases

Each phase uses **Implement track**. No `[TDD-Red]` anywhere in this plan (no behavior-bearing code, no test suite in the project).

All file paths in `[Implement]` steps are relative to the worktree root: `/mnt/c/ai-plugins/worktrees/PI-007-copilot-coship/`. `[Verify]` shell commands assume the current working directory is the worktree root.

### Phase 1: Author plugins/spec-flow/CLAUDE.md

**Exit Gate:** `plugins/spec-flow/CLAUDE.md` exists as plain markdown with exactly one H1 and the four required H2 sections; AC-1's shell pipeline passes.
**ACs Covered:** AC-1 (complete).

- [x] **[Implement]** Author the plugin-level overview.
  - Order sub-items in checkpoint progression:
    1. Create the file `plugins/spec-flow/CLAUDE.md` with an H1 title matching the plugin name (e.g., `# spec-flow`).
    2. Immediately below the H1, author a one-paragraph preamble that names the plugin's purpose: PRD-to-code pipeline for Claude Code, charter → prd → spec → plan → execute, with adversarial QA at every stage. Reuse phrasing from the existing `plugins/spec-flow/README.md` opening to keep tone consistent, but keep the preamble shorter (≤5 sentences).
    3. Author H2 `## What is spec-flow`. Body: 1-2 paragraphs. Summarize the three principles from `plugins/spec-flow/README.md` (progressive narrowing, adversarial review at every boundary, context isolation via subagents) and cite the README as the canonical deeper reference.
    4. Author H2 `## The pipeline: charter → prd → spec → plan → execute`. Body: one paragraph or bullet list naming each stage and its primary skill invocation (e.g., `/spec-flow:charter`, `/spec-flow:prd`, `/spec-flow:spec`, `/spec-flow:plan`, `/spec-flow:execute`). For each stage, one sentence on what it produces and the next stage's entry condition (e.g., "charter → produces `docs/charter/` with binding constraints; enables prd").
    5. Author H2 `## TDD doctrine (summary)`. Body: the Three Laws (no production code without a failing test; no more test than sufficient to fail; no more code than sufficient to pass) in a numbered list, followed by the Red/Build/Verify/Refactor cycle as a short bullet list. Point to `plugins/spec-flow/reference/spec-flow-doctrine.md` as the full reference.
    6. Author H2 `## Entry-point skills`. Body: a markdown table with columns `Skill` | `Purpose` | `Invocation`, one row per top-level skill directory in `plugins/spec-flow/skills/` (charter, execute, plan, prd, spec, status). At minimum include `/spec-flow:status` as the first row and point new users there. Invocation column uses the literal slash-command syntax.
    7. Optional final paragraph: point Copilot CLI users to the README's "Install on GitHub Copilot CLI" section for install instructions (forward reference; the section is authored in Phase 5 placeholder / Phase 8 final).
  - Architecture constraints this phase must honor:
    - CR-009 (heading hierarchy): exactly one H1, H2 for the four required sections, no H4+ nesting. If a table is used, that's fine; tables aren't headings.
    - CR-005 (repo-root-relative paths): any reference to files in the repo uses paths like `plugins/spec-flow/reference/spec-flow-doctrine.md`, not `/home/joe/...` or `../`.
    - NN-P-001 (plain markdown, human-readable). No embedded HTML, no binary assets.
    - Target length: ~100–200 lines per spec guidance. Keep it scannable.
  - Follow existing patterns: `plugins/spec-flow/README.md` for section tone; the existing doctrine file for TDD-summary distillation.

- [x] **[Verify]** AC-1 shell pipeline from spec:
  - Run (from worktree root):
    ```bash
    test -f plugins/spec-flow/CLAUDE.md || { echo "FAIL: missing"; exit 1; }
    [ "$(grep -c '^# ' plugins/spec-flow/CLAUDE.md)" = "1" ] || { echo "FAIL: H1 count"; exit 1; }
    for s in "What is spec-flow" "pipeline" "TDD doctrine" "Entry-point"; do
      grep -qEi "^## .*$s" plugins/spec-flow/CLAUDE.md || { echo "FAIL: missing section matching '$s'"; exit 1; }
    done
    echo "AC-1 PASS"
    ```
  - Expected: prints `AC-1 PASS` and exits 0.

- [x] **[QA]** Phase review.
  - Review against: AC-1, FR-PI-005-001 equivalent content completeness (plugin-level overview covers the four topics), CR-009, CR-005, NN-P-001.
  - Diff baseline: `git diff phase-1-start..HEAD` (single new file, no modifications elsewhere).

### Phase 2: Author scripts/lib/sync-plugin-to-mirror.sh

**Exit Gate:** `scripts/lib/sync-plugin-to-mirror.sh` exists as a POSIX-bash library with a defined `sync_plugin_to_mirror()` function; library-specific AC-2 greps pass; no rsync invocation anywhere.
**ACs Covered:** partial AC-2 (library-side checks). AC-2 fully closes in Phase 3 after the hook script exists.

- [x] **[Implement]** Author the shared sync library.
  - Order sub-items in checkpoint progression:
    1. Create directory `scripts/lib/` (the editor's file-write creates `scripts/` and `scripts/lib/` implicitly).
    2. Create `scripts/lib/sync-plugin-to-mirror.sh` with mode 0644 (library file, sourced not executed directly).
    3. File contents:
       - Shebang line is NOT required for a sourced library, but include a comment at the top indicating the file is a bash library: `# Shared sync function. Sourced by scripts/mirror-copilot-post-commit.sh and scripts/setup-mirror-hook.sh.`
       - Do NOT set `set -euo pipefail` at library level (it would propagate into callers). Set it inside the function body instead.
       - Define the `EXCLUDES` array. Place it as a function-local variable, OR as a module-level constant near the top of the file. Entries at minimum: `".claude-plugin"` and `".DS_Store"`. Comment each entry's reason.
       - Define the function `sync_plugin_to_mirror() { ... }`. Signature: takes two positional arguments `$1=REPO_ROOT` and `$2=WORKTREE`. Returns: 0 on success (commit made), 0 on no-change (no commit made), non-zero on error.
    4. Function body, in checkpoint progression:
       a. `local repo_root="$1" worktree="$2"` and validate both args: error if either is empty or not a directory.
       b. Clear the mirror's non-`.git` contents: `find "$worktree" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +`. This uses `-exec ... +` (POSIX) instead of GNU-only `-delete` on directories.
       c. Copy the plugin tree: `cp -r "$repo_root/plugins/spec-flow/." "$worktree/"`. The trailing `/.` copies the directory's contents (not the directory itself). Verify source exists first with `[ -d "$repo_root/plugins/spec-flow" ] || { echo "missing source" >&2; return 1; }`.
       d. Apply excludes: `rm -rf "$worktree/.claude-plugin"` (POSIX `rm -rf` is always safe when scoped to files inside `$worktree`, which the hook owns). `find "$worktree" -name '.DS_Store' -type f -delete` (note: `-delete` is POSIX for files; `-exec rm -f {} +` would also work and is more portable to older `find` implementations — prefer `-exec rm -f {} +`).
       e. Rename `CLAUDE.md` → `AGENTS.md` at mirror root: `if [ -f "$worktree/CLAUDE.md" ]; then mv "$worktree/CLAUDE.md" "$worktree/AGENTS.md"; fi`.
       f. Rename `agents/*.md` → `agents/*.agent.md` (flat, top-level only per Phase 1 exploration finding): `if [ -d "$worktree/agents" ]; then find "$worktree/agents" -maxdepth 1 -type f -name '*.md' ! -name '*.agent.md' -print0 | xargs -0 -I {} bash -c 'mv "$1" "${1%.md}.agent.md"' _ {}; fi`. Nested files under `agents/reflection/` and `agents/review-board/` keep their `.md` extension; add an inline comment explaining this is intentional per the spec.
       g. Commit on mirror: `cd "$worktree" && git add -A`. If `git diff --cached --quiet`: return 0 without committing. Otherwise: `master_sha=$(git -C "$repo_root" rev-parse --short HEAD) && git commit -m "sync: master $master_sha"`.
       h. Return 0 explicitly at the end of the function for clarity.
    5. At the bottom of the file, do NOT auto-invoke the function. The library only exports the function definition. Consumers invoke it explicitly.
  - Architecture constraints this phase must honor:
    - NN-C-002 (POSIX-bash, no rsync, no non-POSIX tools). Tool inventory for this file: `bash`, `find`, `rm`, `cp`, `mv`, `xargs`, `git`, `test`, `[`, shell builtins. All POSIX.
    - NN-C-005 (silent no-op on missing optional inputs). The function's guards on missing args, missing source, and empty diff cover the no-op paths. Errors log to stderr and return non-zero; no-ops return 0 silently.
    - NN-C-006 (destructive ops scope-bounded). `find -exec rm -rf {} +` operates on `$worktree/*` paths (first argument of find must be `$worktree`); inline-commented that the function never invokes rm against files outside `$worktree`.
  - Follow existing patterns: the existing `plugins/spec-flow/hooks/session-start` shell script for bash idiom and shebang style (though this file omits the shebang since it's sourced). The file's header comment references the spec's FR-PI-007-002.

- [x] **[Verify]** Library-specific AC-2 greps (run from worktree root):
  - Run:
    ```bash
    test -f scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: library missing"; exit 1; }
    grep -q 'sync_plugin_to_mirror' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: function not defined"; exit 1; }
    grep -q 'cp -r' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: POSIX cp -r idiom missing"; exit 1; }
    grep -qF '.claude-plugin' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .claude-plugin exclude missing"; exit 1; }
    grep -qF '.DS_Store' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .DS_Store exclude missing"; exit 1; }
    grep -qF 'CLAUDE.md' scripts/lib/sync-plugin-to-mirror.sh && grep -qF 'AGENTS.md' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: CLAUDE.md→AGENTS.md rename missing"; exit 1; }
    grep -qF '.agent.md' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .agent.md rename missing"; exit 1; }
    ! grep -qE '\brsync\b' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: rsync forbidden (NN-C-002 POSIX-only)"; exit 1; }
    bash -n scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: bash syntax error"; exit 1; }
    echo "Phase 2 library PASS"
    ```
  - Expected: prints `Phase 2 library PASS` and exits 0.
  - Note: `bash -n` syntax-checks without executing. This is a cheap safety net for the sourced library.

- [x] **[QA]** Phase review.
  - Review against: library-specific AC-2 checks, FR-PI-005's library-related sub-requirements, NN-C-002 POSIX-only constraint, NN-C-005 silent-no-op contract, NN-C-006 destructive-scope bound.
  - Diff baseline: `git diff phase-1-end..HEAD` (expect `scripts/` and `scripts/lib/` directories appear new; `scripts/lib/sync-plugin-to-mirror.sh` new file).

### Phase 3: Author scripts/mirror-copilot-post-commit.sh

**Exit Gate:** `scripts/mirror-copilot-post-commit.sh` exists, executable (mode 0755), sources the Phase 2 library, applies the diff-tree guard, and delegates sync to `sync_plugin_to_mirror`. Full AC-2 (hook + library) passes.
**ACs Covered:** AC-2 (complete, covering both the hook and library checks).

- [x] **[Implement]** Author the post-commit hook.
  - Order sub-items in checkpoint progression:
    1. Create `scripts/mirror-copilot-post-commit.sh` with mode 0755.
    2. File header: `#!/usr/bin/env bash` + `set -euo pipefail` + comment block citing the spec's FR-PI-007-002.
    3. Resolve `REPO_ROOT="$(git rev-parse --show-toplevel)"`.
    4. Resolve `WORKTREE="$REPO_ROOT/worktrees/master-copilot"`.
    5. Source the shared library: `source "$REPO_ROOT/scripts/lib/sync-plugin-to-mirror.sh"`. Use `source` rather than `.` for readability.
    6. NN-C-005 no-op path 1 — worktree absent: `if [ ! -d "$WORKTREE" ]; then echo "[mirror-copilot] worktree missing; run scripts/setup-mirror-hook.sh" >&2; exit 0; fi`. One stderr advisory, exit 0.
    7. NN-C-005 no-op path 2 — no plugin touch: `if ! git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r HEAD | grep -q '^plugins/spec-flow/'; then exit 0; fi`. Silent, no stderr.
    8. Invoke the shared function: `sync_plugin_to_mirror "$REPO_ROOT" "$WORKTREE"`. Its exit code becomes the hook's.
  - Architecture constraints this phase must honor:
    - NN-C-002 (POSIX-bash): no rsync, no non-POSIX tools.
    - NN-C-005: two no-op paths explicit and documented inline.
    - NFR-PI-007-004 (hook failure must not unwind master commit): this is a git-native guarantee — post-commit hooks run after the commit is already written; their exit code is reported but master's commit is immutable once the hook fires. Inline comment reminder.
  - Follow existing patterns: `plugins/spec-flow/hooks/run-hook.cmd` for bash shebang + set-flags style.

- [x] **[Verify]** Full AC-2 pipeline from spec (covers hook + library):
  - Run:
    ```bash
    test -x scripts/mirror-copilot-post-commit.sh || { echo "FAIL: hook not executable"; exit 1; }
    test -f scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: shared library missing"; exit 1; }
    head -1 scripts/mirror-copilot-post-commit.sh | grep -qE '^#!/usr/bin/env bash *$' || { echo "FAIL: shebang on line 1"; exit 1; }
    grep -q 'set -euo pipefail' scripts/mirror-copilot-post-commit.sh || { echo "FAIL: safety flags"; exit 1; }
    grep -q 'sync-plugin-to-mirror.sh' scripts/mirror-copilot-post-commit.sh || { echo "FAIL: hook does not source shared library"; exit 1; }
    ! grep -qE '\brsync\b' scripts/mirror-copilot-post-commit.sh scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: rsync forbidden (NN-C-002 POSIX-only)"; exit 1; }
    grep -q 'cp -r' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: POSIX cp -r idiom missing"; exit 1; }
    grep -qF '.claude-plugin' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .claude-plugin exclude"; exit 1; }
    grep -qF '.DS_Store' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: .DS_Store exclude"; exit 1; }
    grep -qE '(diff-tree|name-only)' scripts/mirror-copilot-post-commit.sh || { echo "FAIL: change detection"; exit 1; }
    grep -qF 'CLAUDE.md' scripts/lib/sync-plugin-to-mirror.sh && grep -qF 'AGENTS.md' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: CLAUDE→AGENTS rename"; exit 1; }
    grep -qF '.agent.md' scripts/lib/sync-plugin-to-mirror.sh || { echo "FAIL: agent rename"; exit 1; }
    bash -n scripts/mirror-copilot-post-commit.sh || { echo "FAIL: bash syntax error in hook"; exit 1; }
    echo "AC-2 PASS"
    ```
  - Expected: prints `AC-2 PASS` and exits 0.

- [x] **[QA]** Phase review.
  - Review against: AC-2 (complete), FR-PI-007-002, NN-C-002, NN-C-005 (both no-op paths verified), NFR-PI-007-004 (hook failure isolation — documented via comment, not mechanically tested here but verified in Phase 6's sentinel test).
  - Diff baseline: `git diff phase-2-end..HEAD` (expect only the new hook file).

### Phase 4: Author scripts/setup-mirror-hook.sh

**Exit Gate:** `scripts/setup-mirror-hook.sh` exists, executable (mode 0755), is structured for idempotence with existence-check gates on all four setup steps, contains the pinned `git subtree split` invocation, sources the shared library for the seed step, and contains a post-seed sanity check for AGENTS.md on master-copilot. Structural AC-3 passes (the script's shape is correct; behavioral validation is Phase 6).
**ACs Covered:** AC-3 (structural — idempotence-check pattern present and audit-able). AC-4, AC-5, AC-9 require running the script and are validated in Phase 6.

- [x] **[Implement]** Author the setup bootstrap.
  - Order sub-items in checkpoint progression:
    1. Create `scripts/setup-mirror-hook.sh` with mode 0755.
    2. File header: `#!/usr/bin/env bash` + `set -euo pipefail` + comment block citing spec's FR-PI-007-003 and the **Audience** note (maintainer-only; contributor clones need not run this).
    3. Resolve `REPO_ROOT="$(git rev-parse --show-toplevel)"`.
    4. Resolve `WORKTREE="$REPO_ROOT/worktrees/master-copilot"`.
    5. Step 1 — create `master-copilot` branch if absent. Existence gate:
       ```bash
       if ! git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/master-copilot; then
         echo "[setup] creating master-copilot via git subtree split..." >&2
         git -C "$REPO_ROOT" subtree split --prefix=plugins/spec-flow -b master-copilot
       fi
       ```
       Pin subtree-split as the REQUIRED mechanism per FR-PI-007-003 step 2 (no orphan-branch alternative). Inline comment stating this choice is binding (AC-9 verifies non-orphan history).
    6. Step 2 — create worktree if absent. Existence gate:
       ```bash
       if [ ! -d "$WORKTREE" ]; then
         echo "[setup] creating worktree $WORKTREE..." >&2
         git -C "$REPO_ROOT" worktree add "$WORKTREE" master-copilot
       fi
       ```
    7. Step 3 — install hook symlink. Three-way gate:
       ```bash
       HOOK="$REPO_ROOT/.git/hooks/post-commit"
       TARGET="../../scripts/mirror-copilot-post-commit.sh"
       if [ -L "$HOOK" ] && [ "$(readlink "$HOOK")" = "$TARGET" ]; then
         :  # already installed, no-op
       elif [ -e "$HOOK" ]; then
         echo "ERROR: $HOOK exists and is not the mirror hook." >&2
         echo "Remove it or compose a multi-hook wrapper, then re-run." >&2
         exit 1
       else
         ln -s "$TARGET" "$HOOK"
         echo "[setup] installed post-commit hook symlink" >&2
       fi
       ```
    8. Step 4 — seed initial sync bypassing the hook's diff-tree guard:
       ```bash
       echo "[setup] seeding initial sync..." >&2
       # shellcheck disable=SC1091
       source "$REPO_ROOT/scripts/lib/sync-plugin-to-mirror.sh"
       sync_plugin_to_mirror "$REPO_ROOT" "$WORKTREE"
       ```
    9. Step 5 — post-seed sanity check:
       ```bash
       if ! git -C "$WORKTREE" cat-file -e HEAD:AGENTS.md 2>/dev/null; then
         echo "ERROR: post-seed sanity check failed — AGENTS.md not present on master-copilot HEAD." >&2
         echo "Inspect $WORKTREE and the seed run above." >&2
         exit 1
       fi
       echo "[setup] complete. master-copilot ready at $WORKTREE" >&2
       ```
  - Architecture constraints this phase must honor:
    - NN-C-002: POSIX-bash, `git`, `ln`, `readlink`, shell builtins.
    - NN-C-006: refuses to overwrite an existing `.git/hooks/post-commit` that isn't the expected symlink. Does not `rm -rf` user state.
    - FR-PI-007-003 Audience clause: header comment reiterates maintainer-only intent.
  - Follow existing patterns: session-start hook for bash style. No existing setup-type script in the repo to copy from.

- [x] **[Verify]** Structural AC-3 check (run from worktree root):
  - Run:
    ```bash
    test -x scripts/setup-mirror-hook.sh || { echo "FAIL: setup not executable"; exit 1; }
    head -1 scripts/setup-mirror-hook.sh | grep -qE '^#!/usr/bin/env bash *$' || { echo "FAIL: shebang on line 1"; exit 1; }
    grep -q 'set -euo pipefail' scripts/setup-mirror-hook.sh || { echo "FAIL: safety flags"; exit 1; }
    grep -q 'show-ref.*master-copilot' scripts/setup-mirror-hook.sh || { echo "FAIL: branch existence check"; exit 1; }
    grep -qE '(test -d|\[ -d) .*worktrees/master-copilot' scripts/setup-mirror-hook.sh || { echo "FAIL: worktree existence check"; exit 1; }
    grep -qE '(test -L|\[ -L) .*post-commit' scripts/setup-mirror-hook.sh || { echo "FAIL: hook symlink check"; exit 1; }
    grep -q 'subtree split' scripts/setup-mirror-hook.sh || { echo "FAIL: subtree-split missing (REQUIRED per FR-PI-007-003 step 2)"; exit 1; }
    grep -q 'sync_plugin_to_mirror' scripts/setup-mirror-hook.sh || { echo "FAIL: does not invoke shared sync function"; exit 1; }
    grep -qE '(source|^\. ) .*scripts/lib/sync-plugin-to-mirror\.sh' scripts/setup-mirror-hook.sh || { echo "FAIL: setup script does not source shared library"; exit 1; }
    grep -q 'cat-file -e HEAD:AGENTS.md' scripts/setup-mirror-hook.sh || { echo "FAIL: post-seed sanity check missing"; exit 1; }
    bash -n scripts/setup-mirror-hook.sh || { echo "FAIL: bash syntax error"; exit 1; }
    echo "AC-3 PASS (structural)"
    ```
  - Expected: prints `AC-3 PASS (structural)` and exits 0.

- [x] **[QA]** Phase review.
  - Review against: AC-3 (structural), FR-PI-007-003 (all four steps + Audience), NN-C-002, NN-C-006 (refuse-to-overwrite path), the pinned `git subtree split` choice (FR-PI-007-003 step 2; verified again in Phase 6's AC-9).
  - Diff baseline: `git diff phase-3-end..HEAD` (expect only the setup script file).

### Phase 5: Plugin version bump + placeholder README Copilot-install section

**Exit Gate:** spec-flow version bumped to `2.1.0` in all three required places (plugin.json, marketplace.json, CHANGELOG); the new CHANGELOG entry contains `### Added` bullets naming Copilot CLI install and CLAUDE.md, plus a `### Notes for upgraders` subsection pointing at `scripts/setup-mirror-hook.sh`; `plugins/spec-flow/README.md` gains an `## Install on GitHub Copilot CLI` placeholder section with a `#master-copilot` install command. AC-6 passes; AC-7 passes **with the placeholder** `#` syntax (Phase 8 may update to `@` if the smoketest verifies that form).
**ACs Covered:** AC-6 (complete), AC-7 (placeholder — finalized in Phase 8).

- [x] **[Implement]** Version-bump + README placeholder.
  - Order sub-items in checkpoint progression:
    1. Bump `plugins/spec-flow/.claude-plugin/plugin.json` `version` field from `2.0.0` to `2.1.0`. Preserve all other fields (name, description, author, license, keywords) verbatim.
    2. Bump `.claude-plugin/marketplace.json` spec-flow entry's `version` field from `2.0.0` to `2.1.0`. Preserve all other fields. Verify the entry selected is the one with `"name": "spec-flow"`.
    3. Prepend a new entry at the top of `plugins/spec-flow/CHANGELOG.md` below the `# Changelog` title. Entry structure (Keep a Changelog format, CR-006):
       ```markdown
       ## [2.1.0] — 2026-04-21

       Added GitHub Copilot CLI install compatibility via a derived-mirror-branch pattern (PI-007-copilot-coship). Master stays a pure Claude plugin directory; a POSIX-bash post-commit hook produces the Copilot-ready branch on every commit that touches `plugins/spec-flow/**`.

       ### Added

       - Plugin-level overview at `plugins/spec-flow/CLAUDE.md` summarizing the pipeline and entry-point skills.
       - GitHub Copilot CLI install path via the `master-copilot` mirror branch. Copilot users install with `/plugin install <git-url>#master-copilot` (exact branch-pin syntax verified during execute-time smoketest). See the plugin README section "Install on GitHub Copilot CLI".
       - Marketplace-level scripts supporting the mirror branch: `scripts/lib/sync-plugin-to-mirror.sh`, `scripts/mirror-copilot-post-commit.sh`, `scripts/setup-mirror-hook.sh`.

       ### Notes for upgraders

       - The `scripts/setup-mirror-hook.sh` bootstrap is **for the repo maintainer who pushes `master-copilot`**. Contributors working only on `master` or on feature branches do NOT need to run it — a missing hook on a contributor's clone is not a defect.
       - The `master-copilot` branch is a derived mirror — it receives no author commits directly. Any push should come from the post-commit hook's output only.
       - The `master-copilot` branch visible in `git branch -a` is a derived mirror branch, not a second trunk. Contributors do not need to check it out or push to it. It is maintained by the marketplace repo's post-commit hook on the maintainer's machine and by explicit maintainer pushes. See `plugins/spec-flow/CLAUDE.md` for the plugin overview and `scripts/setup-mirror-hook.sh` for maintainer setup.
       ```
    4. Update `plugins/spec-flow/README.md`: **Append the new section at the end of `plugins/spec-flow/README.md` (i.e., after the current final content line). Rationale: append-at-EOF is mechanically reliable and avoids any ambiguity about whether a Copilot-install section 'belongs' next to some other install section. Existing sections are not reorganized.** The placeholder section content:
       ```markdown
       ## Install on GitHub Copilot CLI

       spec-flow is available on GitHub Copilot CLI via a derived mirror branch that projects this plugin to a standalone-plugin layout.

       ```text
       /plugin install https://github.com/<maintainer>/ai-plugins.git#master-copilot
       ```

       The `master-copilot` branch is maintained automatically by a post-commit hook in the marketplace repo. **Do not push directly to it** — it is a derived branch regenerated from `master` on every commit that touches `plugins/spec-flow/**`.

       The `scripts/setup-mirror-hook.sh` bootstrap script is a **maintainer-only** tool; contributors working on the marketplace repo do not need to run it.

       Example invocation after install (syntax per Copilot CLI):

       ```text
       /spec-flow:status
       ```
       ```
       Note: the branch-pin syntax (`#master-copilot`) is a PLACEHOLDER. Phase 8 verifies it against the Phase 7 smoketest outcome. If the smoketest reveals Copilot uses `@master-copilot` or another form, Phase 8 updates the README.
  - Architecture constraints this phase must honor:
    - NN-C-009 (three-place version bump). All three places updated in this phase.
    - CR-006 (CHANGELOG Keep a Changelog format). Entry format verified by AC-6's regex.
    - CR-005 (repo-root-relative paths in references).
    - CR-009 (heading hierarchy in README addition).
  - Follow existing patterns: CHANGELOG entries at `plugins/spec-flow/CHANGELOG.md` for format; existing README H2 headings for style.

- [x] **[Verify]** AC-6 + AC-7-placeholder pipeline (run from worktree root):
  - Run:
    ```bash
    command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not available — required for marketplace.json extraction"; exit 1; }
    plugin_v=$(jq -r '.version' plugins/spec-flow/.claude-plugin/plugin.json)
    market_v=$(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)
    [ "$plugin_v" = "$market_v" ] || { echo "FAIL: version mismatch ($plugin_v vs $market_v)"; exit 1; }
    [ "$plugin_v" = "2.1.0" ] || { echo "FAIL: expected 2.1.0, got $plugin_v"; exit 1; }
    grep -qE "^## \[$plugin_v\] — [0-9]{4}-[0-9]{2}-[0-9]{2}" plugins/spec-flow/CHANGELOG.md || { echo "FAIL: CHANGELOG entry format"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE '^### Added' || { echo "FAIL: no Added section"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE 'copilot' || { echo "FAIL: no Copilot mention"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE 'CLAUDE\.md|plugin-level' || { echo "FAIL: no CLAUDE.md/overview mention"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qiE '^### Notes for upgraders' || { echo "FAIL: no Notes for upgraders"; exit 1; }
    awk -v v="$plugin_v" '/^## \['v'\]/,/^## \[/' plugins/spec-flow/CHANGELOG.md | grep -qF 'setup-mirror-hook.sh' || { echo "FAIL: no setup-mirror-hook.sh pointer"; exit 1; }
    echo "AC-6 PASS"
    grep -q '^## .*Install on GitHub Copilot CLI' plugins/spec-flow/README.md || { echo "FAIL: README section missing"; exit 1; }
    awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -qE '/plugin install .*[#@]master-copilot' || { echo "FAIL: install command missing"; exit 1; }
    awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -qiE "(don'?t push|do not push|derived.*branch)" || { echo "FAIL: don't-push advisory missing"; exit 1; }
    echo "AC-7 PASS (placeholder — may finalize in Phase 8)"
    ```
  - Expected: prints `AC-6 PASS` followed by `AC-7 PASS (placeholder — may finalize in Phase 8)` and exits 0.

- [x] **[QA]** Phase review.
  - Review against: AC-6 (complete), AC-7 (placeholder acceptable), NN-C-009 (three-place version bump), CR-006, CR-005, CR-009. Note that Phase 8 will revisit AC-7 if smoketest surfaces different syntax.
  - Diff baseline: `git diff phase-4-end..HEAD` (expect: plugin.json version change, marketplace.json version change, CHANGELOG top entry, README new section).

### Phase 6: Run setup script + sentinel test + structural verification

**Exit Gate:** `scripts/setup-mirror-hook.sh` runs successfully (exit 0). Running it a second time succeeds silently (idempotence confirmed). AC-4 (branch/worktree/hook/mirror-tree shape), AC-5 (sentinel round-trip to master-copilot with cleanup), and AC-9 (non-orphan subtree-split history) all pass. Additionally, `docs/specs/PI-007-copilot-coship/ac5-test.sh` exists as a helper script containing the AC-5 sentinel test sequence (identical to the Implement block's step 5). **State persistence:** this phase creates state that persists across the phase completion AND across merge to master: the `master-copilot` branch (remote-tracked after maintainer pushes), the `worktrees/master-copilot/` worktree (local-only, gitignored path), and the `.git/hooks/post-commit` symlink (local-only, not in git). Post-merge, the hook self-heals on the next master commit touching `plugins/spec-flow/**`; no cleanup is performed by this plan. Contributors cloning the marketplace repo who see `master-copilot` in `git branch -a` should consult the CHANGELOG's Notes for upgraders for context.
**ACs Covered:** AC-4 (complete), AC-5 (complete), AC-9 (complete), AC-3 (behavioral confirmation of idempotence).

- [ ] **[Implement]** Execute the setup script and run end-to-end validation.
  - Order sub-items in checkpoint progression:
    1. Run the setup script: `bash scripts/setup-mirror-hook.sh`. Capture stdout+stderr. Expected: exit 0; progress messages to stderr; no errors.
    2. Run it a second time immediately: `bash scripts/setup-mirror-hook.sh`. Expected: exit 0; no branch/worktree/hook creation messages (idempotence).
    3. Validate AC-4 structural expectations (branch, worktree, symlink, mirror tree shape). Use the AC-4 independent test from the spec. This MUST pass cleanly.
    4. Validate AC-9 non-orphan history. The setup seed applies renames (`CLAUDE.md`→`AGENTS.md`, `agents/*.md`→`*.agent.md`) via `sync_plugin_to_mirror`, so a strict tree-match against a fresh `git subtree split` will never hold after the seed. Use a concrete weaker-but-sufficient test that verifies the branch has real subtree-split lineage and was NOT orphan-seeded:
       ```bash
       # AC-9: master-copilot is not orphan (has subtree-split lineage, not just hook-produced sync commits)
       commit_count=$(git log --oneline master-copilot | wc -l)
       [ "$commit_count" -gt 1 ] || { echo "AC-9 FAIL: master-copilot has $commit_count commits (orphan suspected)"; exit 1; }
       # The OLDEST commit on master-copilot must NOT start with "sync:" (the hook's commit-message convention).
       # If it does, master-copilot was orphan-seeded, not subtree-split.
       oldest_subject=$(git log --format=%s --reverse master-copilot | head -1)
       if echo "$oldest_subject" | grep -qE '^sync: '; then
         echo "AC-9 FAIL: oldest commit on master-copilot is a sync commit — branch appears orphan-seeded, not subtree-split"
         exit 1
       fi
       echo "AC-9 PASS"
       ```
       Rationale: the subtree-split seed preserves the upstream plugin history; the oldest commit will be from master's pre-split history (its subject is whatever that commit's original subject was). Hook-sync commits always start with `sync: master <sha>`. If the oldest commit matches that pattern, the branch is orphan-seeded (violating FR-PI-007-003 step 2's REQUIRED mechanism). This is a concrete, sufficient non-orphan check.
    5. Author the AC-5 helper script at `docs/specs/PI-007-copilot-coship/ac5-test.sh` with mode 0755. File contents are the exact 6-step sequence below (the same sequence referenced by Phase 6's Verify block — the helper exists so the Verify pipeline can invoke `bash docs/specs/PI-007-copilot-coship/ac5-test.sh` cleanly rather than inlining 20 lines). The script begins with `#!/usr/bin/env bash` and `set -euo pipefail`.
    6. Validate AC-5 sentinel round-trip per the spec's pinned 6-step sequence (this is the body of `ac5-test.sh`, also reproduced here for reviewability):
       ```bash
       REPO_ROOT=$(git rev-parse --show-toplevel)
       original_branch=$(git -C "$REPO_ROOT" branch --show-current)
       mirror_head_before=$(git -C "$REPO_ROOT/worktrees/master-copilot" rev-parse HEAD)
       throwaway="ac5-smoketest-$(date +%s)"
       git -C "$REPO_ROOT" checkout -b "$throwaway"
       sentinel="AC-5-SENTINEL-$(date +%s)"
       echo "$sentinel" >> "$REPO_ROOT/plugins/spec-flow/CLAUDE.md"
       git -C "$REPO_ROOT" add plugins/spec-flow/CLAUDE.md
       git -C "$REPO_ROOT" commit -m "test: AC-5 sentinel"
       # At this point the post-commit hook should have fired and advanced master-copilot.
       mirror_head_after=$(git -C "$REPO_ROOT/worktrees/master-copilot" rev-parse HEAD)
       [ "$mirror_head_before" != "$mirror_head_after" ] || { echo "FAIL: mirror did not advance"; exit 1; }
       git -C "$REPO_ROOT/worktrees/master-copilot" show "$mirror_head_after:AGENTS.md" | grep -qF "$sentinel" || { echo "FAIL: sentinel absent from mirror AGENTS.md"; exit 1; }
       if git -C "$REPO_ROOT/worktrees/master-copilot" show "$mirror_head_after:CLAUDE.md" 2>/dev/null | grep -qF "$sentinel"; then
         echo "FAIL: sentinel leaked into mirror CLAUDE.md (should not exist after rename)"; exit 1
       fi
       # Cleanup
       git -C "$REPO_ROOT" checkout "$original_branch"
       git -C "$REPO_ROOT" branch -D "$throwaway"
       git -C "$REPO_ROOT/worktrees/master-copilot" reset --hard "$mirror_head_before"
       echo "AC-5 PASS"
       ```
       The `git reset --hard` targets only `worktrees/master-copilot` (the hook-owned mirror) — permitted under NN-C-006 per the spec's explicit carve-out. Invoke the sequence by running `bash docs/specs/PI-007-copilot-coship/ac5-test.sh`; expected output ends with `AC-5 PASS`.
    7. Final composite assertion: all three ACs have passed.
  - Architecture constraints this phase must honor:
    - NN-C-006: the AC-5 cleanup's `git reset --hard` targets only the hook-owned master-copilot worktree. The cleanup also deletes the throwaway branch — safe since it was created for this test.
    - NN-P-003 dogfood groundwork: this phase proves the mechanism works end-to-end before Phase 7's Copilot-CLI smoketest.

- [ ] **[Verify]** Run every AC pipeline in sequence:
  - Run (from worktree root). **Note:** this block does NOT use `set -e`. Each check terminates with an explicit `|| { echo "FAIL: ..."; exit 1; }`, matching the pattern in all other Phase Verify blocks and avoiding fragile interactions between `set -e`, `grep -c` (which exits non-zero on zero matches), and `|| echo 0` fallbacks inside command substitutions.
    ```bash
    # Re-run setup (idempotence)
    bash scripts/setup-mirror-hook.sh > /tmp/setup1.log 2>&1 || { echo "FAIL: first setup invocation errored"; exit 1; }
    bash scripts/setup-mirror-hook.sh > /tmp/setup2.log 2>&1 || { echo "FAIL: second setup invocation errored"; exit 1; }
    # AC-3 behavioral idempotence: second run must NOT produce creation messages
    if grep -qE 'creating master-copilot|creating worktree|installed post-commit hook symlink' /tmp/setup2.log; then
      echo "AC-3 FAIL: second setup run performed creation actions (expected silent idempotence)"
      exit 1
    fi
    echo "AC-3 behavioral PASS"
    # AC-4: structural
    git show-ref --verify --quiet refs/heads/master-copilot || { echo "FAIL: master-copilot branch missing"; exit 1; }
    test -d worktrees/master-copilot || { echo "FAIL: worktree missing"; exit 1; }
    GIT_HOOKS_DIR=$(git rev-parse --git-common-dir)/hooks
    test -L "$GIT_HOOKS_DIR/post-commit" || { echo "FAIL: post-commit hook symlink missing"; exit 1; }
    readlink "$GIT_HOOKS_DIR/post-commit" | grep -q 'mirror-copilot-post-commit' || { echo "FAIL: post-commit symlink points to wrong target"; exit 1; }
    git -C worktrees/master-copilot cat-file -e HEAD:AGENTS.md 2>/dev/null || { echo "FAIL: AGENTS.md missing on mirror"; exit 1; }
    git -C worktrees/master-copilot cat-file -e HEAD:CLAUDE.md 2>/dev/null && { echo "FAIL: CLAUDE.md still present on mirror (should have been renamed)"; exit 1; } || true
    agent_count=$(git -C worktrees/master-copilot ls-tree --name-only HEAD agents/ 2>/dev/null | grep -cE '\.agent\.md$' || true)
    [ "${agent_count:-0}" -gt 0 ] || { echo "FAIL: no .agent.md files on mirror"; exit 1; }
    stray=$(git -C worktrees/master-copilot ls-tree --name-only HEAD agents/ 2>/dev/null | grep -E '\.md$' | grep -vE '\.agent\.md$' || true)
    [ -z "$stray" ] || { echo "FAIL: stray .md files on mirror agents/ (should all be .agent.md)"; exit 1; }
    git -C worktrees/master-copilot cat-file -e HEAD:.claude-plugin 2>/dev/null && { echo "FAIL: .claude-plugin directory leaked onto mirror"; exit 1; } || true
    echo "AC-4 PASS"
    # AC-9: non-orphan history
    commit_count=$(git log --oneline master-copilot | wc -l)
    [ "$commit_count" -gt 1 ] || { echo "AC-9 FAIL: master-copilot has $commit_count commits (orphan suspected)"; exit 1; }
    oldest_subject=$(git log --format=%s --reverse master-copilot | head -1)
    if echo "$oldest_subject" | grep -qE '^sync: '; then
      echo "AC-9 FAIL: oldest commit on master-copilot is a sync commit — branch appears orphan-seeded, not subtree-split"
      exit 1
    fi
    echo "AC-9 PASS"
    # AC-5 round-trip (pinned sequence) — invoke the helper script authored in Phase 6 Implement step 5
    test -f docs/specs/PI-007-copilot-coship/ac5-test.sh || { echo "FAIL: ac5-test.sh missing"; exit 1; }
    test -x docs/specs/PI-007-copilot-coship/ac5-test.sh || { echo "FAIL: ac5-test.sh not executable"; exit 1; }
    bash docs/specs/PI-007-copilot-coship/ac5-test.sh || { echo "FAIL: AC-5 sentinel test failed"; exit 1; }
    # expected: "AC-5 PASS"
    echo "Phase 6 PASS — AC-3 behavioral, AC-4, AC-5, AC-9 all green"
    ```
  - Expected: prints `Phase 6 PASS — AC-3 behavioral, AC-4, AC-5, AC-9 all green` and exits 0.

- [ ] **[QA]** Phase review.
  - Review against: AC-3 (behavioral idempotence confirmed), AC-4 (complete), AC-5 (complete, cleanup performed), AC-9 (complete), NN-C-006 (reset scope bound to hook-owned branch), NN-C-005 (hook's no-op paths exercised implicitly during the idempotent second run — second setup with no plugin-touching commits on HEAD should not re-commit master-copilot).
  - Diff baseline: `git diff phase-5-end..HEAD` (expect new file `docs/specs/PI-007-copilot-coship/ac5-test.sh` + possibly one new commit on master-copilot branch from the initial seed + sentinel-test commit trail has been cleaned).
  - **Important note on execute state:** this phase creates long-lived state (master-copilot branch, worktree, hook symlink). That state persists across the phase's completion. The plan does not clean it up; post-merge the maintainer may re-run setup from master if they want fresh history.

### Phase 7: Manual Copilot CLI smoketest + learnings.md

**Exit Gate:** `docs/specs/PI-007-copilot-coship/learnings.md` exists and contains a `## Copilot CLI smoketest` section with all required fields (Copilot CLI version, install command, skill invoked, transcript, **PASS outcome**). The outcome line MUST indicate pass/success; a recorded FAIL blocks the piece. AC-8 passes.
**ACs Covered:** AC-8 (complete — PASS outcome required).

- [ ] **[Implement]** Human-gated smoketest and learnings authoring.
  - Order sub-items in checkpoint progression:
    1. The orchestrator escalates to the human maintainer: this phase cannot complete without a live Copilot CLI session. The maintainer installs Copilot CLI (if not already installed), records the tool version, pushes `master-copilot` to a remote the maintainer controls (e.g., GitHub), and runs `/plugin install <git-url>#master-copilot` (or `@master-copilot` — whichever syntax Copilot accepts; record which works).
    2. The maintainer invokes at minimum `/spec-flow:status` from within Copilot CLI (or the Copilot-native invocation form, if `/plugin:skill` sigil is lossy). The maintainer captures the full transcript: the invocation, Copilot's response, any errors.
    3. The maintainer reports the transcript back to the orchestrator in chat.
    4. The orchestrator (or an implementer-agent dispatch) writes `docs/specs/PI-007-copilot-coship/learnings.md` with the following structure. **The implementer does not fabricate the transcript** — only the maintainer's real transcript appears in the file.
       ```markdown
       # Learnings: PI-007-copilot-coship

       ## Copilot CLI smoketest

       **Tool version:** <paste `gh copilot --version` or equivalent output here>
       **Date:** <YYYY-MM-DD of the smoketest>
       **Maintainer:** <name>

       ### Install command

       ```
       /plugin install <git-url>#master-copilot
       ```
       (or `@master-copilot` — record whichever branch-pin syntax Copilot accepted)

       ### Skill invocation

       ```
       /spec-flow:status
       ```
       (or whichever invocation form Copilot accepted)

       ### Transcript excerpt

       ```
       <paste the real Copilot transcript here — do not fabricate>
       ```

       ### Observations

       - <What went right>
       - <What went wrong (if anything), and how it was worked around>
       - <Known limitations surfaced: nested agents under agents/reflection/ and agents/review-board/ are NOT renamed on the mirror per spec FR-PI-007-002 step 5.e flat rename; Copilot's custom-agent discovery may not reach them. This is a future-piece item, not a PI-007 blocker.>

       ### Outcome

       **Outcome: PASS** (the install succeeded and the skill invoked as expected)

       OR

       **Outcome: FAIL** (the install failed or the skill did not respond; execute cannot proceed — see the spec's NN-P-003 entry and fix-forward plan.)
       ```
    5. If outcome is PASS: record the exact branch-pin syntax Copilot accepted (`#master-copilot` or `@master-copilot`) — Phase 8 uses this to finalize the README. If outcome is FAIL: escalate to the human for fix-forward (e.g., fix a syntax bug in the hook, re-run Phase 6 validation, re-attempt smoketest) or roll back the README recommendation.
    6. **If smoketest outcome is FAIL:** the piece cannot proceed to Phase 8. The orchestrator MUST escalate to the human with this decision matrix:
       - **Fix-forward path** (preferred): the maintainer identifies the failure root cause (e.g., hook script bug, wrong branch-pin syntax assumption, missing AGENTS.md on the mirror, etc.), applies a fix on the feature branch, re-runs Phase 6 validation, and re-runs Phase 7 smoketest. If the re-run's outcome is PASS, proceed to Phase 8. If the re-run still FAILs, the maintainer decides between continuing to fix-forward or the rollback path below.
       - **Rollback path** (abandon the piece): execute, in order:
         1. `git revert` the commits on the feature branch that added the README's "Install on GitHub Copilot CLI" section (Phase 5's README change) and the CHANGELOG entry's Copilot-recommendation language.
         2. Update `plugins/spec-flow/CHANGELOG.md` to either drop the 2.1.0 entry entirely (if nothing else ships at that version) or rewrite it to cover only the internal additions (CLAUDE.md, scripts) without recommending the Copilot CLI install path to users.
         3. Delete the `master-copilot` branch locally: `git branch -D master-copilot`, and remove the worktree: `git worktree remove worktrees/master-copilot`, and remove `.git/hooks/post-commit` symlink.
         4. Update the manifest to mark PI-007 status as `blocked` (with a notes paragraph describing why) rather than `done`. This stops execute and flags the piece for a later re-attempt.
       Either path is chosen explicitly by the maintainer; the orchestrator does not pick one autonomously.
    7. Additionally record the subtree-split invocation the setup script used and the resulting master-copilot tip SHA, per the spec's Technical Approach note on subtree-split choice being recorded in learnings.md.
  - Architecture constraints this phase must honor:
    - FR-PI-007-006 (smoketest content requirements).
    - NN-P-003 (dogfood before recommend — a FAIL outcome blocks merge per the spec's updated NN-P-003 language).
    - The outcome **must be PASS** for AC-8 to pass. Encoded mechanically in the Verify below.

- [ ] **[Verify]** AC-8 pipeline with PASS requirement (run from worktree root):
  - Run:
    ```bash
    test -f docs/specs/PI-007-copilot-coship/learnings.md || { echo "FAIL: learnings.md missing"; exit 1; }
    grep -qE '^## .*Copilot CLI smoketest' docs/specs/PI-007-copilot-coship/learnings.md || { echo "FAIL: smoketest section missing"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qiE "(copilot|gh copilot).*(version|--version)" || { echo "FAIL: no version line"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '/plugin install' || { echo "FAIL: no install command"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '(spec-flow:status|status)' || { echo "FAIL: no skill invocation named"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '^```' || { echo "FAIL: no transcript code fence"; exit 1; }
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qiE '^[^#].*(outcome|result).*(pass|success)' || { echo "FAIL: smoketest outcome is not PASS"; exit 1; }
    # Fabricate-transcript guard: the learnings template's placeholders must not survive
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -qE '<paste [^>]*here|<paste [^>]*transcript|<YYYY-MM-DD[^>]*>|<name>|<git-url>|<What went [^>]*>|<Known limitations[^>]*>' && { echo "FAIL: learnings.md contains unfilled template placeholders"; exit 1; } || true
    # At least one non-empty line must exist between code-fence markers inside the transcript section
    awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | awk '/^```/{in_fence=!in_fence; next} in_fence{print}' | grep -qE '[^[:space:]]' || { echo "FAIL: transcript code-fence is empty or only whitespace"; exit 1; }
    echo "transcript non-empty, no placeholders PASS"
    echo "AC-8 PASS"
    ```
  - Expected: prints `AC-8 PASS` and exits 0. A recorded FAIL outcome fails the pipeline; the piece cannot proceed to Phase 8.

- [ ] **[QA]** Phase review.
  - Review against: AC-8 (complete, PASS-required enforcement), FR-PI-007-006 (all required fields present), NN-P-003 (dogfood blocks merge on failure; PASS-only gate enforced mechanically).
  - Diff baseline: `git diff phase-6-end..HEAD` (expect: new `docs/specs/PI-007-copilot-coship/learnings.md`).

### Phase 8: Finalize README Copilot-install syntax

**Exit Gate:** `plugins/spec-flow/README.md` "Install on GitHub Copilot CLI" section's install-command branch-pin matches the syntax the Phase 7 smoketest verified (either `#master-copilot` or `@master-copilot`, whichever Copilot accepted). AC-7 passes in its final form.
**ACs Covered:** AC-7 (final, verified).

- [ ] **[Implement]** Align the README install command with the smoketest-verified syntax.
  - Order sub-items in checkpoint progression:
    1. Read Phase 7's learnings.md to extract the exact install command that Copilot accepted (either the `#master-copilot` or `@master-copilot` form, plus the exact git URL form — the maintainer may prefer `https://github.com/<user>/<repo>.git` vs the bare `github.com:<user>/<repo>` form).
    2. If the learnings.md records `#master-copilot` as the accepted syntax: Phase 5's placeholder is already correct. No edit needed. Skip to Verify.
    3. If learnings.md records `@master-copilot` as the accepted syntax: edit `plugins/spec-flow/README.md`'s "Install on GitHub Copilot CLI" section. Replace `#master-copilot` with `@master-copilot` in the install-command code block. Do NOT modify the "Do not push" advisory, the maintainer-only note, or any other content in the section.
    4. If learnings.md records some third syntax entirely different from both (rare — e.g., Copilot might use a URL-encoded branch name): edit the README to match what works, document the choice inline, and note the divergence in learnings.md as a late-finding.
  - Architecture constraints this phase must honor:
    - CR-005 (repo-root-relative paths — N/A here; the URL is external).
    - CR-009 (heading hierarchy — do not introduce new headings).
    - Content source policy: the syntax update must reference the smoketest transcript in learnings.md, not a guess.

- [ ] **[Verify]** Final AC-7 pipeline (run from worktree root):
  - Run:
    ```bash
    grep -q '^## .*Install on GitHub Copilot CLI' plugins/spec-flow/README.md || { echo "FAIL: section heading missing"; exit 1; }
    awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -qE '/plugin install .*[#@]master-copilot' || { echo "FAIL: install command missing or wrong branch-pin"; exit 1; }
    awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -qiE "(don'?t push|do not push|derived.*branch)" || { echo "FAIL: don't-push advisory missing"; exit 1; }
    # Consistency check: README syntax must match the smoketest's accepted syntax from learnings.md
    readme_syntax=$(awk '/^## .*Install on GitHub Copilot CLI/,/^## [^I]/' plugins/spec-flow/README.md | grep -oE '[#@]master-copilot' | head -1)
    learnings_syntax=$(awk '/^## .*Copilot CLI smoketest/,/^## [^C]/' docs/specs/PI-007-copilot-coship/learnings.md | grep -oE '[#@]master-copilot' | head -1)
    [ -n "$readme_syntax" ] && [ -n "$learnings_syntax" ] || { echo "FAIL: could not extract syntax from both files"; exit 1; }
    [ "$readme_syntax" = "$learnings_syntax" ] || { echo "FAIL: README syntax ($readme_syntax) doesn't match learnings.md syntax ($learnings_syntax)"; exit 1; }
    echo "AC-7 PASS (final)"
    ```
  - Expected: prints `AC-7 PASS (final)` and exits 0.

- [ ] **[QA]** Phase review — Opus deep review, cross-cutting final gate before merge.
  - Review against: AC-7 (final), FR-PI-007-004 (install-command syntax matches Copilot's accepted form), consistency between README and learnings.md. Also cross-cutting: confirm all 9 ACs are now green together (mental audit: AC-1 Phase 1, AC-2 Phases 2+3, AC-3 Phases 4+6, AC-4 Phase 6, AC-5 Phase 6, AC-6 Phase 5, AC-7 Phases 5+8, AC-8 Phase 7, AC-9 Phase 6).
  - Diff baseline: `git diff phase-7-end..HEAD` (expect: at most a 1-line edit to `plugins/spec-flow/README.md` changing `#` to `@` in the branch-pin, or zero edits if placeholder was already correct).

## Parallel Execution Notes

No Phase Groups. No `[P]`-marked phases.

**Rationale:** the piece's phases serialize on a real dependency chain:

- Phase 2 (library) → Phase 3 (hook sources library) → Phase 4 (setup sources library) → Phase 6 (runs setup → validates AC-4/5/9) → Phase 7 (smoketest depends on setup having run) → Phase 8 (README syntax depends on smoketest outcome).
- Phase 1 (CLAUDE.md) is independent of the script chain but is authored first to keep the piece's diff legible (content before infrastructure).
- Phase 5 (version bump + placeholder README) could run in parallel with Phases 2–4 (touches entirely disjoint files), but the throughput gain is trivial (all are small text edits). Keeping phases serial simplifies the plan's Verify pipelines — each phase's Verify references prior phases' outputs only as exists-checks, not as in-flight state.

**If a future variant of this piece targets multiple hosts (Cursor + Gemini + OpenCode + Codex) simultaneously,** the per-host hook-registration files could be authored in a Phase Group (each host's `hooks/hooks-<host>.json` is a disjoint file). That's a separate piece scope and out of scope here.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) — Phase 1 | `Mode: Implement` flag, Phase 1 `[Implement]` block, AC-1 pipeline, pointers to existing README and doctrine as reuse sources, CR-009 + CR-005 + NN-P-001 constraints | Spec rationale, brainstorming history, later phases' content |
| Implementer (Mode: Implement) — Phase 2 | `Mode: Implement` flag, Phase 2 `[Implement]` block (shared sync library), EXCLUDES list definition requirements, NN-C-002 POSIX constraint with explicit tool inventory, NN-C-005 silent-no-op contract, NN-C-006 destructive-scope bound, Phase 1 exploration finding about nested agent subdirs (FLAT rename only) | Phase 3+ content, hook-specific concerns |
| Implementer (Mode: Implement) — Phase 3 | `Mode: Implement` flag, Phase 3 `[Implement]` block (hook sources the library), full AC-2 pipeline (library + hook), NN-C-002, NN-C-005 two-no-op-path enumeration | Phase 4+ content, phase-internal library mechanics (already done in Phase 2) |
| Implementer (Mode: Implement) — Phase 4 | `Mode: Implement` flag, Phase 4 `[Implement]` block (setup bootstrap), structural AC-3 pipeline, FR-PI-007-003's Audience paragraph (maintainer-only), pinned `git subtree split` choice, post-seed sanity check requirement | Phase 5+ content |
| Implementer (Mode: Implement) — Phase 5 | `Mode: Implement` flag, Phase 5 `[Implement]` block (version bump + placeholder README), AC-6 pipeline, AC-7 placeholder requirements, NN-C-009 three-place semantics, current version `2.0.0` → target `2.1.0`, Phase 1 exploration finding about existing CHANGELOG format | Phase 6+ content |
| Implementer (Mode: Implement) — Phase 6 | `Mode: Implement` flag, Phase 6 `[Implement]` block (run setup + validate AC-4/5/9 + author ac5-test.sh helper), AC-4/AC-5/AC-9 pipelines, NN-C-006 cleanup scope rationale, the note that phase creates long-lived state not cleaned up | Phase 7+ content |
| Implementer (Mode: Implement) — Phase 7 | `Mode: Implement` flag, Phase 7 `[Implement]` block (human-gated smoketest + learnings.md authoring), AC-8 pipeline with PASS requirement, FR-PI-007-006 required-fields list, NN-P-003 fail-blocks-merge rule, explicit instruction NOT to fabricate transcripts — only the maintainer's real transcript goes in the file | Implementation reasoning about the hook or library internals |
| Implementer (Mode: Implement) — Phase 8 | `Mode: Implement` flag, Phase 8 `[Implement]` block (finalize README syntax), AC-7 final pipeline, learnings.md content from Phase 7 for syntax extraction | Any other content |
| Verify (every phase) | Verification output of the phase's `[Verify]` shell pipeline, the spec ACs referenced in the phase's Exit Gate | Implementation reasoning, any phase's `[Implement]` block rationale |
| QA (every phase) | Phase diff from the baseline tag, the spec, this plan, PRD sections G-3 + SC-002 framing, charter NN-C-002/005/006/008/009 + NN-P-001/003 + CR-003/004/005/006/009 as reviewable constraints | Any agent conversation history, other phases' QA outputs |
