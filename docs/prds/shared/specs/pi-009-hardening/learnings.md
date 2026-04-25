# Learnings — pi-009-hardening (v3.1.0)

End-of-piece reflection for the spec-flow v3.1.0 hardening bundle. Captured at the close of execute, before squash-merge to master. Two reflection agents contributed: process-retro (orchestration mechanics) and future-opportunities (forward-looking spec/process candidates). Raw findings persisted to `docs/improvement-backlog.md` in the prior commit; this file is the human-readable narrative.

The piece bundled 11 v3.0.0-reflection-driven items (CAP-1..4 capability + ORC-1..7 orchestrator hardening) into one coherent v3.1.0 release. 9 phases (1 Phase Group + 8 sequential flat phases), 12 named sub-phase units, ~315 LOC across 18 files. Released as `spec-flow` v3.1.0 (3-place version bump per NN-C-009).

---

## Per-sub-phase narrative

### Group A.1 — PI-008 spec amendment (CAP-1)

**what worked:** clean implementation of FR-005's single-branch resolution. Independent file (PI-008's spec.md), no concurrent contention. The 4-pronged rationale paragraph (a/b/c/d) authored during spec authoring carried directly into the amendment text. AC-1 grep tests passed first-attempt.

**what didn't:** the FR-1 obligation to hyperlink the resolution from PI-008's `learnings.md` was missed by the implementer (AC-1's grep test only checked PI-008's spec.md, not learnings.md). Final Review iter-1 caught it; fix-code applied the cross-link.

### Group A.2 — status-skill `--include-drift` mode (CAP-2)

**what worked:** new `## Citation drift deep scan` section landed at H2 alongside existing status-skill steps with clean H3 sub-bullets (CR-009 honored). Synthetic NN-C-099 / NN-C-002 trace traced cleanly. NN-C-005 missing-input no-op behavior explicit.

**what didn't:** the staging-area race with A.4 — A.2's commit (`728815b`) swept in A.4's prd.md + migrate/SKILL.md changes. Substance correct, attribution muddled. Step 3.7b reconciliation gate would have rejected this in strict mode but the gate is gated `Mode: TDD only` and didn't fire on this Implement-track sub-phase.

### Group A.3 — worktree-token resolver doc + sweep (CAP-3 partial)

**what worked:** new `## Worktree-root template token` section in v3-path-conventions.md establishes the contract; sweeps on spec/SKILL.md and prd/SKILL.md were small text replacements with clean greps.

**what didn't:** the resolution-failure-mode prose was internally contradictory ("substitutes empty string" vs "receives unresolved string verbatim") — Final Review caught it; fix-code rewrote to be consistent.

### Group A.4 — migrate-skill environment precondition + NFR-004 amendment (CAP-4)

**what worked:** new `## Environment preconditions` section frames host capabilities (LLM-agent runtime, git, POSIX shell) as runtime expectations on the LLM operator, NOT plugin-internal dependencies. NN-C-002 honoring is concrete with the explicit "no specific language runtime" framing. AC-5 and AC-6 grep tests passed.

**what didn't:** A.4's commit attribution was lost to the A.2 staging race (no A.4-named commit lands in the squash-merge log). Substance is in the diff but the per-sub-phase commit history is muddled. Captured as a process-retro observation; squash-merge collapses everything anyway.

### Group B.1 — sharpen Opus QA skip-predicate (ORC-1 / FR-8)

**what worked:** the (a)/(b)/(c) structured predicate cleanly classifies the three AC-7 synthetic traces. Three worked examples (additive markdown / bash if-block / new SKILL.md) make the contract concrete. CR-008 honored — predicate lives in skill body, no agent template gains skip-decision logic.

**what didn't:** the predicate body was placed INSIDE the existing "Conditional skip of re-dispatch" block. Phase B.4 later deleted that entire block when retiring `qa_iter2`, taking the FR-8 predicate body with it. Final Review iter-1's spec-compliance reviewer caught this as the most consequential finding ("AC-7's required predicate text is missing"); fix-code restored the predicate as a standalone Step 6 sub-section. Plan-side root cause: no "shared concern" annotation linking B.1's edit to a structural anchor B.4 would later modify.

### Group B.2 — mid-piece Opus QA pass for ≥6-phase pieces (ORC-2 / FR-9)

**what worked:** Step 0a inserted cleanly before Step 1 of the per-phase loop, additive (NN-P-002 honored). Trigger arithmetic (N=6, K=3, fires at K+1=4) verified against 4 synthetic scenarios. NN-C-008 self-contained prompt structure explicit (cumulative diff + spec + AC matrix + cited charter raw text).

**what didn't:** initial implementation cited fictional state — `<piece_start_sha>` undefined, `phase_N_ac_matrix` keying ambiguous, AC matrix accumulator hand-waved, "Step 6 skip-predicate" reference wrong (should be FR-8 Opus skip-predicate), forward-dependent FR-14 cite, no resume idempotency guard. Phase 3 qa-phase Opus iter-1 returned 6 must-fix items; fix-code resolved all 6 in iter-1.

### Group B.3 — deferred-finding tracking (ORC-3 / FR-10)

**what worked:** Step 6a parser/writer logic added cleanly between iter-until-clean loop and proceed-to-Step-7 line. CR-008 honored — orchestrator parses, agent doesn't gain marker-emission instruction. Synthetic trace (qa-phase report with `Deferred to reflection:`) produces the expected stub format and commit.

**what didn't:** initial implementation lacked dedup logic — if iter-1 emits a deferred finding and iter-2 (focused re-review) re-emits it (because focused-re-review carries prior must-fix forward), the orchestrator appends a duplicate stub. Final Review iter-1 caught this; fix-code added the dedup check at top of Step 6a.

### Group B.4 — iter-until-clean reference doc + skill citations (ORC-7 / FR-14, FR-15)

**what worked:** new `qa-iteration-loop.md` reference doc satisfies all 8 grep anchors per AC-13. Citations land in spec/plan/charter/execute SKILL.md per AC-14. `qa_iter2` key retained in pipeline-config.yaml with deprecation comment block (NN-C-003 + CR-007 honored).

**what didn't:** B.4 deleted the "Conditional skip of re-dispatch" block in execute/SKILL.md to retire `qa_iter2`, but the same block contained B.1's FR-8 skip predicate (collateral damage). Also missed 4 dangling iter-2-skip prose remnants in execute/SKILL.md (Steps 6 closing line, QA-lite step in Phase Group loop, Measurement section x2). Final Review iter-1 caught both; fix-code restored the FR-8 predicate as standalone and rewrote the 4 stale lines.

### Group C.1 — plan-skill phase-sizing rule (ORC-4 / FR-11)

**what worked:** step 2a added cleanly to plan/SKILL.md `### Phase 2: Generate Plan`. Synthetic trace (250-line `[Implement]` block → warning emitted; 150-line boundary → no warning; override suppresses warning) all passed first-attempt.

**what didn't:** the `{{worktree_root}}/piece-<piece-slug>/` token sweep produced a doubled `piece-<piece-slug>` segment in two places (Prerequisites + Worktree/branch naming paragraph) because `{{worktree_root}}` already resolves to a path containing `piece-<piece-slug>`. Final Review iter-1 caught it; fix-code dropped the suffix. Also the counting rule's "non-blank, non-comment" definition is operationally ambiguous (excludes checkbox-marker lines but doesn't filter HTML comments or fenced code blocks) — captured as a v3.1.1 candidate.

### Group C.2 — plan-skill exit-gate semantics rule (ORC-5 / FR-12)

**what worked:** step 2b validator scans `**Exit Gate:**` lines + `[Verify]` expected-output prose for 5 forbidden patterns (case-insensitive). Synthetic traces (downgrade pattern → fail; "X ran successfully" → pass; mixed case → caught; "documents the run" → no false positive) all passed.

**what didn't:** the validator has no escape hatch like `phase_size_override` for legitimate documentation prose that quotes the forbidden patterns (e.g., a meta-plan whose `[Verify]` block describes the rejected pattern itself). Edge-case reviewer flagged this; deferred to v3.1.1.

### Group C.3 — LLM-native [Verify] default in plan template (ORC-6 / FR-13)

**what worked:** `templates/plan.md` Phase 2 (Implement track example) `[Verify]` bullet's `Run:` placeholder now includes LLM-agent-step framing for YAML/JSON validation. `grep -E "(yq|jq)( |$)"` returns zero in [Verify] blocks. CR-008 honored — agent does the parse natively, skill still orchestrates.

**what didn't:** smallest phase in the piece (~30 LOC), no significant issues caught at any QA gate.

### Phase D — Release ceremony (FR-16, FR-17)

**what worked:** 3-place version bump (plugin.json + marketplace.json + CHANGELOG.md) in single commit (`338afa7`). NN-C-001 sync invariant holds (both manifests at "3.1.0"). NN-C-007 + CR-006 (Keep a Changelog) format honored — Added / Changed / Removed groupings + Migration notes for upgraders subsection covering qa_iter2 deprecation, --include-drift opt-in, mid-piece Opus pass behavior, and dog-food evidence pointer.

**what didn't:** the CHANGELOG migration notes describe `learnings.md` in past tense as already capturing all 12 sub-phases, but learnings.md doesn't exist until this very Step 5 produces it. PRD-alignment reviewer correctly flagged this. Resolution: this learnings.md, written now, contains the 12 sub-phase narrative the CHANGELOG promises. AC-17 tests 2/3/4 (heading count ≥12, what-worked/didn't ≥12, byte count >1 KB) become checkable post-write; AC-17 test 1 (release commit message references learnings.md path) is the maintainer's pre-squash-merge job, with the CHANGELOG migration note as the in-tree anchor reminder.

---

## Patterns that worked well — repeat

- **Phase Group A's parallel dispatch delivered real throughput** despite the staging-area race. 4 sub-phases over disjoint files completed concurrently; the substance of all 4 is correct in the diff.
- **Final Review's 4-reviewer board (architecture clean) caught the most consequential structural regression** (AC-7 / FR-8 predicate deletion) that per-phase QA didn't have visibility into. Multi-angle adversarial review at end-of-piece is load-bearing for cross-phase issues.
- **Phase 3 qa-phase Opus iter-1 closed all 6 must-fix items in one fix-code pass.** Demonstrates the single-iteration fix pattern holds when per-phase QA runs on complex phases.
- **Edge-case reviewer's deferred-to-v3.1.1 corner cases** (4 medium + 3 low) were scoped correctly — held in backlog rather than expanding end-of-piece fix scope.
- **Spec authoring's 3-iter QA convergence + plan authoring's 3-iter QA convergence** held to the iter-until-clean discipline this piece itself codifies. Reasonable validation of the FR-14 contract on the spec-flow plugin's own dog-food run.

---

## Issues QA caught — change next time

- **Phase B.1 → B.4 collateral damage from shared structural anchor:** B.1 embedded the FR-8 predicate inside the same block B.4 later deleted. Plan should carry "shared concern" annotations when ≥2 phases scope the same SKILL.md block. Captured as v3.1.1 high-priority item.
- **Per-phase qa-phase Opus skip for Phases 4–9 shifted correctness load to Final Review.** 6/9 phases skipped per-phase QA = 67% deviation from doctrine. Final Review iter-1's 7 critical findings are a direct consequence. Recommend: per-phase QA non-negotiable for any phase that modifies a file already touched by a prior phase.
- **Step 3.7b reconciliation gate is `Mode: TDD only`** — Implement track had a real contamination event (Phase Group A staging race) that the gate would have caught. v3.1.1 high-priority: extend gate to Implement track.
- **Token-sweep over-eagerness on `{{worktree_root}}`** produced a doubled `piece-<piece-slug>` segment. Recommend: post-sweep grep validation for consecutive duplicated path segments as part of release-ceremony checklist.
- **CHANGELOG migration notes written in past tense before learnings.md exists.** Either soften phrasing pre-write OR ensure Step 5 runs before Phase D's CHANGELOG commit. Tightening phase ordering is the cleaner fix.

---

## Recommendations for future spec-flow pieces

1. **Plan should annotate shared structural concerns.** When ≥2 phases edit the same SKILL.md section/block, the plan author marks the block as "shared concern: phases X, Y, Z all reference this block; deletion requires consensus." Orchestrator surfaces a warning on Step 0 if the annotation is missing for a multi-phase shared edit.
2. **Reconciliation gate (Step 3.7b) extends to Implement track.** Hard fail on stray files outside the explicit `[Implement]` file list. Phase Group A's contamination would have been caught.
3. **Per-phase qa-phase Opus dispatch is non-negotiable** for phases that share files with prior phases in the piece. Skip predicate (FR-8) decides only for first-touch phases.
4. **Mid-piece Opus QA pass dog-food trigger condition needs clearer cross-reference** to the FR-8 predicate it depends on. The fix landed in this piece (Step 0a now cites Step 6's standalone Opus dispatch decision); future pieces should confirm the cross-reference resolves.
5. **CHANGELOG dog-food evidence references should use future-tense or post-write timing.** Phase D should run AFTER Step 5 (Capture Learnings) so the CHANGELOG can speak truthfully about the artifact it points at.
6. **Edge-case reviewer's deferred items should be promoted to PRD-local backlog** with explicit v3.1.1 / v3.2.0 milestones, not lost in learnings.md alone. The improvement-backlog append (this piece's prior commit `fd3a893`) carries them.
