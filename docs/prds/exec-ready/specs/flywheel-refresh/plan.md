---
charter_snapshot:
  non-negotiables: 2026-06-05
  architecture: 2026-06-10
  coding-rules: 2026-06-01
  processes: 2026-06-01
  tools: 2026-06-10
  flows: 2026-06-01
piece: exec-ready/flywheel-refresh
tdd: false
fast: false
---

# Plan: flywheel-refresh

**Spec:** `docs/prds/exec-ready/specs/flywheel-refresh/spec.md`
**PRD Sections:** FR-015, SC-003, SC-005, G-5
**Dependencies:** flywheel-repo (merged)

## Overview

Doc-as-code extend of the merged flywheel registry. All work edits markdown + YAML config + orchestrator prose — **no runtime code, no test suite** (markdown/config-only repo, NN-C-002). Per the project `tdd: false` setting and the merged `flywheel-repo` precedent, every phase is **Implement-track**; verification is **grep-inspection + manual smoke walk-throughs** (the spec's Testing Strategy), placed in each `[Verify]` block. There are no `[Write-Tests]` steps because there is no executable test surface — the grep recipes ARE the verification. AC Coverage Matrix is required (Implement track retains it).

The single source of truth is `plugins/spec-flow/reference/flywheel.md`; `execute/SKILL.md` only **cites** it (CR-008 / NN-C-008). Phases 1–3 edit different sections of `flywheel.md` and are therefore **serial** (same-file write contention). Phase 4 cites the sections Phases 1–3 create. Phase 5 is the release bump, last.

`[RESEARCH-CONSUMED: 4 files, 4 re-read]` · `[DELIBERATION-CONSUMED: read-time-derivation lifecycle; derive active/hardened via count-vs-at_count, store only archived; piece-count staleness window default 8; refresh at Step 4.5; C-exclude scope]`

## Architectural Decisions

### ADR-1: Derive `state`, store only `archived`
**Context:** A lifecycle needs `active`/`hardened`/`archived`. A stored `state` field drifts out of sync with the `hardenings`/`occurrences` data it summarizes ("zombie memory") and needs a new write path at every occurrence-append site.
**Decision:** `active`↔`hardened` and `last_seen` are **derived at read time** from existing data; `archived` is the **only** stored lifecycle bit.
**Alternatives considered:** All-stored (drift + new write paths); all-derived (cannot derive `archived` — it is operator intent with no data antecedent, and deriving it would silently revive operator-archived patterns).
**Consequences:** Zero new write paths except the operator-confirmed `archived` flip; legacy registries derive `active` free (no migration); reads never mutate.
**Charter alignment:** NN-C-003 (legacy⇒active), NN-P-004 (no silent write), CR-008 (no new mechanics).

### ADR-2: Single-source `hardened` via count-vs-`at_count` arithmetic
**Context:** A date-ordering predicate ("no later occurrence") would, given day-granularity dates and frequent same-day merges, mis-derive a same-day post-hardening recurrence as still `hardened` — and would be a second formulation of exclusion-rule #2 that can disagree with it.
**Decision:** `hardened` iff the latest `resolved` hardening's `at_count ≥ count` (the existing exclusion-rule #2). `ineffective-hardening` is the same rule read in the negative. No date-ordering formulation exists.
**Alternatives considered:** Date-ordering (ambiguous at equal dates; drifts from rule #2); intra-day ordinal (no such field exists; out of scope).
**Consequences:** One predicate defined once; count is distinct-piece-based so recurrence is detected regardless of date granularity.
**Charter alignment:** CR-008/NN-C-008 (single definition, cross-referenced).

### ADR-3: Piece-count staleness window, registry-internal
**Context:** A calendar-days window never trips at the operator's velocity (40 commits / 2 days); a global piece ordinal does not exist and inventing one is out of scope.
**Decision:** `pieces_since_last_seen` = count of distinct pieces across all patterns' `occurrences` with `date > last_seen`. Window `staleness_window` default `8`, read from `.spec-flow.yaml`, documented in tracked `pipeline-config.yaml`.
**Alternatives considered:** N-days (dead on arrival at this velocity); manifest cross-read (heavier coupling, cross-PRD); both (YAGNI + needs the ordinal source anyway).
**Consequences:** Fully registry-internal; measures flywheel-active-piece cadence; no manifest dependency.
**Charter alignment:** NN-C-008 (no cross-artifact coupling), NN-C-003 (absent/null⇒default).

### ADR-4: Refresh at Step 4.5 only; revive in the same prompt
**Context:** FR-015's "end-of-piece OR on demand" disjunction is satisfied by the end-of-piece arm; no `commands/` host exists and `status` is read-only.
**Decision:** Refresh fires automatically at end-of-piece Step 4.5 adjacent to the existing batched hardening proposal; archival + revive are one operator-gated prompt. No on-demand skill.
**Alternatives considered:** New `/spec-flow:flywheel-refresh` skill (net-new surface, YAGNI); fold into `status` (read-only — cannot write).
**Consequences:** Maximal reuse of the existing juncture; per-piece refresh cadence.
**Charter alignment:** NN-P-004 (operator-gated), CR-008 (no new skill).

### ADR-5: C-exclude scope — FW-2 deferred
**Context:** New lifecycle fields raise the structural-validity surface, but FR-015 names no lint.
**Decision:** Ship only FR-015's ACs; the degraded check reuses existing fault logic plus a thin present-but-invalid check. No `## Registry invariants` section, no `flywheel-lint` step.
**Alternatives considered:** Full FW-2 lint (untraceable to FR-015, budget overage → piece-split per charter).
**Consequences:** Piece stays tight; FW-2 owned by flywheel-global.
**Charter alignment:** artifact budgets, NN-C-008.

## Phases

**Cross-cutting charter constraints** (honored by all phases via the named mechanism; the per-phase "Charter constraints honored" slots list only each phase's specific honoring):
- **NN-C-002** (markdown + config only) — every phase edits only `.md` / `.yaml` prose; no runtime code, no `scripts/`, no dependency.
- **NN-C-008 / CR-008** (SSOT discipline) — all lifecycle rules live in `reference/flywheel.md`; `execute/SKILL.md` only cites them (Phase 4).
- **NN-C-003** (backward-compat additive) — distinct honoring surfaces across Phase 1 (legacy registry derives `active`, schema-open), Phase 2 (absent/null/empty `staleness_window` ⇒ default 8), Phase 3 (absence of lifecycle fields ≠ malformed).
- **CR-009** (heading hierarchy) — Phases 1–3 slot new content into the existing `##` / `###` structure.

### Phase 1: Schema lifecycle fields + single-sourced state derivation
**ACs Covered:** AC-1, AC-2, AC-14
**Charter constraints honored in this phase:** NN-C-003 (legacy⇒active, schema-open additive), NN-C-008/CR-008 (definitions in SSOT), CR-009 (heading hierarchy)
**In scope:** Add lifecycle field rules to `reference/flywheel.md` `## Registry schema`; define `hardened`/`active` derivation via count-vs-`at_count` cross-referencing `## Threshold + batched proposal` rule #2.
**NOT in scope:** the refresh pass / staleness / archival arms (Phase 2); degraded-path + no-secrets (Phase 3); execute citations (Phase 4); config key (Phase 2); version bump (Phase 5).
**Exit Gate:** grep confirms the three lifecycle field rules + the count-arithmetic `hardened` definition + the no-date-ordering property; the illustrative YAML carries an example lifecycle annotation.

- [x] **[Implement]**

  **File changes:** MODIFY `plugins/spec-flow/reference/flywheel.md`

  T-1: MODIFY `plugins/spec-flow/reference/flywheel.md`
  Anchor: `**Field rules:**` list, after the `hardenings` bullet (line 35).
  CURRENT (L35):
  ```
  - `hardenings` — a list of hardening-outcome records; each carries `{date, outcome: resolved|blocked, ...}`. ... See `## Hardening dispatch (reuse)`.
  ```
  TARGET: Append three lifecycle field-rule bullets after the `hardenings` bullet:
  - `state` — DERIVED, never stored except `archived`. Values `active | hardened | archived`. `hardened` iff the pattern's latest `outcome: resolved` hardening has `at_count ≥ count` (it is currently resolved-suppressed per `## Threshold + batched proposal` exclusion-rule #2 — that rule is the single definition; there is no date-ordering formulation). Otherwise `active`. `archived` is the lone STORED lifecycle marker (operator-set; archival is an operator decision with no data antecedent — NN-P-004). A registry with no lifecycle fields reads as `active` with no migration (NN-C-003); absence of lifecycle fields is NOT malformed (see `## Degraded path`).
  - `last_seen` — DERIVED `= max(occurrences[].date)`. No stored field.
  - `archived` — optional stored marker; present only on operator-confirmed archival; archived patterns stay in-file for audit and leave the auto-match candidate set (see `## Match + confirm flow`, `## Pattern lifecycle`).
  TARGET (cont.): In the illustrative YAML block (L13–25), add a trailing comment line after the `hardenings: []` line (L24) showing the derived/stored split:
  ```
      # state: derived (active|hardened|archived); last_seen: derived = max(occurrences[].date); archived: stored marker, operator-set only
  ```
  Pattern (mirror the existing field-rule bullet voice at L29–35 and the inline-comment style at L16/L21).
  Done: three new bullets exist; `state` bullet cross-references exclusion-rule #2 and states no date-ordering; YAML carries the derived/stored annotation.
  Verify: `grep -n "DERIVED\|exclusion-rule #2\|lone STORED lifecycle" plugins/spec-flow/reference/flywheel.md` returns ≥3 matches.

- [x] **[Verify]**
  - Run: `grep -c "state\|last_seen\|archived" plugins/spec-flow/reference/flywheel.md` — Expected: ≥3 (lifecycle fields present).
  - Run: `grep -n "at_count ≥ count\|exclusion-rule #2" plugins/spec-flow/reference/flywheel.md` — Expected: ≥1 match (count-arithmetic `hardened`, single-sourced). **[AC-2]**
  - Run: `grep -in "no later occurrence\|no occurrence dated after\|strictly later occurrence" plugins/spec-flow/reference/flywheel.md` — Expected: 0 hits (no residual date-ordering state formulation). **[AC-2]**
  - LLM-agent-step: read the `## Registry schema` field rules and confirm the `state` bullet states "reads as `active` with no migration" and "absence … is NOT malformed". **[AC-1, AC-14]**

- [x] **[QA]** ACs reviewed: AC-1, AC-2, AC-14. Diff baseline: phase_1_start_sha. Result: CLEAN.

### Phase 2: Pattern lifecycle — staleness window, refresh pass, archival arms, rendering, match-exclusion/revive
**ACs Covered:** AC-3, AC-4, AC-5, AC-6, AC-8, AC-10
**Charter constraints honored in this phase:** NN-P-004 (operator-gated archival/revive; derivation reads never write), NN-P-005 (refresh is deterministic mechanics — no Opus upgrade; the spike hardening dispatch is unchanged), NN-C-003 (absent/null/empty `staleness_window` ⇒ default 8), NN-C-008/CR-008 (mechanics in SSOT), CR-007 (config key documented inline), CR-009 (heading hierarchy)
**In scope:** New `## Pattern lifecycle` H2 in `reference/flywheel.md` (after `## Threshold + batched proposal`, before `## Hardening dispatch`) defining `pieces_since_last_seen`, the staleness window, the two archival arms, `ineffective-hardening` + elevated regressions block, in-proposal rendering, and the read-never-write invariant; archived-exclusion + near-match-revive added to `## Match + confirm flow`; `staleness_window` config doc added to `templates/pipeline-config.yaml`.
**NOT in scope:** atomic-write/torn-write + malformed-lifecycle degraded (Phase 3); execute citations (Phase 4); version bump (Phase 5).
**Exit Gate:** grep confirms `## Pattern lifecycle` with both archival arms, the `pieces_since_last_seen` definition + worked example, the regressions block, the in-proposal rendering, the archived-exclusion/revive prose, and the `staleness_window` config block.

- [x] **[Implement]**

  **File changes:** MODIFY `plugins/spec-flow/reference/flywheel.md`; MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`

  T-1: MODIFY `plugins/spec-flow/reference/flywheel.md`
  Anchor: insert a new `## Pattern lifecycle` H2 between `## Threshold + batched proposal` (ends L94) and `## Hardening dispatch (reuse)` (L95).
  TARGET: Author the section with these labelled parts:
  - **Derived state** — restate the pointer (not the rule): `state`/`last_seen` derive per `## Registry schema`; `hardened`/`active` use exclusion-rule #2 (no restatement of the arithmetic — cross-reference only, CR-008).
  - **`ineffective-hardening`** — a pattern with a `resolved` hardening whose `count` has since exceeded that hardening's `at_count` (exclusion-rule #2 read in the negative). It is a COMPUTED condition + label, not a stored flag. Surfaced in a DISTINCT, elevated "regressions" block at the batched review (not a peer proposal row) — honors FR-015 "elevated priority". An ineffective hardening derives `active` (count > at_count) and a recurrence advances derived `last_seen`; it is excluded from both archival arms.
  - **Staleness window** — `pieces_since_last_seen` = count of distinct `piece` values across ALL patterns' `occurrences` whose `date` is after this pattern's `last_seen` (flywheel-active-piece cadence; registry-internal; no global ordinal, no manifest read). The window is `staleness_window` (default `8`, read from `.spec-flow.yaml`). An absent key, a present-but-null, and a present-but-empty value ALL resolve to `8`; a null is never read as `0`.
  - **Worked example** (fenced block, mirror the `## Count rule` example at L41–46, ACTUAL values):
    ```
    Worked example (staleness_window = 8):
      pattern P, last_seen = exec-ready/metrics; distinct pieces recorded after it = 8 (none for P) → pieces_since_last_seen 8 ≥ 8 → stale; if state active → stale-active arm; if state hardened → clean-hardened arm
      pattern Q, last_seen = exec-ready/gate-scaling; distinct pieces after it = 3 → 3 < 8 → not stale, no proposal
      pattern R, hardened at_count 2, recurs in a new piece → count 3 > 2 → derives active, last_seen advances → ineffective-hardening regressions block, NOT archival
    ```
  - **Refresh pass (two archival arms, operator-gated, Step 4.5)** — at end-of-piece Step 4.5, after the existing batched hardening proposal, surface ONE operator-gated batched archival proposal listing: (a) stale-active (`state: active`, `pieces_since_last_seen ≥ staleness_window`); (b) clean-hardened (`state: hardened`, `pieces_since_last_seen ≥ staleness_window`). Both arms use the single `pieces_since_last_seen` clock (differ only by derived state). Nothing archives until the operator confirms (NN-P-004).
  - **In-proposal rendering** — the proposal renders, per listed pattern, its derived `state`, `last_seen`, and ineffective-hardening status.
  - **Read-never-write invariant** — deriving `state`/`last_seen`/`ineffective-hardening` and computing `pieces_since_last_seen` are READS; they never write the registry. The only refresh writes are the operator-confirmed `archived` flip and revive flip (atomicity per `## Degraded path`).
  Done: `## Pattern lifecycle` exists with all seven labelled parts + the worked example.
  Verify: `grep -n "## Pattern lifecycle" plugins/spec-flow/reference/flywheel.md` returns a match.

  T-2: MODIFY `plugins/spec-flow/reference/flywheel.md`
  Anchor: `## Match + confirm flow (no silent write)`, after L57 (the "writes nothing until operator confirms" paragraph).
  TARGET: Append a paragraph: an `archived` pattern is EXCLUDED from the auto-match candidate set. When a Step 6c finding near-matches an archived pattern, the flywheel surfaces a revive option (`resembles archived pattern <id> — revive or mint new?`) so historical correlation is not silently lost (NN-P-004 — operator decides). Revive (clearing the `archived` marker) is offered in the same Step 4.5 refresh prompt; archived entries are never deleted.
  Pattern (mirror the operator-confirm voice at L57).
  Done: archived-exclusion + near-match-revive paragraph present.
  Verify: `grep -n "resembles archived pattern\|excluded from the auto-match" plugins/spec-flow/reference/flywheel.md` returns ≥1 match.

  T-3: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml`
  Anchor: after `flywheel_threshold: 2` (line 86).
  CURRENT (L82–86):
  ```
  # flywheel_threshold: repo-level self-hardening flywheel — occurrence count at which a pattern's
  #   batched hardening proposal is surfaced at end-of-piece reflection (new in v5.8.0; FR-006).
  #   <int> — distinct-piece occurrence count threshold (default 2). Absent ⇒ 2 (non-blocking; NN-C-003).
  #   See plugins/spec-flow/reference/flywheel.md `## Threshold + batched proposal`.
  flywheel_threshold: 2
  ```
  TARGET: Insert a blank line then a mirrored CR-007 block after L86:
  ```
  # staleness_window: flywheel pattern lifecycle — distinct flywheel-active pieces since a pattern's
  #   last occurrence after which the refresh pass proposes it for archival (new in v5.13.0; FR-015).
  #   <int> — distinct-piece staleness window (default 8). Absent / null / empty ⇒ 8 (non-blocking; NN-C-003).
  #   See plugins/spec-flow/reference/flywheel.md `## Pattern lifecycle`.
  staleness_window: 8
  ```
  Done: `staleness_window: 8` documented in the CR-007 style.
  Verify: `grep -n "staleness_window: 8" plugins/spec-flow/templates/pipeline-config.yaml` returns a match.

- [x] **[Verify]**
  - Run: `grep -n "## Pattern lifecycle" plugins/spec-flow/reference/flywheel.md` — Expected: 1 match. **[AC-3, AC-5]**
  - Run: `grep -in "stale-active\|clean-hardened" plugins/spec-flow/reference/flywheel.md` — Expected: ≥2 (both archival arms present). **[AC-5]**
  - Run: `grep -in "regressions\|ineffective-hardening" plugins/spec-flow/reference/flywheel.md` — Expected: ≥2 (elevated regressions block). **[AC-3]**
  - Run: `grep -n "pieces_since_last_seen" plugins/spec-flow/reference/flywheel.md` — Expected: ≥3 (definition + window + worked example). **[AC-4]**
  - LLM-agent-step: read the staleness-window prose and confirm "absent", "null", and "empty" all resolve to `8`. **[AC-4]**
  - LLM-agent-step: read the worked example and confirm it shows ACTUAL piece slugs and the `8 ≥ 8 → stale` / `3 < 8 → not stale` traces (dense-algorithm worked example present). **[AC-5]**
  - Run: `grep -in "renders, per listed pattern\|renders .*state.*last_seen" plugins/spec-flow/reference/flywheel.md` — Expected: ≥1 (in-proposal rendering). **[AC-8]**
  - LLM-agent-step: read the Read-never-write invariant and confirm derivation/`pieces_since_last_seen` are reads and only operator-confirmed flips write. **[AC-10]**
  - Run: `grep -n "resembles archived pattern" plugins/spec-flow/reference/flywheel.md` — Expected: 1 match. **[AC-6]**
  - Run: `grep -n "staleness_window: 8" plugins/spec-flow/templates/pipeline-config.yaml` — Expected: 1 match. **[AC-4]**

- [x] **[QA]** ACs reviewed: AC-3, AC-4, AC-5, AC-6, AC-8, AC-10. Diff baseline: phase_2_start_sha. Result: CLEAN (should-fix applied — Step 6c vs Step 4.5 revive surfaces clarified).

### Phase 3: Write safety + degraded-path extension + no-secrets
**ACs Covered:** AC-7, AC-9, AC-13
**Charter constraints honored in this phase:** NN-C-005 (degraded no-op, non-blocking), NN-C-003 (absence≠malformed), NN-C-008/CR-008 (SSOT)
**In scope:** Extend `reference/flywheel.md` `## Degraded path` with the malformed-lifecycle trigger, the absence≠malformed clause, and atomic-write + post-write verification; extend `## No secrets` to the new free-text surfaces.
**NOT in scope:** execute citations (Phase 4); version bump (Phase 5).
**Exit Gate:** grep confirms the `lifecycle unavailable` marker variant, the absence-not-malformed clause, the atomic temp+rename write + torn-write `archival not applied` notice, and the extended no-secrets field list.

- [x] **[Implement]**

  **File changes:** MODIFY `plugins/spec-flow/reference/flywheel.md`

  T-1: MODIFY `plugins/spec-flow/reference/flywheel.md`
  Anchor: `## Degraded path`, after the existing list (after L131, before the L133 "mirrors the marker convention" paragraph).
  TARGET: Append a `**Lifecycle degraded path**` paragraph:
  - A PRESENT-but-invalid lifecycle value (an `archived` marker not in the sanctioned form, or an otherwise malformed lifecycle field) → emit `[FLYWHEEL-DEGRADED: lifecycle unavailable]`, propose nothing, leave the file untouched; recording continues per the rest of this section. **ABSENCE** of lifecycle fields is NOT malformed — it derives `active` (see `## Registry schema`) and MUST NOT trip the marker.
  - **Atomic write.** Any refresh write (archival flip, revive flip) is atomic: write to a temp file then rename (all-or-nothing). After the write, re-read the file; if the write did not fully land, emit `[FLYWHEEL-DEGRADED: lifecycle unavailable]` with an explicit `archival not applied` notice. The pre-flight gate above covers torn READS; this covers torn WRITES.
  Pattern (mirror the numbered degraded steps at L126–129 and the marker style at L126).
  Done: lifecycle-degraded paragraph with the marker variant, absence≠malformed clause, atomic-write + torn-write notice.
  Verify: `grep -n "lifecycle unavailable" plugins/spec-flow/reference/flywheel.md` returns ≥1 match.

  T-2: MODIFY `plugins/spec-flow/reference/flywheel.md`
  Anchor: `## No secrets` (L135–137).
  CURRENT (L137):
  ```
  When transcribing finding text into an occurrence `source`, or into a `hardenings` or `rejections` rationale, never copy credentials, tokens, private keys, or connection strings verbatim — summarize the finding's nature instead.
  ```
  TARGET: Extend the field list to include the new lifecycle free-text surfaces: "... into a `hardenings` or `rejections` rationale, **or into an archival rationale or regression/revive note**, never copy credentials, ...".
  Done: archival rationale + regression/revive note named in the no-secrets rule.
  Verify: `grep -n "archival rationale\|regression/revive note" plugins/spec-flow/reference/flywheel.md` returns ≥1 match.

- [x] **[Verify]**
  - Run: `grep -c "lifecycle unavailable" plugins/spec-flow/reference/flywheel.md` — Expected: ≥1 (marker variant present). **[AC-9]**
  - LLM-agent-step: read the lifecycle degraded paragraph and confirm it states ABSENCE of lifecycle fields is NOT malformed and does not trip the marker. **[AC-9]**
  - Run: `grep -in "temp file then rename\|atomic\|archival not applied" plugins/spec-flow/reference/flywheel.md` — Expected: ≥2 (atomic write + torn-write notice). **[AC-7]**
  - Run: `grep -n "archival rationale\|regression/revive note" plugins/spec-flow/reference/flywheel.md` — Expected: ≥1 match. **[AC-13]**

- [x] **[QA]** ACs reviewed: AC-7, AC-9, AC-13. Diff baseline: phase_3_start_sha. Result: CLEAN.

### Phase 4: Execute wiring (citations only) + cross-phase schema-consistency
**ACs Covered:** AC-11
**Charter constraints honored in this phase:** NN-C-008/CR-008 (execute cites SSOT, restates no rule)
**In scope:** Add citation lines to `execute/SKILL.md` at the match hook (L1079 region) and the batched hardening proposal (L1913 region) pointing at the new `flywheel.md` lifecycle sections; cross-phase schema-consistency verify of section names + marker string.
**NOT in scope:** any rule restatement (cite-only); version bump (Phase 5).
**Steps traversed (P2):** the refresh-pass citation adds a path through `### Step 4.5: Reflection` (L1846) after `#### Flywheel batched hardening proposal` (L1913); it traverses the existing recording hook (`#### Flywheel pattern recording`, L1079) and the batched hardening proposal (L1913) — both pre-existing and unchanged except for the added citations.
**Dispatch sites (P3):** none — the refresh pass is deterministic; no new or changed agent dispatch (the spike hardening dispatch at L1921 is unchanged).
**Exit Gate:** execute cites the new lifecycle sections; grep confirms cite-markers present and no restated lifecycle rule prose; cross-phase check confirms cited section names + marker match `flywheel.md`.

- [x] **[Implement]**

  **File changes:** MODIFY `plugins/spec-flow/skills/execute/SKILL.md`

  T-1: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: `#### Flywheel pattern recording (FR-006)` (L1079), end of that subsection.
  TARGET: Append a citation sentence: archived patterns are excluded from the auto-match candidate set and a near-match surfaces a revive option — see `plugins/spec-flow/reference/flywheel.md` `## Match + confirm flow` and `## Pattern lifecycle`. Do NOT restate the rules here (CR-008 / NN-C-008).
  Done: citation present, no restated rule.
  Verify: `grep -n "## Pattern lifecycle" plugins/spec-flow/skills/execute/SKILL.md` returns ≥1 match.

  T-2: MODIFY `plugins/spec-flow/skills/execute/SKILL.md`
  Anchor: `#### Flywheel batched hardening proposal (FR-006)` (L1913), after the on-approve bullet block (ends ~L1925).
  TARGET: Append a `**Flywheel refresh pass (FR-015).**` paragraph (citation-only): after the batched hardening proposal, run the operator-gated refresh pass — one batched archival proposal (stale-active + clean-hardened arms), the ineffective-hardening regressions block, in-proposal lifecycle rendering, and revive — all per `plugins/spec-flow/reference/flywheel.md` `## Pattern lifecycle`. Read `staleness_window` from `.spec-flow.yaml` (default 8). On malformed-lifecycle or torn write, emit `[FLYWHEEL-DEGRADED: lifecycle unavailable]` and continue (non-blocking) per `## Degraded path`. Do NOT restate the mechanics here (CR-008 / NN-C-008).
  Done: refresh-pass citation present; cites `## Pattern lifecycle` + `## Degraded path`; names the marker + config key + default; no restated mechanics.
  Verify: `grep -n "Flywheel refresh pass (FR-015)" plugins/spec-flow/skills/execute/SKILL.md` returns a match.

- [x] **[Verify]**
  - Run: `grep -cn "reference/flywheel.md \`## Pattern lifecycle\`" plugins/spec-flow/skills/execute/SKILL.md` — Expected: ≥2 (both sites cite the new section). **[AC-11]**
  - LLM-agent-step: read the two added execute paragraphs and confirm each contains a "do NOT restate / CR-008 / NN-C-008" guard and no copied lifecycle rule prose (e.g. no `at_count ≥ count` arithmetic, no `pieces_since_last_seen` formula). **[AC-11]**
  - **[Verify — cross-phase schema-consistency oracle]** Schema-bearing file: `reference/flywheel.md` (section names + the `[FLYWHEEL-DEGRADED: lifecycle unavailable]` marker established in Phases 1–3). Invariants: every section name and the marker string cited in `execute/SKILL.md` must exist verbatim in `flywheel.md`.
    - Run: `grep -n "## Pattern lifecycle" plugins/spec-flow/reference/flywheel.md` — Expected: 1 match (the cited section exists).
    - Run: `for s in "## Pattern lifecycle" "## Degraded path" "## Match + confirm flow"; do grep -q "$s" plugins/spec-flow/reference/flywheel.md || echo "MISSING: $s"; done` — Expected: no `MISSING` output.
    - Run: `grep -o "FLYWHEEL-DEGRADED: lifecycle unavailable" plugins/spec-flow/skills/execute/SKILL.md plugins/spec-flow/reference/flywheel.md | sort -u | wc -l` — Expected: 1 (identical marker string in both files).

- [x] **[QA]** ACs reviewed: AC-11 + cross-phase schema consistency. Diff baseline: phase_4_start_sha. Result: CLEAN (1 must-fix applied — citation truncation corrected to full section heading).

### Phase 5: Version bump + CHANGELOG (MINOR → 5.13.0)
**ACs Covered:** AC-12
**Charter constraints honored in this phase:** NN-C-009 (version bump on change), NN-C-001 (plugin + marketplace sync), NN-C-007 (CHANGELOG Keep-a-Changelog), CR-006 (CHANGELOG format)
**In scope:** Bump `5.12.3` → `5.13.0` in all four version-bearing files; add a CHANGELOG `## [5.13.0]` entry.
**NOT in scope:** any behavior change.
**Exit Gate:** all four files read `5.13.0`; CHANGELOG has a matching `## [5.13.0]` section; no stale `5.12.3` lingers in the four files.

- [x] **[Implement]**

  **File changes:** MODIFY `plugins/spec-flow/plugin.json`; MODIFY `plugins/spec-flow/.claude-plugin/plugin.json`; MODIFY `.claude-plugin/marketplace.json`; MODIFY `plugins/spec-flow/CHANGELOG.md`

  **Version-drift guard (spec-preresearch learning):** before bumping, confirm master's current spec-flow version is still `5.12.3` (no advance during this cycle): `git show origin/master:plugins/spec-flow/.claude-plugin/plugin.json | grep '"version"'`. If it reads higher than `5.12.3`, the target becomes `<that-version's next MINOR>` and all four files + the CHANGELOG header use that — reconcile before committing.

  T-1: MODIFY `plugins/spec-flow/plugin.json` — L4 `"version": "5.12.3",` → `"version": "5.13.0",`. Verify: `grep '"version": "5.13.0"' plugins/spec-flow/plugin.json`.
  T-2: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` — L4 `"version": "5.12.3",` → `"version": "5.13.0",`. Verify: `grep '"version": "5.13.0"' plugins/spec-flow/.claude-plugin/plugin.json`.
  T-3: MODIFY `.claude-plugin/marketplace.json` — the spec-flow entry's `"version": "5.12.3",` at L15 → `"version": "5.13.0",`. Do NOT touch L24 (`"version": "1.1.1"` — a different plugin). Verify: `grep -n '"version": "5.13.0"' .claude-plugin/marketplace.json` returns the line in the spec-flow block (around L15).
  T-4: MODIFY `plugins/spec-flow/CHANGELOG.md` — after `## [Unreleased]` (L5), insert a new section:
  ```
  ## [5.13.0] — 2026-06-10

  ### Added
  - **Flywheel pattern lifecycle (FR-015):** `reference/flywheel.md` `## Pattern lifecycle` — derived `state` (`active`/`hardened`/`archived`, only `archived` stored), derived `last_seen`, `ineffective-hardening` computed (exclusion-rule #2 negated) surfaced in an elevated regressions block, and an operator-gated end-of-piece refresh pass (Step 4.5) with two archival arms (stale-active + clean-hardened) on a piece-count `staleness_window` (default 8). Archived patterns leave the auto-match candidate set; a near-match surfaces a revive option. Atomic write + post-write verification; malformed-lifecycle / torn-write → `[FLYWHEEL-DEGRADED: lifecycle unavailable]` (non-blocking; absence of lifecycle fields derives `active`, never degraded).
  - **`staleness_window:` config key** in `templates/pipeline-config.yaml` (read from `.spec-flow.yaml`; absent/null/empty ⇒ 8; NN-C-003).
  - **`execute/SKILL.md` citations** at the match hook and batched hardening proposal pointing at the new lifecycle sections (cite-only, CR-008).
  ```
  Done: `## [5.13.0]` section present under Unreleased, Keep-a-Changelog format.
  Verify: `grep -n "## \[5.13.0\]" plugins/spec-flow/CHANGELOG.md` returns a match.

- [x] **[Verify]**
  - **[Anti-drift sweep]** Superseded version `5.12.3` must not remain in any of the four bumped files:
    - Run: `grep -rn "5.12.3" plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json` — Expected: 0 hits (no stale version in the JSON files; historical `5.12.3` in CHANGELOG is expected and untouched).
    - Run: `grep -l "5.13.0" plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/spec-flow/CHANGELOG.md` — Expected: all four files listed. **[AC-12]**
  - Run: `grep -c '"version": "5.13.0"' .claude-plugin/marketplace.json` — Expected: 1 (spec-flow entry only; the other plugin's `1.1.1` untouched). **[AC-12]**

- [x] **[QA]** ACs reviewed: AC-12. Diff baseline: phase_5_start_sha. Result: CLEAN.

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1  | Schema gains derived state + last_seen + stored archived; legacy reads as active | COVERED | Phase 1 |
| AC-2  | hardened via count-vs-at_count (rule #2), no date-ordering | COVERED | Phase 1 |
| AC-3  | ineffective-hardening computed + elevated regressions block | COVERED | Phase 2 |
| AC-4  | staleness window = distinct pieces > last_seen; staleness_window default 8; absent/null/empty ⇒ 8 | COVERED | Phase 2 |
| AC-5  | refresh pass — stale-active + clean-hardened arms, operator-gated | COVERED | Phase 2 |
| AC-6  | archived excluded from auto-match; near-match revive; stays in-file | COVERED | Phase 2 |
| AC-7  | atomic write + post-write torn-write verification | COVERED | Phase 3 |
| AC-8  | proposal renders per-pattern state + last_seen + ineffective-hardening | COVERED | Phase 2 |
| AC-9  | malformed-lifecycle (present-but-invalid only) → degraded; absence derives active | COVERED | Phase 3 |
| AC-10 | no read-time mutation of legacy registries | COVERED | Phase 2 |
| AC-11 | SSOT — execute cites lifecycle sections, restates no rule | COVERED | Phase 4 |
| AC-12 | 5.13.0 across all four version-bearing files + CHANGELOG | COVERED | Phase 5 |
| AC-13 | no-secrets extended to archival rationale + regression/revive notes | COVERED | Phase 3 |
| AC-14 | rollback — old reader ignores unknown lifecycle keys, no data loss | COVERED | Phase 1 |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1  | agent-step | read `## Registry schema` field rules in flywheel.md | state/last_seen/archived bullets; "reads as active, no migration" |
| AC-2  | shell | `grep -in "no later occurrence\|strictly later occurrence" plugins/spec-flow/reference/flywheel.md` | 0 hits (no date-ordering) |
| AC-3  | shell | `grep -in "regressions\|ineffective-hardening" plugins/spec-flow/reference/flywheel.md` | ≥2 |
| AC-4  | shell | `grep -n "staleness_window: 8" plugins/spec-flow/templates/pipeline-config.yaml` | 1 match |
| AC-5  | shell | `grep -in "stale-active\|clean-hardened" plugins/spec-flow/reference/flywheel.md` | ≥2 |
| AC-6  | shell | `grep -n "resembles archived pattern" plugins/spec-flow/reference/flywheel.md` | 1 match |
| AC-7  | shell | `grep -in "atomic\|archival not applied" plugins/spec-flow/reference/flywheel.md` | ≥2 |
| AC-8  | shell | `grep -in "renders, per listed pattern" plugins/spec-flow/reference/flywheel.md` | ≥1 |
| AC-9  | shell | `grep -c "lifecycle unavailable" plugins/spec-flow/reference/flywheel.md` | ≥1 |
| AC-10 | agent-step | read the Read-never-write invariant in `## Pattern lifecycle` | derivation = reads; only operator flips write |
| AC-11 | shell | `grep -c "reference/flywheel.md \`## Pattern lifecycle\`" plugins/spec-flow/skills/execute/SKILL.md` | ≥2 |
| AC-12 | shell | `grep -l "5.13.0" <4 version files>` | all four listed |
| AC-13 | shell | `grep -n "archival rationale\|regression/revive note" plugins/spec-flow/reference/flywheel.md` | ≥1 |
| AC-14 | agent-step | read the `state` field rule | "absence … NOT malformed"; schema-open tolerance |

## Contracts

No TDD-track phases in this plan (doc-as-code, `tdd: false`) — contracts section present for forward compatibility. tdd-red agents will not be dispatched; no contract injection occurs. The lifecycle "interfaces" are markdown schema rules and the `[FLYWHEEL-DEGRADED: lifecycle unavailable]` marker string, defined in `reference/flywheel.md` and cited by `execute/SKILL.md`; their cross-file consistency is enforced by Phase 4's cross-phase schema-consistency `[Verify]`.

## Parallel Execution Notes

**Why serial:** Phases 1–3 each edit `plugins/spec-flow/reference/flywheel.md` (same file) — serial avoids write contention; the sections are disjoint but the file is shared. Phase 4 cites the sections Phases 1–3 create (hard dependency). Phase 5 is the release bump and must land last. No Phase Group is used; the disjoint-scope phases (4 = execute, 5 = version files) are kept serial for the dependency on 1–3 and review-board readability. No `[P]` tasks.

## Testing Strategy

Doc-as-code; no executable test suite (NN-C-002 markdown/config repo). Verification is grep-inspection (the `[Verify]` recipes above) plus the spec's manual smoke walk-throughs (operator-stated expected outcomes): hardened→recur→ineffective regression surfacing (AC-3), stale-active vs clean-hardened trip at window=8 (AC-5), archive-then-recur near-match revive (AC-6), legacy-registry no-mutation read (AC-10), malformed-lifecycle vs absent-field degraded behavior (AC-9), downgrade-tolerance round-trip (AC-14). The end-of-piece Final Review board covers cross-file coherence.

## Integration Coverage

- **Refresh pass ↔ `docs/patterns.yaml` (filesystem).** Boundary: the `execute/SKILL.md` Step 4.5 orchestrator writes/reads the registry; the true external is the filesystem (unwritable / torn-write / malformed = the degraded path). Verified by AC-7 + AC-9 grep + the smoke scenarios; `review-board-integration` traces the write path.
- **Step 6c match flow ↔ archived candidate exclusion + revive.** Boundary: the match hook consults `archived` state to filter candidates. Verified by AC-6 + the archive-then-recur smoke scenario.
- **`reference/flywheel.md` (SSOT) ↔ `execute/SKILL.md` (citing caller).** Boundary: execute cites; no rule restated. Verified by AC-11 grep + the Phase 4 cross-phase schema-consistency oracle.
