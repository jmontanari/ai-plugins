# Slug validator (v3.0.0+)

This document specifies the slug-validation rules every spec-flow skill must enforce when creating worktrees or branches under the v3 multi-PRD layout. The validator is invoked before any `git worktree add` or `git checkout -b` call. On any rule violation, the skill creating the branch refuses with an explicit error — there is no silent truncation, no automatic shortening, no fallback name.

## Rule set

A slug (PRD slug or piece slug) must satisfy every rule below:

- **Length:** must be **at least 1 character** and **at most 10 characters**. The empty string is rejected; a slug of length 0 (or composed entirely of stripped characters after normalization) is never a valid slug.
- **Charset:** `[a-z0-9-]` only (lowercase ASCII letters, digits, and the hyphen).
- **Hyphen position:** must not start with `-` and must not end with `-`. (Combined with the minimum-length rule, single-character slugs `a`–`z` and `0`–`9` are allowed; a single `-` is not.)
- **Reserved words:** none at this time. This is a placeholder for future expansion; today the reserved-word list is empty.

A slug that violates any of these rules is rejected. The skill that attempted to use the slug names it explicitly in the error message (see `## Refusal contract`).

## Branch length budget

Branches that operate on a piece are formatted `<verb>/<prd-slug>-<piece-slug>` where `<verb>` is one of `spec`, `plan`, `execute`, or `migrate`. The total branch length (including the verb, the `/`, the prd-slug, the `-`, and the piece-slug) must remain ≤ 50 characters.

Worked example — passing:

```
prd-slug:    auth     (4 chars)
piece-slug:  tokref   (6 chars)
verb:        spec
branch:      spec/auth-tokref     (16 chars ≤ 50)
```

Worked example — refused:

```
prd-slug:    authentication-flow  (20 chars — violates 10-char max)
piece-slug:  tokref               (6 chars)
REFUSED — prd-slug "authentication-flow" exceeds 10-char limit; shorten to ≤ 10.
```

The 10-char per-slug rule is the primary defense; the 50-char total length is a secondary defense for unusual verb/slug combinations and is checked independently.

## Branch path-separator rule

Per NFR-006: branches contain **exactly one** `/` separator — the one between the verb and the slug body. Slugs themselves must not contain `/`. The charset rule (`[a-z0-9-]`) already excludes `/`, but this rule is stated explicitly for clarity and so callers know they can split a branch name on `/` and recover `[verb, "<prd-slug>-<piece-slug>"]` without ambiguity.

A branch like `spec/auth/tokref` (two `/` separators) is a structural error and must be refused at construction time, not produced and then later parsed-incorrectly downstream.

## Refusal contract

When a slug fails any rule, the skill creating the branch refuses with an error that names:

1. **Which slug** is offending (PRD slug vs piece slug).
2. **The actual value** of the offending slug.
3. **The current length** (when length is the violated rule) or the offending character (when charset is the violated rule).
4. **The limit** (10 characters per slug, 50 characters per branch, or the charset spec `[a-z0-9-]`).

There is no silent truncation. There is no "did-you-mean" auto-fix. The user must edit the manifest (or rename the PRD) and re-run.

Example error message:

```
ERROR: piece-slug "authentication-flow" is 19 characters; limit is 10.
       Edit docs/prds/auth/manifest.yaml and shorten the slug, then re-run /spec-flow:spec.
```

## Where invoked

Five skills enforce this validator. Each invokes it before creating a branch or worktree:

- `/spec-flow:prd` — when assigning the PRD slug at PRD creation or import time.
- `/spec-flow:spec` — before creating the `spec/<prd-slug>-<piece-slug>` branch and the piece worktree.
- `/spec-flow:plan` — before creating the `plan/<prd-slug>-<piece-slug>` branch.
- `/spec-flow:execute` — before creating the `execute/<prd-slug>-<piece-slug>` branch.
- `/spec-flow:migrate` — before producing v3 paths and any branch that operates on the migrated layout.

## See also

- [plugins/spec-flow/reference/v3-path-conventions.md](v3-path-conventions.md) — full v3 layout, path resolution table, and layout version detection.
- [plugins/spec-flow/reference/charter-drift-check.md](charter-drift-check.md) — Phase-1 charter-drift procedure run by every skill that touches a piece.
