---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: pipeline-e2e — Pipeline end-to-end smoke test

**Spec:** docs/prds/exec-ready/specs/pipeline-e2e/spec.md (approved)
**PRD Sections:** FR-013, G-1
**Status:** final-review-pending

## Overview

Build the three-layer bash e2e harness under `plugins/spec-flow/tests/e2e/`: L1 static contract checks on skill prose, L2 fixture-replay + audit mode, L3 live-verification substrate (synthetic fixtures + operator-driven live procedure), golden snapshot, capability-gated SKIPPED semantics, charter sanctioning edits, and the 5.10.0 release (master moved to 5.9.0 via the manifest-ops change on 2026-06-09; merged into this branch 2026-06-10).

**Non-TDD mode:** all phases use Implement track + Write-Tests; the TDD-mode AC Coverage Matrix workflow is not required (the `## AC Coverage Matrix` section below is still generated per the plan contract); QA and Final Review remain intact.

**Architecture summary (from spec):** one runner (`run-e2e.sh`) sources `lib/*.sh` modules; every check reports exactly one of `PASS` / `FAIL` / `SKIPPED: <capability>` / `ERROR`; summary line `== summary: N passed, M failed, S skipped, E errors ==`; exit 0 iff failures==0 && errors==0. Capabilities: `live-run`, `transcript`, `metrics-artifact`. The harness invokes no model anywhere (spec SN-2).

## Architectural Decisions

### ADR-1: Runner pre-wires all modes; modules register by file presence
**Context:** Seven phases would otherwise each edit `run-e2e.sh` (mode dispatch), creating a serial coordination-file bottleneck and merge churn.
**Decision:** Phase 1 writes the complete CLI parser and mode dispatch once. Each mode handler is a function defined in a `lib/<module>.sh` file; the runner sources every `lib/*.sh` present and, before calling a handler, guards with `declare -f <fn> >/dev/null || err "module missing: <fn>"`. Later phases ONLY add new `lib/*.sh` / fixture files — no runner edits.
**Alternatives considered:** (a) per-phase runner edits — rejected: contention on one file across 5 phases; (b) Phase 0 scaffold with stub functions — rejected: the guard idiom achieves the same with zero stub files.
**Consequences:** `run-e2e.sh` is final after Phase 1; a missing module surfaces as `ERROR` (never silent PASS), which also satisfies SF-7's never-false-green posture during partial builds.
**Charter alignment:** NN-C-002 (pure bash), CR-008 analogue (runner orchestrates, modules execute).

### ADR-2: L2 ordering evidence = relative first-occurrence order of commit subjects
**Context:** Real pipeline runs interleave fix-up/amend commits; exact-sequence matching would be brittle.
**Decision:** Ordering checks assert relative order of FIRST occurrences of anchored subject prefixes in `git log --reverse --format=%s` output (e.g., `research: ` before `spec: add`), not an exact full sequence.
**Alternatives considered:** (a) exact sequence match — rejected: any benign extra commit breaks it; (b) timestamp comparison — rejected: same-second commits are common in scripted replay.
**Consequences:** Robust to interleaved commits; a swapped pair is still always caught.
**Charter alignment:** spec SF-3(a); CR-004 (subjects are the stable grammar).

### ADR-3: verify-live degrades by target type — git repo → full checks; plain dir → shape + round-trip only
**Context:** The committed synthetic post-run fixture (`fixtures/post-run/clean|broken/`) is a plain directory (no `.git` can be committed), but SF-3(a)/(b) need git history.
**Decision:** `--verify-live <target>`: if `<target>/.git` exists run SF-3 (a)–(g) + round-trip + transcript checks; else run (c)–(g) + round-trip + transcript checks and print one `EXCLUDED — ordering checks (a)-(b): target has no git history` line (same EXCLUDED line class as audit mode; not SKIPPED, not PASS, not counted).
**Alternatives considered:** (a) builder-materialized git repo for post-run fixtures — rejected: duplicates the L2 replay repo, which already exercises (a)/(b) deterministically; (b) report SKIPPED — rejected: SKIPPED is reserved for the three declared capabilities (SF-7).
**Consequences:** AC-7's deterministic half exercises every tree/round-trip assertion with zero duplication; ordering code is covered by L2.
**Charter alignment:** spec SF-5 deterministic substrate; SF-7 result vocabulary.

### ADR-4: Golden re-assert = contract re-validation + cksum integrity, not tree re-derivation
**Context:** The live run's temp repo is gone after recording; a golden snapshot cannot be re-derived from a tree on later runs.
**Decision:** `golden/footprint.txt` records ordered commit subjects, ordered dispatch sequence, and the piece-relative file inventory from a verified live run, plus a trailing `## cksum` of the body (POSIX `cksum`). Default runs re-validate: (1) cksum matches (any mutation → FAIL), (2) the recorded subject list still satisfies the SF-3 relative-order rules, (3) the recorded dispatch sequence still matches the current expected sequence, (4) the recorded file inventory still contains every contract-required artifact name. A contract change (e.g., a new required dispatch) fails a stale golden → operator re-records after a fresh live run.
**Alternatives considered:** (a) re-hash live tree — impossible, tree is temporary; (b) store golden as opaque blob, assert existence only — rejected: that is a false green on contract drift.
**Consequences:** One operator live run keeps paying dividends; golden failure semantics are meaningful (contract drift or tampering), and `cksum` keeps SN-1 (no shasum dependency assumptions — `cksum` is POSIX).
**Charter alignment:** spec SF-6; SN-1.

### ADR-5: Dispatch evidence grep handles target `"subagent_type"` with flexible whitespace
**Context:** Real transcripts serialize `"subagent_type": "spec-flow:tdd-red"` (spacing may vary); synthetic fixtures are hand-authored.
**Decision:** All transcript greps use `grep -E '"subagent_type"[[:space:]]*:[[:space:]]*"spec-flow:<agent>"'`; dispatch ordering compares first-occurrence line numbers; the Implement-phase negative is asserted as an exact COUNT of tdd-red dispatches (3 — the live plan's three test-authoring phases), not per-phase attribution (which transcripts don't encode).
**Alternatives considered:** (a) jq parsing — rejected: jq is banned by SN-1; (b) per-phase attribution via description fields — rejected: description text is not a stable contract.
**Consequences:** The same grep works on synthetic and real transcripts; schema drift degrades to `SKIPPED: transcript` per SN-3 (resolution failure), never FAIL.
**Charter alignment:** SN-1, SN-3; spec AC-8.

### ADR-6: Fixture piece is `demo/hello` — distilled, not copied
**Context:** Fixture content must be realistic (real merged pieces are the reference) but small and repo-agnostic (the plugin ships to other installs).
**Decision:** All fixtures use PRD slug `demo`, piece slug `hello`. spec/plan/spike/learnings/discovery-log shapes are distilled from `docs/prds/exec-ready/specs/flywheel-repo/` (real example read at introspection) at minimal size; the fixture project's production code is a one-function bash script. The spike round-trip oracle value is the literal string `resolved-42`, planted once in the spike artifact and asserted in plan block + test file.
**Alternatives considered:** (a) verbatim flywheel-repo copy — rejected at brainstorm (120KB repo-specific prose, drift-prone); (b) assert against real repo history — rejected at brainstorm (squash destroys ordering; not portable).
**Consequences:** Fixtures are PR-reviewable, contract-evolution edits are one-file diffs, and no exec-ready prose ships inside the plugin.
**Charter alignment:** spec Technical Approach (fixture provenance); NN-C-002.

## Integration-Test Registry (M1)

| # | Integration (boundary) | Doubled externals | AC | completes_in_phase |
|---|---|---|---|---|
| 1 | harness→git: builder replays history, assertion core reads it back via real git | none (real git every run) | AC-3, AC-4 | 4 |
| 2 | harness→session-transcript: verify-live grep path over `.jsonl` | committed sample transcripts (`fixtures/transcript/clean.jsonl` + `broken.jsonl`); absence path → `SKIPPED: transcript` | AC-8 | 5 |
| 3 | pipeline→fixture: real `/spec-flow:execute` writes the live fixture tree | operator-driven, outside harness boundary (spec SN-2); asserted post-hoc by the same core | AC-7 (live half) | — (operator procedure, documented in Phase 7 README; no in-plan completing phase) |

## Phases

### Phase 1: Core runner + assertion/capability library
Why serial: every later phase sources `lib/assert.sh` symbols (counters, asserters, probes) and registers into the runner written here; Phases 3→4→5→6 additionally consume each other's artifacts (builder → assertion core → post-run fixtures → golden). Shared-symbol dependency chains make sub-phase parallelism not genuinely disjoint.
**Exit Gate:** `bash plugins/spec-flow/tests/e2e/self/test-core.sh` prints `== summary: 6 passed, 0 failed, 0 skipped, 0 errors ==` and exits 0; `run-e2e.sh` with no modules present reports `ERROR` lines (never PASS) for unimplemented modes.
**ACs Covered:** AC-11
**In scope:** CREATE `plugins/spec-flow/tests/e2e/run-e2e.sh`, `lib/assert.sh`, `self/test-core.sh`. Result vocabulary, counters, summary, exit-code logic, capability probes, temp-dir helper, CLI parsing for ALL modes (ADR-1).
**NOT in scope:** any check logic (L1 — Phase 2; L2 — Phases 3-4; live — Phase 5; golden — Phase 6); README (Phase 7).
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): `lib/assert.sh` + runner use only bash 4+, git, grep/sed/awk/mktemp/cksum (all POSIX userland); no jq/python/node anywhere in the tree this phase creates.

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE plugins/spec-flow/tests/e2e/lib/assert.sh**
    - Structure (sourced library, no shebang execution path; header comment `# spec-flow e2e assertion core — sourced by run-e2e.sh`):
      ```bash
      PASSES=0; FAILS=0; SKIPS=0; ERRORS=0
      pass() { printf 'PASS — %s\n' "$1"; PASSES=$((PASSES + 1)); }
      fail() { printf 'FAIL — %s\n' "$1"; FAILS=$((FAILS + 1)); }
      skip_cap() { printf 'SKIPPED: %s — %s\n' "$1" "$2"; SKIPS=$((SKIPS + 1)); }   # $1 ∈ live-run|transcript|metrics-artifact
      err() { printf 'ERROR — %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }
      excluded() { printf 'EXCLUDED — %s\n' "$1"; }                                  # informational, not counted
      summary() {
        printf '== summary: %s passed, %s failed, %s skipped, %s errors ==\n' "$PASSES" "$FAILS" "$SKIPS" "$ERRORS"
        [ "$FAILS" -eq 0 ] && [ "$ERRORS" -eq 0 ] && return 0; return 1
      }
      ```
    - Asserters (same `<want> <label> -- <cmd...>` convention as the linter test — pattern below):
      `assert_exit <want> <label> -- <cmd...>`; `assert_grep <pattern> <file> <label>` (ERE, `grep -E -q`); `assert_no_grep <pattern> <file> <label>`; `assert_file <path> <label>` (exists + non-empty → pass); `assert_count <pattern> <file> <want> <label>` (`grep -E -c` equals want).
    - Ordering asserter: `assert_subject_order <repo> <prefixA> <prefixB> <label>` — `git -C "$repo" log --reverse --format=%s`, find first line number matching each anchored prefix (`^prefix`); pass iff both found AND lineA < lineB; fail naming the missing/misordered prefix (ADR-2).
    - Capability probes (single flip point per spec Technical Approach):
      ```bash
      have_golden() { [ -s "$E2E_DIR/golden/footprint.txt" ]; }
      have_transcript() { [ -n "${TRANSCRIPT:-}" ] && [ -s "$TRANSCRIPT" ]; }
      have_metrics_artifact() { [ -s "$1/metrics.yaml" ]; }   # $1 = piece dir; flips real when FR-010 ships its path
      ```
    - Temp helper (NN-C-006 confinement — all `rm -rf` in the suite goes through this pair):
      ```bash
      e2e_mktemp() { mktemp -d 2>/dev/null || { d="/tmp/e2e-$$-$RANDOM"; mkdir -p "$d"; echo "$d"; }; }
      e2e_cleanup() { case "$1" in /tmp/*|/private/*|/var/folders/*) rm -rf "$1" ;; *) err "refusing cleanup outside tmp: $1" ;; esac; }
      ```
    - Pattern (from `hooks/tests/test-lint-skill-coherence.sh`, introspection Cluster 1):
      ```bash
      assert_exit() {            # assert_exit <want> <label> -- <command...>
        local want="$1" label="$2"; shift 3
        "$@" >/dev/null 2>&1; local got=$?
        if [ "$got" -eq "$want" ]; then pass "${label} (exit ${got})"; else fail "${label} (want ${want}, got ${got})"; fi
      }
      ```
    - Done: file defines exactly the functions above; no top-level side effects besides counter init.
    - Verify: `bash -n plugins/spec-flow/tests/e2e/lib/assert.sh` exits 0; `grep -c '^[a-z_]*()' lib/assert.sh` ≥ 12.

    **T-2: CREATE plugins/spec-flow/tests/e2e/run-e2e.sh**
    - Structure (executable, `#!/usr/bin/env bash`, `set -uo pipefail`):
      ```bash
      SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; E2E_DIR="$SCRIPT_DIR"
      PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"          # plugins/spec-flow
      REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
      . "$SCRIPT_DIR/lib/assert.sh"
      for f in "$SCRIPT_DIR"/lib/*.sh; do [ "$f" = "$SCRIPT_DIR/lib/assert.sh" ] || . "$f"; done
      run_mode() { declare -f "$1" >/dev/null 2>&1 && "$1" "${@:2}" || err "module missing: $1"; }
      ```
    - CLI contract (C-1): no args → default mode; `--audit <piece-dir>`; `--verify-live <target> [--transcript <jsonl>]`; `--record-golden <target> <transcript>`; `--break <case>` (delegates to builder, for manual use); `--help`. Unknown flag → usage to stderr, exit 2.
    - Default mode body (calls in this order, each via `run_mode`): `l1_static_checks` → `l2_replay_checks` (clean build + assertions + break-variant self-test loop) → `verify_live_selftest` (synthetic post-run + transcript fixtures) → `golden_validate` (or `skip_cap live-run "no golden recorded"` when `! have_golden`) → `metrics_check` → `summary`; exit with summary's return.
    - Done: parser handles all six invocations; default mode emits 4 `ERROR — module missing:` lines + summary exiting 1 while modules are absent (proves ADR-1 guard).
    - Verify: `bash plugins/spec-flow/tests/e2e/run-e2e.sh; echo $?` → prints 4 `ERROR — module missing:` lines (l1_static_checks, l2_replay_checks, verify_live_selftest, metrics_check), summary with `4 errors`, exit code 1. `run-e2e.sh --help; echo $?` → usage text, exit 0.

- [x] **[Write-Tests]** `self/test-core.sh` — outcome-class self-test (AC-11)
    - CREATE `plugins/spec-flow/tests/e2e/self/test-core.sh`: sources `lib/assert.sh` in subshells (`bash -c`) to drive each outcome class and asserts the emitted summary line + exit code with its own minimal inline pass/fail counters (it cannot use the library under test for its own verdicts — use plain `[ ... ] && echo PASS... || echo FAIL...` with a local counter, then its own summary).
    - Cases reference the Test Data block below by id.

    **Test Data:**
    - sum-1: input subshell running `pass a; pass b; fail c; skip_cap live-run d; summary` → expect stdout contains `== summary: 2 passed, 1 failed, 1 skipped, 0 errors ==` and subshell exit 1
    - sum-2: input subshell running `pass a; summary` → expect `== summary: 1 passed, 0 failed, 0 skipped, 0 errors ==`, exit 0
    - sum-3: input subshell running `pass a; err boom; summary` → expect `== summary: 1 passed, 0 failed, 0 skipped, 1 errors ==`, exit 1 (errors block green)
    - sum-4: input subshell running `skip_cap metrics-artifact x; summary` → expect line `SKIPPED: metrics-artifact — x` present AND no line beginning `PASS — x` (skipped never rendered PASS), exit 0
    - ord-1: input temp git repo with commits subjects `research: r` then `spec: add s`; `assert_subject_order <repo> 'research: ' 'spec: add' lbl` → expect `PASS — lbl`
    - ord-2: input same repo, reversed args `assert_subject_order <repo> 'spec: add' 'research: ' lbl` → expect `FAIL — lbl` naming misorder

- [x] **[Verify]** Confirm the implementation is sound
    **Per-change checks:**
    - T-1: `bash -n lib/assert.sh` — Expected: exit 0
    - T-2: `bash run-e2e.sh --help` — Expected: usage text, exit 0
    **Phase-level check:**
    - Run: `bash plugins/spec-flow/tests/e2e/self/test-core.sh`
    - Expected: `== summary: 6 passed, 0 failed, 0 skipped, 0 errors ==` (the self-test's own counter line), exit 0
    - Failure: any `FAIL` line, or exit ≠ 0

- [x] **[QA]** Phase review — Review against: AC-11. Diff baseline: phase start SHA.

### Phase 2: L1 static contract checks
**Exit Gate:** `run-e2e.sh` default mode's L1 section reports 13 PASS lines against the unmodified plugin tree; a temp copy of execute/SKILL.md with the QA-TDD-Red section deleted produces `FAIL` naming `qa-tdd-red`.
**ACs Covered:** AC-1, AC-2
**In scope:** CREATE `lib/static.sh` defining `l1_static_checks [skill-file]` (default `$PLUGIN_ROOT/skills/execute/SKILL.md`).
**NOT in scope:** runner changes (none — ADR-1); replay/live checks (Phases 3-6).
**Charter constraints honored in this phase:** none allocated (NN-C-002 held by Phase 1 covers the whole tree's tooling).

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE plugins/spec-flow/tests/e2e/lib/static.sh**
    - Defines `l1_static_checks()`; optional `$1` = skill file path (the AC-2 break-copy hook), default `$PLUGIN_ROOT/skills/execute/SKILL.md`.
    - Ordered dispatch-sequence tokens (fixed strings; current line anchors from introspection Cluster 6 — locator only, the check greps, never hardcodes line numbers):
      ```bash
      L1_SEQUENCE=(
        '### Step 2: TDD-Red'        # 455
        '### Step 2.5: QA-TDD-Red'   # 506
        '### Step 3: Implement'      # 531
        '### Step 4: Verify'         # 718
        '### Step 6: Phase QA'       # 841
        '## Final Review'            # 1590
      )
      ```
      Implementation: tokens MUST match at line start only (heading occurrences) — prose references to step names exist mid-file (verified 2026-06-10: `### Step 6: Phase QA` is quoted inside Step 0a's prose at line 326, far above the real heading at 841; a non-anchored `grep -F -m1` collects the wrong line and false-fails the ordering on the REAL tree). Tokens contain regex specials (`[`), so use literal line-start prefix matching, not regex: `awk -v t="$tok" 'index($0, t) == 1 { print NR; exit }' "$skill"` → empty output → `fail "L1 sequence token missing: $tok"`; collect line numbers; each adjacent pair must be strictly increasing else `fail "L1 sequence misordered: $tokA(>$tokB)"`; all present+ordered → one `pass` per token (6 PASS).
    - Artifact-contract anchors (presence set, 7 checks, one pass/fail each). The three `### Step` heading anchors use the same line-start awk idiom as the sequence tokens; the four prose tokens use `grep -F -q` (anywhere in file):
      headings: `### Step 1c: [SPIKE]-phase resolution` · `### Step 6c: Discovery Triage` · `### Step G9b: Barrier work-commit` — prose: `manifest: mark <prd-slug>/<piece-slug> as in-progress` · `learnings.md` · `.discovery-log.md` · `unified commit`
    - Failure naming rule (AC-2): the FAIL label must contain the literal token text — `qa-tdd-red`'s token is `### Step 2.5: QA-TDD-Red`, so deleting that section yields `FAIL — L1 sequence token missing: ### Step 2.5: QA-TDD-Red`.
    - Pattern: asserter conventions from `lib/assert.sh` (Phase 1 T-1).
    - Done: 13 checks total (6 sequence + 7 anchors); function is pure-read (no writes).
    - Verify: `bash -n lib/static.sh` exit 0; `bash run-e2e.sh 2>/dev/null | grep -c '^PASS — L1'` → 13.

- [x] **[Write-Tests]** Break-copy self-test appended to `self/test-core.sh` (new section `# --- L1 ---`)
    - Drives l1 against a sed-built broken copy in a temp dir (uses `e2e_mktemp`/`e2e_cleanup`).

    **Test Data:**
    - l1-1: input unmodified `plugins/spec-flow/skills/execute/SKILL.md` → expect `l1_static_checks` emits 13 `PASS — L1` lines, 0 FAIL
    - l1-2: input temp copy built by `sed '/^### Step 2.5: QA-TDD-Red/,/^### Step 3: Implement/{/^### Step 3: Implement/!d;}' SKILL.md` (deletes the QA-TDD-Red section, keeps Step 3 heading) → expect exactly one `FAIL — L1 sequence token missing: ### Step 2.5: QA-TDD-Red`, subshell summary exit 1
    - l1-3: input temp copy with `## Final Review` heading moved above `### Step 2: TDD-Red` (sed swap) → expect `FAIL` containing `misordered`

- [x] **[Verify]** Confirm the implementation is sound
    **Phase-level check:**
    - Run: `bash plugins/spec-flow/tests/e2e/self/test-core.sh`
    - Expected: `== summary: 9 passed, 0 failed, 0 skipped, 0 errors ==` (6 core + 3 L1 cases), exit 0
    - Failure: any FAIL line; or l1-2 not naming the QA-TDD-Red token
    **AC-1 timing pre-check:**
    - Run: `time bash run-e2e.sh` — Expected: L1 section completes; total wall time < 5s at this phase (budget headroom for <60s at Phase 7); remaining modules still ERROR (expected until Phases 3-6)

- [x] **[QA]** Phase review — Review against: AC-1, AC-2. Diff baseline: phase start SHA.

### Phase 3: Replay fixture content + builder
**Exit Gate:** `bash build-fixture.sh "$(e2e_mktemp)"` builds a clean `demo/hello` repo with 12 commits in contract order; each of the 6 `--break=<case>` variants builds without error and differs from clean exactly as specified.
**ACs Covered:** — (substrate for AC-3/AC-4; asserted in Phase 4)
**In scope:** CREATE `fixtures/replay/` content files + `build-fixture.sh`.
**NOT in scope:** assertion functions (Phase 4); live fixtures (Phase 5).
**Charter constraints honored in this phase:**
- NN-C-006 (no destructive ops): all temp repos come from `e2e_mktemp`; cleanup only via `e2e_cleanup` (tmp-path-guarded `rm -rf`); the builder never writes outside its target argument.
- CR-004 (conventional commits): the builder reproduces the pipeline's documented commit-subject grammar verbatim (list below) — the fixture's subjects ARE the assertion targets.

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE fixtures/replay/ content set (8 files, all under plugins/spec-flow/tests/e2e/fixtures/replay/)**
    - `research.md` — 10-line distillate: `# research.md — demo/hello` + two fixed headings per the research contract.
    - `spec.md` — ~20 lines: Goal, 2 FRs, 3 ACs (AC-1 greet behavior, AC-2 config glue, AC-3 spike-resolved value).
    - `plan-clean.md` — ~45 lines, front-matter `tdd: true`, two phases:
      Phase 1 (TDD) carries the spike reference + routed-resolution annotation exactly as this fenced fragment (fixture content, not a live marker):
      ```
      [SPIKE: greet suffix value]
      routed-resolution: resolved at execute by spike-agent
      ```
      plus a `- [ ] **[TDD-Red]**` step whose **Test Data:** block is:
      ```
      **Test Data:**
      - rt-1: input "spike" → expect "resolved-42"
      - g-1: input "world" → expect "hello, world"
      ```
      Phase 2 (Implement): `- [ ] **[Implement]**` step (config glue, no test step → no Test Data required).
    - `plan-no-test-data.md` — identical except the `**Test Data:**` block and its two case lines are deleted (the `--break=no-test-data` payload).
    - `spike-phase-1.md` — conforms to spike schema (introspection Cluster 6): `**Mode:** resolve` / `**Trigger:** greet suffix value unknown` / `**Resolution:** suffix is resolved-42` / `**Test Data:**` block repeating case rt-1 verbatim.
    - `discovery-log.md` — header row + one data row, format copied from the real example:
      ```
      | Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |
      |---|---|---|---|---|---|
      | phase_2 | requires-amendment | qa-phase | config key rename | amend | chore(plan): amend — phase_2 key rename |
      ```
    - `learnings.md` — 6-line distillate with `# Learnings — demo/hello` H1 + one `## Patterns that worked well` section.
    - `manifest.yaml` — single piece `hello`, `status: open` (builder sed-bumps the status per stage).
    - Done: all 8 files exist; `plan-clean.md` contains exactly one `**Test Data:**` block with cases rt-1 and g-1; `spike-phase-1.md` contains `resolved-42`.
    - Verify: `grep -c 'resolved-42' fixtures/replay/spike-phase-1.md fixtures/replay/plan-clean.md` → 1 match in each.

    **T-2: CREATE plugins/spec-flow/tests/e2e/build-fixture.sh**
    - Executable; usage: `build-fixture.sh <target-dir> [--break=<case>]`; sources `lib/assert.sh` for `e2e_mktemp` only when target omitted.
    - Builds: `git init -q <target>`; `git -C` config user demo@example.com/demo; piece dir `docs/prds/demo/specs/hello/`; then the canonical 12-commit sequence (each `git add <literal paths>` + `git commit -m "<subject>"`):
      ```
       1. research.md                       research: add demo/hello codebase research
       2. manifest.yaml (status: specced)   manifest: mark demo/hello as specced
       3. spec.md                           spec: add demo/hello specification
       4. manifest.yaml (status: planned)   manifest: mark demo/hello as planned
       5. plan.md (from plan-clean.md)      plan: add demo/hello implementation plan
       6. manifest.yaml (status: in-progress) manifest: mark demo/hello as in-progress
       7. spikes/phase-1.md                 chore(spike): phase-1 resolution
       8. tests/test-greet.sh + src/greet.sh   feat(demo): phase 1 — greet (tests + implementation)
       9. src/config.txt                    feat(demo): phase 2 — config wiring
      10. .discovery-log.md (piece dir)     chore(demo): discovery log — phase 2 triage
      11. learnings.md                      learnings: demo/hello
      12. manifest.yaml (status: merged)    manifest: mark demo/hello as merged
      ```
      `tests/test-greet.sh` content embeds BOTH oracle values: a line `expect "resolved-42"` and a line `expect "hello, world"` (the round-trip assertion targets); `src/greet.sh` is `greet() { printf 'hello, %s\n' "$1"; }` + suffix function returning `resolved-42`.
    - `--break=<case>` variants (exactly these 6 ids — C-4 contract; each changes ONE thing):
      ```
      research-after-spec   commits 1 and 3 swapped (research lands after spec)
      no-test-data          step 5 uses plan-no-test-data.md instead of plan-clean.md
      no-spike-artifact     step 7 skipped entirely
      skip-transition       step 4 skipped (planned transition never fires)
      journal-survives      after step 12, write .phase-group-journal.json ('{"group_letter":"A"}') at repo root, uncommitted
      missing-learnings     step 11 skipped
      ```
    - Pattern: temp + cleanup idiom from introspection Cluster 5 Pattern Catalog.
    - Done: clean build → `git -C <t> log --oneline | wc -l` = 12; each break variant builds exit 0.
    - Verify: `bash build-fixture.sh /tmp/e2e-smoke-$$ && git -C /tmp/e2e-smoke-$$ log --reverse --format=%s | head -1` — Expected: `research: add demo/hello codebase research`; then `rm -rf /tmp/e2e-smoke-$$` (tmp-guarded).

- [x] **[Verify]** Confirm the implementation is sound
    **Phase-level check (LLM-agent-step + shell):**
    - Run: `for c in research-after-spec no-test-data no-spike-artifact skip-transition journal-survives missing-learnings; do d=$(mktemp -d); bash build-fixture.sh "$d" --break=$c || echo "BUILD-FAIL $c"; rm -rf "$d"; done`
    - Expected: no `BUILD-FAIL` lines (all 6 variants build cleanly; their assertions fail only in Phase 4's loop)
    - Failure: any `BUILD-FAIL <case>` line
    - LLM-agent-step: read `fixtures/replay/plan-clean.md` and confirm Phase 1 contains the `**Test Data:**` block with cases `rt-1` and `g-1`, and `plan-no-test-data.md` contains neither.

- [x] **[QA]** Phase review — Review against: spec SF-2 (builder contract). Diff baseline: phase start SHA.

### Phase 4: L2 assertion core + audit mode + break-variant self-test
**Exit Gate:** default `run-e2e.sh` runs clean-fixture assertions (all PASS) + all 6 break variants (each FAILs exactly its targeted check, asserted via expected-fail wrappers reported as PASS) + `--audit docs/prds/exec-ready/specs/flywheel-repo` passes shape checks with the ordering EXCLUDED note.
**ACs Covered:** AC-3, AC-4, AC-5
**In scope:** CREATE `lib/contract.sh`: SF-3 check functions (a)–(g), `l2_replay_checks` (build + assert + break loop), `audit_checks <piece-dir>`.
**NOT in scope:** live/transcript checks (Phase 5); golden (Phase 6).
**Charter constraints honored in this phase:** none newly allocated (temp/cleanup discipline inherited via Phase 3's `e2e_mktemp`/`e2e_cleanup` allocation).

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE plugins/spec-flow/tests/e2e/lib/contract.sh**
    - Check functions, each taking explicit targets (target-parameterized per SF-3; `$repo` = repo root, `$piece` = piece dir relative or absolute):
      ```bash
      check_commit_order <repo>      # (a) assert_subject_order pairs: 'research: '<'spec: add';
                                     #     'spec: add'<'plan: add'; 'plan: add'<'manifest: mark demo/hello as in-progress';
                                     #     '...as in-progress'<'feat(demo): phase 1'; 'learnings: '<'...as merged'
      check_transitions <repo>       # (b) first-occurrence order: as specced < as planned < as in-progress < as merged
      check_test_data <plan-file>    # (c) awk: every '### Phase' section containing '[TDD-Red]' or '[Write-Tests]'
                                     #     must contain '**Test Data:**' before next '### '; fail names the phase heading
      check_spike <piece-dir>        # (d) if plan.md contains '[SPIKE'; then spikes/*.md must exist AND contain
                                     #     '**Mode:**', '**Trigger:**', '**Resolution:**'; any spikes/*.md present must conform
      check_discovery_log <piece-dir># (e) .discovery-log.md first table row matches the 6-column header (grep -F on
                                     #     '| Phase | Discovery type | Source agent | Finding (1-line) | Triage choice | Resolution commit |')
      check_learnings <piece-dir>    # (f) assert_file learnings.md
      check_no_journal <repo>        # (g) [ ! -e "$repo/.phase-group-journal.json" ] — recurses NOT needed; fixed filename at root
      ```
    - `l2_replay_checks()`: ① clean: `t=$(e2e_mktemp)`; `bash "$E2E_DIR/build-fixture.sh" "$t"`; run (a)–(g) (piece dir `$t/docs/prds/demo/specs/hello`); `e2e_cleanup "$t"`. ② break loop (AC-4): for each of the 6 case ids, build into fresh temp, run ONLY the targeted check in a captured subshell, assert it emits ≥1 `FAIL` (expected-fail wrapper → reported as `pass "break:$c fires <check>"`); also assert the OTHER six checks on the `journal-survives` variant still pass (single-defect isolation spot-check).
      Targeted-check map (C-4 → check): research-after-spec→(a); no-test-data→(c); no-spike-artifact→(d); skip-transition→(b); journal-survives→(g); missing-learnings→(f).
    - `audit_checks <piece-dir>`: runs (c)–(g) with `$repo=$REPO_ROOT`; first prints `excluded "ordering checks (a)-(b): commit ordering unverifiable post squash-merge"`; exit reflects shape results only (AC-5).
    - Pattern: asserters from Phase 1; check function naming mirrors linter's invariant functions.
    - Done: 7 check functions + 2 mode functions; no function writes files except via `e2e_mktemp` targets.
    - Verify: `bash -n lib/contract.sh` exit 0.

- [x] **[Write-Tests]** The break-variant loop INSIDE `l2_replay_checks` is this phase's test layer (the spec's clean/defect pair mechanism); plus one audit smoke in `self/test-core.sh` (`# --- L2 ---` section).

    **Test Data:**
    - l2-1: input clean fixture repo (builder default) → expect checks (a)–(g) all PASS (≥10 PASS lines from the L2 section)
    - l2-2: input `--break=research-after-spec` repo, run `check_commit_order` → expect `FAIL` containing `research: `
    - l2-3: input `--break=no-test-data` repo, run `check_test_data` → expect `FAIL` naming `Phase 1`
    - l2-4: input `--break=no-spike-artifact` repo, run `check_spike` → expect `FAIL` containing `spikes/`
    - l2-5: input `--break=skip-transition` repo, run `check_transitions` → expect `FAIL` containing `planned`
    - l2-6: input `--break=journal-survives` repo, run `check_no_journal` → expect `FAIL` containing `.phase-group-journal.json`
    - l2-7: input `--break=missing-learnings` repo, run `check_learnings` → expect `FAIL` containing `learnings.md`
    - l2-8: input real piece dir `docs/prds/exec-ready/specs/flywheel-repo` via `--audit` → expect `EXCLUDED — ordering checks` line AND checks (c)–(g) PASS AND exit 0

- [x] **[Integration-Test]** harness→git boundary (Registry #1) — completes_in_phase: 4
    - Boundary: build-fixture.sh (writes real git history) → contract.sh checks (read it back via real `git log`/`git -C`). No doubles — real git both sides.
    - Run: `bash run-e2e.sh` (default mode, L2 section) — Expected: L2 clean PASS lines + 6 `PASS — break:<case> fires <check>` lines, 0 FAIL in the L2 section.

- [x] **[Verify]** Confirm the implementation is sound
    **Phase-level check:**
    - Run: `bash run-e2e.sh; echo "exit=$?"`
    - Expected: L1 13 PASS + L2 section ≥17 PASS (clean a–g + 6 break-fire + isolation spot-check) + `SKIPPED: live-run` + remaining module ERRORs (verify_live_selftest, metrics_check — until Phases 5-6); summary shows 0 failed; exit=1 (errors from missing modules — expected until Phase 6)
    - Failure: any FAIL line in L1/L2 sections
    **Audit check (AC-5):**
    - Run: `bash run-e2e.sh --audit docs/prds/exec-ready/specs/flywheel-repo; echo "exit=$?"`
    - Expected: `EXCLUDED — ordering checks (a)-(b)` line; 5 PASS (c–g); `== summary: 5 passed, 0 failed, 0 skipped, 0 errors ==`; exit=0
    - Failure: missing EXCLUDED line, any FAIL, or exit≠0

- [x] **[QA]** Phase review — Review against: AC-3, AC-4, AC-5. Diff baseline: phase start SHA.

### Phase 5: Live fixture + synthetic post-run/transcript substrate + verify-live
**Exit Gate:** `setup-live.sh` materializes an executable fixture repo passing `--audit`-grade shape checks; `--verify-live fixtures/post-run/clean --transcript fixtures/transcript/clean.jsonl` → all PASS; each broken variant FAILs its targeted assertion; pathless transcript → `SKIPPED: transcript` with tree checks still run.
**ACs Covered:** AC-6, AC-7, AC-8
**In scope:** CREATE `fixtures/live-project/` (8 files), `fixtures/post-run/clean/` + `fixtures/post-run/broken/`, `fixtures/transcript/clean.jsonl` + `broken.jsonl`, `setup-live.sh`, `lib/live.sh` (`verify_live`, `verify_live_selftest`).
**NOT in scope:** golden record/validate (Phase 6); README live procedure (Phase 7).
**Charter constraints honored in this phase:**
- NN-P-005 (Opus thinking / Sonnet mechanics): nothing in `setup-live.sh`/`lib/live.sh` invokes a model or overrides model placement; the live fixture's plan carries no model directives — the operator-driven run inherits pipeline policy. (Also discharges spec SN-2 for the whole tree: `grep -rn 'claude' tests/e2e/ --include='*.sh'` hits only README-text strings, no invocations — asserted in this phase's Verify.)

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE fixtures/live-project/ (the executable baked fixture, 8 files)**
    - `.spec-flow.yaml` — `docs_root: docs`, `worktrees_root: worktrees`, `layout_version: 4`, `charter_root: .claude`, `charter: {required: false}`, `tdd: true`, `merge_strategy: squash_local`.
    - `docs/prds/demo/prd.md` — 12-line mini PRD (1 goal, FR-001 greet, 2 NN-P none).
    - `docs/prds/demo/manifest.yaml` — piece `hello`, `status: planned`, `feature_branch: null`.
    - `docs/prds/demo/specs/hello/spec.md` — ~25 lines, 4 ACs.
    - `docs/prds/demo/specs/hello/plan.md` — front-matter `tdd: true`, **four phases** (the SF-5 shape contract):
      Phase 1 TDD with `**Test Data:**` (case g-1: input "world" → expect "hello, world"); Phase 2 Implement (write `src/config.txt`); Phase 3 TDD carrying the live spike marker in its deliverable line (fixture content, fenced to stay out of marker scans):
      ```
      [SPIKE: greet suffix value]
      ```
      with NO pre-filled Test Data for case rt-1 (the spike's splice target); Phase 4 TDD with **no Test Data block at all** (the `[TEST-DATA-ABSENT]` trigger).
    - `docs/prds/demo/specs/hello/research.md` — 8-line stub (so execute's research-presence paths are realistic).
    - `src/greet.sh` — empty stub with header comment (the run implements it).
    - `tests/.gitkeep`.
    - Done: four-phase plan greps: `grep -c '\[TDD-Red\]' plan.md` = 3; `grep -c '\[SPIKE' plan.md` = 1; `grep -c '\*\*Test Data:\*\*' plan.md` = 1.
    - Verify: LLM-agent-step: read the plan and confirm phase shapes 1-4 match the SF-5 contract above.

    **T-2: CREATE plugins/spec-flow/tests/e2e/setup-live.sh**
    - Usage: `setup-live.sh <target-dir>`; copies `fixtures/live-project/` into target; `git init -q`; commits baseline in contract order (research → manifest specced → spec → manifest planned → plan — same subjects as build-fixture.sh steps 1-5 minus later stages); prints `READY: <target> — drive with /spec-flow:execute in an interactive session (operator tokens; see tests/e2e/README.md)`.
    - Done: resulting repo at `planned` status with 5 commits.
    - Verify: `bash setup-live.sh /tmp/e2e-live-$$ && git -C /tmp/e2e-live-$$ log --oneline | wc -l` → 5; `grep 'status: planned' /tmp/e2e-live-$$/docs/prds/demo/manifest.yaml` matches; then tmp-guarded cleanup.

    **T-3: CREATE fixtures/post-run/clean/ and fixtures/post-run/broken/ (plain-dir tree fragments)**
    - `clean/`: the live fixture's piece dir AFTER a correct run: plan.md with Phase 3's Test Data block now containing `- rt-1: input "spike" → expect "resolved-42"` (the splice result); `spikes/phase-3.md` (schema-conformant, `**Test Data:**` with rt-1/`resolved-42`); `tests/test-greet.sh` embedding `resolved-42` and `hello, world`; `src/greet.sh` implemented; `.discovery-log.md`; `learnings.md`; `manifest.yaml` `status: merged`.
    - `broken/`: identical EXCEPT `tests/test-greet.sh` lacks `resolved-42` (the consuming test never transcribed the spike oracle — the round-trip defect).
    - Done: `grep -rl 'resolved-42' fixtures/post-run/clean/ | wc -l` ≥ 3 (spike, plan, test); same grep in `broken/` ≥ 2 (spike, plan — NOT test).
    - Verify: shell greps above with exact counts.

    **T-4: CREATE fixtures/transcript/clean.jsonl and broken.jsonl (hand-authored, sanitized)**
    - `clean.jsonl` — 14 lines, each one minimal JSON object. Dispatch lines use the real transcript token shape (ADR-5): `{"type":"assistant","tool":"Agent","input":{"subagent_type":"spec-flow:tdd-red","description":"phase 1 red"}}` — exactly 3 `spec-flow:tdd-red` lines (phases 1, 3, 4), each followed by a `spec-flow:qa-tdd-red`, `spec-flow:implementer`, `spec-flow:verify` line-set in order; 1 `spec-flow:spike` line BEFORE phase 3's tdd-red; 1 `spec-flow:qa-phase`; 1 `spec-flow:review-board-blind` (board evidence); plus 1 text line `{"type":"assistant","text":"[TEST-DATA-ABSENT: no Test Data block in phase]"}`.
    - `broken.jsonl` — same except: first `implementer` line moved BEFORE the first `tdd-red` (ordering defect), only 2 `tdd-red` lines (count defect), and the `[TEST-DATA-ABSENT` line removed.
    - Done: `grep -c 'spec-flow:tdd-red' clean.jsonl` = 3, `broken.jsonl` = 2.
    - Verify: the two grep counts above.

    **T-5: CREATE plugins/spec-flow/tests/e2e/lib/live.sh**
    - `verify_live <target> [transcript]`:
      ```
      tree half:  [ -d "$target/.git" ] → checks (a)–(g) via contract.sh functions;
                  else → checks (c)–(g) + excluded "ordering checks (a)-(b): target has no git history"   (ADR-3)
      round-trip: oracle=$(grep -o 'resolved-42' <spikes dir>/*.md | head -1) — fail if absent;
                  assert_grep 'resolved-42' <plan.md> (splice landed); assert_grep 'resolved-42' <tests/test-greet.sh> (transcription landed)
      transcript half: resolve $TRANSCRIPT: explicit arg → else newest *.jsonl under
                  ~/.claude/projects/$(printf '%s' "$target" | tr '/' '-')/ → unresolvable/empty → skip_cap transcript "..." (tree half already ran)
                  greps (ADR-5 pattern, first-occurrence line numbers): order tdd-red < qa-tdd-red < implementer < verify;
                  assert_count tdd-red == 3 (Implement phase dispatched none); spike line# < phase-3 evidence (spike precedes consumption);
                  assert_grep 'review-board-' (board ran); assert_grep '\[TEST-DATA-ABSENT' (fallback marker emitted)
      ```
    - `verify_live_selftest()` (wired into default mode): runs `verify_live fixtures/post-run/clean fixtures/transcript/clean.jsonl` expecting all PASS; runs the broken pair in expected-fail wrappers: post-run/broken → the round-trip test-file grep FAILs; transcript/broken → ordering FAIL + count FAIL + `[TEST-DATA-ABSENT` FAIL; missing-transcript case: `verify_live fixtures/post-run/clean /nonexistent.jsonl` → `SKIPPED: transcript` emitted AND tree-half PASS lines still present.
    - Done: both functions defined; no model invocation anywhere.
    - Verify: `bash -n lib/live.sh` exit 0; `grep -c 'claude -p\|claude --print' lib/live.sh setup-live.sh` → 0 matches (SN-2).

- [x] **[Write-Tests]** `verify_live_selftest` IS this phase's test layer (clean/broken pairs per spec SF-5 deterministic substrate).

    **Test Data:**
    - vl-1: input `fixtures/post-run/clean` + `fixtures/transcript/clean.jsonl` → expect 0 FAIL; PASS lines include round-trip (`resolved-42` in spike+plan+test) and dispatch order; EXCLUDED line for (a)-(b) present
    - vl-2: input `fixtures/post-run/broken` (test file lacks oracle) → expect exactly the round-trip transcription check FAILs (label contains `test-greet.sh`)
    - vl-3: input `fixtures/transcript/broken.jsonl` → expect FAILs: dispatch order (implementer before tdd-red), tdd-red count (want 3, got 2), missing `[TEST-DATA-ABSENT`
    - vl-4: input transcript path `/nonexistent.jsonl` → expect line `SKIPPED: transcript` AND tree-half PASS lines still emitted (never blocks tree checks)
    - vl-5: input `setup-live.sh` output repo → expect 5 commits, `status: planned`, plan shape greps (3× `[TDD-Red]`, 1× `[SPIKE`, 1× `**Test Data:**`)

- [x] **[Integration-Test]** harness→session-transcript boundary (Registry #2) — completes_in_phase: 5
    - Boundary: `verify_live` transcript-grep path, exercised end-to-end over the committed sample transcripts (the deterministic double for the external Claude Code transcript contract); absence path doubles the missing-capability branch.
    - Contract tests: `clean.jsonl` (well-formed → PASS path) + `broken.jsonl` (defective → FAIL path) + vl-4 (absent → SKIPPED path) — one per doubled-external behavior class.
    - Run: `bash run-e2e.sh` (default mode, verify-live self-test section) — Expected: vl-1..vl-4 outcomes above, 0 unexpected FAIL.

- [x] **[Verify]** Confirm the implementation is sound
    **Per-change checks:**
    - T-1: `grep -c '\[TDD-Red\]' fixtures/live-project/docs/prds/demo/specs/hello/plan.md` — Expected: 3
    - T-2: `bash setup-live.sh /tmp/e2e-live-$$ && git -C /tmp/e2e-live-$$ log --oneline | wc -l` — Expected: 5 (then tmp-guarded cleanup)
    - T-3: `grep -rl 'resolved-42' fixtures/post-run/clean/ | wc -l` — Expected: ≥3; same grep on `fixtures/post-run/broken/` — Expected: 2 (spike + plan only, NOT the test file)
    - T-4: `grep -c 'spec-flow:tdd-red' fixtures/transcript/clean.jsonl` — Expected: 3; same on `broken.jsonl` — Expected: 2
    - T-5: `bash -n lib/live.sh` — Expected: exit 0
    **Phase-level check:**
    - Run: `bash run-e2e.sh; echo "exit=$?"`
    - Expected: L1 + L2 + verify-live sections all green (expected-fail wrappers reported as PASS); `SKIPPED: live-run` (no golden yet); 1 remaining `ERROR — module missing: metrics_check`; summary `0 failed, 1 skipped (live-run), 1 errors`; exit=1 (metrics module lands Phase 6)
    - Failure: any FAIL; or vl-4 emitting FAIL instead of SKIPPED
    **SN-2 sweep:**
    - Run: `grep -rn 'claude -p\|claude --print\|claude code' plugins/spec-flow/tests/e2e/ --include='*.sh'` — Expected: 0 matches
    - Failure: any match (harness must never invoke a model)

- [x] **[QA]** Phase review — Review against: AC-6, AC-7, AC-8. Diff baseline: phase start SHA.

### Phase 6: Golden snapshot + metrics capability gate
**Exit Gate:** record→re-assert→mutate→delete cycle behaves per AC-9 (PASS → FAIL → SKIPPED); metrics check reports `SKIPPED: metrics-artifact` today and engages on a stub file (AC-10); default run now has zero `ERROR — module missing` lines.
**ACs Covered:** AC-9, AC-10
**In scope:** CREATE `lib/golden.sh` (`record_golden`, `golden_validate`), `lib/metrics.sh` (`metrics_check`), `golden/.gitkeep`.
**NOT in scope:** README re-record policy text (Phase 7).
**Charter constraints honored in this phase:** none newly allocated (probes + vocabulary established Phase 1; tooling constraint held by Phase 1).

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE plugins/spec-flow/tests/e2e/lib/golden.sh**
    - Footprint schema (C-3; plain text, exact section headings):
      ```
      # spec-flow e2e golden footprint v1
      ## commit-subjects        ← ordered `git -C <target> log --reverse --format=%s`
      ## dispatch-sequence      ← ordered subagent_type extracts from the transcript (sed -E over the ADR-5 pattern)
      ## files                  ← sorted piece-relative paths of contract artifacts present (spec.md, plan.md, spikes/*.md, .discovery-log.md, learnings.md)
      ## cksum                  ← `cksum` (POSIX) of every line above this heading
      ```
    - `record_golden <target> <transcript>`: refuses (err + return 1) unless a `verify_live "$target" "$transcript"` subshell run reports 0 FAIL (AC-9 precondition "pass with zero FAIL"); writes `golden/footprint.txt` per schema; prints `RECORDED: golden/footprint.txt — commit it (see README re-record policy)`.
    - `golden_validate()` (wired into default mode; ADR-4): ① recompute cksum over body, mismatch → `fail "golden integrity: cksum mismatch (footprint edited or corrupted)"`; ② run the SF-3 relative-order rules (same prefix pairs as `check_commit_order`/`check_transitions`) against the RECORDED `## commit-subjects` lines; ③ assert recorded `## dispatch-sequence` first-occurrence order tdd-red < qa-tdd-red < implementer < verify and contains a `review-board-` entry; ④ assert `## files` contains each required artifact name. Stale-contract failures name the violated rule.
    - Done: both functions; `have_golden` (Phase 1 probe) gates the default-mode call: `! have_golden → skip_cap live-run "no golden recorded — run the live procedure (README)"`.
    - Verify: `bash -n lib/golden.sh` exit 0.

    **T-2: CREATE plugins/spec-flow/tests/e2e/lib/metrics.sh**
    - `metrics_check [piece-dir]` (default: the replay fixture's piece dir inside the default-mode temp build, passed by `l2_replay_checks` via a saved path; standalone default `docs/prds/demo/specs/hello` under last temp target): `have_metrics_artifact "$dir"` → false → `skip_cap metrics-artifact "FR-010 not shipped — probe path: <dir>/metrics.yaml"`; true → `assert_file "$dir/metrics.yaml" "metrics artifact present"` (the engaged assertion; the metrics piece replaces the probe path + adds schema checks when it ships — single flip point per spec).
    - Done: function defined; flip point is `have_metrics_artifact` only.
    - Verify: `bash -n lib/metrics.sh` exit 0.

- [x] **[Write-Tests]** Golden cycle + metrics stub cases appended to `self/test-core.sh` (`# --- golden/metrics ---` section); uses a temp E2E_DIR copy so the real `golden/` stays untouched.

    **Test Data:**
    - gold-1: input record from `fixtures/post-run/clean` + `fixtures/transcript/clean.jsonl` — but post-run/clean has no .git, so `## commit-subjects` is empty → use the L2 clean replay repo (build-fixture.sh output) as target + clean.jsonl as transcript → expect `golden/footprint.txt` written with 4 section headings and `RECORDED:` line
    - gold-2: input default-mode `golden_validate` right after gold-1 → expect PASS lines for cksum + order rules, 0 FAIL
    - gold-3: input footprint with one `## commit-subjects` line deleted (sed) → expect `FAIL — golden integrity: cksum mismatch...`
    - gold-4: input `golden/footprint.txt` removed → expect `SKIPPED: live-run — no golden recorded...`
    - met-1: input piece dir without `metrics.yaml` → expect `SKIPPED: metrics-artifact — FR-010 not shipped...`
    - met-2: input piece dir after `echo 'placeholder: true' > <dir>/metrics.yaml` → expect `PASS — metrics artifact present`

- [x] **[Verify]** Confirm the implementation is sound
    **Phase-level check:**
    - Run: `bash plugins/spec-flow/tests/e2e/self/test-core.sh`
    - Expected: all sections green — `== summary: 28 passed, 0 failed, 0 skipped, 0 errors ==` (6 core + 3 L1 + 8 L2 + 5 vl + 6 gold/met = 28 cases, one verdict line per case — the script's case inventory is FIXED by the Test Data blocks of Phases 1, 2, 4, 5, 6; adding/removing a case requires updating this expected count in the same change), exit 0
    - Failure: any FAIL/ERROR
    **Default-run completeness:**
    - Run: `bash run-e2e.sh; echo "exit=$?"`
    - Expected: ZERO `ERROR — module missing` lines; summary `0 failed, 0 errors`; `SKIPPED: live-run` + `SKIPPED: metrics-artifact` present; exit=0 (first all-green default run)
    - Failure: any module-missing ERROR or FAIL

- [x] **[QA]** Phase review — Review against: AC-9, AC-10. Diff baseline: phase start SHA.

### Phase 7: README + charter sanctioning edits + 5.10.0 release
**Exit Gate:** AC-12's full checklist green: README documents every mode + live procedure + token-cost note; 3 charter edits present; linter untouched; all FOUR version-bearing files at 5.10.0 (per `plugins/spec-flow/docs/releasing.md` — spec-flow co-ships two host descriptors); default run < 60s.
**ACs Covered:** AC-12, AC-1 (timing re-verify on the assembled default run)
**In scope:** CREATE `tests/e2e/README.md`; MODIFY `.claude/skills/charter-architecture/SKILL.md`, `.claude/skills/charter-tools/SKILL.md`, `plugins/spec-flow/.claude-plugin/plugin.json`, `plugins/spec-flow/plugin.json` (Copilot CLI host descriptor), `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`.
**NOT in scope:** any tests/e2e/*.sh logic changes; CI wiring (pi-022-vsync-ci); coherence linter files (must show NO diff); `scripts/` charter-architecture sanctioning (pre-existing gap from the manifest-ops change — out of this piece's scope except the one-word charter-tools accuracy fix in T-3 Edit A).
**Charter constraints honored in this phase:**
- NN-C-001 (version/marketplace sync): both plugin descriptors (`plugins/spec-flow/.claude-plugin/plugin.json` + `plugins/spec-flow/plugin.json`) + the marketplace.json spec-flow entry all move 5.9.0 → 5.10.0 in this phase's release commit.
- NN-C-009 (always bump version): minor bump justified per spec NN-C-009 honoring line (additive in-plugin capability; no major trigger fires); all four version-bearing files per `docs/releasing.md`; CHANGELOG gains `## [5.10.0]` with Added grouping.
- NN-C-003 (backward compat): everything additive; the two charter files gain/amend lines without removing any entry.
- CR-005 (repo-root-relative paths): every file reference in README is repo-root-relative.
- CR-009 (heading hierarchy): README has one H1, H2 sections, H3 subsections.

- [x] **[Implement]** Write code per the plan

    **Change Specifications:**

    **T-1: CREATE plugins/spec-flow/tests/e2e/README.md**
    - H1 `# spec-flow e2e smoke test`; H2 sections: `## What this is` (peer to the coherence linter; FR-013); `## Invocation` (all modes with copy-paste commands: default, `--audit <piece-dir>`, `--verify-live <target> [--transcript <jsonl>]`, `--record-golden <target> <transcript>`, `--break <case>` list — the 6 C-4 ids, `self/test-core.sh`); `## Capabilities and SKIPPED semantics` (the 3 capability ids + never-false-green rule + EXCLUDED line class); `## Live procedure (operator-driven)` (numbered: 1. `setup-live.sh <dir>` 2. open an interactive session in `<dir>`, run `/spec-flow:execute` — **token cost is operator-chosen; the harness never invokes a model**; expect the spike phase to dispatch Opus per pipeline policy 3. `run-e2e.sh --verify-live <dir>` 4. `--record-golden <dir> <transcript>` 5. commit `golden/footprint.txt`); `## Re-record policy` (re-record after any contract change: L1 token list, commit-subject grammar, dispatch sequence, artifact set); `## What is NOT asserted` (journal mid-run, metrics until FR-010, ordering on squashed masters).
    - Done: every mode named in C-1 appears; the 6 break ids EXACTLY match build-fixture.sh's case list.
    - Verify: see cross-phase consistency block below.

    **T-2: MODIFY .claude/skills/charter-architecture/SKILL.md**
    - Anchor: plugin-internal layers bullet list (lines 14-21), bullet `- \`reference/\` — auto-loaded doctrine documents` (line 20).
    - Current:
      ```
      20    - `reference/` — auto-loaded doctrine documents
      21    - `README.md`, `CHANGELOG.md` — human-facing docs
      ```
    - Target: insert one bullet between them: `` - `tests/` — on-demand verification suites (e2e smoke, hook tests) ``
    - Done: layer list enumerates `tests/`.
    - Verify: `grep -n 'tests/.*on-demand verification suites' .claude/skills/charter-architecture/SKILL.md` → 1 match.

    **T-3: MODIFY .claude/skills/charter-tools/SKILL.md (two edits)**
    - Edit A — Anchor: line 12. Current: `- **Primary:** Markdown (content) + YAML (config) + JSON (manifests) + POSIX Bash 4+ (hooks only)` → Target: `... + POSIX Bash 4+ (hooks, scripts, and tests only)`. (Rationale: `plugins/spec-flow/scripts/` shipped 2026-06-09 in the manifest-ops change — writing "hooks and tests only" would be false on arrival.)
    - Edit B — Anchor: Test runner section (lines 19-25). Current: `- **Runner:** None. No test suite exists; verification is:` → Target: `- **Runner:** plain-bash suites run on demand — \`plugins/spec-flow/tests/e2e/run-e2e.sh\` (pipeline e2e smoke, FR-013), \`plugins/spec-flow/hooks/tests/test-lint-skill-coherence.sh\` (coherence linter), and \`plugins/spec-flow/scripts/tests/test-manifest-query.sh\` (manifest-query tool). No framework. Additional verification:` (keep the existing 3 numbered items).
    - Done: "hooks, scripts, and tests only" + runner section names all three suites.
    - Verify: `grep -c 'hooks, scripts, and tests only' .claude/skills/charter-tools/SKILL.md` → 1; `grep -c 'run-e2e.sh' .claude/skills/charter-tools/SKILL.md` → 1; `grep -c 'test-manifest-query.sh' .claude/skills/charter-tools/SKILL.md` → 1.

    **T-4: MODIFY plugins/spec-flow/.claude-plugin/plugin.json**
    - Anchor: line 4 `"version": "5.9.0",` → Target: `"version": "5.10.0",`.
    - Verify: `grep -n '"version": "5.10.0"' plugins/spec-flow/.claude-plugin/plugin.json` → 1 match.

    **T-4b: MODIFY plugins/spec-flow/plugin.json (Copilot CLI host descriptor — 2nd of the four version-bearing files per docs/releasing.md)**
    - Anchor: the top-level `"version": "5.9.0"` field → Target: `"version": "5.10.0"`.
    - Verify: `grep -n '"version": "5.10.0"' plugins/spec-flow/plugin.json` → 1 match.

    **T-5: MODIFY .claude-plugin/marketplace.json**
    - Anchor: spec-flow entry, line 15 `"version": "5.9.0",` → Target: `"version": "5.10.0",`. (Do NOT touch the other plugin's version field further down.)
    - Verify: NN-C-001 sync check: `diff <(grep -o '"version": "[^"]*"' plugins/spec-flow/.claude-plugin/plugin.json) <(sed -n '12,16p' .claude-plugin/marketplace.json | grep -o '"version": "[^"]*"')` → no output; and `grep -c '"version": "5.10.0"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` → 1 match in each.

    **T-6: MODIFY plugins/spec-flow/CHANGELOG.md**
    - Anchor: line 5 `## [Unreleased]` (the `## [5.9.0] — 2026-06-09` manifest-query section now sits below it) → Target: insert below `## [Unreleased]` a `## [5.10.0] — <today's date>` section, groupings: `### Added` (e2e smoke harness: three layers, fixtures, golden snapshot, audit mode, live procedure; charter sanctioning of `tests/`), `### Notes for upgraders` (no behavior change to any existing skill/agent/hook; new on-demand tooling only).
    - Verify: `sed -n '5,12p' plugins/spec-flow/CHANGELOG.md` shows `## [Unreleased]`, then `## [5.10.0]`, then `## [5.9.0]` in that order.

- [x] **[Verify]** Confirm the implementation is sound
    **Cross-phase schema-consistency check (plan SKILL.md 2d — break-case ids, capability ids, golden headings):**
    - Run: LLM-agent-step: extract the 6 `--break` case ids from `build-fixture.sh`, the case list in `lib/contract.sh`'s break loop, and the list in `README.md` — confirm all three sets are IDENTICAL; extract capability ids (`live-run`, `transcript`, `metrics-artifact`) from `lib/assert.sh` (`skip_cap` call sites tree-wide) and `README.md` — confirm identical; extract the 4 `## ` footprint headings from `lib/golden.sh` and the README golden description — confirm identical.
    - Expected: three IDENTICAL verdicts; any drift named per file
    - Failure: any set mismatch
    **Release checks:**
    - Run: `git diff --name-only <phase-start>..HEAD -- plugins/spec-flow/hooks/` — Expected: empty (linter + hook tests untouched, AC-12)
    - Run: NN-C-001 diff from T-5 — Expected: no output
    **AC-1 timing (final):**
    - Run: `time bash plugins/spec-flow/tests/e2e/run-e2e.sh; echo "exit=$?"`
    - Expected: exit=0; `0 failed, 0 errors`; 2 SKIPPED (live-run, metrics-artifact — or 1 if a golden was recorded); real time < 60s (target: < 15s)
    - Failure: ≥60s, any FAIL/ERROR, or exit≠0

- [x] **[QA]** Phase review — Review against: AC-12, AC-1. Diff baseline: phase start SHA.

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | Default run: L1 PASS on unmodified tree, completes < 60s | COVERED | Phase 2, Phase 7 |
| AC-2  | qa-tdd-red-deleted copy → L1 FAILs naming the token | COVERED | Phase 2 |
| AC-3  | Clean replay fixture → all SF-3 checks PASS | COVERED | Phase 4 |
| AC-4  | Each of 6 --break variants → exactly targeted check FAILs | COVERED | Phase 4 |
| AC-5  | --audit on real piece dir → shape checks + ordering EXCLUDED | COVERED | Phase 4 |
| AC-6  | setup-live.sh → executable fixture at planned state, 4-phase shape | COVERED | Phase 5 |
| AC-7  | verify-live tree + spike round-trip: clean PASS / broken FAIL | COVERED | Phase 5 |
| AC-8  | Transcript dispatch order/count/marker: clean PASS / broken FAIL / absent SKIPPED | COVERED | Phase 5 |
| AC-9  | Golden record → re-assert → mutate FAIL → delete SKIPPED | COVERED | Phase 6 |
| AC-10 | Metrics probe: SKIPPED today, engages on stub | COVERED | Phase 6 |
| AC-11 | Summary line + exit-code semantics; skipped never PASS | COVERED | Phase 1 |
| AC-12 | README + 3 charter edits + all 4 version-bearing files + linter untouched | COVERED | Phase 7 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | shell | `time bash plugins/spec-flow/tests/e2e/run-e2e.sh; echo $?` | 13 `PASS — L1` lines; real < 60s; exit 0 (post-Phase-6) |
| AC-2  | shell | `self/test-core.sh` case l1-2 (sed-deleted QA-TDD-Red copy) | `FAIL — L1 sequence token missing: ### Step 2.5: QA-TDD-Red` |
| AC-3  | shell | `bash run-e2e.sh` (L2 clean section) | checks (a)–(g) all PASS on builder output |
| AC-4  | shell | `bash run-e2e.sh` (break loop) | 6 × `PASS — break:<case> fires <check>` |
| AC-5  | shell | `bash run-e2e.sh --audit docs/prds/exec-ready/specs/flywheel-repo; echo $?` | `EXCLUDED — ordering checks (a)-(b)` + 5 PASS + exit 0 |
| AC-6  | shell | `bash setup-live.sh /tmp/x && git -C /tmp/x log --oneline \| wc -l` | 5 commits; `status: planned` in manifest; plan greps 3/1/1 |
| AC-7  | shell | `bash run-e2e.sh --verify-live fixtures/post-run/clean --transcript fixtures/transcript/clean.jsonl; echo $?` | 0 FAIL, exit 0; broken pair → round-trip FAIL (vl-2) |
| AC-8  | shell | same with `broken.jsonl` / `/nonexistent.jsonl` | order+count+marker FAILs / `SKIPPED: transcript` with tree PASS |
| AC-9  | shell | gold-1..gold-4 cycle in `self/test-core.sh` | RECORDED → PASS → cksum FAIL → `SKIPPED: live-run` |
| AC-10 | shell | met-1/met-2 in `self/test-core.sh` | `SKIPPED: metrics-artifact` → stub file → `PASS — metrics artifact present` |
| AC-11 | shell | `bash plugins/spec-flow/tests/e2e/self/test-core.sh; echo $?` | own summary all-green, exit 0; sum-1..sum-4 outcome classes |
| AC-12 | shell + agent-step | T-2..T-6 Verify greps + linter no-diff + NN-C-001 diff + README mode list | all greps match; diffs empty |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs.

The following boundary-crossing interfaces are nonetheless fixed as contracts (consumed across phases and by operators):

### C-1: run-e2e.sh CLI
- **ID:** C-1
- **Type:** API Endpoint (CLI)
- **Phase:** Phase 1 (final from Phase 1 — ADR-1)
- **Signature:** `run-e2e.sh [--audit <piece-dir> | --verify-live <target> [--transcript <jsonl>] | --record-golden <target> <transcript> | --break <case> | --help]`
- **Inputs:** mode flags as above; no args = default mode
- **Outputs:** PASS/FAIL/SKIPPED/ERROR/EXCLUDED lines + `== summary: N passed, M failed, S skipped, E errors ==`
- **Error cases:** unknown flag → usage on stderr, exit 2; missing module → `ERROR — module missing: <fn>`
- **Constraints:** exit 0 iff failed==0 && errors==0; SKIPPED/EXCLUDED never rendered as PASS

### C-2: lib/assert.sh API
- **ID:** C-2
- **Type:** Function (sourced bash API)
- **Phase:** Phase 1
- **Signature:** `pass|fail|err <label>; skip_cap <capability> <label>; excluded <label>; assert_exit <want> <label> -- <cmd...>; assert_grep|assert_no_grep <ERE> <file> <label>; assert_file <path> <label>; assert_count <ERE> <file> <want> <label>; assert_subject_order <repo> <prefixA> <prefixB> <label>; have_golden; have_transcript; have_metrics_artifact <piece-dir>; e2e_mktemp; e2e_cleanup <tmp-path>; summary`
- **Inputs:** as named; capability ∈ {live-run, transcript, metrics-artifact}
- **Outputs:** counter mutations + result lines; `summary` returns 0/1
- **Error cases:** `e2e_cleanup` outside tmp prefixes → `err`, no deletion
- **Constraints:** consumed by lib/static.sh, lib/contract.sh, lib/live.sh, lib/golden.sh, lib/metrics.sh, self/test-core.sh — signature changes after Phase 1 require touching all six consumers

### C-3: golden footprint schema
- **ID:** C-3
- **Type:** Data Schema
- **Phase:** Phase 6
- **Signature:** plain-text sections in order: `# spec-flow e2e golden footprint v1`, `## commit-subjects`, `## dispatch-sequence`, `## files`, `## cksum`
- **Inputs:** written by `record_golden`; read by `golden_validate`
- **Outputs:** validation verdicts per ADR-4
- **Error cases:** cksum mismatch → FAIL (integrity); missing section → FAIL (schema)
- **Constraints:** README's golden description must list the same 4 headings (cross-phase check, Phase 7)

### C-4: break-case id set
- **ID:** C-4
- **Type:** Data Schema (enumerated ids)
- **Phase:** Phase 3
- **Signature:** `research-after-spec | no-test-data | no-spike-artifact | skip-transition | journal-survives | missing-learnings`
- **Inputs:** `build-fixture.sh --break=<id>`
- **Outputs:** single-defect fixture variants
- **Error cases:** unknown id → builder usage error, exit 2
- **Constraints:** consumed by lib/contract.sh break loop (Phase 4) + README (Phase 7); the three lists must stay identical (cross-phase check, Phase 7)

## Parallel Execution Notes

Serial chain, deliberate (see Phase 1 `Why serial:`): Phase 1 → 2 → 3 → 4 → 5 → 6 → 7. Phases 2 and 3 are the only near-disjoint pair, but both consume Phase 1's C-2 API and Phase 4 consumes Phase 3's output — group machinery would buy one phase of overlap at the cost of group QA semantics on a 7-phase piece. No Phase Groups. No `[P]` tasks.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, phase [Implement] tasks (Change Specification Blocks above are self-contained), spec ACs, plan [Verify] commands, pattern blocks inline, introspection Dependency Map/Test Landscape for phase scope | Spec rationale, brainstorm history |
| Write-Tests (Step 2.7) | Phase's Test Data block (transcribe-only — invent nothing), the implemented files, [Write-Tests] instructions | Other phases' tests, prior conversation |
| Verify | [Verify] commands + expected outputs verbatim | Implementation reasoning |
| QA (qa-phase / qa-phase-lite) | Phase diff, phase ACs, spec AC text | Brainstorm history |
| Review board (Final Review) | Cumulative diff, spec, plan, charter | Conversation history |
