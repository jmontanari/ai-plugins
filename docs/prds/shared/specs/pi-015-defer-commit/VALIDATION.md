# Validation — pi-015-defer-commit model

Empirical validation of the deferred-commit / git-free / journal model, run 2026-06-05 with a
concurrent harness driving **real OS processes** running **real `unittest`** against a **shared
git worktree** (Python 3.14, 12 cores). The harness exercises the *concurrent* end state (pi-016's
target), not just this piece's serial default, so the whole model is validated up front.

## Invariants

| # | Invariant | Result | Proves |
|---|-----------|--------|--------|
| INV-1 | git-free concurrent writes → exact, uncorrupted union | PASS | 6 concurrent workers, pure file I/O, no git → working tree = exact 12-file union, all green |
| INV-2 | **scoped** oracle isolates from a sibling's red test | PASS | `unittest tests.test_a` green while sibling `test_z` is red on disk — the Race-2 fix works |
| INV-3 | **whole-suite** oracle IS polluted in the same state | PASS | `discover` fails → Race-2 is real; per-sub-phase scoping is necessary *and* sufficient |
| INV-4 | shared **stable** dependency under concurrency | PASS | 4 workers all importing `pkg/common.py` → all green (stable shared reads are safe) |
| INV-5 | barrier pathspec commit = exact union, journal excluded | PASS | `git add -- <union>` then `git commit -- <union>` → exact union; journal not leaked |
| INV-6 | concurrent per-sub-phase commits collide on `index.lock` | PASS | Proves per-sub-phase commit cannot parallelize → git-free section is mandatory |
| INV-7 | file-scoped recovery leaves siblings byte-identical | PASS | Reset one worker's files (restore + `rm` created) → siblings' hashes unchanged |
| INV-8 | journal resume: greens trusted by hash, only incomplete re-run | PASS | Crash mid-group → resume re-runs only the `pending` sub-phase; completed work untouched |
| INV-9 | shared **runtime** resource collides despite disjoint files | COLLIDES (expected) | file-disjoint ≠ runtime-disjoint — the residual handled lightly in pi-016 (see spec pi-016 seam) |

## Corrections this validation forced into the spec

1. **Barrier commit is add-then-commit (FR-2).** `git commit -- <pathspec>` alone fails with
   `did not match any file(s) known to git` on the **untracked** files the git-free section
   produces. The recipe is `git add -- <union>` then `git commit -- <union>`.
2. **`.gitignore` must cover test/build artifacts (FR-4).** The git-free section runs oracles,
   generating `__pycache__/*.pyc` (and equivalents). The pathspec-only barrier commit already
   excludes them, but the ignore entry prevents any non-pathspec git op from sweeping them.

## INV-9 — the one boundary, and why it is not a correctness risk

Four workers with fully disjoint source files but a hardcoded shared `/tmp` path collided under
concurrency. File-scope (the existing G2 check) is static; runtime-resource sharing is dynamic.
The collision surfaced as a **thrown assertion (loud failure), not a silent false-green**, and
serial execution is proven-correct (INV-1/5/6/7/8). So the pi-016 guarantee is: attempt parallel,
inject `TMPDIR`/port/DB isolation, document a parallel-safety contract (à la `pytest-xdist`), and
**serial-replay any concurrent-group failure** → a runtime collision degrades to *slower*, never
*wrong*. Heavy per-resource declaration is explicitly rejected.

## Reproduce

Harness preserved at `/tmp/ptdd/harness.py` + `/tmp/ptdd/worker.py` (session-local). The synthetic
trace scenarios in the spec's Testing Strategy correspond 1:1 to INV-1…INV-9; the execute phase
re-expresses them as the piece's structural + trace tests.
