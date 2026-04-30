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
2. Scans `docs/prds/` — how many PRD directories exist? For each, reads `prd.md` and `manifest.yaml`.
3. For each piece in each manifest, checks:
   - Manifest status (`open` / `specced` / `planned` / `in-progress` / `done` / `superseded`)
   - Whether a spec / plan / learnings file exists on disk
   - Whether a worktree branch `spec/<prd-slug>-<piece-slug>` exists
   - Whether the piece's declared dependencies are `done`
4. Produces a table per PRD and a "next action" recommendation.

## Loops

None. This command has no QA loop, no brainstorming, no iteration. It queries and exits.

## What you get

A dashboard printed to the session. Example output shape for a project with two active PRDs:

```
Charter: present (docs/charter/, 6 files)
PRDs:    2 active (docs/prds/)

  ddf-creator  (docs/prds/ddf-creator/prd.md, 14 pieces)
    pipeline-infra        planned      (blocked by: none)
    snmp-create-p1        open         (blocked by: pipeline-infra)
    snmp-create-p2        open         (blocked by: snmp-create-p1)
    gw-rampup             open         (blocked by: snmp-create-p2)
    ... (10 more)

  shared  (docs/prds/shared/prd.md, 7 pieces)
    PI-001-marketplace-version-sync    done
    PI-002-version-sync-ci             done
    PI-007-copilot-coship              done
    PI-008-multi-prd-v3.0.0            done
    PI-011-branch-fix                  in-progress  (worktree: worktrees/spec/shared-pi-011-branch-fix/)
    ... (2 more)

Next action: resume /spec-flow:execute shared/PI-011-branch-fix — or run /spec-flow:spec ddf-creator/snmp-create-p1
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
PRDs:    1 active (docs/prds/)

  my-product  (12 pieces)
    PI-012-user-export    in-progress    (worktree: worktrees/spec/my-product-PI-012-user-export/)
                          plan.md present, 4 of 7 phases complete per checkboxes

Next action: resume /spec-flow:execute my-product/PI-012-user-export
```

You know exactly where you left off. `cd worktrees/spec/my-product-PI-012-user-export/` and run `/spec-flow:execute` to pick up from phase 5.

## Where to go next

- [Pipeline concepts](../concepts/pipeline.md)
- Next command in a fresh project: [/spec-flow:charter](./charter.md)
