---
name: review-board
description: >-
  Run spec-flow's end-of-piece review board on ANY target, out of band — decoupled from the
  pipeline merge gate. Points the same adversarial reviewers (blind, edge-case, security,
  ground-truth, architecture, and — when a spec/PRD is supplied — spec-compliance, prd-alignment)
  at a PR, a branch, working-tree changes, or a set of files. Use when the user says "run the
  review board", "board-review this", "adversarial review of this PR/branch/diff", "review these
  changes", "what would the review board say", or wants the merge-gate review without running
  execute. Reports consolidated findings by severity; optionally routes findings into the
  small-change flow for disciplined remediation (--fix) and posts inline PR comments (--comment).
  Does NOT patch code directly, merge, amend, fork, or sign off.
argument-hint: "<PR # | branch | path(s) | blank=working tree> [--fix] [--comment] [--lenses a,b,c] [--spec PATH] [--prd PATH]"
---

# Review Board — On-Demand Adversarial Review

Point the spec-flow Final Review board at any target, any time. This skill **reuses the existing review-board agents** at `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<lens>.md` — it adds no new reviewers. It is the out-of-band sibling of the merge-gate board run inside `execute`'s Final Review, minus the pipeline machinery: **no merge, no plan/spec amendment, no fork, no backlog write, no human sign-off gate.** It reviews, reports, and (only if asked) routes the findings into `/spec-flow:small-change` so any fix gets the full TDD/QA/board discipline — it never patches code itself.

This skill is **standalone** — it does NOT require an active piece, a manifest, or even a spec-flow project layout. It only requires a git repository to compute a diff.

## Step 0: Load config (best-effort)

- Read `.spec-flow.yaml` if present; capture `docs_root` (default `docs`). Used only to discover a charter/spec/PRD for context — never required.
- Confirm the working directory is inside a git repo (`git rev-parse --is-inside-work-tree`). If not, STOP and tell the user the skill needs a git repo to compute a diff.

## Step 1: Resolve the target → a diff + file set

Parse the first positional argument. Resolve it to **a diff string** (the review unit) and a **changed-file set**:

| Argument shape | Resolution |
|---|---|
| All digits (e.g. `412`) | A PR number. `gh pr diff <n>` for the diff; `gh pr view <n> --json headRefName,baseRefName` for refs. Record the PR number for `--comment`. |
| A ref / branch name (`git rev-parse --verify` succeeds) | `base=$(git merge-base <default-branch> <ref>)`; diff = `git diff $base..<ref>`. |
| One or more existing paths (files or dirs) | If the paths have uncommitted/branch changes: `git diff -- <paths>`. If they are unchanged (a "review this file as-is" request): treat the **full file contents** as the review unit and tell each reviewer it is reviewing existing code, not a delta. |
| Blank | Working-tree changes: `git diff HEAD` (staged + unstaged). If empty, fall back to `git diff $(default-branch)..HEAD`. If still empty, STOP — nothing to review. |

Determine the default branch once: `git symbolic-ref refs/remotes/origin/HEAD` → strip to name; else try `main`, then `master`.

Record the changed-file set (`git diff --name-only` on the resolved range, or the path list) for dedup, fix scoping, and `--comment` line mapping.

## Step 2: Resolve context and select lenses

**Default lens set (no spec/PRD needed):** `blind`, `edge-case`, `security`, `ground-truth`, `architecture`.
- `architecture` runs by default because layering, coupling, and dependency-direction judgments apply to almost any code. Discover the charter skills at the resolved charter root (`.github/skills/charter-*/SKILL.md` or `.claude/skills/charter-*/SKILL.md`, per `plugins/spec-flow/reference/charter-location.md`) and pass whatever exists; if none, tell the architecture reviewer to apply general architecture principles (no charter available) rather than skip.
- `ground-truth` always runs — its oracle/correctness lens is the one most likely to catch defects that survive functional tests, and it needs only the diff (plus any worked examples from a spec, if supplied).

**Context-bound lenses — add only when their input is available:**
- `spec-compliance` — add when `--spec PATH` is given, or a spec is unambiguously discoverable for the target (e.g. the branch maps to `<docs_root>/prds/*/specs/<slug>/spec.md`). Pass the spec (and plan if present).
- `prd-alignment` — add when `--prd PATH` is given, or a PRD + manifest are discoverable. Pass PRD + manifest.

**Overrides:**
- `--lenses a,b,c` — run exactly this set (comma-separated lens names), ignoring the defaults. Validate each against the available `review-board-*.md` agents; warn on unknown names.
- `--spec PATH` / `--prd PATH` — supply context explicitly and force-include the corresponding lens.

Log the resolved lens set and why each context-bound lens was included or skipped, so the user knows the review's coverage (no silent omissions).

## Step 3: Dispatch the board (parallel)

Read each selected template from `${CLAUDE_PLUGIN_ROOT}/agents/review-board-<lens>.md` and dispatch ALL selected lenses **concurrently** with `Input Mode: Full` and `model: "opus"`. Compose each prompt with the resolved diff plus that lens's required context:

```
Agent({ description: "Blind review",        prompt: <review-board-blind.md        + Input Mode: Full + diff only>, model: "opus" })
Agent({ description: "Edge case review",    prompt: <review-board-edge-case.md    + Input Mode: Full + diff + codebase note>, model: "opus" })
Agent({ description: "Security review",      prompt: <review-board-security.md     + Input Mode: Full + diff (+ spec for trust-boundary context if available)>, model: "opus" })
Agent({ description: "Ground-truth review", prompt: <review-board-ground-truth.md + Input Mode: Full + diff (+ spec known/expected results if available)>, model: "opus" })
Agent({ description: "Architecture review", prompt: <review-board-architecture.md + Input Mode: Full + diff + charter-if-present-else-general-arch-note>, model: "opus" })
# Added only when their context was resolved in Step 2:
Agent({ description: "Spec compliance review", prompt: <review-board-spec-compliance.md + Input Mode: Full + diff + spec + plan>, model: "opus" })
Agent({ description: "PRD alignment review",   prompt: <review-board-prd-alignment.md   + Input Mode: Full + diff + PRD + manifest>, model: "opus" })
```

Each reviewer is fresh and sees only its prompt — never this conversation.

## Step 4: Collect, dedupe, classify, report

Collect every reviewer's findings. Deduplicate (the same issue raised by multiple lenses → one entry, lenses listed). Classify each:
- `must-fix` — a real defect or violation a reviewer would block merge on
- `should-fix` — non-blocking correctness/quality improvement
- `defer` — pre-existing, not introduced by this change
- `dismiss` — false positive / noise (state why)

Record each lens's own must-fix list separately (needed for `--fix` focused re-review).

Present a consolidated report:

```
## Review Board — <target description>

Lenses run: blind, edge-case, security, ground-truth, architecture[, spec-compliance][, prd-alignment]
Files reviewed: <n>   |   Findings: X must-fix, Y should-fix, Z deferred/dismissed

### Must-fix
- [<lens>] <file:line> — <finding>  →  <suggested fix>
### Should-fix
- [<lens>] <file:line> — <finding>  →  <suggested fix>
### Deferred / Dismissed
- [<lens>] <finding> — <reason>

### Per-lens summary
| Lens | Verdict | Findings |
|------|---------|----------|
| ...  | clean/concerns | n |
```

If neither `--fix` nor `--comment` was passed, stop here.

## Step 5: `--fix` (optional) — remediate via the small-change flow

This skill does **not** patch code itself. Findings found out of band still deserve the same discipline as any other change: a test-first (or Implement-track) fix, a per-phase QA gate, and a re-review by the board. So `--fix` does not call a raw fix agent — it **routes the findings into `/spec-flow:small-change`**, which turns them into a change brief + plan and hands off to `execute`. The fix then passes through the change-track review board (6 members, including `ground-truth`) before it can merge — i.e. the remediation is itself reviewed, closing the loop.

Only when `--fix` is present and must-fix (or operator-selected should-fix) findings exist:

1. **Ownership check.** `--fix` is for code the operator owns (working-tree changes, or a branch you can build on). `small-change` creates a fresh `change/<slug>` worktree off the base branch — it does **not** push onto a third-party PR's branch. If the target is a PR you don't own, do not route to small-change; recommend `--comment` instead and stop.
2. **Compile a findings digest** — the must-fix findings (plus any should-fix the operator opts in), each with `lens`, `file:line`, the problem, and the suggested correction. Mark provenance: `source: review-board`.
3. **Hand off to `/spec-flow:small-change`**, passing the digest as the change description. small-change treats a review-board digest as authoritative requirements (it confirms scope rather than re-brainstorming from zero — see its "Seeded input" provision), writes `brief.md` + `plan.md`, and creates the worktree.
4. small-change ends by instructing the operator to run `/spec-flow:execute change/<slug>` as a **separate** session (per NN-P-001) — this skill does not invoke execute. The fixes are written, QA-gated, and board-reviewed there.

This keeps every out-of-band fix inside the same TDD/QA/review discipline as planned work, instead of landing un-gated edits in the tree.

## Step 6: `--comment` (optional) — post to the PR

## Step 6: `--comment` (optional) — post to the PR

Only when `--comment` is present **and** the target is a PR:
1. For each must-fix and should-fix finding with a `file:line` inside the PR diff, post an inline review comment via `gh api` (`POST /repos/{owner}/{repo}/pulls/{n}/comments` with `path`, `line`, `side`), batched as a single `gh pr review` where practical.
2. Findings that don't map to a diff line go into one summary review comment.
3. Echo back the URLs of posted comments.
If `--comment` is set but the target is not a PR, warn and skip (there is nowhere to post).

## Boundaries — what this skill does NOT do

- **No merge.** It never merges or pushes.
- **No pipeline mutation.** It never amends a plan/spec, forks a piece, writes the backlog, updates a manifest, or touches `.discovery-log.md`. Pipeline triage (Step 6c / Step 8) belongs to `execute`, not here.
- **No sign-off gate.** Findings are advisory; the user decides what to act on.
- **No direct code edits.** `--fix` never patches the tree itself — it routes findings into `/spec-flow:small-change`, so every fix is planned, QA-gated, and re-reviewed by the board. The skill never commits, merges, or invokes `execute`.

For pipeline-integrated review with merge gating and discovery triage, use `/spec-flow:execute` — its Final Review runs the same board with the full routing machinery.
