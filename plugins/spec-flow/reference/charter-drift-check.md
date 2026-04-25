# Charter drift check (Phase-1 procedure)

This document specifies the charter-drift check that every spec-flow skill touching a piece runs as part of its Phase-1 setup. The check compares the piece spec's `charter_snapshot:` values against the current `last_updated:` values in `docs/charter/*.md`. When any charter file has advanced past the snapshot, the skill dispatches `qa-spec` in `Input Mode: Focused charter re-review` and either auto-advances the snapshot (clean) or halts the skill (must-fix). There is no escape hatch.

## When to run

Every skill that touches a piece runs this in Phase 1:

- **`/spec-flow:spec`** — when re-running on an existing piece (drift may have accumulated since the original spec).
- **`/spec-flow:plan`** — before producing the implementation plan.
- **`/spec-flow:execute`** — before starting Phase 1 of execution.
- **`/spec-flow:prd`** — in update mode on active pieces.

`/spec-flow:status` surfaces drift status passively (read-only): it lists pieces with detected drift but does not dispatch the re-review or modify any spec.

## Algorithm

The 7-step algorithm (verbatim from spec.md lines 305-313):

1. Load `docs/charter/*.md` front-matter `last_updated:` values into `charter_now`.
2. Load piece spec's `charter_snapshot:` values into `snapshot`.
3. For each charter file where `charter_now[file] > snapshot[file]`: mark drifted.
4. If any drifted: dispatch `qa-spec` with `Input Mode: Focused charter re-review`, passing the full self-contained input bundle from FR-009 (full spec body, drifted charter file bodies, snapshot values, manifest entry, PRD's NN-P section, spec's NN/CR honoring blocks).
5. Agent returns either `clean` or `must-fix`.
6. If clean: orchestrator rewrites the spec's `charter_snapshot:` values to `charter_now` and appends a log line inside the spec body.
7. If must-fix: orchestrator halts the current skill and prints the findings. The only forward path is amending the spec to honor the new charter (or, explicitly out of band, reverting the charter change). There is no escape hatch to accept the violation — drift findings are blocking.

No new agent file is needed: `qa-spec` gains a third `Input Mode` alongside `Full` and `Focused re-review`.

## Missing-field handling (algorithm extension)

The 7-step algorithm above assumes `charter_now[file]` and `snapshot[file]` both exist for every charter file. In practice they may not. Handle these states explicitly:

- **Charter file missing `last_updated:` front-matter.** Refuse the drift check — print `charter file <name> has no last_updated: front-matter; drift cannot be detected. Add the field (or run /spec-flow:charter retrofit) and re-run.` Do not silently treat the missing date as "infinitely old" or "infinitely new."
- **Spec has no `charter_snapshot:` block at all (legacy pre-charter piece).** Skip the drift check silently and emit a one-line note in the caller's output: `drift check skipped — spec predates charter_snapshot.` This is consistent with `/spec-flow:status`'s passive surfacing rule.
- **New charter file (in `charter_now`, not in `snapshot`).** Mark drifted. The piece's spec must be re-reviewed against the new file in case it added a new NN-C/NN-P/CR entry.
- **Removed/renamed charter file (in `snapshot`, not in `charter_now`).** Mark drifted. The piece's spec may cite an entry that no longer exists; re-review surfaces orphaned citations.
- **Both present, malformed `last_updated:` value (not a parseable date).** Refuse the drift check — print `charter file <name> has malformed last_updated: <value>; expected ISO 8601 (YYYY-MM-DD). Fix and re-run.`

These extensions ensure a new charter file with a NN-C/NN-P/CR entry the spec violates is never silently ignored.

## Drift dispatch contract

When step 4 fires, the skill dispatches `qa-spec` with the full self-contained input bundle required by NN-C-008 (verbatim from FR-009, items (a)-(f)):

(a) the full body of the piece's `spec.md`,
(b) the full body of every charter file whose `last_updated:` advanced past the snapshot,
(c) the piece's previous `charter_snapshot:` values for those files,
(d) the piece's manifest entry (so the agent sees `prd_sections` and dependencies),
(e) the PRD's `## Non-Negotiables (Product)` section (so the agent can cross-check NN-P drift),
(f) the spec's existing `### Non-Negotiables Honored` and `### Coding Rules Honored` blocks (so the agent can detect a newly-added NN-C/NN-P/CR entry that the spec violates and confirm the citation list is still complete).

The agent must be able to detect both compliance violations against existing entries and newly-added NN-C/NN-P/CR entries that the spec does not yet honor. No escape hatch — drift findings are blocking; only forward path is amend the spec or revert the charter change.

## Auto-advance log line format

When `qa-spec` returns `clean` (step 6), the orchestrator rewrites the piece spec's `charter_snapshot:` values to `charter_now` and appends a single log line inside the spec body in the form:

```
charter_snapshot updated YYYY-MM-DD — no content changes required
```

The date is the calendar date of the auto-advance, not the charter file's `last_updated:`. The log line accumulates over the lifetime of the spec — successive clean re-reviews append additional lines rather than overwriting prior entries — so the spec's history is auditable.

## Caller responsibilities

The skill running the Phase-1 check is responsible for:

- **Detecting drift** by loading and comparing `charter_now` and `snapshot` (algorithm steps 1-3).
- **Dispatching `qa-spec`** with `Input Mode: Focused charter re-review` and the full FR-009 input bundle (step 4). The bundle must be self-contained per NN-C-008 — the agent cannot re-read the filesystem.
- **Applying the snapshot rewrite** when the agent returns `clean` (step 6): rewrite the spec's `charter_snapshot:` mapping and append the auto-advance log line.
- **Halting and surfacing findings** when the agent returns `must-fix` (step 7): print the agent's findings and stop the current skill. Do not continue past Phase 1 until the user amends the spec or explicitly reverts the charter change out of band.

## See also

- [plugins/spec-flow/reference/slug-validator.md](slug-validator.md) — slug rules, branch length budget, refusal contract.
- [plugins/spec-flow/reference/v3-path-conventions.md](v3-path-conventions.md) — full v3 layout, path resolution table, and layout version detection.
