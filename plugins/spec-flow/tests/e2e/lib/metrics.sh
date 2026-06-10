# spec-flow e2e — metrics capability gate
# Sourced by run-e2e.sh after assert.sh.
# Functions defined: metrics_check

# ---------------------------------------------------------------------------
# metrics_check [piece-dir]
#   Single flip point: have_metrics_artifact "$dir"
#     false → SKIPPED: metrics-artifact (FR-010 not shipped)
#     true  → assert_file "$dir/metrics.yaml" "metrics artifact present"
#
#   Default piece-dir: docs/prds/demo/specs/hello under REPO_ROOT.
#   This default yields SKIPPED today (no metrics.yaml in that path).
# ---------------------------------------------------------------------------
metrics_check() {
  local dir="${1:-}"

  if [ -z "$dir" ]; then
    # Default: demo piece dir inside repo root — no metrics.yaml today → SKIPPED
    local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
    dir="$repo_root/docs/prds/demo/specs/hello"
  fi

  if have_metrics_artifact "$dir"; then
    assert_file "$dir/metrics.yaml" "metrics artifact present"
  else
    skip_cap metrics-artifact "FR-010 not shipped — probe path: $dir/metrics.yaml"
  fi
}
