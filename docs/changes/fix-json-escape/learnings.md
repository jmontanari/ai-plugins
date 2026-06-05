# Learnings: fix-json-escape

**Date:** 2026-06-05
**Piece:** change/fix-json-escape
**Shipped:** 5.1.1

## What Happened

Replaced `escape_for_json()` in `hooks/session-start` with Python3+bash-fallback. Two QA iterations on Phase 1 and three Review Board blockers, all preventable.

## Process Findings

### Plan T-1 target code should be the final, correct implementation

The plan's T-1 target showed the naive `json.dumps(s)[1:-1]` without `ensure_ascii=False` and without the pipefail-safe if-condition pattern. The implementer used T-1 as a spec. Both defects shipped from Phase 1 and required QA iterations.

**Rule:** For bash/shell implement phases, the T-1 target code must be the exact final implementation — including encoding flags, subprocess safety patterns, and shell semantic invariants. If those are unknown at plan time, mark the target as pseudocode and note what the implementer must verify.

### Version-bump phases must enumerate files from releasing.md, not from memory

Phase 2 listed 3 version-bearing files and missed `plugins/spec-flow/plugin.json` (Copilot CLI descriptor). The plan author enumerated files from memory instead of running the authoritative inventory from `releasing.md`. The Review Board caught it.

**Rule:** Any version-bump phase must start by reading `releasing.md` (or equivalent) and explicitly listing every path it names. The phase scope is that list, not what the planner remembers.

### Small-change brainstorm for bash scripts needs two extra prompts

The brainstorm didn't surface bash pipefail semantics or encoding contracts as risks, even though the target was a hook with `set -euo pipefail` and a Python3/bash fallback path.

**Rule:** For any small-change touching a bash script with subprocess invocations or multi-language fallback paths, ask: (a) does if-condition vs then-branch placement affect errexit? (b) do all code paths agree on encoding contracts?

## What Worked

The deferred-commit model survived a context compaction cleanly. The execute phase resumed from `git log` + plan.md checkboxes with no state loss. The Review Board also caught the CHANGELOG parameter typo (`encode_ascii` → `ensure_ascii`) and the stale plan.md T-1 target — low-signal but real.

## Follow-up Opportunities

- **Session-start test harness** (medium scope): No automated tests exist for `escape_for_json` or the hook's JSON output. A `hooks/tests/test-session-start-escape.sh` would make future hook changes verifiable.
- **Escape output caching** (small-change): Charter content is re-escaped on every session start. A cache keyed by file mtime would eliminate redundant Python3 spawns for unchanged files.
- **Single Python3 invocation** (small-change): 6 subprocesses are spawned per session-start. A single invocation that escapes all 6 values in one pass would reduce overhead for the small-string call sites.
