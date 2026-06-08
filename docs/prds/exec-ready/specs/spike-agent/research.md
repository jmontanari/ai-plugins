# research.md — spike-agent (PRD: exec-ready)

## Brainstorm Inference Digest

**Piece purpose.** Build one new Opus agent `plugins/spec-flow/agents/spike.md` plus execute wiring, serving two roles on the same agent:
- **ROLE 1 (FR-005)** — a `[SPIKE]` plan phase dispatches `spike.md` on Opus in isolated context to resolve a genuine unknown and record a structured resolution to a durable artifact (consumable as FR-003 test data). A non-`[SPIKE]` phase the implementer can't finish on Sonnet **halts → plan amendment (Step 6c)**, never a silent Opus upgrade. Operator override forces Opus for a named piece/phase.
- **ROLE 2 (FR-008)** — any mid-execution scope change (agent-discovered at Step 6c OR operator-initiated "add/change/do X" during execute) enters Step 6c triage under one uniform regime; **above** the 50% diff-ratio gate the same spike agent scopes the change first and writes a scoping artifact that `plan-amend` consumes; **below** it amends directly. Amendment phases queue at a dependency-correct position and do NOT preempt in-progress work unless the operator force-stops. Amends NN-P-002. Spike that can't resolve/scope returns BLOCKED.

**Dependencies** `plan-concrete` + `sonnet-coord` both merged. `plan-concrete` shipped the `[SPIKE: <unknown>]` marker, the finalize-block, and the §4 FR-005 forward-reference. `sonnet-coord` shipped the Model-Policy framework (`coordinator-contract.md`) that names exactly two abstract exceptions — *spike phase → Opus* and *operator override → Opus* — but explicitly **does not** wire the mechanisms (its Out-of-Scope §36 hands both to this piece). This piece fills those two named slots.

**Design constraints the spec author must resolve (open ambiguities):**
1. **Operator-change detection (PRD Open Question, owner = this piece):** execute has no existing "is this operator input a change request?" classifier. spec must define how a mid-execute "add/change/do X" is recognized vs a normal answer/triage reply, and at what point in the per-phase loop it is admitted into Step 6c. The conservative model is to admit it only at a defined checkpoint (e.g., between phases / at Step 6c), not preemptively mid-phase.
2. **Where the scoping/resolution artifact lives + its schema.** Pattern precedent: `research.md` and `.discovery-log.md` both live at `docs/prds/<prd-slug>/specs/<piece-slug>/`. The spike artifact should sit there (e.g. `spike-resolutions.md` or `.spike-log.md`). FR-008 AC requires it be referenced by the `chore(plan): amend` commit and its `.discovery-log.md` row. The artifact must be shaped to satisfy plan-amend's `Structured discovery report` input contract (Type/Source/Why-this-blocks/Proposed-amendment-scope/Estimated-absorption-size) AND, for ROLE 1, the §5 `Test Data` block shape so FR-003's tdd-red can transcribe it.
3. **Queue-without-preempt vs today's "resume at first amendment phase."** Today Amend dispatch step 6 (`execute/SKILL.md` L1057) *resumes execution at the first amendment phase* using `phase_<N>_amend_<K>` — i.e. amendment phases preempt by being run next. FR-008 AC-4 requires the opposite: WIP completes first, amendment phases queue at a dependency-correct position, preemption only on operator force-stop. spec must reconcile this — likely a new insertion-position rule (after current WIP) distinct from plan-amend's current "insert before next original phase" rule.
4. **New `.spec-flow.yaml` (pipeline-config.yaml) key?** PRD Open Question leans *reuse the 50% diff-ratio gate, configurable*. The existing gate is hard-coded `0.5` in Step 6c Auto-mode (L1011/1013). Adding `spike_threshold` (or making the existing ratio configurable) would match the established opt-out-scalar idiom (`model_policy`, `qa_max_iterations`). Lean: reuse the gate; only add a key if the spec wants the threshold tunable.
5. **Spike isolation + return (NFR-001):** spike.md must be context-isolated, all inputs in-prompt (NN-C-008), and return a ≤2K-token structured digest with a final `STATUS: OK | BLOCKED` line — exactly mirroring `agents/research.md`.

## Codebase Conventions

- **Agent frontmatter (CR-001, NN-C-004):** YAML block with bare `name:` (no `spec-flow:` prefix), `description:`, and optional `model:`. Thinking agents declare `model: opus` (research.md), mechanics declare `model: sonnet` (plan-amend.md); tdd-red/qa-plan omit `model:` (inherit). `description:` opens with `Internal agent — dispatched by spec-flow:<skill>. Do NOT call directly.`
- **Self-containment (NN-C-008):** every input injected in-prompt; agents state "do not assume any prior conversation context."
- **Return contract idiom:** structured digest, ≤2K tokens, FINAL line exactly `STATUS: OK` or `STATUS: BLOCKED`; on BLOCKED, reason precedes the status line and no partial artifact is written (see research.md, plan-amend BLOCKED rule).
- **Define-once / cite-everywhere:** authoritative defs live in one `reference/*.md` (research-artifact.md, plan-concreteness.md, coordinator-contract.md); skills/agents *cite* and do not restate. A new spike contract likely belongs in a new `reference/` doc cited by execute + spike.md + plan-amend.md.
- **Commit convention (CR-004):** conventional-commits w/ plugin scope, e.g. `chore(plan): amend — <reason>`, `feat(<slug>): … — spec-flow <version>`. End-of-commit Co-Authored-By trailer.
- **Versioning (NN-C-009 / NN-C-001):** four version-bearing files must stay in sync: `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, + CHANGELOG. All four currently at **5.6.0** (no skew — the historic 5.2.1 skew is already corrected). This behavior change bumps to **5.7.0** (additive/minor).
- **Markers:** bracketed `[UPPERCASE: <detail>]` in orchestrator output, not in artifacts; scan-scoping skips fenced code + HTML comments (plan-concreteness §2).

## Cluster 1 — Execute Step 6c Discovery Machinery (ROLE 2 wires here)

### File Inventory
**File Inventory:** `plugins/spec-flow/skills/execute/SKILL.md` Step 6c "Discovery Triage" (L936–1182): Aggregation (3 sources L944–965), Triage prompt + a/f/d/s options (L967–987), Auto-mode 50% threshold (L989–1021), Amend dispatch (L1023–1065), Fork (L1067–1086), Defer (L1088–1098), Amendment budget (L1100–1151), `.discovery-log.md` authoring (L1153–1174), Recursion (L1176–1178), NN-P-002 preservation (L1180–1182).

### Dependency Map
**Dependency Map:** Step 6c consumes `phase_<id>_routed_discoveries` (Step 4), Step 6 `Deferred to reflection:` findings, and Build missing-prerequisite escalations → dispatches `agents/plan-amend.md` / `agents/spec-amend.md` / `/spec-flow:defer`. ROLE 2 inserts a pre-`plan-amend` spike step on the above-threshold branch and a new operator-initiated trigger source into Aggregation.

### Test Landscape
**Test Landscape:** No unit runner. Validated by: Step 6 per-phase `qa-phase` (Opus) gate, Final Review board, and review-board / qa-plan verifying the NN-P-002 gate (PRD AC: "no execute path applies an above-threshold change without scoping spike + amendment"). The fixture style is grep-the-SKILL Independent Tests (see sibling specs).

### Pattern Catalog
**Pattern Catalog:**
```
ratio = <estimated-absorption-size> / <cumulative-diff-size>
<cumulative-diff-size> = git diff --shortstat $piece_start_sha..HEAD (ins+del)
# Auto-amend if ratio < 0.5; otherwise escalate to operator-mode triage prompt.
```
```
6. Resume execution at the first amendment phase using suffix-form ID
   phase_<N>_amend_<K> (FR-13). [<-- FR-008 must change to queue-without-preempt]
```

## Cluster 2 — plan-amend agent (spike scoping artifact must feed this)

### File Inventory
**File Inventory:** `plugins/spec-flow/agents/plan-amend.md` (66 lines, `model: sonnet`). Inputs (L19–28): full plan.md, **Structured discovery report** (`Type` / `Source` / `Why this blocks` / `Proposed amendment scope` / `Estimated absorption size`), diff+neighborhood scope. Output: `## Diff of changes` unified diff inserting `phase_<N>_amend_<K>` before next original phase; `(none)` → Build re-dispatch; BLOCKED if not single-cycle-addressable.

### Dependency Map
**Dependency Map:** dispatched only by execute Step 6c Amend dispatch. The scoping spike's artifact must populate the same five report fields so `plan-amend` consumes it unchanged. plan-amend does NOT commit (orchestrator stages + commits).

### Test Landscape
**Test Landscape:** Diff validated by orchestrator `git apply --check` then `git apply` (L1033–1047); then qa-plan `Focused re-review` iter-until-clean before commit. Self-policing rules (CR-009 heading hierarchy, charter-citation slot).

### Pattern Catalog
**Pattern Catalog:**
```
- Structured discovery report:
  - Type: requires-amendment | requires-fork | does-not-block-goal | qa-finding-out-of-scope
  - Source: originating phase id + agent name
  - Why this blocks: ... cites NN-C / NN-P / CR IDs
  - Proposed amendment scope: list of phases to add/modify
  - Estimated absorption size: LOC count
```

## Cluster 3 — Model Policy / Coordinator Contract

### File Inventory
**File Inventory:** `plugins/spec-flow/reference/coordinator-contract.md` `## Model Policy` table + the two-exception paragraph (L23: "(1) spike phase → Opus … wired by `spike-agent` piece, FR-005; (2) operator override → Opus … `spike-agent`, FR-005 AC-3"). Execute Pre-flight Model Check (L13–45) + Per-stage model policy report (L47–53). Config: `model_policy: auto|off` (pipeline-config.yaml L55–60).

### Dependency Map
**Dependency Map:** This piece supplies the two mechanisms the contract names abstractly. The contract's table row "spike … opus … Step 6c/spike phase" and the override row must agree with the new dispatch site(s) this piece adds (AC-1 Independent Test diffs each row vs its dispatch site). Must NOT add any path upgrading a non-`[SPIKE]` stage to Opus (NN-P-005).

### Test Landscape
**Test Landscape:** AC-1 grep-diff: every in-execute model-policy row must match an `Agent({… model:})` dispatch site. sonnet-coord AC-3 greps execute for any non-`[SPIKE]` Opus-escalation path (must be absent).

### Pattern Catalog
**Pattern Catalog:**
```
| Stage | Model | Dispatch site |
| coordinator | sonnet | execute pre-flight |
| ...
Exactly two exceptions upgrade an in-execute stage to Opus and are the only
assignments the policy *flags*: (1) spike phase → Opus; (2) operator override → Opus.
```

## Cluster 4 — [SPIKE] marker + finalize handoff

### File Inventory
**File Inventory:** `plugins/spec-flow/reference/plan-concreteness.md` §2 marker syntax/scan-scoping, §4 finalize spike-block + **FR-005 forward reference** (L112–130: "FR-005 adds an Opus spike resolver that clears a `[SPIKE]` via a Step 6c plan amendment … after the plan amendment is applied, the finalize gate is relaxed to a routed-resolution annotation rather than a hard refusal"), §5 per-case `[SPIKE]` in Test Data. Cited by `plan/SKILL.md` Phase-2 §2f/§9d + Phase-4 finalize scan.

### Dependency Map
**Dependency Map:** ROLE 1 implements the §4 forward reference — the spike agent's resolution becomes a plan amendment that replaces the `[SPIKE]` marker with concrete content. This piece may need to relax the interim hard finalize-refusal (§4 "interim until FR-005 ships") to the routed-resolution behavior.

### Test Landscape
**Test Landscape:** plan/SKILL.md Phase-4 finalize scan (skips fences + HTML comments) refuses while any `[SPIKE]` survives; qa-plan criteria #28–#31. No marker survives → silent no-op.

### Pattern Catalog
**Pattern Catalog:**
```
[SPIKE: <description of the unknown>]   # brackets literal, SPIKE uppercase
# §4 interim: finalize refuses while any [SPIKE:] survives in prose.
# FR-005: spike resolves via Step 6c plan amendment → gate relaxed to annotation.
```

## Cluster 5 — tdd-red consumption (FR-005 AC4 → FR-003 link)

### File Inventory
**File Inventory:** `plugins/spec-flow/agents/tdd-red.md` (Context: "**Test Data block:** the phase's `Test Data` block … the oracle you transcribe; you author no input or expected outcome absent from it"). execute Step 2.7 / L670 `[Write-Tests]` mirror. `plan-concreteness.md` §5 Test Data contract (block schema, per-case `[SPIKE]`, transcribe-only, absent→legacy / incomplete→BLOCKED).

### Dependency Map
**Dependency Map:** ROLE 1 closes the loop — a `[SPIKE]` in a Test Data expected-outcome position (§5) is resolved by the spike agent; the resolution is written back as concrete test data BEFORE the TDD phase runs, so tdd-red transcribes it. The spike resolution artifact format must match the §5 `**Test Data:**` line shape (`<case-id>: input … → expect …`).

### Test Landscape
**Test Landscape:** tdd-red emits `BLOCKED — Test Data gap` on present-but-incomplete; `[TEST-DATA-ABSENT]` on absent (legacy). qa-plan #31 gates new plans on block presence.

### Pattern Catalog
**Pattern Catalog:**
```
**Test Data:**
- tok-malformed: input "not_a_jwt" → expect [SPIKE: exact error type needs integration test]
# spike resolves → marker replaced with concrete expected value → tdd-red transcribes.
```

## Cluster 6 — Agent file authoring conventions (for agents/spike.md)

### File Inventory
**File Inventory:** `agents/research.md` (opus, isolated, ≤2K digest, STATUS line), `agents/plan-amend.md` (sonnet, BLOCKED discipline, no-commit, Output Format block), `agents/qa-plan.md` (read-only adversarial). spike.md should mirror research.md's isolation + STATUS contract and plan-amend's structured-report + BLOCKED idioms.

### Dependency Map
**Dependency Map:** spike.md is dispatched by execute (Step 6c above-threshold ROLE 2, and the `[SPIKE]`-phase ROLE 1 path). It writes a durable artifact and returns a bounded digest. No sub-agent dispatch (NFR-001).

### Test Landscape
**Test Landscape:** Self-containment / frontmatter validated by review-board architecture + spec-compliance reviewers and qa-plan style checks; charter NN-C-004/008 + CR-001 are the binding rules. No runtime test.

### Pattern Catalog
**Pattern Catalog:**
```
---
name: spike
description: "Internal agent — dispatched by spec-flow:execute. Do NOT call directly. ..."
model: opus
---
# ... Injected Inputs (No History) ... Return Contract: ≤2K digest; FINAL line STATUS: OK | BLOCKED
```

## Cluster 7 — Config + version

### File Inventory
**File Inventory:** `plugins/spec-flow/templates/pipeline-config.yaml` (keys: `model_policy: auto`, `qa_max_iterations: auto`, `deferred_commit`, `refactor`, etc. — opt-out-scalar idiom). Version files: `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, CHANGELOG — all at **5.6.0**, synced. NOTE: there is no `.spec-flow.yaml` at repo root in this repo; the canonical project config is `templates/pipeline-config.yaml` (the PRD/specs refer to it as `.spec-flow.yaml`, the per-install copy).

### Dependency Map
**Dependency Map:** if the spec adds a configurable spike threshold, follow the `model_policy`/`qa_max_iterations` scalar pattern (commented block + `auto`/`<value>` default, read at Step 0). Bump all four version files + CHANGELOG (NN-C-009/001) to 5.7.0.

### Test Landscape
**Test Landscape:** version sync verified on touch (sonnet-coord did this for 5.6.0); config keys read at execute Step 0 Load Config.

### Pattern Catalog
**Pattern Catalog:**
```
# model_policy: controls the execute per-stage model report (new in v5.6.0)
#   auto — ... flags only the two sanctioned exceptions (spike phase / operator override)
#   off  — run only the legacy Pre-flight Model Check prompt
model_policy: auto
```

## Cluster 8 — Forward-referencing sibling specs

### File Inventory
**File Inventory:** `docs/prds/exec-ready/specs/plan-concrete/spec.md` (Out-of-Scope explicitly defers "the spike resolver — the Opus spike agent `agents/spike.md`, its isolation … to FR-005"). `test-data-up/spec.md` (Out-of-Scope: "Spike resolver (Opus spike agent + execute-time `[SPIKE]` dispatch + spike→test-data write-back) — FR-005"). `sonnet-coord/spec.md` (Out-of-Scope §36: operator-override mechanism + `[SPIKE]` Opus dispatch wiring owned by this piece).

### Dependency Map
**Dependency Map:** This piece is the convergence point for three deferred handoffs: (1) plan-concrete's `[SPIKE]`→amendment resolution, (2) test-data-up's spike→test-data write-back, (3) sonnet-coord's two named model-policy exceptions. The spec must honor each prior contract verbatim (no re-defining the marker, the model table, or the Test Data schema).

### Test Landscape
**Test Landscape:** prd-alignment + spec-compliance review-board agents check that this piece fills exactly the slots the siblings deferred, with no scope overlap.

### Pattern Catalog
**Pattern Catalog:**
```
# sonnet-coord Out-of-Scope §36:
The operator-override mechanism itself ... and the [SPIKE] Opus dispatch wiring
— owned by spike-agent (FR-005 AC-3), which depends_on: sonnet-coord. This piece
defines only the reporting framework that names these two exceptions abstractly.
```
