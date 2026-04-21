#!/usr/bin/env bash
set -euo pipefail

# AC-5 sentinel round-trip test.
# Verifies that a commit touching plugins/spec-flow/CLAUDE.md triggers the post-commit
# hook and the sentinel content appears in the mirror's AGENTS.md.
# Called from Phase 6 [Verify] pipeline.

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
