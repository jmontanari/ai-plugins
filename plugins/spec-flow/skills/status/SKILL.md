---
name: status
description: Use when starting a session on a spec-flow project, checking progress on the spec-flow pipeline, or asking what to work on next (e.g. "where are we", "what's next", "pipeline status", "anything in flight"). Shows PRD coverage, current piece state, phase progress, and recommends the next spec-flow action. Use whenever the user wants a snapshot of spec-flow pipeline state, even if they don't say "status" explicitly.
---

# Pipeline Status

Show the current state of the development pipeline and recommend what to work on next.

## Workflow

0. **Load config:** Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` and `worktrees_root` in place of `worktrees/` for all paths below. If the file is missing, default to `docs` and `worktrees`.

1. **Read manifest:** Look for `docs/manifest.yaml` in the project root. If it does not exist, report: "No pipeline initialized. Run the `prd` skill to import a PRD and create the manifest."

2. **Parse manifest:** Read the YAML file. Extract the pieces list with their statuses and the coverage section.

3. **Scan active specs:** For each piece with status `specced`, `planned`, or `implementing` (a piece is `implementing` while `execute` is running against it):
   - Check if `docs/specs/<piece-name>/spec.md` exists
   - Check if `docs/specs/<piece-name>/plan.md` exists
   - If plan.md exists, count `- [x]` vs `- [ ]` checkboxes to determine phase progress

4. **Check worktrees:** Run `git worktree list` to identify active worktrees matching the `spec/<piece-name>` branch pattern.

5. **Present status:**

Display a dashboard like:
```
PRD Coverage: ■■■■■□□□□□  N/M pieces done

Current: <piece-name>
  Worktree: spec/<piece-name>
  Status: <status> (Phase X of Y)
  
  Phase 1: <name>     ✓ done
  Phase 2: <name>     ● in-progress (<current-step>)
  Phase 3: <name>       pending

Next up: <next-piece> (<status>, ready to <action>)

Blocked: <blocked-pieces with unmet dependencies, or "nothing">
```

6. **Recommend next action:**
   - No manifest → "Run `prd` to initialize the pipeline"
   - No active piece → "Run `spec` on the next `open` piece in the manifest"
   - Spec exists, no plan → "Run `plan` on `<piece>`"
   - Plan exists, not started → "Run `execute` on `<piece>`"
   - Mid-implementation → "Resume `execute` — Phase N, step `<step>`"
   - All pieces done → "All pieces complete. Run `prd --review` to validate full PRD fulfillment."

7. **Surface blocked pieces:** Check each piece's dependencies against the manifest. If a dependency is not `done`, report the piece as blocked.

## PRD Completion Detection

When all pieces in the manifest have status `done`, prompt:
> "All pieces are marked done. Run `prd --review` to validate full PRD fulfillment?"
