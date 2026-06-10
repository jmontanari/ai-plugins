# Learnings — exec-ready/spec-preresearch (Investigation-First Deliberation Protocol)

spec-flow 5.8.0 → re-versioned to 5.10.0 at merge prep. Doc-as-code, 14 phases, Implement track. Executed on Opus coordinator (operator override of the Sonnet-class check).

## Patterns that worked well

- **Per-phase Opus QA on serial cite-source phases.** The plan deliberately kept the agent/skill phases serial "for per-phase Opus QA on each new shipped contract." This paid off: per-phase Opus QA caught 6 distinct semantic defects at the phase boundary *before* later cite-from phases consumed them — NN-P-001 misattribution (Phase 5), CR-008 cluster-ownership leak (Phase 7), wrong fallback parenthetical (Phase 11), and two implementer hallucinations (Phases 13/14). Validates the plan's declared deviation from Phase Groups for cross-citing doc-as-code.
- **Corrective notes embedded in the plan's In-scope block.** Phase 2's plan carried a `NOTE` that `.spec-flow.yaml` is gitignored and the real edit target is the tracked `pipeline-config.yaml` template — the implementer auto-corrected with no BLOCK/operator round-trip. A parenthetical correction in In-scope is a zero-cost guard against mis-targeting a gitignored sibling.
- **Merge-base diff for the review board.** The two-dot `master..HEAD` diff was polluted by 12,618 deletions of master-only files (master had advanced). Switching the board to the merge-base diff (`git diff $(git merge-base master HEAD)..HEAD`) isolated the true 25-file/+2840 piece scope. Always review a piece against its merge-base, not the default-branch tip, when the branch is behind.
- **Mid-phase session-limit interruption recovered cleanly.** The Phase 13 implementer died after editing the working tree but before committing; the orchestrator verified + committed the working-tree state. Implement-track phases survive interruption because work is inspectable pre-commit.

## Issues QA caught

- **Sonnet implementer hallucination on doc-authoring (2/14 phases).** On "describe what another file contains" tasks (Phase 13 PRD failure-mode trigger list; Phase 14 CHANGELOG descriptions), the implementer invented plausible-but-wrong content (wrong lens names, "Tier-1/2/3" instead of full/lite/off, mischaracterized agents, fabricated 5-trigger set). **The implementer's own grep-based `[Verify]` passed** because the content was structurally present but semantically wrong. Caught only by orchestrator diff-review + Opus QA. Lesson: doc-authoring `[Verify]` blocks need exact-value greps (not just count/heading-presence checks), and CHANGELOG phases need a cross-check of each bullet against the artifact it describes.
- **Final Review board found edge-case gaps the per-phase QA missed** — all in protocol-prose edge cases that span files: the single-cluster Phase-C-skip slot (spec/prd/charter injected a never-produced "Phase C recommendation"), the "None" VOQ sentinel colliding with the VOQ-N must-fix rule, and the single-cluster all-Phase-B-blocked marker-contract gap. These are cross-component invariants no single-phase QA could see — the board's whole-diff view is what catches them.
- **AC-12's frozen "5 fatal + 2 non-fatal" count constrained the fix.** The single-cluster Phase-B gap could not be closed by adding a 6th fatal trigger (would violate AC-12); it was folded into non-fatal condition (f) instead. When a spec freezes a count, fixes must work within it.

## Recommendations for future specs

- **FR-8 Opus-QA skip predicate over-skips on doc-as-code.** The control-flow-density predicate would skip Opus QA for nearly every phase in a markdown/agent/skill repo (no shell control-flow), even for behavioral agent/skill contracts. The operator had to override it. Recommend a 4th condition: any modified `agents/*.md` or existing `skills/*/SKILL.md` routes to Opus regardless of content type.
- **Version-drift guard for long pipelines.** This branch bumped 5.7.0→5.8.0, but master reached 5.9.0 during the spec→plan→execute cycle → stale version + merge conflict. The version/CHANGELOG phase should `[Verify]` the target version against master's current CHANGELOG before committing the bump.
- **Step-1a coherence linter gaps.** It false-positives on (a) `deliberation.md §Section` runtime-artifact refs (only models `reference/*.md §`) and (b) pre-existing numbered refs (`§5`). This piece reworded its skill refs to `## Section` to dodge it, creating a §-vs-## convention split with the agents. A linter fix + convention-unification pass is a clean follow-up.

## Open follow-up candidates (from reflection — not blocking this merge)

1. **Linter fix:** teach `lint-skill-coherence` invariant-2 about runtime-artifact `§Section` refs + numbered `§N` refs (also clears pre-existing `plan/SKILL.md` + `execute/SKILL.md` false positives).
2. **`§` convention unification:** after the linter fix, unify skills (`## Section`) and agents (`§Section`) on one form.
3. **AC-7 bootstrap split:** AC-7's `ls deliberation.md` is unsatisfiable for the piece that *builds* the protocol; split into reference-doc `ls` (static) + runtime-artifact `ls` (with a bootstrap exemption).
4. **FR-009 Success Criterion:** FR-009 has no `Linked metrics:` line (unlike FR-001–008); add SC-001 link or a new grounding-rate SC.
5. **Shared `reference/model-preflight.md`:** the Opus pre-flight is duplicated across spec/prd/plan/charter (+ execute's Sonnet variant) — ADR-3 flagged the drift risk; a cite-don't-restate refactor closes it.
