#!/usr/bin/env bash
# run-e2e.sh — spec-flow pipeline end-to-end smoke test runner
# Usage: run-e2e.sh [--audit <piece-dir> | --verify-live <target> [--transcript <jsonl>]
#                   | --record-golden <target> <transcript> | --break <case> | --help]
# No args = default mode (all checks).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; E2E_DIR="$SCRIPT_DIR"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"          # plugins/spec-flow
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"

. "$SCRIPT_DIR/lib/assert.sh"
for f in "$SCRIPT_DIR"/lib/*.sh; do [ "$f" = "$SCRIPT_DIR/lib/assert.sh" ] || . "$f"; done

# run_mode <function> [args...] — guard: missing module → ERROR; present → call it
run_mode() { if declare -f "$1" >/dev/null 2>&1; then "$1" "${@:2}"; else err "module missing: $1"; fi; }

# ---------------------------------------------------------------------------
# CLI parser
# ---------------------------------------------------------------------------
MODE="default"
AUDIT_DIR=""
LIVE_TARGET=""
TRANSCRIPT=""
GOLDEN_TARGET=""
GOLDEN_TRANSCRIPT=""
BREAK_CASE=""

usage() {
  cat >&2 <<'EOF'
Usage: run-e2e.sh [MODE]

Modes:
  (no args)                          Default: L1 static + L2 replay + live selftest + golden + metrics
  --audit <piece-dir>                Audit mode: shape checks on a real piece dir (no git history required)
  --verify-live <target>             Verify-live: full SF-3 checks on a post-run target dir
    [--transcript <jsonl>]             Optional: path to session transcript .jsonl
  --record-golden <target> <jsonl>   Record a new golden footprint from a verified live run
  --break <case>                     Build a single-defect fixture (delegates to build-fixture.sh)
  --help                             Show this usage text

Break cases: research-after-spec | no-test-data | no-spike-artifact |
             skip-transition | journal-survives | missing-learnings

Result vocabulary: PASS | FAIL | SKIPPED: <capability> | ERROR | EXCLUDED
Exit: 0 iff failed==0 && errors==0
EOF
}

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --audit)
      [ $# -lt 2 ] && { printf 'ERROR: --audit requires <piece-dir>\n' >&2; usage; exit 2; }
      MODE="audit"
      AUDIT_DIR="$2"
      shift 2
      ;;
    --verify-live)
      [ $# -lt 2 ] && { printf 'ERROR: --verify-live requires <target>\n' >&2; usage; exit 2; }
      MODE="verify-live"
      LIVE_TARGET="$2"
      shift 2
      # Optional --transcript may follow
      if [ $# -ge 2 ] && [ "$1" = "--transcript" ]; then
        TRANSCRIPT="$2"
        export TRANSCRIPT
        shift 2
      fi
      ;;
    --transcript)
      [ $# -lt 2 ] && { printf 'ERROR: --transcript requires <jsonl>\n' >&2; usage; exit 2; }
      TRANSCRIPT="$2"
      export TRANSCRIPT
      shift 2
      ;;
    --record-golden)
      [ $# -lt 3 ] && { printf 'ERROR: --record-golden requires <target> <transcript>\n' >&2; usage; exit 2; }
      MODE="record-golden"
      GOLDEN_TARGET="$2"
      GOLDEN_TRANSCRIPT="$3"
      shift 3
      ;;
    --break)
      [ $# -lt 2 ] && { printf 'ERROR: --break requires <case>\n' >&2; usage; exit 2; }
      MODE="break"
      BREAK_CASE="$2"
      shift 2
      ;;
    *)
      printf 'ERROR: unknown flag: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Mode dispatch
# ---------------------------------------------------------------------------
case "$MODE" in

  default)
    run_mode l1_static_checks
    run_mode l2_replay_checks
    run_mode verify_live_selftest
    if have_golden; then
      run_mode golden_validate
    else
      skip_cap live-run "no golden recorded — run the live procedure (README)"
    fi
    run_mode metrics_check
    summary
    exit $?
    ;;

  audit)
    run_mode audit_checks "$AUDIT_DIR"
    summary
    exit $?
    ;;

  verify-live)
    run_mode verify_live "$LIVE_TARGET" "${TRANSCRIPT:-}"
    summary
    exit $?
    ;;

  record-golden)
    run_mode record_golden "$GOLDEN_TARGET" "$GOLDEN_TRANSCRIPT"
    summary
    exit $?
    ;;

  break)
    BUILDER="$SCRIPT_DIR/build-fixture.sh"
    if [ ! -f "$BUILDER" ]; then
      err "build-fixture.sh not found (Phase 3 not yet implemented)"
      summary
      exit $?
    fi
    BREAK_TMP=$(e2e_mktemp)
    bash "$BUILDER" "$BREAK_TMP" "--break=$BREAK_CASE"
    printf 'BUILT: %s\n' "$BREAK_TMP"
    ;;

esac
