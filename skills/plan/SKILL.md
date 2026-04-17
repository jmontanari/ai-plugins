---
name: plan
description: Use when a spec is approved and needs a detailed implementation plan. Does read-only codebase exploration, generates an exhaustive phase-by-phase plan where each phase picks a TDD track (for behavior-bearing code) or an Implement track (for config, infra, glue code, docs-as-code), runs QA review, and gets human sign-off. Use whenever the user wants to turn an approved spec into an executable plan — even for non-TDD work.
---

# Plan — Generate Detailed Implementation Plan

Generate an exhaustive implementation plan from an approved spec. The plan is so detailed that a Sonnet-tier agent can execute each task without design decisions.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

## Prerequisites

- Piece must have status `specced` in manifest
- `docs/specs/<piece-name>/spec.md` must exist and be approved
- Must be on the worktree branch `spec/<piece-name>`

## Workflow

### Phase 1: Read-Only Exploration

Extensively explore the codebase using ONLY read operations:
- `Read` — examine source files, test files, existing patterns
- `Grep` — find function signatures, class definitions, import patterns
- `Glob` — discover file structure and naming conventions
- `Bash` — read-only commands: `ls`, `git log`, `git diff`, `find`

**No files are written or edited during this phase.**

Gather:
- Existing code patterns relevant to this spec
- Function/class/method names that will be referenced (semantic anchors)
- Test framework patterns used in the project
- Import conventions and module structure
- Architecture constraints visible in the code

### Phase 2: Generate Plan

Using the spec, exploration findings, and the plan template at `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`:

1. Define phases — each phase is a testable unit of work:
   - Map each phase to specific acceptance criteria from the spec
   - Define a clear exit gate for each phase
   - Order phases by dependency (inside-out execution)

2. For each phase, choose ONE track and generate its structure. A phase must have exactly one track marker — the executor branches on it mechanically.

   **TDD track** (default for behavior-bearing code):
   - **[TDD-Red]**: Exact test file paths, test names, assertions, patterns to follow
   - **[Build]**: Exact source file paths, class/function signatures, implementation approach
   - **[Verify]**: Test command to run, expected output
   - **[Refactor]**: Scope constraints (phase files only)
   - **[QA]**: ACs to review against, diff baseline

   **Implement track** (for config, infra, scaffolding, glue/wiring, docs-as-code, fixtures, migrations — where unit-level TDD is ceremony without payoff):
   - **[Implement]**: Exact file paths, signatures/structure, pattern pointers, architecture constraints the phase must honor
   - **[Verify]**: The verification command the plan author chooses (lint, type check, build, smoke run, integration test) and its expected output
   - **[Refactor]** (optional): Include only if cleanup is plausibly needed
   - **[QA]**: ACs to review against, diff baseline

   Pick the track that matches reality. Don't force TDD onto a YAML file; don't skip TDD for a business rule.

3. Use semantic anchors (function names, class names) NOT line numbers
4. Mark parallel-eligible tasks with `[P]` — verify no file overlap
5. Include the agent context summary table

Write the plan to `docs/specs/<piece-name>/plan.md`

### Phase 3: QA Loop

1. Read template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-plan.md`
2. Dispatch QA agent (Opus) with plan + spec + PRD sections
3. Process findings:
   - must-fix → dispatch fix agent (using `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md`) → QA again
   - **Circuit breaker:** 3 iterations max, then escalate
4. Present to user for sign-off

### Phase 4: Finalize

1. User approves → continue
2. Update manifest on main: piece status → `planned`
   ```bash
   git checkout main
   # update manifest.yaml status for this piece
   git add docs/manifest.yaml
   git commit -m "manifest: mark <piece-name> as planned"
   git checkout spec/<piece-name>
   ```
3. Commit plan on worktree branch:
   ```bash
   git add docs/specs/<piece-name>/plan.md
   git commit -m "plan: add <piece-name> implementation plan"
   ```
