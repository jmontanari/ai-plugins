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
---

# Plan: bugfix-redfirst

## Overview

Wire the already-authored non-negotiable **NN-P-006** (bug-fix/regression work is red-first) into spec-flow's plugin governance so it binds in every consuming repo regardless of that repo's `.spec-flow.yaml tdd:` value. Enforcement is **piece-level, prevention-not-plumbing**: bug-fix/regression classification forces the work to the red-first track wholesale (both producers — the plan skill and `small-change` — write `tdd: true` front-matter), and the QA gates **forbid** the un-runnable combination (a bug-fix phase under `tdd: false`) rather than reconcile execute. Net result: **zero `execute/SKILL.md` changes** — a forced-`tdd: true` piece runs Red through the existing machinery.

**Non-TDD mode: all phases use Implement track + Write-Tests; AC Coverage Matrix is not required; QA and Final Review remain intact.** The deliverables are markdown/governance edits (doctrine, template, two skills, two QA agents, one agent, one reference) plus structural test fixtures and a version bump; "tests" are `assert_grep` static assertions (`tests/e2e/lib/static.sh`) and `l2_replay_checks` fixtures (`tests/e2e/fixtures/replay/`), consistent with the no-live-LLM-in-CI harness (NN-C-002).

Target version bump: **5.18.0 → 5.19.0** (minor — additive, backward-compatible governance behavior; NN-C-003).

**Cross-cutting charter constraints (honored by ALL phases via a single mechanism, not re-allocated per phase):**
- **NN-C-002** (markdown + config only): every phase's deliverable is markdown/config plus a bash static assertion — no runtime dependency is introduced in any phase.
- **NN-P-006** (bug-fix/regression work is red-first): the piece's entire purpose; every phase wires one facet of the governance rule. Per-phase slots below cite only the *additional* single-allocated constraints each phase owns.

## Architectural Decisions

### ADR-1: Piece-level governance precedence, not per-phase execute reconciliation
**Context:** NN-P-006 requires bug-fix/regression work to be red-first "regardless of the piece's `tdd` setting." A naive reading wires a per-phase `[TDD-Red]` override *inside* a `tdd: false` piece, which the deliberation's risk lens proved un-runnable (≥7 front-matter-`tdd:false`-keyed execute skip sites would suppress Red; a `tdd: false` plan never emits a `[TDD-Red]` phase today).
**Decision:** Resolve bug-fix/regression work to `tdd: true` **wholesale** at the two producers (plan skill + `small-change`), and have the QA gates forbid a bug-fix/regression phase that is not red-first. The un-runnable combination never reaches execute.
**Alternatives considered:** (α) narrow all 7 execute skip predicates — rejected: fragile, every future skip site silently reintroduces the bug; (β) a dedicated lightweight red-first path — rejected by operator (bug fixes get *real* TDD, not an imitation).
**Consequences:** Zero `execute/SKILL.md` edits; reuses `[TDD-Red]` + `tdd-red`'s observed-red Oracle block unchanged. A feature piece carrying one regression-guard phase becomes `tdd: true` with its feature phases marked `[Implement]` (existing per-phase override). NN-P-006's "regardless of tdd setting" is honored as governance precedence (bug-fix classification overrides repo/plan `tdd: false`).
**Charter alignment:** Honors NN-P-006 (binding outcome unchanged), NN-C-003 (additive), NN-C-002 (no execute machinery, doc-only).

### ADR-2: NN-P-006 lives in the doctrine (plugin governance), not opt-out-able
**Context:** A consuming repo may set `tdd: false` globally; NN-P-006 must still bind there.
**Decision:** Encode the binding statement in `reference/spec-flow-doctrine.md` (`## TDD Is Opt-In`), the session-loaded governance that applies to every consuming repo, and make the bug-fix precedence a deliberate exception to NFR-003's "everything is opt-out via `.spec-flow.yaml`."
**Alternatives considered:** keep it only as the exec-ready PRD's NN-P-006 (rejected — does not bind other repos); make it an opt-out config key (rejected — contradicts a non-negotiable).
**Consequences:** No PRD amendment; the rule binds universally. One new non-opt-out behavior is documented.
**Charter alignment:** NN-P-006, NN-C-003 (additive; absent classification ⇒ feature work, never retro-failed).

### ADR-3: Reuse the existing structural test harness for SC-009 discharge
**Context:** FR-9/AC-9 require published catch rates for the two new merge-blocking gates (qa-plan #34, qa-spec #18). The repo has no live-LLM CI (NN-C-002).
**Decision:** Add defective + clean-control fixtures to the existing `tests/e2e/fixtures/replay/` corpus and assert their expected outcomes in `contract.sh l2_replay_checks` — the same mechanism gate-evals (FR-017) established.
**Alternatives considered:** a bespoke catch-rate harness (rejected — duplicates gate-evals); defer to a future piece (rejected — silent SC-009 drop; this repo fixes findings in-piece).
**Consequences:** SC-009 discharged with bounded, idiomatic fixtures; the rubric change is recorded as triggering the gate-evals gold-set re-run.
**Charter alignment:** NN-C-002 (structural assertions, no runtime dep), NN-C-009 (gold-set re-run on rubric change).

## Phases

### Phase 1: Doctrine governance statement
**ACs Covered:** AC-2 (binding statement), AC-7 (doctrine carve-out)
**Phase type:** feature
**In scope:** edit `plugins/spec-flow/reference/spec-flow-doctrine.md` — the RED-cycle mode gate and the `## TDD Is Opt-In` section.
**NOT in scope:** plan/SKILL.md resolution (Phase 3); template field (Phase 2); the static assertion lives in this phase's `[Write-Tests]`.
**Charter constraints honored in this phase:** cross-cutting only (NN-C-002, NN-P-006 — the doctrine is NN-P-006's governance home).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/reference/spec-flow-doctrine.md`
    Anchor: `### RED — Write Failing Test (TDD mode only)` (L13).
    CURRENT:
    ```
    13  ### RED — Write Failing Test (TDD mode only)
    ```
    TARGET: keep the heading; immediately after the heading's bullet list (before L20 `### BUILD`), add one bullet:
    `- **Bug-fix/regression carve-out:** a phase classified bug-fix/regression (plan **Phase type:** field) runs RED regardless of the piece's \`tdd\` setting — the RED cycle is not gated to TDD mode for such a phase. See \`## TDD Is Opt-In\`. (NN-P-006 / FR-022.)`
    Done: the RED section names the bug-fix/regression carve-out and cross-references `## TDD Is Opt-In`.
  - T-2: MODIFY `plugins/spec-flow/reference/spec-flow-doctrine.md`
    Anchor: `## TDD Is Opt-In` (L175-179).
    CURRENT:
    ```
    177  The Three Laws govern TDD discipline when TDD mode is selected. TDD is **not mandatory** — the plan skill can generate phases using the Implement track ... (`tdd: false` in the plan front-matter). ...
    179  TDD is the default for behavior-bearing code. Non-TDD is the default for configuration, infrastructure, and glue. The plan skill picks the right track for each phase.
    ```
    TARGET: after L179, append a new paragraph (the binding governance statement):
    `**Bug-fix and regression work is always red-first (NN-P-006).** This is the one carve-out from "TDD is opt-in": any phase or change whose purpose is to fix a defect or guard a regression uses the red-first reproduce → see-it-fail → fix → see-it-pass cycle and records the observed failure (the test seen red against the unfixed code) as evidence — regardless of the piece's \`tdd\` setting and regardless of a consuming repo's \`.spec-flow.yaml tdd:\` value. This precedence is **not opt-out-able** (the single deliberate exception to the otherwise-opt-out config surface). Producers resolve such work to \`tdd: true\` wholesale (plan skill + \`small-change\`); the QA gates forbid a bug-fix/regression phase that is not red-first. See PRD NN-P-006 / FR-022 — do not restate the cycle mechanics.`
    Done: the section carries the binding, non-opt-out bug-fix governance statement citing NN-P-006/FR-022.
- [x] **[Write-Tests]** Add a static assertion in `plugins/spec-flow/tests/e2e/lib/static.sh` (in the doc-doctrine assertion area; see Phase 8 for the version block) that the doctrine carries the carve-out:
  `assert_grep "Bug-fix and regression work is always red-first" "${PLUGIN_ROOT}/reference/spec-flow-doctrine.md" "NN-P-006: doctrine carries the bug-fix red-first governance statement"`
  **Test Data:**
  - d1-1: input = grep `"Bug-fix and regression work is always red-first"` in `spec-flow-doctrine.md` → expect: 1+ match (assert passes).
  - d1-2: input = grep `"runs RED regardless of the piece's"` in `spec-flow-doctrine.md` → expect: 1+ match (RED carve-out present).
- [x] **[Verify]** `grep -n "always red-first" plugins/spec-flow/reference/spec-flow-doctrine.md` → Expected: ≥1 match. `bash plugins/spec-flow/tests/e2e/run-e2e.sh static` → Expected: PASS, 0 failed.
- [x] **[QA]** Review against AC-2, AC-7. Diff baseline: phase_1_start_sha.

### Phase 2: Plan template phase-type field
**ACs Covered:** AC-1
**Phase type:** feature
**In scope:** edit `plugins/spec-flow/templates/plan.md` — add a `**Phase type:**` header field to each phase-header example + document its values.
**NOT in scope:** the qa-plan/qa-spec gates that read the field (Phase 6); the plan skill resolution (Phase 3).
**Charter constraints honored in this phase:** CR-009 (the field is body metadata under the existing H3/H4 anchors; the counted `### Phase N:` heading is untouched). Plus cross-cutting NN-C-002, NN-P-006.

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/templates/plan.md`
    Anchor: each `**ACs Covered:** {{ac_list}}` line — L66 (TDD example), L141 (Implement example), L210 (Non-TDD example).
    TARGET: immediately after each `**ACs Covered:**` line, insert:
    `**Phase type:** {{phase_type}}  <!-- bug-fix | regression | feature (default; absent ⇒ feature) — a bug-fix/regression phase is always red-first per NN-P-006 -->`
    Done: all three phase-header examples carry the `**Phase type:**` field directly below `**ACs Covered:**`.
  - T-2: MODIFY `plugins/spec-flow/templates/plan.md`
    Anchor: the template's phase-header field legend / top-of-Phases prose (the comment region documenting header fields).
    TARGET: add one documentation line: `**Phase type:** classifies the phase as \`bug-fix\` / \`regression\` / \`feature\` (absent ⇒ feature work, never retro-failed). A \`bug-fix\`/\`regression\` phase is red-first regardless of the piece's \`tdd\` setting (NN-P-006); the qa-plan/qa-spec gates enforce it. The field is metadata in the phase body — it does NOT alter the counted \`### Phase N:\` heading (CR-009).`
    Done: the field's values and semantics are documented once in the template.
- [x] **[Write-Tests]** Add to `static.sh`:
  `assert_grep "Phase type:" "${PLUGIN_ROOT}/templates/plan.md" "AC-1: plan template carries the Phase type field"` and an assertion that the `### Phase` Scheduler anchor is unchanged: `assert_grep "### Phase 1 (TDD track example):" "${PLUGIN_ROOT}/templates/plan.md" "CR-009: counted phase heading unchanged"`.
  **Test Data:**
  - d2-1: input = grep `"Phase type:"` in `templates/plan.md` → expect ≥3 matches (one per example) + 1 legend.
  - d2-2: input = grep `"### Phase 1 (TDD track example):"` in `templates/plan.md` → expect 1 match (heading intact).
- [x] **[Verify]** `grep -c "Phase type:" plugins/spec-flow/templates/plan.md` → Expected: ≥4. `grep -n "### Phase 1 (TDD track example):" plugins/spec-flow/templates/plan.md` → Expected: 1 match.
- [x] **[QA]** Review against AC-1. Diff baseline: phase_2_start_sha.

### Phase 3: Plan skill — bug-fix precedence + FR-021 carve-out
**ACs Covered:** AC-2 (plan producer path), AC-7 (carve-out in plan/SKILL.md)
**Phase type:** feature
**In scope:** edit `plugins/spec-flow/skills/plan/SKILL.md` — TDD Preference Resolution + Non-TDD-mode override.
**NOT in scope:** small-change resolution (Phase 4); template field (Phase 2).
**Charter constraints honored in this phase:** cross-cutting only (NN-C-002, NN-P-006 — the plan producer honors the precedence). (NN-C-003 back-compat is owned by Phase 6 where the three-state predicate lives.)
**Steps traversed (P2):** the TDD-preference-resolution step (L53-59) and the Phase-2 Non-TDD-mode override (L267-272) — the new bug-fix precedence reads the spec's `**Phase type:**`-bearing intent / piece classification before the existing `tdd:` branch resolves. `plan/SKILL.md` is a multi-step orchestration file (≥3 `### Step`/`### Phase` headings).
**Dispatch sites (P3):** none (no agent-dispatch contract changed).

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`
    Anchor: `### TDD Preference Resolution` (L53-59), the `- **\`false\`**:` bullet (L59).
    TARGET: add a precedence note immediately after the resolution bullets (after L59):
    `**Bug-fix/regression precedence (NN-P-006 — overrides the above).** Independent of the \`tdd\` key value (\`auto\`/\`true\`/\`false\`) and of any consuming repo's \`.spec-flow.yaml tdd:\`, when the spec/work is classified bug-fix or regression (a regression-guard deliverable, or a phase the author tags \`**Phase type:** bug-fix|regression\`), the piece resolves to \`tdd: true\` and the bug-fix/regression phase uses the red-first \`[TDD-Red]\` track. Record \`tdd: true\` in plan front-matter. This precedence is not opt-out-able (\`reference/spec-flow-doctrine.md\` \`## TDD Is Opt-In\`). A feature piece carrying one regression-guard phase is therefore \`tdd: true\` with its feature phases marked \`[Implement]\` (per-phase override).`
    Done: the resolution documents that bug-fix/regression classification forces `tdd: true`, overriding config.
  - T-2: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`
    Anchor: `**Non-TDD mode override.**` (L267-272).
    TARGET: append one bullet to the override list (after L272):
    `- **FR-021 carve-out (NN-P-006).** The \`tdd: false\` efficient default does NOT apply to bug-fix/regression work: a bug-fix/regression-classified phase is excluded from this override and is emitted as a red-first \`[TDD-Red]\` phase (the piece resolves to \`tdd: true\` per the Bug-fix/regression precedence above). See \`reference/spec-flow-doctrine.md\` \`## TDD Is Opt-In\` and PRD FR-021/FR-022.`
    Done: the Non-TDD override documents the bug-fix/regression exclusion citing both FR-021 and FR-022.
- [x] **[Write-Tests]** Add to `static.sh`:
  `assert_grep "Bug-fix/regression precedence" "${PLUGIN_ROOT}/skills/plan/SKILL.md" "AC-2: plan skill forces tdd:true for bug-fix work"` and `assert_grep "does NOT apply to bug-fix" "${PLUGIN_ROOT}/skills/plan/SKILL.md" "AC-7: FR-021 carve-out documented in plan/SKILL.md"`.
  **Test Data:**
  - d3-1: input = grep `"Bug-fix/regression precedence"` in `plan/SKILL.md` → expect 1 match.
  - d3-2: input = grep `"does NOT apply to bug-fix"` in `plan/SKILL.md` → expect 1 match.
  - d3-3 (branch: classification absent): input = a plan with no bug-fix/regression classification → expect: resolution falls through to the existing `tdd:` key value unchanged (no override) — verified by the absence of any unconditional `tdd: true` forcing in the prose.
- [x] **[Verify]** `grep -n "Bug-fix/regression precedence" plugins/spec-flow/skills/plan/SKILL.md` → Expected: 1 match. `grep -n "does NOT apply to bug-fix" plugins/spec-flow/skills/plan/SKILL.md` → Expected: 1 match.
- [x] **[QA]** Review against AC-2, AC-7. Diff baseline: phase_3_start_sha.

### Phase 4: small-change — bug-signal routing + inline front-matter
**ACs Covered:** AC-5 (small-change routing + exemption), AC-2 (small-change producer path)
**Phase type:** feature
**In scope:** edit `plugins/spec-flow/skills/small-change/SKILL.md` Step 9 — bug-signal → red-first track + write `tdd: true` to the inline `plan.md` front-matter; behavioral/non-behavioral exemption branch.
**NOT in scope:** intake hotfix path (Phase 5); the triage keyword set itself (cited from `triage-contract.md`, not redefined).
**Charter constraints honored in this phase:** NN-C-008 (cite the keyword set, never re-list), NN-P-004 (the non-behavioral exemption is recorded, never silent), CR-002 (skill frontmatter unchanged). Plus cross-cutting NN-C-002, NN-P-006.

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/small-change/SKILL.md`
    Anchor: `## Step 9: Inline Plan Generation (FR-SC-5)` — the track-recommendation bullets (L169-171).
    CURRENT:
    ```
    169  - For each phase in `plan.md`, recommend either TDD or Implement track and give one sentence of reasoning.
    170  - Present all track recommendations to the operator and allow per-phase overrides.
    171  - Do not write `plan.md` until the operator confirms the full phase list and all track selections.
    ```
    TARGET: insert, before L169, a bug-signal routing bullet group:
    `- **Bug-signal red-first routing (NN-P-006).** If the change matches a bug signal — the keyword set defined in \`reference/triage-contract.md\` \`## Red-first obligation\` (cite; do not re-list) — and is **behavioral** (a defect with observable broken behavior a failing test can assert), then by default: (a) recommend the red-first \`[TDD-Red]\` track for the fixing phase(s), and (b) write \`tdd: true\` into the inline \`plan.md\` front-matter so the change resolves to red-first wholesale (a per-phase \`[TDD-Red]\` track alone, without the front-matter write, would leave execute's \`tdd:false\` skip sites live). When the matched change is **non-behavioral** (doc/typo/config — nothing a failing test can assert), record a one-line non-behavioral exemption in \`brief.md\` (mirroring the FR-018 recorded-exemption pattern); never a silent skip. If the defect is behavioral but not reproducible by a failing test, route to a \`[SPIKE]\` to establish a reproduction or record an explicit no-repro rationale — never an unobserved-red test.`
    Done: Step 9 routes behavioral bug-signal work to red-first + writes `tdd: true` front-matter, with a recorded non-behavioral exemption and a no-repro `[SPIKE]` fallback.
- [x] **[Write-Tests]** Add to `static.sh`:
  `assert_grep "Bug-signal red-first routing" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "AC-5: small-change routes bug-signal work to red-first"`, `assert_grep "write \\`tdd: true\\` into the inline" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "AC-2: small-change writes tdd:true front-matter"`, and `assert_grep "Red-first obligation" "${PLUGIN_ROOT}/skills/small-change/SKILL.md" "NN-C-008: cites the triage-contract keyword set"`.
  **Test Data:**
  - d4-1 (branch: behavioral bug): input = small-change matching `fix`/`bug` keyword, behavioral → expect: red-first track + `tdd: true` front-matter (prose present).
  - d4-2 (branch: non-behavioral): input = "fix typo in docs" → expect: recorded one-line non-behavioral exemption, no forced red-first.
  - d4-3 (branch: non-reproducible): input = behavioral defect, no failing-test reproduction → expect: `[SPIKE]` or recorded no-repro rationale (no unobserved-red test).
- [x] **[Verify]** `grep -n "Bug-signal red-first routing" plugins/spec-flow/skills/small-change/SKILL.md` → Expected: 1 match. `grep -c "Red-first obligation" plugins/spec-flow/skills/small-change/SKILL.md` → Expected: ≥1 (citation present).
- [x] **[QA]** Review against AC-5, AC-2. Diff baseline: phase_4_start_sha.

### Phase 5: intake — hotfix red-first obligation
**ACs Covered:** AC-5 (hotfix routing)
**Phase type:** feature
**In scope:** edit `plugins/spec-flow/skills/intake/SKILL.md` — the hotfix Next-step handoff message (L375) + the Q4 hotfix branch.
**NOT in scope:** small-change routing (Phase 4); the keyword set (cited).
**Charter constraints honored in this phase:** cross-cutting only (NN-C-002, NN-P-006 — intake hotfix path carries the obligation). (NN-P-004 recorded-exemption + NN-C-008 cite-the-keyword-set are owned by Phase 4; this phase's exemption text mirrors Phase 4's pattern.)

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/skills/intake/SKILL.md`
    Anchor: the Next-step table hotfix row (L375).
    CURRENT:
    ```
    375  | `hotfix` | — | `Branch [branch] ready. Work directly — charter constraints are active.` |
    ```
    TARGET: replace the message cell with:
    `` | `hotfix` | — | `Branch [branch] ready. Charter constraints are active. Bug-fix / regression work is **red-first** (NN-P-006): reproduce → see-it-fail → fix → see-it-pass, recording the observed red against the unfixed code. A non-behavioral change (no observable broken behavior) records a one-line exemption; a non-reproducible defect routes to [SPIKE] / no-repro rationale.` | ``
    Done: the hotfix handoff carries the red-first obligation + the non-behavioral exemption + the no-repro fallback, replacing the bare "Work directly".
  - T-2: MODIFY `plugins/spec-flow/skills/intake/SKILL.md`
    Anchor: Q4 hotfix routing (L207) — `**Hotfix / regression / CI / infra** → \`type: hotfix\` → Q5`.
    TARGET: append a parenthetical pointer: `(bug-fix/regression sub-type → red-first per NN-P-006; see the hotfix handoff message)`.
    Done: the Q4 hotfix branch points to the red-first obligation.
- [x] **[Write-Tests]** Add to `static.sh`:
  `assert_grep "Bug-fix / regression work is \\*\\*red-first\\*\\*" "${PLUGIN_ROOT}/skills/intake/SKILL.md" "AC-5: intake hotfix path carries the red-first obligation"`.
  **Test Data:**
  - d5-1 (branch: hotfix bug work): input = intake hotfix handoff → expect: red-first obligation text present.
  - d5-2 (branch: non-behavioral): input = a non-behavioral hotfix → expect: one-line exemption path named in the message.
- [x] **[Verify]** `grep -n "red-first" plugins/spec-flow/skills/intake/SKILL.md` → Expected: ≥1 match in the hotfix handoff row.
- [x] **[QA]** Review against AC-5. Diff baseline: phase_5_start_sha.

### Phase 6: QA gates — qa-plan #34, qa-spec #18, out-of-band honoring
**ACs Covered:** AC-3 (dual-gate must-fix), AC-6 (out-of-band honoring)
**Phase type:** feature
**In scope:** add criterion #34 to `plugins/spec-flow/agents/qa-plan.md`; add criterion #18 to `plugins/spec-flow/agents/qa-spec.md`; add the out-of-band honoring note to `plugins/spec-flow/reference/triage-contract.md` and a red-first pointer in `plugins/spec-flow/agents/plan-amend.md`.
**NOT in scope:** the gate-evals fixtures that test these criteria (Phase 7); editing the `.agent.md` symlink twins (auto-mirrored).
**Charter constraints honored in this phase:** NN-C-003 (three-state legacy-safe predicate), NN-C-004 (agent bare name), CR-008 (enforcement in agents, not skills), NN-P-001 (gates add findings; sign-off preserved). Plus cross-cutting NN-C-002, NN-P-006.

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/agents/qa-plan.md`
    Anchor: after criterion `33.` (L200-208), before `## Output Format` (L210).
    TARGET: add criterion 34 (mirror the #33 three-state form):
    ```
    34. **Bug-fix/regression red-first (NN-P-006).** Read each phase's `**Phase type:**` field.
        Three-state, legacy-safe:
        - **Absent** (no `**Phase type:**` on the phase, or value `feature`) → skip; feature work, never retro-failed (not a finding).
        - **`bug-fix` / `regression`** → the phase MUST be red-first: a `[TDD-Red]` step (or, in `tdd: false` plans, the piece must have resolved to `tdd: true` per the Bug-fix/regression precedence). A bug-fix/regression phase that uses `[Implement]`/`[Write-Tests]` (tests-after), or whose plan front-matter is `tdd: false`, is must-fix → quote the `**Phase type:**` line and the contradicting track/front-matter. The observed-red EVIDENCE itself is an execute-time artifact (`tdd-red` Oracle block) — do NOT require it here; gate the DECLARATION only.
        Cite PRD NN-P-006 / FR-022; do not restate the cycle mechanics.
    ```
    Done: qa-plan criterion 34 exists with the three-state predicate, declaration-only.
  - T-2: MODIFY `plugins/spec-flow/agents/qa-spec.md`
    Anchor: after criterion `17.` (L56-78), before `## Output Format` (L80).
    TARGET: add criterion 18 (mirror #17 three-state form):
    ```
    18. **Bug-fix/regression red-first (NN-P-006).** Three-state, legacy-safe, decided by the spec's
        declared bug-fix/regression nature (a regression-guard deliverable / Goal, or an AC asserting
        "broken behavior Y no longer happens"):
        - **Not a bug-fix/regression spec** → skip (not a finding).
        - **Bug-fix/regression spec** → must-fix when the spec proposes tests-after, or commits the
          work to `tdd: false` without the red-first obligation; the spec must commit to red-first
          (the plan will resolve to `tdd: true`). Quote the offending line.
        - **No classification signal** (legacy) → skip; never retro-failed.
        Cite PRD NN-P-006 / FR-022; do not restate the cycle mechanics.
    ```
    Done: qa-spec criterion 18 exists, declaration-only, three-state.
  - T-3: MODIFY `plugins/spec-flow/reference/triage-contract.md`
    Anchor: `## Red-first obligation (NN-P-006 forward-record)` (L45-53), the L51 "Forward-record only — NO dependency on the unmerged bugfix-redfirst machinery."
    TARGET: replace L51 with: `Consumers HONOR the stamp: a bug-classified fix routed to \`small-change\` / \`plan-amend\` / \`new-piece\` runs the red-first cycle (small-change Step 9 routing; plan-amend emits a \`**Phase type:** bug-fix|regression\` red-first phase; a new piece's spec/plan carries the bug-fix classification). A non-reproducible defect routes to \`[SPIKE]\` or records an explicit no-repro rationale. Campaign (FR-020) reach remains forward-record only (the campaign skill does not exist).`
    Done: the triage contract states consumers honor the stamp (no longer "forward-record only / no dependency").
  - T-4: MODIFY `plugins/spec-flow/agents/plan-amend.md`
    Anchor: the amendment-phase authoring section.
    TARGET: add one line: `When the amendment fixes a bug or guards a regression, author the amendment phase with \`**Phase type:** bug-fix\` (or \`regression\`) so it is red-first per NN-P-006 (qa-plan #34 enforces).`
    Done: plan-amend emits bug-fix amendment phases as red-first.
- [x] **[Write-Tests]** Add to `static.sh`:
  `assert_grep "34. \\*\\*Bug-fix/regression red-first" "${PLUGIN_ROOT}/agents/qa-plan.md" "AC-3: qa-plan criterion 34 present"`, `assert_grep "18. \\*\\*Bug-fix/regression red-first" "${PLUGIN_ROOT}/agents/qa-spec.md" "AC-3: qa-spec criterion 18 present"`, `assert_grep "Consumers HONOR the stamp" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-6: triage consumers honor the red-first stamp"`. Also assert symlink twins mirror: `diff "${PLUGIN_ROOT}/agents/qa-plan.md" "${PLUGIN_ROOT}/agents/qa-plan.agent.md"` → no output (byte-identical via symlink).
  **Test Data:**
  - d6-1 (branch: bug-fix phase, tests-after): input = a plan phase `**Phase type:** bug-fix` with `[Implement]`/`[Write-Tests]` → expect qa-plan #34 must-fix.
  - d6-2 (branch: bug-fix phase, red-first): input = `**Phase type:** regression` with `[TDD-Red]` under `tdd: true` → expect #34 clean.
  - d6-3 (branch: absent type): input = a feature phase, no `**Phase type:**` → expect #34 skip (no finding).
  - d6-4 (branch: bug-fix spec, tests-after): input = a regression spec proposing tests-after → expect qa-spec #18 must-fix.
  - d6-5 (branch: legacy spec): input = a spec with no classification signal → expect #18 skip.
- [x] **[Verify]** `grep -n "Bug-fix/regression red-first" plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-spec.md` → Expected: 1 match each. `diff plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-plan.agent.md` → Expected: no output (byte-identical).
- [x] **[QA]** Review against AC-3, AC-6. Diff baseline: phase_6_start_sha.

### Phase 7: gate-evals fixtures (SC-009 discharge)
**ACs Covered:** AC-9
**Phase type:** feature
**In scope:** add 4 fixtures to `plugins/spec-flow/tests/e2e/fixtures/replay/` (defective + clean control for qa-plan #34; defective + clean control for qa-spec #18) and register their expected outcomes in `plugins/spec-flow/tests/e2e/lib/contract.sh` `l2_replay_checks`.
**NOT in scope:** the criteria themselves (Phase 6); the version bump (Phase 8).
**Charter constraints honored in this phase:** cross-cutting only (NN-C-002 — structural fixtures, no runtime dep; NN-P-006). (The NN-C-009 rubric-change → gold-set-re-run obligation is recorded in the CHANGELOG at Phase 8, which owns NN-C-009.)

- [x] **[Implement]**
  - T-1: CREATE `plugins/spec-flow/tests/e2e/fixtures/replay/plan-bugfix-tests-after.md`
    Structure (mirror `plan-authored-tests-collision.md` header-comment convention): a `tdd: false` plan with a `### Phase 1` carrying `**Phase type:** regression` and an `[Implement]`/`[Write-Tests]` (tests-after) step. Header comment: `# Scenario: bug-fix/regression phase proposes tests-after under tdd:false. # Expected qa-plan criterion 34 outcome: must-fix.`
    Done: defective fixture exists; criterion 34 must-fix is the documented expected outcome.
  - T-2: CREATE `plugins/spec-flow/tests/e2e/fixtures/replay/plan-bugfix-redfirst-clean.md`
    Structure: a `tdd: true` plan with `### Phase 1` `**Phase type:** regression` and a `[TDD-Red]` step + Test Data block. Header comment: `# Expected qa-plan criterion 34 outcome: clean (red-first).`
    Done: clean control exists.
  - T-3: CREATE `plugins/spec-flow/tests/e2e/fixtures/replay/spec-bugfix-tests-after.md`
    Structure: a spec fragment classified as a regression (Goal/AC asserting "broken behavior Y no longer happens") that proposes tests-after / commits `tdd: false`. Header comment: `# Expected qa-spec criterion 18 outcome: must-fix.`
    Done: defective spec fixture exists.
  - T-4: CREATE `plugins/spec-flow/tests/e2e/fixtures/replay/spec-bugfix-redfirst-clean.md`
    Structure: a regression spec committing to red-first. Header comment: `# Expected qa-spec criterion 18 outcome: clean.`
    Done: clean spec control exists.
  - T-5: MODIFY `plugins/spec-flow/tests/e2e/lib/contract.sh`
    Anchor: `l2_replay_checks()` (L341).
    TARGET: register 4 structural assertions — each fixture exists and carries the markers its expected outcome keys on (e.g. `plan-bugfix-tests-after.md` contains `**Phase type:** regression` AND an `[Implement]`/`[Write-Tests]` step AND `tdd: false`; the clean control contains `[TDD-Red]` AND `tdd: true`). Record a catch-rate comment: `# gate-evals: qa-plan #34 / qa-spec #18 — 2 defective + 2 clean controls; catch-rate slot.`
    Done: `l2_replay_checks` asserts all 4 fixtures' expected structural markers.
- [x] **[Write-Tests]** The fixtures + `l2_replay_checks` assertions ARE the tests for this phase. Add a roll-up assertion in `static.sh` that the 4 fixtures exist: `for f in plan-bugfix-tests-after plan-bugfix-redfirst-clean spec-bugfix-tests-after spec-bugfix-redfirst-clean; do assert_grep "Phase type:\\|red-first\\|regression" "${PLUGIN_ROOT}/tests/e2e/fixtures/replay/$f.md" "AC-9: fixture $f present"; done`.
  **Test Data:**
  - d7-1: input = `l2_replay_checks` run over `plan-bugfix-tests-after.md` → expect: structural markers of a #34 must-fix scenario present (assert passes).
  - d7-2: input = `l2_replay_checks` over `plan-bugfix-redfirst-clean.md` → expect: red-first markers present (clean-control assert passes).
  - d7-3: input = the 2 spec fixtures → expect: #18 defective + clean markers present.
- [x] **[Verify]** `ls plugins/spec-flow/tests/e2e/fixtures/replay/{plan,spec}-bugfix-*.md` → Expected: 4 files. `bash plugins/spec-flow/tests/e2e/run-e2e.sh` → Expected: L2 replay PASS, 0 failed.
- [x] **[QA]** Review against AC-9. Diff baseline: phase_7_start_sha.

### Phase 8: Version-sync + cross-surface integration sweep
**ACs Covered:** AC-8 (version-sync + back-compat), AC-4 (cross-surface integration sweep), AC-2 (integration verification of the producer-resolution wiring)
**Phase type:** feature
**In scope:** bump 5.18.0 → 5.19.0 across both `plugin.json` files + root `marketplace.json` spec-flow entry + CHANGELOG; update the `static.sh` version literals; add the cross-surface integration sweep assertion.
**NOT in scope:** any new behavior (this phase is finalization + verification only).
**Charter constraints honored in this phase:** NN-C-009 (version bump across all version-bearing files + static literals in lockstep — subsumes the NN-C-001 plugin.json↔marketplace sync and the NN-C-007 CHANGELOG entry, both exercised by T-3/T-4 here). Plus cross-cutting NN-C-002, NN-P-006.
**Integration-Test:** completes_in_phase: 8. Boundary: every fix-origination surface (doctrine, plan/SKILL.md, small-change, intake, qa-plan, qa-spec, triage-contract, plan-amend) must carry the red-first obligation token end-to-end. Doubled externals: a consuming repo's `.spec-flow.yaml tdd:` value (represented by the `plan-bugfix-*` replay fixtures as the contract under test). No live externals.

- [x] **[Implement]**
  - T-1: MODIFY `plugins/spec-flow/plugin.json` — `"version": "5.18.0"` → `"5.19.0"`.
  - T-2: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` — `"version": "5.18.0"` → `"5.19.0"`.
  - T-3: MODIFY root `.claude-plugin/marketplace.json` — the spec-flow entry `"version": "5.18.0"` → `"5.19.0"`.
  - T-4: MODIFY `plugins/spec-flow/CHANGELOG.md` — prepend `## [5.19.0] — 2026-06-13` under the title, with `### Added` (NN-P-006 bug-fix/regression red-first governance: doctrine statement, plan `**Phase type:**` tag, plan/small-change `tdd: true` precedence, intake hotfix obligation, qa-plan #34 / qa-spec #18, gate-evals fixtures) and `### Notes for upgraders` (bug-fix/regression work is now red-first regardless of `tdd: false`; not opt-out-able; rubric change ⇒ gate-evals gold-set re-run).
  - T-5: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`
    Anchor: the AC-11 version-sync block (L207-214) — the 3× `assert_grep '"version": "5\.18\.0"'`.
    TARGET: update all three literals `5\.18\.0` → `5\.19\.0` (covering `${PLUGIN_ROOT}/plugin.json`, `${REPO_ROOT}/.claude-plugin/marketplace.json`, `${PLUGIN_ROOT}/.claude-plugin/plugin.json`). NOTE: there is NO `[5.18.0]` CHANGELOG assertion in static.sh — the only CHANGELOG section assertion (L219) checks `[5.16.1]`, a FROZEN historical anchor that must NOT be changed. Instead, ADD a new assertion `assert_grep "\[5\.19\.0\]" "$changelog" "AC-8: CHANGELOG carries the 5.19.0 section"` alongside the existing one (do not replace the 5.16.1 assertion).
    Done: static.sh asserts 5.19.0 across all three version sites AND adds a new (non-replacing) `[5.19.0]` CHANGELOG assertion; the frozen `[5.16.1]` assertion is untouched.
  - T-6: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh`
    TARGET: add the cross-surface integration sweep — one `assert_grep` per fix-origination surface that the red-first obligation token is present (doctrine "always red-first"; plan/SKILL.md "Bug-fix/regression precedence"; small-change "Bug-signal red-first routing"; intake "red-first"; qa-plan "34. **Bug-fix/regression red-first"; qa-spec "18. **Bug-fix/regression red-first"; triage-contract "Consumers HONOR the stamp"). A missing surface fails the sweep (AC-4).
    Done: static.sh carries a sweep that fails if any fix-origination surface lacks the obligation.
- [x] **[Write-Tests]** The static.sh version block + cross-surface sweep ARE the tests. Add a back-compat assertion: a fixture/representative plan with no `**Phase type:**` field passes qa-plan #34 (skip branch) — assert `plan-clean.md` (existing, untagged) is NOT flagged by #34 via `l2_replay_checks`.
  **Test Data:**
  - d8-1 (version sync): input = `grep '"version"' ` across both plugin.json + marketplace → expect all `5.19.0` (identical).
  - d8-2 (static literal): input = `grep '5\.19\.0' static.sh` → expect 3+ matches; `grep '5\.18\.0' static.sh` → expect 0.
  - d8-3 (cross-surface sweep, AC-4): input = run the sweep over all 7 surfaces → expect all present (pass); removing any one → sweep fails.
  - d8-4 (back-compat, AC-8): input = untagged `plan-clean.md` → expect qa-plan #34 skip (not flagged).
- [x] **[Integration-Test]** completes_in_phase: 8. Run `bash plugins/spec-flow/tests/e2e/run-e2e.sh static` and the `l2_replay_checks` — confirm: (a) all 7 fix-origination surfaces carry the obligation (cross-surface sweep PASS), (b) version is 5.19.0 everywhere, (c) the defective bug-fix fixtures trip #34/#18 and the clean controls + untagged legacy plan pass. This is the AC-2/AC-4 end-to-end wiring verification (producer-resolution + every-surface coverage).
- [x] **[Verify]** `bash plugins/spec-flow/tests/e2e/run-e2e.sh` → Expected: ALL PASS, 0 failed. `git grep -c "5.18.0" plugins/spec-flow/ | grep -v ':0'` → Expected: no stray 5.18.0 (except historical CHANGELOG entries).
- [x] **[QA]** Review against AC-8, AC-4, AC-2. Diff baseline: phase_8_start_sha.

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Plan template carries `**Phase type:**` field; feature piece may carry one bug-fix phase | COVERED | Phase 2 |
| AC-2 | Bug-fix work resolves to red-first under `tdd:false`; never false-green; never false-positive on feature | COVERED | Phase 1, Phase 3, Phase 4, Phase 8 |
| AC-3 | qa-plan #34 + qa-spec #18 must-fix on tests-after / missing declaration (three-state) | COVERED | Phase 6 |
| AC-4 | Red-first obligation wired at every fix-origination surface (integration sweep) | COVERED | Phase 8 |
| AC-5 | small-change + intake hotfix route bug-signal → red-first; non-behavioral recorded exemption | COVERED | Phase 4, Phase 5 |
| AC-6 | Out-of-band triage fix routes honor the stamp; no-repro → `[SPIKE]`/rationale | COVERED | Phase 6 |
| AC-7 | FR-021 `tdd:false` exclusion documented in both FR surfaces (doctrine + plan/SKILL.md) | COVERED | Phase 1, Phase 3 |
| AC-8 | Untagged plans not retro-failed (three-state); version bump across all version-bearing files + static literals | COVERED | Phase 8 |
| AC-9 | gate-evals fixtures (defective + clean controls) for #34/#18 → published catch rate | COVERED | Phase 7 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -c "Phase type:" plugins/spec-flow/templates/plan.md` | ≥4 |
| AC-2 | shell | `grep -n "Bug-fix/regression precedence" plugins/spec-flow/skills/plan/SKILL.md && grep -n "Bug-signal red-first routing" plugins/spec-flow/skills/small-change/SKILL.md` | 1 match each |
| AC-3 | shell | `grep -c "Bug-fix/regression red-first" plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/qa-spec.md` | 1 each |
| AC-4 | shell | `bash plugins/spec-flow/tests/e2e/run-e2e.sh static` (cross-surface sweep) | PASS, 0 failed |
| AC-5 | shell | `grep -n "Bug-signal red-first routing" plugins/spec-flow/skills/small-change/SKILL.md && grep -n "red-first" plugins/spec-flow/skills/intake/SKILL.md` | 1+ match each |
| AC-6 | shell | `grep -n "Consumers HONOR the stamp" plugins/spec-flow/reference/triage-contract.md` | 1 match |
| AC-7 | shell | `grep -n "always red-first" plugins/spec-flow/reference/spec-flow-doctrine.md && grep -n "does NOT apply to bug-fix" plugins/spec-flow/skills/plan/SKILL.md` | 1 match each |
| AC-8 | shell | `git grep -l '"version": "5.19.0"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` | 3 files |
| AC-9 | shell | `ls plugins/spec-flow/tests/e2e/fixtures/replay/{plan,spec}-bugfix-*.md \| wc -l` | 4 |

## Contracts

No TDD-track phases in this plan (`tdd: false` — all phases use Implement track + Write-Tests). Contracts section present for forward compatibility. `tdd-red` agents will not be dispatched; no contract injection occurs. The boundary-crossing "interface" this piece introduces — the `**Phase type:**` field as the gate input — is documented in the plan template (Phase 2) and consumed by qa-plan #34 / qa-spec #18 (Phase 6); its consistency is verified by the Phase 8 cross-surface integration sweep.

## Parallel Execution Notes

All phases are **serial**. Why serial: phases form a dependency chain — the doctrine (P1) is the governance foundation; the `**Phase type:**` tag (P2) must exist before the gates (P6) and fixtures (P7) reference it; the producer resolution (P3, P4) must exist before the cross-surface sweep (P8) can assert it; the version bump + sweep (P8) must run last.

**Shared-file (`tests/e2e/lib/static.sh`) region discipline.** Phases 1–7 each APPEND their new `assert_grep` lines into a single new labelled block delimited by `# --- bugfix-redfirst: phase<N> ---` … `# --- end phase<N> ---` (each phase owns its own labelled region — no two phases edit the same lines). Only **Phase 8** edits the pre-existing version-sync block (L207-214) and the CHANGELOG assertions, and adds the cross-surface sweep in its own `# --- bugfix-redfirst: sweep ---` region. Because execution is serial and each phase writes a disjoint labelled region, there is no contention and no Phase 0 Scaffold is needed (the Scaffold pattern addresses *concurrent* `[P]` contention, which does not apply here).
