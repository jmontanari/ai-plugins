# /spec-flow:status

Pipeline dashboard. Shows which pieces are in which stage, what is blocked, and what to work on next.

## What it does

Reads the current state of the project — the charter, the PRD manifests, the worktree branches, the committed specs and plans — and produces a human-readable summary:

- Which pieces are `open`, `specced`, `planned`, `in-progress`, `merged`, `done`, `superseded`, or `blocked`
- Which pieces are blocked by manifest dependencies
- What action is next (run charter? import PRD? spec the next open piece?)
- Any mid-flight state (active worktree overrides the main-branch manifest status; plan exists but execute hasn't started)
- Charter divergence flags on pieces whose `charter_snapshot:` predates the live charter

It doesn't modify any files. It's a pure query.

## Invocation forms

- `/spec-flow:status` — all-PRDs default view (archived PRDs hidden).
- `/spec-flow:status --include-archived` (or `-a`) — include PRDs whose front-matter has `status: archived`.
- `/spec-flow:status <prd-slug>` — drill-in mode: piece-by-piece detail for one PRD.
- `/spec-flow:status --resolve <piece-slug>` — walk through charter-divergence resolution for one piece (re-spec / re-plan / accept).
- `/spec-flow:status --include-drift` — citation-drift deep scan (verifies every cited NN-C/NN-P/CR ID still exists in the charter).

## When to run it

- **Starting a fresh project:** you'll see "no charter yet." Start there.
- **Resuming after a break:** run it first. It tells you where the pipeline left off.
- **Any time you're unsure what to work on:** the answer is here.

Run it *before* charter, before PRD, before spec, before anything. It's designed to orient you from zero context.

## The flow

1. Scans active worktrees first (`git worktree list`); a live `piece/<prd-slug>-<piece-slug>` worktree is authoritative for that piece and overrides the main-branch manifest.
2. Scans the charter root — globs `charter-*/SKILL.md` under both `.claude/skills/` and `.github/skills/` (or honors `charter_root` in `.spec-flow.yaml`, per [reference/charter-location.md](../../../reference/charter-location.md)) — does the charter exist? Is it complete?
3. Scans `docs/prds/` — how many PRD directories exist? For each, reads `prd.md` front-matter (`status: drafting | active | shipped | archived`) and `manifest.yaml`.
4. For each piece in each manifest, checks:
   - Manifest status (`open` / `specced` / `planned` / `in-progress` / `merged` / `done` / `superseded` / `blocked`)
   - Whether a spec / plan / learnings file exists on disk
   - Whether a worktree branch `piece/<prd-slug>-<piece-slug>` exists (legacy `spec/`, `plan/`, `execute/` prefixes are matched for back-compat)
   - Whether the piece's declared dependencies are `merged`/`done`
   - Charter divergence (snapshot vs live charter dates)
5. Produces a table per PRD and a "next action" recommendation.

## Loops

None. This command has no QA loop, no brainstorming, no iteration. It queries and exits.

## What you get

A dashboard printed to the session. Example output shape for a project with two active PRDs:

```
Charter: present (.github/skills/, 7 files)   # or .claude/skills/ — whichever charter_root resolves to
PRDs:    2 active (docs/prds/)

  ddf-creator  (docs/prds/ddf-creator/prd.md, 14 pieces)
    pipeline-infra        planned      (blocked by: none)
    snmp-create-p1        open         (blocked by: pipeline-infra)
    snmp-create-p2        open         (blocked by: snmp-create-p1)
    gw-rampup             open         (blocked by: snmp-create-p2)
    ... (10 more)

  shared  (docs/prds/shared/prd.md, 7 pieces)
    PI-001-marketplace-version-sync    merged
    PI-002-version-sync-ci             merged
    PI-007-copilot-coship              merged
    PI-008-multi-prd-v3.0.0            merged
    PI-011-branch-fix                  in-progress  (worktree: worktrees/prd-shared/piece-PI-011-branch-fix/)
    ... (2 more)

Next action: resume /spec-flow:execute shared/PI-011-branch-fix — or run /spec-flow:spec ddf-creator/snmp-create-p1
```

No files are written or modified.

## Handoff

Whatever the "Next action" line says — typically one of:

- `/spec-flow:charter` (bootstrap or update)
- `/spec-flow:prd` (import or amend the PRD)
- `/spec-flow:spec <prd-slug>/<piece-slug>` (author a spec for an open piece)
- `/spec-flow:plan` (plan a specced piece, once inside the piece's worktree)
- `/spec-flow:execute` (execute a planned piece, once inside the piece's worktree)

## Worked example

You haven't touched the project in two weeks. You run `/spec-flow:status`:

```
Charter: present
PRDs:    1 active (docs/prds/)

  my-product  (12 pieces)
    PI-012-user-export    in-progress    (worktree: worktrees/prd-my-product/piece-PI-012-user-export/)
                          plan.md present, 4 of 7 phases complete per checkboxes

Next action: resume /spec-flow:execute my-product/PI-012-user-export
```

You know exactly where you left off. `cd worktrees/prd-my-product/piece-PI-012-user-export/` and run `/spec-flow:execute` to pick up from phase 5.

## Drill-in and divergence resolution

- `/spec-flow:status <prd-slug>` narrows to one PRD and lists every piece with its pipeline stage, branch, current phase, and drift flags.
- When a piece is flagged as diverged (charter changed since its snapshot), `/spec-flow:status --resolve <piece>` walks each diverged charter file and offers three options per file: **re-spec** (update Non-Negotiables/Coding-Rules Honored), **re-plan** (re-allocate per-phase charter slots), or **accept** (document why the change doesn't apply). Status only surfaces drift — it never dispatches the drift QA agent itself.
- If `docs/prds/` has no PRDs, status prints a single line pointing you at `/spec-flow:prd <slug>` to create the first PRD.

## Where to go next

- [Pipeline concepts](../concepts/pipeline.md)
- Next command in a fresh project: [/spec-flow:charter](./charter.md)
