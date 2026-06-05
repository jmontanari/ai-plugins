# Learnings — shared/pi-021-coherence

A charter-tools coherence linter (`hooks/lint-skill-coherence`) over `skills/*/SKILL.md` +
P2/P3 plan-authoring discipline + an execute pre-board self-check. The piece exists because
pi-015's Final Review caught ~6 cross-step wiring gaps that every per-phase QA passed clean —
this piece mechanizes detection of that gap class.

## What the Final Review board caught that per-phase QA didn't

Per-phase QA validated each phase's diff in isolation and passed all four phases. The
end-of-piece board (fresh context, whole-diff, adversarial) found **4 must-fix** defects that
only surface when you reason about the linter as a *whole artifact against an independently-
derived oracle*:

1. **Phantom-target masking (ground-truth).** invariant-1 registered every bare ordered-list
   `N.` item as a step-resolution target. Consequence: a dangling `Step N` *phantom-resolved*
   against any unrelated `N.` enumeration. AC-9's "zero false positives on the real corpus"
   was TRUE **partly because phantom targets HID real dangling references** — the headline
   invariant was half-blind on the very execute/plan files the piece protects. A green test
   suite + clean per-phase QA coexisted with a confidently-wrong component. **Lesson:** when an
   AC asserts "zero findings," an independent reviewer must check whether zero means *coherent*
   or *masked*. Only the ground-truth lens (re-derive the correct answer, don't trust the
   code's own logic) catches this.

2. **Security via the most boring line (CWE-88).** `find "$arg" -type f -name '*SKILL.md'` with
   no `./` guard: a dash-leading directory arg (`-delete`) is parsed by `find` as an option,
   defaulting the start path to `.` and recursively deleting the working tree. The fix is a
   `case "$arg" in -*) find_dir="./$arg"` guard — note `--` does NOT work (BSD find treats it
   as a path), and a blanket `./` prefix would corrupt absolute pathspecs. **Lesson:** every
   user-arg that reaches `find`/`rm`/`git restore` needs an option-injection guard, and the
   guard must preserve absolute paths.

3. **Code/spec divergence (spec-compliance).** invariant-4 implemented only written-no-read;
   FR-2 required both directions. A reviewer that quotes the spec line catches what a reviewer
   reasoning only about the code cannot.

4. **Per-line vs per-reference scoping (gate-bypass, CWE-693).** A per-*line* cross-skill check
   let an unrelated `<skill>/SKILL.md` token anywhere on a line suppress a legitimate same-file
   self-reference. The fix tracks each `Step N`'s own before/after context (per-reference).

## Engineering gotchas (bash + awk on macOS)

- **An apostrophe inside a single-quoted awk program silently terminates it.** I wrote a
  comment "each ref's own context" *inside* the awk body; the `'` closed the awk string and
  bash then tried to parse the awk source, erroring ~200 lines downstream (`syntax error near
  unexpected token '('`) in a totally unrelated invariant. The error location is nowhere near
  the cause. **Always `bash -n` after editing an embedded-awk heredoc/quote, and grep the awk
  body for stray `'`.**
- **BSD awk (20200816) handles a multibyte `§` (U+00A7) inside a negated bracket class** —
  `§[^...§]+` correctly stops the scan at the next `§`. Validated in isolation before trusting it.
- **The linter computes `PLUGIN_ROOT` from `$0`.** Running a copy from `/tmp` makes
  `REFERENCE_DIR=/reference` and every cross-file pointer false-positives. Dogfood from the real
  hooks/ path, not a temp copy.

## invariant-4 has a heuristic ceiling — and that's by design

The board suggested tuning invariant-4 (same-line write+read → balanced; add `diff` as a read
verb). I **prototyped it and it was net-worse**: it relocated the advisory noise (5 warnings
instead of 4, new `end_sha`/`group_start_sha` consumers) and broke a fixture assertion. FR-2
explicitly scopes invariant-4 as a *syntactic WARNING-only heuristic* that never affects exit.
**Lesson:** a deliberately-fuzzy heuristic has a precision ceiling; chasing its false positives
shifts noise rather than removing it. Honor the spec's "advisory only" boundary instead of
gold-plating. (This is distinct from deferring a real defect — it's recognizing a documented
design limit, which all 6 re-reviewers independently endorsed.)

## Process notes

- **Detached-HEAD drift.** This worktree finished all four phases in *detached HEAD* — the
  branch ref `piece/shared-pi-021-coherence` stayed at the pre-Phase-1 commit while the work
  landed on a detached HEAD line. The merge would have shipped an empty branch. Repaired with
  `git branch -f <branch> <work-tip> && git checkout <branch>`. **Worth a guard in execute:
  assert HEAD is attached to the expected piece branch before each phase commit.** (Candidate
  future opportunity.)
- **fix-as-found held.** Every board finding was fixed in-loop (commits `ec3dffc`, `940957a`),
  not deferred to backlog — per the standing directive. The one genuinely out-of-scope finding
  (`git diff main..HEAD` assuming `main` while this repo's default is `master`, ~5 sites across
  execute/SKILL.md) was routed to a **new tracked manifest piece** (pi-023-base-ref), not a
  backlog entry.
