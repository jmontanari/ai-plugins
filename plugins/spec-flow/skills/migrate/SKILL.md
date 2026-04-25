---
name: migrate
description: Use when migrating an existing spec-flow project from v1.x or v2.x layout to v3.0.0 multi-PRD layout. Performs git-mv-based history-preserving moves of docs/prd/ → docs/prds/<slug>/, docs/specs/ → docs/prds/<slug>/specs/, injects v3 front-matter, updates .spec-flow.yaml to layout_version: 3, and writes MIGRATION_NOTES.md. Supports --inspect (dry-run) and --force (override safety checks). Refuses on missing charter, dirty tree, or sibling worktrees by default.
---

# Migrate — v1.x / v2.x → v3.0.0 Multi-PRD Layout

Migrate an existing spec-flow project's documentation tree from the legacy single-PRD layout (v1.x, v2.x) to the v3.0.0 multi-PRD layout (`docs/prds/<slug>/...`), preserving git history via `git mv`.

This skill is a thin orchestrator (CR-008): it inspects the filesystem, prints a dry-run plan, runs `git mv` and small file edits, and writes `MIGRATION_NOTES.md`. It does **not** dispatch subagents and introduces no runtime code dependencies (NN-C-002).

---

## Step 0: Parse arguments

The skill accepts an optional PRD-slug positional argument and two optional flags:

- `--inspect` — print the dry-run plan and exit 0 without prompting and without making any changes (AC-19).
- `--force` — override the dirty-tree and sibling-worktree safety checks (AC-13). Does **not** override v0/v3 detection or the charter prerequisite.

Examples:

```
/spec-flow:migrate                          # auto-derive slug, prompt to confirm
/spec-flow:migrate auth-revamp              # use given slug
/spec-flow:migrate --inspect                # dry-run only
/spec-flow:migrate auth-revamp --force      # override safety checks
```

Capture: `slug_arg` (string or null), `inspect` (bool), `force` (bool).

---

## Step 1: Detect source layout

Inspect the filesystem in the current repo root.

### 1a. Ambiguous-state pre-check (run BEFORE version classification)

Before classifying as v0/v1/v2/v3, refuse on any of these mixed states. These checks fire first because the version dispatch below uses single-marker rules and would mis-classify a half-migrated tree as a clean version.

- Both `docs/prd/` AND `docs/prds/` exist → refuse with:
  > ambiguous layout — both v2 and v3 directories present. Manually consolidate before re-running migrate.
- Both `docs/prd.md` AND `docs/prd/prd.md` exist → refuse with:
  > ambiguous layout — both v1 and v2 PRD files present. Remove the stale one before re-running migrate.
- `docs/prd/prd.md` exists without `docs/prd/manifest.yaml` → refuse with:
  > partial v2 layout — manifest missing. Restore the manifest or revert to v1.
- `docs/manifest.yaml` exists without `docs/prd.md` (and without `docs/prd/prd.md`) → refuse with:
  > orphan manifest — no PRD file. Restore the PRD or remove the manifest before re-running migrate.

None of these refusals are overrideable by `--force` — they signal a tree state the skill cannot safely reason about.

### 1b. Version classification

| Marker | Layout |
|--------|--------|
| `docs/prd.md` exists, no `docs/manifest.yaml` | **v0** (pre-charter) |
| `docs/prd.md` + `docs/manifest.yaml` | **v1** |
| `docs/prd/prd.md` + `docs/prd/manifest.yaml` | **v2** |
| `docs/prds/` exists | **v3** |

(If `docs_root` in `.spec-flow.yaml` is set to something other than `docs`, substitute it in every path above and below.)

Refusal contract:

- **v0 detected:** exit non-zero with message:
  > Pre-charter project detected — please run `/spec-flow:charter` retrofit mode first to seed a charter and a manifest.
- **v3 detected:** exit non-zero with message:
  > Already on v3.0.0 layout — no migration needed.
- **Neither v1 nor v2 detected** (e.g. no PRD at all): exit non-zero with message:
  > No spec-flow PRD detected at expected paths — run `/spec-flow:prd` first or check that you are at the project root.

Set `src_version` to `v1` or `v2`; carry forward.

---

## Step 2: Gather inputs

Determine the slug:

1. If `slug_arg` was provided, use it.
2. Otherwise derive a default from the existing PRD's title:
   - For v2: read first H1 (or `name:` front-matter key) of `docs/prd/prd.md`.
   - For v1: read first H1 (or `name:` front-matter key) of `docs/prd.md`.
   - Slugify (lowercase, hyphenate, strip non-alphanum-hyphen) and truncate to 10 chars.
3. Prompt: "Use slug `<derived>`? Override or press Enter to confirm:".
   - On Enter: keep derived slug.
   - On override: replace with user-supplied value.

Validate the final slug against `plugins/spec-flow/reference/slug-validator.md`. On validation failure, exit non-zero with the slug-validator's error contract — do not retry silently.

Whichever path produced the slug (argument, derivation, or interactive override), the final slug MUST pass the slug-validator before Step 3 begins. Re-validate on every path. Refuse with the validator's error contract on any failure — no auto-fix, no second-chance prompt, no shell interpolation prior to validation.

Carry forward: `slug`.

---

## Step 3: Safety checks

All three checks below run in order; the first failure exits non-zero.

### 3a. Charter prerequisite (FR-017)

If `docs/charter/` is absent, refuse with:

> Charter is a v3 prerequisite. Please run `/spec-flow:charter` (retrofit mode if pre-charter project) first.

Migration **never** auto-creates a charter — this is a deliberate scope boundary so retrofit dialogue stays in the `charter` skill. Not overrideable by `--force`.

### 3b. Dirty working tree (AC-13)

Run `git status --porcelain`. If output is non-empty:

- Without `--force`: refuse with
  > working tree dirty — commit or stash first
- With `--force`: print warning ("proceeding with dirty tree under --force") and continue.

Note: the dirty-tree refusal exists specifically because Step 8 stages by literal path (never `git add -A`). Bypassing with `--force` may leave pre-existing user changes uncommitted in the working tree (deliberate — the user asked for `--force` so they accept this responsibility), but it does NOT enable `git add -A` to inhale unrelated content into the migration commit. Step 8 stays explicit-path under all conditions.

### 3c. Sibling worktrees (AC-13)

First, read `worktrees_root` from `.spec-flow.yaml` using the same parser pattern this skill uses elsewhere (grep + sed):

```bash
worktrees_root=$(grep -E '^worktrees_root:' .spec-flow.yaml 2>/dev/null | sed -E 's/^worktrees_root:[[:space:]]*//; s/[[:space:]]*$//' | tr -d '"' | tr -d "'")
worktrees_root="${worktrees_root:-worktrees}"
```

Then run `git worktree list --porcelain`. Parse `worktree` entries. If any entry's path is under the configured `<worktrees_root>/` directory at the repo root **and** is not the current session's own working directory:

- Without `--force`: refuse with
  > in-flight worktree present under `<worktrees_root>/` — abort or `--force`
  (Name the configured root in the message so the user can verify the check ran against the right directory.)
- With `--force`: emit a multi-line warning (per NN-C-006 posture) AND record a recovery section in MIGRATION_NOTES.md (Step 7). Warning format — exactly these lines, surrounded by `═══` separators, ≥5 lines of body:

  ```
  ═══════════════════════════════════════════════════════════════════════════
  WARNING — proceeding past sibling-worktree gate under --force
  ═══════════════════════════════════════════════════════════════════════════
  The following in-flight worktrees will have stale `docs/specs/<piece>/`
  paths after this migration completes. They will produce rename/modify
  conflicts at merge time unless rebased or abandoned:

    - <worktree-path-1>  (branch: <branch-1>)
    - <worktree-path-2>  (branch: <branch-2>)
    …

  See `## Recovery — sibling worktrees affected by migration` in
  MIGRATION_NOTES.md for rebase/abandon instructions per worktree.
  ═══════════════════════════════════════════════════════════════════════════
  ```

  Carry forward: `affected_worktrees` (list of `{path, branch}` records) for use in Step 7.

---

## Step 4: Dry-run plan

Print a comprehensive plan to stdout. The plan must enumerate, in order:

1. Every `git mv` command that will run (source → destination, exact strings).
2. Every front-matter mutation: file path + key + old value (or `<absent>`) → new value.
3. Every newly-created file (full path + brief content sketch — backlog from template, MIGRATION_NOTES, etc.).
4. The final commit message: `chore(spec-flow): migrate docs to v3.0.0 multi-PRD layout` (CR-004).

If `inspect` is true, print the plan and exit 0 (AC-19) — no prompt, no execution.

Otherwise prompt:

> Apply this migration? [y/N]

Refuse on any answer other than `y` / `Y` (exit non-zero, no changes made).

---

## Step 5: Execute

Run the moves in order. Stop on first non-zero exit and report which step failed.

### Destination-already-exists guard (both paths)

Before any `git mv`, assert that the destination directory does not already exist. This catches stale state from a prior aborted migration on a different slug that the Step 1a ambiguous-state check did not classify (e.g. `docs/prds/<slug>` populated under a different slug from a previous attempt):

```bash
[ ! -d docs/prds/<slug> ] || refuse_with \
  "destination docs/prds/<slug> already exists; pick a different slug or clean up the stale directory first"
```

This guard is in addition to Step 1a's pre-classification check — it covers the narrow case where the half-migrated state involves a *different* slug than the one currently being requested.

### v2 path (`docs/prd/` + `docs/specs/`)

```
mkdir -p docs/prds
git mv docs/prd docs/prds/<slug>
git mv docs/specs docs/prds/<slug>/specs
```

(`mkdir -p docs/prds` is mandatory: `git mv` requires the parent of the destination to exist. Without this, the move fails with "fatal: destination directory does not exist" and the v2 → v3 migration aborts before any moves are staged.)

### v1 path (`docs/prd.md` + `docs/manifest.yaml` + `docs/specs/`)

```
mkdir -p docs/prds/<slug>
git mv docs/prd.md       docs/prds/<slug>/prd.md
git mv docs/manifest.yaml docs/prds/<slug>/manifest.yaml
git mv docs/specs        docs/prds/<slug>/specs
```

### Both paths — front-matter injection

In `docs/prds/<slug>/prd.md`:

- If a YAML front-matter block (`---` … `---`) exists, parse it. Preserve any existing `name:` line.
- Ensure these keys are present (insert if missing — do not overwrite if already set):
  - `slug: <slug>`
  - `status: active`
  - `version: 1`
- If no front-matter block exists, prepend one containing the four keys (`name:` derived from existing H1 if absent, plus the three above).

### Both paths — backlog seeding

If `docs/prds/<slug>/backlog.md` is absent, copy from `plugins/spec-flow/templates/backlog.md`. Substitute the `<slug>` placeholder if the template contains one; otherwise copy verbatim.

### Both paths — improvement backlog

If `docs/improvement-backlog.md` is absent, create with minimal content:

```markdown
# Improvement backlog
```

### Both paths — `.spec-flow.yaml` layout_version bump

Edit `.spec-flow.yaml` at the repo root:

- If `layout_version:` key exists with value `<3`, replace it with `layout_version: 3`.
- If absent, insert `layout_version: 3` immediately after the `worktrees_root:` line (or at end of file if `worktrees_root:` is absent).
- Preserve all other keys, comments, and ordering.

---

## Step 6: Scan for stale internal references

Grep the following set of unmoved files for legacy path prefixes:

**Files to scan:**
- `README.md` (repo root)
- `CLAUDE.md` (repo root)
- Any other top-level docs (e.g. `CONTRIBUTING.md`, `AGENTS.md`)
- `plugins/*/README.md`

**Patterns to search (literal substrings):**
- `docs/specs/`
- `docs/prd/`
- `docs/prd.md`
- `docs/manifest.yaml`

For each match, capture: `<file>:<line>: <matched text>`. Accumulate into `stale_refs` list.

This is a read-only scan (CR-008 — orchestrator does the grep itself; no agent dispatch). The skill does **not** rewrite these files — manual review only, recorded in `MIGRATION_NOTES.md`.

---

## Step 7: Write `MIGRATION_NOTES.md`

Create `MIGRATION_NOTES.md` at the repo root with this exact structure (AC-14):

```markdown
# Migration notes — v<src_version> → v3.0.0

## Files moved
- <old path> → <new path>
- …

## Stale internal references (manual review)
- <file>:<line>: <matched text>
- …

## What to do next
- Review stale references above; rewrite as needed (no automatic rewrite to keep migration scope minimal).
- Verify `git log --follow docs/prds/<slug>/prd.md` shows pre-migration history.
- Delete this MIGRATION_NOTES.md once you've completed the manual review.
```

If `stale_refs` is empty, render the section as:

```
## Stale internal references (manual review)
- (none detected)
```

### Recovery section — sibling worktrees affected by migration

If Step 3c carried forward a non-empty `affected_worktrees` list (i.e. `--force` was used past the sibling-worktree gate), append this section to `MIGRATION_NOTES.md`:

```markdown
## Recovery — sibling worktrees affected by migration

The following worktrees were in flight when this migration ran. Their
branches reference the legacy `docs/specs/<piece>/` layout and will produce
rename/modify conflicts at merge time. For each, choose one recovery path:

- <worktree-path-1> (branch: <branch-1>)
  - Rebase onto migration: `git checkout <branch-1> && git rebase <migration-sha>` then resolve any rename conflicts (the conflicts will surface as `docs/specs/...` vs `docs/prds/<slug>/specs/...`).
  - Or abandon: `git worktree remove <worktree-path-1> && git branch -D <branch-1>`.

- <worktree-path-2> (branch: <branch-2>)
  - Rebase onto migration: `git checkout <branch-2> && git rebase <migration-sha>` then resolve any rename conflicts.
  - Or abandon: `git worktree remove <worktree-path-2> && git branch -D <branch-2>`.

…
```

Substitute `<migration-sha>` with the SHA of this migration's commit (Step 8). If `affected_worktrees` is empty, omit this section entirely (do not render an empty heading).

---

## Step 8: Commit

Stage only files this migration created or modified — **never** `git add -A`. Under `--force`, a blanket `git add -A` would inhale every untracked or modified file in the working tree (including `.env.local`, credentials, WIP), which is exactly the system-prompt-named anti-pattern. The migration only ever touches a known, finite set of paths, so we stage by literal path.

The `git mv` calls in Step 5 have already staged the `docs/prd → docs/prds` moves and the deletion of the source paths. After Step 5/7 completes, the only NEW unstaged paths are `docs/improvement-backlog.md`, `.spec-flow.yaml` edits, `MIGRATION_NOTES.md`, the (possibly seeded) `docs/prds/<slug>/backlog.md`, and the front-matter-injected `docs/prds/<slug>/prd.md`.

```bash
# Stage only files this migration created or modified (NEVER `git add -A`).
# git mv has already staged the docs/prd → docs/prds moves and deletions.
git add MIGRATION_NOTES.md
git add .spec-flow.yaml
git add docs/improvement-backlog.md 2>/dev/null || true   # may not exist if pre-existing
git add docs/prds/<slug>/backlog.md 2>/dev/null || true   # may not exist if not seeded
git add docs/prds/<slug>/prd.md   # front-matter injection in Step 5 may have edited it

git commit -m "chore(spec-flow): migrate docs to v3.0.0 multi-PRD layout"
```

Commit message scope follows CR-004 (conventional-commits, `spec-flow` scope). Do not bypass hooks.

On success, print:

> Migration complete. Review `MIGRATION_NOTES.md` and run `git log --follow docs/prds/<slug>/prd.md` to verify history is preserved.

---

## Exit codes

| Condition | Exit |
|-----------|------|
| Successful migration | 0 |
| Successful `--inspect` (plan printed, no changes) | 0 |
| v0 detected | non-zero |
| v3 detected (already migrated) | non-zero |
| No PRD detected | non-zero |
| Slug validation failure | non-zero |
| Charter missing | non-zero |
| Dirty tree (without `--force`) | non-zero |
| Sibling worktree (without `--force`) | non-zero |
| User declines plan at prompt | non-zero |
| `git mv` or filesystem operation failed | non-zero |

---

## Constraints honored

- **NN-C-002** — markdown + config only; the skill prescribes `git mv` and YAML edits, no new runtime dependencies.
- **NN-C-006** — no destructive ops without confirmation; dry-run plan precedes any move; refuses on dirty tree / sibling worktrees without `--force`; `--inspect` exits with zero changes.
- **CR-002** — full skill frontmatter (`name`, `description`).
- **CR-004** — commit message uses conventional-commits with `spec-flow` scope.
- **CR-008** — thin orchestrator; no agent dispatch; stale-ref scan done inline.
- **FR-017** — charter prerequisite enforced; migration does not auto-create charter.
