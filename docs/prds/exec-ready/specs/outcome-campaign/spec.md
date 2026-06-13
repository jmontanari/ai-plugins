---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
piece_class: behavior-bearing
---

# Spec: outcome-campaign

**PRD Sections:** FR-020, SC-010, SC-005, G-7
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** outcome-acs (merged), discovery-triage (done), metrics (merged), flywheel-repo (merged), seam-design (merged)

## Goal

Ship `spec-flow:campaign` — a new gate **class**, the running-system sibling of the Final Review board. Where review-board points adversarial lenses at a *diff*, the campaign points them at a *running system's outputs*, graded against an oracle (in-scope FR-018 outcome ACs + declared product money/safety rules). It runs the target system on **Sonnet**, dispatches **Opus** adversarial lenses (ground-truth / seam / edge-case) that grade real output, verifies each finding before it becomes actionable, routes every surviving finding through `/spec-flow:triage` to a recorded disposition, and records `source: campaign` to the metrics artifact and the flywheel. This closes the largest uncovered cost channel from the 2026-06-12 efficiency evaluation: result-level wrongness and whole-platform seam defects that pass every construction gate and surface today only in expensive freeform Opus validation.

This piece ships the **single-pass v1**. The surface-scaled convergence loop (Pass A → fix → wired QA-validate → Pass B re-hunt) was split to a follow-up piece `campaign-converge` (operator decision, this brainstorm) — see `## Out of Scope / Non-Goals`.

## In Scope

- A `spec-flow:campaign` SKILL.md mirroring the review-board out-of-band thin-orchestrator skeleton; invoked out of band, it changes no version-bearing file when run.
- Oracle loading by ID: in-scope FR-018 outcome ACs + declared money/safety rules; never re-derived. Oracle-absence handling (`SKIPPED: no-oracle`).
- A **run-safety contract**: declared `.spec-flow.yaml campaign.entrypoint` + mandatory `campaign.run_mode: dry-run|sandbox|live`; a pre-run confirm of the exact resolved command; capability-detect + `SKIPPED: <capability>` per stage (never false-green); system run on Sonnet.
- Three **new** Opus lens agents — `campaign-ground-truth`, `campaign-seam`, `campaign-edge-case` — grading run output against the skill-injected oracle.
- A skill-orchestrated per-finding **theater-guard VERIFY** pass (precision-biased: route only confirmed findings).
- Triage routing: surviving findings → triage Form B records (incl. a `bug_classified` field, BRF-3) → Form C batch → `/spec-flow:triage`; fixes route OUT (the campaign never patches); red-first via triage Step 7.
- Additive recording: a `findings_by_source` block in `metrics.yaml` + a `campaign` value in the flywheel `source_type` enum; operator-gated; degraded-path-safe.
- This piece **dogfoods FR-018**: it carries its own outcome ACs (never-false-green; campaign→triage seam exercised e2e; no lens/seat silently dropped).
- Plugin version bump (minor) across all version-bearing files (NN-C-009).

## Out of Scope / Non-Goals

- **The surface-scaled convergence loop** (Pass A find+verify → fix batch → QA-validate-wired-together → Pass B re-hunt; three-way-OR termination; integration-surface metric → depth scaling; per-round vs terminal confirm granularity [VOQ-1]; loop-spec home [VOQ-5]). Split to a new `campaign-converge` follow-up piece (running-system sibling of `review-board-converge`), depends on outcome-campaign + seam-design. v1 is **always single-pass** (= the convergence loop's low-surface depth).
- **Conditional seat activation logic** beyond a reporting hook — FR-016(b) is unshipped, so v1 runs 3 always-on lenses and emits `conditional-activation: not-yet-available (FR-016b unshipped)`. Full signal-conditional activation lands when FR-016(b) ships.
- **Patching/fixing the target system** — the campaign produces findings + dispositions only; all fixes route out through triage → small-change/execute (NN-P-002).
- **Novel un-specced wrongness** the oracle cannot name — see the honest-replacement statement in `## Technical Approach`.

## Requirements

### Functional Requirements

- FR-C1: A `spec-flow:campaign` skill is invocable out of band (no active piece/manifest required beyond a git repo + `docs_root`), takes a target piece-set / system entrypoint, and mirrors the review-board Step-0–6 skeleton (config load → resolve target+oracle → run → grade → verify → route → record → Boundaries). It changes no version-bearing file when run.
- FR-C2: The oracle is loaded by ID — in-scope FR-018 outcome ACs (resolved from the target piece-set's `spec.md` files) plus declared product money/safety rules — and injected into each lens prompt as a delimited data block. The oracle is never re-derived by a grader. When **no** in-scope outcome ACs resolve, oracle-bound lenses (seam, edge-case) emit `SKIPPED: no-oracle` (never a clean pass); the ground-truth lens still runs (degeneracy/dead-knob needs no oracle); declared money/safety rules, when present, are a first-class oracle input.
- FR-C3 (run-safety): The target declares `campaign.entrypoint` (+ optional `--run` override) and a **mandatory** `campaign.run_mode: dry-run|sandbox|live` in `.spec-flow.yaml`; the skill **refuses to run** if `run_mode` is unset, `live` requires explicit opt-in, and the skill **confirms the exact resolved run command with the operator before first execution**. Capability-detect each declared stage (pilot/backtest/e2e); a stage that cannot run emits `SKIPPED: <capability>` and the campaign continues — never a whole-run failure, never a false-green. The system run is performed on **Sonnet** from the main window; absent `campaign.entrypoint` ⇒ the campaign is SKIPPED/unavailable, not an error.
- FR-C4: Three new Opus lens agents — `campaign-ground-truth` (result degeneracy / dead-knob), `campaign-seam` (cross-piece integration on run output; consumes the target's declared `## Integration Coverage` seam inventory — it does not re-derive boundaries), `campaign-edge-case` (boundary/regime behavior) — are dispatched as bounded isolated agents (≤2K return) grading captured run output against the injected oracle. v1 runs all three always-on; an omission-reporting hook reports any non-activated lens/seat (`conditional-activation: not-yet-available (FR-016b unshipped)`) — a lens/seat is never silently dropped.
- FR-C5: A skill-orchestrated per-finding **theater-guard VERIFY** pass runs a single Opus skeptic dispatch per finding before that finding becomes a triage item. The gate is **precision-biased**: a finding routes only if VERIFY independently confirms it; an unconfirmed finding is suppressed (documented tradeoff — campaign findings feed expensive fix work, and the campaign is re-runnable, so a suppressed true-positive resurfaces on a later run). The verify loop is orchestrated by the skill; no agent dispatches a sub-agent (CR-008).
- FR-C6: Surviving VERIFIED findings are assembled as triage Form B records (`source_phase: campaign`, `source_agent: <lens>`, `discovery_type: degeneracy|seam|edge-case`, `bug_classified: <bool>`) into a single Form C batch handed to `/spec-flow:triage`; the batch is confirmed once (triage's existing single-aggregated-confirm, NN-P-004). Fixes route OUT through triage (the campaign never patches the target, NN-P-002); a bug-classified finding becoming a fix is stamped red-first by triage Step 7 (NN-P-006).
- FR-C7: Findings are recorded `source: campaign` additively — a `findings_by_source` block in the piece `metrics.yaml` (schema_version unchanged) and a `campaign` value in the flywheel `source_type` enum (operator-gated occurrence). Both writes are degraded-path-safe (`[METRICS-DEGRADED]` / `[FLYWHEEL-DEGRADED]` never block the recorded triage disposition). Findings and metrics records never transcribe sensitive output values verbatim (no-secrets rule, mirroring the research agent).
- FR-C8: BRF-3 — the triage-contract Form B/C schema gains a `bug_classified` field for campaign-source findings so triage applies the NN-P-006 red-first stamp automatically; a campaign finding NOT classified as a bug does NOT inherit the stamp (clean-control fixture).
- FR-C9 (packaging): The piece bumps the spec-flow plugin version (minor) in all four version-bearing files and prepends a CHANGELOG entry (NN-C-009); the three new agents carry bare `name:` frontmatter and are self-contained (NN-C-004/008).

### Non-Functional Requirements

- NFR-C1 (isolation): lens and verify agents run in fresh isolated contexts and return ≤2K-token digests (NFR-001 / NN-C-008); richer detail stays in the run-output artifact, not the main-window context.
- NFR-C2 (no runtime deps): the entire campaign is markdown + bash + yaml orchestration — no static-analysis tooling, no second model provider, no Workflow-tool engine (NN-C-002).
- NFR-C3 (cost): the single-pass v1 Opus dispatch count per run is exactly `3 lens dispatches + 1 VERIFY per surviving finding` (no convergence-loop multiplier in v1); this per-run count is recorded to the metrics artifact (`source: campaign`) so SC-005's cross-PRD downward trend is measured from disk, not asserted. The per-finding VERIFY multiplier is named here so `campaign-converge` can bound the looped case.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (no runtime deps): campaign is markdown/bash/yaml only; lenses are isolated agents; no Workflow tool, no static-analysis tooling, no second provider.
- NN-C-003 (backward-compat, additive): the `findings_by_source` metrics block (schema_version unchanged) and the `campaign` flywheel enum value are purely additive; no existing reader breaks (the only metrics reader asserts `schema_version` presence and ignores unknown blocks; no programmatic validator reads the flywheel enum). The `.spec-flow.yaml campaign.*` keys default to skip-when-absent.
- NN-C-004 / NN-C-008 (agent conventions): the three new lens agents + the verify dispatch are self-contained, bare `name:`, no conversation-history assumption.
- NN-C-009 (version bump): minor bump across all four version-bearing files + CHANGELOG.
- NN-C-006 (no destructive ops without confirm): the run-safety pre-run confirm gates the one genuinely side-effecting action (executing the target system).

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human sign-off never removed): the campaign is operator-invoked; the triage handoff is operator-confirmed; the run-safety confirm is an operator gate. Nothing auto-advances.
- NN-P-002 (no silent/mid-stream change): every finding routes through triage to a recorded disposition; the campaign never patches the target; fixes run in a separate operator session.
- NN-P-004 (operator-gated writes): the triage confirm gate, the flywheel occurrence, and the run all require operator confirmation; nothing is written or run silently.
- NN-P-005 (Opus thinking / Sonnet mechanics): the system run + observation is on Sonnet; the lenses + VERIFY are on Opus. No silent upgrade.
- NN-P-006 (bug-fix red-first): a campaign finding that becomes a fix is red-first, applied automatically by triage Step 7 via the `bug_classified` Form C field (BRF-3).

### Coding Rules Honored

- CR-008 (thin-orchestrator / narrow-executor): the campaign skill orchestrates (run, dispatch lenses, run the per-finding verify loop, invoke triage, record); lens and verify agents execute one narrow task and dispatch nothing.
- CR-002 (skill frontmatter): `campaign/SKILL.md` carries `name:` + a specific when-to-use `description:`.
- CR-001 (agent frontmatter): the three lens agents carry `name:` + `description:` (+ `model: opus`).
- CR-005 (repo-root-relative paths): all cited paths are repo-root-relative.
- CR-007 (inline config docs): the new `.spec-flow.yaml campaign.*` keys carry inline `#` comments (purpose, values, default, rationale).
- CR-009 (heading hierarchy): the campaign SKILL.md and any reference-doc edits preserve the single-H1 / H2 / H3 hierarchy and stable anchors.

## Acceptance Criteria

AC-1: Given a git repo with a `docs_root`, When `/spec-flow:campaign <target>` is invoked out of band, Then a `spec-flow:campaign` SKILL.md resolves the target + oracle, runs the review-board-style skeleton, and exits having changed no version-bearing file. [mechanism]
  Independent Test [machine: `plugins/spec-flow/skills/campaign/SKILL.md` exists with valid `name:`+`description:` frontmatter; `git diff --name-only` of a campaign run touches no `plugin.json`/`marketplace.json`/`CHANGELOG.md`]

AC-2: Given a target piece-set, When the oracle is resolved, Then in-scope FR-018 outcome ACs are loaded by ID + declared money/safety rules, never re-derived; and When no in-scope outcome ACs resolve, Then oracle-bound lenses emit `SKIPPED: no-oracle` and the ground-truth lens still runs. [mechanism]
  Independent Test [machine: grep `campaign/SKILL.md` for the by-ID oracle-resolution step, the `SKIPPED: no-oracle` path, and the ground-truth-runs-regardless branch]

AC-3: When the campaign runs against a stage it did not actually exercise (entrypoint absent, oracle empty, or a lens errored), Then it reports `SKIPPED: <capability>` / `SKIPPED: no-oracle` for that stage and NEVER renders it as a clean / zero-findings pass. [outcome:result]
  Independent Test [judgment: qa-spec / review-board reads every campaign stage exit and confirms no path emits "clean"/"no findings" without having exercised that stage against a non-empty oracle]

AC-4: Given `.spec-flow.yaml`, When the campaign prepares to run, Then `campaign.run_mode` is mandatory (the campaign refuses to run if unset), `live` requires explicit opt-in, and the exact resolved run command is confirmed with the operator before first execution. [mechanism]
  Independent Test [machine: prod-callsite=plugins/spec-flow/skills/campaign/SKILL.md (the run-safety + Sonnet system-run step); grep it for the `run_mode`-required refusal, the `live` opt-in gate, the pre-run command-confirm step, and the Sonnet system-run dispatch]

AC-5: When the campaign runs, Then the system run is dispatched on Sonnet and the lens + verify dispatches carry `model: "opus"` (NN-P-005). [mechanism]
  Independent Test [machine: grep `campaign/SKILL.md` lens/verify dispatch blocks for `model: "opus"`; confirm the system-run step is main-window Sonnet, not an Opus sub-agent]

AC-6: Given captured run output + the injected oracle, When the lenses grade, Then three new agents `campaign-{ground-truth,seam,edge-case}` exist (bare `name:`, self-contained), grade run OUTPUT (not a diff) against the oracle, and the seam lens consumes the target's declared `## Integration Coverage` inventory. [mechanism]
  Independent Test [machine: prod-callsite=plugins/spec-flow/skills/campaign/SKILL.md (the lens-dispatch block); the three `plugins/spec-flow/agents/campaign-*.md` files exist with bare `name:`] + [judgment: each agent prompt grades run output against an injected oracle, not a git diff]

AC-7: Given a set of lens findings, When the theater-guard runs, Then each finding gets one skill-orchestrated Opus VERIFY before triage and only VERIFY-confirmed findings are routed (precision-biased; unconfirmed suppressed) — and no agent dispatches a sub-agent. [mechanism]
  Independent Test [machine: grep `campaign/SKILL.md` for the per-finding verify gate + the confirmed-only routing branch; confirm the verify loop is in the skill, not an agent]

AC-8: When the campaign finishes grading, Then every surviving finding is routed through `/spec-flow:triage` as a Form C batch to a recorded disposition — never left only in conversation, never applied as a mid-stream patch. [outcome:integration]
  Independent Test [machine: prod-callsite=`plugins/spec-flow/skills/campaign/SKILL.md` contains the `/spec-flow:triage` Form C invocation; an e2e fixture asserts a graded finding produces a recorded triage disposition row, not a chat-only note]

AC-9: When any lens or seat is not activated, Then the campaign reports the omission (`SKIPPED` / `conditional-activation: not-yet-available (FR-016b unshipped)`) — a lens or seat is NEVER silently dropped. [outcome:integration]
  Independent Test [judgment: review-board confirms every lens/seat code path either runs or emits a reported omission; no silent skip]

AC-10: Given a recorded disposition, When findings are recorded, Then `source: campaign` is written additively to the piece `metrics.yaml` `findings_by_source` block (schema_version unchanged) and surfaced to the flywheel as a `campaign` `source_type` occurrence (operator-gated); both writes degrade safely (`[METRICS-DEGRADED]` / `[FLYWHEEL-DEGRADED]`) without blocking the disposition. [mechanism]
  Independent Test [machine: prod-callsite=plugins/spec-flow/skills/campaign/SKILL.md (the metrics + flywheel recording step); grep `reference/metrics-artifact.md` for the additive `findings_by_source` block (schema_version unchanged) + `reference/flywheel.md` for the `campaign` enum value + the two degraded markers]

AC-11: Given a campaign bug-finding, When it is handed to triage, Then the Form C record carries `bug_classified: true` and triage Step 7 applies the NN-P-006 red-first stamp automatically; and a non-bug campaign finding carries `bug_classified: false` and does NOT inherit the stamp. [mechanism]
  Independent Test [machine: grep `reference/triage-contract.md` for the campaign-source `bug_classified` field; a fixture with one bug + one non-bug campaign finding asserts the stamp fires only on the bug]

AC-12: When the piece is built, Then the spec-flow plugin version is bumped (minor) in all four version-bearing files with a matching CHANGELOG entry, and the three new agents are self-contained with bare `name:`. [mechanism]
  Independent Test [machine: the four version strings match the new version (per `docs/releasing.md`); `grep -E "^name:\s*spec-flow-" plugins/spec-flow/agents/campaign-*.md` returns nothing]

## Technical Approach

The campaign is a thin orchestrator that reuses shipped primitives rather than inventing machinery:

- **Skeleton** mirrors `plugins/spec-flow/skills/review-board/SKILL.md` (Step 0 config/git-check → Step 1 resolve target + oracle → Step 2 run-safety + run on Sonnet → Step 3 dispatch Opus lenses → Step 4 per-finding theater-guard VERIFY → Step 5 Form C → `/spec-flow:triage` → Step 6 record metrics/flywheel → Boundaries). Each lens dispatch prepends the `WORKTREE:` preamble and runs `model: "opus"`.
- **Oracle** is resolved by ID from the target piece-set's `spec.md` outcome ACs (FR-018 "addressable by ID, not re-derived") + declared money/safety rules, and injected as a delimited data block into each lens prompt.
- **Run-safety** is the one genuinely side-effecting surface and the dominant risk (the first spec-flow component to execute the target; the flagship target is a live trading system). It is gated by a mandatory `run_mode`, a pre-run command confirm, and `live` opt-in. Capability detection mirrors `reference/integration-capability-check.md`; SKIPPED-per-stage mirrors the FR-013/FR-017 SKIPPED contract.
- **Lenses** are NEW agents (Fork F1 resolved → new agents, not a mode on the shared review-board agents, which are co-owned by execute Final Review + review-board and would be a regression surface). The seam lens consumes seam-design's shipped `## Integration Coverage` declaration directly — v1 does not compute a numeric surface metric (that is `campaign-converge`'s job).
- **Theater-guard VERIFY** is skill-orchestrated (the only CR-008-legal arrangement — a per-finding verify loop is orchestration); precision-biased so the campaign feeds real fix-work, not theater.
- **Downstream** reuses the shipped `/spec-flow:triage` Form B/C path, the additive metrics-artifact pattern (precedent: `ac_verifiability`, `gate_scaling`), and the flywheel enum-extension pattern (precedent: `metric`).

**Honest-replacement statement (user-intent lens d):** the campaign replaces the oracle-anchored fraction of hand-validation (result/seam defects nameable against outcome ACs); it does NOT replace novel, un-specced wrongness the oracle never anticipated. The ground-truth lens partially compensates — it flags degeneracy/dead-knob without an oracle — but the seam/edge lenses are oracle-bound. The spec does not oversell SC-010.

## Testing Strategy

- **Unit (~60%):** oracle resolution (by-ID + money/safety rules + no-oracle SKIPPED); run-safety gating (run_mode-required refusal, live opt-in, pre-run confirm); capability-detect SKIPPED-per-stage; theater-guard confirmed-only routing; Form B/C assembly incl. `bug_classified`; additive metrics/flywheel writes + degraded markers.
- **Integration (~30%):** the campaign→triage seam exercised end-to-end (a graded finding produces a recorded triage disposition — AC-8, the production-call-site); the campaign→metrics and campaign→flywheel recording seams.
- **e2e / fixtures (~10%):** a SKIPPED-per-capability run (entrypoint absent → reports what it could not exercise, never false-green); a no-oracle run (oracle-bound lenses SKIPPED, ground-truth runs); the BRF-3 bug vs non-bug clean-control fixture.
- **Edge cases:** empty oracle; entrypoint declared but undetected (false-negative → loud SKIPPED, not silent gap); a lens returning empty because it errored (must not render clean); `run_mode` unset (refuse).

## Integration Coverage

- Integration: campaign→`/spec-flow:triage` — inside:{campaign skill}; doubled externals: triage skill (contract-tested via the Form C handoff fixture); allocated AC-8 (prod-callsite on its machine sub-line).
- Integration: campaign→metrics.yaml `findings_by_source` + flywheel `docs/patterns.yaml` — inside:{campaign skill}; doubled externals: the metrics-artifact writer + the flywheel occurrence writer (each contract-tested); allocated AC-10 (prod-callsite on its machine sub-line).
- Integration: campaign→Opus lens agents (campaign-ground-truth/seam/edge-case) + theater-guard VERIFY — inside:{campaign skill}; doubled externals: the Agent dispatch boundary (contract-tested); allocated AC-6 (prod-callsite on its machine sub-line); see also AC-7 (verify gate).
- Integration: campaign→target system run (bash entrypoint on Sonnet) — inside:{campaign skill}; doubled externals: the target project's declared `campaign.entrypoint` (capability-detected, run-safety-gated); allocated AC-4 (prod-callsite on its machine sub-line); see also AC-5 (model placement).

## Open Questions

- None. All six deliberation VOQs were resolved this brainstorm: VOQ-2 → single-pass v1, loop split to `campaign-converge`; VOQ-3 → `SKIPPED: no-oracle` per lens (ground-truth still runs); VOQ-4 → `run_mode` mandatory, refuse-if-unset; VOQ-6 → theater-guard precision-biased. VOQ-1 (confirm granularity) and VOQ-5 (loop-spec home) moved to `campaign-converge` with the loop.
