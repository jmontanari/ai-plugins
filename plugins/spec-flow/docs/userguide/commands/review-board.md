# /spec-flow:review-board

Run the Final Review board out of band on any PR, branch, working-tree changes, or files — decoupled from the end-of-piece merge gate. Reports adversarial findings by severity. Optionally applies fixes (`--fix`) or posts inline PR comments (`--comment`). Never merges, amends, forks, or signs off.

## What it does

Points the same adversarial reviewers that `/spec-flow:execute` runs at end-of-piece at any target you name — running the 6-lens default set (blind, edge-case, security, ground-truth, architecture, integration), or up to 8 when a spec/PRD context is supplied. Reviewers run in parallel and return in roughly the time of the slowest (about one Opus round-trip). Findings are consolidated by severity and returned to you in the main window.

Use it when you want adversarial review without going through the full pipeline: a PR from another contributor, a branch you want to sanity-check before opening a PR, files you're about to merge manually, or a working-tree diff you want reviewed before committing.

## When to run it

- You want a board-level review of a PR without running a full piece through the pipeline.
- You have a branch you want reviewed before opening a PR.
- You want to check a diff or a set of files for correctness, architecture drift, or security issues.
- You want to apply the integration lens specifically to a set of wired paths.
- You're using the `--fix` path to get a planned, QA-gated, board-reviewed fix without a full PRD pipeline entry.

It does **not** require a manifest entry or a piece in any state. It is fully out-of-band.

## Usage

```
/spec-flow:review-board [target] [--fix] [--comment] [--fast]
```

**`target`** — what to review. One of:
- A PR number: `123` or `#123`
- A branch name: `feature/my-branch`
- A diff spec: `main..HEAD` or `HEAD~3..HEAD`
- One or more file paths: `src/foo.py src/bar.py`
- Omit to review uncommitted working-tree changes

**`--fix`** — route must-fix findings into `/spec-flow:small-change` for a planned, QA-gated, board-reviewed fix. Does **not** patch the tree directly. Produces a `docs/changes/<slug>/change-brief.md` + `plan.md` and routes to `execute`.

**`--comment`** — post findings as inline PR comments (requires a PR number target and appropriate GitHub permissions). Findings are posted at the nearest relevant line.

**`--fast`** — add a 9th reviewer (`verify` Mode: Piece Full) for the full theater-pattern catalog and AC binding check across the target's test surface.

**`--context <path>`** — supply a spec.md or prd.md to unlock the spec-compliance and prd-alignment lenses (they are omitted without context).

## The lens set

Six reviewers run in parallel by default (blind, edge-case, security, ground-truth, architecture, integration). Two additional lenses — spec-compliance and prd-alignment — are added when a spec/PRD context is supplied via `--context` or discovery, bringing the total to up to 8:

| Reviewer | Focus |
|---|---|
| **blind** | Just the diff. Bugs, dead references, broken claims — no context. |
| **edge-case** | Failure modes, stale caches, version floors, boundary conditions. |
| **security** | CWE Top 25, injection, crypto, auth/authz, supply chain, language-specific anti-patterns. |
| **ground-truth** | Do computed/measured outputs reproduce an independently-derived correct answer? Degenerate results, lookahead leakage, scope contamination, parity mismatch, silent truncation. |
| **architecture** | Layer boundaries, charter compliance, CR-xxx drift. Requires charter context to be loaded. |
| **integration** | Real wired path across each boundary; path coverage; mock-avalanche detection (over-mocked paths that suppress true integration failures). |
| **spec-compliance** | Every AC honored? *(added when `--context` supplies a spec.md)* |
| **prd-alignment** | Advances PRD goals? Respects non-negotiables? *(added when `--context` supplies a prd.md)* |

In `--fast` mode, a 9th reviewer (`verify` Mode: Piece Full) is added — it applies the full theater-pattern catalog and AC binding check across the target's test surface.

## What it does NOT do

- **Never merges.** The board reports findings; you decide what to do with them.
- **Never patches the tree directly.** Even with `--fix`, changes go through `/spec-flow:small-change` — a planned, QA-gated, board-reviewed track. No direct edits.
- **Never amends, forks, or signs off.** It is purely advisory unless you explicitly route findings through `--fix`.
- **No piece state required.** You do not need a manifest entry, a spec, or a plan to run it.

## Finding severity

Findings are returned in three tiers:

- **must-fix** — correctness bugs, security vulnerabilities, broken contracts, spec violations (when context supplied).
- **should-fix** — non-breaking but high-risk issues; architecture drift; patterns likely to cause future bugs.
- **nit** — style, naming, or clarity issues that have no behavioral impact.

With `--fix`, only `must-fix` and `should-fix` findings are routed into the fix track. Nits are reported but not actioned unless you explicitly ask.

## The `--fix` path

When you pass `--fix`, the skill:

1. Consolidates must-fix and should-fix findings into a structured report.
2. Asks you to confirm which findings to act on.
3. Calls `/spec-flow:small-change` with the confirmed findings as the change brief — a focused brainstorm, scoped plan, and worktree on `change/<slug>`.
4. Routes to `/spec-flow:execute` for the standard TDD/Implement loop with QA gates and a final board review.

This means every `--fix` outcome has the same quality bar as a piece that went through the full pipeline. There are no direct-to-tree patches.

## The `--comment` path

When you pass `--comment` with a PR number target, the skill posts each finding as an inline PR comment at the nearest relevant line. Findings without a file:line anchor are posted as top-level PR comments.

Requires:
- A PR number target (`/spec-flow:review-board 123 --comment`)
- GitHub CLI (`gh`) available in the session

## Circuit breakers

The review board itself has no iteration loop — it reports what it finds in one pass. If you use `--fix` and route findings through `/spec-flow:small-change`, the standard QA circuit breakers apply (3 iterations per QA gate, 2 build attempts, 3 board-review iterations). The board itself does not re-run after fixes unless you invoke it again.

## Comparison with the end-of-piece board

| Property | End-of-piece board (inside execute) | `/spec-flow:review-board` |
|---|---|---|
| Triggered by | Final phase of a piece completing | You, directly |
| Target | The piece's full diff against merge target | Any PR / branch / diff / files |
| Piece required | Yes (manifest entry, `in-progress` state) | No |
| Spec/PRD context | Loaded from the piece's spec/plan | Optional via `--context` |
| Blocks merge | Yes — must clear before execute advances | No — purely advisory |
| Fix path | `fix-code`/`fix-doc` inline in execute | `--fix` → `/spec-flow:small-change` |

Both boards draw from the same pool of reviewer agents, but the end-of-piece execute board runs all 8 lenses unconditionally (spec and PRD context are always present), whereas the review-board command runs the 6-lens default subset unless a spec/PRD context is supplied via `--context`. The end-of-piece board is the mandatory merge gate; this command is the on-demand version you can run at any time.

## Where to go next

- [/spec-flow:execute](./execute.md) — the full pipeline including the mandatory end-of-piece board.
- [/spec-flow:small-change](./small-change.md) — the fix track that `--fix` routes into.
- [QA loop concepts](../concepts/qa-loop.md) — how findings get resolved iteratively.
- [/spec-flow:defer](./defer.md) — record a non-blocking finding to a backlog instead of fixing it now.
