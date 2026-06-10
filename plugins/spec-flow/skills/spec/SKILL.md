---
name: spec
description: >-
  Use when the user wants to brainstorm, design, or think through how a feature or piece of work
  should behave — before writing code. This is the primary entry point for any "what should X do?"
  conversation. Brainstorms requirements one question at a time, writes a spec with acceptance
  criteria, runs adversarial QA review, and gets human sign-off before advancing. Trigger on
  "brainstorm", "let's think through", "how should X work", "design this", "figure out the
  requirements", "think through the design", "what do we need to build", "acceptance criteria for",
  "design doc", "let's design the next piece", "spec out X", "write a spec for Y", or any time the
  user wants to clarify behavior and constraints before planning or building. Also triggers whenever
  the pipeline has an open piece ready to spec — even if the user doesn't say "spec" explicitly.
---

## Pre-flight: Model Check

Before any other step, verify the active model is an Opus-class model.

Determine the active model using the platform-appropriate method:

- **Copilot CLI** — read the `<model_information>` system tag injected into this session's context. The model name and ID are present there explicitly.
- **Claude Code** — no equivalent tag is injected. Use Claude's self-knowledge: introspect your own model identity (Claude reliably knows which model variant it is from training) and treat that as the model name for the check below.

If the active model name does **not** contain `opus` (case-insensitive):

1. Use `ask_user` to block and prompt the user:

   > ⚠️ **Model mismatch.** Spec authoring is thinking work per NN-P-005, but the active model appears to be **[model-name]**.

   Choices:
   - "Override — proceed on [model-name]"
   - "Change now — I'll switch models"
   - "Cancel spec"

2. If the user selects **"Cancel spec"** → stop immediately and emit:
   `Spec cancelled. Re-run after switching to an Opus model.`

3. If the user selects **"Override — proceed on [model-name]"** → proceed to Step 0 immediately on the current model. Emit a one-line acknowledgment first:
   `Overriding model check — proceeding on [model-name]. Spec quality may be reduced.`

4. If the user selects **"Change now — I'll switch models"** → **close the prompt and return control to the user.** The model cannot be switched while an `ask_user` prompt is blocking, and there is no programmatic model-change event to listen for — so leave the dialog and wait for the user to signal. Emit:
   `Switch to an Opus model now. When ready, type "proceed" to resume, or "cancel" to stop.`
   Then wait for the user's free-text reply:
   - On `proceed` (or any "I've switched / continue" phrasing) → re-run this model check (re-introspect your model identity on Claude Code, or re-read the `<model_information>` tag on Copilot CLI). If the model now contains `opus`, proceed to Step 0. If it still does not, re-present the three choices above.
   - On `cancel` → stop and emit the cancellation line from step 2.

If the model already contains `opus` → proceed to Step 0 immediately with no prompt.

# Spec — Author Spec for One Piece

Author a detailed specification for one piece from the manifest through Socratic dialogue, adversarial QA review, and human sign-off.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- `docs/prds/<prd-slug>/manifest.yaml` must exist (run `prd` first). `<prd-slug>` is the slug of the PRD that owns the target piece — the manifest lives under that PRD's folder per `plugins/spec-flow/reference/v3-path-conventions.md`.
- The piece must have status `open` in the manifest

## Workflow

### Phase 1: Load Context

> Phase 1 includes a **dependency precondition check** (step 6a below) that runs the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list before authoring begins.

1. Read `docs/prds/<prd-slug>/manifest.yaml` — find the target piece (from user argument or next `open` piece). Resolve `<prd-slug>` from the user's argument or by scanning `docs/prds/*/manifest.yaml` for the next `open` piece across PRDs. Capture both `<prd-slug>` (owning PRD) and `<piece-slug>` (target piece) for use throughout the skill — every path below is parameterized on these two slugs.
2. Read `docs/prds/<prd-slug>/prd.md` — extract the PRD sections mapped to this piece
3. Run the Charter Context Loading Protocol specified in
   `plugins/spec-flow/reference/brainstorm-procedure.md` per the reference doc's
   "## Charter Context Loading Protocol" section. Charter location resolves per
   `plugins/spec-flow/reference/charter-location.md` — the active charter root is
   `<charter_root>` (`.github` or `.claude`). Outputs: `charter_snapshot`, `integration_cfg`.
4. Scan `<docs_root>/prds/<prd-slug>/specs/*/learnings.md` — load learnings from previously completed pieces in this PRD
5. Scan for binding rules across namespaces. Charter paths use the active charter root
   (resolved per `plugins/spec-flow/reference/charter-location.md`) — `<charter_root>` is
   `.github` or `.claude`:
   - **NN-C**: `<charter_root>/skills/charter-non-negotiables/SKILL.md` (if the charter root has no charter skills, there are no project-level NNs yet)
   - **NN-P**: `<docs_root>/prds/<prd-slug>/prd.md` (Non-Negotiables (Product) section)
   - **CR**: `<charter_root>/skills/charter-coding-rules/SKILL.md`
6. Read `<docs_root>/prds/<prd-slug>/backlog.md` if it exists. This is the PRD-local backlog — it accumulates end-of-piece reflection findings from prior pieces in this PRD (future opportunities deferred to later pieces of the same PRD). For each item recorded, semantic-match against this piece's name (from manifest) and the user's brainstorm prompt; surface the ~5 most-relevant items as candidate considerations during Phase 2 brainstorm. Track user responses in orchestrator state for Phase 5 prune (statuses: `incorporated` — addressed by this piece's spec; `deferred` — still relevant but not in this piece's scope; `obsolete` — no longer applies). If the file does not exist (first piece on a new PRD), skip silently. If `reflection: off` is set but the file exists from a previous run, still read it — stale findings from past reflections may still be useful brainstorm context. (Process-retro items live in the global `<docs_root>/improvement-backlog.md`; that file is touched only by the reflection-process-retro agent and is out of scope for this skill.)
6a. **Dependency precondition check (FR-4 of pi-010-discovery, AC-5).** Run the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list, read from the manifest entry loaded in step 1 (`docs/prds/<prd-slug>/manifest.yaml`). For each ref, resolve per the reference doc's "Reference resolution" section (qualified `<dep-prd-slug>/<dep-piece-slug>` against `docs/prds/<dep-prd-slug>/manifest.yaml`; bare `<dep-piece-slug>` against the current PRD's manifest). On resolution failure, refuse with the exact resolution-failure refusal string from the reference doc — do NOT prompt for triage on a malformed/missing ref. On successful resolution, classify each dep's `status:` per the reference doc's "Status interpretation" section. If every resolved dep is `merged` or `done`, this step is a silent no-op (no prompt, no recorded state) and Phase 1 continues to step 7 (NN-C-005). If any resolved dep has a transient or structural-failure status, render the three-option triage prompt verbatim from the reference doc's "Triage options at spec/plan time" section (literal `(1) pull-deps-in`, `(2) fork`, `(3) proceed` markers; one bullet per unmet dep). Record the operator's choice and the per-dep status snapshot in orchestrator state keyed for Phase 3's spec.md authoring step to read. **Structural-failure statuses (`superseded`, `blocked`) refuse the `(3) proceed` option** — apply that rule symmetrically to the spec-time prompt per the reference doc.
7. **Charter-drift check.** If the target piece's `spec.md` already exists and carries a `charter_snapshot:` front-matter (i.e., this is an update/amend re-run, not a greenfield first-run), execute the charter-drift procedure specified in `plugins/spec-flow/reference/charter-drift-check.md`: compare the spec's `charter_snapshot:` values against the current charter dates captured in step 3 (`git log` last-commit date per domain — charter skills carry no `last_updated:` front-matter), and on any drift dispatch `qa-spec` with `Input Mode: Focused charter re-review` per that reference. On `clean`: auto-advance the snapshot and continue. On `must-fix`: halt the skill and surface findings — no escape hatch. Skip this step on greenfield runs (no spec yet, nothing to drift).
8. Integration config load is handled by the Charter Context Loading Protocol in
   `plugins/spec-flow/reference/brainstorm-procedure.md` `"## Charter Context Loading Protocol"` section.
   `integration_cfg` is already populated. This step is a no-op — proceed to Phase 2.

### Phase 2: Brainstorm

**Integration — create piece issue (if `integration_cfg != null` and `auto_create_tasks: true`):**
Run the capability check from `plugins/spec-flow/reference/integration-capability-check.md`
for operation `create_piece_issue`. If the tool is available:
- From `integration_cfg.hierarchy`, find the entry with `managed_by: spec` → this is the piece level (`piece_level`).
  Let `parent_level` = the entry immediately above it in the list.
- Read the parent key: from `parent_level`, resolve `artifact` (e.g. `prd`) and `key_field` (e.g. `jira_key`).
  Read that field from `<docs_root>/prds/<prd-slug>/prd.md` front-matter.
  **If the field is absent → refuse:** "Cannot create piece issue: `prd.md` must have
  `<key_field>:` set (hierarchy requires a `<parent_level.type>` parent for every `<piece_level.type>`).
  Set it manually in `prd.md` front-matter and re-run."
- Create an issue of type `piece_level.type` in project `integration_cfg.project_key`
  using the naming convention from `piece_level.naming` or the default
  (default: `{piece-slug} — {piece description from manifest}`).
  Pass `additional_fields: {"parent": "<parent_key_value>"}` — this is **required**, not optional.
- Apply Task Creation Requirements from `charter-integrations` (the active charter root, resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-integrations/SKILL.md`, where `<charter_root>` is `.github` or `.claude`):
  - **Story points:** read `story_points_field` from `piece_level`. If present, estimate piece effort in days,
    compute `ceil(days × 0.5)` rounded up to next Fibonacci number, pass as `additional_fields: {"<story_points_field>": <value>}`.
  - **Assignee:** call `jira_get_user_profile` with `user_identifier: "me"` to get the authenticated user's `accountId`.
    Pass as `assignee` on the create call.
  - **Initial status:** issue is created in `To Do` by default — no transition needed at creation time.
- Record the returned issue key: write `<piece_level.key_field>: <key>` (i.e. `jira_key: <key>`)
  and `jira_url: <integration_cfg.base_url>/browse/<key>` to spec.md front-matter
  so plan, execute, and status skills can find and link to it.
On tool unavailable → emit warning → skip.

Socratic dialogue with the user, one question at a time. **Prefer multiple-choice questions** when possible — they're faster to answer than open-ended. Ask one question per message; if a topic needs more exploration, break it into sequential messages. The brainstorm is complete when every sub-area in step 3 below has been explored and each meets the C-3 floor check (one concrete example + one failure mode). There is no question count — ask as many as it takes. Do not ask theater questions (questions whose answer is already clear from the PRD, prior responses, or obvious context). If an area is clear, confirm it in one sentence rather than asking.

**Before the first question — scope check.** Assess whether the piece as described covers multiple independent subsystems (e.g., "vault integration, CI pipeline changes, and a new CLI command" is three pieces). If so, flag immediately: don't spend questions refining details of work that needs to be decomposed first. Propose the decomposition, let the user confirm the sub-piece ordering, and brainstorm only the first sub-piece.

**[Pre-brainstorm setup — worktree + research]** *(runs after the scope-check, before any question)*:

1. **gitignore check** — Check if `worktrees/` is in `.gitignore` — add it if missing.
2. **Slug validation** — Run both `<prd-slug>` and `<piece-slug>` through the rules in `plugins/spec-flow/reference/slug-validator.md` (max 20 chars, charset `[a-z0-9-]`, no leading/trailing `-`, total branch length ≤ 50 chars). On any violation, refuse with the exact error contract from that reference doc — name which slug is offending, its actual value, the current length or offending character, and the limit. There is no silent truncation, no auto-fix; the user must edit `docs/prds/<prd-slug>/manifest.yaml` (or rename the PRD) and re-run.
3. **Worktree/branch creation** — Create worktree before writing, so all work lives on the feature branch. Worktree path and branch name follow `plugins/spec-flow/reference/v3-path-conventions.md`. First read `feature_branch:` from `<docs_root>/prds/<prd-slug>/manifest.yaml`:
   - **`feature_branch:` is set (non-null)** — use it as the base so the piece branch tracks the PRD accumulator, not `master`:
     ```bash
     git worktree add {{worktree_root}} -b piece/<prd-slug>-<piece-slug> <feature_branch>
     ```
     Fail with an explicit error if `<feature_branch>` does not exist locally — do NOT silently fall back to `master`. The user must create or fetch the feature branch first.
   - **`feature_branch:` is absent or null** — the PRD develops directly on the default branch; omit the base argument:
     ```bash
     git worktree add {{worktree_root}} -b piece/<prd-slug>-<piece-slug>
     ```
4. **Research dispatch** — Dispatch the `research` agent into the worktree (self-contained prompt: this piece's PRD sections + the manifest piece description + the resolved charter). The schema, markers, return contract, and ≤2K bound are defined in `plugins/spec-flow/reference/research-artifact.md` — cite it; do not restate it.
5. **OK path** — if the agent returns `STATUS: OK` and `research.md` is present and non-empty: commit it on the piece branch BEFORE any spec write:
   ```bash
   git add docs/prds/<prd-slug>/specs/<piece-slug>/research.md
   git commit -m "research: add <prd-slug>/<piece-slug> codebase research"
   ```
   If `git add` stages zero files (path not found) or `git commit` exits non-zero, treat this as trigger (d) of the UNAVAILABLE path below.
   The brainstorm then leads with the digest's inferences (seeding step 3's "lead with your understanding" pattern), and the Charter Constraint Identification Protocol's Conventions Block consumes `research.md`'s `## Codebase Conventions` (per `plugins/spec-flow/reference/brainstorm-procedure.md`).
6. **UNAVAILABLE path** — surface `[RESEARCH-UNAVAILABLE: <reason>]` to the user (include it in your response so the operator sees it) and fall back **non-blocking** when ANY of these four triggers holds: (a) the agent returns `STATUS: BLOCKED`; (b) the dispatch errors; (c) `research.md` is missing or zero-length after dispatch; (d) the `git add`/`git commit` of `research.md` fails (zero files staged or non-zero exit). On this path commit NO `research.md`, and run the standalone L-10 convention scan below (whose output the Conventions Block then consumes). See `plugins/spec-flow/reference/research-artifact.md` for the marker definition.

**[Deliberation protocol]** *(runs after step 6, before the first brainstorm question)*:

Depth levels and per-skill defaults are defined in `reference/deliberation-depth.md` (full / lite / off profiles, operator override contract). The artifact structure, VOQ-N IDs, marker contract, and STATUS line are defined in `reference/deliberation-artifact.md` — cite both; do not restate.

0. **Resolve depth:** read `.spec-flow.yaml` `deliberation.depth`; apply any operator override; else use per-skill default (`full` for spec). On `depth=off` → emit `[DELIBERATION-SKIPPED: depth=off]`, run current brainstorm, STOP here.

1. **Dispatch Phase A** (`agents/deliberation-coordinator.md`): inject PRD sections, piece description, `research.md` digest (if `STATUS: OK`), charter constraints.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-A-blocked]`, fall back to current brainstorm.

2. **Identify decision-unit clusters:** group FRs by functional similarity / dependency. At `lite` depth treat the whole piece as one cluster.

3. **Dispatch Phase B in parallel, one `agents/deliberation-viability.md` agent per cluster**: inject Phase A investigation seed + per-cluster FR assignment + charter constraints. Each agent enumerates reuse/extend-existing paths from `research.md`, not only greenfield.
   **Barrier:** wait for all Phase B agents to complete.
   On any Phase B `STATUS: BLOCKED` → log the blocked cluster; proceed with remaining cluster outputs (non-fatal partial).

4. **Dispatch Phase C** (`agents/deliberation-synthesis.md`): inject all Phase B per-cluster findings.
   **Skip when ≤1 cluster** — single-cluster output is already integrated.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-C-blocked]`, fall back.

5. **Dispatch Phase D in parallel, exactly five lens agents** (`agents/deliberation-lens.md` dispatched 5×): inject Phase C recommendation + one lens label per agent. Full depth lens labels (one agent per label):
   - `architecture-integrity` — structural / layering / dependency-direction review
   - `scope/simplicity` — YAGNI / over-engineering / unnecessary abstraction review
   - `user-intent` — does the recommendation serve the operator's stated goal?
   - `backward-compat` — breaking-change / migration / rollback impact review
   - `risk` — failure modes, hidden assumptions, external-dependency exposure review
   At `lite` depth use the configured subset (default: `scope/simplicity` + `risk`). Depth profile and per-lens label list are defined in `reference/deliberation-depth.md`.
   **Barrier:** wait for all dispatched Phase D agents.
   On any/all Phase D `STATUS: BLOCKED` → log blocked lens(es); proceed to Phase E with available verdicts (non-fatal).

6. **Dispatch Phase E** (`agents/deliberation-convergence.md`): inject Phase C recommendation + all Phase D verdicts. Phase E tags each validated open question with a stable `VOQ-N` ID and records the resolved depth in §Investigation Summary.
   On `STATUS: OK` and `deliberation.md` present + non-empty: commit `deliberation.md`.
   On `STATUS: BLOCKED` or `deliberation.md` missing/empty or commit fail → emit `[DELIBERATION-UNAVAILABLE: phase-E-blocked]`, fall back.

7. **First brainstorm message:** present Investigation Summary + Recommendation + "I have N validated questions for you."

8. **Questions:** draw from §Validated Open Questions in order; each question cites its `VOQ-N` ID (or a named deliberation section for an emergent follow-up, e.g. "Following deliberation §Integration Check: …").

On the `[DELIBERATION-UNAVAILABLE]` or `[DELIBERATION-SKIPPED]` path: run today's brainstorm (step 1b live approach framing, step 3 unrestricted questions).

<!-- Example: a spec piece with FRs {auth-token, token-refresh, session-store} clustered into
2 clusters {auth (auth-token, token-refresh), session (session-store)}. full depth.
Phase A coordinator reads PRD+research+charter, fires 1 web search on an unknown.
Phase B: 2 viability agents (one per cluster) in parallel → barrier.
Phase C synthesis runs (2 clusters ≥2 → not skipped) → integrated recommendation.
Phase D: 5 lens agents in parallel → barrier (4 HOLDS, 1 CONTESTED on backward-compat).
Phase E: folds the CONTESTED into VOQ-1, writes deliberation.md (7 sections), records depth=full.
First brainstorm message: Investigation Summary + Recommendation + "I have 1 validated question (VOQ-1)."
Single-cluster counter-example: a 1-FR piece → 1 viability agent, Phase C SKIPPED (≤1 cluster). -->

**YAGNI throughout.** Remove anything the mapped PRD sections don't ask for. If a brainstorm question surfaces a feature not in the piece's PRD sections, name it out-of-scope before discussing it. Don't add behavior the user didn't request. When the agent proposes an approach, explicitly flag any scope it introduces that the PRD didn't ask for.

**[Convention context]** *(L-10 — runs only on the `[RESEARCH-UNAVAILABLE]` path)*: On the OK path, the conventions list comes from `research.md`'s `## Codebase Conventions` section (written by the pre-brainstorm research pass above), and the standalone L-10 scan is skipped. Only on the `[RESEARCH-UNAVAILABLE]` path, run the L-10 Convention Context Scan specified in `plugins/spec-flow/reference/brainstorm-procedure.md` per the reference doc's "## Core Brainstorm Building Blocks" section ("### L-10: Convention Context Scan"). Outputs: conventions list surfaced in step 1a.

**[PRD assumption audit]** *(C-1 — runs before step 1)*: Read the PRD section mapped to this piece and probe explicitly for dimensions the PRD doesn't mention: security/auth model, data sensitivity, backward compatibility, rate limiting/quotas, operational readiness. For each gap, ask as a multiple-choice: *"The PRD doesn't mention [X]. Is this: (a) intentionally absent — inherited from charter NNs; (b) intentionally N/A for this piece; (c) an open question that needs to be answered in this spec?"* Any `(c)` answers become required open questions for step 3.

Before beginning brainstorm, scan the PRD section text for any existing `[PENDING-DECISION` strings. For each found, surface it as an open question that must be resolved before step 6 sign-off. If the user explicitly re-defers it, re-emit it as `[PENDING-DECISION: <area>]` in the spec with user confirmation (per the lifecycle block above).

**Uncertainty marker lifecycle.** Two marker types signal unresolved uncertainty in a spec:

- `[NEEDS CLARIFICATION: <topic>]` — ambiguity that must be resolved *before* the spec is complete. qa-spec flags surviving markers as must-fix; they must be cleared before sign-off.
- `[PENDING-DECISION: <decision area>]` — a deliberate deferral: the user acknowledges the decision exists but explicitly chooses not to resolve it during brainstorm. These markers are flagged as must-fix by `qa-spec` at spec sign-off (criterion 7). User acknowledgment during brainstorm is informational only — qa-spec will still flag surviving markers and fix-doc must resolve them before sign-off passes. They also block the plan stage — the plan skill's prerequisites check scans spec.md for surviving `[PENDING-DECISION]` markers and refuses to proceed if any are found.

Emit `[PENDING-DECISION: <decision area>]` inline at the exact location in spec.md where the deferred decision would live — not in a separate section, not in a comment, not in front-matter. The marker text becomes a placeholder that fix-doc can locate and replace precisely when the decision is resolved.

1. State the piece scope: "I'm treating this piece as covering [PRD sections]." Proceed; the user corrects inline if the scope doesn't match their intent — no blocking confirmation required.
1a. Run the Charter Constraint Identification Protocol specified in
    `plugins/spec-flow/reference/brainstorm-procedure.md` per the reference doc's
    "## Charter Constraint Identification Protocol" section. The protocol reads charter files
    and infers which NN-C/NN-P/CR entries apply from brainstorm context — present only the
    inferred applicable set with rationale, not the full charter list. Outputs: confirmed NN-C/NN-P/CR list.
    The confirmed list populates `### Non-Negotiables Honored`
    and `### Coding Rules Honored` in spec.md (Phase 3).
1b. **Approach framing** *(H-6)*: When `deliberation.md` exists (depth ≠ `off`), do NOT frame approaches live — read `deliberation.md` §Recommendation and present it as the design anchor for step 3 (the protocol already evaluated the viable paths in §Viability Analysis). When `deliberation.md` is absent (`[DELIBERATION-UNAVAILABLE]` / `[DELIBERATION-SKIPPED]`), fall back to today's behavior: propose 2–3 lightweight approaches and ask the user to choose one. This is not a deep trade-off discussion — just enough framing to know which approach to design for. The chosen approach becomes the design anchor for step 3; full trade-off analysis happens in step 5.
2. **Surface backlog items.** If Phase 1 step 6 loaded items from `<docs_root>/prds/<prd-slug>/backlog.md`, present the top ~5 most-relevant to the user with their concrete references and ask "for each, is this `incorporated` in this piece's spec, `deferred` to a later piece, or `obsolete`?" Record each response in orchestrator state keyed by backlog item — Phase 5 step 4 reads this state to prune `incorporated` and `obsolete` entries from the file. If no items were surfaced (file did not exist, or no relevant matches), skip this step. Any item the user marks as `deferred` is logged internally in orchestrator state for the deferred scope close-out at the end of Phase 2.
3. **Explore purpose, boundaries, and design.** For each sub-area below, state what you've already inferred from the PRD and codebase context, then ask only about what remains genuinely unclear. Lead with your understanding; the user corrects or fills gaps. **Floor check (C-3):** Before advancing past each sub-area, verify the cumulative answer contains (a) one concrete named scenario or example AND (b) one failure mode or edge case. If not, ask one targeted follow-up: *"Can you give me a concrete example of [X failing / Y being invalid]?"* One follow-up max per sub-area; accept explicit N/A without pushback. When `deliberation.md` exists, design questions are **restricted to §Validated Open Questions**; each question presented MUST carry a citation — either a `VOQ-N` ID (for a listed validated open question) or a named deliberation section (for an emergent follow-up, e.g. "Following deliberation §Integration Check: …"). Mandatory blocks (C-1, C-2, H-4, M-7) follow the auto-skip / confirmation-not-discovery logic in `reference/brainstorm-procedure.md` (cite, do not restate).
   - **Architecture & components:** Propose the key components and their relationships from L-10 scan and PRD. State what you understand about boundary independence. Ask only about design decisions the codebase can't resolve — specifically where multiple valid decompositions exist and the user needs to choose.
   - **Data flow:** Map the inferred data flow from PRD and codebase: how data enters, transforms, and exits, and what states it passes through. State the inferred flow; ask only about transitions that are genuinely unclear from PRD and code.
   - **Security** *(C-2 — run via brainstorm-procedure.md C-2 Security Sub-Block)*: Apply the inference-first C-2 protocol from the reference doc.
   - **NFR sub-block** *(H-4 — scaled by piece complexity)*: Infer NFR relevance from work type first. For config, documentation, or skill-file changes, state all four areas N/A without asking. For runtime components — services, APIs, data pipelines — infer reasonable defaults from the PRD and state them (e.g., "no SLO mentioned — treating as best-effort unless you specify one"); ask only when a specific value is needed that can't be derived from context. Four dimensions: (1) Latency budget (2) Throughput ceiling (3) Observability: metrics, log events, trace spans (4) Operational readiness: feature flag, gradual rollout, kill switch.
   - **Error handling:** What can go wrong, and how should failures surface (exception, error return, log, retry)? What's the failure posture for each external dependency? (Failure posture is a design decision — this sub-area generally requires user input.)
   - **Migration & backward compatibility** *(M-7 — conditional)*: Surface only if the piece modifies an existing API endpoint, schema field, message contract, or exported function. If triggered: (1) Is the change breaking or additive-only? (2) What's the backward-compat strategy? (3) Is there data to migrate, and is it reversible? (4) Is rollback safe after migration? If not triggered, state: "Migration sub-block N/A — no existing interfaces changed." User corrects if wrong.
   - **Testing approach:** Propose the testing strategy from TDD doctrine and work type: default ~60% unit / ~30% integration / ~10% e2e, with rationale tied to the specific components. State what "done" coverage looks like for this piece. Ask only if the user has constraints that override the defaults (e.g., no integration test infrastructure, charter-required E2E coverage).
   - **Integration surfacing:** Identify each cross-component integration in scope: name the boundary (which components are inside), the true externals that must be doubled (each needing a contract test), and the AC each integration is allocated to. Record them in the spec's Integration Coverage block (per `templates/spec.md`); if there is no cross-component wiring, write 'None in scope.' Reference `reference/spec-flow-doctrine.md` for the definitions — do not redefine them here.
   - **Isolation & modularity:** Assess component boundaries from the proposed architecture. If any unit has multiple responsibilities or unclear interfaces, surface it as a finding and propose a split. This is a design-quality report — ask the user only when you need their input on a specific split decision.
4. **PRD compliance check:** If the manifest maps requirements the user hasn't mentioned, ask about them. Also apply bidirectional YAGNI: for any approach component or behavior proposed during step 3 that isn't traceable to a PRD section, flag it explicitly: *"This [component/behavior] wasn't called out in the PRD — include it with justification, or constrain scope to match PRD?"*
5. **Confirm approach and trade-offs.** Revisit the approach chosen in step 1b: present full trade-offs now that design exploration is complete, confirm user still wants this approach, and explicitly note any PRD-untraced scope the chosen approach adds (bidirectional YAGNI — M-8).
6. Resolve all open questions. Two outcomes are allowed:
   - **Resolved:** the question has a concrete answer captured in the spec. No marker needed.
   - **Explicitly deferred (PENDING-DECISION):** the user says "I haven't decided yet" or equivalent and explicitly acknowledges the deferral. Emit `[PENDING-DECISION: <decision area>]` inline in spec.md at the exact location of the deferred decision. Confirm with the user: "I've marked this as `[PENDING-DECISION: <decision area>]` — it will be flagged as must-fix by `qa-spec` during spec sign-off and will also block the plan stage if it reaches planning. Understood?"

   No `[NEEDS CLARIFICATION]` markers may survive into the spec.md output. `[PENDING-DECISION]` markers may survive only with the explicit confirmation above.
7. **Active validation preview** *(H-5, L-11)*. Three passes before writing the spec:
   1. **FR→AC coverage check:** Explicitly list: "I see N FRs. Let me verify each has at least one AC." Flag any FR with zero ACs. Flag any AC with no stated test approach.
   2. **Gap call-out:** For each of the four sub-blocks (security, NFRs, migration, testing), either summarize what was captured or state "intentionally N/A — confirmed by user." Name any area skipped without explicit N/A confirmation as a risk.
   3. **Adversarial close:** *"Challenge me — name one scenario that would cause this spec to fail in production. Is anything here interpretable two ways by two different implementers? What's the hardest part of implementing this spec as written?"*

**[Deferred scope close-out]** *(M-9)*: Present the full list of items the user marked `deferred` during step 2 (backlog) and any deferred items from the [PRD assumption audit]. For each, ask: *"Which future piece should own this?"* — multiple-choice based on manifest pieces, or "new piece TBD." These items appear in spec.md under a new section `## Explicitly Out of Scope / Deferred` with rationale. Also note them additively in `docs/prds/<prd-slug>/backlog.md` using the same format as existing backlog entries (Phase 5 step 4 handles final pruning of the same file).

### Phase 3: Write Spec

The worktree/branch already exist (created pre-brainstorm in Phase 2); this phase only writes `spec.md`.

1. Write `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` in the worktree directory. Read the dependency-triage choice recorded by Phase 1 step 6a from orchestrator state and branch as follows (per FR-6 of pi-010-discovery and the `## Dependency Triage` section format in `plugins/spec-flow/reference/depends-on-precondition.md`):
   - **No unmet deps recorded** (every dep was already `merged`/`done` at the time of step 6a, or the piece had no `depends_on:` entries): write spec.md normally with no `## Dependency Triage` section. The section is required only when at least one dep was unmet at the moment of authoring.
   - **Operator chose `(1) pull-deps-in`:** write spec.md and append a `## Dependency Triage` section using the format from the reference doc — one bullet per unmet dep, each rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator chose pull-deps-in; spec covers prerequisite behavior in §<section>.`` (or the Phase 0 variant per the reference doc's "Resolution values" list, depending on whether the absorption is documented in the spec body or deferred to plan-time Phase 0). The Goal / Scope / FR / AC sections of spec.md must be authored to also cover the dep's behavior — the unmet-dep entry should only be removed from `depends_on:` once the prerequisite is actually covered in this spec.
   - **Operator chose `(2) fork`:** halt the skill immediately with the exact refusal string `Refused — fork chosen; spec the prerequisite piece <ref> first.` (substituting each unmet dep's `<ref>` if more than one is unmet, one refusal line per dep). Write NO spec.md and do not advance to Phase 4. Note: the pre-brainstorm setup in Phase 2 may have already created a worktree and branch, and if the research agent returned OK a `research:` commit will exist on the piece branch — this is an accepted recoverable orphan. The operator may clean up the orphaned branch/worktree if desired, but no spec.md is written and execution stops here. The operator's next action is to switch to the prerequisite piece and run `/spec-flow:spec` on it.
   - **Operator chose `(3) proceed --ignore-deps`:** write spec.md and append a `## Dependency Triage` section with one bullet per unmet dep rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator override; deps remain unmet at spec time.`` Recall that `(3) proceed` is refused for structural-failure statuses (`superseded`, `blocked`) at step 6a — if execution reaches this branch, every unmet dep is in a transient-status class.
2. Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/spec.md` as the structural guide. Populate the `charter_snapshot:` front-matter with the charter dates captured in Phase 1 step 3: `git log` last-commit date per domain (charter skills carry no `last_updated:` front-matter). If a charter domain is absent, omit its key from the snapshot block (do not write a blank/null value).

### Phase 4: QA Loop

Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).

1. Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-spec.md`

2. **Iteration 1 (full review):** Compose prompt with `Input Mode: Full`: interpolate the full spec, PRD sections, charter files (all seven if present — architecture, non-negotiables (NN-C), tools, processes, flows, coding-rules (CR), integrations; at the active charter root resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-*/SKILL.md`, where `<charter_root>` is `.github` or `.claude`), manifest piece, and NN-P from the PRD's Non-Negotiables (Product) section. Dispatch:
   ```
   Agent({
     description: "Spec QA for <prd-slug>/<piece-slug> (iter 1, full)",
     prompt: <composed>,
     model: "opus"
   })
   ```

3. **QA loop (iterations 2+, focused):** If iteration M-1 returned must-fix findings:
   - Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md`
   - Dispatch fix agent with prior findings + spec + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of spec.md.
   - Extract that diff string and hold it in orchestrator state as `spec_iter_M_fix_diff`.
   - Re-dispatch QA agent (fresh) with `Input Mode: Focused re-review`, the prior iteration's must-fix findings, and `spec_iter_M_fix_diff`. Do NOT re-send the full spec.
   - **Circuit breaker:** After 3 QA iterations, escalate to human.
   - If the fix agent returns `Diff of changes: (none)` (all blocked), escalate.

4. When QA returns clean: present spec to user for sign-off.

**Limitation:** The QA agent cannot assess brainstorming trade-offs not captured in the spec. The human sign-off covers this gap.

### Phase 5: Finalize

1. User approves → continue. User requests changes → make them → back to QA loop.
2. Update `docs/prds/<prd-slug>/manifest.yaml` on the piece branch (the current
   working branch — no checkout needed):
   ```bash
   # update docs/prds/<prd-slug>/manifest.yaml status for this piece
   git add docs/prds/<prd-slug>/manifest.yaml
   git commit -m "manifest: mark <prd-slug>/<piece-slug> as specced"
   ```
   > **Branch ownership:** The manifest update stays on the piece branch
   > (`piece/<prd-slug>-<piece-slug>`). The merge target for piece branches is
   > the manifest's `feature_branch:` value if set, or `merge_target:` (default:
   > `master`) if `feature_branch:` is null. For PR-based repos (`pr_required: true`),
   > the human merges the piece branch to the accumulator as part of the normal review
   > workflow. The `feature_branch:` itself merges to `merge_target:` only when the
   > full PRD ships — **never commit PRD piece work directly to `merge_target:` while
   > `feature_branch:` is set.**
3. Commit spec on worktree branch:
   ```bash
   git add docs/prds/<prd-slug>/specs/<piece-slug>/spec.md
   git commit -m "spec: add <prd-slug>/<piece-slug> specification"
   ```
4. **Prune addressed backlog items.** If Phase 1 step 6 surfaced backlog items from `<docs_root>/prds/<prd-slug>/backlog.md` and the user marked any as `incorporated` or `obsolete` during brainstorm, remove those entries from that PRD-local backlog file. `deferred` items stay in the file. Commit the prune as a separate commit on the worktree branch:
   ```bash
   git add <docs_root>/prds/<prd-slug>/backlog.md
   git commit -m "chore: prune backlog items addressed by <prd-slug>/<piece-slug>"
   ```
   If no items were marked or no PRD-local backlog existed, skip this step.
5. **Integration — no additional Jira items at spec sign-off.** The Epic was created at Phase 2 start and represents the entire piece. Phase Tasks are created by the plan skill at sign-off. No action needed here.

## NEEDS CLARIFICATION Lifecycle

These markers flag unresolved questions during brainstorming. The skill MUST resolve all markers with the user before writing the final spec. The QA agent treats any surviving marker as a must-fix finding.
