---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
tdd: false
fast: false
---

# Plan: outcome-campaign

**PRD Sections:** FR-020, SC-010, SC-005, G-7
**Spec:** docs/prds/exec-ready/specs/outcome-campaign/spec.md
**Piece class:** behavior-bearing (markdown/config plugin work — Implement track + Write-Tests)

## Overview

Ship the single-pass v1 of `spec-flow:campaign` — a new gate class that runs a target system on Sonnet, grades its real output with three new Opus lens agents against an oracle, verifies each finding (theater guard) before routing it through `/spec-flow:triage`, and records `source: campaign` to metrics + flywheel. The work is entirely markdown + config + bash (no runtime code, NN-C-002), built inside-out: reference-doc contracts first (Phase 1), then the agents that consume them (Phase 2), then the orchestrating skill (Phase 3, the completing phase for the campaign→triage integration), then the config contract (Phase 4), then packaging + the persistent test suite + fixtures (Phases 5–6).

**Non-TDD mode:** all phases use Implement track ([Implement] → [Write-Tests] → [Verify]); AC Coverage Matrix is required (kept for traceability — this piece is behavior-bearing and grades against an oracle). Tests for markdown-plugin work are grep/awk assertions added to `plugins/spec-flow/tests/e2e/lib/static.sh` (`l1_static_checks()`) plus judgment fixtures under `tests/fixtures/outcome-campaign/`. Each phase appends its own assertions to `static.sh`; phases are flat and sequential (no Phase Group), so the shared-file appends never race. A cross-phase consistency `[Verify]` in Phase 6 confirms the full campaign assertion set is present (FR-PROC-01).

**Charter cross-cutting invariants:** NN-C-002 (markdown/bash only — no runtime deps) and NN-C-003 (additive/backward-compat) are piece-wide and hold in every phase. To satisfy the one-phase-per-entry allocation rule they are each cited canonically once — NN-C-003 in Phase 1 (the additive schema edits), NN-C-002 in Phase 3 (the markdown skill) — rather than repeated per phase; no phase violates either.

**Three corrections folded in from Phase-1 exploration:** (1) `.spec-flow.yaml` is gitignored — the `campaign:` keys are documented in the committed SSOT `plugins/spec-flow/templates/pipeline-config.yaml`, NOT a created `.spec-flow.yaml`; the skill treats absent keys as SKIPPED/refuse. (2) Pre-existing version drift (`plugin.json` 5.19.0 vs the other three 5.20.0) is reconciled — all four → 5.21.0. (3) The per-finding VERIFY is a 4th agent `campaign-verify.md` (self-contained, NN-C-008); all four new agents need `.agent.md` symlinks or the static.sh symlink-count guard fires.

## Architectural Decisions

### ADR-1: New `campaign-*` lens agents, not an output-mode on the shared review-board agents
**Context:** the campaign lenses grade run output vs an oracle; the existing `review-board-{ground-truth,integration,edge-case}` agents are diff-bound and co-owned by execute Final Review + the review-board skill.
**Decision:** create three NEW agents (`campaign-ground-truth`, `campaign-seam`, `campaign-edge-case`) plus a VERIFY agent (`campaign-verify`). Do NOT add a "Campaign mode" to the shared agents.
**Alternatives considered:** output-graded mode on the 3 existing agents (rejected — mutating shared agents live in two call sites is a regression surface); a single monolithic campaign-judge (rejected — collapses lens diversity R16, breaches ≤2K return NFR-001).
**Consequences:** zero regression surface on existing reviewers; 4 new files + 4 symlinks to maintain.
**Charter alignment:** NN-C-003 (additive), NN-C-008 (self-contained), CR-008 (narrow executors). Resolves deliberation Fork F1.

### ADR-2: Theater-guard VERIFY realized as a dedicated agent `campaign-verify.md`
**Context:** FR-C5 requires a per-finding skeptic VERIFY before a finding becomes a triage item; CR-008 forbids an agent dispatching sub-agents, so the verify LOOP must be skill-orchestrated.
**Decision:** the skill orchestrates the loop and dispatches a dedicated `campaign-verify.md` agent (model: opus) once per finding; precision-biased (route only if VERIFY confirms).
**Alternatives considered:** inline composed verify prompt in the skill (rejected — less self-contained, harder to grep/test); majority-vote jury (rejected — cost > bounded goal, deliberation NON-VIABLE).
**Consequences:** the spec's "three lens agents" + one verify agent = 4 new agents; AC-7 greps the skill's verify gate + the agent file.
**Charter alignment:** CR-008 (skill orchestrates, agent executes one task), NN-C-008, NN-P-005 (Opus judgment).

### ADR-3: Campaign config documented in `templates/pipeline-config.yaml`, not a created `.spec-flow.yaml`
**Context:** `.spec-flow.yaml` is gitignored; the committed config SSOT is `plugins/spec-flow/templates/pipeline-config.yaml` (CR-007). Creating a `.spec-flow.yaml` would not persist (gitignored) and repeats the flywheel-repo gitignore defect.
**Decision:** document the `campaign:` block (entrypoint, run_mode) with CR-007 inline comments in `templates/pipeline-config.yaml`; the skill reads the user's `.spec-flow.yaml` at runtime, treating absent `campaign.entrypoint` as SKIPPED and absent `run_mode` as refuse-to-run.
**Alternatives considered:** create root `.spec-flow.yaml` (rejected — gitignored, non-persistent); skill-only handling with no documented template (rejected — CR-007 requires documented config keys).
**Consequences:** absent-key behavior is the backward-compatible default; no gitignored file is committed.
**Charter alignment:** NN-C-003, CR-007.

### ADR-4: Reconcile the pre-existing version drift while bumping
**Context:** `plugins/spec-flow/plugin.json` is at 5.19.0 while `.claude-plugin/plugin.json`, `marketplace.json`, and CHANGELOG are at 5.20.0 — a pre-existing NN-C-009 violation. `static.sh` version assertions still hardcode 5.19.0.
**Decision:** bump all four version-bearing files to 5.21.0 (minor — new skill + agents) and update the `static.sh` version assertions to 5.21.0, fixing the drift in the same commit (NFR-004 "corrected when first touched").
**Alternatives considered:** bump only from each file's current value (rejected — leaves drift; static.sh stays stale).
**Consequences:** all version strings converge at 5.21.0; the static.sh guard passes.
**Charter alignment:** NN-C-001 (sync), NN-C-009 (bump all version-bearing files), NFR-004.

## Phases

### Phase 1: Reference-doc contracts (additive)
**In scope:** `reference/triage-contract.md` (remove stale placeholder; add `bug_classified` to Form B/C schema; add campaign to Consumed-by), `reference/metrics-artifact.md` (additive `findings_by_source` block doc), `reference/flywheel.md` (add `campaign` to source_type in both places + header).
**NOT in scope:** the campaign skill that consumes these (Phase 3); static.sh version/symlink edits (Phase 5/6).
**ACs Covered:** AC-10 (partial — the metrics+flywheel contract surface), AC-11 (the `bug_classified` contract).
**Charter constraints honored in this phase:** NN-C-003 (additive, schema_version unchanged), NN-P-006 (red-first stamp surface for campaign bug findings via BRF-3 field), CR-009 (heading hierarchy).
**Steps traversed (P2):** N/A (reference docs are not multi-step orchestration files). **Dispatch sites (P3):** none.

- [x] **[Implement]**
  **File changes:** triage-contract.md (MODIFY), metrics-artifact.md (MODIFY), flywheel.md (MODIFY)

  T-1: MODIFY `plugins/spec-flow/reference/triage-contract.md`
  Anchor: `## Red-first obligation` section, last sentence (line ~51).
  CURRENT:
  ```
  A non-reproducible defect routes to `[SPIKE]` or records an explicit no-repro rationale. Campaign (FR-020) reach remains forward-record only (the campaign skill does not exist).
  ```
  TARGET: replace the final sentence with: `A non-reproducible defect routes to [SPIKE] or records an explicit no-repro rationale. Campaign (FR-020) findings route through this contract as a Form C batch (see `## Consumed by`): a bug-classified campaign finding routed to a fix disposition is stamped red-first like any other.`
  Done: the "the campaign skill does not exist" placeholder is gone.
  Verify: `grep -q "does not exist" plugins/spec-flow/reference/triage-contract.md` returns NO match.

  T-2: MODIFY `plugins/spec-flow/reference/triage-contract.md`
  Anchor: the Form B field documentation (add a `## Form B/C schema` note if the field list is not already in this file; the field list currently lives in triage/SKILL.md Step 1).
  TARGET: add a subsection documenting the campaign-source Form B field set and the new `bug_classified: <bool>` field — "Form B accepts an optional `bug_classified: true|false` set explicitly by an external caller (the campaign); when present it pre-seeds the Step-2 bug-signal result so triage applies the NN-P-006 red-first stamp without re-deriving it from keywords. Absent ⇒ triage derives `bug_classified` from its own bug-signal scan (backward-compatible)." Cite BRF-3.
  Done: `bug_classified` is a documented Form B/C field with the absent-default rule.
  Verify: `grep -q "bug_classified" plugins/spec-flow/reference/triage-contract.md` returns a match.

  T-3: MODIFY `plugins/spec-flow/reference/triage-contract.md`
  Anchor: `## Consumed by` (line ~70).
  CURRENT: lists triage/SKILL.md + execute/SKILL.md Step 6c.
  TARGET: add `plugins/spec-flow/skills/campaign/SKILL.md` (the FR-020 Form C producer) to the consumer list.
  Done: campaign appears in `## Consumed by`. Verify: `grep -q "campaign/SKILL.md" plugins/spec-flow/reference/triage-contract.md`.

  T-4: MODIFY `plugins/spec-flow/reference/metrics-artifact.md`
  Anchor: the schema block (after the existing `gate_scaling` example, ~line 77).
  TARGET: add a documented additive block (schema_version unchanged):
  ```yaml
  findings_by_source:
    campaign:
      total: 3              # findings emitted by campaign lenses
      verified: 2           # findings confirmed by the theater-guard VERIFY pass
      suppressed: 1         # findings VERIFY did not confirm (precision-biased)
      routed_to_triage: 2   # findings handed to /spec-flow:triage as a Form C batch
      dispatches: { lens: 3, verify: 2 }  # Opus dispatches (lens always 3 in v1; verify = 1 per surviving finding)
  ```
  plus one prose line: "`findings_by_source` is additive passive metadata (NN-C-003, schema_version unchanged); written by `spec-flow:campaign`; existing readers ignore unknown blocks. Degraded path: `[METRICS-DEGRADED]`."
  Done: the block + prose exist. Verify: `grep -q "findings_by_source" plugins/spec-flow/reference/metrics-artifact.md`.

  T-5: MODIFY `plugins/spec-flow/reference/flywheel.md`
  Anchor 1: the inline `source_type` enum comment (line ~33). CURRENT: `one of reflection-finding | execute-discovery | metric`. TARGET: `... | metric | campaign`.
  Anchor 2: the `## Source taxonomy` table (lines ~67–77). TARGET: add a 4th row `| campaign | **WIRED** | Findings from spec-flow:campaign's theater-guard VERIFY pass, recorded as occurrences via the existing operator-confirmed match/confirm flow (NN-P-004). See plugins/spec-flow/skills/campaign/SKILL.md. |`. Update the header parenthetical `(schema-open, wire-narrow)` → `(schema-open)`.
  Done: `campaign` appears in BOTH the inline comment and the taxonomy table.
  Verify: `grep -c "campaign" plugins/spec-flow/reference/flywheel.md` returns ≥ 2.

**Test Data:** (each case = grep pattern + target file → expected match/no-match; the [Write-Tests] assertions below carry these inputs+oracles inline)
- TD-1 (AC-11 placeholder removed): `grep "does not exist" reference/triage-contract.md` → expect NO match
- TD-2 (AC-11 bug_classified field): `grep "bug_classified" reference/triage-contract.md` → expect match
- TD-3 (AC-10 findings_by_source block): `grep "findings_by_source" reference/metrics-artifact.md` → expect match
- TD-4 (AC-10 campaign source_type, 2 places): `grep -c "campaign" reference/flywheel.md` → expect ≥ 2

- [x] **[Write-Tests]** Append to `l1_static_checks()` in `plugins/spec-flow/tests/e2e/lib/static.sh`:
  `assert_no_grep "does not exist" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-11: campaign placeholder removed"`;
  `assert_grep "bug_classified" "${PLUGIN_ROOT}/reference/triage-contract.md" "AC-11: bug_classified Form B/C field"`;
  `assert_grep "findings_by_source" "${PLUGIN_ROOT}/reference/metrics-artifact.md" "AC-10: findings_by_source block"`;
  `assert_grep "campaign" "${PLUGIN_ROOT}/reference/flywheel.md" "AC-10: campaign source_type"`.
- [x] **[Verify]** Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` (L1 static) — Expected: the 4 new assertions PASS; `0 failed` in the L1 summary. And: `grep -c "campaign" plugins/spec-flow/reference/flywheel.md` — Expected: ≥ 2.
- [x] **[QA]** Review against AC-10 (contract surface), AC-11 (bug_classified). Diff baseline: phase_1_start_sha.

**Exit Gate:** all four reference-doc edits landed and grep-verified; L1 static passes; the campaign placeholder is removed.

---

### Phase 2: Campaign lens + verify agents (CREATE)
Why serial: four small, near-identical CREATE files whose [Write-Tests] each append assertions to the shared `static.sh`; parallel sub-phases would race on that file, and the per-file authoring cost is trivial — sequential authoring avoids the race with no meaningful wall-clock cost.
**In scope:** CREATE `agents/campaign-ground-truth.md`, `campaign-seam.md`, `campaign-edge-case.md`, `campaign-verify.md` (+ their `.agent.md` symlinks).
**NOT in scope:** the skill that dispatches them (Phase 3); the static.sh symlink-count guard bump (Phase 5).
**ACs Covered:** AC-6 (3 grading lens agents), AC-7 (partial — the verify agent), AC-5 (partial — agents carry `model: opus`).
**Charter constraints honored in this phase:** NN-C-004 (bare `name:`), NN-C-008 (self-contained), CR-001 (frontmatter). (The Sonnet-run/Opus-grade non-negotiable is cited canonically in Phase 3 — the agents' `model: opus` frontmatter here supports it.)
**Steps traversed (P2):** N/A. **Dispatch sites (P3):** none (these are dispatched BY the Phase-3 skill, authored there).

- [x] **[Implement]**
  **File changes:** campaign-ground-truth.md (CREATE), campaign-seam.md (CREATE), campaign-edge-case.md (CREATE), campaign-verify.md (CREATE), + 4 `.agent.md` symlinks (CREATE)

  T-1..T-3: CREATE the three lens agents. Pattern to follow (adapt `plugins/spec-flow/agents/review-board-ground-truth.md` — same rubric/probe structure, read-only, ≤2K return), with these REQUIRED differences:
  - Frontmatter: `name: campaign-<lens>` (bare, NN-C-004), `description: "Internal agent — dispatched by spec-flow:campaign. Do NOT call directly. Grades a running system's captured output against an injected oracle for the <lens> lens. Read-only; dispatches no sub-agents."`, `model: opus`.
  - Replace the diff-bound "Context Provided" with: **Context Provided = the captured run OUTPUT (stdout/artifacts from the Sonnet system run) + the injected ORACLE block (in-scope FR-018 outcome ACs by ID + declared money/safety rules).** State explicitly the agent grades RUN OUTPUT, not a git diff.
  - Collapse Input Modes to a single run-output grading mode (no iteration-2 focused mode).
  - Lens-specific rubric: ground-truth = result degeneracy / dead-knob (does any output column report a forced/constant value while appearing earned?); seam = cross-piece integration behavior on run output (consumes the target's declared `## Integration Coverage` seam inventory — does NOT re-derive boundaries); edge-case = boundary/regime behavior at the envelope.
  - Keep the read-only "does NOT run code / dispatches no sub-agents" statements and the ≤2K return contract. Each finding returned with: lens, finding text, the output evidence, the oracle AC id it violates (or "no-oracle" for ground-truth degeneracy).
  Done (per file): the agent file exists with bare `name: campaign-<lens>`, `model: opus`, grades run output vs oracle, ≤2K return.
  Verify (per file): `grep -q "^name: campaign-<lens>" plugins/spec-flow/agents/campaign-<lens>.md` AND `grep -q "model: opus" plugins/spec-flow/agents/campaign-<lens>.md`.

  T-4: CREATE `plugins/spec-flow/agents/campaign-verify.md` (the theater-guard skeptic).
  Frontmatter: `name: campaign-verify`, `model: opus`, description noting it independently refutes a single campaign finding. Body: given ONE finding (lens + output evidence + cited oracle AC), attempt to REFUTE it; return CONFIRMED only if the finding independently holds against the evidence, else REFUTED with reason. Precision bias: default to REFUTED when the evidence does not independently support the finding. Read-only, dispatches nothing, ≤2K return.
  Done: file exists, bare name, model opus, precision-biased refute contract. Verify: `grep -q "^name: campaign-verify" ...` AND `grep -qi "refute\|REFUTED\|CONFIRMED" plugins/spec-flow/agents/campaign-verify.md`.

  T-5: CREATE the 4 `.agent.md` symlinks (mirror convention — each `<name>.agent.md -> <name>.md`):
  `ln -s campaign-ground-truth.md plugins/spec-flow/agents/campaign-ground-truth.agent.md` (and the same for seam, edge-case, verify).
  Done: 4 symlinks exist pointing to their `.md`. Verify: `ls -l plugins/spec-flow/agents/campaign-*.agent.md` shows 4 symlinks.

**Test Data:** (per-agent grep cases → expected outcome)
- TD-1 (AC-6/AC-7 each agent exists, bare name): `grep "^name: campaign-<x>" agents/campaign-<x>.md` for x ∈ {ground-truth, seam, edge-case, verify} → expect match (4 cases)
- TD-2 (AC-5 Opus tier): `grep "model: opus" agents/campaign-<x>.md` (each) → expect match
- TD-3 (AC-12 no plugin prefix): `grep -E "^name:\s*spec-flow-" agents/campaign-<x>.md` (each) → expect NO match
- TD-4 (symlinks): `ls agents/campaign-*.agent.md | wc -l` → expect 4

- [x] **[Write-Tests]** Append to `l1_static_checks()`:
  for each of the 4 agents `assert_grep "^name: campaign-<x>" "${PLUGIN_ROOT}/agents/campaign-<x>.md" "AC-6/AC-7: campaign-<x> agent"` and `assert_grep "model: opus" ...`;
  `assert_no_grep "^name:\s*spec-flow-" "${PLUGIN_ROOT}/agents/campaign-ground-truth.md" "AC-12: bare name (no plugin prefix)"` (repeat per agent).
- [x] **[Verify]** Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` — Expected: the new agent assertions PASS, `0 failed`. And: `ls plugins/spec-flow/agents/campaign-*.agent.md | wc -l` — Expected: `4`.
- [x] **[QA]** Review against AC-6, AC-7 (verify agent), AC-5 (model: opus), AC-12 (bare names). Diff baseline: phase_2_start_sha.

**Exit Gate:** 4 agent files + 4 symlinks exist; each grades run output vs oracle (lenses) / refutes a finding (verify); all carry bare `name:` + `model: opus`; L1 static passes.

---

### Phase 3: Campaign SKILL.md — the orchestrator (completing phase for campaign→triage)
**In scope:** CREATE `plugins/spec-flow/skills/campaign/SKILL.md` (the full Step 0–6 orchestrator: config + oracle resolution + run-safety + Sonnet run + Opus lens dispatch + theater-guard verify loop + Form C triage route + metrics/flywheel recording + Boundaries).
**NOT in scope:** the agents (Phase 2, dispatched here); reference contracts (Phase 1, consumed here); config template (Phase 4); fixtures + packaging (Phases 5–6).
**ACs Covered:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-7, AC-8 (completing), AC-9, AC-10 (the recording call sites).
**Charter constraints honored in this phase:** CR-008 (thin orchestrator; the verify loop is here, not in an agent), CR-002 (skill frontmatter), NN-P-001 (operator gates), NN-P-002 (findings route out, no patch), NN-P-004 (operator-confirmed triage + flywheel), NN-P-005 (Sonnet run / Opus grade), NN-C-002 (markdown/bash only), NN-C-006 (pre-run confirm of the side-effecting run), CR-005 (repo-root paths).
**Steps traversed (P2):** this CREATEs a multi-step orchestration file (≥3 Step headings) — its own Steps 0–6 are the full traversal; no pre-existing loop is mutated (new file). **Dispatch sites (P3):** the skill is the sole dispatch site for `campaign-{ground-truth,seam,edge-case,verify}` (model: opus) and the `/spec-flow:triage` Form C invocation; no other site dispatches these.
phase_size_override: the campaign SKILL.md is one cohesive orchestration file; splitting its sections across sub-phases would fragment checkpoints and leave a half-wired skill at phase boundaries. Authored as one phase mirroring review-board/SKILL.md's structure.

- [x] **[Implement]** CREATE `plugins/spec-flow/skills/campaign/SKILL.md`. Mirror `plugins/spec-flow/skills/review-board/SKILL.md` Step 0–6 skeleton + `## Boundaries`. Sections:
  - **Frontmatter (CR-002):** `name: campaign`, `description:` (when-to-use: "run the results campaign", "grade a running system's output", "adversarial validation of a pilot/backtest/e2e against the spec's outcome ACs"; out-of-band like review-board).
  - **Step 0 — Load config + git check:** read `.spec-flow.yaml` best-effort (docs_root); confirm git repo. Read `campaign.entrypoint` and `campaign.run_mode`. **Absent `campaign.entrypoint` ⇒ emit `SKIPPED: no-entrypoint (campaign unavailable)` and STOP (not an error).** **Absent `campaign.run_mode` ⇒ REFUSE: "campaign.run_mode is required (dry-run|sandbox|live); set it in .spec-flow.yaml and re-run." STOP.**
  - **Step 1 — Resolve target + oracle:** take the target piece-set / system entrypoint arg. Resolve the ORACLE BY ID: in-scope FR-018 outcome ACs from the target piece-set's `spec.md` files (by AC id, NOT re-derived) + declared product money/safety rules. **If no in-scope outcome ACs resolve AND no money/safety rules ⇒ the oracle is empty: oracle-bound lenses (seam, edge-case) will emit `SKIPPED: no-oracle`; the ground-truth lens still runs (degeneracy needs no oracle).** Assemble the oracle as a delimited data block for injection.
  - **Step 2 — Run-safety gate (NN-C-006 / risk lens):** resolve the exact run command from `campaign.entrypoint` (+ `--run` override). **Confirm the exact resolved command with the operator before first execution** (show precisely what bash will run). `run_mode: live` requires explicit operator opt-in; `dry-run`/`sandbox` proceed after the confirm. Capability-detect each declared stage (pilot/backtest/e2e); a stage that cannot run emits `SKIPPED: <capability>` and the campaign continues (never whole-run failure, never false-green).
  - **Step 3 — Run on Sonnet:** execute the confirmed command from the main window (Sonnet — execution/observation need no Opus, NN-P-005); capture stdout + named output artifacts into a run-output buffer. Do NOT dispatch the run to an Opus sub-agent.
  - **Step 4 — Dispatch Opus lenses (parallel):** prepend the verbatim `WORKTREE:` dispatch preamble (from coordinator-contract.md). Dispatch `campaign-ground-truth`, `campaign-seam`, `campaign-edge-case` concurrently with `model: "opus"`, each injected with {run-output buffer + oracle block}. v1 runs all three always-on; an omission-reporting hook emits `conditional-activation: not-yet-available (FR-016b unshipped)` and reports any non-activated lens — **never silently drop a lens/seat**. Oracle-bound lenses emit `SKIPPED: no-oracle` when the oracle is empty.
  - **Step 5 — Theater-guard VERIFY (per finding):** for EACH lens finding, dispatch `campaign-verify` (model: "opus", WORKTREE preamble) with the single finding + its output evidence + cited oracle AC. **Precision-biased: route ONLY findings VERIFY returns CONFIRMED; suppress (drop) REFUTED/unconfirmed findings** (documented tradeoff — the campaign feeds expensive fix work and is re-runnable). The verify loop is orchestrated HERE (CR-008).
  - **Step 6 — Route via triage + record:** assemble surviving CONFIRMED findings as triage Form B records (`source_phase: campaign`, `source_agent: <lens>`, `finding_text`, `discovery_type: degeneracy|seam|edge-case`, `bug_classified: <bool>`) into a single Form C batch and invoke `/spec-flow:triage` (single aggregated confirm, NN-P-004). The campaign NEVER patches the target (NN-P-002); a bug-classified finding becoming a fix is stamped red-first by triage Step 7 (NN-P-006). Then record: `source: campaign` to the piece `metrics.yaml` `findings_by_source` block (`[METRICS-DEGRADED]` safe) and a `campaign` source_type occurrence to the flywheel via the existing operator-confirmed flow (`[FLYWHEEL-DEGRADED]` safe). **No secrets:** findings + metrics records never transcribe sensitive output values verbatim.
  - **`## Boundaries`:** no merge; no pipeline mutation beyond the recorded triage disposition; NEVER patches/edits the target; changes NO version-bearing file when run; the convergence loop (Pass A/B re-hunt) is NOT in v1 — it lives in `campaign-converge`.
  Pattern (verbatim from review-board/SKILL.md Step 3 dispatch idiom):
  ```
  Agent({ description: "...", prompt: <WORKTREE preamble + agent template + injected context>, model: "opus" })
  ```

- [x] **[Integration-Test]** (completes_in_phase: 3) Boundary: {campaign skill → `/spec-flow:triage`}. Author the outer wiring assertion: the skill contains the Form C invocation of `/spec-flow:triage` with the campaign-source Form B fields. Doubled true external: the triage skill (contract-tested via the AC-8 fixture authored in Phase 6). Add to `l1_static_checks()`: `assert_grep "spec-flow:triage" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-8: campaign→triage Form C wiring"` and `assert_grep "Form C" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-8: Form C batch"`.
**Test Data:** (grep pattern + skills/campaign/SKILL.md → expected outcome)
- TD-1 (AC-1 frontmatter): `grep "name: campaign"` → match
- TD-2 (AC-2/AC-3 no-oracle): `grep "SKIPPED: no-oracle"` → match
- TD-3 (AC-4 run-safety): `grep "run_mode"` + `grep "before first execution"` + `grep "live"` → all match (3 cases)
- TD-4 (AC-5 Opus dispatch): `grep 'model: "opus"'` → match
- TD-5 (AC-7 verify gate): `grep "campaign-verify"` + `grep "CONFIRMED"` → match
- TD-6 (AC-9 seat omission): `grep "conditional-activation: not-yet-available"` → match
- TD-7 (AC-10 recording): `grep "findings_by_source\|source: campaign"` + `grep "METRICS-DEGRADED"` + `grep "FLYWHEEL-DEGRADED"` → all match
- TD-8 (AC-8 integration): `grep "spec-flow:triage"` + `grep "Form C"` → match

- [x] **[Write-Tests]** Append to `l1_static_checks()`:
  `assert_grep "name: campaign" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-1: skill frontmatter"`;
  `assert_grep "SKIPPED: no-oracle" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-2/AC-3: no-oracle skip"`;
  `assert_grep "run_mode" "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-4: run_mode gate"` + `assert_grep "before first execution" ... "AC-4: pre-run confirm"` + `assert_grep "live" ... "AC-4: live opt-in"`;
  `assert_grep 'model: "opus"' "${PLUGIN_ROOT}/skills/campaign/SKILL.md" "AC-5: Opus lens dispatch"`;
  `assert_grep "campaign-verify" ... "AC-7: theater-guard verify"` + `assert_grep "CONFIRMED" ... "AC-7: confirmed-only routing"`;
  `assert_grep "conditional-activation: not-yet-available" ... "AC-9: seat omission reported"`;
  `assert_grep "findings_by_source\|source: campaign" ... "AC-10: metrics recording"` + `assert_grep "METRICS-DEGRADED" ...` + `assert_grep "FLYWHEEL-DEGRADED" ...`.
- [x] **[Verify]** Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` — Expected: all Phase-3 assertions PASS, `0 failed`. LLM-agent-step: read `plugins/spec-flow/skills/campaign/SKILL.md` and confirm Step 3 runs the system on Sonnet (main window) while Steps 4–5 dispatch `model: "opus"` — confirm no path runs the target system inside an Opus sub-agent (NN-P-005).
- [x] **[QA]** Review against AC-1, AC-2, AC-3, AC-4, AC-5, AC-7, AC-8, AC-9, AC-10. Diff baseline: phase_3_start_sha.

**Exit Gate:** campaign/SKILL.md exists, mirrors the review-board skeleton, wires run-safety + oracle + Sonnet-run + Opus lenses + verify loop + Form C triage + recording + Boundaries; the campaign→triage integration assertion passes; L1 static passes.

---

### Phase 4: Campaign config contract (template)
**In scope:** MODIFY `plugins/spec-flow/templates/pipeline-config.yaml` — add the documented `campaign:` block (CR-007 inline comments).
**NOT in scope:** any `.spec-flow.yaml` (gitignored — ADR-3); skill enforcement (Phase 3).
**ACs Covered:** AC-4 (partial — the documented run_mode contract the skill enforces).
**Charter constraints honored in this phase:** CR-007 (inline config docs). (The additive-optional-key and markdown-only piece-wide invariants are cited canonically in Phases 1 and 3 — see the Overview cross-cutting note.)
**Steps traversed (P2):** N/A. **Dispatch sites (P3):** none.

- [x] **[Implement]**
  T-1: MODIFY `plugins/spec-flow/templates/pipeline-config.yaml` — append a `campaign:` block:
  ```yaml
  # campaign: configures spec-flow:campaign — the running-system results gate (new in v5.21.0)
  #   Out-of-band gate; reads these keys from the project .spec-flow.yaml at run time.
  # campaign:
  #   entrypoint: ""        # (string) bash command that runs the target system (pilot/backtest/e2e).
  #                          #   Absent ⇒ campaign is SKIPPED/unavailable (not an error).
  #   run_mode: ""          # (REQUIRED to run) dry-run | sandbox | live.
  #                          #   dry-run = no side effects (read-only); sandbox = isolated, no prod data/orders;
  #                          #   live = real side effects, requires explicit operator opt-in at run time.
  #                          #   Absent ⇒ campaign REFUSES to run (run-safety; the gate executes the target).
  ```
  Done: the documented `campaign:` block exists with entrypoint + run_mode and CR-007 comments. Verify: `grep -q "campaign:" plugins/spec-flow/templates/pipeline-config.yaml` AND `grep -q "run_mode" plugins/spec-flow/templates/pipeline-config.yaml`.

**Test Data:**
- TD-1 (AC-4 config documented): `grep "run_mode" templates/pipeline-config.yaml` → expect match; `grep "campaign:" templates/pipeline-config.yaml` → expect match

- [x] **[Write-Tests]** Append to `l1_static_checks()`: `assert_grep "run_mode" "${PLUGIN_ROOT}/templates/pipeline-config.yaml" "AC-4: campaign config documented"`.
- [x] **[Verify]** Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` — Expected: assertion PASS, `0 failed`. LLM-agent-step: read `plugins/spec-flow/templates/pipeline-config.yaml` and confirm the `campaign:` block documents `entrypoint` (absent⇒SKIPPED) and `run_mode` (absent⇒refuse) with inline comments.
- [x] **[QA]** Review against AC-4 (config half). Diff baseline: phase_4_start_sha.

**Exit Gate:** the `campaign:` block is documented in the committed config template with CR-007 comments and the absent-key semantics.

---

### Phase 5: Packaging — version reconcile + CHANGELOG + static.sh version/symlink guards
**In scope:** bump all 4 version-bearing files to 5.21.0 (fixing the 5.19.0 drift on `plugin.json`); prepend the CHANGELOG 5.21.0 entry; update `static.sh` version assertions 5.19.0→5.21.0 and the symlink-count guard (27→31).
**NOT in scope:** fixtures (Phase 6); skill/agent content (Phases 2–3).
**ACs Covered:** AC-12 (version bump 4 files + symlink guard), AC-1 (partial — the "run changes no version file" is a skill-design claim; the version bump here is the PIECE bump).
**Charter constraints honored in this phase:** NN-C-001 (version sync), NN-C-009 (bump all version-bearing files + CHANGELOG), NFR-004 (correct the pre-existing drift), NN-C-007/CR-006 (Keep a Changelog format).
**Steps traversed (P2):** N/A. **Dispatch sites (P3):** none.

- [x] **[Implement]**
  T-1: MODIFY `plugins/spec-flow/plugin.json` — `"version": "5.19.0"` → `"5.21.0"`.
  T-2: MODIFY `plugins/spec-flow/.claude-plugin/plugin.json` — `"version": "5.20.0"` → `"5.21.0"`.
  T-3: MODIFY `.claude-plugin/marketplace.json` — spec-flow entry `"version": "5.20.0"` → `"5.21.0"`.
  T-4: MODIFY `plugins/spec-flow/CHANGELOG.md` — insert below `## [Unreleased]` and above `## [5.20.0]`:
  ```markdown
  ## [5.21.0] — 2026-06-13

  ### Added
  - **Results-campaign gate `spec-flow:campaign` (FR-020).** A new gate class — the running-system sibling of the Final Review board. Runs a target system on Sonnet, grades real output with three new Opus lens agents (`campaign-ground-truth`/`seam`/`edge-case`) + a `campaign-verify` theater-guard against an oracle (in-scope FR-018 outcome ACs + declared money/safety rules), routes findings through `/spec-flow:triage` (Form C), records `source: campaign` to metrics + flywheel. Run-safety: `campaign.run_mode` mandatory + pre-run confirm. Single-pass v1; the convergence loop is split to `campaign-converge`.
  - **BRF-3:** `bug_classified` Form B/C field so triage auto-applies the NN-P-006 red-first stamp to campaign bug findings.

  ### Fixed
  - **Version drift (NN-C-009):** reconciled `plugins/spec-flow/plugin.json` (was 5.19.0) with the other version-bearing files; all now 5.21.0.
  ```
  T-5: MODIFY `plugins/spec-flow/tests/e2e/lib/static.sh` — version assertions (lines ~209–221): change the hardcoded `5.19.0` → `5.21.0` in the four version-string assertions and the CHANGELOG-section assertion (the file hardcodes `5.19.0`, not `5.20.0`). Symlink guard (lines ~270–281): the guard loop is count-AGNOSTIC (it accumulates `_nonlink`/`_mismatch` and passes when zero), so it already tolerates the 4 new pairs without logic change — update only the two COSMETIC `27` references (the comment at line ~270 and the pass-message string at line ~278) to `31` so the message stays accurate.
  Done: all four version strings = 5.21.0; CHANGELOG has the 5.21.0 section; static.sh version assertions read 5.21.0 and its cosmetic symlink-count label reads 31.

**Test Data:**
- TD-1 (AC-12 versions): `grep '"version"'` on the 4 files → all `5.21.0`; `grep -c "5.21.0" CHANGELOG.md` → ≥1
- TD-2 (no superseded version in static.sh): `grep -E "5\.19\.0" static.sh` → expect NO match (advanced to 5.21.0)
- TD-3 (cosmetic count label): `grep -E "\b27\b" static.sh` (symlink-guard block) → expect NO match (advanced to 31)

- [x] **[Write-Tests]** No new test authored — Phase 5 MODIFIES the existing static.sh version + symlink-guard assertions in T-5 (the Test Data above is the oracle for those edits); the persistent suite is updated in place.
- [x] **[Verify]** Run: `for f in plugins/spec-flow/plugin.json plugins/spec-flow/.claude-plugin/plugin.json; do grep '"version"' "$f"; done; grep -A3 '"spec-flow"' .claude-plugin/marketplace.json | grep version` — Expected: every printed version is `5.21.0`. Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` — Expected: the version + symlink-count assertions PASS, `0 failed`. Run: `grep -c "5.21.0" plugins/spec-flow/CHANGELOG.md` — Expected: ≥ 1.
  Superseded-ordinal anti-drift sweep (FR-PROC-03) — scoped to the assertion file (NOT the CHANGELOG, which legitimately keeps `## [5.20.0]`/`## [5.19.0]` history): sweep for the superseded version string that static.sh actually hardcodes — `grep -nE "5\.19\.0" plugins/spec-flow/tests/e2e/lib/static.sh` — Expected: 0 hits (every version assertion advanced to 5.21.0). Sweep for the superseded cosmetic symlink count — `grep -nE "\b27\b" plugins/spec-flow/tests/e2e/lib/static.sh` (symlink-guard comment + pass-message) — Expected: 0 hits (advanced to 31).
- [x] **[QA]** Review against AC-12. Diff baseline: phase_5_start_sha.

**Exit Gate:** all four version-bearing files at 5.21.0 with a matching CHANGELOG section; static.sh version + symlink-count guards updated and passing.

---

### Phase 6: Judgment fixtures + cross-phase consistency
**In scope:** CREATE `tests/fixtures/outcome-campaign/` fixtures (AC-8 campaign→triage seam scenario; AC-11 BRF-3 bug + non-bug clean-control; AC-3 SKIPPED-not-false-green scenario); add the cross-phase schema-consistency `[Verify]`.
**NOT in scope:** skill/agent/contract content (Phases 1–3).
**ACs Covered:** AC-8 (e2e fixture half), AC-11 (BRF-3 fixture half), AC-3 (SKIPPED fixture half).
**Charter constraints honored in this phase:** none unique to this phase — the fixtures are markdown-only; the piece-wide invariants are cited canonically in earlier phases (see the Overview cross-cutting note).
**Steps traversed (P2):** N/A. **Dispatch sites (P3):** none.

- [x] **[Implement]** CREATE under `plugins/spec-flow/tests/fixtures/outcome-campaign/` (follow the seam-design fixture markdown-scenario pattern):
  T-1: `campaign-triage-seam.md` — a scenario asserting a graded+verified finding becomes a Form C item that reaches a recorded triage disposition (not a chat-only note) — the AC-8 oracle for the judgment test.
  T-2: `brf3-bug-vs-nonbug.md` — two campaign findings, one bug-classified (`bug_classified: true`) one not; asserts the red-first stamp fires ONLY on the bug — the AC-11 clean-control.
  T-3: `skipped-no-false-green.md` — entrypoint-absent + empty-oracle scenarios asserting `SKIPPED: <capability>` / `SKIPPED: no-oracle` rather than a clean/no-findings pass — the AC-3 oracle.
  Done: 3 fixture files exist. Verify: `ls plugins/spec-flow/tests/fixtures/outcome-campaign/*.md | wc -l` returns `3`.
**Test Data:**
- TD-1 (AC-11 BRF-3 fixture): `grep "bug_classified" tests/fixtures/outcome-campaign/brf3-bug-vs-nonbug.md` → expect match
- TD-2 (fixtures exist): `ls tests/fixtures/outcome-campaign/*.md | wc -l` → expect 3
- TD-3 (cross-phase consistency): `grep -l "bug_classified" reference/triage-contract.md skills/campaign/SKILL.md tests/fixtures/outcome-campaign/brf3-bug-vs-nonbug.md` → expect all 3 paths returned

- [x] **[Write-Tests]** Append to `l1_static_checks()`: `assert_grep "bug_classified" "${PLUGIN_ROOT}/tests/fixtures/outcome-campaign/brf3-bug-vs-nonbug.md" "AC-11: BRF-3 fixture"`; file-existence checks for the 3 fixtures.
- [x] **[Verify]** (cross-phase consistency oracle, FR-PROC-01) Run: `bash plugins/spec-flow/tests/e2e/run-e2e.sh` — Expected: ALL campaign assertions across Phases 1–6 PASS, `0 failed`. Cross-phase schema check — confirm the campaign-source contract is consistent across the files that touch it: `grep -l "bug_classified" plugins/spec-flow/reference/triage-contract.md plugins/spec-flow/skills/campaign/SKILL.md plugins/spec-flow/tests/fixtures/outcome-campaign/brf3-bug-vs-nonbug.md` — Expected: all three paths returned (the `bug_classified` field is defined in the contract, produced by the skill, and exercised by the fixture). And confirm `source_type` `campaign` appears in BOTH flywheel locations: `grep -c "campaign" plugins/spec-flow/reference/flywheel.md` ≥ 2.
- [x] **[QA]** Review against AC-3, AC-8, AC-11; confirm cross-phase `bug_classified` + `findings_by_source` + `campaign` source_type consistency. Diff baseline: phase_6_start_sha.

**Exit Gate:** 3 fixtures exist; the full campaign L1 assertion set passes; the cross-phase schema-consistency check confirms `bug_classified`/`findings_by_source`/`campaign` are consistent across contract, skill, and fixture.

## AC Coverage Matrix

| AC ID | Summary | Status | Covered By |
|-------|---------|--------|------------|
| AC-1 | campaign skill exists, out-of-band, changes no version-bearing file when run | COVERED | Phase 3 (skill), Phase 5 (the run-no-version-change claim is the skill design; piece bump is here) |
| AC-2 | oracle by ID + SKIPPED: no-oracle; ground-truth still runs | COVERED | Phase 3 |
| AC-3 | never false-green for an un-exercised stage/oracle [outcome:result] | COVERED | Phase 3 (skill paths), Phase 6 (SKIPPED fixture) |
| AC-4 | run_mode mandatory (refuse if unset) + pre-run confirm + live opt-in | COVERED | Phase 3 (enforcement), Phase 4 (documented config) |
| AC-5 | system run on Sonnet; lens + verify dispatch model: "opus" | COVERED | Phase 3 (skill), Phase 2 (agent model: opus) |
| AC-6 | 3 new lens agents grade run output vs oracle | COVERED | Phase 2 |
| AC-7 | per-finding theater-guard VERIFY, confirmed-only routing | COVERED | Phase 3 (loop), Phase 2 (campaign-verify) |
| AC-8 | every finding routed through triage to a recorded disposition [outcome:integration] | COVERED | Phase 3 (completing, wiring), Phase 6 (e2e fixture) |
| AC-9 | never silently drop a lens/seat [outcome:integration] | COVERED | Phase 3 |
| AC-10 | source: campaign recorded additively to metrics + flywheel; degraded-safe | COVERED | Phase 1 (contracts), Phase 3 (recording call sites) |
| AC-11 | bug_classified Form C field (BRF-3) + non-bug clean control | COVERED | Phase 1 (contract), Phase 6 (fixture) |
| AC-12 | version bump 4 files to 5.21.0 + agents bare name | COVERED | Phase 5 (version), Phase 2 (bare names) |

## Executable AC Binding

| AC ID | Verification Type | Command/Check | Expected Result |
|-------|------------------|---------------|-----------------|
| AC-1 | file-check | `grep -q "name: campaign" plugins/spec-flow/skills/campaign/SKILL.md` | match |
| AC-2 | shell | `grep -c "SKIPPED: no-oracle\|by ID" plugins/spec-flow/skills/campaign/SKILL.md` | ≥ 2 |
| AC-3 | agent-step | read campaign/SKILL.md + fixtures/outcome-campaign/skipped-no-false-green.md; confirm no stage emits "clean" without exercising it against a non-empty oracle | confirmed |
| AC-4 | shell | `grep -c "run_mode\|before first execution\|live" plugins/spec-flow/skills/campaign/SKILL.md` | ≥ 3 |
| AC-5 | shell | `grep -q 'model: "opus"' plugins/spec-flow/skills/campaign/SKILL.md` | match; system-run is Sonnet/main-window |
| AC-6 | file-check | `ls plugins/spec-flow/agents/campaign-{ground-truth,seam,edge-case}.md` all exist; `grep -q "run output" each` | 3 files, grade output |
| AC-7 | shell | `grep -q "campaign-verify" + "CONFIRMED" plugins/spec-flow/skills/campaign/SKILL.md` | match |
| AC-8 | shell + fixture | `grep -q "spec-flow:triage" + "Form C" plugins/spec-flow/skills/campaign/SKILL.md` (prod-callsite); fixture campaign-triage-seam.md asserts recorded disposition | match + fixture |
| AC-9 | agent-step | read campaign/SKILL.md; confirm every lens/seat path runs or emits a reported omission | confirmed |
| AC-10 | shell | `grep -q findings_by_source metrics-artifact.md; grep -c campaign flywheel.md (≥2); grep -q METRICS-DEGRADED + FLYWHEEL-DEGRADED campaign/SKILL.md` | all match |
| AC-11 | shell + fixture | `grep -q bug_classified triage-contract.md`; fixture brf3-bug-vs-nonbug.md | match + fixture |
| AC-12 | shell | 4 version strings = 5.21.0; `grep -E "^name:\s*spec-flow-" campaign agents` returns nothing | 5.21.0 ×4; no prefix |

## Contracts

### C-1: Campaign → triage Form C handoff
- **ID:** C-1
- **Type:** Data Schema (Form B record set → Form C batch)
- **Phase:** Phase 3 (producer) / Phase 1 (the `bug_classified` field added to the contract)
- **Signature:** a Form C list of Form B records `{source_piece, source_phase: "campaign", source_agent: <lens>, finding_text, operator_rationale?, discovery_type: degeneracy|seam|edge-case, bug_classified: bool}` handed to `/spec-flow:triage`.
- **Inputs:** one record per CONFIRMED campaign finding.
- **Outputs:** a recorded triage disposition per finding (single aggregated confirm).
- **Error cases:** empty surviving set → no triage invocation (nothing to route); triage declines → findings surfaced unchanged.
- **Constraints:** NN-P-002 (no patch), NN-P-004 (operator-confirmed), NN-P-006 (red-first via `bug_classified`).

### C-2: findings_by_source metrics block (additive)
- **ID:** C-2  **Type:** Data Schema  **Phase:** Phase 1 (doc) / Phase 3 (writer)
- **Signature:** additive `findings_by_source.campaign: {total, verified, suppressed, routed_to_triage, dispatches:{lens,verify}}` in the piece `metrics.yaml`; `schema_version` unchanged.
- **Constraints:** NN-C-003 additive; existing readers ignore unknown blocks; `[METRICS-DEGRADED]` non-blocking.

### Phase 2, 4, 5, 6 — no boundary-crossing interfaces
Omission rationale: Phase 2 creates self-contained agent prompts (no exported symbols); Phase 4 documents config; Phase 5 bumps versions; Phase 6 adds fixtures. None exposes an interface consumed by code outside its defining phase beyond C-1/C-2 above.

## Parallel Execution Notes

All phases are flat and sequential (no Phase Groups). Dependency order: Phase 1 (contracts) → Phase 2 (agents) → Phase 3 (skill, consumes both) → Phase 4 (config) → Phase 5 (packaging) → Phase 6 (fixtures + cross-phase check). Phase 2's four agents are disjoint files but kept serial (see its `Why serial:` line — shared static.sh [Write-Tests] appends). No `[P]` dispatch in this piece.

## Agent Context Summary

| Phase | Track | Primary files | Key pattern source |
|-------|-------|---------------|--------------------|
| 1 | Implement | reference/{triage-contract,metrics-artifact,flywheel}.md | introspection.md Cluster C verbatim blocks |
| 2 | Implement | agents/campaign-{ground-truth,seam,edge-case,verify}.md + symlinks | review-board-ground-truth.md (adapt diff→run-output) |
| 3 | Implement | skills/campaign/SKILL.md | review-board/SKILL.md Step 0–6 + Boundaries |
| 4 | Implement | templates/pipeline-config.yaml | CR-007 inline-comment style |
| 5 | Implement | 4 version files + CHANGELOG + tests/e2e/lib/static.sh | docs/releasing.md; static.sh lines 209–221, 271–281 |
| 6 | Implement | tests/fixtures/outcome-campaign/*.md | seam-design fixture scenario pattern |
