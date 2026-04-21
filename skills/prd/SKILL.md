---
name: prd
description: Use when importing an existing PRD into the spec-flow pipeline, decomposing it into implementable pieces, onboarding a new project that already has requirements docs (BMad, speckit, a Notion export, or a plain `prd.md`), or reviewing PRD fulfillment after all pieces are complete. Also handles updating the manifest when the PRD changes or the user wants to add/reprioritize pieces. Use whenever the user mentions "import my PRD", "set up spec-flow", "onboard this project", or "validate we built everything the PRD asked for".
---

# PRD — Import, Normalize, Decompose

Import an existing PRD, normalize it into the pipeline format, decompose it into implementable pieces, and create the tracking manifest.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`. During import, if the user specifies a non-default docs location or you detect docs live elsewhere (e.g., `repo/docs/`), update `.spec-flow.yaml` accordingly.

## Step 0.5: Charter Prerequisite Check

Read the `charter:` block from `.spec-flow.yaml` (added in v2.0.0). Two keys: `required` (default `false`) and `doctrine_load`.

- If `charter.required: true` and `<docs_root>/charter/` does not exist → respond with: *"Charter is required for this project but `<docs_root>/charter/` is missing. Run `/spec-flow:charter` first to bootstrap the charter, then re-run `prd`."* Halt.
- If `<docs_root>/charter/` exists → continue; charter content is available for PRD import (you can cite `NN-C-xxx` from `<docs_root>/charter/non-negotiables.md` when classifying PRD constraints).
- If `<docs_root>/charter/` does not exist and `charter.required: false` → continue. Treat this as a pre-charter project; the PRD holds all non-negotiables as unprefixed `NN-xxx` (legacy) until the project chooses to retrofit.

Legacy layout detection: if `<docs_root>/prd.md` exists at the legacy flat path (v1.5.x and prior) rather than `<docs_root>/prd/prd.md`, note this and offer: *"Detected legacy docs layout (pre-v2.0). Run `/spec-flow:charter --retrofit` to migrate to the new charter-aware layout — nine-step, commit-per-step, fully revertable. Until then, this `prd` skill continues to read and write the legacy path for backward compat."*

## Modes

Detect which mode based on arguments and current state:

- **Import mode:** `docs/manifest.yaml` does not exist. First-time onboarding.
- **Update mode:** `docs/manifest.yaml` exists. User wants to add pieces or update.
- **Review mode:** User invoked with `--review` argument. Validate full PRD fulfillment.

## Import Mode Workflow

1. **Detect existing artifacts:**
   - Check for BMad artifacts: `_bmad-output/planning-artifacts/PRD.md`
   - Check for speckit specs: `specs/*/spec.md`
   - Check for raw docs: `docs/`, `README.md`, any `*.md` with "requirements" content
   - Report what was found and ask user to confirm the source PRD

2. **Read and normalize PRD** into the PRD path — `<docs_root>/prd/prd.md` (v2.0.0 layout; default for new projects) or `<docs_root>/prd.md` (legacy; only if you detected legacy layout in Step 0.5 and chose to preserve it):
   - Extract functional requirements → number as FR-001, FR-002, ...
   - Extract non-functional requirements → number as NFR-001, NFR-002, ...
   - Extract goals and non-goals
   - Extract success metrics → number as SC-001, SC-002, ...
   - Extract constraints / non-negotiables:
     - If charter exists (`<docs_root>/charter/non-negotiables.md`), classify each constraint:
       - Project-wide (security, compliance, architecture, tooling) → propose adding to charter as `NN-C-xxx`. Ask the user to confirm; if accepted, append to `<docs_root>/charter/non-negotiables.md` with the next sequential NN-C ID.
       - Product-specific (tied to this PRD) → number as `NN-P-001, NN-P-002, ...` in the `## Non-Negotiables (Product)` section of `prd.md`.
     - If charter does not exist (legacy pre-charter project) → number as unprefixed `NN-001, NN-002, ...` in the PRD's legacy `## Non-Negotiables` section. Retrofit (piece 6) will reclassify later.
   - Strip process metadata, persona theater, ceremony artifacts
   - Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/prd.md` as the structural guide. In v2.0.0, the template uses `## Non-Negotiables (Product)` with structured entries. For pre-charter projects, fall back to the legacy `## Non-Negotiables` section shape.

3. **Brainstorm breakdown** with user (interactive, one question at a time):
   - Identify independently implementable and testable pieces
   - Each piece traces to specific PRD sections (FR-xxx, NFR-xxx)
   - Identify dependency ordering between pieces
   - Ask: "Does this breakdown cover all requirements? Any pieces missing?"

4. **Create manifest** at `<docs_root>/prd/manifest.yaml` (v2.0.0 layout) or `<docs_root>/manifest.yaml` (legacy — if preserving legacy layout):
   - Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/manifest.yaml`
   - Populate pieces list with names, descriptions, prd_sections, dependencies
   - All pieces start with status: `open`
   - Calculate coverage section

5. **Archive legacy artifacts:**
   - Create `docs/archive/` if it doesn't exist
   - Move legacy artifacts (BMad `_bmad-output/`, old specs) to `docs/archive/`
   - Do NOT delete — move only

6. **Commit:**
   - New-layout projects: `git add <docs_root>/prd/prd.md <docs_root>/prd/manifest.yaml <docs_root>/archive/` (also stage any `<docs_root>/charter/non-negotiables.md` updates if you appended NN-C entries in step 2).
   - Legacy-layout projects: `git add <docs_root>/prd.md <docs_root>/manifest.yaml <docs_root>/archive/`
   - `git commit -m "feat: import and normalize PRD, create manifest"`

## Update Mode Workflow

1. Read existing `docs/manifest.yaml` and `docs/prd.md`
2. Discuss changes with user (new pieces, reprioritization, PRD amendments)
3. Update manifest accordingly
4. Commit changes

## Review Mode Workflow (prd --review)

1. Read `docs/prd.md` (full PRD) and `docs/manifest.yaml`
2. Read all completed specs: `docs/specs/*/spec.md` for pieces with status `done`
3. Read the current codebase (use Grep, Glob, Read for key files)
4. Dispatch a PRD alignment review agent:

   ```
   Agent({
     description: "Full PRD completion review",
     prompt: <read agents/qa-prd-review.md, interpolate PRD + all specs + manifest>,
     model: "opus"
   })
   ```

5. Process findings through the standard QA loop:
   - must-fix → fix → re-review → until clean (circuit breaker: 3 iterations)
6. Present results to user

## No QA Gate on Import/Update

The user is directly involved in the brainstorming, so no separate QA agent is needed.
