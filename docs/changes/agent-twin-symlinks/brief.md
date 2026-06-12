---
charter_snapshot:
  architecture: 2026-06-10
  non-negotiables: 2026-06-05
  tools: 2026-06-10
  processes: 2026-06-01
  flows: 2026-06-01
  coding-rules: 2026-06-01
---

# Change Brief: agent-twin-symlinks

**Slug:** agent-twin-symlinks
**Branch:** change/agent-twin-symlinks
**Status:** final-review-pending
**Type:** small-change (Implement track, tdd: false)

## Source

Surfaced as a synchronous discovery during plan-time exploration of `exec-ready/outcome-acs` (which edits `qa-spec` + `qa-plan`). Operator-directed fix.

## Problem Statement

`plugins/spec-flow/agents/*.agent.md` (the Copilot CLI co-ship variants) are maintained as byte-identical **copies** of `plugins/spec-flow/agents/*.md` (the Claude source), with the invariant enforced only by a `diff` in `tests/e2e/lib/static.sh` (AC-10, gate-evals). The copy model has drifted in **2 of 27 pairs**:

- **qa-plan** — `5.15.0` retired the "Plan over budget (FR-014)" criterion from `qa-plan.md` but never mirrored the removal into `qa-plan.agent.md`. `static.sh` AC-10 byte-identity has been **RED for the qa-plan pair since 5.16.0**.
- **implementer** — drifted; not in the 13 identity-enforced pairs, so the drift is unguarded.

Copies will keep drifting. The fix is structural: make `.agent.md` a symlink to `.md` so there is one source of truth and drift is impossible.

## Functional Requirements

- **FR-1:** Each `plugins/spec-flow/agents/*.agent.md` (27 files) is a **relative, same-directory symlink** to its `.md` twin (`ln -s <name>.md <name>.agent.md`), tracked by git as mode `120000`. `.md` is the single source of truth.
- **FR-2:** The 2 drifted pairs resolve to `.md` content via the symlink (qa-plan → the 5.15.0-correct budget-retired state; implementer → `.md` authoritative). No content is hand-edited.
- **FR-3:** `tests/e2e/lib/static.sh` AC-10 is hardened to assert each `.agent.md` **is a symlink** (`-L`) to its `.md`, in addition to the existing content checks — so a future copy cannot silently reintroduce drift. The full suite passes green (including the previously-red qa-plan pair).
- **FR-4:** `plugins/spec-flow/docs/releasing.md` documents the symlink co-ship mechanism, `rsync -a` symlink preservation, and the Windows `core.symlinks` caveat.
- **FR-5:** Version bumped to **5.16.1** across all four version-bearing files; CHANGELOG entry added.

## Acceptance Criteria

- **AC-1:** `git ls-files -s plugins/spec-flow/agents/*.agent.md` shows mode `120000` for all 27 files; `find plugins/spec-flow/agents -name '*.agent.md' -type l | wc -l` == 27. Independent Test [machine: the two commands above].
- **AC-2:** Each `.agent.md` resolves to content identical to its `.md` twin (symlink target is the sibling `.md`). Independent Test [machine: `for f in plugins/spec-flow/agents/*.agent.md; do cmp -s "$f" "${f%.agent.md}.md" || echo "MISMATCH $f"; done` prints nothing].
- **AC-3:** `static.sh` AC-10 asserts symlink-ness; the full `static.sh` run passes with 0 failures (the qa-plan pair, red since 5.16.0, is now green). Independent Test [machine: run `static.sh`; expect 0 failed].
- **AC-4:** `releasing.md` co-ship section documents the symlink mechanism + rsync-a preservation + Windows caveat. Independent Test [machine: grep `releasing.md` for "symlink", "rsync", "core.symlinks"].
- **AC-5:** All four version-bearing files read `5.16.1` and CHANGELOG has a `## [5.16.1]` entry. Independent Test [machine: the releasing.md verification grep/jq; CHANGELOG head].

## Out of Scope / Non-Goals

- FR-018 / `outcome-acs` content (resumes after this merges; that piece then edits only `.md` files with no twin-lockstep).
- Converting non-agent co-ship files (there are none — only `agents/*.agent.md` are twinned).
- Any change to NN-C-009 (it governs version-descriptor sync, not agent-twin identity — confirmed no twin-byte-identity claim to update).

## Non-Negotiables Honored

- **NN-C-002** (markdown + config only): symlinks are a POSIX filesystem construct; the only executable touched is the existing bash test. No runtime dependency added.
- **NN-C-003** (backward compat within major): Claude reads the real `.md` files and is entirely unaffected; Copilot's `qa-plan` is *corrected* to the already-decided 5.15.0 state (a fix, not a break); no public surface removed. PATCH bump.
- **NN-C-009** (version bump + all host descriptors): all four version-bearing files bumped to 5.16.1.

## Coding Rules Honored

- **CR-005** (repo-root-relative paths): symlink targets are relative same-dir filenames (`qa-spec.md`), no absolute or `../`-traversing paths; doc references stay repo-root-relative.

## Security (C-2)

N/A — markdown co-ship files, a bash test, and docs. No trust boundary, sensitive data, input-validation surface, auth, or secrets. Note: symlinks are **relative, same-directory** to sibling `.md` files (no `../` escape) — no path-traversal surface.
