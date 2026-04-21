---
name: charter
description: Use when bootstrapping a new spec-flow project's architectural foundation — producing binding project-wide constraints (architecture, non-negotiables, tools, processes, flows, coding rules) via Socratic dialogue. Also handles updating charter files later (update mode) and migrating existing pre-charter projects (retrofit mode). Use whenever the user mentions "set up the charter", "define architecture rules", "establish non-negotiables", "onboard project foundation", or runs `/spec-flow:charter` directly. Runs before `prd` in the pipeline — charter binds every subsequent PRD, spec, plan, and implementation.
---

# Charter — Project-Wide Binding Constraints

Produce a codified, binding set of project-wide constraints in `docs/charter/` via Socratic dialogue. Charter content is referenced by every downstream skill (`prd`, `spec`, `plan`, `execute`) and binds every implementation.

## Step 0: Load Config

Read `.spec-flow.yaml` from the project root. Use `docs_root` in place of `docs/` for all paths below. If the file is missing, default to `docs`.

Charter-specific config keys (added in piece 2 — safe defaults if absent):
- `charter.required` — default `false` in piece 1; piece 2 changes default to `true`
- `charter.doctrine_load` — default `[non-negotiables, architecture]` when absent; piece 2 wires doctrine

## Modes

Detected from current state:

- **Bootstrap mode** — `docs/charter/` does not exist. Full Socratic flow → write six files → QA → sign-off.
- **Update mode** (v2.0.0 piece 5) — `docs/charter/` exists and no legacy signals. User wants to change a charter file.
- **Retrofit mode** (piece 6) — legacy `docs/prd.md` or unprefixed `NN-xxx` detected in existing PRD. Reclassify + migrate. Not implemented until piece 6.

Explicit mode flags (optional): `/spec-flow:charter --update`, `/spec-flow:charter --retrofit`. Without flags, mode is auto-detected.

If retrofit signals detected (legacy layout or unprefixed NN-xxx) and piece 6 isn't shipped yet, respond: `"Retrofit mode lands in v2.0.0 piece 6. To update existing charter files in the meantime, run /spec-flow:charter --update."`

## Bootstrap Mode Workflow

### Phase 1.1: Auto-detect signals

Read the following if present, as priors for Socratic questions:

- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`
- Build manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`
- TS/lint configs: `tsconfig.json`, `.eslintrc*`, `.ruff.toml`, `.prettierrc*`
- CI: `.github/workflows/*`, `.pre-commit-config.yaml`
- Existing `docs/architecture/` or `docs/adr/`
- Recent `git log --oneline -n 50`

Synthesize into a signal summary (internal — not yet shown to user).

### Phase 1.2: Prompt user for additional sources

Ask:

> "Any other places I should look? This can include:
> - **Local paths** — folders or files in this repo I wouldn't auto-detect (e.g., `internal/handbook/`, `docs/rfcs/`, `.devcontainer/`)
> - **External URLs** — team wikis, Notion pages, Confluence spaces, engineering handbooks, design docs, RFCs, style guides
> - **Sibling repos** — shared convention repos (user provides local path to a cloned working copy)
>
> Paste paths/links, or say 'none'."

For each source:
- **Local paths:** read with `Read`/`Glob`/`Grep`. Fold content into signal summary.
- **External URLs:** attempt `WebFetch`. On success, summarize into signals. On failure (auth-walled, offline, rate-limited), record as pending reference and inform user: *"Couldn't fetch `<url>`; treating as unverified reference. You'll need to summarize what it binds us to during Socratic."*
- **Sibling repos:** treat provided local path as a local-path source.

### Phase 1.3: Confirm combined signal summary

Present the union of auto-detected + user-supplied signals:

> "Here's what I've gathered:
> - [language] [version] / [framework] / [test runner] / [CI]
> - [detected architecture patterns]
> - [external references the user provided]
>
> Does this look right? Anything to add or correct?"

Only proceed to Phase 2 after user confirms.

### Phase 2: Socratic by file, one question at a time

Authoritative order (earlier files seed context for later ones):

1. `tools.md` — language/runtime, framework(s), test runner + coverage, linter + formatter, package manager, CI platform, approved/banned libraries
2. `architecture.md` — top-level layers, dependency direction, component ownership, boundaries
3. `flows.md` — request flow, auth flow, data-write path, other critical end-to-end flows
4. `coding-rules.md` — numbered `CR-xxx` entries, each tagged `Type: Rule` (inline) or `Type: Reference` (external Source)
5. `processes.md` — branching model, review policy, release cadence, CI gates, incident response
6. `non-negotiables.md` — numbered `NN-C-xxx` entries, structured schema (Type, Scope, Rationale, How QA verifies)

Rules:
- One question at a time. Multiple choice preferred.
- Use detection signals + user-supplied sources as priors. Don't ask questions whose answers were already captured.
- Any unresolved answer becomes a `[NEEDS CLARIFICATION]` marker in the draft. QA treats these as must-fix.
- For numbered entries, confirm `Type` explicitly: "Is this a **Rule** (inline body) or a **Reference** (link to external source)?"

### Phase 3: Write files

Load templates from `${CLAUDE_PLUGIN_ROOT}/templates/charter/`. Populate placeholders from Socratic answers. Write to `<docs_root>/charter/` (default `docs/charter/`). Each file gets front-matter:

```yaml
---
last_updated: YYYY-MM-DD   # today's date in ISO format
---
```

Charter files live on `main` (not a worktree — charter is project-global, not piece-scoped).

### Phase 4: QA loop

Read the agent template: `${CLAUDE_PLUGIN_ROOT}/agents/qa-charter.md`.

**Iteration 1 (full review):** Compose prompt with `Input Mode: Full` — interpolate all six charter files, detection signal summary, user-supplied source list. Dispatch:

```
Agent({
  description: "Charter QA (iter 1, full)",
  prompt: <composed>,
  model: "opus"
})
```

**Iterations 2+ (focused re-review):** If iteration M-1 returned must-fix findings:

1. Read the fix template: `${CLAUDE_PLUGIN_ROOT}/agents/fix-doc.md` (existing agent — no `fix-charter` exists).
2. Dispatch fix-doc with prior findings + charter files + context. The fix agent does NOT commit; it ends its report with `## Diff of changes` containing its `git diff` of the charter files.
3. Extract that diff string. Hold it in orchestrator state as `charter_iter_M_fix_diff`.
4. Re-dispatch `qa-charter` with `Input Mode: Focused re-review`, prior iteration's must-fix findings, and `charter_iter_M_fix_diff`. Do NOT re-send the full charter.
5. **Circuit breaker:** after 3 QA iterations, escalate to human.
6. If fix-doc returns `Diff of changes: (none)` (all blocked), escalate.

**Clean iteration → Phase 5.**

### Phase 5: Human sign-off

Present the six charter files to the user for review. User approves → continue. User requests changes → make them (back to Phase 2 or 3 scoped to the requested change) → back to Phase 4 QA.

### Phase 6: Commit per file

One commit per file so `git blame` is useful:

```bash
git add <docs_root>/charter/architecture.md && git commit -m "charter: add architecture"
git add <docs_root>/charter/tools.md && git commit -m "charter: add tools"
git add <docs_root>/charter/flows.md && git commit -m "charter: add flows"
git add <docs_root>/charter/coding-rules.md && git commit -m "charter: add coding-rules"
git add <docs_root>/charter/processes.md && git commit -m "charter: add processes"
git add <docs_root>/charter/non-negotiables.md && git commit -m "charter: add non-negotiables"
```

### Phase 7: Doctrine wiring reminder

Since v2.0.0 piece 2, the SessionStart hook auto-loads charter files listed in `.spec-flow.yaml`'s `charter.doctrine_load` (default `[non-negotiables, architecture]`). Users need to run `/reload-plugins` (or start a new session) to pick up newly-authored charter into agent doctrine context.

Inform the user after Phase 6:
> "Charter files committed. Run `/reload-plugins` (or start a new session) so downstream skills and agents pick up the charter via SessionStart doctrine load. Future runs of `prd`, `spec`, `plan`, `execute`, and `status` will read from these files automatically."

## Update Mode Workflow (v2.0.0 piece 5)

Triggered when `docs/charter/` exists and no legacy signals are detected. Purpose: edit one or more charter files with the same Socratic+QA rigor as bootstrap, but scoped to only the touched files.

### Phase U1 — Ask which file(s) to edit

Present the six files with their current `last_updated` dates:

```
docs/charter/
  architecture.md        last_updated: 2026-02-15
  non-negotiables.md     last_updated: 2026-03-20
  tools.md               last_updated: 2026-02-15
  processes.md           last_updated: 2026-02-15
  flows.md               last_updated: 2026-02-15
  coding-rules.md        last_updated: 2026-04-01
```

Ask: "Which file(s) do you want to change? (comma-separated, or 'all')."

### Phase U2 — Scoped Socratic per selected file

For each selected file, run a Socratic flow scoped to that file's subject area (reuse the bootstrap Phase 2 question set for just that file). The skill proposes edits based on user answers — adds, modifications, or retirements.

**Retirement handling:** If the user wants to remove an `NN-C-xxx` or `CR-xxx` entry, ask:

> "Retire this entry (keep as tombstone in file for historical traceability — recommended) or delete entirely (removes all trace)? Retire is safer — pieces that previously cited this ID will have their citations flagged by QA, giving you a chance to upgrade them. Delete breaks that trail."

Default is **retire**. Retired entries get the tombstone format (strikethrough title + `RETIRED YYYY-MM-DD` marker + reason + list of pieces that cited them).

**Add handling:** New NN-C or CR entries get the next sequential unused ID (continuing past retired IDs — never reuse).

**Modify handling:** Keep the same ID, replace the body, bump `last_updated`.

### Phase U3 — Write and front-matter bump

Write each touched file to `<docs_root>/charter/<name>.md`. Update `last_updated: YYYY-MM-DD` in front-matter to today's date.

### Phase U4 — QA on touched files only

Dispatch `qa-charter` with `Input Mode: Full`, but pass only the touched files in the prompt (not all six). The agent's cross-file consistency checks still run — it will refer to non-touched files if the orchestrator attaches them as read-only context, but only findings on touched files are must-fix (non-touched-file drift is a different update run).

Iteration loop is the same as bootstrap mode's Phase 4 (fix-doc diff, focused re-review, 3-iter circuit breaker).

### Phase U5 — Sign-off and per-file commit

Human reviews diffs. On approval, commit each touched file separately:

```bash
git add <docs_root>/charter/<file>.md && git commit -m "charter: update <file> — <brief summary>"
```

### Phase U6 — Divergence awareness

After commit, check the manifest for pieces at `specced`, `planned`, or `implementing` status. For any piece whose `charter_snapshot` on any touched file is older than the new `last_updated`, inform the user:

> "The following pieces are now diverged: [list]. Run `/spec-flow:status --resolve <piece-name>` to walk through divergence resolution options."

Do NOT automatically re-spec or re-plan — human decides per piece.

## Retrofit Mode Workflow

Deferred to v2.0.0 piece 6. See piece 6 plan.

## No QA Gate Between Charter Skill and User

User is directly involved throughout Socratic. The `qa-charter` agent is the only automated review.
