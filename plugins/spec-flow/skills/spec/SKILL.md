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
   "## Charter Context Loading Protocol" section. Outputs: `charter_variant`,
   `charter_snapshot`, `integration_cfg`.
4. Scan `<docs_root>/prds/<prd-slug>/specs/*/learnings.md` — load learnings from previously completed pieces in this PRD
5. Scan for binding rules across namespaces using paths from `charter_variant`:
   - **NN-C**: v4 → `.github/skills/charter-non-negotiables/SKILL.md`; v3 → `<docs_root>/charter/non-negotiables.md`; legacy/none → no project-level NNs yet
   - **NN-P**: `<docs_root>/prds/<prd-slug>/prd.md` (Non-Negotiables (Product) section) — same for all variants
   - **CR**: v4 → `.github/skills/charter-coding-rules/SKILL.md`; v3 → `<docs_root>/charter/coding-rules.md`
   - **Legacy NN-xxx**: any unprefixed `NN-xxx` in `CLAUDE.md` or the PRD — treat as legacy; mention in Phase 2 that retrofitting would reclassify them.
6. Read `<docs_root>/prds/<prd-slug>/backlog.md` if it exists. This is the PRD-local backlog — it accumulates end-of-piece reflection findings from prior pieces in this PRD (future opportunities deferred to later pieces of the same PRD). For each item recorded, semantic-match against this piece's name (from manifest) and the user's brainstorm prompt; surface the ~5 most-relevant items as candidate considerations during Phase 2 brainstorm. Track user responses in orchestrator state for Phase 5 prune (statuses: `incorporated` — addressed by this piece's spec; `deferred` — still relevant but not in this piece's scope; `obsolete` — no longer applies). If the file does not exist (first piece on a new PRD), skip silently. If `reflection: off` is set but the file exists from a previous run, still read it — stale findings from past reflections may still be useful brainstorm context. (Process-retro items live in the global `<docs_root>/improvement-backlog.md`; that file is touched only by the reflection-process-retro agent and is out of scope for this skill.)
6a. **Dependency precondition check (FR-4 of pi-010-discovery, AC-5).** Run the resolution + status + triage logic specified in `plugins/spec-flow/reference/depends-on-precondition.md` against the target piece's `depends_on:` list, read from the manifest entry loaded in step 1 (`docs/prds/<prd-slug>/manifest.yaml`). For each ref, resolve per the reference doc's "Reference resolution" section (qualified `<dep-prd-slug>/<dep-piece-slug>` against `docs/prds/<dep-prd-slug>/manifest.yaml`; bare `<dep-piece-slug>` against the current PRD's manifest). On resolution failure, refuse with the exact resolution-failure refusal string from the reference doc — do NOT prompt for triage on a malformed/missing ref. On successful resolution, classify each dep's `status:` per the reference doc's "Status interpretation" section. If every resolved dep is `merged` or `done`, this step is a silent no-op (no prompt, no recorded state) and Phase 1 continues to step 7 (NN-C-005). If any resolved dep has a transient or structural-failure status, render the three-option triage prompt verbatim from the reference doc's "Triage options at spec/plan time" section (literal `(1) pull-deps-in`, `(2) fork`, `(3) proceed` markers; one bullet per unmet dep). Record the operator's choice and the per-dep status snapshot in orchestrator state keyed for Phase 3's spec.md authoring step to read. **Structural-failure statuses (`superseded`, `blocked`) refuse the `(3) proceed` option** — apply that rule symmetrically to the spec-time prompt per the reference doc.
7. **Charter-drift check.** If the target piece's `spec.md` already exists and carries a `charter_snapshot:` front-matter (i.e., this is an update/amend re-run, not a greenfield first-run), execute the charter-drift procedure specified in `plugins/spec-flow/reference/charter-drift-check.md`: compare the spec's `charter_snapshot:` values against the current charter dates captured in step 3 (v4: `git log` last-commit date per domain; v3: `last_updated:` front-matter per file), and on any drift dispatch `qa-spec` with `Input Mode: Focused charter re-review` per that reference. On `clean`: auto-advance the snapshot and continue. On `must-fix`: halt the skill and surface findings — no escape hatch. Skip this step on greenfield runs (no spec yet, nothing to drift).
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
- Apply Task Creation Requirements from `charter-integrations` (`.github/skills/charter-integrations/SKILL.md`):
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

**YAGNI throughout.** Remove anything the mapped PRD sections don't ask for. If a brainstorm question surfaces a feature not in the piece's PRD sections, name it out-of-scope before discussing it. Don't add behavior the user didn't request. When the agent proposes an approach, explicitly flag any scope it introduces that the PRD didn't ask for.

**[Convention context]** *(L-10 — runs before any questions)*: Run the L-10 Convention Context Scan
specified in `plugins/spec-flow/reference/brainstorm-procedure.md` per the reference doc's
"## Core Brainstorm Building Blocks" section ("### L-10: Convention Context Scan"). Outputs:
conventions list surfaced in step 1a.

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
1b. **Approach framing** *(H-6)*: Propose 2-3 lightweight approaches and ask the user to choose one. This is not a deep trade-off discussion — just enough framing to know which approach to design for. The chosen approach becomes the design anchor for step 3; full trade-off analysis happens in step 5.
2. **Surface backlog items.** If Phase 1 step 6 loaded items from `<docs_root>/prds/<prd-slug>/backlog.md`, present the top ~5 most-relevant to the user with their concrete references and ask "for each, is this `incorporated` in this piece's spec, `deferred` to a later piece, or `obsolete`?" Record each response in orchestrator state keyed by backlog item — Phase 5 step 4 reads this state to prune `incorporated` and `obsolete` entries from the file. If no items were surfaced (file did not exist, or no relevant matches), skip this step. Any item the user marks as `deferred` is logged internally in orchestrator state for the deferred scope close-out at the end of Phase 2.
3. **Explore purpose, boundaries, and design.** For each sub-area below, state what you've already inferred from the PRD and codebase context, then ask only about what remains genuinely unclear. Lead with your understanding; the user corrects or fills gaps. **Floor check (C-3):** Before advancing past each sub-area, verify the cumulative answer contains (a) one concrete named scenario or example AND (b) one failure mode or edge case. If not, ask one targeted follow-up: *"Can you give me a concrete example of [X failing / Y being invalid]?"* One follow-up max per sub-area; accept explicit N/A without pushback.
   - **Architecture & components:** Propose the key components and their relationships from L-10 scan and PRD. State what you understand about boundary independence. Ask only about design decisions the codebase can't resolve — specifically where multiple valid decompositions exist and the user needs to choose.
   - **Data flow:** Map the inferred data flow from PRD and codebase: how data enters, transforms, and exits, and what states it passes through. State the inferred flow; ask only about transitions that are genuinely unclear from PRD and code.
   - **Security** *(C-2 — run via brainstorm-procedure.md C-2 Security Sub-Block)*: Apply the inference-first C-2 protocol from the reference doc.
   - **NFR sub-block** *(H-4 — scaled by piece complexity)*: Infer NFR relevance from work type first. For config, documentation, or skill-file changes, state all four areas N/A without asking. For runtime components — services, APIs, data pipelines — infer reasonable defaults from the PRD and state them (e.g., "no SLO mentioned — treating as best-effort unless you specify one"); ask only when a specific value is needed that can't be derived from context. Four dimensions: (1) Latency budget (2) Throughput ceiling (3) Observability: metrics, log events, trace spans (4) Operational readiness: feature flag, gradual rollout, kill switch.
   - **Error handling:** What can go wrong, and how should failures surface (exception, error return, log, retry)? What's the failure posture for each external dependency? (Failure posture is a design decision — this sub-area generally requires user input.)
   - **Migration & backward compatibility** *(M-7 — conditional)*: Surface only if the piece modifies an existing API endpoint, schema field, message contract, or exported function. If triggered: (1) Is the change breaking or additive-only? (2) What's the backward-compat strategy? (3) Is there data to migrate, and is it reversible? (4) Is rollback safe after migration? If not triggered, state: "Migration sub-block N/A — no existing interfaces changed." User corrects if wrong.
   - **Testing approach:** Propose the testing strategy from TDD doctrine and work type: default ~60% unit / ~30% integration / ~10% e2e, with rationale tied to the specific components. State what "done" coverage looks like for this piece. Ask only if the user has constraints that override the defaults (e.g., no integration test infrastructure, charter-required E2E coverage).
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

### Phase 3: Create Worktree and Write Spec

1. Check if `worktrees/` is in `.gitignore` — add it if missing
2. **Validate slugs before any branch or worktree creation.** Run both `<prd-slug>` and `<piece-slug>` through the rules in `plugins/spec-flow/reference/slug-validator.md` (max 20 chars, charset `[a-z0-9-]`, no leading/trailing `-`, total branch length ≤ 50 chars). On any violation, refuse with the exact error contract from that reference doc — name which slug is offending, its actual value, the current length or offending character, and the limit. There is no silent truncation, no auto-fix; the user must edit `docs/prds/<prd-slug>/manifest.yaml` (or rename the PRD) and re-run.
3. Create worktree (before writing, so all work lives on the feature branch). Worktree path and branch name follow `plugins/spec-flow/reference/v3-path-conventions.md`. First read `feature_branch:` from `<docs_root>/prds/<prd-slug>/manifest.yaml`:
   - **`feature_branch:` is set (non-null)** — use it as the base so the piece branch tracks the PRD accumulator, not `master`:
     ```bash
     git worktree add {{worktree_root}} -b piece/<prd-slug>-<piece-slug> <feature_branch>
     ```
     Fail with an explicit error if `<feature_branch>` does not exist locally — do NOT silently fall back to `master`. The user must create or fetch the feature branch first.
   - **`feature_branch:` is absent or null** — the PRD develops directly on the default branch; omit the base argument:
     ```bash
     git worktree add {{worktree_root}} -b piece/<prd-slug>-<piece-slug>
     ```
4. Write `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` in the worktree directory. Read the dependency-triage choice recorded by Phase 1 step 6a from orchestrator state and branch as follows (per FR-6 of pi-010-discovery and the `## Dependency Triage` section format in `plugins/spec-flow/reference/depends-on-precondition.md`):
   - **No unmet deps recorded** (every dep was already `merged`/`done` at the time of step 6a, or the piece had no `depends_on:` entries): write spec.md normally with no `## Dependency Triage` section. The section is required only when at least one dep was unmet at the moment of authoring.
   - **Operator chose `(1) pull-deps-in`:** write spec.md and append a `## Dependency Triage` section using the format from the reference doc — one bullet per unmet dep, each rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator chose pull-deps-in; spec covers prerequisite behavior in §<section>.`` (or the Phase 0 variant per the reference doc's "Resolution values" list, depending on whether the absorption is documented in the spec body or deferred to plan-time Phase 0). The Goal / Scope / FR / AC sections of spec.md must be authored to also cover the dep's behavior — the unmet-dep entry should only be removed from `depends_on:` once the prerequisite is actually covered in this spec.
   - **Operator chose `(2) fork`:** halt the skill immediately with the exact refusal string `Refused — fork chosen; spec the prerequisite piece <ref> first.` (substituting each unmet dep's `<ref>` if more than one is unmet, one refusal line per dep). Write NO spec.md, create NO commits, do not advance to Phase 4. The operator's next action is to switch to the prerequisite piece and run `/spec-flow:spec` on it.
   - **Operator chose `(3) proceed --ignore-deps`:** write spec.md and append a `## Dependency Triage` section with one bullet per unmet dep rendered as ``- `<ref>` (status: `<status>` at <YYYY-MM-DD>) — Operator override; deps remain unmet at spec time.`` Recall that `(3) proceed` is refused for structural-failure statuses (`superseded`, `blocked`) at step 6a — if execution reaches this branch, every unmet dep is in a transient-status class.
5. Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/spec.md` as the structural guide. Populate the `charter_snapshot:` front-matter with the charter dates captured in Phase 1 step 3: v4 → `git log` last-commit date per domain; v3 → `last_updated:` value per file. If a charter file or domain is absent, omit its key from the snapshot block (do not write a blank/null value).

### Phase 4: QA Loop

Iteration policy: see plugins/spec-flow/reference/qa-iteration-loop.md (iter-until-clean; 3-iter circuit breaker).

1. Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-spec.md`

2. **Iteration 1 (full review):** Compose prompt with `Input Mode: Full`: interpolate the full spec, PRD sections, charter files (all seven if present — architecture, non-negotiables (NN-C), tools, processes, flows, coding-rules (CR), integrations; paths per `charter_variant` from Phase 1 step 3: v4 → `.github/skills/charter-*/SKILL.md`, v3 → `<docs_root>/charter/`, legacy → `<docs_root>/architecture/`), manifest piece, and NN-P from the PRD's Non-Negotiables (Product) section. Dispatch:
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
