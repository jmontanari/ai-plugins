#!/usr/bin/env bash
# test-lint-skill-coherence.sh — plain-bash assertion runner (no test framework).
#
# Runs the coherence linter against the three fixtures and asserts exit codes +
# finding presence, plus the invocation surface (single path / multiple paths /
# directory). Prints PASS/FAIL per assertion; exits non-zero if any assertion fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINTER="${SCRIPT_DIR}/../lint-skill-coherence"

CLEAN="${SCRIPT_DIR}/fixture-clean.md"
DEFECT="${SCRIPT_DIR}/fixture-3defect.md"
ORPHAN="${SCRIPT_DIR}/fixture-orphan-field.md"
REAL="${SCRIPT_DIR}/fixture-real-conventions.md"
PREFIXFN="${SCRIPT_DIR}/fixture-prefix-falseneg.md"
PHANTOM="${SCRIPT_DIR}/fixture-phantom-step.md"

FAILS=0
PASSES=0

pass() { printf 'PASS — %s\n' "$1"; PASSES=$((PASSES + 1)); }
fail() { printf 'FAIL — %s\n' "$1"; FAILS=$((FAILS + 1)); }

# assert_exit <expected_code> <label> -- <command...>
assert_exit() {
  local want="$1" label="$2"; shift 3
  "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then pass "${label} (exit ${got})"; else fail "${label} (want exit ${want}, got ${got})"; fi
}

# assert_grep <pattern> <label> -- <command...>
assert_grep() {
  local pat="$1" label="$2"; shift 3
  local out
  out="$("$@" 2>/dev/null)"
  if printf '%s\n' "$out" | grep -qE "$pat"; then pass "$label"; else fail "${label} (pattern not found: ${pat})"; fi
}

# assert_no_grep <pattern> <label> -- <command...>
assert_no_grep() {
  local pat="$1" label="$2"; shift 3
  local out
  out="$("$@" 2>/dev/null)"
  if printf '%s\n' "$out" | grep -qE "$pat"; then fail "${label} (unexpected pattern present: ${pat})"; else pass "$label"; fi
}

echo "== executable bit =="
if [ -x "$LINTER" ]; then pass "linter is executable"; else fail "linter is executable"; fi

echo "== clean fixture (exit 0, no findings) =="
assert_exit 0 "clean fixture exits 0" -- "$LINTER" "$CLEAN"
assert_no_grep ' — ' "clean fixture has zero finding lines" -- "$LINTER" "$CLEAN"

echo "== 3-defect fixture (exit != 0, one finding per blocking invariant) =="
assert_exit 1 "3-defect fixture exits non-zero" -- "$LINTER" "$DEFECT"
assert_grep 'invariant-1' "3-defect: step-reference finding present" -- "$LINTER" "$DEFECT"
assert_grep 'invariant-2' "3-defect: pointer finding present" -- "$LINTER" "$DEFECT"
assert_grep 'invariant-3' "3-defect: config-branch-parity finding present" -- "$LINTER" "$DEFECT"
# The invariant-3 defect is now a 3-value key (phase_groups: auto+always, off omitted)
# — a 2-value key can never violate under the >= 2-distinct-values trigger.
assert_grep 'invariant-3 — config-branch parity: key "phase_groups".*missing: off' \
  "3-defect: parity defect is phase_groups omitting off" -- "$LINTER" "$DEFECT"

echo "== real-conventions fixture (exit 0, no findings) =="
# Regression guard for all four real-corpus conventions: backtick cross-refs,
# bold-marker step defs, cross-skill refs, and incidental single-value config
# mentions. None may produce a blocking finding.
assert_exit 0 "real-conventions fixture exits 0" -- "$LINTER" "$REAL"
assert_no_grep ' — ' "real-conventions: zero finding lines" -- "$LINTER" "$REAL"

echo "== prefix-falseneg fixture (MF-A: broken cross-ref sharing a heading prefix IS caught) =="
# A broken §-pointer whose first word is a character-prefix of a real heading in
# the target reference doc (`§Purposeful…` vs `## Purpose`) must NOT resolve via
# an unbounded prefix-match — the word-boundary guard makes it fire invariant-2.
assert_exit 1 "prefix-falseneg fixture exits non-zero" -- "$LINTER" "$PREFIXFN"
assert_grep 'invariant-2 — unresolved cross-ref pointer.*Purposeful' \
  "prefix-falseneg: broken prefix-shadowed cross-ref is flagged" -- "$LINTER" "$PREFIXFN"

echo "== orphan-field fixture (WARNING present, exit 0) =="
assert_exit 0 "orphan-field fixture exits 0" -- "$LINTER" "$ORPHAN"
assert_grep '^WARNING:' "orphan-field: WARNING line present" -- "$LINTER" "$ORPHAN"
assert_no_grep ' — invariant-[123] — ' "orphan-field: no blocking findings" -- "$LINTER" "$ORPHAN"
# FR-2 parity: invariant-4 fires in BOTH directions.
assert_grep 'orphan producer' "orphan-field: orphan PRODUCER (written-never-read) warned" -- "$LINTER" "$ORPHAN"
assert_grep 'orphan consumer' "orphan-field: orphan CONSUMER (read-never-written) warned" -- "$LINTER" "$ORPHAN"

echo "== phantom-step fixture (ground-truth: bare list is not a step target; per-ref cross-skill) =="
# A dangling `Step 7` masked by a bare `7.` enumeration must still be flagged, and a
# dangling self-ref `Step 9` on a line that also names a `/SKILL.md` path must NOT be
# suppressed (per-reference scoping, not per-line). Steps 1/2 (bold-labeled list
# items) resolve and must NOT be flagged.
assert_exit 1 "phantom-step fixture exits non-zero" -- "$LINTER" "$PHANTOM"
assert_grep 'invariant-1 — unresolved step reference "Step 7"' \
  "phantom-step: dangling Step 7 masked by a bare 7. list IS flagged" -- "$LINTER" "$PHANTOM"
assert_grep 'invariant-1 — unresolved step reference "Step 9"' \
  "phantom-step: dangling Step 9 on a /SKILL.md line is NOT gate-bypassed" -- "$LINTER" "$PHANTOM"
assert_no_grep 'unresolved step reference "Step [12]"' \
  "phantom-step: bold-labeled Steps 1/2 resolve (no false positive)" -- "$LINTER" "$PHANTOM"

echo "== invocation surface: single path =="
assert_exit 1 "single path lints the one given file (defect → exit 1)" -- "$LINTER" "$DEFECT"

echo "== invocation surface: multiple paths =="
# clean + defect together → the defect makes the run exit non-zero, and findings
# reference the defect file.
assert_exit 1 "two paths exit non-zero when one has defects" -- "$LINTER" "$CLEAN" "$DEFECT"
assert_grep 'fixture-3defect\.md' "two paths: defect file appears in findings" -- "$LINTER" "$CLEAN" "$DEFECT"
assert_no_grep 'fixture-clean\.md — ' "two paths: clean file produces no finding" -- "$LINTER" "$CLEAN" "$DEFECT"

echo "== invocation surface: directory expansion (*SKILL.md) =="
# A directory arg expands to its *SKILL.md files. Build a temp dir holding a
# copy of the defect fixture renamed to SKILL.md and confirm the directory
# invocation lints it (non-zero exit, finding references the temp SKILL.md).
TMPDIR_CASE="$(mktemp -d 2>/dev/null || echo /tmp/lsc-dir-$$)"
mkdir -p "$TMPDIR_CASE"
cp "$DEFECT" "${TMPDIR_CASE}/SKILL.md"
# Also drop a non-SKILL .md that must be IGNORED by directory expansion.
cp "$CLEAN" "${TMPDIR_CASE}/NOTES.md"
assert_exit 1 "directory expands to its SKILL.md and lints it" -- "$LINTER" "$TMPDIR_CASE"
assert_grep "${TMPDIR_CASE}/SKILL.md" "directory: SKILL.md is the linted file" -- "$LINTER" "$TMPDIR_CASE"
assert_no_grep 'NOTES\.md' "directory: non-SKILL .md is ignored" -- "$LINTER" "$TMPDIR_CASE"
rm -rf "$TMPDIR_CASE"

echo
echo "== summary: ${PASSES} passed, ${FAILS} failed =="
if [ "$FAILS" -ne 0 ]; then
  exit 1
fi
exit 0
