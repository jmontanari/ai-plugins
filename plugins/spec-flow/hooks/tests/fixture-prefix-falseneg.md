---
name: fixture-prefix-falseneg
description: >
  MF-A regression: a genuinely-broken cross-ref pointer whose first word is a
  character-prefix of a real heading in the target reference doc must STILL be
  flagged (invariant-2). The §-scan prefix-match must be word-boundary-guarded so
  `§Purposeful…` does NOT silently resolve against the doc's `## Purpose` heading.
---

# Fixture Prefix False-Negative

## Broken cross-ref guarded by word boundary

The deferred-commit journal is described per
`reference/deferred-commit-journal.md` §Purposeful misdirection that is not a real
heading. This pointer's first word ("purposeful") shares the character prefix
"purpose" with that doc's real `## Purpose` heading, but continues with alnum
("ful"), so it is a genuinely-broken cross-ref and MUST fire invariant-2 — it must
not resolve via an unbounded prefix-match.
