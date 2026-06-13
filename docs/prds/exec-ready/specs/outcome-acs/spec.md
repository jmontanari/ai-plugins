---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
piece_class: behavior-bearing
---

# Spec: outcome-acs — Outcome & negative-space acceptance criteria

**PRD Sections:** FR-018, SC-010, G-7
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** spec-preresearch (merged)

> **Dogfooding note.** This spec carries its own `piece_class: behavior-bearing` front-matter and authors outcome ACs across both facets (see AC-9..AC-13). It is a "legacy" spec by construction — it is authored under the *current* skill, before this piece ships, so the new `qa-spec` criterion #17 does not gate it. The tags are a deliberate demonstration of the feature on itself (VOQ-5: yes).

## Goal

Behavior-bearing specs today record only **mechanism** ACs ("returns X", "writes row Y"). Nothing records the **negative space** — what the *running, integrated* system must NOT produce. So two failure classes pass every construction gate and surface only in expensive freeform Opus validation (~$12.3k/2mo, [R22]):

1. **Result-level wrongness** — "$0 masquerading as an earned result", "a loss outside the risk rule".
2. **Integration / seam incompleteness** — every unit test green, every per-piece gate passing, yet the feature does not actually work because a seam was **stubbed and never plumbed in**, the e2e path produces a fixture instead of a real result, or glue is missing.

This piece adds the missing **oracle**: a behavior-bearing spec must state, as ID-addressable **outcome ACs** tagged distinctly from mechanism ACs, what unacceptable output looks like across **two facets** — `result` (output values/content) and `integration` (seams plumbed, e2e produces a real result, nothing stubbed). The oracle is elicited (mandatory negative-space question in the brainstorm *and* the deliberation `user-intent` lens), enforced (`qa-spec` must-fix when a facet is missing; `qa-plan` cross-check against the plan track to defeat mislabeling), and addressable by ID so the downstream FR-020 campaign and the ground-truth board seat grade real output against it — referenced, not re-derived. Additive and backward-compatible: legacy specs without the tags are never retro-failed.

## In Scope

- **`reference/behavior-classification.md` (NEW):** single source of truth — defines behavior-bearing vs non-behavioral at **piece granularity** with concrete criteria; defines the two outcome facets (`result`, `integration`); owns the canonical token glossary (`[mechanism]`, `[outcome:result]`, `[outcome:integration]`, the per-facet N/A sentinel form, the `piece_class:` enum).
- **`templates/spec.md`:** `piece_class:` + `behavior_rationale:` front-matter keys; the AC-line tag scheme; the per-facet N/A sentinel; a citation to `reference/behavior-classification.md`.
- **`skills/spec/SKILL.md`:** Phase 2 cites the new elicitation block; Phase 3 **always** writes `piece_class` on new (greenfield) specs (ambiguity → `behavior-bearing`) and never back-fills it on drift/amend re-runs; step-7 (H-5) active-validation preview gains a per-facet outcome-AC coverage self-check.
- **`reference/brainstorm-procedure.md`:** a new always-run mandatory negative-space block (modeled on the C-2 security sub-block), posing the two-dimensional question, depth-independent, with auto-skip for non-behavioral pieces.
- **`agents/deliberation-lens.md`:** the `user-intent` lens row's governing question gains the negative-space dimensions (table stays exactly 5 rows).
- **`agents/deliberation-convergence.md`:** a negative-space `CONTESTED` from the `user-intent` lens folds into the existing sequential `VOQ-N` scheme.
- **`agents/qa-spec.md` + `agents/qa-spec.agent.md`:** new criterion **#17** (two-facet, 3-state, exact-literal matching, bounded quality heuristic, sentinel exemptions, legacy skip); `rubric_version` 1→2; Focused-re-review wiring; edit `qa-spec.md` only — `qa-spec.agent.md` is a relative symlink and follows automatically.
- **`agents/qa-plan.md` + `agents/qa-plan.agent.md`:** new criterion **#33** cross-checking the spec's `piece_class: non-behavioral` against the plan's track selection; `rubric_version` 1→2; edit `qa-plan.md` only — `qa-plan.agent.md` is a relative symlink and follows automatically.
- **Version triad:** `plugins/spec-flow/.claude-plugin/plugin.json` + root `.claude-plugin/marketplace.json` + `plugins/spec-flow/CHANGELOG.md` bumped 5.16.1 → **5.17.0** (MINOR).

## Out of Scope / Non-Goals

- **Metrics counts** (`outcome_ac_count` etc. in `metrics.yaml`) — deferred (passive leaf, no consumer until the campaign/SC-010 measurement piece exists; DU-4).
- **`spec-gate` predicate change** — NON-VIABLE per ADR-2 + `gate-scaling.md#spec-gate` (predicate is conjunct (i)∧(ii) only). Enforcement rides the existing "QA clean" conjunct: a #17 must-fix already fails it and renders the full prompt. No predicate edit.
- **SC-010 trend measurement** — the cross-piece "pieces authored after FR-018 ships carry ≥1 outcome AC" aggregate belongs to the FR-020 campaign piece. This piece's only SC-010 obligation is delivering ID-addressable outcome ACs (met by the data model).
- **Oracle-content semantic grading beyond the bounded heuristic** — distinguishing a substantive oracle from a thin one is the downstream FR-020 ground-truth gate's job. `qa-spec` #17 enforces presence + a bounded, enumerated liveness-blocklist heuristic only; it does not perform open-ended semantic adjudication of oracle quality (a free-text vibe judgment was found NON-VIABLE — non-reproducible).
- **The discovery-triage (FR-019) and campaign (FR-020) skills** — separate pieces.

## Requirements

### Functional Requirements

- **FR-OA-1 (single source of truth):** `reference/behavior-classification.md` is created and defines, at piece granularity with concrete criteria, (a) behavior-bearing vs non-behavioral, (b) the two outcome facets `result` and `integration` (with the integration facet explicitly covering: seams plumbed/wired, e2e produces a real result not a fixture, nothing stubbed, no missing glue), and (c) the canonical token glossary. It does NOT modify `spec-flow-doctrine.md` L179 (that stays the phase-level TDD-track default).
- **FR-OA-2 (data model):** `templates/spec.md` gains `piece_class: behavior-bearing|non-behavioral` and `behavior_rationale:` front-matter keys; an AC-line tag scheme where every AC carries exactly one of `[mechanism]`, `[outcome:result]`, `[outcome:integration]` (orthogonal to and coexisting with the existing `[machine:]`/`[judgment:]` Independent-Test tag); and a per-facet N/A sentinel line form. The AC-N ID is untouched, so outcome ACs are addressable by ID. The template cites `reference/behavior-classification.md`. No new `###` heading is added under `## Acceptance Criteria` (avoids the CR-009 extraction-anchor collision).
- **FR-OA-3 (spec-skill authoring):** `skills/spec/SKILL.md` Phase 3 ALWAYS writes `piece_class` on a new greenfield spec — ambiguous behavioral status resolves to `behavior-bearing` at authoring time and is written into the key (never left absent); `behavior_rationale` is written only when `non-behavioral`. The drift/amend re-run paths (Phase 1 step 7) MUST NOT inject or back-fill `piece_class` into a legacy spec. Phase 2 cites the FR-OA-4 elicitation block; step-7 (H-5) gains a per-facet outcome-AC coverage self-check.
- **FR-OA-4 (elicitation — brainstorm hop):** `reference/brainstorm-procedure.md` gains a new always-run mandatory block posing the two-dimensional negative-space question — *"When this runs end-to-end and integrated with its surroundings: (a) what unacceptable output values/content could it produce, and (b) what could be left unwired, stubbed, or not actually plumbed in so e2e doesn't really work?"* The block is depth-independent (it does not depend on any deliberation lens firing). For a behavior-bearing piece it auto-skips ONLY when `piece_class: non-behavioral` with a recorded rationale; otherwise the operator must, **per facet**, record at least one answer or an explicit facet N/A before sign-off. The sign-off keystroke is always required (NN-P-001).
- **FR-OA-5 (elicitation — lens hop):** `agents/deliberation-lens.md` extends the `user-intent` row's governing question to include the negative-space dimensions, keeping the table at exactly five rows; `agents/deliberation-convergence.md` folds a negative-space `CONTESTED` into the existing sequential `VOQ-N` scheme. This hop is the full-depth enhancer; FR-OA-4 is the primary path that also covers lite/off depth.
- **FR-OA-6 (enforcement — qa-spec #17):** A new criterion #17 is appended to `agents/qa-spec.md`; `agents/qa-spec.agent.md` is a relative symlink and follows automatically. `rubric_version` bumped 1→2. The criterion:
  - **Legacy skip:** when the spec carries no `piece_class` field → skip entirely (legacy spec — never retro-failed; not an error).
  - **Non-behavioral exemption:** `piece_class: non-behavioral` → exempt; must-fix ONLY if `behavior_rationale` is absent (rationale *presence* is the clean state, per the criterion-15 sentinel precedent).
  - **Behavior-bearing enforcement:** `piece_class: behavior-bearing` (or ambiguous-defaulted) → for EACH facet in {`result`, `integration`}, require at least one AC tagged `[outcome:<facet>]` OR a matching per-facet N/A sentinel. A facet with neither → must-fix (quote the missing facet + list the mechanism-only AC IDs).
  - **Bounded quality heuristic:** an `[outcome:result]` AC whose prohibition is purely a liveness/crash property (enumerated blocklist — e.g. "crash", "throw", "hang", "timeout", "error out") with no value/content property → must-fix (quote the AC). This is a fixed enumerated list, not open semantic judgment.
  - **Matching:** exact-literal, case-sensitive on the tag tokens (a mis-spelled `[Outcome]` does not count as an outcome AC → fail-safe). Tokens are the canonical ones from `reference/behavior-classification.md`.
  - Wired into `## Input Modes` Focused-re-review as a delta-scoped regression (if the delta adds ACs to a behavior-bearing piece and a facet is now uncovered, re-raise; if `piece_class` is not visible in the delta, do not evaluate #17). Out of scope in Focused-charter-re-review mode (which applies only criteria 8–11).
- **FR-OA-7 (enforcement — qa-plan #33 anti-mislabel cross-check):** A new criterion #33 is appended to `agents/qa-plan.md`; `agents/qa-plan.agent.md` is a relative symlink and follows automatically. `rubric_version` bumped 1→2. The criterion: when the spec declares `piece_class: non-behavioral`, verify the plan contains NO TDD-track phase (`[TDD-Red]` block). A `non-behavioral` spec whose plan uses the TDD track (i.e. the plan treats the piece as behavior-bearing) is a divergence → must-fix (quote the `piece_class` line and the contradicting `[TDD-Red]` phase). When the spec has no `piece_class` field (legacy) → skip (not an error).
- **FR-OA-8 (version triad):** `plugin.json`, root `marketplace.json` spec-flow entry, and `CHANGELOG.md` are bumped 5.16.1 → 5.17.0 with a CHANGELOG entry under the appropriate Keep-a-Changelog groupings.

### Non-Functional Requirements

- **NFR-OA-1 (additive / backward-compatible — NFR-003, NN-C-003):** Every change is additive. Legacy specs (no `piece_class`) are never retro-failed by #17 or #33 (both skip on the absent discriminator). New front-matter keys, a new AC tag, a new criterion, and a new reference doc are additive surface; no existing key, heading, criterion number, or invocation pattern changes meaning. Bump is MINOR.
- **NFR-OA-2 (determinism):** All gate matching is exact-literal and greppable; the only quality judgment (#17 liveness heuristic) is a fixed enumerated blocklist with quoted evidence — no free-text semantic adjudication anywhere in the gate.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only): every change is to markdown skill/agent/template/reference files and JSON/YAML config — no runtime code, no dependencies added.
- NN-C-003 (backward compat within major): additive front-matter keys, additive AC tag, appended criteria (no renumbering), new reference doc; legacy specs exempt; MINOR bump — no existing public surface changes meaning.
- NN-C-008 (agents self-contained): `qa-spec` #17 and `qa-plan` #33 read the discriminator/tags from the artifact they are given (spec front-matter, plan body) with no brainstorm-history dependency; the elicitation block is authored so the brainstorm does not assume any lens fired.
- NN-C-009 (version bump on plugin change): the version triad (plugin.json + marketplace.json + CHANGELOG) is bumped to 5.17.0 in this piece.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human approval gate never removed): the brainstorm zero-answer block and #17 add gating but never auto-advance — the sign-off keystroke is always required; nothing in this piece bypasses the spec sign-off gate.

### Coding Rules Honored

- CR-001 / CR-002 (agent/skill front-matter schema): the new `piece_class:`/`behavior_rationale:` keys are added to the spec template front-matter; the `rubric_version` bumps stay within the existing agent front-matter schema.
- CR-005 (repo-root-relative paths): all doc cross-references (template/qa-spec/qa-plan/brainstorm-procedure → `reference/behavior-classification.md`) use repo-root-relative paths.
- CR-008 (thin-orchestrator skills, narrow-executor agents): elicitation logic lives in the reference doc + the spec skill (orchestrator); `qa-spec`/`qa-plan` stay read-only narrow reviewers gaining one criterion each; the `user-intent` lens gains only question text, no logic.
- CR-009 (markdown heading hierarchy): no new heading is added under `## Acceptance Criteria` (the AC tag rides the existing `AC-N:` line); the new reference doc and brainstorm block follow the existing H1/H2/H3 discipline.

## Acceptance Criteria

AC-1: Given the piece is implemented, When `reference/behavior-classification.md` is read, Then it defines piece-level behavior-bearing vs non-behavioral criteria, the two facets (`result`, `integration` — integration explicitly naming seams/e2e/stub/glue), and the canonical token glossary; and it does not modify `spec-flow-doctrine.md` L179. `[mechanism]`
  Independent Test [machine: grep for the piece-class criteria, both facet definitions, and the glossary tokens in `reference/behavior-classification.md`; `git diff` shows `spec-flow-doctrine.md` L179 unchanged]

AC-2: Given the spec template, When read, Then it carries `piece_class:`/`behavior_rationale:` front-matter keys, the `[mechanism]`/`[outcome:result]`/`[outcome:integration]` AC-line tag scheme, the per-facet N/A sentinel form, and a citation to `reference/behavior-classification.md`; and adds no new `###` heading under `## Acceptance Criteria`. `[mechanism]`
  Independent Test [machine: grep `templates/spec.md` for the keys, the three tag tokens, the sentinel form, and the reference citation; confirm no new `### ` under `## Acceptance Criteria`]

AC-3: Given `skills/spec/SKILL.md`, When read, Then Phase 3 instructs always-write `piece_class` on a new spec (ambiguity → `behavior-bearing`), the drift/amend paths are instructed NOT to back-fill it, Phase 2 cites the elicitation block, and step-7 H-5 includes a per-facet outcome-AC coverage check. `[mechanism]`
  Independent Test [judgment: reviewer confirms the four authoring instructions are present and unambiguous in `skills/spec/SKILL.md`]

AC-4: Given `reference/brainstorm-procedure.md`, When read, Then a new always-run mandatory block poses the two-dimensional negative-space question (result + integration/seam/e2e/stub), is depth-independent, and auto-skips only for `non-behavioral` pieces with a recorded rationale. `[mechanism]`
  Independent Test [machine: grep `reference/brainstorm-procedure.md` for the new block, both question dimensions, the depth-independence statement, and the non-behavioral auto-skip clause]

AC-5: Given `agents/deliberation-lens.md` and `agents/deliberation-convergence.md`, When read, Then the `user-intent` row question includes the negative-space dimensions, the lens table still has exactly five rows, and convergence folds a negative-space CONTESTED into the `VOQ-N` scheme. `[mechanism]`
  Independent Test [machine: grep the `user-intent` row for the negative-space text; count lens table rows == 5; grep convergence for the negative-space→VOQ fold]

AC-6: Given the two `qa-spec` files, When compared and read, Then `qa-spec.md` contains criterion #17 (legacy-skip, non-behavioral-exemption, per-facet behavior-bearing enforcement, liveness-blocklist heuristic, exact-literal matching, Focused-mode wiring, Focused-charter exclusion) and carries `rubric_version: 2`; and `qa-spec.agent.md` is a relative symlink to `qa-spec.md` (single source of truth). `[mechanism]`
  Independent Test [machine: `[ -L agents/qa-spec.agent.md ]`; `readlink agents/qa-spec.agent.md` confirms it resolves to `qa-spec.md`; grep `agents/qa-spec.md` for #17 sub-clauses and `rubric_version: 2`]

AC-7: Given the two `qa-plan` files, When compared and read, Then `qa-plan.md` contains criterion #33 (non-behavioral-spec-vs-TDD-track divergence must-fix; legacy skip) and carries `rubric_version: 2`; and `qa-plan.agent.md` is a relative symlink to `qa-plan.md` (single source of truth). `[mechanism]`
  Independent Test [machine: `[ -L agents/qa-plan.agent.md ]`; `readlink agents/qa-plan.agent.md` confirms it resolves to `qa-plan.md`; grep `agents/qa-plan.md` for #33 and `rubric_version: 2`]

AC-8: Given the plugin, When the version-bearing files are read, Then `plugin.json`, the `marketplace.json` spec-flow entry, and `CHANGELOG.md` all show 5.17.0 with a CHANGELOG entry. `[mechanism]`
  Independent Test [machine: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[]|select(.name=="spec-flow").version' .claude-plugin/marketplace.json)` is empty and both == 5.17.0; CHANGELOG has a `## [5.17.0]` heading]

AC-9: Given a behavior-bearing spec (with `piece_class: behavior-bearing`) whose ACs are all `[mechanism]` with no `[outcome:result]` AC and no result-facet N/A sentinel, When `qa-spec` reviews it, Then `qa-spec` MUST raise a #17 must-fix and MUST NEVER return that spec clean. `[outcome:result]`
  Independent Test [judgment: reviewer runs `qa-spec` (Full mode) on a provided behavior-bearing fixture spec missing the result facet; confirms a #17 must-fix is returned and the spec is not passed]

AC-10: Given a legacy spec (no `piece_class` front-matter key), When `qa-spec` reviews it, Then `qa-spec` MUST skip criterion #17 and MUST NEVER raise an outcome-AC must-fix against it (no retro-fail). `[outcome:result]`
  Independent Test [judgment: reviewer runs `qa-spec` on a legacy fixture spec with no `piece_class`; confirms zero #17 findings]

AC-11: Given the implemented piece, When every site the design requires to cite `reference/behavior-classification.md` is inspected (the spec template, both `qa-spec` twins, both `qa-plan` twins, `reference/brainstorm-procedure.md`, `skills/spec/SKILL.md`), Then EVERY such site MUST contain the citation — the glossary owner must NEVER be left unwired or its reference stubbed/dangling in any consuming site. `[outcome:integration]`
  Independent Test [machine: grep each of the seven named sites for the `reference/behavior-classification.md` citation; all must match — zero unwired sites]

AC-12: Given the paired agent files, When checked, Then `qa-spec.agent.md` is a symlink to `qa-spec.md` and `qa-plan.agent.md` is a symlink to `qa-plan.md`, and the e2e static check that enforces this MUST pass — the symlink seam must NEVER be left broken or divergent. `[outcome:integration]`
  Independent Test [machine: run `tests/e2e/lib/static.sh` (the per-pair `[ -L ]` symlink assertion and the 27-pair drift guard within it); it must pass for both twin pairs]

AC-13: Given a behavior-bearing piece taken end-to-end through brainstorm → spec → `qa-spec` → plan → `qa-plan`, When a facet is left uncovered (no `[outcome:<facet>]` AC and no facet N/A) OR the spec declares `non-behavioral` while the plan uses the TDD track, Then the chain MUST actually block at the corresponding gate — the elicitation→tag→#17→#33 path must NEVER be plumbed such that a missing facet or a mislabel silently passes e2e. `[outcome:integration]`
  Independent Test [judgment: reviewer walks a fixture piece through the full chain for both failure injections (missing facet; non-behavioral spec + TDD plan) and confirms each is blocked at the right gate, not silently passed]

AC-14: Given a behavior-bearing spec whose only `[outcome:result]` AC states a purely-liveness prohibition (e.g. "must never crash") with no value/content property, When `qa-spec` reviews it, Then #17 MUST raise a must-fix on the liveness heuristic — the gate must NEVER accept a vacuous liveness-only AC as satisfying the result facet. `[outcome:result]`
  Independent Test [judgment: reviewer runs `qa-spec` (Full mode) on a behavior-bearing fixture whose result-facet AC is "must never crash"; confirms a #17 liveness-heuristic must-fix is returned — the gate fires, it does not merely contain the rule text]

AC-15: Given a spec that carries the new `[outcome:result]`/`[outcome:integration]`/`[mechanism]` AC-line tags, When the spec skill's Phase-5 `ac_verifiability` computation runs (it greps `[machine:]`/`[judgment:]` on the Independent-Test sub-line), Then the new AC-line tags MUST NEVER alter or break that computation — the existing metrics seam stays plumbed and the `machine`/`judgment` counts equal the Independent-Test sub-line tag counts, unaffected by the outcome/mechanism tags. `[outcome:integration]`
  Independent Test [machine: run the Phase-5 `ac_verifiability` count on a fully-tagged spec; assert `machine + judgment` equals the count of `[machine:]`/`[judgment:]` sub-lines and is unchanged by the presence of `[outcome:*]`/`[mechanism]` AC-line tags]

## Technical Approach

**Data model (keystone).** Two orthogonal axes coexist on one AC line: the verifiability axis stays on the indented `Independent Test [machine:|judgment:]` sub-line; the new outcome/mechanism axis is an inline bracket tag on the `AC-N:` line itself. The tag value space is a closed enum — `[mechanism]`, `[outcome:result]`, `[outcome:integration]` — owned by `reference/behavior-classification.md`. The `piece_class:` front-matter key is the single discriminator: its **presence** distinguishes a new (gated) spec from a legacy (exempt) one; this only holds because the spec skill always writes it on new specs (FR-OA-3) and never back-fills it on legacy ones.

**Two-hop elicitation.** The brainstorm block (FR-OA-4) is the depth-independent primary hop — it fires whenever the brainstorm runs, so lite/off-depth pieces are covered. The `user-intent` lens extension (FR-OA-5) is the full-depth enhancer: a negative-space `CONTESTED` becomes a `VOQ-N` the brainstorm then surfaces. The two are complementary, mandated by AC-1's literal "lens AND brainstorm both pose" conjunction.

**Two-stage enforcement.** `qa-spec` #17 is the spec-time gate (presence of both facets, exact-literal tag matching, bounded liveness heuristic). `qa-plan` #33 is the plan-time anti-mislabel cross-check — it exists because `qa-spec` runs before the plan and cannot see the track choice; the contradiction (`non-behavioral` spec + TDD-track plan) is only visible once both artifacts exist, which is exactly `qa-plan`'s input bundle.

**Relationship to existing machinery (complement, not duplicate).** The spec's **Integration Coverage block** names *which* seams get contract-tested; **outcome ACs** state *what* unacceptable integrated behavior looks like (the oracle); the downstream **FR-020 SEAM lens / `review-board-integration`** *grade* the running system against those outcome ACs. This piece supplies the oracle that seam-grading currently lacks.

## Testing Strategy

- Doc-as-code piece — verification is grep/diff assertions over the edited markdown plus symlink-resolution checks of the two twin pairs and a `static.sh` run (AC-6, AC-7, AC-8, AC-11, AC-12 are machine-checkable).
- Behavioral ACs (AC-9, AC-10, AC-13, AC-14) are judgment ACs verified by running the affected agents on small fixture specs/plans (a behavior-bearing fixture missing a facet; a legacy fixture; a non-behavioral-spec-with-TDD-plan fixture; a vacuous-liveness-AC fixture) and confirming the gate fires or skips correctly. AC-15 is machine-checkable (the metrics-seam non-interference assertion).
- Edge cases to cover: ambiguous piece (defaults behavior-bearing), per-facet N/A sentinel accepted, mis-spelled tag fails safe (false-fire not false-pass), vacuous liveness-only outcome AC must-fixed (AC-14), the new AC-line tag does not perturb `ac_verifiability` (AC-15), Focused-re-review with `piece_class` outside the delta (do-not-evaluate), Focused-charter mode (#17/#33 out of scope).
- **Self-audit provenance:** AC-14 and AC-15 were added by dogfooding this spec through its own gate — AC-14 closes a mechanism-only test of the liveness heuristic (the spec was asserting the rule's *text* via AC-6 but not its *behavior*); AC-15 closes the integration-facet seam with the existing `ac_verifiability` metric. They demonstrate the exact mechanism→outcome upgrade the piece exists to force.

## Integration Coverage

- Integration: `skills/spec/SKILL.md` → `reference/behavior-classification.md` + `reference/brainstorm-procedure.md` — inside: spec skill, the two reference docs; doubled externals: none (all in-repo doc citations, verified by grep); AC-11; completes the elicitation wiring.
- Integration: `templates/spec.md` / `agents/qa-spec.*` / `agents/qa-plan.*` → `reference/behavior-classification.md` (shared token glossary) — inside: the template, both qa twins, both qa-plan twins; doubled externals: none; AC-11, AC-12; the glossary-consumer seam (must not be left unwired — the core integration-facet risk this piece is itself about).
- Integration: brainstorm → spec → `qa-spec` → plan → `qa-plan` (the e2e gate chain) — inside: all five stages; doubled externals: none; AC-13; the end-to-end path that must actually block on a missing facet or a mislabel.

## Open Questions

None. VOQ-1..VOQ-5 were resolved during brainstorm (anti-mislabel: build the qa-plan cross-check now; tag matching: exact-literal case-sensitive; dogfood: yes; oracle quality: bounded heuristic in-gate + semantic grading layered to FR-020; glossary single-source: `reference/behavior-classification.md`). The operator additionally elevated the integration/seam/e2e facet to a structurally-required dimension. No deferred-decision markers survive.
