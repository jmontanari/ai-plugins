# Research — artifact-budgets (FR-014)

## Brainstorm Inference Digest

**Piece purpose.** Add per-artifact-class *size budgets* — the inverse of the FR-002 plan-concreteness floor (`reference/plan-concreteness.md`). Concreteness is the lower bound (must name file/anchor/content); the budget is the upper bound (bloat is the failure mode on the other side). Deliverables: (1) a new SSOT reference doc `plugins/spec-flow/reference/artifact-budgets.md` defining per-class budgets in **lines + approximate tokens** with defaults derived from the merged exec-ready size distribution; (2) optional/additive `.spec-flow.yaml` override keys; (3) one new `qa-spec` criterion (#16) flagging over-budget `spec.md`/`deliberation.md` and one new `qa-plan` criterion (#32) flagging over-budget `plan.md` (per-phase and total), both **must-fix with named split/condense guidance**; (4) a `budget_compliance` block added to the `metrics.yaml` schema; (5) registration of a binding `deliberation.md` budget for the spec-preresearch piece, verified at its `qa-plan` gate.

**Design constraints inferred.**
- **NN-C-003 (additive):** every new `.spec-flow.yaml` key must be optional; absent ⇒ documented default; pre-budget specs/plans must not retroactively fail (mirror `flywheel_threshold`/`metrics` "Absent ⇒ default; NN-C-003" wording).
- **CR-007 / CR-005:** new config keys documented inline in `templates/pipeline-config.yaml`; all reference-doc paths repo-root-relative.
- **CR-008 (thin-orchestrator/narrow-executor):** the line-count is a *mechanical* fact; per the existing concreteness-floor split, the qa agent receives the full artifact text and the budget numbers and decides over/under structurally — qa-spec/qa-plan have **no codebase access and no shell** (qa-plan.md: "Do not have codebase access — review the plan document structurally"). So the *budget values* must reach the agent as interpolated text (reference doc + resolved overrides) and the agent counts lines from the artifact text it already holds. The orchestrator skill resolves overrides from `.spec-flow.yaml` and interpolates; the agent applies. This matches how concreteness floor #28–#31 work today (agent reads plan text, cites the reference doc).
- **Routing on irreducible overage:** must route to piece-splitting via the qa-prd ≤7-AC granularity rule — **never** a waiver (PRD edge-case table line 424; FR-014 failure mode). Contrast the qa-spec weasel-word `<!-- weasel-waived -->` mechanism — that pattern must NOT be copied here.
- **NN-P-001 / NN-P-005:** keystroke gate and Opus-thinking/Sonnet-mechanics untouched (qa agents already Opus).

**Open ambiguities for the brainstorm.**
1. **Default budget values per class** — derive from the table below (PRD Open-Questions line 493 says "derive from the size distribution"). Decision: anchor on p75 or max? p75 catches the bloated tail as must-fix; max ratifies current sizes as the ceiling. The merged corpus is the *current* (pre-budget) population, so its p75/max are arguably already too high (the spec-kit failure mode is exactly "current sizes feel normal"). Recommend p75-anchored with modest headroom.
2. **plan.md budget: per-phase AND total, or total only?** PRD says both. Per-phase median 66 / p75 91 / max 197 lines; total median 664 / max 885. Need both numbers.
3. **Units:** lines are the deterministic count (agent can count); approximate tokens (chars/4 or lines×N) are advisory. Token figures below use chars/4.
4. **deliberation.md budget with zero on-disk samples** — no `deliberation.md` exists anywhere yet (protocol shipped in spec-preresearch 5.8.0 but no piece has produced one). The budget must be set from first principles / by analogy to `research.md` + its 7-section structure, not from data.
5. **spec-preresearch binding mechanics (sequencing tension — load-bearing):** the manifest order-of-operations (lines 370–374) says land artifact-budgets "before/alongside spec-preresearch execution," but **spec-preresearch is already MERGED** (commit `58de9b8`, 2026-06-10) and *its* `plan.md` is already on disk at 885 lines / 124 423 chars — the single largest plan in the corpus. So the "binds spec-preresearch's plan, verified at its qa-plan gate" AC is now **retroactive for the already-merged piece** and **forward-looking for any future deliberation.md producers**. The spec author must decide: (a) treat the binding as forward-looking (future pieces' deliberation.md inherit the budget) and document the already-merged spec-preresearch as a grandfathered/measured baseline, or (b) record the deliberation.md budget as a registered constraint that *would* bind a re-plan. Flag explicitly — the AC as literally worded ("verified at its qa-plan gate") cannot fire for a merged piece.
6. **What "budget compliance recorded in metrics" means concretely** — `metrics.yaml` today has no budget field; add a `budget_compliance:` block (per-class lines/budget/status). Who writes it: spec writes spec/deliberation rows, plan writes plan rows (mirroring metrics.yaml's per-stage-owner write rule).

## Codebase Conventions

- **Reference-doc house style** (`reference/plan-concreteness.md`, `reference/metrics-artifact.md`, `reference/deliberation-artifact.md`): each opens with a one-paragraph "single source of truth … cited by X, Y, Z; definitions live here and nowhere else" preamble naming the consuming files; numbered/`##`-headed sections; thresholds expressed as explicit numbers with a `<!-- Worked example: … -->` HTML comment block; a `## No secrets` clause where artifacts hold user data. New `artifact-budgets.md` should match this exactly. H2/H3 hierarchy only, no skipped levels (CR-009).
- **Config-key documentation** (`templates/pipeline-config.yaml`): every key has a `# <key>:` comment header, one line per enum value with `—` dash explanation, a `Absent ⇒ <default> (non-blocking; NN-C-003)` line, and a `See plugins/spec-flow/reference/<doc>.md` pointer. Existing nested-block examples to mirror: `charter:` (required/doctrine_load), `deliberation:` (depth/lenses), `integrations:`. Existing scalar examples: `flywheel_threshold: 2`, `qa_max_iterations: auto`, `metrics: auto`. A nested `artifact_budgets:` block fits the `deliberation:`/`charter:` precedent.
- **qa-agent criterion format:** flat numbered list under `## Review Criteria`; each criterion = bold lead-in, `(activate when …; skip if absent — not an error)` guard for additive checks (NN-C-003 backward-compat), explicit `Flag:` / `Do NOT flag:` bullets, `Evidence:` line, severity (`**Must-fix.**` / `**Should-fix.**`). New criteria append at the end (highest current: qa-spec **#15**, qa-plan **#31**).
- **Versioning/release discipline (NN-C-009/001/007):** three version descriptors kept in lockstep — `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (all currently **5.11.0**; next bump **5.12.0**). Every behavior-changing piece adds a `### Added`/`### Changed` block to `plugins/spec-flow/CHANGELOG.md` under a new version heading and a marketplace-sync sweep. Per-piece plan corpus shows the version bump as its own final phase ("Version bump + CHANGELOG + cross-phase citation-consistency verify", ~120–197 lines).
- **Testing conventions (charter-tools — markdown/YAML/JSON/POSIX-bash only, no runtime deps):** reference docs are not unit-tested; they are validated by (a) the cited-by/citation-consistency cross-check the version-bump phase runs, (b) the qa agents that consume them, and (c) the FR-013 e2e harness (`plugins/spec-flow/tests/e2e/`, L1 static contract checks + L2 fixture-replay). Bash helpers (e.g. `scripts/metrics-aggregate`) ship with a paired `.bats`-style/test script and require byte-identical python+awk output. A budget-compliance metrics field, if it touches `metrics-aggregate`, would need a corresponding test update.

## Reference-Doc + Config Cluster

### File Inventory
**File Inventory:**
- `plugins/spec-flow/reference/plan-concreteness.md` (185 lines) — the FR-002 floor doc this piece inverts; the template for the new `artifact-budgets.md` (preamble, numbered sections, worked-example comments).
- `plugins/spec-flow/reference/artifact-budgets.md` — **to CREATE**; the SSOT for per-class budgets + override keys.
- `plugins/spec-flow/reference/metrics-artifact.md` (151 lines) — metrics.yaml SSOT; gains a `budget_compliance` schema block + field semantics.
- `plugins/spec-flow/reference/deliberation-artifact.md` (145 lines) — defines deliberation.md's 7-section structure but **no size ceiling**; the gap FR-014 fills; the spec-preresearch binding target.
- `plugins/spec-flow/reference/research-artifact.md` (116 lines) — research.md contract; analog for sizing deliberation.md.
- `plugins/spec-flow/templates/pipeline-config.yaml` (176 lines) — gains the `artifact_budgets:` override block.
- `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — version-sync targets (5.11.0 → 5.12.0).
- `plugins/spec-flow/CHANGELOG.md` (1283 lines; `## [Unreleased]` head) — new version block.

### Dependency Map
**Dependency Map:** `artifact-budgets.md` (new SSOT) ← cited by `qa-spec.md` (spec/deliberation budget), `qa-plan.md` (plan budget), `metrics-artifact.md` (budget_compliance), and the spec/plan orchestrator SKILLs (resolve overrides from `.spec-flow.yaml`, interpolate budget values into the qa-agent prompt). `pipeline-config.yaml` `artifact_budgets:` → read by spec/plan skills. Pattern mirrors `plan-concreteness.md` ← {`plan/SKILL.md`, `qa-plan.md`, `templates/plan.md`, `tdd-red.md`, `execute/SKILL.md`}. No code dependency on other open pieces; `dependencies: []` in manifest.

### Test Landscape
**Test Landscape:** No unit tests for reference docs (markdown). Validation via: version-bump-phase citation-consistency cross-check; the qa agents as live consumers; FR-013 e2e harness L1 (static contract/dispatch grammar) + L2 (`run-e2e.sh --audit <piece-dir>` fixture replay, six break variants). If `budget_compliance` is added to `scripts/metrics-aggregate`, its paired test (python+awk byte-identical) must be extended; if budget is read-only metadata not feeding an SC, the aggregator may be untouched.

### Pattern Catalog
**Pattern Catalog:**

Reference-doc preamble + threshold-as-number style (copy for `artifact-budgets.md`):
```
This document is the single source of truth for ... It is cited by
`plugins/spec-flow/skills/plan/SKILL.md` ... and `plugins/spec-flow/agents/qa-plan.md` ...
Any definition, marker syntax, or rule lives here and nowhere else; the
consuming files cite this document and do not restate its definitions.
```

`.spec-flow.yaml` additive scalar-key documentation (mirror for budget overrides):
```
# flywheel_threshold: repo-level self-hardening flywheel — occurrence count at which ...
#   <int> — distinct-piece occurrence count threshold (default 2). Absent ⇒ 2 (non-blocking; NN-C-003).
#   See plugins/spec-flow/reference/flywheel.md `## Threshold + batched proposal`.
flywheel_threshold: 2
```

Nested-block precedent for an `artifact_budgets:` block (from `deliberation:`):
```
# deliberation:
#   depth: full
#   lenses: [scope/simplicity, risk]
```

## QA-Gate Cluster

### File Inventory
**File Inventory:**
- `plugins/spec-flow/agents/qa-spec.md` (90 lines) — adversarial spec reviewer; **15 numbered criteria** (highest #15 deliberation grounding). New **#16** = over-budget spec.md / deliberation.md → must-fix. Receives the full spec text (Full mode) and, when present, deliberation.md on the piece branch.
- `plugins/spec-flow/agents/qa-plan.md` (213 lines) — adversarial plan reviewer; **31 numbered criteria** (highest #31 Test Data block). New **#32** = over-budget plan.md (per-phase or total) → must-fix. Receives the full plan document; explicitly **no codebase access, structural review only**.

### Dependency Map
**Dependency Map:** Both agents are dispatched by their orchestrator skills (`skills/spec/SKILL.md`, `skills/plan/SKILL.md`) with the artifact text interpolated in the prompt (qa-spec "Context Provided: Spec — the spec document"; qa-plan "Plan — the implementation plan to review"). The new criteria depend on `reference/artifact-budgets.md` for budget values and need the resolved per-class budgets interpolated by the skill (the agent cannot read `.spec-flow.yaml`). Both agents have Focused re-review modes (iteration 2+) that re-check prior must-fix and scan deltas — the budget criterion must behave under focused mode too (re-check resolved? scan delta for new bloat).

### Test Landscape
**Test Landscape:** qa agents are prose-encoded; tested indirectly by the FR-013 e2e L1 dispatch-sequence checks and by live use. New criteria are validated by the existing additive-criterion convention (`(activate …; skip if absent — not an error)`) ensuring pre-budget artifacts don't fail. No standalone agent unit test exists.

### Pattern Catalog
**Pattern Catalog:**

qa-plan additive-criterion shape (copy for #32 — note guard + Flag/Do-NOT-flag + Evidence + severity):
```
29. **Unmarked unknown (FR-002b).** A decision the plan defers ... must be an explicit
    `[SPIKE: <unknown>]` marker (`plugins/spec-flow/reference/plan-concreteness.md` §2). ...
    Flag:
    - Prose that defers a decision ... with no `[SPIKE:` marker
    Do NOT flag:
    - A deliverable carrying a `[SPIKE: <description>]` marker ...
    Evidence: quote the hedged sentence and note the absent marker. **Must-fix.**
```

qa-spec criterion + present-only guard (copy for #16 deliberation.md budget):
```
14. **Deliberation structure (when present):** When `deliberation.md` exists on the piece
    branch, confirm it contains the 7 core H2 sections ... When `deliberation.md` is absent,
    note informational only — add no must-fix.
```

## Metrics-Recording Cluster

### File Inventory
**File Inventory:**
- `plugins/spec-flow/reference/metrics-artifact.md` (151 lines) — schema SSOT; add a `budget_compliance:` block under field semantics + write-procedure owner note.
- On-disk metrics: only `docs/prds/exec-ready/specs/metrics/metrics.yaml` exists as the worked example inside the reference doc; no piece has a populated `metrics.yaml` on disk yet (metrics piece merged 5.11.0; budget field is net-new).

### Dependency Map
**Dependency Map:** `metrics.yaml` written per-stage-owner (metrics-artifact.md write procedure: "Upsert only the calling stage's own block/fields"). Budget compliance is known at the qa gate, so the natural owners are: spec stage (spec.md + deliberation.md rows), plan stage (plan.md row). `scripts/metrics-aggregate` consumes metrics.yaml for SC-001..SC-006 — budget data feeds **SC-008** (operator-interaction reduction) only indirectly; decide whether budget_compliance is aggregated (touches the helper + its byte-identical test) or recorded as passive metadata (no helper change). Block-style/no-inline-flow-maps invariant applies to any new field.

### Test Landscape
**Test Landscape:** `scripts/metrics-aggregate` has a paired test requiring byte-identical python3 + awk stdout. Adding an aggregated budget field requires extending both paths and the test; recording budget_compliance as non-aggregated leaf data requires only schema-doc + writer changes (no helper/test change). The block-style parseability invariant (grep/awk + yaml.safe_load) constrains the field shape.

### Pattern Catalog
**Pattern Catalog:**

metrics.yaml block-style leaf (new `budget_compliance` follows this exact form — own indented line per leaf, no inline flow maps):
```
plan:
  qa_iterations: 2
  concreteness_floor: passed   # passed | overridden
```

Field-semantics doc entry style (one DEFINED entry per field — copy for budget leaves):
```
- `plan.concreteness_floor` — **DEFINED:** `passed` when the qa-plan gate reached clean
  with no circuit-breaker escalation; `overridden` when the piece advanced via the 3-iter
  circuit-breaker human override. Gates SC-002's denominator.
```

## Empirical Size Distribution (basis for defaults)

Measured via `wc -l` / `wc -c` over all 9 merged-piece spec dirs under `docs/prds/exec-ready/specs/`. Tokens ≈ chars/4 (median char count shown). Per-phase computed by counting lines between `### Phase`/`#### Sub-Phase` anchors across all 9 plans (70 phases total). **No `deliberation.md` exists on disk** (zero samples — protocol shipped but unrun); budget must be derived from first principles.

| Artifact class | count | min | median | p75 | max | median ≈tokens |
|---|---|---|---|---|---|---|
| spec.md (lines) | 9 | 130 | 176 | 302 | 467 | ~7,050 |
| plan.md total (lines) | 9 | 510 | 664 | 748 | 885 | ~16,500 |
| plan.md per-phase (lines) | 70 | 17 | 66 | 91 | 197 | — |
| research.md (lines) | 7 | 120 | 192 | 192 | 287 | ~5,080 |
| deliberation.md (lines) | 0 | — | — | — | — | — (no samples) |
| learnings.md (lines) | 3 | 26 | 30 | 30 | 39 | ~1,380 |

Per-piece raw line counts (for the spec author): spec.md — flywheel-repo 467, metrics 236, pipeline-e2e 176, plan-concrete 130, research-unify 302, sonnet-coord 138, spec-preresearch 420, spike-agent 172, test-data-up 151. plan.md total — flywheel-repo 664, metrics 748, pipeline-e2e 672, plan-concrete 510, research-unify 880, sonnet-coord 619, **spec-preresearch 885 (largest)**, spike-agent 529, test-data-up 595. research.md — flywheel-repo 287, metrics 192, pipeline-e2e 198, plan-concrete 168, research-unify (absent), sonnet-coord 166, spec-preresearch 120, spike-agent 192, test-data-up (absent). learnings.md — flywheel-repo 26, pipeline-e2e 39, spec-preresearch 30.
