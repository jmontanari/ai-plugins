# Research — bugfix-redfirst (exec-ready / FR-022, NN-P-006, SC-009, G-6)

## Brainstorm Inference Digest

**Piece purpose.** Codify NN-P-006 (bug-fix / regression work is red-first) as a general spec-flow principle that follows the fix wherever it is raised, REGARDLESS of the piece's `tdd:` setting. The non-substitutable artifact is OBSERVING a test fail against the actual broken code (reproduce → see-it-fail → fix → see-it-pass) and recording that observed red as phase evidence. Edit surfaces named in the manifest: (1) small-change routes bug-signal work to red-first by default; (2) hotfix track defaults bug work to red-first; (3) plan gains a PHASE-level bug-fix/regression tag (a feature piece may carry one regression-guard phase while other phases use the Implement track); (4) qa-plan / qa-spec raise a must-fix when such a phase proposes tests-after or omits observed-red evidence; (5) FR-021's `tdd: false` default documents the exclusion. Non-reproducible defect → `[SPIKE]` to establish a reproduction or record an explicit no-repro rationale at triage. Out-of-band reach: triage (FR-019) bug-classified fix and campaign (FR-020) finding-turned-fix are red-first too.

**(a) Phase-level bug-fix/regression tag — anchor status.** NO existing phase-level bug-fix/regression tag. Today phase track is binary and inferred MECHANICALLY: a phase containing `[TDD-Red]` is TDD-track; a phase containing `[Implement]` and no `[TDD-Red]` is Implement-track (plan template L46–50; execute Step 1a L391–399). `piece_class` (`behavior-bearing` / `non-behavioral`) and AC tags (`[mechanism]` / `[outcome:result]` / `[outcome:integration]`) exist at the SPEC level (spec.md template; behavior-classification.md), but there is no bug-fix/regression classification anywhere — it must be NEWLY DEFINED. The natural attach point for a phase tag is the plan-template phase header (alongside `**ACs Covered:**`, `**Authored-tests:**`) under CR-009 anchors `### Phase N:` (H3) / `#### Sub-Phase N.m:` (H4). The doctrine "RED — Write Failing Test" section is hard-gated `(TDD mode only)` and "WRITE-TESTS" is `(Non-TDD mode only)` — doctrine currently has NO notion of red-first independent of the piece-level mode; this is the doctrinal gap the piece fills.

**(b) Checkable at PLAN/SPEC time vs only at EXECUTE time.** Pre-execution (static, gate-checkable by qa-plan/qa-spec from document text alone): that a phase classified bug-fix/regression DECLARES the red-first track (carries a `[TDD-Red]` step, not tests-after), and that the plan/spec does not propose tests-after for it. The OBSERVED-RED evidence itself is an EXECUTE artifact — it only exists once tdd-red runs the test against unfixed code and emits its `## Oracle block` / `## Test Results` (FAILED list, `0 passed` summary). So qa-plan/qa-spec can only enforce the *declaration* ("this phase must be red-first; tests-after is a must-fix") — they cannot see the red itself. Whoever records observed-red as phase evidence must do so at execute time (tdd-red already produces it; the gap is binding/recording it as bug-fix phase evidence even inside a `tdd:false` piece).

**(c) Can execute already run a single red-first phase inside a `tdd:false` piece?** YES, mechanically — with one caveat. Step 1a (L391–399) branches PER-PHASE on the literal checkbox: phase with `[TDD-Red]` → Mode TDD (runs Red Step 2); phase with `[Implement]`/no `[TDD-Red]` → Mode Implement (skips Red). The mode decision is the plan author's; the orchestrator never decides. So a `tdd:false` plan whose ONE regression-guard phase carries a `[TDD-Red]` block will run Red for that phase. CAVEAT: several execute steps gate on the plan-FRONT-MATTER `tdd:` field, not the per-phase checkbox — Step 2 / Step 2.5 / qa-tdd-red are written "Skip this step entirely when the plan uses non-TDD mode (`tdd: false`)" (L467, L518), and `qa_max_iterations` `auto` resolves off front-matter `tdd:` (L276). A per-phase red-first inside a `tdd:false` piece may hit these front-matter-keyed skips. This piece must reconcile per-phase-checkbox vs piece-front-matter gating so a bug-fix phase actually runs Red + records observed-red even when the piece front-matter says `tdd: false`.

**(d) `tdd:false` "efficient default" doc surface for the FR-021 carve-out.** EXISTS today even though implement-oracle (FR-021 Road A) is unbuilt: plan/SKILL.md TDD Preference Resolution (`auto`/`true`/`false`, L57–59), the Non-TDD-mode override block (L267–274), plan template "Phase 2 (Non-TDD mode)" + the `tdd: false` front-matter convention (template L50, L208–279), and doctrine's WRITE-TESTS `(Non-TDD mode only)` section. The carve-out bullet ("`tdd: false` default does NOT apply to bug-fix/regression phases") can attach to plan/SKILL.md's Non-TDD-mode override and to doctrine — no need to wait for implement-oracle.

**(e) Exact small-change / hotfix routing seam for bug-signal detection.** Bug-signal keyword set is ALREADY canonicalized: `fix` / `bug` / `broken` / `regression` / `patch` in `reference/triage-contract.md` `## Red-first obligation` (called "small-change's existing set"). small-change SKILL.md, however, has NO routing rule today — its frontmatter `description` lists trigger words ("quick fix", "patch", "small bug fix") but Step 6 is a generic brainstorm and Step 9 recommends TDD-vs-Implement per phase with no bug-signal branch. The seam to add bug-signal→red-first is Step 9 (Inline Plan Generation, "recommend either TDD or Implement track") and/or Step 6 brainstorm. HOTFIX is NOT a distinct skill — it is a routing path inside `intake/SKILL.md` (Q4 "Hotfix / regression / CI failure" → `type: hotfix` → Q5 branch strategy → Q6 tracking → "Work directly — charter constraints are active", intake L195–235, L375). Today the hotfix track hands the operator straight to a branch with zero red-first obligation. Out-of-band reach is PARTLY pre-built: triage already stamps the NN-P-006 red-first obligation on all three provenance surfaces for bug-classified fix dispositions (`triage/SKILL.md` Step 7 L136–146; contract `## Red-first obligation`) as a forward-record with no dependency on this unmerged piece. Campaign (FR-020) has NO skill — only referenced via triage's batch handoff (Form C).

**Design constraints.** NN-C-002 markdown+config only. NN-C-003 additive/back-compat: phases without a bug-fix tag read as feature work, existing pieces not retro-failed (mirrors qa-spec criterion-17's "Legacy skip" three-state pattern). NN-C-004/008 agent prompts self-contained. NN-C-009 version bump in all three version-bearing files AND the hard-coded `5.18.0` assertions in `tests/e2e/lib/static.sh`. CR-008 thin-orchestrator skills / narrow agents; agents don't dispatch agents. CR-009 H3/H4 phase anchors are the Scheduler detection points — any phase-tag syntax must not break them. SC-009 links because the new qa-plan/qa-spec must-fix is a new merge-blocking gate behavior needing a published catch rate.

## Codebase Conventions

- **Agent QA criteria** are a numbered list `N. **Title:** …` under `## Review Criteria`, each with explicit must-fix / acceptable / "do NOT flag" branches and an Evidence clause. qa-plan currently tops at **criterion 33**; qa-spec tops at **criterion 17**. A new criterion is appended with the next integer. Both agents have a `## Input Modes` Full (iter 1, all criteria) + Focused-re-review (iter 2+, delta only) contract and a `### must-fix` / `### acceptable` `## Output Format`.
- **Co-ship twins:** every `agents/<name>.md` has a sibling `agents/<name>.agent.md` that is a **symlink** to the `.md`. Editing the `.md` auto-mirrors. `tests/e2e/lib/static.sh` enforces all 27 pairs are byte-identical symlinks. No separate edit to `.agent.md` is needed (or allowed — drift fails the test).
- **Shared contracts** (e.g. `reference/triage-contract.md`) are the single source of truth; skills CITE a named `## Heading` and never restate vocabulary (NN-C-008). The bug-signal keyword set and red-first forward-record already live in `triage-contract.md` `## Red-first obligation` — a new piece should CITE it, not re-list keywords.
- **Three-state legacy-safe predicate** is the established back-compat idiom for new classification gates (qa-spec criterion 17 `piece_class`: Legacy-skip if field absent / Non-behavioral exemption / Behavior-bearing enforcement). A bug-fix/regression tag should follow the same shape: absent tag → feature work, never retro-failed.
- **Phase track declaration** is checkbox-literal (`[TDD-Red]` / `[Implement]` / `[Write-Tests]`); execute branches mechanically, plan author decides. Phase headers carry bold-label fields (`**ACs Covered:**`, optional `**Authored-tests:**`).
- **Static tests** are `assert_grep "<token>" <file> "<label>"` token-presence checks in `tests/e2e/lib/static.sh`; a new doc/criterion is locked in by adding an `assert_grep` for a stable token. Version assertions hard-code the literal version string.
- **Markers** are bracketed sentinels (`[SPIKE: …]`, `[DELIBERATION-UNAVAILABLE]`, `[RESEARCH-CONSUMED]`). A no-repro / spike path for a bug would use the existing `[SPIKE: <unknown>]` marker (plan-concreteness §2; execute Step 1c resolves it on Opus).

## Small-change & Hotfix Routing

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/small-change/SKILL.md` (223 lines — Steps 0–13; bug-signal seam at Step 6 brainstorm + Step 9 inline-plan track recommendation; frontmatter `description` already lists "quick fix"/"patch"/"small bug fix" triggers but no routing rule). `plugins/spec-flow/skills/intake/SKILL.md` (hotfix routing path: Q4 standalone-type L195–211, Q5 branch strategy L213–223, Q6 tracking L225–235; classification table L88, L375, L391; CWD map L266; charter tier L332–333). `plugins/spec-flow/docs/userguide/commands/intake.md` (hotfix UX docs L9/31/32/59/76–89). No standalone `hotfix` skill exists.

### Dependency Map
**Dependency Map:** small-change → `reference/brainstorm-procedure.md` (Charter Context Loading, L-10 Convention Scan, C-2/C-3 blocks), `reference/deliberation-depth.md` + `reference/deliberation-artifact.md` (lite deliberation), `reference/slug-validator.md`, `reference/integration-capability-check.md`, `templates/change-brief.md`, `templates/plan.md`, `/spec-flow:defer`, `/spec-flow:execute`. intake → `charter-location.md`, `brainstorm-procedure.md`, and ROUTES to `/spec-flow:triage` (Q4 investigation option), `/spec-flow:status`, spec/plan/execute. Hotfix path produces a branch + "Work directly" handoff — no execute, no plan, no red-first obligation today.

### Test Landscape
**Test Landscape:** `tests/e2e/lib/static.sh` L285+ asserts `intake/SKILL.md` routes Q4 to `spec-flow:triage` (`assert_grep "spec-flow:triage" intake/SKILL.md`). No existing static assertion ties small-change or hotfix to a red-first / bug-signal token — a new one would be added.

### Pattern Catalog
**Pattern Catalog:**

small-change Step 9 — the per-phase track-recommendation seam (no bug-signal branch today):
```markdown
- For each phase in `plan.md`, recommend either TDD or Implement track and give one sentence of reasoning.
- Present all track recommendations to the operator and allow per-phase overrides.
- Do not write `plan.md` until the operator confirms the full phase list and all track selections.
```

intake Q4 hotfix routing — bug/regression work lands on "Work directly" with no red-first stamp:
```markdown
- **Hotfix / regression / CI / infra** → `type: hotfix` → Q5
...
| `hotfix` | — | `Branch [branch] ready. Work directly — charter constraints are active.` |
```

Canonical bug-signal keyword set (already shared — cite, don't re-list):
```markdown
## Red-first obligation (NN-P-006 forward-record)
Bug-signal keyword set: `fix` / `bug` / `broken` / `regression` / `patch` (small-change's existing set).
```

## QA Gates (qa-plan / qa-spec)

### File Inventory
**File Inventory:** `plugins/spec-flow/agents/qa-plan.md` (25.7K; numbered `## Review Criteria` 1–33; highest = criterion 33 "Anti-mislabel cross-check (spec piece_class vs plan track)" L200; TDD-structure criterion 3 L22 names the Red-QARed-Build-Verify pattern; criteria 30–32 already branch on TDD-track vs Implement-track / Non-TDD `tdd:false`). `plugins/spec-flow/agents/qa-spec.md` (13.2K; criteria 1–17; highest = criterion 17 "Outcome / negative-space coverage" with the three-state `piece_class` legacy-safe predicate L56+). Co-ship symlinks `qa-plan.agent.md`, `qa-spec.agent.md` (auto-mirror).

### Dependency Map
**Dependency Map:** qa-plan reads plan.md (phase headers, `[TDD-Red]`/`[Implement]` blocks, AC Coverage Matrix, Test Data blocks, `**Authored-tests:**`), `reference/plan-concreteness.md` (§1 floor, §2 SPIKE, §3 branch-AC, §5 Test Data), `reference/ac-matrix-contract.md`. qa-spec reads spec.md (`piece_class`, AC tags, honored sections), charter files, `reference/behavior-classification.md`, `reference/deliberation-artifact.md`, `reference/artifact-budgets.md`. Both dispatched by their skills (`plan`/`spec`) with Full vs Focused-re-review input modes; fixes flow through `fix-doc.md` (unified-diff, orchestrator commits).

### Test Landscape
**Test Landscape:** `tests/e2e/lib/static.sh` L235–238 asserts a representative criterion token exists in BOTH `qa-plan.md` and `qa-plan.agent.md` (e.g. `assert_grep "Authored-tests declaration"`), plus the 27-pair byte-identity / symlink guard L240+. A new bug-fix/regression criterion would get a parallel `assert_grep "<stable criterion token>"` on qa-plan.md and qa-spec.md.

### Pattern Catalog
**Pattern Catalog:**

qa-plan criterion format + an existing track-aware criterion (the template a bug-fix criterion follows):
```markdown
30. **Doc-as-code branch-enumeration AC (FR-002c) (activate only for Implement-track / Non-TDD phases — a phase with `[Implement]` and no `[TDD-Red]`; skip TDD-track phases).** For each such phase, every conditional branch in the deliverable prose ... must have a matching numbered AC ...
```

qa-spec criterion 17 — the three-state legacy-safe predicate (NN-C-003 back-compat model to mirror):
```markdown
- **Legacy skip:** the spec carries NO `piece_class` field → skip this criterion
  entirely (legacy spec; never retro-failed). This is not a finding and not an error.
- **Non-behavioral exemption:** `piece_class: non-behavioral` → exempt. Must-fix ...
- **Behavior-bearing enforcement:** `piece_class: behavior-bearing` ... require at least one AC ...
```

Output contract (shared by both agents):
```markdown
### must-fix
### acceptable
If no must-fix findings: return "### must-fix\nNone" and list all passing criteria under acceptable.
```

## Plan Phase Classification & Templates

### File Inventory
**File Inventory:** `plugins/spec-flow/templates/plan.md` (21.8K; track contract L46–50; Phase-1 TDD example L64–137 with `[TDD-Red]`→`[QA-Red]`→`[Build]`→`[Verify]`→`[Refactor]`; Phase-2 Implement example L139–206; Phase-2 Non-TDD-mode example L208–279; Phase Group H4 sub-phases L283–315; `## Executable AC Binding` L340; `## Integration-Test Registry` L351). `plugins/spec-flow/skills/plan/SKILL.md` (TDD Preference Resolution L57–59; Non-TDD-mode override L267–274; Test Data contract 2g L338; front-matter `tdd:` write L676). `plugins/spec-flow/templates/spec.md` (`piece_class` + `behavior_rationale` front-matter; AC tag form `[mechanism]`/`[outcome:*]`). `reference/spec-flow-doctrine.md` (Red-Build-Verify-Refactor cycle L11–50, each phase gated `(TDD mode only)` / `(Non-TDD mode only)`).

### Dependency Map
**Dependency Map:** plan template consumed by `skills/plan/SKILL.md` (authoring) AND `skills/small-change/SKILL.md` Step 9 (inline plan). Phase headers use CR-009 anchors `### Phase N:` (H3) / `#### Sub-Phase N.m:` (H4) — the Phase Scheduler detection points (execute Step 0b counts these). The `tdd:` front-matter flag is read by execute (Steps 0/1a/2/2.5/Step-4 mode, `qa_max_iterations` resolution) and by qa-plan criterion 33 / qa-spec criterion 17. Test Data block (FR-003) is consumed verbatim by tdd-red and by Step 2.7 Write-Tests. `[SPIKE: <unknown>]` markers resolved by execute Step 1c (Opus).

### Test Landscape
**Test Landscape:** No phase-level bug-fix tag exists, so no test covers one. Existing plan-template tests live in `tests/e2e/` static + e2e fixtures (`scripts/tests/fixtures/prop-firm.yaml`). A new phase-tag syntax + its qa-plan criterion would be locked by an `assert_grep` plus (optionally) an e2e plan fixture carrying the tag.

### Pattern Catalog
**Pattern Catalog:**

The binary track contract a bug-fix tag layers onto (note: track is independent of the new bug-fix dimension — a bug-fix phase is a TDD-track/red-first phase that ALSO carries the regression-guard intent):
```markdown
Each phase uses exactly ONE of two tracks:
- **TDD track** — phase contains `[TDD-Red]`. Use for behavior-bearing code ...
- **Implement track** — phase contains `[Implement]` (and NO `[TDD-Red]`). Use for config, infrastructure ...
- **Non-TDD mode** — the plan's front-matter declares `tdd: false`. ALL phases use `[Implement]` + `[Write-Tests]` ...
```

Phase header (the natural attach point for a `**Phase type:**`/bug-fix tag — next to ACs Covered / Authored-tests):
```markdown
### Phase 1 (TDD track example): {{phase_name}}
**ACs Covered:** {{ac_list}}
...
- [ ] **[TDD-Red]** Write failing tests
```

Doctrine RED is mode-gated — the doctrinal gap (no phase-level red-first independent of piece mode):
```markdown
### RED — Write Failing Test (TDD mode only)
- Must fail for the right reason: feature is missing, not typo/setup error
- Agent reports the failure message; orchestrator validates it
```

plan/SKILL.md Non-TDD-mode override — the FR-021 carve-out doc surface:
```markdown
**Non-TDD mode override.** If the plan front-matter declares `tdd: false`:
- Update the Overview section to state: "Non-TDD mode: all phases use Implement track + Write-Tests; AC Coverage Matrix is not required; QA and Final Review remain intact."
```

## Execute Red-First Machinery

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` (Step 1a Detect Phase Mode L391–399 — per-phase checkbox branch; Step 2 Red `(Mode: TDD only … skip when tdd:false)` L467; Step 2.5 qa-tdd-red `(Mode: TDD only … skip when tdd:false)` L518; Step 2.7 Write-Tests Non-TDD L739; Step 3.7a/Step-4 test-integrity re-hash L795; `qa_max_iterations` auto-resolve off front-matter `tdd:` L276; Step 1c `[SPIKE]` resolve on Opus L401–425; Step 6c discovery routing / FR-008). `plugins/spec-flow/agents/tdd-red.md` (the observed-red producer; `## Test Results` verbatim failure output L102–103, `## Oracle block` FAILED list + `0 passed` invariant L105–124, Rule 8/9 "zero passing tests" L48–50, `## Failure Analysis` L127). Co-ship symlink `tdd-red.agent.md`.

### Dependency Map
**Dependency Map:** execute Step 1a branches on the literal `[TDD-Red]` checkbox (per-phase) → dispatches `tdd-red.md` (Step 2) then `implementer.md` Mode:TDD. tdd-red emits staged-test SHA-256 manifest + Oracle block; orchestrator validates failure (the observed-red), snapshots manifest, re-hashes at HEAD (anti-tamper Step 3.7a/4). Several skips key on plan FRONT-MATTER `tdd:` (Steps 2/2.5, qa_max_iterations) NOT the per-phase checkbox — the reconciliation point for per-phase red-first inside a `tdd:false` piece. `[SPIKE]` resolution (Step 1c) is the no-repro escalation path. Step 6c is where out-of-band (FR-008/FR-019) discoveries route.

### Test Landscape
**Test Landscape:** `tests/e2e/` exercises the Red→Build→Verify cycle via fixtures; cheater-oracle harness `tests/e2e/lib/cheater-oracle.sh` (L437 notes a red-first reproduction the shell oracle can't mechanize). tdd-red's `0 passed` invariant is the existing observed-red enforcement. No test today asserts a bug-fix phase runs red-first inside a `tdd:false` piece — that is new coverage.

### Pattern Catalog
**Pattern Catalog:**

Step 1a — per-phase mechanical mode detect (THIS is why a single red-first phase in a `tdd:false` piece is already possible):
```markdown
- Phase contains `[TDD-Red]` → **Mode: TDD**. Run Step 2 (Red) first, then Step 3 (Implement in TDD mode) ...
- Phase contains `[Implement]` and NO `[TDD-Red]` → **Mode: Implement**. Skip Step 2 ...
The orchestrator branches mechanically on the checkbox; it does not decide which mode applies.
```

But Step 2 skips on FRONT-MATTER `tdd:false` (the reconciliation gap):
```markdown
*(Mode: TDD only. Skip this step entirely when the plan uses non-TDD mode (`tdd: false` in plan front-matter). ...)*
```

tdd-red — the observed-red evidence artifact (already produced; the non-substitutable failure record):
```markdown
## Test Results
<verbatim test-runner output showing failures ...>
## Oracle block (for implementer prompt)
FAILED <test identifier> — <one-line cause ...>
<summary line ... e.g. "N failed, 0 passed, K skipped in T">
```

## Triage Out-of-Band Reach & FR-020 Campaign

### File Inventory
**File Inventory:** `plugins/spec-flow/reference/triage-contract.md` (`## Red-first obligation (NN-P-006 forward-record)` L45–53 — already stamps red-first on all 3 provenance surfaces for bug-classified fix dispositions; bug-signal keyword set; `## Dispositions → target surface`; `## FR-008 mid-execution change-signal phrasing set`). `plugins/spec-flow/skills/triage/SKILL.md` (Step "Scan finding_text for keyword set" L47; Step 7 red-first stamp L136–146; AC-6). NO `skills/campaign/` (FR-020 campaign skill does NOT exist — only referenced as triage Form C batch handoff + `status` skill archive logic). execute Step 6c also classifies through the contract.

### Dependency Map
**Dependency Map:** triage/SKILL.md and execute Step 6c BOTH cite `triage-contract.md` (no restatement, NN-C-008). Bug-classified discovery routed to a fix disposition (`small-change` / `plan-amend` / `new-piece`) gets the red-first stamp forward-recorded (handoff digest + `.discovery-log.md` row + manifest/backlog entry). The stamp is FORWARD-RECORD ONLY — explicitly "NO dependency on the unmerged `bugfix-redfirst` machinery", so this piece must make the downstream (small-change / plan-amend / new-piece) consumers actually HONOR the stamp by running red-first.

### Test Landscape
**Test Landscape:** `tests/e2e/lib/static.sh` L295–298 already asserts `red-first` and the notes `source:` token exist in `triage-contract.md`. A new piece extends coverage to the consuming surfaces (small-change/hotfix/plan honoring the stamp).

### Pattern Catalog
**Pattern Catalog:**

triage Step 7 — the existing forward-record stamp (the obligation this piece must make consumers honor):
```markdown
**Red-first stamp (AC-6):** When `bug_classified = true` AND the disposition is a fix disposition (`small-change` / `plan-amend` / `new-piece`), stamp the red-first reproduce→fail→fix→pass obligation onto **all three** provenance surfaces:
```

Contract — forward-record only, no machinery dependency:
```markdown
On a bug-classified discovery routed to a **fix** disposition (`small-change` / `plan-amend` / `new-piece`), stamp the red-first reproduce→fail→fix→pass obligation onto **all three** provenance surfaces ...
Forward-record only — NO dependency on the unmerged `bugfix-redfirst` machinery.
```

## Version-Bearing Files

### File Inventory
**File Inventory:** `plugins/spec-flow/.claude-plugin/plugin.json` (`"version": "5.18.0"`). `plugins/spec-flow/plugin.json` (root-of-plugin copy, also `"version": "5.18.0"` — currently NO skew). `.claude-plugin/marketplace.json` (spec-flow entry `"version": "5.18.0"` at L15; the other entry at L24 is a different plugin v1.1.1). `plugins/spec-flow/CHANGELOG.md` (top released entry `## [5.18.0] — 2026-06-12`; `## [Unreleased]` present above it). `plugins/spec-flow/tests/e2e/lib/static.sh` (HARD-CODES `5.18.0` in three `assert_grep '"version": "5\.18\.0"'` checks L209–214).

### Dependency Map
**Dependency Map:** NN-C-009 requires a version bump to land in ALL version-bearing files together. The three current 5.18.0 sites are the two plugin.json files + the marketplace spec-flow entry, plus the CHANGELOG entry. CRITICAL: the static test `static.sh` L209–214 hard-codes the literal `5.18.0` — a bump MUST update the test regex too or the static suite fails. The root-vs-`.claude-plugin` plugin.json pair is currently in sync (both 5.18.0); keep them so.

### Test Landscape
**Test Landscape:** `tests/e2e/lib/static.sh` L204–214 is the version-sync gate (`assert_grep '"version": "5\.18\.0"'` on plugin.json, marketplace.json, `.claude-plugin/plugin.json`). The `[Unreleased]` CHANGELOG section is where this piece's entry is drafted before release.

### Pattern Catalog
**Pattern Catalog:**

Current synced versions (bump target for this piece):
```json
{ "name": "spec-flow", "version": "5.18.0", ... }   // both plugin.json files + marketplace spec-flow entry
```

The hard-coded version assertion that must be updated in lockstep:
```bash
assert_grep '"version": "5\.18\.0"' "$pluginjson" "AC-11: plugin.json version is 5.18.0"
assert_grep '"version": "5\.18\.0"' "$marketplace" "AC-11: marketplace.json spec-flow entry is 5.18.0"
assert_grep '"version": "5\.18\.0"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" "..."
```
