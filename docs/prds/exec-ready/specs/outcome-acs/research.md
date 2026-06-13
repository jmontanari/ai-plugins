# Research: outcome-acs

## Brainstorm Inference Digest

**Piece purpose.** Add the missing *oracle* to behavior-bearing specs: ACs must state what the running system must and must NOT produce (negative space), not only that a function returns a value. Two coordinated additions across four doc-as-code surfaces, covering FR-018 / SC-010 / G-7:

- **(a) ELICITATION** — a mandatory negative-space question ("when this runs, what does unacceptable output look like?") is posed in *two* places: the spec brainstorm (`skills/spec/SKILL.md` Phase 2 step 3) and the FR-009 deliberation `user-intent` lens (`agents/deliberation-lens.md`). The answer(s) are captured as one or more **outcome ACs**, tagged distinctly from **mechanism ACs**. A behavior-bearing spec cannot reach sign-off with zero recorded outcome answers (≥1 prohibition, "must never …").
- **(b) ENFORCEMENT** — `qa-spec` (`agents/qa-spec.md`) raises a must-fix when a behavior-bearing spec has only mechanism ACs. A piece declared non-behavioral (config/glue/docs) is exempt with a recorded one-line rationale. Ambiguous status defaults to behavior-bearing.

**Downstream consumption (out of scope to build here, but design must enable).** Outcome ACs are addressable *by ID* as the oracle for the future `outcome-campaign` (FR-020) and the `review-board-ground-truth` seat — *referenced, not re-derived*. The ground-truth agent already hunts the exact failure class outcome ACs target (green-suite + clean-review coexisting with confidently-wrong output: degenerate/dead-knob, lookahead leakage, scope contamination, silent truncation) and explicitly looks in the spec for "stated known/expected results." Outcome ACs give it a structured oracle to bind to.

**Design constraints (charter-binding).**
- NN-C-002 / charter-tools: markdown + YAML + JSON + POSIX-bash only, no runtime deps. Entirely doc-as-code edits.
- NN-C-003 (backward-compat within major version): **additive only**. Per NFR-003, legacy specs authored before this ships carry no outcome tags and must NOT be retro-failed. The gate applies only to specs authored after this ships — qa-spec needs a way to distinguish a legacy spec from a new one.
- NN-C-008: agent prompts self-contained (qa-spec and deliberation-lens both carry the `## Worktree` / no-history boilerplate; new criteria must be self-describing).
- NN-C-009: any change under `plugins/spec-flow/` triggers a version bump across the sync triad: `plugins/spec-flow/plugin.json` + `.claude-plugin/marketplace.json` + `plugins/spec-flow/CHANGELOG.md` (all currently `5.16.0`).
- CR-008: thin-orchestrator skills / narrow-executor agents — the elicitation/piece-class logic is orchestrator-side in `skills/spec/SKILL.md`; qa-spec stays a read-only narrow reviewer.
- CR-009: markdown heading hierarchy is detection-load-bearing (`### Phase N:`, template `## Acceptance Criteria`, qa-spec numbered criteria, the lens table). New anchors must preserve nesting.

**Open design ambiguities the spec author must resolve.**
1. **AC tag form** — inline tag on the AC line (parallel to the existing `[machine:]`/`[judgment:]` Independent-Test tag, e.g. `[outcome]`/`[mechanism]`) vs. a separate `### Outcome Acceptance Criteria` subsection under `## Acceptance Criteria`. Inline keeps one AC list and one numbering; separate section is easier to grep but doubles the heading surface. The existing tag lives *on the Independent Test sub-line*, not the AC line — a new tag could go either place.
2. **Piece-class declaration** — *where* the behavior-bearing-vs-non-behavioral declaration is recorded (spec front-matter key? a `## Piece Class` section? a line in Goal/Scope?) and *how qa-spec reads it self-containedly*. This same field is the backward-compat discriminator: how does qa-spec tell a NEW spec (subject to the gate) from a LEGACY spec (exempt)? Candidate signals: presence of the piece-class declaration itself, a `charter_snapshot:` date threshold, or an explicit schema marker. The piece must pick one and make it greppable.
3. **`user-intent` lens "poses a question"** — the lens renders an adversarial HOLDS/CONTESTED *verdict* (Phase D), it does not converse with the operator. Reconcile "mandatory negative-space question" with verdict semantics: most likely the lens emits a CONTESTED/finding when the recommendation lacks a stated unacceptable-output property, which Phase E (`deliberation-convergence`) folds into a `VOQ-N` validated open question — which the spec brainstorm then surfaces (every brainstorm question already must cite a `VOQ-N` ID or named deliberation section). So elicitation is two-hop: lens → VOQ-N → brainstorm question → outcome AC.
4. **"behavior-bearing" definition reuse** — the codebase already splits behavior-bearing (TDD track) vs config/infra/glue/docs (Implement track) at *plan* time (doctrine line 179, plan SKILL). The piece introduces the same split at *spec* time. Decide whether to reuse that exact phrasing/definition or define a spec-local piece class, and whether the default-to-behavior-bearing-on-ambiguity rule is stated once and cited.
5. **qa-spec criterion numbering** — criteria are a numbered list currently ending at **16**; a new outcome-AC enforcement criterion is **#17** (see Pattern Catalog). The `## Output Format` and `## Input Modes` (Focused re-review applies criteria by number) must both pick it up.
6. **Metrics surface** — `metrics.yaml` `spec.ac_verifiability` already counts `[machine:]`/`[judgment:]` tags. Decide whether outcome-vs-mechanism counts are added there (additive leaf, schema_version stays 1 per NN-C-003) or left out of scope.

## Codebase Conventions

- **Co-ship pairing (superpowers pattern).** 27 of 35 agents have a `<name>.agent.md` twin alongside `<name>.md` (GitHub Copilot CLI distribution). **`qa-spec` IS paired** (`qa-spec.md` + `qa-spec.agent.md`, both 102 lines, identical content) — any edit to qa-spec must be mirrored to both files. **`deliberation-lens` is NOT paired** (single `.md`, 91 lines) — deliberation agents are Claude-only. Templates and skills have no `.agent.md` twins.
- **Agent frontmatter (CR-001).** `name:` + `description:` (always opens "Internal agent — dispatched by …. Do NOT call directly."); review/QA agents add `rubric_version: 1`; deliberation/internal agents add `model: opus`. Every executor agent ends with a `## Worktree` block (NN-C-008 self-containment).
- **qa-spec criteria style.** A flat numbered list under `## Review Criteria`, each item `**Bold name:**` + an adversarial "actively look for violations" framing, many stating "must-fix" explicitly with required evidence (quote the term/ID/surrounding phrase). Some criteria are conditionally activated ("when present", "activate when the orchestrator supplies …; skip if absent — not an error"). `## Output Format` is fixed (`### must-fix` / `### acceptable`). `## Input Modes` defines Full / Focused re-review / Focused charter re-review; Focused re-review re-checks prior findings + scans the delta for regressions.
- **Spec template AC form** (`templates/spec.md` `## Acceptance Criteria`): Given/When/Then AC lines, each followed by an indented `Independent Test [machine: <named check>]: …` line, with an HTML-comment alternative form `[judgment: <named arbiter>]`. The tag is on the Independent-Test sub-line. ACs are `AC-N:`-numbered.
- **Marker / lifecycle idiom.** Bracketed inline markers: `[NEEDS CLARIFICATION: …]`, `[PENDING-DECISION: …]`, `[METRICS-ABSENT]`, `[RESEARCH-UNAVAILABLE: …]`. qa-spec criterion 7 flags surviving open-bracket markers as must-fix. An "explicit None — … sentinel is a valid clean state" pattern is used (deliberation VOQ exemption, integration-coverage absence) — a strong precedent for how a non-behavioral exemption should read.
- **Reference-doc indirection (CR-008).** Skills cite reference docs rather than restating contracts ("cite both; do not restate"). New contract detail (tag definition, piece-class rule, backward-compat discriminator) likely belongs in a reference doc (`spec-flow-doctrine.md` or `gate-scaling.md`) that the template, qa-spec, and spec skill all cite.
- **Deliberation indirection.** `deliberation-artifact.md` is the single source of truth for VOQ-N IDs, the 7-section structure, and the sentinel exemptions; agents and skills defer to it. Lens labels and depth subsets live in `deliberation-depth.md`.

## Surface 1 — Spec AC Template & AC Definitions

### File Inventory
**File Inventory:**
- `plugins/spec-flow/templates/spec.md` (72 lines) — `## Acceptance Criteria` (lines 53–56) with the `AC-N:` + `Independent Test [machine:]/[judgment:]` form; `## Requirements`, `### Non-Negotiables Honored`, `## Integration Coverage`, `## Open Questions`. PRIMARY edit surface for where the outcome-vs-mechanism distinction lives.
- `plugins/spec-flow/reference/spec-flow-doctrine.md` — AC / integration / behavior-bearing definitions ("TDD default for behavior-bearing code … config/infra/glue" line 179). Candidate home for the outcome-AC + piece-class definitions cited by template/qa-spec/skill.
- `plugins/spec-flow/reference/gate-scaling.md` — `## spec-gate` (lines 15–23): predicate = QA-clean AND zero surviving markers; evidence-digest with the advisory `machine_checkable_ratio` third field. Candidate home for an outcome-AC sign-off conjunct.

### Dependency Map
**Dependency Map:** `templates/spec.md` is consumed by `skills/spec/SKILL.md` Phase 3 step 2 (`${CLAUDE_PLUGIN_ROOT}/templates/spec.md` as structural guide) and read for structure by `qa-spec` (criteria 6/13). The AC tag is read by the metrics step (`spec.ac_verifiability`) and the spec-gate digest. `spec-flow-doctrine.md` is cited by the plan skill (track selection) and brainstorm. Downstream-by-ID consumers: future `outcome-campaign` (FR-020) and `review-board-ground-truth` (spec "stated known/expected results").

### Test Landscape
**Test Landscape:** No unit-test harness for markdown plugin files (NN-C-002 / charter-tools: no runtime deps). Validation is structural/grep-based: heading anchors (CR-009), the `metrics.yaml` block-style invariant is parseable by `python3 yaml.safe_load` and grep/awk (`scripts/metrics-aggregate`). Verification for this piece will be grep/script checks over template + spec instances, exercised at plan/execute time — not a test runner.

### Pattern Catalog
**Pattern Catalog:** existing AC + tagged Independent-Test form (`templates/spec.md` 53–56):
```
## Acceptance Criteria
AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}}
  Independent Test [machine: <named check — a grep/script/test that decides>]: <how to verify>
  <!-- Alternative form: Independent Test [judgment: <named arbiter — who decides>]: <what they inspect> -->
```
spec-gate predicate (`gate-scaling.md` ~15–21):
```
When the spec-gate predicate holds (QA-clean and zero surviving markers), the gate
renders the evidence digest and offers a single-key summary-confirm. Otherwise the full
sign-off prompt is rendered. A keystroke is always required on both branches.
```

## Surface 2 — qa-spec Enforcement

### File Inventory
**File Inventory:**
- `plugins/spec-flow/agents/qa-spec.md` (102 lines) — `## Review Criteria` numbered list 1–16; `## Output Format` (`### must-fix`/`### acceptable`); `## Input Modes` (Full / Focused re-review / Focused charter re-review); `## Rules` ("NO context from brainstorming"); `## Worktree`. PRIMARY enforcement edit.
- `plugins/spec-flow/agents/qa-spec.agent.md` (102 lines, identical) — Copilot CLI twin; **must be edited in lockstep**.

### Dependency Map
**Dependency Map:** Dispatched by `skills/spec/SKILL.md` Phase 4 (iter-1 Full with full spec + charter + PRD + NN-P + budgets; iter-2+ Focused re-review with fix-doc delta + prior findings). Criteria 14/15 read `deliberation.md` when present; criterion 16 reads orchestrator-supplied budget counts. A new outcome-AC criterion needs: (a) the spec's piece-class declaration injected/readable, (b) a way to read the AC tags, (c) the legacy-vs-new discriminator. Output flows to the QA loop (iter-until-clean, 3-iter circuit breaker) → `fix-doc` → re-review.

### Test Landscape
**Test Landscape:** No automated tests for the agent prompt. The criterion is self-validating prose; verification is the QA loop itself plus grep that the criterion (a) appears in both `qa-spec.md` and `qa-spec.agent.md`, (b) is numbered 17, (c) is wired into `## Input Modes` focused re-review. The `transcript-eval` tooling (`tools/transcript-eval/`) mines real sessions for gate behavior (gate-evals piece) — a future eval could measure this gate's firing, not in scope here.

### Pattern Catalog
**Pattern Catalog:** existing conditionally-activated, evidence-bearing criterion idiom (criterion 7 + the activate-when pattern of 16) — the new #17 should follow this exact shape:
```
7. **Uncertainty markers:** Any surviving `[NEEDS CLARIFICATION` or `[PENDING-DECISION`
   markers … are automatic must-fix findings. For each found: quote the full marker text
   and the surrounding sentence as evidence. The absence … is not a finding — only
   surviving instances trigger must-fix.
```
sentinel-exemption precedent (criterion 15 — model for the non-behavioral exemption):
```
**Exemption:** a `## Validated Open Questions` section whose body is an explicit
"None — …" sentinel … is a valid clean state … and does NOT trigger a must-fix finding.
```

## Surface 3 — Spec Skill Elicitation & Piece-Class Declaration

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/spec/SKILL.md` (343 lines) — Phase 2 brainstorm step 3 sub-areas (architecture, data flow, security C-2, NFR H-4, error handling, migration M-7, testing, integration, isolation); step 7 active-validation preview (H-5/L-11: FR→AC coverage, gap call-out, adversarial close); Phase 3 write; Phase 5 metrics (`ac_verifiability`). PRIMARY orchestrator-side edit for the mandatory negative-space question + piece-class declaration.
- `plugins/spec-flow/reference/brainstorm-procedure.md` — Core Brainstorm Building Blocks (C-2 always-run, C-3 floor check, L-10, Tier-2 answer-validation loop). Candidate home for a negative-space building block.

### Dependency Map
**Dependency Map:** `skills/spec/SKILL.md` reads PRD sections + manifest piece + charter (Phase 1), runs the deliberation protocol (dispatches the five lenses incl. `user-intent`), drives brainstorm (Phase 2), writes spec.md from `templates/spec.md` (Phase 3), dispatches `qa-spec` (Phase 4), writes `metrics.yaml` + advances manifest (Phase 5). The piece-class declaration written here is what qa-spec (Surface 2) reads and what plan/execute may later key track selection on. Brainstorm questions cite `VOQ-N` IDs from `deliberation.md` — the elicitation two-hop (lens→VOQ→question) runs through this file.

### Test Landscape
**Test Landscape:** No runtime tests. Verification is structural (heading anchors `### Phase N:`, step numbering) + behavioral via the QA loop and human sign-off gate. The H-5 active-validation preview (step 7) is the natural place to add an "≥1 outcome AC for behavior-bearing pieces" self-check that mirrors the existing FR→AC coverage check.

### Pattern Catalog
**Pattern Catalog:** the H-5 FR→AC coverage self-check (Phase 2 step 7.1) — the model for a parallel outcome-AC presence check:
```
1. **FR→AC coverage check:** Explicitly list: "I see N FRs. Let me verify each has at
   least one AC." Flag any FR with zero ACs. Flag any AC with no stated test approach.
```
the inference-first sub-area pattern (step 3) the negative-space question would slot into:
```
3. **Explore purpose, boundaries, and design.** For each sub-area below, state what
   you've already inferred … then ask only about what remains genuinely unclear. Lead
   with your understanding … Floor check (C-3): … (a) one concrete named scenario …
   AND (b) one failure mode or edge case.
```

## Surface 4 — Deliberation user-intent Lens & VOQ Folding

### File Inventory
**File Inventory:**
- `plugins/spec-flow/agents/deliberation-lens.md` (91 lines) — `## Lens Definitions` 5-row table (incl. `user-intent`: "Does the recommendation genuinely serve the PRD user story and acceptance criteria?"); `## Procedure` (HOLDS/CONTESTED verdict, no VOQ assignment); single file, NOT co-shipped. PRIMARY edit for adding the negative-space dimension to the user-intent lens.
- `plugins/spec-flow/agents/deliberation-convergence.md` — Phase E: folds CONTESTED verdicts, assigns `VOQ-N` IDs, writes `## Adversarial Review` + `## Validated Open Questions`. The negative-space gap surfaces here as a VOQ-N.
- `plugins/spec-flow/reference/deliberation-artifact.md` — single source of truth for VOQ-N IDs, 7-section structure, sentinel exemptions.
- `plugins/spec-flow/reference/deliberation-depth.md` — lens label list + lite-depth subset (`scope/simplicity` + `risk`); note `user-intent` is NOT in the lite subset, so a lite-depth piece would not pose the negative-space question via the lens — the spec-brainstorm hop must cover that path.

### Dependency Map
**Dependency Map:** `deliberation-lens` is dispatched 5× in parallel by `skills/spec/SKILL.md` Phase 2 deliberation step 5 (one lens label each), after Phase C. Verdicts feed Phase E (`deliberation-convergence`), which writes `deliberation.md`. The spec brainstrom (Surface 3) then draws questions from `## Validated Open Questions` by `VOQ-N` ID. qa-spec criteria 14/15 check `deliberation.md` structure and VOQ-N presence. The elicitation chain: user-intent lens emits negative-space CONTESTED → Phase E → VOQ-N → brainstorm question → outcome AC.

### Test Landscape
**Test Landscape:** No runtime tests. Verification is structural: the lens table keeps 5 rows with stable labels; Phase E still produces the 7 core sections; VOQ-N IDs remain stable. A risk to flag: editing the `user-intent` row must not break the depth-subset references in `deliberation-depth.md` or the lens-count assertion (exactly five) in the spec skill.

### Pattern Catalog
**Pattern Catalog:** the lens table row to extend (`deliberation-lens.md` ~37):
```
| `user-intent` | Does the recommendation genuinely serve the PRD user story and
acceptance criteria? Will the user's actual goal be met? |
```
Phase E fold rule (`deliberation-convergence.md` ~30–36) — how a negative-space CONTESTED becomes a VOQ-N:
```
1. **Fold Phase D verdicts into the recommendation.**
   - If any verdict is CONTESTED: revise the recommendation to address the specific
     challenge … a changed path, constraint, or scope boundary that resolves the challenge.
…  - Only questions that survived adversarial review **unresolved** belong here. Assign
     each surviving question a stable `VOQ-N` ID sequentially starting from `VOQ-1`.
```
