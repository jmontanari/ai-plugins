---
name: spec
description: Use when authoring a detailed specification for a piece from the spec-flow manifest — including when the user says "spec out X", "write a spec for Y", "let's design the next piece", or wants to start work on the next `open` piece. Brainstorms with the user one question at a time, creates a worktree on a feature branch, writes the spec, runs adversarial QA review, and gets human sign-off before advancing. Use whenever the pipeline is in a state where the next move is to spec a piece — even if the user doesn't explicitly say "spec".
---

# Spec — Author Spec for One Piece

Author a detailed specification for one piece from the manifest through Socratic dialogue, adversarial QA review, and human sign-off.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- `docs/manifest.yaml` must exist (run `prd` first)
- The piece must have status `open` in the manifest

## Workflow

### Phase 1: Load Context

1. Read `docs/manifest.yaml` — find the target piece (from user argument or next `open` piece)
2. Read `docs/prd.md` — extract the PRD sections mapped to this piece
3. Read `docs/architecture/` — load any architecture decision docs
4. Scan `docs/specs/*/learnings.md` — load learnings from previously completed pieces
5. Scan `CLAUDE.md` and `docs/prd.md` for non-negotiables (NN-xxx pattern)

### Phase 2: Brainstorm

Socratic dialogue with the user, one question at a time:

1. Confirm the piece scope: "This piece covers [PRD sections]. Does that match your intent?"
2. Explore purpose and boundaries
3. PRD compliance check: if the manifest maps requirements the user hasn't mentioned, ask about them
4. Propose 2-3 approaches with trade-offs and your recommendation
5. Resolve all open questions — no `[NEEDS CLARIFICATION]` markers may survive

### Phase 3: Create Worktree and Write Spec

1. Check if `worktrees/` is in `.gitignore` — add it if missing
2. Create worktree (before writing, so all work lives on the feature branch):
   ```bash
   git worktree add worktrees/<piece-name> -b spec/<piece-name>
   ```
3. Write `docs/specs/<piece-name>/spec.md` in the worktree directory
4. Use the template at `${CLAUDE_PLUGIN_ROOT}/templates/spec.md` as the structural guide

### Phase 4: QA Loop

1. Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-spec.md`
2. Compose prompt: interpolate the spec, PRD sections, architecture docs, manifest piece, non-negotiables
3. Dispatch QA agent:
   ```
   Agent({
     description: "Spec QA review for <piece-name>",
     prompt: <composed prompt>,
     model: "opus"
   })
   ```
4. Parse findings. If `must-fix` findings exist:
   - Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md`
   - Dispatch fix agent:
     ```
     Agent({
       description: "Fix spec findings for <piece-name>",
       prompt: <composed with findings + spec + context>,
       model: "sonnet"
     })
     ```
   - Re-dispatch QA agent (completely fresh — new Agent call)
   - **Circuit breaker:** After 3 QA iterations, escalate to human
5. When QA returns clean: present spec to user for sign-off

**Limitation:** The QA agent cannot assess brainstorming trade-offs not captured in the spec. The human sign-off covers this gap.

### Phase 5: Finalize

1. User approves → continue. User requests changes → make them → back to QA loop.
2. Update `docs/manifest.yaml` on main: piece status → `specced`
   ```bash
   git checkout main
   # update manifest.yaml status for this piece
   git add docs/manifest.yaml
   git commit -m "manifest: mark <piece-name> as specced"
   git checkout spec/<piece-name>
   ```
3. Commit spec on worktree branch:
   ```bash
   git add docs/specs/<piece-name>/spec.md
   git commit -m "spec: add <piece-name> specification"
   ```

## NEEDS CLARIFICATION Lifecycle

These markers flag unresolved questions during brainstorming. The skill MUST resolve all markers with the user before writing the final spec. The QA agent treats any surviving marker as a must-fix finding.
