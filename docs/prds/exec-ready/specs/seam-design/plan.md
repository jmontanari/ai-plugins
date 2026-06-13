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
review_board_variant: doc-as-code  # deliverable is entirely markdown (reference docs, agent prompts, template, skill, fixtures) — swap blind seat for dual seeded edge-case (structural + semantic)
---

# Plan: seam-design

**Spec:** docs/prds/exec-ready/specs/seam-design/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Narrow, additive hardening of the **already-shipped** integration-coverage contract (doctrine §"Integration Tests & Path Coverage", the `## Integration Coverage` block, plan B-lite + `## Integration-Test Registry`, qa-spec #13/#17, qa-plan #26, the `review-board-integration` agent). Per the deliberation recommendation (full-confidence — Adversarial Review ran, 3 lenses), this is **not** a new "seam primitive": it ships the FR-024 residue as five touchpoints on the integration axis.

Two mechanisms:
- **A — production-call-site obligation + 3-place reconciliation.** A declared seam's allocated AC must cite a production-rooted `prod-callsite=<path>` pointer on its `Independent Test [machine:]` sub-line; that pointer is shape-checked at qa-spec construction (present + production-rooted + not-under-test-root), mapped to a wiring phase at qa-plan, and reconciled against the diff-derived wired-path inventory at review-board-integration.
- **B — silent-omission closure.** A behavior-bearing, boundary-touching spec can no longer pass by omitting the `## Integration Coverage` block or free-text-N/A-ing the `[outcome:integration]` facet — it must declare its integrations or record an `integration_rationale` front-matter exemption.

**Implementation mode — Non-TDD (`tdd: false`), doc-as-code.** Every deliverable is markdown: a reference doc (doctrine, behavior-classification), a template, a skill, three QA-agent prompts, and gate-eval fixtures. There is no runtime code and no executable unit suite. Verification is (a) static greps over the edited markdown (the `[machine:]` ACs) and (b) **gate-eval runs** — dispatch the actual QA-agent prompt against a planted-defect / clean fixture and grep its verdict (mirrors the shipped `outcome-acs` fixture approach at `plugins/spec-flow/tests/fixtures/outcome-acs/`). Phases 1–2 (pure definitional/template/skill edits) use the **Implement track** (`[Implement]` → `[Verify]`) — their verification is a self-contained static grep, so there is no separate behavioral test to author; `[Write-Tests]` would be ceremony. Phases that author fixtures (Phase Group A sub-phases, Phase 4) carry `[Write-Tests]` (fixture authoring) + a Test Data block. Per qa-plan #33, a `behavior-bearing` piece may legitimately use either track; no `[TDD-Red]` block appears anywhere.

**Phase map (dependency order, inside-out):**
1. **Phase 1 — Definitions** (single source of truth): doctrine `prod-callsite` convention + behavior-classification boundary-touching predicate. The gates cite these by anchor, so they land first.
2. **Phase 2 — Authoring surface**: spec template field + spec skill emission. Depends on Phase 1's definitions.
3. **Phase Group A — Gates** (3 disjoint agent files, `[P]`): qa-spec (#13 extend + #17 tighten), qa-plan (#26 extend), review-board-integration (reconciliation). Each cites Phase 1's definitions; mutually disjoint files → parallel-by-default.
4. **Phase 4 — Cross-gate controls + release**: no-false-positive / no-retro-fail (AC-7) against legacy + clean fixtures across all three gates, cross-phase token-consistency check, version triad bump (NN-C-009).

AC Coverage Matrix and Executable AC Binding are included for rigor (the Non-TDD override makes the matrix optional, not forbidden).

## Architectural Decisions

### ADR-1: Production-call-site pointer rides the `Independent Test [machine:]` sub-line, not the `[outcome:integration]` facet tag
**Context:** The seam must name a production call site. Two carriers were live: overload the existing `[outcome:integration]` AC-line facet tag with the `src/` locator (path 1a), or place the locator on the AC's `Independent Test [machine:]` sub-line (path 2a).
**Decision:** Place `prod-callsite=<path>` on the `Independent Test [machine:]` sub-line. REJECT 1a.
**Alternatives considered:** 1a (overload facet tag) — breaks the "exactly one AC-line tag" invariant and conflates negative-space facet semantics with a positive locator; 1b (mint a 4th AC-line tag) — non-additive schema change, retro-fail risk against every existing spec; 1c (new standalone artifact) — CR-009 heading collision + duplicate source of one fact (drift).
**Consequences:** Preserves the exactly-one-tag invariant; orthogonal to the facet tag; reuses the shipped test-pointer sub-line. Matches the already-shipped integration ADR (`proposals/review-board-integration/spec.md:262-263`).
**Charter alignment:** CR-009 (no new `###` under `## Acceptance Criteria`); NN-C-003 (additive — rides an existing sub-line).

### ADR-2: Omission closure tightens qa-spec #17 + extends #13 — does NOT mint a new criterion #18
**Context:** A behavior-bearing boundary-touching spec can pass today by omitting the Integration Coverage block or free-text-N/A-ing the integration facet (the FO-16 hole).
**Decision:** Close the hole by tightening the free-text N/A sentinel handling in #17 (which already runs for all behavior-bearing pieces via `piece_class`) and extending #13's existing "silently deferred → must-fix" clause with the boundary-touching predicate. Do not mint #18.
**Alternatives considered:** New criterion #18 — duplicates #17's three-state `piece_class` predicate and fragments omission-closure (already owned by #13) across two criteria.
**Consequences:** One concern stays in the two criteria that already own it; no parallel legacy-skip/exemption logic re-derived; no new retro-fail surface beyond what #13/#17 already impose.
**Charter alignment:** NN-C-003 (no activation-guard mutation of a shipped criterion that would retro-fail); CR-008 (gate logic stays in the gate, not in behavior-classification).

### ADR-3: FR-024-A folds into qa-spec #13; FR-024-C folds into qa-plan #26 (extend, not new criteria)
**Context:** The pointer-presence check (FR-024-A) and the pointer-maps-to-a-phase check (FR-024-C) are each a completeness clause on an allocation concern that an existing criterion already owns.
**Decision:** Extend #13 with the pointer clause; extend #26 with the maps-to-phase clause. No standalone criteria.
**Alternatives considered:** Standalone qa-spec / qa-plan criteria — fragment one allocation concern across two criteria and (for qa-plan) duplicate #26's "spec declares an Integration Coverage block" activation guard.
**Consequences:** Same activation guards reused (no retro-fail surface change); criterion count unchanged; the new clauses inherit the existing skip-if-absent semantics.
**Charter alignment:** NN-C-003 (additive clause, existing guard); CR-008 (one criterion, one concern).

### ADR-4: Exemption rationale lives in front-matter (`integration_rationale`), mirroring `behavior_rationale`
**Context:** A behavior-bearing piece that genuinely touches no boundary needs an exemption from the declaration obligation. Two homes: front-matter (5a) or the Integration Coverage block body (5b).
**Decision:** Front-matter key `integration_rationale` (5a). Collapse now; do not ship 5b.
**Alternatives considered:** 5b (block body) — splits rationale between front-matter and block body where #17 already standardizes front-matter (`behavior_rationale`), creating two homes for one rationale class.
**Consequences:** Rides the existing `piece_class` / `behavior_rationale` front-matter machinery #17 already reads — one schema, no new field family. Gate checks rationale PRESENCE, not correctness (judgment-backstopped).
**Charter alignment:** NN-C-003 (additive front-matter key); CR-008.

### ADR-5: No caller-existence verification at construction — truthfulness reconciled at review time against the diff-derived inventory
**Context:** A construction-time gate cannot prove the cited production call site actually wires the seam (VOQ-1 false-assurance risk).
**Decision:** Construction gates (qa-spec, qa-plan) check pointer SHAPE only. Truthfulness is reconciled by review-board-integration cross-checking the cited `prod-callsite` against the wired-path inventory it already derives from the diff (VOQ-1 option b). The predicate and pointer gates are explicitly labelled judgment-backstopped / shape-only — no deterministic-closure claim.
**Alternatives considered:** Path 2c (gate confirms the caller exists in `src/`) — requires AST / call-graph tooling forbidden by NN-C-002; dropping Mechanism A entirely — loses the shift-left review TARGET the reconciliation needs.
**Consequences:** Closes the false-assurance gap without runtime tooling; the genuine "is it wired in prod" catch is reused from review-board-integration's existing inventory rather than re-derived.
**Charter alignment:** NN-C-002 (markdown/bash/yaml only — no AST tooling); honest-scope (the spec states class-3 closure only).

## Phases

Each phase uses exactly ONE track. This plan is Non-TDD (`tdd: false`): no `[TDD-Red]` / `[QA-Red]` / `[Build]` anywhere. Phases 1–2 use the Implement track (`[Implement]` → `[Verify]`). Phase Group A sub-phases and Phase 4 use `[Implement]` → `[Write-Tests]` → `[Verify]` (they author fixtures).

## Integration-Test Registry (M1)

**None in scope.** This piece declares no integrations of its own (spec `## Integration Coverage`: "None in scope"; dogfoods FR-024-D's exemption — `integration_rationale: edits gate prompts/docs only; no runtime boundary`). Per NFR-INT-02, an absent registry means no integrations declared. No `[Integration-Test]` block appears in any phase.

---

### Phase 1: Definitions — doctrine pointer convention + behavior-classification boundary-touching predicate

**Exit Gate:** `prod-callsite=` convention (with the test-root exclusion rule) is present in `reference/spec-flow-doctrine.md` §Integration; the three-state boundary-touching predicate + "judgment-backstopped" caveat + the `integration_rationale` key are present in `reference/behavior-classification.md`. Both grep checks below pass.
**ACs Covered:** AC-1 (doctrine half), AC-6 (predicate + key half)
**In scope:** add the production-call-site pointer convention to `reference/spec-flow-doctrine.md`; add the boundary-touching predicate section + the `integration_rationale` front-matter key to `reference/behavior-classification.md`
**NOT in scope:** the spec-template surfacing of the convention and the `integration_rationale` template field (Phase 2); the spec-skill emission (Phase 2); any gate enforcement (Phase Group A); version bump (Phase 4)
**Charter constraints honored in this phase:**
- NN-C-002 (markdown only, no runtime deps): both edits are markdown prose; the convention is grep-shaped, explicitly rejecting any AST/caller-existence check.
- CR-005 (repo-root-relative paths): the convention and predicate reference each other by repo-root-relative path (`reference/spec-flow-doctrine.md`, `reference/behavior-classification.md`).
- CR-008 (thin orchestrator / narrow executor): behavior-classification.md carries ONLY the predicate/token DEFINITION; no gate enforcement logic is placed there.

- [x] **[Implement]** Add the definitions
  - Order: doctrine convention (T-1) first — it is the single source of truth the predicate and the gates cite — then the behavior-classification predicate + key (T-2).
  - Architecture constraints this phase must honor: definitions only; the gates (Phase Group A) cite these by anchor and own all enforcement (CR-008). The pointer convention is a SHAPE locator, never a caller-existence assertion (NN-C-002, ADR-5).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/reference/spec-flow-doctrine.md**
  - Anchor: end of `## Integration Tests & Path Coverage` (the M4 bullet ends ~line 136; `## Verification Checklist` begins at line 138)
  - Current:
    ```
    136  - **M4 — Oracle split + completing-phase `[Integration-Test]` sub-cycle.** The completing phase's `[Verify]` block is split into a non-integration oracle (per-phase gate) and an integration oracle (runs `[integration]`-tagged tests). The `[Integration-Test]` sub-cycle in the completing phase confirms the wired path is green before advancing.
    137
    138  ## Verification Checklist
    ```
  - Target: insert a new sub-block between line 136 and the blank line preceding `## Verification Checklist` (i.e. at the end of the §Integration section), with this exact prose:

    > **Production-call-site pointer.** A declared integration's allocated AC carries a production-call-site pointer on its `Independent Test [machine:]` sub-line, written as the literal token `prod-callsite=<path>` inside the `[machine: …]` bracket. `<path>` is repo-root-relative and rooted in production source — it MUST NOT resolve under a test root (`tests/`, a `*_test.*` filename, or any `*/test/*` or `*/tests/*` segment). It names the production call path the integration AC exercises; a seam whose pointer is absent or test-rooted is the untested-unused-seam failure (integration failure class 3). The pointer is **shape-checked at construction** (present + production-rooted + not-under-test-root) by qa-spec and qa-plan; its **truthfulness** — does the cited site actually wire the seam — is reconciled by `review-board-integration` against the wired-path inventory it derives from the diff, not at construction (NN-C-002 forbids the AST/call-graph tooling a construction-time existence check would require).

  - Pattern (sibling definition style already in this section, lines 121-123 — terse bold-lead-in definition):
    ```
    121  **Contract test** — a test that verifies a stub or fake of a true external stays faithful to the real external's contract. Required for every doubled true external.
    ```
  - Done: a `**Production-call-site pointer.**` paragraph exists at the end of §Integration, naming the `prod-callsite=<path>` token, the production-rooted requirement, the test-root exclusion list, and the construction-shape-vs-review-truthfulness split.
  - Verify: `grep -n "prod-callsite=" plugins/spec-flow/reference/spec-flow-doctrine.md` returns ≥1 match AND `grep -n "MUST NOT resolve under a test root" plugins/spec-flow/reference/spec-flow-doctrine.md` returns a match.

  **T-2: MODIFY plugins/spec-flow/reference/behavior-classification.md**
  - Anchor (a): the `**Front-matter keys:**` yaml block (lines 22-25); Anchor (b): the boundary between `## Outcome facets` (ends ~line 47) and `## Canonical token glossary` (line 49).
  - Current (front-matter keys block, lines 20-29):
    ```
    20  **Front-matter keys:**
    21
    22  ```yaml
    23  piece_class: behavior-bearing | non-behavioral
    24  behavior_rationale: {{required only when non-behavioral}}
    25  ```
    26
    27  `behavior_rationale` is required when `piece_class: non-behavioral`; it is omitted for
    28  `behavior-bearing` pieces. The absence of `piece_class` entirely signals a legacy spec
    29  predating this classification scheme — gates treat that as an exempt/skip condition.
    ```
  - Target (a): add `integration_rationale` to the yaml block and a sentence describing it, so the block reads:
    ```yaml
    piece_class: behavior-bearing | non-behavioral
    behavior_rationale: {{required only when non-behavioral}}
    integration_rationale: {{required only when behavior-bearing AND the piece declares it touches no integration boundary}}
    ```
    and append after line 29 a sentence: "`integration_rationale` is required only when a `behavior-bearing` piece asserts it crosses no integration boundary (the non-boundary exemption — see ## Boundary-touching predicate below); it is omitted when the piece declares its integrations. Its **absence is meaningful** (no exemption claimed → integrations must be declared) and is NOT a legacy signal — only the absence of `piece_class` is the legacy/skip discriminator."
  - Target (b): insert a new `## Boundary-touching predicate` section after `## Outcome facets` and before `## Canonical token glossary` (line 49), with this content:

    > ## Boundary-touching predicate
    >
    > A three-state predicate, evaluated at spec time for behavior-bearing pieces, deciding whether the integration facet's declaration obligation applies. It is **judgment-backstopped, NOT deterministic closure**: no markdown/bash-only gate can decide "this piece touches an integration boundary" (that needs the call-graph analysis NN-C-002 forbids). The deterministic surface is field/sentinel/pointer presence; **qa-spec judgment is the actual enforcer** of a wrong non-boundary claim. An author can dodge by mis-declaring; this predicate does not claim to prevent that.
    >
    > - **Boundary-touching (enforce):** the piece is `behavior-bearing` AND wires, calls, or crosses an integration boundary (a real component → collaborator → external chain, per the *integration boundary* definition in `spec-flow-doctrine.md`). It MUST either declare ≥1 integration in its `## Integration Coverage` block OR record an `integration_rationale` front-matter value.
    > - **Declared non-boundary (exempt-with-rationale):** the piece is `behavior-bearing` but its author asserts it crosses no integration boundary. Exempt from the declaration obligation ONLY when `integration_rationale` is present (rationale *presence* is the clean state; the gate does not adjudicate rationale *correctness* — that is qa-spec judgment, the criterion-15 sentinel precedent).
    > - **Ambiguous → boundary-touching:** when boundary-touching status is genuinely ambiguous, default to boundary-touching (the stricter state), mirroring the `piece_class` ambiguity rule above.

  - Pattern (the existing three-state framing the predicate mirrors — front-matter-keyed, presence-is-clean, lines 27-29 above and the `piece_class` ambiguity rule at line 18):
    ```
    18  **Ambiguity rule:** When piece classification is genuinely ambiguous, default to `behavior-bearing`.
    ```
  - Done: the `integration_rationale` key is in the yaml block with its "absence is meaningful, not legacy" sentence; a `## Boundary-touching predicate` H2 section exists with the three states and the literal phrase "judgment-backstopped" and carries NO locator/pointer semantics (those live in doctrine per ADR-1).
  - Verify: `grep -n "## Boundary-touching predicate" plugins/spec-flow/reference/behavior-classification.md` matches; `grep -n "judgment-backstopped" plugins/spec-flow/reference/behavior-classification.md` matches; `grep -n "integration_rationale" plugins/spec-flow/reference/behavior-classification.md` returns ≥2 matches; `grep -n "prod-callsite" plugins/spec-flow/reference/behavior-classification.md` returns 0 matches (no locator semantics leaked here — ADR-1).

- [x] **[Verify]** Confirm the definitions are present and correctly scoped
  **Per-change checks:**
  - T-1: `grep -c "prod-callsite=" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: ≥1; and `grep -c "MUST NOT resolve under a test root" plugins/spec-flow/reference/spec-flow-doctrine.md` — Expected: 1
  - T-2: `grep -c "## Boundary-touching predicate" plugins/spec-flow/reference/behavior-classification.md` — Expected: 1; `grep -c "judgment-backstopped" plugins/spec-flow/reference/behavior-classification.md` — Expected: ≥1; `grep -c "integration_rationale" plugins/spec-flow/reference/behavior-classification.md` — Expected: ≥2; `grep -c "prod-callsite" plugins/spec-flow/reference/behavior-classification.md` — Expected: 0
  **Phase-level check:**
  - Run (LLM-agent-step): Read `plugins/spec-flow/reference/spec-flow-doctrine.md` §"Integration Tests & Path Coverage" and `plugins/spec-flow/reference/behavior-classification.md` and confirm: (1) the doctrine `prod-callsite` paragraph states the production-rooted requirement + the test-root exclusion list + the shape-vs-truthfulness split; (2) the behavior-classification predicate has exactly three states and states it is judgment-backstopped; (3) no `prod-callsite` locator text appears in behavior-classification.md.
  - Expected: all three confirmations hold.
  - Failure: a missing test-root exclusion list, a missing judgment-backstopped caveat, or locator text leaked into behavior-classification.md.

---

### Phase 2: Authoring surface — spec template field + spec skill emission

**Exit Gate:** `templates/spec.md` front-matter carries `integration_rationale` and its AC-form comment surfaces the `prod-callsite` convention; `skills/spec/SKILL.md` Phase-3 write step instructs emitting `integration_rationale` for new specs. Both greps below pass.
**ACs Covered:** AC-1 (template half), AC-6 (template + skill half)
**In scope:** add the `integration_rationale` front-matter field + surface the `prod-callsite` pointer convention in `templates/spec.md`; extend `skills/spec/SKILL.md` Phase-3 step 3 to emit `integration_rationale` for greenfield specs (same drift/amend exclusion as `piece_class`)
**NOT in scope:** the doctrine/behavior-classification definitions (Phase 1, done); gate enforcement (Phase Group A); version bump (Phase 4)
**Steps traversed (P2):** `skills/spec/SKILL.md` is a multi-step orchestration file (5 `### Phase` headings). The edit rides Phase 3 "Write Spec" step 3 (the existing greenfield "always-write `piece_class`" step) and inherits its drift/amend back-fill exclusion (Phase 1 step 7 — a legacy spec reaching the skill without the key stays without it). No new conditional path is introduced through the Phase 1→4 loop; the new emission is a sibling clause inside the already-traversed step 3.
**Dispatch sites (P3):** none. The spec skill dispatches `qa-spec` (Phase 4 QA loop) and `fix-doc`; neither dispatch contract changes — `qa-spec` reads `integration_rationale` from the full spec it already receives, so no agent-dispatch contract is altered.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compatibility): the template field and skill clause are additive; the skill explicitly does NOT back-fill `integration_rationale` on drift/amend re-runs, preserving the legacy discriminator.
- CR-005 (repo-root-relative paths): the template comment cites `reference/spec-flow-doctrine.md` and `reference/behavior-classification.md` by repo-root-relative path.
- CR-009 (heading hierarchy / extraction stability): the `prod-callsite` surfacing rides the existing `Independent Test` AC-form comment and the existing front-matter — no new `###` under `## Acceptance Criteria`.

- [x] **[Implement]** Surface the field + convention in the authoring path
  - Order: template front-matter field (T-1) → template AC-form comment surfacing (T-2) → spec skill emission clause (T-3).
  - Architecture constraints this phase must honor: the template is the structural guide the spec skill writes from; the skill must emit `integration_rationale` ONLY for greenfield specs and ONLY in the behavior-bearing + non-boundary case, never back-filling legacy specs (NN-C-003).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/templates/spec.md**
  - Anchor: front-matter `piece_class`/`behavior_rationale` keys (lines 10-12)
  - Current:
    ```
    10  piece_class: {{behavior-bearing|non-behavioral}}
    11  behavior_rationale: {{required only when non-behavioral}}
    12  ---
    ```
  - Target: insert `integration_rationale` between lines 11 and 12:
    ```
    piece_class: {{behavior-bearing|non-behavioral}}
    behavior_rationale: {{required only when non-behavioral}}
    integration_rationale: {{required only when behavior-bearing AND the piece declares it touches no integration boundary — see reference/behavior-classification.md}}
    ---
    ```
  - Pattern (the sibling conditional-field placeholder already at line 11):
    ```
    11  behavior_rationale: {{required only when non-behavioral}}
    ```
  - Done: the front-matter has an `integration_rationale` placeholder line with the "behavior-bearing AND non-boundary" condition and the reference-doc pointer.
  - Verify: `grep -n "integration_rationale" plugins/spec-flow/templates/spec.md` returns a front-matter match.

  **T-2: MODIFY plugins/spec-flow/templates/spec.md**
  - Anchor: the AC-form HTML comment under `## Acceptance Criteria` (lines 59-61)
  - Current:
    ```
    59  <!-- AC-line tag (exactly one): [mechanism] | [outcome:result] | [outcome:integration].
    60       Per-facet N/A sentinel form: `Outcome N/A [outcome:<facet>]: <reason>`.
    61       Tokens defined in plugins/spec-flow/reference/behavior-classification.md (CR-005). -->
    ```
  - Target: add the production-call-site convention line inside the same comment, so it reads:
    ```
    <!-- AC-line tag (exactly one): [mechanism] | [outcome:result] | [outcome:integration].
         Per-facet N/A sentinel form: `Outcome N/A [outcome:<facet>]: <reason>`.
         A declared integration's allocated AC carries a production-call-site pointer on its
         Independent Test sub-line: `Independent Test [machine: prod-callsite=<production-rooted path>; <check>]: …`
         (path NOT under a test root). See plugins/spec-flow/reference/spec-flow-doctrine.md.
         Tokens defined in plugins/spec-flow/reference/behavior-classification.md (CR-005). -->
    ```
  - Pattern (the existing single-source-of-truth citation style on line 61):
    ```
    61       Tokens defined in plugins/spec-flow/reference/behavior-classification.md (CR-005). -->
    ```
  - Done: the AC-form comment names `prod-callsite=`, the "NOT under a test root" rule, and cites `spec-flow-doctrine.md`; it remains an HTML comment (no new `###`).
  - Verify: `grep -n "prod-callsite=" plugins/spec-flow/templates/spec.md` returns a match within the AC-form comment.

  **T-3: MODIFY plugins/spec-flow/skills/spec/SKILL.md**
  - Anchor: Phase 3 "Write Spec", step 3 ("Always write `piece_class` …") at line 261
  - Current:
    ```
    261  3. **Always write `piece_class` on a new (greenfield) spec.** Resolve behavioral status from the brainstorm; an ambiguous status resolves to `behavior-bearing` and is written into the key (never left absent). Write `behavior_rationale` only when `non-behavioral`. **Do NOT back-fill `piece_class` on a drift/amend re-run** (Phase 1 step 7): a legacy spec that reached this skill without the key stays without it — the absent key is the legacy/exempt discriminator that `qa-spec` #17 and `qa-plan` #33 rely on. Tokens/enum per `reference/behavior-classification.md`.
    ```
  - Target: append a new step 3a (or a trailing sentence to step 3 — author's choice, but it MUST be a distinct instruction) instructing `integration_rationale` emission, with this content:

    > 3a. **Emit `integration_rationale` on a new (greenfield) behavior-bearing spec when the author asserts the piece touches no integration boundary** (the non-boundary exemption — see the boundary-touching predicate in `reference/behavior-classification.md`). Write `integration_rationale: <reason>` when the piece is `behavior-bearing` and declares no integration in its `## Integration Coverage` block; omit it when the piece declares ≥1 integration (the rationale is the exemption, not a default). **Do NOT back-fill `integration_rationale` on a drift/amend re-run** — same legacy-skip discipline as `piece_class`. Tokens/keys per `reference/behavior-classification.md`.

  - Pattern (step 3's greenfield-vs-drift structure this clause mirrors, line 261 above): "Always write … on a new (greenfield) spec … Do NOT back-fill … on a drift/amend re-run".
  - Done: a Phase-3 write instruction names `integration_rationale`, scopes it to greenfield behavior-bearing + non-boundary, and carries the same drift/amend back-fill exclusion.
  - Verify: `grep -n "integration_rationale" plugins/spec-flow/skills/spec/SKILL.md` returns a match inside Phase 3.


  **Per-change checks:**
  - T-1: `grep -c "integration_rationale" plugins/spec-flow/templates/spec.md` — Expected: ≥1 (front-matter)
  - T-2: `grep -c "prod-callsite=" plugins/spec-flow/templates/spec.md` — Expected: ≥1 (AC-form comment)
  - T-3: `grep -c "integration_rationale" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1 (Phase 3)
  **Phase-level check:**
  - Run (LLM-agent-step): Read `plugins/spec-flow/templates/spec.md` front-matter + AC-form comment and `plugins/spec-flow/skills/spec/SKILL.md` Phase 3, and confirm: (1) the template front-matter has `integration_rationale` with the behavior-bearing+non-boundary condition; (2) the AC-form comment surfaces `prod-callsite=` with the not-under-test-root rule; (3) the skill Phase-3 step emits `integration_rationale` for greenfield behavior-bearing non-boundary specs and excludes drift/amend back-fill.
  - Expected: all three confirmations hold.
  - Failure: the field missing from template or skill, or a back-fill instruction that would retro-mark legacy specs.

---

## Phase Group A: Gates — qa-spec, qa-plan, review-board-integration enforcement

**Exit Gate:** all three sub-phases pass their gate-eval oracles (planted-defect fixtures flagged, exemption fixture clean) + each agent's `rubric_version` bumped + each `.agent.md` symlink intact + group Deep QA clean.
**ACs Covered:** AC-2, AC-3, AC-4, AC-5

#### Sub-Phase A.1 [P]: qa-spec — pointer check (#13) + omission closure (#17)
**Scope:** plugins/spec-flow/agents/qa-spec.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-missing-pointer.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-testrooted-pointer.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-omission-no-rationale.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-omission-with-rationale.md
**ACs:** AC-2, AC-5
**Authored-tests:** plugins/spec-flow/tests/fixtures/seam-design/qaspec-missing-pointer.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-testrooted-pointer.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-omission-no-rationale.md, plugins/spec-flow/tests/fixtures/seam-design/qaspec-omission-with-rationale.md
**Charter constraints honored in this sub-phase:**
- NN-C-002 (markdown only): the checks are grep-shaped (pointer present / path under a test root / field present); no AST/caller-existence check.
- NN-C-003 (additive): #13 and #17 are extended in place; no activation-guard mutation that retro-fails legacy specs (#17 keeps its `piece_class`-absent legacy skip).
- NN-C-008 (self-contained agents): the criteria cite `reference/behavior-classification.md` (predicate) and `reference/spec-flow-doctrine.md` (pointer) by anchor; no cross-agent state.
- NN-C-009 (version bump): qa-spec `rubric_version` 2→3.
- CR-001 (agent frontmatter schema): `name` + `description` preserved; only `rubric_version` changes; the `qa-spec.agent.md` relative symlink is left intact.

- [x] **[Implement]** Extend #13 (pointer) + tighten #17 (omission) + bump rubric
  - Order: #13 pointer clause (T-1) → #17 N/A-sentinel tightening (T-2) → rubric bump (T-3).
  - Architecture constraints: #13 owns the pointer-shape clause (FR-024-A) and the boundary-touching reinforcement of its silently-deferred clause; #17 owns the omission/N/A-sentinel closure (FR-024-D). Both cite the boundary-touching predicate in `behavior-classification.md` by anchor (CR-008 — no predicate logic restated here). All checks are SHAPE checks (ADR-5), explicitly not caller-existence.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/qa-spec.md**
  - Anchor: criterion #13 "Integration allocation" (line 37)
  - Current:
    ```
    37  13. **Integration allocation:** If the spec declares any integration in its Integration Coverage block, each must (a) state its boundary (which components are inside), (b) name the true externals to be doubled (each requiring a contract test), and (c) be allocated to a specific AC. A declared integration missing any of (a)/(b)/(c), or any integration silently deferred, is must-fix. Absence of an Integration Coverage block when the piece has no cross-component wiring is NOT a finding (NFR-INT-02 — absence = 'no integrations declared').
    ```
  - Target: extend #13 in place to add clause (d) and the boundary-touching reinforcement, preserving (a)/(b)/(c) and the NFR-INT-02 absence rule verbatim. Append after "be allocated to a specific AC":
    > , and (d) carry a production-call-site pointer on that allocated AC's `Independent Test [machine:]` sub-line in the form `prod-callsite=<path>`, where `<path>` is production-rooted and does NOT resolve under a test root (`tests/`, a `*_test.*` filename, or a `*/test/*` / `*/tests/*` segment) — per `reference/spec-flow-doctrine.md`. A declared integration whose allocated AC lacks the `prod-callsite=` pointer, or whose pointer resolves under a test root, is must-fix: name the integration and the missing/test-rooted pointer. This is a SHAPE check only (presence + production-rooted + not-under-test-root); truthfulness is reconciled by `review-board-integration` (do NOT attempt caller-existence verification here — NN-C-002).
    And extend the silently-deferred sentence so it reads: "A declared integration missing any of (a)/(b)/(c)/(d), or any integration silently deferred — including a `behavior-bearing` piece that is boundary-touching (per the boundary-touching predicate in `reference/behavior-classification.md`) yet declares no integration and records no `integration_rationale` — is must-fix." Keep the final NFR-INT-02 absence sentence unchanged.
  - Pattern (the existing clause-list + reference-by-anchor style in this same criterion):
    ```
    37  ... each must (a) state its boundary ..., (b) name the true externals ..., and (c) be allocated to a specific AC. ...
    ```
  - Done: #13 has clauses (a)-(d); (d) names `prod-callsite=`, production-rooted, the test-root exclusion list, the shape-only caveat, and the boundary-touching reinforcement citing `behavior-classification.md`; the NFR-INT-02 absence sentence is intact.
  - Verify: `grep -n "prod-callsite=" plugins/spec-flow/agents/qa-spec.md` matches within #13; `grep -n "boundary-touching predicate" plugins/spec-flow/agents/qa-spec.md` matches.

  **T-2: MODIFY plugins/spec-flow/agents/qa-spec.md**
  - Anchor: criterion #17 "Outcome / negative-space coverage", the **Behavior-bearing enforcement** bullet (lines 67-71)
  - Current:
    ```
    67      - **Behavior-bearing enforcement:** `piece_class: behavior-bearing` (or an
    68        ambiguous-defaulted spec that carries the key) → for EACH facet in {`result`,
    69        `integration`}, require at least one AC whose AC-line carries `[outcome:<facet>]`
    70        OR a matching per-facet N/A sentinel. A facet with neither is must-fix: quote the
    71        missing facet and list the mechanism-only AC IDs.
    ```
  - Target: append to the Behavior-bearing enforcement bullet a tightening clause for the `integration` facet specifically:
    > **Integration-facet tightening (FR-024-D):** when the boundary-touching predicate (`reference/behavior-classification.md`) holds for this `behavior-bearing` piece, a free-text `Outcome N/A [outcome:integration]: <reason>` sentinel does NOT satisfy the integration facet, and an omitted `## Integration Coverage` block does NOT satisfy it either — the piece must carry a real `[outcome:integration]` AC (declaring the integration) OR record an `integration_rationale` front-matter value. A boundary-touching behavior-bearing piece that satisfies the integration facet only by a free-text N/A sentinel or by omission, with no `integration_rationale`, is must-fix: quote the N/A sentinel (or note the omitted block) and the missing `integration_rationale`. The predicate is judgment-backstopped — challenge a non-boundary claim you judge wrong; rationale PRESENCE (not correctness) is the deterministic clean state.
  - Pattern (the three-state, presence-is-clean structure already in #17, lines 64-66):
    ```
    64      - **Non-behavioral exemption:** `piece_class: non-behavioral` → exempt. Must-fix
    65        ONLY if `behavior_rationale` is absent (rationale *presence* is the clean state,
    66        per the criterion-15 sentinel precedent). Quote the missing key on must-fix.
    ```
  - Done: #17's behavior-bearing enforcement carries the integration-facet tightening — free-text N/A or omission is rejected when boundary-touching unless `integration_rationale` is present; the legacy skip (no `piece_class`) and non-behavioral exemption bullets are unchanged.
  - Verify: `grep -n "integration_rationale" plugins/spec-flow/agents/qa-spec.md` matches within #17; `grep -n "Integration-facet tightening" plugins/spec-flow/agents/qa-spec.md` matches.

  **T-3: MODIFY plugins/spec-flow/agents/qa-spec.md**
  - Anchor: front-matter `rubric_version` (line 4)
  - Current:
    ```
    4  rubric_version: 2
    ```
  - Target: `rubric_version: 3`
  - Done: `rubric_version: 3` in qa-spec.md front-matter; `name`/`description` unchanged (CR-001).
  - Verify: `grep -n "rubric_version: 3" plugins/spec-flow/agents/qa-spec.md` matches; `test -L plugins/spec-flow/agents/qa-spec.agent.md && readlink plugins/spec-flow/agents/qa-spec.agent.md` returns `qa-spec.md`.

- [x] **[Write-Tests]** Author the qa-spec gate-eval fixtures
  - No "fail first"; these are planted-defect / exemption fixture specs dispatched to the real qa-spec agent at Verify. Stage via `git add` (do NOT commit).
  - Build each fixture as a minimal but VALID spec (front-matter + `## Acceptance Criteria` + `## Integration Coverage`) so that ONLY the targeted defect distinguishes it. Mirror `plugins/spec-flow/tests/fixtures/outcome-acs/behaving-missing-result.md` shape.

  **Test Data:**
  - TD-A1-1 (AC-2, missing pointer): `qaspec-missing-pointer.md` — `piece_class: behavior-bearing`; declares one integration in `## Integration Coverage` (boundary + a doubled external) allocated to AC-2; AC-2 is `[outcome:integration]` but its `Independent Test [machine:]` sub-line carries NO `prod-callsite=` token. → expect qa-spec **must-fix on #13** naming the integration and the missing pointer.
  - TD-A1-2 (AC-2, test-rooted pointer): `qaspec-testrooted-pointer.md` — same as TD-A1-1 but the allocated AC's sub-line carries `prod-callsite=tests/foo_test.py:10`. → expect qa-spec **must-fix on #13** naming the integration and the test-rooted pointer.
  - TD-A1-3 (AC-5, omission no rationale): `qaspec-omission-no-rationale.md` — `piece_class: behavior-bearing`; the spec is plainly boundary-touching (its FRs wire a caller → an external HTTP service); it satisfies the integration facet ONLY with `Outcome N/A [outcome:integration]: no externals`; NO `integration_rationale` in front-matter. → expect qa-spec **must-fix on #17** (integration-facet tightening) quoting the N/A sentinel + the missing `integration_rationale`.
  - TD-A1-4 (AC-5, omission with rationale): `qaspec-omission-with-rationale.md` — identical to TD-A1-3 but front-matter adds `integration_rationale: edits a static config file; no runtime boundary crossed`. → expect qa-spec **clean on #13/#17 integration criteria** (no integration must-fix; other criteria out of scope for this AC).

- [x] **[Verify]** Run qa-spec against the fixtures; confirm verdicts; confirm rubric + symlink
  **Per-change checks:**
  - T-3 rubric: `grep -c "rubric_version: 3" plugins/spec-flow/agents/qa-spec.md` — Expected: 1
  - T-3 symlink: `test -L plugins/spec-flow/agents/qa-spec.agent.md && [ "$(readlink plugins/spec-flow/agents/qa-spec.agent.md)" = "qa-spec.md" ] && echo OK` — Expected: `OK`
  - Static convention greps: `grep -c "prod-callsite=" plugins/spec-flow/agents/qa-spec.md` — Expected: ≥1; `grep -c "Integration-facet tightening" plugins/spec-flow/agents/qa-spec.md` — Expected: 1
  **Phase-level check (gate-eval — AC-2, AC-5):**
  - Run (LLM-agent-step): dispatch the qa-spec agent prompt (`agents/qa-spec.md`, Full mode) once per fixture {TD-A1-1, TD-A1-2, TD-A1-3, TD-A1-4} with the fixture as the spec input. Grep each returned verdict.
  - Expected: TD-A1-1 → must-fix mentioning the integration + "prod-callsite"/"pointer"; TD-A1-2 → must-fix mentioning "test root"/test-rooted pointer; TD-A1-3 → must-fix on the integration facet citing the missing `integration_rationale`; TD-A1-4 → NO integration must-fix (clean on #13/#17 integration criteria).
  - Failure: any planted-defect fixture (1/2/3) returns no integration must-fix, or the exemption fixture (4) returns an integration must-fix (false positive).

- [x] **[QA-lite]** Sonnet narrow review
  - Scope: this sub-phase only (qa-spec.md + its 4 fixtures)
  - Review: #13/#17 edits preserve existing clauses verbatim (no dropped (a)/(b)/(c) or NFR-INT-02 sentence); fixtures isolate exactly one defect each; rubric bump + symlink intact; AC-2/AC-5 binding.

#### Sub-Phase A.2 [P]: qa-plan — pointer maps to a wiring phase (#26)
**Scope:** plugins/spec-flow/agents/qa-plan.md, plugins/spec-flow/tests/fixtures/seam-design/qaplan-unmapped-seam-spec.md, plugins/spec-flow/tests/fixtures/seam-design/qaplan-unmapped-seam-plan.md
**ACs:** AC-4
**Authored-tests:** plugins/spec-flow/tests/fixtures/seam-design/qaplan-unmapped-seam-spec.md, plugins/spec-flow/tests/fixtures/seam-design/qaplan-unmapped-seam-plan.md
**Charter constraints honored in this sub-phase:**
- NN-C-002 (markdown only): the check is grep-shaped (the cited `src/` path string appears in some phase's `[Build]`/`[Implement]` scope); no call-graph analysis.
- NN-C-003 (additive): #26 is extended with clause (f); its existing "spec declares an Integration Coverage block" activation guard is untouched (no retro-fail of legacy plans).
- NN-C-008 (self-contained): clause (f) cites the pointer convention in `reference/spec-flow-doctrine.md` by anchor.
- NN-C-009 (version bump): qa-plan `rubric_version` 2→3.
- CR-001 (agent frontmatter schema): `name`/`description` preserved; `qa-plan.agent.md` symlink intact.

- [x] **[Implement]** Extend #26 with the maps-to-phase clause + bump rubric
  - Order: #26 clause (f) (T-1) → rubric bump (T-2).
  - Architecture constraints: clause (f) reuses #26's existing activation guard (only when the spec declares an Integration Coverage block — NFR-INT-02); it is a SHAPE check that the cited production path appears in a phase scope, not a wiring-correctness judgment (that is review-board-integration's job — ADR-5).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/qa-plan.md**
  - Anchor: criterion #26 "Integration allocation" (line 148), clauses (a)-(e)
  - Current (clause tail, line 148):
    ```
    148  26. **Integration allocation (activate only when the spec declares an Integration Coverage block; skip if absent — not an error per NFR-INT-02):** For each declared integration: (a) ... (e) for every registry row, `registered_in_phase ≤ completes_in_phase` ... Any missing (a)/(b)/(c)/(d)/(e) → must-fix. Evidence: quote the integration and the phase block.
    ```
  - Target: add clause (f) before the "Any missing …" sentence and extend that sentence to include (f):
    > (f) each declared seam that carries a `prod-callsite=<path>` pointer (per `reference/spec-flow-doctrine.md`) maps to a phase that wires it — i.e. the cited production `<path>` string appears in the `[Build]`/`[Implement]` Change-Specification scope of the `[Integration-Test]` block's completing phase (or an earlier phase that phase depends on). A declared seam whose `prod-callsite` path appears in NO phase's `[Build]`/`[Implement]` scope is must-fix: name the unmapped seam pointer. This is a string-presence (shape) check; do not judge whether the wiring is correct (review-board-integration owns that — NN-C-002).
    Then change "Any missing (a)/(b)/(c)/(d)/(e) → must-fix" to "Any missing (a)/(b)/(c)/(d)/(e)/(f) → must-fix."
  - Pattern (the existing lettered-clause + reference-by-anchor structure in #26):
    ```
    148  ... (a) exactly one phase contains an `[Integration-Test]` block ...; (b) each doubled true external has a contract test ...; (c) the block states its boundary ...
    ```
  - Done: #26 has clauses (a)-(f); (f) names the `prod-callsite` map-to-phase-scope check + the unmapped-seam must-fix + the shape-only caveat; the activation guard is unchanged; the summary "Any missing …" sentence lists (f).
  - Verify: `grep -n "prod-callsite" plugins/spec-flow/agents/qa-plan.md` matches within #26; `grep -n "(a)/(b)/(c)/(d)/(e)/(f)" plugins/spec-flow/agents/qa-plan.md` matches.

  **T-2: MODIFY plugins/spec-flow/agents/qa-plan.md**
  - Anchor: front-matter `rubric_version` (line 4)
  - Current:
    ```
    4  rubric_version: 2
    ```
  - Target: `rubric_version: 3`
  - Done: `rubric_version: 3`; `name`/`description` unchanged.
  - Verify: `grep -n "rubric_version: 3" plugins/spec-flow/agents/qa-plan.md` matches; `readlink plugins/spec-flow/agents/qa-plan.agent.md` returns `qa-plan.md`.

- [x] **[Write-Tests]** Author the qa-plan gate-eval fixture pair (spec + plan)
  - qa-plan receives the spec + the plan; the cross-check is spec-pointer vs plan-phase-scope. Stage via `git add` (do NOT commit).

  **Test Data:**
  - TD-A2-1 (AC-4, unmapped seam): `qaplan-unmapped-seam-spec.md` declares one integration whose allocated AC carries `prod-callsite=src/ingest/http_client.py:88`; `qaplan-unmapped-seam-plan.md` is a well-formed plan whose phases' `[Build]`/`[Implement]` Change-Specification scopes reference only OTHER files (e.g. `src/ingest/parser.py`) — the cited `src/ingest/http_client.py` path appears in NO phase scope. → expect qa-plan **must-fix on #26 clause (f)** naming the unmapped seam pointer `src/ingest/http_client.py`.

- [x] **[Verify]** Run qa-plan against the fixture; confirm verdict; confirm rubric + symlink
  **Per-change checks:**
  - T-2 rubric: `grep -c "rubric_version: 3" plugins/spec-flow/agents/qa-plan.md` — Expected: 1
  - T-2 symlink: `test -L plugins/spec-flow/agents/qa-plan.agent.md && [ "$(readlink plugins/spec-flow/agents/qa-plan.agent.md)" = "qa-plan.md" ] && echo OK` — Expected: `OK`
  - Static grep: `grep -c "prod-callsite" plugins/spec-flow/agents/qa-plan.md` — Expected: ≥1
  **Phase-level check (gate-eval — AC-4):**
  - Run (LLM-agent-step): dispatch the qa-plan agent prompt (`agents/qa-plan.md`, Full mode) with `qaplan-unmapped-seam-spec.md` as the spec and `qaplan-unmapped-seam-plan.md` as the plan. Grep the returned verdict.
  - Expected: must-fix on #26 mentioning the unmapped seam pointer / `src/ingest/http_client.py` / "no phase".
  - Failure: no must-fix on the unmapped seam, or a must-fix on an unrelated criterion masking it.

- [x] **[QA-lite]** Sonnet narrow review
  - Scope: this sub-phase only (qa-plan.md + the fixture pair)
  - Review: #26 clauses (a)-(e) preserved verbatim; activation guard untouched; (f) is shape-only; rubric + symlink intact; AC-4 binding.

#### Sub-Phase A.3 [P]: review-board-integration — pointer reconciliation against the wired-path inventory
**Scope:** plugins/spec-flow/agents/review-board-integration.md, plugins/spec-flow/tests/fixtures/seam-design/rbi-unwired-pointer-spec.md, plugins/spec-flow/tests/fixtures/seam-design/rbi-unwired-pointer-diff.patch
**ACs:** AC-3
**Authored-tests:** plugins/spec-flow/tests/fixtures/seam-design/rbi-unwired-pointer-spec.md, plugins/spec-flow/tests/fixtures/seam-design/rbi-unwired-pointer-diff.patch
**Charter constraints honored in this sub-phase:**
- NN-C-002 (markdown only): the reconciliation reuses the agent's existing diff-derived inventory (string comparison of the cited path against inventory paths); no AST/call-graph tooling added.
- NN-C-003 (additive): the reconciliation folds into the existing Step 1 inventory + coverage axis — the "two axes" / probe counts are NOT changed (no superseded-ordinal drift).
- NN-C-008 (self-contained): the cited `prod-callsite` convention is referenced from `reference/spec-flow-doctrine.md` by anchor.
- NN-C-009 (version bump): review-board-integration `rubric_version` 1→2.
- CR-001 (agent frontmatter schema): `name`/`description`/`model` preserved; only `rubric_version` changes; `review-board-integration.agent.md` symlink intact.

- [x] **[Implement]** Add the spec-pointer reconciliation to Step 1 + coverage axis; bump rubric
  - Order: Step 1 reconciliation sub-step (T-1) → rubric bump (T-2).
  - Architecture constraints: fold the reconciliation into the EXISTING Step 1 inventory + coverage probe — do NOT add a third axis or renumber the 7 boundary probes / the coverage probe (avoids superseded-ordinal drift; keeps the "two-axis verdict" contract intact). The reconciliation reuses the diff-derived inventory the agent already builds (ADR-5 / VOQ-1 option b).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/agents/review-board-integration.md**
  - Anchor: end of `### Step 1 — Enumerate every integration path first` (the inventory fenced block + its trailing sentence, lines 44-52)
  - Current:
    ```
    44  ```
    45  Integration Path Inventory
    46  --------------------------
    47  Path P1: <caller> → <component-A> → <component-B> [boundary: ...]
    48  Path P2: <caller> → <component-C> → <external-X> (doubled as <fake-Y>) [boundary: ...]
    49  ...
    50  ```
    51
    52  Include the boundary label ... Do not begin probing until this inventory is complete. **Every subsequent probe is applied per path in this inventory.**
    ```
  - Target: add a new paragraph immediately after line 52 (still inside Step 1, before `### Step 2`):
    > **Spec-pointer reconciliation (FR-024-B).** After the inventory is complete, read the spec's declared integrations and extract every `prod-callsite=<path>` pointer (the production-call-site convention, `reference/spec-flow-doctrine.md`). For each cited `<path>`, check whether it appears on any wired path in the inventory above (the inventory is derived from the diff, not from the author's pointer — so this confronts the author's claim with the independently-derived reality). A cited `prod-callsite` path that does NOT appear on any wired path in the inventory is **must-fix**: emit the finding **"cited production call site not exercised by any wired path"**, naming the integration and the cited `<path>`. This is the shift-left reconciliation: the construction gates (qa-spec, qa-plan) shape-checked the pointer; this is the only gate that confronts it with real wiring. Record this reconciliation result on the affected path's **Path-coverage verdict** (a cited-but-unwired pointer forces at most `UNIT-ONLY`/`UNCOVERED`, never `COVERED`, for that path).
  - Pattern (the existing finding-string + per-path discipline already in this agent, lines 83-84 coverage probe):
    ```
    83  8. **Coverage probe — is the wired path exercised by an `[integration]`-tagged test?**
    84     For each path in the inventory, is there at least one test tagged `[integration]` ...
    ```
  - Done: a `**Spec-pointer reconciliation (FR-024-B).**` paragraph exists at the end of Step 1; it extracts `prod-callsite=` pointers, confronts each against the diff-derived inventory, and emits the exact must-fix string "cited production call site not exercised by any wired path"; the two-axis verdict contract and the 7+1 probe counts are unchanged.
  - Verify: `grep -n "cited production call site not exercised by any wired path" plugins/spec-flow/agents/review-board-integration.md` matches; `grep -n "prod-callsite" plugins/spec-flow/agents/review-board-integration.md` matches; `grep -c "three-axis\|Axis 3" plugins/spec-flow/agents/review-board-integration.md` returns 0 (no new axis introduced).

  **T-2: MODIFY plugins/spec-flow/agents/review-board-integration.md**
  - Anchor: front-matter `rubric_version` (line 5)
  - Current:
    ```
    5  rubric_version: 1
    ```
  - Target: `rubric_version: 2`
  - Done: `rubric_version: 2`; `name`/`description`/`model: opus` unchanged.
  - Verify: `grep -n "rubric_version: 2" plugins/spec-flow/agents/review-board-integration.md` matches; `readlink plugins/spec-flow/agents/review-board-integration.agent.md` returns `review-board-integration.md`.

- [x] **[Write-Tests]** Author the review-board-integration gate-eval fixture (spec + diff)
  - review-board-integration receives a diff + spec. Stage via `git add` (do NOT commit). The diff fixture is a `.patch`-style unified diff the agent reads as the piece diff.

  **Test Data:**
  - TD-A3-1 (AC-3, unwired pointer): `rbi-unwired-pointer-spec.md` declares one integration whose allocated AC cites `prod-callsite=src/report/exporter.py:42`. `rbi-unwired-pointer-diff.patch` is a unified diff whose wired paths (caller → component chains the agent can trace) involve ONLY `src/report/formatter.py` and its tests — `src/report/exporter.py` is never wired into any path in the diff (the FO-16 zero-production-caller case). → expect review-board-integration **must-fix** with the string "cited production call site not exercised by any wired path" naming `src/report/exporter.py`.

- [x] **[Verify]** Run review-board-integration against the fixture; confirm verdict; confirm rubric + symlink
  **Per-change checks:**
  - T-2 rubric: `grep -c "rubric_version: 2" plugins/spec-flow/agents/review-board-integration.md` — Expected: 1
  - T-2 symlink: `test -L plugins/spec-flow/agents/review-board-integration.agent.md && [ "$(readlink plugins/spec-flow/agents/review-board-integration.agent.md)" = "review-board-integration.md" ] && echo OK` — Expected: `OK`
  - Static grep (exact finding string): `grep -c "cited production call site not exercised by any wired path" plugins/spec-flow/agents/review-board-integration.md` — Expected: 1
  - No-new-axis guard: `grep -c "Axis 3\|three-axis" plugins/spec-flow/agents/review-board-integration.md` — Expected: 0
  **Phase-level check (gate-eval — AC-3):**
  - Run (LLM-agent-step): dispatch the review-board-integration agent prompt (`agents/review-board-integration.md`, Full mode) with `rbi-unwired-pointer-diff.patch` as the diff and `rbi-unwired-pointer-spec.md` as the spec. Grep the returned verdict.
  - Expected: must-fix containing "cited production call site not exercised by any wired path" and naming `src/report/exporter.py`.
  - Failure: no such must-fix, or the agent marks the cited path's path-coverage `COVERED`.

- [x] **[QA-lite]** Sonnet narrow review
  - Scope: this sub-phase only (review-board-integration.md + the spec/diff fixture)
  - Review: reconciliation folded into Step 1 without adding an axis or renumbering probes; exact finding string present; rubric + symlink intact; AC-3 binding.

#### Group-level tasks
- [x] **[Refactor]** (optional — auto-skipped when all sub-phase Implements clean)
  - Scope: union of the three agent files (no cross-file dedup expected — disjoint criteria)
  - Constraint: only files changed in this group
- [x] **[QA]** Opus deep review
  - Review against: group ACs (AC-2, AC-3, AC-4, AC-5)
  - Diff baseline: git diff <group_start_sha>..HEAD
  - Focus: each gate's extension preserves its existing criteria verbatim (no dropped clauses, no mutated activation guard); each `rubric_version` bumped exactly once; all three `.agent.md` symlinks intact; the `prod-callsite=` token is spelled identically across qa-spec / qa-plan / review-board-integration (cross-phase schema consistency — confirmed in Phase 4).
- [x] **[Progress]** Single deferred commit for the group

---

### Phase 4: Cross-gate controls (no retro-fail / no false-positive) + cross-phase token consistency + release

**Exit Gate:** all three gates return ZERO new findings on the legacy fixture and the clean-correct fixture (AC-7); the `prod-callsite=` and `integration_rationale` tokens are spelled identically across all touching files (cross-phase schema consistency); the version triad is bumped to 5.20.0 with a CHANGELOG entry.
**ACs Covered:** AC-7
**In scope:** author the legacy + clean-correct control fixtures (spec/plan/diff); run all three gates against them; cross-phase token-consistency verification; version triad bump (plugin.json, root marketplace.json, CHANGELOG.md)
**NOT in scope:** any gate-prompt logic change (Phase Group A, done); any definition/template/skill change (Phases 1-2, done)
**Charter constraints honored in this phase:**
- NN-C-003 (backward compatibility): the legacy fixture (no `piece_class`) proves no retro-fail; the clean-correct fixture proves no false-positive on a correct boundary-touching spec.
- NN-C-009 (version bump, all version-bearing files): plugin.json + root marketplace.json + CHANGELOG bumped together (MINOR — additive).
- CR-005 (repo-root-relative paths): fixtures and CHANGELOG reference repo-root-relative paths.

- [x] **[Implement]** Bump the version triad + author the CHANGELOG entry
  - Order: plugin.json (T-1) → root marketplace.json (T-2) → CHANGELOG (T-3). (Control fixtures are authored in [Write-Tests] below.)
  - Architecture constraints: MINOR bump 5.19.0 → 5.20.0 (additive — NN-C-009); all three version-bearing files move together.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/.claude-plugin/plugin.json**
  - Anchor: `"version"` (line 4)
  - Current:
    ```
    4  "version": "5.19.0",
    ```
  - Target: `"version": "5.20.0",`
  - Done: plugin.json version is `5.20.0`.
  - Verify: `grep -c '"version": "5.20.0"' plugins/spec-flow/.claude-plugin/plugin.json` — Expected: 1.

  **T-2: MODIFY .claude-plugin/marketplace.json** (repo-root marketplace manifest; the spec-flow entry)
  - Anchor: the spec-flow plugin object's `"version"` (line 15)
  - Current:
    ```
    15  "version": "5.19.0",
    ```
  - Target: `"version": "5.20.0",`
  - Done: the spec-flow entry in the root marketplace.json is `5.20.0`.
  - Verify: LLM-agent-step — Read `.claude-plugin/marketplace.json` and confirm the object whose `"name": "spec-flow"` has `"version": "5.20.0"` (NOT the qa entry at version 1.1.1). Expected: spec-flow version is 5.20.0.

  **T-3: MODIFY plugins/spec-flow/CHANGELOG.md**
  - Anchor: between `## [Unreleased]` (line 5) and `## [5.19.0] — 2026-06-13` (line 7)
  - Current:
    ```
    5  ## [Unreleased]
    6
    7  ## [5.19.0] — 2026-06-13
    ```
  - Target: insert a new release section under `## [Unreleased]`:
    ```
    ## [Unreleased]

    ## [5.20.0] — 2026-06-13

    ### Added
    - **Production-call-site obligation (FR-024-A/B/C).** A declared integration's allocated
      AC now carries a `prod-callsite=<path>` pointer on its `Independent Test [machine:]`
      sub-line (production-rooted, not under a test root). Defined in
      `reference/spec-flow-doctrine.md`; surfaced in `templates/spec.md`. Shape-checked at
      qa-spec (#13) and qa-plan (#26); reconciled against the diff-derived wired-path
      inventory at `review-board-integration` (new must-fix "cited production call site not
      exercised by any wired path"). Closes integration failure class 3 (untested-unused seam)
      at spec/plan time.
    - **Silent-omission closure (FR-024-D).** A behavior-bearing, boundary-touching spec can
      no longer pass by omitting `## Integration Coverage` or free-text-N/A-ing the
      `[outcome:integration]` facet — qa-spec #17 now rejects that unless an
      `integration_rationale` front-matter exemption is recorded.
    - **Boundary-touching predicate (FR-024-E).** Three-state, judgment-backstopped predicate
      added to `reference/behavior-classification.md`; `integration_rationale` front-matter
      key emitted by `templates/spec.md` + `skills/spec/SKILL.md` for new specs.
    - Agent `rubric_version` bumps: qa-spec 2→3, qa-plan 2→3, review-board-integration 1→2.

    ## [5.19.0] — 2026-06-13
    ```
  - Pattern (the existing Keep-a-Changelog release entry, lines 7-9):
    ```
    7  ## [5.19.0] — 2026-06-13
    8
    9  ### Changed
    ```
  - Done: a `## [5.20.0] — 2026-06-13` section with an `### Added` list exists under `## [Unreleased]`, above the 5.19.0 entry.
  - Verify: `grep -c "## \[5.20.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1.

- [x] **[Write-Tests]** Author the control fixtures (legacy + clean-correct) for all three gates
  - Stage via `git add` (do NOT commit). These prove no-retro-fail (legacy) and no-false-positive (clean-correct) across qa-spec, qa-plan, review-board-integration.

  **Test Data:**
  - TD-4-1 (AC-7, legacy): `plugins/spec-flow/tests/fixtures/seam-design/legacy-no-piececlass-spec.md` — a spec with NO `piece_class` front-matter and no integration declarations (mirrors `plugins/spec-flow/tests/fixtures/outcome-acs/legacy-no-piececlass.md`). → expect qa-spec: NO new must-fix (every new check legacy-skips on `piece_class` absence). For qa-plan/review-board the legacy case carries no `prod-callsite` pointer → the new clauses are inert.
  - TD-4-2 (AC-7, clean-correct spec): `plugins/spec-flow/tests/fixtures/seam-design/clean-correct-spec.md` — `piece_class: behavior-bearing`; declares one integration in `## Integration Coverage` (boundary + a doubled external with a contract test) allocated to an `[outcome:integration]` AC whose `Independent Test [machine:]` sub-line carries a valid `prod-callsite=src/report/exporter.py:42` (production-rooted, not test-rooted). → expect qa-spec: NO new must-fix (pointer present + production-rooted; integration facet covered).
  - TD-4-3 (AC-7, clean-correct plan): `plugins/spec-flow/tests/fixtures/seam-design/clean-correct-plan.md` — a plan for TD-4-2 whose `[Integration-Test]` completing phase's `[Build]`/`[Implement]` scope includes `src/report/exporter.py` (the cited pointer maps to a phase). → expect qa-plan: NO new #26 (f) must-fix.
  - TD-4-4 (AC-7, clean-correct diff): `plugins/spec-flow/tests/fixtures/seam-design/clean-correct-diff.patch` — a unified diff for TD-4-2 in which `src/report/exporter.py` IS wired into a traced path (caller → exporter → external). → expect review-board-integration: NO "cited production call site not exercised" must-fix (the cited pointer appears in the inventory).

- [x] **[Verify]** Cross-gate no-false-positive/no-retro-fail + cross-phase token consistency + release sanity
  **Per-change checks:**
  - T-1: `grep -c '"version": "5.20.0"' plugins/spec-flow/.claude-plugin/plugin.json` — Expected: 1
  - T-2: LLM-agent-step — Read `.claude-plugin/marketplace.json`; confirm the `spec-flow` object's version is `5.20.0`. Expected: 5.20.0.
  - T-3: `grep -c "## \[5.20.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1
  **Cross-phase schema-consistency check (FR-PROC-01 — the `prod-callsite=` / `integration_rationale` token contract spans Phases 1, 2, A):**
  - Run: `grep -rl "prod-callsite=" plugins/spec-flow/reference/spec-flow-doctrine.md plugins/spec-flow/templates/spec.md plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/agents/qa-plan.md plugins/spec-flow/agents/review-board-integration.md` — Expected: all 5 files listed (the token is spelled identically — literal `prod-callsite=` — in every producer and consumer).
  - Run: `grep -rl "integration_rationale" plugins/spec-flow/reference/behavior-classification.md plugins/spec-flow/templates/spec.md plugins/spec-flow/skills/spec/SKILL.md plugins/spec-flow/agents/qa-spec.md` — Expected: all 4 files listed (the key is spelled identically in its definition, template, skill emitter, and gate consumer).
  - Run (no-stray-token): `grep -rn "prod_callsite\|prodcallsite\|prod-call-site=" plugins/spec-flow/` — Expected: 0 matches (no drifted spelling variant).
  **Phase-level check (gate-eval — AC-7):**
  - Run (LLM-agent-step): dispatch qa-spec against {TD-4-1, TD-4-2}; qa-plan against {TD-4-1, TD-4-3}; review-board-integration against {TD-4-4 (+ TD-4-2 spec)}. Grep each verdict for ABSENCE of the new must-fix strings ("prod-callsite", "cited production call site not exercised", "integration_rationale" must-fix).
  - Expected: ZERO new findings on the legacy fixture (no retro-fail) and ZERO new findings on the clean-correct fixtures (no false positive) across all three gates.
  - Failure: ANY new must-fix on the legacy fixture (retro-fail) or the clean-correct fixtures (false positive).

- [x] **[QA]** Phase review
  - Review against: AC-7
  - Diff baseline: git diff <phase_start_sha>..HEAD

---

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | `prod-callsite` pointer convention defined in doctrine + surfaced in spec template; not-under-test-root rule documented | COVERED | Phase 1 (doctrine), Phase 2 (template) |
| AC-2 | qa-spec must-fix when a declared integration's allocated AC lacks the pointer or it is test-rooted | COVERED | Sub-Phase A.1 |
| AC-3 | review-board-integration must-fix when a cited `prod-callsite` is absent from the wired-path inventory; `rubric_version` bumped | COVERED | Sub-Phase A.3 |
| AC-4 | qa-plan must-fix when a declared seam's `prod-callsite` maps to no phase scope | COVERED | Sub-Phase A.2 |
| AC-5 | qa-spec must-fix on boundary-touching omission/N/A without `integration_rationale`; clean with it | COVERED | Sub-Phase A.1 |
| AC-6 | three-state boundary-touching predicate + judgment-backstopped caveat in behavior-classification; template + skill emit `integration_rationale` | COVERED | Phase 1 (predicate), Phase 2 (template + skill) |
| AC-7 | no retro-fail of legacy spec + no false-positive on clean-correct spec, across all three gates | COVERED | Phase 4 |

All ACs COVERED — no NOT COVERED rows, no forward pointers required.

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `grep -c "prod-callsite=" plugins/spec-flow/reference/spec-flow-doctrine.md plugins/spec-flow/templates/spec.md` | each file ≥1; doctrine also matches `grep -c "MUST NOT resolve under a test root" …` = 1 |
| AC-2 | agent-step | Dispatch qa-spec (Full) against `qaspec-missing-pointer.md` and `qaspec-testrooted-pointer.md`; grep verdicts | both → must-fix on #13 (missing pointer; test-rooted pointer) |
| AC-3 | agent-step + shell | Dispatch review-board-integration (Full) against `rbi-unwired-pointer-diff.patch` + `rbi-unwired-pointer-spec.md`; grep verdict; `grep -c "rubric_version: 2" plugins/spec-flow/agents/review-board-integration.md` | must-fix "cited production call site not exercised by any wired path"; rubric_version = 2 |
| AC-4 | agent-step | Dispatch qa-plan (Full) against `qaplan-unmapped-seam-spec.md` + `qaplan-unmapped-seam-plan.md`; grep verdict | must-fix on #26 (f) naming the unmapped seam pointer |
| AC-5 | agent-step | Dispatch qa-spec (Full) against `qaspec-omission-no-rationale.md` (i) and `qaspec-omission-with-rationale.md` (ii); grep verdicts | (i) must-fix on #17 integration facet; (ii) clean on #13/#17 integration criteria |
| AC-6 | shell | `grep -c "## Boundary-touching predicate" …/behavior-classification.md` and `grep -c "judgment-backstopped" …/behavior-classification.md` and `grep -c "integration_rationale" …/templates/spec.md …/skills/spec/SKILL.md` | predicate section = 1; caveat ≥1; `integration_rationale` present in template and skill |
| AC-7 | agent-step | Dispatch all three gates against the legacy + clean-correct fixtures; grep verdicts for absence of the new must-fix strings | zero new findings on both |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs. (The boundary-crossing "interfaces" of this piece are documentation token conventions — `prod-callsite=`, `integration_rationale`, the boundary-touching predicate — whose cross-phase consistency is enforced by the Phase 4 cross-phase schema-consistency `[Verify]` step, not by a runtime contract.)

## Parallel Execution Notes

- **Phase Group A** dispatches three `[P]` sub-phases concurrently — qa-spec, qa-plan, and review-board-integration are disjoint agent files, and each sub-phase's fixtures live at disjoint `plugins/spec-flow/tests/fixtures/seam-design/` paths (verified disjoint by the Scope lists). No shared coordination file is appended by ≥2 sub-phases, so no Phase 0 Scaffold is needed.
- Phases 1 → 2 → Group A → 4 are serial by dependency: Group A's gates cite Phase 1's definitions by anchor; Phase 2's authoring surface depends on Phase 1's definitions; Phase 4's cross-gate controls require all three gates (Group A) to be in place. Phase 2 (authoring surface) and Phase Group A (gates) both depend only on Phase 1 and are mutually disjoint, but are sequenced serially for review-board readability — the wall-clock cost is one small flat phase.

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan `[Implement]` Change Specifications, spec ACs, plan's `[Verify]` command, arch constraints, pattern blocks, `introspection.md` (Dependency Map + Pattern Catalog for phase scope) | Spec rationale, brainstorming history |
| Write-Tests (fixtures) | The phase's Test Data block (fixture id + content + expected verdict), fixture path conventions, the `outcome-acs` fixture pattern | Implementation reasoning, other sub-phases' fixtures |
| Verify | The `[Verify]` block's per-change + phase-level commands, gate-eval dispatch instructions, spec ACs | Implementation reasoning |
| QA-lite (sub-phase) | `Mode:` flag, sub-phase diff, sub-phase ACs, sub-phase scope block | Full piece spec, other sub-phases' diffs |
| QA (group / phase) | Phase/group diff, spec, plan, PRD sections | Any agent conversation history |
