---
charter_snapshot:
  non-negotiables: 2026-06-05
  architecture: 2026-06-10
  coding-rules: 2026-06-01
  processes: 2026-06-01
  tools: 2026-06-10
  flows: 2026-06-01
---

# Spec: flywheel-refresh

**PRD Sections:** FR-015, SC-003, SC-005, G-5
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** flywheel-repo (merged)

## Goal

Give the merged flywheel registry (`docs/patterns.yaml`, SSOT `plugins/spec-flow/reference/flywheel.md`) a **lifecycle**, so it stays high-signal as it ages instead of growing monotonically into noise (the documented failure mode of memory systems without expiry — PRD R4/R9/R14). A pattern gains a derived state (`active`/`hardened`/`archived`), a `last_seen`, and an outcome trail; a fix that did not actually stop recurrence comes back **loudly**; stale and verified-resolved patterns leave the active set via an operator-gated refresh pass. This is a pure doc-as-code **extend** of the existing registry — no new runtime code (NN-C-002), no new pattern-recording mechanics, maximal reuse of the schema and exclusion-rule machinery flywheel-repo already shipped. Covers FR-015.

## In Scope

- Lifecycle fields added to `reference/flywheel.md` `## Registry schema`: a **derived** `state` (`active`/`hardened`/`archived`), a **derived** `last_seen`, and a single **stored** operator-set `archived` marker.
- `active`↔`hardened` derivation defined via the **same** `count`-vs-`at_count` arithmetic as the existing exclusion-rule #2 (single-sourced, no independent date-ordering formulation).
- `ineffective-hardening` as a **computed** condition (exclusion-rule #2 read in the negative), surfaced in a **distinct, elevated "regressions" block** at the batched review.
- An operator-gated **refresh pass** at end-of-piece Step 4.5 (adjacent to the existing batched hardening proposal) with two archival arms — stale-active and clean-hardened — using a **piece-count** staleness window.
- A `staleness_window` config key (default `8`, read from `.spec-flow.yaml`, documented in tracked `templates/pipeline-config.yaml`).
- Archived patterns leave the auto-match candidate set; a near-match to an archived pattern surfaces a **revive** option at Step 6c; revive folds into the same Step 4.5 prompt.
- **Atomic** registry write (temp + rename) with post-write verification for torn-write safety.
- In-proposal rendering of each pattern's derived lifecycle state + `last_seen` + ineffective-hardening status.
- Degraded-path extension: a **present-but-malformed** lifecycle value → `[FLYWHEEL-DEGRADED: lifecycle unavailable]`.
- No-secrets guard extended to the new free-text surfaces (archival rationale, regression/revive notes).
- MINOR version bump → `5.13.0` across all four version-bearing files + CHANGELOG.

## Out of Scope / Non-Goals

- **FW-2 registry-integrity lint** (a `flywheel-lint` step / standalone `## Registry invariants` recipe for schema-valid-but-structurally-wrong registries) — deferred to `flywheel-global` / `flywheel-enhancements`. The lifecycle degraded check reuses the existing parse/write fault logic plus a thin present-but-invalid-value check; it needs no standalone lint.
- **AB-2 budget-threshold-drift** (`metric`-source pattern when an aggregate report's p75 diverges) — downstream of `metrics` aggregate reporting, not lifecycle.
- **On-demand refresh skill / `commands/` entry** — AC-3's "end-of-piece OR on demand" disjunction is satisfied by the end-of-piece trigger; revive is reachable in the same per-piece prompt.
- **`/spec-flow:status` lifecycle rendering** — owned by the `metrics` piece (SC-007). This piece renders state only in the Step 4.5 proposal.
- **N-days / both staleness-window units** — `N pieces` chosen (see Technical Approach). The other units are not built.
- **Machine-global (`~/`) registry lifecycle** — `flywheel-global` reuses these mechanics; this piece touches only the repo registry.

## Requirements

### Functional Requirements

- **SF-1 (Lifecycle schema fields — derived state + stored archived):** `reference/flywheel.md` `## Registry schema` gains a `state` field with values `active | hardened | archived`, a `last_seen` field, and an operator-set `archived` marker. `state` and `last_seen` are **derived at read time** (not stored); `archived` is the **only** stored lifecycle bit (archival is a genuine operator decision with no data antecedent — NN-P-004). A registry written before this piece (no lifecycle fields) reads as `active` with no migration (NN-C-003).
- **SF-2 (Derived `hardened` state, single-sourced to exclusion-rule #2):** A pattern is `hardened` iff its latest `outcome: resolved` hardening has `at_count ≥ count` (the pattern is currently resolved-suppressed); otherwise `active`. This is the **same** count-vs-`at_count` arithmetic as `## Threshold + batched proposal` exclusion-rule #2; `## Registry schema` cross-references that rule as the single definition. There is **no** independent date-ordering ("no later occurrence") formulation — count is distinct-piece-based, so a genuine new-piece recurrence pushes `count > at_count` and derives `active` regardless of same-day occurrence dates.
- **SF-3 (`ineffective-hardening` computed + elevated surfacing):** `ineffective-hardening` is exclusion-rule #2 read in the negative — a pattern with a `resolved` hardening whose `count` has since exceeded that hardening's `at_count`. It is a **computed condition + label**, not a stored flag. At the batched review it is surfaced in a **distinct, elevated "regressions" block** (not a peer proposal row), honoring FR-015's "elevated priority".
- **SF-4 (Piece-count staleness window):** Staleness is measured in **pieces**: `pieces_since_last_seen` = the count of **distinct `piece` values across all patterns' `occurrences`** whose occurrence `date` is after this pattern's `last_seen` (flywheel-active-piece cadence; fully registry-internal — no manifest cross-read, no invented global ordinal). The window is `staleness_window` (default `8`), read from `.spec-flow.yaml`; documented with a CR-007 inline comment in tracked `templates/pipeline-config.yaml`, mirroring `flywheel_threshold`. An **absent** key, a **present-but-null**, and a **present-but-empty** value all resolve to the default `8` (a null MUST NOT be read as `0`).
- **SF-5 (Refresh pass — two operator-gated archival arms at Step 4.5):** At end-of-piece Step 4.5, after the existing batched hardening proposal, a refresh pass surfaces **one** operator-gated batched archival proposal listing: (a) **stale-active** — derived `state: active` with `pieces_since_last_seen ≥ staleness_window`; and (b) **clean-hardened** — derived `state: hardened` with `pieces_since_last_seen ≥ staleness_window`. Both arms use the **single** `pieces_since_last_seen` clock of SF-4 (measured from derived `last_seen`); they differ only by derived state, not by clock. For a clean-hardened pattern, `last_seen` is the threshold-tripping occurrence whose date coincides with the hardening's own Step 4.5 — so this one clock is an exact proxy for "no recurrence since the hardening" and no separate hardening-date clock is needed. Nothing archives until the operator confirms (NN-P-004). An ineffective hardening (a recurrence appended a new occurrence, so `count > at_count` ⇒ the pattern derives `active` and the new occurrence advances derived `last_seen`) is excluded from both arms and instead appears in the SF-3 regressions block.
- **SF-6 (Archived exclusion + revive, history-preserving):** An `archived` pattern is excluded from the **auto**-match candidate set at the Step 6c match flow. When a Step 6c finding **near-matches** an archived pattern, the flywheel surfaces a revive option (`resembles archived pattern <id> — revive or mint new?`) so historical correlation is not silently lost. Revive (clearing `archived`) is offered in the same Step 4.5 refresh prompt; an archived pattern stays in-file for audit (it is never deleted).
- **SF-7 (Atomic write + post-write verification):** Any refresh write to `docs/patterns.yaml` (archival flip, revive flip) is **atomic** (write-to-temp + rename; all-or-nothing). After the write the orchestrator re-reads the file; if the write did not fully land, it emits `[FLYWHEEL-DEGRADED: lifecycle unavailable]` with an explicit `archival not applied` notice. (The pre-flight degraded gate covers torn **reads**; this covers torn **writes**.)
- **SF-8 (In-proposal lifecycle rendering):** The Step 4.5 batched/refresh proposal renders, per listed pattern, its derived `state`, `last_seen`, and ineffective-hardening status, so the operator can see the registry self-curating at the gate where they act.
- **SF-9 (Degraded path extension — malformed lifecycle):** `## Degraded path` gains a trigger: a **present-but-invalid** lifecycle value (e.g. an `archived` marker that is not the sanctioned form, or an otherwise malformed lifecycle field) → `[FLYWHEEL-DEGRADED: lifecycle unavailable]`, propose nothing, leave the file untouched, recording continues per FR-006. **Absence** of lifecycle fields is NOT malformed — it derives `active` and MUST NOT trip the marker.
- **SF-10 (SSOT + version sync):** All lifecycle schema, derivation rules, window mechanics, refresh flow, and degraded extension are defined in `reference/flywheel.md` and nowhere else; `execute/SKILL.md` only **cites** them (no restated rules — CR-008 / NN-C-008). The piece is a MINOR bump → `5.13.0` across all four version-bearing files (`plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, root `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`).
- **SF-11 (No-secrets extension):** `## No secrets` is extended to cover the new free-text surfaces — archival rationale and regression/revive notes — so credentials or tokens are never transcribed verbatim into lifecycle records.

### Non-Functional Requirements

- **SF-N1 (Non-blocking):** The refresh pass never affects the execute result. A registry that is unwritable, unparseable, malformed-lifecycle, or torn-on-write degrades to a no-op marker; execute is never blocked or failed (NN-C-005).
- **SF-N2 (Backward-compatible, additive, reversible):** All changes are additive within the current major version (NN-C-003). Reading a legacy registry mutates nothing. Rollback is non-breaking: an older reader ignores the unknown `archived`/lifecycle keys (worst case re-proposes an archived pattern — degraded experience, not data loss).
- **SF-N3 (No new runtime surface, deterministic):** Pure doc-as-code (markdown + YAML config + orchestrator prose). The archival/derivation logic is deterministic mechanics — no Opus, no new agent, no new skill, no `scripts/` (NN-P-005, CR-008).

### Non-Negotiables Honored

- **NN-C-002 (markdown + config only):** No runtime code, no dependencies, no `scripts/`; lifecycle is schema + orchestrator prose + one config key.
- **NN-C-003 (backward compat within major):** Lifecycle fields are additive and optional; legacy registries derive `active`; `staleness_window` absent/null/empty ⇒ default `8`; rollback non-breaking (SF-1, SF-4, SF-9, SF-N2).
- **NN-C-005 (degraded no-op):** Malformed-lifecycle and torn-write degrade to a non-blocking marker (SF-7, SF-9, SF-N1).
- **NN-C-008 (self-contained / SSOT):** All rules live in `reference/flywheel.md`; execute cites, never restates (SF-10).
- **NN-C-009 / NN-C-001 (version + marketplace sync):** MINOR bump to `5.13.0` across all four version-bearing files in one commit series (SF-10).
- **NN-P-004 (flywheel writes operator-gated):** Archival, revive, and every lifecycle write occur only on operator confirmation; nothing archives or revives silently; derivation reads never write (SF-1, SF-5, SF-6).
- **NN-P-005 (Opus thinking / Sonnet mechanics):** Refresh is deterministic mechanics — no Opus upgrade; reuses the existing spike path only for the (pre-existing) hardening dispatch, unchanged (SF-N3).

### Coding Rules Honored

- **CR-007 (config keys documented inline):** `staleness_window` carries an inline comment in tracked `templates/pipeline-config.yaml`, mirroring `flywheel_threshold` (SF-4).
- **CR-008 (thin orchestrator / separation of concerns):** Mechanics defined once in the reference SSOT; `execute/SKILL.md` is a thin citing caller (SF-10).
- **CR-009 (heading hierarchy):** New `reference/flywheel.md` content slots into the existing `##`/`###` structure (folded into `## Registry schema`, `## Threshold + batched proposal`, `## Degraded path`, `## No secrets`).

## Acceptance Criteria

AC-1: Given `reference/flywheel.md` after this piece, When a reviewer inspects `## Registry schema`, Then it defines a derived `state` (`active | hardened | archived`), a derived `last_seen`, and a stored operator-set `archived` marker; and it states that a registry with no lifecycle fields reads as `active` with no migration. **[SF-1]**

AC-2: Given the `state` definition, Then `hardened` is defined as "latest `outcome: resolved` hardening with `at_count ≥ count`" and cross-references `## Threshold + batched proposal` exclusion-rule #2 as the single definition; and no independent date-ordering ("later occurrence") formulation of `state` appears anywhere in the file. **[SF-2]**

AC-3: Given a `hardened` pattern whose `count` later exceeds the hardening's `at_count`, Then `reference/flywheel.md` defines `ineffective-hardening` as that computed condition (rule #2 negated, no stored flag) and specifies it is surfaced in a distinct, elevated "regressions" block at the batched review, separate from peer archival/hardening proposal rows. **[SF-3]**

AC-4: Given the staleness mechanics, Then the window unit is distinct pieces with occurrence `date > last_seen`; the key is `staleness_window` (default `8`) read from `.spec-flow.yaml` and documented with an inline comment in tracked `templates/pipeline-config.yaml`; and an absent key, a present-but-null value, and a present-but-empty value ALL resolve to `8` (null is never read as `0`). **[SF-4]**

AC-5: Given the Step 4.5 refresh pass, Then it surfaces one operator-gated batched archival proposal covering both arms — stale-active (`state: active`, `pieces_since_last_seen ≥ staleness_window`) and clean-hardened (`state: hardened`, `pieces_since_last_seen ≥ staleness_window`) — and nothing is archived until the operator confirms (NN-P-004). **[SF-5]**

AC-6: Given an `archived` pattern, Then `reference/flywheel.md` specifies it is excluded from the auto-match candidate set at Step 6c, that a near-match to an archived pattern surfaces a revive option (`revive or mint new?`), that revive (clearing `archived`) is offered in the Step 4.5 prompt, and that archived entries remain in-file for audit. **[SF-6]**

AC-7: Given a refresh write to `docs/patterns.yaml`, Then `reference/flywheel.md` specifies the write is atomic (temp + rename) and that a post-write re-read failing to confirm the write emits `[FLYWHEEL-DEGRADED: lifecycle unavailable]` with an `archival not applied` notice. **[SF-7]**

AC-8: Given the Step 4.5 proposal prose (in `reference/flywheel.md`, cited by `execute/SKILL.md`), Then it renders per listed pattern the derived `state`, `last_seen`, and ineffective-hardening status. **[SF-8]**

AC-9: Given `## Degraded path`, Then a present-but-invalid lifecycle value triggers `[FLYWHEEL-DEGRADED: lifecycle unavailable]` (propose nothing, file untouched); and the section explicitly states that ABSENCE of lifecycle fields derives `active` and does NOT trip the marker. **[SF-9, backward-compat (a)]**

AC-10: Given a legacy registry (no lifecycle fields), When any new path (refresh, match-exclusion, batched proposal, degraded check) reads it, Then no write or migration occurs — the file is byte-unchanged absent an explicit operator-confirmed archival/revive. **[SF-1, SF-N2, NN-P-004]**

AC-11: Given the shipped piece, Then `reference/flywheel.md` is the sole definition of the lifecycle schema/rules and `execute/SKILL.md` contains only citations to it (no restated lifecycle rules — grep confirms cite-markers, not rule prose). **[SF-10, CR-008]**

AC-12: Given the piece ships, Then `5.13.0` appears in all four version-bearing files (`plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, root `.claude-plugin/marketplace.json`, `plugins/spec-flow/CHANGELOG.md`) and the CHANGELOG has a matching entry. **[SF-10, NN-C-009/NN-C-001]**

AC-13: Given `## No secrets`, Then it names the new lifecycle free-text surfaces (archival rationale, regression/revive notes) as subject to the no-verbatim-credentials rule. **[SF-11]**

AC-14: Given a user adds `archived` entries then downgrades to a pre-flywheel-refresh plugin, Then the older reader ignores the unknown lifecycle keys without a parse error (schema-open) and at worst re-proposes the archived pattern — no data loss. **[SF-N2, backward-compat (d)]**

## Technical Approach

1. **Schema (`## Registry schema`).** Add field rules: `state` (`active|hardened|archived`, derived except the stored `archived` marker), `last_seen` (`= max(occurrences[].date)`, derived). `archived` is the lone stored bit. State the "legacy ⇒ active, no migration" rule beside the existing `originating_repo` reserved-field note.
2. **Single-sourced `hardened` (`## Threshold + batched proposal`).** Define `hardened` / `ineffective-hardening` in terms of exclusion-rule #2's `count`/`at_count` (evaluated against the highest `at_count`, reusing the existing "most-recent suppression point" rule). The schema section cross-references this; it carries no second formula. This is the convergence move that dissolves the same-day-date ambiguity (count is distinct-piece-based).
3. **Staleness + refresh (`## Threshold + batched proposal` / a new lifecycle subsection).** Define `pieces_since_last_seen` = distinct registry pieces with occurrence `date > last_seen`. The refresh pass runs at end-of-piece Step 4.5 after the hardening proposal; the two archival arms gate on derived state + the piece-count window; both are batched into one operator-gated prompt that also lists revivable archived patterns and renders per-pattern lifecycle state, with ineffective-hardenings in the elevated regressions block.
4. **Config.** Add `staleness_window` to `templates/pipeline-config.yaml` (CR-007 comment); read from `.spec-flow.yaml`; absent/null/empty ⇒ `8`.
5. **Match exclusion + revive (`## Match + confirm flow`).** Archived patterns leave the auto-candidate set; a near-match surfaces the revive option.
6. **Write safety + degraded (`## Degraded path`).** Atomic temp+rename write; post-write verify; present-but-invalid-lifecycle trigger; explicit absence≠malformed clause.
7. **Execute wiring (`execute/SKILL.md`).** Extend the `#### Flywheel batched hardening proposal` region (~L1913) and the `#### Flywheel pattern recording` match site (~L1079) with **citations** to the new `reference/flywheel.md` sections — no restated rules.
8. **Version + CHANGELOG.** Bump all four files to `5.13.0`; add the Keep-a-Changelog entry.

## Testing Strategy

This is doc-as-code; verification is inspection (grep) + manual smoke walk-throughs (operator-stated expected outcomes), mirroring flywheel-repo.

- **Inspection-verifiable (grep recipes):** schema lifecycle fields (AC-1), single-sourced `hardened` + no date-ordering (AC-2), ineffective-hardening regressions block (AC-3), `staleness_window` enum + default + null-safety doc (AC-4), both archival arms (AC-5), archived exclusion + revive prose (AC-6), atomic-write + torn-write degraded (AC-7), per-pattern rendering prose (AC-8), present-but-invalid trigger + absence-not-malformed clause (AC-9), SSOT/cite-only in execute (AC-11), four-file version sync (AC-12), no-secrets extension (AC-13).
- **Manual smoke scenarios (operator walk-through, expected outcome stated):** hardened→recur→ineffective regression surfacing (AC-3), stale-active vs clean-hardened archival trip at window=8 (AC-5), archive-then-recur near-match revive prompt (AC-6), legacy-registry no-mutation read (AC-10), malformed-lifecycle vs absent-field degraded behavior (AC-9), downgrade-tolerance round-trip (AC-14).

## Integration Coverage

- **Refresh pass ↔ `docs/patterns.yaml` (the registry file).** Boundary: the `execute/SKILL.md` Step 4.5 orchestrator (inside) writes/reads the registry file; the true external is the filesystem (unwritable/torn-write/malformed = the degraded path). Verified by the AC-7 (atomic/torn-write) and AC-9 (malformed) smoke scenarios; `review-board-integration` traces the write path. AC-5, AC-7, AC-9.
- **Step 6c match flow ↔ archived candidate exclusion + revive.** Boundary: the `#### Flywheel pattern recording` match site (inside) consults the registry's `archived` state to filter candidates and surface revive. Verified by the AC-6 smoke scenario (archive-then-recur near-match). AC-6.
- **`reference/flywheel.md` (SSOT) ↔ `execute/SKILL.md` (citing caller).** Boundary: execute cites the lifecycle sections; no rule is restated. Verified by AC-11's grep (cite-markers present, rule prose absent). AC-11.

## Explicitly Out of Scope / Deferred

- **FW-2 — registry-integrity lint** (`flywheel-lint` / `## Registry invariants`): stays `deferred`; owner `flywheel-global` / `flywheel-enhancements`. The lifecycle degraded check reuses existing fault logic plus a thin present-but-invalid check; no standalone lint is required by FR-015.
- **AB-2 — budget-threshold-drift `metric` pattern:** stays `deferred`; downstream of `metrics` aggregate reporting, not lifecycle.
- **On-demand refresh skill / `/spec-flow:status` lifecycle rendering / N-days window unit:** out of scope per the resolved VOQs (end-of-piece trigger + proposal-only visibility + N-pieces unit).
