---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
review_board_variant: doc-as-code
---

# Plan: gate-scaling

**Spec:** docs/prds/exec-ready/specs/gate-scaling/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** merged

## Overview

Ship FR-012 as the 3-cluster spine from `deliberation.md` (`[DELIBERATION-CONSUMED]`, high-confidence — all 5 lenses returned): per-AC verifiability tagging → tiered evidence-digest sign-off gates → review-board cost controls. Operator decisions folded: spec gate rests on QA-clean ∧ zero-markers (VOQ-1 = Option B, tags metrics-only at spec time); blind→edge-case swap wired at **both** execute Final Review and the out-of-band review-board skill (VOQ-2); the 2nd edge-case carries a differentiated lens seed (VOQ-3).

**Track rationale (Non-TDD / Implement, per charter-tools).** Every deliverable is markdown (reference doc, agent prose, SKILL.md prose) or YAML (config, metrics schema). The repo ships no unit-test runner for these and reference docs are not unit-tested (charter-tools); adding a framework would violate NN-C-002. Phases use the **Implement track** with structural `[Verify]` (grep / file-check / LLM-agent-step) in place of `[TDD-Red]`/`[Write-Tests]`. `[Write-Tests]` is **N/A** (no unit-test surface for markdown/YAML); qa-plan #31 (Test Data block) correctly skips for all phases. Correctness validation is by (a) the Phase-8 citation- and schema-consistency sweep, (b) the qa-spec/qa-plan/execute skills as live consumers, and (c) the FR-013 e2e harness (pipeline-e2e, merged). Mirrors the merged `artifact-budgets` plan shape.

**Sequencing.** Phases 1–4 are the foundation (tag, the `gate-scaling.md` contract, metrics schema, the triage agent). Phases 5–8 wire the consumers, each citing `gate-scaling.md` by anchor. Serial by design — see Parallel Execution Notes.

**Coordination flag (exec-guardrails).** Phase 7 edits `skills/execute/SKILL.md` (Final Review Step 1/3/4); the live `exec-guardrails` piece also edits this file (tdd-red hash gate, amendment budget). Neither piece is a dependency of the other, but at merge the two execute edits touch adjacent regions. Phase 7's Change Specs are anchored on stable Step headings (`### Step 1`, `### Step 3`, `### Step 4`) rather than line numbers to minimize collision; resolve the merge order at integration time.

## Architectural Decisions

### ADR-1: `review_board_variant` is a per-piece HINT, never aliased to `tdd:`
**Context:** Doc-as-code board composition needs a trigger. `tdd: false` already exists and already drives `qa_max_iterations: auto → 5`. Reusing it would overload one field and silently drop blind coverage on any non-TDD *code* piece.
**Decision:** A new, independent, optional per-piece annotation `review_board_variant: doc-as-code` (absent → today's 8-seat board). The annotation is a HINT; the binding board-composition decision lives in execute Final Review Step 1 (and the review-board skill), the layers that own board composition. No file-extension classifier (dropped at deliberation — net-new disagreement surface for zero AC gain).
**Alternatives considered:** (a) reuse `tdd: false` — rejected, drops blind on code-bearing non-TDD pieces; (b) file-extension diff classifier — rejected, scope creep beyond AC-3 + annotation-vs-classifier disagreement.
**Consequences:** Board roster and breaker budget stay orthogonal; absent-path is byte-identical to today (NN-C-003). Relies on planner discipline to set the annotation (fail-safe: un-annotated doc piece simply gets today's full board).
**Charter alignment:** NN-C-003 (additive-optional), NN-P-001 (never weakens the merge gate's coverage on code).

### ADR-2: Spec gate rests on QA-clean ∧ zero-markers; tags are metrics-only at spec time (VOQ-1 = Option B)
**Context:** At the spec gate no check has run; the machine-checkable tag is self-authored by the same pipeline LLM that benefits from the cheap gate. Gating on tag honesty would be self-certification.
**Decision:** The spec-gate clean predicate is `QA-clean ∧ zero surviving [PENDING-DECISION]/[NEEDS CLARIFICATION]` — both independently machine-verifiable. Tags are recorded for metrics but are NOT a spec-gate input. A dishonest machine tag self-corrects at the plan/Final-Review gates (no assemblable evidence → full prompt).
**Alternatives considered:** (a) Option A — spec gate always full; rejected, contradicts AC-2's literal "spec … render an evidence digest"; (b) Option C — confirm + disclosure + qa-spec re-derives each tag; rejected, adds Opus cost at spec time and still confirms on unrun checks.
**Consequences:** Spec gate participates in cost-scaling without a self-certification hole. The plan/Final-Review gates carry the real evidence requirement.
**Charter alignment:** NN-P-001 (keystroke preserved), NN-P-005 (no extra Opus needed at spec gate).

### ADR-3: `review-board-triage` is a meta-router, not a reviewer
**Context:** A cheap pre-filter on fix iterations (Trust-or-Escalate). Re-checking a fix for regression overlaps the blind/edge-case seats.
**Decision:** Triage renders a meta routing verdict (contested-vs-settled) only; it is forbidden from emitting net-new correctness findings. It routes to the full board on three conservative triggers and fails open. Pinned inside Step 3's existing iteration so triage-only cycles do not decrement `L`.
**Alternatives considered:** (a) reuse an existing reviewer as the pre-filter — rejected, no single seat holds the full prior board set to adjudicate contested/new; (b) let triage emit findings — rejected, duplicates seated reviewers (architecture lens).
**Consequences:** The pre-filter can only ever *skip a redundant full-board cycle*, never clear a piece for merge — the merge keystroke and breaker are untouched.
**Charter alignment:** NN-P-005 (Opus), NN-P-001 (consequence preserved), CR-008 (narrow executor).

## Phases

All phases use the Implement track (`tdd: false`) — `[Implement]` → `[Verify]` → `[QA]`. The executor branches mechanically on the `[Implement]` marker.

## Integration-Test Registry (M1)

The spec declares three cross-component wirings (spec.md `## Integration Coverage`). **All have zero doubled true externals** — every boundary is internal (skill↔reference citation, orchestrator↔agent dispatch, annotation↔composition), so requirement (b) (contract test per doubled external) is vacuously satisfied and no external is doubled. For this doc-as-code pipeline the "real wired path" verification is structural (anchor-resolution / dispatch-presence / absent-path-identity), authored in the completing phase's `[Integration-Test]` step. `skeleton_sha256`/`completed_sha256` are runtime-populated (left `—`).

| ID | Path | Boundary (inside) | Doubled externals (contract test) | AC | registered_in_phase | completes_in_phase | skeleton_sha256 | completed_sha256 |
|----|------|-------------------|-----------------------------------|----|--------------------|---------------------|-----------------|------------------|
| INT-1 | `gate-scaling.md` → spec/plan/execute/review-board cite-by-anchor | gate-scaling.md + the 4 consuming SKILL.md gate/board sites | none (internal citation) | AC-8 | 2 | 8 | — | — |
| INT-2 | execute Final Review Step 3 orchestrator → `review-board-triage` dispatch | execute Step 3 fix loop + the triage agent | none (internal dispatch) | AC-19, AC-20 | 4 | 7 | — | — |
| INT-3 | `review_board_variant` annotation → board composition (execute Step 1 + review-board) | the annotation reader + the two composition sites | none (internal wiring) | AC-15, AC-17 | 7 | 8 | — | — |

### Phase 1: AC verifiability tag + qa-spec #17
**Exit Gate:** template AC block carries a tagged Independent Test line; qa-spec #17 (delta-conditioned) present in both qa-spec files; greps pass.
**ACs Covered:** AC-1, AC-2, AC-3
**In scope:** `templates/spec.md` (AC block + tag convention note); `agents/qa-spec.md` (criterion #17); `agents/qa-spec.agent.md` (mirror).
**NOT in scope:** the metrics ratio that consumes tag counts — Phase 3/5; gate predicates — Phases 5–7.
**Charter constraints honored in this phase:**
- NN-C-003 (backward-compat): #17 is delta-conditioned — fires only on ACs added/modified in the current authoring delta and is skipped in Full mode when the spec carries zero tagged ACs, so legacy untagged specs never regress.

- [x] **[Implement]** Add the tag to the template + criterion #17 to qa-spec (+ mirror)

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/templates/spec.md`**
  - Anchor: `## Acceptance Criteria` block (lines 53–56)
  - Current:
    ```
    53  ## Acceptance Criteria
    54  AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}}
    55    Independent Test: {{how_to_verify_in_isolation}} (for an integration-bearing AC, the Independent Test may assert the real wired path, not isolation)
    ```
  - Target: replace the `Independent Test:` line with a tagged form and add a one-line convention note directly under the `## Acceptance Criteria` heading. New text:
    `AC-1: Given …, When …, Then …`
    `  Independent Test [machine: <named check — a grep/script/test that decides>]: <how to verify>`
    `  — or — Independent Test [judgment: <named arbiter — who decides>]: <what they inspect>`
    Convention note (under the heading): `<!-- Every AC's Independent Test line MUST carry exactly one verifiability tag: [machine: <named check>] (a deterministic grep/script/test decides) or [judgment: <named arbiter>] (a named human decides). Untagged/empty-valued ACs are qa-spec #17 must-fix. -->`
  - Done: the template AC block shows both tag variants and the convention note; no `{{...}}` placeholder remains on the Independent Test line shape.
  - Verify: `grep -nE "Independent Test \[(machine|judgment):" plugins/spec-flow/templates/spec.md` returns ≥2 matches.

  **T-2: MODIFY `plugins/spec-flow/agents/qa-spec.md`**
  - Anchor: end of the numbered Review Criteria list (criterion #16 ends ~line 53); insert #17 after it.
  - Current (criteria list tail): `16. **Artifact over budget (FR-014) …**` is the last numbered criterion before `## Output Format` (line 55).
  - Target: insert a new criterion immediately after #16 and before `## Output Format`:
    `17. **AC verifiability tag (FR-012).** Every AC's Independent Test line must carry exactly one tag — \`[machine: <named check>]\` or \`[judgment: <named arbiter>]\` — with a non-empty named value. An AC whose Independent Test line lacks a tag, or carries an empty value, is must-fix. **Delta-conditioning:** in Focused re-review mode, apply #17 only to ACs added or modified in the supplied delta. In Full mode, apply #17 only when the spec carries ≥1 tagged AC; a spec with zero tagged ACs is a legacy untagged spec and #17 is skipped (no finding) — NN-C-003. Evidence: quote the untagged AC id and its Independent Test line.`
  - Done: `### must-fix`-eligible criterion #17 present with the delta-conditioning + zero-tag-skip clauses.
  - Verify: `grep -n "17\. \*\*AC verifiability tag" plugins/spec-flow/agents/qa-spec.md` returns a match; `grep -c "Delta-conditioning" plugins/spec-flow/agents/qa-spec.md` ≥ 1.

  **T-3: MODIFY `plugins/spec-flow/agents/qa-spec.agent.md`** (paired mirror)
  - Anchor: the mirror's criteria list (same #16 tail).
  - Target: insert the identical #17 criterion text from T-2 at the matching position.
  - Done: mirror carries #17 verbatim-equivalent to qa-spec.md.
  - Verify: `grep -c "17\. \*\*AC verifiability tag" plugins/spec-flow/agents/qa-spec.agent.md` returns 1.

- [x] **[Verify]** Structural checks
  - T-1: `grep -nE "Independent Test \[(machine|judgment):" plugins/spec-flow/templates/spec.md` — Expected: ≥2 matches.
  - T-2/T-3: `grep -l "17\. \*\*AC verifiability tag" plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md` — Expected: both files listed.
  - Delta-conditioning present: `grep -c "Delta-conditioning\|zero tagged AC\|legacy untagged" plugins/spec-flow/agents/qa-spec.md` — Expected: ≥1.
  - Failure: any grep returns 0 / only one file listed.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-3
  - Diff baseline: git diff phase_1_start..HEAD

### Phase 2: Create the SSOT — `reference/gate-scaling.md`
**Exit Gate:** the reference doc exists with all six named anchors + the two differentiated seeds; greps pass.
**ACs Covered:** AC-7, AC-10, AC-11, AC-12, AC-13, AC-16
**In scope:** CREATE `plugins/spec-flow/reference/gate-scaling.md`.
**NOT in scope:** wiring the skills to cite it — Phases 5–8.
**Charter constraints honored in this phase:**
- CR-008 (thin-orchestrator / cite-don't-restate): the clean-gate predicate, the three per-gate evidence rules, the digest-payload contract, and the board-swap rule live ONLY here; skills cite by anchor. Defeats the ADR-3 evidence-prose drift the architecture lens flagged.

- [x] **[Implement]** Author the SSOT reference doc

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/gate-scaling.md`**
  - Structure outline (H2 anchors are load-bearing — skills cite `gate-scaling.md#<anchor>`):
    - Title + one-paragraph purpose ("single source of truth for verifiability-scaled sign-off gates and review-board cost controls; cited by anchor from spec/plan/execute/review-board").
    - `## clean-gate-predicate` — the three-input conjunction: (i) QA returned clean (zero must-fix); (ii) zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` markers (open-bracket scan, mirroring qa-spec #7); (iii) every machine-checkable AC evidenced per the per-gate rule below. State that a gate offers summary-confirm only when its predicate holds; else it renders today's full prompt; a keystroke is ALWAYS required (NN-P-001), nothing auto-advances.
    - `## spec-gate` — predicate = (i) ∧ (ii) ONLY (Option B). Explicit line: "tags are recorded for metrics at spec time and are NOT a gate input; a machine-checkable tag does not unlock summary-confirm at the spec gate (ADR-2). Conjunct (iii) does not apply at the spec gate — no check has run."
    - `## plan-gate` — predicate = (i) ∧ (ii) ∧ (iii) where evidence for each machine-checkable AC = an AC-Coverage-Matrix row marked `covered` with a concrete `file:line` (a vague pointer fails per `reference/ac-matrix-contract.md`).
    - `## final-review-gate` — predicate = (i) ∧ (ii) ∧ (iii) where evidence = executed `[Verify]`/oracle output validated by the verify agent, AND the digest asserts the evidence was produced against current HEAD (or is re-run on the final commit) before summary-confirm.
    - `## evidence-digest-payload` — per machine-checkable AC the digest MUST enumerate: check name, run status, pass/fail count, and a clickable artifact pointer. No bare "all clean ✓".
    - `## failure-mode` — if any machine-checkable AC's evidence cannot be assembled, the gate renders today's full prompt; summary-confirm is never offered on incomplete evidence.
    - `## board-swap-rule` — when `review_board_variant: doc-as-code`, the board-composition layer omits the `review-board-blind` seat and dispatches a SECOND `review-board-edge-case` seat; seat count stays 8; absent → today's roster (incl. blind). Define the two differentiated lens seeds injected at dispatch: **seed-A (structural / pointer-integrity)** — broken cross-references, unresolved `§`/anchor links, stale `file:line` citations, missing `.agent.md` mirror edits, dangling cited IDs; **seed-B (content / semantic)** — cross-doc contradictions, skill-vs-reference rule drift, example/contract mismatch, unhandled prose edge cases. State the swap applies at execute Final Review Step 1 and the out-of-band review-board skill.
  - Pattern (anchored-subsection + cite-by-anchor idiom from a peer SSOT doc, e.g. `reference/artifact-budgets.md` / `reference/ac-matrix-contract.md`): all H2 headings are lowercase-hyphenated `## <anchor>` so GitHub-style fragment anchors match exactly; consumers cite `reference/gate-scaling.md#<anchor>`.
  - Done: file exists; all six anchors (`clean-gate-predicate`, `spec-gate`, `plan-gate`, `final-review-gate`, `evidence-digest-payload`, `board-swap-rule`) present as lowercase-hyphenated headings; `failure-mode` present; seed-A and seed-B both named.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks on the reference doc
  - Anchors present (lowercase-hyphenated, GitHub-anchor-safe): `grep -cE "^## (clean-gate-predicate|spec-gate|plan-gate|final-review-gate|evidence-digest-payload|board-swap-rule|failure-mode)$" plugins/spec-flow/reference/gate-scaling.md` — Expected: 7.
  - Option B explicit: `grep -c "NOT a gate input\|not a gate input" plugins/spec-flow/reference/gate-scaling.md` — Expected: ≥1 (in `## spec-gate`).
  - HEAD-freshness: `grep -c "current HEAD\|re-run on the final commit" plugins/spec-flow/reference/gate-scaling.md` — Expected: ≥1 (in `## final-review-gate`).
  - Digest payload 4 fields: LLM-agent-step — read `## evidence-digest-payload` and confirm it lists check name, run status, pass/fail count, and artifact pointer. Expected: all four present.
  - Seeds: `grep -c "seed-A\|seed-B\|pointer-integrity\|content / semantic\|content/semantic" plugins/spec-flow/reference/gate-scaling.md` — Expected: ≥2.
  - Failure: any count below expected.

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-10, AC-11, AC-12, AC-13, AC-16
  - Diff baseline: git diff phase_2_start..HEAD

### Phase 3: Extend the metrics schema (tag ratio + fallback leaves)
**Exit Gate:** metrics-artifact.md documents the new additive `spec:` leaves; schema_version unchanged (1); greps pass.
**ACs Covered:** AC-4, AC-6
**In scope:** `reference/metrics-artifact.md` — schema + field semantics for the verifiability ratio leaf and the `gate_scaling` fallback leaves.
**NOT in scope:** the actual writes — spec-side ratio write is Phase 5; per-gate fallback writes are Phases 5/6/7.
**Charter constraints honored in this phase:** none unique (additive schema; NN-C-003 allocated to Phase 1).

- [x] **[Implement]** Add the schema leaves + field semantics

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/reference/metrics-artifact.md`**
  - Anchor: the `## Schema` `spec:` block (~lines 18–33) and the `## Field semantics` list.
  - Current (schema sample): the `spec:` block lists `qa_rounds`, `qa_iterations`, `research_artifact`, `budget_compliance`. `schema_version: 1` at line 14; line 80 states "schema_version incremented only on a breaking schema change."
  - Target: add to the `spec:` block (additive leaves, schema_version stays 1):
    `  ac_verifiability:` with sub-leaves `machine: <int>`, `judgment: <int>`, `machine_checkable_ratio: <float 0..1>` (machine / (machine+judgment)); and a top-level `gate_scaling:` block with `spec_gate`, `plan_gate`, `final_review_gate`, each `{offered_summary_confirm: <bool>, fell_back: <bool>, reason: <str|null>}`. Add matching `## Field semantics` bullets: `spec.ac_verifiability.*` written by the spec skill at finalize; `[METRICS-ABSENT]` when the spec carries no tags. `gate_scaling.<gate>.fell_back` = true when the gate's clean predicate held on QA-clean but the gate still rendered the full prompt because a machine-checkable AC's evidence could not be assembled (the full-gate fallback rate). All additive, passive metadata (ADR-3) — `scripts/metrics-aggregate` does NOT consume them. State explicitly that `schema_version` stays 1 (additive, NN-C-003).
  - Done: both leaf groups documented in `## Schema` and `## Field semantics`; an explicit "schema_version stays 1" note present.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  - `grep -c "ac_verifiability\|machine_checkable_ratio" plugins/spec-flow/reference/metrics-artifact.md` — Expected: ≥2.
  - `grep -c "gate_scaling\|fell_back\|offered_summary_confirm" plugins/spec-flow/reference/metrics-artifact.md` — Expected: ≥2.
  - schema_version unchanged: `grep -n "schema_version: 1" plugins/spec-flow/reference/metrics-artifact.md` — Expected: present; `grep -c "schema_version: 2" plugins/spec-flow/reference/metrics-artifact.md` — Expected: 0.
  - Failure: any count off.

- [x] **[QA]** Phase review
  - Review against: AC-4, AC-6
  - Diff baseline: git diff phase_3_start..HEAD

### Phase 4: `review-board-triage` agent (+ mirror)
**Exit Gate:** both agent files exist with bare name + `model: opus`; the meta-router constraints + 3 triggers present; greps pass.
**ACs Covered:** AC-18, AC-19
**In scope:** CREATE `agents/review-board-triage.md` and `agents/review-board-triage.agent.md`.
**NOT in scope:** wiring the agent into execute Step 3 — Phase 7.
**Charter constraints honored in this phase:**
- NN-C-004 (bare agent name): frontmatter `name: review-board-triage` (no plugin prefix).
- NN-C-008 (self-contained prompt): the prompt declares it receives the just-fixed findings, the fix diff, and the recorded prior deduped board must-fix set — assumes no conversation history.
- NN-P-005 (Opus, no silent downgrade): frontmatter `model: opus`; the prompt states triage is an adversarial gate that runs on Opus.
- CR-001 (agent frontmatter schema): `name` + `description` YAML frontmatter.

- [x] **[Implement]** Author the triage agent + mirror

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/agents/review-board-triage.md`**
  - Structure outline (pattern: peer agent frontmatter from `agents/review-board-blind.md` lines 1–4):
    - Frontmatter: `name: review-board-triage`; `description:` ("Internal agent — dispatched by spec-flow:execute at Final Review Step 3 fix loop. Do NOT call directly. Single-Opus meta-router: re-checks just-fixed findings + the fix diff and routes contested/new/out-of-locus to the full board. Renders NO net-new correctness findings. Read-only.").
    - `## Role` — meta routing only (contested-vs-settled). EXPLICITLY: "You do NOT emit net-new correctness findings — that is the seated reviewers' job. You only route."
    - `## Context Provided` — the just-fixed must-fix findings (per-reviewer), the fix diff (`review_iter_M_fix_diff`), and the recorded prior deduped board must-fix set.
    - `## Verdict` — for each fixed finding emit `settled` (the fix resolves it, nothing new, fix stays within the finding's locus) or route to the full board. Three fail-open-to-full-board triggers: (1) **contested** — triage disputes that the fix resolves the finding; (2) **new** — triage detects a finding signal absent from the prior deduped board set; (3) **out-of-locus** — the fix touches files beyond the finding's locus. On ambiguity or inability to decide → route to full board (fail open).
    - `## Rules` — Opus; read-only; no net-new findings; output a per-finding routing verdict + an overall `route-to-full-board: yes|no`.
  - Pattern (frontmatter, from review-board-blind.md):
    ```
    ---
    name: review-board-blind
    description: "Internal agent — dispatched by spec-flow:execute …"
    ---
    ```
  - Done: file exists; frontmatter `name: review-board-triage` + `model: opus`; the no-net-new clause + the three named triggers + fail-open present.
  - Verify: see [Verify].

  **T-2: CREATE `plugins/spec-flow/agents/review-board-triage.agent.md`** (mirror)
  - Target: the paired `.agent.md` mirror of T-1 (same body; per the repo's paired-agent convention — confirmed by `review-board-edge-case.agent.md` existing).
  - Done: mirror exists and matches T-1's constraints.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  - Both files exist: `test -f plugins/spec-flow/agents/review-board-triage.md && test -f plugins/spec-flow/agents/review-board-triage.agent.md && echo OK` — Expected: `OK`.
  - Bare name + opus: `grep -c "^name: review-board-triage$" plugins/spec-flow/agents/review-board-triage.md` — Expected: 1; `grep -c "model: opus\|model: \"opus\"" plugins/spec-flow/agents/review-board-triage.md` — Expected: ≥1.
  - Constraints: `grep -ci "net-new\|no net.new\|do NOT emit" plugins/spec-flow/agents/review-board-triage.md` — Expected: ≥1; `grep -ci "contested\|out-of-locus\|fail open\|fail-open" plugins/spec-flow/agents/review-board-triage.md` — Expected: ≥2.
  - Failure: any check off.

- [x] **[QA]** Phase review
  - Review against: AC-18, AC-19
  - Diff baseline: git diff phase_4_start..HEAD

### Phase 5: Spec-skill wiring (ratio write + spec gate)
**Exit Gate:** spec/SKILL.md Phase 5 step 3a writes the ratio leaf; the spec sign-off cites `gate-scaling.md#spec-gate` with a clean-branch + full-prompt fallback + always-keystroke; greps pass.
**ACs Covered:** AC-5, AC-8, AC-9, AC-14
**In scope:** `skills/spec/SKILL.md` — Phase 5 step 3a (metrics ratio write) and the Phase 4 step 4 / Phase 5 sign-off prose.
**NOT in scope:** plan/execute gates — Phases 6/7; the predicate definitions — already in `gate-scaling.md` (Phase 2).
**Steps traversed (P2):** Phase 4 step 4 (present spec for sign-off, line 287); Phase 5 step 1 (user approves, line 293); Phase 5 step 3a (metrics upsert, line 310). The clean-branch adds a new path through the existing sign-off step; the ratio write extends the existing step-3a upsert.
**Dispatch sites (P3):** none (no agent dispatch contract changed in this phase).
**Charter constraints honored in this phase:** none unique (NN-P-001 allocated to Phase 7; the keystroke is preserved here per AC-9/AC-14).

- [x] **[Implement]** Wire the spec gate + the ratio metrics write

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** (sign-off — Phase 4 step 4 / Phase 5 step 1)
  - Anchor: line 287 `4. When QA returns clean: present spec to user for sign-off.`
  - Current:
    ```
    287  4. When QA returns clean: present spec to user for sign-off.
    ```
  - Target: extend so that when the spec-gate clean predicate (`reference/gate-scaling.md#spec-gate` — QA-clean ∧ zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]`) holds, render the evidence digest (`reference/gate-scaling.md#evidence-digest-payload`) and offer a single-key summary-confirm; otherwise present today's full sign-off prompt unchanged. A keystroke is ALWAYS required on both branches — nothing auto-advances (NN-P-001). Cite the anchors; do NOT restate the predicate. When the gate falls back despite QA-clean (predicate (iii) un-assemblable), record `gate_scaling.spec_gate.fell_back: true` at step 3a.
  - Done: the sign-off step branches on the cited `#spec-gate` predicate, both branches require a keystroke, and the digest is cited (not restated).
  - Verify: see [Verify].

  **T-2: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** (metrics ratio — Phase 5 step 3a)
  - Anchor: line 310 `3a. Write metrics (metrics: auto): …` (the `spec:` block upsert).
  - Current: step 3a upserts `qa_rounds`, `qa_iterations`, `research_artifact`, `spec.budget_compliance`.
  - Target: also compute, from the finalized spec.md AC section, the machine/judgment tag counts and `machine_checkable_ratio`, and upsert `spec.ac_verifiability` per `reference/metrics-artifact.md`. Emit `[METRICS-ABSENT]` (not a divide-by-zero) when the spec carries zero tags. Also upsert `gate_scaling.spec_gate.{offered_summary_confirm, fell_back, reason}` reflecting this run's sign-off path.
  - Done: step 3a writes `spec.ac_verifiability` + `gate_scaling.spec_gate`; `[METRICS-ABSENT]` path named.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  - Gate cite: `grep -c "gate-scaling.md#spec-gate\|gate-scaling.md#Evidence-digest" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1.
  - Keystroke-always: LLM-agent-step — read the modified Phase 4 step 4 / Phase 5 step 1 region and confirm both the clean-branch and the fallback-branch require an explicit operator keystroke (nothing auto-advances). Expected: confirmed.
  - Ratio write: `grep -c "ac_verifiability\|machine_checkable_ratio" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1; `grep -c "METRICS-ABSENT" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1.
  - Failure: any count 0 / agent-step finds an auto-advance path.

- [x] **[QA]** Phase review
  - Review against: AC-5, AC-8, AC-9, AC-14
  - Diff baseline: git diff phase_5_start..HEAD

### Phase 6: Plan-skill wiring (plan gate)
**Exit Gate:** plan/SKILL.md Phase 3 step 4 cites `gate-scaling.md#plan-gate` with clean-branch + fallback + always-keystroke; greps pass.
**ACs Covered:** AC-8, AC-9, AC-14
**In scope:** `skills/plan/SKILL.md` — Phase 3 step 4 / Phase 4 step 1 sign-off.
**NOT in scope:** spec/execute gates — Phases 5/7.
**Steps traversed (P2):** Phase 3 step 4 (present plan for sign-off, line 649); Phase 4 step 1 (user approves, line 653). The clean-branch adds a new path through the existing sign-off step.
**Dispatch sites (P3):** none.
**Charter constraints honored in this phase:** none unique (keystroke preserved per AC-9/AC-14; NN-P-001 allocated Phase 7).

- [x] **[Implement]** Wire the plan gate

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`**
  - Anchor: line 649 `4. Present to user for sign-off.`
  - Current:
    ```
    649  4. Present to user for sign-off.
    ```
  - Target: extend so that when the plan-gate clean predicate (`reference/gate-scaling.md#plan-gate` — QA-clean ∧ zero markers ∧ every machine-checkable AC evidenced by an AC-Coverage-Matrix `covered` row with concrete `file:line`) holds, render the evidence digest and offer single-key summary-confirm; else today's full sign-off prompt. Keystroke always required (NN-P-001). On QA-clean but un-assemblable evidence → record `gate_scaling.plan_gate.fell_back: true` in metrics (Phase 4 step 5a `plan:` block). Cite anchors; do not restate.
  - Done: the plan sign-off branches on the cited `#plan-gate` predicate; both branches keystroke-gated; digest cited.
  - Verify: see [Verify].

- [x] **[Verify]** Structural checks
  - `grep -c "gate-scaling.md#plan-gate" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥1.
  - Keystroke-always: LLM-agent-step — read the modified Phase 3 step 4 region and confirm both branches require an operator keystroke. Expected: confirmed.
  - Fallback metric: `grep -c "plan_gate" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥1.
  - Failure: any count 0 / agent-step finds auto-advance.

- [x] **[QA]** Phase review
  - Review against: AC-8, AC-9, AC-14
  - Diff baseline: git diff phase_6_start..HEAD

### Phase 7: Execute-skill wiring (board swap + triage + final-review gate)
**Exit Gate:** execute Final Review Step 1 reads `review_board_variant` and swaps blind→2nd edge-case (seat count 8, absent→unchanged); Step 3 inserts the triage meta-router inside the existing iteration (L not decremented on triage-only); Step 4 cites `gate-scaling.md#final-review-gate`; greps + agent-steps pass.
**ACs Covered:** AC-8, AC-9, AC-14, AC-15, AC-20, AC-21
**In scope:** `skills/execute/SKILL.md` — Final Review Step 1 (board composition), Step 3 (fix loop / triage insertion), Step 4 (sign-off gate).
**NOT in scope:** the review-board skill swap — Phase 8; the triage agent file — Phase 4 (done); the predicate/seed text — `gate-scaling.md` (Phase 2).
**Steps traversed (P2):** Final Review Step 1 (dispatch ALL EIGHT, lines 1697–1707); Step 2 (triage / record per-reviewer must-fix, line 1744 — the prior board set the new triage reads); Step 3 (fix loop: fix-code 1752 → commit 1758 → re-dispatch reviewers 1760 → breaker L 1762); Step 4 (Human Sign-Off, lines 1808–1813); Step 8 (Final Review Triage — unaffected, but the triage meta-router must not be confused with Step 8). The triage insertion adds a new conditional path between 1758 and 1760; on `route-to-full-board: no` it SKIPS the 1760 re-dispatch and the 1762 `L` decrement.
**Dispatch sites (P3):** blind/edge-case dispatch at Step 1 (lines 1700–1701); reviewer re-dispatch at Step 3 (line 1760); the new triage dispatch (inside Step 3). The board-swap changes the blind/edge-case dispatch contract at Step 1 AND the Step 3 re-dispatch roster — both updated here. (The review-board skill's dispatch site is Phase 8.)
**Charter constraints honored in this phase:**
- NN-P-001 (human gate never removed): the Final Review merge gate (Step 4) keeps an explicit "Request approval to merge" keystroke on both the clean-summary and full branches; the triage meta-router can only skip a redundant full-board cycle, never clear the piece for merge.

- [x] **[Implement]** Wire the board swap, the triage meta-router, and the final-review gate

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** (board swap — Final Review Step 1)
  - Anchor: line 1697 `Read each template … dispatch ALL EIGHT concurrently with Input Mode: Full:` and the blind/edge-case dispatch lines 1700–1701.
  - Current:
    ```
    1697  Read each template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<role>.md` and dispatch ALL EIGHT concurrently with `Input Mode: Full`:
    1700  Agent({ description: "Blind review (iter 1, full)", prompt: <review-board-blind.md + Input Mode: Full + diff only>, model: "opus" })
    1701  Agent({ description: "Edge case review (iter 1, full)", prompt: <review-board-edge-case.md + Input Mode: Full + diff + codebase note>, model: "opus" })
    ```
  - Target: before composing the roster, read `review_board_variant` from the plan front-matter. When `review_board_variant: doc-as-code`, apply the swap from `reference/gate-scaling.md#board-swap-rule`: OMIT the blind dispatch (1700) and dispatch a SECOND edge-case agent — the two edge-case dispatches carry the differentiated seeds (edge-case#1 ← seed-A structural/pointer-integrity; edge-case#2 ← seed-B content/semantic), injected into the prompt. Seat count stays 8. When the annotation is absent, dispatch the roster exactly as today (blind retained, single un-seeded edge-case). Cite the anchor; do not restate the seeds.
  - Done: Step 1 reads the variant, conditionally swaps blind→2nd-edge-case with the two seeds, seat count invariant 8; absent-path unchanged.
  - Verify: see [Verify].

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** (triage meta-router — Final Review Step 3)
  - Anchor: Step 3 fix loop, between the fix commit (line 1758) and the reviewer re-dispatch (line 1760); breaker `L` at line 1762.
  - Current:
    ```
    1758    git commit -m "fix: final-review iter M must-fix"
    1760  - Re-dispatch reviewers (fresh) with `Input Mode: Focused re-review`, …
    1762  - **Circuit breaker:** `qa_max_iterations` (`L`) full review cycles maximum …
    ```
  - Target: insert, between 1758 and 1760, a triage step INSIDE the existing iteration: dispatch `review-board-triage` (Opus) with the just-fixed must-fix findings, `review_iter_M_fix_diff`, and the recorded prior deduped board must-fix set (Step 2, line 1744). If triage returns `route-to-full-board: yes` (any contested / new / out-of-locus trigger, or ambiguity), proceed to the existing 1760 full-board re-dispatch (this consumes one `L` cycle as today). If `route-to-full-board: no` (all fixed findings settled), SKIP the 1760 re-dispatch for this iteration and do NOT decrement `L` — the triage-only cycle is not a full review cycle. Note next to line 1762 that `L` decrements only on a full-board re-dispatch. When the swap is active, the Step 3 re-dispatch roster (1760) uses the swapped set (2nd edge-case, no blind), consistent with T-1.
  - Done: triage dispatch present inside Step 3; the `route-to-full-board` branch governs the 1760 re-dispatch; the L-decrement-only-on-full-board rule stated; absent/off-path (no triage wired) leaves today's loop unchanged.
  - Verify: see [Verify].

  **T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`** (final-review gate — Step 4)
  - Anchor: lines 1808–1813 `### Step 4: Human Sign-Off` … `Request approval to merge`.
  - Current:
    ```
    1810  Present to user:
    1811  - Summary of what was built (phases, files, test counts)
    1812  - Final review results (clean or deferred items)
    1813  - Request approval to merge
    ```
  - Target: when the final-review-gate clean predicate (`reference/gate-scaling.md#final-review-gate` — QA-clean ∧ zero markers ∧ every machine-checkable AC evidenced by executed `[Verify]`/oracle validated against current HEAD) holds, render the evidence digest and offer a single-key summary-confirm to merge; else present today's full "Request approval to merge". Keystroke always required (NN-P-001). On QA-clean but un-assemblable/stale evidence → fall back to the full prompt and record `gate_scaling.final_review_gate.fell_back: true`. Cite anchors; do not restate.
  - Done: Step 4 branches on the cited `#final-review-gate` predicate; both branches keystroke-gated; HEAD-freshness honored via the cited rule.
  - Verify: see [Verify].

- [x] **[Integration-Test]** (completing-phase) INT-2 — orchestrator → `review-board-triage` wired path
  - Boundary: execute Final Review Step 3 fix loop + the `review-board-triage` agent; doubled externals: none (internal subagent dispatch).
  - completes_in_phase: 7
  - Contract tests: none (no doubled true external).
  - Run (real wired path): `grep -c "review-board-triage" plugins/spec-flow/skills/execute/SKILL.md` AND `test -f plugins/spec-flow/agents/review-board-triage.md` — Expected: dispatch reference present in Step 3 AND the agent file the dispatch targets exists (the citation resolves to a real agent). LLM-agent-step — confirm the Step-3 triage dispatch names `review-board-triage` and the agent file's frontmatter `name:` matches. Expected: end-to-end name match (no dangling dispatch).

- [x] **[Verify]** Structural checks
  - Swap: `grep -c "review_board_variant" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1; LLM-agent-step — read the Step 1 swap region and confirm: variant read, blind omitted + 2nd edge-case added with seed-A/seed-B when doc-as-code, seat count 8, absent-path retains blind. Expected: confirmed.
  - Triage: `grep -c "review-board-triage" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1; LLM-agent-step — read the Step 3 region and confirm the triage dispatch sits inside the existing iteration and `L` decrements only on a full-board re-dispatch (not on triage-only). Expected: confirmed.
  - Final-review gate: `grep -c "gate-scaling.md#final-review-gate" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1; LLM-agent-step — confirm both Step-4 branches require an operator keystroke. Expected: confirmed.
  - Absent-path identity (AC-21): LLM-agent-step — confirm that with no `review_board_variant` and no triage route-skip, Step 1 + Step 3 behave exactly as before this change. Expected: confirmed.
  - Failure: any count 0 / any agent-step disconfirms.

- [x] **[QA]** Phase review
  - Review against: AC-8, AC-9, AC-14, AC-15, AC-20, AC-21
  - Diff baseline: git diff phase_7_start..HEAD

### Phase 8: Review-board swap + config + version + consistency sweep
**Exit Gate:** review-board skill swaps blind→2nd-edge-case on `review_board_variant`; config key documented; versions bumped + synced; citation- and schema-consistency sweep passes.
**ACs Covered:** AC-15, AC-17, AC-22
**In scope:** `skills/review-board/SKILL.md` (swap); `templates/pipeline-config.yaml` (config key); `plugins/spec-flow/.claude-plugin/plugin.json` + root `.claude-plugin/marketplace.json` + `plugins/spec-flow/CHANGELOG.md` (version 5.13.0).
**NOT in scope:** execute board swap — Phase 7 (done).
**Steps traversed (P2):** review-board/SKILL.md is a multi-step file; the swap touches the default-lens-set resolution (line 44) and the dispatch block (lines 63–74).
**Dispatch sites (P3):** review-board/SKILL.md blind/edge-case dispatch (lines 66–67). This is the second board surface (VOQ-2); the execute surface was Phase 7.
**Charter constraints honored in this phase:**
- NN-C-001 (version/marketplace sync): plugin.json + marketplace.json bumped to 5.13.0 in the same phase.
- NN-C-009 (bump all version-bearing files): plugin.json, marketplace.json, CHANGELOG all updated.
- CR-007 (config keys documented inline): `review_board_variant` documented in `templates/pipeline-config.yaml` with valid values + default-when-absent.

- [x] **[Implement]** Wire the review-board swap, document the config key, bump versions

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/review-board/SKILL.md`** (out-of-band board swap)
  - Anchor: default lens set (line 44: `blind, edge-case, security, ground-truth, architecture, integration`) and the dispatch block (lines 63–74; blind 66, edge-case 67).
  - Current:
    ```
    44  **Default lens set (no spec/PRD needed):** `blind`, `edge-case`, `security`, `ground-truth`, `architecture`, `integration`.
    66  Agent({ description: "Blind review",        prompt: <review-board-blind.md  + Input Mode: Full + diff only>, model: "opus" })
    67  Agent({ description: "Edge case review",    prompt: <review-board-edge-case.md + Input Mode: Full + diff + codebase note>, model: "opus" })
    ```
  - Target: apply the same `reference/gate-scaling.md#board-swap-rule` — when `review_board_variant: doc-as-code` is in effect for the target, omit `blind` from the default set and add a 2nd `edge-case` with the differentiated seeds (seed-A / seed-B). Absent → today's default set unchanged. Cite the anchor.
  - Done: review-board default set conditionally swaps blind→2nd-edge-case on the variant; absent-path identical to today.
  - Verify: see [Verify].

  **T-2: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`** (config key doc — CR-007)
  - Anchor: the config template (peer keys like `qa_max_iterations`, `refactor`).
  - Target: add a commented `review_board_variant:` key documenting valid value `doc-as-code` and default-when-absent (today's 8-seat board incl. blind); note it is a per-piece plan-front-matter annotation (the config entry documents the surface). Inline comment per CR-007.
  - Done: `review_board_variant` documented with valid values + default.
  - Verify: see [Verify].

  **T-3: MODIFY version-bearing files (NN-C-001/009)**
  - `plugins/spec-flow/.claude-plugin/plugin.json`: `"version": "5.12.2"` → `"5.13.0"`.
  - root `.claude-plugin/marketplace.json`: the spec-flow entry `"version": "5.12.2"` (line 15) → `"5.13.0"`.
  - `plugins/spec-flow/CHANGELOG.md`: add a `## [5.13.0] — <date>` section under `## [Unreleased]` describing FR-012 (verifiability tag + #17; gate-scaling.md; tiered evidence-digest gates with Option-B spec gate; review_board_variant doc-as-code swap at both surfaces with differentiated seeds; review-board-triage meta-router; metrics leaves).
  - Done: all three version strings agree at 5.13.0; CHANGELOG entry present.
  - Verify: see [Verify].

- [x] **[Integration-Test]** (completing-phase) INT-1 + INT-3 — cite-by-anchor + variant→composition wired paths
  - Boundary (INT-1): `gate-scaling.md` + the 4 consuming SKILL.md sites; doubled externals: none (internal citation). Boundary (INT-3): the `review_board_variant` reader + the execute Step-1 and review-board composition sites; doubled externals: none (internal wiring).
  - completes_in_phase: 8
  - Contract tests: none (no doubled true external on either integration).
  - Run (real wired path, INT-1): LLM-agent-step — collect every `gate-scaling.md#<anchor>` citation across spec/plan/execute/review-board SKILL.md and confirm each resolves to a character-identical lowercase-hyphenated `## ` heading in `reference/gate-scaling.md`. Expected: every citation resolves end-to-end (no dangling anchor).
  - Run (real wired path, INT-3): LLM-agent-step — confirm both composition sites (execute Step 1 and review-board default-set) read the same `review_board_variant` annotation and apply the identical `#board-swap-rule` swap, and that the absent-variant path is identical to today at both. Expected: both surfaces consistent; absent-path identity holds (AC-17).

- [x] **[Verify]** Version-sync + citation- and schema-consistency sweep
  - Swap (review-board): `grep -c "review_board_variant" plugins/spec-flow/skills/review-board/SKILL.md` — Expected: ≥1.
  - Config: `grep -c "review_board_variant" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: ≥1.
  - Version sync (NN-C-001): `grep -h '"version"' plugins/spec-flow/.claude-plugin/plugin.json` and the spec-flow entry in `.claude-plugin/marketplace.json` — Expected: both `5.13.0`. CHANGELOG: `grep -c "## \[5.13.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1.
  - **Cross-phase citation-consistency sweep (step 2d):** every consumer cites the SSOT anchors that exist in `gate-scaling.md`. `grep -rl "gate-scaling.md#" plugins/spec-flow/skills/{spec,plan,execute,review-board}/SKILL.md` — Expected: spec, plan, execute (review-board cites the board-swap rule; verify it cites `#board-swap-rule`). For each cited anchor `#X`, confirm a `## X` heading exists in `gate-scaling.md` with an EXACT case-and-hyphen match (GitHub fragment-anchor equivalence): LLM-agent-step — collect all `gate-scaling.md#<anchor>` citations across the four skills and confirm each `<anchor>` is character-identical to a lowercase-hyphenated `## ` heading in `reference/gate-scaling.md`. Expected: no dangling citation (a casing/spacing mismatch is a dangling citation — exactly the seed-A defect class).
  - **Schema-consistency (gate_scaling metrics leaves):** the leaves written by the gates (Phases 5/6/7) match the schema documented in Phase 3. `grep -o "gate_scaling.[a-z_]*" plugins/spec-flow/skills/{spec,plan,execute}/SKILL.md plugins/spec-flow/reference/metrics-artifact.md | sort -u` — Expected: the skill-written leaf names are a subset of the documented `gate_scaling.{spec_gate,plan_gate,final_review_gate}` schema.
  - Failure: version mismatch, dangling anchor citation, or a skill-written metrics leaf absent from the schema doc.

- [x] **[QA]** Phase review
  - Review against: AC-15, AC-17, AC-22
  - Diff baseline: git diff phase_8_start..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | Template AC block requires a verifiability tag | COVERED | Phase 1 |
| AC-2  | qa-spec #17 enforces tag presence, delta-conditioned, mirrored | COVERED | Phase 1 |
| AC-3  | #17 flags new untagged AC; skips legacy untagged spec | COVERED | Phase 1 |
| AC-4  | metrics-artifact documents tag-count + ratio leaf; schema_version 1 | COVERED | Phase 3 |
| AC-5  | spec Phase-5 step-3a writes the ratio leaf; [METRICS-ABSENT] | COVERED | Phase 5 |
| AC-6  | metrics-artifact documents the full-gate fallback-rate leaf | COVERED | Phase 3 |
| AC-7  | gate-scaling.md exists with the six required subsections | COVERED | Phase 2 |
| AC-8  | spec/plan/execute/review-board cite gate-scaling.md by anchor; no restatement | COVERED | Phase 2, Phase 5, Phase 6, Phase 7, Phase 8 |
| AC-9  | each gate has clean-branch + full-prompt fallback + keystroke on both | COVERED | Phase 5, Phase 6, Phase 7 |
| AC-10 | #spec-gate predicate = QA-clean ∧ zero markers; tags not a gate input | COVERED | Phase 2 |
| AC-11 | #plan-gate evidence = matrix file:line; #final-review = run+HEAD freshness | COVERED | Phase 2 |
| AC-12 | digest-payload contract enumerates the 4 per-AC fields | COVERED | Phase 2 |
| AC-13 | un-assemblable evidence → full prompt; summary-confirm never on incomplete | COVERED | Phase 2 |
| AC-14 | no gate path auto-advances — keystroke always required | COVERED | Phase 5, Phase 6, Phase 7 |
| AC-15 | review_board_variant swaps blind→2nd edge-case at both surfaces; seats=8 | COVERED | Phase 7, Phase 8 |
| AC-16 | the two edge-case seats carry differentiated lens seeds (named in SSOT) | COVERED | Phase 2 |
| AC-17 | variant absent → board composition identical to today (both surfaces) | COVERED | Phase 8 |
| AC-18 | review-board-triage + mirror exist; bare name; model opus | COVERED | Phase 4 |
| AC-19 | triage prompt: meta-routing only, no net-new, fix-diff scope, 3 triggers | COVERED | Phase 4 |
| AC-20 | triage pinned inside Step 3; L decrements only on full-board re-dispatch | COVERED | Phase 7 |
| AC-21 | triage off → Step-3 fix loop unchanged | COVERED | Phase 7 |
| AC-22 | plugin.json + marketplace.json synced at 5.13.0; CHANGELOG entry | COVERED | Phase 8 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | shell | `grep -cE "Independent Test \[(machine\|judgment):" plugins/spec-flow/templates/spec.md` | ≥2 |
| AC-2  | shell | `grep -l "17\. \*\*AC verifiability tag" plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-spec.agent.md` | both files |
| AC-3  | agent-step | Read qa-spec #17 and confirm the new-AC-must-fix vs legacy-skip two-branch logic | Both branches present |
| AC-4  | shell | `grep -c "ac_verifiability\|machine_checkable_ratio" plugins/spec-flow/reference/metrics-artifact.md` | ≥2 |
| AC-5  | shell | `grep -c "ac_verifiability" plugins/spec-flow/skills/spec/SKILL.md` | ≥1 |
| AC-6  | shell | `grep -c "fell_back\|gate_scaling" plugins/spec-flow/reference/metrics-artifact.md` | ≥2 |
| AC-7  | shell | `grep -cE "^## (clean-gate-predicate\|spec-gate\|plan-gate\|final-review-gate\|evidence-digest-payload\|board-swap-rule)$" plugins/spec-flow/reference/gate-scaling.md` | 6 |
| AC-8  | shell | `grep -rl "gate-scaling.md#" plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/skills/plan/SKILL.md plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/skills/review-board/SKILL.md` | all 4 listed |
| AC-9  | agent-step | Read each gate site and confirm clean-branch + full-prompt fallback both keystroke-gated | Confirmed for all 3 |
| AC-10 | shell | `grep -c "not a gate input\|NOT a gate input" plugins/spec-flow/reference/gate-scaling.md` | ≥1 |
| AC-11 | agent-step | Read `#plan-gate` + `#final-review-gate` and confirm matrix-file:line and run+HEAD-freshness evidence | Both present |
| AC-12 | agent-step | Read `## evidence-digest-payload` and confirm check name + run status + pass/fail + artifact pointer | All 4 present |
| AC-13 | shell | `grep -c "summary-confirm is never offered on incomplete\|never offered on incomplete" plugins/spec-flow/reference/gate-scaling.md` | ≥1 |
| AC-14 | agent-step | Read all 3 gate sites; confirm no path auto-advances without a keystroke | Confirmed |
| AC-15 | shell | `grep -c "review_board_variant" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/skills/review-board/SKILL.md` | ≥1 each |
| AC-16 | shell | `grep -c "seed-A\|seed-B\|pointer-integrity" plugins/spec-flow/reference/gate-scaling.md` | ≥2 |
| AC-17 | agent-step | Read both swap sites; confirm absent-variant path is identical to today (blind retained, 8 seats) | Confirmed both surfaces |
| AC-18 | shell | `test -f plugins/spec-flow/agents/review-board-triage.md && test -f plugins/spec-flow/agents/review-board-triage.agent.md && grep -c "^name: review-board-triage$" plugins/spec-flow/agents/review-board-triage.md` | files exist; 1 |
| AC-19 | agent-step | Read review-board-triage.md; confirm meta-routing-only + no-net-new + fix-diff scope + 3 triggers | All present |
| AC-20 | agent-step | Read execute Step 3; confirm triage inside the iteration and L decrements only on full-board re-dispatch | Confirmed |
| AC-21 | agent-step | Read execute Step 1+3; confirm no-variant/no-triage-route path matches current behavior | Confirmed |
| AC-22 | shell | `grep -h '"version"' plugins/spec-flow/.claude-plugin/plugin.json; grep -c "## \[5.13.0\]" plugins/spec-flow/CHANGELOG.md` | 5.13.0; 1 |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs. All boundary surfaces here are documentation/config (the `reference/gate-scaling.md` anchors, the `metrics.yaml` `ac_verifiability`/`gate_scaling` leaves, the `review_board_variant` annotation, and the `review-board-triage` agent's input contract), governed by the SSOT reference doc and the cross-phase citation/schema-consistency `[Verify]` in Phase 8.

## Parallel Execution Notes

**Why serial:** the whole plan runs serial flat phases by deliberate choice, not missed parallelism. Two rationales:
1. **Wiring phases 5–8** all cite the single `reference/gate-scaling.md` SSOT created in Phase 2; serial flat phases preserve per-phase Opus QA on each cross-citing edit, which the merged `spec-preresearch` retro found caught 6 cross-file citation/semantic defects a group-level QA would have missed on doc-as-code. Phase 7 additionally shares `execute/SKILL.md` with the in-flight `exec-guardrails` piece, so isolating it as its own serially-reviewed phase (anchored on Step headings) minimizes merge collision.
2. **Foundation phases 1, 3, 4** have disjoint file scopes (Phase 1: template + qa-spec; Phase 3: metrics-artifact.md; Phase 4: triage agent) and *could* form a `[P]` Phase Group, but are kept serial deliberately: each ships a new contract surface that a downstream wiring phase consumes (the tag → consumed by the Phase-5 metrics ratio; the metrics schema → written by the Phase-5/6/7 gates; the triage agent → wired by Phase 7), and per-phase Opus QA on each new contract before its consumer is authored is the same defect-catching discipline rationale (1) invokes. The phases are small (≤52 lines) so parallel-orchestration overhead would not pay back. Phase 2 (the SSOT) is the genuine hub all of 5–8 depend on. No Phase Groups; `[P]` is not used.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase's [Implement] Change Specification Blocks, spec ACs, the [Verify] commands, arch constraints, introspection.md anchors | Spec rationale, brainstorming history, other phases' diffs |
| Verify | The phase's [Verify] commands + expected outputs, spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
| Final Review board | Cumulative diff (+ per-lens context); doc-as-code variant swaps blind→2nd edge-case | Brainstorming history |
