# Learnings — dispatch-integrity (spec-flow 5.10.0)

Change-track piece hardening the execute/review-board dispatch contract from 4 field-verified
backlog findings. 7 Implement-track phases (doc-as-code) + 2 amendment cycles. Ran on an Opus
orchestrator (model-check overridden).

## Patterns that worked well

- **Inside-out build order.** Phase 1 defined the two contracts (WORKTREE preamble + manifest
  ownership) once in `coordinator-contract.md`; every later phase cited it rather than re-deriving.
  No paraphrase drift; a single `WORKTREE:` grep token verifies coverage everywhere.
- **Synchronous discovery triage held under a real event.** Phase 2 surfaced that the plan's
  "all agent twins identical" assumption was wrong (4 divergent pairs + 2 singletons + 1
  frontmatter stub). It was triaged at discovery time as `amend-spec`, committed before Phase 3
  proceeded (Phase 3 depends on the Phase-2 contract), and did not cascade. The single spec-amend
  budget (1/1) held.
- **Explicit "Parallel Execution Notes" earned its place.** The plan considered and rejected a
  Phase 2+3 Phase Group ("disjoint files, but small volume"). Correct: Phase 2's spec-amend would
  have forced a mid-group block or a stale-spec Phase 3. Surfacing parallelism eligibility at plan
  time prevented that.
- **Fix-as-we-go on plugin self-improvement.** End-of-piece reflection findings were fixed in-piece
  (merge-base diff base, duplicate heading, twin reconciliation, provenance-aware exemption) rather
  than deferred — appropriate when the piece IS improving the tool that runs it.

## Issues QA caught (the adversarial gates earned their keep)

Every net-new-mechanism phase (4, 5, 6) AND the Final Review board found real must-fix defects —
6 of 6 must-fix defects concentrated in the 3 net-new-logic phases; the 4 mechanical phases
(1, 2, 3, 7) had zero.

- **Phase 4 (Opus QA):** G9 manifest sweep was blind under `deferred_commit: auto` (committed-range
  diff empty pre-barrier). Fixed to working-tree union, then refined again at board to *unfiltered*
  `git status --porcelain` (scope-union filter was hiding out-of-scope manifest writes).
- **Phase 5 (Opus QA):** the precondition would have **deadlocked every change-track merge** (no
  manifest in change-track) — needed a `track = "change"` carve-out. Then the board found the
  Phase-5 QA *fix itself* had introduced a regression: the OR-form (git-log OR manifest-content)
  is bypassable after the documented `git revert` (revert leaves the old commit in log history) —
  reintroducing the exact premature-merge bug FR-3 targets. Fixed to content-at-HEAD authoritative.
- **Phase 6 (Opus QA):** the READY-TO-COMMIT marker text told the agent to "stage" in the
  deferred-group path where staging is forbidden — scoped the marker to flat-phase / `off`.
- **Final Review board:** flat Step 6b sweep was **dead when no `.pre-commit-config.yaml` exists**
  (this repo's case) — a blocking guard placed inside a conditionally-skipped block. Made it
  unconditional.

## Recommendations for future specs

- **Net-new-mechanism phases need scenario-table ACs.** Each Phase 4/5/6 defect was an *interaction
  axis* the AC named the goal but not the matrix for: `deferred_commit: auto`×`off`,
  `track: piece`×`change`, flat×Phase-Group. When a plan/ADR marks a phase "net-new mechanism,"
  the AC should enumerate the interaction axes it must hold under.
- **Grep `[Verify]` confirms presence, not correctness.** Phases 4/5/6 all passed their grep
  `[Verify]` (the token was present) while the surrounding logic was wrong — caught only by Opus QA.
  For net-new-mechanism doc-as-code phases, the `[Verify]` should include a *scenario-specific*
  read-and-confirm ("confirm the sweep runs when `.pre-commit-config.yaml` is absent"), not a broad
  "read and confirm coherent."
- **Re-review the QA fix, not just the QA finding.** The Phase-5 fix introduced a new bug caught
  only at Final Review. A per-phase QA fix to net-new logic deserves one bounded adversarial pass
  over the *fix diff* before the phase closes.
- **"Guard inside a conditionally-skipped block" is a detectable class.** When adding a numbered
  sub-item to a step that has a skip preamble, state the item's own conditionality
  (unconditional / only-when-X) rather than letting it silently inherit the parent's skip path.
- **Diff base should be `merge-base`, not `default_branch..HEAD`.** Master advanced mid-session and
  the raw two-dot diff showed 144 files / 9435 spurious deletions; merge-base gave the true 62-file
  piece diff. (Fixed in-piece for execute's Final Review.)
