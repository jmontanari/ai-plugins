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

# Spec: bugfix-redfirst

**PRD Sections:** FR-022, SC-009, G-6
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** none

## Goal

Encode the already-authored non-negotiable **NN-P-006** (bug-fix / regression work is red-first) into spec-flow's **plugin governance**, so it binds in **every** repo that installs spec-flow — independent of what that repo set in its `.spec-flow.yaml tdd:` field or a plan's `tdd: false` front-matter. The non-substitutable artifact is **observing a test fail against the actual broken code** (reproduce → see-it-fail → fix → see-it-pass): a test written after the fix passes against fixed code with no evidence it would have caught the original defect, and the broken state is gone, so the regression claim is unverifiable. This piece wires that obligation into the plan phase tag, the QA gates, the intake/small-change/hotfix routing, the out-of-band triage fix-routes, and the binding doctrine — and documents it as the standing carve-out from FR-021's `tdd: false` efficient default.

**Design decision (operator, 2026-06-12 brainstorm):** enforcement is **piece-level, prevention not plumbing**. Bug-fix/regression work resolves to the red-first track *as a whole*; the un-runnable combination (a bug-fix phase under `tdd: false`) is **forbidden by the gates**, not made to work by per-phase mechanical reconciliation inside `tdd: false`. This eliminates the execute-side reconciliation entirely (a `tdd: true`-resolved piece runs Red natively) and reuses the existing `[TDD-Red]` track and `tdd-red`'s observed-red Oracle block as the evidence. NN-P-006's *"regardless of the piece's `tdd` setting"* is honored as a **governance precedence**: bug-fix classification overrides the repo/plan `tdd: false` default; a repo cannot opt out (a deliberate exception to NFR-003's opt-out pattern).

## In Scope

- A phase-level classification tag (`**Phase type:** bug-fix | regression`) in the plan template.
- A binding governance statement in `reference/spec-flow-doctrine.md` (`## TDD Is Opt-In`) that bug-fix/regression work is red-first regardless of the `tdd` setting, and that the RED cycle runs for such a phase regardless of mode.
- Red-first **precedence** at both producer surfaces: the plan TDD-preference resolution writes `tdd: true` to the plan front-matter, and `small-change` writes `tdd: true` to the inline plan front-matter, when bug-fix/regression work is present — overriding a repo/plan `tdd: false` so the piece resolves to red-first wholesale.
- New must-fix criteria in `qa-plan` and `qa-spec` (declaration-only; three-state legacy-safe).
- Defective + clean-control fixtures for the two new criteria registered in the FR-017 `gate-evals` corpus, so each new merge-blocking gate carries a published catch rate / clean-fixture flag rate (SC-009).
- Bug-signal routing in `small-change` track selection and the `intake` hotfix path, with a non-behavioral recorded-exemption posture.
- Out-of-band honoring: `small-change` / `plan-amend` / `new-piece` consumers of triage's NN-P-006 forward-record stamp run red-first; non-reproducible → `[SPIKE]` / explicit no-repro rationale.
- FR-021 `tdd: false` carve-out documentation in both FR surfaces (plan/SKILL.md Non-TDD override + doctrine).
- Version bump across all version-bearing files + the hard-coded `static.sh` version literals; new static assertions for the added tokens.

## Out of Scope / Non-Goals

- **Execute-side per-phase mode reconciliation under `tdd: false`** — eliminated by the piece-level decision. A bug-fix piece resolves to `tdd: true`, so the existing `tdd: true` execute path runs Red natively; the front-matter-`tdd:false`-keyed skip sites (execute Step 2/2.5/3.6/3.7+/4) are never reached. No edit to `execute/SKILL.md`'s dispatch/skip logic.
- **A campaign consumer (FR-020)** — the `spec-flow:campaign` skill does not exist; campaign reach stays **forward-record only**, mirroring triage's existing stamp. No campaign code is written here.
- **A new no-repro marker** — reuse the existing `[SPIKE]` marker; no new sentinel.
- **A new hotfix skill** — reuse the existing `intake` hotfix routing path; no new skill surface.
- **`implement-oracle` (FR-021 / Road A) itself** — only its `tdd: false`-default carve-out *documentation* is in scope; the implement-oracle machinery is a separate open piece.
- **Editing the `.agent.md` symlink twins directly** — edit the `.md` source; the symlink + byte-identity static test handle the twin.

## Requirements

### Functional Requirements

- **FR-1 — Phase classification tag.** `templates/plan.md` gains a `**Phase type:** bug-fix | regression` bold-label field in the phase header (beside `**ACs Covered:**`), under the existing CR-009 H3/H4 anchors. Absent ⇒ feature work. The field is metadata in the phase body; it does **not** alter the counted `### Phase N:` / `#### Sub-Phase N.m:` headings the Phase Scheduler parses.
- **FR-2 — Red-first governance precedence (both producer surfaces).** Bug-fix/regression classification forces the red-first track regardless of the consuming repo's `.spec-flow.yaml tdd:` value or a plan's `tdd: false` front-matter. The resolution is mechanized at **both** producers that emit an executable plan: (a) the plan skill's TDD-preference resolution writes `tdd: true` to the plan front-matter; (b) `small-change` writes `tdd: true` to the inline `plan.md` front-matter (not merely per-phase `[TDD-Red]` track selection — a per-phase track alone leaves the inline plan's `tdd:` absent/false and execute's front-matter-`tdd:false` skip sites would still be reached). Both paths therefore resolve the piece to red-first *wholesale*, so no `execute/SKILL.md` change is needed. This precedence is **not opt-out-able** (a deliberate, documented exception to NFR-003's opt-out pattern).
- **FR-3 — Binding doctrine statement.** `reference/spec-flow-doctrine.md` `## TDD Is Opt-In` gains a carve-out: bug-fix/regression work is always red-first regardless of the `tdd` setting (cite NN-P-006 / FR-022 — do not restate the cycle mechanics elsewhere). The RED-cycle `(TDD mode only)` gating is annotated so a bug-fix/regression phase runs RED regardless of mode.
- **FR-4 — Static enforcement gates.** `qa-plan` gains criterion #34 and `qa-spec` gains criterion #18: a bug-fix/regression-classified phase (qa-plan) or spec (qa-spec) that proposes tests-after, resolves to a non-red-first track, or omits the red-first declaration is **must-fix**. Declaration-only (observed-red is an execute-time artifact a static gate cannot see). The criterion mirrors the qa-spec #17 three-state legacy-safe predicate (absent classification ⇒ feature work, never a finding).
- **FR-5 — Intake-time routing.** `small-change`'s per-phase track recommendation routes bug-signal work to the red-first track **by default** AND writes `tdd: true` to the inline `plan.md` front-matter (per FR-2 (b)) so the inline plan resolves to red-first wholesale, *citing* `reference/triage-contract.md` `## Red-first obligation` for the keyword set (do not re-list it — NN-C-008). The `intake` hotfix path gains a red-first obligation in place of its bare "Work directly" handoff. When the matched change is **non-behavioral** (a doc/typo/config change with no observable broken behavior to reproduce), the operator records a one-line non-behavioral exemption (mirroring FR-018's recorded exemption); a silent skip is never permitted.
- **FR-6 — Out-of-band fix-route honoring.** The fix consumers of triage's NN-P-006 forward-record stamp — `small-change`, `plan-amend`, `new-piece` — run the red-first cycle on the spawned fix. A defect not reproducible by a failing test routes to the existing `[SPIKE]` marker (to establish a reliable reproduction) or records an explicit no-repro rationale at triage; a fabricated or never-observed-red test is never accepted. Campaign (FR-020) reach remains forward-record only.
- **FR-7 — FR-021 carve-out documentation.** The `tdd: false` efficient default is documented to **exclude** bug-fix/regression work in both FR surfaces: plan/SKILL.md's Non-TDD-mode override and `reference/spec-flow-doctrine.md`. The exclusion is stated in both FR-021 and FR-022 prose.
- **FR-8 — Version-sync + back-compat.** Per NN-C-009, bump the plugin version in **both** `plugins/spec-flow/plugin.json` AND `plugins/spec-flow/.claude-plugin/plugin.json`, the root `.claude-plugin/marketplace.json` spec-flow entry, and `plugins/spec-flow/CHANGELOG.md`, and update the hard-coded version literals in `plugins/spec-flow/tests/e2e/lib/static.sh` (the three version-sync assertions) in lockstep. Add `assert_grep` static assertions for the new surface tokens.
- **FR-9 — Gate-efficacy coverage (SC-009).** The two new merge-blocking criteria (qa-plan #34, qa-spec #18) are a gate-mechanism addition, so per the FR-017 `gate-evals` contract they ship with fixtures: at minimum one defective fixture each (a bug-fix/regression-classified plan and spec that propose tests-after — the gate must catch) plus a clean control each (a correctly red-first bug-fix plan/spec — the gate must NOT flag), registered in the committed `gate-evals` corpus so each new gate carries a published catch rate and clean-fixture flag rate. The criterion additions are a QA-rubric change and therefore trigger the `gate-evals` gold-set re-run before this version ships (the rubric-freeze rule). This discharges SC-009 for the gates this piece introduces; no catch-rate obligation is silently deferred.

### Non-Functional Requirements

- **NFR-1 — Additive / backward-compatible (NN-C-003).** Existing plans and specs without the `**Phase type:**` tag read as feature work and are never retro-failed; the new gates and routing apply only to work authored after this ships. The three-state predicate is the back-compat idiom.
- **NFR-2 — No new runtime dependency (NN-C-002).** Every edit is markdown / config (doctrine, templates, skill/agent prose, a bash static test). No `package.json`, no runtime code.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only): all edits are doctrine/template/skill/agent markdown + a bash static assertion; no runtime dependency added.
- NN-C-003 (backward compatibility): three-state legacy-safe predicate; absent `**Phase type:**` ⇒ feature work, existing pieces never retro-failed; additive criteria and routing.
- NN-C-004 / NN-C-008 (agent bare name + self-contained / cite-not-restate): the new qa-plan/qa-spec criteria carry their full context; the bug-signal keyword set is **cited** from `triage-contract.md`, never duplicated.
- NN-C-009 (version bump across all version-bearing files): both `plugin.json` files + marketplace entry + CHANGELOG + the `static.sh` literals bumped in lockstep (FR-8).

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- **NN-P-006 (bug-fix/regression work is red-first):** this piece **is** its implementation — encoded as binding doctrine governance that holds regardless of the consuming repo's `tdd` setting, enforced at every fix-origination surface.
- NN-P-001 (human approval gate never removed): the new gates add must-fix findings; they do not remove or weaken any spec/plan sign-off.
- NN-P-004 (no silent defer): the non-behavioral exemption (FR-5) and the no-repro path (FR-6) are recorded, never silent.

### Coding Rules Honored

- CR-008 (thin-orchestrator skills / narrow-executor agents): enforcement logic lives in the `qa-plan` / `qa-spec` agents; routing lives in the `small-change` / `intake` skills; no agent gains sub-dispatch.
- CR-009 (markdown heading hierarchy / Scheduler anchors): the `**Phase type:**` field is body metadata under the existing H3/H4 anchors; the counted `### Phase N:` headings are untouched.
- CR-002 (skill frontmatter schema): no new skill is added; edited skills keep their existing frontmatter.

## Acceptance Criteria

AC-1: Given the plan template, When a plan author classifies a phase, Then a `**Phase type:** bug-fix | regression` field is available in the phase header (absent ⇒ feature work) and a feature piece may carry such a phase alongside Implement-track feature phases, without altering the counted `### Phase N:` heading. [mechanism]
  Independent Test [machine: grep `templates/plan.md` for the `**Phase type:**` field + its documented values; grep that the `### Phase N:` anchor format is unchanged]: confirm the field and value enumeration are present and the Scheduler anchor regex still matches.

AC-2: Given a bug-fix/regression-classified piece in a repo whose `.spec-flow.yaml` sets `tdd: false` (via either producer — the plan skill or `small-change`), When the pipeline runs it, Then the producer writes `tdd: true` to the (inline) plan front-matter and the work resolves to the red-first track, and the running pipeline must **never** produce a "green" bug-fix/regression phase whose test was authored after the fix and never observed red against the broken code, and must **never** force the red-first must-fix onto an untagged/feature phase. [outcome:result]
  Independent Test [machine: an e2e/static scenario, run for BOTH producer paths (plan and `small-change`), where `tdd: false` + a `**Phase type:** regression` phase yields `tdd: true` front-matter and resolves to red-first (doctrine + producer-resolution + gate assertions), plus a feature-phase control that is not flagged]: assert the bug-fix phase is red-first-forced on each path and the feature control passes clean.

AC-3: Given a bug-fix/regression-classified phase (plan) or spec, When it proposes tests-after, resolves to a non-red-first track, or omits the red-first declaration, Then `qa-plan` (criterion #34) and `qa-spec` (criterion #18) raise a must-fix; an absent classification reads as feature work and raises nothing. [mechanism]
  Independent Test [machine: grep `agents/qa-plan.md` for criterion #34 and `agents/qa-spec.md` for criterion #18, each with the three-state legacy-safe predicate and the tests-after/non-red-first/missing-declaration must-fix triggers]: confirm both criteria and the absent-classification skip branch are present.

AC-4: Given every surface from which a bug fix can originate — the full pipeline (doctrine + plan resolution + gates), `small-change` track selection, the `intake` hotfix path, and the out-of-band triage fix-routes — When this piece ships, Then the red-first obligation is wired/cited at **each** such surface end-to-end, with no fix-origination surface left unwired. [outcome:integration]
  Independent Test [machine: grep each of doctrine, plan/SKILL.md, qa-plan, qa-spec, small-change, intake, and the triage-consumer note for the red-first routing/citation token]: confirm every enumerated surface carries the obligation; a missing surface fails the assertion.

AC-5: Given `small-change` or the `intake` hotfix path receives bug-signal work (per the `triage-contract.md` keyword set), When the work is behavioral, Then it is routed to the red-first track by default AND `small-change` writes `tdd: true` to the inline `plan.md` front-matter; When the matched change is non-behavioral, Then the operator records a one-line non-behavioral exemption and no silent skip occurs. [mechanism]
  Independent Test [machine: grep `small-change` track-recommendation step for the cited keyword set, the red-first default, and the `tdd: true` inline-front-matter write; grep `intake` hotfix path for the red-first obligation] and [judgment: a reviewer confirms the non-behavioral-exemption wording requires a recorded rationale, never a silent skip]: both pass.

AC-6: Given triage routes a bug-classified discovery to a fix (`small-change` / `plan-amend` / `new-piece`), When the fix is authored, Then it runs the red-first reproduce→fail→fix→pass cycle; and When the defect cannot be reproduced by a failing test, Then it routes to `[SPIKE]` or records an explicit no-repro rationale — never a fabricated/unobserved-red test. [mechanism]
  Independent Test [machine: grep the triage fix-consumer surfaces for the honor-the-stamp red-first instruction and the `[SPIKE]`/no-repro fallback]: confirm the honoring instruction and the no-repro fallback are present.

AC-7: Given FR-021's `tdd: false` efficient default, When this piece ships, Then the bug-fix/regression exclusion is documented in **both** FR surfaces (plan/SKILL.md Non-TDD-mode override and `spec-flow-doctrine.md`). [mechanism]
  Independent Test [machine: grep plan/SKILL.md Non-TDD-mode section and `spec-flow-doctrine.md` for the bug-fix/regression exclusion text]: confirm both carry the exclusion.

AC-8: Given an existing plan/spec authored before this piece (no `**Phase type:**` tag), When the new gates run, Then it reads as feature work and is not retro-failed; and the plugin version is bumped across both `plugin.json` files + marketplace entry + CHANGELOG + the `static.sh` version literals in lockstep. [mechanism]
  Independent Test [machine: grep the gates for the absent-tag skip branch; `diff` the version field across both plugin.json + marketplace; grep `static.sh` for the updated version literal and the new token assertions]: all version sites match and the legacy-skip branch exists.

AC-9: Given the two new merge-blocking criteria (qa-plan #34, qa-spec #18), When this piece ships, Then the `gate-evals` corpus carries — for each criterion — at least one defective fixture (a tests-after bug-fix/regression plan/spec the gate must catch) and one clean control (a correctly red-first bug-fix plan/spec the gate must not flag), so each gate has a published catch rate and clean-fixture flag rate (SC-009), and the rubric change is recorded as triggering the `gate-evals` gold-set re-run. [mechanism]
  Independent Test [machine: grep the committed `gate-evals` fixture corpus for the new defective + clean-control fixtures keyed to qa-plan #34 / qa-spec #18, and for the catch-rate/clean-flag entry]: confirm both criteria have a defective fixture, a clean control, and a recorded catch-rate slot.

## Technical Approach

**Governance-first, prevention not plumbing.** The rule lives in `reference/spec-flow-doctrine.md` (`## TDD Is Opt-In`, L175–177) — the doctrine loaded at session start that governs all implementation work in any consuming repo. It states bug-fix/regression work is red-first regardless of the `tdd` setting and is not opt-out-able. The two enforcement directions:

1. **Precedence (producer side).** When bug-fix/regression classification is present, **both** plan-emitting producers write `tdd: true` to the (inline) plan front-matter — the plan skill's TDD-preference resolution and `small-change`'s inline-plan authoring — overriding a repo/plan `tdd: false`. The producer-side front-matter write is the load-bearing step: it is what makes the piece resolve to red-first *wholesale* so the existing `tdd: true` machinery runs Red and the front-matter-`tdd:false` skip sites (execute Step 2/2.5/3.6/3.7+/4) are never reached — **no `execute/SKILL.md` change**. (small-change selecting a per-phase `[TDD-Red]` track WITHOUT the front-matter write would leave those skip sites live — hence FR-2 (b)/FR-5 require the front-matter write on the small-change path too.)
2. **Backstop (gate side).** `qa-plan` #34 and `qa-spec` #18 must-fix a bug-fix/regression-classified phase/spec that slipped through as tests-after or non-red-first. Declaration-only: the observed-red evidence itself is produced at execute time by `tdd-red`'s Oracle block (`0 passed`), reused unchanged.

**Classification signal.** A phase-level `**Phase type:**` field (FR-1) lets a *feature* piece carry one regression-guard phase (the field marks which phase must be red-first), while the piece-level resolution forces the whole piece to red-first so that phase actually runs Red. The three-state predicate (present-bugfix / present-regression / absent⇒feature) is the NN-C-003 back-compat idiom, copied from qa-spec #17.

**Reuse over net-new.** `[TDD-Red]` marker (not a new marker), `tdd-red` observed-red Oracle block (not a new evidence artifact), the `triage-contract.md` keyword set (cited, not re-listed), the `[SPIKE]` marker (not a new no-repro sentinel), and the triage forward-record stamp (already shipped — this piece makes consumers honor it).

## Testing Strategy

- **Static (`assert_grep`, primary):** one assertion per surface token — the `**Phase type:**` field + values (template), the doctrine carve-out, qa-plan #34 / qa-spec #18 criteria + three-state branch, the small-change/intake red-first routing citing the keyword set, the triage-consumer honoring, the FR-021 exclusion in both surfaces, and the version-sync literals.
- **e2e (extends `pipeline-e2e`, merged):** a `tdd: false` repo-config scenario, run for BOTH producer paths (plan skill and `small-change`), where a `**Phase type:** regression` phase yields `tdd: true` front-matter, resolves to red-first, and records observed-red; plus a feature-phase control that is not flagged (the AC-2 false-positive guard).
- **gate-evals fixtures (extends `gate-evals`, merged):** defective fixtures (tests-after bug-fix plan + spec the new criteria must catch) and clean controls (correctly red-first bug-fix plan + spec the criteria must not flag), with the gold-set re-run on the rubric change (AC-9 / SC-009).
- **Back-compat:** a legacy untagged plan/spec fixture passes the new gates untouched (NFR-1 / AC-8).
- **Edge cases:** non-behavioral bug-signal match → recorded exemption (AC-5); non-reproducible defect → `[SPIKE]`/no-repro (AC-6); version half-bump (one plugin.json missed) caught by `static.sh`.

## Integration Coverage

- Integration: `triage` (NN-P-006 forward-record stamp) → `small-change`/`plan-amend`/`new-piece` (fix consumers) — inside: the shared `triage-contract.md` `## Red-first obligation` contract; doubled externals: none (all in-repo plugin surfaces); AC-6; the consumers honor the already-shipped stamp.
- Integration: bug-signal origination (`small-change` track selection, `intake` hotfix path) → red-first track resolution (doctrine + plan TDD-preference resolution) — inside: plugin skills + doctrine; doubled externals: a consuming repo's `.spec-flow.yaml tdd:` value (exercised by the e2e `tdd: false` scenario as the contract under test); AC-2, AC-4.
- The cross-surface wiring is verified by the AC-4 `[outcome:integration]` static sweep (every fix-origination surface must carry the obligation) plus the e2e scenario.

## Open Questions

- None. All four deliberation validated open questions are resolved: VOQ-1 (execute approach) → piece-level governance precedence, no execute reconciliation; VOQ-2 (marker) → reuse `[TDD-Red]`; VOQ-3 (observed-red evidence) → reuse `tdd-red`'s Oracle block; VOQ-4 (false-positive posture) → behavioral filter + recorded non-behavioral exemption.
