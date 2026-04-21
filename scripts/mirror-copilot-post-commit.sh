#!/usr/bin/env bash
set -euo pipefail

# Post-commit hook: mirrors plugins/spec-flow to the master-copilot worktree.
# Implements FR-PI-007-002 (automated sync on commit).
#
# NFR-PI-007-004 note: this is a post-commit hook. The master commit is already
# written before this hook fires. A non-zero exit here is reported to the user
# but does NOT unwind or cancel the commit — git-native guarantee.
#
# NN-C-005 no-op paths (two):
#   1. Worktree absent — advisory to stderr, exit 0.
#   2. No plugins/spec-flow files touched in HEAD — silent exit 0.

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE="$REPO_ROOT/worktrees/master-copilot"

# Source the shared sync library (Phase 2).
source "$REPO_ROOT/scripts/lib/sync-plugin-to-mirror.sh"

# --- no-op path 1: worktree not yet set up ---
if [ ! -d "$WORKTREE" ]; then
    echo "[mirror-copilot] worktree missing; run scripts/setup-mirror-hook.sh" >&2
    exit 0
fi

# --- no-op path 2: this commit did not touch plugins/spec-flow ---
if ! git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r HEAD | grep -q '^plugins/spec-flow/'; then
    exit 0
fi

# Delegate sync to the shared library function.
sync_plugin_to_mirror "$REPO_ROOT" "$WORKTREE"
