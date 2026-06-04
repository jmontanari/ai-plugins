# /spec-flow:defer

Record a non-blocking finding to a backlog with provenance. The sole supported write path for `improvement-backlog.md` and `prds/<slug>/backlog.md`. Requires `--rationale`.

## What it does

Backlogs rot when entries arrive without context — who found this, when, and why doesn't it block? `defer` exists so every backlog entry carries provenance: the piece that surfaced the finding, the phase, the agent, and the operator's explicit rationale for why it doesn't block the current piece's goals.

It is a thin orchestrator: it parses arguments, formats one entry, appends it under the target file's `## Recent findings` section, and commits. It dispatches no subagents and writes exactly one backlog file per invocation.

It refuses if the rationale is missing. Silent backlog writes (the old v3.1.x pattern) are no longer supported — every entry must answer "why does this not block this piece's goals?" in the operator's own words.

## When to run it

Two forms:

- **Manually** — you want to capture a finding outside any active triage flow: "defer", "log to backlog", "record this finding".
- **Structured** — the orchestrator calls it after you choose `defer` in `execute`'s discovery-triage prompt, or `small-change`'s deferred-item disposition routes a dropped item here.

Either way, this is the *only* path that should touch a backlog file. Nothing else writes to them.

## The flow

1. **Parse arguments / context block** — detects manual vs. structured form.
2. **Refuse if rationale missing** (manual form) — emits the refusal string and exits without writing.
3. **Resolve the target backlog file** — `--global` (or `target=global`) writes to `<docs_root>/improvement-backlog.md`; otherwise the active piece's `<docs_root>/prds/<prd-slug>/backlog.md`. The active piece is resolved from `--source-piece`, or by reverse-lookup of the current worktree against the manifests.
4. **Format the entry** — both date fields resolve from a single `date +%F`.
5. **Operator confirmation** (manual form only) — reads the entry back and asks `(y/n)`. Structured invocations skip this — you already chose `defer` upstream.
6. **Append** under `## Recent findings` (creating the section if absent).
7. **Append a discovery-log row** (structured invocations only) to the piece's `.discovery-log.md`.
8. **Commit** on the active worktree branch (`chore(<piece-slug>): defer <finding-summary>`).
9. **Report** the modified file(s) and the commit SHA.

## Loops

None. It records one entry and exits.

## Arguments

Manual form:

```
/spec-flow:defer "<finding>" --rationale "<text>" [--global] [--source-piece <slug>] [--source-phase <id>]
```

- `<finding>` (required) — one-line finding summary.
- `--rationale "<text>"` (required) — why it doesn't block the current piece. Missing or empty → refusal.
- `--global` — write to the project-wide `improvement-backlog.md` instead of the per-piece backlog.
- `--source-piece` — bare or qualified slug; omitted, it's resolved from the worktree.
- `--source-phase` — phase id; omitted, recorded as the literal `manual`.

## The entry format

Every invocation appends one entry with six required fields:

```markdown
### [Deferred via /spec-flow:defer] <finding-summary> — YYYY-MM-DD

**Source:** `<prd-slug>/<piece-slug>` phase `<phase-id>` (agent: `<agent-name>`)
**Finding (verbatim):** <finding-text>
**Why this does not block <piece-slug>'s goals:** <operator-rationale>
**Captured:** YYYY-MM-DD
```

The `**Source:**` line always uses the qualified `<prd-slug>/<piece-slug>` form regardless of which backlog file the entry lands in — provenance shape is invariant; only the target path differs.

## Refusals

The skill emits one of these and exits without writing:

- **Missing rationale:** `REFUSED — defer requires --rationale; explain why this finding does not block the current piece's goals.`
- **Unresolved active piece** (manual form, no `--source-piece`, and reverse-lookup found nothing): `Refused — no active piece detected; pass --source-piece explicitly or invoke from within a piece worktree.`

## What you get

- One entry appended under `## Recent findings` in exactly one backlog file.
- For structured invocations, a matching row in the piece's `.discovery-log.md` audit trail.
- A single commit on the active worktree branch capturing the change.
- A one-line success report with the path(s) and the commit SHA.

## Worked example

Mid-execute, the QA reviewer flags a pre-existing inefficiency unrelated to the current piece. You don't want to scope-creep, but you don't want to lose it:

```
/spec-flow:defer "N+1 query in the legacy report exporter" \
  --rationale "Pre-existing, outside this piece's auth scope; perf, not correctness; safe to batch later."

Append this entry to docs/prds/my-product/backlog.md and commit? (y/n)
> y

Wrote docs/prds/my-product/backlog.md
Commit: a1b9f3c  chore(PI-012-user-export): defer N+1 query in the legacy report exporter
```

The finding is captured with full provenance, and the current piece stays focused.

## Where to go next

- [/spec-flow:execute](./execute.md) — its discovery triage routes findings here structurally.
- [/spec-flow:small-change](./small-change.md) — its deferred-item disposition can also defer here.
- [QA loop concepts](../concepts/qa-loop.md) — how must-fix vs. defer gets decided.
