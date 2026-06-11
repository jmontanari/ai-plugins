# Deliberation — flywheel-refresh (PRD exec-ready)

## Investigation Summary

**Resolved depth: `full`.** This piece adds a lifecycle layer (active / hardened / archived / ineffective-hardening) over the merged flywheel registry so the pattern set self-refreshes instead of accreting stale rows. The investigation evaluated four decision clusters: lifecycle schema & state model, refresh mechanics & trigger placement, candidate-set / revive behavior at match time, and degraded-path / backward-compat surface.

The shape that emerged is **pure doc-as-code with read-time derivation**: lifecycle state is computed from data the registry already carries (occurrences, hardening resolutions, dates), not stored — with the single exception of `archived`, which is an operator-set marker. The refresh fires automatically at end-of-piece **Step 4.5**, adjacent to the existing batched hardening proposal (`execute/SKILL.md` ~L1913); there is no new on-demand skill. SSOT for the spec is `reference/flywheel.md`; the registry lives at `docs/patterns.yaml`.

The decisive finding from adversarial review: an early date-ordering formulation of `active↔hardened` collided with the existing count-arithmetic hardening rule and broke on same-day completions — which are the **common** case in this repo (38 merges on a single day). Convergence dissolved this by collapsing the derivation onto the existing count-vs-`at_count` predicate (one rule, defined once). Two genuine operator decisions survived unresolved and are recorded as VOQ-1 (staleness-window units + default) and VOQ-2 (visibility scope).

## Viability Analysis

### Cluster A — Lifecycle schema & state model

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Read-time derivation; only `archived` stored | VIABLE (winner) | `active↔hardened`, `last_seen`, `ineffective-hardening` are all computable from existing registry data; no read-time mutation of legacy registries; honors NN-C-003 / NN-P-004 | Yes — folds `state`-enum + `last_seen`-format into existing `## Registry schema` | — |
| Fully stored lifecycle state (write on every read) | NON-VIABLE | Read-time mutation of `docs/patterns.yaml` would rewrite legacy registries on first read, violating NN-C-003 (no silent schema migration) and NN-P-004 | Partial | Read-time write contradicts the no-mutation non-negotiable |
| Derive everything incl. `archived` (no stored marker) | NON-VIABLE | Archival is an intentional operator act with no purely-derivable trigger that matches AC-4's explicit-revive semantics | Yes | No data field can encode operator intent to archive; would mis-derive |

### Cluster B — Refresh mechanics & trigger placement

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Auto-fire at Step 4.5, batched operator-gated proposal | VIABLE (winner) | Reuses existing batched hardening-proposal seam; revive folds into the same prompt; satisfies AC-3 disjunction at end-of-piece | Yes — extends `execute/SKILL.md` ~L1913 prompt | — |
| New on-demand `/spec-flow:flywheel-refresh` skill | NON-VIABLE | AC-3 disjunction is already satisfied by the end-of-piece trigger; a standalone skill adds a surface with no AC requiring it (scope/simplicity HOLDS confirms the drop) | No | No AC mandates on-demand invocation; pure scope creep |
| Wall-clock `now` for staleness | NON-VIABLE | Non-deterministic across replays / CI; breaks reproducibility | No | `now` must be the piece's recorded ISO date at Step 4.5, not wall-clock |

### Cluster C — Candidate-set & revive behavior

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Archived excluded from auto-candidates; near-match surfaces revive option | VIABLE (winner) | Keeps archived patterns out of noise while preserving history correlation; consistent with AC-4 "unless the operator explicitly revives" | Yes — extends Step 6c match | — |
| Archived hard-excluded, no revive surfacing | NON-VIABLE | A recurrence silently mints a "new" pattern, orphaning history (risk R3) — defeats the anti-rot intent | Partial | Silent history loss on archive-then-recur |

### Cluster D — Degraded path & backward-compat surface

| Path | Verdict | Reasoning | Reuse? | Blocker |
|------|---------|-----------|--------|---------|
| Extend existing `## Degraded path`; PRESENT-but-invalid triggers degraded; atomic write + post-write verify | VIABLE (winner) | Reuses existing degraded machinery; covers both torn-read and torn-write; ABSENCE derives `active` (no false degrade on legacy files) | Yes — extends `## Degraded path` | — |
| New `## Invariants` section + lint | NON-VIABLE | No AC requires a lint/invariants surface; FW-2 (invariant enforcement) is explicitly out of scope, deferred to flywheel-global | No | Out-of-scope feature; no AC support |

## Integration Check

Cross-cluster composition is **clean**. The four winning paths compose without conflict: A's read-time derivation feeds C's match-time candidate filtering (archived excluded, near-match surfaced), B's Step 4.5 trigger is the single place all of it renders, and D's degraded path wraps both the read and the write of A's data.

**One cross-cluster seam was tightened during synthesis (the "B2-surface" resolution):** B (refresh trigger) and the user-intent requirement that derived state be *visible* were initially under-coupled — the refresh could fire without the operator ever seeing what state each pattern was in. Resolution: the Step 4.5 batched/refresh proposal MUST render, per pattern, its derived lifecycle state + `last_seen` + any ineffective-hardening label. This makes B the single rendering surface for A's derivations, closing the seam. Whether that visibility *also* extends to the read-only `/spec-flow:status` dashboard is left open as VOQ-2 (it touches SC-007, owned by the separate `metrics` piece).

No unresolvable cross-cluster conflicts remain.

## Adversarial Review

Five lenses ran in Phase D: 2 HOLDS, 3 CONTESTED. All CONTESTED challenges were resolved by recommendation revision (folded below); none survive as open questions.

### architecture-integrity — CONTESTED → resolved

**Challenged:** `active↔hardened` was phrased as date-ordering ("no later occurrence"), but the existing exclusion-rule #2 is count-arithmetic (`count ≤ at_count`). Two prose copies of an overlapping rule can disagree — a new occurrence dated ≤ the hardening date increments count (rule #2 re-includes) while date-ordering still calls it hardened.
**Resolution (folded):** `hardened` is defined via the SAME count-vs-`at_count` arithmetic — a pattern is `hardened` iff the latest resolved hardening's `at_count ≥ count` (i.e. currently resolved-suppressed), else `active`. `## Registry schema` cross-references `## Threshold` rule #2 as the single definition; no independent date-ordering formulation exists. `active↔hardened`, `ineffective-hardening` (rule #2 negated), and exclusion-rule #2 are now ONE predicate defined once.

### risk — CONTESTED → resolved

**Challenged (R1, decisive — same root as architecture):** same-day occurrence-after-hardening mis-derives as `hardened` under date-ordering; with 38 merges on 2026-06-09, same-day multi-piece completion is the common case.
**Resolution (folded):** dissolved by the count-arithmetic fix above. Count is distinct-piece-based, so a genuine new-piece recurrence increments `count > at_count` → derives `active` regardless of date granularity. (Recorded in §Answered by Investigation.)
**Challenged (R3):** archive-then-recur silently loses correlation — a recurrence of an archived pattern is excluded and mints a "new" pattern, orphaning history.
**Resolution (folded):** at Step 6c, archived patterns are excluded from the AUTO-candidate set, but a near-match to an archived pattern SURFACES a revive option to the operator ("resembles archived pattern P — revive or mint new?"), consistent with AC-4.
**Challenged (R4):** post-confirm write failure (mid-write ENOSPC / permission flip) is uncovered by the pre-flight degraded gate → torn registry, flywheel silently disabled.
**Resolution (folded):** atomic write (temp + rename, all-or-nothing) plus a post-write verification that re-emits `[FLYWHEEL-DEGRADED]` with an explicit "archival not applied" notice if the write did not fully land. "File untouched" on malformed-read does NOT cover "file half-touched on write."

### user-intent — CONTESTED → partially resolved (2 folded, 2 surfaced as VOQ)

**Challenged (gap 1):** a 180-day date-span window means archival NEVER fires at this operator's demonstrated velocity (40 commits / 2 days) — defeating the anti-rot intent. The PRD's own open question ("window — N pieces, N days, or both?") is genuinely unresolved.
**Resolution:** this is a real operator decision, not a deliberation call → **VOQ-1**.
**Challenged (gap 2):** ineffective-hardening as a peer label is buried, contradicting FR-015's "elevated priority" / "come back loudly" intent.
**Resolution (folded):** surface ineffective-hardening patterns in a DISTINCT, elevated block (a separate "regressions" callout) at the batched review, not a peer row.
**Challenged (gap 3):** derived lifecycle state is invisible.
**Resolution (folded):** the Step 4.5 proposal MUST render each pattern's derived state + `last_seen` + ineffective-hardening label. Whether to ALSO render in `/spec-flow:status` → **VOQ-2**.

### scope/simplicity — HOLDS (soft flag)

The literal `180` and the days-vs-pieces resolution need recorded spec-time justification — this rolls into VOQ-1. Confirmed: both archival arms (stale-active + clean-hardened) are genuinely required (different reference clocks). On-demand correctly dropped (AC-3 disjunction satisfied by end-of-piece).

### backward-compat — HOLDS (must-carry ACs)

The four must-carry constraints (a)–(d) are recorded in §Answered by Investigation as resolved design constraints the spec MUST encode as falsifiable ACs.

## Recommendation

**Read-time-derivation lifecycle over the merged flywheel registry** (`docs/patterns.yaml`, SSOT `reference/flywheel.md`). Pure doc-as-code, no new runtime surface. Revised from the Phase C anchor with all Phase D folds.

**Schema / state.**
- `archived` is STORED (operator-set marker). `active`↔`hardened` is DERIVED.
- `hardened` iff the latest resolved hardening's `at_count ≥ count` (pattern currently resolved-suppressed); else `active`. This uses the SAME count-vs-`at_count` arithmetic as existing exclusion-rule #2. `## Registry schema` cross-references `## Threshold` rule #2 as the single definition — there is NO independent date-ordering formulation.
- `ineffective-hardening` = exclusion-rule #2 read in the negative (a hardened pattern whose `count` has since exceeded `at_count`) + label.
- `last_seen = max(occurrences[].date)`, derived.

**Refresh mechanics.**
- Staleness window uses a date span where `now` = the current piece's recorded ISO date at Step 4.5 (NOT wall-clock). Default `staleness_window: 180`, read from `.spec-flow.yaml`, documented in tracked `templates/pipeline-config.yaml`. (Window UNITS + default value are VOQ-1 — see below; `180` days is a placeholder pending that decision.)
- Refresh fires automatically at end-of-piece Step 4.5, adjacent to the existing batched hardening proposal (`execute/SKILL.md` ~L1913).
- Archival is a batched, operator-gated proposal. Revive folds into the same Step 4.5 prompt. NO on-demand skill.
- Both archival arms are retained: stale-active (no occurrence within the window) and clean-hardened (hardened with no recurrence within the window) — they reference different clocks and are both required.

**Match-time / revive (folded R3).** Archived patterns leave the AUTO-candidate set at Step 6c. A near-match to an archived pattern SURFACES a revive option to the operator ("resembles archived pattern P — revive or mint new?"), consistent with AC-4's "unless the operator explicitly revives." History correlation is preserved.

**Write safety (folded R4).** The registry write is atomic (temp + rename, all-or-nothing). A post-write verification re-reads the file and, if the write did not fully land, re-emits `[FLYWHEEL-DEGRADED]` with an explicit "archival not applied" notice. The pre-flight degraded gate covers torn READS; this covers torn WRITES.

**Visibility / surfacing (folded user-intent gaps 2 & 3).** The Step 4.5 batched/refresh proposal MUST render, per pattern, its derived lifecycle state + `last_seen` + ineffective-hardening status. Ineffective-hardening patterns appear in a DISTINCT, elevated "regressions" block (not a peer row), traceable to FR-015's "elevated priority."

**Scope.** C-exclude. Fold `state`-enum + `last_seen`-format field rules into the existing `## Registry schema`. Extend the existing `## Degraded path` for malformed-lifecycle → `[FLYWHEEL-DEGRADED: lifecycle unavailable]`. NO invariants section, NO lint. FW-2 deferred to flywheel-global.

**Backward-compat ACs to encode (from §Answered by Investigation (a)–(d)).** malformed-lifecycle trigger = PRESENT-but-invalid ONLY; `staleness_window` absent/null/empty ⇒ default; MINOR version bump → target 5.13.0 across all four version-bearing files; rollback is non-breaking (schema-open keys).

## Validated Open Questions

**VOQ-1 — Staleness-window units and default value.** Should the window be N pieces, N days, or both, and what is the default? The PRD left this open and the days-only / `180` resolution is likely wrong for this operator. Evidence: demonstrated velocity is ~40 commits / 2 days, at which a 180-day span means archival NEVER fires — defeating the anti-rot intent. Architecture constraint to weigh: no global piece ordinal exists, so a piece-count window needs a derivable source (e.g. count of distinct pieces whose `merged_at` / occurrence date > `last_seen`). This is a genuine operator decision (also carries scope/simplicity's soft flag: the chosen value needs recorded spec-time justification).

**VOQ-2 — Visibility scope of derived lifecycle state.** Render derived lifecycle state (state + `last_seen` + ineffective-hardening) ONLY in the Step 4.5 refresh / batched proposal, or ALSO in the read-only `/spec-flow:status` dashboard? The in-proposal rendering is settled (folded). The `/spec-flow:status` extension touches SC-007, which is owned by the separate `metrics` piece — hence a scope boundary the operator must set, not a deliberation call.

## Answered by Investigation

- **Same-date `active`/`hardened` ambiguity (risk R1) — RESOLVED.** Dissolved by defining `hardened` via count-vs-`at_count` arithmetic instead of date-ordering. Count is distinct-piece-based, so a genuine new-piece recurrence increments `count > at_count` → derives `active` regardless of same-day date granularity. This was the decisive convergence move; it also collapses architecture-integrity's "two overlapping rules" finding (one predicate, defined once).
- **Archive-then-recur history loss (risk R3) — RESOLVED.** Near-match-to-archived surfaces a revive option at Step 6c; history correlation preserved (folded).
- **Torn-write on post-confirm failure (risk R4) — RESOLVED.** Atomic write + post-write verification re-emitting `[FLYWHEEL-DEGRADED]` (folded).
- **On-demand refresh skill — RESOLVED (dropped).** AC-3 disjunction is satisfied by the end-of-piece trigger; no AC mandates on-demand. Scope/simplicity HOLDS confirms.
- **Both archival arms required — RESOLVED.** Stale-active and clean-hardened reference different reference clocks; both retained, not collapsible.
- **Backward-compat constraint (a) — RESOLVED (must encode as AC).** malformed-lifecycle trigger = PRESENT-but-invalid value ONLY. ABSENCE of lifecycle fields derives `active` and MUST NOT trip `[FLYWHEEL-DEGRADED: lifecycle unavailable]`. No read-time mutation of legacy registries (NN-C-003 + NN-P-004).
- **Backward-compat constraint (b) — RESOLVED (must encode as AC).** `staleness_window` absent ⇒ default AND present-but-null/empty ⇒ default. A null MUST NOT be read as 0 / archive-everything.
- **Backward-compat constraint (c) — RESOLVED (must encode as plan task).** Version bump is MINOR per NN-C-003 / NN-C-009 → target 5.13.0 (current 5.12.3). spec-flow has FOUR version-bearing files (plugin.json Copilot descriptor, `.claude-plugin/plugin.json`, root `marketplace.json`, `CHANGELOG.md`) per `docs/releasing.md`; the plan MUST bump all four.
- **Backward-compat constraint (d) — RESOLVED.** Rollback is non-breaking: archived / lifecycle fields are schema-open, so an old reader ignores unknown keys (no break). Worst case it re-proposes an archived pattern (degraded experience, not data loss).
- **FW-2 (invariant enforcement / lint) — N/A.** Explicitly out of scope for this piece; deferred to flywheel-global. No invariants section, no lint here.
