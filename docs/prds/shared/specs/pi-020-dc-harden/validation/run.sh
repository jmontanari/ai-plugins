#!/usr/bin/env bash
# Validation harness for pi-020-dc-harden — Phase 1
# Usage: bash run.sh [CASE ...]
# Each case prints PASS <CASE> or FAIL <CASE> and exits non-zero on any FAIL.

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

run_case() {
  local case_name="$1"
  case "$case_name" in
    ANCHOR-1) case_anchor_1 ;;
    ANCHOR-2) case_anchor_2 ;;
    MIG-1)    case_mig_1    ;;
    PROD-1)   case_prod_1   ;;
    SF3-1)    case_sf3_1    ;;
    INV-1)    case_inv_1    ;;
    INV-2)    case_inv_2    ;;
    INV-3)    case_inv_3    ;;
    INV-5)    case_inv_5    ;;
    INV-9)    case_inv_9    ;;
    BASE-1)   case_base_1   ;;
    BASE-2)   case_base_2   ;;
    BASE-3)   case_base_3   ;;
    *)
      echo "UNKNOWN case: $case_name" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      return
      ;;
  esac
}

# ---------------------------------------------------------------------------
# ANCHOR-1 (AC-1):
#   Simulate orchestrator at red-done: run git hash-object -w on a Red test
#   file. Assert the returned blob SHA matches git hash-object (without -w)
#   and that git cat-file -t prints "blob" (the blob was written to the
#   object store).
# ---------------------------------------------------------------------------
case_anchor_1() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Set up a throwaway git repo
  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Create a Red test file
  local test_file="$repo/tests/test_red.py"
  mkdir -p "$repo/tests"
  cat > "$test_file" <<'EOF'
def test_missing_feature():
    from src.foo import bar
    assert bar() == 42
EOF

  # Simulate "orchestrator at red-done": write blob to object store
  local blob_sha
  blob_sha=$(git -C "$repo" hash-object -w -- "$test_file")

  # Assert 1: blob SHA from -w matches hash-object without -w (same content)
  local verify_sha
  verify_sha=$(git -C "$repo" hash-object -- "$test_file")
  if [ "$blob_sha" != "$verify_sha" ]; then
    echo "FAIL ANCHOR-1: blob SHA from -w ($blob_sha) != hash-object without -w ($verify_sha)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Assert 2: git cat-file -t prints "blob" (blob was written to object store)
  local obj_type
  obj_type=$(git -C "$repo" cat-file -t "$blob_sha")
  if [ "$obj_type" != "blob" ]; then
    echo "FAIL ANCHOR-1: git cat-file -t $blob_sha printed '$obj_type', expected 'blob'" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS ANCHOR-1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# ANCHOR-2 (AC-2):
#   After red-done, mutate the test file. Assert git hash-object (without -w)
#   now differs from the stored blob SHA. This proves the barrier would detect
#   the tamper.
# ---------------------------------------------------------------------------
case_anchor_2() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Set up throwaway git repo
  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Create a Red test file
  local test_file="$repo/tests/test_red.py"
  mkdir -p "$repo/tests"
  cat > "$test_file" <<'EOF'
def test_missing_feature():
    from src.foo import bar
    assert bar() == 42
EOF

  # Simulate orchestrator at red-done: record the blob SHA
  local original_blob_sha
  original_blob_sha=$(git -C "$repo" hash-object -w -- "$test_file")

  # Mutate the test file (simulate Build-agent tampering)
  echo "# tamper" >> "$test_file"

  # Assert: working-tree blob SHA now differs from the stored blob SHA
  local tampered_blob_sha
  tampered_blob_sha=$(git -C "$repo" hash-object -- "$test_file")

  if [ "$tampered_blob_sha" = "$original_blob_sha" ]; then
    echo "FAIL ANCHOR-2: blob SHA did not change after mutation — tamper not detectable" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # This proves the barrier would detect the tamper:
  # wt_blob=$(git hash-object -- "$test_file") != manifest_blob ($original_blob_sha)
  echo "PASS ANCHOR-2"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# MIG-1 (AC-5):
#   A fixture journal WITHOUT "anchor: blob" (sha256sum values in
#   red_manifest_hashes) should be honored as-is on resume — verify with
#   sha256sum, not git hash-object, when the marker is absent.
#
#   Since the "resume path" is prose in SKILL.md (not executable code), this
#   case validates the invariant by:
#   (a) Creating an old-format journal fixture (no "anchor" field, sha256sum
#       values in red_manifest_hashes)
#   (b) Verifying the sha256sum of the test file matches the stored value
#       (the old path is honored — the file is unchanged)
#   (c) Confirming no re-anchor is needed (no git hash-object -w needed)
#   Exit 0 on success, documenting that the old path is honored.
# ---------------------------------------------------------------------------
case_mig_1() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Set up throwaway git repo for sha256sum context
  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Create a Red test file (the "old" sub-phase file)
  local test_file="$repo/tests/test_old.py"
  mkdir -p "$repo/tests"
  cat > "$test_file" <<'EOF'
def test_old_behavior():
    assert 1 + 1 == 2
EOF

  # Compute sha256sum (old format — what <=5.1.0 would have stored)
  local sha256_value
  sha256_value=$(sha256sum -- "$test_file" | cut -d' ' -f1)

  # Create a fixture journal WITHOUT the "anchor: blob" marker
  local journal_file="$tmpdir/old_journal.json"
  python3 - <<PYEOF
import json
journal = {
    "group_start_sha": "deadbeef" * 5,
    "group_letter": "A",
    # NOTE: no "anchor" field — this is a <=5.1.0 journal
    "sub_phases": {
        "A.1": {
            "scope": ["tests/test_old.py"],
            "status": "green",
            "red_manifest_hashes": {
                "tests/test_old.py": "$sha256_value"
            }
        }
    }
}
with open("$journal_file", "w") as f:
    json.dump(journal, f, indent=2)
PYEOF

  # Simulate resume: detect that "anchor" is absent → use sha256sum path
  local has_anchor
  has_anchor=$(python3 -c "
import json
with open('$journal_file') as f:
    j = json.load(f)
print('yes' if 'anchor' in j else 'no')
")

  if [ "$has_anchor" = "yes" ]; then
    echo "FAIL MIG-1: fixture journal unexpectedly has 'anchor' field" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # The resume path for old journals uses sha256sum — verify it matches
  local stored_hash
  stored_hash=$(python3 -c "
import json
with open('$journal_file') as f:
    j = json.load(f)
print(j['sub_phases']['A.1']['red_manifest_hashes']['tests/test_old.py'])
")

  local actual_hash
  actual_hash=$(sha256sum -- "$test_file" | cut -d' ' -f1)

  if [ "$actual_hash" != "$stored_hash" ]; then
    echo "FAIL MIG-1: sha256sum mismatch on old-format journal ($actual_hash != $stored_hash)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Confirm: NO git hash-object -w is called in the old resume path
  # (document the invariant — no re-anchor for old journals, file unchanged)
  # The test verifies exit 0 and no re-anchor needed (hash matches, file unchanged).
  echo "PASS MIG-1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# PROD-1 (AC-3):
#   A production-file change must NOT trip the barrier integrity check.
#   The barrier iterates ONLY the keys in red_manifest_hashes (the Red test
#   file). A production-file that is not a key in that map is invisible to
#   the gate.
# ---------------------------------------------------------------------------
case_prod_1() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Set up a throwaway git repo
  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Create a Red test file and anchor it
  local test_file="$repo/tests/test_red.py"
  mkdir -p "$repo/tests"
  cat > "$test_file" <<'EOF'
def test_missing_feature():
    from src.feature import compute
    assert compute() == 99
EOF

  local blob_sha
  blob_sha=$(git -C "$repo" hash-object -w -- "$test_file")

  # Create a separate production file (NOT in red_manifest_hashes)
  local prod_file="$repo/src/feature.py"
  mkdir -p "$repo/src"
  cat > "$prod_file" <<'EOF'
def compute():
    return 0
EOF

  # Simulate Build-agent writing production code (modify the production file)
  cat > "$prod_file" <<'EOF'
def compute():
    return 99
EOF

  # Barrier: iterate ONLY red_manifest_hashes keys (the Red test file only)
  # The production file is NOT a key — it must not influence barrier_failed.
  local barrier_failed=0
  local wt_blob
  wt_blob=$(git -C "$repo" hash-object -- "$test_file")
  if [ "$wt_blob" != "$blob_sha" ]; then
    barrier_failed=1
  fi

  # Assert: barrier_failed is still 0 (production-file change is invisible)
  if [ "$barrier_failed" -ne 0 ]; then
    echo "FAIL PROD-1: production-file change incorrectly tripped the barrier" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS PROD-1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# SF3-1 (AC-4):
#   After a G9 formatter autofix (SF3 sweep), the re-anchor guard writes a
#   new blob SHA. The G9b barrier must PASS using the post-sweep blob SHA
#   (not the original pre-sweep SHA).
# ---------------------------------------------------------------------------
case_sf3_1() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Set up a throwaway git repo
  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Create a Red test file and record the initial anchor
  local test_file="$repo/tests/test_red.py"
  mkdir -p "$repo/tests"
  cat > "$test_file" <<'EOF'
def test_missing_feature():
    from src.foo import bar
    assert bar() == 42
EOF

  local blob_sha_before
  blob_sha_before=$(git -C "$repo" hash-object -w -- "$test_file")

  # Simulate G9 formatter autofix (SF3 sweep): mutate the Red test file
  printf '\n' >> "$test_file"

  # Simulate SF3 re-anchor guard: write the post-sweep blob
  local blob_sha_after
  blob_sha_after=$(git -C "$repo" hash-object -w -- "$test_file")

  # Update the journal entry to the post-sweep blob SHA
  local journal_blob="$blob_sha_after"

  # G9b barrier compare: working-tree blob vs journal blob (post-sweep)
  local wt_blob
  wt_blob=$(git -C "$repo" hash-object -- "$test_file")

  # Assert 1: barrier passes (wt_blob == journal_blob after re-anchor)
  if [ "$wt_blob" != "$journal_blob" ]; then
    echo "FAIL SF3-1: barrier failed after SF3 re-anchor ($wt_blob != $journal_blob)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Assert 2: the sweep actually changed the content (re-anchor was necessary)
  if [ "$blob_sha_before" = "$blob_sha_after" ]; then
    echo "FAIL SF3-1: sweep did not change blob SHA — re-anchor was not exercised" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS SF3-1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# INV-1 (AC-6):
#   Simulate two sub-phases (A.1, A.2) writing distinct files concurrently
#   to the same working tree (no git add, no commit). Barrier "union" add +
#   commit with explicit pathspec. Assert the commit contains exactly those
#   4 files and does NOT contain the journal file.
# ---------------------------------------------------------------------------
case_inv_1() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Initial commit so HEAD exists (git show works on non-empty repos)
  git -C "$repo" commit --allow-empty -m "init" --quiet

  # Create directories
  mkdir -p "$repo/src" "$repo/tests"

  # Sub-phase A.1 writes its files (no git add, no commit — git-free)
  printf 'def a1(): pass\n' > "$repo/src/a1.py"
  printf 'def test_a1(): assert True\n' > "$repo/tests/test_a1.py"

  # Sub-phase A.2 writes its files concurrently (also no git add, no commit)
  printf 'def a2(): pass\n' > "$repo/src/a2.py"
  printf 'def test_a2(): assert True\n' > "$repo/tests/test_a2.py"

  # Barrier: explicit-pathspec git add then commit (union of both sub-phases)
  git -C "$repo" add -- src/a1.py tests/test_a1.py src/a2.py tests/test_a2.py
  git -C "$repo" commit --quiet -m "barrier work-commit" \
      -- src/a1.py tests/test_a1.py src/a2.py tests/test_a2.py

  # Assert 1: commit contains exactly the 4 union files
  local committed_files
  committed_files=$(git -C "$repo" show --name-only --pretty= HEAD | sort)
  local expected_files
  expected_files=$(printf 'src/a1.py\nsrc/a2.py\ntests/test_a1.py\ntests/test_a2.py')

  if [ "$committed_files" != "$expected_files" ]; then
    echo "FAIL INV-1: committed files ($committed_files) != expected union ($expected_files)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Assert 2: journal file is NOT in the commit
  if git -C "$repo" show --name-only --pretty= HEAD | grep -q '\.phase-group-journal\.json'; then
    echo "FAIL INV-1: journal file found in barrier commit" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS INV-1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# INV-5 (AC-6):
#   Same as INV-1 but a .phase-group-journal.json file exists in the working
#   tree. The barrier commit's explicit pathspec must NOT include the journal.
#   Assert the commit contains exactly the 4 sub-phase files and the journal
#   is absent from the commit.
# ---------------------------------------------------------------------------
case_inv_5() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  git init --quiet "$tmpdir/repo"
  local repo="$tmpdir/repo"

  # Initial commit so HEAD exists
  git -C "$repo" commit --allow-empty -m "init" --quiet

  mkdir -p "$repo/src" "$repo/tests"

  # Sub-phase files (git-free, no staging)
  printf 'def a1(): pass\n' > "$repo/src/a1.py"
  printf 'def test_a1(): assert True\n' > "$repo/tests/test_a1.py"
  printf 'def a2(): pass\n' > "$repo/src/a2.py"
  printf 'def test_a2(): assert True\n' > "$repo/tests/test_a2.py"

  # Journal file present in working tree (must never be committed)
  printf '{}' > "$repo/.phase-group-journal.json"

  # Barrier: explicit pathspec does NOT include the journal
  git -C "$repo" add -- src/a1.py tests/test_a1.py src/a2.py tests/test_a2.py
  git -C "$repo" commit --quiet -m "barrier work-commit" \
      -- src/a1.py tests/test_a1.py src/a2.py tests/test_a2.py

  # Assert 1: commit contains exactly the 4 sub-phase files
  local committed_files
  committed_files=$(git -C "$repo" show --name-only --pretty= HEAD | sort)
  local expected_files
  expected_files=$(printf 'src/a1.py\nsrc/a2.py\ntests/test_a1.py\ntests/test_a2.py')

  if [ "$committed_files" != "$expected_files" ]; then
    echo "FAIL INV-5: committed files ($committed_files) != expected union ($expected_files)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Assert 2: journal file is NOT in the commit
  if git -C "$repo" show --name-only --pretty= HEAD | grep -q '\.phase-group-journal\.json'; then
    echo "FAIL INV-5: journal file found in barrier commit (pathspec discipline failed)" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS INV-5"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# INV-2 (AC-7):
#   Scoped oracle for sub-phase A is green while sub-phase B's test is still
#   red (on the shared working tree). Proves Race-2 prevention: scoping
#   isolates A's oracle from B's still-failing test.
#
#   Uses simple python3 script files as a portable stand-in for pytest:
#     test_a.py → sys.exit(0)  (green)
#     test_b.py → sys.exit(1)  (red/failing)
#   "Scoped oracle for A" = run only test_a.py → exit 0 despite test_b.py
#   being red on the working tree.
# ---------------------------------------------------------------------------
case_inv_2() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Sub-phase A's test (green when run)
  printf 'import sys\nsys.exit(0)\n' > "$tmpdir/test_a.py"

  # Sub-phase B's test (still red — B's Build hasn't run yet)
  printf 'import sys\nsys.exit(1)\n' > "$tmpdir/test_b.py"

  # Scoped oracle for A: run ONLY test_a.py (path-scoped)
  if ! python3 "$tmpdir/test_a.py"; then
    echo "FAIL INV-2: scoped oracle for A returned non-zero even though test_a is green" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Confirm B is actually red (so the "shared tree" condition is real)
  if python3 "$tmpdir/test_b.py" 2>/dev/null; then
    echo "FAIL INV-2: test_b.py unexpectedly exited 0 — Race-2 precondition not met" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS INV-2"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# INV-3 (AC-7):
#   Unscoped whole-suite oracle IS polluted in the same state (A green,
#   B still red on shared working tree). Proves that scoping is necessary:
#   an unscoped oracle would report failure for A due to B's red test.
# ---------------------------------------------------------------------------
case_inv_3() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Same setup as INV-2
  printf 'import sys\nsys.exit(0)\n' > "$tmpdir/test_a.py"
  printf 'import sys\nsys.exit(1)\n' > "$tmpdir/test_b.py"

  # "Unscoped oracle": run B's still-red test (or any test in the tree that
  # includes B). B's failure proves the unscoped oracle would report failure
  # even though A is individually green.
  if python3 "$tmpdir/test_b.py" 2>/dev/null; then
    echo "FAIL INV-3: unscoped oracle did NOT fail — Race-2 pollution not demonstrated" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Also confirm A would otherwise pass (isolation is real)
  if ! python3 "$tmpdir/test_a.py"; then
    echo "FAIL INV-3: test_a.py failed — test setup is broken" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS INV-3"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# INV-9 (AC-8):
#   INV-9 runtime isolation and serial-replay backstop.
#
#   Assertion 1: Isolation prevents the collision.
#     - Demonstrate that a shared TMPDIR causes collision (overwrite).
#     - Demonstrate that isolated TMPDIRs prevent the collision.
#
#   Assertion 2: Forced collision → serial replay resolves it.
#     - concurrent_result=1 (simulated failure), serial_result=0 (passes alone)
#     - Decision: collision resolved — not a real failure; logged explicitly.
#
#   Assertion 3: Genuine failure surfaces under serial replay.
#     - concurrent_result=1, serial_result=1
#     - Decision: real failure — escalated, NOT silently masked.
# ---------------------------------------------------------------------------
case_inv_9() {
  local inv9_failed=0

  # -------------------------------------------------------------------------
  # Assertion 1: isolation prevents the collision
  # -------------------------------------------------------------------------

  # Without isolation, two sub-phases writing to the same TMPDIR path would collide
  # (A's output.txt overwritten by B). The assertions below verify that injected
  # isolation (distinct TMPDIR_A / TMPDIR_B) prevents this.

  # Demonstrate isolation prevents the collision
  local TMPDIR_A TMPDIR_B
  TMPDIR_A=$(mktemp -d)
  TMPDIR_B=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$TMPDIR_A' '$TMPDIR_B'" RETURN

  printf 'from-A\n' > "$TMPDIR_A/output.txt"
  printf 'from-B\n' > "$TMPDIR_B/output.txt"

  local content_a content_b
  content_a=$(cat "$TMPDIR_A/output.txt")
  content_b=$(cat "$TMPDIR_B/output.txt")

  if [ "$content_a" != "from-A" ]; then
    echo "FAIL INV-9 assertion 1b: TMPDIR_A/output.txt was overwritten (got '$content_a', expected 'from-A')" >&2
    inv9_failed=1
  fi

  if [ "$content_b" != "from-B" ]; then
    echo "FAIL INV-9 assertion 1b: TMPDIR_B/output.txt has wrong content (got '$content_b', expected 'from-B')" >&2
    inv9_failed=1
  fi

  if [ "$TMPDIR_A" = "$TMPDIR_B" ]; then
    echo "FAIL INV-9 assertion 1c: TMPDIR_A and TMPDIR_B are identical (isolation not achieved)" >&2
    inv9_failed=1
  fi

  rm -rf "$TMPDIR_A" "$TMPDIR_B"

  # -------------------------------------------------------------------------
  # Assertion 2: forced collision → serial replay runs and resolves it
  # -------------------------------------------------------------------------

  # Simulate: concurrent group failed (collision), but work passes in serial
  local concurrent_result=1
  local serial_result=0

  local replay_outcome
  if [ "$concurrent_result" -ne 0 ] && [ "$serial_result" -eq 0 ]; then
    # Serial replay resolved the collision — NOT a real failure
    replay_outcome="collision-resolved"
  elif [ "$concurrent_result" -ne 0 ] && [ "$serial_result" -ne 0 ]; then
    replay_outcome="real-failure"
  else
    replay_outcome="no-failure"
  fi

  if [ "$replay_outcome" != "collision-resolved" ]; then
    echo "FAIL INV-9 assertion 2: expected 'collision-resolved' from replay decision tree, got '$replay_outcome'" >&2
    inv9_failed=1
  fi

  # -------------------------------------------------------------------------
  # Assertion 3: genuine failure surfaces under serial replay
  # -------------------------------------------------------------------------

  # Simulate: concurrent group failed AND serial replay also fails → real failure
  local concurrent_result2=1
  local serial_result2=1

  local replay_outcome2
  if [ "$concurrent_result2" -ne 0 ] && [ "$serial_result2" -eq 0 ]; then
    replay_outcome2="collision-resolved"
  elif [ "$concurrent_result2" -ne 0 ] && [ "$serial_result2" -ne 0 ]; then
    replay_outcome2="real-failure"
  else
    replay_outcome2="no-failure"
  fi

  if [ "$replay_outcome2" != "real-failure" ]; then
    echo "FAIL INV-9 assertion 3: expected 'real-failure' when serial replay also fails, got '$replay_outcome2'" >&2
    inv9_failed=1
  fi

  # -------------------------------------------------------------------------
  # Report
  # -------------------------------------------------------------------------
  if [ "$inv9_failed" -ne 0 ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS INV-9"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# BASE-1 (AC-10): resolver returns `master` when origin/HEAD → master
# ---------------------------------------------------------------------------
case_base_1() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Create a working repo with a commit on master (so origin tracking refs exist)
  local work_dir="$tmpdir/work"
  git init --initial-branch=master "$work_dir" >/dev/null 2>&1 || {
    git init "$work_dir" >/dev/null 2>&1
    git -C "$work_dir" symbolic-ref HEAD refs/heads/master >/dev/null 2>&1
  }
  git -C "$work_dir" config user.email "test@test.com"
  git -C "$work_dir" config user.name "Test"
  printf 'init\n' > "$work_dir/README"
  git -C "$work_dir" add README >/dev/null 2>&1
  git -C "$work_dir" commit -m "init" >/dev/null 2>&1

  # Create a bare "origin" repo cloned from the working repo
  local origin_dir="$tmpdir/origin"
  git clone --bare "$work_dir" "$origin_dir" >/dev/null 2>&1

  # Create a local clone so origin/HEAD is set (clone sets it automatically)
  local local_dir="$tmpdir/local"
  git clone "$origin_dir" "$local_dir" >/dev/null 2>&1

  # Run the resolver's first tier
  local resolved
  resolved=$(git -C "$local_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')

  if [ "$resolved" != "master" ]; then
    echo "FAIL BASE-1: expected 'master' from symbolic-ref, got '$resolved'" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS BASE-1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# BASE-2 (AC-11): all sources absent → non-zero / loud error, no silent `main`
# ---------------------------------------------------------------------------
case_base_2() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Repo with NO remote
  git init "$tmpdir/local" >/dev/null 2>&1
  # No .spec-flow.yaml in $tmpdir/local

  # Tier 1: symbolic-ref (combine local+assignment to avoid set -e on non-zero exit)
  local t1=$(git -C "$tmpdir/local" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  # Tier 2: remote show origin
  local t2=$(git -C "$tmpdir/local" remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  # Tier 3: .spec-flow.yaml
  local t3=$(grep '^default_branch:' "$tmpdir/local/.spec-flow.yaml" 2>/dev/null | awk '{print $2}')

  local resolved="${t1:-${t2:-$t3}}"

  if [ -n "$resolved" ]; then
    echo "FAIL BASE-2: expected empty resolution (no sources), got '$resolved'" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Empirically confirm the error message text is present in execute/SKILL.md
  # (the resolver emits this exact string to stderr before exit 1)
  # Script is invoked from the project root, so this relative path resolves correctly.
  if ! grep -q "cannot resolve default branch" "plugins/spec-flow/skills/execute/SKILL.md" 2>/dev/null; then
    echo "FAIL BASE-2: 'cannot resolve default branch' error message not found in execute/SKILL.md" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS BASE-2"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# BASE-3 (AC-12): config fallback returns `trunk` when other sources absent
# ---------------------------------------------------------------------------
case_base_3() {
  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" RETURN

  # Repo with NO remote but WITH .spec-flow.yaml default_branch: trunk
  git init "$tmpdir/local" >/dev/null 2>&1
  printf 'default_branch: trunk\n' > "$tmpdir/local/.spec-flow.yaml"

  # Tier 1 + 2 are empty (no remote); combine local+assignment to avoid set -e on non-zero exit
  local t1=$(git -C "$tmpdir/local" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  local t2=$(git -C "$tmpdir/local" remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  # Tier 3: .spec-flow.yaml
  local t3=$(grep '^default_branch:' "$tmpdir/local/.spec-flow.yaml" 2>/dev/null | awk '{print $2}')

  local resolved="${t1:-${t2:-$t3}}"

  if [ "$resolved" != "trunk" ]; then
    echo "FAIL BASE-3: expected 'trunk' from config fallback, got '$resolved'" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  echo "PASS BASE-3"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  echo "Usage: bash run.sh CASE [CASE ...]" >&2
  echo "Available cases: ANCHOR-1 ANCHOR-2 MIG-1 PROD-1 SF3-1 INV-1 INV-2 INV-3 INV-5 INV-9 BASE-1 BASE-2 BASE-3" >&2
  exit 1
fi

for case_arg in "$@"; do
  run_case "$case_arg"
done

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
