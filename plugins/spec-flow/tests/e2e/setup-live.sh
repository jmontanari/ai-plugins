#!/usr/bin/env bash
# setup-live.sh — initialise a live-project repo for spec-flow:execute drive-through
# Usage: setup-live.sh <target-dir>
# Copies fixtures/live-project/ into <target-dir>, inits a git repo, and
# commits a 5-commit baseline in contract order (research → manifest specced →
# spec → manifest planned → plan).
# Prints: READY: <target> — drive with /spec-flow:execute in an interactive session
#   (operator tokens; see tests/e2e/README.md)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/live-project"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
if [ $# -ne 1 ]; then
  printf 'Usage: setup-live.sh <target-dir>\n' >&2
  exit 1
fi

TARGET="$1"

if [ -e "$TARGET" ]; then
  printf 'ERROR: target already exists: %s\n' "$TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET"

# ---------------------------------------------------------------------------
# Copy live-project fixture into target
# ---------------------------------------------------------------------------
cp -R "$FIXTURE_DIR/." "$TARGET/"

# ---------------------------------------------------------------------------
# Init git repo
# ---------------------------------------------------------------------------
git init -q "$TARGET"
git -C "$TARGET" config user.email "demo@example.com"
git -C "$TARGET" config user.name "demo"

PIECE_DIR="docs/prds/demo/specs/hello"

# Helper: stage files and commit
_commit() {
  local subject="$1"; shift
  git -C "$TARGET" add -- "$@"
  git -C "$TARGET" commit -q -m "$subject"
}

# ---------------------------------------------------------------------------
# 5-commit sequence: research → manifest specced → spec → manifest planned → plan
# ---------------------------------------------------------------------------

# Commit 1: research
_commit "research: add demo/hello codebase research" \
  "$PIECE_DIR/research.md"

# Commit 2: manifest at specced state
# Temporarily rewrite manifest to specced for this commit
sed 's/status: planned/status: specced/' \
  "$TARGET/docs/prds/demo/manifest.yaml" \
  > "$TARGET/docs/prds/demo/manifest.yaml.tmp"
mv "$TARGET/docs/prds/demo/manifest.yaml.tmp" "$TARGET/docs/prds/demo/manifest.yaml"
_commit "manifest: mark demo/hello as specced" \
  "docs/prds/demo/manifest.yaml"

# Commit 3: spec
_commit "spec: add demo/hello specification" \
  "$PIECE_DIR/spec.md"

# Commit 4: manifest at planned state (restore original)
sed 's/status: specced/status: planned/' \
  "$TARGET/docs/prds/demo/manifest.yaml" \
  > "$TARGET/docs/prds/demo/manifest.yaml.tmp"
mv "$TARGET/docs/prds/demo/manifest.yaml.tmp" "$TARGET/docs/prds/demo/manifest.yaml"
_commit "manifest: mark demo/hello as planned" \
  "docs/prds/demo/manifest.yaml"

# Commit 5: plan + remaining untracked fixture files
_commit "plan: add demo/hello implementation plan" \
  "$PIECE_DIR/plan.md" \
  ".spec-flow.yaml" \
  "docs/prds/demo/prd.md" \
  "src/greet.sh" \
  "tests/.gitkeep"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf 'READY: %s — drive with /spec-flow:execute in an interactive session (operator tokens; see tests/e2e/README.md)\n' "$TARGET"
