---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
tdd: false
fast: false
---

# Plan: Artifact size budgets

**Spec:** docs/prds/exec-ready/specs/artifact-budgets/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Implement artifact size budgets as the inverse of the FR-002 concreteness floor. Six serial Implement-track phases: (1) create the SSOT `reference/artifact-budgets.md`; (2) add the additive `.spec-flow.yaml artifact_budgets:` override block; (3) extend the `metrics.yaml` schema with a `budget_compliance:` block; (4) add qa-spec criterion #16 + the spec-skill `wc -l`/budget interpolation + spec-side metrics write; (5) add qa-plan criterion #32 + the plan-skill `wc -l`/budget interpolation + plan-side metrics write; (6) version bump to 5.12.0 + CHANGELOG + marketplace sync.

**Track rationale (Non-TDD / Implement, per charter-tools).** Every deliverable is markdown (reference doc, agent-criterion prose, SKILL.md prose) or YAML (config, metrics schema). The repo ships no test runner for these and reference docs are not unit-tested (charter-tools). Phases therefore use the Implement track with structural `[Verify]` (grep / file-checks / LLM-agent-step) in place of `[TDD-Red]`/`[Write-Tests]`. Validation of correctness is by (a) the Phase-6 citation-consistency sweep, (b) the qa-spec/qa-plan agents as live consumers, and (c) the FR-013 e2e harness. `[Write-Tests]` is N/A — there is no unit-test surface for markdown/YAML reference docs, and adding a framework would violate NN-C-002 (no runtime deps). qa-plan #31 (Test Data block) correctly skips for all phases (no `[TDD-Red]`/`[Write-Tests]` step).

**Serial, not a Phase Group.** Phases 4 and 5 touch disjoint files (qa-spec.md+spec/SKILL.md vs qa-plan.md+plan/SKILL.md) and could parallelize, but are kept serial deliberately — see `Why serial:` on Phase 5.

## Architectural Decisions

### ADR-1: Orchestrator computes the line count; the agent judges
**Context:** qa-spec/qa-plan have no shell/codebase access (qa-plan.md:212). If the agent counts lines from the interpolated artifact text, a too-large artifact truncated during interpolation reads *shorter* and silently passes — the gate fails on exactly the worst offenders (deliberation risk R-1).
**Decision:** the spec/plan orchestrator skill runs `wc -l` on each gated artifact, resolves `.spec-flow.yaml` overrides → reference defaults, and interpolates "artifact is N lines; soft S; hard H" into the qa prompt. The agent compares the supplied count to the budgets and judges over/under — it never counts lines itself.
**Alternatives considered:** (a) agent counts from interpolated text — rejected, truncation under-count; (b) a new bash helper to count + verdict — rejected, over-engineered, the skill already resolves config.
**Consequences:** truncation can no longer hide bloat; the count is authoritative. Adds a `wc -l` + interpolation step to two skills.
**Charter alignment:** CR-008 (measurement plumbing is config-resolution-adjacent, mirrors concreteness-floor #28–#31 skill/agent split); NN-C-008 (budget values reach the agent by interpolation, not config-read).

### ADR-2: Two-tier soft/hard; only the hard ceiling is must-fix
**Context:** a must-fix that fires on a legitimately-large artifact adds gate round-trips, fighting SC-008 (deliberation risk R-2).
**Decision:** each class has a soft (advisory, ≈p75) and a hard (must-fix ceiling, ≈observed-max +~10%) tier. Over soft but under hard = advisory note only; over hard = must-fix.
**Alternatives considered:** (a) single threshold — rejected, forces too-tight (false positives) vs too-loose (no signal); (b) soft-only advisory — rejected, no enforcement, FR-014 demands must-fix.
**Consequences:** legitimately-large-but-under-ceiling artifacts never trigger a round-trip; egregious bloat is still caught.
**Charter alignment:** NN-P-001 (keystroke gate untouched; ADD-only must-fix).

### ADR-3: Budget compliance is passive metrics metadata, not aggregated
**Context:** VOQ-3. Recording compliance could extend `scripts/metrics-aggregate` (and its byte-identical python/awk parity test) or be passive metadata.
**Decision:** record `budget_compliance` as passive per-piece metadata in `metrics.yaml`; do NOT consume it in `scripts/metrics-aggregate`, do NOT add an SC computation.
**Alternatives considered:** (a) aggregate across the PRD — deferred to a real follow-up piece if demanded; higher blast radius (parity test).
**Consequences:** the aggregator + its parity test stay untouched; the bloat trend is observable per-piece (FR-014 AC4 satisfied).
**Charter alignment:** charter-tools (no new bash/test surface).

### ADR-4: deliberation.md binds forward, grandfathers the merged baseline, generous ceiling now
**Context:** VOQ-1/VOQ-2. spec-preresearch is already merged (885-line plan); deliberation.md has zero on-disk samples.
**Decision:** the deliberation.md budget binds future producers at the qa-spec gate; the merged spec-preresearch plan is recorded as the grandfathered baseline (not retroactively flagged); the hard ceiling is set generously to 350 lines now (operator override of the deliberation's observe-only R-3 recommendation — no follow-up obligation).
**Alternatives considered:** (a) observe-only one cycle then re-bind — rejected by operator (leaves a re-bind obligation); (b) retroactively flag the merged plan — impossible (gate already passed).
**Consequences:** AC3 reframed forward-looking; closes the loop today.
**Charter alignment:** NN-P-001; no-defer doctrine (no silent backlog re-bind).

### ADR-5: No waiver mechanism; irreducible overage routes to piece-split
**Context:** an inline waiver would let any author silence the budget (FR-014 failure mode).
**Decision:** no waiver primitive; irreducible overage routes to the qa-prd ≤7-AC piece-split path. Do NOT copy qa-spec's `<!-- weasel-waived -->` dialect.
**Alternatives considered:** (a) a budget-waiver comment — rejected, converts a structural signal into a rubber stamp.
**Consequences:** over-budget that can't be cut becomes a decomposition decision, not a suppression.
**Charter alignment:** FR-014 failure mode; PRD edge-case table.

## Integration-Test Registry (M1)

No integrations declared (NFR-INT-02). Spec `## Integration Coverage` = "None in scope."

## Phases

### Phase 1: Create the SSOT reference doc
**Exit Gate:** `reference/artifact-budgets.md` exists, defines all 6 classes with soft+hard tiers in lines + approx tokens, documents the override keys, the deliberation.md forward-bind + grandfather note, and the no-waiver clause; grep checks pass.
**ACs Covered:** AC-1, AC-6
**In scope:** CREATE `plugins/spec-flow/reference/artifact-budgets.md`
**NOT in scope:** the `.spec-flow.yaml` config block (Phase 2); qa criteria (Phases 4–5); metrics schema (Phase 3)
**Charter constraints honored in this phase:**
- CR-005 (repo-root-relative paths): all cross-references use repo-root-relative paths.
- CR-009 (heading hierarchy): one H1, numbered H2 sections, no skipped levels.
- NN-C-003 (additive): doc states `Absent ⇒ default (non-blocking; NN-C-003)` for overrides.

- [x] **[Implement]** Author the reference doc
  - Architecture constraints: match `reference/plan-concreteness.md` house style — SSOT preamble naming consumers, numbered H2 sections, explicit numeric thresholds, a `<!-- Worked example: … -->` comment, a `## No secrets` clause.

  **Change Specifications:**

  **T-1: CREATE plugins/spec-flow/reference/artifact-budgets.md**
  - Structure outline (H2 sections):
    1. Preamble (SSOT, cited-by) — "single source of truth for per-artifact-class size budgets … cited by `plugins/spec-flow/agents/qa-spec.md` (#16), `plugins/spec-flow/agents/qa-plan.md` (#32), `plugins/spec-flow/reference/metrics-artifact.md` (budget_compliance), `plugins/spec-flow/skills/spec/SKILL.md` + `plugins/spec-flow/skills/plan/SKILL.md` (resolve overrides + `wc -l` interpolation). Definitions live here and nowhere else."
    2. `## Budget table` — the 6-class table (soft/hard lines + approx tokens + gate column):

       | Class | Soft (advisory) | Hard (must-fix) | Gate | Approx tokens (hard) |
       |---|---|---|---|---|
       | spec.md | 300 | 520 | qa-spec #16 | ~20k |
       | plan.md (total) | 750 | 1000 | qa-plan #32 | ~25k |
       | plan.md (per-phase) | 90 | 220 | qa-plan #32 | ~5.5k |
       | research.md | 200 | 320 | documented-only | ~8k |
       | deliberation.md | 200 | 350 | qa-spec #16 | ~9k |
       | learnings.md | 30 | 50 | documented-only | ~1.5k |
    3. `## Derivation` — soft = corpus p75 (rounded); hard = observed-max +~10% headroom (rounded). Tokens ≈ chars/4 (advisory secondary; lines are the `wc -l`-checkable primary). Cite the 9-merged-piece corpus.
    4. `## Tiers and gates` — over hard ⇒ must-fix with split/condense guidance; over soft & under hard ⇒ advisory only (no round-trip); budget unresolvable/absent ⇒ skip (NN-C-003). research.md + learnings.md are documented-only (no qa gate reviews them).
    5. `## deliberation.md (forward-binding + grandfathered baseline)` — zero on-disk samples; hard 350 set generously from the 7-section structure + research.md analogy. Binds future deliberation.md producers at the qa-spec gate. The already-merged spec-preresearch plan (885 lines) is recorded as the grandfathered baseline, NOT retroactively flagged.
    6. `## Overrides` — `.spec-flow.yaml artifact_budgets:` nested block; per-class `soft`/`hard` line overrides; `Absent ⇒ table defaults (non-blocking; NN-C-003)`. Point to `templates/pipeline-config.yaml`.
    7. `## Irreducible overage` — routes to the qa-prd ≤7-AC piece-split rule; NO waiver mechanism.
    8. `## No secrets` — budgets record only line/token counts; never transcribe artifact content containing secrets.
  - Worked example (required — `[Verify]` asserts it present): `<!-- Worked example: a plan.md with total 940 lines (under hard 1000, over soft 750) and a worst phase of 210 lines (under hard 220) → qa-plan #32 emits an advisory note on total, no must-fix. A plan.md total 1050 → must-fix with "split the piece or hoist detail to reference". -->`
  - Pattern (preamble shape, from reference/plan-concreteness.md:3):
    ```
    This document is the single source of truth for ... It is cited by
    `plugins/spec-flow/skills/plan/SKILL.md` ... Any definition ... lives
    here and nowhere else; the consuming files cite this document and do
    not restate its definitions.
    ```
  - Done: file exists; all 8 H2 sections present; budget table has all 6 classes with soft+hard; deliberation.md grandfather note present; no-waiver clause present; worked example present.
  - Verify: see [Verify] block.

- [x] **[Verify]** Structural checks on the reference doc
  **Per-change checks:**
  - T-1: `test -f plugins/spec-flow/reference/artifact-budgets.md` — Expected: exit 0
  - T-1: `grep -cE "spec\.md|plan\.md|research\.md|deliberation\.md|learnings\.md" plugins/spec-flow/reference/artifact-budgets.md` — Expected: ≥6 (all classes named)
  - T-1: `grep -c "Worked example" plugins/spec-flow/reference/artifact-budgets.md` — Expected: ≥1
  - T-1: LLM-agent-step: read the doc and confirm (a) the budget table has soft AND hard columns for all 6 classes, (b) the deliberation.md section states forward-binding + grandfathered spec-preresearch baseline + 350 hard ceiling, (c) the irreducible-overage section routes to piece-split with NO waiver mechanism.
  **Phase-level check:**
  - Run: `grep -n "weasel-waived" plugins/spec-flow/reference/artifact-budgets.md` — Expected: no output (exit 1) — confirms no waiver dialect copied (AC-5).
  - Failure: any class missing soft/hard; missing grandfather note; a waiver token present.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-6
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 2: Add the `.spec-flow.yaml` override block
**Exit Gate:** `templates/pipeline-config.yaml` carries an additive, inline-documented `artifact_budgets:` block consistent with the reference-doc defaults; grep checks pass.
**ACs Covered:** AC-1
**In scope:** MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`
**NOT in scope:** the reference doc (Phase 1); skill resolution logic (Phases 4–5)
**Charter constraints honored in this phase:**
- CR-007 (config keys documented inline): `# artifact_budgets:` header, per-class lines, `Absent ⇒ default (non-blocking; NN-C-003)`, `See reference/artifact-budgets.md`.
- NN-C-003 (additive): block is optional; absent ⇒ reference-doc defaults.

- [x] **[Implement]** Add the override block
  - Architecture constraints: mirror the existing `deliberation:`/`charter:` nested-block doc style; commented example values, real keys optional.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/templates/pipeline-config.yaml**
  - Anchor: end of file, after the `deliberation:` commented block (after line ~173)
  - Current (tail context):
    ```
    # deliberation: pre-brainstorm Investigation-First protocol depth (new in v5.8.0)
    # deliberation:
    #   depth: full
    #   lenses: [scope/simplicity, risk]
    ```
  - Target: append a documented `artifact_budgets:` block. Inline doc per CR-007:
    ```
    # artifact_budgets: per-artifact-class size budgets (new in v5.12.0; FR-014).
    #   Optional per-class line-count overrides; soft = advisory, hard = must-fix ceiling.
    #   Classes: spec_md, plan_md_total, plan_md_per_phase, research_md, deliberation_md, learnings_md.
    #   Absent ⇒ defaults from plugins/spec-flow/reference/artifact-budgets.md (non-blocking; NN-C-003).
    #   See plugins/spec-flow/reference/artifact-budgets.md `## Overrides`.
    # artifact_budgets:
    #   spec_md: {soft: 300, hard: 520}
    #   plan_md_total: {soft: 750, hard: 1000}
    ```
  - Done: block appended; commented (so defaults apply unless a user uncomments); names all override-able classes in the doc comment.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  **Per-change checks:**
  - T-1: `grep -c "artifact_budgets" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: ≥1
  - T-1: `grep -c "Absent ⇒ defaults from plugins/spec-flow/reference/artifact-budgets.md" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: 1
  - T-1: LLM-agent-step: read the appended block and confirm it parses as valid YAML comment style and names all 6 override classes.
  **Phase-level check:**
  - Run: LLM-agent-step: read `plugins/spec-flow/templates/pipeline-config.yaml` and confirm the file still parses as valid YAML (the new block is commented).
  - Failure: invalid YAML; missing NN-C-003 absent-default line.

- [x] **[QA]** Phase review
  - Review against: AC-1
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 3: Extend the metrics schema with `budget_compliance`
**Exit Gate:** `reference/metrics-artifact.md` defines a `budget_compliance:` block under `spec:` and `plan:`, with field semantics and a per-stage-owner write note stating it is passive (not aggregated); grep checks pass.
**ACs Covered:** AC-7
**In scope:** MODIFY `plugins/spec-flow/reference/metrics-artifact.md`
**NOT in scope:** the actual writes by the skills (Phases 4–5); `scripts/metrics-aggregate` (explicitly untouched — ADR-3)
**Charter constraints honored in this phase:**
- NN-C-003 (additive): new field; pre-budget metrics.yaml without it reads valid.
- CR-009 (heading hierarchy): additions stay within existing H2 sections.

- [x] **[Implement]** Add the schema block + field semantics + write note
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/reference/metrics-artifact.md**
  - Anchor 1: `## Schema` block (lines 18–24, the `spec:`/`plan:` example)
  - Current:
    ```
    spec:
      qa_rounds: 3
      qa_iterations: 1
      research_artifact: true
    plan:
      qa_iterations: 2
      concreteness_floor: passed
    ```
  - Target: add a `budget_compliance:` leaf under both `spec:` and `plan:` (block-style, own indented lines — no inline flow maps, per the line-52 invariant):
    ```
    spec:
      ...
      budget_compliance:
        spec_md:        {lines: 121, hard: 520, status: pass}   # ← NO: must be block-style
    ```
    CORRECTED block-style form to write:
    ```
    spec:
      budget_compliance:
        spec_md:
          lines: 121
          hard: 520
          status: pass        # pass | over
        deliberation_md:
          lines: 66
          hard: 350
          status: pass
    plan:
      budget_compliance:
        plan_md_total:
          lines: 664
          hard: 1000
          status: pass
        plan_md_max_phase:
          lines: 91
          hard: 220
          status: pass
    ```
  - Anchor 2: `## Field semantics` (after line 66, the `plan.concreteness_floor` entry)
  - Target: add DEFINED entries for the new leaves, e.g.: "`spec.budget_compliance.<class>.status` — **DEFINED:** `pass` when the artifact's `wc -l` count ≤ the resolved hard ceiling; `over` otherwise. Written by the owning stage (spec writes spec_md + deliberation_md; plan writes plan_md_total + plan_md_max_phase). **Passive metadata — not consumed by `scripts/metrics-aggregate`; gates no SC.**"
  - Anchor 3: `## Write procedure` (lines 85–106) — add a one-line note that budget_compliance is upserted by the owning stage and is NOT aggregated (ADR-3).
  - Done: schema block shows budget_compliance under spec + plan (block-style); field semantics define each leaf and state "passive / not aggregated"; write-procedure note present.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  **Per-change checks:**
  - T-1: `grep -c "budget_compliance" plugins/spec-flow/reference/metrics-artifact.md` — Expected: ≥4 (schema spec+plan, field semantics, write note)
  - T-1: `grep -c "not consumed by .scripts/metrics-aggregate.\|not aggregated\|Passive metadata" plugins/spec-flow/reference/metrics-artifact.md` — Expected: ≥1 (ADR-3 passivity stated)
  - T-1: LLM-agent-step: read the schema block and confirm `budget_compliance` leaves are block-style (own indented lines, no `{…}` inline flow maps), satisfying the line-52 invariant.
  **Phase-level check:**
  - Run: `git diff --stat plugins/spec-flow/scripts/metrics-aggregate*` — Expected: no output (aggregator untouched, ADR-3).
  - Failure: inline flow map used; aggregator changed; missing passivity note.

- [x] **[QA]** Phase review
  - Review against: AC-7
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 4: qa-spec #16 + spec-skill wc-l interpolation + spec-side metrics write
**Exit Gate:** qa-spec.md has criterion #16 with the three branches (must-fix/advisory/skip); spec/SKILL.md Phase 4 resolves budgets + runs `wc -l` on spec.md and deliberation.md and interpolates counts; spec finalize writes `spec.budget_compliance`; grep + agent-step checks pass.
**ACs Covered:** AC-2, AC-4, AC-5, AC-6, AC-7
**In scope:** MODIFY `plugins/spec-flow/agents/qa-spec.md`, MODIFY `plugins/spec-flow/skills/spec/SKILL.md`
**NOT in scope:** qa-plan.md / plan/SKILL.md (Phase 5); reference doc (Phase 1)
**Steps traversed (P2):** spec/SKILL.md Phase 4 (QA Loop) step 2 (iteration-1 dispatch) and the Phase-5 finalize metrics-write step; the new budget-resolution sub-step is added inside the existing Phase 4 dispatch path — no new phase, no new loop branch.
**Dispatch sites (P3):** qa-spec is dispatched in spec/SKILL.md Phase 4 step 2 (iteration 1, Full) and step 3 (iteration 2+, Focused re-review). Both dispatch sites must interpolate the budget counts; the focused-re-review path re-checks a prior #16 must-fix and scans the delta.
**Charter constraints honored in this phase:**
- CR-008 (thin-orchestrator): skill computes `wc -l` + resolves config; agent judges over/under.
- NN-C-008 (self-contained prompt): budget values + counts interpolated into the qa-spec prompt; the agent reads no config.
- NN-C-003 (additive): #16 carries `(activate when budgets resolvable; skip if absent — not an error)`.
- NN-P-001 (keystroke gate untouched): ADD-only must-fix.
- NN-P-005 (mechanics on Sonnet): line-count is mechanical.

- [x] **[Implement]** Add criterion #16, the wc-l interpolation, and the spec-side metrics write
  - Architecture constraints: append #16 after qa-spec #15; mirror the additive-criterion shape (#14 present-only guard, #28/#29 Flag/Do-NOT-flag/Evidence/**Must-fix.**). The wc-l sub-step mirrors how the skill already resolves config + interpolates.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/qa-spec.md**
  - Anchor: end of `## Review Criteria` list, after criterion 15 (line 38), before `## Output Format` (line 47)
  - Current:
    ```
    15. **Deliberation grounding provenance (when present):** ... Add no finding on the UNAVAILABLE/SKIPPED path.
    ```
  - Target: append criterion 16:
    ```
    16. **Artifact over budget (FR-014) (activate when the orchestrator supplies budget values; skip if absent — not an error).** The orchestrator interpolates, for spec.md and (when present) deliberation.md, the artifact's actual line count plus its soft and hard budgets (`plugins/spec-flow/reference/artifact-budgets.md`). Judge from the supplied count — do NOT count lines yourself.
        Flag (Must-fix):
        - An artifact whose supplied line count exceeds its HARD ceiling → name the class, actual vs hard lines, and split/condense guidance (split the piece per the qa-prd ≤7-AC rule, hoist detail to a reference doc, or cut restatement). There is NO waiver — do not accept an inline waiver comment.
        Advisory only (NOT must-fix):
        - A count over SOFT but under HARD → note it as advisory; add no must-fix.
        Do NOT flag:
        - A count at or under soft; an artifact with no supplied budget (skip).
        Evidence: quote the supplied count and the exceeded ceiling. **Must-fix on hard-ceiling breach only.**
    ```
  - Done: #16 present with three branches + no-waiver clause + supplied-count directive.
  - Verify: `grep -n "Artifact over budget (FR-014)" plugins/spec-flow/agents/qa-spec.md` returns a match.

  **T-2: MODIFY plugins/spec-flow/skills/spec/SKILL.md**
  - Anchor: Phase 4 step 2 (line 263), the iteration-1 Full-mode dispatch ("interpolate the full spec, PRD sections, charter files …, manifest piece, and NN-P …")
  - Current:
    ```
    2. **Iteration 1 (full review):** Compose prompt with `Input Mode: Full`: interpolate the full spec, PRD sections, charter files (...), manifest piece, and NN-P from the PRD's Non-Negotiables (Product) section. Dispatch:
    ```
  - Target: add a budget-resolution sub-step (applies to BOTH the iter-1 and the focused-re-review dispatch — P3) immediately before the dispatch: "Resolve `artifact_budgets` from `.spec-flow.yaml` (absent ⇒ `reference/artifact-budgets.md` defaults). Run `wc -l` on `spec.md` and, if it exists on the piece branch, `deliberation.md`. Interpolate into the qa-spec prompt, for each: `<class> is N lines; soft S; hard H` so criterion #16 judges from the count, not from the (possibly-truncated) interpolated text."
    Add a worked example (dense-algorithm guard 2c — 3-step resolve→count→interpolate sequence): `<!-- Example: artifact_budgets absent → spec_md hard=520. wc -l spec.md = 540. Interpolate "spec.md is 540 lines; soft 300; hard 520" → #16 must-fix. deliberation.md absent → no deliberation row interpolated. -->`
  - Anchor 2: Phase 5 finalize (the metrics write step, per `reference/metrics-artifact.md` write procedure)
  - Target: when writing `spec:` metrics, also upsert `spec.budget_compliance.spec_md` and (if deliberation.md exists) `spec.budget_compliance.deliberation_md` with `{lines, hard, status}` per the Phase-3 schema.
  - Done: budget-resolution sub-step present at the qa-spec dispatch with worked example; both dispatch sites covered (P3); spec finalize writes budget_compliance.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  **Per-change checks:**
  - T-1: `grep -c "Artifact over budget (FR-014)" plugins/spec-flow/agents/qa-spec.md` — Expected: 1
  - T-1: LLM-agent-step: read qa-spec #16 and confirm all three branches (hard→must-fix, soft→advisory, absent→skip) and the explicit no-waiver clause are present.
  - T-2: `grep -c "wc -l" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1
  - T-2: `grep -c "artifact-budgets.md\|artifact_budgets" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1
  - T-2: LLM-agent-step: read the spec/SKILL.md Phase 4 edit and confirm (a) budgets resolved from .spec-flow.yaml with reference-doc default, (b) `wc -l` on spec.md AND deliberation.md, (c) the worked example present, (d) spec finalize writes spec.budget_compliance.
  **Phase-level check:**
  - Run: `grep -n "weasel-waived" plugins/spec-flow/agents/qa-spec.md | wc -l` — Expected: 1 (only the pre-existing #13 weasel mechanism; #16 adds NO new waiver) — confirms AC-5.
  - Failure: #16 missing a branch; wc-l absent; a new waiver token in #16.

- [x] **[QA]** Phase review
  - Review against: AC-2, AC-4, AC-5, AC-6, AC-7
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 5: qa-plan #32 + plan-skill wc-l interpolation + plan-side metrics write
Why serial: this phase's plan-side `wc -l`/budget-interpolation idiom must mirror the exact phrasing established in Phase 4's spec-side edit (one consistent mechanism across both skills); and both phases edit the QA review machinery itself, so per-phase Opus QA on each is worth more than the parallel wall-clock saving.
**Exit Gate:** qa-plan.md has criterion #32 evaluating per-phase AND total with the three branches; plan/SKILL.md Phase 3 resolves budgets + runs `wc -l` (total + per `### Phase`/`#### Sub-Phase` max) and interpolates; plan finalize writes `plan.budget_compliance`; cross-phase metrics consistency verify passes.
**ACs Covered:** AC-3, AC-4, AC-5, AC-7
**In scope:** MODIFY `plugins/spec-flow/agents/qa-plan.md`, MODIFY `plugins/spec-flow/skills/plan/SKILL.md`
**NOT in scope:** qa-spec.md / spec/SKILL.md (Phase 4)
**Steps traversed (P2):** plan/SKILL.md Phase 3 (QA Loop) step 2 (iteration-1 dispatch) and the Phase-4 finalize metrics-write step; the budget sub-step is added inside the existing Phase 3 dispatch path.
**Dispatch sites (P3):** qa-plan is dispatched in plan/SKILL.md Phase 3 step 2 (iteration 1, Full) and step 3 (iteration 2+, Focused re-review). Both must interpolate the plan budget counts.
**Charter constraints honored in this phase:**
- CR-008 (thin-orchestrator): skill computes `wc -l` (total + per-phase); agent judges.
- NN-C-008 (self-contained prompt): counts + budgets interpolated.
- NN-C-003 (additive): #32 carries the activation guard.
- NN-P-001; NN-P-005.

- [x] **[Implement]** Add criterion #32, the wc-l interpolation, and the plan-side metrics write
  - Architecture constraints: append #32 after qa-plan #31 (line 191); mirror the #28/#31 additive shape and Phase-4's spec-side wc-l phrasing exactly.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/qa-plan.md**
  - Anchor: after criterion 31 (starts line 181, ends line 191), before `## Output Format` (line 193)
  - Current:
    ```
    31. **Test Data block presence + completeness (FR-003) ...** ... **Must-fix.**

    ## Output Format
    ```
  - Target: insert criterion 32 before `## Output Format`:
    ```
    32. **Plan over budget (FR-014) (activate when the orchestrator supplies budget values; skip if absent — not an error).** The orchestrator interpolates plan.md's total line count and its largest per-phase line count, each with soft + hard budgets (`plugins/spec-flow/reference/artifact-budgets.md`). Judge from the supplied counts — do NOT count lines yourself.
        Flag (Must-fix):
        - Total OR any per-phase count over its HARD ceiling → name which (total / phase), actual vs hard, and split/condense guidance (split the piece per the qa-prd ≤7-AC rule, or hoist detail to a reference doc). NO waiver.
        Advisory only (NOT must-fix):
        - A count over SOFT but under HARD → advisory note.
        Do NOT flag:
        - Counts at/under soft; no supplied budget (skip).
        Evidence: quote the supplied count and the exceeded ceiling. **Must-fix on hard-ceiling breach only.**
    ```
  - Done: #32 present; evaluates total AND per-phase; three branches; no waiver.
  - Verify: `grep -n "Plan over budget (FR-014)" plugins/spec-flow/agents/qa-plan.md` returns a match.

  **T-2: MODIFY plugins/spec-flow/skills/plan/SKILL.md**
  - Anchor: Phase 3 step 2 (line 625), the iteration-1 Full dispatch
  - Current:
    ```
    2. **Iteration 1 (full review):** Dispatch QA agent (Opus) with `Input Mode: Full`, the full plan, spec, PRD sections, and charter skills (...).
    ```
  - Target: add a budget-resolution sub-step before the dispatch (covering BOTH iter-1 and focused re-review — P3): "Resolve `artifact_budgets` from `.spec-flow.yaml` (absent ⇒ `reference/artifact-budgets.md` defaults). Run `wc -l` on `plan.md` for the total; compute the largest per-phase count by counting lines between `### Phase`/`#### Sub-Phase` anchors. Interpolate `plan.md total is N lines; soft 750; hard 1000` and `largest phase is M lines; soft 90; hard 220` into the qa-plan prompt so #32 judges from the counts." Use the SAME phrasing pattern as spec/SKILL.md Phase 4 (Why-serial).
  - Anchor 2: Phase 4 finalize step 5a (the metrics write)
  - Target: when writing `plan:` metrics, also upsert `plan.budget_compliance.plan_md_total` and `plan.budget_compliance.plan_md_max_phase` per the Phase-3 schema.
  - Done: budget sub-step present (total + per-phase max); both dispatch sites covered; plan finalize writes budget_compliance; phrasing mirrors Phase 4.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks + cross-phase metrics-schema consistency oracle
  **Per-change checks:**
  - T-1: `grep -c "Plan over budget (FR-014)" plugins/spec-flow/agents/qa-plan.md` — Expected: 1
  - T-1: LLM-agent-step: read #32 and confirm it evaluates BOTH total and per-phase, with the three branches and no waiver.
  - T-2: `grep -c "wc -l" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥1
  - T-2: `grep -c "Phase\b.*anchor\|per-phase" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥1 (per-phase counting present)
  **Cross-phase schema-consistency check (2d — metrics.yaml budget_compliance):**
  - The field names written by spec/SKILL.md (Phase 4: `spec.budget_compliance.{spec_md,deliberation_md}`) and plan/SKILL.md (Phase 5: `plan.budget_compliance.{plan_md_total,plan_md_max_phase}`) must match the schema defined in `reference/metrics-artifact.md` (Phase 3).
  - Run: LLM-agent-step: read `reference/metrics-artifact.md` budget_compliance schema, then grep spec/SKILL.md and plan/SKILL.md for the budget_compliance leaf names; confirm every leaf written by a skill is defined in the schema and vice versa (no drift).
  - Run: `grep -rn "budget_compliance" plugins/spec-flow/reference/metrics-artifact.md plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md` — Expected: matches in all three files with consistent leaf names.
  **Cross-phase budget-number consistency (reference doc is SSOT):**
  - Run: LLM-agent-step: confirm qa-spec #16, qa-plan #32, and both SKILL.md interpolation steps cite `reference/artifact-budgets.md` for budget values and do NOT hardcode a different number than the reference table.
  - Failure: leaf-name drift between schema and writers; a budget number in a criterion/SKILL that contradicts the reference table.

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-4, AC-5, AC-7
  - Diff baseline: git diff <phase_start>..HEAD

### Phase 6: Version bump, CHANGELOG, marketplace sync
**Exit Gate:** all three version descriptors read 5.12.0; CHANGELOG has a `## [5.12.0]` block; marketplace entry synced; citation-consistency sweep clean.
**ACs Covered:** (none — release mechanics; honors NN-C-009/001/007)
**In scope:** MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`, `plugins/spec-flow/plugin.json`, `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`
**NOT in scope:** any behavioral change (Phases 1–5)
**Charter constraints honored in this phase:**
- NN-C-009 (version bump all descriptors), NN-C-001 (plugin/marketplace sync), NN-C-007 (CHANGELOG Keep-a-Changelog format).

- [x] **[Implement]** Bump version + CHANGELOG + marketplace
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/.claude-plugin/plugin.json**
  - Anchor: line 4 `"version": "5.11.0",` → `"version": "5.12.0",`
  - Done: reads 5.12.0.

  **T-2: MODIFY plugins/spec-flow/plugin.json**
  - Anchor: line 4 `"version": "5.11.0",` → `"version": "5.12.0",`
  - Done: reads 5.12.0.

  **T-3: MODIFY .claude-plugin/marketplace.json**
  - Anchor: spec-flow entry `"version": "5.11.0",` → `"version": "5.12.0",`
  - Done: spec-flow entry reads 5.12.0.

  **T-4: MODIFY plugins/spec-flow/CHANGELOG.md**
  - Anchor: top, after `# Changelog` title (and any `## [Unreleased]`)
  - Target: add `## [5.12.0] — 2026-06-10` with an `### Added` block: artifact-budgets reference doc, qa-spec #16 / qa-plan #32 budget gates, `.spec-flow.yaml artifact_budgets:` overrides, `metrics.yaml budget_compliance` passive metadata.
  - Done: new version block present with ≥1 grouping.

- [x] **[Verify]** Version-sync + citation-consistency sweep
  **Per-change checks:**
  - Run: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name=="spec-flow") | .version' .claude-plugin/marketplace.json)` — Expected: no output (NN-C-001 sync).
  - Run: `grep -c '"version": "5.12.0"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` — Expected: 1 each.
  - Run: `grep -c "## \[5.12.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1.
  **Citation-consistency sweep:**
  - Run: LLM-agent-step: confirm every file that cites `reference/artifact-budgets.md` (qa-spec.md #16, qa-plan.md #32, metrics-artifact.md, spec/SKILL.md, plan/SKILL.md) resolves to the created file and the reference doc's "cited by" preamble names them all (bidirectional citation integrity).
  - Failure: version mismatch; missing CHANGELOG block; a dangling citation.

- [x] **[QA]** Phase review
  - Review against: NN-C-009/001/007 honoring
  - Diff baseline: git diff <phase_start>..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | reference doc + config define per-class soft/hard budgets + override keys | COVERED | Phase 1, Phase 2 |
| AC-2 | qa-spec #16 must-fix on hard-ceiling breach (advisory/skip branches) | COVERED | Phase 4 |
| AC-3 | qa-plan #32 evaluates per-phase AND total | COVERED | Phase 5 |
| AC-4 | orchestrator computes wc -l, agent judges from supplied count | COVERED | Phase 4 (spec), Phase 5 (plan) |
| AC-5 | irreducible overage → piece-split; no waiver token added | COVERED | Phase 1, Phase 4, Phase 5 |
| AC-6 | deliberation.md forward-bind + grandfather + 350 ceiling | COVERED | Phase 1, Phase 4 |
| AC-7 | budget compliance recorded as passive metrics metadata | COVERED | Phase 3 (schema), Phase 4 (spec write), Phase 5 (plan write) |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | file-check | `test -f plugins/spec-flow/reference/artifact-budgets.md && grep -cE "spec\.md\|plan\.md\|research\.md\|deliberation\.md\|learnings\.md" plugins/spec-flow/reference/artifact-budgets.md` | file exists; ≥6 class matches |
| AC-1 | shell | `grep -c artifact_budgets plugins/spec-flow/templates/pipeline-config.yaml` | ≥1 |
| AC-2 | agent-step | Read qa-spec.md #16; confirm hard→must-fix, soft→advisory, absent→skip branches + no-waiver | all three branches + no-waiver present |
| AC-3 | agent-step | Read qa-plan.md #32; confirm per-phase AND total evaluation + three branches | present |
| AC-4 | shell | `grep -c "wc -l" plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md` | ≥1 each |
| AC-5 | shell | `grep -c weasel-waived plugins/spec-flow/agents/qa-spec.md` (must stay 1 — the pre-existing #13) and `grep -L weasel plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/reference/artifact-budgets.md` | qa-spec stays 1; no waiver token in qa-plan/reference doc |
| AC-6 | agent-step | Read artifact-budgets.md deliberation.md section | forward-bind + grandfather baseline + 350 hard present |
| AC-7 | shell | `grep -c budget_compliance plugins/spec-flow/reference/metrics-artifact.md` | ≥4 |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs. All boundary surfaces here are documentation/config (reference-doc budget table, `.spec-flow.yaml artifact_budgets:` keys, `metrics.yaml budget_compliance` schema), governed by the SSOT reference doc and the cross-phase consistency `[Verify]` in Phase 5.

## Parallel Execution Notes

All six phases run serially. Phases 4 and 5 are disjoint in file scope and could form a Phase Group, but are kept serial by deliberate choice (see Phase 5 `Why serial:`): the wc-l/interpolation idiom must be consistent across both skills, and both edit the QA review machinery, where per-phase Opus QA is worth more than parallel wall-clock. Phase ordering is dependency-driven: 1 (budgets) → 2 (config) → 3 (metrics schema) → 4 (spec gate+write) → 5 (plan gate+write, cross-phase metrics consistency) → 6 (version).

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase's [Implement] Change Specification Blocks, spec ACs, the [Verify] commands, arch constraints, introspection.md anchors | Spec rationale, brainstorming history, other phases' diffs |
| Verify | The phase's [Verify] commands + expected outputs, spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
