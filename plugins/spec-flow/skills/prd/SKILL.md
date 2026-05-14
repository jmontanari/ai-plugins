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

# PRD — Import, Create, Normalize, Decompose

Import an existing PRD or build one from scratch via structured interview, normalize it into the pipeline format, decompose it into implementable pieces, and create the tracking manifest.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`. During import, if the user specifies a non-default docs location or you detect docs live elsewhere (e.g., `repo/docs/`), update `.spec-flow.yaml` accordingly.

## Step 0.5: Charter Prerequisite Check

Read the `charter:` block from `.spec-flow.yaml` (added in v2.0.0). Two keys: `required` (default `false`) and `doctrine_load`.

**Auto-detect charter location** (check in this order):
1. **v4** — `.github/skills/charter-non-negotiables/SKILL.md` exists → charter lives at `.github/skills/charter-*/SKILL.md`
2. **v3** — `<docs_root>/charter/` directory exists → charter lives at `<docs_root>/charter/`
3. **none** — neither exists

Record the detected variant as `charter_variant` (`v4`, `v3`, or `none`) for use in later steps.

- If `charter.required: true` and `charter_variant == none` → respond with: *"Charter is required for this project but no charter files were found at `.github/skills/charter-*/SKILL.md` or `<docs_root>/charter/`. Run `/spec-flow:charter` first to bootstrap the charter, then re-run `prd`."* Halt.
- If `charter_variant == v4` → continue; cite `NN-C-xxx` entries from `.github/skills/charter-non-negotiables/SKILL.md` when classifying PRD constraints.
- If `charter_variant == v3` → continue; cite `NN-C-xxx` entries from `<docs_root>/charter/non-negotiables.md` when classifying PRD constraints.
- If `charter_variant == none` and `charter.required: false` → continue. Treat this as a pre-charter project; the PRD holds all non-negotiables as unprefixed `NN-xxx` (legacy) until the project chooses to retrofit.

**Legacy layout detection:** if `<docs_root>/prd.md` exists at the legacy flat path (v1.5.x and prior) rather than `<docs_root>/prd/prd.md`, present the retrofit offer: *"Detected legacy docs layout (pre-v2.0). Run `/spec-flow:charter --retrofit` to migrate to the new charter-aware layout — nine-step, commit-per-step, fully revertable."* Then pause:

> "Do you want to run the retrofit now before continuing? (yes / no / remind me later)"

- **yes** → halt and direct the user to run `/spec-flow:charter --retrofit` first; do not continue.
- **no or remind me later** → emit a persistent warning banner: `⚠️ [LEGACY-MODE] This project uses the pre-v2.0 layout. Some skill features are limited until retrofit.` Write `legacy_mode: true` under the `charter:` block in `.spec-flow.yaml`. Note `[LEGACY-MODE: true]` in the manifest YAML front-matter (written at commit time) so downstream skills have a visible signal. Continue with legacy path behavior for backward compat.

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
- Extract constraints / non-negotiables:
  - If `charter_variant` is `v4` or `v3`, classify each constraint:
    - Project-wide (security, compliance, architecture, tooling) → propose adding to charter as `NN-C-xxx`. Ask the user to confirm; if accepted, append the new entry to the charter non-negotiables file:
      - v4: `.github/skills/charter-non-negotiables/SKILL.md`
      - v3: `<docs_root>/charter/non-negotiables.md`
    - Product-specific (tied to this PRD) → number as `NN-P-001, NN-P-002, ...` in the `## Non-Negotiables (Product)` section of `prd.md`.
  - If charter does not exist (legacy pre-charter project) → number as unprefixed `NN-001, NN-002, ...` in the PRD's legacy `## Non-Negotiables` section. Retrofit (piece 6) will reclassify later.

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
- If `legacy_mode: true` (from Step 0.5), add `legacy_mode: true` to the manifest YAML front-matter
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

This step exists ONLY for legacy import artifacts (BMad `_bmad-output/`, old hand-written specs predating spec-flow) — NOT for PRDs themselves. Archived PRDs in v3 stay in place via `status: archived` front-matter; there is no `docs/prds/archive/` convention.

- If legacy import scrap exists, create `<docs_root>/archive/` (the import-scrap folder, not a PRD location) and move the scrap there.
- Do NOT delete — move only.
- Skip this step entirely if no legacy scrap is present.

**Step 10: Commit**

- v3 layout: `git add <docs_root>/prds/<prd-slug>/prd.md <docs_root>/prds/<prd-slug>/manifest.yaml <docs_root>/prds/<prd-slug>/backlog.md`
- Also stage any charter non-negotiables updates if you appended NN-C entries in step 2a:
  - v4: `git add .github/skills/charter-non-negotiables/SKILL.md`
  - v3: `git add <docs_root>/charter/non-negotiables.md`
- Also stage `<docs_root>/archive/` only if step 9 actually moved scrap there.
- `git commit -m "feat(<prd-slug>): import and normalize PRD, create manifest"`

## Create Mode Workflow

This mode runs when the user has an idea but no existing PRD document. It conducts a structured Socratic interview to elicit all PRD content before writing the document.

> **Order:** argument parsing → slug-validator → slug uniqueness check → interview (steps 1–8) → write PRD → brainstorm (same as Import mode Step 4) → qa-prd gate (same as Import mode Step 5) → create manifest (Step 6) → create backlog (Step 7) → commit.

Ask one question at a time. Wait for the user's full answer before advancing to the next question. Do not batch multiple questions in a single turn.

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

After all steps: write the PRD using `${CLAUDE_PLUGIN_ROOT}/templates/prd.md` as the structural guide, populated with all elicited content. Set front-matter `slug: <prd-slug>`, `status: drafting`, `version: 1`.

Then proceed through:
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
