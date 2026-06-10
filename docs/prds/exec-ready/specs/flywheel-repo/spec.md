---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: flywheel-repo

**PRD Sections:** FR-006, G-5
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** sonnet-coord, spike-agent

> **Dependency note (manifest amendment required at finalize):** the manifest currently records
> `dependencies: [sonnet-coord]`. This spec wires the flywheel's hardening path through the **spike
> agent** (`agents/spike.md`, FR-005/FR-008, merged in 5.7.0), so the true dependency set is
> `[sonnet-coord, spike-agent]`. Both are `merged`, so the precondition is satisfied; the manifest
> entry is updated to add `spike-agent` as part of Phase 5 finalize.

## Goal

Establish a repo-level **self-hardening flywheel**: a durable, stable-ID registry at
`docs/patterns.yaml` that makes recurring avoidable-discovery patterns countable across pieces and
PRDs within the repo. When a finding reaches the execute Step 6c discovery-triage juncture, the
flywheel LLM-proposes a pattern match (or "new"); the operator confirms classification and scope
before any write (no silent write, NN-P-004). At a configurable threshold, a single batched hardening
proposal is surfaced at end-of-piece reflection; on approval the existing **spike agent** scopes the
concrete fix and the existing **reflection→Step 6c→`plan-amend`** path applies it. The registry's
schema, match, and count mechanics are factored so the later `flywheel-global` piece (FR-007) reuses
them by changing only the registry location and the routing target.

This is the registry + match + count foundation. The plugin-global cross-install registry is a
separate piece (`flywheel-global`, FR-007).

## In Scope

- A new durable registry file `docs/patterns.yaml` (does not exist today) with a defined schema:
  envelope (`schema_version`, dates), a `patterns:` list of stable-ID records, per-occurrence
  provenance, and a `rejections:` list.
- A flywheel **record + match-propose + operator-confirm** hook at the execute **Step 6c** discovery-
  triage juncture (alongside the existing Step 6c spike/amend gate). Step 6c runs in two places that
  the flywheel hooks identically: per-phase (native discoveries) and at end-of-piece Step 4.5
  Reflection (reflection-agent findings, which already route through Step 6c). On a triaged finding,
  propose a match to an existing pattern ID or "new", and append a dated occurrence only after operator
  confirmation.
- **Per-(pattern, piece)** occurrence granularity: count = number of distinct pieces in which the
  pattern occurred (a pattern recurring multiple times within one piece counts once). See
  `## Technical Approach` for the reconciliation with FR-006 AC1's "count = occurrences length".
- A `flywheel_threshold` key (plain integer, default 2, global) documented in
  `templates/pipeline-config.yaml` (the authoritative *committed* config source). `.spec-flow.yaml`
  is gitignored per-developer runtime config (read at runtime, default 2 if the key is absent) and is
  not part of the committed deliverable.
- A **batched hardening proposal** surfaced once per piece at the **end-of-piece Step 4.5 Reflection
  juncture** (after the Final Review board and Human Sign-Off, before merge — the point at which
  reflection findings already route through Step 6c), listing every pattern at/over threshold with its
  proposed routing home (charter / QA / PRD).
- **Spike-routed hardening via the existing reflection-amend path:** an approved proposal dispatches
  the spike agent (`scope` mode, Opus, isolated); the scoped fix is applied through the **existing**
  Step 4.5 reflection-finding `amend` dispatch (`plan-amend` appends the scoped phases, which run
  through the full Per-Phase Loop and re-enter the Final Review board before merge — identical to any
  reflection-finding amend today, and consuming the same amendment budget). The outcome (accept +
  spike-artifact reference, or reject + rationale) is recorded in `docs/patterns.yaml`.
- **Rejection recording**: rejected proposals append a rationale and are not re-proposed until the
  pattern's count grows beyond the count at which it was rejected.
- **Degraded path**: `[FLYWHEEL-DEGRADED: repo registry unavailable]` when `docs/patterns.yaml` is
  unwritable or unparseable — non-blocking; the triggering finding still flows to its normal Step 6c
  triage / reflection resolution.
- A single canonical `reference/flywheel.md` holding the schema, stable-ID scheme, match/confirm
  flow, count/threshold/batched-routing mechanics, and the `[FLYWHEEL-DEGRADED]` marker contract.
- Plugin version bump 5.7.0 → 5.8.0 across the four version-bearing files + a CHANGELOG section.

## Out of Scope / Non-Goals

- **The machine-global plugin registry** — that is `flywheel-global` (FR-007). This piece only
  designs `docs/patterns.yaml` (repo scope) and reserves schema room for the global reuse.
- **`metric`-source occurrence emitters** — the schema admits a `metric` occurrence `source_type`
  (so it is representable for later work), but **no code path in this piece emits one**. The two
  deferred emitters are spike-agent FO-2 (admission-`n` event recording) and FO-3 (cross-piece
  resolved-spike index). See `## Explicitly Out of Scope / Deferred`.
- **Configurable `spike_threshold`** (spike-agent FO-1) — deferred; this piece adds only
  `flywheel_threshold`.
- **Per-scope thresholds** — a single global integer threshold; per-home thresholds (charter vs QA
  vs PRD) are a possible later extension, not built here.
- **Auto-authoring the hardening fix in-loop** — the flywheel never authors a charter/QA/PRD change
  itself; it dispatches the spike (Opus thinking) and lets the existing `plan-amend` path apply the
  result. No new auto-scaffold mechanism is introduced.
- **A new end-of-piece step or a new amend mechanism** — the flywheel reuses the existing Step 4.5
  reflection→Step 6c→amend dispatch verbatim; it does not add a parallel amend path or a new pipeline
  step.
- **Removing any human gate** — every registry write and every promotion is operator-confirmed
  (NN-P-004); the spec/plan sign-off gates are untouched (NN-P-001).

## Requirements

### Functional Requirements

- **SF-1 (Registry + schema):** Create `docs/patterns.yaml` with a defined schema — envelope
  (`schema_version`, `generated`, `last_updated`), and a `patterns:` list where each pattern carries
  a stable kebab-slug `id`, a one-line `description`, a `scope` (`charter | qa | prd`), an
  `occurrences:` list (each `{piece, date, source, source_type}`), and a `rejections:` list. Count is
  the number of distinct pieces represented in `occurrences`; because recording is deduped per piece
  (SF-2), the `occurrences` list holds at most one entry per piece, so count also equals
  `len(occurrences)`. The file is created lazily on the first confirmed occurrence. The occurrence
  record reserves clean room for `flywheel-global` to add a single `originating_repo` field and a
  `plugin` scope value without restructuring.
- **SF-2 (Per-(pattern, piece) count):** On recording, if the matched pattern already has an
  occurrence for the current piece, no new occurrence is added (count unchanged); a finding in a
  not-yet-recorded piece adds one occurrence (count increments). Recurrence within a single piece
  never advances the count.
- **SF-3 (Match-propose + operator-confirm, no silent write):** At the flywheel hook, the flywheel
  emits a match proposal — an existing pattern `id` **or** "new" with an LLM-proposed kebab slug —
  and writes nothing to `docs/patterns.yaml` until the operator confirms the classification (which
  pattern) and the scope (`charter | qa | prd`). On a "new" confirmation the operator may rename the
  proposed slug. Match proposals follow the existing single-aggregated-prompt-per-phase convention
  (NFR-6) used by the Step 6c triage.
- **SF-4 (Source taxonomy — schema-open, wire-narrow):** The occurrence `source_type` field admits
  `{reflection-finding, execute-discovery, metric}`. This piece **wires** the `reflection-finding`
  source (the two reflection agents' findings, which route through Step 6c at Step 4.5) and the
  `execute-discovery` source (native per-phase Step 6c discoveries: `qa-phase`/`qa-phase-lite`
  findings, AC-matrix NOT-COVERED rows, unmarked execute-time discoveries, Build missing-prerequisite
  escalations). No path in this piece emits a `metric` occurrence.
- **SF-5 (Threshold + batched end-of-piece proposal):** Read `flywheel_threshold` (plain integer,
  default 2) from `.spec-flow.yaml`. At the end-of-piece Step 4.5 Reflection juncture — after this
  piece's reflection findings have been recorded through the Step 6c hook — surface **one** batched
  proposal listing every pattern whose distinct-piece count ≥ threshold, each with its recorded `scope`
  as the proposed routing home.
- **SF-6 (Spike-routed hardening via the existing reflection-amend path):** When the operator approves
  a hardening proposal, the flywheel dispatches the spike agent in `scope` mode (Opus, isolated
  context, per NFR-001) with the pattern + its occurrences; the spike writes a scoping artifact; the
  scoped fix is then handed to the **existing** Step 4.5 reflection-finding `amend` dispatch
  (`execute/SKILL.md` line ~1844): `plan-amend` appends the scoped hardening phases to the current
  piece's plan at a dependency-correct position, those phases run through the full Per-Phase Loop and
  re-enter the Final Review board before merge, and the amendment consumes the standard per-piece
  amendment budget (5 total / 1 spec). The accepted outcome — including the spike-artifact reference
  and the routing home — is recorded against the pattern in `docs/patterns.yaml`, and the standard
  `.discovery-log.md` row is appended for the flywheel-origin amendment.
- **SF-7 (Rejection recorded, not re-proposed):** When the operator rejects a hardening proposal, a
  `rejections:` entry `{date, rationale, rejected_at_count}` is appended; the pattern is excluded from
  future proposals until its distinct-piece count exceeds `rejected_at_count`.
- **SF-8 (Reference SSOT + version sync):** A single `plugins/spec-flow/reference/flywheel.md` is the
  sole definition of the schema, stable-ID scheme, match/confirm flow, count/threshold/batched-routing
  mechanics, and the `[FLYWHEEL-DEGRADED]` marker; `execute/SKILL.md` cites it by path + `## Heading`
  anchor and restates none of it. The plugin version is bumped 5.7.0 → 5.8.0 across all four
  version-bearing files with a CHANGELOG `### Added` section.

### Non-Functional Requirements

- **SF-N1 (Non-blocking):** The flywheel step never affects the execute result. A registry that is
  unwritable or unparseable, or a spike that returns `BLOCKED`, degrades or escalates without failing
  or blocking the piece. (Realizes the FR-006 "non-blocking" guarantee and NN-P-004's "nothing
  silently deferred".)
- **SF-N2 (Spike isolation):** The hardening spike runs in a fresh, isolated context and returns a
  ≤2K-token structured summary to the orchestrator; the rich scoping detail lives in the on-disk
  spike artifact (inherits NFR-001 verbatim — the same `agents/spike.md` primitive).
- **SF-N3 (Backward-compatible, additive):** All changes are additive within the current major
  (NN-C-003). With no `flywheel_threshold` key and no `docs/patterns.yaml`, execute behaves exactly as
  before; the flywheel hook is a no-op until a finding is recorded.
- **SF-N4 (Global-reuse factoring):** The registry schema and the match/count mechanics are factored
  so `flywheel-global` (FR-007) reuses them by varying only the registry **location**
  (`docs/patterns.yaml` → machine-global `~/`) and the **routing target** (charter/QA/PRD →
  spec-flow self-improvement piece), plus one added `originating_repo` occurrence field and a `plugin`
  scope value — not a restructure.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (toolchain — md/YAML/JSON/bash, no runtime deps): `docs/patterns.yaml` is read/written by
  the LLM orchestrator's native YAML handling; no `yq`/`jq`/`python` parser or any runtime dependency
  is added.
- NN-C-003 (backward-compatible, additive): absent `flywheel_threshold` and absent `patterns.yaml`
  reproduce current behavior exactly (SF-N3).
- NN-C-005 (refuse rather than guess / silently fail): on an unwritable or unparseable registry the
  flywheel emits `[FLYWHEEL-DEGRADED]` and writes nothing — it never guesses a write or silently
  drops the finding (the finding still flows to its normal triage).
- NN-C-006 (operator-gated state change): every occurrence write and every hardening promotion is
  behind an explicit confirmation prompt.
- NN-C-008 (agents self-contained, bare `name:`): no new agent is created — the hardening path reuses
  the existing self-contained `agents/spike.md`; the dispatch injects all inputs and assumes no shared
  history.
- NN-C-001 / NN-C-007 / NN-C-009 (version ⇄ marketplace sync, CHANGELOG, always-bump): a new
  capability is a minor bump 5.7.0 → 5.8.0 across the four version-bearing files + a Keep-a-Changelog
  section (SF-8, AC-11).

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-004 (flywheel writes and promotions are operator-gated): the central non-negotiable — no
  registry write or promotion without operator confirmation; matches are LLM-proposed, human-confirmed;
  rejections recorded and not re-proposed; nothing auto-applied or silently deferred (SF-3, SF-6, SF-7).
- NN-P-002 (no silent or mid-stream execute-time change): flywheel hardening is never a mid-stream
  patch — it routes through the spike (`scope`) and the existing Step 6c `amend` dispatch, recorded in
  `.discovery-log.md` and re-reviewed by the Final Review board before merge (SF-6).
- NN-P-005 (thinking on Opus, mechanics on Sonnet — no silent upgrade): the hardening "what is the
  fix" thinking is done by the Opus spike agent in isolation — not by a silent Sonnet→Opus upgrade of
  the execute coordinator (SF-6).
- NN-P-001 (human approval gate never removed): unaffected. The Step 4 Human Sign-Off gate still fires
  on the piece's spec work. The flywheel adds a *second, distinct* operator gate (the hardening
  approval at Step 4.5) whose amendment re-enters the Per-Phase Loop + Final Review board before merge
  — exactly as every reflection-finding `amend` does today. No existing sign-off prompt is removed,
  bypassed, or weakened.

### Coding Rules Honored

- CR-004 (Conventional Commits): registry/reference/config commits use `chore(flywheel-repo): …`;
  the flywheel-origin plan amendment uses the existing `chore(plan): amend …` convention.
- CR-008 (thin orchestrator / declarative skills): the match/count/threshold mechanics live as a
  declarative contract in `reference/flywheel.md`; `execute/SKILL.md` carries only the hook + citation,
  no heavyweight imperative logic.

## Acceptance Criteria

> **Verification model (no test harness).** charter-tools fixes the toolchain at markdown/YAML/JSON/
> bash with **no test runner**. Accordingly, each AC's verification is one of: (i) a **grep/inspection
> recipe** a reviewer runs against the shipped SKILL/reference/config prose to confirm the contract is
> documented as specified, or (ii) a **manual smoke scenario** — a scripted operator walk-through whose
> expected observable outcome is stated, to be performed by a human or asserted by the Final Review
> `review-board-integration` reviewer tracing the wired path. ACs label which. This mirrors the
> spike-agent piece's verification model (grep-recipe ACs + adversarial review).

AC-1: Given the `reference/flywheel.md` schema, When a reviewer inspects it, Then `docs/patterns.yaml`
is defined with `schema_version`, `generated`/`last_updated` dates, and a `patterns:` record carrying
`id` (kebab slug), `description`, `scope`, an `occurrences:` list of `{piece, date, source,
source_type}`, and a `rejections:` list; and a worked example file instance is included.
  Independent Test (grep/inspection): `grep -E 'schema_version|occurrences|rejections|source_type'
  plugins/spec-flow/reference/flywheel.md` returns the schema block; a reviewer confirms the five
  occurrence/record fields and the worked example are present and well-formed YAML.

AC-2: Given `reference/flywheel.md`'s count rule, Then count is defined as the number of distinct
`piece` values in `occurrences`; recording is deduped per piece (a second finding of the same pattern
in an already-recorded piece adds no occurrence); a finding in a new piece adds one.
  Independent Test (grep/inspection + manual smoke scenario): grep the reference for the dedup-per-piece
  count rule; smoke scenario — record two same-pattern findings in one piece and confirm the registry
  shows one occurrence (count 1); record one in a second piece and confirm two occurrences (count 2).

AC-3: Given the execute Step 6c flywheel hook prose, Then it specifies that on a finding the flywheel
emits a match proposal (existing `id`, or "new" with a proposed kebab slug), writes nothing to
`docs/patterns.yaml` until the operator confirms classification + scope, and accepts an operator
rename of a "new" slug as the stored `id`.
  Independent Test (grep/inspection): grep `execute/SKILL.md` + `reference/flywheel.md` for the
  no-write-before-confirm rule and the rename-on-new rule; a reviewer confirms the documented gate
  forbids any pre-confirmation registry write (the `review-board-spec-compliance` reviewer checks the
  NN-P-004 gate against the diff).

AC-4: Given the registry schema, Then `source_type` admits exactly `{reflection-finding,
execute-discovery, metric}`; the hook prose wires `reflection-finding` (Step 4.5 reflection findings)
and `execute-discovery` (native per-phase Step 6c discoveries); and no shipped skill/reference prose
emits an occurrence with `source_type: metric`.
  Independent Test (grep/inspection): grep `reference/flywheel.md` for the exact three-value enum; grep
  the hook prose for the two wired source types; `grep -rn 'source_type: *metric' plugins/spec-flow/`
  returns no emission site (only the schema enum definition).

AC-5: Given `flywheel_threshold: N`, When the end-of-piece Step 4.5 batched-proposal prose runs and a
pattern's distinct-piece count ≥ N, Then a single batched proposal is specified to list that pattern and
its recorded `scope` as the routing home; and a pattern with count < N produces no proposal.
  Independent Test (grep/inspection + manual smoke scenario): grep the SKILL/reference for the
  threshold-comparison + single-batched-proposal rule; smoke scenario — with `flywheel_threshold: 2`
  and a seeded count-2 pattern, confirm one batched proposal names the pattern + home; with
  `flywheel_threshold: 3`, confirm no proposal surfaces at count 2.

AC-6: Given an operator-approved hardening proposal, Then the prose specifies the flywheel dispatches
`agents/spike.md` in `scope` mode (isolated), hands the resulting scope artifact to the existing Step
4.5 reflection-finding `amend` dispatch (so `plan-amend` appends the phases, they run the full
Per-Phase Loop, and re-enter Final Review before merge), records the accepted outcome + spike-artifact
reference in `docs/patterns.yaml`, and emits the standard `.discovery-log.md` row.
  Independent Test (grep/inspection + manual smoke scenario): grep the SKILL for the `scope`-mode
  dispatch and the reuse of the existing reflection `amend` path (no new amend mechanism); smoke
  scenario — approve a proposal and confirm `plan.md` gains flywheel-origin amendment phases, the
  pattern record carries the spike-artifact path, and a `step-4.5-reflection` `.discovery-log.md` row
  is appended; `review-board-integration` traces the wired flywheel→spike→plan-amend path.

AC-7: Given an operator-rejected hardening proposal with a rationale, Then the prose specifies a
`rejections:` entry `{date, rationale, rejected_at_count}` is appended and the pattern is not
re-proposed while its distinct-piece count ≤ `rejected_at_count`, but is proposed again once a new
occurrence pushes the count above `rejected_at_count`.
  Independent Test (grep/inspection + manual smoke scenario): grep `reference/flywheel.md` for the
  `rejected_at_count` re-propose rule; smoke scenario — reject at count 2 and confirm no re-proposal at
  count 2; add an occurrence (count 3) and confirm the pattern is proposed again.

AC-8: Given `docs/patterns.yaml` is unwritable or unparseable, Then the prose specifies the flywheel
emits `[FLYWHEEL-DEGRADED: repo registry unavailable]`, performs no registry write, does not block or
fail execute, and the triggering finding still flows to its normal Step 6c triage / reflection
resolution.
  Independent Test (grep/inspection + manual smoke scenario): grep the SKILL/reference for the exact
  marker string and the non-blocking + finding-still-routes guarantees; smoke scenario — make
  `docs/patterns.yaml` read-only (or write malformed YAML), run a piece through Step 6c, and confirm the
  marker is emitted, the piece proceeds to merge, and the finding reaches its normal triage.

AC-9: Given an approved hardening whose scoping spike returns `BLOCKED`, Then the prose specifies
execute escalates to the operator with the spike's findings, no plan amendment is produced, no
mid-stream patch is applied, and the pattern is recorded as proposed-but-unresolved (not a rejection).
  Independent Test (grep/inspection + manual smoke scenario): grep the SKILL for the spike-`BLOCKED`
  escalation branch and the "no amendment / not a rejection" rule; smoke scenario — drive a spike that
  returns `BLOCKED` and confirm an escalation is surfaced, no `chore(plan): amend` commit appears, and
  the pattern carries neither an accepted outcome nor a `rejections:` entry.

AC-10: Given `.spec-flow.yaml` has no `flywheel_threshold` key, Then the threshold defaults to 2 and
behavior is identical to `flywheel_threshold: 2`; and the key is documented (value + default) in
`templates/pipeline-config.yaml` (the authoritative *committed* config source). `.spec-flow.yaml` is
gitignored per-developer runtime config and is not part of the committed deliverable; an absent key
defaults to 2.
  Independent Test (grep/inspection + manual smoke scenario): the committed grep targets
  `templates/pipeline-config.yaml` — `grep -n flywheel_threshold
  plugins/spec-flow/templates/pipeline-config.yaml` shows the documented key + a stated default of 2;
  smoke scenario (operating on the runtime `.spec-flow.yaml` in the working tree) — remove the key and
  confirm a count-2 pattern trips; set `flywheel_threshold: 3` and confirm a count-2 pattern does not
  trip.

AC-11: Given the piece ships, Then `reference/flywheel.md` is the sole definition of the schema /
match / count / threshold / marker mechanics (`execute/SKILL.md` cites it by path + `## Heading` anchor
without restating it), and the plugin version reads 5.8.0 across all four version-bearing files with a
CHANGELOG `## [5.8.0]` `### Added` section.
  Independent Test (grep/inspection): `grep '"version"' plugins/spec-flow/plugin.json
  plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` and the CHANGELOG top
  section all print 5.8.0; `grep -n 'reference/flywheel.md' plugins/spec-flow/skills/execute/SKILL.md`
  shows the citation; a reviewer confirms the schema is defined only in `reference/flywheel.md` (no
  duplicate schema block elsewhere).

## Technical Approach

**Where the hook lives.** The flywheel attaches to the execute **Step 6c Discovery Triage** juncture,
which the pipeline reaches in two places — and the flywheel hooks both identically:

1. **Per-phase Step 6c** (`execute/SKILL.md` ~975): native discoveries (`qa-phase`/`qa-phase-lite`
   findings, AC-matrix NOT-COVERED rows, Build missing-prerequisite escalations) → `source_type:
   execute-discovery`.
2. **End-of-piece Step 4.5 Reflection** (`execute/SKILL.md` ~1785, which runs *after* the Final Review
   board at ~1575 and *after* Human Sign-Off at ~1747, before merge): the two reflection agents' findings
   already route through Step 6c here (`#### Routing reflection findings through Step 6c`, ~1818) →
   `source_type: reflection-finding`.

At either site, the **record + match-propose** step proposes a match against `docs/patterns.yaml` and,
on operator confirmation, appends a per-(pattern, piece) occurrence (the match line is additive to the
existing single-aggregated triage prompt, NFR-6).

> **Naming-collision note for the plan author.** "Step 4.5" is overloaded in `execute/SKILL.md`: there
> is a **per-phase** "Step 4.5 — Completing-phase [Integration-Test] sub-cycle" (~766) AND an
> **end-of-piece** "Step 4.5 — Reflection" (~1785). The flywheel's batched-proposal point is the
> **end-of-piece Reflection** Step 4.5, NOT the per-phase one. The plan must cite line ~1785 and must
> not touch the per-phase ~766 sub-cycle.

**Batched proposal + hardening (reuses the existing reflection-amend path).** The batched hardening
proposal fires at end-of-piece Step 4.5, *after* this piece's reflection findings have been recorded
through the hook — so a pattern that trips because of this piece's own reflection finding is included.
On approval, the flywheel dispatches `agents/spike.md` in `scope` mode (Opus, isolated) with
`{pattern, occurrences, proposed home}`; the spike writes a scope artifact (same schema as FR-008
scope spikes). That artifact is handed to the **existing** Step 4.5 reflection-finding `amend` dispatch
(`execute/SKILL.md` ~1844: "the standard Step 6c amend dispatch fires — `plan-amend` runs … amendment
phases run through the full Per-Phase Loop … the amendment budget applies"). No new amend mechanism is
introduced: the scoped hardening becomes amendment phases that re-run the loop and re-enter the Final
Review board before merge, landing in the piece's own diff with a `step-4.5-reflection`
`.discovery-log.md` row. This is the load-bearing reuse that makes "fix it now, in this piece" coherent
*without* bypassing review — the post-sign-off amend re-review is the same one every reflection-finding
amend already performs (NN-P-001/NN-P-002 honored).

**Count semantics — reconciliation with FR-006 AC1.** FR-006 AC1 states "count = occurrences length"
and the PRD edge case (prd.md ~243) states "same finding twice in one repo → two occurrences →
threshold trips." This spec resolves the PRD's own Open Question ("Pattern occurrence granularity: one
per piece … or one per reflection finding?") in favor of **per-(pattern, piece)**. The two are
consistent: because recording is deduped per piece, the `occurrences` list holds exactly one entry per
distinct piece, so `count = len(occurrences)` holds *exactly* as FR-006 AC1 requires. The edge case's
"twice in one repo" is realized as **two distinct pieces in the repo** — the cross-piece unit the PRD's
own correlation goal is built on ("correlating patterns across PRDs within the repo," "a defect
appearing once per repo correlate across all repos"). A pattern recurring twice *within a single piece*
is one occurrence and does not trip the threshold — this is the deliberate, goal-aligned reading, stated
here so no implementer infers per-finding counting.

**`docs/patterns.yaml` schema (defined canonically in `reference/flywheel.md`).** Mirrors the
`manifest.yaml` registry envelope (house style):

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

Count = number of distinct `piece` values in `occurrences` (= `len(occurrences)` under dedup-on-piece).
The `metric` `source_type` and the `originating_repo` field are reserved for later work (schema-open)
but unwritten here (wire-narrow).

**Config.** The committed `flywheel_threshold: <int>` (default 2) key lives in
`templates/pipeline-config.yaml` — the authoritative *committed* config source — documented inline in
the house comment style (a plain integer with the default called out). The live `.spec-flow.yaml` is a
gitignored per-developer override read at runtime (default 2 if the key is absent); it is not part of
the committed deliverable.

**Degraded path.** A single bracketed orchestrator line `[FLYWHEEL-DEGRADED: repo registry
unavailable]` on unwritable/unparseable `docs/patterns.yaml`; no write; execute unblocked; the finding
continues to its normal Step 6c triage / reflection resolution. Mirrors the `[RESEARCH-UNAVAILABLE]` /
`[TEST-DATA-ABSENT]` marker convention.

## Testing Strategy

- **Track:** doc-as-code / Implement (no behavior-bearing runtime code; `tdd: false` ⇒
  `qa_max_iterations: auto` = 5). Per the Verification model note above, there is **no test runner**
  (charter-tools); verification is grep/inspection recipes against the shipped prose + manual smoke
  scenarios + the adversarial gates (`qa-plan`, Final Review `spec-compliance` /
  `review-board-integration`).
- **Inspection-verifiable (grep recipes):** schema definition (AC-1), count/dedup rule (AC-2),
  no-write-before-confirm gate (AC-3), `source_type` enum + no `metric` emission (AC-4), threshold rule
  (AC-5), spike-mode dispatch + existing-amend-path reuse (AC-6), `rejected_at_count` rule (AC-7),
  degraded marker (AC-8), spike-`BLOCKED` branch (AC-9), config key documentation (AC-10), version-sync
  + SSOT (AC-11).
- **Manual smoke scenarios (operator walk-through, expected outcome stated):** dedup count (AC-2),
  threshold trip vs no-trip (AC-5), end-to-end hardening amend (AC-6), reject-then-worsen re-propose
  (AC-7), read-only/malformed registry degraded path (AC-8), spike-`BLOCKED` escalation (AC-9), config
  default vs override (AC-10).
- **Adversarial-gate verification:** `review-board-spec-compliance` checks the NN-P-004 no-silent-write
  gate against the diff; `review-board-integration` traces the wired flywheel→spike→plan-amend path
  (AC-6, AC-9).

## Integration Coverage

Doc-as-code pipeline: there are no runtime services to double, and no test runner exists (NN-C-002,
charter-tools). "Contract test" here = the boundary contract is **defined in `reference/flywheel.md`**
and the **wired path is audited by the Final Review `review-board-integration` reviewer** against the
named AC scenario; there is no mocked-double unit test (and none is claimed).

- Integration: flywheel→spike-agent — inside:{`execute/SKILL.md` flywheel hook, `agents/spike.md`};
  boundary contract: dispatch injects `{pattern, occurrences, proposed home}` with `mode: scope`, spike
  returns `STATUS: OK` + a scope-artifact path or `STATUS: BLOCKED` + findings; verified by
  `review-board-integration` tracing the path; AC-6 (OK path), AC-9 (BLOCKED path).
- Integration: flywheel→plan-amend — inside:{`execute/SKILL.md` existing Step 4.5 `amend` dispatch,
  `agents/plan-amend.md`}; boundary contract: the spike scope-artifact is consumed by the *existing*
  reflection-finding `amend` path (no new wiring on the plan-amend side); verified by
  `review-board-integration`; AC-6.
- Integration: flywheel→reflection findings — inside:{`execute/SKILL.md` Step 4.5 `#### Routing
  reflection findings through Step 6c`}; the reflection agents stay read-only and emit structured
  findings; the flywheel reads them at the existing Step 6c routing point (no agent modification);
  AC-4.
- Integration: flywheel→`docs/patterns.yaml` (filesystem) — the only true external I/O; its failure
  modes are the degraded path; verified by the AC-8 smoke scenario (read-only / malformed file); AC-1,
  AC-8.

## Explicitly Out of Scope / Deferred

These were surfaced during brainstorm (PRD Open Questions + `docs/prds/exec-ready/backlog.md` FO
items) and explicitly deferred. The `metric` source_type and `originating_repo` field are
schema-reserved here so the deferred work is additive, not a restructure.

- **spike-agent FO-2 — admission-`n` event recording (`admission-false-positive` pattern-type).**
  Proposed owner: a follow-on `flywheel-enhancements` piece (new, TBD). Represented by the reserved
  `metric` source_type; no emitter wired here.
- **spike-agent FO-3 — cross-piece resolved-spike index in `docs/patterns.yaml`.** Proposed owner:
  `flywheel-enhancements` (new, TBD) or `flywheel-global`. Schema reserves room; not built here.
- **spike-agent FO-1 — configurable `spike_threshold` key.** Proposed owner: `flywheel-enhancements`
  (new, TBD). This piece adds only `flywheel_threshold`.
- **Per-scope (charter/QA/PRD) thresholds.** Proposed owner: `flywheel-enhancements` (new, TBD).
- **Note — INCORPORATED, not deferred:** the backlog item "unmarked-execute-time-discovery as a
  first-class flywheel pattern-type" is folded into SF-4 as the `execute-discovery` source_type
  (wired), so it is addressed by this piece rather than deferred.

## Open Questions

(None blocking. All brainstorm questions were resolved; no surviving uncertainty markers.)
