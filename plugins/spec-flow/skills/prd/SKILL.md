---
name: prd
description: >-
  Use when the user has formal requirements to structure, import, or decompose — not for
  brainstorming. Handles creating a PRD from scratch via structured interview when the user
  already knows what they want to build at a high level, importing an existing requirements doc
  (BMad, speckit, Notion export, plain prd.md), decomposing a PRD into implementable pieces for
  the spec-flow pipeline, and reviewing PRD fulfillment after all pieces ship. Also updates the
  manifest when the PRD changes or the user wants to reprioritize. Trigger on "create a PRD",
  "import my PRD", "set up spec-flow", "onboard this project", "break this into pieces",
  "write up requirements", "define the scope", "roadmap", "user stories",
  "validate we built everything", or "I have a requirements doc". For open-ended brainstorming
  about how something should work, use the spec skill instead.
---

## Pre-flight: Model Check

Before any other step, verify the active model is an Opus-class model.

Determine the active model using the platform-appropriate method:

- **Copilot CLI** — read the `<model_information>` system tag injected into this session's context. The model name and ID are present there explicitly.
- **Claude Code** — no equivalent tag is injected. Use Claude's self-knowledge: introspect your own model identity (Claude reliably knows which model variant it is from training) and treat that as the model name for the check below.

If the active model name does **not** contain `opus` (case-insensitive):

1. Use `ask_user` to block and prompt the user:

   > ⚠️ **Model mismatch.** PRD authoring is thinking work per NN-P-005, but the active model appears to be **[model-name]**.

   Choices:
   - "Override — proceed on [model-name]"
   - "Change now — I'll switch models"
   - "Cancel prd"

2. If the user selects **"Cancel prd"** → stop immediately and emit:
   `PRD cancelled. Re-run after switching to an Opus model.`

3. If the user selects **"Override — proceed on [model-name]"** → proceed to Step 0 immediately on the current model. Emit a one-line acknowledgment first:
   `Overriding model check — proceeding on [model-name]. PRD quality may be reduced.`

4. If the user selects **"Change now — I'll switch models"** → **close the prompt and return control to the user.** The model cannot be switched while an `ask_user` prompt is blocking, and there is no programmatic model-change event to listen for — so leave the dialog and wait for the user to signal. Emit:
   `Switch to an Opus model now. When ready, type "proceed" to resume, or "cancel" to stop.`
   Then wait for the user's free-text reply:
   - On `proceed` (or any "I've switched / continue" phrasing) → re-run this model check (re-introspect your model identity on Claude Code, or re-read the `<model_information>` tag on Copilot CLI). If the model now contains `opus`, proceed to Step 0. If it still does not, re-present the three choices above.
   - On `cancel` → stop and emit the cancellation line from step 2.

If the model already contains `opus` → proceed to Step 0 immediately with no prompt.

# PRD — Import, Create, Normalize, Decompose

Import an existing PRD or build one from scratch via structured interview, normalize it into the pipeline format, decompose it into implementable pieces, and create the tracking manifest.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`. During import, if the user specifies a non-default docs location or you detect docs live elsewhere (e.g., `repo/docs/`), update `.spec-flow.yaml` accordingly.

## Step 0.5: Charter Prerequisite Check

Read the `charter:` block from `.spec-flow.yaml`. Key: `required` (default `false`).

**Resolve charter location.** Charter is published as skill files under the active charter root, resolved per `plugins/spec-flow/reference/charter-location.md` — `<charter_root>/skills/charter-<domain>/SKILL.md`, `<charter_root>` ∈ {`.github`, `.claude`}. Resolution either yields a root (charter present) or finds none (a pre-charter project).

- If `charter.required: true` and no charter root resolves → respond with: *"Charter is required for this project but no charter skills were found at `<charter_root>/skills/charter-*/SKILL.md` (`<charter_root>` ∈ {`.github`, `.claude`}). Run `/spec-flow:charter` first to bootstrap the charter, then re-run `prd`."* Halt.
- If a charter root resolves → continue; cite `NN-C-xxx` entries from `<charter_root>/skills/charter-non-negotiables/SKILL.md` when classifying PRD constraints.
- If no charter root resolves and `charter.required: false` → continue. The PRD holds product-specific non-negotiables as `NN-P-xxx`; no project-level NN-C is available until `/spec-flow:charter` bootstraps one.

## Argument parsing (v3)

The skill is invoked as `/spec-flow:prd [<prd-slug>] [--review]` (FR-006, FR-023):

- **`--review` flag** → Review mode immediately (no prompt). The slug argument selects which PRD to review; if omitted and exactly one PRD has `status: shipped` it defaults to that one, otherwise errors.
- **`<docs_root>/prds/<slug>/prd.md` already exists AND no `--review`** → Update mode immediately (silent auto-detect, no prompt).
- **User provides a file path argument** → Import mode immediately (no prompt; skip to Import Step 1).
- **Everything else** → present the interactive mode prompt:

  ```
  How would you like to start?
  (a) Import — I have an existing PRD document (BMad output, Notion export, plain markdown, etc.)
  (b) Create — I have an idea but no document yet; help me build the PRD from scratch
  (c) Update — I have an existing PRD in this pipeline I want to amend
  ```

  Route to the appropriate mode based on user response. If the user responds (c), apply the no-arg Update mode rules (default to the only active PRD; error if multiple active PRDs without a slug).

- **Slug argument** (`<prd-slug>`): names the PRD this invocation targets. Required when creating a new PRD greenfield and when more than one PRD has `status: active` in update mode.
- **No-arg in update mode:** defaults to "the only PRD with `status: active`". Errors with the list of active PRDs if more than one is active and no slug was supplied (FR-006).

**Slug rules:** every slug supplied to or generated by this skill is validated against `${CLAUDE_PLUGIN_ROOT}/reference/slug-validator.md`. Do not restate the rules — read the reference and refuse with the documented refusal contract on any violation.

**Slug prompt (FR-023):** if entering Import or Create mode and no `<prd-slug>` argument was supplied, prompt the user interactively for the slug — no implicit default, no derivation from filenames or PRD title. After the user supplies a slug, run it through the slug-validator before continuing.

## Modes

Path resolution everywhere below follows `${CLAUDE_PLUGIN_ROOT}/reference/v3-path-conventions.md` — the v3 layout is `<docs_root>/prds/<prd-slug>/{prd.md, manifest.yaml, backlog.md, specs/<piece-slug>/...}`. With the default `docs_root: docs`, that resolves to literal `docs/prds/<prd-slug>/...`. Each piece's worktree lives at `{{worktree_root}}` (resolves to `worktrees/prd-<prd-slug>/piece-<piece-slug>` at orchestrator dispatch time — see `${CLAUDE_PLUGIN_ROOT}/reference/v3-path-conventions.md`, section `## Worktree-root template token`).

- **Import mode:** `<docs_root>/prds/<slug>/prd.md` does not exist; user has an existing document to import.
- **Create mode:** `<docs_root>/prds/<slug>/prd.md` does not exist; user has an idea but no document yet.
- **Update mode:** `<docs_root>/prds/<slug>/prd.md` exists. User wants to add pieces, reprioritize, or amend the PRD.
- **Review mode:** User invoked with `--review`. Validate full PRD fulfillment for the resolved PRD.

### Slug uniqueness check (FR-023)

Before any greenfield write, scan all existing PRDs to confirm the supplied slug is not already taken:

1. Enumerate `<docs_root>/prds/*/prd.md` (literal: `docs/prds/*/prd.md` with the default `docs_root`).
2. Read each file's YAML front-matter and collect the `slug:` value.
3. If any existing front-matter `slug:` equals the slug for this invocation, refuse with an error that names the colliding PRD path (e.g. `Refusing: slug "auth" already used by docs/prds/authentication/prd.md`) and exit without creating any files. This is the AC-20 contract.

The check runs after slug-validator passes and before the charter-drift check.

## Import Mode Workflow

> **Order (v3):** argument parsing → slug-validator → slug uniqueness check → path resolution → charter-drift check (skipped on greenfield — no spec yet to drift against; see `${CLAUDE_PLUGIN_ROOT}/reference/charter-drift-check.md`) → write artifacts.

**Step 1: Detect existing artifacts**

- Check for BMad artifacts: `_bmad-output/planning-artifacts/PRD.md`
- Check for speckit specs: `specs/*/spec.md`
- Check for raw docs: `docs/`, `README.md`, any `*.md` with "requirements" content
- Report what was found and ask user to confirm the source PRD

**Step 2a: Structure extraction (no stripping yet)**

Read the confirmed source PRD and reorganize its content into the template structure at `${CLAUDE_PLUGIN_ROOT}/templates/prd.md` WITHOUT discarding anything at this stage. Map content into template sections:

- Extract functional requirements → number as FR-001, FR-002, ...
- Extract non-functional requirements → number as NFR-001, NFR-002, ...
- Extract goals and non-goals
- Extract success metrics → number as SC-001, SC-002, ...
- Extract any persona descriptions → `## Personas`
- Extract any user story content → `## User Stories`
- Extract any edge cases or failure modes → `## Edge Cases & Failure Modes`
- Extract any prioritization → `## Priority Tiers`
- Extract problem statement / background / context → `## Problem Statement`
- Extract assumptions → `## Assumptions`
- Extract open questions → `## Open Questions`
- Extract constraints / non-negotiables. Classify each constraint:
  - Project-wide (security, compliance, architecture, tooling) → propose adding to charter as `NN-C-xxx`. Ask the user to confirm; if accepted, append the new entry to the charter non-negotiables skill at the resolved charter root: `<charter_root>/skills/charter-non-negotiables/SKILL.md` (`<charter_root>` ∈ {`.github`, `.claude`}, resolved per `plugins/spec-flow/reference/charter-location.md`).
  - Product-specific (tied to this PRD) → number as `NN-P-001, NN-P-002, ...` in the `## Non-Negotiables (Product)` section of `prd.md`.

**Persona content rule:** Preserve substantive persona content (differing user roles, usage contexts, behavioral constraints) into `## Personas`. Strip only: vacuous one-liner bios with no product-specific constraint, process checklists, meeting notes, template instructions. When in doubt: preserve and flag for user review with a `[NEEDS REVIEW: possible persona theater]` inline marker.

Populate the v3 PRD front-matter with `slug: <prd-slug>`, `status: drafting`, `version: 1` per FR-002.

> **Integration capability check:** After writing the initial structured draft, run `${CLAUDE_PLUGIN_ROOT}/reference/integration-capability-check.md` to identify any third-party integrations implied by the FRs. Surface integration assumptions to the user; if the integration is not captured as an explicit FR or NFR, ask whether to add it.

**Step 2b: Enrichment pass**

After structure extraction, scan the normalized draft for missing or empty required sections. For each missing or thinly populated required section, ask targeted questions to fill the gap. Required sections: Problem Statement, Personas (≥1), User Stories (≥1 per FR), Edge Cases, Priority Tiers.

Ask one targeted question at a time. Examples:

- *No user stories found:* "I see FR-001: [requirement]. Who specifically needs this and what outcome does it give them? Let's write a user story."
- *No personas found:* "Who are the primary users of this product? Let's define at least one persona."
- *No edge cases found:* "For [feature area], what can go wrong? Name one failure scenario."
- *No priority tiers:* "Which of these FRs are must-haves for launch versus nice-to-haves? Let's sketch a priority tier."

Do NOT ask about sections already well-populated from the source document. Skip silently if all required sections are adequately populated.

**Step 3: FR quality floor check**

Before brainstorm, validate each FR meets all three criteria:

1. **Falsifiable** — Can be expressed as a pass/fail testable condition (e.g., "system must X within Y ms" passes; "system should be fast" fails).
2. **User-anchored** — Has ≥1 user story in `## User Stories` linking it to a named persona need.
3. **Metric-linked** — Either references a SC-xxx success criterion OR is explicitly marked as a constraint (not a measurable feature).

FRs that fail any criterion are flagged inline as `[NEEDS EXPANSION: <reason>]`. These markers block the brainstorm step — the user must resolve or explicitly waive each flagged FR before proceeding. Lifecycle is identical to `[NEEDS CLARIFICATION]` in the spec skill: present all flagged FRs in a single list, ask the user to address or waive each one, then clear the markers before writing.

**[Deliberation protocol]** *(runs after Step 3 FR quality floor check, before Step 4 Brainstorm)*:

Depth levels and per-skill defaults are defined in `reference/deliberation-depth.md` (full / lite / off profiles, operator override contract). The artifact structure, VOQ-N IDs, marker contract, and STATUS line are defined in `reference/deliberation-artifact.md` — cite both; do not restate.

The decision unit for this skill is the **candidate piece / decomposition boundary** (not an FR). Each cluster in Phase A represents a candidate piece or natural boundary grouping; Phase B viability agents assess each candidate piece independently.

0. **Resolve depth:** read `.spec-flow.yaml` `deliberation.depth`; apply any operator override; else use per-skill default (`full` for prd). On `depth=off` → emit `[DELIBERATION-SKIPPED: depth=off]`, run Step 4 Brainstorm from the top, STOP here.

1. **Dispatch Phase A** (`agents/deliberation-coordinator.md`): inject PRD sections, the normalized PRD draft (with FR/NFR/User Stories populated from Steps 1–3), charter constraints.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-A-blocked]`, fall back to Step 4 Brainstorm.

2. **Consume decision-unit clusters from Phase A:** take the identified candidate-piece clusters returned in Phase A's investigation seed (the coordinator already derived them from the PRD). At `lite` depth, collapse them to one whole-PRD cluster regardless of what Phase A returned.

3. **Dispatch Phase B in parallel, one `agents/deliberation-viability.md` agent per cluster**: inject Phase A investigation seed + per-cluster candidate-piece assignment + charter constraints. Each agent enumerates reuse/extend-existing paths from any available research context, not only greenfield.
   **Barrier:** wait for all Phase B agents to complete.
   On any Phase B `STATUS: BLOCKED` → log the blocked cluster; proceed with remaining cluster outputs (non-fatal partial).

4. **Dispatch Phase C** (`agents/deliberation-synthesis.md`): inject all Phase B per-cluster findings.
   **Skip when ≤1 cluster** — single-cluster output is already integrated. On skip, record single-cluster coherence in the `## Integration Check` section of `deliberation.md`; the Phase B single-cluster viability output becomes the anchor for Phase D and Phase E in place of a Phase C recommendation.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-C-blocked]`, fall back to Step 4 Brainstorm.

5. **Dispatch Phase D in parallel, exactly five lens agents** (`agents/deliberation-lens.md` dispatched 5×): inject Phase C recommendation + one lens label per agent (when Phase C was skipped at ≤1 cluster, inject the Phase B single-cluster viability output as the recommendation anchor — the single-cluster coherence summary — in place of the Phase C recommendation). Full depth lens labels (one agent per label):
   - `architecture-integrity` — structural / layering / dependency-direction review
   - `scope/simplicity` — YAGNI / over-engineering / unnecessary abstraction review
   - `user-intent` — does the recommendation serve the operator's stated goal?
   - `backward-compat` — breaking-change / migration / rollback impact review
   - `risk` — failure modes, hidden assumptions, external-dependency exposure review
   At `lite` depth use the configured subset (default: `scope/simplicity` + `risk`). Depth profile and per-lens label list are defined in `reference/deliberation-depth.md`.
   **Barrier:** wait for all dispatched Phase D agents.
   On any/all Phase D `STATUS: BLOCKED` → log blocked lens(es); proceed to Phase E with available verdicts (non-fatal).

6. **Dispatch Phase E** (`agents/deliberation-convergence.md`): inject Phase C recommendation + all Phase D verdicts (when Phase C was skipped at ≤1 cluster, inject the Phase B single-cluster viability output as the recommendation anchor — the single-cluster coherence summary — in place of the Phase C recommendation). Phase E tags each validated open question with a stable `VOQ-N` ID and records the resolved depth in the `## Investigation Summary` section.
   On `STATUS: OK` and `deliberation.md` present + non-empty: commit `deliberation.md`.
   On `STATUS: BLOCKED` → emit `[DELIBERATION-UNAVAILABLE: phase-E-blocked]`, fall back to Step 4 Brainstorm.
   On `deliberation.md` missing or zero-length after dispatch → emit `[DELIBERATION-UNAVAILABLE: deliberation.md-empty-after-dispatch]`, fall back to Step 4 Brainstorm.
   On `git commit` of `deliberation.md` failing (zero files staged or non-zero exit) → remove the uncommitted `deliberation.md` before falling back (e.g. `rm -f <path>` if it was not previously committed, or `git checkout -- <path>` if it was) so downstream consumers cannot pick up the disowned artifact → emit `[DELIBERATION-UNAVAILABLE: deliberation.md-commit-failed]`, fall back to Step 4 Brainstorm.

7. **First Step 4 message:** present Investigation Summary + Recommendation + "I have N validated questions for you." Draw questions from the `## Validated Open Questions` section in order.

8. **Questions:** each question cites its `VOQ-N` ID (or a named deliberation section for an emergent follow-up, e.g. "Following deliberation's `## Integration Check`: …").

On the `[DELIBERATION-UNAVAILABLE]` or `[DELIBERATION-SKIPPED]` path: run Step 4 Brainstorm as written (today's behavior — interactive sub-steps 4a–4l in order, no deliberation pre-seed).

<!-- Example: a PRD with FRs decomposing into 3 candidate pieces {ingestion-pipeline, api-layer, ui-dashboard} clustered into 2 clusters {data (ingestion-pipeline), surface (api-layer, ui-dashboard)}. Decision unit = candidate piece. full depth.
Phase A coordinator reads PRD+charter, produces candidate-piece clusters.
Phase B: 2 viability agents (one per cluster) in parallel → barrier.
Phase C synthesis runs (2 clusters ≥2 → not skipped) → integrated recommendation on piece boundaries.
Phase D: 5 lens agents in parallel → barrier.
Phase E: folds contested boundaries into VOQ-1, writes deliberation.md, records depth=full.
First Step 4 message: Investigation Summary + Recommendation + "I have 1 validated question (VOQ-1)."
Single-cluster counter-example: a 1-piece PRD → 1 viability agent, Phase C SKIPPED (≤1 cluster). -->

**Step 4: Brainstorm**

Interactive, one question at a time, in the order below. Do not batch questions; wait for the user's answer before proceeding to the next sub-step.

**4a. Persona coverage:** "Does the PRD cover all distinct user types who will use this product? Is there any user with meaningfully different needs not yet represented?" For FRs that touch multiple personas: "Do any personas have conflicting needs around [FR]? If so, should those be separate FRs?"

**4b. User story coverage:** Walk through each FR. For any FR still without a user story after the enrichment pass, ask: "FR-xxx says [requirement]. Who specifically needs this and what outcome does it give them?" Confirm ≥1 user story per FR before proceeding.

**4c. Edge case elicitation:** "What are the 3 most likely user errors, misuse scenarios, or failure cases for this product? Should any of these become explicit FRs or NFRs?"

**4d. Risk identification:** "Which FRs are highest risk — either technically uncertain or dependent on assumptions we haven't validated? Let's flag those as P0 risk in the Priority Tiers."

**4e. Conditional flows:** "Are there any 'if the user does X, then Y must happen' paths not yet captured as requirements?"

**4f. Success metric ownership:** "Does each SC-xxx have a piece in the planned breakdown responsible for making it measurable? Is there any SC without a clear owner?"

**4g. Non-goal elicitation (per feature area):** For each major feature area with ≥3 FRs: "For [feature area], what's the adjacent thing we're explicitly NOT building?" Require at least 1 non-goal per 3 FRs. Add confirmed non-goals to `## Non-Goals`.

**4h. Piece identification:** "Based on this PRD, let's identify the independently implementable pieces. Each piece should be completeable in one execution session, have no more than ~5-7 acceptance criteria, and be independently testable. What are the natural groupings?"

**4i. Piece granularity check:** "Are any of these pieces large enough to split further? Flag any piece you estimate would need more than ~7 ACs."

**4j. Dependency ordering:** "Which pieces depend on others? What's the right sequencing? Which can be built in parallel?"

**4k. Adversarial close:** "What would a skeptical stakeholder say is missing from this PRD? If one assumption here is wrong, which one would most invalidate the whole product?"

**4l. Branching strategy:** "Will this PRD's pieces accumulate on a dedicated feature branch before merging, or develop directly on `master`?" Ask one follow-up at a time:
   - If a feature branch: "What should it be named? (e.g., `feature/<prd-slug>`)"
   - "Where does the feature branch ultimately merge when the full PRD ships? (default: `master` / `main` / `develop`)"
   - "Should piece branches merge back via PR or direct push?" (default: PR)
   
   Capture all three answers as:
   - `feature_branch`: accumulator branch name, or null for direct-to-master
   - `merge_target`: destination when the PRD ships (default: `master`)
   - `pr_required`: `true` for PR, `false` for direct push (default: `true`)
   
   These are written to `manifest.yaml` front-matter in Step 6 so all downstream skills (spec, plan, execute) enforce the correct branching topology automatically — no per-session configuration needed.

End brainstorm only when all sub-steps above are confirmed. Ask: "Any other requirements, constraints, or concerns before we lock the breakdown?"

**Step 5: qa-prd gate**

Dispatch a PRD completeness review agent:

```
Agent({
  description: "PRD completeness review for <prd-slug>",
  prompt: <read agents/qa-prd.md, interpolate full PRD content + manifest draft>,
  model: "opus"
})
```

Iteration policy (same as spec skill QA loop):

- If must-fix findings are returned: dispatch `fix-doc` agent to repair PRD content, re-dispatch `qa-prd` for focused re-review of changed sections only.
- Iterate until clean or circuit breaker (3 iterations maximum). After 3 iterations with remaining must-fix findings, surface them to the user and require explicit waive-or-fix decision for each.
- **Must-fix findings block manifest creation.** The manifest is only created after `qa-prd` returns clean (or user explicitly waives).

**Step 6: Create manifest**

At `<docs_root>/prds/<prd-slug>/manifest.yaml` (v3 layout):

- Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/manifest.yaml`
- Populate pieces list with names, descriptions, prd_sections, dependencies
- All pieces start with status: `open`
- Calculate coverage section
- For each piece, verify `prd_sections:` references real FR-xxx / NFR-xxx identifiers from the normalized PRD (no dangling references)
- Write branching strategy from step 4l into the manifest front-matter:
  ```yaml
  feature_branch: <value or null>  # piece branches base off this and merge here after execute
  merge_target: <value>            # feature_branch merges here when full PRD ships
  pr_required: <true|false>        # piece branches merge via PR (not direct push)
  ```

**Step 7: Create backlog**

At `<docs_root>/prds/<prd-slug>/backlog.md` (v3 layout, FR-001):

- Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`
- PRD-scoped deferred work; cross-PRD learnings still live at `<docs_root>/improvement-backlog.md`.

**Step 8: Cleanup pass**

NOW strip ceremony artifacts from `prd.md`: process checklists, meeting notes, template instructions, empty placeholder sections, vacuous one-liner bios that the user confirmed as content-free during the enrichment pass. This cleanup runs AFTER brainstorm — not before — to avoid discarding content that informed the breakdown.

Any `[NEEDS REVIEW]` markers still present must be resolved or explicitly accepted by the user before cleanup completes.

**Step 9: Archive legacy import scrap (optional, not for PRDs)**

This step exists ONLY for import-source artifacts (BMad `_bmad-output/`, hand-written specs predating spec-flow) — NOT for PRDs themselves. Archived PRDs stay in place via `status: archived` front-matter; there is no `docs/prds/archive/` convention.

- If legacy import scrap exists, create `<docs_root>/archive/` (the import-scrap folder, not a PRD location) and move the scrap there.
- Do NOT delete — move only.
- Skip this step entirely if no legacy scrap is present.

**Step 10: Commit**

- v3 layout: `git add <docs_root>/prds/<prd-slug>/prd.md <docs_root>/prds/<prd-slug>/manifest.yaml <docs_root>/prds/<prd-slug>/backlog.md`
- Also stage any charter non-negotiables updates if you appended NN-C entries in step 2a: `git add <charter_root>/skills/charter-non-negotiables/SKILL.md` (`<charter_root>` ∈ {`.github`, `.claude`}, resolved per `plugins/spec-flow/reference/charter-location.md`).
- Also stage `<docs_root>/archive/` only if step 9 actually moved scrap there.
- `git commit -m "feat(<prd-slug>): import and normalize PRD, create manifest"`

## Create Mode Workflow

This mode runs when the user has an idea but no existing PRD document. It conducts a structured Socratic interview to elicit all PRD content before writing the document.

> **Order:** argument parsing → slug-validator → slug uniqueness check → interview (steps 1–8) → write PRD → brainstorm (same as Import mode Step 4) → qa-prd gate (same as Import mode Step 5) → create manifest (Step 6) → create backlog (Step 7) → commit.

Ask one question at a time. Wait for the user's full answer before advancing to the next question. Do not batch multiple questions in a single turn.

> **Deferred decisions throughout the interview:** Throughout the interview, if the user explicitly defers any decision (phrases like "I haven't decided yet", "TBD", "to be determined"), emit `[PENDING-DECISION: <brief area description>]` inline at the location of the deferred decision in the PRD draft and confirm with the user: "I've marked this as `[PENDING-DECISION: <brief area description>]` in the PRD." The step 8 prompt serves as a final catch-all for anything not yet captured.

**Step 1: Problem statement elicitation**

Ask in sequence:
1. "What problem are you solving? Describe it in one or two sentences."
2. "Who experiences this problem? Who are the primary users?"
3. "How do users currently work around it? What does that cost them (time, money, frustration)?"
4. "Why is this the right time to solve it?"

**Step 2: Persona elicitation**

For each user type identified in Step 1:

- "Tell me about [user type] — what's their role, their main goal, and the biggest pain point this product addresses for them?"

Continue asking for each user type. When the user has described all personas: "Are there any other user types with meaningfully different needs?" Proceed when the user confirms all are covered. Minimum 1 persona required before advancing.

**Step 3: User story elicitation**

For each major capability the user describes, draft a user story in this format: *"As a [persona], I want [capability], so that [value]."* Then ask:

- "What are the acceptance criteria? How would you verify this works correctly?"
- "What can go wrong? Name one failure mode and how the system should behave."

Continue until user confirms all capabilities are captured.

**Step 4: Success metrics**

"How will we know this product is working? Name 1–3 measurable outcomes with specific targets (e.g., 'reduce support tickets by 30% within 90 days of launch')."

**Step 5: Non-goals**

For each major feature area identified: "What's the adjacent capability we're explicitly NOT building right now?" Require at least 1 entry before proceeding.

**Step 6: Constraints and assumptions**

"Are there timeline, budget, technology, regulatory, or integration constraints? What are we assuming about users or the market that we haven't validated yet?"

**Step 7: Risk areas**

"Which requirements are most uncertain — technically or in terms of assumptions? If one thing would invalidate this PRD, what is it?"

**Step 8: Open questions**

"Are there things you still need to decide or research before development begins? Let's track them."

For each open question the user identifies:
- If the user wants to resolve it now, elicit the answer and record it inline in the PRD at the relevant FR or NFR.
- If the user explicitly defers the decision ("I haven't decided yet" or equivalent), emit `[PENDING-DECISION: <decision area>]` inline in the PRD draft at the location of the deferred decision — not in a separate section. Confirm: "I've marked this as `[PENDING-DECISION: <decision area>]` in the PRD."

`[PENDING-DECISION]` markers in the PRD are informational — they signal deferred product-level decisions. The spec skill for each piece resolves them when the affected piece is brainstormed. A surviving `[PENDING-DECISION]` in a PRD section is not an error in the PRD itself; it is a signal that the corresponding spec brainstorm must address it.

After all steps: write the PRD using `${CLAUDE_PLUGIN_ROOT}/templates/prd.md` as the structural guide, populated with all elicited content. Set front-matter `slug: <prd-slug>`, `status: drafting`, `version: 1`.

Then proceed through:
- **Deliberation** (the `[Deliberation protocol]` block from Import mode — runs before Step 4 in both Import and Create modes; the deliberation pass precedes Step 4 Brainstorm in all modes)
- **Brainstorm** (Import mode Step 4, sub-steps 4a–4k)
- **qa-prd gate** (Import mode Step 5)
- **Create manifest** (Import mode Step 6)
- **Create backlog** (Import mode Step 7)
- (No cleanup pass or archive step for Create mode — PRD was authored clean.)

**Commit:** `git add <docs_root>/prds/<prd-slug>/prd.md <docs_root>/prds/<prd-slug>/manifest.yaml <docs_root>/prds/<prd-slug>/backlog.md`, then:

```
git commit -m "feat(<prd-slug>): create PRD from scratch, create manifest"
```

## Update Mode Workflow

1. Resolve the target PRD slug per the "Argument parsing" rules (no-arg → "the only active PRD"; error if multiple `status: active` PRDs exist without a slug — FR-006).
2. Run the **charter-drift check** per `${CLAUDE_PLUGIN_ROOT}/reference/charter-drift-check.md`. Apply when this PRD's pieces have specs at `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` carrying `charter_snapshot:` values; otherwise skip (no anchor to drift against).
3. Read existing `<docs_root>/prds/<prd-slug>/prd.md` and `<docs_root>/prds/<prd-slug>/manifest.yaml`.
4. Discuss changes with user (new pieces, reprioritization, PRD amendments). Track which PRD sections are added or changed during this discussion.
5. Update manifest and PRD accordingly. Bump the PRD front-matter `version:` per FR-002 if PRD-level fields change.
6. **Impact assessment:** After recording any PRD amendments, scan `<docs_root>/prds/<prd-slug>/specs/*/spec.md` for pieces whose `prd_sections:` in the manifest maps to any changed or added PRD sections. If affected pieces are found, surface them:

   > "These pieces have specs that reference sections you just changed: [list with piece slugs and section names]. They may need re-review to confirm their ACs are still accurate."

   Offer to dispatch `qa-spec` focused re-review for each affected piece — ask the user which ones to re-review. Dispatch the user-approved set sequentially. If no pieces are affected, skip this step silently.

7. Commit changes: `git add <docs_root>/prds/<prd-slug>/...` then `git commit -m "feat(<prd-slug>): update PRD/manifest"`.

## Review Mode Workflow (prd --review)

1. Resolve the target PRD slug per the "Argument parsing" rules.
2. Read `<docs_root>/prds/<prd-slug>/prd.md` (full PRD) and `<docs_root>/prds/<prd-slug>/manifest.yaml`.
3. Read all completed specs: `<docs_root>/prds/<prd-slug>/specs/<piece-slug>/spec.md` for pieces with status `merged` or `done` (the two terminal states per the spec's piece-status state machine — v3-native pieces land as `merged`; `done` is the backward-compatible alias).
4. Read the current codebase (use Grep, Glob, Read for key files).
5. Dispatch a PRD alignment review agent:

   ```
   Agent({
     description: "Full PRD completion review",
     prompt: <read agents/qa-prd-review.md, interpolate PRD + all specs + manifest>,
     model: "opus"
   })
   ```

6. Process findings through the standard QA loop:
   - must-fix → fix → re-review → until clean (circuit breaker: 3 iterations)
7. Present results to user
