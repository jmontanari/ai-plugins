---
charter_snapshot:
  non-negotiables: 2026-06-05
  architecture: 2026-06-10
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: exec-guardrails

**PRD Sections:** FR-011, SC-002, G-2, G-6
**Spec:** `docs/prds/exec-ready/specs/exec-guardrails/spec.md`
**Branch:** `piece/exec-ready-exec-guardrails`

## Overview

Make execute's integrity guardrails mechanical: (1) tighten the existing Red-manifest re-hash gates so a Build phase's test tampering is rejected with violating paths named, with legitimately-authored tests exempt only when declared; (2) enrich `tdd-red`'s manifest with directly-imported fixtures + same-tree `conftest.py`; (3) turn the per-piece amendment budget into a configurable diagnostic hard-cap, unifying the single `piece_amendment_count` counter and editing the spike-agent SSOT so "never hard-blocks" no longer contradicts it.

**Non-TDD mode:** all phases use Implement track + `[Write-Tests]`; the AC Coverage Matrix is generated for traceability but is not a TDD gate; QA and Final Review remain intact. Validation surface (per spec Testing Strategy): the `tests/e2e/` harness — **L1 static** (`lib/static.sh`, `assert_grep`/`assert_no_grep` over `execute/SKILL.md` prose) and **L2 contract** (`lib/contract.sh` replay-fixture checks) — plus adversarial review.

**Ordering & serialization.** `execute/SKILL.md` is the serial spine: Phases 3, 4, 6, 7 each edit a different region of it and therefore cannot be parallelized (the scheduler validates disjointness by file path; same file = serial). Phases 1, 2, 5, 8 edit disjoint files but are kept as flat serial phases for review-board readability and because the fan-out of a few small doc/agent edits does not justify Phase-Group overhead (see per-phase `Why serial:`). Dependency order: 1 (declaration surface) + 2 (manifest enrichment) → 3 (gate consumes both) → 4 (phase-exit) → 5 (qa-plan verifies the field from 1) → 6 (routing off the gate from 3) → 7 (amendment cap, independent) → 8 (version + cross-file consistency, last).

## Architectural Decisions

### ADR-1: Read AC-1 "before any commit" as path-dependent (revert-before-acceptance on the flat path; literal pre-commit on the deferred path)
**Context:** AC-1 says a tampering diff is rejected "before any commit." On the flat / `deferred_commit: off` path the implementer owns its unified commit autonomously (`implementer.md` Rule 8) — the orchestrator never holds a staged-but-uncommitted tree, so a literal pre-commit `git diff --cached` inspection is impossible without rewriting the dispatch contract. On the deferred path the orchestrator owns the barrier commit (Step G9b step 4), so its working-tree re-hash at step 1 is genuinely pre-commit.
**Decision:** Keep the existing post-commit re-hash on the flat path and reject by revert-before-acceptance (no tampered commit survives into accepted history); keep the genuinely-pre-commit working-tree re-hash on the deferred path. Both converge on the invariant "no tampered state is accepted."
**Alternatives considered:** (a) Genuine `git diff --cached` pre-commit on the flat path — rejected: requires changing the autonomous-commit contract, out of FR-011 scope, regresses the one-commit-per-phase invariant. (b) Post-commit detect + hard-route to 6c with no retry — rejected: discards the existing 2-attempt budget that AC-1's sibling wording assumes.
**Consequences:** A tampered commit transiently exists on HEAD on the flat path before revert; reachable only by the (already-hostile) implementer subprocess, never by the operator or merge. The stronger no-tampered-object-ever guarantee holds only on the deferred path. Documented in spec Out-of-Scope.
**Charter alignment:** NN-C-002 (bash/git only); NN-P-002 (tightens, no bypass).

### ADR-2: One `piece_amendment_count` counter, two thresholds — do not fork
**Context:** The deliberation architecture lens proved the proposed "fork" (a separate canonical home for the hard-cap) is a definitional contradiction: the soft-checkpoint and the hard-cap are the *same* counter (`piece_amendment_count`, one `git log --grep` recovery, one 5/1 threshold pair).
**Decision:** Model the soft-checkpoint and the hard-cap as two behaviors of the single counter in one canonical home (`execute/SKILL.md` `#### Amendment budget tracking`). Remove the per-event `(c) continue`. Edit `reference/spike-agent.md` `## Soft-checkpoint budget` so its "never hard-blocks" assertion matches the new hard-halt.
**Alternatives considered:** (a) Fork into two homes — rejected: SSOT contradiction (one counter, two homes asserting opposite halt semantics). (b) Supersede the spike-agent section entirely — rejected: that section also governs the spike-phase soft-checkpoint, which must keep continuing.
**Consequences:** A single counter governs both behaviors; readers following the cite from execute land on consistent prose. The spike-phase soft-checkpoint is untouched.
**Charter alignment:** CR-008 (single source of truth); NN-C-002; NN-P-001 (the halt is an operator gate).

### ADR-3: Dedicated conditional `**Authored-tests:**` field, not scope-reuse
**Context:** AC-3 needs Implement-track phases to declare legitimately-authored tests for exemption. Reusing the existing `**In scope:**`/`**Scope:**` list would force the orchestrator to classify a path as test-vs-prod by heuristic — ambiguity that, in a security gate, either over-exempts (reopens the hole) or false-rejects.
**Decision:** Add a new optional, conditional `**Authored-tests:**` phase-header field (absent ⇒ empty exemption set, no parse error, no warning). qa-plan verifies it iff present.
**Alternatives considered:** (a) Reuse `In scope:` + test-path heuristic — rejected (parse ambiguity in a security gate). (b) Reuse the Integration-Test Registry — rejected (M1 invariant: registry rows are `[integration]` skeleton→completed windows, not plain authored tests).
**Consequences:** One unambiguous parse source; backward-compatible (pre-piece plans have no field). New conditional field documented in three header sites of `templates/plan.md`.
**Charter alignment:** NN-C-003 (conditional/backward-compat); CR-008 (orchestrator parses an unambiguous field).

## Phases

### Phase 1: Authored-tests declaration surface
**ACs Covered:** AC-5 (declaration surface + conditional-absence half)
**In scope:** add the conditional `**Authored-tests:**` phase-header field + its semantics to `templates/plan.md` at all three flat-phase header sites
**NOT in scope:** the runtime exemption that consumes the field (Phase 3); qa-plan verification of the field (Phase 5)
**Why serial:** disjoint file from the rest, but a single trivial template edit — Phase-Group overhead unjustified; Phase 3 and Phase 5 both depend on this field being defined first.

- [x] **[Implement]**
  **File changes:** `templates/plan.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/templates/plan.md`
  Anchor: flat-phase header field block (lines 61–66), repeated at 134–143 and 201–206.
  CURRENT (61–66):
  ```
  61  **ACs Covered:** {{ac_list}}
  62  **In scope:** {{explicit_scope_list}}
  63  **NOT in scope:** {{explicit_exclusions_with_forward_phase_references}}
  64  <!-- The two fields below are REQUIRED only when this phase edits a multi-step orchestration file ...; omit otherwise. See plan SKILL.md §9c. -->
  65  **Steps traversed (P2):** {{steps_or_na}}
  66  **Dispatch sites (P3):** {{sites_or_none}}
  ```
  TARGET: After line 66 (and at the two repeated sites), add a new conditional field, guarded by an HTML comment exactly like line 64:
  ```
  <!-- OPTIONAL: list the literal test paths this phase legitimately authors. Omit if none. Listed paths are exempt from the Red-immutability reject (Implement-track only); a path that is ALSO in Red's staged manifest is a hard reject (smuggling), never an exemption. qa-plan verifies this field iff present. -->
  **Authored-tests:** {{authored_test_paths_or_omit}}
  ```
  Pattern (the existing conditional-field idiom at line 64): an HTML-comment guard immediately preceding the optional field.
  Done: all three header sites carry the commented `**Authored-tests:**` field; the comment states (a) absent ⇒ empty exemption, (b) smuggling = hard reject, (c) Implement-track only.
  Verify: `grep -c "Authored-tests:" plugins/spec-flow/templates/plan.md` returns 3.

  **Test Data:**
  - TD-1 (AC-5 decl): input = `templates/plan.md` after T-1 → expected: `grep -c "Authored-tests:"` returns `3` (all three header sites).
  - TD-2 (AC-5 conditional note): input = the HTML-comment guard text → expected: contains "hard reject" (smuggling) AND "Omit if none" (conditional-absence).

- [x] **[Write-Tests]**
  L1 static assert (in `tests/e2e/lib/static.sh`, a new `assert_grep` in the existing template-checks group, or `assert_count`): assert `templates/plan.md` contains the `**Authored-tests:**` field with the "hard reject" smuggling note and the "Omit if none" conditional note.

- [x] **[Verify]**
  Run: `grep -c "Authored-tests:" plugins/spec-flow/templates/plan.md` — Expected: `3`.
  Run: `grep -c "absent\|Omit if none" plugins/spec-flow/templates/plan.md` — Expected: ≥1 (the conditional-absence note is present).
  LLM-agent-step: read `plugins/spec-flow/templates/plan.md` around the first `**Authored-tests:**` and confirm the HTML-comment guard states "a path that is ALSO in Red's staged manifest is a hard reject."

- [x] **[QA]** Review against AC-5 (declaration half). Diff baseline: phase start SHA.

### Phase 2: tdd-red manifest enrichment (fixtures + conftest)
**ACs Covered:** AC-4 (manifest-presence half)
**In scope:** extend `tdd-red`'s manifest-production rule + output template to fold directly-imported fixtures + same-tree `conftest.py` into the SHA-256 manifest; edit both the `.md` and `.agent.md` mirror
**NOT in scope:** the gate that protects the enriched set (Phase 3); full transitive/by-name closure (out of scope per spec — deferred backlog EG-1)
**Why serial:** disjoint files from the rest, but Phase 3's gate depends on the enriched manifest existing first; trivial fan-out.

- [x] **[Implement]**
  **File changes:** `agents/tdd-red.md` (MODIFY), `agents/tdd-red.agent.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/agents/tdd-red.md`
  Anchor: Rule 10 "Emit a `## Staged test manifest`" (line 58).
  CURRENT (58):
  ```
  58  10. **Emit a `## Staged test manifest` with SHA-256 hashes.** For every path in `## Tests Written`, compute the content hash of the staged file and list it as `<path>: <sha256>`. ... In a deferred Phase Group the ORCHESTRATOR independently anchors each test file with `git hash-object -w` at red-done; your manifest is an advisory cross-check, not the integrity baseline.
  ```
  TARGET: Extend Rule 10 with the bounded enrichment rule (OQ-1 default, no transitive walk): after listing the test files, additionally resolve and list — with their `<path>: <sha256>` — the fixture/helper files each staged test **directly imports** (resolve `from X import …` / `import X` statements in the staged test to repo-relative files; skip imports that do not resolve to a repo file) plus any `conftest.py` found from the staged test's directory up to the test root. State explicitly: this is a best-effort byte-immutability enrichment, NOT a transitive closure; deep transitive chains and by-name fixture injection are a documented residual (spec Out-of-Scope / backlog EG-1).
  Done: Rule 10 prose names the direct-import resolution rule, the same-tree `conftest.py` rule, "no transitive walk," and "skip non-resolving imports."
  Verify: `grep -n "conftest\|directly import\|no transitive" plugins/spec-flow/agents/tdd-red.md` returns matches.

  T-2: MODIFY `plugins/spec-flow/agents/tdd-red.md`
  Anchor: `## Staged test manifest` output template (lines 128–131).
  CURRENT (128–131):
  ```
  128  ## Staged test manifest
  129  <one line per staged test file — `<path>: <sha256>` — emitted verbatim into the orchestrator's state for integrity reconciliation after the implementer's unified commit>
  130  - tests/path/test_foo.py: a3f5c891...
  131  - tests/path/test_bar.py: b71d2a4e...
  ```
  TARGET: Add example fixture/conftest lines and update the descriptive line to note the manifest includes directly-imported fixtures + same-tree conftest, e.g. add:
  ```
  - tests/path/conftest.py: 9c2e... (fixture — directly consumed by test_foo.py)
  - tests/path/_helpers.py: 4d8a... (directly imported by test_foo.py)
  ```
  Done: the output template shows at least one fixture/conftest example line and the descriptive line mentions the enrichment.
  Verify: `grep -n "fixture\|conftest" plugins/spec-flow/agents/tdd-red.md` returns matches in the template region.

  T-3: MODIFY `plugins/spec-flow/agents/tdd-red.agent.md`
  Anchor: Rule 9 manifest production (line 51) + output template (121–124) + anti-pattern (line 134).
  TARGET: Apply the SAME enrichment rule (T-1) to Rule 9 and the SAME template example (T-2) to lines 121–124, mirroring the `.md` edit. Keep the trimmed mirror's structure; do not import the long staging prose the mirror omits.
  Done: `.agent.md` Rule 9 + template carry the identical enrichment semantics.
  Verify: `grep -c "conftest" plugins/spec-flow/agents/tdd-red.agent.md` returns ≥1.

  **Test Data:**
  - TD-1 (AC-4 enrich): input = a staged test `test_foo.py` with `from ._helpers import x` and a same-dir `conftest.py` → expected: manifest includes `_helpers.py` and `conftest.py` each as `<path>: <sha256>`.
  - TD-2 (AC-4 bounded): input = `test_foo.py` with `import requests` (non-repo) → expected: `requests` is skipped (not in manifest), no error (the OQ-1 "skip non-resolving imports" rule).
  - TD-3 (FR-EG-10 mirror): input = `tdd-red.agent.md` after T-3 → expected: `grep -c conftest` ≥1.

- [x] **[Write-Tests]**
  L1 static assert (`lib/static.sh`): assert BOTH `tdd-red.md` and `tdd-red.agent.md` contain the enrichment rule (direct-import + conftest + "no transitive walk"). L2 fixture (`fixtures/replay/`): a Red-stage manifest fixture that includes a `conftest.py` line + a `contract.sh` assert that the manifest-capture treats it as a protected path (cross-checked in Phase 3's trip test).

- [x] **[Verify]**
  Run: `grep -l "conftest" plugins/spec-flow/agents/tdd-red.md plugins/spec-flow/agents/tdd-red.agent.md | wc -l` — Expected: `2` (both mirrors edited).
  LLM-agent-step: read `tdd-red.md` Rule 10 and confirm it states "no transitive walk" and "skip non-resolving imports" (the OQ-1 bounded rule).

- [x] **[QA]** Review against AC-4 (manifest half). Diff baseline: phase start SHA.

### Phase 3: Immutability gate — exemption composition + named-path reject (flat + deferred) + implementer contract
**ACs Covered:** AC-1, AC-2, AC-4 (trip half), AC-5 (runtime-exempt half), AC-6 (runtime smuggling half)
**In scope:** `execute/SKILL.md` gate (a) (599–607), gate (b) reconciliation expected-set (681–690), exemption-set composition after the M3 window (677), deferred barrier Step G9b (1437–1449); `implementer.md` + mirror re-dispatch contract (manifest now includes fixtures; violating paths named)
**NOT in scope:** phase-exit re-verification (Phase 4); repeated-rejection→6c routing (Phase 6); the qa-plan-side smuggling must-fix (Phase 5)
**Steps traversed (P2):** Step 2 item 6 (manifest capture — now enriched set), Step 3 item 7 gate (a) + gate (b), Step 3 items 5b/5c (named-path re-dispatch precedent), the M3 edit-window (609–677, unchanged but the exemption composes after it), Step G9b barrier integrity step 1.
**Dispatch sites (P3):** implementer (re)dispatch at Step 3 (flat) and Step G9b sub-phase re-dispatch (deferred) — both gain named-violating-paths in the re-dispatch prompt.
**Why serial:** edits `execute/SKILL.md` (same file as Phases 4/6/7) — cannot parallelize.

- [x] **[Implement]**
  **File changes:** `skills/execute/SKILL.md` (MODIFY), `agents/implementer.md` (MODIFY), `agents/implementer.agent.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: after the M3 edit-window close (line 677), before gate (a) at 599 — define the exemption set composition once. (The eval order is: M3 registry window → Red-manifest immutability → declared `**Authored-tests:**` exemption (lower precedence) → reconciliation.)
  TARGET: Add a short prose block defining `exempt_authored = { literal paths from the current phase's `**Authored-tests:**` field, if present; else ∅ }`, evaluated at LOWER precedence than Red-manifest immutability. State the precedence rule explicitly: "A path in BOTH `phase_N_red_stage_manifest` and `exempt_authored` is a HARD REJECT (smuggling guard), never an exemption." Mirror the M3 framing (line 677): plan-derived, qa-plan-reviewed, gate-tightening, never a merge path (NN-P-002).
  Worked example (2c — required: add this inline trace as an HTML comment immediately after the eval-order block in `execute/SKILL.md`, so the multi-step eval order has a concrete input→output trace):
  ```
  <!-- Example: phase manifest = {tests/test_a.py, tests/conftest.py}; Authored-tests = {tests/test_b.py}.
       Build commit touches tests/test_a.py → in manifest, not exempt → integrity fail: tests/test_a.py → reject, name path.
       Build commit creates tests/test_b.py → exempt (declared), not in manifest → passes reconciliation.
       Build commit touches tests/test_a.py AND declares it in Authored-tests → in BOTH → HARD REJECT (smuggling), exemption ignored. -->
  ```
  Done: a named `exempt_authored` set is defined with the precedence + smuggling rule, sourced only from the plan phase field, AND the inline worked-example trace (above) is present in the committed file.
  Verify: `grep -n "exempt_authored\|smuggling" plugins/spec-flow/skills/execute/SKILL.md` returns matches; `grep -c "Example: phase manifest" plugins/spec-flow/skills/execute/SKILL.md` returns 1 (the worked-example trace is committed).

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: gate (a) content-hash integrity, line 607 (the reject sentence).
  CURRENT (607):
  ```
  607  Any mismatch means the implementer modified one of Red's tests — the anti-cheat safeguard replacing pre-v2.7.0's `git diff tests/` check. Reject the phase and retry within the 2-attempt budget (the retry must recreate the commit without touching Red's tests). Escalate on second failure.
  ```
  TARGET: Reword so the reject (i) excludes any path in `exempt_authored` from the mismatch set (lower-precedence exemption; a path in both is still a reject per T-1), and (ii) NAMES the violating paths in the re-dispatch to the implementer (reuse the SKIPPED-IDs surfacing precedent at Step 3 items 5b/5c, lines 589–592). Keep "retry within the 2-attempt budget; escalate on second failure." Do NOT add any warn-and-proceed branch (AC-1 locks its absence).
  Done: gate (a) reject excludes `exempt_authored` (minus smuggled paths), names violating paths on re-dispatch, retains the 2-attempt budget, has no warn/continue branch.
  Verify: `grep -n "violating paths\|exempt_authored" plugins/spec-flow/skills/execute/SKILL.md` near gate (a) returns matches; `assert_no_grep` for "warn" / "continue anyway" at gate (a) (Write-Tests).

  T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: gate (b) reconciliation expected-set, lines 681–690.
  CURRENT (682):
  ```
  682  - **Mode: TDD:** `expected = Red's manifest paths ∪ Build's `## Files Created/Modified` paths`.
  ```
  TARGET: Add `∪ exempt_authored` to the `expected` set composition (both modes where an Implement-track phase legitimately authors a test) so a declared authored test is not flagged as a stray file (AC-5). Note that on Implement-track phases there is no Red manifest, so `exempt_authored` is the mechanism that whitelists the authored test in reconciliation.
  Done: `expected` includes `exempt_authored`; the prose states declared authored tests pass reconciliation.
  Verify: `grep -n "exempt_authored" plugins/spec-flow/skills/execute/SKILL.md` near gate (b) returns a match.

  T-4: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Step G9b barrier integrity step 1, lines 1437–1449.
  CURRENT (1449):
  ```
  1449  Any mismatch means a Build agent modified one of Red's tests ... Reject within the 2-attempt budget (re-dispatch the offending sub-phase's Build without touching Red's tests ...); escalate on second failure.
  ```
  TARGET: Apply the SAME exemption + named-path treatment as T-2 on the deferred path: exclude `exempt_authored` for the sub-phase (lower precedence; smuggled path still rejects), name the violating paths in the offending sub-phase's re-dispatch. Preserve the ≤5.1.0 `sha256sum` fallback at line 1447 unchanged (NFR-EG-3 in-flight resume escape — the hard-reject applies to fresh dispatches, not old-format resume).
  Done: G9b reject excludes `exempt_authored`, names violating paths, preserves the ≤5.1.0 fallback.
  Verify: `grep -n "exempt_authored\|violating paths" plugins/spec-flow/skills/execute/SKILL.md` near G9b returns matches; confirm line 1447 fallback prose intact.

  T-5: MODIFY `plugins/spec-flow/agents/implementer.md`
  Anchor: Rule 8 (51–63) + anti-pattern (86).
  CURRENT (63 excerpt): `**What "Red test modification" means.** Any change to a file in Red's `## Staged test manifest` ... strict and unforgiving by design.`
  TARGET: Note that Red's manifest now includes directly-imported fixtures + same-tree `conftest.py` (Phase 2), so editing those is equally rejected; and that on rejection the orchestrator re-dispatches naming the violating paths. No behavioral change to the implementer's own commit rule.
  Done: Rule 8 / anti-pattern mention the enriched manifest set + named-path re-dispatch.
  Verify: `grep -n "fixture\|conftest\|violating" plugins/spec-flow/agents/implementer.md` returns a match.

  T-6: MODIFY `plugins/spec-flow/agents/implementer.agent.md`
  TARGET: Apply the SAME edit as T-5 to the mirror.
  Done: mirror carries identical prose.
  Verify: `grep -c "fixture\|conftest" plugins/spec-flow/agents/implementer.agent.md` returns ≥1.

  **Test Data:**
  - TD-1 (AC-1 no-warn): input = gate (a) prose after T-2 → expected: `grep -nE "warn|proceed anyway" | grep -i integrity` returns nothing (no warn branch).
  - TD-2 (AC-1 named reject): input = Build commit edits `tests/test_a.py` (in manifest, not exempt) → expected: `integrity fail: tests/test_a.py`, reject, path named in re-dispatch.
  - TD-3 (AC-4 trip): input = Build commit edits a manifest-listed `tests/conftest.py` → expected: `integrity fail: tests/conftest.py`, reject (fixture enrichment is protected).
  - TD-4 (AC-5 exempt): input = Implement-track phase, `**Authored-tests:** tests/test_b.py`, Build creates `tests/test_b.py` → expected: reconciliation passes, no stray-file flag, no reject.
  - TD-5 (AC-6 smuggling): input = `**Authored-tests:** tests/test_a.py` where `tests/test_a.py` is a Red-manifest path, Build edits it → expected: HARD REJECT (exemption ignored).
  - TD-6 (AC-2 deferred): input = deferred Phase Group, a sub-phase tampers a Red test in the working tree → expected: barrier reject before the Step-G9b-step-4 commit, path named; the ≤5.1.0 `sha256sum` fallback (line 1447) still present/honored on old-format resume.

- [x] **[Write-Tests]**
  L1 static (`lib/static.sh`): AC-1 — `assert_no_grep` that gate (a) (around line 607) contains no "warn"/"proceed anyway"/"continue" branch; `assert_grep` that gate (a) and G9b name violating paths + reference `exempt_authored`. AC-2 — `assert_grep` G9b reject prose + the preserved ≤5.1.0 fallback. L2 contract (`fixtures/replay/` + `contract.sh`): AC-4 trip — a replay fixture where a Build commit edits a `conftest.py` listed in the manifest → assert the gate flags it (`integrity fail` on the conftest path). AC-5 runtime-exempt — fixture: Implement-track phase with `**Authored-tests:**` listing the test it writes → assert reconciliation passes (no stray-file flag). AC-6 runtime smuggling — fixture: `**Authored-tests:**` lists a Red-manifest path → assert hard reject (not exemption).

- [x] **[Verify]**
  Run: `grep -n "exempt_authored" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥4 hits (definition T-1, gate (a) T-2, gate (b) T-3, G9b T-4).
  Run (AC-1 structural): `grep -nE "warn|proceed anyway" plugins/spec-flow/skills/execute/SKILL.md | grep -i "integrity\|gate (a)"` — Expected: no output (no warn branch at the gate).
  Run: `grep -lc "fixture\|conftest\|violating" plugins/spec-flow/agents/implementer.md plugins/spec-flow/agents/implementer.agent.md` — Expected: both files match.
  LLM-agent-step: read the `exempt_authored` definition block and confirm "A path in BOTH ... is a HARD REJECT (smuggling guard)".

- [x] **[Refactor]** (optional) Scope: the four `execute/SKILL.md` edit regions only — ensure the `exempt_authored` term is defined once and referenced, not redefined per gate.

- [x] **[QA]** Review against AC-1, AC-2, AC-4 (trip), AC-5 (exempt), AC-6 (runtime). Diff baseline: phase start SHA.

### Phase 4: Phase-exit re-verification as a blocking finding
**ACs Covered:** AC-3
**In scope:** `execute/SKILL.md` Step 4 item 5 (line 763) — reframe the phase-exit re-hash from "already passed — no-op" into an unconditional blocking finding attributed to the phase on mismatch
**NOT in scope:** the entry-gate reject (Phase 3); `verify.md` (confirmed it carries no re-hash; phase-exit lives in execute Step 4 — do not edit verify.md)
**Steps traversed (P2):** Step 4 item 5 (phase-exit integrity), Step 5 (Refactor commit — the drift window this catches).
**Why serial:** edits `execute/SKILL.md` — cannot parallelize.

- [x] **[Implement]**
  **File changes:** `skills/execute/SKILL.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Step 4 item 5 "Test integrity", line 763.
  CURRENT (763):
  ```
  763  5. **Test integrity (Mode: TDD only; non-TDD mode: no-op).** As of v2.7.0, the primary anti-tampering safeguard runs at Step 3.7a ... By the time Step 4 runs, that gate has already passed — so no additional diff is needed here. ... If the phase produces a Refactor commit in Step 5, re-run the content-hash check ... If any hash drifts at Refactor time: REJECT, revert the refactor commit, and flag the Refactor agent for re-dispatch with the offending paths surfaced.
  ```
  TARGET: Reframe so the phase-exit re-hash of the full manifest set (incl. Phase-2 fixtures) is UNCONDITIONAL and any mismatch is a **blocking finding attributed to the phase** (REJECT + revert + re-dispatch the offending agent with violating paths named) — never "already passed / no additional diff needed / no-op." Keep the Refactor-commit re-hash as the concrete drift case but lead with the blocking-finding framing, not the "already passed" framing. Preserve `Mode: TDD only; non-TDD mode: no-op` (non-TDD has no Red manifest).
  Done: Step 4 item 5 leads with "blocking finding attributed to the phase," states the re-hash is unconditional, and no longer leads with "already passed — no additional diff is needed."
  Verify: `grep -n "blocking finding" plugins/spec-flow/skills/execute/SKILL.md` near line 763 returns a match; `assert_no_grep` for "already passed — so no additional diff is needed" as the leading framing.

  **Test Data:**
  - TD-1 (AC-3 blocking): input = Step 4 item 5 prose after T-1 → expected: contains "blocking finding"; `assert_no_grep` "already passed — so no additional diff is needed here" as the lead framing.
  - TD-2 (AC-3 drift case): input = a phase that produces a Refactor commit editing a Red test → expected: phase-exit re-hash mismatch surfaced as a blocking finding attributed to the phase (REJECT + revert + re-dispatch), never silently absorbed.

- [x] **[Write-Tests]**
  L1 static (`lib/static.sh`): AC-3 — `assert_grep` Step 4 item 5 contains "blocking finding"; `assert_no_grep` that the "already passed — so no additional diff is needed here" no-op framing is no longer the lead.

- [x] **[Verify]**
  Run: `grep -c "blocking finding" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1.
  LLM-agent-step: read Step 4 item 5 and confirm a hash mismatch is described as a blocking finding attributed to the phase, not a no-op.

- [x] **[QA]** Review against AC-3. Diff baseline: phase start SHA.

### Phase 5: qa-plan Authored-tests verification criterion
**ACs Covered:** AC-6 (qa-plan-side must-fix half)
**In scope:** add a new conditional criterion to `qa-plan.md` (after criterion 31) and `qa-plan.agent.md` (after criterion 26) verifying `**Authored-tests:**` declarations iff present
**NOT in scope:** the runtime smuggling reject (Phase 3); the field definition (Phase 1)
**Why serial:** disjoint files, but depends on Phase 1 (field defined) and mirrors the Phase-3 invariant; trivial fan-out.

- [x] **[Implement]**
  **File changes:** `agents/qa-plan.md` (MODIFY), `agents/qa-plan.agent.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/agents/qa-plan.md`
  Anchor: after criterion 31, before `## Output Format` (line 193). Pattern model: criterion 26 (line 147), the (a)–(e) activate-only-when-present cross-check.
  TARGET: Add criterion **32**: "**Authored-tests declaration (activate only when a phase carries an `**Authored-tests:**` field; absence is never a finding):** (a) each declared path is a literal test path cited in that phase's `[Implement]`/`[Verify]`/`**Scope:**`/`**In scope:**` body (no phantom declaration); (b) no declared path collides with any Red-manifest path (derivable from the plan's `[TDD-Red]`/Red-stage phases) or any `integration_registry` row. A phantom declaration or a collision (smuggling) → must-fix. Evidence: quote the phase block and the offending path." Reuse the scope-collection mechanic (criterion 11 step at line 32) to confirm a path is cited.
  Done: criterion 32 present with the activate-iff-present guard + (a)/(b) + smuggling must-fix.
  Verify: `grep -n "Authored-tests declaration" plugins/spec-flow/agents/qa-plan.md` returns a match; criterion numbered 32.

  T-2: MODIFY `plugins/spec-flow/agents/qa-plan.agent.md`
  Anchor: after criterion 26 (the mirror is trimmed to 1–26), before `## Output Format`.
  TARGET: Add the SAME criterion as T-1 but numbered **27** (the mirror's next number). Keep the trimmed mirror's terser style.
  Done: mirror criterion 27 present with identical semantics.
  Verify: `grep -n "Authored-tests declaration" plugins/spec-flow/agents/qa-plan.agent.md` returns a match.

  **Test Data:**
  - TD-1 (AC-6 clean): input = `plan-*.md` fixture with a valid `**Authored-tests:** tests/test_b.py` cited in the phase body, not colliding → expected: criterion 32/27 raises no finding.
  - TD-2 (AC-6 collision): input = `**Authored-tests:**` lists a path that is also a Red-manifest path → expected: must-fix (smuggling).
  - TD-3 (AC-6 phantom): input = `**Authored-tests:**` lists a path NOT cited anywhere in the phase body → expected: must-fix (phantom declaration).
  - TD-4 (conditional-absence): input = a plan fixture with no `**Authored-tests:**` field → expected: no finding.

- [x] **[Write-Tests]**
  L2 contract (`fixtures/replay/` + `contract.sh`): AC-6 qa-plan — a `plan-*.md` fixture declaring an `**Authored-tests:**` path that collides with a Red-manifest path → assert qa-plan would must-fix; a clean-declaration fixture → no finding; a no-field fixture → no finding (conditional-absence).

- [x] **[Verify]**
  Run: `grep -l "Authored-tests declaration" plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-plan.agent.md | wc -l` — Expected: `2`.
  LLM-agent-step: read the new criterion in both files and confirm "absence is never a finding" and "collision ... must-fix" both appear.

- [x] **[QA]** Review against AC-6 (qa-plan half). Diff baseline: phase start SHA.

### Phase 6: Repeated-rejection → Step 6c routing
**ACs Covered:** AC-9
**In scope:** `execute/SKILL.md` Step 6c — add a discovery source for the 2nd immutability rejection (`source_agent: orchestrator`, `default_triage: amend`), conforming to the existing aggregation record schema; `.discovery-log.md` format unchanged
**NOT in scope:** the gate that produces the rejection (Phase 3); the discovery-log row format (unchanged)
**Steps traversed (P2):** Step 3.7 gate (a) reject (the 2nd-failure escalation point), Step 6c aggregation (source list 991–1004), Step 6c triage prompt (1036–1052).
**Dispatch sites (P3):** none new (reuses the existing Step 6c triage dispatch).
**Why serial:** edits `execute/SKILL.md` — cannot parallelize; depends on Phase 3's gate.

- [x] **[Implement]**
  **File changes:** `skills/execute/SKILL.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: Step 6c aggregation sources, after source 3 (missing-prerequisite escalation, line 1004). Schema model: the aggregation record (991–999).
  CURRENT (1004 excerpt): source 3 captures the Build-oracle missing-prerequisite escalation with `default_triage: "amend"`, `source_agent: "implementer"`.
  TARGET: Add source 4: "**Repeated immutability rejection.** When gate (a) / Step G9b rejects the same phase a 2nd time within the 2-attempt budget (the implementer cannot complete without touching Red's tests), the orchestrator captures a discovery with `default_triage: "amend"`, `source_agent: "orchestrator"` (VOQ-4: the orchestrator detects the reject), `ac_id: "—"`, and `row_text` = the named violating paths + 'repeated immutability rejection — plan/test-data likely under-scoped'. This routes to plan-incompleteness; it NEVER auto-exempts the touched test — mutability is reachable only via a plan amendment re-reviewed by qa-plan and re-gated by per-phase QA."
  Done: source 4 present, conforms to the 991–999 record schema, uses `orchestrator`/`amend`, states "never auto-exempts."
  Verify: `grep -n "Repeated immutability rejection\|source_agent: .orchestrator" plugins/spec-flow/skills/execute/SKILL.md` returns matches.

  **Test Data:**
  - TD-1 (AC-9 routing): input = a phase where the Build agent tampers a Red test on BOTH attempts (2nd immutability rejection) → expected: a single Step 6c discovery row, `Source agent = orchestrator`, `Triage choice = amend`, `row_text` names the violating paths.
  - TD-2 (AC-9 never-exempt): input = the same 2nd-rejection event → expected: the gate (a) exemption set is unchanged by the routing (the touched test is NOT auto-added to `exempt_authored`).

- [x] **[Write-Tests]**
  L1 static (`lib/static.sh`): assert Step 6c lists the repeated-immutability-rejection source with `source_agent: orchestrator` + `default_triage: amend` + "never auto-exempts". L2 contract (`contract.sh check_discovery_log`): a replay fixture with a persistently-tampering Build → assert a single `.discovery-log.md` row, `Source agent = orchestrator`, `Triage choice = amend`, and the exemption set unchanged.

- [x] **[Verify]**
  Run: `grep -c "Repeated immutability rejection" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1.
  Run: `grep -n "never auto-exempt" plugins/spec-flow/skills/execute/SKILL.md` — Expected: a match in Step 6c.
  LLM-agent-step: read Step 6c source 4 and confirm it conforms to the aggregation record schema (row_text/default_triage/source_agent/ac_id).

- [x] **[QA]** Review against AC-9. Diff baseline: phase start SHA.

### Phase 7: Amendment hard-cap — config key + diagnostic halt + counter unify + SSOT edit
**ACs Covered:** AC-7, AC-8, AC-10
**In scope:** `templates/pipeline-config.yaml` (new `amendment_budget` key); `execute/SKILL.md` amendment block (1211–1263: read config, remove `(c) continue`, diagnostic hard-halt reusing `(b) block`, single counter); `reference/spike-agent.md` (edit "never hard-blocks")
**NOT in scope:** a second counter (AC-10 forbids); the 1-spec sub-cap as a config key (stays a fixed constant); an off/unlimited sentinel (AC-8 forbids)
**Steps traversed (P2):** Step 0 config load (new key), the `#### Amendment budget tracking` block (counters 1215–1218, recovery 1220–1225, pre-dispatch check 1227–1232, soft-checkpoint prompt 1241–1263), every amend site that routes through the checkpoint (Step 6c, Final Review, reflection).
**Why serial:** edits `execute/SKILL.md` — cannot parallelize; otherwise independent of the immutability chain (shares only the discovery-log escalation substrate).

- [x] **[Implement]**
  **File changes:** `templates/pipeline-config.yaml` (MODIFY), `skills/execute/SKILL.md` (MODIFY), `reference/spike-agent.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`
  Anchor: after the `qa_max_iterations` key block (lines 62–70).
  CURRENT (pattern, 62–70): the `qa_max_iterations` comment block (purpose + value enumeration + governs/does-not-govern note + key).
  TARGET: Add an `amendment_budget` key modeled on that idiom (CR-007):
  ```
  # amendment_budget: per-piece amendment hard-cap (new in v5.12.0)
  #   <int> — the total number of amendments allowed for one piece before execute
  #           HALTS with a diagnostic "why are we here?" escalation (default 5).
  #           Reaching it is a hard stop, not a soft checkpoint — there is no
  #           per-event continuation. The operator may raise this value and resume
  #           (an attended decision) or route to fork/block. There is NO off/unlimited
  #           sentinel — the cap is always a finite integer.
  #   Governs: the per-piece amendment checkpoint (Step 6c, Final Review, reflection).
  #   Does NOT govern: the 1-spec-amendment sub-cap (a fixed documented constant), the
  #   oracle 2-attempt build budget, or the spike-phase soft-checkpoint.
  amendment_budget: 5
  ```
  Done: the key is present with the documented default 5, the "no off/unlimited sentinel" note, and the governs/does-not-govern lines.
  Verify: `grep -n "amendment_budget" plugins/spec-flow/templates/pipeline-config.yaml` returns the key + comment.

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: the soft-checkpoint four-option prompt (1241–1263) + the merged prompt (1229) + pre-dispatch routing (1231–1232).
  CURRENT (1243–1248 prompt incl. `(c) continue`; 1253 the on-`c` branch; 1263 the cite).
  TARGET: (i) Read `amendment_budget` at Step 0 with the existing config idiom (valid value: positive int; default 5 when absent; malformed → one-line warning + default 5; NN-C-003). (ii) Replace the soft-checkpoint with a hard-cap: when `piece_amendment_count` reaches `amendment_budget`, HALT with a diagnostic escalation that (a) frames it as "this piece may be under-scoped — is a larger spec/plan change needed?", (b) summarizes the amendment history (the `git log --grep '^chore(plan): amend'` canonical count + the `.discovery-log.md` amend rows when present), (c) offers the operator: raise `amendment_budget` and resume, fork (`f`), defer (`d`), or block (`b`) — but NO `(c) continue` per-event option. Reuse the existing `(b) block` flow (status→`blocked`, manifest commit) as the halt mechanism. Remove `(c) continue` from the prompt (1244), the merged prompt (1229), and the on-`c` branch (1253). Keep exactly ONE counter `piece_amendment_count` (AC-10 — do not add a second counter/home).
  Done: no `(c) continue` affordance remains; the hard-cap reads `amendment_budget`, halts with the diagnostic escalation, reuses `(b) block`; the 1263 cite still points at spike-agent (now consistent).
  Verify: `grep -nc "(c) continue\|continue amending" plugins/spec-flow/skills/execute/SKILL.md` — Expected: `0`. `grep -n "amendment_budget" plugins/spec-flow/skills/execute/SKILL.md` returns the read + check.

  T-3: MODIFY `plugins/spec-flow/reference/spike-agent.md`
  Anchor: `## Soft-checkpoint budget` (67–84), lines 74/76/81.
  CURRENT (74/76/81):
  ```
  74  Default thresholds: 5 total; 1 spec sub-cap.
  76  At threshold: prompt the operator `continue / fork / defer / block`. Re-surface on each subsequent amendment.
  81  Count never resets within a piece; never hard-blocks (only the operator's `block` choice halts execution).
  ```
  TARGET: Edit so the SSOT matches the new behavior (AC-10): line 74 note that the total is the configurable `.spec-flow.yaml` `amendment_budget` (default 5), spec sub-cap a fixed constant 1; line 76 drop `continue` from the menu (`fork / defer / block` + raise-and-resume); line 81 change "never hard-blocks" → "the spike-phase soft-checkpoint never hard-blocks; the configurable `amendment_budget` amendment hard-cap halts at its threshold (no per-event continuation)." Keep the spike-phase soft-checkpoint semantics (it still continues) distinct from the amendment hard-cap.
  Done: lines 74/76/81 no longer contradict the hard-cap; the spike-phase vs amendment distinction is explicit.
  Verify: `grep -n "never hard-blocks" plugins/spec-flow/reference/spike-agent.md` — Expected: only the qualified "spike-phase soft-checkpoint never hard-blocks" form remains (no bare "never hard-blocks" applying to amendments).

  **Test Data:**
  - TD-1 (AC-7 halt): input = a piece reaching `amendment_budget` amendments → expected: hard halt + diagnostic "why are we here / under-scoped?" escalation summarizing amendment history; NO `(c) continue` affordance.
  - TD-2 (AC-7 default-absent): input = `.spec-flow.yaml` with no `amendment_budget` key → expected: defaults to 5, no warning.
  - TD-3 (AC-7 default-malformed): input = `amendment_budget: banana` → expected: one-line warning + default 5 (NN-C-003).
  - TD-4 (AC-8 resume): input = operator raises `amendment_budget` to 8 and resumes a halted piece → expected: execution continues from journal state.
  - TD-5 (AC-8 no-sentinel): input = `amendment_budget: off` → expected: no off/unlimited sentinel is honored (treated as malformed → warning + default 5).
  - TD-6 (AC-10 single counter): input = `execute/SKILL.md` after T-2 → expected: exactly one `piece_amendment_count` recovery definition; no second counter/home introduced.
  - TD-7 (AC-10 SSOT): input = `spike-agent.md` after T-3 → expected: no bare "never hard-blocks" applying to amendments (only the qualified spike-phase form).

- [x] **[Write-Tests]**
  L1 static (`lib/static.sh`): AC-7 — `assert_no_grep` `(c) continue`/`continue amending` in `execute/SKILL.md`; `assert_grep` the diagnostic escalation + `amendment_budget` read. AC-8 — `assert_no_grep` any off/unlimited/`amendment_budget: off` sentinel; `assert_grep` "raise ... and resume". AC-10 — `assert_count` `piece_amendment_count` recovery appears once (single counter); `assert_no_grep` a bare "never hard-blocks" in spike-agent.md. L2 config (`fixtures/live-project/.spec-flow.yaml`): absent key → default 5; malformed → warning + default 5.

- [x] **[Verify]**
  Run: `grep -c "(c) continue\|continue amending" plugins/spec-flow/skills/execute/SKILL.md` — Expected: `0`.
  Run: `grep -c "amendment_budget" plugins/spec-flow/templates/pipeline-config.yaml plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 in each.
  Run: `grep -c "piece_amendment_count = \|piece_amendment_count =" plugins/spec-flow/skills/execute/SKILL.md` — Expected: 1 recovery definition (single counter).
  Run: `grep -n "never hard-blocks" plugins/spec-flow/reference/spike-agent.md` — Expected: only the "spike-phase soft-checkpoint never hard-blocks" qualified form.
  LLM-agent-step: read `pipeline-config.yaml` `amendment_budget` and confirm default 5 + "NO off/unlimited sentinel".

- [x] **[QA]** Review against AC-7, AC-8, AC-10. Diff baseline: phase start SHA.

### Phase 8: Version bump + CHANGELOG + cross-file consistency sweep
**ACs Covered:** AC-11
**In scope:** bump `plugin.json` + `marketplace.json` (spec-flow entry only) to 5.12.0; CHANGELOG `### Changed` migration-note entry; cross-file consistency sweep (dual-mirror pairs from Phases 2/3/5, version trio, no stale `(c) continue` references)
**NOT in scope:** any behavioral edit (this phase is packaging + verification only)
**Why serial:** must run LAST — verifies the cumulative diff from all prior phases.

- [x] **[Implement]**
  **File changes:** `plugin.json` (MODIFY), `.claude-plugin/marketplace.json` (MODIFY), `CHANGELOG.md` (MODIFY)

  T-1: MODIFY `plugins/spec-flow/plugin.json`
  Anchor: line 4 `"version": "5.11.0"`.
  TARGET: bump to `"version": "5.12.0"` (minor — new guardrail behavior; the `(c) continue` removal is backward-compatible within the major per NN-C-003 config-defaults).
  Done: version is 5.12.0.
  Verify: `grep '"version"' plugins/spec-flow/plugin.json` shows 5.12.0.

  T-2: MODIFY `.claude-plugin/marketplace.json`
  Anchor: line 15 — the spec-flow entry `"version": "5.11.0"` (do NOT touch the different plugin's entry at line 24, v1.1.1).
  TARGET: bump the spec-flow entry to 5.12.0 to match `plugin.json` (NN-C-001 sync).
  Done: spec-flow marketplace entry is 5.12.0; the other plugin entry is unchanged.
  Verify: `grep -n '"version": "5.12.0"' .claude-plugin/marketplace.json` returns the spec-flow entry; `grep -c '1.1.1' .claude-plugin/marketplace.json` unchanged.

  T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`
  Anchor: `## [Unreleased]` (line 5); head release `## [5.11.0] — 2026-06-10`.
  TARGET: Add a `## [5.12.0]` section (or populate `[Unreleased]`→`[5.12.0]`) with: `### Added` (test-immutability mechanical reject incl. fixture/conftest manifest enrichment + `**Authored-tests:**` exemption + qa-plan criterion; `amendment_budget` config key) AND `### Changed` carrying the behavioral break with a migration note: "Removed the per-event `(c) continue` soft-checkpoint option at the amendment budget; reaching `amendment_budget` (default 5) now HALTS with a diagnostic escalation. Migration: set `amendment_budget` in `.spec-flow.yaml` to tune the cap; raise-and-resume replaces per-event continue." (CR-006 Keep-a-Changelog; the break is `### Changed`, not `### Added`.)
  Done: a 5.12.0 entry exists with the `(c) continue` removal under `### Changed` + a migration note.
  Verify: `grep -n "5.12.0" plugins/spec-flow/CHANGELOG.md` returns a match; the `(c) continue` removal appears under `### Changed`.

  **Test Data:**
  - TD-1 (AC-11 version sync): input = `plugin.json` + spec-flow `marketplace.json` entry after T-1/T-2 → expected: both `5.12.0`; the unrelated v1.1.1 plugin entry untouched; no `5.11.0` remains for spec-flow.
  - TD-2 (AC-11 mirror parity): input = the three agent pairs → expected: `tdd-red.md`+`.agent.md` both match `conftest`; `implementer.md`+`.agent.md` both match `fixture`/`violating`; `qa-plan.md`+`.agent.md` both match `Authored-tests declaration`.
  - TD-3 (AC-11 CHANGELOG): input = `CHANGELOG.md` after T-3 → expected: a `5.12.0` section with the `(c) continue` removal under `### Changed` + a migration note (not `### Added`).

- [x] **[Write-Tests]**
  L1 static (`lib/static.sh`): version-sync assert (`plugin.json` == spec-flow `marketplace.json` entry); CHANGELOG `### Changed` contains the `(c) continue` removal. Cross-file mirror sweep: for each edited agent pair (`tdd-red`, `implementer`, `qa-plan`), assert both `.md` and `.agent.md` carry the new feature token (`conftest` for tdd-red; `fixture`/`violating` for implementer; `Authored-tests declaration` for qa-plan).

- [x] **[Verify]** (cross-phase consistency oracle — see ## Cross-Phase Schema Consistency)
  Run: `grep -h '"version"' plugins/spec-flow/plugin.json; grep '"version": "5.12.0"' .claude-plugin/marketplace.json` — Expected: both 5.12.0.
  Run (mirror parity): `for a in tdd-red implementer qa-plan; do echo -n "$a: "; grep -lc "conftest\|fixture\|Authored-tests declaration" plugins/spec-flow/agents/$a.md plugins/spec-flow/agents/$a.agent.md | tr '\n' ' '; echo; done` — Expected: each agent's `.md` and `.agent.md` both match.
  Run (no stale references): `grep -rn "(c) continue\|continue amending" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/reference/spike-agent.md` — Expected: no output.
  Run (superseded version sweep): `grep -rn "5.11.0" plugins/spec-flow/plugin.json .claude-plugin/marketplace.json` — Expected: no output (spec-flow no longer at 5.11.0; only the unrelated v1.1.1 plugin remains untouched).
  LLM-agent-step: read CHANGELOG 5.12.0 and confirm the `(c) continue` removal is under `### Changed` with a migration note.

- [x] **[QA]** Review against AC-11. Diff baseline: phase start SHA.

## Cross-Phase Schema Consistency

Two cross-phase invariants span ≥2 phases and are verified in Phase 8's `[Verify]`:

1. **Dual-mirror parity (Phases 2, 3, 5 → verified Phase 8).** Every agent edited as a `.md`/`.agent.md` pair must carry the same new feature in both files: `tdd-red` (conftest/fixture enrichment), `implementer` (enriched-manifest + named-path note), `qa-plan` (the Authored-tests criterion, at divergent numbers 32 vs 27). Check: `grep -lc <token>` returns both files for each pair.
2. **`exempt_authored` term consistency (Phase 3, internal).** The exemption set is defined once (T-1) and referenced by gate (a) (T-2), gate (b) (T-3), and G9b (T-4) — never redefined. Check: the definition block is the single authoritative description; the three consumers reference it.

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Flat-path Build diff touching Red manifest rejected before accept, paths named, no warn branch | COVERED | Phase 3 |
| AC-2 | Deferred-group barrier rejects tampering before barrier commit, paths named | COVERED | Phase 3 |
| AC-3 | Phase-exit re-hash mismatch is a blocking finding, not a no-op | COVERED | Phase 4 |
| AC-4 | tdd-red manifest includes directly-imported fixtures + same-tree conftest; a Build edit trips reject | COVERED | Phase 2 (manifest), Phase 3 (trip) |
| AC-5 | Declared Authored-tests path is exempt; absent field ⇒ empty exemption, no error | COVERED | Phase 1 (declaration), Phase 3 (runtime exempt) |
| AC-6 | Authored-tests path also in Red manifest = hard reject (runtime) + qa-plan must-fix | COVERED | Phase 3 (runtime), Phase 5 (qa-plan) |
| AC-7 | amendment_budget hard halt + diagnostic escalation, no per-event soft-continue; absent/malformed ⇒ default 5 | COVERED | Phase 7 |
| AC-8 | Operator raise-and-resume continues from journal; no off/unlimited sentinel | COVERED | Phase 7 |
| AC-9 | 2nd immutability rejection → Step 6c row (source_agent orchestrator, default_triage amend), never auto-exempt | COVERED | Phase 6 |
| AC-10 | Exactly one piece_amendment_count counter/home; spike-agent SSOT no longer says "never hard-blocks" | COVERED | Phase 7 |
| AC-11 | Mirror pairs edited, version trio synced, CHANGELOG ### Changed migration note | COVERED | Phase 8 |

All ACs COVERED — no NOT COVERED rows.

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -nE "warn|proceed anyway" plugins/spec-flow/skills/execute/SKILL.md \| grep -i integrity` | no output (no warn branch at gate (a)) |
| AC-1 | file-check | `grep -c "violating paths\|exempt_authored" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 near gate (a) |
| AC-2 | shell | `grep -n "exempt_authored\|violating paths" plugins/spec-flow/skills/execute/SKILL.md` near G9b (line ~1449) | match; line 1447 ≤5.1.0 fallback intact |
| AC-3 | shell | `grep -c "blocking finding" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 |
| AC-4 | agent-step | L2 fixture: Build edits a manifest-listed `conftest.py` → gate emits `integrity fail` on that path | reject trips on the conftest |
| AC-5 | shell | `grep -c "Authored-tests:" plugins/spec-flow/templates/plan.md` | `3` |
| AC-5 | agent-step | L2 fixture: Implement phase declares the test it writes → reconciliation passes | no stray-file flag |
| AC-6 | agent-step | L2 fixture: Authored-tests lists a Red-manifest path | runtime hard reject AND qa-plan must-fix |
| AC-7 | shell | `grep -c "(c) continue\|continue amending" plugins/spec-flow/skills/execute/SKILL.md` | `0` |
| AC-8 | shell | `grep -c "amendment_budget: off\|unlimited" plugins/spec-flow/templates/pipeline-config.yaml plugins/spec-flow/skills/execute/SKILL.md` | `0` |
| AC-9 | shell | `grep -c "Repeated immutability rejection" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 (source_agent orchestrator) |
| AC-10 | shell | `grep -n "never hard-blocks" plugins/spec-flow/reference/spike-agent.md` | only the qualified "spike-phase soft-checkpoint" form |
| AC-11 | shell | `grep '"version"' plugins/spec-flow/plugin.json; grep '"version": "5.12.0"' .claude-plugin/marketplace.json` | both 5.12.0 |

## Contracts

No TDD-track phases in this plan (all phases are Implement track, `tdd: false`) — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs.

## Parallel Execution Notes

No `[P]` parallelism in this plan. `execute/SKILL.md` is edited by Phases 3, 4, 6, 7 (a serial spine — same file, cannot parallelize). The remaining phases (1 template, 2 tdd-red, 5 qa-plan, 8 packaging) edit disjoint files but are kept serial per their `Why serial:` lines: the fan-out of a few small doc/agent edits does not justify Phase-Group overhead, and the dependency chain (1+2 → 3 → 4 → 5 → 6 → 7 → 8) is mostly linear. No Phase 0 Scaffold — no shared coordination file is append-contended (each phase edits distinct regions/files; the e2e `lib/*.sh` test files are appended by `[Write-Tests]` steps which the executor serializes within a phase).
