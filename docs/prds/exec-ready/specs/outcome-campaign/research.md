# Research — outcome-campaign (FR-020)

## Brainstorm Inference Digest

**Piece purpose.** Build `spec-flow:campaign` — a new *gate class* that is the running-system sibling of the Final Review board. Review-board points adversarial Opus lenses at a DIFF; campaign points them at a RUNNING SYSTEM's OUTPUTS. It (1) loads in-scope FR-018 outcome ACs + declared product money/safety rules as the ORACLE; (2) runs the system (pilot/backtest/e2e) from the main window on Sonnet; (3) dispatches three always-on Opus lenses (GROUND-TRUTH, SEAM, EDGE-CASE) as bounded isolated agents grading real output against the oracle; (4) routes every finding synchronously through `spec-flow:triage` (FR-019) as a Form C batch; (5) records findings `source: campaign` into metrics.yaml (FR-010) + surfaces to the flywheel (FR-006). Changes no version-bearing file by itself. SKIPPED-per-capability when the system can't be run.

**Folded-in (operator 2026-06-13): surface-scaled convergence loop.** Pass A (find-all, each finding adversarially verified before becoming a triage item — theater guard) → fix batch → QA-validate the batch WIRED TOGETHER → Pass B re-hunt. Terminate on whichever fires first: K consecutive dry rounds (zero VERIFIED findings), verified-count below X% of Pass A, or a hard round/budget cap. Loop DEPTH scaled by integration surface (low → single pass = today's behavior; high → loop-until-dry), via `gate-scaling.md` (campaign ADDS the convergence-loop section — it does not exist yet).

**Design constraints (charter-binding).**
- NN-C-002: markdown + config only. The campaign skill is hand-rolled markdown orchestration (NOT the Workflow tool); no runtime deps. The "run the system" step shells out to the project's own entrypoint via bash — campaign carries no test framework of its own.
- CR-008 / NN-C-008: thin orchestrator skill is the SOLE dispatcher; lens agents do NOT dispatch sub-agents and are self-contained (no conversation history). Mirror review-board's structure exactly.
- NN-C-009 / NFR-004: **four** version-bearing files (see Conventions) — but FR-020 AC says campaign changes no version-bearing file *by itself*; the version bump is the RELEASE of this piece's own new skill/agents, not a runtime campaign action.
- NN-P-005 (system on Sonnet, judgment on Opus), NN-P-002 (findings → triage, never mid-stream patch), NN-P-004 (operator-gated writes), NN-P-006 (a campaign finding that becomes a fix is red-first — forward-record the stamp through triage's existing red-first machinery).

**Open ambiguities the spec must resolve.**
1. **No numeric "integration-surface model" exists** to scale loop depth on. seam-design (shipped) delivered the *three-state boundary-touching predicate* (`behavior-classification.md`) + the `prod-callsite` reconciliation in `review-board-integration` — NOT a low/medium/high surface metric. The campaign spec must DEFINE how "surface" is derived for depth-scaling (candidate: count of declared integrations in `## Integration Coverage` + boundary-touching state of in-scope pieces). The SEAM lens "grades against the seam-design surface model" really means: grade against declared `## Integration Coverage` blocks + `prod-callsite` pointers, not re-derive boundaries.
2. **Three lens agents vs adapt three existing.** The existing `review-board-{ground-truth,edge-case,integration}` agents are DIFF-oriented ("the full git diff"). Campaign lenses grade RUN OUTPUTS against an oracle. New campaign-specific lens agents are almost certainly required (the input mode, the "Context Provided", and the verdict framing all change diff→output). SEAM lens ≈ adapted `review-board-integration` (path/seam) but graded on real e2e output, not a wired-path inventory from a diff.
3. **"Verified finding" (theater guard).** Pass A requires each finding to be adversarially verified before it becomes a triage item. The spec must define the verification mechanism (a second bounded check? a re-derivation by the lens itself? a separate verify pass?) and what counts as VERIFIED vs rejected-as-theater.
4. **Seat activation conditionality (FR-016(b)).** The always-on core is the three lenses; conditional seats activate on signal. Any omission must be REPORTED, never silent — mirror the SKIPPED-per-capability / `## Citation obligation for seat cuts` contract in `gate-scaling.md`.
5. **SKIPPED-per-capability.** When the system can't be run (no pilot/backtest/e2e entrypoint), emit `SKIPPED: <capability>` per stage — never a false green. Mirror the MCP `integration-capability-check.md` warning form + execute's SKIPPED-ID surfacing.
6. **metrics has no `source: campaign` field yet.** metrics.yaml has no findings-by-source block. The spec must add an additive leaf (schema_version stays 1, NN-C-003) for campaign-source findings, OR record them via the existing degraded-path-safe upsert. Flywheel occurrence `source_type` is a closed enum `reflection-finding | execute-discovery | metric` — `campaign` is NOT currently an enum value; campaign findings likely surface as `execute-discovery`-shaped occurrences or the spec adds a value (NN-C-003 additive).

## Codebase Conventions

- **Out-of-band gate skill shape** (`review-board/SKILL.md`): Step 0 load config best-effort → Step 1 resolve target → Step 2 select lenses (log inclusions/omissions, no silent omit) → Step 3 dispatch all lenses concurrently `model: "opus"` with the verbatim `WORKTREE:` preamble → Step 4 collect/dedupe/classify/report → optional `--fix` routes into another skill (never patches itself) → explicit "Boundaries — what this skill does NOT do". Campaign mirrors this skeleton.
- **Agent file pair**: `<name>.md` + a `<name>.agent.md` SYMLINK to it (relative, same-dir). Frontmatter: bare `name:` (CR-001/NN-C-004), `description:` starting "Internal agent — dispatched by … Do NOT call directly.", optional `model: opus` and `rubric_version: N`. Body ends with a `## Worktree` section citing `coordinator-contract.md → ## Dispatch Preamble`.
- **WORKTREE preamble** is the single authoritative block in `coordinator-contract.md`; every dispatch site reproduces it verbatim; an agent lacking it STOPs with `[WORKTREE-ABSENT]`. Campaign's main window runs from the worktree root (this piece's own dispatch already carries it).
- **Reference-doc single-source idiom**: contracts (triage, metrics, flywheel, gate-scaling, behavior-classification) own their vocabulary; skills/agents CITE by anchor and never restate (NN-C-008). Campaign cites these; it restates nothing.
- **Bounded ≤2K isolated returns** ending `STATUS: OK | BLOCKED` (research/spike pattern); coordinator return discipline = bounded structured summaries, raw artifacts referenced by path never pasted (`coordinator-contract.md`).
- **Model policy** (`coordinator-contract.md` table): Sonnet for mechanics/coordinator/implementer, Opus for qa-phase/board/triage-meta. Campaign honors NN-P-005: system-run on Sonnet (main window), lens grading on Opus.
- **Degraded/absent markers**: single-line bracketed (`[METRICS-DEGRADED]`, `[METRICS-ABSENT]`, `[FLYWHEEL-DEGRADED]`, `[WORKTREE-ABSENT]`); non-blocking, stage continues. SKIPPED form mirrors these.
- **Version-bearing files (4, per `docs/releasing.md`)**: `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (spec-flow entry), `plugins/spec-flow/CHANGELOG.md`. Current version **5.20.0**. (NB: there is NO root-level `.claude-plugin/plugin.json` — the injected "5.x root/.claude-plugin plugin.json sync" refers to these four; both spec-flow plugin.jsons must agree.)

## Sibling Out-of-Band Gate Skills

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/review-board/SKILL.md` (147 lines — the canonical pattern campaign mirrors: target→diff resolution, lens selection w/ logged omissions, concurrent Opus dispatch, collect/dedupe/classify, `--fix`→small-change routing, Boundaries). `plugins/spec-flow/skills/triage/SKILL.md` (164 lines — FR-019 consume target; Form A/B/C inputs, batch aggregated-confirm, 5 dispositions, spike scope-mode, provenance + red-first stamp). `plugins/spec-flow/skills/execute/SKILL.md` (the in-pipeline board + Step 6c triage + SKIPPED-ID surfacing precedent).

### Dependency Map
**Dependency Map:** review-board → `agents/review-board-<lens>.md` (reuses, adds none) + `coordinator-contract.md#Dispatch-Preamble` + `gate-scaling.md#board-swap-rule`. triage → `reference/triage-contract.md` (vocabulary) + `agents/spike.md` (scope mode, the only sub-dispatch) + `/spec-flow:small-change`, `/spec-flow:defer`, `agents/plan-amend.md`. **Campaign depends on: triage (Form C batch entry), the three lens agents (new/adapted), metrics-artifact, flywheel, behavior-classification (oracle tags), gate-scaling (adds convergence section).**

### Test Landscape
**Test Landscape:** No unit tests for skills (markdown). Verification is fixture gate-evals (seam-design/gate-evals precedent): planted-defect fixtures the gate MUST flag + clean/legacy fixtures it MUST NOT. Campaign's testing strategy will mirror: a runnable fixture system whose output contains a planted degeneracy/seam-break the lens MUST catch, + a clean run it MUST pass; a no-entrypoint fixture that MUST yield `SKIPPED:`.

### Pattern Catalog
**Pattern Catalog:**
Concurrent Opus dispatch with preamble (review-board Step 3):
```
Read each selected template from ${CLAUDE_PLUGIN_ROOT}/agents/review-board-<lens>.md and
dispatch ALL selected lenses concurrently with Input Mode: Full and model: "opus".
Every Agent({...}) call MUST prepend a `WORKTREE: <absolute path>` block … An agent that does
not receive this preamble MUST STOP and report `[WORKTREE-ABSENT]`.
```
Boundaries section (verbatim discipline campaign reuses):
```
- No merge. - No pipeline mutation (never amends a plan/spec, forks, writes backlog…).
- No sign-off gate. - No direct code edits. `--fix` never patches the tree itself — it routes
  findings into /spec-flow:small-change, so every fix is planned, QA-gated, and re-reviewed.
```
Triage Form C batch (the campaign handoff target):
```
Form C — batch (FR-020 campaign): a list of Form A or Form B findings. All findings in a batch
proceed through Steps 2–4 together and are presented as a single aggregated confirm prompt.
```

## Adversarial Lens Agents (oracle-graded, run-output)

### File Inventory
**File Inventory:** `agents/review-board-ground-truth.md` (115 ln, 8 correctness probes incl. degenerate/dead-knob, lookahead, scope contamination, silent truncation, result-attribution; per-component SOLID|UNVERIFIED|DIVERGES verdict). `agents/review-board-edge-case.md` (51 ln, boundary/state/concurrency/error-cascade/missing-branch). `agents/review-board-integration.md` (162 ln, `rubric_version: 2`; Integration Path Inventory + 7 boundary probes + 1 coverage probe + `prod-callsite` reconciliation FR-024-B; two-axis SOUND/COVERED verdict). No `review-board-seam*` agent exists.

### Dependency Map
**Dependency Map:** All three are DIFF-input agents ("Context Provided: Diff: the full git diff"; Full/Focused-re-review input modes). They cite `coordinator-contract.md#Dispatch-Preamble` and `spec-flow-doctrine.md` (integration defs). Campaign's lenses need: input = RUN OUTPUT + ORACLE (the FR-018 outcome ACs, addressable by ID) instead of a diff; verdict framed as "real output vs oracle". → **New campaign lens agents** (`campaign-ground-truth`, `campaign-seam`, `campaign-edge-case` or similar) adapting these prompts, OR a parameterized input-mode added to the existing ones. The SEAM lens is the closest adaptation of `review-board-integration` (it grades seams), but on e2e output not a wired-path inventory.

### Test Landscape
**Test Landscape:** Lens correctness is exercised via fixture runs (a system output with a planted dead-knob / a stubbed-seam short-circuit / a boundary-regime failure that the lens must DIVERGE/flag). ground-truth's "degenerate-output / dead-knob" and "result-attribution" probes map directly to the campaign's GROUND-TRUTH degeneracy mandate.

### Pattern Catalog
**Pattern Catalog:**
ground-truth default stance + dead-knob probe (campaign's core degeneracy lens):
```
Your default stance: any number a component produces is wrong until an independent derivation
says otherwise. … Degenerate-output / dead-knob detection: for every parameter the component
claims to respond to: would changing it actually change the output? … A perfect/constant result
is a defect hypothesis, not a success.
```
integration two-axis verdict (the SEAM lens template):
```
Boundary-correctness verdict: SOUND | DIVERGES | UNTRACED
Path-coverage verdict: COVERED (≥1 [integration]-tagged test exercises the real wired path)
  | UNIT-ONLY | UNCOVERED
```

## Triage Contract (the FR-019 handoff)

### File Inventory
**File Inventory:** `reference/triage-contract.md` (72 ln — single source for dispositions, exactly-one rule, spike scope-mode, provenance row, operator gate, `notes:` schema, red-first obligation, the FR-008 change-signal set). `skills/triage/SKILL.md` (the standalone consumer).

### Dependency Map
**Dependency Map:** Campaign constructs a **Form C batch** of Form B records `{source_piece, source_phase, source_agent, finding_text, operator_rationale, target?, discovery_type?}`. For campaign findings `source_phase:source_agent` = e.g. `campaign:ground-truth`. The batch hits one aggregated operator confirm (NN-P-004). Red-first stamp is forward-recorded on bug-classified fix dispositions through all three provenance surfaces; the contract notes "Campaign (FR-020) reach remains forward-record only (the campaign skill does not exist)" — **this piece IS that skill, so it now wires the campaign→triage path the contract reserved.**

### Test Landscape
**Test Landscape:** Verified by routing a planted finding batch through triage and asserting a recorded disposition per finding (none left in conversation, none mid-stream patched) + a single aggregated confirm event.

### Pattern Catalog
**Pattern Catalog:**
Operator gate / aggregated batch (the exact campaign contract):
```
When multiple findings are supplied at once (FR-020 campaign batch), present them in a single
aggregated confirm prompt (execute's existing Step 6c aggregated-prompt pattern) — one
confirmation event, not one keystroke per finding.
```
Red-first forward-record (campaign-finding-becomes-fix, NN-P-006):
```
On a bug-classified discovery routed to a fix disposition (small-change / plan-amend / new-piece),
stamp the red-first reproduce→fail→fix→pass obligation onto all three provenance surfaces:
(1) downstream handoff digest, (2) the .discovery-log.md row, (3) the manifest/backlog entry.
```

## Oracle, Metrics & Flywheel Recording

### File Inventory
**File Inventory:** `reference/behavior-classification.md` (116 ln — `[mechanism]`/`[outcome:result]`/`[outcome:integration]` token glossary, per-facet N/A sentinel, the three-state boundary-touching predicate). `reference/metrics-artifact.md` (schema, serial-checkpoint write procedure, `[METRICS-DEGRADED]`/`[METRICS-ABSENT]`, SC computation, no-secrets). `reference/flywheel.md` (`docs/patterns.yaml` schema, `source_type` enum, occurrence dedup-per-piece, operator-gated confirm, degraded path). `docs/prds/exec-ready/specs/outcome-acs/spec.md` (the oracle data model — outcome ACs addressable by ID; explicitly states FR-020 + ground-truth seat grade real output against these).

### Dependency Map
**Dependency Map:** Oracle = in-scope pieces' `[outcome:result]`/`[outcome:integration]` ACs (grep by tag, reference by AC-N ID — outcome-acs guarantees ID-addressability) + declared product money/safety rules. metrics `source: campaign` recording: metrics.yaml has NO findings-by-source block today → spec adds an additive leaf (schema_version stays 1). Flywheel `source_type` enum is `reflection-finding | execute-discovery | metric` — `campaign` is not a value; campaign occurrences either map to an existing value or the spec adds one (NN-C-003 additive, but a closed enum extension needs care). Both writes are operator-gated (NN-P-004) and degraded-path-safe.

### Test Landscape
**Test Landscape:** Assert a campaign finding lands in metrics.yaml with the campaign source marker and as a flywheel occurrence with provenance; assert `[METRICS-DEGRADED]`/`[FLYWHEEL-DEGRADED]` on unwritable/unparseable registry (non-blocking, never a false green). outcome-acs already dogfoods the tags (`spec.md` AC-9..AC-15).

### Pattern Catalog
**Pattern Catalog:**
Oracle relationship (outcome-acs spec — campaign supplies the grading consumer):
```
The spec's Integration Coverage block names which seams get contract-tested; outcome ACs state
what unacceptable integrated behavior looks like (the oracle); the downstream FR-020 SEAM lens /
review-board-integration grade the running system against those outcome ACs.
```
Flywheel source taxonomy (the slot campaign must fit, operator-confirmed write):
```
source_type — one of reflection-finding | execute-discovery | metric. … metric occurrences cite
a measured metrics.yaml trend, written via the operator-confirm flow (FR-010).
```
metrics degraded path (campaign mirrors for source: campaign writes):
```
On an unwritable or unparseable path: emit a single bracketed line [METRICS-DEGRADED: <reason>];
no metrics write occurs; execute is not blocked or failed — the stage continues normally.
```

## Surface Model, Convergence Loop & SKIPPED/Conditional-Seat Contracts

### File Inventory
**File Inventory:** `reference/gate-scaling.md` (80 ln — clean-gate predicates, board-swap-rule, the `## Citation obligation for seat cuts and model downgrades` FR-016 contract; **NO convergence-loop section — campaign ADDS one**). `reference/integration-capability-check.md` (MCP capability-check + `⚠️ INTEGRATION WARNING` form — the SKIPPED-per-capability template). `docs/prds/exec-ready/specs/seam-design/spec.md` (what shipped: `prod-callsite` reconciliation + boundary-touching predicate — NOT a numeric surface metric). `reference/behavior-classification.md#Boundary-touching predicate` (the three-state surface signal the SEAM lens + depth-scaling actually grade against).

### Dependency Map
**Dependency Map:** Convergence-loop depth scales on integration surface → the spec must DEFINE "surface" from declared `## Integration Coverage` blocks + boundary-touching state (low surface → single pass = today's review-board behavior; high surface → loop-until-dry). Termination conjunction (K dry rounds OR verified-count < X% of Pass A OR hard cap) is NEW and lives in the gate-scaling convergence section campaign adds. Seat-omission reporting mirrors gate-scaling's FR-016 citation-obligation + execute's SKIPPED-ID surfacing + integration-capability-check's warning form. SKIPPED-per-capability never a false green (mirrors FR-013/FR-017 e2e/eval SKIPPED contract).

### Test Landscape
**Test Landscape:** Assert: a low-surface in-scope set runs a single pass; a high-surface set loops until a termination condition fires; a no-runnable-system case emits `SKIPPED: <capability>` per stage (never green); an omitted conditional seat is reported in the run log (never silent).

### Pattern Catalog
**Pattern Catalog:**
Seat-omission / cut citation obligation (the never-silent contract campaign mirrors):
```
Any board-seat cut or model downgrade MUST cite two evidence classes before taking effect:
(1) mined per-seat precision/overlap/unique-catch; (2) cheater-track DETECTED. A seat cut that
lacks both is an unevidenced capacity reduction and is rejected per NN-P-001.
```
What seam-design actually shipped (surface model caveat — there is NO numeric metric):
```
This piece closes seam failure-class 3 (untested-unused seam) at spec time. … the genuine
"is it wired in prod" check is the review-board-integration reconciliation (FR-024-B), which
derives a wired-path inventory from the diff and confronts the author's cited pointer against it.
```
Boundary-touching three-state predicate (the SEAM-lens / depth-scaling surface signal):
```
boundary-touching | non-boundary | ambiguous (→ default boundary-touching). boundary-touching
pieces MUST declare integrations in ## Integration Coverage OR record integration_rationale.
judgment-backstopped: not deterministically verifiable from static analysis.
```
SKIPPED-per-capability template (integration-capability-check warning form):
```
⚠️ INTEGRATION WARNING: Required MCP tools not available. … Fix: Ensure the <provider> server
is configured and exposes these tools.   (campaign emits `SKIPPED: <capability>` per stage when
the system can't be run — never a false green)
```

## Key inference-digest one-liners (per injected cluster)

- **Sibling gate skills:** mirror review-board's 0–6 step skeleton + Boundaries; the `--fix`-equivalent is the triage Form C batch, not a code patch.
- **Lens agents:** new campaign lens agents (or a new output-graded input mode) required — existing three are diff-bound; SEAM ≈ adapted `review-board-integration`.
- **Triage contract:** campaign builds a Form B/Form C batch → single aggregated confirm; this piece wires the campaign→triage path the contract explicitly reserved.
- **Metrics:** add an additive `source: campaign` findings leaf (schema_version 1); degraded-path-safe, operator-gated.
- **Flywheel:** campaign occurrences need a source_type home (`execute-discovery`-shaped or an additive enum value); operator-confirm write, dedup per piece.
- **Oracle / behavior-classification:** load in-scope `[outcome:*]` ACs by ID (outcome-acs guarantees addressability) + declared money/safety rules; reference, don't re-derive.
- **Seam-design surface model:** does NOT exist as a number — grade against `## Integration Coverage` + boundary-touching predicate; the spec must define depth-scaling from those.
- **Gate-scaling + SKIPPED:** campaign ADDS a convergence-loop section; seat-omission + SKIPPED-per-capability reporting mirror FR-016 citation-obligation + integration-capability-check warning; never a silent omit, never a false green.
- **Model policy:** system-run on Sonnet (main window bash), lens grading on Opus, ≤2K bounded isolated returns — per coordinator-contract.
- **Packaging:** 4 version-bearing files at 5.20.0; the campaign run itself changes none (FR-020 AC) — only the release of this piece bumps them.

STATUS: OK
