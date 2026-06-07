---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: sonnet-coord — Lean Sonnet coordinator on file-based state

**Spec:** docs/prds/exec-ready/specs/sonnet-coord/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Doc-as-code piece (markdown/YAML only; no behavior-bearing code, no test harness — charter-tools). All phases use the **Implement track** (`[Implement]` → `[Verify]` → `[QA]`); `[Write-Tests]` is N/A — there is no executable test surface, so `[Verify]` blocks use `grep` / `test -f` / LLM-agent-step assertions (mirrors the merged `plan-concrete` and `test-data-up` pieces). AC Coverage Matrix and Executable AC Binding are included even though optional for `tdd: false`, because the inspectable-invariant ACs map cleanly to grep/agent-step checks.

Implementation order: (1) author the canonical `reference/coordinator-contract.md` (the source of truth every execute edit cites), (2) add the two `.spec-flow.yaml` keys, (3) parameterize `qa-iteration-loop.md`, then (4–7) edit `execute/SKILL.md` in four serial concern-scoped passes (model-policy report, configurable breaker, resume/STATE-INCOMPLETE, return discipline+audit), then (8) bump the version across all four version-bearing files + CHANGELOG **last** (NN-C-009 + the post-CHANGELOG re-verify rule). Phases 4–7 all edit the single 1863-line `execute/SKILL.md` and are inherently serial.

## Architectural Decisions

### ADR-1: Canonical definitions live in a new `reference/coordinator-contract.md`, not inline in execute
**Context:** The model-policy table, the coordinator return discipline, and the resume-critical field-tier table are cross-cutting contracts that `execute/SKILL.md` (already 1863 lines) consumes. They could be inlined into execute or factored into a reference doc.
**Decision:** Author one new `reference/coordinator-contract.md` holding all three; `execute/SKILL.md` cites it.
**Alternatives considered:** (a) Inline everything in execute — rejected: grows the largest skill file further and fights the lean-coordinator theme. (b) Three separate reference docs — rejected: the three contracts are one cohesive "how the coordinator behaves" surface; one doc keeps them discoverable together.
**Consequences:** Easier: execute stays lean; reviewers diff one canonical table against dispatch sites. Harder: one extra cross-file citation hop. Matches the established convention (`deferred-commit-journal.md`, `qa-iteration-loop.md`, `research-artifact.md` are canonical defs cited by skills).
**Charter alignment:** CR-008 (thin orchestrator — defs in reference, orchestration in skill); charter-architecture (reference/ holds auto-loaded doctrine cited by skills).

### ADR-2: `qa_max_iterations: auto` resolves off the plan's `tdd:` flag (single key, all five QA fix-loops)
**Context:** The spec extends the configurable breaker from "Final Review only" (PRD literal) to all five QA-agent fix-loops via one key. `auto` must resolve to 5 for doc-as-code and 3 for TDD pieces (pi-011), and the resolver needs a disk-derivable signal.
**Decision:** `auto` reads the plan front-matter `tdd:` field already loaded at Step 0 — `tdd: false` → 5, `tdd: true` → 3. An explicit integer overrides all five loops uniformly. Absent key → `auto`.
**Alternatives considered:** (a) Per-loop keys — rejected: five knobs for one concept; the operator wants one dial. (b) Per-track config map — rejected: over-engineered; the `tdd:` flag already encodes the track. (c) Final-Review-only (PRD literal) — superseded by the operator's spec decision to govern all five for consistency.
**Consequences:** Easier: one dial; backward-compatible (TDD pieces still get 3). Harder: a single flip also loosens the per-phase gate — accepted by the operator; default preserves current behavior so no silent loosening.
**Charter alignment:** NN-C-003 (absent/explicit-3 restores current behavior); CR-007 (one documented key).

### ADR-3: STATE-INCOMPLETE refines, not replaces, the existing "no journal → fresh start" path
**Context:** Today a missing Phase Group journal = fresh start (execute L1837), and missing discovery fields use defensive defaults (L932). The new escalate-don't-guess failure mode could contradict both.
**Decision:** Three-tier classification (in `coordinator-contract.md`): escalate `[STATE-INCOMPLETE]` only when a field is resume-critical AND expected-present-given-position AND missing/corrupt; recompute tier (SHA, amendment counters); valid-absence/defensive-default tier (preserves L1837 fresh-start and L932 cosmetic defaults). The "group in flight" predicate makes "expected-present" computable from plan.md checkboxes + HEAD.
**Alternatives considered:** (a) Strict — any missing resume-critical field escalates — rejected: false escalations on valid fresh-start. (b) Minimal — escalate only on unreadable plan.md — rejected: under-delivers NFR-002. (Both were weighed and declined at spec time.)
**Consequences:** Easier: no false escalations; L932/L1837 behavior preserved. Harder: the predicate must be precisely specified (mitigated by an inline worked trace, per the dense-algorithm guard).
**Charter alignment:** NN-C-005 (silent no-op on valid absence); NN-P-003 (operator-invoked — escalation surfaces to operator, no auto-guess).

## Phases

### Phase 1: Canonical coordinator-contract reference doc
**Exit Gate:** `reference/coordinator-contract.md` exists with the three sections (Model Policy, Coordinator Return Discipline, Resume-Critical State field-tier table) and a worked STATE-INCOMPLETE trace; `grep` confirms each section heading and the model-table rows.
**ACs Covered:** AC-1 (model-policy table), AC-3 (exception categories), AC-4 (return-discipline contract), AC-7 (field-tier table), AC-8 (predicate + worked trace)
**In scope:** CREATE `plugins/spec-flow/reference/coordinator-contract.md`
**NOT in scope:** any `execute/SKILL.md` edits (Phases 4–7 cite this doc); config keys (Phase 2); version bump (Phase 8)
**Why serial:** Phases 4–7 cite this doc's table and predicates by name; authoring it first makes the execute edits transcription rather than design, and keeps the dependency chain reviewable. (Phases 1–3 touch disjoint files but are sequenced for this citation order; per-file changes are small so parallel fan-out saves negligible wall-clock.)
**Charter constraints honored in this phase:**
- CR-008 (thin orchestrator): canonical defs live in reference/, consumed by the skill — no orchestration logic added here.
- CR-009 (heading hierarchy): one H1, H2 sections, H3 subsections; no level skips.
- CR-005 (repo-root-relative paths): all cross-references use repo-root-relative paths.

- [x] **[Implement]** Author the canonical reference doc
  - Architecture constraints: markdown only; peer of `reference/deferred-commit-journal.md`; cited by `execute/SKILL.md` (Phases 4–7). No runtime deps.

  **Change Specifications:**

  **T-1: CREATE plugins/spec-flow/reference/coordinator-contract.md**
  - Structure outline (H1 title + three H2 sections):
    ```
    # Coordinator Contract — model policy, return discipline, resume-critical state
    ## Model Policy
    ## Coordinator Return Discipline
    ## Resume-Critical State — Field Tiers
    ```
  - Target content for `## Model Policy`:
    - Intro: "The table below documents the model assigned to each in-execute dispatch stage. It is **derived from and must agree with** the actual `Agent({… model:})` dispatch sites in `plugins/spec-flow/skills/execute/SKILL.md` — it documents, it does not redefine. The execute skill diffs this table against the dispatch sites (AC-1)."
    - Markdown table (these values are ground-truth from the dispatch sites):
      ```
      | Stage | Model | Dispatch site |
      |-------|-------|---------------|
      | coordinator (this skill) | sonnet | execute pre-flight |
      | implementer (TDD/Implement) | sonnet | Step 3 / Step G |
      | tdd-red | sonnet | Step 2 |
      | qa-tdd-red | sonnet | Step 2.5 |
      | verify | sonnet | Step 4 |
      | refactor | sonnet | Step 5 / G7 |
      | fix-code | sonnet | Step 6 / G8 / Final Review Step 3 |
      | qa-phase-lite | sonnet | Group QA-lite |
      | reflection (process-retro, future-opportunities) | sonnet | Step 4.5 |
      | qa-phase (full, per-phase) | opus | Step 6 |
      | mid-piece QA pass | opus | Step 0a |
      | Final Review board (8–9 agents) | opus | Final Review Step 2 |
      | spec / plan authoring | opus | upstream of execute — excluded from the dispatch-site diff |
      ```
    - Sanctioned exceptions block: "Exactly two exceptions upgrade an in-execute stage to Opus and are the only assignments the policy *flags* (vs silently reports): (1) **spike phase → Opus** — a `[SPIKE]` phase dispatches the spike agent on Opus (mechanism wired by the `spike-agent` piece, FR-005); (2) **operator override → Opus** — the operator forces Opus for a named piece/phase (mechanism wired by `spike-agent`, FR-005 AC-3). No other path upgrades a non-`[SPIKE]` stage to Opus (NN-P-005)."
    - `model_policy` semantics: "`model_policy: auto` (default; absent → auto) — the coordinator reports the per-stage assignment at execute start and flags only the two exceptions. `model_policy: off` — the coordinator runs only the legacy single Pre-flight Model Check prompt (`execute/SKILL.md` `## Pre-flight: Model Check`) and emits no per-stage report."
  - Target content for `## Coordinator Return Discipline`:
    - "The coordinator stays lean over long pieces by consuming **bounded, structured** agent returns. Every agent return to the coordinator MUST be a bounded summary; raw artifacts — full diffs, full test output, file bodies — live on disk or git and are referenced by path, never pasted into the coordinator's context. The execute skill carries an audit table (one row per dispatch) asserting each return is bounded; any dispatch instructing an agent to paste a raw dump is a defect."
  - Target content for `## Resume-Critical State — Field Tiers`:
    - Three-tier rule statement: "`[STATE-INCOMPLETE: <field>]` is emitted (and the coordinator escalates to the operator rather than guessing) **iff** a field is (a) resume-critical, (b) expected-present given the current resume position, and (c) missing or corrupt. Otherwise the coordinator recomputes (tier 2) or treats the absence as valid (tier 3)."
    - Field-tier table:
      ```
      | Field | Tier | On-disk home / recompute source | Missing-field behavior |
      |-------|------|---------------------------------|------------------------|
      | plan.md + its [x] checkboxes | 1 | plan.md | escalate [STATE-INCOMPLETE: plan.md] — position cannot be located |
      | Phase Group journal sub_phases[].status, red_manifest_hashes — WHEN a group is in flight | 1 | journal (deferred-commit-journal.md) | escalate [STATE-INCOMPLETE: journal] — cannot know which sub-phases are green |
      | phase-start SHA | 2 | git rev-parse HEAD (minus this phase's committed steps) | recompute — no escalation |
      | amendment counters | 2 | count committed amendments in branch history | recompute — no escalation |
      | Phase Group journal — WHEN no group is in flight | 3 | n/a (valid absence) | fresh start (existing L1837 behavior) — no escalation |
      | .orchestra-state.json (mid-piece pass flag) | 3 | file absent = pass not yet dispatched | valid absence — no escalation |
      | discovery-row cosmetic fields (source_agent, ac_id) | 3 | n/a | defensive default (existing L932 behavior: `unknown` / `—`) — no escalation |
      ```
    - "Group in flight" predicate (computable from disk): "A Phase Group is *in flight* iff plan.md shows at least one checked sub-phase step checkbox under the group AND the group-level `[Progress]` checkbox is unchecked. When a group is in flight, its journal is expected-present (tier-1); when no group is in flight, journal absence is valid (tier-3)."
    - Worked trace (REQUIRED — concrete input→output, per the dense-algorithm guard):
      ```
      <!-- Worked example:
        plan.md state: Phase Group B — sub-phase B.1 [Build] checkbox = [x],
                       group-level [Progress] checkbox = [ ]   ⇒ group B IS in flight.
        Disk: no journal file present (or group_letter ≠ B).
        Classify journal: tier-1 (resume-critical AND expected-present AND missing).
        Output: emit `[STATE-INCOMPLETE: journal]`, escalate to operator. Do NOT fresh-start.

        Contrast: plan.md shows group B with NO checked sub-phase steps and [Progress] = [ ]
                  ⇒ group B NOT in flight. No journal ⇒ tier-3 valid absence ⇒ fresh start (L1837). -->
      ```
  - Done: file exists with all three H2 sections, the model table (13 rows incl. the upstream-excluded row), the two exceptions, the field-tier table (7 rows), the predicate, and the worked-example comment.
  - Verify: `grep -c "^## " plugins/spec-flow/reference/coordinator-contract.md` returns 3; `grep -n "STATE-INCOMPLETE: journal" plugins/spec-flow/reference/coordinator-contract.md` returns ≥2 matches (rule + worked trace).

- [x] **[Verify]** Confirm the reference doc is complete and consistent
  **Per-change checks:**
  - T-1: `grep -nE "^## (Model Policy|Coordinator Return Discipline|Resume-Critical State)" plugins/spec-flow/reference/coordinator-contract.md` — Expected: 3 matching headings.
  - T-1: LLM-agent-step: read `plugins/spec-flow/reference/coordinator-contract.md` and confirm (a) the model table lists reflection→sonnet and qa-phase→opus, (b) exactly two sanctioned exceptions are named (spike, operator-override), (c) the worked trace shows a concrete in-flight→escalate and not-in-flight→fresh-start contrast — Expected: all three confirmed.
  **Phase-level check:**
  - Run: `test -f plugins/spec-flow/reference/coordinator-contract.md && echo OK` — Expected: `OK`.
  - Failure: file missing, fewer than 3 H2 sections, or model table contradicts the dispatch-site ground truth.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-3, AC-4, AC-7, AC-8
  - Diff baseline: git diff {{phase_1_start}}..HEAD

### Phase 2: Add `.spec-flow.yaml` config keys
**Exit Gate:** `templates/pipeline-config.yaml` defines `model_policy` and `qa_max_iterations` with CR-007 comment blocks (valid values + default + rationale); `grep` confirms both keys.
**ACs Covered:** AC-1 (model_policy opt-out key), AC-5 (qa_max_iterations key + auto default), AC-6 (backward-compat default)
<!-- Branch-enumeration ACs: the keys' value-branches (model_policy auto|off; qa_max_iterations auto|<int>) are documented in the comment blocks here and exercised by Phases 4/5 — the per-branch ACs (AC-1/AC-2 for model_policy, AC-5/AC-6 for qa_max_iterations) are covered in those phases. -->
**In scope:** MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`
**NOT in scope:** reading the keys in execute (Phase 4 reads model_policy; Phase 5 reads qa_max_iterations); the parameterized loop semantics (Phase 3)
**Why serial:** Phases 4 and 5 read these keys by name; defining the schema first makes those reads concrete.
**Charter constraints honored in this phase:**
- CR-007 (inline config-key docs): each key gets a leading comment block with valid values, default, and rationale.
- NN-C-003 (backward-compat): both keys default to current behavior when absent.

- [x] **[Implement]** Add the two keys following the existing scalar-key idiom
  - Architecture constraints: match the `refactor` / `deferred_commit` comment-block shape (CR-007); place in the "Orchestrator behavior" region after `deferred_commit` (current L48–53).

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/templates/pipeline-config.yaml**
  - Anchor: after the `deferred_commit:` block (lines 48–53)
  - Current:
    ```
    48  # deferred_commit: controls Phase Group commit model (new in v5.0.0)
    ...
    53  deferred_commit: auto
    ```
  - Target: insert two new key blocks immediately after line 53 (blank line separated):
    ```
    # model_policy: controls the execute per-stage model report (new in v5.6.0)
    #   auto — coordinator reports the per-stage model assignment at execute start and flags only
    #          the two sanctioned exceptions (spike phase / operator override); see
    #          plugins/spec-flow/reference/coordinator-contract.md (default)
    #   off  — run only the legacy Pre-flight Model Check prompt; emit no per-stage report
    model_policy: auto

    # qa_max_iterations: configurable QA fix-loop circuit-breaker limit (new in v5.6.0)
    #   auto  — resolve per piece track: 5 for doc-as-code/Implement pieces (tdd: false),
    #           3 for TDD pieces (tdd: true). Codifies the pi-011 finding that a hard 3 is
    #           wrong for doc-as-code Final Review (default)
    #   <int> — explicit cap applied uniformly to all five QA-agent fix-loops
    #   Governs: Final Review fix loop, per-phase qa-phase, mid-piece Opus pass, Group Deep QA,
    #   qa-phase-lite. Does NOT govern the oracle 2-attempt build budget or the mechanical
    #   SKILL self-lint loop.
    qa_max_iterations: auto
    ```
  - Done: both keys present with comment blocks; defaults are `auto`/`auto`.
  - Verify: `grep -nE "^(model_policy|qa_max_iterations):" plugins/spec-flow/templates/pipeline-config.yaml` returns both with value `auto`.

- [x] **[Verify]** Confirm keys and comments are present and valid YAML
  **Per-change checks:**
  - T-1: `grep -c "^model_policy: auto" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: 1; `grep -c "^qa_max_iterations: auto" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: 1.
  - T-1: LLM-agent-step: read `plugins/spec-flow/templates/pipeline-config.yaml` and confirm it parses as valid YAML and each new key has a preceding comment block stating valid values + default — Expected: valid YAML; both comment blocks present.
  **Phase-level check:**
  - Run: `grep -A1 "qa_max_iterations: configurable" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: comment lines listing the five governed loops and the two exclusions.
  - Failure: missing key, missing comment block, or malformed YAML.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-5, AC-6
  - Diff baseline: git diff {{phase_2_start}}..HEAD

### Phase 3: Parameterize `qa-iteration-loop.md`
**Exit Gate:** `reference/qa-iteration-loop.md` states the breaker limit as `qa_max_iterations` (default 3) rather than a hard "3-iter"; semantics preserved (escalate on the configured-limit-th must-fix iteration; never limit+1).
**ACs Covered:** AC-5 (parameterized default), AC-6 (default 3 preserves behavior)
<!-- Branch-enumeration ACs: this phase has one conditional surface — the limit value (auto→5/3 or explicit int). Both branches are covered by AC-5/AC-6, verified in Phase 5 where the value threads into the loops. -->
**In scope:** MODIFY `plugins/spec-flow/reference/qa-iteration-loop.md`
**NOT in scope:** threading the value into execute's five loops (Phase 5); the config key definition (Phase 2)
**Why serial:** Phase 5's breaker edits cite this parameterized semantics; updating the canonical loop doc first keeps the contract consistent.
**Charter constraints honored in this phase:**
- NN-C-003 (backward-compat): default remains 3 — TDD-piece semantics unchanged.
- CR-005 (repo-root-relative paths): the cross-reference to the config key stays repo-root-relative where pathed.

- [x] **[Implement]** Replace the two hard-"3-iter" statements with parameterized prose
  - Architecture constraints: this is the canonical loop-semantics doc; keep the escalate-on-final-iteration semantics, only parameterize the integer.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/reference/qa-iteration-loop.md**
  - Anchor: Purpose paragraph (line 7)
  - Current:
    ```
    7  Every QA gate in the pipeline iterates until the reviewing agent returns must-fix=None. The 3-iter circuit breaker is the escalation guard — it fires when iteration 3 still has must-fix findings and the orchestrator cannot resolve them automatically. ...
    ```
  - Target: replace "The 3-iter circuit breaker is the escalation guard — it fires when iteration 3 still has must-fix findings" with "The circuit breaker is the escalation guard — its limit is `qa_max_iterations` from `.spec-flow.yaml` (default 3; `auto` resolves to 5 for doc-as-code/`tdd: false` pieces and 3 for TDD/`tdd: true` pieces). It fires when iteration `qa_max_iterations` still has must-fix findings". Keep the rest of the sentence.
  - Done: line 7 references `qa_max_iterations` and no longer hard-codes "iteration 3" as the only limit.
  - Verify: `grep -n "qa_max_iterations" plugins/spec-flow/reference/qa-iteration-loop.md` returns ≥2 matches.

  **T-2: MODIFY plugins/spec-flow/reference/qa-iteration-loop.md**
  - Anchor: iteration-numbering bullet (line 15)
  - Current:
    ```
    15  - The **3-iter circuit breaker** fires when iter-3 returns ≥ 1 must-fix finding. At that point the orchestrator escalates to the human with the iter-3 must-fix list intact and does NOT dispatch iter-4.
    ```
  - Target: replace with "- The **circuit breaker** fires when iter-`L` returns ≥ 1 must-fix finding, where `L = qa_max_iterations` (default 3; `auto` → 5 for `tdd: false`, 3 for `tdd: true`). At that point the orchestrator escalates to the human with the iter-`L` must-fix list intact and does NOT dispatch iter-`L+1`."
  - Done: the bullet is value-parameterized; "iter-4" is replaced with "iter-`L+1`".
  - Verify: `grep -n "iter-\`L+1\`\|qa_max_iterations" plugins/spec-flow/reference/qa-iteration-loop.md` returns matches; `grep -c "does NOT dispatch iter-4" plugins/spec-flow/reference/qa-iteration-loop.md` returns 0.

  **T-3: MODIFY plugins/spec-flow/reference/qa-iteration-loop.md** (the THIRD limit statement — escalation termination)
  - Anchor: `## Iteration termination`, "Circuit-breaker termination" bullet (line 26)
  - Current:
    ```
    26  - **Circuit-breaker termination escalates to human.** When iter-3 returns ≥ 1 must-fix finding, the orchestrator surfaces the iter-3 must-fix list to the human and halts. The only forward paths are: (a) the human amends the artifact directly and re-runs the QA gate from iter-1, or (b) the human overrides the finding as out-of-scope with an explicit rationale.
    ```
  - Target: replace both "iter-3" occurrences in this bullet with "iter-`L`" (`L = qa_max_iterations`, default 3): "When iter-`L` returns ≥ 1 must-fix finding, the orchestrator surfaces the iter-`L` must-fix list to the human and halts." Leave the forward-paths clause (a)/(b) unchanged.
  - Done: the escalation-termination bullet is value-parameterized; no bare "iter-3" survives in it.
  - Verify: `grep -c "When iter-3 returns" plugins/spec-flow/reference/qa-iteration-loop.md` returns 0; `grep -c "When iter-\`L\` returns" ...` returns 1.

  **T-4: MODIFY plugins/spec-flow/reference/qa-iteration-loop.md** (migration historical note)
  - Anchor: `## Migration from qa_iter2`, line 40
  - Current:
    ```
    40  v3.1.0 retires this skip. ... The 3-iter circuit breaker provides the only automatic exit short of must-fix=None.
    ```
  - Target: replace "The 3-iter circuit breaker" with "The circuit breaker (`qa_max_iterations`, default 3; configurable since v5.6.0)" so the historical note does not contradict the now-configurable limit. Rest of the sentence unchanged.
  - Done: no live "3-iter" limit claim remains anywhere in the file (only the parameterized default 3).
  - Verify: `grep -c "3-iter circuit breaker" plugins/spec-flow/reference/qa-iteration-loop.md` returns 0.
  - Note: every limit/escalation statement in this file (lines 7, 15, 26, 40) is now parameterized to `qa_max_iterations`; the document title and "iter-until-clean" descriptive prose are unchanged.

- [x] **[Verify]** Confirm parameterization is consistent across ALL limit statements
  **Per-change checks:**
  - T-1/T-2/T-3/T-4: `grep -c "qa_max_iterations" plugins/spec-flow/reference/qa-iteration-loop.md` — Expected: ≥4 matches (Purpose L7 + numbering bullet L15 + termination L26 + migration L40).
  - T-2: `grep -c "does NOT dispatch iter-4" plugins/spec-flow/reference/qa-iteration-loop.md` — Expected: 0.
  - T-3: `grep -c "When iter-3 returns" plugins/spec-flow/reference/qa-iteration-loop.md` — Expected: 0.
  - T-4: `grep -c "3-iter circuit breaker" plugins/spec-flow/reference/qa-iteration-loop.md` — Expected: 0.
  **Phase-level check (no surviving live hard-3 limit anywhere):**
  - Run: `grep -nE "iter-3|3-iter" plugins/spec-flow/reference/qa-iteration-loop.md` — Expected: 0 matches (every limit statement is now `L`/`qa_max_iterations`-parameterized).
  - Run: LLM-agent-step: read the file and confirm the default is stated as 3 and `auto` resolves to 5 (tdd:false) / 3 (tdd:true) — Expected: confirmed; escalate-on-limit-th / never-limit+1 semantics intact.
  - Failure: any surviving bare "iter-3"/"3-iter" limit, or lost escalation semantics.

- [x] **[QA]** Phase review
  - Review against: AC-5, AC-6
  - Diff baseline: git diff {{phase_3_start}}..HEAD

### Phase 4: Execute — model-policy report + opt-out
**Exit Gate:** execute reads `model_policy` at Step 0; under `auto` it emits a per-stage report (citing `coordinator-contract.md`) flagging exactly the two exceptions; under `off` the legacy Pre-flight prompt runs unchanged with no report; `grep` confirms the branch and the citation.
**ACs Covered:** AC-1 (report + exceptions), AC-2 (off preserves legacy), AC-3 (no silent upgrade)
<!-- Branch-enumeration ACs (doc-as-code §3): model_policy has three branches — auto→report (AC-1), off→legacy prompt only (AC-2), absent→auto (AC-1 "(or absent)"). All covered. -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — Step 0 config read + the Pre-flight Model Check section (wrap with model_policy branch + add the report)
**NOT in scope:** the breaker (Phase 5), resume/STATE-INCOMPLETE (Phase 6), return discipline (Phase 7), the override *mechanism* (spike-agent piece), version bump (Phase 8)
**Steps traversed (P2):** Pre-flight: Model Check (L13–47) → Step 0: Load Config (L49–99). The new `auto` report path runs at the end of the Pre-flight check before Step 0 proceeds; the `off` path leaves Pre-flight unchanged. No other step is traversed.
**Dispatch sites (P3):** none — no agent-dispatch contract changes; the report only READS the existing `model:` fields at the dispatch sites (it does not alter them).
**Charter constraints honored in this phase:**
- NN-P-005 (no silent Opus upgrade): the report asserts the stage→model split and flags the only two sanctioned upgrades; no new path upgrades a non-`[SPIKE]` stage.
- NN-C-005 (silent no-op on absent config): absent `model_policy` → `auto`, no error; malformed value → one-line warning + `auto` fallback.
- CR-008 (thin orchestrator): the report cites the reference table; it adds no model-selection logic of its own.

- [x] **[Implement]** Add the model_policy read and the report/opt-out branch
  - Architecture constraints: follow the Step 0 config-read idiom (L236 `deferred_commit` pattern); cite `coordinator-contract.md` for the table — do NOT inline the table in execute.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 0 config-read region — add alongside the `deferred_commit` read (line 236 idiom)
  - Current (idiom to copy):
    ```
    236  Read the `deferred_commit` key from `.spec-flow.yaml` in the SAME pass (valid values: `auto`, `off`;
         default `auto` when the key is absent or unset — per NN-C-003 backward-compat). ...
    ```
  - Target: add a config-read line in the Step 0 pass: "Read the `model_policy` key from `.spec-flow.yaml` (valid values: `auto`, `off`; default `auto` when absent/unset — NN-C-003). A malformed value emits a one-line warning and falls back to `auto`. Hold it in orchestrator state for the Pre-flight report branch."
  - Done: execute reads `model_policy` at Step 0 with absent-default `auto` + malformed→warn+auto.
  - Verify: `grep -n "model_policy" plugins/spec-flow/skills/execute/SKILL.md` returns the Step 0 read.

  **T-2: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: `## Pre-flight: Model Check`, end of section (after line 45 "proceed to Step 0 immediately with no prompt.", before line 47 "**Why Sonnet.**")
  - Current:
    ```
    45  If the model already contains `sonnet` → proceed to Step 0 immediately with no prompt.
    46
    47  **Why Sonnet.** Execute orchestrates multi-agent, multi-phase work: ...
    ```
  - Target: insert a new subsection `### Per-stage model policy report` between L45 and L47 stating:
    - "When `model_policy: auto` (the default), after the Sonnet-class check passes, emit a per-stage model-assignment report from the table in `plugins/spec-flow/reference/coordinator-contract.md` `## Model Policy`. The report lists each in-execute stage → its model and **flags only the two sanctioned exceptions** (spike phase → Opus; operator override → Opus). It never upgrades a non-`[SPIKE]` stage to Opus (NN-P-005)."
    - "When `model_policy: off`, skip the report entirely — only the Pre-flight Model Check prompt above runs (legacy behavior)."
  - Done: the Pre-flight section contains the `auto`→report / `off`→no-report branch and cites `coordinator-contract.md`.
  - Verify: `grep -n "Per-stage model policy report\|coordinator-contract.md" plugins/spec-flow/skills/execute/SKILL.md` returns the new subsection + citation.

- [x] **[Verify]** Confirm the report branch and opt-out
  **Per-change checks:**
  - T-1: `grep -n "model_policy" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥2 matches (Step 0 read + Pre-flight branch).
  - T-2: `grep -n "model_policy: off" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 (the opt-out branch preserving legacy).
  **Phase-level check (AC-1 table↔dispatch agreement — cross-phase with Phase 1):**
  - Run: LLM-agent-step: read the `## Model Policy` table in `coordinator-contract.md` and, for each row mapping to an in-execute dispatch site, confirm the model matches the corresponding `model:` field in `execute/SKILL.md` (sonnet rows: L411/455/509/688/749/1230/1675-76/317; opus rows: L312/828/1520-1527) — Expected: every in-execute row agrees; spec/plan row excluded.
  - Failure: report path missing under `auto`, `off` not preserving legacy, or table disagreeing with a dispatch site.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-3
  - Diff baseline: git diff {{phase_4_start}}..HEAD

### Phase 5: Execute — configurable QA circuit-breaker
**Exit Gate:** execute reads `qa_max_iterations` at Step 0 and threads the resolved value into all five QA fix-loop sites; no hard-coded "3" survives at those sites; absent+tdd:true resolves to 3 (unchanged).
**ACs Covered:** AC-5 (auto default 5/3, explicit int), AC-6 (absent+TDD → 3 unchanged)
<!-- Branch-enumeration ACs (doc-as-code §3): qa_max_iterations branches — auto+tdd:false→5, auto+tdd:true→3, explicit int→that int, absent→auto. AC-5 covers auto(5/3)+explicit; AC-6 covers absent+tdd:true→3. All branches covered. -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — Step 0 read + the five breaker sites (L320, L846, L1230, L1278, L1580) + the Escalation Rules summary line (L1818)
**NOT in scope:** the loop-semantics doc (Phase 3 already parameterized it); the oracle 2-attempt budget and the mechanical self-lint (explicitly excluded — unchanged)
**Steps traversed (P2):** Step 0 (read+resolve) → Step 0a Mid-piece QA (L320) → Step 6 Phase QA (L846) → Group QA-lite (L1230) → Step G8 Group Deep QA (L1278) → Final Review Step 3 fix loop (L1580); Escalation Rules summary (L1818). The resolved value flows into each of these five loop sites; no other step is traversed.
**Dispatch sites (P3):** none — the change adjusts loop-iteration caps, not any agent-dispatch contract (agent prompts/models unchanged).
**Charter constraints honored in this phase:**
- NN-C-003 (backward-compat): absent key + `tdd: true` resolves to 3 — byte-for-byte current behavior; explicit `3` likewise.
- CR-007 (config-key read): value read at Step 0 with documented default, matching the existing config-read idiom.

- [x] **[Implement]** Read+resolve qa_max_iterations and thread it into the five sites
  - Order: Step 0 read+resolve first (defines the value), then the five site edits.
  - Architecture constraints: resolution signal is the plan front-matter `tdd:` field (already loaded); `auto` → 5 if `tdd: false`, 3 if `tdd: true`.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Step 0 config-read region (alongside L236 idiom and the Phase-4 model_policy read)
  - Target: add "Read the `qa_max_iterations` key from `.spec-flow.yaml` (valid values: `auto`, or a positive integer; default `auto` when absent/unset — NN-C-003; malformed → one-line warning + `auto`). Resolve `auto` from the plan front-matter `tdd:` field: `tdd: false` → 5, `tdd: true` → 3. Hold the resolved integer `L` in orchestrator state; all five QA-agent fix-loops use `L` as their circuit-breaker limit. This does NOT govern the oracle 2-attempt build budget or the mechanical SKILL self-lint loop."
  - Done: execute resolves `L` at Step 0.
  - Verify: `grep -n "qa_max_iterations" plugins/spec-flow/skills/execute/SKILL.md` returns the Step 0 read.

  **T-2: MODIFY plugins/spec-flow/skills/execute/SKILL.md** (Mid-piece, Step 0a)
  - Anchor: line 320
  - Current:
    ```
    320     - **Circuit breaker:** 3 iterations maximum. On third circuit-breaker hit, surface to human and do NOT auto-resume.
    ```
  - Target: replace "3 iterations maximum. On third circuit-breaker hit" with "`qa_max_iterations` (`L`) iterations maximum. On the `L`-th circuit-breaker hit".
  - Done: site reads `L`, no hard "3".
  - Verify: `grep -n "qa_max_iterations\|(\`L\`) iterations maximum" plugins/spec-flow/skills/execute/SKILL.md` matches near L320.

  **T-3: MODIFY plugins/spec-flow/skills/execute/SKILL.md** (Per-phase qa-phase, Step 6)
  - Anchor: line 846
  - Current:
    ```
    846     - **Circuit breaker:** 3 iterations max, then escalate.
    ```
  - Target: replace "3 iterations max" with "`qa_max_iterations` (`L`) iterations max".
  - Done / Verify: `grep -n "iterations max, then escalate" ...` — the surviving line references `L`, not `3`.

  **T-4: MODIFY plugins/spec-flow/skills/execute/SKILL.md** (qa-phase-lite, Group QA-lite)
  - Anchor: line 1230 (inline "3-iter circuit breaker")
  - Current:
    ```
    1230  - QA-lite step — ... Iter-until-clean per `plugins/spec-flow/reference/qa-iteration-loop.md` — full review on iter-1, focused re-review on iter-2+, 3-iter circuit breaker.
    ```
  - Target: replace "3-iter circuit breaker" with "`qa_max_iterations`-limited circuit breaker (per qa-iteration-loop.md)".
  - Done / Verify: `grep -n "qa_max_iterations-limited" ...` matches near L1230.

  **T-5: MODIFY plugins/spec-flow/skills/execute/SKILL.md** (Group Deep QA, Step G8)
  - Anchor: line 1278
  - Current:
    ```
    1278  If Group Deep QA returns must-fix: run the iter-until-clean loop per plugins/spec-flow/reference/qa-iteration-loop.md (no skip; 3-iter circuit breaker), dispatching fix-code agents for findings. ...
    ```
  - Target: replace "3-iter circuit breaker" with "`qa_max_iterations`-limited circuit breaker".
  - Done / Verify: `grep -n "qa_max_iterations-limited" ...` matches near L1278.

  **T-6: MODIFY plugins/spec-flow/skills/execute/SKILL.md** (Final Review fix loop, Step 3)
  - Anchor: line 1580
  - Current:
    ```
    1580  - **Circuit breaker:** 3 full review cycles maximum.
    ```
  - Target: replace "3 full review cycles maximum" with "`qa_max_iterations` (`L`) full review cycles maximum (the pi-011 doc-as-code default raises `L` to 5)".
  - Done / Verify: `grep -n "full review cycles maximum" ...` — the surviving line references `L`, not a bare "3".

  **T-7: MODIFY plugins/spec-flow/skills/execute/SKILL.md** (Escalation Rules summary)
  - Anchor: line 1818
  - Current:
    ```
    1818  - 3+ QA loops on same finding → escalate (architectural issue)
    ```
  - Target: replace "3+ QA loops" with "`qa_max_iterations`+ QA loops".
  - Done / Verify: `grep -n "qa_max_iterations+ QA loops" ...` matches near L1818.

- [x] **[Verify]** Confirm all five sites + summary read the configured value and no stray hard-3 remains
  **Per-change checks:**
  - T-1: `grep -c "qa_max_iterations" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥7 (Step 0 read + 5 sites + escalation summary).
  - T-2..T-6 (anti-drift sweep — superseded "3" tokens at breaker sites): LLM-agent-step: read lines 318–322, 844–848, 1228–1232, 1276–1280, 1578–1582 of `execute/SKILL.md` and confirm NONE of the five breaker statements still says a bare "3 iterations"/"3 full review cycles"/"3-iter" as the limit — Expected: 0 surviving hard-3 limits at these five sites. (Note: other unrelated "3" usages elsewhere — e.g. the self-lint loop, "≥3 headings" — are out of scope and must remain.)
  **Phase-level check:**
  - Run: LLM-agent-step: read the Step 0 resolution prose and confirm `auto` → 5 when `tdd: false`, 3 when `tdd: true`, explicit int overrides, and the oracle 2-attempt budget + self-lint are named as NOT governed — Expected: all confirmed.
  - Failure: any breaker site still hard-codes 3 as its limit, or the oracle budget/self-lint were wrongly parameterized.

- [x] **[QA]** Phase review
  - Review against: AC-5, AC-6
  - Diff baseline: git diff {{phase_5_start}}..HEAD

### Phase 6: Execute — file-based resume + `[STATE-INCOMPLETE]`
**Exit Gate:** Session Resumability + Escalation Rules emit `[STATE-INCOMPLETE: <field>]` and escalate for tier-1 expected-but-missing fields; the L1837 "no journal → fresh start" path is refined to tier-3 (valid absence only when no group is in flight); a worked input→output trace is present; `grep` confirms the marker and the citation.
**ACs Covered:** AC-7 (resume from disk, no re-run), AC-8 (STATE-INCOMPLETE predicate — escalate vs continue branches)
<!-- Branch-enumeration ACs (doc-as-code §3): the resume classifier has three branches — tier-1 (expected-present+missing → escalate), tier-2 (recompute → continue), tier-3 (valid absence / cosmetic → continue). AC-8 covers the escalate branch AND the valid-absence/cosmetic continue branch; AC-7 covers the recompute/normal-resume path. All branches covered. -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — Session Resumability (L1826–1841, esp. the L1837 no-journal bullet) + Escalation Rules (L1815–1824)
**NOT in scope:** changing the journal schema (`deferred-commit-journal.md` unchanged); the L932 defensive-default for cosmetic discovery fields (preserved, not edited); model policy / breaker / return discipline (other phases)
**Steps traversed (P2):** `## Session Resumability` (L1826–1841) — specifically the mid-group resume algorithm bullets (L1835–1841): the new tier-1 check is inserted BEFORE the existing "No journal → fresh group start" bullet (L1837), which is retained as the tier-3 valid-absence branch; `## Escalation Rules` (L1815–1824) gains the STATE-INCOMPLETE line. The existing green-subphase (L1839) / incomplete (L1840) / absent (L1841) bullets are unchanged.
**Dispatch sites (P3):** none — resume-position logic only; no agent dispatch changed.
**Charter constraints honored in this phase:**
- NN-C-005 (silent no-op on valid absence): tier-3 (no group in flight; cosmetic fields) continues without error; only tier-1 escalates.
- NN-P-003 (operator-invoked): STATE-INCOMPLETE surfaces to the operator and halts; the coordinator never auto-guesses resume position.
- NN-C-006 (passive surface for recovery actions): the existing reset/orphan logging is preserved.

- [x] **[Implement]** Add the STATE-INCOMPLETE escalation and refine the no-journal branch
  - Architecture constraints: cite the field-tier table + "group in flight" predicate in `coordinator-contract.md`; do NOT duplicate the table in execute. Insert the tier-1 check before the existing fresh-start bullet; preserve all existing bullets.
  <!-- Dense-algorithm guard (§2c): this edits the multi-step resume algorithm prose — the phase MUST add an inline worked input→output trace (below) and a [Verify] that confirms it is present. -->

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: Mid-group resume, the no-journal bullet (line 1837)
  - Current:
    ```
    1837    - **No journal → fresh group start** (NN-C-005). This is not an error — it is the normal case for a group that never began. Proceed to Step G1 (write a fresh journal) and run the group from scratch.
    ```
  - Target: insert a NEW bullet BEFORE line 1837, and qualify the existing bullet:
    - New tier-1 bullet: "**No/corrupt journal WHILE a group is in flight → `[STATE-INCOMPLETE: journal]`, escalate.** Per the field-tier table in `plugins/spec-flow/reference/coordinator-contract.md` `## Resume-Critical State`, a journal is *expected-present* when the active group is *in flight* — plan.md shows ≥1 checked sub-phase step under the group AND the group-level `[Progress]` checkbox is unchecked. If the journal is then missing or corrupt, the coordinator MUST emit `[STATE-INCOMPLETE: journal]` and escalate to the operator rather than guessing which sub-phases are green. Worked trace: group B with `B.1 [Build] = [x]` and group `[Progress] = [ ]` ⇒ in flight ⇒ missing journal ⇒ escalate; group B with no checked sub-phase steps ⇒ not in flight ⇒ missing journal ⇒ fresh start (next bullet)."
    - Qualify the existing bullet: change "**No journal → fresh group start**" to "**No journal AND no group in flight → fresh group start (tier-3 valid absence)**" (rest of the bullet unchanged).
  - Done: a tier-1 escalation bullet precedes a tier-3 fresh-start bullet; the predicate + worked trace are inline; `coordinator-contract.md` is cited.
  - Verify: `grep -n "STATE-INCOMPLETE: journal" plugins/spec-flow/skills/execute/SKILL.md` returns ≥1; `grep -n "no group in flight → fresh group start" ...` returns the qualified bullet.

  **T-2: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: `## Escalation Rules` list (lines 1815–1824)
  - Current:
    ```
    1817  - Agent reports BLOCKED → escalate to human
    1818  - 3+ QA loops on same finding → escalate (architectural issue)
    ```
  - Target: add a new bullet to the Escalation Rules list: "- Resume-critical state missing/corrupt when expected-present (tier-1 per `reference/coordinator-contract.md`) → emit `[STATE-INCOMPLETE: <field>]` and escalate; do NOT guess. (Valid absences and cosmetic fields do not escalate — see the field-tier table.)"
  - Done: Escalation Rules names the STATE-INCOMPLETE tier-1 rule and cites the tier table.
  - Verify: `grep -n "STATE-INCOMPLETE: <field>" plugins/spec-flow/skills/execute/SKILL.md` returns ≥1 in the Escalation Rules region.

- [x] **[Verify]** Confirm the escalation, the refinement, and the worked trace
  **Per-change checks:**
  - T-1: `grep -c "STATE-INCOMPLETE: journal" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1; `grep -c "no group in flight → fresh group start" ...` — Expected: 1 (the qualified tier-3 bullet).
  - T-1 (dense-algorithm worked-example present): `grep -n "Worked trace: group B" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 (concrete input→output trace present).
  - T-2: `grep -n "STATE-INCOMPLETE: <field>" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 in Escalation Rules.
  **Phase-level check:**
  - Run: LLM-agent-step: read the mid-group resume bullets and confirm (a) tier-1 escalation precedes the tier-3 fresh-start bullet, (b) the L932 cosmetic defensive-default is NOT removed (still says "Do NOT halt or escalate on missing fields"), (c) the green/incomplete/absent bullets are unchanged — Expected: all confirmed.
  - Failure: fresh-start path unconditional (no in-flight qualifier), missing worked trace, or L932 behavior altered.

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-8
  - Diff baseline: git diff {{phase_6_start}}..HEAD

### Phase 7: Execute — lean coordinator return discipline + audit
**Exit Gate:** execute carries a "Coordinator Return Discipline" section (citing `coordinator-contract.md`) and an audit table classifying each dispatch's return shape; every dispatch row is compliant or carries a correction directive; `grep` confirms the section + table.
**ACs Covered:** AC-4 (return discipline + audit)
<!-- Branch-enumeration ACs (doc-as-code §3): the audit has one decision per row — compliant vs needs-correction. AC-4 covers both outcomes (every row is "compliant or corrected"). -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — add a "Coordinator Return Discipline" subsection under "The Orchestrator Role" (after L124) + an audit table
**NOT in scope:** changing any agent's actual return contract beyond a correction directive where a dispatch currently instructs a raw dump; the reference-doc contract itself (Phase 1 authored it)
**Steps traversed (P2):** `## The Orchestrator Role` (L112–124) — the new subsection is appended here; the audit table references the dispatch sites across Step 2 (tdd-red), Step 3 (implementer), Step 4 (verify), Step 5/G7 (refactor), Step 6/Step 0a/G8 (qa-phase, fix-code), Final Review Step 2 (board), Step 4.5 (reflection), and the research dispatch (pre-spec). These are enumerated as audit rows, not re-sequenced.
**Dispatch sites (P3):** the audit DOCUMENTS every (re-)dispatch site of the phase/end-of-piece agents but changes no dispatch contract — a row only gets a correction directive if it currently instructs a raw dump. List of audited dispatch sites: tdd-red (L411), qa-tdd-red (L455), implementer (L509), verify (L688), refactor (L749), qa-phase (L828), mid-piece qa-phase (L312), qa-phase-lite (L1230), fix-code (L317/L1570), review-board ×8 (L1520-1527), reflection ×2 (L1675-1676).
**Charter constraints honored in this phase:**
- CR-008 (thin orchestrator): the discipline cites the reference contract; it adds a documentation surface, not orchestration logic.
- NN-C-008 (self-contained agents): the audit confirms returns are bounded summaries; it does not introduce any conversation-history assumption.
- NN-C-003 (backward-compat): existing return shapes that are already bounded are marked compliant — no behavior change.

- [x] **[Implement]** Add the return-discipline section and the audit table
  - Architecture constraints: cite `coordinator-contract.md` `## Coordinator Return Discipline`; the audit is a markdown table the review board can diff against the dispatch prose.

  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/skills/execute/SKILL.md**
  - Anchor: end of `## The Orchestrator Role` (after line 124 "Synthesis and code-writing still come from subagents.")
  - Current:
    ```
    124  You write ZERO implementation code. Fact-gathering probes (`wc`, `head`, `git grep`, reading `.pre-commit-config.yaml`) are explicitly part of the conductor role — they are cheap reads that collapse 5–15 agent tool calls per dispatch. Synthesis and code-writing still come from subagents.
    ```
  - Target: insert a new subsection `### Coordinator Return Discipline` after L124:
    - Contract prose: "To stay lean over long pieces (G-4), the coordinator consumes **bounded, structured** agent returns. Every agent return to the coordinator MUST be a bounded summary; raw artifacts — full diffs, full test output, file bodies — live on disk or git and are referenced by path, never pasted into the coordinator's context. See `plugins/spec-flow/reference/coordinator-contract.md` `## Coordinator Return Discipline`."
    - Audit table:
      ```
      | Dispatch | Return shape today | Compliant? |
      |----------|--------------------|-----------|
      | research (pre-spec) | ≤2K structured digest; richer artifact on disk | ✓ |
      | tdd-red | staged-test manifest (paths + SHA) + summary | ✓ |
      | qa-tdd-red | theater-pattern verdict list | ✓ |
      | implementer | unified-commit SHA + AC matrix + deviations summary | ✓ |
      | verify | pass/fail + AC coverage summary | ✓ |
      | refactor | changed-files summary | ✓ |
      | qa-phase / qa-phase-lite / mid-piece | must-fix/should-fix finding list | ✓ |
      | fix-code | `## Diff of changes` (bounded diff the orchestrator applies) | ✓ |
      | review-board (×8–9) | per-reviewer finding list by severity | ✓ |
      | reflection (×2) | findings appended to backlog file; short summary returned | ✓ |
      ```
    - Correction directive note: "Any dispatch that instructs an agent to paste a raw full diff, full test output, or a file body into its return is a defect — convert it to a bounded summary + on-disk reference. (Audit on authoring: all current dispatches return bounded summaries.)"
  - Done: the subsection + audit table exist; every dispatch row is marked ✓ (or carries a correction directive if a raw-dump instruction is found during the audit).
  - Verify: `grep -n "Coordinator Return Discipline" plugins/spec-flow/skills/execute/SKILL.md` returns the subsection; the audit table lists every phase/end-of-piece agent.

- [x] **[Verify]** Confirm the discipline section and audit completeness
  **Per-change checks:**
  - T-1: `grep -n "Coordinator Return Discipline" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥1 (execute) — and the citation to `coordinator-contract.md` present.
  - T-1 (audit completeness): LLM-agent-step: read the audit table and confirm it has a row for each of {research, tdd-red, qa-tdd-red, implementer, verify, refactor, qa-phase/lite/mid-piece, fix-code, review-board, reflection} and that no remaining dispatch in execute instructs pasting a raw full diff/test output/file body into a return — Expected: all rows present; no raw-dump instruction found.
  **Phase-level check:**
  - Run: LLM-agent-step: confirm the discipline cites `coordinator-contract.md` and states "referenced by path, never pasted into the coordinator's context" — Expected: confirmed.
  - Failure: missing section, incomplete audit, or a surviving raw-dump-return instruction left unflagged.

- [x] **[QA]** Phase review
  - Review against: AC-4
  - Diff baseline: git diff {{phase_7_start}}..HEAD

### Phase 8: Version bump (5.5.0 → 5.6.0) + CHANGELOG
**Exit Gate:** all four version-bearing files read `5.6.0` identically; CHANGELOG has a `## [5.6.0] — <date>` section with non-empty groupings; the `docs/releasing.md` sync recipe passes.
**ACs Covered:** AC-9 (version bump + sync)
<!-- Branch-enumeration ACs: no conditional branches in this phase — a straight 4-file bump + CHANGELOG section. -->
**In scope:** MODIFY `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (spec-flow entry), `plugins/spec-flow/CHANGELOG.md`
**NOT in scope:** any behavior change (Phases 1–7); the marketplace `qa` plugin entry (unrelated, stays 1.1.1)
**Why serial:** runs LAST — NN-C-009 + the post-CHANGELOG re-verify rule (execute L1583) require the version/CHANGELOG to land after all behavior changes so the CHANGELOG describes the final diff.
**Charter constraints honored in this phase:**
- NN-C-009 (bump all version-bearing files): all four files bumped to 5.6.0 in one phase; minor tier (new opt-out capabilities).
- NN-C-001 (version ⇄ marketplace sync): marketplace entry bumped in lockstep with plugin.json.
- NN-C-007 (CHANGELOG format): Keep a Changelog groupings (Added / Changed) under `## [5.6.0]`.

- [x] **[Implement]** Bump the four files
  **Change Specifications:**

  **T-1: MODIFY plugins/spec-flow/plugin.json**
  - Anchor: `"version"` field
  - Current: `"version": "5.5.0"`
  - Target: `"version": "5.6.0"`
  - Done / Verify: `grep '"version"' plugins/spec-flow/plugin.json` → `5.6.0`.

  **T-2: MODIFY plugins/spec-flow/.claude-plugin/plugin.json**
  - Current: `"version": "5.5.0"` → Target: `"version": "5.6.0"`
  - Verify: `grep '"version"' plugins/spec-flow/.claude-plugin/plugin.json` → `5.6.0`.

  **T-3: MODIFY .claude-plugin/marketplace.json**
  - Anchor: the `spec-flow` entry's `"version"` field (NOT the `qa` entry)
  - Current: spec-flow entry `"version": "5.5.0"` → Target: `"version": "5.6.0"`
  - Verify: `jq -r '.plugins[]|select(.name=="spec-flow")|.version' .claude-plugin/marketplace.json` → `5.6.0`.

  **T-4: MODIFY plugins/spec-flow/CHANGELOG.md**
  - Anchor: immediately after the `## [Unreleased]` section (line ~5) and before `## [5.5.0]` (Keep a Changelog ordering: newest released version directly under Unreleased)
  - Target: insert a `## [5.6.0] — <commit date>` section there with groupings:
    - **Added:** `model_policy` (auto|off) config key + per-stage model-policy report in execute citing `reference/coordinator-contract.md`; `qa_max_iterations` (auto|<int>) config key governing the five QA-agent fix-loops (auto = 5 doc-as-code / 3 TDD); new `reference/coordinator-contract.md` (model policy, return discipline, resume-critical field tiers); `[STATE-INCOMPLETE: <field>]` resume escalation; coordinator return-discipline contract + audit.
    - **Changed:** Final Review + per-phase/mid-piece/group/lite QA breakers now read `qa_max_iterations` (default 3); `reference/qa-iteration-loop.md` parameterized; mid-group resume refined to distinguish in-flight (escalate) from valid-absence (fresh start).
  - Done / Verify: `grep -n "## \[5.6.0\]" plugins/spec-flow/CHANGELOG.md` returns the new top section with ≥1 Added and ≥1 Changed bullet.

- [x] **[Verify]** Cross-phase version-sync consistency oracle (schema-bearing: 4 version strings must agree)
  **Per-change checks:**
  - T-1..T-3: `grep -h '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` and `jq -r '.plugins[]|select(.name=="spec-flow")|.version' .claude-plugin/marketplace.json` — Expected: all three print `5.6.0`.
  - T-4: `grep -n "## \[5.6.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: 1 match at the top.
  **Phase-level cross-phase check (FR-PROC-01 / §2d — version is a schema-bearing invariant across 4 files):**
  - Run: the `docs/releasing.md` sync recipe — `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` + the marketplace `jq` + the CHANGELOG header — Expected: all four sources print/contain `5.6.0`; no file left at 5.5.0.
  - Failure: any of the four reads ≠ 5.6.0 (the NFR-004 sync invariant is violated).

- [x] **[QA]** Phase review
  - Review against: AC-9
  - Diff baseline: git diff {{phase_8_start}}..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Model policy declared + reported; exactly two flagged exceptions | COVERED | Phase 1, Phase 4 |
| AC-2 | `model_policy: off` preserves legacy Pre-flight prompt, no report | COVERED | Phase 4 |
| AC-3 | No silent Opus upgrade outside the two exceptions | COVERED | Phase 1, Phase 4 |
| AC-4 | Lean return discipline contract + audit table | COVERED | Phase 1, Phase 7 |
| AC-5 | Configurable breaker — auto = 5 doc-as-code / 3 TDD; explicit int | COVERED | Phase 2, Phase 3, Phase 5 |
| AC-6 | Breaker backward-compat — absent + TDD → 3, semantics unchanged | COVERED | Phase 2, Phase 3, Phase 5 |
| AC-7 | Resume from disk, no passing-phase re-run; field-tier homes | COVERED | Phase 1, Phase 6 |
| AC-8 | `[STATE-INCOMPLETE]` predicate (escalate vs continue) | COVERED | Phase 1, Phase 6 |
| AC-9 | Version bump 5.6.0 across 4 files + CHANGELOG; sync verified | COVERED | Phase 8 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | agent-step | Read `coordinator-contract.md` model table + diff against in-execute `model:` dispatch sites | Every in-execute row agrees; exactly 2 flagged exceptions |
| AC-2 | shell | `grep -n "model_policy: off" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 match (legacy-preserving branch) |
| AC-3 | agent-step | Read execute; confirm no non-`[SPIKE]` stage upgrades to Opus without operator override | No such path found |
| AC-4 | shell | `grep -n "Coordinator Return Discipline" plugins/spec-flow/skills/execute/SKILL.md` | ≥1 (section) + audit table present |
| AC-5 | agent-step | Read Step 0 resolution + the five breaker sites | auto→5(tdd:false)/3(tdd:true); all five read `L` |
| AC-6 | agent-step | Read `qa-iteration-loop.md` + breaker sites with absent key + tdd:true | Limit resolves to 3; escalate-on-limit-th semantics intact |
| AC-7 | agent-step | Read `coordinator-contract.md` field-tier table | Every resume-critical field has an on-disk home or recompute source |
| AC-8 | shell | `grep -c "STATE-INCOMPLETE" plugins/spec-flow/skills/execute/SKILL.md` | ≥2 (resume bullet + Escalation Rules) |
| AC-9 | shell | `grep -h '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` + marketplace jq | all print `5.6.0` |

## Contracts

No TDD-track phases in this plan (all phases are Implement track; `tdd: false`) — contracts section present for forward compatibility. `tdd-red` agents will not be dispatched; no contract injection occurs. Note: the boundary-crossing surfaces this piece touches (the two config keys, the model-policy table, the field-tier table) are documentation/config contracts captured canonically in `reference/coordinator-contract.md` and `templates/pipeline-config.yaml`, not code interfaces.

## Parallel Execution Notes

All phases run serially. Phases 1–3 touch disjoint files but are sequenced for citation order (see each phase's `Why serial:`). Phases 4–7 all edit the single `execute/SKILL.md` and therefore cannot parallelize (shared-file contention). Phase 8 runs last by NN-C-009 / post-CHANGELOG re-verify ordering. No Phase Groups, no `[P]` tasks, no Phase 0 Scaffold (no parallel coordination-file contention).

## Agent Context Summary
| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, plan [Implement] tasks (T-N Change Spec Blocks), spec ACs, plan's [Verify] command, arch constraints, pattern pointers, `introspection.md` anchors for the phase scope | Spec rationale, brainstorming history |
| Verify | Verification output (grep / LLM-agent-step / `jq` results per the [Verify] block), spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections | Any agent conversation history |
| fix-doc (QA-loop) | qa-plan must-fix findings + plan.md + context | — (returns `## Diff of changes`, does not commit) |
