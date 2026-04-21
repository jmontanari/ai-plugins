#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script: sets up the master-copilot mirror branch, worktree, and post-commit hook.
# Implements FR-PI-007-003 (one-time maintainer setup).
#
# Audience: MAINTAINER-ONLY. Contributor clones do NOT need to run this script.
# This sets up the local infrastructure for the Copilot CLI mirror branch.
# Normal contributors just commit to master as usual.
#
# Steps performed (all idempotent — safe to re-run):
#   1. Create the master-copilot branch via git subtree split (REQUIRED mechanism
#      per FR-PI-007-003 step 2; AC-9 verifies non-orphan history — no alternative).
#   2. Create the worktrees/master-copilot git worktree.
#   3. Install the post-commit hook symlink at .git/hooks/post-commit.
#   4. Seed initial sync by invoking sync_plugin_to_mirror() from the shared library,
#      bypassing the hook's diff-tree guard.
#   5. Sanity-check: verify AGENTS.md is present on master-copilot HEAD.

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE="$REPO_ROOT/worktrees/master-copilot"

# --- Step 1: create master-copilot branch if absent ---
# git subtree split is the REQUIRED mechanism per FR-PI-007-003 step 2.
# Using an orphan branch here is NOT permitted — AC-9 validates non-orphan history.
if ! git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/master-copilot; then
    echo "[setup] creating master-copilot via git subtree split..." >&2
    git -C "$REPO_ROOT" subtree split --prefix=plugins/spec-flow -b master-copilot
fi

# --- Step 2: create worktree if absent ---
if [ -d "$WORKTREE" ]; then  # worktrees/master-copilot already present
    :  # no-op
else
    echo "[setup] creating worktree $WORKTREE..." >&2
    git -C "$REPO_ROOT" worktree add "$WORKTREE" master-copilot
fi

# --- Step 3: install hook symlink (NN-C-006: refuse to overwrite unexpected hook) ---
HOOK="$REPO_ROOT/.git/hooks/post-commit"
TARGET="../../scripts/mirror-copilot-post-commit.sh"
if [ -L "$HOOK" ] && [ "$(readlink "$HOOK")" = "$TARGET" ]; then  # post-commit symlink already correct
    :  # no-op
elif [ -e "$HOOK" ]; then
    echo "ERROR: $HOOK exists and is not the mirror hook." >&2
    echo "Remove it or compose a multi-hook wrapper, then re-run." >&2
    exit 1
else
    ln -s "$TARGET" "$HOOK"
    echo "[setup] installed post-commit hook symlink" >&2
fi

# --- Step 4: seed initial sync (bypasses hook's diff-tree guard) ---
echo "[setup] seeding initial sync..." >&2
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/sync-plugin-to-mirror.sh"
sync_plugin_to_mirror "$REPO_ROOT" "$WORKTREE"

# --- Step 5: post-seed sanity check ---
if ! git -C "$WORKTREE" cat-file -e HEAD:AGENTS.md 2>/dev/null; then
    echo "ERROR: post-seed sanity check failed — AGENTS.md not present on master-copilot HEAD." >&2
    echo "Inspect $WORKTREE and the seed run above." >&2
    exit 1
fi
echo "[setup] complete. master-copilot ready at $WORKTREE" >&2
