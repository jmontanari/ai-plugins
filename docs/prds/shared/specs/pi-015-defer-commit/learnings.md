# Learnings — shared/pi-015-defer-commit (spec-flow 5.0.0)

The deferred-commit / git-free parallel-TDD model for the `execute` orchestrator: under the new
default `deferred_commit: auto`, a Phase Group runs serial + git-free and lands ONE barrier
work-commit, made resumable by a Tier-1 journal and sibling-safe by file-scoped recovery.

## Patterns that worked well

- **ADR-5 "don't dogfood the unfixed machinery on yourself."** This piece fixes the parallel
  Phase-Group commit-stage race, so it authored its own phases as serial flat phases rather than a
  parallel Phase Group — refusing to run its own edits through the very machinery it repairs. Result:
  zero per-phase circuit-breaker hits, zero contamination/scope-violation events across all 7 phases.
  Worth codifying as a plan-authoring heuristic: a piece modifying orchestration machinery it would
  itself run under should self-exclude from that machinery until it ships.

- **FR-8 trivial-diff QA-skip predicate held with zero leakage.** Opus QA was skipped on Phase 2
  (config/gitignore) and Phase 7 (version bump) per the predicate; the entire end-of-piece must-fix
  cluster was in `execute/SKILL.md` (the orchestration-logic phases that DID get Opus QA), none in the
  skipped mechanical phases. The "trivial diff" boundary was accurate.

- **Structural-grep `[Verify]` oracles for docs-as-code (the pi-014 convention).** All 7 phases were
  Implement-track with grep oracles gating documented-trace presence; runtime behavior was pre-proven
  separately by the 9-invariant harness (VALIDATION.md). The orchestrator independently re-ran every
  oracle, catching nothing the agents missed but confirming each phase cheaply.

- **Empirical verification by the ground-truth reviewer.** The board's ground-truth reviewer ran real
  git in scratch repos to confirm load-bearing claims (bare `git commit -- <untracked>` fails;
  `git restore --source` aborts on created paths; `git diff -- <path>` omits untracked files; the
  2-vs-N+1 commit math). This caught the recovery-`git restore`-aborts-on-created-files defect that
  pure prose review would have rated plausible-but-correct.

## Issues QA caught (and where)

The defining signal of this piece: **every per-phase QA returned must-fix = None, yet the end-of-piece
Final Review board found ~6 distinct must-fix cross-step wiring gaps** requiring 3 fix iterations.
100% of the cluster was raised by the whole-system reviewers (blind / edge-case / ground-truth /
integration); 0 by the per-artifact reviewers (architecture / spec-compliance / prd-alignment /
security — all PASS on iter-1). The gaps:

- The `deferred_commit` knob was branched on but **never actually read** by any step.
- The deferred-group flag was **never injected** into the sub-phase agent prompts — and, after the
  first fix, was injected only at the initial G4 dispatch, not at the G6-recovery / G9b-reject /
  resume re-dispatch sites (a flagless re-dispatch silently reverts to per-sub-phase commits).
- Pre-barrier steps (G7/G8/Pass-2) derived their file set from `git diff $group_start_sha..HEAD`,
  which is **empty under the git-free model** until the barrier commit.
- The auto-triage recovery `git restore` was applied over the **full scope (modified + created)**,
  which aborts on created paths and silently leaves modified files un-restored.
- The G6 recovery **never wrote the journal status back**, so a mid-group resume would re-reset
  already-good work.
- The anti-cheat doc **over-claimed** parity with the flat-phase HEAD-hash gate (it is strictly
  weaker — test-files-only, production trusted by association).

Root cause: per-phase QA scopes its diff to one phase's region of a single large file; it structurally
cannot see a new conditional path failing to reconcile with the *surrounding* pre-existing steps that
no single phase edits.

## Recommendations for future specs (now tracked as pieces, not deferred)

Per the repo's fix-as-found policy, the actionable retrospective findings were filed as real manifest
pieces rather than backlog entries:

- **pi-018 (P1/P2/P3 — review-process hardening):** add a whole-file coherence pass for single-file
  multi-phase pieces *before* Final Review; require plans to enumerate every existing step a new
  conditional path traverses; require a dispatch-site census when changing a cross-cutting agent
  contract. These would have converted this piece's Final-Review surprises into phase task items.
- **pi-019 (F2 — SKILL.md coherence linter):** a charter-tools-compliant structural linter for
  cross-step invariants (referenced steps exist; `auto`/`off` branch parity; journal field
  producer↔consumer matching).
- **pi-017 (F1 — anti-cheat hash-object anchoring):** close the self-asserted-manifest hole the
  security reviewer flagged, before pi-016 widens the tamper window with concurrency.
- **pi-016:** the concurrency + Race-2 carve-out (depends on this piece).

## Process metrics

7 phases, all Implement-track, all Verify Mode:Audit (clean oracle every phase), all per-phase QA
must-fix=None, 1 plan amendment (Phase 1, budget 1/5) + 1 reflection amendment (F3 dedup),
mid_piece_opus_pass not-triggered, Step 6b hook sweep a no-op every phase (no pre-commit config).
Final Review: 8-agent board, 3 fix iterations to converge. Data point: on single-large-file
orchestration pieces, defect detection migrates almost entirely from per-phase QA to the end-of-piece
whole-system reviewers — concentrating remediation cost at the merge gate, which is exactly what
pi-018's pre-Final-Review coherence pass aims to redistribute.
