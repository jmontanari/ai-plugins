#!/usr/bin/env bash
# test-metrics-aggregate.sh — test harness for metrics-aggregate (M1–M10)
#
# Runs each test case against both the python fast path and the awk fallback
# (METRICS_AGG_NO_PY=1), plus a path-parity check per case.
# Exit 0 only if every assertion passes.

set -uo pipefail   # NOT -e: test must continue on assertion failure

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="${SCRIPT_DIR}/../metrics-aggregate"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$(( PASS + 1 )); }
fail() { echo "  FAIL: $1"; FAIL=$(( FAIL + 1 )); }

assert_grep() {
  local pat="$1" label="$2"; shift 2
  local out
  out="$("$@" 2>/dev/null)" || true
  if printf '%s\n' "$out" | grep -qE "$pat"; then
    pass "$label"
  else
    fail "${label} (pattern not found: ${pat})"
    printf '%s\n' "$out" | head -8 | sed 's/^/    /'
  fi
}

assert_no_grep() {
  local pat="$1" label="$2"; shift 2
  local out
  out="$("$@" 2>/dev/null)" || true
  if printf '%s\n' "$out" | grep -qE "$pat"; then
    fail "${label} (unexpected pattern found: ${pat})"
    printf '%s\n' "$out" | head -4 | sed 's/^/    /'
  else
    pass "$label"
  fi
}

assert_exit_zero() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label (non-zero exit)"
  fi
}

check_path_parity() {
  local label="$1" prd="$2" tmp="$3"
  local py_out awk_out
  py_out="$(DOCS_ROOT="${tmp}/docs" bash "$TOOL" "$prd" 2>/dev/null)" || true
  awk_out="$(METRICS_AGG_NO_PY=1 DOCS_ROOT="${tmp}/docs" bash "$TOOL" "$prd" 2>/dev/null)" || true
  if [ "$py_out" = "$awk_out" ]; then
    pass "$label"
  else
    fail "$label (py/awk paths differ)"
    diff <(printf '%s\n' "$py_out") <(printf '%s\n' "$awk_out") | head -10 | sed 's/^/    /'
  fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

make_manifest() {
  local dir="$1"; shift
  # Remaining args: piece slugs in order
  mkdir -p "$dir"
  printf 'schema_version: 1\npieces:\n' > "${dir}/manifest.yaml"
  for slug in "$@"; do
    printf '  - name: %s\n    slug: %s\n    status: open\n    dependencies: []\n' "$slug" "$slug" >> "${dir}/manifest.yaml"
  done
}

make_metrics() {
  local path="$1"
  local research_artifact="${2:-false}"
  local qa_rounds="${3:-0}"
  local concreteness_floor="${4:-}"
  local phases_total="${5:-0}"
  local phases_clean="${6:-0}"
  local disc_unmarked="${7:-0}"
  local spikes_planned="${8:-0}"
  local spikes_scope="${9:-0}"
  local repeat_scope="${10:-0}"
  local sonnet_default="${11:-true}"
  local resume_outcome="${12:-}"   # empty = no resume, "clean" or "state-incomplete"

  mkdir -p "$(dirname "$path")"
  {
    printf 'schema_version: 1\ngenerated: 2026-06-10\nlast_updated: 2026-06-10\n'
    printf 'spec:\n'
    printf '  research_artifact: %s\n' "$research_artifact"
    printf '  qa_rounds: %d\n' "$qa_rounds"
    printf 'plan:\n'
    if [ -n "$concreteness_floor" ]; then
      printf '  concreteness_floor: %s\n' "$concreteness_floor"
    fi
    printf 'execute:\n'
    printf '  sonnet_default: %s\n' "$sonnet_default"
    printf '  phases:\n'
    printf '    total: %d\n' "$phases_total"
    printf '    clean_sonnet: %d\n' "$phases_clean"
    printf '  discoveries:\n'
    printf '    unmarked: %d\n' "$disc_unmarked"
    printf '  spikes:\n'
    printf '    planned: %d\n' "$spikes_planned"
    printf '    scope: %d\n' "$spikes_scope"
    printf '  amendments:\n'
    printf '    repeat_scope: %d\n' "$repeat_scope"
    if [ -n "$resume_outcome" ]; then
      printf '  resume:\n'
      printf '    - at: phase_3\n'
      printf '      outcome: %s\n' "$resume_outcome"
    fi
  } > "$path"
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
echo "=== metrics-aggregate tests (M1-M10, dual-path) ==="
echo ""

if [ ! -f "$TOOL" ]; then
  echo "FATAL: tool not found: $TOOL" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# M1: instrumented + absent
# ---------------------------------------------------------------------------
echo "--- M1: instrumented + absent ---"

M1_TMP="$(mktemp -d)"
make_manifest "${M1_TMP}/docs/prds/test-prd" p1 p2
make_metrics "${M1_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  true 2 passed 4 4 0 1 0 0 true clean
# p2: no metrics.yaml (ABSENT)

assert_grep "SC-001 pass=1 total=1" "M1 (py): SC-001" \
  env DOCS_ROOT="${M1_TMP}/docs" bash "$TOOL" test-prd
assert_grep "ABSENT test-prd/p2" "M1 (py): ABSENT p2" \
  env DOCS_ROOT="${M1_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M1 (py): exit 0" \
  env DOCS_ROOT="${M1_TMP}/docs" bash "$TOOL" test-prd

assert_grep "SC-001 pass=1 total=1" "M1 (awk): SC-001" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M1_TMP}/docs" bash "$TOOL" test-prd
assert_grep "ABSENT test-prd/p2" "M1 (awk): ABSENT p2" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M1_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M1 (awk): exit 0" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M1_TMP}/docs" bash "$TOOL" test-prd

echo ""

# ---------------------------------------------------------------------------
# M2: awk fallback parity
# ---------------------------------------------------------------------------
echo "--- M2: awk fallback parity ---"

check_path_parity "M2: py/awk byte-identical output" "test-prd" "$M1_TMP"

rm -rf "$M1_TMP"
echo ""

# ---------------------------------------------------------------------------
# M3: malformed metrics.yaml
# ---------------------------------------------------------------------------
echo "--- M3: malformed metrics.yaml ---"

M3_TMP="$(mktemp -d)"
make_manifest "${M3_TMP}/docs/prds/test-prd" p1 p2
make_metrics "${M3_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  true 2 passed 4 4 0 1 0 0 true clean
# p2: malformed yaml
mkdir -p "${M3_TMP}/docs/prds/test-prd/specs/p2"
printf 'spec:\n  qa_rounds: : :\n' > "${M3_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml"

assert_grep "ABSENT test-prd/p2" "M3 (py): malformed treated as absent" \
  env DOCS_ROOT="${M3_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-001 pass=1 total=1" "M3 (py): SC-001 over p1 only" \
  env DOCS_ROOT="${M3_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M3 (py): exit 0" \
  env DOCS_ROOT="${M3_TMP}/docs" bash "$TOOL" test-prd

assert_grep "ABSENT test-prd/p2" "M3 (awk): malformed treated as absent" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M3_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-001 pass=1 total=1" "M3 (awk): SC-001 over p1 only" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M3_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M3 (awk): exit 0" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M3_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M3: py/awk parity with malformed piece" "test-prd" "$M3_TMP"

rm -rf "$M3_TMP"
echo ""

# ---------------------------------------------------------------------------
# M4: trend even N=4
# p1 unmarked=3, spikes=(4+0)=4
# p2 unmarked=2, spikes=(2+0)=2
# p3 unmarked=1, spikes=(1+0)=1
# p4 unmarked=0, spikes=(0+0)=0
# first_half=[p1,p2]: disc=5, spikes=6
# second_half=[p3,p4]: disc=1, spikes=1
# ---------------------------------------------------------------------------
echo "--- M4: trend even N=4 ---"

M4_TMP="$(mktemp -d)"
make_manifest "${M4_TMP}/docs/prds/test-prd" p1 p2 p3 p4
make_metrics "${M4_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" false 0 "" 0 0 3 4 0 0 true
make_metrics "${M4_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml" false 0 "" 0 0 2 2 0 0 true
make_metrics "${M4_TMP}/docs/prds/test-prd/specs/p3/metrics.yaml" false 0 "" 0 0 1 1 0 0 true
make_metrics "${M4_TMP}/docs/prds/test-prd/specs/p4/metrics.yaml" false 0 "" 0 0 0 0 0 0 true

assert_grep "SC-003 first=5 second=1 trend=down" "M4 (py): SC-003 first=5 second=1 trend=down" \
  env DOCS_ROOT="${M4_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-005 first=6 second=1 trend=down" "M4 (py): SC-005 first=6 second=1 trend=down" \
  env DOCS_ROOT="${M4_TMP}/docs" bash "$TOOL" test-prd

assert_grep "SC-003 first=5 second=1 trend=down" "M4 (awk): SC-003 first=5 second=1 trend=down" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M4_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-005 first=6 second=1 trend=down" "M4 (awk): SC-005 first=6 second=1 trend=down" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M4_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M4: py/awk parity N=4" "test-prd" "$M4_TMP"

rm -rf "$M4_TMP"
echo ""

# ---------------------------------------------------------------------------
# M5: trend odd N=5
# p1=4, p2=3, p3=2(middle), p4=1, p5=0
# N=5, floor(5/2)=2; first=[p1,p2]=7; second=[p4,p5]=1; middle=p3 excluded
# ---------------------------------------------------------------------------
echo "--- M5: trend odd N=5 ---"

M5_TMP="$(mktemp -d)"
make_manifest "${M5_TMP}/docs/prds/test-prd" p1 p2 p3 p4 p5
make_metrics "${M5_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" false 0 "" 0 0 4 0 0 0 true
make_metrics "${M5_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml" false 0 "" 0 0 3 0 0 0 true
make_metrics "${M5_TMP}/docs/prds/test-prd/specs/p3/metrics.yaml" false 0 "" 0 0 2 0 0 0 true
make_metrics "${M5_TMP}/docs/prds/test-prd/specs/p4/metrics.yaml" false 0 "" 0 0 1 0 0 0 true
make_metrics "${M5_TMP}/docs/prds/test-prd/specs/p5/metrics.yaml" false 0 "" 0 0 0 0 0 0 true

assert_grep "SC-003 first=7 second=1 trend=down" "M5 (py): SC-003 first=7 second=1 trend=down" \
  env DOCS_ROOT="${M5_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-003 first=7 second=1 trend=down" "M5 (awk): SC-003 first=7 second=1 trend=down" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M5_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M5: py/awk parity N=5" "test-prd" "$M5_TMP"

rm -rf "$M5_TMP"
echo ""

# ---------------------------------------------------------------------------
# M6: N=1 insufficient-data
# ---------------------------------------------------------------------------
echo "--- M6: N=1 insufficient-data ---"

M6_TMP="$(mktemp -d)"
make_manifest "${M6_TMP}/docs/prds/test-prd" p1
make_metrics "${M6_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  false 0 "" 0 0 0 0 0 0 true

assert_grep "SC-003 trend=insufficient-data" "M6 (py): SC-003 insufficient-data" \
  env DOCS_ROOT="${M6_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-005 trend=insufficient-data" "M6 (py): SC-005 insufficient-data" \
  env DOCS_ROOT="${M6_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M6 (py): exit 0" \
  env DOCS_ROOT="${M6_TMP}/docs" bash "$TOOL" test-prd

assert_grep "SC-003 trend=insufficient-data" "M6 (awk): SC-003 insufficient-data" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M6_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-005 trend=insufficient-data" "M6 (awk): SC-005 insufficient-data" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M6_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M6 (awk): exit 0" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M6_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M6: py/awk parity N=1" "test-prd" "$M6_TMP"

rm -rf "$M6_TMP"
echo ""

# ---------------------------------------------------------------------------
# M7: SC-001 population gating
# p1: research_artifact=true, qa_rounds=2 → in population, passes
# p2: research_artifact=false, qa_rounds=9 → excluded, NOT a failure
# Expected: SC-001 pass=1 total=1
# ---------------------------------------------------------------------------
echo "--- M7: SC-001 population gating ---"

M7_TMP="$(mktemp -d)"
make_manifest "${M7_TMP}/docs/prds/test-prd" p1 p2
make_metrics "${M7_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  true 2 "" 0 0 0 0 0 0 true
make_metrics "${M7_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml" \
  false 9 "" 0 0 0 0 0 0 true

assert_grep "SC-001 pass=1 total=1" "M7 (py): SC-001 only p1 in population" \
  env DOCS_ROOT="${M7_TMP}/docs" bash "$TOOL" test-prd
assert_no_grep "SC-001 pass=1 total=2" "M7 (py): p2 not counted in SC-001" \
  env DOCS_ROOT="${M7_TMP}/docs" bash "$TOOL" test-prd

assert_grep "SC-001 pass=1 total=1" "M7 (awk): SC-001 only p1 in population" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M7_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M7: py/awk parity SC-001 gating" "test-prd" "$M7_TMP"

rm -rf "$M7_TMP"
echo ""

# ---------------------------------------------------------------------------
# M8: SC-002 population gating
# p1: concreteness_floor=passed, total=4, clean=4
# p2: concreteness_floor=overridden, total=9, clean=1
# Expected: SC-002 rate=1.00 (p2 excluded)
# ---------------------------------------------------------------------------
echo "--- M8: SC-002 population gating ---"

M8_TMP="$(mktemp -d)"
make_manifest "${M8_TMP}/docs/prds/test-prd" p1 p2
make_metrics "${M8_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  false 0 passed 4 4 0 0 0 0 true
make_metrics "${M8_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml" \
  false 0 overridden 9 1 0 0 0 0 true

assert_grep "SC-002 rate=1\.00" "M8 (py): SC-002 rate=1.00 (p2 excluded)" \
  env DOCS_ROOT="${M8_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-002 rate=1\.00" "M8 (awk): SC-002 rate=1.00 (p2 excluded)" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M8_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M8: py/awk parity SC-002 gating" "test-prd" "$M8_TMP"

rm -rf "$M8_TMP"
echo ""

# ---------------------------------------------------------------------------
# M9a: SC-004 conjunct b fails (sonnet_default=false on p2)
# ---------------------------------------------------------------------------
echo "--- M9a: SC-004 conjunct b fails ---"

M9A_TMP="$(mktemp -d)"
make_manifest "${M9A_TMP}/docs/prds/test-prd" p1 p2
make_metrics "${M9A_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  false 0 "" 0 0 0 0 0 0 true clean
make_metrics "${M9A_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml" \
  false 0 "" 0 0 0 0 0 0 false clean

assert_grep "SC-004.*pass=false" "M9a (py): SC-004 pass=false (sonnet_default_all=false)" \
  env DOCS_ROOT="${M9A_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-004.*sonnet_default_all=false" "M9a (py): SC-004 sonnet_default_all=false" \
  env DOCS_ROOT="${M9A_TMP}/docs" bash "$TOOL" test-prd

assert_grep "SC-004.*pass=false" "M9a (awk): SC-004 pass=false" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M9A_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M9a: py/awk parity SC-004 conjunct b" "test-prd" "$M9A_TMP"

rm -rf "$M9A_TMP"
echo ""

# ---------------------------------------------------------------------------
# M9b: SC-004 conjunct a fails (resume outcome=state-incomplete on p2)
# ---------------------------------------------------------------------------
echo "--- M9b: SC-004 conjunct a fails ---"

M9B_TMP="$(mktemp -d)"
make_manifest "${M9B_TMP}/docs/prds/test-prd" p1 p2
make_metrics "${M9B_TMP}/docs/prds/test-prd/specs/p1/metrics.yaml" \
  false 0 "" 0 0 0 0 0 0 true clean
make_metrics "${M9B_TMP}/docs/prds/test-prd/specs/p2/metrics.yaml" \
  false 0 "" 0 0 0 0 0 0 true state-incomplete

assert_grep "SC-004.*pass=false" "M9b (py): SC-004 pass=false (resume_rate < 1.0)" \
  env DOCS_ROOT="${M9B_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-004.*resume_rate=0\.50" "M9b (py): SC-004 resume_rate=0.50" \
  env DOCS_ROOT="${M9B_TMP}/docs" bash "$TOOL" test-prd

assert_grep "SC-004.*pass=false" "M9b (awk): SC-004 pass=false" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M9B_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M9b: py/awk parity SC-004 conjunct a" "test-prd" "$M9B_TMP"

rm -rf "$M9B_TMP"
echo ""

# ---------------------------------------------------------------------------
# M10: all-absent PRD
# ---------------------------------------------------------------------------
echo "--- M10: all-absent PRD ---"

M10_TMP="$(mktemp -d)"
make_manifest "${M10_TMP}/docs/prds/test-prd" p1 p2
# Neither p1 nor p2 has metrics.yaml

assert_grep "ABSENT test-prd/p1" "M10 (py): ABSENT p1" \
  env DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd
assert_grep "ABSENT test-prd/p2" "M10 (py): ABSENT p2" \
  env DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-003 trend=insufficient-data" "M10 (py): SC-003 insufficient-data" \
  env DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M10 (py): exit 0" \
  env DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd

assert_grep "ABSENT test-prd/p1" "M10 (awk): ABSENT p1" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd
assert_grep "ABSENT test-prd/p2" "M10 (awk): ABSENT p2" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd
assert_grep "SC-003 trend=insufficient-data" "M10 (awk): SC-003 insufficient-data" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd
assert_exit_zero "M10 (awk): exit 0" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${M10_TMP}/docs" bash "$TOOL" test-prd

check_path_parity "M10: py/awk parity all-absent" "test-prd" "$M10_TMP"

rm -rf "$M10_TMP"
echo ""

# ---------------------------------------------------------------------------
# M11: inline comments in metrics.yaml
# ---------------------------------------------------------------------------
echo "--- M11: inline comments in metrics.yaml ---"

TMP_M11=$(mktemp -d)
mkdir -p "${TMP_M11}/docs/prds/test-prd/specs/p1"
cat > "${TMP_M11}/docs/prds/test-prd/manifest.yaml" << 'EOF'
schema_version: 1
pieces:
  - name: p1
    slug: p1
    status: merged
EOF
cat > "${TMP_M11}/docs/prds/test-prd/specs/p1/metrics.yaml" << 'EOF'
schema_version: 1
spec:
  qa_rounds: 2  # should be ≤3
  qa_iterations: 1
  research_artifact: true # gates SC-001
plan:
  qa_iterations: 1
  concreteness_floor: passed # passed | overridden
execute:
  sonnet_default: true # SC-004 second conjunct
  phases:
    total: 4
    clean_sonnet: 4
  discoveries:
    spike_attributed: 0
    unmarked: 0
  spikes:
    planned: 0
    scope: 0
  escalations: 0
  amendments:
    total: 0
    repeat_scope: 0
  dispatches:
    opus: 2
    sonnet: 8
  qa_iterations: 2
  resume: []
final_review:
  iterations: 1
  must_fix: 0
EOF
# python path
assert_grep "SC-001 pass=1 total=1" "M11 (py): SC-001 correct with inline comments" \
  env DOCS_ROOT="${TMP_M11}/docs" bash "$TOOL" test-prd
assert_grep "SC-002 rate=1\.00" "M11 (py): SC-002 correct with inline comments" \
  env DOCS_ROOT="${TMP_M11}/docs" bash "$TOOL" test-prd
assert_exit_zero "M11 (py): exit 0" \
  env DOCS_ROOT="${TMP_M11}/docs" bash "$TOOL" test-prd
# awk path
assert_grep "SC-001 pass=1 total=1" "M11 (awk): SC-001 correct with inline comments" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${TMP_M11}/docs" bash "$TOOL" test-prd
assert_grep "SC-002 rate=1\.00" "M11 (awk): SC-002 correct with inline comments" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${TMP_M11}/docs" bash "$TOOL" test-prd
assert_exit_zero "M11 (awk): exit 0" \
  env METRICS_AGG_NO_PY=1 DOCS_ROOT="${TMP_M11}/docs" bash "$TOOL" test-prd
# parity check
check_path_parity "M11: py/awk parity with inline comments" "test-prd" "$TMP_M11"

rm -rf "$TMP_M11"
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "== summary: ${PASS} passed, ${FAIL} failed =="
[ "$FAIL" -ne 0 ] && exit 1
exit 0
