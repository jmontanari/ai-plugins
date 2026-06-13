# Flywheel — registry schema, match/confirm flow, count rule, threshold, hardening dispatch, degraded marker

Single source of truth for the repo-level self-hardening flywheel (FR-006) — the `docs/patterns.yaml` schema, stable-ID scheme, match/confirm flow, count/threshold/batched-routing mechanics, the hardening dispatch, and the `[FLYWHEEL-DEGRADED]` marker. Cited by `plugins/spec-flow/skills/execute/SKILL.md` (Step 6c record/match hook + Step 4.5 batched proposal). Reused by the `flywheel-global` piece (FR-007). Definitions live here and nowhere else.

## Registry schema

The `docs/patterns.yaml` registry is created lazily on the first confirmed occurrence (the piece does not ship the file). Its canonical illustrative form:

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
    hardenings: []                      # each: { date, outcome (resolved|blocked), spike_artifact, amend_commit, at_count }
      # state: derived (active|hardened|archived); last_seen: derived = max(occurrences[].date); archived: stored marker, operator-set only
```

**Field rules:**

- `id` — a stable kebab slug; LLM-proposed at the moment of the "new" classification, operator-confirmed or renamed; never reassigned once stored.
- `scope` — one of `charter | qa | prd`; the flywheel-global piece (FR-007) adds `plugin` without restructuring. Routes the hardening proposal to its home: `charter` → charter amendment, `qa` → local QA hardening, `prd` → PRD work.
- `occurrences` — a list of occurrence records; each carries `{piece, date, source, source_type}`. Because recording is deduped per piece (see `## Count rule`), the list holds at most one entry per piece.
  - `source_type` — one of `reflection-finding | execute-discovery | metric | campaign`. All four are wired: `metric` occurrences cite a measured `metrics.yaml` trend, written via the operator-confirm flow (FR-010). See `## Source taxonomy`.
  - `originating_repo` — RESERVED for the flywheel-global piece (FR-007); no path in this piece writes it.
- `rejections` — a list of rejection records; each carries `{date, rationale, rejected_at_count}`. See `## Rejection rule`.
- `hardenings` — a list of hardening-outcome records; each carries `{date, outcome: resolved|blocked, spike_artifact: <path or — for blocked>, amend_commit: <sha, resolved only>, at_count: <distinct-piece count at the time of the hardening>}`. This is the schema home for both accepted-outcome (resolved) and proposed-but-unresolved (blocked) hardening records — symmetric with `rejections`. See `## Hardening dispatch (reuse)`.
- `state` — DERIVED, never stored except `archived`. Values `active | hardened | archived`. If the stored `archived` marker is present, `state = archived` (takes precedence over hardening status); the `hardened`/`active` derivation applies only when `archived` is absent. `hardened` (when `archived` absent) iff the pattern is currently resolved-suppressed per `## Threshold + batched proposal` exclusion-rule #2 — the `at_count ≥ count` check applies to the highest resolved `at_count`; that rule is the single definition; there is no separate "latest hardening" or date-ordering formulation. Otherwise `active`. `archived` is the lone STORED lifecycle marker (operator-set; archival is an operator decision with no data antecedent — NN-P-004). A registry with no lifecycle fields reads as `active` with no migration (NN-C-003); absence of lifecycle fields is NOT malformed (see `## Degraded path`).
- `last_seen` — DERIVED `= max(occurrences[].date)`. No stored field.
- `archived` — optional stored marker; present only on operator-confirmed archival. **Sanctioned form: `archived: true` (boolean).** Any other value type — string, date, integer — is invalid and triggers the lifecycle degraded path (see `## Degraded path`). Archived patterns stay in-file for audit and leave the auto-match candidate set (see `## Match + confirm flow`, `## Pattern lifecycle`).

## Count rule

Count = number of **distinct `piece` values** in `occurrences`. Recording is **deduped per piece**: if the matched pattern already has an occurrence for the current piece, no occurrence is added (count unchanged); a finding in a not-yet-recorded piece adds one (count increments). Because of dedup, `occurrences` holds at most one entry per piece, so `count = len(occurrences)`.

```
Worked example (threshold = 2):
  pattern `stale-charter-snapshot`, occurrences = [plan-concrete]            → count 1, no trip
  same finding recurs in plan-concrete (same piece)        → deduped, no add → count 1, no trip
  finding recurs in sonnet-coord (new piece)               → add occurrence  → count 2, TRIPS threshold
```

This resolves the PRD's Open Question in favor of per-(pattern, piece) granularity. The two representations are consistent: because the list is deduped per piece, `count = len(occurrences)` holds exactly as FR-006 AC1 requires. A pattern recurring multiple times within one piece counts once; "same finding twice in one repo" means two distinct pieces.

## Match + confirm flow (no silent write)

At the Step 6c hook the flywheel proposes a match against `docs/patterns.yaml`. The proposal is one of:

- **Existing `id`:** the flywheel LLM-proposes the closest matching pattern slug from the registry.
- **"New" + proposed kebab slug:** when no existing pattern fits, the flywheel proposes a new `id` (kebab slug, LLM-authored).

The flywheel writes **nothing** to `docs/patterns.yaml` until the operator confirms both the classification (which pattern) and the scope (`charter | qa | prd`). On a "new" confirmation the operator may rename the proposed slug, and the rename becomes the stored `id`.

An `archived` pattern is EXCLUDED from the auto-match candidate set. Archived patterns are included in the LLM's match context (labelled `[archived]`) so near-match proposals can surface — they are excluded only from the auto-accept candidate set (operator confirmation is still required for revive — NN-P-004). When a Step 6c finding near-matches an archived pattern, the flywheel surfaces a revive option (`resembles archived pattern <id> — revive or mint new?`) immediately at that Step 6c prompt so historical correlation is not silently lost. Revive (clearing the `archived` marker) is also offered in the Step 4.5 refresh prompt for patterns already archived before the current piece runs; archived entries are never deleted.

Matches are LLM-proposed, human-confirmed (NN-P-004). The match line is additive to the existing single-aggregated-prompt-per-phase convention (NFR-6) — it does not add a separate prompt round-trip per finding; it is folded into the phase's existing Step 6c triage prompt.

## Source taxonomy (schema-open)

The `source_type` field on each occurrence admits three values:

| value | status | description |
|-------|--------|-------------|
| `reflection-finding` | **WIRED** | Findings from the two reflection agents routed through Step 6c at end-of-piece Step 4.5 |
| `execute-discovery` | **WIRED** | Native per-phase Step 6c discoveries: `qa-phase`/`qa-phase-lite` findings, AC-matrix NOT-COVERED rows, Build missing-prerequisite escalations, unmarked execute-time discoveries |
| `metric` | **WIRED** | An occurrence may cite a measured trend from a piece's `metrics.yaml`; the `source:` field carries a pointer `<prd-slug>/<piece-slug>/metrics.yaml#<field>`. Written only via the existing match/confirm flow (operator-confirmed, NN-P-004). See `plugins/spec-flow/reference/metrics-artifact.md`. |
| `campaign` | **WIRED** | Findings from spec-flow:campaign's theater-guard VERIFY pass, recorded as occurrences via the existing operator-confirmed match/confirm flow (NN-P-004). See plugins/spec-flow/skills/campaign/SKILL.md. |

FR-010 wired the third source_type (see `## Source taxonomy`). The `originating_repo` occurrence field remains schema-open (representable) but wire-narrow (no path emits it here) — the `flywheel-global` piece (FR-007) adds that emitter.

## Threshold + batched proposal

Read `flywheel_threshold` (plain integer, default 2) from `.spec-flow.yaml`; absent key ⇒ default 2 (non-blocking, backward-compatible, NN-C-003).

At end-of-piece Step 4.5, **after** this piece's reflection findings are recorded through the Step 6c flywheel hook, surface **one** batched proposal listing every pattern whose distinct-piece count ≥ `flywheel_threshold`. Each entry in the batched proposal carries:

- The pattern `id` and `description`
- Its recorded `count` (distinct pieces)
- Its `scope` as the proposed routing home (`charter` → charter amendment, `qa` → local QA hardening, `prd` → PRD work)

A single proposal covers all at/over-threshold patterns simultaneously (one operator prompt). A pattern at count ≥ threshold is **excluded** from the batched proposal when ANY of the following hold:

1. It has a `rejections` entry and `count ≤ rejected_at_count` (existing rejection rule — the pattern re-includes when a new occurrence pushes count above `rejected_at_count`).
2. It has a `hardenings` entry with `outcome: resolved` and `count ≤ at_count` (resolved-exclusion — the pattern re-includes only when a new occurrence pushes count above the resolved `at_count`).
3. It has a `hardenings` entry with `outcome: blocked` and `count ≤ at_count` (blocked back-off — re-propose only when count exceeds the blocked `at_count`).

Note: a pattern hardened (resolved) at count 2 is excluded while count stays 2; a new occurrence (count 3 > 2) re-includes it — symmetric with the rejection rule. When a pattern has multiple `hardenings`/`rejections` entries, evaluate each rule against the **highest (most-recent) `at_count` / `rejected_at_count`** among matching entries — the pattern re-includes only when the count exceeds the largest recorded suppression point.

Patterns with count < threshold are not included.

The batched proposal fires at the **end-of-piece** Step 4.5 Reflection juncture — after the Final Review board and Human Sign-Off, before merge — using the existing point at which reflection findings already route through Step 6c. This is not a new pipeline step.

## Pattern lifecycle

**Derived state:** `state` and `last_seen` derive per `## Registry schema`; `hardened` and `active` use exclusion-rule #2 (see `## Threshold + batched proposal`).

**Ineffective hardening:** A pattern whose `count` has since exceeded the highest resolved `at_count` across all its `hardenings` entries (exclusion-rule #2 read in the negative — see `## Threshold + batched proposal`). This is a COMPUTED condition and label — not a stored flag. It is surfaced in a DISTINCT, elevated "regressions" block at the batched review (not a peer proposal row), honoring FR-015 "elevated priority". An ineffective hardening derives `active` (count > at_count) and a recurrence advances derived `last_seen`; it is excluded from both archival arms.

**Staleness window:** `pieces_since_last_seen` = count of distinct `piece` values across ALL patterns' `occurrences` whose `date` is after this pattern's `last_seen` (flywheel-active-piece cadence; registry-internal; no global ordinal, no manifest read). The window is `staleness_window` (default `8`, read from `.spec-flow.yaml`). An absent key, a present-but-null, a present-but-empty value, and a value ≤ 0 ALL resolve to `8` (zero and negative windows are nonsensical — NN-C-003); a null is never read as `0`.

```
Worked example (staleness_window = 8):
  pattern P, last_seen = exec-ready/metrics; distinct pieces recorded after it = 8 (in other patterns' occurrences; P itself had none after exec-ready/metrics' date) → pieces_since_last_seen 8 ≥ 8 → stale; if state active → stale-active arm; if state hardened → clean-hardened arm
  pattern Q, last_seen = exec-ready/gate-scaling; distinct pieces after it = 3 → 3 < 8 → not stale, no proposal
  pattern R, hardened at_count 2, recurs in a new piece → count 3 > 2 → derives active, last_seen advances → ineffective-hardening regressions block, NOT archival
```

**Refresh pass:** At end-of-piece Step 4.5, after the existing batched hardening proposal, surface ONE operator-gated batched archival proposal listing: (a) stale-active (`state: active`, `pieces_since_last_seen ≥ staleness_window`); (b) clean-hardened (`state: hardened`, `pieces_since_last_seen ≥ staleness_window`). Both arms use the single `pieces_since_last_seen` clock (differ only by derived state). The single clock is a correct proxy for the clean-hardened arm because hardening appends only a `hardenings` entry — never an occurrence (see `## Hardening dispatch (reuse)`) — so `last_seen` does not advance at hardening time. Nothing archives until the operator confirms (NN-P-004). Ineffective-hardening patterns (count > at_count) are excluded from both arms and appear in the regressions block.

**In-proposal rendering:** The proposal renders, per listed pattern, its derived `state`, `last_seen`, and ineffective-hardening status.

**Read-never-write invariant:** Deriving `state`/`last_seen`/`ineffective-hardening` and computing `pieces_since_last_seen` are READS; they never write the registry. The only refresh writes are the operator-confirmed `archived` flip and revive flip (atomicity per `## Degraded path`).

## Hardening dispatch (reuse)

On operator **approval** of one or more patterns in the batched proposal:

1. Dispatch `agents/spike.md` in `scope` mode (Opus, isolated context, ≤2K digest). A flywheel-originated scope spike uses `<id>` = `flywheel-<pattern-id>`; the orchestrator injects this `<id>` exactly as a per-discovery spike injects `<discovery-id>`. The artifact is written and read at `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/flywheel-<pattern-id>.md`. The dispatch payload injects `mode:scope` + the change text (the pattern description + its occurrences + the proposed routing home, framed as the change to scope) + the current `plan.md` + diff/neighborhood scope — the same plan/scope inputs the `#### Amend dispatch` Scope-spike pre-step injects — so the spike emits a valid `Classification` (typically `additive: <after-phase-id>`). The spike always runs — the hardening fix is unknown by nature; treat as the undefined-ratio → spike case.
2. On `STATUS: OK`: read the spike artifact at `spikes/flywheel-<pattern-id>.md`, then route the scoped fix through the **existing** Step 6c reflection-finding `amend` dispatch (`execute/SKILL.md` ~1844 behavior): `plan-amend` appends the scoped hardening phases to the current piece's plan at a dependency-correct position; those phases run through the full Per-Phase Loop and re-enter the Final Review board before merge; the amendment consumes the standard per-piece amendment budget (5 total / 1 spec). Append a `hardenings` entry to the pattern in `docs/patterns.yaml`: `{date, outcome: resolved, spike_artifact: spikes/flywheel-<pattern-id>.md, amend_commit: <amend sha>, at_count: <current distinct-piece count>}` — do NOT write to `occurrences` (the piece's occurrence already exists; adding another would break the per-piece dedup rule). Append the standard `.discovery-log.md` row with source-phase token `step-4.5-reflection`.
3. On `STATUS: BLOCKED`: escalate to the operator with the spike's findings. Produce **no** plan amendment. Apply **no** mid-stream patch. Append a `hardenings` entry to the pattern in `docs/patterns.yaml`: `{date, outcome: blocked, spike_artifact: —, at_count: <current distinct-piece count>}`; the pattern remains eligible for future proposals — this is **not** a rejection (a rejection entry is not written).

No new agent is created. No new amend mechanism is introduced. The flywheel gains a runtime dependency on `agents/spike.md` (already merged as of 5.7.0) and the existing `plan-amend` path.

**Charter alignment:** NN-P-005 (Opus thinking via the sanctioned isolated spike agent), NN-P-002 (routes through scope → amend → execute, never a mid-stream patch), CR-008 (no heavyweight new orchestrator logic), NN-P-001 (human sign-off gate unchanged; the hardening approval is a second distinct operator gate whose amendment re-enters review before merge).

## Rejection rule

On operator **rejection** of a pattern in the batched proposal, append to its `rejections` list:

```yaml
rejections:
  - date: <ISO date>
    rationale: <operator-provided one-line reason>
    rejected_at_count: <count at rejection time>
```

The pattern is **excluded from future batched proposals** while its distinct-piece count ≤ `rejected_at_count`. Once a new occurrence pushes the count above `rejected_at_count`, the pattern is included in proposals again (the count-based exclusion lifts automatically).

A rejected pattern is not deleted from `docs/patterns.yaml`; occurrences continue to accumulate normally. Only proposal inclusion is gated by the rejection record.

## Degraded path

When `docs/patterns.yaml` is **unwritable** (filesystem permission error) OR **unparseable** (malformed YAML):

1. The flywheel emits a single bracketed orchestrator line: `[FLYWHEEL-DEGRADED: repo registry unavailable]`
2. **No** registry write occurs.
3. Execute is **not** blocked or failed — the piece continues normally.
4. The triggering finding still flows to its normal Step 6c triage / reflection resolution.

The degraded path also covers the **Step 4.5 batched proposal**: if `docs/patterns.yaml` is unwritable OR unparseable at batched-proposal time (whether reading the count, or writing a reject/hardening entry), emit `[FLYWHEEL-DEGRADED: repo registry unavailable]`, skip the batched proposal entirely (no read, no write, no proposal surfaced), and do NOT block merge — the piece proceeds to Step 5 / merge.

**Lifecycle degraded path:** A lifecycle field that is PRESENT but invalid (an `archived` marker not in the sanctioned form, or an otherwise malformed lifecycle field) → emit `[FLYWHEEL-DEGRADED: lifecycle unavailable]`, propose nothing, and leave the file untouched; recording (occurrence append, rejection, hardening) continues per the steps above. ABSENCE of lifecycle fields is NOT malformed — it derives `active` (see `## Registry schema`) and MUST NOT trip the marker. **Atomic write:** Any refresh write (archival flip, revive flip) is atomic: write to a temp file then rename (all-or-nothing). After the write, re-read the file; if the write did not fully land, emit `[FLYWHEEL-DEGRADED: lifecycle unavailable]` with an explicit `archival not applied` notice. After emitting the degraded marker, discard the in-memory change and re-read the registry state from disk before continuing — the session state must match the on-disk state. The pre-flight gate above covers torn reads; this covers torn writes.

This mirrors the `[RESEARCH-UNAVAILABLE]` / `[TEST-DATA-ABSENT]` marker convention used elsewhere in the pipeline. The degraded marker is informational; it surfaces the fault without creating a blocking condition.

## No secrets

When transcribing finding text into an occurrence `source`, or into a `hardenings` or `rejections` rationale, or into an archival rationale or regression/revive note, never copy credentials, tokens, private keys, or connection strings verbatim — summarize the finding's nature instead.

## See also

- `plugins/spec-flow/skills/execute/SKILL.md`
- `plugins/spec-flow/agents/spike.md`
- `plugins/spec-flow/reference/spike-agent.md`
- `plugins/spec-flow/agents/plan-amend.md`
- `plugins/spec-flow/reference/research-artifact.md`
