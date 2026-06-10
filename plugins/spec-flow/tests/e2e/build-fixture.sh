#!/usr/bin/env bash
# build-fixture.sh — builds the e2e replay fixture repo in <target-dir>
# Usage: build-fixture.sh <target-dir> [--break=<case>]
# Break cases: research-after-spec | no-test-data | no-spike-artifact |
#              skip-transition | journal-survives | missing-learnings
set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths and helpers
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/replay"

# Source lib/assert.sh only when we need e2e_mktemp (target omitted)
_ensure_helpers() {
  # shellcheck source=lib/assert.sh
  source "$SCRIPT_DIR/lib/assert.sh"
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
TARGET_DIR=""
BREAK_CASE=""

for arg in "$@"; do
  case "$arg" in
    --break=*) BREAK_CASE="${arg#--break=}" ;;
    -*) printf 'Unknown flag: %s\n' "$arg" >&2; exit 1 ;;
    *)
      if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$arg"
      else
        printf 'Unexpected argument: %s\n' "$arg" >&2; exit 1
      fi
      ;;
  esac
done

if [ -z "$TARGET_DIR" ]; then
  _ensure_helpers
  TARGET_DIR="$(e2e_mktemp)"
fi

# ---------------------------------------------------------------------------
# Validate break case
# ---------------------------------------------------------------------------
VALID_BREAKS="research-after-spec no-test-data no-spike-artifact skip-transition journal-survives missing-learnings"
if [ -n "$BREAK_CASE" ]; then
  valid=0
  for b in $VALID_BREAKS; do
    [ "$b" = "$BREAK_CASE" ] && valid=1 && break
  done
  if [ "$valid" -eq 0 ]; then
    printf 'Unknown break case: %s\nValid cases: %s\n' "$BREAK_CASE" "$VALID_BREAKS" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Helper: commit one or more files into the target repo
# ---------------------------------------------------------------------------
_commit() {
  local subject="$1"; shift
  # "$@" = list of files relative to TARGET_DIR that are already written
  git -C "$TARGET_DIR" add -- "$@"
  git -C "$TARGET_DIR" commit -q -m "$subject"
}

# ---------------------------------------------------------------------------
# Initialise the target git repo
# ---------------------------------------------------------------------------
git init -q "$TARGET_DIR"
git -C "$TARGET_DIR" config user.email "demo@example.com"
git -C "$TARGET_DIR" config user.name "demo"

# ---------------------------------------------------------------------------
# Piece directory layout
# ---------------------------------------------------------------------------
PIECE_DIR="docs/prds/demo/specs/hello"
mkdir -p "$TARGET_DIR/$PIECE_DIR/spikes"
mkdir -p "$TARGET_DIR/$PIECE_DIR/tests"
mkdir -p "$TARGET_DIR/$PIECE_DIR/src"

# ---------------------------------------------------------------------------
# Fixture content helpers
# ---------------------------------------------------------------------------

_write_research() {
  cp "$FIXTURE_DIR/research.md" "$TARGET_DIR/$PIECE_DIR/research.md"
}

_write_manifest_specced() {
  sed 's/status: open/status: specced/' "$FIXTURE_DIR/manifest.yaml" \
    > "$TARGET_DIR/manifest.yaml"
}

_write_spec() {
  cp "$FIXTURE_DIR/spec.md" "$TARGET_DIR/$PIECE_DIR/spec.md"
}

_write_manifest_planned() {
  sed 's/status: [a-z]*/status: planned/' "$FIXTURE_DIR/manifest.yaml" \
    > "$TARGET_DIR/manifest.yaml"
}

_write_plan() {
  local src
  if [ "$BREAK_CASE" = "no-test-data" ]; then
    src="$FIXTURE_DIR/plan-no-test-data.md"
  else
    src="$FIXTURE_DIR/plan-clean.md"
  fi
  cp "$src" "$TARGET_DIR/$PIECE_DIR/plan.md"
}

_write_manifest_inprogress() {
  sed 's/status: [a-z]*/status: in-progress/' "$FIXTURE_DIR/manifest.yaml" \
    > "$TARGET_DIR/manifest.yaml"
}

_write_spike() {
  cp "$FIXTURE_DIR/spike-phase-1.md" "$TARGET_DIR/$PIECE_DIR/spikes/phase-1.md"
}

_write_tests_and_src() {
  # test-greet.sh — embeds both oracle values
  cat > "$TARGET_DIR/$PIECE_DIR/tests/test-greet.sh" <<'TESTEOF'
#!/usr/bin/env bash
# test-greet.sh — oracle tests for greet utility
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../src/greet.sh"

pass=0; fail=0
check() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    printf 'PASS — %s\n' "$label"; pass=$((pass+1))
  else
    printf 'FAIL — %s (got=%s want=%s)\n' "$label" "$got" "$want"; fail=$((fail+1))
  fi
}

check "rt-1 spike suffix" "$(greet_suffix)" "resolved-42"
check "g-1 greet world"   "$(greet world)"  "hello, world"

printf '== %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
TESTEOF

  # src/greet.sh — greet function + suffix returning resolved-42
  cat > "$TARGET_DIR/$PIECE_DIR/src/greet.sh" <<'SRCEOF'
#!/usr/bin/env bash
greet() { printf 'hello, %s\n' "$1"; }
greet_suffix() { printf 'resolved-42\n'; }
SRCEOF
}

_write_config() {
  printf 'greet_suffix=resolved-42\n' > "$TARGET_DIR/$PIECE_DIR/src/config.txt"
}

_write_discovery_log() {
  cp "$FIXTURE_DIR/discovery-log.md" "$TARGET_DIR/$PIECE_DIR/.discovery-log.md"
}

_write_learnings() {
  cp "$FIXTURE_DIR/learnings.md" "$TARGET_DIR/$PIECE_DIR/learnings.md"
}

_write_manifest_merged() {
  sed 's/status: [a-z]*/status: merged/' "$FIXTURE_DIR/manifest.yaml" \
    > "$TARGET_DIR/manifest.yaml"
}

# ---------------------------------------------------------------------------
# Build the 12-commit sequence (with break variants applied)
# ---------------------------------------------------------------------------

if [ "$BREAK_CASE" = "research-after-spec" ]; then
  # Commits 1 and 3 swapped: spec lands before research

  # Step 1 (swapped): write manifest at specced state (pre-step-2 normally)
  # We still need commit 2 (manifest: specced) — the swap is research <-> spec
  # research-after-spec: commit 1 becomes spec, commit 3 becomes research
  _write_manifest_specced
  _commit "manifest: mark demo/hello as specced" manifest.yaml

  _write_spec
  _commit "spec: add demo/hello specification" "$PIECE_DIR/spec.md"

  _write_research
  _commit "research: add demo/hello codebase research" "$PIECE_DIR/research.md"
else
  # Normal order: commit 1 = research
  _write_research
  _commit "research: add demo/hello codebase research" "$PIECE_DIR/research.md"

  _write_manifest_specced
  _commit "manifest: mark demo/hello as specced" manifest.yaml

  _write_spec
  _commit "spec: add demo/hello specification" "$PIECE_DIR/spec.md"
fi

# Commit 4: manifest planned — skipped for skip-transition break
if [ "$BREAK_CASE" != "skip-transition" ]; then
  _write_manifest_planned
  _commit "manifest: mark demo/hello as planned" manifest.yaml
fi

# Commit 5: plan
_write_plan
_commit "plan: add demo/hello implementation plan" "$PIECE_DIR/plan.md"

# Commit 6: manifest in-progress
_write_manifest_inprogress
_commit "manifest: mark demo/hello as in-progress" manifest.yaml

# Commit 7: spike artifact — skipped for no-spike-artifact break
if [ "$BREAK_CASE" != "no-spike-artifact" ]; then
  _write_spike
  _commit "chore(spike): phase-1 resolution" "$PIECE_DIR/spikes/phase-1.md"
fi

# Commit 8: tests + src
_write_tests_and_src
_commit "feat(demo): phase 1 — greet (tests + implementation)" \
  "$PIECE_DIR/tests/test-greet.sh" \
  "$PIECE_DIR/src/greet.sh"

# Commit 9: config
_write_config
_commit "feat(demo): phase 2 — config wiring" "$PIECE_DIR/src/config.txt"

# Commit 10: discovery log
_write_discovery_log
_commit "chore(demo): discovery log — phase 2 triage" "$PIECE_DIR/.discovery-log.md"

# Commit 11: learnings — skipped for missing-learnings break
if [ "$BREAK_CASE" != "missing-learnings" ]; then
  _write_learnings
  _commit "learnings: demo/hello" "$PIECE_DIR/learnings.md"
fi

# Commit 12: manifest merged
_write_manifest_merged
_commit "manifest: mark demo/hello as merged" manifest.yaml

# ---------------------------------------------------------------------------
# Post-build: journal-survives break — write uncommitted journal file
# ---------------------------------------------------------------------------
if [ "$BREAK_CASE" = "journal-survives" ]; then
  printf '{"group_letter":"A"}\n' > "$TARGET_DIR/.phase-group-journal.json"
fi
