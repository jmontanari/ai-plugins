#!/usr/bin/env bash
# lib/cheater-oracle.sh — cheater-oracle scenarios for spec-flow e2e suite (AC-7, AC-8)
# Sourced automatically by run-e2e.sh.
# Entry point: cheater_oracle_checks()
# INT-1: registered_in_phase=5, completes_in_phase=6
#   Phase 5: base oracle (6 FR-017 taxonomy + EG-4 transient-commit + allow-set + EG-1 residual)
#   Phase 6: adds EG-2 multi-sub-phase locking fixture (DO NOT add here)

# ---------------------------------------------------------------------------
# Sha256 shim — ADR-7 parity pin (single definition, no duplication)
# ---------------------------------------------------------------------------
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

# ---------------------------------------------------------------------------
# _build_initial_repo <tmpdir>
#   Populates $tmpdir with a minimal git repo:
#     - Initial commit: "Red test" file (tests/test_red.py) + production file (src/math_util.py)
#   Saves the hash of tests/test_red.py in $tmpdir/red-hash.txt BEFORE any tamper.
#   Caller is responsible for cleanup (trap or explicit e2e_cleanup).
# ---------------------------------------------------------------------------
_build_initial_repo() {
  local tmp="$1"

  git -C "$tmp" init -q
  git -C "$tmp" config user.email "test@example.com"
  git -C "$tmp" config user.name "Test"

  mkdir -p "$tmp/tests" "$tmp/src"
  printf '# test_red.py — Red test\ndef test_add():\n    from src.math_util import add\n    assert add(1, 2) == 3\n' \
    > "$tmp/tests/test_red.py"
  printf '# math_util.py\ndef add(a, b):\n    return a + b\n' \
    > "$tmp/src/math_util.py"

  git -C "$tmp" add tests/test_red.py src/math_util.py
  git -C "$tmp" commit -q -m "red: add test_add"

  # Save the original Red test hash before any tamper
  git -C "$tmp" show "HEAD:tests/test_red.py" | _sha256 > "$tmp/red-hash.txt"
}

# ---------------------------------------------------------------------------
# _apply_tamper <tmpdir> <scenario_desc>
#   Applies the scenario-specific tamper to an already-initialized repo.
#   The repo at entry has exactly one commit (the Red commit).
#   After return, HEAD is the tampered/build commit.
# ---------------------------------------------------------------------------
_apply_tamper() {
  local tmp="$1"
  local scenario_desc="$2"

  case "$scenario_desc" in

    edit-assertions)
      # Drift a Red manifest test's assertion text → gate(a) rejects (hash mismatch)
      printf '# test_red.py — Red test (TAMPERED)\ndef test_add():\n    from src.math_util import add\n    assert add(1, 2) == 99\n' \
        > "$tmp/tests/test_red.py"
      git -C "$tmp" add tests/test_red.py
      git -C "$tmp" commit -q -m "build: implement add (tampered assertion)"
      ;;

    skip-delete-tests)
      # Delete a file from the manifest → gate(b) reconciliation rejects (missing file)
      printf '# extra.py\npass\n' > "$tmp/src/extra.py"
      git -C "$tmp" add src/extra.py
      git -C "$tmp" rm -q tests/test_red.py
      git -C "$tmp" commit -q -m "build: implement (deleted test file)"
      ;;

    hardcode-except)
      # Hardcode output in an except-handler inside the test file → gate(a) rejects
      printf '# test_red.py — TAMPERED: hardcoded except\ndef test_add():\n    try:\n        from src.math_util import add\n        assert add(1, 2) == 3\n    except Exception:\n        pass  # hardcoded ignore\n' \
        > "$tmp/tests/test_red.py"
      git -C "$tmp" add tests/test_red.py
      git -C "$tmp" commit -q -m "build: implement add (hardcoded except)"
      ;;

    stub-function)
      # Stub the function-under-test inside the test file → gate(a) rejects
      printf '# test_red.py — TAMPERED: stub inside test\ndef add(a, b):\n    return 3  # stub\ndef test_add():\n    assert add(1, 2) == 3\n' \
        > "$tmp/tests/test_red.py"
      git -C "$tmp" add tests/test_red.py
      git -C "$tmp" commit -q -m "build: implement add (stubbed function)"
      ;;

    weaken-tolerance)
      # Change a tolerance value in a Red test → gate(a) rejects
      printf '# test_red.py — TAMPERED: weakened tolerance\ndef test_add():\n    from src.math_util import add\n    result = add(1, 2)\n    assert abs(result - 3) < 9999  # weakened tolerance\n' \
        > "$tmp/tests/test_red.py"
      git -C "$tmp" add tests/test_red.py
      git -C "$tmp" commit -q -m "build: implement add (weakened tolerance)"
      ;;

    ac-done-no-diff)
      # Attempt to pass via a commit that does not modify any relevant file
      # → gate(b) rejects: commit file list does not include expected manifest files
      printf '# notes.txt — unrelated\n' > "$tmp/notes.txt"
      git -C "$tmp" add notes.txt
      git -C "$tmp" commit -q -m "build: mark ac done (no diff to test)"
      ;;

    eg4-transient-commit)
      # Flat-path tampered content at HEAD that gate(a) sees → gate(a) rejects
      printf '# test_red.py — TAMPERED: eg4 transient\ndef test_add():\n    assert True  # trivially passes\n' \
        > "$tmp/tests/test_red.py"
      git -C "$tmp" add tests/test_red.py
      git -C "$tmp" commit -q -m "build: eg4 transient tamper"
      ;;

    comment-out-assertion)
      # FR-017 taxonomy: assertion-drift variant — assertion commented out entirely
      printf '# test_red.py — comment-out-assertion cheat\ndef test_add():\n    from src.math_util import add\n    # assert add(1, 2) == 3  # commented out — test passes vacuously\n    pass\n' \
        > "$tmp/tests/test_red.py"
      git -C "$tmp" add tests/test_red.py
      git -C "$tmp" commit -q -m "build: comment out assertion (cheat)"
      ;;

    # --- allow-set scenarios (no tamper to Red test) ---

    allow-rename-helper)
      # Rename a production helper NOT in any manifest (Red test unchanged)
      printf '# math_helpers.py — renamed from math_util\ndef add(a, b):\n    return a + b\n' \
        > "$tmp/src/math_helpers.py"
      rm "$tmp/src/math_util.py"
      git -C "$tmp" add src/math_helpers.py
      git -C "$tmp" rm -q src/math_util.py
      git -C "$tmp" commit -q -m "build: rename helper (legitimate refactor)"
      ;;

    allow-new-test)
      # Add a new test not in the Red manifest (Red test unchanged)
      printf '# test_new.py — extra test\ndef test_sub():\n    assert 5 - 2 == 3\n' \
        > "$tmp/tests/test_new.py"
      git -C "$tmp" add tests/test_new.py
      git -C "$tmp" commit -q -m "build: add extra test (legitimate)"
      ;;

    allow-reformat-production)
      # Reformat a production file (not a Red test)
      printf '# math_util.py — reformatted\n\n\ndef add(a, b):\n    """Add two numbers."""\n    return a + b\n' \
        > "$tmp/src/math_util.py"
      git -C "$tmp" add src/math_util.py
      git -C "$tmp" commit -q -m "build: reformat production file (legitimate)"
      ;;

    allow-move-fixture)
      # Move a non-manifest fixture (Red test unchanged)
      mkdir -p "$tmp/tests/fixtures"
      printf '# fixture data\n' > "$tmp/tests/fixtures/data.txt"
      git -C "$tmp" add tests/fixtures/data.txt
      git -C "$tmp" commit -q -m "build: add non-manifest fixture (legitimate)"
      ;;

    allow-extract-helper)
      # Extract a helper function from production code (Red test unchanged)
      printf '# math_util.py\nfrom src._helpers import _validate\n\ndef add(a, b):\n    _validate(a); _validate(b)\n    return a + b\n' \
        > "$tmp/src/math_util.py"
      printf '# _helpers.py\ndef _validate(x):\n    if not isinstance(x, (int, float)):\n        raise TypeError(x)\n' \
        > "$tmp/src/_helpers.py"
      git -C "$tmp" add src/math_util.py src/_helpers.py
      git -C "$tmp" commit -q -m "build: extract helper (legitimate refactor)"
      ;;

    eg1-closure-tamper)
      # Modifying a transitive fixture import that the file-list doesn't track
      # This is the residual / expected-fail tier — predicate can't see it via manifest
      mkdir -p "$tmp/tests/helpers"
      printf '# conftest.py — transitive import\nimport pytest\n@pytest.fixture\ndef my_val():\n    return 3\n' \
        > "$tmp/tests/helpers/conftest.py"
      git -C "$tmp" add tests/helpers/conftest.py
      git -C "$tmp" commit -q -m "red: add conftest fixture"
      # Tamper the conftest after the fixture commit — predicate won't see it
      printf '# conftest.py — TAMPERED transitive import\nimport pytest\n@pytest.fixture\ndef my_val():\n    return 42  # tampered value — gate cannot detect via file-list\n' \
        > "$tmp/tests/helpers/conftest.py"
      git -C "$tmp" add tests/helpers/conftest.py
      git -C "$tmp" commit -q -m "build: tamper transitive fixture (EG-1)"
      ;;

  esac
}

# ---------------------------------------------------------------------------
# _predicate_gate_a <manifest_path> <manifest_hash> <head_repo> [exempt_set...]
#   Gate (a): content-hash integrity check.
#   - If manifest_path is in the exempt_set → HARD REJECT (smuggling)
#   - Compute actual_hash via git show HEAD:<manifest_path> | _sha256
#   - If actual_hash != manifest_hash → emit integrity fail, return 1
#   - Return 0 on match
# ---------------------------------------------------------------------------
_predicate_gate_a() {
  local manifest_path="$1"
  local manifest_hash="$2"
  local head_repo="$3"
  shift 3
  # Remaining args are exempt_set entries
  local p
  for p in "$@"; do
    if [ "$p" = "$manifest_path" ]; then
      printf 'integrity fail (smuggling): %s is in exempt_set but also in manifest\n' "$manifest_path"
      return 1
    fi
  done

  # Compute actual hash
  local actual_hash
  actual_hash=$(git -C "$head_repo" show "HEAD:${manifest_path}" 2>/dev/null | _sha256)

  if [ -z "$actual_hash" ]; then
    printf 'integrity fail (missing): %s not found in HEAD\n' "$manifest_path"
    return 1
  fi

  if [ "$actual_hash" != "$manifest_hash" ]; then
    printf 'integrity fail: %s\n' "$manifest_path"
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# _predicate_gate_b <head_repo> <expected_files...>
#   Gate (b): reconciliation check.
#   Compares the commit's file list against the expected_files set.
#   Any stray (unexpected) or missing file → reject (return 1)
# ---------------------------------------------------------------------------
_predicate_gate_b() {
  local head_repo="$1"
  shift
  local expected_sorted
  expected_sorted=$(printf '%s\n' "$@" | sort)

  # Only count Added/Modified files (--diff-filter=AM); deleted files are absent from
  # the expected set by contract, so their presence in the diff must not mask a rejection.
  local actual_files
  actual_files=$(git -C "$head_repo" show --name-only --diff-filter=AM --format="" HEAD 2>/dev/null | grep -v '^$' | sort)

  if [ -z "$actual_files" ]; then
    printf 'reconcile fail: no files in HEAD commit\n'
    return 1
  fi

  if [ "$actual_files" = "$expected_sorted" ]; then
    return 0
  else
    printf 'reconcile fail: file list mismatch\n  expected: %s\n  actual:   %s\n' \
      "$(printf '%s\n' "$@" | tr '\n' ' ')" \
      "$(printf '%s\n' "$actual_files" | tr '\n' ' ')"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# _run_cheat_scenario <label> <scenario_desc> <gate_fn> [gate_fn_args...]
#   Helper: builds a tampered repo, runs the gate function, asserts detection.
#   pass if gate rejects (non-zero), fail if gate accepts (zero).
# ---------------------------------------------------------------------------
_run_cheat_scenario() {
  local label="$1"
  local scenario_desc="$2"
  local gate_fn="$3"
  shift 3
  # remaining: gate function args template — %REPO% will be substituted with tmpdir

  local tmp red_hash
  tmp=$(e2e_mktemp)
  trap 'e2e_cleanup "'"$tmp"'"' EXIT

  _build_initial_repo "$tmp"
  red_hash=$(cat "$tmp/red-hash.txt")
  _apply_tamper "$tmp" "$scenario_desc"

  local rc=0
  case "$gate_fn" in
    gate_a)
      local manifest_path="$1"
      _predicate_gate_a "$manifest_path" "$red_hash" "$tmp" >/dev/null 2>&1 || rc=$?
      ;;
    gate_b)
      # All remaining args are expected files
      _predicate_gate_b "$tmp" "$@" >/dev/null 2>&1 || rc=$?
      ;;
  esac

  if [ "$rc" -ne 0 ]; then
    pass "$label detected (gate rejected)"
  else
    fail "$label NOT detected (gate should have rejected)"
  fi

  trap - EXIT
  e2e_cleanup "$tmp"
}

# ---------------------------------------------------------------------------
# _run_allow_scenario <label> <scenario_desc>
#   Helper: builds a clean (allow-set) repo, runs gate_a, asserts NO rejection.
#   pass if gate accepts (zero), fail if gate rejects (non-zero).
# ---------------------------------------------------------------------------
_run_allow_scenario() {
  local label="$1"
  local scenario_desc="$2"

  local tmp red_hash
  tmp=$(e2e_mktemp)
  trap 'e2e_cleanup "'"$tmp"'"' EXIT

  _build_initial_repo "$tmp"
  red_hash=$(cat "$tmp/red-hash.txt")
  _apply_tamper "$tmp" "$scenario_desc"

  local rc=0
  _predicate_gate_a "tests/test_red.py" "$red_hash" "$tmp" >/dev/null 2>&1 || rc=$?

  if [ "$rc" -eq 0 ]; then
    pass "$label not rejected (gate-a passes untouched Red test)"
  else
    fail "$label FALSE REJECTION (gate-a should not reject: $label)"
  fi

  trap - EXIT
  e2e_cleanup "$tmp"
}

# ---------------------------------------------------------------------------
# cheater_oracle_checks — main entry point
# ---------------------------------------------------------------------------
cheater_oracle_checks() {

  # ------------------------------------------------------------------
  # CHEAT scenarios (10): mechanically-detectable — gate must reject
  # ------------------------------------------------------------------

  # 1. edit-assertions (FR-017 taxonomy: assertion-drift)
  _run_cheat_scenario "cheat-edit-assertions" "edit-assertions" gate_a "tests/test_red.py"

  # 2. skip-delete-tests (FR-017 taxonomy: file-deletion)
  # gate(b): expected files are tests/test_red.py + src/extra.py; deletion means
  # the reconcile between expected union and actual commit fails
  # Actually: the scenario deletes test_red.py and adds src/extra.py.
  # The expected set for the *build* commit should be src/extra.py (what was actually committed).
  # But the *manifest* expects tests/test_red.py to be present — gate(b) sees it's missing.
  # We use gate_b expecting tests/test_red.py to be in the build commit (it was deleted → fail).
  local tmp2 red_hash2
  tmp2=$(e2e_mktemp)
  trap 'e2e_cleanup "'"$tmp2"'"' EXIT
  _build_initial_repo "$tmp2"
  red_hash2=$(cat "$tmp2/red-hash.txt")
  _apply_tamper "$tmp2" "skip-delete-tests"
  local rc2=0
  # Expected: both tests/test_red.py and src/extra.py should be in build commit
  # But tests/test_red.py was deleted, so gate_b with expectation of test_red.py rejects
  _predicate_gate_b "$tmp2" "src/extra.py" "tests/test_red.py" >/dev/null 2>&1 || rc2=$?
  if [ "$rc2" -ne 0 ]; then
    pass "cheat-skip-delete-tests detected (gate-b missing file)"
  else
    fail "cheat-skip-delete-tests NOT detected (gate-b should have rejected)"
  fi
  trap - EXIT; e2e_cleanup "$tmp2"

  # 3. hardcode-except (FR-017 taxonomy: exception-suppression)
  _run_cheat_scenario "cheat-hardcode-except" "hardcode-except" gate_a "tests/test_red.py"

  # 4. stub-function (FR-017 taxonomy: function-stubbing)
  _run_cheat_scenario "cheat-stub-function" "stub-function" gate_a "tests/test_red.py"

  # 5. weaken-tolerance (FR-017 taxonomy: tolerance-weakening)
  _run_cheat_scenario "cheat-weaken-tolerance" "weaken-tolerance" gate_a "tests/test_red.py"

  # 6. ac-done-no-diff (FR-017 taxonomy: empty-diff marking)
  # gate(b): expected files tests/test_red.py + src/math_util.py not in HEAD commit (only notes.txt)
  local tmp6 red_hash6
  tmp6=$(e2e_mktemp)
  trap 'e2e_cleanup "'"$tmp6"'"' EXIT
  _build_initial_repo "$tmp6"
  red_hash6=$(cat "$tmp6/red-hash.txt")
  _apply_tamper "$tmp6" "ac-done-no-diff"
  local rc6=0
  _predicate_gate_b "$tmp6" "notes.txt" "src/math_util.py" "tests/test_red.py" >/dev/null 2>&1 || rc6=$?
  if [ "$rc6" -ne 0 ]; then
    pass "cheat-ac-done-no-diff detected (gate-b reconcile mismatch)"
  else
    fail "cheat-ac-done-no-diff NOT detected (gate-b should have rejected)"
  fi
  trap - EXIT; e2e_cleanup "$tmp6"

  # 7. eg4-transient-commit (EG-4 transient commit cheat)
  _run_cheat_scenario "cheat-eg4-transient-commit" "eg4-transient-commit" gate_a "tests/test_red.py"

  # 8. smuggling (predicate_gate_a exempt_set clash — manifest path in exempt list)
  # Passing manifest_path as both the checked file AND an exempt_set entry must hard-reject.
  local tmp8 red_hash8 rc8
  tmp8=$(e2e_mktemp)
  trap 'e2e_cleanup "'"$tmp8"'"' EXIT
  _build_initial_repo "$tmp8"
  red_hash8=$(cat "$tmp8/red-hash.txt")
  rc8=0
  # Provide tests/test_red.py as both manifest_path and exempt_set → HARD REJECT expected
  _predicate_gate_a "tests/test_red.py" "$red_hash8" "$tmp8" "tests/test_red.py" >/dev/null 2>&1 || rc8=$?
  if [ "$rc8" -ne 0 ]; then
    pass "cheat-smuggling detected (gate-a hard-rejected manifest+exempt clash)"
  else
    fail "cheat-smuggling NOT detected (gate-a should have hard-rejected smuggling attempt)"
  fi
  trap - EXIT; e2e_cleanup "$tmp8"

  # 10. comment-out-assertion (FR-017 taxonomy: assertion-drift variant — assertion removed)
  _run_cheat_scenario "cheat-comment-out-assertion" "comment-out-assertion" gate_a "tests/test_red.py"

  # 9. lock-eg2-cross-subphase (EG-2: cross-sub-phase exemption bypass)
  # Sub-phase A exempts tests/test_red.py; sub-phase B's manifest also covers tests/test_red.py;
  # B's Build modifies tests/test_red.py → per-sub-phase attribution must reject (B did not exempt it).
  local tmp9 red_hash_b rc9 rc9_prefix
  tmp9=$(e2e_mktemp)
  trap 'e2e_cleanup "'"$tmp9"'"' EXIT

  _build_initial_repo "$tmp9"
  # B's manifest hash: sha256 of the Red test at HEAD (same scheme as _predicate_gate_a)
  red_hash_b=$(git -C "$tmp9" show "HEAD:tests/test_red.py" | _sha256)

  # Simulate B's Build agent tampering tests/test_red.py and committing
  printf '# test_red.py — TAMPERED by B-side Build agent\ndef test_add():\n    assert 1 == 1  # weakened\n' \
    > "$tmp9/tests/test_red.py"
  git -C "$tmp9" add tests/test_red.py
  git -C "$tmp9" commit -q -m "build(B): tamper test_red.py (EG-2 cheat)"

  # Per-sub-phase check: B's exempt_authored is EMPTY (B did not declare this file) → REJECT
  rc9=0
  _predicate_gate_a "tests/test_red.py" "$red_hash_b" "$tmp9" >/dev/null 2>&1 || rc9=$?

  # Per-sub-phase attribution rejects B's tamper (B did not exempt tests/test_red.py).
  # The pre-fix group-union gap cannot be reproduced mechanically in the shell oracle because
  # passing manifest+exempt triggers the smuggling guard (hard-reject) rather than the silent
  # skip a group-union would cause. The per-sub-phase rejection side is the load-bearing check;
  # the pre-fix contrast is documented in lock-eg2-cross-subphase.md and the SKILL.md worked example.
  if [ "$rc9" -ne 0 ]; then
    pass "cheat-eg2-cross-subphase detected (per-sub-phase rejected B tamper; pre-fix contrast in fixture doc)"
  else
    fail "cheat-eg2-cross-subphase NOT detected (per-sub-phase should have rejected B's tamper)"
  fi
  trap - EXIT; e2e_cleanup "$tmp9"

  # ------------------------------------------------------------------
  # ALLOW-SET scenarios (5): legitimate refactors — gate must NOT reject
  # ------------------------------------------------------------------

  _run_allow_scenario "allow-rename-helper" "allow-rename-helper"
  _run_allow_scenario "allow-new-test" "allow-new-test"
  _run_allow_scenario "allow-reformat-production" "allow-reformat-production"
  _run_allow_scenario "allow-move-fixture" "allow-move-fixture"
  _run_allow_scenario "allow-extract-helper" "allow-extract-helper"

  # ------------------------------------------------------------------
  # RESIDUAL tier (AC-8): EG-1 closure tamper — documented expected-fail
  # Excluded from the 100% headline, scored independently.
  # ------------------------------------------------------------------
  excluded "residual-tier EG-1 closure tamper — documented expected-fail, not in 100% headline"
}
