# Introspection — seam-design

Markers: `[RESEARCH-CONSUMED: 7 files, 7 re-read]` · `[DELIBERATION-CONSUMED]` (Adversarial Review ran — full-confidence anchor).
Seeded by structural reuse of research.md; all 7 spec-target files re-read directly for concrete current-state line-numbered blocks. None changed since research commit `0b9c3d4`.

Deliberation anchor: narrow additive hardening of the shipped integration-coverage contract. Pointer on `Independent Test [machine:]` sub-line (NOT facet tag); tighten qa-spec #17 + extend #13; extend qa-plan #26; add review-board-integration reconciliation; boundary-touching predicate in behavior-classification.md; `integration_rationale` in front-matter (mirrors `behavior_rationale`).

## Cluster 1 — Definitions (single source of truth)

### File Inventory

**`plugins/spec-flow/reference/spec-flow-doctrine.md`** (184 lines). §"Integration Tests & Path Coverage" L113-136 (defs: integration boundary, integration test, path coverage, `[integration]` tag, contract test, never-mock policy, R1, R3 double-loop, M1-M4). §"Verification Checklist" L138-152. No `prod-callsite` string anywhere today (grep clean). Insertion point: end of §Integration block (after M4, before `## Verification Checklist` at L138) — new sub-block defining the production-call-site pointer convention + test-root exclusion rule.

**`plugins/spec-flow/reference/behavior-classification.md`** (78 lines). Current structure:
```
L7   ## Piece classification
L20  **Front-matter keys:**   (piece_class, behavior_rationale yaml block L22-25)
L31  ## Outcome facets        (result L36-39, integration L41-44)
L49  ## Canonical token glossary  (AC-line tags L51-57; N/A sentinel L59-65; matching rules L67-69)
L71  ## Relationship to spec-flow-doctrine.md
```
Insertion points: (a) front-matter keys block (L22-25) → add `integration_rationale` key with its "required only when behavior-bearing + non-boundary" semantics; (b) a new `## Boundary-touching predicate` section after `## Outcome facets` (before `## Canonical token glossary` at L49) defining the three-state predicate + judgment-backstopped caveat.

### Pattern Catalog (current verbatim)

behavior-classification front-matter block (L20-29):
```
**Front-matter keys:**

​```yaml
piece_class: behavior-bearing | non-behavioral
behavior_rationale: {{required only when non-behavioral}}
​```

`behavior_rationale` is required when `piece_class: non-behavioral`; it is omitted for
`behavior-bearing` pieces. The absence of `piece_class` entirely signals a legacy spec
predating this classification scheme — gates treat that as an exempt/skip condition.
```

`integration` facet (L41-44) — to be referenced by the new predicate (do NOT restate):
```
- **`integration`** — the seams are plumbed and wired; the e2e path produces a real result,
  not a fixture; nothing is stubbed; no glue is missing. ...
```

## Cluster 2 — Authoring surface

### File Inventory

**`plugins/spec-flow/templates/spec.md`** (77 lines). Front-matter L1-12 (`charter_snapshot`, `piece_class` L10, `behavior_rationale` L11). AC form L56-61 (`Independent Test [machine: ...]` L57; AC-line-tag comment L59-61). `## Integration Coverage` block L71-73. Edits: add `integration_rationale` front-matter field after L11; add a `prod-callsite=` mention to the `Independent Test` AC-form comment (L59-61) / Integration Coverage block (L71-73).

**`plugins/spec-flow/skills/spec/SKILL.md`** (multi-step orchestration file — 5 `### Phase` headings → 9c P2/P3 applies). Phase 3 "Write Spec" L251-261; step 3 (always-write `piece_class`) L261. Integration surfacing step L230. Edit: extend Phase 3 step 3 to also always-emit `integration_rationale` for new specs (parallel to piece_class); same drift/amend back-fill exclusion.

### Pattern Catalog (current verbatim)

spec/SKILL.md Phase 3 step 3 (L261, always-write piece_class — the pattern to mirror):
```
3. **Always write `piece_class` on a new (greenfield) spec.** Resolve behavioral status from the
   brainstorm; an ambiguous status resolves to `behavior-bearing` and is written into the key (never
   left absent). Write `behavior_rationale` only when `non-behavioral`. **Do NOT back-fill `piece_class`
   on a drift/amend re-run** ... the absent key is the legacy/exempt discriminator that `qa-spec` #17
   and `qa-plan` #33 rely on. Tokens/enum per `reference/behavior-classification.md`.
```

templates/spec.md AC-form comment (L59-61):
```
<!-- AC-line tag (exactly one): [mechanism] | [outcome:result] | [outcome:integration].
     Per-facet N/A sentinel form: `Outcome N/A [outcome:<facet>]: <reason>`.
     Tokens defined in plugins/spec-flow/reference/behavior-classification.md (CR-005). -->
```

templates/spec.md Integration Coverage (L71-73):
```
## Integration Coverage
- Integration: {{A}}→{{B}} — inside:{{components}}; doubled externals:{{ext}}(contract-tested); AC-{{id}}; completes phase {{N}}
- (A piece with no cross-component wiring writes "None in scope.")
```

## Cluster 3 — Gates (3 disjoint agent files → Phase Group)

### File Inventory

**`plugins/spec-flow/agents/qa-spec.md`** (126 lines, `rubric_version: 2`, symlink `qa-spec.agent.md -> qa-spec.md`). #13 "Integration allocation" L37 (single para). #17 "Outcome / negative-space coverage" L56-78 (three-state predicate; N/A sentinel handling). Last criterion = #17. Edits: extend #13 (pointer present + src-rooted + not-under-test-root = FR-024-A; + boundary-touching silently-deferred = FR-024-D); tighten #17 N/A sentinel + add `integration_rationale` exemption (FR-024-D). Bump `rubric_version` 2→3.

**`plugins/spec-flow/agents/qa-plan.md`** (233 lines, `rubric_version: 2`, symlink). #26 "Integration allocation" L148 (clauses a-e; activation guard "only when the spec declares an Integration Coverage block; skip if absent — NFR-INT-02"). Last criterion = #33 (L200). Edit: extend #26 with clause (f) — each spec-declared `prod-callsite` pointer maps to a phase whose `[Build]`/`[Implement]` scope contains the cited src/ path (FR-024-C). Bump `rubric_version` 2→3.

**`plugins/spec-flow/agents/review-board-integration.md`** (159 lines, `rubric_version: 1`, `model: opus`, symlink). Step 1 "Integration Path Inventory" L40-52 (diff-derived wired-path inventory). Step 2 boundary probes 1-7 + coverage probe 8 L54-84. Output Format per-path verdicts L94-115. Edit: add a reconciliation check — each spec-cited `prod-callsite=<src/ path>` cross-checked against the Step-1 inventory; a cited prod call site absent from the inventory is must-fix ("cited production call site not exercised by any wired path") = FR-024-B. Bump `rubric_version` 1→2.

### Pattern Catalog (current verbatim)

qa-spec #13 (L37) — to extend:
```
13. **Integration allocation:** If the spec declares any integration in its Integration Coverage block,
    each must (a) state its boundary (which components are inside), (b) name the true externals to be
    doubled (each requiring a contract test), and (c) be allocated to a specific AC. A declared
    integration missing any of (a)/(b)/(c), or any integration silently deferred, is must-fix. Absence
    of an Integration Coverage block when the piece has no cross-component wiring is NOT a finding
    (NFR-INT-02 — absence = 'no integrations declared').
```

qa-spec #17 N/A sentinel handling (L56-71, the free-text hole FO-16 exploits) — to tighten:
```
17. **Outcome / negative-space coverage (behavior-bearing pieces).** ... Three-state predicate, decided
    by the spec's `piece_class` front-matter:
    - **Legacy skip:** NO `piece_class` → skip (never retro-failed).
    - **Non-behavioral exemption:** `piece_class: non-behavioral` → exempt. Must-fix ONLY if
      `behavior_rationale` is absent ...
    - **Behavior-bearing enforcement:** for EACH facet in {result, integration}, require ≥1 AC carrying
      `[outcome:<facet>]` OR a per-facet N/A sentinel. A facet with neither is must-fix ...
```
(The free-text `Outcome N/A [outcome:integration]: <reason>` is accepted today regardless of whether the piece touches a boundary — the hole.)

qa-plan #26 (L148, clauses a-e) — to extend with (f). Activation guard already present: "activate only when the spec declares an Integration Coverage block; skip if absent — NFR-INT-02".

review-board-integration Step 1 inventory (L44-52) — the diff-derived inventory the new reconciliation reuses:
```
Integration Path Inventory
--------------------------
Path P1: <caller> → <component-A> → <component-B> [boundary: ...]
Path P2: <caller> → <component-C> → <external-X> (doubled as <fake-Y>) [boundary: ...]
```

review-board-integration finding shape (L109-115): Location / Probe / Expected / Actual / Severity / Suggested correction. New reconciliation finding fits this shape.

## Cluster 4 — Version triad + fixtures

### File Inventory

- **`plugins/spec-flow/.claude-plugin/plugin.json`** L4 `"version": "5.19.0"` → bump MINOR (additive) to `5.20.0`.
- **`/Volumes/joeData/ai-plugins/.claude-plugin/marketplace.json`** L15 spec-flow `"version": "5.19.0"` → `5.20.0` (repo-root marketplace; NOT the worktree copy — the worktree has its own `.claude-plugin/marketplace.json` at L15 too; the canonical one committed is the repo-root file, mirrored in worktree).
- **`plugins/spec-flow/CHANGELOG.md`** — `## [Unreleased]` L5 then `## [5.19.0]` L7. Add `## [5.20.0] — <date>` Added section under Unreleased.

### Test Landscape

Gate-eval fixtures mirror the **outcome-acs precedent**: `tests/fixtures/outcome-acs/*.md` are standalone planted-defect + legacy/clean spec/plan fixtures, NOT wired into `run-e2e.sh` — they are dispatched to the real gate agent (qa-spec/qa-plan) during verification and the verdict is grepped. Mirror this with `tests/fixtures/seam-design/`. Sample fixture shape (`behaving-missing-result.md`):
```
---
piece_class: behavior-bearing
---
# Spec: behaving-missing-result (fixture)
## Acceptance Criteria
AC-1: ... [mechanism]
  Independent Test [machine: ...]: ...
Outcome N/A [outcome:integration]: this piece has no external seam
```
Static greps run via `assert_grep` patterns in `tests/e2e/lib/static.sh` (L246 lists `review-board-integration` among agents). `[machine:]` ACs that "run a gate against a fixture" execute as **LLM-agent-step** verifications in execute (dispatch the gate agent with the fixture, grep its verdict) — same as outcome-acs AC-9/AC-10 judgment fixtures.

## Architectural Decisions (drafted in exploration — finalized in plan §Architectural Decisions)

- ADR-1 — pointer on `Independent Test [machine:]` sub-line, not `[outcome:integration]` facet tag (deliberation: preserves exactly-one-tag invariant; matches shipped ADR `proposals/review-board-integration/spec.md:262-263`). Rejected: 1a (facet overload), 1b (4th tag), 1c (new artifact).
- ADR-2 — omission closure by tightening #17 + extending #13; do NOT mint #18 (avoids predicate duplication + criterion fragmentation).
- ADR-3 — FR-024-A pointer check folds into #13 (one allocation concern, one criterion); FR-024-C folds into #26 (same activation guard). Rejected: standalone criteria.
- ADR-4 — exemption rationale in front-matter (`integration_rationale`, 5a), mirroring `behavior_rationale`. Rejected: 5b block-body.
- ADR-5 — no caller-existence check at construction (NN-C-002 forbids AST tooling, path 2c); truthfulness reconciled by review-board-integration reusing its diff-derived inventory (VOQ-1 option b). Construction gates check pointer SHAPE only — judgment-backstopped, not deterministic closure.
