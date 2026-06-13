# Fixture: BRF-3 bug vs non-bug classification (AC-11)

**Scenario:** Two campaign findings enter the triage Form C batch — one classified as a bug (`bug_classified: true`), one as a quality gap (`bug_classified: false`). The NN-P-006 red-first stamp fires ONLY on the bug-classified finding when triage assigns a `fix` disposition. The non-bug finding with a `fix` disposition receives no red-first stamp.

## Setup

Two findings survive the theater-guard VERIFY pass:

**Finding A (bug):**
- `lens: campaign-edge-case`
- `finding_text: "Position size exceeds the declared 2% risk-per-trade limit on day 3 of the backtest."`
- `output_evidence: "Day 3: position_size=0.045 (limit: 0.02); trade executed without rejection"`
- `oracle_ac_id: AC-07`
- `discovery_type: edge-case`
- `bug_classified: true`  ← explicit — violates a declared money/safety rule

**Finding B (non-bug quality gap):**
- `lens: campaign-seam`
- `finding_text: "The integration coverage seam for the order-router → risk-engine handoff has no run-output evidence."`
- `output_evidence: "order_router: 3 orders routed; risk_engine: no log lines observed"`
- `oracle_ac_id: AC-09`
- `discovery_type: seam`
- `bug_classified: false`  ← explicit — coverage gap, not a correctness violation

## Expected behavior (AC-11 / BRF-3)

When both findings receive a `fix` disposition from the triage operator:

1. **Finding A** (`bug_classified: true`) → triage Step 7 applies the NN-P-006 red-first stamp. A RED failing test must be written before any fix production code.

2. **Finding B** (`bug_classified: false`) → triage Step 7 does NOT apply the red-first stamp. A `fix` disposition for a coverage gap follows the normal implement track.

## Clean control

- When `bug_classified: false`, no red-first stamp fires regardless of `discovery_type` or `fix` disposition. The field is the authoritative pre-seeded signal; triage does not re-derive it from finding keywords for campaign-source records.
- When `bug_classified` is absent (non-campaign source), triage derives it from its own bug-signal scan (backward-compatible). Campaign records always carry the explicit value.

## Falsifying conditions (would break AC-11 / BRF-3)

- Triage applies the red-first stamp to Finding B (non-bug quality gap). ❌
- Triage re-derives `bug_classified` from keyword matching for campaign records instead of reading the explicit field. ❌
- Triage omits the red-first stamp for Finding A despite `bug_classified: true` + `fix` disposition. ❌
- The `bug_classified` field is ignored entirely. ❌

## Oracle

**Assert:** `reference/triage-contract.md` documents `bug_classified: true|false` as a Form B/C field.
**Assert:** `reference/triage-contract.md` states the field pre-seeds the bug-signal result (absent ⇒ triage derives it — backward-compatible).
**Assert:** `skills/campaign/SKILL.md` includes `bug_classified` in the Form B record assembly (Step 6).
**Assert:** This fixture file contains `bug_classified` (cross-phase consistency — grep from the [Verify] step).
