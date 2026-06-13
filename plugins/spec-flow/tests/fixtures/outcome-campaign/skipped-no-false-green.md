# Fixture: SKIPPED outcomes are never false-green (AC-3)

**Scenario:** Two distinct situations where the campaign cannot exercise a stage or oracle — the expected outcome is an explicit `SKIPPED: <reason>` signal, never a clean pass or a no-findings result that looks like success.

## Situation A: No entrypoint configured

**Setup:** `.spec-flow.yaml` has no `campaign.entrypoint` key (or the key is empty string).

**Expected behavior (AC-3):**
```
SKIPPED: no-entrypoint (campaign unavailable)
```
The skill STOPs immediately. It does NOT emit "0 findings" or "PASS". No lens agents are dispatched. No triage is invoked.

**Falsifying condition:** The skill emits "Campaign complete — 0 findings confirmed" or any success-looking message when the entrypoint is absent. ❌

## Situation B: Oracle is empty (no in-scope outcome ACs, no money/safety rules)

**Setup:** The target piece-set's spec files contain no `(FR-018)` tagged outcome ACs and no declared money/safety rules. The oracle block resolves to empty.

**Expected behavior (AC-3 / AC-2):**

1. `campaign-ground-truth` still runs (degeneracy needs no oracle — it checks for dead-knob outputs regardless).
2. `campaign-seam` emits: `SKIPPED: no-oracle`
3. `campaign-edge-case` emits: `SKIPPED: no-oracle`

The run report shows the two SKIPPED lenses explicitly. The overall campaign result is:
```
Campaign complete — ground-truth lens ran; seam/edge-case: SKIPPED (no-oracle).
```
This is NOT a clean pass. The operator can see exactly which coverage was and was not exercised.

**Falsifying condition A:** Both oracle-bound lenses emit "0 findings" instead of "SKIPPED: no-oracle". ❌
**Falsifying condition B:** The oracle-absent run is indistinguishable from a "no problems found" run. ❌

## Situation C: A declared stage cannot execute

**Setup:** The campaign entrypoint declares three stages: `pilot`, `backtest`, `e2e`. The `e2e` stage requires a live broker connection that is unavailable.

**Expected behavior (AC-3):**
- `pilot` and `backtest` stages run normally.
- `e2e` stage emits: `SKIPPED: e2e (capability unavailable)`
- The campaign continues with the two runnable stages; it does NOT fail the whole campaign.
- The run report includes the SKIPPED stage entry. It does NOT report a clean overall pass without noting the gap.

**Falsifying condition A:** The `e2e` stage failure causes the whole campaign to abort with an error. ❌
**Falsifying condition B:** The `e2e` SKIPPED stage does not appear in the run report. ❌
**Falsifying condition C:** The `e2e` stage being skipped is presented as a pass ("no issues in e2e"). ❌

## Oracle

**Assert:** `skills/campaign/SKILL.md` Step 0 emits `SKIPPED: no-entrypoint (campaign unavailable)` when `campaign.entrypoint` is absent.
**Assert:** `skills/campaign/SKILL.md` Step 1 notes the empty-oracle case and the ground-truth exemption.
**Assert:** `skills/campaign/SKILL.md` Step 4 documents that oracle-bound lenses emit `SKIPPED: no-oracle` when the oracle is empty.
**Assert:** `skills/campaign/SKILL.md` Step 2 documents per-stage capability detection and `SKIPPED: <stage>` emission without whole-campaign failure.
