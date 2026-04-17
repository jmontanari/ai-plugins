---
name: prd
description: Use when importing an existing PRD into the pipeline, decomposing it into implementable pieces, or reviewing PRD fulfillment after all pieces are complete. Also handles updating the manifest when PRD changes.
---

# PRD — Import, Normalize, Decompose

Import an existing PRD, normalize it into the pipeline format, decompose it into implementable pieces, and create the tracking manifest.

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

2. **Read and normalize PRD** into `docs/prd.md`:
   - Extract functional requirements → number as FR-001, FR-002, ...
   - Extract non-functional requirements → number as NFR-001, NFR-002, ...
   - Extract goals and non-goals
   - Extract success metrics → number as SC-001, SC-002, ...
   - Extract constraints / non-negotiables → number as NN-001, NN-002, ...
   - Strip process metadata, persona theater, ceremony artifacts
   - Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/prd.md` as the structural guide

3. **Brainstorm breakdown** with user (interactive, one question at a time):
   - Identify independently implementable and testable pieces
   - Each piece traces to specific PRD sections (FR-xxx, NFR-xxx)
   - Identify dependency ordering between pieces
   - Ask: "Does this breakdown cover all requirements? Any pieces missing?"

4. **Create `docs/manifest.yaml`:**
   - Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/manifest.yaml`
   - Populate pieces list with names, descriptions, prd_sections, dependencies
   - All pieces start with status: `open`
   - Calculate coverage section

5. **Archive legacy artifacts:**
   - Create `docs/archive/` if it doesn't exist
   - Move legacy artifacts (BMad `_bmad-output/`, old specs) to `docs/archive/`
   - Do NOT delete — move only

6. **Commit:**
   - `git add docs/prd.md docs/manifest.yaml docs/archive/`
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
