---
charter_snapshot:
  architecture: 2026-06-01
  non-negotiables: 2026-06-05
  tools: 2026-06-01
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Spec: spike-agent — Opus spike agent + mid-execution scope-change workflow

**PRD Sections:** FR-005, FR-008, G-2, G-3
**Charter:** .claude/skills/charter-*/SKILL.md (binding — see Non-Negotiables Honored / Coding Rules Honored below)
**Status:** draft
**Dependencies:** plan-concrete (merged), sonnet-coord (merged)

## Goal

Make every act of *thinking during execute* a sanctioned, isolated, recorded event — never a mid-stream patch. One new Opus agent (`agents/spike.md`) does the thinking; execute wires it into two call sites that share the agent as their primitive:

- **ROLE 1 — resolve (FR-005):** a planned `[SPIKE]` phase dispatches the agent on Opus in an isolated context to resolve a genuine unknown the plan author could not predict; the resolution is recorded to a durable artifact (and, when the unknown is a test oracle, written back as FR-003 `Test Data`) so the same unknown is never spiked twice.
- **ROLE 2 — scope (FR-008):** any mid-execution scope change — agent-discovered found-work at Step 6c **or** an operator-initiated change request during execute — enters Step 6c triage under one uniform regime. Above the existing 50% diff-ratio threshold the agent runs in *scope* mode to understand the change's full blast-radius and enumerate its task list **before** `plan-amend` touches the plan; below the threshold the change amends directly as today. The resulting amendment phases are placed by a **block-aware** rule that does not preempt in-progress work unless the operator force-stops.

The piece also softens the amendment budget from a hard wall into a guidance checkpoint, and (since the scope workflow increases amendment frequency) keeps the count as the flywheel's "this piece was under-scoped" signal. Everything is additive (NN-C-003): a piece with no `[SPIKE]` markers and no mid-execution change runs exactly as before.

This piece fills three slots its merged dependencies deliberately deferred: `plan-concrete`'s `[SPIKE]`→plan-amendment resolver (`reference/plan-concreteness.md` §4 forward-ref to FR-005), `test-data-up`'s spike→test-data write-back, and `sonnet-coord`'s two abstract model-policy exceptions (`reference/coordinator-contract.md` model-policy table). It honors each prior contract verbatim — it does **not** redefine the `[SPIKE]` marker, the model table, or the `Test Data` schema.

## In Scope

- **New agent `plugins/spec-flow/agents/spike.md`** (Opus, bare `name:`, self-contained): a single-task thinking agent with two modes selected by an injected `mode:` field — `resolve` (resolve a planned `[SPIKE]` unknown) and `scope` (scope a mid-execution change). Isolated context (no coordinator/brainstorm history), returns a ≤2K-token structured digest whose final line is `STATUS: OK` or `STATUS: BLOCKED`; on `BLOCKED` it writes no partial artifact. Dispatches no sub-agents.
- **Canonical reference doc `plugins/spec-flow/reference/spike-agent.md`** holding: the agent's two-mode I/O contract, the spike-artifact schema + location, the change-classification rule (`blocking-on-current` | `blocking-on-later` | `additive`), the block-aware placement rule, the threshold-reuse rule, and the soft-checkpoint budget rule. Execute and `plan-amend` *cite* it (keeps the execute SKILL lean, matching the `coordinator-contract.md` / `research-artifact.md` reference-doc convention).
- **Execute wiring (ROLE 1):** `[SPIKE]`-phase detection dispatches the agent in `resolve` mode on Opus; the resolution is recorded to the spike artifact; when the unknown is a test oracle, the resolution's `Test Data` block is written back so `tdd-red` transcribes it (FR-003 link).
- **Execute wiring (ROLE 2 — admission):** Step 6c admits both triggers — agent-discovered found-work (unchanged sources) and operator-initiated change requests via **detect-and-confirm** (the Sonnet coordinator flags a free-form operator message that reads as a scope change and asks one `y/n` confirmation before admitting).
- **Execute wiring (ROLE 2 — threshold + scope spike):** the existing 50% diff-ratio gate is evaluated for admitted changes in **both** auto and operator modes; `ratio ≥ 0.5` → `scope`-mode spike runs first and writes a scoping artifact that `plan-amend` consumes as input; `ratio < 0.5` → direct `plan-amend` as today.
- **Execute wiring (ROLE 2 — block-aware placement):** the scope-spike classifies the change; placement follows the class; no amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop. Replaces today's unconditional "resume at the first amendment phase."
- **Operator override (FR-005 AC-3 mechanism):** an execute invocation flag `--opus=<phase-id|all>` forces Opus for the named phase(s); parsed at pre-flight and surfaced as the sanctioned override exception in `sonnet-coord`'s model-policy report.
- **Soft-checkpoint amendment budget:** the count is kept; the hard refusal + amend-lockout at threshold is replaced by a guidance prompt (`continue / fork / defer / block`) that re-surfaces on each amendment past threshold; the 1-spec-amendment sub-cap behaves the same way.
- **`plan-amend` input + placement extension:** `plan-amend` reads the scoping artifact (when present) as an additional structured input alongside the existing discovery report, and accepts an optional **placement directive** derived from the scope-spike classification. Its `## Diff of changes` output *format* is unchanged; the insertion position the diff encodes is selected by the directive (absent directive → today's "insert before the next original phase numerically" default, preserving backward-compat — NN-C-003).
- **Plan-finalize `[SPIKE]` gate relaxation (FR-005 handoff):** the `plan/SKILL.md` Phase-4 finalize spike-scan changes from a hard refusal to a **routed-resolution annotation** — a surviving `[SPIKE: <unknown>]` in prose no longer blocks finalize; the plan advances with the marker annotated as "resolved at execute by `spike-agent`," so the `[SPIKE]` phase reaches execute where ROLE 1 resolves it. `reference/plan-concreteness.md` §4 is updated to mark FR-005 as shipped and the gate as relaxed. (`plan-concrete` explicitly deferred this relaxation to FR-005, §4 line 128.) `qa-plan`'s unmarked-unknown must-fix (#29) is unchanged — only a *marked* `[SPIKE]` passes; an unmarked unknown is still a defect.
- **Plugin version bump** 5.6.0 → 5.7.0 across all four version-bearing files + a `CHANGELOG.md` section, with a sync-verify on touch.

## Out of Scope / Non-Goals

- **The model-policy reporting framework itself** — owned by `sonnet-coord` (`reference/coordinator-contract.md`). This piece wires the two sanctioned exceptions (`spike → Opus`, `operator override → Opus`) *into* that report; it does not build the report.
- **The `[SPIKE: <unknown>]` marker definition + syntax/scan-scoping** — owned by `plan-concrete` (`reference/plan-concreteness.md` §2). This piece *consumes* the marker as the resolve-mode trigger and does not redefine its syntax or scan-scoping rules. (It DOES relax the finalize *gate* from hard-refuse to routed-resolution annotation — the sanctioned FR-005 handoff per §4, listed In-Scope above; that is a gate-behavior change, not a marker redefinition.)
- **The `Test Data` block schema** — owned by `plan-concrete` §5 / `test-data-up`. The resolve-mode write-back *produces* a block in that schema; it does not redefine it.
- **The flywheel recording of recurring discovery patterns** (counting unmarked-discovery as a pattern type) — owned by `flywheel-repo` (FR-006). This piece keeps the amendment *count* as a local signal; it does not write `docs/patterns.yaml`.
- **Removing the amendment budget** — explicitly rejected. The count and the threshold checkpoint stay (the under-scoped signal is load-bearing for the flywheel); only the hard block/lockout is removed.
- **A general operator-command parser / NLU** — detection is a deliberately broad heuristic flag plus a `y/n` confirm, not a robust intent classifier. False-positives are accepted (cost: one `y/n`); the confirm is the real gate.
- **Auto-forking / auto-deferring a mid-execution change** — the scope workflow only ever produces a plan amendment (or escalates); fork/defer remain operator-chosen Step 6c outcomes, unchanged.
- **Cross-PRD / machine-global behavior** — none; this is repo-local execute wiring.

## Requirements

### Functional Requirements

- **FR-005.1 (Spike agent):** `plugins/spec-flow/agents/spike.md` exists — Opus, bare `name:`, self-contained, dispatches no sub-agents, runs in an isolated context. It accepts an injected `mode:` (`resolve` | `scope`) plus the mode's inputs, writes its output to the spike artifact, and returns a ≤2K-token digest whose final line is exactly `STATUS: OK` or `STATUS: BLOCKED`. On `BLOCKED` it writes no partial artifact.
- **FR-005.2 (Resolve mode):** When execute reaches a `[SPIKE]` phase, it dispatches the agent in `resolve` mode on Opus in isolation. On `OK`, the resolution is recorded to the spike artifact at the canonical spec-dir path; when the unknown is a test oracle, the resolution carries a `Test Data` block (plan-concreteness §5 schema) that `tdd-red` transcribes — so the same unknown is not spiked twice within the piece.
- **FR-005.3 (No silent upgrade + operator override):** A non-`[SPIKE]` phase the implementer cannot complete on Sonnet **halts and routes to Step 6c** — execute never silently re-runs it on Opus. The operator may force Opus for a named phase via `--opus=<phase-id|all>` at invocation; the forced assignment appears as the sanctioned override exception in the `sonnet-coord` model-policy report.
- **FR-005.4 (Plan-finalize gate relaxation):** The `plan/SKILL.md` Phase-4 finalize spike-scan is relaxed from a hard refusal to a routed-resolution annotation: a surviving `[SPIKE: <unknown>]` in prose no longer refuses finalize; the plan advances with the marker annotated for execute-time resolution by `spike-agent`, and `reference/plan-concreteness.md` §4 is updated to mark FR-005 shipped. The existing scan-scoping rules (skip fenced code + HTML comments) are preserved. Unmarked unknowns remain a `qa-plan` #29 must-fix; only marked `[SPIKE]` markers pass.
- **FR-008.1 (Admission — both triggers):** A mid-execution scope change enters Step 6c triage from either source: (a) agent-discovered found-work (the existing Step 6c sources, unchanged) or (b) an operator-initiated change request, admitted via detect-and-confirm — the coordinator flags a free-form operator message that reads as a behavior/scope change and asks one `y/n` confirmation; `y` admits it to Step 6c, `n` treats it as a comment with no routing. Detection is suppressed while execute is awaiting a structured answer to its own prompt (triage choice, QA sign-off, etc.).
- **FR-008.2 (Threshold → scope spike vs direct amend):** For an admitted change, the existing 50% diff-ratio gate is evaluated in **both** auto and operator modes. `ratio ≥ 0.5` → a `scope`-mode spike runs **before** `plan-amend`, writing a scoping artifact (scope + enumerated task list + classification) that `plan-amend` consumes. `ratio < 0.5` → the change amends the plan directly with no scope spike (today's path). The zero-cumulative-diff edge (ratio undefined) routes to the scope spike (conservative).
- **FR-008.3 (Block-aware placement):** The scope-mode spike classifies the change as `blocking-on-current` (the in-progress phase's own deliverable changes → that phase is re-planned and re-run), `blocking-on-later` (a not-yet-started phase depends on it → the amendment is inserted before that dependent phase; current WIP finishes first), or `additive` (no existing phase depends on it → appended at a dependency-correct position after current WIP). No amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop. Placement is realized by passing the classification to `plan-amend` as an optional placement directive: execute owns the classification (from the spike), `plan-amend` owns encoding the chosen insertion position in its diff. An absent directive defaults to today's "insert before the next original phase" behavior. This replaces today's unconditional "resume at the first amendment phase."
- **FR-008.4 (Artifact + audit trail):** Both the resolve and scope artifacts are recorded under `docs/prds/<prd-slug>/specs/<piece-slug>/spikes/`. The resulting `chore(plan): amend` commit and its `.discovery-log.md` row reference the artifact: the artifact path is appended inside the row's existing **Resolution commit** cell (e.g. `abc1234 chore(plan): amend — … (spike: spikes/<id>.md)`); no `.discovery-log.md` column is added — the FR-15 column set is unchanged.
- **FR-008.5 (Soft-checkpoint budget):** The amendment count is kept. At the threshold (default 5 total; 1 spec-amendment sub-cap) execute prompts `continue / fork / defer / block` instead of refusing; `continue` dispatches the amendment and the prompt re-surfaces on each subsequent amendment. The count never resets and never hard-blocks; the spec-amendment sub-cap follows the same checkpoint behavior. This replaces today's hard refusal + amend-lockout.
- **FR-008.6 (BLOCKED escalation):** A spike (either mode) that returns `STATUS: BLOCKED` causes execute to escalate to the operator with the spike's findings; no plan amendment is dispatched, no resolution is recorded, and no mid-stream patch is applied.

### Non-Functional Requirements

- **NFR-001 (Agent isolation, ≤2K return):** the spike agent always runs in a fresh isolated context with no coordinator/brainstorm history; its return to the coordinator is a ≤2K-token structured digest. Richer detail lives in the on-disk artifact. (Reuses the FR-001/NFR-001 isolation contract.)
- **NFR-003 (Additive / backward-compatible):** a piece with no `[SPIKE]` markers and no admitted mid-execution change runs byte-for-byte as today. The two behavior changes — block-aware placement (replacing unconditional preempt) and the soft-checkpoint budget (replacing the hard wall) — are re-derivable from disk on resume so a fresh context lands the same next action (NFR-002 reuse). The override flag is opt-in (absent → no exception).
- **NFR-004 (Version + self-containment):** minor bump 5.6.0 → 5.7.0 in all version-bearing files; the new agent is self-contained with a bare `name:`; no existing agent's frontmatter is changed.

### Non-Negotiables Honored

**Project (NN-C — from `.claude/skills/charter-non-negotiables/SKILL.md`):**
- NN-C-003 (Backward compat within a major): `[SPIKE]`-free / change-free pieces are unaffected; the placement and budget changes preserve resume correctness from disk; the override flag defaults to absent; the finalize-gate relaxation is strictly more permissive (a *marked* `[SPIKE]` that previously refused now advances — the FR-005-intended direction); no config key, skill name, template header, or hook contract is removed or renamed.
- NN-C-004 / NN-C-008 (Agent files self-contained, bare `name:`): `agents/spike.md` carries a bare `name: spike`, is self-contained, and dispatches no sub-agents; no other agent template is forced to adopt new behavior (the orchestrator drives all wiring).
- NN-C-009 (Always bump version, all files): minor bump 5.6.0 → 5.7.0 across `plugins/spec-flow/plugin.json`, `plugins/spec-flow/.claude-plugin/plugin.json`, the `.claude-plugin/marketplace.json` spec-flow entry, and a new `CHANGELOG.md` `## [5.7.0]` section.
- NN-C-001 (version ⇄ marketplace sync): the marketplace entry is bumped in lockstep; the sync-verify re-runs the `releasing.md` grep recipe on touch.
- NN-C-005 (silent no-op / graceful fallback on absent optional input) — applied to the override flag and the spike-decision: an absent `--opus` flag is a silent no-op; a `[SPIKE]`-free, change-free run dispatches no spike with no warning.
- NN-C-002 (Plugins are markdown + config only — no runtime deps): `agents/spike.md` and `reference/spike-agent.md` are LLM-native markdown; the spike agent uses only the harness Read/Bash/Grep tools and adds no `node_modules`/`pip`/Docker/binary or any runtime dependency.
- NN-C-007 (CHANGELOG in Keep a Changelog format): the new `## [5.7.0] — YYYY-MM-DD` section uses Keep a Changelog groupings (Added/Changed) with at least one non-empty grouping; AC-9 verifies the heading shape.

**Product (NN-P — from `docs/prds/exec-ready/prd.md`):**
- NN-P-002 (No silent or mid-stream execute-time change): the entire piece is the enforcement — every mid-execution change (agent- or operator-initiated) enters Step 6c, is scoped by a recorded spike when above threshold, and routes through plan amendment; no mid-stream patch and no silent decision artifact exists.
- NN-P-005 (Thinking on Opus, mechanics on Sonnet — no silent upgrade): the spike is the *only* in-execute Opus path besides the explicit `--opus` override; a non-`[SPIKE]` Sonnet failure halts to Step 6c rather than upgrading; both Opus uses surface in the model-policy report.
- NN-P-003 (Execute loop is operator-invoked only): detect-and-confirm reacts to operator input and the override flag is operator-supplied at invocation; nothing adds a self-invocation path.

### Coding Rules Honored

- CR-004 (Conventional commits): amend commits keep the `chore(plan): amend — <reason>` form; the version-bump commit uses the plugin scope.
- CR-008 (Thin-orchestrator skills): all wiring/control-flow lives in the execute orchestrator + the cited reference doc; the spike agent does a single task and dispatches no sub-agents.
- CR-009 (Heading hierarchy): edited execute sections preserve the H2/H3/H4 hierarchy; the `### Phase N` / `#### Sub-Phase N.m` detection anchors and the `phase_<N>_amend_<K>` ID convention are not altered.
- CR-005 (Repo-root-relative paths in docs): the new reference doc, the new agent, and all cross-references use repo-root-relative paths.

## Acceptance Criteria

**AC-1 (Spike agent contract).** Given the repository, When `agents/spike.md` is reviewed, Then it declares `name: spike` (bare) and `model: opus`, documents the two modes (`resolve`, `scope`) and their inputs, states the isolated-context + ≤2K-digest + final-`STATUS:` return contract, and states that `BLOCKED` writes no partial artifact.
  Independent Test: read `agents/spike.md` + `reference/spike-agent.md`; confirm bare `name:`, `model: opus`, both modes with input lists, the return contract, and the no-partial-on-BLOCKED rule; confirm the agent dispatches no sub-agents (CR-008) and assumes no conversation history (NN-C-008).

**AC-2 (Resolve mode + test-data write-back).** Given a `[SPIKE]` phase, When execute reaches it, Then it dispatches the agent in `resolve` mode on Opus in isolation, and on `OK` records the resolution to `docs/prds/<prd>/specs/<piece>/spikes/<id>.md`; And when the unknown is a test oracle, the resolution carries a `Test Data` block in the plan-concreteness §5 schema that `tdd-red` transcribes; And the recorded resolution is consumable so the same unknown is not re-spiked within the piece.
  Independent Test: read execute's `[SPIKE]`-phase handling; confirm the `resolve` dispatch (`model: "opus"`), the artifact path + schema cited from `reference/spike-agent.md`, and the write-back path that `tdd-red` reads; confirm the "already-resolved → no re-spike" guard.

**AC-3 (No silent upgrade + operator override).** Given a non-`[SPIKE]` phase the implementer cannot complete on Sonnet, When the failure surfaces, Then execute halts and routes to Step 6c and never re-runs the phase on Opus; And Given `--opus=<phase-id|all>` at invocation, When that phase runs, Then it runs on Opus and the model-policy report lists it as the sanctioned override exception.
  Independent Test: grep execute for any non-`[SPIKE]` Opus-upgrade path — there must be none; confirm `--opus` is parsed at pre-flight and surfaced in the `coordinator-contract.md` model-policy report exception list; spec-compliance reviewer verifies NN-P-005.

**AC-4 (Admission — agent + operator via detect-confirm).** Given agent-discovered found-work, When Step 6c runs, Then it is triaged from the existing sources unchanged; And Given a free-form operator message mid-execute that reads as a scope change, When the coordinator processes it, Then it emits one `y/n` confirmation, routes to Step 6c on `y`, and treats it as a comment on `n`; And Given execute is awaiting a structured answer to its own prompt, When the operator replies, Then detection is suppressed (the reply is the answer, not a change).
  Independent Test: read the Step 6c admission section; confirm the agent-discovered sources are unchanged, the detect-flag → confirm-prompt branch enumerates both `y` and `n` outcomes, and the await-structured-answer suppression branch is stated.

**AC-5 (Threshold → scope spike vs direct amend, both modes).** Given an admitted change with absorption/cumulative-diff `ratio ≥ 0.5`, When triage resolves to amend, Then a `scope`-mode spike runs before `plan-amend` and writes a scoping artifact that `plan-amend` consumes; And Given `ratio < 0.5`, Then the change amends directly with no scope spike; And the ratio is evaluated in both `--auto` and operator modes; And the zero-cumulative-diff (undefined-ratio) case routes to the scope spike; And the resulting `chore(plan): amend` commit and its `.discovery-log.md` Resolution-commit cell reference the scoping artifact path.
  Independent Test: read the threshold computation site; confirm it is evaluated outside `--auto`, the `≥0.5 → spike-then-amend` and `<0.5 → direct-amend` branches, the undefined-ratio → spike branch, that `plan-amend`'s input list includes the scoping artifact, and that the amend commit + `.discovery-log.md` row reference the artifact path inside the Resolution-commit cell.

**AC-6 (Block-aware placement).** Given a `scope`-mode spike returns `OK` with a classification, When execute places the amendment phases, Then `blocking-on-current` re-plans and re-runs the in-progress phase, `blocking-on-later` inserts the amendment before the dependent later phase with current WIP finishing first, and `additive` appends at a dependency-correct position after current WIP; And no amendment phase preempts the in-progress phase except `blocking-on-current` or an explicit operator force-stop; And a fresh-context resume re-derives the placement from disk (plan.md) and reaches the same next phase.
  Independent Test: read the placement rule in `reference/spike-agent.md` + the execute amend-dispatch site; confirm all three classes enumerated with distinct placement, the force-stop preempt branch, the resume-from-disk derivation, that `plan-amend` receives the classification as an optional placement directive selecting the diff insertion position (default = before-next-phase when absent), and that the old unconditional "resume at first amendment phase" (execute amend-dispatch step 6) is replaced by this rule.

**AC-7 (Soft-checkpoint budget).** Given the piece is at the amendment threshold (default 5; spec-amend sub-cap 1), When another amendment is requested, Then execute prompts `continue / fork / defer / block` (not a hard refusal), dispatches the amendment on `continue`, and re-surfaces the prompt on each subsequent amendment; And the count is never reset and never locks out amendments; And on session resume the count is still recovered by grepping committed amend commits.
  Independent Test: read the budget section; confirm today's hard refusal + amend-lockout is replaced by the four-option guidance prompt, `continue` allows further amendments, the spec-amend sub-cap uses the same checkpoint, the count persists, and the resume-recovery grep is retained.

**AC-8 (BLOCKED escalation, both modes).** Given a spike (resolve or scope) returns `STATUS: BLOCKED`, When execute receives it, Then it escalates to the operator with the spike's findings and produces no amendment, no recorded resolution, and no mid-stream patch.
  Independent Test: read both dispatch sites; confirm `BLOCKED` → escalate-with-findings, no partial artifact written, and no `plan-amend` dispatch on that path.

**AC-9 (Version bump + sync).** Given this piece's changes, When committed, Then all four version-bearing files read 5.7.0 identically and CHANGELOG carries a `## [5.7.0] — <date>` section with a non-empty grouping.
  Independent Test: run the `plugins/spec-flow/docs/releasing.md` grep recipe — all four version strings print 5.7.0; CHANGELOG top section is `## [5.7.0]`.

**AC-10 (No-bypass gate).** Given any above-threshold (`ratio ≥ 0.5`) admitted mid-execution change — agent-discovered or operator-confirmed — When execute processes it, Then no branch reaches `plan-amend` (or applies any edit to the worktree) without first dispatching a `scope`-mode spike; And the gate is verified by `qa-plan` (concreteness) and the review-board spec-compliance reviewer per NN-P-002.
  Independent Test: trace every execute branch from admission to amend for the `≥0.5` case (both the agent-discovered Step 6c source and the operator detect-confirm source); confirm each path passes through the scope-spike dispatch before `plan-amend`; confirm no path applies a mid-execution edit without the spike; confirm the gate is stated as an explicit invariant the spec-compliance reviewer can assert against NN-P-002.

**AC-11 (Plan-finalize gate relaxed).** Given a plan with a surviving `[SPIKE: <unknown>]` marker in prose, When `plan/SKILL.md` Phase-4 finalize runs, Then it does NOT refuse — it annotates the marker as execute-resolved (routed-resolution) and the plan advances; And the existing scan-scoping rules (skip fenced code blocks + HTML comments) are preserved; And `reference/plan-concreteness.md` §4 and the `plan/SKILL.md` Phase-4 block both state FR-005 as shipped with the gate relaxed; And `qa-plan` #29 (unmarked-unknown must-fix) is unchanged.
  Independent Test: read the `plan/SKILL.md` Phase-4 finalize spike-scan and `plan-concreteness.md` §4; confirm the hard-refuse path is replaced by an annotate-and-advance path for a *marked* `[SPIKE]`, the fenced-code/HTML-comment skip rules are retained, both docs mark FR-005 shipped, and `qa-plan` criterion #29 still must-fixes an unmarked unknown.

## Technical Approach

**Edit targets.** New `plugins/spec-flow/agents/spike.md`; new `plugins/spec-flow/reference/spike-agent.md`; `plugins/spec-flow/skills/execute/SKILL.md` (the `[SPIKE]`-phase dispatch; Step 6c admission + detect-confirm; the threshold computation now evaluated in both modes; the amend-dispatch placement rule replacing step-6 "resume at first amendment phase"; the soft-checkpoint budget replacing the hard-refusal block; the `--opus` pre-flight parse + model-policy exception surfacing); `plugins/spec-flow/agents/plan-amend.md` (accept the scoping artifact + optional placement directive; diff *format* unchanged); `plugins/spec-flow/skills/plan/SKILL.md` (Phase-4 finalize spike-scan: hard-refuse → routed-resolution annotation); `plugins/spec-flow/reference/plan-concreteness.md` §4 (mark FR-005 shipped, gate relaxed); the four version-bearing files + `plugins/spec-flow/CHANGELOG.md`. No new `.spec-flow.yaml` / `pipeline-config.yaml` key (threshold reuse + budget soft-checkpoint need none).

**Agent design.** One agent, mode-dispatched. `resolve` input: the `[SPIKE: <unknown>]` text + the phase's plan context + (if a test oracle) the `Test Data` skeleton to fill. `scope` input: the change text (operator request or discovery `row_text`) + the current plan + the diff/neighborhood scope. Output (both modes): the spike artifact + a ≤2K digest. `scope` mode additionally emits the **classification** and the **enumerated task list** that `plan-amend` consumes. `BLOCKED` writes nothing and returns findings.

**Spike artifact schema** (canonical in `reference/spike-agent.md`), at `docs/prds/<prd>/specs/<piece>/spikes/<id>.md`:
`mode` (resolve|scope) · `trigger` (the unknown or change text) · `classification` (scope mode: blocking-on-current|blocking-on-later|additive) · `Scope / Task list` (enumerated) · `Resolution` (resolve mode: the answer) · optional `Test Data` block (plan-concreteness §5). `<id>` = the phase id (resolve) or the discovery/change id (scope).

**Threshold reuse.** The existing diff-ratio computation (absorption-size ÷ cumulative-diff) is lifted out of the `--auto`-only branch so it is computed for every admitted change. It now drives two decisions: the existing auto-amend-vs-escalate decision (in `--auto`) and the new spike-vs-direct-amend decision (both modes). Single threshold value (0.5), no new key.

**Block-aware placement.** Replaces execute's amend-dispatch "resume at the first amendment phase." The `scope` spike's `classification` selects placement; `blocking-on-current` re-opens the current phase as `phase_<N>_amend_<K>` and supersedes its remainder (the current work *itself* changed — this is not queue-jumping); `blocking-on-later` inserts before the first dependent phase; `additive` appends after the current phase at a dependency-correct slot. Force-stop (explicit operator signal) preempts immediately in any class. Placement is realized through `plan-amend`'s optional placement directive: execute computes the class from the spike and passes it; `plan-amend` encodes the corresponding insertion position in its diff; an absent directive (below-threshold direct amends, or legacy callers) falls back to today's "before the next original phase" default. Below-threshold direct amends default to `additive` placement unless the discovery report names a dependent phase. Resume re-derives placement from plan.md checkboxes + the amendment IDs already on disk (NFR-003).

**Detect-and-confirm.** A coordinator step inspects free-form operator turns (not structured-prompt answers) for an imperative/suggestion about behavior ("add…", "change…", "we should…", "what if we…"); on a hit it emits one `y/n` confirm. Broad trigger, cheap confirm — biased to avoid false-negatives (the failure mode being fixed). `n` is recorded as a no-op comment.

**Soft-checkpoint budget.** The two counters (`piece_amendment_count`, `piece_spec_amendment_count`) and the resume-recovery grep are retained. The exhaustion *refusal* and the "no further amendments allowed" lock are replaced by a guidance prompt (`continue / fork / defer / block`) that re-fires per amendment past threshold. `block` reproduces today's halt-and-block-piece outcome (operator-chosen, not forced).

**Data flow.** `[SPIKE]` phase → resolve spike (Opus) → artifact (+ Test Data write-back) → `tdd-red`. Mid-execution change → admission (agent source | operator detect-confirm) → threshold → (≥0.5) scope spike (Opus) → scoping artifact → `plan-amend` → block-aware placement → execute; (<0.5) → direct `plan-amend` → placement. Either amend path → soft-checkpoint budget check → commit + `.discovery-log.md` row. `BLOCKED` at any spike → escalate, no writes.

## Testing Strategy

- **No automated harness** (markdown/YAML/bash plugin; charter-tools). Verification is by `qa-plan` / review-board reading the SKILL + agent + reference doc for internal consistency, plus targeted manual smoke.
- **Inspectable-invariant ACs:** AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-9 are phrased so a reviewer diffs the declared contract/placement/threshold/budget rules against the dispatch + computation sites.
- **Manual smoke:** (a) an operator mid-execute "we should also…" message → confirm prompt → `y` routes to Step 6c, `n` no-ops (AC-4); (b) a forced `/clear`-then-resume after a queued `additive` amendment lands the same next phase (AC-6 / NFR-003).
- **Edge cases to cover:** undefined ratio (zero cumulative diff) → scope spike; `blocking-on-current` vs `blocking-on-later` vs `additive` placement; detection suppressed during a structured prompt; `BLOCKED` in resolve vs scope mode; threshold checkpoint `continue` past 5; spec-amend sub-cap checkpoint; absent `--opus` flag (silent no-op).

## Integration Coverage

- Integration: execute → `spike` agent — inside:{execute Step 6c + `[SPIKE]`-phase dispatch, `agents/spike.md`}; doubled externals: none (in-plugin agent dispatch, no runtime boundary); AC-2, AC-5, AC-8; completes the resolve + scope wiring.
- Integration: `spike` (scope) → `plan-amend` — inside:{scoping artifact producer, `agents/plan-amend.md` consumer}; doubled externals: none; AC-5, AC-6, AC-10; the contract surface is the scoping artifact **plus the optional placement directive** (both schema'd in `reference/spike-agent.md`); `plan-amend`'s diff format is unchanged.
- Integration: `spike` (resolve) → `tdd-red` — inside:{resolution `Test Data` block, `agents/tdd-red.md` transcriber}; doubled externals: none; AC-2; reuses the plan-concreteness §5 schema (not redefined here).
- Integration: `--opus` override → `sonnet-coord` model-policy report — inside:{execute pre-flight flag parse, `reference/coordinator-contract.md` exception list}; doubled externals: none; AC-3; this piece supplies the mechanism for the exception `sonnet-coord` declared abstractly.

These are in-plugin documentary contracts (no external service to double); each is verified by reading the producer and consumer for schema/branch agreement, per the no-harness testing strategy.

## Open Questions

None surviving. The two PRD/backlog open questions owned by this piece are resolved above:
- *Operator-change detection* → detect-and-confirm (broad heuristic flag + one `y/n`), detection suppressed during structured prompts (FR-008.1 / AC-4).
- *Spike-first threshold* → reuse the existing 50% diff-ratio gate, now evaluated in both modes; no new config key (FR-008.2 / AC-5). If tuning is later needed, a `spike_threshold` scalar can be added to `pipeline-config.yaml` following the `model_policy` idiom — out of scope here.
