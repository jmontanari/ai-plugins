# Shared sync function. Sourced by scripts/mirror-copilot-post-commit.sh and scripts/setup-mirror-hook.sh.
# Implements the sync logic described in FR-PI-007-002.
# This file is a bash library — do NOT execute directly. Source it.
# Do NOT set -euo pipefail at library level (would propagate into callers);
# set -euo pipefail is set inside the function body instead.

# EXCLUDES list: paths to strip from the mirror after copying.
# Placed at module level so callers can inspect or extend if needed.
SYNC_EXCLUDES=(
    ".claude-plugin"   # plugin registry metadata — not meaningful to Copilot consumers
    ".DS_Store"        # macOS metadata cruft
)

# sync_plugin_to_mirror REPO_ROOT WORKTREE
#
# Copies plugins/spec-flow from REPO_ROOT into the mirror WORKTREE, applies
# excludes, renames CLAUDE.md → AGENTS.md and agents/*.md → agents/*.agent.md
# (flat, top-level only — see note on nested subdirs below), then commits on the
# mirror if there are changes.
#
# Returns:
#   0  — success (commit made, or no-op when nothing changed)
#   1  — error (missing args, missing source dir; message written to stderr)
#
# Architecture constraints honored:
#   NN-C-002: POSIX-bash only. Tool inventory: bash, find, rm, cp, mv, xargs,
#             git, test, [, shell builtins. POSIX tools only — no non-POSIX sync tools.
#   NN-C-005: Silent no-op on missing optional inputs. Error paths log to stderr
#             and return 1; no-ops return 0 without printing anything.
#   NN-C-006: All destructive ops (find -exec rm, rm -rf) are scoped to paths
#             inside $worktree. This function never invokes rm against files
#             outside $worktree.
sync_plugin_to_mirror() {
    set -euo pipefail

    local repo_root="$1"
    local worktree="$2"

    # --- validate arguments ---
    if [ -z "$repo_root" ] || [ -z "$worktree" ]; then
        echo "sync_plugin_to_mirror: REPO_ROOT and WORKTREE must be non-empty" >&2
        return 1
    fi
    if [ ! -d "$repo_root" ]; then
        echo "sync_plugin_to_mirror: REPO_ROOT is not a directory: $repo_root" >&2
        return 1
    fi
    if [ ! -d "$worktree" ]; then
        echo "sync_plugin_to_mirror: WORKTREE is not a directory: $worktree" >&2
        return 1
    fi

    # --- verify source exists ---
    [ -d "$repo_root/plugins/spec-flow" ] || {
        echo "sync_plugin_to_mirror: missing source directory: $repo_root/plugins/spec-flow" >&2
        return 1
    }

    # --- clear mirror's non-.git contents (NN-C-006: scoped to $worktree) ---
    find "$worktree" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

    # --- copy plugin tree ---
    # Trailing /. copies directory contents (not the directory itself).
    cp -r "$repo_root/plugins/spec-flow/." "$worktree/"

    # --- apply excludes ---
    # NN-C-006: rm -rf below is always scoped to $worktree paths.
    rm -rf "$worktree/.claude-plugin"
    # Use -exec rm -f {} + instead of -delete for portability to older find implementations.
    find "$worktree" -name '.DS_Store' -type f -exec rm -f {} +

    # --- rename CLAUDE.md → AGENTS.md at mirror root ---
    if [ -f "$worktree/CLAUDE.md" ]; then
        mv "$worktree/CLAUDE.md" "$worktree/AGENTS.md"
    fi

    # --- rename agents/*.md → agents/*.agent.md (flat, maxdepth 1) ---
    # Per FR-PI-007-002 step 5.e and the Phase 1 exploration finding:
    # Only top-level .md files in agents/ are renamed. Files nested under
    # agents/reflection/ and agents/review-board/ intentionally keep their
    # .md extension — Copilot's custom-agent discovery does not reach them
    # and renaming them would break relative cross-references.
    if [ -d "$worktree/agents" ]; then
        find "$worktree/agents" -maxdepth 1 -type f -name '*.md' ! -name '*.agent.md' -print0 \
            | xargs -0 -I {} bash -c 'mv "$1" "${1%.md}.agent.md"' _ {}
    fi

    # --- commit on mirror if there are changes ---
    local master_sha
    master_sha=$(git -C "$repo_root" rev-parse --short HEAD)

    cd "$worktree"
    git add -A

    if git diff --cached --quiet; then
        # Nothing changed — silent no-op per NN-C-005.
        return 0
    fi

    git commit -m "sync: master $master_sha"

    return 0
}
