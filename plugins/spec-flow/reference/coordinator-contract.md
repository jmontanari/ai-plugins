# Coordinator Contract — model policy, return discipline, resume-critical state

## Model Policy

The table below documents the model assigned to each in-execute dispatch stage. It is **derived from and must agree with** the actual `Agent({… model:})` dispatch sites in `plugins/spec-flow/skills/execute/SKILL.md` — it documents, it does not redefine. AC-1's Independent Test diffs each in-execute row against its dispatch site to confirm agreement; the execute skill itself performs no such diff at runtime.

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

Exactly two exceptions upgrade an in-execute stage to Opus and are the only assignments the policy *flags* (vs silently reports): (1) **spike phase → Opus** — a `[SPIKE]` phase dispatches the spike agent on Opus (mechanism wired by the `spike-agent` piece, FR-005); (2) **operator override → Opus** — the operator forces Opus for a named phase via the `--opus=<phase-id|all>` execute invocation flag (wired by `spike-agent`, FR-005 AC-3). No other path upgrades a non-`[SPIKE]` stage to Opus (NN-P-005).

`model_policy: auto` (default; absent → auto) — the coordinator reports the per-stage assignment at execute start and flags only the two exceptions. `model_policy: off` — the coordinator runs only the legacy single Pre-flight Model Check prompt (`execute/SKILL.md` `## Pre-flight: Model Check`) and emits no per-stage report.

## Coordinator Return Discipline

The coordinator stays lean over long pieces by consuming **bounded, structured** agent returns. Every agent return to the coordinator MUST be a bounded summary; raw artifacts — full diffs, full test output, file bodies — live on disk or git and are referenced by path, never pasted into the coordinator's context. The execute skill carries an audit table (one row per dispatch) asserting each return is bounded; any dispatch instructing an agent to paste a raw dump is a defect.

## Resume-Critical State — Field Tiers

`[STATE-INCOMPLETE: <field>]` is emitted (and the coordinator escalates to the operator rather than guessing) **iff** a field is (a) resume-critical, (b) expected-present given the current resume position, and (c) missing or corrupt. Otherwise the coordinator recomputes (tier 2) or treats the absence as valid (tier 3).

| Field | Tier | On-disk home / recompute source | Missing-field behavior |
|-------|------|---------------------------------|------------------------|
| plan.md + its [x] checkboxes | 1 | plan.md | escalate [STATE-INCOMPLETE: plan.md] — position cannot be located |
| Phase Group journal sub_phases[].status, red_manifest_hashes — WHEN a group is in flight | 1 | journal (deferred-commit-journal.md) | escalate [STATE-INCOMPLETE: journal] — cannot know which sub-phases are green |
| phase-start SHA | 2 | git rev-parse HEAD (minus this phase's committed steps) | recompute — no escalation |
| amendment counters | 2 | count committed amendments in branch history | recompute — no escalation |
| Phase Group journal — WHEN no group is in flight | 3 | n/a (valid absence) | fresh start (existing L1837 behavior) — no escalation |
| .orchestra-state.json (mid-piece pass flag) | 3 | file absent = pass not yet dispatched | valid absence — no escalation |
| discovery-row cosmetic fields (source_agent, ac_id) | 3 | n/a | defensive default (existing L932 behavior: `unknown` / `—`) — no escalation |

A Phase Group is *in flight* iff plan.md shows at least one checked sub-phase step checkbox under the group AND the group-level `[Progress]` checkbox is unchecked. When a group is in flight, its journal is expected-present (tier-1); when no group is in flight, journal absence is valid (tier-3).

<!-- Worked example:
  plan.md state: Phase Group B — sub-phase B.1 [Build] checkbox = [x],
                 group-level [Progress] checkbox = [ ]   ⇒ group B IS in flight.
  Disk: no journal file present (or group_letter ≠ B).
  Classify journal: tier-1 (resume-critical AND expected-present AND missing).
  Output: emit `[STATE-INCOMPLETE: journal]`, escalate to operator. Do NOT fresh-start.

  Contrast: plan.md shows group B with NO checked sub-phase steps and [Progress] = [ ]
            ⇒ group B NOT in flight. No journal ⇒ tier-3 valid absence ⇒ fresh start (L1837). -->
