---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: gate-evals

**PRD Sections:** FR-017, SC-009, G-6
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** pipeline-e2e (merged — shared `tests/e2e/` harness for the consumer-surface parts), metrics (merged)

> **Re-alignment note (supersedes the prior fabricated-corpus design).** This spec replaces the earlier hand-authored fixture-corpus approach. The gate-efficacy measurement now mines **real spec-flow session transcripts** already on disk (`~/.claude/projects/<project>/*.jsonl` — hundreds of real sessions across multiple repos) rather than fabricating labeled fixtures. Rationale, substrate volume, the precision-vs-recall limit, and the privacy model are recorded in `deliberation.md` + the plan-stage conversation; this spec records the resolved design.

## Goal

Measure how spec-flow's own merge-blocking QA gates are actually performing, from **real usage**, so FR-016's board-seat cuts/downgrades are evidence-gated (G-6) — and red-team the FR-011 execute-integrity guardrails with a deterministic cheater track. The gate-effectiveness signal comes from mining the operator's real session transcripts (per-seat findings + inferred operator accept/reject); the guardrail signal comes from constructed tamper scenarios. The two are complementary: mining gives precision/overlap/activity from reality; the cheater track gives recall against known-planted tampers.

## Substrate & boundaries

- **Source data:** `~/.claude/projects/<encoded-project>/*.jsonl` session transcripts (read-only). Operator-configurable set of projects/repos; cross-repo by design.
- **Internal tool:** `tools/transcript-eval/` at the **repo root** (in git, python+pip allowed) — **internal maintainer tooling only**. It is NOT under `plugins/spec-flow/` and is NOT distributed (releasing.md rsyncs only `plugins/spec-flow/` to installed plugins), so NN-C-002 (scope: files under `plugins/<plugin>/`) does not govern it. It never runs inside an end user's installed-plugin runtime.
- **Durable insight store:** a repo-peer directory **outside repo scope** (configurable; default `/Volumes/joeData/spec-flow-insights/`) so git operations / worktree removal / `git clean` cannot wipe accrued insights. Source transcripts get rotated; derived insights are the irreplaceable asset.
- **Consumer surface (shipped, bash-only):** the cheater track, the EG-2 guardrail fix, and the `rubric_version` agent tag live under `plugins/spec-flow/` and stay POSIX-bash with zero runtime deps (NN-C-002 honored).

## In Scope

- A reusable **transcript-mining lib** (`tools/transcript-eval/`, python+pip) that enumerates configured project transcript dirs, parses `.jsonl` best-effort, and extracts per-seat gate **findings** + **inferred operator accept/reject** — structured so `flywheel-global` (FR-007) can reuse it later (shared-lib decision).
- A **gate-effectiveness metric set** computed from the mined data: per-seat precision, verdict-overlap, **leave-one-out unique-catch**, rubber-stamp signals, and gate activity — the load-bearing FR-016 board-cut evidence.
- A **broad pipeline-health "story"** report rendered from the aggregates (cross-repo), with the FR-016 per-seat evidence as a required section.
- A **durable external insight store** (repo-peer dir) holding run-history + accrued aggregates + story snapshots, never committed to the repo.
- An **extraction-validation spike** that runs first and gates the rest on real extraction quality.
- A **privacy/scrub contract**: nothing mined is committed to the repo; cross-repo (e.g. prop-firm) content never enters the ai-plugins repo; secrets are scrubbed.
- The **cheater track** (constructed bash oracle red-teaming FR-011) + EG-1 residual tier + the **EG-2 guardrail fix** + locking fixture — carried from the prior design, consumer-surface, bash-only.
- A light **`rubric_version`** tag on measured gate agents so mined metrics can be segmented by rubric era (apples-to-apples).
- The **FR-016 consuming contract** (`gate-scaling.md#board-swap-rule`) + an honest **SC-009 re-scope**.

## Out of Scope / Non-Goals

- **The LLM-inference layer** (re-running a past gate against its artifact to measure verdict-flip / consistency) — explicitly deferred to a later piece; this piece is deterministic mining + the deterministic cheater track only.
- **True recall / catch-rate from mining** — structurally impossible (you cannot see defects nobody flagged). Recall is provided ONLY by the cheater track / constructed tampers. The mined "story" must not claim a catch rate.
- **Committing any mined output to the repo** — the insight store is external; cross-repo correlation never lands in-repo.
- **A fabricated labeled fixture corpus** — dropped (gave only controlled-recall at high authoring cost).
- **The full rubric-freeze release-gate / forced gold-set re-run** — that machinery was coupled to the deferred LLM-judge layer; only the lightweight `rubric_version` tag ships here.
- **A charter amendment** — the internal tool is out of NN-C-002 scope by location; no charter change is needed. (An optional one-line NN-C-002 scope clarification is a possible follow-up, not part of this piece.)
- **Cross-machine correlation** — single-machine only (cross-machine is flywheel-global's explicit non-goal too).
- **The EG-1 transitive/by-name closure fix** — ships only as a residual expected-fail probe, not fixed here.

## Requirements

### Functional Requirements

- **SF-1 (internal tool home + shared-lib shape):** Create `tools/transcript-eval/` at the repo root (python 3, pip deps declared in a co-located `requirements.txt` + a one-line setup contract). It is internal-only, not under `plugins/spec-flow/`, not shipped. Its parse/scrub/aggregate core is a reusable lib `flywheel-global` (FR-007) can later import. [FR-017]
- **SF-2 (extraction):** Given a configurable set of project transcript dirs under `~/.claude/projects/`, parse `.jsonl` **best-effort** (probe fields, emit null on miss) to extract, per session: each gate/board-seat dispatch, its findings, and an **inferred operator accept/reject** per finding (heuristic: fix-followed-the-finding ⇒ accepted; operator-dismissed / no-action ⇒ rejected). Report extraction **coverage + confidence** (sessions parsed, fields missed, inference-ambiguous count); never silently drop. [FR-017]
- **SF-3 (gate-effectiveness metrics):** From the extracted data compute, per board seat and per gate: **precision** (accepted ÷ raised), **verdict-overlap** (seats co-finding the same issue), **leave-one-out unique-catch** (accepted findings only one seat raised), **rubber-stamp signals** (an approval recorded with zero reviewer notes, OR emitted within a configurable short dispatch-to-approval interval — default < 60 s — flagged as a candidate rubber-stamp), and **activity** (dispatch counts). These are the FR-016 board-cut evidence. [FR-017, SC-009, G-6]
- **SF-4 (pipeline-health story):** Render a broad cross-repo pipeline-health report from the aggregates. The FR-016 per-seat evidence (SF-3) is a **required** section; the report also surfaces trends/activity/rubber-stamp reads. Every effectiveness number is labeled as **precision-from-real-usage**, never "catch rate." [FR-017, G-6]
- **SF-5 (durable external insight store):** Write run-history, accrued aggregates, and story snapshots to a configurable repo-peer directory (default `/Volumes/joeData/spec-flow-insights/`) **outside repo scope**, with a per-project layout and an append-only run index. The store survives repo wipe / `git clean` / worktree removal. [FR-017]
- **SF-6 (privacy/scrub):** No mined content is ever written into the repo. Cross-repo content (e.g. prop-firm) is confined to the external store and never copied into the ai-plugins tree. Extracted records are scrubbed of secrets per the metrics-artifact no-secrets clause; raw transcripts are never copied or committed. [FR-017]
- **SF-7 (extraction-validation spike — gates the rest):** Before the metric/story layer is built, a spike validates extraction against real sessions: hand-check a sample (≥20 findings across ≥3 sessions / ≥2 repos) and proceed only if seat/finding extraction coverage ≥95% and inferred accept/reject agreement with the hand-check ≥80% (default thresholds, tunable). Below threshold ⇒ halt and redesign the inference before building downstream. [FR-017]
- **SF-8 (recall-honesty):** The tool and the story explicitly state that mining measures precision/overlap/activity, **not** true recall; no output is labeled "catch rate." True recall is sourced only from the cheater track / constructed defects. [SC-009]
- **SF-9 (cheater track — oracle):** A reconstructed bash oracle (under `plugins/spec-flow/tests/e2e/`, pure bash) re-implements the FR-011 predicate (content-hash vs Red manifest; `--name-only` reconciliation; smuggling = manifest ∩ exempt; M3 window; amendment cap) against a tampered HEAD built in `e2e_mktemp` with `trap … EXIT` cleanup. The cheat set covers each of the six FR-017 taxonomy classes ≥1× + the EG-4 flat-path transient-commit cheat (≥10 total), with ≥5 legitimate-refactor allow-set fixtures; every mechanically-detectable scenario is detected (100%); per-scenario detection + false-rejection reported. [PRD-FR-017 AC[4]; EG-4]
- **SF-10 (residual tier):** EG-1 (transitive/by-name closure tamper) ships in a separate documented-residual / expected-fail tier, scored independently and excluded from the 100% headline. [backlog EG-1]
- **SF-11 (EG-2 guardrail fix + locking fixture):** Add an explicit per-sub-phase `exempt_authored` attribution rule at the G9b Phase-Group barrier in `execute/SKILL.md`; ship the multi-sub-phase fixture that exercises it as a *detected* cheat. [backlog EG-2]
- **SF-12 (rubric_version tag):** Add an additive `rubric_version` frontmatter key to every measured gate-agent pair (byte-identical `.md`/`.agent.md`) so mined metrics can be segmented by rubric era. (The full release-gate drift-detector is deferred with the LLM-judge layer.) [FR-017]
- **SF-13 (consuming contract + SC-009 re-scope):** Add the **PRD-FR-017 AC[6]** citation obligation to `reference/gate-scaling.md#board-swap-rule` (a seat-cut/downgrade must cite the mined per-seat precision/overlap/leave-one-out evidence **and** the cheater-track detection); re-scope SC-009 in the PRD to distinguish mined **precision-from-usage** (published) from true **recall** (only from the cheater track / constructed defects), retiring the "100% of gates have a published catch rate" framing. [PRD-FR-017 AC[6]; SC-009]
- **SF-14 (release verification):** Bump the plugin version across all version-bearing files + CHANGELOG; every new/edited agent keeps a bare `name:`; no runtime-dependency artifact under `plugins/spec-flow/` (the python `requirements.txt` lives only under repo-root `tools/`). [NN-C-009, NN-C-001, NN-C-002]

### Non-Functional Requirements

- **SF-NFR-1 (read-only + safe):** The miner is strictly read-only against `~/.claude/projects/`; it never mutates source transcripts. Any temp work is confined to `e2e_mktemp`-style throwaway dirs (cheater track) or the external insight store.
- **SF-NFR-2 (best-effort schema resilience):** `.jsonl` parsing probes fields and emits null on miss; a schema change degrades coverage (reported) rather than crashing or silently mis-scoring.
- **SF-NFR-3 (no false green / honest gaps):** The consumer-surface bash parts honor the `tests/e2e/` never-false-green rule (SKIPPED is inert; `summary()` exits non-zero iff FAILS>0 or ERRORS>0). The python tool reports extraction coverage and never presents a partial mine as complete.
- **SF-NFR-4 (durability):** The insight store path is configurable and validated at startup; if unwritable, the tool fails loudly (no silent in-repo fallback that could leak data).

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-002 (bash-only, no runtime deps — *consumer surface*): every shipped artifact under `plugins/spec-flow/` (cheater oracle, EG-2 edit, `rubric_version` tag) is POSIX bash + markdown/YAML with no runtime deps. The python+pip tool lives at **repo-root `tools/`**, outside NN-C-002's scope (`plugins/<plugin>/`) and outside the shipped distribution — so the end-user zero-install guarantee is unchanged.
- NN-C-001 (plugin/marketplace version sync): SF-14 bumps `plugin.json` + `.claude-plugin/marketplace.json` together; verified by the version-sync diff.
- NN-C-003 (backward-compat additive): new files + an additive optional `rubric_version` key; the one behavior change is the EG-2 G9b attribution tightening (a stricter guardrail-correctness fix, CHANGELOG `### Fixed`).
- NN-C-004 (bare agent `name:`): the `rubric_version` edits keep each agent's `name:` unprefixed.
- NN-C-006 (destructive ops confined): all tampered-HEAD `git`/`rm` runs inside `e2e_mktemp` throwaway repos with `trap … EXIT`; the miner is read-only.
- NN-C-008 (self-contained agents): no agent gains conversation-history assumptions.
- NN-C-009 (version bump): the plugin version is bumped across all version-bearing files + CHANGELOG.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-001 (human sign-off gate never removed): nothing here removes a sign-off gate.
- NN-P-004 (operator-gated): the miner runs out-of-band, operator-invoked; no auto-scaffolding/auto-archival; cross-repo correlation is operator-driven.
- NN-P-005 (Opus thinking / Sonnet mechanics — no silent upgrade): no model is invoked by this piece at all (mining is deterministic parsing; the LLM layer is deferred).

### Coding Rules Honored

- CR-004 (conventional commits): commits use `<type>(spec-flow): …`.
- CR-005 (repo-root-relative paths): all in-repo references are repo-root-relative; the external store path is configurable/absolute.
- CR-008 (thin orchestrator / narrow executor): the miner is a standalone operator tool; no skill gains executor logic and no agent spawns sub-agents.
- CR-009 (heading hierarchy): fixtures and docs keep one H1 / H2 / H3.

## Acceptance Criteria

AC-1: Given a configured project transcript dir under `~/.claude/projects/`, When the transcript-eval tool runs extraction, Then it parses `.jsonl` best-effort and emits, per session, each gate/board-seat dispatch with its findings and an inferred accept/reject per finding, plus an extraction coverage+confidence report; no finding is silently dropped.
  Independent Test [machine: `pytest tools/transcript-eval/` extraction tests pass against committed sample transcript fixtures; assert per-seat finding records + accept/reject field + a coverage report are produced; assert a malformed record yields null fields + a reported miss, not a crash].

AC-2: Given extracted records, When the metric layer runs, Then it computes per-seat precision, verdict-overlap, leave-one-out unique-catch, rubber-stamp signals, and activity, each matching a hand-derived expected on a synthetic fixture.
  Independent Test [machine: `pytest tools/transcript-eval/` metric tests — feed a synthetic extracted-records fixture, assert each metric equals its hand-derived value; assert leave-one-out delta is computed per seat].

AC-3: Given computed aggregates, When the story report is rendered, Then it contains a required FR-016 per-seat evidence section, surfaces broad pipeline-health reads, and labels every effectiveness number as precision-from-usage (never "catch rate").
  Independent Test [machine: render the report on a fixture; grep the FR-016 evidence section header and assert no occurrence of "catch rate" / "recall" mislabel] + [judgment: operator confirms the story is accurate and decision-useful].

AC-4: Given a run, When outputs are written, Then run-history + aggregates + story land in the configured repo-peer insight store (default `/Volumes/joeData/spec-flow-insights/`), outside repo scope, and nothing mined is written under the repo; an unwritable store fails loudly.
  Independent Test [machine: run against a temp store path; assert files appear there and `git status` in the repo shows no new mined content; point the store at an unwritable path → assert a loud non-zero failure, no in-repo fallback].

AC-5: Given cross-repo source data including a sensitive repo, When the tool runs, Then extracted records are scrubbed of secrets and cross-repo content stays in the external store; no raw transcript is copied and no cross-repo content enters the ai-plugins tree.
  Independent Test [machine: run across ≥2 project dirs into a temp store; grep the in-repo tree for any mined/transcript content → none; assert a secret-shaped token in a fixture transcript is scrubbed in the stored output] + [judgment: operator confirms no prop-firm content reached the repo].

AC-6: Given the extraction-validation spike, When it runs against real sessions, Then it hand-checks ≥20 findings across ≥3 sessions / ≥2 repos and reports seat/finding extraction coverage and accept/reject inference agreement; the downstream metric/story build proceeds only when coverage ≥95% and agreement ≥80% (else it halts with the gap named).
  Independent Test [judgment: operator reviews the spike report and confirms the coverage/agreement numbers + the gate decision] + [machine: assert the spike emits coverage% + agreement% fields and a PROCEED/HALT verdict].

AC-7: Given a tampered HEAD constructed in `e2e_mktemp`, When the cheater oracle runs, Then the cheat set covers each of the six FR-017 taxonomy classes ≥1× plus the EG-4 transient-commit cheat (≥10 total), each mechanically-detectable cheat is detected (100%), ≥5 legitimate-refactor allow-set fixtures pass, per-scenario detection + false-rejection are reported, and `$TMPDIR` is clean after a forced mid-scenario abort (trap fired).
  Independent Test [machine: `bash plugins/spec-flow/tests/e2e/lib/cheater-oracle.sh` — assert per-class coverage ≥1×, 10/10 detection, 0/5 false-rejection, and a clean `$TMPDIR` after a forced abort].

AC-8: Given the EG-1 transitive/by-name closure-tamper probe, When the suite runs, Then it lives in a separate documented-residual / expected-fail tier, scored independently and excluded from the 100% headline.
  Independent Test [machine: assert the residual-tier fixture is reported under a distinct tier label and its result does not enter the 100%-detection headline].

AC-9: Given a multi-sub-phase Phase Group where sub-phase A declares an `exempt_authored` path that sub-phase B tampers, When the G9b barrier re-hash runs after the EG-2 attribution-rule fix, Then the cross-sub-phase exemption is rejected (the tamper is caught) and the locking fixture passes as a detected cheat.
  Independent Test [machine: grep the per-sub-phase attribution-rule anchor in `execute/SKILL.md`; assert the EG-2 multi-sub-phase oracle scenario reports DETECTED, not residual].

AC-10: Given the piece is complete, When the measured gate-agent pairs are inspected, Then each carries a byte-identical additive `rubric_version` frontmatter key (no other frontmatter change).
  Independent Test [machine: `grep -L 'rubric_version:'` over the measured agent pairs returns nothing; `diff` of each `.md`/`.agent.md` pair is empty].

AC-11: Given the piece is complete, When the consuming/SSOT surfaces are inspected, Then `reference/gate-scaling.md#board-swap-rule` carries the citation obligation (mined per-seat evidence + cheater detection) and SC-009 in the PRD is re-scoped to distinguish precision-from-usage from true recall (no "published catch rate" claim).
  Independent Test [machine: grep the citation anchor + the leave-one-out reference in gate-scaling.md; grep SC-009 for the precision-vs-recall distinction and absence of "catch rate"] + [judgment: operator confirms the SC-009 re-scope wording is accurate].

AC-12: Given the merged piece, When release verification runs, Then the plugin version is bumped in all version-bearing files with a CHANGELOG entry, every new/edited agent has a bare `name:`, and no runtime-dependency artifact exists under `plugins/spec-flow/` (the python `requirements.txt` exists only under repo-root `tools/`).
  Independent Test [machine: NN-C-001 version-sync `diff` is empty; `grep -E "^name:\s*spec-flow-" agents/*` returns nothing; assert no `requirements.txt`/`package.json` under `plugins/spec-flow/`, and that `tools/transcript-eval/requirements.txt` exists].

## Technical Approach

Two cleanly separated halves. **(1) Internal mining tool** at repo-root `tools/transcript-eval/` (python 3 + pip): a parse/scrub/aggregate lib + a CLI, reading `~/.claude/projects/<project>/*.jsonl` read-only, writing only to the external insight store. The `.jsonl` schema is undocumented/unstable, so extraction is best-effort with explicit coverage reporting — and an up-front spike (SF-7/AC-6) proves extraction quality on real sessions before the metric/story layer is built. The metric set deliberately measures **precision/overlap/leave-one-out/activity** — real-usage signal — and is explicit that this is **not recall**. The lib is structured for reuse by `flywheel-global` (FR-007). **(2) Consumer-surface guardrail evals** under `plugins/spec-flow/tests/e2e/` (pure bash, reusing `assert.sh` vocabulary, `e2e_mktemp`, `trap … EXIT`): the cheater track (the deterministic recall floor for the FR-011 guardrails), the EG-1 residual tier, and the EG-2 fix + locking fixture. The `rubric_version` tag, the gate-scaling citation, the SC-009 re-scope, and the version bump complete the contract. Privacy is structural: the only writable output target is the external repo-peer store; the repo never receives mined content.

## Testing Strategy

- **Tool (python):** `pytest` under `tools/transcript-eval/` — extraction against committed sample transcript fixtures (incl. malformed-record + secret-scrub cases), metric math against hand-derived synthetic fixtures, store-path + privacy assertions (no in-repo writes; loud failure on unwritable store).
- **Cheater track (bash):** the reconstructed-oracle self-test mirroring `tests/e2e/self/` — per-class coverage, 100% detection, allow-set 0 false-rejection, trap cleanup, residual-tier accounting, EG-2 detected-not-missed (incl. a pre-fix simulation proving the fix is load-bearing).
- **Spike (operator-gated):** the SF-7 extraction-validation report reviewed by the operator against the coverage/agreement gate.
- **Capability/honesty:** explicit cases for partial extraction (reported, never false-green) and an unwritable store.

## Integration Coverage

- Integration: cheater-oracle → FR-011 live predicate — inside:{reconstructed bash oracle, `execute/SKILL.md` predicate}; doubled external:{the FR-011 predicate is re-implemented as the oracle — contract-tested by the same `sha256` shim the live gate uses}; AC-7, AC-9; completes phase (plan-assigned).
- Integration: transcript-eval lib → external insight store — inside:{parse/scrub/aggregate lib, store writer}; doubled external:{the filesystem store is the recorded boundary — privacy-bound per SF-6}; AC-1, AC-4, AC-5; completes phase (plan-assigned).

## Open Questions

- OQ-1: The accept/reject inference is heuristic (fix-followed-finding vs dismissed). The SF-7 spike sets the agreement gate (≥80% default); if real sessions come in below it, the inference design — not just the threshold — is revisited at plan time. (Default: spike-gated; halt-and-redesign below threshold.)
- OQ-2: Exact external store layout (per-project subdirs, run-index format) is a plan-time detail within the SF-5 contract. (Default: per-project dir + append-only run index + latest-story snapshot; plan sets concrete filenames.)
- OQ-3: This piece deliberately overlaps `flywheel-global` (FR-007) on the shared mining lib. The boundary is: gate-evals builds + first-consumes the lib; flywheel-global later imports it for cross-install pattern correlation. (Default: shared lib in `tools/transcript-eval/`, owned here, consumed there.)
