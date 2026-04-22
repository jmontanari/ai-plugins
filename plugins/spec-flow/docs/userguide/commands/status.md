# /spec-flow:status

Pipeline dashboard. Shows which pieces are in which stage, what is blocked, and what to work on next.

## What it does

Reads the current state of the project — the charter, the PRD manifest, the worktree branches, the committed specs and plans — and produces a human-readable summary:

- Which pieces are `open`, `specced`, `planned`, `implementing`, or `done`
- Which pieces are blocked by manifest dependencies
- What action is next (run charter? import PRD? spec the next open piece?)
- Any mid-flight state (spec worktree exists but spec isn't committed; plan exists but execute hasn't started)

It doesn't modify any files. It's a pure query.

## When to run it

- **Starting a fresh project:** you'll see "no charter yet." Start there.
- **Resuming after a break:** run it first. It tells you where the pipeline left off.
- **Any time you're unsure what to work on:** the answer is here.

Run it *before* charter, before PRD, before spec, before anything. It's designed to orient you from zero context.

## The flow

1. Scans `docs/charter/` — does it exist? Is it complete?
2. Scans `docs/prd/prd.md` and `docs/prd/manifest.yaml` — does the PRD exist? How many pieces does it enumerate?
3. For each piece in the manifest, checks:
   - Manifest status (`open` / `specced` / `planned` / `implementing` / `done` / `superseded`)
   - Whether a spec / plan / learnings file exists on disk
   - Whether a worktree branch `spec/<piece-name>` exists
   - Whether the piece's declared dependencies are `done`
4. Produces a table and a "next action" recommendation.

## Loops

None. This command has no QA loop, no brainstorming, no iteration. It queries and exits.

## What you get

A dashboard printed to the session. Example output shape:

```
Charter: present (docs/charter/, 6 files)
PRD:     present (docs/prd/prd.md, 7 pieces)

Pieces:
  PI-001-marketplace-version-sync         done
  PI-002-version-sync-ci                  open         (blocked by: none)
  PI-003-charter-dogfood-lessons          open         (blocked by: PI-002)
  PI-004-second-plugin-pilot              open         (blocked by: none)
  PI-005-copilot-cli-parity-map           superseded
  PI-006-copilot-mirror-ci                superseded
  PI-007-copilot-coship                   done

Next action: run /spec-flow:spec PI-002 or /spec-flow:spec PI-004
```

No files are written or modified.

## Handoff

Whatever the "Next action" line says — typically one of:

- `/spec-flow:charter` (bootstrap or retrofit)
- `/spec-flow:prd` (import or amend the PRD)
- `/spec-flow:spec <piece-name>` (author a spec for an open piece)
- `/spec-flow:plan` (plan a specced piece, once inside the piece's worktree)
- `/spec-flow:execute` (execute a planned piece, once inside the piece's worktree)

## Worked example

You haven't touched the project in two weeks. You run `/spec-flow:status`:

```
Charter: present
PRD:     present (12 pieces)

Pieces in flight:
  PI-012-user-export    implementing    (worktree: worktrees/PI-012-user-export/)
                        plan.md present, 4 of 7 phases complete per checkboxes

Next action: resume /spec-flow:execute on PI-012
```

You know exactly where you left off. `cd worktrees/PI-012-user-export/` and run `/spec-flow:execute` to pick up from phase 5.

## Where to go next

- [Pipeline concepts](../concepts/pipeline.md)
- Next command in a fresh project: [/spec-flow:charter](./charter.md)
