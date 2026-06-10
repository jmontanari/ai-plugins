# Learnings — exec-ready/flywheel-repo

Repo-level self-hardening flywheel (FR-006). 5 Implement-track phases + 1 board-driven amendment; shipped spec-flow 5.8.0.

## Patterns that worked well

- **Two-tier per-phase QA dispatch held up.** The Opus skip-predicate correctly skipped per-phase QA on the structurally-verifiable phases (Phase 1 reference doc, Phase 2 config key, Phase 5 version bump — all grep-checkable) and dispatched Opus `qa-phase` only on the two `execute/SKILL.md` wiring phases (3 + 4) where behavioral correctness can't be asserted by grep alone. Neither skipped phase leaked a defect into Final Review.
- **Consolidate-then-single-amendment for board findings.** The Final Review board surfaced three coupled must-fix findings (F1 broken spike `<id>` seam, F3 no schema home for hardening outcome, F5 re-proposal loops). Batching all three (plus two should-fixes + a no-secrets guard + the degraded-path extension) into ONE consolidated amendment (`phase_final_amend_1`) resolved everything in a single pass — the focused board re-review came back clean with no further escalation. Worth repeating for final-review-origin amendments.
- **The piece dog-fooded its own design.** The flywheel's amend-in-place hardening path is exactly the mechanism that fixed the flywheel's own hardening gaps — the board found the hardening half under-specified and the consolidated amendment used the existing spike→plan-amend→re-review loop to complete it.
- **Synchronous discovery worked as intended.** Three discoveries surfaced and were triaged at the moment they appeared (Phase 2 gitignore, pre-board linter defect, board hardening gaps) rather than silently deferred — each got an operator decision + a `.discovery-log.md` row.

## Issues QA caught

- **Phase 3 (qa-phase, Opus):** one should-fix — the Step 6c hook restated the Count rule inside a "do not restate" subsection (NN-C-008 drift). Fixed in-place via fix-code before phase close.
- **Final Review board (8 agents):** the recording/match/count half was confirmed SOLID (ground-truth re-derived all math; spec-compliance found all 11 ACs implemented), but blind + edge-case + integration independently caught that the **hardening-dispatch half was incomplete**: the spike artifact path was keyed on an `<id>` the flywheel never minted (F1), the schema had no field for the accepted/blocked outcome the prose told the orchestrator to write (F3), and resolved/blocked patterns would re-propose on every subsequent piece forever (F5). All resolved by the consolidated amendment.
- **Pre-board coherence linter (Step 1a):** flagged a *pre-existing* invariant-2 cross-ref defect at `execute/SKILL.md:397` (also broken on master, unrelated to the flywheel) — fixed with operator approval as a fix-to-improve.

## Recommendations for future specs (deferred to improvement-backlog)

- **Enumerate the schema home for any "record-this-outcome" behavior at spec/plan time.** The hardening-schema gap (F1/F3/F5) traced to a single spec omission: SF-6 said "the accepted outcome … is recorded against the pattern" but named no concrete schema field and no re-proposal exclusion rule. qa-spec/qa-plan should require any "record/persist this outcome" AC to name the field that carries it, and the cross-phase schema-consistency `[Verify]` should confirm every outcome state has a dedicated schema home. (PR-FW-1)
- **qa-spec should grep `.gitignore` for config-file ACs.** The AC-10 "documented in both files" mismatch (`.spec-flow.yaml` is gitignored) cost a spec-amend + plan-amend at implementation time; a one-line `.gitignore` check at spec QA would have caught it. (PR-FW-2)
- **Require a grep-verifiable assertion per concrete dispatch identifier.** The plan specified `<id> = flywheel-<pattern-id>` but the implementer didn't carry it through, and the `[Verify]` was an LLM-agent-step rather than a grep on the literal token. (PR-FW-3)

## Notes for flywheel-global (FR-007, next piece)

The mid-execute `hardenings` field means the SF-N4 reuse factoring ("one added field") undercounts — flywheel-global's brainstorm must explicitly resolve whether to inherit `hardenings` (with repo-specific `amend_commit`/`spike_artifact`), narrow it, or omit it; and must add explicit ACs for the resolved/blocked exclusion branches (only the rejection rule has one today). A registry-integrity lint for schema-valid-but-structurally-wrong `patterns.yaml` is also a candidate. (FW-1/2/3 in the PRD backlog.)
