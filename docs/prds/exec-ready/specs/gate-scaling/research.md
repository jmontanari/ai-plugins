# research.md — exec-ready/gate-scaling

## Brainstorm Inference Digest

**Piece purpose.** Make oversight cost scale with verifiability while preserving NN-P-001 in full. Three deliverable clusters: (1) **AC verifiability tagging** — every AC tagged at spec time as machine-checkable (named check) or judgment-required (named judgment); untagged AC = qa-spec must-fix. (2) **Verifiability-scaled sign-off gates** — at the three human gates (spec Phase 5, plan Phase 4, execute Final Review Step 4), render an evidence digest + offer a single summary-confirm keystroke ONLY when QA-clean + zero surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` markers + every machine-checkable AC has evidence attached; otherwise today's full gate runs unchanged. A keystroke is ALWAYS required (NN-P-001 — central constraint). (3) **Two review-cost controls** — `review_board_variant: doc-as-code` (substitute the blind seat with a 2nd edge-case reviewer; codifies pi-011 retro blind 0/6 vs edge-case 6/6) and a single-Opus triage pre-filter on Final Review fix iterations (full board re-dispatches only for contested/new findings; runs on Opus per NN-P-005). Tag ratios flow into metrics.yaml (FR-010).

**Design constraints (from charter + PRD).**
- **NN-P-001** — keystroke never removed at spec/plan/Final-Review; summary-confirm is still a keystroke, not auto-advance. The failure mode (FR-012): if a machine-checkable AC lacks attached evidence, the gate FALLS BACK to the full review prompt; summary-confirm is never offered on incomplete evidence.
- **NN-P-005** — the single-Opus triage pre-filter is an adversarial gate → must run `model: "opus"` (consistent with all board seats today).
- **NN-C-003** — new config keys (`review_board_variant`) and tag enforcement must be additive/back-compat: pre-existing specs without tags, absent config keys default to today's behavior. Pattern to follow: `qa_max_iterations: auto`, `metrics: auto`.
- **NN-C-008** — agent prompts self-contained. **NN-C-009** — bump version in all version-bearing files (plugin.json now 5.12.2; also `.claude-plugin/marketplace.json`, README, CHANGELOG). **CR-007** — config keys documented inline. **CR-008** — thin-orchestrator skills, narrow-executor agents.

**Open ambiguities the spec author must resolve.**
1. **Evidence-attached definition differs per gate.** At execute Final Review, machine-checkable evidence already exists: per-phase `[Verify]` command output + the AC Coverage Matrix (`reference/ac-matrix-contract.md`) + verify-agent reports. But at the **spec** gate (Phase 5) NO code/tests exist yet — "evidence attached" for a machine-checkable AC there can only mean the AC names a concrete check (the "named check"), not that the check has run. Spec must define "evidence attached" separately for the spec gate, the plan gate (AC Coverage Matrix exists in plan.md), and the Final Review gate (Verify output + matrix).
2. **Doc-as-code detection for the board variant.** Today doc-as-code is detected ONLY via the plan front-matter `tdd: false` flag (used by `qa_max_iterations: auto` → 5). There is NO existing "classify cumulative diff by file extension (markdown/agent/skill only)" logic. Spec must choose: reuse the `tdd: false` signal, add a diff-extension classifier, or make `review_board_variant` an explicit plan/config annotation (the pi-011 learnings recommend an explicit `review_board_variant: doc-as-code` annotation). PRD AC-3 says "entirely-doc-as-code cumulative diff" → leans toward diff classification but says "configurable".
3. **Interaction with the existing Final Review iter-loop circuit breaker.** sonnet-coord already made the breaker configurable (`qa_max_iterations` `L`, auto=5 doc-as-code / 3 TDD). The new single-Opus triage pre-filter inserts BETWEEN fix-code landing and the full-board re-dispatch (Step 3). Spec must define how triage outcomes (contested/new vs resolved) interact with the `L`-cycle counter — does a triage-only cycle count against `L`?
4. **AC tag storage shape.** Where the tag lives on each AC line in the spec template (inline annotation vs sub-field like `Independent Test:`) and how qa-spec parses it for the untagged-must-fix check.
5. **Which gates get the summary-confirm.** PRD AC-2 names all three (spec/plan/Final-Review). The spec/plan gates today are soft "Present to user for sign-off" prose (no AskUserQuestion shape specified); Final Review Step 4 is "Present to user … Request approval to merge."

## Codebase Conventions

- **Config-read idiom** (`.spec-flow.yaml`, all keys): read at the skill's Step 0/config-load pass; valid values + default-when-absent stated inline; malformed → one-line warning + fall back to default; cite NN-C-003. Documented in `templates/pipeline-config.yaml` with a CR-007 comment block (valid values / default / "new in vX.Y.Z" / rationale). Verbatim example below in Config + Metrics cluster.
- **Marker convention** — single-line bracketed informational tokens: `[METRICS-DEGRADED: <reason>]`, `[METRICS-ABSENT]`, `[RESEARCH-UNAVAILABLE]`, `[STATE-INCOMPLETE]`, `[TEST-DATA-ABSENT]`, `[FLYWHEEL-DEGRADED]`. Non-blocking; the stage logs and continues.
- **Paired agent files** — every agent ships as both `<name>.md` and `<name>.agent.md` (Claude + Copilot hosts). Edits to one must mirror the other. qa-spec, fix-code, review-board-*, verify all follow this.
- **QA agent structure** — numbered Review Criteria list; `### must-fix` / `### acceptable` output; Input Modes (Full / Focused re-review); circuit breaker per `reference/qa-iteration-loop.md` (iter-until-clean, 3-iter default, configurable via `qa_max_iterations`). Adversarial agents dispatched `model: "opus"`.
- **Board dispatch** — `Read each template from ${CLAUDE_PLUGIN_ROOT}/agents/review-board-<role>.md` then dispatch concurrently with `Input Mode: Full` + `model: "opus"`; each prompt prefixed with `WORKTREE:` preamble.
- **Metrics writes** — upsert-only, serial-checkpoint-only (ADR-4); block-style YAML (one leaf per line, no inline flow maps); degrade to `[METRICS-DEGRADED]`, never block.
- **Sign-off gate prose** — spec/plan use "present to user for sign-off"; execute uses an explicit "Present to user: … Request approval to merge" with APPROVE/REJECT branches. No AskUserQuestion card is currently specified at any of the three gates.

## QA-Spec + Spec Template (AC tagging)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/agents/qa-spec.md` (+ `qa-spec.agent.md` mirror) — 16 numbered Review Criteria; AC-relevant: #6 Testability, #7 surviving-marker must-fix, #12 weasel-word scan of ACs/FRs. A new "every AC carries a verifiability tag; untagged AC = must-fix" criterion slots as #17 (or folds into #6). Reports via `### must-fix` / `### acceptable`.
- `plugins/spec-flow/templates/spec.md` — `## Acceptance Criteria` section: `AC-1: Given … When … Then …` + `Independent Test:` sub-line. The verifiability tag annotation lands per-AC here (new sub-field or inline marker).
- `plugins/spec-flow/skills/spec/SKILL.md` — Phase 3 (Write Spec), Phase 4 (QA Loop, dispatches qa-spec), Phase 5 (Finalize, writes metrics). The untagged-must-fix enforcement threads through Phase 4's qa-spec dispatch.

### Dependency Map
**Dependency Map:** spec/SKILL.md Phase 4 → reads `${CLAUDE_PLUGIN_ROOT}/agents/qa-spec.md` → dispatches `model: "opus"`. qa-spec criteria reference the spec template's AC shape. Phase 5 Finalize writes `metrics.yaml` `spec:` block (where the new machine-checkable ratio field would be added). qa-spec is also dispatched by spec-amend and in Focused charter re-review mode. Spec template is consumed by spec/SKILL.md Phase 3 and read by qa-plan / review-board-spec-compliance downstream.

### Test Landscape
**Test Landscape:** No executable unit tests — these are prose-instruction files (pi-011 doctrine: SKILL/agent/template prose verified by structural reads, not unit tests). Verification = `grep`/LLM-agent-step structural crit-presence reads + the qa-spec / qa-plan adversarial gates + end-of-piece Final Review. A doc-as-code piece (likely `tdd: false`). New AC: every spec AC must carry a verifiability tag, enforced by a new qa-spec criterion — itself verifiable via a structural read of qa-spec.md + a fixture spec.

### Pattern Catalog
**Pattern Catalog:**

Current AC shape in `templates/spec.md` (under the `Acceptance Criteria` H2; tag annotation will extend this):
```
AC-1: Given {{precondition}}, When {{action}}, Then {{outcome}}
  Independent Test: {{how_to_verify_in_isolation}} (for an integration-bearing AC, the Independent Test may assert the real wired path, not isolation)
```

qa-spec criterion #7 (the marker must-fix pattern to mirror for the untagged-tag check):
```
7. **Uncertainty markers:** Any surviving `[NEEDS CLARIFICATION` or `[PENDING-DECISION` markers (open-bracket prefix, no closing bracket) are automatic must-fix findings. For each found: quote the full marker text and the surrounding sentence as evidence.
```

qa-spec output contract:
```
### must-fix
1. [Category] Description of issue
### acceptable
- No issues found in <category>
If no must-fix findings: return "### must-fix\nNone"
```

## Sign-Off Gates (spec / plan / Final Review)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/spec/SKILL.md` — Phase 4 step 4 "When QA returns clean: present spec to user for sign-off." Phase 5 step 1 "User approves → continue. User requests changes → … back to QA loop." Surviving `[PENDING-DECISION]`/`[NEEDS CLARIFICATION]` scanned in Phase 2 brainstorm; qa-spec #7 must-fixes any survivors before sign-off.
- `plugins/spec-flow/skills/plan/SKILL.md` — Phase 3 step 4 "Present to user for sign-off." Phase 4 step 1 "User approves → continue." Finalize spike-scan (FR-002e) runs before commits.
- `plugins/spec-flow/skills/execute/SKILL.md` — `## Final Review` Step 4 "Human Sign-Off" (line 1808): the merge gate. APPROVE → Step 4.5; REJECT → phase reset/rework loop.

### Dependency Map
**Dependency Map:** All three gates run after their QA loop reaches clean (qa-spec / qa-plan / Final-Review board). The summary-confirm branch must read: QA-clean state (already known), surviving-marker count (scan spec.md/plan.md for `[PENDING-DECISION`/`[NEEDS CLARIFICATION`), and per-machine-checkable-AC evidence (spec gate: named check present; plan gate: AC Coverage Matrix rows; Final Review: Verify output + matrix + verify-agent). NN-P-001 binds all three. Each gate is a peer of NN-P-002's two-human-gate model (per-phase QA + end-of-piece board) — execute's two gates must not be bypassed.

### Test Landscape
**Test Landscape:** Prose-instruction gates; no unit tests. Verified structurally (grep for the digest-render + keystroke-always branch) + by reading that the full-gate fallback is preserved. The critical invariant to assert: a keystroke is required on BOTH the summary-confirm and full-gate branches (NN-P-001) — both paths must end in an explicit operator action.

### Pattern Catalog
**Pattern Catalog:**

spec gate (spec/SKILL.md Phase 4 step 4 + Phase 5 step 1):
```
4. When QA returns clean: present spec to user for sign-off.
...
### Phase 5: Finalize
1. User approves → continue. User requests changes → make them → back to QA loop.
```

plan gate (plan/SKILL.md Phase 3 step 4 + Phase 4 step 1):
```
4. Present to user for sign-off.
### Phase 4: Finalize
1. User approves → continue
```

execute Final Review gate (execute/SKILL.md Step 4, line 1808):
```
### Step 4: Human Sign-Off

Present to user:
- Summary of what was built (phases, files, test counts)
- Final review results (clean or deferred items)
- Request approval to merge

**If human APPROVES:** proceed to Step 4.5.
**If human REJECTS (requests rework):** ...
```

## Review Board + Variants + Triage Pre-filter

### File Inventory
**File Inventory:**
- `plugins/spec-flow/skills/execute/SKILL.md` `## Final Review` (line 1629): Step 1 (8-agent / 9-in-fast dispatch, line 1697), Step 1a pre-board linter, Step 2 Triage, Step 3 Fix Loop (line 1748 — where the single-Opus triage pre-filter inserts), Step 8 Final Review Triage (line 1783). Board roster: `blind`, `edge-case`, `spec-compliance`, `prd-alignment`, `architecture`, `security`, `ground-truth`, `integration` (8 standard; +`verify-piece-full` in fast mode = 9). `track="change"` drops prd-alignment → 7.
- `plugins/spec-flow/agents/review-board-blind.md` — the slot the doc-as-code variant SUBSTITUTES. Diff-only, no spec/plan context; checks logic/security/smells/error-handling/resources.
- `plugins/spec-flow/agents/review-board-edge-case.md` — the slot duplicated by the variant (2nd edge-case pass). Walks every branch/boundary; Read access to codebase.
- `plugins/spec-flow/agents/fix-code.md` — Sonnet fix agent; outputs `## Diff of changes` (orchestrator commits). The triage pre-filter runs AFTER this lands, BEFORE board re-dispatch.
- `plugins/spec-flow/skills/review-board/SKILL.md` — out-of-band board (Step 3 dispatch); same lens templates; default lens set `blind, edge-case, security, ground-truth, architecture, integration`. A new triage agent template likely lives at `agents/review-board-triage.md` (does not exist yet).

### Dependency Map
**Dependency Map:** Final Review Step 1 reads each `review-board-<role>.md` template → dispatches concurrently `model: "opus"`. Step 3 fix loop: dispatch fix-code (Sonnet) → commit → re-dispatch reviewers (Focused re-review) → re-triage → circuit breaker `qa_max_iterations` `L`. The new single-Opus triage pre-filter inserts between "commit the fix" and "Re-dispatch reviewers" in Step 3 — a single Opus agent re-checks the specific just-fixed findings; full board re-dispatches ONLY for contested (triage disputes the fix) or new findings. `review_board_variant: doc-as-code` reads at Step 1 board-composition time (swap blind→2nd edge-case). Both the inline (execute) and out-of-band (review-board skill) board compositions are touch points; spec must decide whether the variant applies to both.

### Test Landscape
**Test Landscape:** Prose orchestration + adversarial agents; no unit tests. The pi-011 empirical signal grounds the variant (blind 0/6, edge-case 6/6). Verification: structural reads of the composition branch + the new triage agent template; the existing pipeline-e2e (merged) asserts the board dispatch sequence and is the regression net for execute/SKILL.md surgery. Risk: execute/SKILL.md is ~1,986 lines — gate-scaling, exec-guardrails, pipeline-economics all modify it (manifest WHY note re sequencing).

### Pattern Catalog
**Pattern Catalog:**

Final Review iter-1 dispatch (execute/SKILL.md ~line 1700 — blind is the slot to swap):
```
Agent({ description: "Blind review (iter 1, full)", prompt: <review-board-blind.md + Input Mode: Full + diff only>, model: "opus" })
Agent({ description: "Edge case review (iter 1, full)", prompt: <review-board-edge-case.md + Input Mode: Full + diff + codebase note>, model: "opus" })
```

Step 3 fix loop — insertion point for the single-Opus triage pre-filter (execute/SKILL.md line 1752-1762):
```
- Dispatch fix agent (Sonnet, `agents/fix-code.md`) with all must-fix findings...
- Commit the fix so HEAD advances for the next review cycle:
- Re-dispatch reviewers (fresh) with `Input Mode: Focused re-review`, that reviewer's own prior must-fix findings...
- **Circuit breaker:** `qa_max_iterations` (`L`) full review cycles maximum (`L` ... `auto` resolves to 5 for `tdd: false` pieces and 3 for `tdd: true` pieces).
```

pi-011 retro finding (verbatim, `docs/prds/shared/specs/pi-011-branch-fix/learnings.md`):
```
**Review board composition was mismatched for doc-as-code.** The blind reviewer contributed 0 must-fix items across all 6 iterations. The edge-case reviewer contributed 67%. ... The current 1:1 board composition assumed "code" pieces; doc-as-code needs a different slot allocation.

2. **Add `review_board_variant: doc-as-code` annotation to the plan for pure-SKILL.md pieces.** This signals the orchestrator to substitute the blind reviewer slot with a second edge-case pass...
```

## Config + Metrics (tagging key + ratio field)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/templates/pipeline-config.yaml` — the `.spec-flow.yaml` template; `review_board_variant` config key lands here with a CR-007 comment block. Existing keys to mirror: `qa_max_iterations`, `model_policy`, `metrics`, `flywheel_threshold`, `reflection`, `refactor`.
- `plugins/spec-flow/reference/metrics-artifact.md` — metrics.yaml schema + Write procedure + Field semantics + SC computation. The `spec:` block is where the per-piece machine-checkable AC ratio (+ tag counts) is recorded (written by spec/SKILL.md Phase 5).
- `docs/prds/exec-ready/specs/metrics/spec.md` — the (merged) metrics piece spec; SF-2 (spec writes its block), SF-9 (config key pattern), SF-10 (markers). Defines SC-008 baseline dependency.
- `docs/prds/exec-ready/specs/sonnet-coord/spec.md` + `plan.md` — prior art for adding a configurable key (`qa_max_iterations`) and the `tdd: false`→5 doc-as-code resolution this piece's variant detection may reuse.

### Dependency Map
**Dependency Map:** spec/SKILL.md Phase 5 step 3a writes `spec:` block per metrics-artifact.md Write procedure (upsert, serial-checkpoint, block-style, `[METRICS-DEGRADED]` on failure). The new machine-checkable ratio field is an additive leaf under `spec:` (e.g. `spec.machine_checkable_ratio` + tag counts) — does NOT alter `schema_version` unless breaking (it's additive → stays `1`). `review_board_variant` read at execute Step 1 (board composition) using the standard config-read idiom. `metrics:` key gates whether the ratio is written. gate-scaling `dependencies: [metrics]` — metrics must be merged first (SC-008 baseline).

### Test Landscape
**Test Landscape:** metrics.yaml is parseable by `python3 -c yaml.safe_load` AND grep/awk (block-style invariant). New fields must keep one-leaf-per-line. Verification: structural read of the upserted `spec:` block + a fixture metrics.yaml. Config key verified by reading template comment + the skill's read idiom. SC-008 (operator interactions per clean piece) measured by metrics before gate-scaling ships — gate-scaling's keystroke reduction is the thing SC-008 measures.

### Pattern Catalog
**Pattern Catalog:**

Config-read idiom (execute/SKILL.md line 276 — the exact pattern `review_board_variant` follows):
```
Read the `qa_max_iterations` key from `.spec-flow.yaml` in the SAME pass (valid values: `auto`, or a positive integer; default `auto` when absent/unset — NN-C-003; malformed → one-line warning + `auto`). Resolve `auto` from the plan front-matter `tdd:` field: `tdd: false` → 5, `tdd: true` → 3.
```

CR-007 config-comment block (templates/pipeline-config.yaml — the comment shape to mirror):
```
# qa_max_iterations: configurable QA fix-loop circuit-breaker limit (new in v5.6.0)
#   auto  — resolve per piece track: 5 for doc-as-code/Implement pieces (tdd: false),
#           3 for TDD pieces (tdd: true). ...
#   <int> — explicit cap applied uniformly to all five QA-agent fix-loops
qa_max_iterations: auto
```

metrics.yaml `spec:` block (reference/metrics-artifact.md — additive ratio field lands here):
```
spec:
  qa_rounds: 3            # Phase-2 question→answer exchanges
  qa_iterations: 1        # spec QA gate (Phase 4) loops to clean
  research_artifact: true # research.md present for this piece
  budget_compliance:
    spec_md:
      lines: 121
      ...
```

## Evidence Sources (machine-checkable AC evidence)

### File Inventory
**File Inventory:**
- `plugins/spec-flow/reference/ac-matrix-contract.md` — the AC Coverage Matrix shape (4 columns: AC ID / Status / Pointer / Reason); Build agents emit it, the Step 4 verify gate validates it. The primary "evidence attached" source at execute/Final-Review (a `covered` row with a concrete `file:line` or `[Verify]` assertion reference = attached evidence for a machine-checkable AC).
- `plugins/spec-flow/agents/verify.md` (+ mirror) — Full / Audit / Piece-Full modes; consumes the AC Coverage Matrix + oracle/`[Verify]` output; the verify-agent report is corroborating evidence.
- `plugins/spec-flow/skills/plan/SKILL.md` — Phase 2 authors the per-phase AC Coverage Matrix + each `[Verify]` block (exact command + expected output + failure indicator). The plan gate's "evidence attached" = the matrix row + concrete `[Verify]` command present.
- `plugins/spec-flow/skills/execute/SKILL.md` Step 4 (Verify, line 745) — runs the `[Verify]` command / oracle; output is the runtime machine-checkable evidence captured per phase.

### Dependency Map
**Dependency Map:** machine-checkable AC → its named check → evidence lives in: (spec gate) the AC's named-check field in spec.md only (no run yet); (plan gate) the AC Coverage Matrix row in plan.md + the phase `[Verify]` command; (Final Review gate) the executed `[Verify]`/oracle output + the verify-agent's matrix validation + Build's emitted matrix. The gate's evidence-digest assembly reads these. FR-012 failure mode: a machine-checkable AC whose evidence cannot be assembled → gate falls back to full review, never offers summary-confirm.

### Test Landscape
**Test Landscape:** AC matrix has explicit validation rules (6 reject conditions in ac-matrix-contract.md) + refusal contracts — already machine-enforced at execute Step 4. `[Verify]` concreteness enforced by qa-plan #29/#32. Verify-agent runs the Theater Pattern Catalog. These existing gates are the evidence the digest cites; gate-scaling reuses them rather than inventing new evidence capture.

### Pattern Catalog
**Pattern Catalog:**

AC Coverage Matrix shape (ac-matrix-contract.md — the evidence pointer for a machine-checkable AC):
```
| AC ID | Status   | Pointer                          | Reason |
| AC-1  | covered  | tests/path/to/test_file.py:42    | —      |
| AC-2  | covered  | tests/path/to/test_other.py:71   | —      |
```
A `covered` row with a concrete `file:line` (or a concrete assertion reference inside the `[Verify]` command) is the "evidence attached" signal; a vague pointer (`see test file`, no line) FAILS validation — exactly the incomplete-evidence case that forces full-gate fallback.

verify agent Audit-mode evidence check (agents/verify.md):
```
### Mode: Audit
Used when Build reported everything clean: oracle ran GREEN on first attempt, zero deviations, and a complete AC coverage matrix.
... confirm each AC→test mapping is real (the named test actually exercises the AC; the named assertion actually checks it) ...
```
