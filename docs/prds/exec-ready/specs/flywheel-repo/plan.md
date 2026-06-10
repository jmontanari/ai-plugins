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

# Plan: flywheel-repo

**Spec:** docs/prds/exec-ready/specs/flywheel-repo/spec.md
**Charter:** .claude/skills/charter-*/SKILL.md (binding — each phase enumerates its honored NN-C/NN-P/CR entries)
**Status:** final-review-pending

## Overview

Non-TDD mode (doc-as-code): all phases use `[Implement]` → `[Write-Tests]` → `[Verify]` → `[QA]`. There is
**no test runner** in this toolchain (charter-tools: Runner = None); `[Write-Tests]` authors the grep/inspection
assertions for each phase's ACs (the `[Verify]` block runs the greppable subset), and manual smoke scenarios are
documented as verification checklist items. AC Coverage Matrix is included (not strictly required in non-TDD
mode) because it maps the 11 spec ACs to phases and strengthens the plan; QA and Final Review remain intact.

Five serial phases, inside-out:
1. **`reference/flywheel.md`** — the single source of truth (schema, count rule, match/confirm flow, source
   taxonomy, threshold/batched-routing, hardening flow, `[FLYWHEEL-DEGRADED]` marker). Everything else cites it.
2. **Config key** — `flywheel_threshold` in `.spec-flow.yaml` + `templates/pipeline-config.yaml`.
3. **execute Step 6c record + match-propose hook** (per-phase + reflection sources) + degraded path.
4. **execute Step 4.5 batched proposal + hardening** (reuses the existing spike `scope` → Step 6c amend path)
   + spike-`BLOCKED` escalation + the `reference/flywheel.md` citation.
5. **Version bump** 5.7.0 → 5.8.0 across the four version-bearing files + CHANGELOG + version-sync sweep.

The hardening path is **reuse, not invention**: the flywheel dispatches the existing `agents/spike.md` in
`scope` mode and feeds the artifact to the existing Step 6c `plan-amend` path (execute/SKILL.md 1089–1104,
1844). No new agent, no new amend mechanism. `docs/patterns.yaml` is NOT shipped by this piece — it is created
lazily at execute-time of future pieces (spec SF-1).

## Architectural Decisions

### ADR-1: Reuse the existing spike→Step-6c-amend path for hardening (no new auto-scaffold mechanism)
**Context:** an approved hardening proposal needs (a) Opus thinking to figure out the concrete fix and (b) a way
to apply it. Both already exist: `agents/spike.md` `scope` mode (Opus, isolated) and the Step 6c `plan-amend`
dispatch. Execute runs on Sonnet (NN-P-005), so authoring a charter/PRD fix in-loop is impossible without an
isolated Opus path — which the spike *is*.
**Decision:** on approval, the flywheel dispatches `agents/spike.md` in `scope` mode, then hands the scoping
artifact to the existing Step 6c reflection-finding `amend` dispatch (execute 1844). No new mechanism.
**Alternatives considered:** (1) a new auto-scaffold mechanism that invokes charter/prd skills in-loop — breaks
the Sonnet/Opus boundary and adds a large new surface; (2) a draft-stub + queued-handoff artifact — invents a
parallel amend path the pipeline doesn't need.
**Consequences:** zero new agents/mechanisms; the flywheel gains a runtime dependency on `spike-agent` (already
merged) and `plan-amend`; the hardening re-enters the Per-Phase Loop + Final Review before merge automatically.
**Charter alignment:** honors NN-P-005 (Opus thinking via the sanctioned isolated agent), NN-P-002 (routes
through scope→amend→execute, never a mid-stream patch), CR-008 (no heavyweight new orchestrator logic).

### ADR-2: Per-(pattern, piece) count with dedup-on-piece (not per-finding)
**Context:** PRD Open Question ("one per piece … or one per reflection finding?"). FR-006 AC1 says
"count = occurrences length"; the edge case says "twice in one repo → two occurrences → threshold trips."
**Decision:** one occurrence per `(pattern, piece)`; recurrence within a single piece does not advance the count.
**Alternatives considered:** per-finding counting (a single noisy piece self-trips threshold=2, defeating
cross-piece correlation); per-PRD counting (too coarse — loses piece-level provenance).
**Consequences:** because occurrences are deduped per piece, `count = len(occurrences)` holds exactly (FR-006 AC1
satisfied); "twice in one repo" = two distinct pieces, aligned with the PRD's cross-piece correlation goal.
**Charter alignment:** consistent with FR-006 AC1; no charter conflict.

### ADR-3: Schema-open / wire-narrow source taxonomy (`metric` reserved, unwired)
**Context:** the operator wanted the registry to be *able* to count execute metrics (broad) yet keep this piece
tight (defer FO-2/FO-3). Literally doing both conflicts.
**Decision:** the occurrence `source_type` enum admits `{reflection-finding, execute-discovery, metric}`, but
this piece wires only the first two (both already flow through Step 6c); no path emits a `metric` occurrence.
**Alternatives considered:** fully broad (wire admission-`n` + spike-count emitters now — un-defers FO-2/FO-3,
materially bigger); fully tight (drop `metric` from the schema — forces a schema restructure when FO-2/FO-3 land).
**Consequences:** FO-2/FO-3 and `flywheel-global` become additive (one field / one emitter), not restructures.
**Charter alignment:** NN-C-003 (additive, backward-compatible).

### ADR-4: Hardening amends the current piece in-place at Step 4.5 (not fork-to-follow-on)
**Context:** the operator chose amend-in-place. The batched proposal fires at end-of-piece Step 4.5 Reflection —
*after* the Final Review board and Human Sign-Off, *before* merge.
**Decision:** the approved hardening reuses the existing Step 4.5 reflection-finding `amend` path, which re-runs
amendment phases through the full Per-Phase Loop + a fresh Final Review pass before merge.
**Alternatives considered:** `fork` to a follow-on piece (an existing Step 6c option) — defers the fix and risks
it never being prioritized, conflicting with the operator's "fix it now" intent.
**Consequences:** the current piece's diff absorbs often-orthogonal repo hardening (gated + provenance-tagged in
`.discovery-log.md` + `patterns.yaml`, so not a silent scope addition); the amendment consumes the standard
5-total/1-spec budget, bounding recursion.
**Charter alignment:** NN-P-001 (sign-off still fires; hardening is a second, distinct gate whose amend re-enters
review), NN-P-002 (recorded, reviewed, never mid-stream).

## Integration-Test Registry (M1)

Absent ⇒ no `[integration]` outer tests declared (NFR-INT-02). This is a doc-as-code piece with no test runner;
the flywheel→spike and flywheel→plan-amend integration boundaries are verified by the Final Review
`review-board-integration` reviewer tracing the wired prose path (spec Integration Coverage), not by an automated
outer test. No registry rows.

## Phases

### Phase 1: Author `reference/flywheel.md` (single source of truth)
**Exit Gate:** `reference/flywheel.md` exists with all required `## ` sections; the schema block, count rule,
rejection rule, and `[FLYWHEEL-DEGRADED]` marker are present and grep-verifiable; an inline worked example traces
the match→count algorithm at concrete values.
**ACs Covered:** AC-1, AC-2, AC-7, AC-8 (marker definition)
<!-- Branch-enumeration ACs (doc-as-code, plan-concreteness §3): the deliverable's conditional branches —
match-vs-new, same-piece-vs-new-piece (AC-2), reject-then-worsen re-propose (AC-7), unwritable-vs-unparseable
degraded (AC-8) — each map to the listed numbered ACs. No uncovered branch. -->
**In scope:** CREATE `plugins/spec-flow/reference/flywheel.md` only.
**NOT in scope:** the execute hook (Phase 3/4), the config key (Phase 2), version bump (Phase 5),
`docs/patterns.yaml` itself (created lazily at execute-time of future pieces — never authored here).
**Charter constraints honored in this phase:**
- NN-C-002 (toolchain): pure markdown; the schema is illustrative YAML read by the LLM natively — no parser/runtime.
- NN-C-008 (single source of truth / self-contained reference): definitions live here and nowhere else.
- CR-004 (Conventional Commits) — honored by ALL phases via the per-phase commit convention (`chore(flywheel-repo): …`, and `chore(plan): amend …` for flywheel-origin amendments); flagged here as the single cross-cutting owner.
- SF-N4 (global-reuse factoring, piece NFR): the schema reserves `originating_repo` + `plugin` scope for flywheel-global.

- [x] **[Implement]** Author the reference doc per the structure below.
  - Order: preamble → schema → count rule → match/confirm flow → source taxonomy → threshold/batched-routing →
    hardening flow → degraded marker → See also. Checkpoint after the schema block, then after each `## ` section.
  - Architecture constraints: model the file structure on `plugins/spec-flow/reference/spike-agent.md` (one-line
    "Single source of truth … Cited by … Definitions live here and nowhere else." preamble, `## ` sections, a
    `## See also` footer). NN-C-002: no `yq`/`jq`/`python`.

  **Change Specifications:**

  **T-1: CREATE `plugins/spec-flow/reference/flywheel.md`**
  - Structure outline (each `## ` is a required section):
    1. Preamble (one line): "Single source of truth for the repo-level self-hardening flywheel (FR-006) — the
       `docs/patterns.yaml` schema, stable-ID scheme, match/confirm flow, count/threshold/batched-routing
       mechanics, the hardening dispatch, and the `[FLYWHEEL-DEGRADED]` marker. Cited by
       `plugins/spec-flow/skills/execute/SKILL.md` (Step 6c record/match hook + Step 4.5 batched proposal).
       Reused by the `flywheel-global` piece (FR-007). Definitions live here and nowhere else."
    2. `## Registry schema` — emit this exact illustrative block, then a field-by-field description and the
       count/dedup rule:
       ```yaml
       schema_version: 1
       generated: 2026-06-08
       last_updated: 2026-06-08
       patterns:
         - id: stale-charter-snapshot         # stable kebab slug; LLM-proposed, operator-confirmed
           description: charter_snapshot drift not re-checked before authoring
           scope: charter                      # charter | qa | prd  (flywheel-global adds: plugin)
           occurrences:
             - piece: exec-ready/plan-concrete
               date: 2026-06-07
               source: "reflection-future-opportunities: qa-spec lacks branch-enumeration AC"
               source_type: reflection-finding # reflection-finding | execute-discovery | metric
               # originating_repo: <reserved — flywheel-global only>
           rejections: []                      # each: { date, rationale, rejected_at_count }
       ```
       Field rules to state in prose: `id` is a stable kebab slug; `scope ∈ {charter, qa, prd}` (flywheel-global
       adds `plugin`); each occurrence carries `{piece, date, source, source_type}`; `source_type ∈
       {reflection-finding, execute-discovery, metric}` (the `metric` value and the `originating_repo` field are
       RESERVED — no writer emits them in the repo flywheel); `rejections[]` each `{date, rationale,
       rejected_at_count}`. Lazily created on first confirmed occurrence (the piece does not ship the file).
    3. `## Count rule` — "Count = number of **distinct `piece` values** in `occurrences`. Recording is **deduped
       per piece**: if the matched pattern already has an occurrence for the current piece, no occurrence is
       added (count unchanged); a finding in a not-yet-recorded piece adds one (count increments). Because of
       dedup, `occurrences` holds at most one entry per piece, so `count = len(occurrences)`." Immediately follow
       with the inline worked example (dense-algorithm guard — concrete trace):
       ```
       Worked example (threshold = 2):
         pattern `stale-charter-snapshot`, occurrences = [plan-concrete]            → count 1, no trip
         same finding recurs in plan-concrete (same piece)        → deduped, no add → count 1, no trip
         finding recurs in sonnet-coord (new piece)               → add occurrence  → count 2, TRIPS threshold
       ```
    4. `## Match + confirm flow (no silent write)` — at the Step 6c hook the flywheel proposes either an existing
       `id` or "new" with an LLM-proposed kebab slug; it writes NOTHING to `docs/patterns.yaml` until the operator
       confirms classification (which pattern) and scope (`charter|qa|prd`); on a "new" confirm the operator may
       rename the slug, and the rename becomes the stored `id`. Matches are LLM-proposed, human-confirmed
       (NN-P-004). Reuses the single-aggregated-prompt-per-phase convention (NFR-6).
    5. `## Source taxonomy (schema-open, wire-narrow)` — `reflection-finding` (the two reflection agents' findings
       routed through Step 6c at Step 4.5) and `execute-discovery` (native per-phase Step 6c discoveries) are
       WIRED; `metric` is a reserved enum value with NO emitter in this piece (FO-2/FO-3 deferred).
    6. `## Threshold + batched proposal` — read `flywheel_threshold` (plain int, default 2) from `.spec-flow.yaml`;
       at end-of-piece Step 4.5, after this piece's reflection findings are recorded, surface ONE batched proposal
       listing every pattern whose distinct-piece count ≥ threshold, each with its recorded `scope` as the routing
       home (`charter` → charter amendment, `qa` → local QA hardening, `prd` → PRD work).
    7. `## Hardening dispatch (reuse)` — on operator approval: dispatch `agents/spike.md` in `scope` mode (Opus,
       isolated) with `{pattern, occurrences, proposed home}`; on `STATUS: OK` read the spike artifact, then route
       through the EXISTING Step 6c reflection-finding `amend` dispatch (plan-amend appends the scoped phases,
       which run the full Per-Phase Loop + re-enter Final Review before merge; amendment budget 5/1 applies); record
       the accepted outcome + spike-artifact reference against the pattern; append the standard `.discovery-log.md`
       row. On `STATUS: BLOCKED`: escalate with the spike's findings, produce NO amendment, apply NO mid-stream
       patch, and record the pattern as proposed-but-unresolved (NOT a rejection).
    8. `## Rejection rule` — on operator rejection, append `rejections: [{date, rationale, rejected_at_count}]`;
       the pattern is excluded from future proposals while its distinct-piece count ≤ `rejected_at_count`, and is
       proposed again once a new occurrence pushes the count above `rejected_at_count`.
    9. `## Degraded path` — define the marker `[FLYWHEEL-DEGRADED: repo registry unavailable]` (verbatim): emitted
       as a single bracketed orchestrator line when `docs/patterns.yaml` is unwritable OR unparseable; NO registry
       write occurs; execute is NOT blocked or failed; the triggering finding still flows to its normal Step 6c
       triage / reflection resolution. Mirrors the `[RESEARCH-UNAVAILABLE]` / `[TEST-DATA-ABSENT]` convention.
    10. `## See also` — list `plugins/spec-flow/skills/execute/SKILL.md`, `plugins/spec-flow/agents/spike.md`,
        `plugins/spec-flow/reference/spike-agent.md`, `plugins/spec-flow/agents/plan-amend.md`,
        `plugins/spec-flow/reference/research-artifact.md`.
  - Pattern (preamble shape, from `reference/spike-agent.md:1-3`):
    ```
    # Spike Agent — modes, artifact schema, classification, placement, threshold, budget
    Single source of truth for the spike agent (...). Cited by (...). Definitions live here and nowhere else.
    ```
  - Done: the file exists with sections 1–10; the schema block, the worked example, the `rejected_at_count` rule,
    and the verbatim marker string are all present.
  - Verify: `grep -nE 'schema_version|occurrences|rejections|source_type|rejected_at_count|FLYWHEEL-DEGRADED' plugins/spec-flow/reference/flywheel.md` returns hits for each token.

- [x] **[Write-Tests]** Author the grep/inspection assertions for this phase's ACs.
  - No test runner exists (charter-tools); the assertions below ARE the test artifact and run in `[Verify]`.
  - Manual smoke scenario (AC-2): walk the worked example — confirm same-piece recurrence does not increment and a
    new-piece occurrence does.

  **Test Data:**
  - AC-1: input = `reference/flywheel.md` → expect schema block with `schema_version`, `occurrences` (4 fields:
    piece/date/source/source_type), `rejections`, AND a worked example present.
  - AC-2: input = the count rule prose → expect "distinct `piece`" + dedup-per-piece + the worked-example trace.
  - AC-7: input = the rejection rule prose → expect `rejected_at_count` re-propose semantics.
  - AC-8: input = the degraded section → expect the verbatim string `[FLYWHEEL-DEGRADED: repo registry unavailable]`
    + "no … write" + "not blocked" + "finding still flows".

- [x] **[Verify]** Confirm the reference doc is complete.
  **Per-change checks:**
  - T-1: `grep -c '^## ' plugins/spec-flow/reference/flywheel.md` — Expected: ≥ 9 section headings.
  - T-1: LLM-agent-step: read `plugins/spec-flow/reference/flywheel.md` and confirm sections 1–10 from the outline
    are all present and the worked example shows concrete piece names (not placeholders).
  **Phase-level check:**
  - Run: `grep -nE 'schema_version|occurrences|rejections|source_type|rejected_at_count|FLYWHEEL-DEGRADED: repo registry unavailable' plugins/spec-flow/reference/flywheel.md`
  - Expected: at least one hit per token (6 distinct tokens matched).
  - Failure: any token returns 0 hits → a required rule/section is missing.

- [x] **[QA]** Phase review
  - Review against: AC-1, AC-2, AC-7, AC-8
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 2: Add `flywheel_threshold` config key
**Exit Gate:** `flywheel_threshold` (default 2) documented in `templates/pipeline-config.yaml` (the
committed SSOT); `.spec-flow.yaml` is gitignored per-developer runtime config (edited in the working
tree, not committed); absent key ⇒ default 2 (backward-compatible). [amended — see `.discovery-log.md`]
**ACs Covered:** AC-10
**In scope:** MODIFY `plugins/spec-flow/templates/pipeline-config.yaml` (committed). Also edit the live
`.spec-flow.yaml` in the working tree (gitignored per-developer runtime config — NOT part of the commit).
**NOT in scope:** reading the key (execute Phase 4); the `qa_max_iterations` live-vs-template drift (pre-existing,
out of scope).
Why serial: Phase 1 (reference) and Phase 2 (config) are disjoint and parallel-eligible, but kept serial — this is
a doc-as-code piece with no test runs, so parallel fan-out saves no wall-clock; serial keeps the SSOT reviewable
before the config whose comment points at it.
**Charter constraints honored in this phase:**
- NN-C-003 (additive/backward-compat): absent `flywheel_threshold` reproduces current behavior (default 2); plain YAML scalar + comment, no parser added.

- [x] **[Implement]** Add the key to both files in the house comment style.
  - Order: template first (canonical doc), then live config. Checkpoint after each file.
  - Architecture constraints: follow the `qa_max_iterations` comment-block idiom (a behavioral key with an inline
    comment naming the value + default). NN-C-003: the key is optional.

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`**
  - Anchor: between `reflection: auto` (line 80 block) and `charter:` (line 89).
  - Current:
    ```
    80  reflection: auto
    ...
    89  charter:
    ```
  - Target: insert before line 89 (after the `reflection` block ends):
    ```yaml
    # flywheel_threshold: repo-level self-hardening flywheel — occurrence count at which a pattern's
    #   batched hardening proposal is surfaced at end-of-piece reflection (new in v5.8.0; FR-006).
    #   <int> — distinct-piece occurrence count threshold (default 2). Absent ⇒ 2 (non-blocking; NN-C-003).
    #   See plugins/spec-flow/reference/flywheel.md `## Threshold + batched proposal`.
    flywheel_threshold: 2
    ```
  - Pattern (from `pipeline-config.yaml:70` qa_max_iterations style):
    ```yaml
    # qa_max_iterations: configurable QA fix-loop circuit-breaker limit (new in v5.6.0)
    #   auto  — resolve per piece track ...
    qa_max_iterations: auto
    ```
  - Done: the template carries `flywheel_threshold: 2` with the comment block, between `reflection` and `charter`.
  - Verify: `grep -n 'flywheel_threshold' plugins/spec-flow/templates/pipeline-config.yaml` returns the key + default.

  **T-2: MODIFY `.spec-flow.yaml`** (gitignored per-developer runtime config — working-tree edit only, NOT committed)
  - Anchor: after the `reflection:` block (lines 54-57), before the integrations comment (line 69).
  - Current:
    ```
    54  # reflection: controls Step 4.5 end-of-piece reflection (new in v1.5.0)
    55  #   auto    — dispatch reflection agents ...
    56  #   off     — skip Step 4.5 ...
    57  reflection: auto
    ```
  - Target: insert after line 57:
    ```yaml
    # flywheel_threshold: repo self-hardening flywheel occurrence threshold (new in v5.8.0; FR-006)
    #   <int> — distinct-piece occurrence count at which a batched hardening proposal surfaces (default 2).
    #   Absent ⇒ 2. Non-blocking. See plugins/spec-flow/reference/flywheel.md.
    flywheel_threshold: 2
    ```
  - Done: the live config carries `flywheel_threshold: 2` with its comment.
  - Verify: `grep -n 'flywheel_threshold' .spec-flow.yaml` returns the key + default.

- [x] **[Write-Tests]** Author the AC-10 assertions.
  **Test Data:**
  - AC-10: input = committed template (`pipeline-config.yaml`) → expect `flywheel_threshold` documented with
    stated default 2; the live `.spec-flow.yaml` (gitignored runtime config) carries the same in the working tree;
    manual smoke — remove the key ⇒ a count-2 pattern trips (default 2); set `flywheel_threshold: 3` ⇒ count-2
    does not trip.

- [x] **[Verify]** Confirm the key is present (committed: template; working-tree: live config).
  **Per-change checks:**
  - T-1 (committed): `grep -n 'flywheel_threshold: 2' plugins/spec-flow/templates/pipeline-config.yaml` — Expected: 1 match.
  - T-2 (working tree, gitignored): `grep -n 'flywheel_threshold: 2' .spec-flow.yaml` — Expected: 1 match (runtime override; not in the commit).
  **Phase-level check (committed artifact):**
  - Run: `grep -c 'flywheel_threshold' plugins/spec-flow/templates/pipeline-config.yaml`
  - Expected: ≥ 1 (key + comment references) in the committed template.
  - Failure: template reports 0 → committed key missing.

- [x] **[QA]** Phase review
  - Review against: AC-10
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 3: execute Step 6c record + match-propose hook + degraded path
**Exit Gate:** execute/SKILL.md Step 6c carries a flywheel record/match-propose hook covering both wired sources
(`reflection-finding`, `execute-discovery`) with the no-write-before-confirm gate; the `[FLYWHEEL-DEGRADED]`
degraded path is wired non-blocking; no path emits `source_type: metric`.
**ACs Covered:** AC-3, AC-4, AC-8 (non-blocking wiring)
<!-- Branch-enumeration ACs: match-vs-new (AC-3), reflection-finding-vs-execute-discovery source (AC-4),
writable-vs-unwritable/unparseable registry (AC-8) — each covered by the listed ACs. -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — add the flywheel record/match hook at Step 6c
(per-phase triage + the Step 4.5 reflection→Step 6c routing point) and the degraded-path branch.
**NOT in scope:** the batched threshold proposal + hardening dispatch (Phase 4); the reference schema (Phase 1).
**Steps traversed (P2):** Step 6c Discovery Triage — `#### Aggregation` (981), `#### Triage prompt` (1026); and
the end-of-piece `### Step 4.5: Reflection` → `#### Routing reflection findings through Step 6c` (1818). The new
flywheel record/match path runs at each of these triage points (additive to the existing aggregated prompt).
**Dispatch sites (P3):** none — recording + match-propose is orchestrator-side; no agent is dispatched or
re-contracted in this phase (the reflection agents are read at their existing routing point, unchanged).
**Charter constraints honored in this phase:**
- NN-C-006 (operator-gated state change): the recording hook writes nothing to `docs/patterns.yaml` until the operator confirms classification + scope (the recording write gate).
- NN-C-005 (refuse, don't guess): unwritable/unparseable registry ⇒ `[FLYWHEEL-DEGRADED]`, no write, no guess.

- [x] **[Implement]** Wire the record/match hook + degraded path into Step 6c.
  - Order: (1) add the hook prose under `#### Triage prompt` covering per-phase discoveries; (2) add the same hook
    at the Step 4.5 reflection routing point; (3) add the degraded-path branch; (4) add the `reference/flywheel.md`
    citation. Checkpoint after each.
  - Architecture constraints: additive to the existing single-aggregated-prompt-per-phase (NFR-6); cite
    `reference/flywheel.md` by `## ` anchor; do NOT restate the schema/rules (CR-008, NN-C-008).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: end of `#### Triage prompt` (after line 1046, before `#### Auto-mode threshold` at 1048).
  - Current:
    ```
    1046  **Aggregate shortcuts decompose into per-discovery dispatches.** ...
    1048  #### Auto-mode threshold (FR-17)
    ```
  - Target: insert a new `#### Flywheel pattern recording (FR-006)` subsection stating: for each discovery being
    triaged, the flywheel proposes a match against `docs/patterns.yaml` (existing `id` or "new <kebab-slug>") and,
    on operator confirmation of classification + scope, appends a per-(pattern, piece) occurrence with
    `source_type: execute-discovery`; nothing is written before confirmation (NN-P-004); recurrence within the same
    piece is deduped (no count change). Cite `plugins/spec-flow/reference/flywheel.md` `## Match + confirm flow
    (no silent write)` and `## Count rule` for all mechanics. State that an unwritable/unparseable
    `docs/patterns.yaml` triggers the degraded path (T-3) and the discovery's normal triage still proceeds.
  - Done: a `#### Flywheel pattern recording (FR-006)` subsection exists at Step 6c with the no-write-before-confirm
    gate and an anchor citation to `reference/flywheel.md`.
  - Verify: `grep -n 'Flywheel pattern recording' plugins/spec-flow/skills/execute/SKILL.md` returns a match.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: `#### Routing reflection findings through Step 6c` (line 1818), within Step 4.5 Reflection.
  - Current:
    ```
    1818  #### Routing reflection findings through Step 6c
    1819
    1820  For each agent's findings, dispatch the Step 6c triage flow ...
    ```
  - Target: add a sentence/paragraph noting that when reflection findings route through Step 6c here, the same
    flywheel record/match hook (T-1) fires with `source_type: reflection-finding` — so reflection findings are
    recorded as occurrences identically to native discoveries. Cite `reference/flywheel.md` `## Source taxonomy`.
  - Done: the reflection-routing subsection references the flywheel hook with `source_type: reflection-finding`.
  - Verify: `grep -n 'reflection-finding' plugins/spec-flow/skills/execute/SKILL.md` returns a match.

  **T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: same `#### Flywheel pattern recording (FR-006)` subsection from T-1.
  - Target: add the degraded-path rule: if `docs/patterns.yaml` is unwritable or unparseable, the flywheel emits
    the single line `[FLYWHEEL-DEGRADED: repo registry unavailable]`, performs no registry write, does NOT block or
    fail execute, and the triggering finding still flows to its normal Step 6c triage / reflection resolution. Cite
    `reference/flywheel.md` `## Degraded path`.
  - Done: the verbatim marker string and the non-blocking + finding-still-routes guarantees appear in the SKILL.
  - Verify: `grep -n 'FLYWHEEL-DEGRADED: repo registry unavailable' plugins/spec-flow/skills/execute/SKILL.md` returns a match.

- [x] **[Write-Tests]** Author the AC-3 / AC-4 / AC-8 assertions.
  **Test Data:**
  - AC-3: input = the Step 6c flywheel subsection → expect "no … write … until … confirm" + rename-on-new.
  - AC-4: input = SKILL + reference → expect both wired source_types present; `grep -rn 'source_type: *metric'
    plugins/spec-flow/` returns ONLY the schema enum in `reference/flywheel.md`, no execute emission site.
  - AC-8: input = the degraded subsection → expect the verbatim marker + non-blocking + finding-still-routes.

- [x] **[Verify]** Confirm the Step 6c wiring.
  **Per-change checks:**
  - T-1: `grep -n 'Flywheel pattern recording' plugins/spec-flow/skills/execute/SKILL.md` — Expected: 1 match.
  - T-2: `grep -n 'reflection-finding' plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1 match.
  - T-3: `grep -n 'FLYWHEEL-DEGRADED: repo registry unavailable' plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1.
  **Phase-level check:**
  - Run: `grep -rn 'source_type: *metric' plugins/spec-flow/ | grep -v 'reference/flywheel.md'`
  - Expected: 0 matches (no `metric` emission anywhere outside the reference schema enum).
  - Failure: any match outside `reference/flywheel.md` → a `metric` emitter was wired (scope violation).
  - LLM-agent-step: read the new Step 6c flywheel subsection and confirm it CITES `reference/flywheel.md` by `## `
    anchor and does NOT restate the schema (CR-008 / NN-C-008).

- [x] **[QA]** Phase review
  - Review against: AC-3, AC-4, AC-8
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 4: execute Step 4.5 batched proposal + hardening dispatch + citation
**Exit Gate:** execute/SKILL.md Step 4.5 surfaces the batched hardening proposal at threshold and routes an
approved proposal through the spike `scope` mode → existing reflection-amend path; spike-`BLOCKED` escalates with
no amendment; execute cites `reference/flywheel.md`; the cross-phase schema-consistency check passes.
**ACs Covered:** AC-5, AC-6, AC-9, AC-11 (citation portion)
<!-- Branch-enumeration ACs: count≥threshold-vs-below (AC-5), spike OK-vs-BLOCKED (AC-6 / AC-9),
accept-vs-reject outcome recording — each covered. -->
**In scope:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md` — add the Step 4.5 batched proposal + hardening
dispatch (reusing the Step 6c spike-scope→plan-amend path) + spike-BLOCKED branch + the reference citation.
**NOT in scope:** the recording hook (Phase 3); version bump (Phase 5).
**Steps traversed (P2):** `### Step 4.5: Reflection` (1785) and its `#### Routing reflection findings through Step
6c` (1818) — the batched proposal fires after this piece's reflection findings are recorded; on approval it reuses
`#### Amend dispatch` → Scope-spike pre-step (1089–1104) and the reflection-finding amend behavior at 1844.
**Dispatch sites (P3):** `agents/spike.md` (`scope` mode) — existing dispatch sites: `### Step 1c` `[SPIKE]`
resolve (~393) and `#### Amend dispatch` scope pre-step (1093–1100). This phase ADDS a third dispatch site: the
Step 4.5 flywheel-hardening scope dispatch (reusing the exact `Agent({... model:"opus"})` scope contract).
`agents/plan-amend.md` is reused at its existing amend site (no new dispatch). The spike scope-mode contract
(`reference/spike-agent.md` `## Agent modes`) is unchanged — this is a new call site of an existing contract.
**Charter constraints honored in this phase:**
- NN-P-004 (operator-gated promotions): the batched proposal requires operator approval before any spike/amend; rejections recorded, not re-proposed.
- NN-P-002 (no mid-stream change): hardening routes through spike→plan-amend→Per-Phase-Loop→Final Review.
- NN-P-005 (Opus thinking, Sonnet mechanics): the hardening fix is scoped by the Opus spike, not a Sonnet upgrade.
- NN-P-001 (human approval gate never removed): the Step 4 sign-off still fires; the hardening approval is a second, distinct operator gate whose amendment re-enters review before merge.
- CR-008 (thin orchestrator / cite, don't restate): cite `reference/flywheel.md` + `reference/spike-agent.md`; reuse the existing amend path; no heavyweight new logic in the SKILL.

- [x] **[Implement]** Wire the batched proposal + hardening dispatch into Step 4.5.
  - Order: (1) batched-proposal prose (read threshold, list at/over-threshold patterns + routing home); (2) the
    approval → spike `scope` dispatch reusing the Step 6c scope contract; (3) the OK path → existing reflection
    amend dispatch + outcome recording + `.discovery-log.md` row; (4) the BLOCKED path → escalate, no amend, record
    proposed-but-unresolved; (5) the `reference/flywheel.md` citation. Checkpoint after each.
  - Architecture constraints: REUSE the Step 6c Scope-spike pre-step (1093–1104) and the reflection amend behavior
    (1844) — do NOT author a new amend mechanism (ADR-1). The spike is dispatched regardless of diff-ratio (the
    hardening fix is unknown by nature — treat as always-spike, analogous to the undefined-ratio→spike case).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: end of `### Step 4.5: Reflection` (after `#### What gets committed (and what does not)` ~1848, before
    `### Step 5: Capture Learnings` at 1850).
  - Current:
    ```
    1848  **Explicit removal note (v3.2.0+).** ...
    1850  ### Step 5: Capture Learnings
    ```
  - Target: insert a new `#### Flywheel batched hardening proposal (FR-006)` subsection stating: after this piece's
    reflection findings have been recorded through the Step 6c flywheel hook, read `flywheel_threshold` (default 2)
    and surface ONE batched proposal listing every pattern whose distinct-piece count ≥ threshold with its recorded
    `scope` as the routing home (charter/qa/prd). For each proposal the operator may approve or reject. On reject:
    append a `rejections` entry per `reference/flywheel.md` `## Rejection rule`. On approve: dispatch `agents/spike.md`
    in `scope` mode (reuse the `#### Amend dispatch` Scope-spike block, lines 1093–1104 — same `Agent({... mode:scope
    ... model:"opus"})` shape), the spike always runs (the hardening fix is unknown by nature). Cite
    `reference/flywheel.md` `## Threshold + batched proposal` and `## Hardening dispatch (reuse)`.
  - Done: a `#### Flywheel batched hardening proposal (FR-006)` subsection exists with the threshold read + single
    batched proposal + operator approve/reject.
  - Verify: `grep -n 'Flywheel batched hardening proposal' plugins/spec-flow/skills/execute/SKILL.md` returns a match.

  **T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: within the new subsection from T-1.
  - Target: specify the OK and BLOCKED branches. On `STATUS: OK`: read the spike artifact, route the scoped fix
    through the EXISTING reflection-finding `amend` dispatch (line 1844 behavior — plan-amend appends phases, they
    run the full Per-Phase Loop + re-enter Final Review before merge; amendment budget 5/1 applies); record the
    accepted outcome + spike-artifact reference against the pattern in `docs/patterns.yaml`; append the standard
    `.discovery-log.md` row (source-phase token `step-4.5-reflection`). On `STATUS: BLOCKED`: escalate with the
    spike's findings, produce NO plan amendment, apply NO mid-stream patch, and record the pattern as
    proposed-but-unresolved (NOT a rejection). Cite `reference/flywheel.md` `## Hardening dispatch (reuse)`.
  - Pattern (the reused scope-spike OK/BLOCKED shape, from execute/SKILL.md:1103-1104):
    ```
    - On STATUS: OK: read the scoping artifact ... extract Classification: and Scope / Task list: ... pass to plan-amend.
    - On STATUS: BLOCKED: append a .discovery-log.md row ... then escalate ... do NOT dispatch plan-amend.
    ```
  - Done: OK routes via the existing amend path + records the outcome; BLOCKED escalates, no amend, not a rejection.
  - Verify: LLM-agent-step: read the subsection and confirm BOTH the OK (reuse existing amend) and BLOCKED
    (escalate, no amend, not-a-rejection) branches are present.

  **T-3: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`**
  - Anchor: within the new subsection (a "See" line) AND confirm the Step 6c hook (Phase 3 T-1) carries the same
    citation form.
  - Target: ensure execute cites `plugins/spec-flow/reference/flywheel.md` by `## ` anchor (the SSOT for all
    schema/match/count/threshold/marker/hardening mechanics), satisfying AC-11's citation requirement.
  - Done: `grep` finds a `reference/flywheel.md` citation in execute/SKILL.md.
  - Verify: `grep -n 'reference/flywheel.md' plugins/spec-flow/skills/execute/SKILL.md` returns ≥ 1 match.

- [x] **[Write-Tests]** Author the AC-5 / AC-6 / AC-9 / AC-11(citation) assertions.
  **Test Data:**
  - AC-5: input = the batched-proposal subsection → expect threshold read + single batched proposal + routing home;
    manual smoke — threshold 2 with a count-2 pattern surfaces one proposal; threshold 3 surfaces none at count 2.
  - AC-6: input = the subsection → expect `scope`-mode spike dispatch + reuse of the existing reflection amend path
    + outcome/spike-artifact recording + `.discovery-log.md` row; manual smoke — approve → plan.md gains
    flywheel-origin amendment phases.
  - AC-9: input = the subsection → expect spike-BLOCKED escalation, no amendment, recorded NOT as a rejection.
  - AC-11 (citation): input = execute/SKILL.md → expect a `reference/flywheel.md` anchor citation.

- [x] **[Verify]** Confirm the Step 4.5 wiring + cross-phase schema consistency.
  **Per-change checks:**
  - T-1: `grep -n 'Flywheel batched hardening proposal' plugins/spec-flow/skills/execute/SKILL.md` — Expected: 1.
  - T-2: LLM-agent-step: read the subsection; confirm OK→existing-amend-path and BLOCKED→escalate/no-amend/not-a-rejection.
  - T-3: `grep -n 'reference/flywheel.md' plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥ 1.
  **Cross-phase schema-consistency check (plan §2d — patterns.yaml schema established in Phase 1, consumed here):**
  - Schema-bearing file: `plugins/spec-flow/reference/flywheel.md` (defines the registry shape); consumers:
    execute/SKILL.md Step 6c hook (Phase 3) + Step 4.5 proposal (Phase 4).
  - Invariant: every `docs/patterns.yaml` field the execute prose names (`id`, `scope`, `occurrences`,
    `source_type`, `rejections`, `rejected_at_count`) must be defined in `reference/flywheel.md`.
  - Run (LLM-agent-step): for each field token execute/SKILL.md references in the flywheel subsections, confirm the
    same token is defined in `reference/flywheel.md`'s `## Registry schema` / `## Rejection rule`. Report any
    execute-named field absent from the reference as a schema-drift must-fix.
  - Expected: zero execute-named fields missing from the reference.
  **Phase-level check:**
  - Run: `grep -cn 'Flywheel' plugins/spec-flow/skills/execute/SKILL.md`
  - Expected: ≥ 3 (recording subsection + reflection note + batched-proposal subsection).

- [x] **[QA]** Phase review
  - Review against: AC-5, AC-6, AC-9, AC-11
  - Diff baseline: git diff <phase_start_tag>..HEAD

### Phase 5: Version bump + CHANGELOG + version-sync sweep
**Exit Gate:** all four version-bearing files read 5.8.0; CHANGELOG has a `## [5.8.0]` `### Added` section; no
superseded `5.7.0` string remains in the spec-flow version slots.
**ACs Covered:** AC-11 (version-sync portion)
**In scope:** MODIFY `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json` (spec-flow entry), `plugins/spec-flow/CHANGELOG.md`.
**NOT in scope:** the marketplace.json line-24 entry (a different plugin @1.1.1 — must not change); `git push` /
release tag (human gate).
**Charter constraints honored in this phase:**
- NN-C-009 (always bump, per-semver scope): a new capability = minor bump 5.7.0 → 5.8.0.
- NN-C-001 (version ⇄ marketplace sync): all three JSON version fields move together.
- NN-C-007 (CHANGELOG Keep-a-Changelog): a dated `## [5.8.0]` `### Added` section is prepended.

- [x] **[Implement]** Bump all four files.
  - Order: the three JSON version fields, then the CHANGELOG section. Checkpoint after the JSONs, then the CHANGELOG.
  - Architecture constraints: change ONLY the spec-flow version slots (marketplace.json line 15, NOT line 24).

  **Change Specifications:**

  **T-1: MODIFY `plugins/spec-flow/plugin.json`** — Anchor: line 4 `"version": "5.7.0",` → `"version": "5.8.0",`.
  Done: line 4 reads 5.8.0. Verify: `grep '"version": "5.8.0"' plugins/spec-flow/plugin.json` returns a match.

  **T-2: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`** — Anchor: line 4 `"version": "5.7.0",` →
  `"version": "5.8.0",`. Done: line 4 reads 5.8.0. Verify: `grep '"version": "5.8.0"' plugins/spec-flow/.claude-plugin/plugin.json`.

  **T-3: MODIFY `.claude-plugin/marketplace.json`** — Anchor: line 15 (spec-flow entry) `"version": "5.7.0",` →
  `"version": "5.8.0",`. Do NOT touch line 24 (`1.1.1`, different plugin). Done: the spec-flow entry reads 5.8.0.
  Verify: LLM-agent-step: read `.claude-plugin/marketplace.json`, confirm the `spec-flow` entry version is 5.8.0 and
  the other entry is unchanged at 1.1.1.

  **T-4: MODIFY `plugins/spec-flow/CHANGELOG.md`** — Anchor: after `## [Unreleased]` (line 5), before `## [5.7.0]`
  (line 7).
  - Target: insert:
    ```markdown
    ## [5.8.0] — 2026-06-08

    ### Added
    - **`reference/flywheel.md` (repo self-hardening flywheel SSOT, FR-006):** the `docs/patterns.yaml` registry
      schema, stable kebab-slug IDs, per-(pattern,piece) count rule, match/confirm flow (no silent write), source
      taxonomy (`reflection-finding`/`execute-discovery` wired; `metric` reserved), `flywheel_threshold` semantics,
      the hardening dispatch (reuses `spike` scope mode → existing Step 6c `plan-amend` path), and the
      `[FLYWHEEL-DEGRADED: repo registry unavailable]` marker.
    - **execute Step 6c flywheel recording hook + Step 4.5 batched hardening proposal:** recurring findings are
      recorded against `docs/patterns.yaml` (operator-confirmed, no silent write); at `flywheel_threshold` a single
      batched proposal at end-of-piece reflection routes an approved pattern through a `scope` spike + the existing
      reflection-amend path; rejections are recorded and not re-proposed; non-blocking degraded path.
    - **`flywheel_threshold` `.spec-flow.yaml` key (default 2):** added to the live config + `pipeline-config.yaml`.
    ```
  - Done: a `## [5.8.0] — 2026-06-08` `### Added` section sits between Unreleased and 5.7.0.
  - Verify: `grep -n '## \[5.8.0\]' plugins/spec-flow/CHANGELOG.md` returns a match above the 5.7.0 line.

- [x] **[Write-Tests]** Author the version-sync assertions (AC-11) including the superseded-ordinal sweep.
  **Test Data:**
  - AC-11: input = the four files → expect all spec-flow version slots = 5.8.0, CHANGELOG top = `## [5.8.0]`, and
    NO superseded `5.7.0` in the spec-flow version slots.

- [x] **[Verify]** Version sync + superseded-ordinal anti-drift sweep (plan §2e).
  **Per-change checks:**
  - T-1/T-2/T-3: `grep -h '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` and
    line 15 of `.claude-plugin/marketplace.json` — Expected: each prints `"version": "5.8.0",`.
  - T-4: `grep -n '## \[5.8.0\]' plugins/spec-flow/CHANGELOG.md` — Expected: 1 match, above `## [5.7.0]`.
  **Superseded-ordinal sweep (5.7.0 → 5.8.0):**
  - Sweep superseded: `grep -n '5\.7\.0' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json` and
    marketplace.json line 15 — Expected: 0 hits in the spec-flow version slots (the CHANGELOG `## [5.7.0]` history
    entry legitimately remains and is NOT a version slot).
  - Sweep new target: `grep -rl '"version": "5.8.0"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` — Expected: 3 files.
  **Phase-level check (the AC-9-style version-sync grep recipe):**
  - Run: `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json; sed -n '15p' .claude-plugin/marketplace.json`
  - Expected: every spec-flow version field prints 5.8.0.
  - Failure: any spec-flow version field ≠ 5.8.0 → NN-C-001/009 sync violation.

- [x] **[QA]** Phase review
  - Review against: AC-11
  - Diff baseline: git diff <phase_start_tag>..HEAD

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | reference defines patterns.yaml schema (envelope + record fields + worked example) | COVERED | Phase 1 |
| AC-2  | count = distinct pieces; dedup-per-piece rule | COVERED | Phase 1 |
| AC-3  | execute hook: match-propose, no-write-before-confirm, rename-on-new | COVERED | Phase 3 (Phase 1 rule def) |
| AC-4  | source_type enum; reflection-finding + execute-discovery wired; no metric emission | COVERED | Phase 1 (enum), Phase 3 (wiring) |
| AC-5  | threshold N + single batched end-of-piece proposal with routing home | COVERED | Phase 2 (key), Phase 4 (proposal) |
| AC-6  | approved hardening → spike scope mode → existing amend path → record + discovery-log row | COVERED | Phase 4 |
| AC-7  | rejection {date, rationale, rejected_at_count}; not re-proposed until count > rejected_at_count | COVERED | Phase 1 |
| AC-8  | degraded marker, no write, non-blocking, finding still routes | COVERED | Phase 1 (marker), Phase 3 (non-blocking wiring) |
| AC-9  | spike BLOCKED → escalate, no amendment, not a rejection | COVERED | Phase 4 |
| AC-10 | flywheel_threshold default 2 in both config files; absent = default | COVERED | Phase 2 |
| AC-11 | reference SSOT (execute cites by anchor) + version 5.8.0 across 4 files + CHANGELOG | COVERED | Phase 1 (SSOT), Phase 4 (citation), Phase 5 (version) |

All 11 ACs COVERED — no NOT COVERED rows, no forward pointers required.

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | agent-step | Read `plugins/spec-flow/reference/flywheel.md`; confirm schema block (schema_version, occurrences with 4 fields, rejections) + worked example present | Schema + example present |
| AC-2  | shell | `grep -nE 'distinct .?piece.?|deduped per piece' plugins/spec-flow/reference/flywheel.md` | ≥1 match (count/dedup rule) |
| AC-3  | shell | `grep -n 'Flywheel pattern recording' plugins/spec-flow/skills/execute/SKILL.md` + agent-step confirm no-write-before-confirm | subsection present; gate stated |
| AC-4  | shell | `grep -n 'reflection-finding\|execute-discovery\|metric' plugins/spec-flow/reference/flywheel.md`; `grep -rn 'source_type: *metric' plugins/spec-flow/ \| grep -v reference/flywheel.md` | enum present; 0 metric emissions |
| AC-5  | shell | `grep -n 'flywheel_threshold' plugins/spec-flow/skills/execute/SKILL.md` + `grep -n 'Flywheel batched hardening proposal' …execute/SKILL.md` | threshold read + batched proposal present |
| AC-6  | agent-step | Read execute Step 4.5 flywheel subsection; confirm `scope`-mode spike dispatch + reuse of existing reflection-amend path + outcome/discovery-log recording | all present |
| AC-7  | shell | `grep -n 'rejected_at_count' plugins/spec-flow/reference/flywheel.md` | re-propose rule present |
| AC-8  | shell | `grep -n 'FLYWHEEL-DEGRADED: repo registry unavailable' plugins/spec-flow/reference/flywheel.md plugins/spec-flow/skills/execute/SKILL.md` | marker in both; non-blocking stated |
| AC-9  | agent-step | Read execute Step 4.5 flywheel subsection; confirm spike-BLOCKED → escalate, no amendment, not a rejection | branch present |
| AC-10 | shell | committed: `grep -n 'flywheel_threshold: 2' plugins/spec-flow/templates/pipeline-config.yaml`; runtime (gitignored, working tree): `grep -n 'flywheel_threshold: 2' .spec-flow.yaml` | key + default 2 in committed template; live override in working-tree `.spec-flow.yaml` |
| AC-11 | shell | `grep '"version"' plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json; sed -n '15p' .claude-plugin/marketplace.json; grep -n 'reference/flywheel.md' plugins/spec-flow/skills/execute/SKILL.md` | all 5.8.0 + citation present |

## Contracts

No TDD-track phases in this plan — contracts section present for forward compatibility. `tdd-red` agents will not
be dispatched; no contract injection occurs. The one durable boundary-crossing interface this piece defines is a
data schema (the `flywheel-global` piece, FR-007, consumes it verbatim):

### C-1: `docs/patterns.yaml` registry schema
- **ID:** C-1
- **Type:** Data Schema
- **Phase:** Phase 1 (defined in `reference/flywheel.md`); consumed by execute Phases 3–4; reused by `flywheel-global`
- **Signature:** `{ schema_version: int, generated: date, last_updated: date, patterns: [ { id: kebab-slug, description: str, scope: charter|qa|prd, occurrences: [ {piece, date, source, source_type} ], rejections: [ {date, rationale, rejected_at_count} ] } ] }`
- **Inputs:** an operator-confirmed finding occurrence (piece, date, source, source_type)
- **Outputs:** the persisted registry; `count = len(distinct occurrence.piece)`
- **Error cases:** unwritable/unparseable file → `[FLYWHEEL-DEGRADED: repo registry unavailable]`, no write, non-blocking
- **Constraints:** dedup-on-piece (one occurrence per pattern per piece); `source_type: metric` and `originating_repo` are RESERVED, unwritten by this piece; `flywheel-global` adds `originating_repo` per occurrence + `plugin` scope without restructure (SF-N4)

## Parallel Execution Notes

All five phases run **serial**. Phases 1 and 2 are disjoint and parallel-eligible but kept serial (see Phase 2
`Why serial:` — doc-as-code, no test-run wall-clock to save; SSOT-before-config readability). Phases 3 and 4 both
edit `execute/SKILL.md` with an ordering dependency (recording must exist before the proposal counts), so they are
inherently coupled, not a parallelization candidate. Phase 5 depends on all prior phases. No Phase 0 Scaffold —
the only multi-touch file (`execute/SKILL.md`, Phases 3+4) is edited serially, so there is no shared-file race.

## Agent Context Summary

| Task Type | Receives | Does NOT receive |
|-----------|----------|-----------------|
| Implementer (Mode: Implement) | `Mode: Implement` flag, the phase's `[Implement]` Change Specification Blocks, spec ACs, the `[Verify]` commands, arch constraints, anchors + verbatim current snippets, codebase context from `introspection.md` | Spec rationale, brainstorming history |
| Verify | The phase's `[Verify]` grep/inspection commands + expected outputs, spec ACs | Implementation reasoning |
| QA (qa-phase-lite, standard mode) | Phase diff, spec, plan, the phase's ACs | Other phases' diffs, brainstorming history |
