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
6. Read `<docs_root>/improvement-backlog.md` if it exists. This file accumulates end-of-piece reflection findings from prior pieces (process retros + future opportunities). For each item recorded, semantic-match against this piece's name (from manifest) and the user's brainstorm prompt; surface the ~5 most-relevant items as candidate considerations during Phase 2 brainstorm. Track user responses in orchestrator state for Phase 5 prune (statuses: `incorporated` — addressed by this piece's spec; `deferred` — still relevant but not in this piece's scope; `obsolete` — no longer applies). If the file does not exist (first piece on a new project), skip silently. If `reflection: off` is set but the file exists from a previous run, still read it — stale findings from past reflections may still be useful brainstorm context.

### Phase 2: Brainstorm

Socratic dialogue with the user, one question at a time:

1. Confirm the piece scope: "This piece covers [PRD sections]. Does that match your intent?"
2. **Surface backlog items.** If Phase 1 step 6 loaded items from `<docs_root>/improvement-backlog.md`, present the top ~5 most-relevant to the user with their concrete references and ask "for each, is this `incorporated` in this piece's spec, `deferred` to a later piece, or `obsolete`?" Record each response in orchestrator state keyed by backlog item — Phase 5 step 4 reads this state to prune `incorporated` and `obsolete` entries from the file. If no items were surfaced (file did not exist, or no relevant matches), skip this step.
3. Explore purpose and boundaries
4. PRD compliance check: if the manifest maps requirements the user hasn't mentioned, ask about them
5. Propose 2-3 approaches with trade-offs and your recommendation
6. Resolve all open questions — no `[NEEDS CLARIFICATION]` markers may survive

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

2. **Iteration 1 (full review):** Compose prompt with `Input Mode: Full`: interpolate the full spec, PRD sections, architecture docs, manifest piece, non-negotiables. Dispatch:
   ```
   Agent({
     description: "Spec QA for <piece-name> (iter 1, full)",
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
4. **Prune addressed backlog items.** If Phase 1 step 6 surfaced backlog items and the user marked any as `incorporated` or `obsolete` during brainstorm, remove those entries from `<docs_root>/improvement-backlog.md`. `deferred` items stay in the file. Commit the prune as a separate commit on the worktree branch:
   ```bash
   git add <docs_root>/improvement-backlog.md
   git commit -m "chore: prune backlog items addressed by <piece-name>"
   ```
   If no items were marked or no backlog existed, skip this step.

## NEEDS CLARIFICATION Lifecycle

These markers flag unresolved questions during brainstorming. The skill MUST resolve all markers with the user before writing the final spec. The QA agent treats any surviving marker as a must-fix finding.
