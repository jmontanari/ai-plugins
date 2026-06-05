---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-01
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: pi-020-dc-harden — execute-robustness hardening

**Status:** merge-pending

## Overview

Non-TDD mode: all phases use Implement track (`[Implement]` → `[Write-Tests]` → `[Verify]` → `[QA]`);
the AC Coverage Matrix is required; QA and Final Review remain intact. There are **no registry-tracked
integration tests** (the spec's Integration Coverage is "None in scope" — the plugin ships no
runner-discoverable suite); behavioral claims (anchor forge-resistance, concurrency, Race-2, INV-9,
migration) are proven by a one-off **validation harness** authored as a runnable script at
`docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh` (bash; `python3` permitted as a throwaway
validation tool, NOT shipped plugin code) plus a `VALIDATION.md` recording its run — built up across
Phases 1-4 (real git + real OS processes, mirroring pi-015). Each phase's `[Write-Tests]` step appends
its cases to the harness; `[Verify]` runs `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh <CASE>`.
Plugin prose/config/version edits are verified by pi-014 grep-oracles. Five **serial** flat phases
(all edit the single file `plugins/spec-flow/skills/execute/SKILL.md`, so they cannot be parallelized,
and items are sequenced item-1 → item-2 → item-3 per the spec). Target version: 5.2.0.

**Why serial:** every phase edits `execute/SKILL.md` (single-file contention forbids `[P]` parallelism),
and the spec sequences item 1 (anti-cheat anchor) strictly before item 2 (concurrency) — the anchor
must land before concurrency widens the tamper window.

## Architectural Decisions

### ADR-1: Tier-1 `git hash-object -w` orchestrator anchor (not Tier-2 `commit-tree`)
**Context:** the deferred-group anti-cheat trusts a Red-agent self-asserted `sha256sum` manifest with
no independent object anchor until the barrier (CWE-345).
**Decision:** at `red-done` the ORCHESTRATOR runs `git hash-object -w` per Red test file, writing the
blob to the object store and recording the returned blob SHA in the journal. This is a Tier-1
hardening — the content anchor becomes orchestrator-produced and immutable, replacing trust in the
agent's self-report.
**Alternatives considered:** (a) keep `sha256sum` self-report — rejected: the policed actor asserts
its own baseline; (b) implement the journal's Tier-2 `commit-tree`/private-`GIT_INDEX_FILE` dangling
commit — rejected: Tier-2 targets working-tree-WIPE survival (a different threat), is gated behind a
future `journal_tier` knob, and exceeds this piece's scope.
**Consequences:** the blob exists in `.git/objects` immediately at red-done; forge-resistance is
gained for Red test files; production files stay trusted-by-association (ADR-5). The journal's Tier-2
forward-design block is untouched and remains distinct.
**Charter alignment:** NN-C-002 (git only, no runtime deps); CR-008 (orchestrator owns integrity,
agents stay narrow).

### ADR-2: Concurrency default-ON under `deferred_commit: auto`
**Context:** pi-015 forced serial dispatch as a safety carve-out; the parallelism win is off.
**Decision:** under `deferred_commit: auto` + `phase_groups: auto`/`always`, dispatch sub-phases
concurrently on the git-free foundation. `deferred_commit: off` and the serial path remain reachable.
**Alternatives considered:** gate concurrency behind a new opt-in knob — rejected: leaves the win
off-by-default and adds config surface; the `off` escape hatch already provides rollback.
**Consequences:** restores pre-5.0.0 wall-clock parallelism; requires the Race-2 scoped oracle (ADR
n/a — FR-6) and INV-9 isolation (ADR n/a — FR-7) to be safe.
**Charter alignment:** NN-C-003 (`off` escape hatch + minor bump preserve backward compat).

### ADR-3: Execute base-ref resolver is stricter than review-board's
**Context:** `review-board/SKILL.md:38` resolves the default branch as `symbolic-ref` → else `main`
→ else `master` (silent guesses). Spec FR-9 forbids a silent `main` assumption.
**Decision:** execute (and verify) resolve via `git symbolic-ref refs/remotes/origin/HEAD` →
`git remote show origin` → `.spec-flow.yaml default_branch:` → **loud error**. review-board is left
unchanged (out of scope, already functional).
**Alternatives considered:** (a) reuse review-board's `main`→`master` fallback — rejected: violates
FR-9's no-silent-`main` rule; (b) converge both skills on one resolver — rejected: review-board is
out of this piece's scope.
**Consequences:** a misconfigured repo errors instead of silently diffing against a nonexistent
`main`; a one-line `default_branch:` config escape exists. A future piece may converge review-board.
**Charter alignment:** CR-007 (the new config key is documented inline).

### ADR-4: Journal migration = format-marker + graceful fallback
**Context:** item 1 changes `red_manifest_hashes` from sha256 to blob SHA; in-flight ≤5.1.0 journals
must resume after the upgrade (NFR-003).
**Decision:** journals created at/after 5.2.0 carry a top-level `anchor: blob` marker; on resume, a
journal lacking the marker is verified with `sha256sum` as-is (honored), with no forced migration and
no refusal.
**Alternatives considered:** refuse + fresh start (rejected: NFR-003 regression); auto-migrate
(rejected: the old sha256 can't be converted to a blob SHA without re-anchoring, i.e. re-running).
**Consequences:** zero user disruption across the upgrade; two verify paths coexist for one release.
**Charter alignment:** NN-C-003.

### ADR-5: Red-test-files-only anchor
**Context:** the pi-015 board flagged the self-asserted manifest specifically for Red tests.
**Decision:** blob-anchor Red test files only; production files remain trusted-by-association,
exactly as pi-015.
**Alternatives considered:** anchor production files too — rejected: exceeds the flagged finding,
adds journal entries + a re-hash pass, and production-drift-across-resume is a separate Tier-1
limitation already documented.
**Consequences:** scope stays bounded; production-file drift across resume remains undetected (known).
**Charter alignment:** NN-C-002.

## Phases

### Phase 1: Anti-cheat blob anchor + journal migration (item 1)
**In scope:** replace the deferred-group Red-test integrity anchor with an orchestrator-produced
`git hash-object -w` blob in `execute/SKILL.md` (G4 record, G9b barrier, SF3) + the journal schema/
example/prose + a format marker + resume fallback; clarify `tdd-red.md` / `implementer.md` (+ twins)
that the orchestrator's anchor is authoritative.
**NOT in scope:** concurrency (Phase 2); the flat-phase HEAD-hash gate (Step 2.6/Step 3 (a)) — already
HEAD-anchored, untouched; base-ref (Phase 4); version bump (Phase 5); the journal Tier-2 block.
**Steps traversed (P2):** the change adds a new conditional path in the resume logic (old-marker-absent
sha256 path vs new blob path) — it traverses: Step G4 (record at red-done), Step G9b (barrier verify),
the Step G9 SF3 re-capture guard, and the Session-Resumability green-sub-phase re-verify (journal
`green` re-hash). No NEW step is inserted; existing steps' anchor mechanism + one resume branch change.
**Dispatch sites (P3):** the integrity contract feeding `tdd-red` / `implementer` changes (Red's
manifest becomes advisory). Affected (re-)dispatch sites of those agents: G4 initial dispatch (L1185),
G9b reject re-dispatch (L1293), G6 contamination + scope-violation re-dispatch (L1372/L1373), G6
pre-decision-mismatch re-dispatch (L1378), mid-group resume re-dispatch (L1802). This phase does not
change WHICH sites dispatch; it changes the prompt's integrity wording (advisory manifest) at the
tdd-red/implementer template level (one edit each + byte-identical twin lines).
**Charter constraints honored in this phase:** NN-C-002, CR-008, NN-P-002 (anchor strengthens the
per-phase/Final-Review integrity, bypasses no gate), ADR-1/ADR-4/ADR-5.
**Exit Gate:** grep-oracles confirm blob-anchor language at G4/G9b/SF3 + journal + agents (+ twins);
VALIDATION harness invariants ANCHOR-1/ANCHOR-2/MIG-1 pass; per-phase Opus [QA] clean.

- [x] **[Implement]**

  **File changes:**
  | File | Change |
  |------|--------|
  | `plugins/spec-flow/skills/execute/SKILL.md` | MODIFY (G4 record, G9b barrier, SF3, resume) |
  | `plugins/spec-flow/reference/deferred-commit-journal.md` | MODIFY (schema, example, prose, marker) |
  | `plugins/spec-flow/agents/tdd-red.md` | MODIFY (Rule 9 + deferred-group branch) |
  | `plugins/spec-flow/agents/tdd-red.agent.md` | MODIFY (Rule 9 line — byte-identical twin) |
  | `plugins/spec-flow/agents/implementer.md` | MODIFY (Rule 8 + deferred-group branch) |
  | `plugins/spec-flow/agents/implementer.agent.md` | MODIFY (Rule 8 line — byte-identical twin) |

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: G9b barrier verify loop (lines 1283-1293)
  CURRENT:
  ```
  1285     ```bash
  1286     for path in <this sub-phase's red_manifest_hashes keys>; do
  1287       wt_hash=$(sha256sum -- "$path" | cut -d' ' -f1)
  1288       manifest_hash=<journal red_manifest_hashes[path]>
  1289       [ "$wt_hash" = "$manifest_hash" ] || echo "barrier integrity fail: $path"
  1290     done
  1291     ```
  ```
  TARGET: replace the working-tree hash with the git-blob hash so the verify compares against the
  orchestrator-written blob SHA. New loop body:
  ```bash
  for path in <this sub-phase's red_manifest_hashes keys>; do
    wt_blob=$(git hash-object -- "$path")
    manifest_blob=<journal red_manifest_hashes[path]>
    [ "$wt_blob" = "$manifest_blob" ] || echo "barrier integrity fail: $path"
  done
  ```
  Also update the surrounding prose (1283, 1293): "re-hash … `sha256sum`" → "re-hash … `git hash-object`";
  state the anchor is the orchestrator-written blob from red-done (FR-2). Keep the test-files-only /
  production-trusted-by-association sentence (ADR-5). Add the FR-4 marker note: "If the journal lacks
  the `anchor: blob` marker (written by ≤5.1.0), verify with `sha256sum` instead (see resume fallback)."
  Done: the bash block uses `git hash-object`; no `sha256sum` remains in the G9b block.
  Verify: `grep -n "git hash-object" plugins/spec-flow/skills/execute/SKILL.md` returns the G9b line.

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: G4 record-at-red-done (line 1191)
  CURRENT:
  ```
  1191  - **Red** writes its failing tests to the working tree and emits its SHA-256 manifest, but does **not** stage them (no `git add`). The orchestrator records that manifest in the journal and flips the sub-phase to `red-done` (transitioning it from `pending`).
  ```
  TARGET: the orchestrator does NOT record Red's self-reported hashes; instead, for each Red test file
  it runs `git hash-object -w -- "$path"` (writes the blob to the object store, returns the blob SHA),
  records `{path: blob_sha}` in the journal `red_manifest_hashes`, sets the journal top-level
  `anchor: blob` marker, and flips to `red-done`. Red's emitted manifest is retained only as an
  advisory cross-check (a mismatch is a soft warning, not the integrity source). State explicitly:
  "the orchestrator-produced blob SHA is authoritative; the agent's self-reported manifest is not the
  integrity baseline (FR-1)."
  Done: prose says orchestrator runs `git hash-object -w` at red-done and sets `anchor: blob`.
  Verify: `grep -n "git hash-object -w" plugins/spec-flow/skills/execute/SKILL.md` returns the G4 line.

  T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: SF3 ordering guard blockquote (line 1281)
  CURRENT (verbatim, the load-bearing clause of the L1281 blockquote):
  ```
  1281  > **Ordering guard (hook-autofix vs anti-cheat — SF3).** The Step G9 hook sweep runs BEFORE this G9b re-hash. … Guard: **after the G9 sweep applies any autofix, re-capture `red_manifest_hashes` for every Red test file the (trusted) sweep modified** — updating the journal — so this re-hash compares against the post-sweep baseline. (The sweep is trusted by construction; the anti-cheat targets Build-agent tampering, not formatter autofixes.) …
  ```
  TARGET: keep the guard; specify the re-capture uses `git hash-object -w` (re-writes the post-sweep
  blob to the object store and updates the journal entry), consistent with T-2 — replace the implicit
  "re-capture … hashes" with "re-anchor via `git hash-object -w` … for every Red test file the
  (trusted) sweep modified". Done: SF3 prose names `git hash-object -w` as the re-capture mechanism.
  Verify: `grep -n "re-capture\|re-anchor" plugins/spec-flow/skills/execute/SKILL.md` SF3 block names `git hash-object -w`.

  T-4: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Session-Resumability green-sub-phase re-verify (line 1801)
  CURRENT (verbatim):
  ```
  1801    - **`green` sub-phases → trust after a hash re-check.** For each sub-phase with `status: green`, re-hash ONLY its Red test files (the keys of its `red_manifest_hashes`) …
  ```
  TARGET: add the FR-4 fallback branch — "If the journal carries `anchor: blob`, re-verify green
  sub-phases with `git hash-object`; if the marker is ABSENT (journal written by ≤5.1.0), re-verify
  with `sha256sum` and do NOT re-anchor or refuse — honor the old format as-is for this in-flight
  piece." Done: the resume re-verify documents both branches keyed on the `anchor:` marker.
  Verify: `grep -n "anchor: blob" execute/SKILL.md` returns the G4 set + the resume branch.

  T-5: MODIFY `plugins/spec-flow/reference/deferred-commit-journal.md`
  Anchor: per-sub-phase schema row + lifecycle (lines 33, 74, 89, 101) and a new top-level marker
  CURRENT (L33): "`red_manifest_hashes` | map | Map of path → SHA-256 hex digest, one entry per Red
  test file … Captured when the sub-phase reaches `red-done`."
  TARGET: change the value definition to "path → git blob SHA (the output of `git hash-object -w`,
  written by the orchestrator at `red-done`)". Add a top-level field row: "`anchor` | string |
  `blob` for journals written at/after 5.2.0 (red_manifest_hashes are git blob SHAs); ABSENT for
  ≤5.1.0 journals (red_manifest_hashes are `sha256sum` digests — honored as-is on resume)." Update the
  green-re-verify prose (L89, L101) to "re-hash … via `git hash-object`" while keeping the
  production-trusted-by-association limitation verbatim. Update the JSON example (L41-66) to add
  `"anchor": "blob"` at top level and a comment noting the hash values are git blob SHAs. Leave the
  Tier-2 block (L200-215) UNCHANGED.
  Done: schema documents `anchor` marker + blob-SHA `red_manifest_hashes`; Tier-2 block unchanged.
  Verify: `grep -n "git hash-object\|anchor" deferred-commit-journal.md` shows the schema + marker.

  T-6: MODIFY `plugins/spec-flow/agents/tdd-red.md`
  Anchor: Rule 9 (line 53) + deferred-group branch (line 42)
  CURRENT (L53 tail): "Compute the hashes with whatever tool is standard … `git hash-object` adds a
  header so prefer `sha256sum`."
  TARGET: Rule 9 keeps Red emitting its `## Staged test manifest` (now advisory). Add: "In a deferred
  Phase Group the ORCHESTRATOR independently anchors each test file with `git hash-object -w` at
  red-done; your manifest is an advisory cross-check, not the integrity baseline." Soften "prefer
  sha256sum" to "emit sha256 for the advisory manifest; the orchestrator's git-blob anchor is
  authoritative in deferred groups." Mirror the SAME Rule 9 edit into `tdd-red.agent.md` **by CONTENT
  MATCH, not line number** — the byte-identical Rule 9 sentence sits at a DIFFERENT line in the twin
  (~L51; the twin's frontmatter length differs, so lines do not co-align). Locate the matching text
  and edit it identically. The twin LACKS the deferred-group branch — do NOT add it there; only the
  Rule 9 sentence is shared. Done: Rule 9 states the orchestrator's blob anchor is authoritative in
  both files. Verify: `grep -n "authoritative\|git hash-object" plugins/spec-flow/agents/tdd-red.md plugins/spec-flow/agents/tdd-red.agent.md` — both match.

  T-7: MODIFY `plugins/spec-flow/agents/implementer.md`
  Anchor: Rule 8 (line 53) + deferred-group branch (line 59) + "Red test modification" (line 63)
  TARGET: Rule 8 / deferred-group branch — add: "the orchestrator anchors Red's tests with
  `git hash-object -w`; you cannot make a tampered test hash to the original blob — do not touch
  Red's test files." Keep the strict no-edit contract. Mirror the SAME Rule 8 edit into
  `implementer.agent.md` **by CONTENT MATCH, not line number** — the byte-identical Rule 8 / "Red test
  modification" sentences sit at a DIFFERENT line in the twin (frontmatter length differs). Locate the
  matching text and edit it identically; the twin LACKS the deferred-group branch — do NOT add it
  there. Done: Build prose names the orchestrator blob anchor in both files.
  Verify: `grep -n "git hash-object\|cannot" plugins/spec-flow/agents/implementer.md plugins/spec-flow/agents/implementer.agent.md` — both match.

- [x] **[Write-Tests]** (validation harness — a runnable artifact, NOT a registry integration test)
  CREATE `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh` (bash dispatcher; `python3`
  permitted as a throwaway validation helper, NOT shipped plugin code) — invocation
  `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh <CASE>`. It drives a real throwaway
  git worktree and implements these cases (echo `PASS <CASE>` / `FAIL <CASE>`, exit non-zero on FAIL):
  - **ANCHOR-1 (AC-1):** simulate red-done → assert the journal `red_manifest_hashes[path]` equals
    `git hash-object <path>` AND `git cat-file -t <sha>` prints `blob` (orchestrator wrote the blob).
  - **ANCHOR-2 (AC-2):** mutate the test file post-red-done → assert `git hash-object <path>` ≠ stored
    blob SHA (barrier detects tamper). Assert re-greening would require editing the orchestrator-owned
    journal (not a Build-agent capability — document, not executable).
  - **MIG-1 (AC-5):** a fixture journal WITHOUT the `anchor: blob` marker (sha256 values) resumes via
    the `sha256sum` path with exit 0 and no re-anchor.
  Also CREATE `docs/prds/shared/specs/pi-020-dc-harden/VALIDATION.md` recording the run + results.
  (Real git; no doubles. Later phases append their cases to the same `run.sh`.)

- [x] **[Verify]** (one check per change-class + harness run)
  - T-1/T-2 (G4 record + G9b verify): `grep -n "git hash-object -w" plugins/spec-flow/skills/execute/SKILL.md`
    (≥1 G4 match) and `grep -n "git hash-object" plugins/spec-flow/skills/execute/SKILL.md` (G9b loop);
    `grep -n "sha256sum" plugins/spec-flow/skills/execute/SKILL.md` — Expected: the G9b deferred-block
    no longer uses sha256sum (flat-phase Step 2.6 L421 + Step 3(a) L522 sha256sum lines REMAIN, untouched).
  - T-3 (SF3): `grep -n "re-anchor\|git hash-object -w" plugins/spec-flow/skills/execute/SKILL.md` — SF3 block names `git hash-object -w`.
  - T-4 (resume FR-4): `grep -n "anchor: blob" plugins/spec-flow/skills/execute/SKILL.md` — Expected: the resume re-verify branch keyed on the marker.
  - T-5 (journal): `grep -n "anchor" plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: the new `anchor` schema row + `"anchor": "blob"` in the JSON example; `grep -c "SHA-256 hex digest" …` on the `red_manifest_hashes` row — Expected: 0.
  - T-6/T-7 (twins): LLM-agent-step — confirm the shared Rule 9 (tdd-red) and Rule 8 (implementer)
    sentences are byte-identical across `.md` and `.agent.md` after the edit (content-match, not line).
  - Run: `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh ANCHOR-1 ANCHOR-2 MIG-1` —
    Expected: `PASS ANCHOR-1`, `PASS ANCHOR-2`, `PASS MIG-1`; results recorded in VALIDATION.md.
- [x] **[QA]** Opus deep review vs AC-1/2/3/4/5; diff baseline: phase_1 start.
- [x] **[Progress]**

### Phase 2: Safe concurrency re-enable + Race-2 scoped oracle (item 2, part 1)
**In scope:** flip `deferred_commit: auto` from serial to concurrent dispatch (under `phase_groups:
auto`/`always`) in `execute/SKILL.md` (knob def, G4 section, worked trace); add the Race-2 per-sub-phase
scoped oracle + barrier whole-non-integration-suite re-run; extend the flag-injection rule to inject the
concurrency MODE at every (re-)dispatch site; correct the L1192 "line 499" cross-ref to 506; update the
journal serial-note. Depends on Phase 1.
**NOT in scope:** INV-9 runtime isolation + serial-replay (Phase 3); anti-cheat (Phase 1); base-ref
(Phase 4); the `deferred_commit: off` legacy section (untouched).
**Steps traversed (P2):** introduces the concurrent-dispatch PATH through the Phase Group Loop. Pre-
existing steps it traverses/invalidates: Step G4 (serial→concurrent dispatch + worked trace), Step G5/
G9b barrier (now the FIRST point all sub-phase files coexist → whole-suite gate moves here), Step 3
oracle invariant (a) L506 + (b) L509 (now scoped per sub-phase via `phase_N_oracle_block`), the G4
flag-injection rule L1185-1187 (mode added), G6 recovery rows L1372/L1373/L1378, mid-group resume L1802.
**Dispatch sites (P3):** changes the agent-dispatch contract — every `tdd-red`/`implementer` dispatch
now also carries the concurrency mode. Sites: G4 initial (L1185), G9b reject (L1293), G6 contamination
(L1372), G6 scope-violation (L1373), G6 pre-decision-mismatch (L1378), mid-group resume (L1802).
**Charter constraints honored in this phase:** NN-C-003 (`off` escape hatch preserved), NN-C-008
(self-contained prompts — mode injected, not assumed), NN-P-002, NFR-2 (performance), ADR-2.
**Exit Gate:** grep-oracles confirm concurrent-dispatch + scoped-oracle + barrier-suite + flag+mode at
every (re-)dispatch site (AC-9); VALIDATION harness INV-1/2/3/5 pass in the concurrent state; [QA] clean.

- [x] **[Implement]**

  **File changes:**
  | File | Change |
  |------|--------|
  | `plugins/spec-flow/skills/execute/SKILL.md` | MODIFY (knob def, G4, oracle, barrier, flag rule, L1192) |
  | `plugins/spec-flow/reference/deferred-commit-journal.md` | MODIFY (L74 serial-note) |

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: `deferred_commit` knob definition (lines 230-231)
  CURRENT:
  ```
  230  - `auto` — Phase Groups run the serial git-free section (Step G4) and barrier work-commit (Step G9b); the journal is written.
  231  - `off` — Phase Groups run the legacy concurrent dispatch (each sub-phase commits its own work); no journal, no barrier work-commit.
  ```
  TARGET: `auto` becomes "the **concurrent** git-free section (Step G4) — sub-phases dispatch in
  parallel on the git-free foundation when `phase_groups: auto`/`always` — and the barrier work-commit
  (Step G9b); the journal is written. (Serial dispatch remains the fallback when `phase_groups: off` or
  a single sub-phase.)" Leave `off` line unchanged. Done: `auto` documents concurrent git-free dispatch.
  Verify: `grep -n "concurrent git-free" execute/SKILL.md`.

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Step G4 header + serial paragraph + worked trace (lines 1177-1205)
  CURRENT (header L1177): "### Step G4: Dispatch sub-phase pipelines (serial git-free by default)";
  (L1181) "#### Serial git-free section (`deferred_commit: auto` — default)"; (L1183) "Dispatch the
  group's sub-phases **serially**: one sub-phase's full Red → Build cycle completes … before the next
  sub-phase dispatches."
  TARGET: rename to "Concurrent git-free section (`deferred_commit: auto` + `phase_groups: auto`/
  `always`)". Replace the serial-dispatch paragraph: "Dispatch the group's `[P]` sub-phases
  **concurrently** on the git-free foundation — each runs its full Red → Build cycle writing to the
  working tree with **NO `git add` and NO `git commit`**. Because nothing stages until the barrier
  (Step G9b), the shared-index race (Race-1) cannot occur even under concurrency. Disjointness of
  sub-phase `**Scope:**` is validated at dispatch (overlap → serial fallback, existing rule)."
  Replace the worked serial trace (L1199-1205) with a concurrent trace (sub-phases A.1/A.2/A.3 dispatch
  together; each independently advances pending→red-done→green; journal writes are per-sub-phase and
  incremental; zero per-sub-phase commits; barrier commits the union). Keep the L1183 "no shared index"
  insight but attribute it to git-free (not to serial). Done: G4 documents concurrent dispatch with a
  concurrent worked trace. Verify: `grep -n "concurrently" execute/SKILL.md` returns the G4 section.

  T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Build oracle "no Race-2 because serial" (line 1192)
  CURRENT:
  ```
  1192  - **Build** writes the production code and runs its oracle **against the working tree** … The oracle is the **existing whole-non-integration-suite invariant (Step 5 / line 499, invariant (a) "0 failed across the non-integration suite") — UNCHANGED by this phase.** Because dispatch is serial, only one sub-phase's files are in the tree mid-cycle, so the suite-wide oracle has no sibling-in-progress interference: there is **no Race-2**. Build does **not** commit (no `git commit`).
  ```
  TARGET: replace with the Race-2 scoped oracle: "**Build** writes production code and runs its oracle
  **against the working tree**, **scoped to THIS sub-phase's own Red test IDs** (the FAILED set captured
  in `phase_N_oracle_block`, re-run path-scoped per Step 3 invariant (b) at line 509 / the path-scoped
  re-run idiom at line 408). Scoping is required under concurrency: a sibling sub-phase's still-red
  tests are on the shared working tree, and an unscoped whole-suite oracle would fail spuriously
  (Race-2). The **whole-non-integration-suite green** invariant (Step 3 invariant (a), line 506) is
  re-asserted **ONCE at the barrier (Step G9b)** after every sub-phase is individually green — never
  per sub-phase under concurrency. Build does **not** commit." Correct the stale cross-ref ("line 499"
  → "line 506"). Done: L1192 documents the scoped oracle + barrier whole-suite gate; cross-ref fixed.
  Verify: `grep -n "scoped to THIS sub-phase\|phase_N_oracle_block" execute/SKILL.md` near G4; and
  `grep -n "line 499" execute/SKILL.md` returns 0 (drift corrected).

  T-4: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: G9b barrier (lines 1283+, after the Phase-1 anti-cheat block)
  TARGET: add a barrier step — "After every sub-phase is `green` and the anti-cheat blob verify (Phase
  1) passes, run the **whole-non-integration-suite** oracle ONCE over the union working tree; require
  `0 failed` (composing with pi-014's M2/M4 integration/non-integration split). A failure here is a
  group reject (existing recovery path)." Done: barrier documents the single whole-suite green gate.
  Verify: `grep -n "whole-non-integration-suite" execute/SKILL.md` returns a G9b match.

  T-5: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: flag-injection rule (lines 1185-1187)
  CURRENT: the rule injects only the `Deferred Phase Group: yes` flag at every (re-)dispatch site.
  TARGET: extend the rule so the orchestrator ALSO injects the concurrency mode + (forward ref to
  Phase 3) the runtime-isolation values at the SAME sites. Add: "Under `deferred_commit: auto` with
  concurrency, each (re-)dispatch MUST carry `Deferred Phase Group: yes` AND the sub-phase's isolation
  envelope (see Phase 3 / FR-7). A flagless or envelope-less re-dispatch reverts to serial/per-commit
  behavior and breaks the barrier." Keep the four enumerated sites (G4, G6 rows, G9b reject, resume).
  Done: the rule names flag + concurrency/isolation at all sites. Verify: `grep -n "every (re-)dispatch"
  execute/SKILL.md` shows the extended rule.

  T-6: MODIFY `plugins/spec-flow/reference/deferred-commit-journal.md`
  Anchor: serial-note (line 74)
  CURRENT: "Under `deferred_commit: auto` dispatch is **serial** … so the journal's value here is
  **crash-resume durability**, not index-contention avoidance".
  TARGET: "Under `deferred_commit: auto` dispatch is **concurrent** (git-free; staging deferred to the
  barrier removes the shared-index race — see SKILL.md Step G4). The journal's value is crash-resume
  durability AND it records per-sub-phase status for the barrier whole-suite gate; writes are
  incremental and concurrency-safe (one sub-phase entry at a time)." Done: L74 reflects concurrency.
  Verify: `grep -n "concurrent" deferred-commit-journal.md` returns L74.

- [x] **[Write-Tests]** (extend the validation harness — append cases to `validation/run.sh`)
  Append to `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh` (real git + real OS processes,
  no doubles); update VALIDATION.md with the run:
  - **INV-1/INV-5 (AC-6):** concurrent git-free writes from ≥2 sub-phases → assert the barrier commit
    equals the exact uncorrupted union (journal excluded) and the sub-phase execution windows overlap.
  - **INV-2 (AC-7):** sub-phase A's oracle scoped to A's Red IDs is green while sibling B's tests are
    red on the shared tree.
  - **INV-3 (AC-7):** the unscoped whole-suite oracle IS polluted in the identical state (proving
    scoping is necessary), and the barrier whole-suite gate is green only after all are green.

- [x] **[Verify]**
  - Run: `grep -n "concurrent" plugins/spec-flow/skills/execute/SKILL.md` — Expected: knob def + G4
    header/section + trace all say concurrent.
  - Run: `grep -n "line 499" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0 (drift fixed).
  - LLM-agent-step (AC-9 anti-drift): read the flag-injection rule (L1185-1187) and each of the 4
    re-dispatch sites (G4, G6 rows ~L1372/1373/1378, G9b reject ~L1293, resume ~L1802); confirm EACH
    names `Deferred Phase Group: yes` AND the concurrency/isolation envelope. Superseded sweep:
    `grep -n "serially\|no Race-2\|one sub-phase mid-cycle" execute/SKILL.md` — Expected: 0 hits in
    the `deferred_commit: auto` G4 section (all prior serial-only assertions removed/relocated).
  - Run: `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-1 INV-2 INV-3 INV-5` —
    Expected: `PASS` for each in the concurrent state.
- [x] **[QA]** Opus deep review vs AC-6/7/9; diff baseline: phase_2 start.
- [x] **[Progress]**

### Phase 3: INV-9 runtime isolation + serial-replay backstop (item 2, part 2)
**In scope:** inject per-sub-phase runtime isolation (unique `TMPDIR`, optional port/DB-name) + a
parallel-safety contract into the concurrent dispatch; add a serial-replay-on-failure backstop
("slower-never-wrong") in `execute/SKILL.md`. Depends on Phase 2.
**NOT in scope:** the concurrency dispatch itself (Phase 2); heavyweight per-resource declaration
schema; anti-cheat / base-ref / version.
**Steps traversed (P2):** adds a new conditional path — the serial-replay branch on a collision-
attributable concurrent-group failure. Traverses: Step G4 (isolation injection into the dispatch
envelope), Step G6 recovery (the new serial-replay triage row), the barrier (a group that fails the
whole-suite gate due to a collision triggers replay before a real reject).
**Dispatch sites (P3):** the isolation envelope is part of the dispatch contract added in Phase 2;
this phase populates its values at the same sites (G4 initial; G6 rows; G9b reject; resume). No NEW
dispatch site.
**Charter constraints honored in this phase:** NN-C-006 (serial-replay re-runs already-failed work;
no NEW destructive op; logged), NN-C-008, NFR-2 (slower-never-wrong), ADR-2.
**Exit Gate:** grep-oracles confirm isolation-injection + parallel-safety contract + serial-replay
backstop language; VALIDATION harness INV-9 (collision prevented by isolation; forced collision →
serial replay; genuine failure under replay surfaces loudly) passes; [QA] clean.

- [x] **[Implement]**

  **File changes:**
  | File | Change |
  |------|--------|
  | `plugins/spec-flow/skills/execute/SKILL.md` | MODIFY (G4 isolation envelope, G6 serial-replay row) |

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Step G4 concurrent section (the "#### Concurrent git-free section" text CREATED by Phase 2 T-2)
  CURRENT: none — this APPENDS an "INV-9 runtime isolation" subsection immediately after the Phase 2
  T-2 concurrent-dispatch paragraph (which establishes concurrent dispatch but no isolation). Locate
  the Phase-2 concurrent section by content (`#### Concurrent git-free section`).
  TARGET: add an "INV-9 runtime isolation" subsection: "Each concurrently-dispatched sub-phase receives
  an **isolation envelope** in its dispatch prompt: a unique `TMPDIR` (e.g. `$TMPDIR/sf-<group>-<n>`),
  and — only when the plan/phase declares them — isolated port and DB-name values; plus a stated
  **parallel-safety contract** (the sub-phase's tests must not assume a shared mutable global resource
  beyond what the envelope isolates). File-disjoint is NOT runtime-disjoint (INV-9): the envelope makes
  them so." Done: G4 documents the isolation envelope + parallel-safety contract.
  Verify: `grep -n "isolation envelope\|parallel-safety contract\|TMPDIR" execute/SKILL.md`.

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Step G6 auto-triage matrix (lines ~1372-1378) — ADD a row (no CURRENT to replace)
  CURRENT (the matrix column shape to match — verbatim header/row form at L1372):
  ```
  1372  | Contamination — implementer modified test files during Build (Mode: TDD) | Orchestrator's test-file diff check flagged modified tests | File-scoped reset (SPLIT form …) … | 1 |
  ```
  The table columns are `| condition | heuristic/detection | action | budget |`. Match that shape.
  TARGET: add a triage row: "**Runtime collision — concurrent group failed in a manner attributable to
  a shared runtime resource** (e.g. identical `/tmp` path, port, or DB collision; non-deterministic
  sibling-dependent failure) | heuristic: the group failed but each sub-phase passes in isolation |
  **serial-replay backstop**: re-run the whole group **serially** (one sub-phase mid-cycle at a time,
  reusing the Phase-2 serial fallback) before declaring failure; only a failure that PERSISTS under
  serial replay is a real failure (escalate). The replay is logged (NN-C-006 passive surface). Degrades
  to *slower*, never to *wrong* or *silently-green*. | 1 |". Done: G6 has the serial-replay row.
  Verify: `grep -n "serial-replay\|Runtime collision" execute/SKILL.md`.

- [x] **[Write-Tests]** (extend the validation harness — append cases to `validation/run.sh`)
  Append to `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh` (real OS processes, no doubles);
  update VALIDATION.md:
  - **INV-9 (AC-8):** reproduce the shared-`/tmp` collision (file-disjoint, runtime-shared) → assert
    the injected unique `TMPDIR` prevents it; then FORCE a collision → assert serial replay runs and a
    genuine failure under replay surfaces loudly (no silent false-green).

- [x] **[Verify]**
  - Run: `grep -n "isolation envelope\|serial-replay\|slower-never-wrong\|TMPDIR" plugins/spec-flow/skills/execute/SKILL.md`
    — Expected: G4 isolation subsection + G6 serial-replay row matches.
  - Run: `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-9` — Expected: `PASS INV-9`
    (isolation prevents collision; forced collision → serial replay; real failure surfaces loudly).
- [x] **[QA]** Opus deep review vs AC-8; diff baseline: phase_3 start.
- [x] **[Progress]**

### Phase 4: Base-ref parameterization (item 3)
**In scope:** add a default-branch resolver to `execute/SKILL.md` and thread the resolved base ref
through all six `git diff main..HEAD` sites; mirror the two `verify.md` + `verify.agent.md` sites; add
a documented `.spec-flow.yaml default_branch:` key to the config template. Independent of Phases 1-3.
**NOT in scope:** `review-board/SKILL.md` (already resolves dynamically — ADR-3); the
`merge_strategy: pr` `gh pr create --base main` site (deferred — spec Out of Scope); L270's existing
`git merge-base origin/main HEAD` form (consistency-reviewed, not literal `main..HEAD`).
**Steps traversed (P2):** no NEW conditional path through the loop — the change substitutes a resolved
variable for the literal `main` at existing diff sites and adds one resolver recipe near Final Review
Step 1. Traverses: Final Review Step 1 (L1460), Step 1a (L1469), the verify Piece-Full dispatch
(L1511), the CHANGELOG cross-check (L1557/L1559), the Step 8 amend re-entry (L1580).
**Dispatch sites (P3):** changes the `verify` agent dispatch contract (the diff it receives now uses
the resolved base). Site: the Final Review Step 1 `verify Mode: Piece Full` dispatch (L1511) + the
verify.md/verify.agent.md templates (L38/L141). No tdd-red/implementer dispatch change.
**Charter constraints honored in this phase:** CR-007 (config key documented inline), NN-C-002
(git/awk only), ADR-3.
**Exit Gate:** grep confirms zero `main..HEAD` literals remain in execute/SKILL.md + verify.md +
verify.agent.md; the resolver shell harness passes AC-10/11/12; config key documented; [QA] clean.

- [x] **[Implement]**

  **File changes:**
  | File | Change |
  |------|--------|
  | `plugins/spec-flow/skills/execute/SKILL.md` | MODIFY (resolver recipe + 6 diff sites) |
  | `plugins/spec-flow/agents/verify.md` | MODIFY (L38, L141) |
  | `plugins/spec-flow/agents/verify.agent.md` | MODIFY (L38, L141 — byte-identical twin) |
  | `plugins/spec-flow/templates/pipeline-config.yaml` | MODIFY (new `default_branch:` key) |

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Final Review Step 1 (just before line 1460, the first `git diff main..HEAD`)
  TARGET: insert a resolver recipe (FR-9): "**Resolve the diff base once** (used by every
  `git diff <base>..HEAD` below): try `default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD
  2>/dev/null | sed 's#^origin/##')`; if empty, `default_branch=$(git remote show origin 2>/dev/null |
  awk '/HEAD branch/ {print $NF}')`; if still empty, read `default_branch:` from `.spec-flow.yaml`; if
  STILL unresolved, ERROR loudly — `ERROR: cannot resolve default branch (no origin/HEAD, no origin
  remote, no .spec-flow.yaml default_branch:) — set default_branch: in .spec-flow.yaml` — and do NOT
  assume `main`." Pattern (the idiom to follow, from review-board/SKILL.md:38):
  ```
  38   Determine the default branch once: `git symbolic-ref refs/remotes/origin/HEAD` → strip to name; else try `main`, then `master`.
  ```
  (execute is STRICTER per ADR-3: config key + loud error instead of `main`/`master` guesses.)
  Done: a resolver recipe precedes the diff sites and sets `$default_branch`.
  Verify: `grep -n "symbolic-ref refs/remotes/origin/HEAD" execute/SKILL.md`.

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: the six `git diff main..HEAD` sites. CURRENT (verbatim, per site):
  ```
  1460  git diff main..HEAD
  1469     git diff main..HEAD --name-only
  1511    prompt: <verify.md + "Mode: Piece Full\n\n" + full piece diff (git diff main..HEAD) + all spec ACs (all phases, from spec.md) + "Tests verified per-phase — do NOT re-run the test suite.">,
  1557  git diff main..HEAD -- CHANGELOG.md
  1559  Compare the CHANGELOG diff against the full cumulative piece diff (`git diff main..HEAD`) to identify any artifact-level change not reflected in the CHANGELOG. …
  1580  - **On `amend` (or `amend-spec`):** the piece **re-opens**. … then jumps back to Final Review Step 1 on the new cumulative diff `git diff main..HEAD`. …
  ```
  TARGET: at each site replace `main` with `$default_branch` in shell/code contexts and with "the
  resolved default branch" in prose. Specifically:
  - L1460 (fenced bash) → `git diff "$default_branch"..HEAD`
  - L1469 (fenced bash) → `git diff "$default_branch"..HEAD --name-only`
  - L1511 (the verify-dispatch `prompt:` arg — edit ONLY the inline `git diff main..HEAD` token inside
    the parenthesis, leave the rest of the long prompt line intact) → `git diff $default_branch..HEAD`
  - L1557 (fenced bash) → `git diff "$default_branch"..HEAD -- CHANGELOG.md`
  - L1559 (prose) → "the full cumulative piece diff (`git diff $default_branch..HEAD`)"
  - L1580 (prose, long amend-re-entry paragraph — edit ONLY the `git diff main..HEAD` token, preserve
    the surrounding sentence) → "the new cumulative diff `git diff $default_branch..HEAD`"
  Done: no literal `main..HEAD` remains in execute/SKILL.md. Verify: `grep -n "main\.\.HEAD" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 0.

  T-3: MODIFY `plugins/spec-flow/agents/verify.md` AND `plugins/spec-flow/agents/verify.agent.md`
  Anchor: lines 38 and 141 (byte-identical across both files)
  CURRENT (L38): "- **Full piece diff:** `git diff main..HEAD` covering all test and implementation
  files …"; (L141): "the full piece diff (`git diff main..HEAD`) …".
  TARGET: replace `git diff main..HEAD` with `git diff <resolved default branch>..HEAD` (prose — the
  verify agent receives the diff from the orchestrator, so describe the base as the resolved default
  branch, not a literal). Apply the IDENTICAL edit to both files at both lines (keep them byte-identical).
  Done: neither verify file contains `main..HEAD`. Verify: `grep -rn "main\.\.HEAD" plugins/spec-flow/agents/verify.md plugins/spec-flow/agents/verify.agent.md` — Expected: 0.

  T-4: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`
  Anchor: after the `deferred_commit:` block (lines 48-53), mirror its comment format
  Pattern (from L42-46):
  ```
  42  # phase_groups: controls Phase Group parallel execution (new in v1.4.0)
  43  #   auto    — dispatch sub-phases concurrently when plan uses Phase Groups; fall back to serial for flat phases (default)
  ...
  46  phase_groups: auto
  ```
  TARGET: add a new key block:
  ```
  # default_branch: the base branch for `git diff <base>..HEAD` in Final Review (new in v5.2.0)
  #   <unset> — auto-detect: git symbolic-ref refs/remotes/origin/HEAD, then git remote show origin (default)
  #   <name>  — explicit override (e.g. master, trunk) when auto-detect cannot resolve
  # default_branch:
  ```
  (Leave it commented/unset so auto-detect is the default; an explicit value overrides.)
  Done: the config template documents `default_branch:` in the header-plus-per-value format.
  Verify: `grep -n "default_branch" plugins/spec-flow/templates/pipeline-config.yaml`.

- [x] **[Write-Tests]** (extend the validation harness — append cases to `validation/run.sh`)
  Append the base-ref resolver cases to `docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh`
  (real git; no doubles); update VALIDATION.md:
  - **BASE-1 (AC-10):** in a repo with `origin/HEAD → master`, the resolver returns `master`.
  - **BASE-2 (AC-11):** with no `origin/HEAD`, no `origin`, and no `default_branch:` key → non-zero/loud
    error, no silent `main`.
  - **BASE-3 (AC-12):** with `default_branch: trunk` and detection sources absent → returns `trunk`.

- [x] **[Verify]**
  - Run: `grep -rn "main\.\.HEAD" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/agents/verify.md plugins/spec-flow/agents/verify.agent.md` — Expected: 0 (AC-10).
  - Run: `grep -n "default_branch" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: the
    documented key block (AC-12).
  - Run: `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh BASE-1 BASE-2 BASE-3` —
    Expected: `PASS` for each. In THIS repo, confirm `git symbolic-ref --short refs/remotes/origin/HEAD`
    → `origin/master` → resolves `master`.
  - LLM-agent-step: confirm `verify.md` and `verify.agent.md` remain byte-identical
    (`diff -q plugins/spec-flow/agents/verify.md plugins/spec-flow/agents/verify.agent.md`).
- [x] **[QA]** Opus deep review vs AC-10/11/12; diff baseline: phase_4 start.
- [x] **[Progress]**

### Phase 5: Version bump + CHANGELOG + cross-phase consistency (item 4)
**In scope:** bump `plugin.json` + `marketplace.json` (spec-flow entry) to 5.2.0; add a `## [5.2.0]`
CHANGELOG entry; run the cross-phase schema-consistency oracle (`red_manifest_hashes` blob-SHA format
agreement) and the version-sync sweep.
**NOT in scope:** behavioral code (Phases 1-4); the qa plugin's version (untouched).
**Charter constraints honored in this phase:** NN-C-001 (plugin/marketplace sync), NN-C-007 +
CR-006 (CHANGELOG), NN-C-009 (bump all version-bearing files), CR-004 (commit format).
**Exit Gate:** plugin.json + marketplace.json both read 5.2.0; CHANGELOG has `## [5.2.0]`; cross-phase
`red_manifest_hashes` schema consistent across execute + journal + agents; version-sync sweep clean;
[QA] clean.

- [x] **[Implement]**

  **File changes:**
  | File | Change |
  |------|--------|
  | `plugins/spec-flow/.claude-plugin/plugin.json` | MODIFY (L4 version) |
  | `.claude-plugin/marketplace.json` | MODIFY (L15 spec-flow version; L24 qa UNTOUCHED) |
  | `plugins/spec-flow/CHANGELOG.md` | MODIFY (insert `## [5.2.0]`) |

  T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` — L4 `"version": "5.1.0"` → `"5.2.0"`.
  Done/Verify: `grep '"version"' plugin.json` shows `5.2.0`.

  T-2: MODIFY `.claude-plugin/marketplace.json` — L15 (spec-flow entry) `"version": "5.1.0"` →
  `"5.2.0"`; DO NOT touch L24 (qa `1.1.1`). Done/Verify: the spec-flow entry reads `5.2.0`, qa `1.1.1`.

  T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`
  Anchor: between `## [Unreleased]` (L5) and `## [5.1.0]` (L7)
  TARGET: insert (em-dash, Keep-a-Changelog, bold-lede bullets):
  ```
  ## [5.2.0] — 2026-06-05

  ### Changed
  - **Anti-cheat blob anchor (deferred Phase Groups):** the orchestrator now anchors each Red test file with `git hash-object -w` at red-done (orchestrator-owned, immutable), replacing the Red-agent's self-asserted `sha256sum` manifest (closes CWE-345). Red-test-files only; production stays trusted-by-association.
  - **Phase Group concurrency re-enabled:** under `deferred_commit: auto` + `phase_groups: auto`/`always`, sub-phases dispatch concurrently again on the git-free foundation, with a Race-2 per-sub-phase scoped oracle + a whole-suite green gate at the barrier, plus INV-9 runtime isolation (unique `TMPDIR`/port/DB) and a serial-replay backstop (slower-never-wrong). `deferred_commit: off` remains the rollback.
  - **Default-branch resolution:** Final Review and the verify agent resolve the diff base (`git symbolic-ref` → `git remote show origin` → `.spec-flow.yaml default_branch:` → loud error) instead of hardcoding `git diff main..HEAD`; works on `master`-default repos.

  ### Migration
  - In-flight journals written by ≤5.1.0 (sha256 `red_manifest_hashes`, no `anchor:` marker) resume without change — they are verified with `sha256sum` as-is. New journals carry `anchor: blob`.
  ```
  Done/Verify: `grep -n "## \[5.2.0\]" CHANGELOG.md` returns the new heading.

- [x] **[Write-Tests]** (cross-phase consistency + version sweep — grep-oracles)
  - Cross-phase schema-consistency oracle (red_manifest_hashes format): assert the blob-SHA form +
    `anchor` marker are consistent across `execute/SKILL.md`, `deferred-commit-journal.md`, and the
    agent files (no residual "SHA-256 hex digest" definition for `red_manifest_hashes`).
  - Version-sync + superseded-ordinal sweep for the bump.

- [x] **[Verify]**
  - Run: `python3 -c "import json;a=json.load(open('plugins/spec-flow/.claude-plugin/plugin.json'))['version'];b=[p['version'] for p in json.load(open('.claude-plugin/marketplace.json'))['plugins'] if p['name']=='spec-flow'][0];print(a,b);assert a==b=='5.2.0'"`
    — Expected: `5.2.0 5.2.0`, no assertion error (AC-13, NN-C-001).
  - Run: `grep -n "## \[5.2.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1 match (NN-C-007).
  - Cross-phase schema oracle: `grep -rn "SHA-256 hex digest" plugins/spec-flow/reference/deferred-commit-journal.md` — Expected: 0 for the `red_manifest_hashes` row (it now says git blob SHA); `grep -rn "git hash-object\|anchor: blob" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/reference/deferred-commit-journal.md` agree on the blob-SHA contract.
  - Superseded-ordinal sweep: `grep -rn '"version": "5.1.0"' plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` — Expected: 0 (no version-bearing file still on 5.1.0; CHANGELOG history retains `## [5.1.0]` legitimately and is NOT a version-bearing file).
- [x] **[QA]** Opus deep review vs AC-13 + overall piece coherence; diff baseline: phase_5 start.
- [x] **[Progress]**

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | Orchestrator records `git hash-object -w` blob anchor at red-done | COVERED | Phase 1 |
| AC-2  | Barrier detects tampered Red test; journal forge-resistant | COVERED | Phase 1 |
| AC-3  | Red test files only anchored; production not re-hashed | COVERED | Phase 1 |
| AC-4  | G9 sweep-modified Red file re-anchored (SF3) before barrier | COVERED | Phase 1 |
| AC-5  | ≤5.1.0 sha256 journal resumes as-is (no marker) | COVERED | Phase 1 |
| AC-6  | Concurrent sub-phase dispatch; barrier = exact union | COVERED | Phase 2 |
| AC-7  | Scoped oracle green while sibling red; whole-suite at barrier | COVERED | Phase 2 |
| AC-8  | INV-9 isolation prevents collision; serial-replay backstop | COVERED | Phase 3 |
| AC-9  | Flag + concurrency mode at every (re-)dispatch site | COVERED | Phase 2 |
| AC-10 | Resolver yields `master`; zero `main..HEAD` literals remain | COVERED | Phase 4 |
| AC-11 | All sources absent → loud error, no silent `main` | COVERED | Phase 4 |
| AC-12 | `default_branch: trunk` config fallback honored + documented | COVERED | Phase 4 |
| AC-13 | plugin.json + marketplace.json both 5.2.0; CHANGELOG `## [5.2.0]` | COVERED | Phase 5 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh ANCHOR-1` | `PASS ANCHOR-1` (journal value == `git hash-object <path>`; `git cat-file -t` == `blob`) |
| AC-2  | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh ANCHOR-2` | `PASS ANCHOR-2` (mutated test → hash ≠ stored blob; barrier fails) |
| AC-3  | file-check | `grep -n "trusted by association" plugins/spec-flow/skills/execute/SKILL.md` (G9b) | match present (production not re-hashed) |
| AC-4  | file-check | `grep -n "re-anchor\|git hash-object -w" plugins/spec-flow/skills/execute/SKILL.md` (SF3 block) | match present |
| AC-5  | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh MIG-1` | `PASS MIG-1` (no-marker journal resumes via sha256; no error/re-anchor) |
| AC-6  | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-1 INV-5` | `PASS` each (barrier commit == union; windows overlap) |
| AC-7  | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-2 INV-3` | `PASS` each (scoped green while sibling red; unscoped polluted) |
| AC-8  | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh INV-9` | `PASS INV-9` (isolation prevents collision; replay on forced collision) |
| AC-9  | agent-step | read flag rule + 4 re-dispatch sites; `grep -n "line 499\|serially" plugins/spec-flow/skills/execute/SKILL.md` in G4 | flag+mode at all sites; 0 stale hits |
| AC-10 | shell | `grep -rn "main\.\.HEAD" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/agents/verify.md plugins/spec-flow/agents/verify.agent.md` | 0 |
| AC-11 | shell | `bash docs/prds/shared/specs/pi-020-dc-harden/validation/run.sh BASE-2` | `PASS BASE-2` (all sources unset → loud error, no `main`) |
| AC-12 | shell | `grep -n "default_branch" plugins/spec-flow/templates/pipeline-config.yaml` + `…/run.sh BASE-3` | key documented; `PASS BASE-3` (returns `trunk`) |
| AC-13 | shell | `python3` parse plugin.json + marketplace.json versions; `grep "## \[5.2.0\]" CHANGELOG.md` | `5.2.0 5.2.0`; heading present |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents
will not be dispatched; no contract injection occurs.

## Parallel Execution Notes

All five phases are serial (no `[P]`). **Why serial:** every phase edits the single file
`plugins/spec-flow/skills/execute/SKILL.md` (file-contention forbids parallel dispatch), and the spec
sequences item 1 (anti-cheat) strictly before item 2 (concurrency). Phase 4 (base-ref) and Phase 5
(version) are logically independent of 1-3 but still touch `execute/SKILL.md`, so they remain serial.

## Agent Context Summary

| Phase | Track | Primary files | Oracle |
|-------|-------|---------------|--------|
| 1 | Implement | execute/SKILL.md, deferred-commit-journal.md, tdd-red(.agent).md, implementer(.agent).md | grep-oracles + VALIDATION ANCHOR-1/2, MIG-1 |
| 2 | Implement | execute/SKILL.md, deferred-commit-journal.md | grep-oracles + VALIDATION INV-1/2/3/5 |
| 3 | Implement | execute/SKILL.md | grep-oracles + VALIDATION INV-9 |
| 4 | Implement | execute/SKILL.md, verify.md, verify.agent.md, pipeline-config.yaml | grep zero `main..HEAD` + resolver harness |
| 5 | Implement | plugin.json, marketplace.json, CHANGELOG.md | version-sync + cross-phase schema oracle |
