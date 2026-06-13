---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
piece_class: behavior-bearing
integration_rationale: edits gate prompts/docs only; no runtime boundary
---

# Spec: seam-design

**PRD Sections:** FR-024 (reserved — this piece adds it to the exec-ready PRD at merge, per the FR-009/spec-preresearch precedent), G-1, G-7
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** plan-concrete (merged), outcome-acs (merged)

## Goal

Close the spec-time and review-time gaps that let an integration seam ship without **verified production wiring**. Two mechanisms, both additive to the already-shipped integration machinery (doctrine §"Integration Tests & Path Coverage", the `## Integration Coverage` block, plan B-lite + `## Integration-Test Registry`, qa-spec #13, qa-plan #26, the `review-board-integration` agent):

- **A — Production-call-site obligation + 3-place reconciliation.** A declared seam's allocated AC must cite a real `src/` (non-`tests/`) production call-path pointer, and that pointer is reconciled at three gates (qa-spec construction, qa-plan plan-time, review-board-integration review-time). This kills the FO-16 smoking gun: a seam fully unit-tested with **zero production callers** that satisfied every gate because its AC referenced wiring in tests.
- **B — Silent-omission closure.** A behavior-bearing, boundary-touching spec can no longer pass gates by simply *omitting* the `## Integration Coverage` block or N/A-ing the `[outcome:integration]` facet with free text. It must either declare its integrations or record a non-boundary exemption rationale.

This piece closes seam failure-class **3 (untested-unused seam)** at spec time. Honest scope: failure-classes 1 (mock-avalanche), 2 (cross-phase composition), 4 (post-merge conflict), and 5 (spec↔impl contract drift) remain owned by the shipped `review-board-integration` axis + plan registry and are **not** claimed here.

## In Scope

- A production-call-site pointer convention on a seam AC's `Independent Test` sub-line (`[machine: prod-callsite=<src/ path>]`), defined once in `reference/spec-flow-doctrine.md` and surfaced in `templates/spec.md`.
- A deterministic qa-spec check: a declared integration's allocated AC must carry the pointer; the cited path must not resolve under a test root.
- An extension to the `review-board-integration` agent: reconcile each spec-cited `src/` pointer against its diff-derived wired-path inventory; a cited production call site absent from the inventory is must-fix (`rubric_version` bump).
- A qa-plan check: each declared seam's production-call-site pointer maps to an `[integration]` phase that wires it.
- Silent-omission closure: tighten qa-spec's `[outcome:integration]` N/A sentinel + extend the #13 silently-deferred clause with a boundary-touching predicate; a non-boundary exemption rationale recorded in spec front-matter.
- A boundary-touching three-state predicate defined in `reference/behavior-classification.md`; spec template + spec skill always emit `piece_class` and the exemption field for new specs.

## Out of Scope / Non-Goals

- **Forcing up-front integration *discovery*** (investigation-backed surfacing of seams the author didn't think to declare) — split to the `seam-investigate` piece.
- **The `--converge` after-the-fact backstop loop** — split to the `review-board-converge` piece.
- **Verifying a production caller actually *exists*** at construction time — intractable bash-only (needs AST/call-graph tooling, violates NN-C-002). The construction gate checks pointer *shape* only; truthfulness (does the cited site really wire the seam) is reconciled by `review-board-integration` against its independently-derived path inventory.
- Re-opening true double-loop ordering, the SHA-256 anti-cheat gate, fast mode, or reintroducing a `[seam]` tag (shipped work uses `[integration]`).
- Retro-failing legacy specs (NN-C-003) — see NFR-1.

## Requirements

### Functional Requirements

- **FR-024-A (production-call-site pointer):** The seam-AC pointer convention is defined in doctrine and the spec template: a declared integration's allocated AC carries `[machine: prod-callsite=<src-rooted path>]` on its `Independent Test` sub-line. qa-spec raises must-fix when a declared integration's allocated AC lacks the pointer, or the cited path resolves under a test root (e.g. `tests/`, `*_test.*`, `*/test/*`).
- **FR-024-B (review-time reconciliation):** `review-board-integration` is extended to cross-check each spec-cited `prod-callsite=<path>` against the wired-path inventory it derives from the diff (Step 1). A cited production call site that does not appear in that inventory is a must-fix ("cited production call site not exercised by any wired path"). Carries a `rubric_version` bump.
- **FR-024-C (plan-time reconciliation):** qa-plan verifies that each declared seam's `prod-callsite` pointer maps to a phase that wires it — i.e., the cited `src/` path appears in the `[Build]`/`[Implement]` scope of the `[Integration-Test]` block's completing phase (or an earlier phase it depends on). A declared seam whose pointer maps to no phase is must-fix.
- **FR-024-D (silent-omission closure):** A behavior-bearing, boundary-touching spec is must-fix at qa-spec when it (a) omits the `## Integration Coverage` block entirely, or (b) records `Outcome N/A [outcome:integration]: <free text>` while the boundary-touching predicate holds — UNLESS it records a non-boundary exemption rationale in front-matter (`integration_rationale`). This tightens qa-spec's existing `[outcome:integration]` sentinel acceptance (criterion #17) and extends the #13 silently-deferred clause; it does NOT mutate qa-plan #26's activation guard (that would retro-fail legacy plans).
- **FR-024-E (predicate + authoring path):** A three-state boundary-touching predicate is defined in `reference/behavior-classification.md` (behavior-bearing + boundary-touching → declare integrations OR record `integration_rationale`; declared non-boundary → exempt-with-rationale; ambiguous → boundary-touching). The predicate is **judgment-backstopped** — the deterministic gate cannot decide "touches a boundary"; qa-spec judgment challenges a wrong non-boundary claim. The spec template + spec skill always emit `piece_class` and the `integration_rationale` field for new specs.

### Non-Functional Requirements

- **NFR-1 (additive / backward-compat — NN-C-003):** A legacy spec that carries no `piece_class` (and therefore no `integration_rationale`) is skipped by every new check — never retro-failed. Field-absence is the legacy discriminator, exactly as criterion #17 already treats `piece_class`.
- **NFR-2 (determinism):** The qa-spec (FR-024-A) and qa-plan (FR-024-C) checks are deterministic and greppable (pointer present; path under/not-under a test root; path present in a phase scope) — no semantic adjudication at construction time. Only the review-time reconciliation (FR-024-B) and the boundary-touching predicate (FR-024-E) are judgment-backstopped, and each is explicitly labeled as such.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (markdown + config only, no runtime deps): every change is markdown — doctrine, agent prompts, skill prose, template, reference doc. The production-caller-existence check is explicitly rejected because it would require AST/graph tooling (a runtime dependency); the gate is grep-shaped instead.
- NN-C-003 (backward compatibility within a major version): all checks are additive and legacy-skip by field-absence (NFR-1). No existing criterion's activation guard is mutated; qa-plan #26 is left intact precisely to avoid retro-failing legacy plans.
- NN-C-008 (self-contained agents — no conversation-history assumption): the boundary-touching predicate and the pointer convention are defined in `behavior-classification.md` / doctrine and cited by anchor; qa-spec, qa-plan, and review-board-integration read them from the cited docs, carrying no cross-agent state.
- NN-C-009 (bump version, all version-bearing files): editing the `review-board-integration` agent bumps its `rubric_version`; the release bumps the plugin version triad.

### Coding Rules Honored

- CR-001 (agent frontmatter schema): the `review-board-integration` edit preserves `name` + `description` and bumps `rubric_version` in frontmatter; the relative `.agent.md` symlink is preserved.
- CR-005 (repo-root-relative paths in documentation): doctrine/template references to the pointer convention and predicate use repo-root-relative paths (e.g. `plugins/spec-flow/reference/spec-flow-doctrine.md`), never cwd-dependent `../` or user-home absolute paths.
- CR-008 (separation of concerns — thin orchestrator, narrow executor): no gate logic is placed in `behavior-classification.md`; it owns only the predicate/token definition that the qa-spec criterion references.
- CR-009 (markdown heading hierarchy / extraction stability): the pointer rides the existing `Independent Test` sub-line and the existing `## Integration Coverage` block — no new `###` under `## Acceptance Criteria` that would collide with section-extraction anchors.

## Acceptance Criteria

AC-1: Given the doctrine and spec template, When the pointer convention is defined, Then a declared integration's allocated AC carries `[machine: prod-callsite=<src-rooted path>]` on its `Independent Test` sub-line, and the convention (and its not-under-`tests/` rule) is documented once in `reference/spec-flow-doctrine.md`. [mechanism]
  Independent Test [machine: grep `reference/spec-flow-doctrine.md` and `templates/spec.md` for the `prod-callsite=` convention and the test-root exclusion rule]: both files contain the convention; the doctrine states the not-under-test-root rule.

AC-2: Given a spec that declares an integration whose allocated AC has no `prod-callsite` pointer (or a pointer resolving under a test root), When qa-spec reviews it, Then qa-spec raises a must-fix naming the integration and the missing/test-rooted pointer. [outcome:result]
  Independent Test [machine: run qa-spec against two planted-defect fixture specs (missing pointer; `tests/`-rooted pointer); grep the verdict for a must-fix on each]: both produce a must-fix.

AC-3: Given a diff in which a spec-cited `prod-callsite` path is absent from review-board-integration's diff-derived wired-path inventory, When the integration reviewer runs, Then it raises a must-fix ("cited production call site not exercised by any wired path"), and its `rubric_version` is bumped. [outcome:result]
  Independent Test [machine: run the extended review-board-integration prompt against a fixture diff whose cited `src/` pointer is not in any wired path; grep the verdict for the must-fix; grep the agent frontmatter for the incremented `rubric_version`]: must-fix present; rubric_version incremented.

AC-4: Given a plan in which a declared seam's `prod-callsite` pointer maps to no `[integration]` phase scope, When qa-plan reviews it, Then qa-plan raises a must-fix naming the unmapped seam pointer. [outcome:result]
  Independent Test [machine: run qa-plan against a planted-defect fixture plan whose declared seam pointer appears in no phase `[Build]`/`[Implement]` scope; grep the verdict for the must-fix]: must-fix present.

AC-5: Given a behavior-bearing, boundary-touching spec that omits the `## Integration Coverage` block (or N/A's `[outcome:integration]` with free text) AND records no `integration_rationale`, When qa-spec reviews it, Then qa-spec raises a must-fix; given the same spec with a recorded non-boundary `integration_rationale`, qa-spec does NOT raise that finding. [outcome:result]
  Independent Test [machine: run qa-spec against (i) a boundary-touching fixture omitting the block with no rationale and (ii) the same fixture with `integration_rationale` set; grep verdicts]: (i) must-fix; (ii) clean on this criterion.

AC-6: Given `reference/behavior-classification.md`, the spec template, and the spec skill, When this piece lands, Then the three-state boundary-touching predicate is defined in `behavior-classification.md` (with the judgment-backstopped caveat stated), and the template + skill emit `piece_class` and `integration_rationale` for new specs. [mechanism]
  Independent Test [machine: grep `behavior-classification.md` for the three-state predicate + the "judgment-backstopped" caveat; grep `templates/spec.md` front-matter and `skills/spec/SKILL.md` Phase-3 write step for `integration_rationale`]: predicate + caveat present; field emitted in template and skill.

AC-7: Given (a) a legacy spec carrying no `piece_class`/`integration_rationale`, and (b) a clean boundary-touching spec that properly declares its integrations and cites a real `src/` pointer, When qa-spec, qa-plan, and review-board-integration run, Then NONE of the new checks raise a finding on either spec (no retro-fail of legacy; no false positive on a correct spec). [outcome:result]
  Independent Test [machine: run all three gates against the legacy fixture and the clean-correct fixture; grep verdicts for absence of the new must-fix strings]: zero new findings on both.

Outcome N/A [outcome:integration]: this piece edits markdown gate prompts, templates, doctrine, and a reference doc; it has no runtime cross-component wiring of its own. Its "integration" surface is documentation/gate prose, not a wired code path — so it dogfoods FR-024-D's exemption (`integration_rationale: edits gate prompts/docs only; no runtime boundary`).

## Technical Approach

- **Pointer carrier (architecture decision, from deliberation §Adversarial Review):** the `prod-callsite` pointer rides the existing `Independent Test [machine:]` sub-line — NOT the `[outcome:integration]` AC-line facet tag. Overloading the facet would break the "exactly one AC-line tag" invariant and conflate negative-space semantics with a positive locator; the shipped proposal lineage already placed the integration pointer on the test line.
- **No new criterion #18 (deliberation §Adversarial Review):** omission closure is delivered by *tightening* qa-spec's existing `[outcome:integration]` N/A sentinel (criterion #17) and *extending* #13's silently-deferred clause — not by minting a parallel criterion that re-derives legacy-skip/exemption logic #17 already owns.
- **Reconciliation is the shift-left teeth (VOQ-1 resolution):** the construction gate can only check pointer shape; the genuine "is it wired in prod" check is the review-board-integration reconciliation (FR-024-B), which already derives a wired-path inventory from the diff and now also confronts the author's cited pointer against it.
- **Predicate is judgment-backstopped (VOQ-3 resolution):** there is no bash-only way to decide "touches a boundary"; the deterministic surface is the pointer/sentinel/field checks, and qa-spec judgment is the actual enforcer of a wrong non-boundary claim. The spec does not claim deterministic closure of silent omission.

## Testing Strategy

- Fixture gate-evals (mirrors the shipped `gate-evals` approach): planted-defect fixtures the gates MUST flag (missing pointer; test-rooted pointer; cited pointer absent from wired inventory; unmapped plan pointer; boundary-touching omission with no rationale) + clean/legacy fixtures the gates MUST NOT flag (false-positive + retro-fail control).
- Unit focus: the deterministic grep rules (pointer-present, not-under-test-root, path-in-phase-scope, field-present).
- Integration boundaries: None in scope for this piece's own implementation (markdown edits) — see Integration Coverage.
- Edge cases: a spec citing multiple seams (per-seam pointer binding); a pointer to a `src/` path that exists but is not in the wired inventory (the FO-16 case → FR-024-B must-fix); ambiguous `piece_class` (resolves to boundary-touching).

## Integration Coverage

- None in scope. This piece edits markdown QA-agent prompts (`qa-spec`, `qa-plan`, `review-board-integration`), the spec template, the spec skill, `reference/spec-flow-doctrine.md`, and `reference/behavior-classification.md` — there is no cross-component runtime wiring with doubled externals. (`integration_rationale: edits gate prompts/docs only; no runtime boundary` — dogfoods FR-024-D's exemption.)

## Open Questions

- (None surviving. The three deliberation VOQs are resolved in this spec: VOQ-1 → reconciliation gate at review-board-integration, FR-024-B; VOQ-2 → standalone piece, confirmed by operator; VOQ-3 → judgment-backstopped predicate accepted, FR-024-E. See `deliberation.md`.)
