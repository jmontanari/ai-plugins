# Learnings — manifest-ops

## Patterns that worked well

- **Dual-implementation parity enforced by test, not trust.** Shipping a python fast
  path + pure-bash fallback only stays honest because every subcommand × fixture is
  diffed byte-for-byte between the two engines, and the *bash-when-python-absent* path
  is exercised under a genuinely stripped PATH (not just an env-var mask). The env-var
  mask (`MANIFEST_QUERY_NO_PY=1`) tests a *different* branch than `command -v python3`
  failing — both must be covered.
- **Fix-as-found (no-defer) caught real bugs the green suite hid.** The review board
  found a python cross-device-link crash on the actual repo filesystem layout, a
  symlink-on-PATH dispatch failure, a `ready` mis-resolution of `done` deps, and silent
  dep-graph corruption from inline comments on real prop-firm pieces — none caught by a
  128-assertion suite that only asserted python-vs-bash *parity*.

## Issues QA caught (and the lesson)

- **Parity tests ≠ correctness tests.** Two implementations agreeing byte-for-byte
  proves nothing if both are wrong. Every must-fix from ground-truth (the `done`-alias
  `ready` divergence, the block-comment dep corruption) survived because the suite
  checked self-consistency, not independently-derived expected values. Lesson: golden
  content assertions derived from the fixture by hand, not just cross-engine diffs.
- **Real fixtures expose schema reality.** Using the live `prop_firm` manifest as a
  fixture surfaced that spec-flow manifests use BOTH `dependencies:` and `depends_on:`
  in the wild — the same drift this change fixed in the `status` skill. A synthetic
  fixture would have hidden it.
- **Concurrent-merge version collision is a real hazard.** Master advanced to 5.8.0
  (flywheel-repo) mid-execution, colliding with this piece's own 5.8.0 bump and exposing
  a second `plugin.json` the plan never knew about. The branch had to merge master and
  re-version to 5.9.0. Lesson: a version bump authored against a moving `master` should
  resolve the target version at *merge* time, and version-sync (NN-C-001) must enumerate
  ALL version-bearing files (there were two `plugin.json`s + marketplace).

## Recommendations for future specs

- When a plan touches `plugin.json`/version, enumerate every version-bearing file up
  front (`grep -rl '"version"'`) — don't assume one canonical location.
- For doc-as-code skills whose examples cite a live, drifting file, point examples at a
  stable in-repo fixture so the documented output stays reproducible (ADR-2 rationale).
- The NN-C-002 owner-accepted python exception held up under review *only because* the
  bash fallback is complete and mandatory. If any future change makes python required,
  the exception's justification collapses — keep the parity + python-absent tests as the
  guardrail.

## Deferred follow-up (not done in this change)

- **`scripts/` is undocumented in `charter-architecture`.** The new top-level plugin
  directory `scripts/` (for skill-invoked non-hook executables) is not in the charter's
  plugin-internal-layers list. Editing charter was Out of Scope for this change by
  operator decision; this should be a real follow-up (add `scripts/` to
  `charter-architecture/SKILL.md`, same zero-dependency contract as `hooks/`).
