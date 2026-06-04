# /spec-flow:review-board

Run the end-of-piece Final Review board on any target, out of band. Points the same adversarial reviewers at a PR, a branch, working-tree changes, or files — decoupled from the merge gate.

## What it does

The board that `execute` runs before merge is the strongest gate in spec-flow. `review-board` lets you point it at anything, any time, without running the pipeline. It reuses the existing review-board agents — it adds no new reviewers — minus all the pipeline machinery: **no merge, no plan/spec amendment, no fork, no backlog write, no human sign-off gate.**

It reviews, reports findings by severity, and (only if you ask) routes them into `/spec-flow:small-change` so any fix gets the full TDD/QA/board discipline. It never patches code itself.

This skill is standalone — it does not require an active piece, a manifest, or even a spec-flow project layout. It only needs a git repository to compute a diff.

## When to run it

- "Run the review board", "board-review this", "adversarial review of this PR/branch/diff", "review these changes", "what would the review board say".
- You want the merge-gate-quality review without running `execute`.
- Pre-merge sanity on a PR, a feature branch, your working tree, or a specific set of files.

## The flow

1. **Load config** (best-effort) — reads `.spec-flow.yaml` for `docs_root` if present; confirms you're inside a git repo (else it stops).
2. **Resolve the target → a diff + file set:**
   - All digits (`412`) → a PR number (`gh pr diff`).
   - A ref/branch name → diff against the merge-base with the default branch.
   - One or more paths → their uncommitted/branch changes, or — if unchanged — the full file contents reviewed as existing code.
   - Blank → working-tree changes (`git diff HEAD`), falling back to `default-branch..HEAD`.
3. **Resolve context and select lenses.**
4. **Dispatch the board** — all selected lenses run concurrently, each a fresh Opus agent that sees only its prompt.
5. **Collect, dedupe, classify, report** — by severity.
6. **`--fix`** (optional) — route findings into `/spec-flow:small-change`.
7. **`--comment`** (optional) — post inline PR comments.

## The lenses

**Default set (no spec/PRD needed):** `blind`, `edge-case`, `security`, `ground-truth`, `architecture`.

- `architecture` runs by default — layering and dependency-direction judgments apply to almost any code; it uses your charter if present, else general principles.
- `ground-truth` always runs — its oracle/correctness lens catches defects that survive functional tests.

**Context-bound lenses — added only when their input is available:**

- `spec-compliance` — when `--spec PATH` is given, or a spec is discoverable for the target.
- `prd-alignment` — when `--prd PATH` is given, or a PRD + manifest are discoverable.

So a bare run uses 5 lenses; with a spec and PRD supplied, all 7. The resolved lens set and the reason each context-bound lens was included or skipped is logged — no silent omissions.

**Overrides:** `--lenses a,b,c` runs exactly that set; `--spec PATH` / `--prd PATH` force-include the corresponding lens.

## Loops

None. It dispatches the board once, consolidates, and reports. (Iterative fix-and-re-review happens downstream in `execute`, if you route findings there with `--fix`.)

## What you get

A consolidated report, deduped across lenses, with each finding classified `must-fix` / `should-fix` / `defer` / `dismiss`:

```
## Review Board — PR #412

Lenses run: blind, edge-case, security, ground-truth, architecture
Files reviewed: 6   |   Findings: 2 must-fix, 3 should-fix, 1 deferred/dismissed

### Must-fix
- [security] api/export.py:88 — unparameterized query on `filter` param  →  use bound params
- [ground-truth] api/export.py:140 — CSV writer drops the final row on odd counts  →  fix loop bound

### Should-fix
- [edge-case] api/export.py:54 — no guard for empty result set  →  return 204
...

### Per-lens summary
| Lens | Verdict | Findings |
|------|---------|----------|
| blind | clean | 0 |
| security | concerns | 1 |
...
```

No code is modified unless you pass `--fix` or `--comment`.

## Flags

- **`--fix`** — does not patch the tree. It compiles a findings digest (marked `source: review-board`) and hands it to `/spec-flow:small-change`, which writes a `brief.md` + `plan.md` and creates a `change/<slug>` worktree. The fix is then built, QA-gated, and re-reviewed by the change-track board when you run `execute` separately. An ownership check applies — it won't push onto a third-party PR's branch; for those, use `--comment`.
- **`--comment`** — when the target is a PR, posts each `file:line` finding as an inline review comment via `gh`, with off-diff findings collected into one summary comment, and echoes back the posted URLs. Warns and skips if the target isn't a PR.

## What it never does

No merge. No pipeline mutation (never amends a plan/spec, forks, writes the backlog, or touches a manifest). No sign-off gate — findings are advisory. No direct code edits.

## Worked example

A teammate's PR is up and you want the board's read before approving:

```
/spec-flow:review-board 412 --comment

Resolved target: PR #412 (head: feat/csv-export, base: master)
Lenses: blind, edge-case, security, ground-truth, architecture
  (spec-compliance skipped — no spec discoverable; prd-alignment skipped — no PRD)

Dispatching 5 reviewers (parallel, opus)...

Findings: 2 must-fix, 3 should-fix.
Posted 4 inline comments + 1 summary comment to PR #412:
  https://github.com/org/repo/pull/412#discussion_r...
```

You drop the must-fix comments on the PR; the author fixes them on their own branch.

## Where to go next

- [/spec-flow:execute](./execute.md) — the pipeline-integrated board with merge gating and discovery triage.
- [/spec-flow:small-change](./small-change.md) — where `--fix` findings are remediated.
- [QA loop concepts](../concepts/qa-loop.md) — how findings get classified and resolved.
