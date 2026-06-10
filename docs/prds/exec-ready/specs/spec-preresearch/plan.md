---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
legacy_deferred_rows: false
tdd: false
fast: false
---

# Plan: spec-preresearch — Investigation-First Design Protocol (Spec 2.0)

**Spec:** docs/prds/exec-ready/specs/spec-preresearch/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** draft

## Overview

Non-TDD mode: all phases use the Implement track (`[Implement]` → `[Verify]` → `[QA]`); there are no `[TDD-Red]`/`[Build]`/`[Write-Tests]` steps because this is a markdown/JSON/YAML plugin with no test runner (charter-tools). Verification is by-inspection — `ls`/`grep`/`jq`/`diff` structural assertions on the agent/skill/reference prose plus the `releasing.md` version recipe — supplemented by `qa-spec`/`qa-plan` adversarial review and the end-of-piece Final Review board. The spec's own Testing Strategy names one manual smoke (`/spec-flow:spec` on a scratch piece) as the only live run; it is documented in Phase 7's `[Verify]` as an operator step, not an automated gate. **AC Coverage Matrix IS included** (25 ACs: AC-1…AC-24 + AC-10b) because the spec enumerates 25 grep-verifiable ACs and the matrix is the cleanest binding guarantee; QA and Final Review remain fully intact.

Build order is inside-out / cite-before-use, exactly mirroring the `spike-agent` precedent (define-once contract doc first, consumers after):

1. **Contracts first** — `reference/deliberation-artifact.md` (Phase 1) and `reference/deliberation-depth.md` + the `.spec-flow.yaml` key (Phase 2) define the artifact schema, marker contract, VOQ/Validation-Round contracts, and depth policy. Every later file cites these and restates nothing (the `reference/research-artifact.md` ↔ `agents/research.md` idiom).
2. **Agents** — the five Tier-1 deliberation agents (Phases 3–4) and the Tier-2 `deliberation-validate` agent (Phase 5), each a structural clone of `agents/research.md` citing the Phase-1 contract.
3. **Shared brainstorm logic** — `reference/brainstorm-procedure.md` (Phase 6) gains the deliberation invocation-order item, the Tier-2 answer-validation loop, the C-2 "never silently skip" amendment, and the mandatory-block skip logic. This lives once and is cited by all four calling skills.
4. **Skill wiring, one file per phase** — `spec` (Phase 7), `prd` (Phase 8), `charter` (Phase 9), `small-change` (Phase 10), `plan` (Phase 11). Each skill file is touched in exactly one phase (its pre-flight + dispatch/consumption together), so no two phases contend on the same SKILL.md and each gets a clean per-phase diff baseline.
5. **QA + PRD + release** — `agents/qa-spec.md` criteria 14/15 + the cross-phase schema-consistency check (Phase 12); `prd.md` FR-009 + NN-P-005 Scope + `manifest.yaml` coverage (Phase 13); the 5.7.0 → 5.8.0 version bump (Phase 14, last — the CHANGELOG describes the finished piece).

Everything is additive (NN-C-003): a piece whose skills do not dispatch deliberation, the optional `.spec-flow.yaml deliberation.depth` key when absent, `depth=off`, the `[DELIBERATION-UNAVAILABLE]` fallback, and FR-009-N's silent-proceed-when-already-Opus path each reproduce pre-5.8.0 behavior.

**Why serial, not Phase Groups (parallel-by-default deviation — declared).** Many phases touch disjoint files (six agent files; two reference docs; five skill files) and could in principle parallelize after the Phase-1/2 contracts land. They are kept **serial** deliberately, for three reasons, declared once here and on a `Why serial:` line per affected phase: (a) **cite-before-use** — agents (3–5) cite the Phase-1/2 contracts; skill wiring (7–11) cites the Phase-6 loop and the agents; the dependency chain forbids reordering; (b) **per-phase Opus QA audit value** — every edit here adds to a shipped, merged plugin contract surface (the same audit reason `spike-agent` cited), and a Phase Group defers QA to the group level; (c) **negligible wall-clock** — these are small markdown edits; the fan-out savings do not justify losing phase-by-phase regression catching on cross-cutting brainstorm wiring. No Phase Groups; no Phase 0 Scaffold (the file-per-phase decomposition means no shared coordination file is appended by ≥2 phases, so there is no contention to scaffold away).

**Cross-cutting charter constraints (declared, not allocation drift).** Several entries are honored in more than one phase because each phase honors a *distinct facet*; the per-phase slot names which: **NN-C-002** (no runtime deps) — every new `.md`/config file (Phases 1–6, 13) and the JSON version files (Phase 14); **NN-C-003** (backward-compat) — the optional depth key + `off` path (Phase 2), the UNAVAILABLE fallback wiring (Phases 7–10), the silent-proceed pre-flight (Phases 7–9, 11), the additive consumption marker (Phase 11); **NN-C-004** (bare agent name) — each of the six agent files (Phases 3–5); **NN-C-008** (self-contained agent prompt) — each agent (Phases 3–5) and each new dispatch site (Phases 7–11); **CR-001** (agent frontmatter `model: opus`) — Phases 3–5; **CR-008** (thin orchestrator / narrow executor) — the agents do one phase each (3–5) and the skills orchestrate (7–11); **CR-009** (heading hierarchy) — every file-editing phase; **NN-P-001** (human gate preserved) — the question gate (Phase 7), the FLAG-HARD/FLAG-SOFT override rule (Phase 6), the always-can-Override pre-flight (Phases 7–9, 11); **NN-P-005** (Opus thinking) — every agent is `model: opus` (Phases 3–5) and the Scope provenance edit lands in Phase 13.

## Architectural Decisions

### ADR-1: Single-model, multi-lens adversarial board — NOT a multi-model council
**Context:** Phase D stress-tests the recommendation. Karpathy's LLM Council uses *model* diversity (different architectures cross-review). NN-P-005 places "all adversarial gates" on Opus.
**Decision:** Phase D is five Opus `deliberation-lens` instances, each injected a distinct lens label (architecture-integrity | scope/simplicity | user-intent | backward-compat | risk). Diversity comes from the *lens dimension*, not the model. One agent file with a `{lens}` parameter slot, dispatched five times at `full` depth.
**Alternatives considered:** (a) True multi-model council (non-Opus reviewers) — rejected: adversarial review is thinking work; a non-Opus reviewer violates NN-P-005 (recorded in `design-basis.md` §D-1). (b) Five separate lens agent files — rejected: duplicates the identical contract five times; a parameter slot is one file to maintain.
**Consequences:** Dimension diversity without a charter carve-out; the calling skill owns the five-way fan-out + barrier. Revisit only if a charter exception for non-thinking "cross-check" review is ever added.
**Charter alignment:** NN-P-005 (Opus thinking), CR-008 (single-task agent), CR-001/NN-C-004 (frontmatter, bare name).

### ADR-2: `reference/deliberation-artifact.md` is the define-once single source of truth
**Context:** The 7-section `deliberation.md` schema, the four markers, the VOQ-N IDs, and the Validation-Round format are referenced by six agents, four calling skills, the plan skill, and qa-spec. Restating them anywhere invites drift.
**Decision:** All schema/marker/contract detail lives in `reference/deliberation-artifact.md` (Phase 1); every agent and skill *cites, never restates* — exactly the `reference/research-artifact.md` ↔ `agents/research.md` ↔ `skills/{spec,plan}/SKILL.md` idiom already in the codebase.
**Alternatives considered:** (a) Inline the schema in the convergence agent — rejected: the plan skill and qa-spec also need it; three copies drift. (b) Put markers in `brainstorm-procedure.md` — rejected: splits the contract across two files.
**Consequences:** A cross-phase schema-consistency check (Phase 12 `[Verify]`) is required to prove the citers agree with the SoT. One file to change if the schema evolves.
**Charter alignment:** CR-008 (separation — definitions vs orchestration), CR-009 (heading hierarchy mirrors research-artifact.md).

### ADR-3: Opus pre-flight is a structural mirror-inverse of execute's Sonnet check
**Context:** FR-009-N wants spec/prd/plan/charter to recommend Opus, the inverse of execute's Step-0 Sonnet block (`execute/SKILL.md` L13–45).
**Decision:** Copy execute's pre-flight block into each of the four skills verbatim-by-structure, inverting `sonnet`→`opus`, the warning text, and the cancel label. Three choices preserved (Override always proceeds → no hard refusal; Change-now; Cancel); silent no-op when already Opus. small-change is excluded (lite, single-session — a pre-flight would be disproportionate).
**Alternatives considered:** (a) A new shared `reference/model-preflight.md` both checks cite — rejected as out-of-scope scope-creep for this piece (execute's block is not refactored to cite it either; introducing the abstraction now touches execute, which the spec excludes). (b) A passive one-line advisory — rejected: AC-24 requires an interactive `ask_user` with three choices, mirroring execute.
**Consequences:** Four near-identical blocks (acceptable duplication; matches the existing execute precedent which is itself standalone). If execute's block changes later, the four copies must follow — noted for the flywheel.
**Charter alignment:** NN-P-005 (thinking on Opus), NN-P-001 (Override always proceeds — operator is the authority).

### ADR-4: Tier-2 `deliberation-validate` reuses the spike `scope`-mode contract shape
**Context:** Tier 2 validates a single operator free-form assertion at brainstorm time. `agents/spike.md` `scope` mode already is an isolated Opus pass that reads a change + context, investigates, and returns a structured digest.
**Decision:** `deliberation-validate` clones the spike-scope structural shape (isolated Opus, ≤2K digest, STATUS OK/BLOCKED, no-partial-on-BLOCKED, no sub-agents) but returns CONFIRM | FLAG-HARD | FLAG-SOFT (not a scope classification) and appends a Validation Round to `deliberation.md`. It cites `reference/deliberation-artifact.md` for the Validation-Round schema.
**Alternatives considered:** (a) Extend `agents/spike.md` with a third `validate` mode — rejected: spike is dispatched by *execute*; validate is dispatched by the *calling skill at brainstorm time* — different lifecycle, different artifact; folding them couples two pipelines. (b) Reuse `deliberation-lens` — rejected: lens reviews the AI's recommendation; validate reviews the operator's assertion against charter/NN + prior art — a different input and a different verdict vocabulary.
**Consequences:** A sixth agent file; one more contract, but a clean lifecycle boundary. BLOCKED returns no verdict and the skill accepts the answer unvalidated (non-blocking).
**Charter alignment:** NN-P-005 (Opus thinking), NN-P-001 (FLAG-HARD no-override honors the binding NN set; operator signs off), CR-008.

### ADR-5: File-per-skill phase decomposition (each SKILL.md touched once)
**Context:** spec/prd/charter/plan each receive both an Opus pre-flight (skill-start) and a deliberation dispatch/consumption (pre-brainstorm / Phase 1). These are two regions of one file.
**Decision:** Bundle all of a skill file's edits into one phase (pre-flight + dispatch together). Each SKILL.md is modified in exactly one phase.
**Alternatives considered:** (a) A dedicated "Opus pre-flight across 4 skills" phase + separate dispatch phases — rejected: makes four SKILL.md files cross-phase-shared (pre-flight phase + dispatch phase both edit them), creating contention and split diff baselines for no benefit. (b) One mega "all skill wiring" phase — rejected: would blow the 150-line phase-size threshold and bundle five distinct files into one un-reviewable diff.
**Consequences:** Five skill phases (7–11) instead of fewer; each is small, single-file, cleanly reviewable, and contention-free. AC-24 spreads across Phases 7/8/9/11 (one pre-flight per file).
**Charter alignment:** CR-009, NN-C-003 (each edit additive within its file).

## Phases

## Integration-Test Registry

None in scope. The spec's `## Integration Coverage` entries (the 5-agent protocol → each of spec/prd/small-change/charter; `deliberation.md` → plan; `deliberation-validate` → brainstorm-procedure; depth-config → the four skills; Opus pre-flight → four skills) are **in-plugin documentary contracts** with no true external to double and no executable outer wired-path test (markdown/JSON/YAML plugin; charter-tools — no test runner). The "doubled externals" the spec lists (WebSearch/WebFetch, git commit/read, config read) are platform primitives, not project code with a contract to stub. Each integration is verified by reading producer + consumer for schema/branch agreement (the by-inspection `[Verify]` blocks below + the Phase-12 cross-phase schema-consistency check) and, for the end-to-end protocol, the single operator smoke in Phase 7's `[Verify]`. No `completes_in_phase` markers, no contract tests.

### Phase 1: Artifact contract — `reference/deliberation-artifact.md`
**Exit Gate:** `reference/deliberation-artifact.md` exists and is the single source of truth for: the `deliberation.md` location; the 7 core H2 sections (+ optional 8th `## Validation Rounds`) in order; the §Viability Analysis per-decision-unit table format (with reuse-path flag + NON-VIABLE blocker column); the VOQ-N ID contract; the Validation-Round subsection format; the four markers (`[DELIBERATION-UNAVAILABLE]` with its 5 fatal triggers + 2 non-fatal partials, `[DELIBERATION-SKIPPED]`, `[DELIBERATION-CONSUMED]`, `[DELIBERATION-ABSENT]`); and the ≤2K/STATUS return contract. `grep` confirms each section header present.
**ACs Covered:** AC-7 (artifact structure SoT + `ls` target), AC-12 (marker-trigger definitions), AC-13 (7-section structure def + optional-8th tolerance that qa-spec cites), AC-20 (VOQ-N contract def), AC-23 (Validation-Rounds contract def)
**In scope:** CREATE `plugins/spec-flow/reference/deliberation-artifact.md` only.
**NOT in scope:** the agent files that write/cite it (Phases 3–5); the depth policy (Phase 2); skill marker-emission wiring (Phases 7–11); the qa-spec criterion that checks the structure (Phase 12 — cites this doc, does not restate).
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): pure markdown, no tooling introduced.
- CR-009 (heading hierarchy): H2/H3 structure mirroring `reference/research-artifact.md`.
- CR-008 (define-once/cite-everywhere): all schema/marker/return detail lives here; agents and skills cite it.

- [x] **[Implement]** Author the artifact contract doc
  - Architecture constraints: mirror the section style and the "three roles" preamble of `reference/research-artifact.md` (introspection.md §11, lines 836–842). Define-once: every consumer cites this file and restates nothing.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/deliberation-artifact.md`**
  - Structure outline (H2 sections, in order):
    1. Intro paragraph — "single source of truth for the `deliberation.md` artifact produced by the spec-flow deliberation protocol. Cited by the six deliberation agents (`deliberation-coordinator`, `-viability`, `-synthesis`, `-lens`, `-convergence`, `-validate`), the four calling skills (`spec`, `prd`, `small-change`, `charter`), and the `plan` skill (Phase-1 consumption). Any schema detail, marker definition, VOQ/Validation-Round format, or return-contract rule lives here and nowhere else." (Clone the research-artifact.md preamble, lines 839–841, adjusting citers.)
    2. `## Location` — `docs/prds/<prd-slug>/specs/<piece-slug>/deliberation.md`, written on the piece branch by the Phase E convergence agent; `<prd-slug>`/`<piece-slug>` resolved from `manifest.yaml`.
    3. `## deliberation.md structure` — the 7 core H2 sections in exact order: `## Investigation Summary` (records the resolved depth), `## Viability Analysis`, `## Integration Check`, `## Adversarial Review`, `## Recommendation`, `## Validated Open Questions`, `## Answered by Investigation`; then the optional 8th `## Validation Rounds` (appended later by Tier 2). State explicitly that a reviewer/qa-spec MUST tolerate the presence OR absence of the 8th section. Define the **§Viability Analysis** format: one entry per **decision unit** (decision unit = FR for `spec`, candidate piece/decomposition boundary for `prd`, domain rule/principle for `charter`, the change for `small-change`); each entry is a markdown table of rows `Path | Verdict (VIABLE/NON-VIABLE) | Reasoning | Reuse? (flag reuse/extend-existing paths surfaced from research.md) | Blocker (concrete; required iff NON-VIABLE)`. Define **§Answered by Investigation** entries carry the dimension + N/A-or-resolved rationale (consumed by the mandatory-block skip logic).
    4. `## VOQ-N ID contract` — every `## Validated Open Questions` entry carries a stable `VOQ-1`, `VOQ-2`, … ID; brainstorm questions and qa-spec cite these IDs; the convergence agent assigns them only to questions that survived adversarial review unresolved.
    5. `## Validation Round contract` — the 8th `## Validation Rounds` H2 holds one `### Validation Round <n>` per Tier-2 pass, recording in order: `**Assertion:**`, `**Verdict:**` (CONFIRM | FLAG-HARD | FLAG-SOFT), `**Evidence:**`, `**Resolution:**` (folded | revised | overridden-with-rationale). Appended during brainstorm, never by Phase E.
    6. `## Marker contract` — clone the research-artifact.md marker block (introspection.md §11, lines 794–820) structure, defining four markers, each with exact emitter + triggers + non-blocking note:
       - `[DELIBERATION-UNAVAILABLE: <phase>-<reason>]` — emitted by the **calling skill**; **5 fatal triggers**: (a) Phase A `STATUS: BLOCKED`; (b) Phase C `STATUS: BLOCKED`; (c) Phase E `STATUS: BLOCKED`; (d) `deliberation.md` missing/zero-length after Phase E; (e) `git commit` of `deliberation.md` fails. Non-blocking → falls back to current brainstorm, indistinguishable from pre-5.8.0.
       - **2 non-fatal partials** (documented under the same marker section, explicitly NOT emitting UNAVAILABLE): (f) Phase B some-cluster BLOCKED → proceed to Phase C with remaining clusters; (g) Phase D any/all lens BLOCKED → proceed to Phase E with available verdicts; Phase E notes "adversarial review unavailable" in §Adversarial Review.
       - `[DELIBERATION-SKIPPED: depth=off]` — emitted by the **calling skill** when resolved depth is `off`; runs current brainstorm unchanged.
       - `[DELIBERATION-CONSUMED: <recommendation-one-liner>]` — emitted by the **plan** skill Phase 1 when `deliberation.md` exists + non-empty.
       - `[DELIBERATION-ABSENT: no deliberation artifact]` — emitted by the **plan** skill Phase 1 when `deliberation.md` is absent/zero-length.
       - STATUS-line placement rule: markers are bracketed lines in the skill's orchestrator output, never written into `deliberation.md` (clone research-artifact.md lines 818–820).
    7. `## Return contract` — each deliberation agent returns a ≤2K-token digest to the calling skill; the on-disk `deliberation.md` may be richer; FINAL line of every agent return is exactly `STATUS: OK` or `STATUS: BLOCKED`; on BLOCKED, reason precedes the line and no partial artifact is written. (Clone research-artifact.md `## Return contract`.)
    8. `## See also` — the six deliberation agents, the four calling skills, the plan skill, `reference/deliberation-depth.md`, `reference/research-artifact.md`.
  - Pattern (three-roles preamble, from `reference/research-artifact.md` lines 839–841):
    ```
    # Research Artifact (research.md) — Contract

    This document is the single source of truth for the `research.md` artifact ... It is cited by
    `plugins/spec-flow/agents/research.md` ..., `plugins/spec-flow/skills/spec/SKILL.md` ..., and
    `plugins/spec-flow/skills/plan/SKILL.md` .... Any schema detail, marker definition, or
    return-contract rule lives here and nowhere else; the agent and both skills defer to this file.
    ```
  - Done: all eight H2 sections present; the 7-core-+-optional-8th order stated with the tolerate-8th rule; §Viability Analysis table format with reuse-flag + blocker columns; VOQ-N + Validation-Round contracts; all four markers with the 5-fatal/2-nonfatal split; ≤2K/STATUS return; repo-root-relative cross-references; no secrets.
  - Verify: `grep -nE "^## (Location|deliberation.md structure|VOQ-N ID contract|Validation Round contract|Marker contract|Return contract|See also)" plugins/spec-flow/reference/deliberation-artifact.md` returns 7 matches.

- [x] **[Verify]** Confirm the artifact contract is complete
  **Per-change checks:**
  - T-1: `ls plugins/spec-flow/reference/deliberation-artifact.md` — Expected: exit 0 (satisfies AC-7's `ls` test for the reference doc).
  - T-1: `grep -c "DELIBERATION-UNAVAILABLE\|DELIBERATION-SKIPPED\|DELIBERATION-CONSUMED\|DELIBERATION-ABSENT" plugins/spec-flow/reference/deliberation-artifact.md` — Expected: ≥4 (all four markers defined).
  - T-1: `grep -c "VOQ" plugins/spec-flow/reference/deliberation-artifact.md` — Expected: ≥1 (VOQ-N contract present; satisfies AC-20's reference-doc grep).
  - T-1: `grep -E "Investigation Summary|Viability Analysis|Integration Check|Adversarial Review|Recommendation|Validated Open Questions|Answered by Investigation|Validation Rounds" plugins/spec-flow/reference/deliberation-artifact.md | wc -l` — Expected: ≥8 (all 7 core + the optional 8th named).
  **Phase-level check:**
  - Run: LLM-agent-step — read `plugins/spec-flow/reference/deliberation-artifact.md`; confirm the 5 fatal UNAVAILABLE triggers AND the 2 non-fatal partials (Phase B / Phase D) are each enumerated; confirm the optional-8th-section tolerance is stated; confirm no marker form other than the four is defined.
  - Expected: 5 fatal + 2 non-fatal enumerated; tolerance stated; exactly four markers.
  - Failure: any trigger missing, the partial/fatal split absent, or a fifth marker invented.

- [x] **[QA]** Phase review
  - Review against: AC-7, AC-12, AC-13, AC-20, AC-23 (definition coverage)
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 2: Depth policy contract — `reference/deliberation-depth.md` + `.spec-flow.yaml` key
Why serial: disjoint from Phase 1's file but must land before any agent/skill cites depth; kept serial to preserve per-phase Opus QA on the new contract + config surface.
**Exit Gate:** `reference/deliberation-depth.md` defines the `full`/`lite`/`off` profiles, the per-skill defaults (full for spec/prd/charter, lite for small-change), the `lite` lens subset (default scope/simplicity + risk) and the optional `.spec-flow.yaml deliberation.lenses` override, the resolution order (operator override → config → per-skill default), the `[DELIBERATION-SKIPPED: depth=off]` off-path, and the depth-independent ≤1-cluster Phase-C-no-op rule; `.spec-flow.yaml` carries an additive, commented `deliberation:` template block so the key is documented but absent-by-default (per-skill default applies → NN-C-003).
**ACs Covered:** AC-19 (depth profiles + per-skill defaults + `off` SKIPPED marker definition)
**In scope:** CREATE `plugins/spec-flow/reference/deliberation-depth.md`; MODIFY `plugins/spec-flow/templates/pipeline-config.yaml` (add commented `deliberation:` template block). NOTE (execute correction): `.spec-flow.yaml` is gitignored (`.gitignore:15`) — a per-developer local copy generated from the tracked template `pipeline-config.yaml`; the committable edit target is the template, not the local copy.
**NOT in scope:** the small-change skill resolving its lite default (Phase 10); each skill's `step 0` depth read (Phases 7–10 wire it, citing this doc); the artifact/marker schema (Phase 1).
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): the `deliberation.depth`/`deliberation.lenses` keys are optional; absent → per-skill default; `off` → current brainstorm. The `.spec-flow.yaml` addition is a comment block (parseable, inert).
- NN-C-002 (no runtime deps): markdown + YAML comment only.
- CR-009 (heading hierarchy): H2/H3 structure consistent with `reference/research-artifact.md`.

- [x] **[Implement]** Author the depth-policy doc + config template
  - Architecture constraints: cite `reference/deliberation-artifact.md` for the Phase-C-no-op rule's interaction with the artifact's §Integration Check; do not restate the artifact schema.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/deliberation-depth.md`**
  - Structure outline (H2 sections, in order):
    1. Intro — "single source of truth for the deliberation depth policy. Cited by the four calling skills (`spec`, `prd`, `small-change`, `charter`) at the step-0 depth-resolution step, and documented by the `.spec-flow.yaml deliberation` key."
    2. `## Depth profiles` — a table (clone spec.md §Depth policy table, lines 293–299): `Depth | Phases run | Lenses | Default for | Cost`. `full`: A→B(parallel)→C*→D(parallel, 5 lenses)→E, default spec/prd/charter. `lite`: A→B(single pass over whole piece)→C*→D(subset, default 2)→E, default small-change. `off`: none — `[DELIBERATION-SKIPPED: depth=off]` + current brainstorm.
    3. `## Per-skill defaults` — full = spec, prd, charter; lite = small-change.
    4. `## Lens subset (lite)` — default `scope/simplicity` + `risk`; overridable via optional `.spec-flow.yaml deliberation.lenses`.
    5. `## Resolution order` — explicit operator override at invocation → `.spec-flow.yaml deliberation.depth` → per-skill default. The chosen depth is recorded in `deliberation.md` §Investigation Summary (or in the `[DELIBERATION-SKIPPED]` marker for `off`).
    6. `## Phase C no-op rule` — depth-independent: Phase C is a no-op whenever ≤1 decision-unit cluster (nothing to integrate); §Integration Check then records single-cluster coherence. Since `lite` treats the whole piece as one cluster, Phase C never runs at `lite`. (Cross-reference FR-009-H / `reference/deliberation-artifact.md` §Integration Check; do not restate.)
    7. `## off path` — `[DELIBERATION-SKIPPED: depth=off]` emitted by the calling skill; runs pre-5.8.0 brainstorm unchanged; Tier 2 inactive (no `deliberation.md`).
    8. `## See also` — the four calling skills, `reference/deliberation-artifact.md`, `.spec-flow.yaml`.
  - Done: all profiles/defaults/lens-subset/resolution-order/no-op-rule/off-path/see-also present; SKIPPED marker contract present; repo-root-relative refs.
  - Verify: `grep -nE "^## (Depth profiles|Per-skill defaults|Lens subset|Resolution order|Phase C no-op rule|off path|See also)" plugins/spec-flow/reference/deliberation-depth.md` returns 7 matches.

  **T-2: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`** (the tracked template; `.spec-flow.yaml` is gitignored and generated from it)
  - Anchor: append after the existing `integrations:` commented block (end of file).
  - TARGET: add an additive, commented template block documenting the optional key, so absence → per-skill default (backward-compatible). Content:
    ```yaml
    # deliberation: pre-brainstorm Investigation-First protocol depth (new in v5.8.0)
    #   depth: full | lite | off
    #     full  — all 5 phases, all 5 lenses (default for spec/prd/charter)
    #     lite  — Phase A + single Phase B pass + reduced Phase D (lens subset) + Phase E (default for small-change)
    #     off   — skip deliberation; emit [DELIBERATION-SKIPPED: depth=off]; run pre-5.8.0 brainstorm
    #   lenses: optional list overriding the lite-depth lens subset (default: [scope-simplicity, risk])
    #   Absent key → per-skill default. See plugins/spec-flow/reference/deliberation-depth.md.
    # deliberation:
    #   depth: full
    #   lenses: [scope-simplicity, risk]
    ```
  - Done: the commented block is appended; the live config is unchanged (no active key added → existing behavior preserved); file still valid YAML.
  - Verify: `grep -n "deliberation.depth\|deliberation:" .spec-flow.yaml` returns the documented (commented) key.

- [x] **[Verify]** Confirm depth contract + config template
  **Per-change checks:**
  - T-1: `grep -n "DELIBERATION-SKIPPED" plugins/spec-flow/reference/deliberation-depth.md` — Expected: ≥1 match (satisfies AC-19's off-path marker grep).
  - T-1: `grep -c "full\|lite\|off" plugins/spec-flow/reference/deliberation-depth.md` — Expected: ≥3 (all three profiles named).
  - T-2: `grep -c "deliberation" .spec-flow.yaml` — Expected: ≥1.
  **Phase-level check:**
  - Run: LLM-agent-step — read `plugins/spec-flow/reference/deliberation-depth.md`; confirm per-skill defaults name full for spec/prd/charter and lite for small-change, the lite lens subset is scope/simplicity + risk, and the resolution order is operator→config→default.
  - Expected: all present.
  - Failure: a default mislabeled, the lens subset wrong, or resolution order missing.

- [x] **[QA]** Phase review
  - Review against: AC-19, NN-C-003
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 3: Tier-1 agents A·B·C — coordinator, viability, synthesis
Why serial: the three files are disjoint but each cites the Phase-1 artifact contract (cite-before-use); kept serial for per-phase Opus QA on each new shipped agent contract; wall-clock savings negligible for three small markdown clones.
**Exit Gate:** `agents/deliberation-coordinator.md`, `agents/deliberation-viability.md`, `agents/deliberation-synthesis.md` each exist with bare `name: deliberation-<role>`, `model: opus`, the research.md six-section skeleton, the ≤2K/STATUS/no-partial/no-sub-agents contract, and each cites `reference/deliberation-artifact.md` for all schema. Viability enumerates ALL paths incl. reuse/extend-existing with VIABLE/NON-VIABLE + concrete blocker (EARS discipline).
**ACs Covered:** AC-1 (coordinator/viability/synthesis files exist + frontmatter), AC-3 (viability: all paths, verdicts, blockers, reuse paths), AC-4 (coordinator: web research fires on genuine unknown / not otherwise), AC-5 (synthesis: Phase C integration-check conflict flagging), AC-17 (viability agent frontmatter: `name: deliberation-viability`, `model: opus`)
**In scope:** CREATE `plugins/spec-flow/agents/deliberation-coordinator.md`, `plugins/spec-flow/agents/deliberation-viability.md`, `plugins/spec-flow/agents/deliberation-synthesis.md`.
**NOT in scope:** the lens + convergence agents (Phase 4); the validate agent (Phase 5); skill-side dispatch/barrier orchestration (Phases 7–10); the artifact schema (Phase 1 — cited, not restated).
**Charter constraints honored in this phase:**
- NN-C-004 (bare agent names): `name: deliberation-coordinator` / `-viability` / `-synthesis` (no plugin prefix).
- CR-001 (agent frontmatter): each has `name:`, `description:` (trigger + dispatch contract), `model: opus`.
- NN-C-008 (self-contained, no history): each agent's `## Injected Inputs (No History)` lists exactly what the calling skill injects; no brainstorm history assumed.
- CR-008 (single-task, no sub-agents): each agent runs one phase and dispatches nothing.
- NN-P-005 (Opus thinking): all three are `model: opus`.

- [x] **[Implement]** Author the coordinator, viability, and synthesis agents
  - Architecture constraints: each file clones `agents/research.md` (introspection.md §10) — frontmatter shape + the six H2 sections (`## Role / Single Task` → `## Injected Inputs (No History)` → `## Procedure` → `## Output Contract` → `## No Secrets` → `## Return Contract`) + the verbatim STATUS final-line block. All schema/marker detail is CITED from `reference/deliberation-artifact.md`, never restated.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/agents/deliberation-coordinator.md`** (Phase A)
  - Frontmatter: `name: deliberation-coordinator`; `description: "Internal agent — dispatched by spec-flow:{spec,prd,small-change,charter} before brainstorm. Do NOT call directly. Phase A of the deliberation protocol: reads all injected artifacts, fires web research on genuine unknowns, returns an investigation seed. Dispatches no sub-agents."`; `model: opus`.
  - Body sections (cite `reference/deliberation-artifact.md` for return contract):
    1. `## Role / Single Task` — "Phase A coordinator. You read all injected inputs, identify genuine unknowns, fire web research only on those, and return an investigation seed. You dispatch NO sub-agents."
    2. `## Injected Inputs (No History)` — PRD sections, `research.md` digest (if STATUS: OK), charter constraints, piece description, manifest entry. "No prior conversation history; all inputs are in this prompt." (Clone research.md lines 759–762 idiom.)
    3. `## Procedure` — (1) read all injected inputs; (2) identify **genuine unknowns** = questions not answerable from injected inputs (PRD/charter/research resolve → NOT genuine); (3) for each genuine unknown fire WebSearch/WebFetch for prior art/methodology/comparable implementations; (4) if none, state "no unknowns requiring web research found" and make no web calls; (5) return the investigation seed (structured summary of inputs + web findings, each finding cited).
    4. `## Output Contract` — Phase A writes NO artifact (it returns a seed to the skill; Phase E writes `deliberation.md`). Cite `reference/deliberation-artifact.md` for the return contract.
    5. `## No Secrets` — never transcribe credentials into the digest.
    6. `## Return Contract` — ≤2K digest = investigation seed; FINAL line `STATUS: OK` or `STATUS: BLOCKED` (reason above the line on BLOCKED). Cite the artifact doc.
  - Pattern (STATUS final-line block, from `agents/research.md` lines 730–742):
    ```
    The **FINAL line** of your return must be exactly one of:
    STATUS: OK
    STATUS: BLOCKED
    On `STATUS: BLOCKED`, include the reason before the status line and do NOT write a partial artifact.
    ```
  - Done: file exists; bare name; `model: opus`; six sections; web-fires-only-on-genuine-unknown procedure (both branches: fire / explicitly-no-web); cites the artifact doc; STATUS contract present.
  - Verify: `grep -E "^name: deliberation-coordinator$" …` and `grep -E "^model: opus$" …` both match (see phase `[Verify]`).

  **T-2: CREATE `plugins/spec-flow/agents/deliberation-viability.md`** (Phase B, parallel per cluster)
  - Frontmatter: `name: deliberation-viability`; `description: "Internal agent — dispatched (in parallel, one per decision-unit cluster) by the deliberation protocol. Do NOT call directly. Phase B: enumerates ALL viable paths for its cluster (incl. reuse/extend-existing), assigns VIABLE/NON-VIABLE with a concrete blocker for any NON-VIABLE. Dispatches no sub-agents."`; `model: opus`.
  - Body sections:
    1. `## Role / Single Task` — "Phase B viability. For your assigned decision-unit cluster, enumerate every viable path and assign verdicts. You dispatch NO sub-agents."
    2. `## Injected Inputs (No History)` — the Phase A investigation seed, the assigned cluster (its decision units), charter constraints, `research.md` conventions (for reuse-path discovery).
    3. `## Procedure` — enumerate ALL viable paths for the cluster (NO 2–3 cap); **must include reuse/extend-existing-code paths surfaced from research.md, not only greenfield**; evaluate each against charter constraints + codebase conventions + PRD goals; assign VIABLE or NON-VIABLE; a path is NON-VIABLE only with a **concrete identified blocker** (EARS-style — never a bare "seems hard"/"should"/"may"). Return per-cluster viability findings shaped as the §Viability Analysis table rows defined in `reference/deliberation-artifact.md`.
    4. `## Output Contract` — returns findings to the skill (the skill applies the Phase-C barrier); cite the artifact doc for the §Viability Analysis table format.
    5. `## No Secrets`.
    6. `## Return Contract` — ≤2K digest; STATUS final line; on BLOCKED the skill logs the blocked cluster and proceeds with remaining clusters (non-fatal partial — cite the artifact marker contract).
  - Done: file exists; bare name; `model: opus`; enumerate-all-paths + reuse-paths + EARS-blocker discipline stated; cites artifact §Viability Analysis format; STATUS contract.
  - Verify: phase `[Verify]` greps name/model + "reuse"/"NON-VIABLE"/"blocker".

  **T-3: CREATE `plugins/spec-flow/agents/deliberation-synthesis.md`** (Phase C)
  - Frontmatter: `name: deliberation-synthesis`; `description: "Internal agent — dispatched by the deliberation protocol after the Phase B barrier (only when ≥2 clusters). Do NOT call directly. Phase C: checks cross-cluster path composition, documents conflicts, narrows to composable paths, produces an integrated recommendation. Dispatches no sub-agents."`; `model: opus`.
  - Body sections:
    1. `## Role / Single Task` — "Phase C synthesis. Integrate all Phase B per-cluster findings; check cross-cluster composition. You dispatch NO sub-agents."
    2. `## Injected Inputs (No History)` — all Phase B per-cluster viability findings; charter constraints.
    3. `## Procedure` — for each pair of clusters with VIABLE paths, check whether the paths compose; document conflicts explicitly; narrow the VIABLE set to composable paths; produce an integrated recommendation; flag unresolvable cross-cluster conflicts as validated open questions (feeding Phase E). Note the no-op condition: when invoked with ≤1 cluster the skill skips this agent and §Integration Check records single-cluster coherence (the skill, not this agent, enforces the skip — cite the artifact doc).
    4. `## Output Contract` — returns the integrated recommendation + documented conflicts to the skill; cite the artifact §Integration Check format.
    5. `## No Secrets`.
    6. `## Return Contract` — ≤2K digest; STATUS final line; on BLOCKED the skill emits `[DELIBERATION-UNAVAILABLE: phase-C-blocked]` and falls back (fatal — cite the marker contract).
  - Done: file exists; bare name; `model: opus`; compose-check + conflict-documentation + narrow-to-composable procedure; cites artifact §Integration Check; STATUS contract.
  - Verify: phase `[Verify]` greps name/model + "compose"/"conflict".

- [x] **[Verify]** Confirm the three agent contracts
  **Per-change checks:**
  - T-1: `grep -E "^name: deliberation-coordinator$" plugins/spec-flow/agents/deliberation-coordinator.md && grep -E "^model: opus$" plugins/spec-flow/agents/deliberation-coordinator.md` — Expected: both match.
  - T-1: `grep -ci "web\|search" plugins/spec-flow/agents/deliberation-coordinator.md` — Expected: ≥1 (web-research procedure present, AC-4).
  - T-2: `grep -E "^name: deliberation-viability$" plugins/spec-flow/agents/deliberation-viability.md && grep -E "^model: opus$" plugins/spec-flow/agents/deliberation-viability.md` — Expected: both match (AC-17).
  - T-2: `grep -ci "reuse\|NON-VIABLE\|blocker" plugins/spec-flow/agents/deliberation-viability.md` — Expected: ≥3 (reuse-path + EARS-blocker discipline, AC-3).
  - T-3: `grep -E "^name: deliberation-synthesis$" plugins/spec-flow/agents/deliberation-synthesis.md && grep -E "^model: opus$" plugins/spec-flow/agents/deliberation-synthesis.md` — Expected: both match.
  - T-3: `grep -ci "compose\|conflict\|integrat" plugins/spec-flow/agents/deliberation-synthesis.md` — Expected: ≥2 (AC-5).
  **Phase-level check:**
  - Run: LLM-agent-step — read all three agents; confirm each has the six-section skeleton, cites `reference/deliberation-artifact.md` rather than restating the schema, includes the verbatim STATUS final-line + no-partial rule, and contains no instruction to dispatch sub-agents. Confirm the coordinator has BOTH web-fires and explicit-no-web branches; the viability agent has BOTH a reuse-path requirement and an EARS concrete-blocker rule for NON-VIABLE.
  - Expected: all true.
  - Failure: a restated schema, a prefixed name, a missing branch, or any sub-agent dispatch.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-3, AC-4, AC-5, AC-17
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 4: Tier-1 agents D·E — lens (5-instance, parameterized) + convergence
Why serial: disjoint files citing the Phase-1 contract; kept serial for per-phase Opus QA on the adversarial-board + convergence contracts (the agents that produce the VOQ-tagged questions consumed downstream).
**Exit Gate:** `agents/deliberation-lens.md` exists with a `{lens}` parameter slot (single file dispatched 5× at full depth) returning HOLDS/CONTESTED; `agents/deliberation-convergence.md` exists, writes the 7-core-section `deliberation.md`, assigns VOQ-N IDs to surviving CONTESTED questions, records resolved depth in §Investigation Summary, and emits no validated open questions before it runs. Both bare-named, `model: opus`, cite the artifact contract.
**ACs Covered:** AC-1 (lens + convergence files exist), AC-6 (Phase D adversarial review documented; CONTESTED→VOQ; all-HOLDS recorded), AC-7 (convergence writes the 7 core H2 sections — the writer side; the SoT was Phase 1), AC-18 (5 lens agents full depth, `{lens}` param slot, convergence folds verdicts, CONTESTED→VOQ)
**In scope:** CREATE `plugins/spec-flow/agents/deliberation-lens.md`, `plugins/spec-flow/agents/deliberation-convergence.md`.
**NOT in scope:** the skill-side 5-way fan-out + barrier + lens-label injection (Phase 7 for spec; Phases 8–10 for the others); the count "exactly five lenses" appears in the SKILL orchestration blocks, not here; the validate agent (Phase 5).
**Charter constraints honored in this phase:**
- NN-C-004 (bare agent names): `name: deliberation-lens` / `-convergence`.
- CR-001 (agent frontmatter): `name:`/`description:`/`model: opus`.
- NN-C-008 (self-contained, no history): the lens label + Phase C recommendation are injected; convergence receives Phase C rec + all Phase D verdicts.
- CR-008 (single-task, no sub-agents).
- NN-P-005 (Opus thinking; the board is an adversarial gate): both `model: opus` — the single-model multi-lens board (ADR-1).

- [x] **[Implement]** Author the lens and convergence agents
  - Architecture constraints: `deliberation-lens.md` is ONE file with a `{lens}` injection slot (ADR-1 — dimension diversity, single model); the calling skill supplies the lens label. `deliberation-convergence.md` is the only agent that writes `deliberation.md` (the 7 core sections), per the artifact contract. Both clone the research.md skeleton + STATUS block; both cite the artifact doc.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/agents/deliberation-lens.md`** (Phase D, 5 instances at full depth)
  - Frontmatter: `name: deliberation-lens`; `description: "Internal agent — dispatched (in parallel, one per lens) by the deliberation protocol after Phase C. Do NOT call directly. Phase D: adversarially challenges the recommendation from a single injected lens; returns HOLDS or CONTESTED with specific reasoning. Single-model multi-lens board (NOT multi-model). Dispatches no sub-agents."`; `model: opus`.
  - Body sections:
    1. `## Role / Single Task` — "Phase D adversarial lens. You challenge the Phase C recommendation from exactly ONE lens (`{lens}`). You dispatch NO sub-agents."
    2. `## Injected Inputs (No History)` — the Phase C recommendation; a single **lens label** `{lens}` ∈ {architecture-integrity | scope/simplicity | user-intent | backward-compat | risk}; charter constraints. Document each lens's question (clone spec.md lines 226–230): architecture-integrity = follows charter architectural principles?; scope/simplicity = simplest solution, any scope creep/under-scope?; user-intent = serves the PRD user story?; backward-compat = breaks any existing behavior/contract?; risk = key failure modes, hidden assumptions, external deps?
    3. `## Procedure` — adversarially stress-test the recommendation through the injected lens only; return HOLDS (with what was challenged and why it held) or CONTESTED (with the specific challenge). Verdict-folding is Phase E's job (do NOT generate VOQ IDs here).
    4. `## Output Contract` — returns one verdict to the skill (the skill applies the Phase-E barrier); cite the artifact §Adversarial Review format.
    5. `## No Secrets`.
    6. `## Return Contract` — ≤2K digest; STATUS final line; on BLOCKED the skill logs the blocked lens and proceeds to Phase E with available verdicts (non-fatal partial — cite the marker contract).
  - Done: file exists; bare name; `model: opus`; a `{lens}` parameter slot present; the five lens definitions documented; HOLDS/CONTESTED verdict; "single-model multi-lens, NOT multi-model" stated; cites artifact §Adversarial Review.
  - Verify: phase `[Verify]` greps name/model + the `{lens}` slot + "HOLDS"/"CONTESTED".

  **T-2: CREATE `plugins/spec-flow/agents/deliberation-convergence.md`** (Phase E)
  - Frontmatter: `name: deliberation-convergence`; `description: "Internal agent — dispatched by the deliberation protocol after the Phase D barrier. Do NOT call directly. Phase E: synthesizes adversarial verdicts, finalizes the surviving recommendation, generates VOQ-tagged validated open questions + the answered-by-investigation list, records resolved depth, and writes the 7-core-section deliberation.md. Dispatches no sub-agents."`; `model: opus`.
  - Body sections:
    1. `## Role / Single Task` — "Phase E convergence. Fold Phase D verdicts, finalize the recommendation, write `deliberation.md`. You dispatch NO sub-agents."
    2. `## Injected Inputs (No History)` — the Phase C recommendation; all Phase D adversarial verdicts (may be empty if Phase D all-BLOCKED — then note 'adversarial review unavailable' in §Adversarial Review); resolved depth; the decision-unit list.
    3. `## Procedure` — finalize the recommendation (revise if CONTESTED verdicts require); generate §Validated Open Questions = only questions that survived adversarial review unresolved, **each assigned a stable `VOQ-N` ID** per the artifact's VOQ contract; generate §Answered by Investigation (dimensions resolved + N/A rationale); record resolved depth in §Investigation Summary; write the 7 core H2 sections in order.
    4. `## Output Contract — Write deliberation.md` — write to `docs/prds/<prd-slug>/specs/<piece-slug>/deliberation.md` per `reference/deliberation-artifact.md` `## deliberation.md structure` (cite, do not restate). Write the 7 core sections only (the optional 8th is Tier 2's, later). On BLOCKED, write no artifact.
    5. `## No Secrets`.
    6. `## Return Contract` — ≤2K digest; STATUS final line; on BLOCKED the skill emits `[DELIBERATION-UNAVAILABLE: phase-E-blocked]` (also fires if `deliberation.md` missing/empty after a STATUS: OK, or the git commit fails — cite the 5-fatal trigger set).
  - Done: file exists; bare name; `model: opus`; writes the 7 core sections; assigns VOQ-N IDs; records depth; handles empty-Phase-D verdict set; cites artifact structure + marker contract; STATUS + no-partial.
  - Verify: phase `[Verify]` greps name/model + "VOQ" + "deliberation.md".

- [x] **[Verify]** Confirm the lens + convergence contracts
  **Per-change checks:**
  - T-1: `grep -E "^name: deliberation-lens$" plugins/spec-flow/agents/deliberation-lens.md && grep -E "^model: opus$" plugins/spec-flow/agents/deliberation-lens.md` — Expected: both match.
  - T-1: `grep -c "{lens}\|HOLDS\|CONTESTED" plugins/spec-flow/agents/deliberation-lens.md` — Expected: ≥3 (param slot + both verdicts; satisfies AC-18's lens-param-slot grep).
  - T-2: `grep -E "^name: deliberation-convergence$" plugins/spec-flow/agents/deliberation-convergence.md && grep -E "^model: opus$" plugins/spec-flow/agents/deliberation-convergence.md` — Expected: both match.
  - T-2: `grep -c "VOQ\|deliberation.md" plugins/spec-flow/agents/deliberation-convergence.md` — Expected: ≥2 (VOQ assignment + writes the artifact).
  **Phase-level check:**
  - Run: LLM-agent-step — read both agents; confirm the lens agent has a `{lens}` slot + the five lens definitions + "single-model multi-lens NOT multi-model" + HOLDS/CONTESTED; confirm convergence writes the 7 core sections (not the 8th), assigns VOQ-N IDs only to surviving-CONTESTED questions, records depth, handles an empty Phase-D verdict set, and cites the artifact doc.
  - Expected: all true.
  - Failure: lens hardcodes a single dimension, convergence writes the 8th section, VOQ IDs missing, or schema restated.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-6, AC-7, AC-18
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 5: Tier-2 agent — `agents/deliberation-validate.md`
Why serial: disjoint file; cites the Phase-1 artifact (Validation-Round schema) and structurally mirrors `agents/spike.md` scope mode (ADR-4); kept serial for per-phase Opus QA on the new Tier-2 verdict contract.
**Exit Gate:** `agents/deliberation-validate.md` exists with bare `name: deliberation-validate`, `model: opus`, a single validate task scoped to one operator assertion (viability + conflicts charter/NN+cross-FR + prior-art via scope/simplicity + risk lenses), returning exactly CONFIRM | FLAG-HARD | FLAG-SOFT, appending a Validation Round per the artifact contract; mirrors the spike scope-mode isolated/≤2K/STATUS/no-partial/no-sub-agents shape; BLOCKED returns no verdict.
**ACs Covered:** AC-21 (validate file exists + frontmatter), AC-22 (CONFIRM/FLAG-HARD/FLAG-SOFT verdict contract in the agent)
**In scope:** CREATE `plugins/spec-flow/agents/deliberation-validate.md`.
**NOT in scope:** the brainstorm-procedure detection + auto-fire + hard/soft branch wiring (Phase 6); the Validation-Round schema definition (Phase 1 — cited).
**Charter constraints honored in this phase:**
- NN-C-004 (bare name): `name: deliberation-validate`.
- CR-001 (frontmatter): `name:`/`description:`/`model: opus`.
- NN-C-008 (self-contained): the single assertion + deliberation context are injected; no history.
- CR-008 (single-task, no sub-agents).
- NN-P-005 (Opus thinking — Tier-2 validation is an adversarial gate). FLAG-HARD enforces that a binding charter non-negotiable cannot be operator-waived — stated on its own terms (execute QA correction: the prior NN-P-001 citation was a misattribution; NN-P-001 governs the spec/plan sign-off gate, not brainstorm-time assertion validation).

- [x] **[Implement]** Author the deliberation-validate agent
  - Architecture constraints: clone the `agents/spike.md` scope-mode structural shape (introspection.md §9, lines 633–675) — isolated Opus, single task, ≤2K digest, STATUS OK/BLOCKED, no-partial-on-BLOCKED, no sub-agents — but a `validate` task with a three-verdict output, citing `reference/deliberation-artifact.md` for the Validation-Round schema.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/agents/deliberation-validate.md`**
  - Frontmatter: `name: deliberation-validate`; `description: "Internal agent (Tier 2) — auto-fired by spec-flow:{spec,prd,small-change,charter} during brainstorm when an operator free-form answer introduces an assertion outside the evaluated path-set. Do NOT call directly. Isolated Opus pass: checks one assertion's viability + conflicts + prior art; returns CONFIRM | FLAG-HARD | FLAG-SOFT; appends a Validation Round. Dispatches no sub-agents."`; `model: opus`.
  - Body sections (cite `reference/deliberation-artifact.md` for the Validation-Round schema + return contract):
    1. `## Role / Single Task` — "Validate ONE operator assertion against the deliberation. You dispatch NO sub-agents."
    2. `## Injected Inputs (No History)` — the single operator assertion (verbatim); the relevant `deliberation.md` context (§Viability Analysis path labels + §Answered by Investigation); charter/NN constraints; PRD/cross-FR context.
    3. `## Procedure` — check the assertion's (a) viability; (b) conflicts against charter/NN + cross-FR; (c) prior art (web + codebase); apply the scope/simplicity + risk lenses; decide the verdict.
    4. `## Verdict contract` — return exactly one of: **CONFIRM** (viable → fold with cited evidence); **FLAG-HARD** (violates a binding charter rule / non-negotiable → operator MUST revise; **no override path**); **FLAG-SOFT** (risk/scope/complexity concern → operator MAY override; override recorded with rationale). The skill, not this agent, owns the override interaction.
    5. `## Output Contract — Append a Validation Round` — append `### Validation Round <n>` under `## Validation Rounds` in `deliberation.md` per `reference/deliberation-artifact.md` `## Validation Round contract` (cite, do not restate). On BLOCKED, append nothing and return no verdict.
    6. `## No Secrets`.
    7. `## Return Contract` — ≤2K digest carrying the verdict + evidence; STATUS final line; on BLOCKED the skill surfaces a one-line note and accepts the operator answer unvalidated (non-blocking).
  - Pattern (spike scope-mode procedure shape, from `agents/spike.md` lines 666–674):
    ```
    ### Scope mode
    1. Read the change text and current plan.
    2. Determine the full blast-radius ...
    3. Enumerate the task list ...
    4. Classify the change per reference/spike-agent.md ...
    Both modes: if you cannot resolve / scope fully, set STATUS: BLOCKED and write NO artifact.
    ```
  - Done: file exists; bare name; `model: opus`; single validate task; the three-verdict contract with FLAG-HARD=no-override / FLAG-SOFT=override-with-rationale; appends a Validation Round (cites the schema); STATUS + no-partial; no sub-agents.
  - Verify: phase `[Verify]` greps name/model + the three verdicts.

- [x] **[Verify]** Confirm the validate agent contract
  **Per-change checks:**
  - T-1: `grep -E "^name: deliberation-validate$" plugins/spec-flow/agents/deliberation-validate.md && grep -E "^model: opus$" plugins/spec-flow/agents/deliberation-validate.md` — Expected: both match (AC-21).
  - T-1: `grep -c "CONFIRM\|FLAG-HARD\|FLAG-SOFT" plugins/spec-flow/agents/deliberation-validate.md` — Expected: ≥3 (the three-verdict contract; satisfies AC-22's agent grep).
  **Phase-level check:**
  - Run: LLM-agent-step — read `agents/deliberation-validate.md`; confirm it is a single isolated validate task, returns exactly the three verdicts, states FLAG-HARD has no override and FLAG-SOFT is override-with-rationale, appends a Validation Round (cites the artifact schema, does not restate), and dispatches no sub-agents.
  - Expected: all true.
  - Failure: a fourth verdict, an override path on FLAG-HARD, a restated schema, or a sub-agent dispatch.

- [x] **[QA]** Phase review
  - Review against: AC-21, AC-22
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 6: Shared brainstorm logic — `reference/brainstorm-procedure.md`
Why serial: a single shared file cited by all four calling skills; must land before the skill-wiring phases (7–10) that cite the Tier-2 loop and the deliberation invocation item; kept serial for per-phase Opus QA on this high-blast-radius shared contract.
**Exit Gate:** `reference/brainstorm-procedure.md` carries: (1) a new invocation-order item for the deliberation pass (after the research pass); (2) a new `### Tier 2: Answer-Validation Loop` `[shared]` section encoding assertion detection (default-bias-don't-fire), auto-fire of `deliberation-validate`, the CONFIRM/FLAG-HARD/FLAG-SOFT branch (hard=no-override, soft=override-with-rationale), the Validation-Round append, and human-paced termination (sign-off, no artificial cap); (3) the C-2 "never silently skip" amendment (auto-skip ≠ silent skip — permitted only on logged-N/A + one-line note); (4) the mandatory-block skip logic (N/A → skip-with-note; not-N/A → confirmation-not-discovery). A worked example of the Tier-2 loop is present.
**ACs Covered:** AC-8 (the VOQ-N / named-section citation requirement, shared — the spec side is Phase 7), AC-11 (C-2 amendment + N/A-skip + confirmation-not-discovery branches), AC-21 (Tier-2 detection + auto-fire wiring + no-fire-without-deliberation.md), AC-22 (hard/soft branch + no-override rule in this reference file), AC-23 (Validation-Rounds append + human-paced termination rule)
**In scope:** MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md` (invocation-order list; new Tier-2 section; C-2 amendment; mandatory-block skip logic).
**NOT in scope:** the validate agent file (Phase 5 — cited); the per-skill dispatch blocks (Phases 7–10); the artifact/Validation-Round schema (Phase 1 — cited).
**Steps traversed (P2):** the Tier-2 loop wraps the existing brainstorm dialogue — it traverses the existing `## Core Brainstorm Building Blocks` (L-10, C-2, C-3, Approach+Tradeoffs) without invalidating them; the C-2 always-run block is amended (not removed); the invocation-order list gains one item between the research pass (item 2) and the building blocks (item 5).
**Dispatch sites (P3):** introduces one new agent-dispatch site — `deliberation-validate` (auto-fired on a detected new assertion). No pre-existing dispatch contract is changed (the research dispatch is untouched; this file does not itself dispatch the 5-phase protocol — the skills do).
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): the Tier-2 loop is inactive when no `deliberation.md` exists (depth=off / UNAVAILABLE); the C-2 amendment only ADDS a permitted-auto-skip condition, the "never silently skip" rule otherwise stands.
- NN-P-001 (human gate): FLAG-HARD has no override; FLAG-SOFT override is operator-chosen + logged; the loop terminates only on operator sign-off.
- CR-009 (heading hierarchy): new sections are H3 under `## Core Brainstorm Building Blocks`, carrying the `[shared]` tag idiom.
- NN-C-008 (self-contained dispatch): the validate agent is dispatched with the assertion + deliberation context injected; no history assumed.

- [x] **[Implement]** Wire the deliberation invocation item, the Tier-2 loop, and the C-2 amendment
  - Architecture constraints: the loop lives ONCE here and is shared by all four calling skills; new sections carry `[shared]` (introspection.md §6 Pattern Catalog). Cite `agents/deliberation-validate.md` and `reference/deliberation-artifact.md`; restate neither the verdict semantics beyond the branch nor the Validation-Round schema.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`** — invocation-order list (anchor: the numbered list at lines 3–8, introspection.md §6(lines 504–513))
  - CURRENT (lines 4–8): items 1 Charter Context Loading → 2 Research pass → 3 L-10 → 4 Charter Constraint Identification → 5 Remaining Building Blocks.
  - TARGET: insert a new item after item 2 (research pass): "**Deliberation pass** — after the research commit (or the `[RESEARCH-UNAVAILABLE]` fallback), the calling skill dispatches the 5-phase deliberation protocol (Phase A coordinator → Phase B parallel per-cluster viability [barrier] → Phase C synthesis [skipped when ≤1 cluster] → Phase D parallel adversarial board [barrier] → Phase E convergence), commits `deliberation.md`, and emits `[DELIBERATION-UNAVAILABLE: <phase>-<reason>]` on any of the 5 fatal triggers (falling back to current brainstorm). Depth resolved per `reference/deliberation-depth.md`; on `off`, emit `[DELIBERATION-SKIPPED: depth=off]` and run the current brainstorm. See `reference/deliberation-artifact.md` for markers/return contract." Renumber subsequent items.
  - Done: the deliberation pass is item 3 (research = 2), with the marker + depth citations; later items renumbered.

  **T-2: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`** — C-2 amendment (anchor: `### C-2: Security Sub-Block (always-run)`, line 64–65, introspection.md §6(b))
  - CURRENT (line 65): "[shared] This is an always-run sub-block: never silently skip it, and treat its five prompts as additive …"
  - TARGET: append an amendment sentence (do NOT delete the existing rule): "**Amendment (v5.8.0, investigation-first):** a mandatory block (C-1, C-2, H-4 NFR sub-block, M-7 migration) MAY be auto-skipped ONLY when (a) deliberation explicitly concludes N/A for that dimension with reasoning logged in `deliberation.md` §Answered by Investigation AND (b) the calling skill surfaces the block name + N/A rationale to the user as a one-line note. Auto-skip is NOT silent skip — the user always sees the block name and rationale. When deliberation cannot conclude N/A, the block runs as **confirmation, not open discovery**: present deliberation's partial answer as a prefacing statement, then ask the confirmation question."
  - Done: the "never silently skip" line is preserved and the amendment is appended with both conditions + the confirmation-not-discovery branch.

  **T-3: MODIFY `plugins/spec-flow/reference/brainstorm-procedure.md`** — new Tier-2 section (anchor: after `### Approach + Tradeoffs Confirmation`, line 78–80, introspection.md §6(c))
  - TARGET: insert a new `### Tier 2: Answer-Validation Loop` `[shared]` section under `## Core Brainstorm Building Blocks`, active whenever a `deliberation.md` exists (depth ≠ off). Encode the loop (clone spec.md §Tier 2 steps 1–5, lines 307–324):
    1. After the operator answers a brainstorm question with **free-form input** (not selecting a presented option), **the calling skill itself** (the Opus authoring session, not a separate classifier agent) classifies the answer against `deliberation.md` §Viability Analysis path labels + §Answered by Investigation. **Decision rule:** it is a NEW ASSERTION when it names a design path/assumption/technology absent — verbatim or as a clear referent — from both. **Default bias toward NOT firing:** on an ambiguous match, treat as covered and do not fire (the cheaper miss is under-trigger).
    2. On a new assertion, auto-fire (no confirmation prompt) `deliberation-validate` (Opus), scoped to that single assertion.
    3. Branch on the verdict: **CONFIRM** → fold with cited evidence; **FLAG-HARD** → charter/NN violation, operator MUST revise, **no override**; **FLAG-SOFT** → operator MAY override → record the rationale.
    4. Append `### Validation Round <n>` under `## Validation Rounds` in `deliberation.md` (cite `reference/deliberation-artifact.md`); new conflicts become VOQ-tagged validated open questions feeding the brainstorm.
    5. The loop is **human-paced**: it continues until the operator introduces no new assertion and signs off; **no artificial round cap** (NN-P-001). When no `deliberation.md` exists (UNAVAILABLE/SKIPPED), Tier 2 does not fire.
  - Include an inline worked example (dense-algorithm guard) immediately after the steps:
    ```
    <!-- Example: deliberation.md §Viability Analysis path labels = {"reuse research.md agent shape",
    "greenfield agent"}; §Answered by Investigation covers {security: N/A}. Operator answers a question
    with free-form "let's store deliberation.md in a Postgres table instead of the piece branch."
    "Postgres table" is in neither set → NEW ASSERTION → auto-fire deliberation-validate.
    Verdict = FLAG-HARD (violates NN-C-002 no-runtime-deps) → operator must revise, no override;
    append Validation Round 1 (assertion / FLAG-HARD / NN-C-002 evidence / resolution: revised to piece-branch file).
    Counter-example: operator answers "use the greenfield agent path" → matches a §Viability Analysis
    label → accepted, no validation fires. Ambiguous answer "the simpler one" → bias: accept, do not fire. -->
    ```
  - Done: the Tier-2 section exists with `[shared]`, the five-step loop, the default-bias-don't-fire rule, the three-verdict branch with hard=no-override/soft=override, the Validation-Round append citation, the human-paced termination, the no-fire-without-deliberation.md condition, AND the worked example.
  - Verify: phase `[Verify]` greps the section + verdicts + override + sign-off + the example comment.

- [x] **[Verify]** Confirm the shared brainstorm wiring
  **Per-change checks:**
  - T-1: `grep -ni "deliberation pass\|deliberation protocol" plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: ≥1 (invocation item present).
  - T-2: `grep -n "never silently skip" plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: still present (rule preserved); AND `grep -ni "auto-skip is not silent\|Amendment (v5.8.0" …` — Expected: ≥1 (amendment appended; AC-11).
  - T-3: `grep -c "deliberation-validate\|new assertion\|evaluated path" plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: ≥2 (detection + auto-fire; AC-21).
  - T-3: `grep -ci "FLAG-HARD\|FLAG-SOFT\|CONFIRM" plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: ≥3; AND `grep -ni "override" …` — Expected: shows FLAG-HARD no-override + FLAG-SOFT override-with-rationale (AC-22).
  - T-3: `grep -ni "sign-off\|no new assertion\|human-paced" plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: ≥1 (AC-23 termination rule).
  - T-3: worked example present — `grep -c "Example:" plugins/spec-flow/reference/brainstorm-procedure.md` — Expected: ≥1 (dense-algorithm guard).
  **Phase-level check:**
  - Run: LLM-agent-step — read the amended C-2 block + the Tier-2 section; confirm the "never silently skip" rule is preserved AND amended (not deleted); confirm the Tier-2 loop conditions firing on a `deliberation.md` being present, defaults to NOT firing on ambiguity, has the three-verdict branch with the correct override semantics, appends a Validation Round, and terminates only on operator sign-off.
  - Expected: all true.
  - Failure: the "never silently skip" rule deleted, Tier-2 fires without a deliberation.md, a wrong override semantic, or a missing worked example.

- [x] **[QA]** Phase review
  - Review against: AC-8, AC-11, AC-21, AC-22, AC-23
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 7: Spec skill wiring — `skills/spec/SKILL.md`
Why serial: the canonical 5-phase orchestration block lands here and the other three skill phases (8–10) clone its dispatch pattern; must follow Phases 1–6 (cites the agents + the shared loop); kept serial for per-phase Opus QA on the primary calling skill.
**Exit Gate:** `skills/spec/SKILL.md` carries (a) an Opus pre-flight model check at skill-start (3 choices, Override-proceeds, silent-when-Opus); (b) a deliberation orchestration block in Phase 2 pre-brainstorm setup (after the research OK/UNAVAILABLE branch) dispatching Phase A→B(barrier)→C→D(barrier)→E in strict order with the 5 fatal/2 non-fatal failure handling, depth resolution, the ≤1-cluster Phase-C skip, and exactly five lens labels at full depth; (c) step 1b rewritten to read `deliberation.md` §Recommendation (with the UNAVAILABLE fallback to live framing); (d) the step-3 question gate restricting questions to §Validated Open Questions, each citing a VOQ-N ID or a named deliberation section. A worked example of the orchestration is present.
**ACs Covered:** AC-1 (spec Phase-2 dispatch block exists), AC-2 (strict phase order A→B→barrier→C→D→barrier→E + no VOQ before E + ≤1-cluster Phase-C no-op), AC-8 (investigation-first first message + VOQ-cited question gate), AC-11 (mandatory-block auto-skip applied in spec brainstorm), AC-12 (the 5 fatal / 2 non-fatal fallback applied here), AC-17 (Phase B parallel + barrier in spec), AC-18 (exactly 5 lens labels at full depth), AC-24 (spec Opus pre-flight)
**In scope:** MODIFY `plugins/spec-flow/skills/spec/SKILL.md` (skill-start pre-flight; Phase 2 deliberation block; step 1b rewrite; step 3 question gate).
**NOT in scope:** prd/charter/small-change/plan wiring (Phases 8–11); the agent files (Phases 3–5); the shared Tier-2 loop + C-2 amendment (Phase 6 — cited).
**Steps traversed (P2):** the deliberation block is a new path inserted into the Phase-2 pre-brainstorm setup AFTER step 6 (UNAVAILABLE fallback, line 108) and BEFORE the brainstorm building blocks; it traverses the existing steps 1–6 (gitignore/slug/worktree/research-dispatch/OK-commit/UNAVAILABLE) without invalidating them, and it re-seeds step 1b (approach framing) and gates step 3 (sub-areas). The C-1/C-2/H-4/M-7 mandatory blocks are traversed by the auto-skip logic.
**Dispatch sites (P3):** introduces five new agent-dispatch sites (coordinator, viability×N, synthesis, lens×5, convergence) in Phase 2. The pre-existing research dispatch (step 4) is unchanged and precedes the new block. No other dispatch contract changes.
**Charter constraints honored in this phase:**
- NN-P-001 (human gate): the question gate preserves human sign-off; the pre-flight Override always proceeds.
- NN-P-005 (Opus): the pre-flight recommends Opus; the dispatched agents are Opus.
- NN-C-003 (backward compat): on `[DELIBERATION-UNAVAILABLE]`/`off`, step 1b falls back to today's live framing; the pre-flight is silent when already Opus.
- NN-C-008 (self-contained dispatch): each agent is dispatched with its injected inputs per the agent contracts.
- CR-008 (thin orchestrator): the skill dispatches/sequences/commits; no design logic moves into it.

- [x] **[Implement]** Wire the Opus pre-flight, the deliberation block, the step-1b rewrite, and the question gate
  - Architecture constraints: the deliberation block follows the existing numbered-step dispatch+branch convention of the pre-brainstorm setup (introspection.md §1 Pattern Catalog). The orchestration prose is the spec.md §Skill wiring steps 0–8 (lines 244–285). The pre-flight is execute's L13–45 block inverted to Opus (introspection.md §8).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — Opus pre-flight (anchor: between frontmatter close `---` and `# Spec — Author Spec for One Piece`, ~line 14, introspection.md §1(a))
  - TARGET: insert a `## Pre-flight: Model Check` section mirroring `execute/SKILL.md` L13–45 (introspection.md §8) but inverted: "Before any other step, verify the active model is an Opus-class model." Determine the model by the same platform method (Copilot `<model_information>` tag; Claude Code self-introspection). If the name does NOT contain `opus` (case-insensitive): `ask_user` with three choices — "Override — proceed on [model-name]", "Change now — I'll switch models", "Cancel spec". Override → proceed immediately on the current model (one-line ack; **no hard refusal**). Cancel → stop, emit "Spec cancelled. Re-run after switching to an Opus model." Change-now → return control, wait for "proceed"/"cancel", re-check. If the name already contains `opus` → proceed silently, no prompt. Warning text: "Spec authoring is thinking work per NN-P-005, but the active model appears to be [model-name]."
  - Pattern (execute L22/L36/L45, from introspection.md §8):
    ```
    If the active model name does **not** contain `sonnet` (case-insensitive): 1. Use `ask_user` to block ...
    3. If "Override — proceed on [model-name]" → proceed to Step 0 immediately on the current model ...
    If the model already contains `sonnet` → proceed to Step 0 immediately with no prompt.
    ```
    (Invert `sonnet`→`opus` throughout; Cancel label → "Cancel spec".)
  - Done: the pre-flight block exists with the three choices, the Override-proceeds branch, and the silent-when-`opus` path.

  **T-2: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — deliberation orchestration block (anchor: after the UNAVAILABLE path step 6, line 108, before `**YAGNI throughout.**`, introspection.md §1(b))
  - TARGET: insert a `**[Deliberation protocol]**` block continuing the pre-brainstorm numbered steps, transcribing spec.md §Skill wiring steps 0–8 (lines 244–285): step 0 resolve depth (per `reference/deliberation-depth.md`; on `off` → emit `[DELIBERATION-SKIPPED: depth=off]`, run current brainstorm, STOP); step 1 dispatch Phase A (inject PRD sections, piece description, research.md digest if OK, charter; on BLOCKED → `[DELIBERATION-UNAVAILABLE: phase-A-blocked]`, fall back); step 2 identify decision-unit clusters (FRs grouped by functional similarity/dependency; at lite → whole piece = one cluster); step 3 dispatch Phase B **in parallel, one agent per cluster** with a **barrier** (on some-cluster BLOCKED → log, proceed with remaining — non-fatal); step 4 dispatch Phase C synthesis (**skip when ≤1 cluster**; on BLOCKED → `[DELIBERATION-UNAVAILABLE: phase-C-blocked]`, fall back); step 5 dispatch Phase D **in parallel** with **exactly five lens labels** at full depth (architecture-integrity, scope/simplicity, user-intent, backward-compat, risk; lite = configured subset) + **barrier** (any/all BLOCKED → log, proceed — non-fatal; Phase E notes unavailability); step 6 dispatch Phase E convergence (inject Phase C rec + all Phase D verdicts; tags VOQ-N; records depth; on OK + deliberation.md present+non-empty → commit; on BLOCKED or missing/empty or commit-fail → `[DELIBERATION-UNAVAILABLE: phase-E-blocked]`, fall back); step 7 first brainstorm message = Investigation Summary + Recommendation + "I have N validated questions for you."; step 8 questions drawn from §Validated Open Questions, each citing its VOQ-N ID or a named deliberation section. Cite `reference/deliberation-artifact.md` (markers) and `reference/deliberation-depth.md` (depth) — do not restate. Ensure the literal tokens `Phase A`, `Phase B`, `barrier`, `Phase C`, `Phase D`, `Phase E` all appear (AC-2 grep).
  - Include an inline worked example (dense-algorithm guard) after the block:
    ```
    <!-- Example: a spec piece with FRs {auth-token, token-refresh, session-store} clustered into
    2 clusters {auth (auth-token, token-refresh), session (session-store)}. full depth.
    Phase A coordinator reads PRD+research+charter, fires 1 web search on an unknown.
    Phase B: 2 viability agents (one per cluster) in parallel → barrier.
    Phase C synthesis runs (2 clusters ≥2 → not skipped) → integrated recommendation.
    Phase D: 5 lens agents in parallel → barrier (4 HOLDS, 1 CONTESTED on backward-compat).
    Phase E: folds the CONTESTED into VOQ-1, writes deliberation.md (7 sections), records depth=full.
    First brainstorm message: Investigation Summary + Recommendation + "I have 1 validated question (VOQ-1)."
    Single-cluster counter-example: a 1-FR piece → 1 viability agent, Phase C SKIPPED (≤1 cluster). -->
    ```
  - Done: the block transcribes steps 0–8 with the literal phase tokens + `barrier`, the depth/skip/fallback branches, the five lens labels, the VOQ-cited question gate, AND the worked example.

  **T-3: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — step 1b rewrite (anchor: line 133, introspection.md §1(c))
  - CURRENT: "1b. **Approach framing** *(H-6)*: Propose 2-3 lightweight approaches and ask the user to choose one. … The chosen approach becomes the design anchor for step 3 …"
  - TARGET: rewrite to: "1b. **Approach framing** *(H-6)*: When `deliberation.md` exists (depth ≠ off), do NOT frame approaches live — read `deliberation.md` §Recommendation and present it as the design anchor for step 3 (the protocol already evaluated the viable paths in §Viability Analysis). When `deliberation.md` is absent (`[DELIBERATION-UNAVAILABLE]`/`[DELIBERATION-SKIPPED]`), fall back to today's behavior: propose 2–3 lightweight approaches and ask the user to choose." Keep the step-5 trade-off confirmation reference intact.
  - Done: step 1b reads the recommendation on the available path and falls back live on the absent path (both branches present).

  **T-4: MODIFY `plugins/spec-flow/skills/spec/SKILL.md`** — step 3 question gate (anchor: line 135, introspection.md §1(d))
  - TARGET: augment step 3's "ask only about what remains genuinely unclear" with: "When `deliberation.md` exists, design questions are **restricted to §Validated Open Questions**; each question presented MUST carry a citation — either a `VOQ-N` ID (for a listed validated open question) or a named deliberation section (for an emergent follow-up, e.g. 'Following deliberation §Integration Check: …'). Mandatory blocks (C-1, C-2, H-4, M-7) follow the auto-skip / confirmation-not-discovery logic in `reference/brainstorm-procedure.md` (cite, do not restate)."
  - Done: the VOQ-N / named-section citation requirement + the mandatory-block reference are present in step 3.

- [x] **[Verify]** Confirm the spec wiring
  **Per-change checks:**
  - T-1: `grep -n -i "opus" plugins/spec-flow/skills/spec/SKILL.md | grep -i "pre-flight\|model check\|Override\|Cancel spec"` — Expected: the pre-flight block lines; AND `grep -c "Override\|Change now\|Cancel" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥3 (three choices; AC-24).
  - T-2: `grep -nE "Phase A|Phase B|barrier|Phase C|Phase D|Phase E" plugins/spec-flow/skills/spec/SKILL.md` — Expected: all six tokens present in the pre-brainstorm block (AC-2).
  - T-2: `grep -n "deliberation-coordinator" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1 (dispatch line; AC-1).
  - T-2: lens-label count — `grep -c "architecture-integrity\|scope/simplicity\|user-intent\|backward-compat\|risk" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥5 (five lenses; AC-18).
  - T-2: `grep -c "Example:" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1 (worked example present).
  - T-4: `grep -c "VOQ" plugins/spec-flow/skills/spec/SKILL.md` — Expected: ≥1 (question-gate citation; AC-8).
  **Phase-level check:**
  - Run: LLM-agent-step — read the Phase-2 deliberation block; confirm strict order A→B(barrier)→C→D(barrier)→E, the ≤1-cluster Phase-C skip, the 5-fatal/2-non-fatal failure handling, the depth `off`/`[DELIBERATION-SKIPPED]` STOP, the five lens labels at full depth, the step-1b dual-path (read recommendation / live fallback), and the step-3 VOQ citation gate. Confirm the Opus pre-flight Override always proceeds and is silent when already Opus.
  - Expected: all true.
  - Failure: phase order wrong, no barrier, a missing fallback branch, fewer than five lenses, or a hard-refusing pre-flight.
  - Manual smoke (operator, optional — the spec's only live run): run `/spec-flow:spec` on a scratch piece; confirm the first brainstorm message is the Investigation Summary (not a question) and `deliberation.md` has the 7 H2 sections.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-8, AC-11, AC-12, AC-17, AC-18, AC-24
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 8: PRD skill wiring — `skills/prd/SKILL.md`
Why serial: clones Phase 7's dispatch pattern into a disjoint file; must follow Phases 1–6; kept serial for per-phase Opus QA.
**Exit Gate:** `skills/prd/SKILL.md` carries an Opus pre-flight at skill-start and a deliberation orchestration block (full depth) before Step 4 Brainstorm, with decision units = candidate pieces / decomposition boundaries; the first brainstorm message presents the Investigation Summary.
**ACs Covered:** AC-9 (prd deliberation block before decomposition brainstorm), AC-24 (prd Opus pre-flight)
**In scope:** MODIFY `plugins/spec-flow/skills/prd/SKILL.md` (skill-start pre-flight; pre-Step-4 deliberation block).
**NOT in scope:** the other skills (Phases 7, 9–11); the shared loop (Phase 6 — cited); the agents (Phases 3–5 — cited).
**Steps traversed (P2):** the deliberation block inserts between Step 3 (FR quality floor) and Step 4 (Brainstorm), traversing the existing Steps 0–3 without invalidating them and re-seeding Step 4's first message; decision unit = candidate piece (Step 4h identification).
**Dispatch sites (P3):** five new dispatch sites (the protocol); pre-existing dispatches unchanged.
**Charter constraints honored in this phase:**
- NN-P-005 (Opus): pre-flight + Opus agents.
- NN-C-003 (backward compat): UNAVAILABLE/off fall back to today's Step-4 brainstorm; silent pre-flight when Opus.
- NN-C-008 (self-contained dispatch); CR-008 (thin orchestrator).

- [x] **[Implement]** Wire the prd Opus pre-flight + deliberation block (full depth)
  - Architecture constraints: clone Phase 7's pre-flight (invert to "PRD authoring is thinking work per NN-P-005"; Cancel label "Cancel prd") and the deliberation orchestration block (steps 0–8), citing `reference/deliberation-artifact.md` + `reference/deliberation-depth.md`. Decision unit = candidate piece.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/prd/SKILL.md`** — Opus pre-flight (anchor: between frontmatter `---` and `# PRD — …`, ~line 14, introspection.md §2(a))
  - TARGET: insert `## Pre-flight: Model Check` mirroring Phase 7 T-1 (Opus-inverted), Cancel label "Cancel prd", warning "PRD authoring is thinking work per NN-P-005…". Three choices; Override proceeds; silent when `opus`.
  - Done: pre-flight present with three choices + Override-proceeds + silent-when-opus.

  **T-2: MODIFY `plugins/spec-flow/skills/prd/SKILL.md`** — deliberation block (anchor: before `**Step 4: Brainstorm**`, line 137, introspection.md §2(b))
  - TARGET: insert a `**[Deliberation protocol]**` block (full depth; decision unit = candidate piece) transcribing steps 0–8 as in Phase 7 T-2 (depth resolution; Phase A→B[barrier]→C[skip ≤1 cluster]→D[5 lenses, barrier]→E; 5-fatal/2-non-fatal handling; commit; first Step-4 message = Investigation Summary; questions VOQ-cited). Include the literal phase tokens + `barrier`. Add a one-line worked example noting decision-unit = candidate piece.
  - Done: the block present before Step 4 with full-depth orchestration + the candidate-piece decision-unit framing + worked example.

- [x] **[Verify]** Confirm the prd wiring
  **Per-change checks:**
  - T-1: `grep -c "Override\|Change now\|Cancel" plugins/spec-flow/skills/prd/SKILL.md` — Expected: ≥3; `grep -n -i "opus" plugins/spec-flow/skills/prd/SKILL.md` — Expected: pre-flight block present (AC-24).
  - T-2: `grep -n "deliberation-coordinator" plugins/spec-flow/skills/prd/SKILL.md` — Expected: ≥1 (AC-9).
  - T-2: `grep -nE "Phase A|Phase B|barrier|Phase E" plugins/spec-flow/skills/prd/SKILL.md` — Expected: present.
  **Phase-level check:**
  - Run: LLM-agent-step — read the prd deliberation block; confirm full-depth orchestration with the candidate-piece decision unit, the dispatch order + barriers, the fallback handling, and that the first Step-4 message is the Investigation Summary; confirm the Opus pre-flight semantics.
  - Expected: all true. Failure: missing dispatch, wrong decision-unit, or hard-refusing pre-flight.

- [x] **[QA]** Phase review
  - Review against: AC-9, AC-24
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 9: Charter skill wiring — `skills/charter/SKILL.md`
Why serial: kept serial for per-phase Opus QA audit value on each calling-skill contract edit. Depends only on Phases 1–6 (the agents + the shared brainstorm loop), NOT on the sibling skill phases — this file is disjoint from Phases 8/9/10 with no symbol cross-refs, so it is parallelizable in principle; the wall-clock saving on a small markdown edit does not justify deferring QA to a group. It transcribes the same source the spec phase does (spec.md §Skill wiring + the Phase-6 loop), so Phase 7 is a sibling, not a prerequisite.
**Exit Gate:** `skills/charter/SKILL.md` carries an Opus pre-flight at skill-start and a `### Phase 1.9: Deliberation Protocol` block (full depth) before Phase 2 Socratic dialogue, with decision units = per-domain rules/principles and investigation covering existing codebase patterns + industry-standard rules (web research); the first Phase-2 message presents the Investigation Summary.
**ACs Covered:** AC-10b (charter per-domain deliberation block + context), AC-24 (charter Opus pre-flight)
**In scope:** MODIFY `plugins/spec-flow/skills/charter/SKILL.md` (skill-start pre-flight; Phase 1.9 deliberation block).
**NOT in scope:** the other skills (Phases 7–8, 10–11); the shared loop + agents (Phases 6, 3–5 — cited).
**Steps traversed (P2):** the Phase 1.9 block inserts between Phase 1.3 (Confirm combined signal summary) and Phase 2 (Socratic dialogue), traversing the Phase 1.x signal-gathering steps without invalidating them and re-seeding the Phase-2 first message; decision unit = per-domain rule/principle.
**Dispatch sites (P3):** five new dispatch sites; pre-existing charter dispatches (qa-charter, fix-doc) unchanged.
**Charter constraints honored in this phase:**
- NN-P-005 (Opus); NN-C-003 (backward compat, UNAVAILABLE/off fallback, silent pre-flight); NN-C-008 (self-contained dispatch); CR-008 (thin orchestrator).

- [x] **[Implement]** Wire the charter Opus pre-flight + Phase 1.9 deliberation block (full depth)
  - Architecture constraints: clone Phase 7's pre-flight (Cancel label "Cancel charter"; warning "Charter authoring is thinking work per NN-P-005…") and the deliberation block; use the `### Phase 1.N:` heading convention (introspection.md §4 Pattern Catalog). Decision unit = per-domain rule; coordinator investigation explicitly covers existing codebase patterns (research/L-10) + industry-standard rules for the project type (web research).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/charter/SKILL.md`** — Opus pre-flight (anchor: between frontmatter `---` and `# Charter — …`, ~line 8, introspection.md §4(a))
  - TARGET: insert `## Pre-flight: Model Check` mirroring Phase 7 T-1 (Opus-inverted), Cancel label "Cancel charter". Three choices; Override proceeds; silent when `opus`.
  - Done: pre-flight present with three choices + Override-proceeds + silent-when-opus.

  **T-2: MODIFY `plugins/spec-flow/skills/charter/SKILL.md`** — Phase 1.9 deliberation block (anchor: before `### Phase 2: Socratic dialogue`, line 311, introspection.md §4(b))
  - TARGET: insert `### Phase 1.9: Deliberation Protocol` (full depth; decision unit = per-domain rule/principle) transcribing steps 0–8 (Phase A→B[barrier]→C[skip ≤1 cluster]→D[5 lenses, barrier]→E; fatal/non-fatal handling; commit; first Phase-2 message = Investigation Summary). The Phase A inputs explicitly include existing codebase patterns + the domain being chartered + related industry-standard rules (web research). Include literal phase tokens + `barrier` + a one-line worked example (decision-unit = domain rule).
  - Done: the Phase 1.9 block present before Phase 2 with full-depth orchestration + the per-domain framing + the codebase-patterns/industry-standards context + worked example.

- [x] **[Verify]** Confirm the charter wiring
  **Per-change checks:**
  - T-1: `grep -c "Override\|Change now\|Cancel" plugins/spec-flow/skills/charter/SKILL.md` — Expected: ≥3; `grep -n -i "opus" plugins/spec-flow/skills/charter/SKILL.md` — Expected: pre-flight block present (AC-24).
  - T-2: `grep -n "deliberation-coordinator" plugins/spec-flow/skills/charter/SKILL.md` — Expected: ≥1 (AC-10b); AND `grep -nE "Phase 1.9|Phase A|barrier|Phase E" …` — Expected: present.
  **Phase-level check:**
  - Run: LLM-agent-step — read the Phase 1.9 block; confirm full-depth orchestration with the per-domain-rule decision unit, the codebase-patterns + industry-standards investigation context, the dispatch order + barriers + fallback, and that the first Phase-2 message is the Investigation Summary; confirm pre-flight semantics.
  - Expected: all true. Failure: missing context inputs, wrong decision-unit, or hard-refusing pre-flight.

- [x] **[QA]** Phase review
  - Review against: AC-10b, AC-24
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 10: Small-change skill wiring — `skills/small-change/SKILL.md` (lite depth, no pre-flight)
Why serial: kept serial for per-phase Opus QA audit value on the lite-depth wiring edit. Depends only on Phases 1–6; this file is disjoint from Phases 7/8/9 with no symbol cross-refs (parallelizable in principle), but the wall-clock saving on a small markdown edit does not justify deferring QA to a group. It transcribes the lite profile from spec.md §Skill wiring + `reference/deliberation-depth.md`, so the sibling skill phases are not prerequisites.
**Exit Gate:** `skills/small-change/SKILL.md` carries a `## Step 5b: Deliberation Protocol (lite depth)` block before Step 6 Focused Brainstorm, resolving depth to lite by default (whole piece = one cluster → Phase C no-op; Phase D = configured lens subset), with the first Step-6 message presenting the Investigation Summary. **No Opus pre-flight** (small-change is excluded per FR-009-N).
**ACs Covered:** AC-10 (small-change deliberation block before focused brainstorm), AC-19 (small-change lite-depth default resolution)
**In scope:** MODIFY `plugins/spec-flow/skills/small-change/SKILL.md` (pre-Step-6 deliberation block, lite depth).
**NOT in scope:** any Opus pre-flight (excluded); the other skills (Phases 7–9, 11); the shared loop + agents (Phases 6, 3–5 — cited); the depth-policy definition (Phase 2 — cited).
**Steps traversed (P2):** the Step 5b block inserts between Step 5 (L-10 scan) and Step 6 (Focused Brainstorm), traversing Steps 1–5 without invalidating them and re-seeding Step 6's first message; decision unit = the change.
**Dispatch sites (P3):** five new dispatch sites at lite profile (coordinator, 1 viability pass, no synthesis [≤1 cluster], 2 lenses, convergence); pre-existing small-change dispatches unchanged.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): lite default via `reference/deliberation-depth.md`; UNAVAILABLE/off fall back to today's Step-6 brainstorm.
- NN-C-008 (self-contained dispatch); CR-008 (thin orchestrator).

- [ ] **[Implement]** Wire the small-change lite-depth deliberation block
  - Architecture constraints: clone the deliberation block but resolve depth to **lite** by default (cite `reference/deliberation-depth.md`): whole piece = one cluster → Phase B single pass, Phase C no-op, Phase D = configured lens subset (default scope/simplicity + risk), Phase E. NO pre-flight. Use the `## Step Nb:` heading convention (introspection.md §3 Pattern Catalog).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/small-change/SKILL.md`** — Step 5b deliberation block (anchor: before `## Step 6: Focused Brainstorm`, line 70, introspection.md §3)
  - TARGET: insert `## Step 5b: Deliberation Protocol (lite depth)` transcribing the lite-profile orchestration: depth resolves to lite by default (cite `reference/deliberation-depth.md`; on `off` → `[DELIBERATION-SKIPPED: depth=off]`, run current Step-6 brainstorm, STOP); Phase A coordinator; Phase B single viability pass over the whole change (one cluster); Phase C skipped (≤1 cluster); Phase D = configured lens subset (default scope/simplicity + risk); Phase E convergence + commit; the first Step-6 message = Investigation Summary. 5-fatal/2-non-fatal handling per the marker contract. Include the literal `lite` token + a one-line worked example (decision-unit = the change; Phase C skipped).
  - Done: the Step 5b block present before Step 6, resolving to lite, with the single-cluster/Phase-C-skip + lens-subset profile + worked example; no pre-flight added.

- [ ] **[Verify]** Confirm the small-change wiring
  **Per-change checks:**
  - T-1: `grep -n "deliberation-coordinator" plugins/spec-flow/skills/small-change/SKILL.md` — Expected: ≥1 (AC-10).
  - T-1: `grep -n "lite" plugins/spec-flow/skills/small-change/SKILL.md` — Expected: ≥1 (lite-depth default resolution; satisfies AC-19's small-change grep).
  - T-1: `grep -c -i "opus.*pre-flight\|pre-flight.*model" plugins/spec-flow/skills/small-change/SKILL.md` — Expected: 0 (no pre-flight — small-change excluded).
  **Phase-level check:**
  - Run: LLM-agent-step — read the Step 5b block; confirm lite-depth resolution (whole piece = one cluster, Phase C no-op, lens subset), the fallback handling, and that the first Step-6 message is the Investigation Summary; confirm NO Opus pre-flight was added.
  - Expected: all true. Failure: full-depth used, a pre-flight added, or Phase C not skipped.

- [ ] **[QA]** Phase review
  - Review against: AC-10, AC-19
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 11: Plan skill consumption — `skills/plan/SKILL.md`
Why serial: edits the plan skill itself (the consumer); must follow Phase 1 (cites the deliberation artifact + markers); kept serial for per-phase Opus QA. (Meta-note: this phase edits the same SKILL.md that orchestrated this plan — the edit is additive to its Phase-1 context-load and changes no behavior of the run in progress.)
**Exit Gate:** `skills/plan/SKILL.md` carries an Opus pre-flight at skill-start and, in Phase 1 context-load (after the `[RESEARCH-CONSUMED]`/`[RESEARCH-ABSENT]` emit on BOTH paths), a deliberation-consumption step that reads `deliberation.md` §Recommendation + §Viability Analysis and emits `[DELIBERATION-CONSUMED: <recommendation>]` (present+non-empty) or `[DELIBERATION-ABSENT: no deliberation artifact]` (absent), using the recommendation as the approach anchor.
**ACs Covered:** AC-16 (plan reads deliberation.md + CONSUMED/ABSENT markers in Phase 1), AC-24 (plan Opus pre-flight)
**In scope:** MODIFY `plugins/spec-flow/skills/plan/SKILL.md` (skill-start pre-flight; Phase-1 deliberation-consumption step on both research paths).
**NOT in scope:** the deliberation dispatch (that is spec/prd/charter/small-change, Phases 7–10); the artifact/marker schema (Phase 1 — cited).
**Steps traversed (P2):** the consumption step inserts into the Phase-1 CONSUMED path (after line 101, the `[RESEARCH-CONSUMED]` emit) and the ABSENT path (after line 107, the `[RESEARCH-ABSENT]` emit), traversing the existing research-source-branch logic without invalidating it; the pre-flight inserts at skill-start.
**Dispatch sites (P3):** none — the plan skill CONSUMES `deliberation.md` (a file read), it dispatches no deliberation agent. The pre-existing plan dispatches (qa-plan, fix-doc) are unchanged.
**Charter constraints honored in this phase:**
- NN-C-003 (backward compat): `[DELIBERATION-ABSENT]` preserves current plan behavior (research.md as primary context); the consumption is additive; silent pre-flight when Opus.
- NN-P-005 (Opus): the pre-flight recommends Opus for plan authoring.
- CR-008 (thin orchestrator): the plan agent decomposes the recommendation; the skill only reads + emits the marker.

- [ ] **[Implement]** Wire the plan Opus pre-flight + Phase-1 deliberation consumption
  - Architecture constraints: clone Phase 7's pre-flight (Cancel label "Cancel plan"; warning "Plan authoring is thinking work per NN-P-005…"). The consumption step mirrors the existing CONSUMED/ABSENT dual-path pattern (introspection.md §5 Pattern Catalog) and emits the marker on BOTH research paths so the markers appear in order: research marker, then deliberation marker. Cite `reference/deliberation-artifact.md`.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`** — Opus pre-flight (anchor: between frontmatter `---` and `# Plan — …`, ~line 4, introspection.md §5(a))
  - TARGET: insert `## Pre-flight: Model Check` mirroring Phase 7 T-1 (Opus-inverted), Cancel label "Cancel plan". Three choices; Override proceeds; silent when `opus`.
  - Done: pre-flight present with three choices + Override-proceeds + silent-when-opus.

  **T-2: MODIFY `plugins/spec-flow/skills/plan/SKILL.md`** — Phase-1 deliberation consumption (anchors: after the CONSUMED-path `[RESEARCH-CONSUMED]` emit, ~line 101; and after the ABSENT-path `[RESEARCH-ABSENT]` emit, ~line 112; introspection.md §5(b))
  - Anchors (string anchors are authoritative; line numbers are exploration-time and may drift): CONSUMED path — immediately after the `5. Emit [RESEARCH-CONSUMED: <N> files, <M> re-read]` line (~line 101); ABSENT path — immediately after the `1. Emit [RESEARCH-ABSENT: running full exploration]` line (~line 112).
  - TARGET: on BOTH paths, after the research marker emit, add: "Read `deliberation.md` §Recommendation and §Viability Analysis from the piece branch (per `reference/deliberation-artifact.md` `## Location`). On file present and non-empty: emit `[DELIBERATION-CONSUMED: <recommendation-one-liner>]` and include 'Deliberation recommendation: <recommendation>' in the plan agent prompt as the approach anchor. On file absent or zero-length: emit `[DELIBERATION-ABSENT: no deliberation artifact]` and proceed with current behavior (research.md as primary context)." Place the insertion so the deliberation marker follows the research marker in Phase-1 output.
  - Done: both paths emit the deliberation marker after the research marker; the CONSUMED path feeds the recommendation to the plan agent; the ABSENT path preserves current behavior.

- [ ] **[Verify]** Confirm the plan consumption
  **Per-change checks:**
  - T-1: `grep -c "Override\|Change now\|Cancel" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥3; `grep -n -i "opus" plugins/spec-flow/skills/plan/SKILL.md` — Expected: pre-flight block present (AC-24).
  - T-2: `grep -nE "DELIBERATION-CONSUMED|DELIBERATION-ABSENT" plugins/spec-flow/skills/plan/SKILL.md` — Expected: ≥2 lines, and within the Phase-1 / context-load section (AC-16).
  **Phase-level check:**
  - Run: LLM-agent-step — read the Phase-1 consumption step; confirm it appears on BOTH the CONSUMED and ABSENT research paths, emits the deliberation marker AFTER the research marker, feeds §Recommendation to the plan agent on the present path, and preserves current behavior on the absent path; confirm pre-flight semantics.
  - Expected: all true. Failure: marker on only one path, wrong order, or a hard-refusing pre-flight.

- [ ] **[QA]** Phase review
  - Review against: AC-16, AC-24
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 12: qa-spec criteria + cross-phase schema-consistency check — `agents/qa-spec.md`
Why serial: cites the Phase-1 artifact structure; the cross-phase check must run after all schema-touching phases (1, 4, 11) have landed; kept serial for per-phase Opus QA.
**Exit Gate:** `agents/qa-spec.md` carries criterion 14 (deliberation structure: when `deliberation.md` is present, the 7 core H2 sections in order with the optional 8th `## Validation Rounds` tolerated; DELIBERATION-UNAVAILABLE/SKIPPED informational, NOT must-fix) and criterion 15 (grounding provenance: §Validated Open Questions entries are VOQ-ID-tagged — must-fix when present; the spec's Phase-2 instructions require VOQ-N/named-section citations; no finding on the UNAVAILABLE/SKIPPED path). The cross-phase schema-consistency check confirms the 7-section names agree across `deliberation-artifact.md` ↔ `deliberation-convergence.md` ↔ `qa-spec.md` criterion 14 ↔ `plan/SKILL.md` consumption.
**ACs Covered:** AC-13 (qa-spec deliberation-structure criterion), AC-20 (qa-spec grounding-provenance criterion)
**In scope:** MODIFY `plugins/spec-flow/agents/qa-spec.md` (add criteria 14 + 15 after criterion 13).
**NOT in scope:** the artifact schema (Phase 1 — cited, the SoT); the spec skill's Phase-2 citation instructions (Phase 7 — criterion 15 verifies they exist, does not author them).
**Charter constraints honored in this phase:**
- NN-C-002 (no runtime deps): markdown criterion additions.
- CR-009 (heading hierarchy): the numbered bold-label criterion format (introspection.md §7 Pattern Catalog).
- NN-C-003 (backward compat): both criteria are guarded — they add NO finding when `deliberation.md` is absent (UNAVAILABLE/SKIPPED), so pre-5.8.0 specs are unaffected.

- [ ] **[Implement]** Add criteria 14 and 15
  - Architecture constraints: follow the numbered bold-label criterion format `N. **Category:** Description.` (introspection.md §7, lines 531–544); the new criteria explicitly do NOT treat DELIBERATION-UNAVAILABLE/SKIPPED as must-fix (unlike criterion 7's NEEDS-CLARIFICATION/PENDING-DECISION). Cite `reference/deliberation-artifact.md` for the structure; do not restate the 7 sections.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/agents/qa-spec.md`** — append criteria 14 + 15 (anchor: after criterion 13 `**Integration allocation:**`, ~line 36, introspection.md §7(b))
  - CURRENT: criteria list ends at 13 (`**Integration allocation:**`).
  - TARGET: add:
    - `14. **Deliberation structure (when present):** When `deliberation.md` exists on the piece branch, confirm it contains the 7 core H2 sections in order (Investigation Summary, Viability Analysis, Integration Check, Adversarial Review, Recommendation, Validated Open Questions, Answered by Investigation) per `reference/deliberation-artifact.md`; an optional 8th `## Validation Rounds` after Answered by Investigation is permitted — do NOT flag its presence OR absence. Treat any `[DELIBERATION-UNAVAILABLE]`/`[DELIBERATION-SKIPPED]` in the spec artifact as informational, NOT must-fix. When `deliberation.md` is absent, note informational only — add no must-fix. Do NOT add a transcript-behavior check.`
    - `15. **Deliberation grounding provenance (when present):** When `deliberation.md` exists, confirm every §Validated Open Questions entry carries a stable `VOQ-N` ID (must-fix when present) and that the spec skill's Phase-2 instructions require every brainstorm question to cite a `VOQ-N` ID or a named deliberation section (per AC-8). Add no finding on the UNAVAILABLE/SKIPPED path.`
  - Done: criteria 14 + 15 present in the numbered format; both guarded against the absent path; the optional-8th tolerance + the UNAVAILABLE-informational rule stated; cite the artifact doc.
  - Verify: phase `[Verify]` greps the two criteria.

- [ ] **[Verify]** Confirm the qa-spec criteria + cross-phase schema consistency
  **Per-change checks:**
  - T-1: `grep -nE "^14\.|^15\." plugins/spec-flow/agents/qa-spec.md` — Expected: both criteria present.
  - T-1: `grep -c "VOQ\|grounding" plugins/spec-flow/agents/qa-spec.md` — Expected: ≥1 (AC-20's provenance criterion grep).
  - T-1: `grep -ci "deliberation.md\|Validation Rounds" plugins/spec-flow/agents/qa-spec.md` — Expected: ≥1 (AC-13's structure criterion grep).
  **Cross-phase schema-consistency check (FR-PROC-01 / ADR-2 — the deliberation.md 7-section schema spans Phases 1, 4, 11, 12):**
  - Run: LLM-agent-step — confirm the SEVEN core section names are byte-consistent across all four touch points: `reference/deliberation-artifact.md` `## deliberation.md structure` (definer, Phase 1) ↔ `agents/deliberation-convergence.md` Output Contract (writer, Phase 4) ↔ `agents/qa-spec.md` criterion 14 (checker, Phase 12) ↔ `skills/plan/SKILL.md` consumption (reads §Recommendation + §Viability Analysis, Phase 11). Specifically grep each file for the section names and confirm no file renames or drops a section, and that §Recommendation + §Viability Analysis (the two plan reads) are spelled identically to the artifact definer.
  - Concrete command: `for f in plugins/spec-flow/reference/deliberation-artifact.md plugins/spec-flow/agents/deliberation-convergence.md plugins/spec-flow/agents/qa-spec.md plugins/spec-flow/skills/plan/SKILL.md; do echo "== $f =="; grep -c "Recommendation\|Viability Analysis" "$f"; done` — Expected: each ≥1 (the two plan-consumed section names appear consistently in definer, writer, checker, and reader).
  - Expected: all four files agree on the seven section names; §Recommendation and §Viability Analysis spelled identically everywhere.
  - Failure: any file renames/drops a section, or the plan-read names diverge from the definer.

- [ ] **[QA]** Phase review
  - Review against: AC-13, AC-20
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 13: PRD authorship — FR-009 + NN-P-005 Scope + manifest coverage
Why serial: depends on the final AC set being stable (cross-references AC-1…AC-24 + AC-10b); kept serial for per-phase Opus QA on the PRD edit.
**Exit Gate:** `docs/prds/exec-ready/prd.md` contains an FR-009 section (Statement covering both tiers + the Opus pre-flight, Priority P0, US-009, AC cross-reference) after FR-008; NN-P-005's `Scope:` line reads `FR-004, FR-005, FR-009`; the priority table gains an FR-009 row; `docs/prds/exec-ready/manifest.yaml` coverage block reflects the new FR-009.
**ACs Covered:** AC-14 (FR-009 section + NN-P-005 Scope FR-009 + manifest coverage — the blocking Scope edit)
**In scope:** MODIFY `docs/prds/exec-ready/prd.md` (FR-009 section; NN-P-005 Scope; priority table row); MODIFY `docs/prds/exec-ready/manifest.yaml` (coverage block).
**NOT in scope:** the manifest piece-status flip (the plan-finalize step does specced→planned); the spec.md (already approved).
**Charter constraints honored in this phase:**
- NN-P-005 (Opus): the Scope provenance edit aligns the rule's Scope with its Statement (additive — no meaning change).
- NN-C-002 (no runtime deps): markdown + YAML edits.
- CR-009 (heading hierarchy): the FR section format matches FR-008 (introspection.md §14 Pattern Catalog).

- [ ] **[Implement]** Write FR-009, extend NN-P-005 Scope, update manifest coverage
  - Architecture constraints: the FR-009 section format clones FR-008 (introspection.md §14(a), lines 945–963); the Statement transcribes spec.md §"FR-009 content to write into prd.md" (lines 372–378); the AC list cross-references AC-1…AC-24 (incl. AC-10b).

  **Change Specifications:**

  **T-1: MODIFY `docs/prds/exec-ready/prd.md`** — FR-009 section (anchor: after FR-008's `**Failure mode:**` line, ~line 204, before `## Non-Functional Requirements`; introspection.md §14(a/c))
  - TARGET: insert `### FR-009: Investigation-First Design Protocol (Deliberation)` with: **Statement** (one paragraph covering BOTH tiers + the Opus pre-flight per spec.md lines 372–378 — must convey: protocol runs before any user question; Tier 2 validates the operator's own answers; output is a structured deliberation.md [7 core + optional Validation Rounds]; only unresolved questions are asked, each traceable; plan consumes the recommendation); **Priority:** P0; **#### User Stories** with **US-009** (spec.md line 376 verbatim); **Acceptance Criteria:** a `- [ ]` line cross-referencing AC-1 through AC-24 (incl. AC-10b) as the full FR-009 AC set; **Failure mode:** deliberation fails on any of the 5 fatal triggers → emits `[DELIBERATION-UNAVAILABLE]`, falls back to current brainstorm.
  - Done: the FR-009 section present in FR-008's format with both-tier Statement + P0 + US-009 + AC cross-ref + failure mode.

  **T-2: MODIFY `docs/prds/exec-ready/prd.md`** — NN-P-005 Scope (anchor: line 326, `- **Scope:** FR-004, FR-005`; introspection.md §14(b))
  - CURRENT: `- **Scope:** FR-004, FR-005`
  - TARGET: `- **Scope:** FR-004, FR-005, FR-009` (additive provenance edit; the Statement text is unchanged).
  - Done: the Scope line reads `FR-004, FR-005, FR-009`.

  **T-3: MODIFY `docs/prds/exec-ready/prd.md`** — priority table row (anchor: the FR priority table, ~lines 258–268 per introspection.md §14(c))
  - TARGET: add an FR-009 row after the FR-008 row, Priority P0 (matching the table's existing column shape).
  - Done: the priority table contains an FR-009 row.

  **T-4: MODIFY `docs/prds/exec-ready/manifest.yaml`** — coverage block (anchor: the `coverage:` block, lines 148–171)
  - CURRENT: `total_prd_sections: 12` … `covered_sections: 12` … `percentage: 100` with a `notes:` block.
  - TARGET: increment to reflect FR-009 (`total_prd_sections: 13`, `covered_sections: 13`, `percentage: 100`); append a one-line note that FR-009 (Investigation-First Design Protocol) is covered by the `spec-preresearch` piece. (Do NOT touch the `spec-preresearch` piece entry's `status:` here — the plan-finalize step owns specced→planned.)
  - Done: the coverage counts include FR-009; the note names the covering piece; the piece-status line is untouched.
  - Verify: phase `[Verify]` greps prd FR-009 + Scope + manifest coverage.

- [ ] **[Verify]** Confirm the PRD authorship
  **Per-change checks:**
  - T-1: `grep -n "### FR-009" docs/prds/exec-ready/prd.md` — Expected: the FR-009 heading (AC-14).
  - T-2: `grep -n "Scope:.*FR-009" docs/prds/exec-ready/prd.md` — Expected: the NN-P-005 Scope line contains FR-009 (**blocking** — AC-14).
  - T-3: `grep -nE "FR-009.*P0|P0.*FR-009" docs/prds/exec-ready/prd.md` — Expected: the priority-table FR-009 row present (P0).
  - T-4: `grep -nE "total_prd_sections: 13|FR-009" docs/prds/exec-ready/manifest.yaml` — Expected: coverage reflects FR-009.
  **Phase-level check:**
  - Run: LLM-agent-step — read the FR-009 section; confirm the Statement covers BOTH tiers + the Opus pre-flight, Priority is P0, US-009 is present, the AC line cross-references AC-1…AC-24 (incl. AC-10b), and the priority table carries an FR-009 row; confirm NN-P-005 Scope now includes FR-009 and its Statement is unchanged.
  - Expected: all true. Failure: a one-tier Statement, a missing US-009, or an unchanged Scope line.

- [ ] **[QA]** Phase review
  - Review against: AC-14
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

### Phase 14: Version bump 5.7.0 → 5.8.0
Why serial: must be last — the CHANGELOG describes the finished piece; depends on all prior file additions existing.
**Exit Gate:** `plugins/spec-flow/.claude-plugin/plugin.json` and the spec-flow entry in `.claude-plugin/marketplace.json` both read `5.8.0`; `plugins/spec-flow/CHANGELOG.md` has a `## [5.8.0] — 2026-06-09` section with non-empty Added/Changed groupings naming the new agents, reference docs, and skill wiring. (No root `plugin.json` exists — AC-15's "if present" clause is a no-op.)
**ACs Covered:** AC-15 (version sync 5.8.0 across plugin.json + marketplace.json + CHANGELOG)
**In scope:** MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` (version), `.claude-plugin/marketplace.json` (spec-flow version, line 15 only), `plugins/spec-flow/CHANGELOG.md` (new 5.8.0 section).
**NOT in scope:** any behavior change (all prior phases); the `qa` plugin entry in marketplace.json (line 24 — do NOT touch).
**Charter constraints honored in this phase:**
- NN-C-001 (version/marketplace sync): plugin.json + marketplace.json both → 5.8.0.
- NN-C-007 (CHANGELOG format): Keep a Changelog `## [5.8.0]` section.
- NN-C-009 (version bump): all version-bearing files bumped in this commit series.
- NN-C-002 (no runtime deps): JSON/markdown edits only.

- [ ] **[Implement]** Bump the version files + author the CHANGELOG entry
  - Architecture constraints: follow `plugins/spec-flow/reference/releasing.md` (the version recipe); the CHANGELOG entry inserts between `## [Unreleased]` (line 5) and `## [5.7.0]` (line 7) per the Keep-a-Changelog format (introspection.md §12(c)).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`** (anchor: line 4, `"version": "5.7.0"`)
  - TARGET: `"version": "5.8.0"`. Done: reads 5.8.0.

  **T-2: MODIFY `.claude-plugin/marketplace.json`** (anchor: line 15, the spec-flow `"version": "5.7.0"` — introspection.md §12(b))
  - TARGET: line 15 → `"version": "5.8.0"`. Do NOT touch line 24 (the `qa` plugin). Done: spec-flow entry reads 5.8.0; qa entry unchanged.

  **T-3: MODIFY `plugins/spec-flow/CHANGELOG.md`** (anchor: insert after line 5 `## [Unreleased]`, before line 7 `## [5.7.0]`)
  - TARGET: insert `## [5.8.0] — 2026-06-09` with `### Added` (the six new agents — `deliberation-coordinator/-viability/-synthesis/-lens/-convergence/-validate`; the two reference docs — `deliberation-artifact.md`, `deliberation-depth.md`; the optional `.spec-flow.yaml deliberation.depth` key) and `### Changed` (the Tier-1/Tier-2 wiring into `skills/{spec,prd,small-change,charter}/SKILL.md`; `deliberation.md` consumption in `skills/plan/SKILL.md`; the Opus pre-flight in spec/prd/plan/charter; the `reference/brainstorm-procedure.md` Tier-2 loop + C-2 amendment; the `qa-spec.md` criteria 14/15; the FR-009 PRD section + NN-P-005 Scope extension). One bullet per significant item.
  - Done: the `## [5.8.0]` section exists with non-empty Added + Changed groupings.
  - Verify: phase `[Verify]` checks version sync + CHANGELOG heading.

- [ ] **[Verify]** Confirm version sync
  **Per-change checks:**
  - T-1/T-2: `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[] | select(.name == "spec-flow") | .version' .claude-plugin/marketplace.json)` — Expected: no output (both 5.8.0; AC-15).
  - T-1: `jq -r .version plugins/spec-flow/.claude-plugin/plugin.json` — Expected: `5.8.0`.
  - T-3: `grep -n "## \[5.8.0\]" plugins/spec-flow/CHANGELOG.md` — Expected: the heading present (AC-15).
  - T-2: `jq -r '.plugins[] | select(.name == "qa") | .version' .claude-plugin/marketplace.json` — Expected: `1.1.1` (unchanged — qa entry not touched).
  **Phase-level check:**
  - Run: LLM-agent-step — read the CHANGELOG 5.8.0 section; confirm Added names the six agents + two reference docs and Changed names the skill wiring + qa-spec + PRD edits.
  - Expected: all present. Failure: empty groupings, a missing file, or the qa entry altered.

- [ ] **[QA]** Phase review
  - Review against: AC-15
  - Diff baseline: git diff {{phase_start_tag}}..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | Five Tier-1 agent files exist + spec Phase-2 dispatch block | COVERED | Phase 3 (coord/viab/synth), Phase 4 (lens/conv), Phase 7 (spec dispatch) |
| AC-2 | full-depth strict order A→B(barrier)→C→D(barrier)→E + no VOQ before E + ≤1-cluster Phase-C no-op | COVERED | Phase 7 |
| AC-3 | Viability: all paths (incl. reuse), VIABLE/NON-VIABLE + concrete blocker | COVERED | Phase 3 (viability agent), Phase 1 (table format) |
| AC-4 | Coordinator web research fires on genuine unknown / not otherwise | COVERED | Phase 3 (coordinator) |
| AC-5 | Phase C integration check flags cross-unit conflicts | COVERED | Phase 3 (synthesis), Phase 1 (§Integration Check format) |
| AC-6 | Phase D adversarial review documented; CONTESTED→VOQ; all-HOLDS recorded | COVERED | Phase 4 (lens + convergence) |
| AC-7 | Phase E writes deliberation.md 7 core H2 in order + reference doc is SoT | COVERED | Phase 1 (SoT + ls test), Phase 4 (convergence writer) |
| AC-8 | Spec investigation-first first message + VOQ-cited question gate | COVERED | Phase 7 (spec), Phase 6 (shared citation requirement) |
| AC-9 | PRD deliberation runs before decomposition brainstorm | COVERED | Phase 8 |
| AC-10 | small-change deliberation before focused brainstorm | COVERED | Phase 10 |
| AC-10b | Charter per-domain deliberation + context (codebase + industry) | COVERED | Phase 9 |
| AC-11 | Mandatory-block N/A auto-skip (non-silent) + confirmation-not-discovery | COVERED | Phase 6 (brainstorm-procedure), Phase 7 (spec applies) |
| AC-12 | 5 fatal UNAVAILABLE triggers + 2 non-fatal partials | COVERED | Phase 1 (def), Phase 7 (spec applies) |
| AC-13 | qa-spec deliberation-structure criterion (7 sections, optional-8th tolerated, UNAVAILABLE informational) | COVERED | Phase 12 (criterion 14), Phase 1 (structure def) |
| AC-14 | prd FR-009 section + NN-P-005 Scope FR-009 + manifest coverage | COVERED | Phase 13 |
| AC-15 | version sync 5.8.0 across plugin.json + marketplace + CHANGELOG | COVERED | Phase 14 |
| AC-16 | plan reads deliberation.md + CONSUMED/ABSENT markers in Phase 1 | COVERED | Phase 11 |
| AC-17 | Phase B parallel + barrier; single cluster → 1 agent + Phase-C no-op | COVERED | Phase 3 (viability frontmatter), Phase 7 (spec barrier) |
| AC-18 | 5 lens agents full depth + `{lens}` param slot + convergence folds + CONTESTED→VOQ | COVERED | Phase 4 (lens param + convergence), Phase 7 (5 labels) |
| AC-19 | depth full/lite/off profiles + per-skill defaults + small-change lite | COVERED | Phase 2 (depth def), Phase 10 (small-change lite) |
| AC-20 | VOQ-N IDs + qa-spec grounding-provenance criterion | COVERED | Phase 1 (VOQ def), Phase 12 (criterion 15), Phase 7 (spec citation) |
| AC-21 | Tier-2 assertion detection + auto-fire deliberation-validate; no deliberation.md→no fire | COVERED | Phase 5 (validate agent), Phase 6 (detection+fire wiring) |
| AC-22 | CONFIRM/FLAG-HARD/FLAG-SOFT verdict + hard-no-override/soft-override | COVERED | Phase 5 (agent verdict), Phase 6 (brainstorm-procedure branch) |
| AC-23 | ## Validation Rounds 8th section + human-paced termination | COVERED | Phase 1 (Validation-Round def), Phase 6 (human-paced rule) |
| AC-24 | Opus pre-flight spec/prd/plan/charter (3 choices, Override-proceeds, silent-opus) | COVERED | Phase 7 (spec), Phase 8 (prd), Phase 9 (charter), Phase 11 (plan) |

All 25 ACs COVERED — no NOT-COVERED rows; no forward pointers required.

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | shell | `ls plugins/spec-flow/agents/deliberation-{coordinator,viability,synthesis,lens,convergence}.md` | all exit 0 |
| AC-1 | shell | `grep -n "deliberation-coordinator" plugins/spec-flow/skills/spec/SKILL.md` | ≥1 dispatch line |
| AC-2 | shell | `grep -nE "Phase A|Phase B|barrier|Phase C|Phase D|Phase E" plugins/spec-flow/skills/spec/SKILL.md` | all six tokens present |
| AC-3 | shell | `grep -ci "reuse\|NON-VIABLE\|blocker" plugins/spec-flow/agents/deliberation-viability.md` | ≥3 |
| AC-4 | agent-step | Read `deliberation-coordinator.md`; confirm both web-fires and explicit-no-web branches | both present |
| AC-5 | shell | `grep -ci "compose\|conflict\|integrat" plugins/spec-flow/agents/deliberation-synthesis.md` | ≥2 |
| AC-6 | shell | `grep -c "HOLDS\|CONTESTED" plugins/spec-flow/agents/deliberation-lens.md` | ≥2 |
| AC-7 | shell | `ls plugins/spec-flow/reference/deliberation-artifact.md && grep -c "Investigation Summary\|Viability Analysis\|Integration Check\|Adversarial Review\|Recommendation\|Validated Open Questions\|Answered by Investigation" plugins/spec-flow/reference/deliberation-artifact.md` | exit 0; ≥7 |
| AC-8 | shell | `grep -c "VOQ" plugins/spec-flow/skills/spec/SKILL.md` | ≥1 |
| AC-9 | shell | `grep -n "deliberation-coordinator" plugins/spec-flow/skills/prd/SKILL.md` | ≥1 |
| AC-10 | shell | `grep -n "deliberation-coordinator" plugins/spec-flow/skills/small-change/SKILL.md` | ≥1 |
| AC-10b | shell | `grep -n "deliberation-coordinator" plugins/spec-flow/skills/charter/SKILL.md` | ≥1 |
| AC-11 | shell | `grep -ni "Amendment (v5.8.0\|auto-skip is not silent" plugins/spec-flow/reference/brainstorm-procedure.md` | ≥1 (and "never silently skip" still present) |
| AC-12 | agent-step | Read `deliberation-artifact.md` marker contract; confirm 5 fatal + 2 non-fatal enumerated | both sets present |
| AC-13 | shell | `grep -nE "^14\." plugins/spec-flow/agents/qa-spec.md` | criterion 14 present |
| AC-14 | shell | `grep -n "### FR-009" docs/prds/exec-ready/prd.md && grep -n "Scope:.*FR-009" docs/prds/exec-ready/prd.md` | both match (Scope = blocking) |
| AC-15 | shell | `diff <(jq -r .version plugins/spec-flow/.claude-plugin/plugin.json) <(jq -r '.plugins[]\|select(.name=="spec-flow").version' .claude-plugin/marketplace.json) && grep -n "## \[5.8.0\]" plugins/spec-flow/CHANGELOG.md` | no diff; heading present |
| AC-16 | shell | `grep -nE "DELIBERATION-CONSUMED\|DELIBERATION-ABSENT" plugins/spec-flow/skills/plan/SKILL.md` | ≥2 lines in Phase 1 |
| AC-17 | shell | `grep -E "^name: deliberation-viability$\|^model: opus$" plugins/spec-flow/agents/deliberation-viability.md` | both match |
| AC-18 | shell | `grep -c "{lens}" plugins/spec-flow/agents/deliberation-lens.md && grep -c "architecture-integrity\|scope/simplicity\|user-intent\|backward-compat\|risk" plugins/spec-flow/skills/spec/SKILL.md` | ≥1; ≥5 |
| AC-19 | shell | `ls plugins/spec-flow/reference/deliberation-depth.md && grep -n "lite" plugins/spec-flow/skills/small-change/SKILL.md && grep -n "DELIBERATION-SKIPPED" plugins/spec-flow/reference/deliberation-depth.md` | exit 0; both ≥1 |
| AC-20 | shell | `grep -n "VOQ" plugins/spec-flow/reference/deliberation-artifact.md && grep -ni "VOQ\|grounding" plugins/spec-flow/agents/qa-spec.md` | both ≥1 |
| AC-21 | shell | `ls plugins/spec-flow/agents/deliberation-validate.md && grep -c "deliberation-validate\|new assertion\|evaluated path" plugins/spec-flow/reference/brainstorm-procedure.md` | exit 0; ≥2 |
| AC-22 | shell | `grep -c "FLAG-HARD\|FLAG-SOFT\|CONFIRM" plugins/spec-flow/agents/deliberation-validate.md && grep -ni "override" plugins/spec-flow/reference/brainstorm-procedure.md` | ≥3; shows hard=no-override/soft=override |
| AC-23 | shell | `grep -n "Validation Rounds" plugins/spec-flow/reference/deliberation-artifact.md && grep -ni "sign-off\|no new assertion\|human-paced" plugins/spec-flow/reference/brainstorm-procedure.md` | both ≥1 |
| AC-24 | shell | `for s in spec prd charter plan; do grep -c "Override\|Change now\|Cancel" plugins/spec-flow/skills/$s/SKILL.md; done` | each ≥3 |

## Contracts

No TDD-track phases in this plan (`tdd: false`) — the Contracts section is present for forward compatibility; `tdd-red` agents are not dispatched and no contract injection occurs. The piece's genuine boundary-crossing interfaces — the `deliberation.md` 7+1-section schema, the four markers (`[DELIBERATION-UNAVAILABLE/-SKIPPED/-CONSUMED/-ABSENT]`), the VOQ-N ID format, the Validation-Round format, the per-agent ≤2K/STATUS return contract, and the three Tier-2 verdicts — are defined canonically in `reference/deliberation-artifact.md` (Phase 1) and `reference/deliberation-depth.md` (Phase 2), cited (never restated) by the six agents and five skills, and verified by the **cross-phase schema-consistency check in Phase 12's `[Verify]`** (definer ↔ writer ↔ checker ↔ reader agreement on the seven section names).

## Parallel Execution Notes

All phases run **serial**; no Phase Groups; no Phase 0 Scaffold. The file-per-phase decomposition (ADR-5) means **no shared coordination file is appended by ≥2 phases** — each agent file, reference doc, skill file, the PRD, and the version files are each touched in exactly one phase — so there is no contention to scaffold away and no `[P]` parallelism to exploit. Many phases touch disjoint files and could in principle parallelize after the Phase-1/2 contracts land, but they are kept serial deliberately (see the `Why serial:` line on each affected phase) for three reasons: **cite-before-use** ordering (agents cite the Phase-1/2 contracts; skill wiring cites the Phase-6 loop + the agents), **per-phase Opus QA audit value** on each edit to a shipped/merged plugin contract surface, and **negligible wall-clock** for small markdown edits. Phase 1 must precede all (defines the cited artifact contract); Phase 6 must precede the skill-wiring phases (7–10); Phase 14 must be last (the CHANGELOG describes the finished piece). Phase 12's cross-phase check must run after Phases 1, 4, and 11 (all schema touch points) have landed.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase `[Implement]` Change Specs (T-N blocks), spec ACs, the phase `[Verify]` commands, arch constraints, pattern blocks, the `introspection.md` anchors for the phase scope | Spec rationale, brainstorming history, other phases' internals |
| Verify | The phase `[Verify]` commands + expected outputs, the cross-phase schema check (Phase 12), spec ACs | Implementation reasoning |
| QA | Phase diff, spec, plan, PRD sections, charter (NN-C/NN-P/CR) | Any agent conversation history |
| Refactor (optional, auto-skipped per `.spec-flow.yaml refactor: auto`) | Current files (phase scope only), the `[Verify]` command, quality principles | Prior agent conversations |
