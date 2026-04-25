# v2.0.0 Piece 4 — Agent Updates

**Goal:** Teach the implementer and review agents to honor charter constraints, verify NN-C/NN-P/CR citations, and audit charter compliance across the pipeline.

**Architecture:** Surgical markdown edits to 8 agent files. No new agents.

## Files

- Modify: `plugins/spec-flow/agents/implementer.md` (Rule 4 path hint + naming)
- Modify: `plugins/spec-flow/agents/qa-spec.md` (verify NN/CR cited in spec actually exist)
- Modify: `plugins/spec-flow/agents/qa-plan.md` (verify per-phase charter slot)
- Modify: `plugins/spec-flow/agents/qa-phase.md` (check cited entries honored in commit)
- Modify: `plugins/spec-flow/agents/qa-prd-review.md` (audit NN coverage across done)
- Modify: `plugins/spec-flow/agents/review-board/architecture.md` (expanded scope)
- Modify: `plugins/spec-flow/agents/review-board/spec-compliance.md` (verify claims in diff)
- Modify: `plugins/spec-flow/agents/review-board/prd-alignment.md` (verify NN-P preserved)
- Modify: `plugins/spec-flow/CHANGELOG.md`

## Scope fence

- No new agents (qa-charter already added in piece 1)
- No implementation of fetching external references (v1 trusts the link)
- No ADR-generation agents

## Tasks

1. **implementer**: Rule 4 updates `docs/architecture/` hint → `docs/charter/` hint; explicitly list NN-C/NN-P/CR as binding reference types the plan may cite.
2. **qa-spec**: Add a check that every NN-C/NN-P/CR cited in the spec exists in its source file (no hallucinated IDs); verify "how honored" phrasing is specific and verifiable.
3. **qa-plan**: Add a check that per-phase "Charter constraints honored in this phase" slot allocates every spec-cited entry to exactly one phase (no drops, no duplicates).
4. **qa-phase**: Add a check that the phase's cited NN-C/NN-P/CR are actually honored in the phase diff.
5. **qa-prd-review**: Add end-of-pipeline audit that every NN-C and NN-P from the PRD & charter is honored somewhere across the set of done pieces.
6. **review-board/architecture**: Expand review scope to include CR-xxx compliance; input context is now all six charter files.
7. **review-board/spec-compliance**: Verify every NN-C/NN-P/CR the spec claims is demonstrably honored in the final cumulative diff.
8. **review-board/prd-alignment**: Verify NN-P entries are preserved and honored in the implementation.
9. CHANGELOG piece 4 entry.
10. Single commit covering all eight agent files + CHANGELOG.
