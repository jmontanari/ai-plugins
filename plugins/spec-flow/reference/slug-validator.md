# Slug validator (v3.0.0+)

This document specifies the slug-validation rules every spec-flow skill must enforce when creating worktrees or branches under the v3 multi-PRD layout. The validator is invoked before any `git worktree add` or `git checkout -b` call. On any rule violation, the skill creating the branch refuses with an explicit error — there is no silent truncation, no automatic shortening, no fallback name.

## Rule set

A slug (PRD slug or piece slug) must satisfy every rule below:

- **Length:** must be **at least 1 character** and **at most 20 characters**. The empty string is rejected; a slug of length 0 (or composed entirely of stripped characters after normalization) is never a valid slug.
- **Charset:** `[a-z0-9-]` only (lowercase ASCII letters, digits, and the hyphen).
- **Hyphen position:** must not start with `-` and must not end with `-`. (Combined with the minimum-length rule, single-character slugs `a`–`z` and `0`–`9` are allowed; a single `-` is not.)
- **Reserved words:** none at this time. This is a placeholder for future expansion; today the reserved-word list is empty.

A slug that violates any of these rules is rejected. The skill that attempted to use the slug names it explicitly in the error message (see `## Refusal contract`).

## Branch length budget

Branches that operate on a piece use the fixed prefix `piece` for all pipeline stages, or
`migrate` for the migrate skill: `piece/<prd-slug>-<piece-slug>` and
`migrate/<prd-slug>-<piece-slug>`. The total branch length (including the prefix, the `/`,
the prd-slug, the `-`, and the piece-slug) must remain ≤ 50 characters.

Worked example — passing:

```
prd-slug:    auth     (4 chars)
piece-slug:  tokref   (6 chars)
prefix:      piece
branch:      piece/auth-tokref     (17 chars ≤ 50)
```

Worked example — refused:

```
prd-slug:    user-authentication-service  (27 chars — violates 20-char max)
piece-slug:  tokref                       (6 chars)
REFUSED — prd-slug "user-authentication-service" is 27 characters; limit is 20. Shorten to ≤ 20.
```

The 20-char per-slug rule is the primary defense; the 50-char total branch length is a secondary defense and is checked independently. With both slugs at the 20-char maximum, the worst-case branch is `migrate/<20>-<20>` = 49 characters, just inside the 50-char budget. `piece/<20>-<20>` = 47 characters.

## Branch path-separator rule

Per NFR-006: branches contain **exactly one** `/` separator — the one between the prefix (`piece` or `migrate`) and the slug body. Slugs themselves must not contain `/`. The charset rule (`[a-z0-9-]`) already excludes `/`, but this rule is stated explicitly for clarity and so callers know they can split a branch name on `/` and recover `[prefix, "<prd-slug>-<piece-slug>"]` without ambiguity.

A branch like `piece/auth/tokref` (two `/` separators) is a structural error and must be refused at construction time, not produced and then later parsed-incorrectly downstream.

## Refusal contract

When a slug fails any rule, the skill creating the branch refuses with an error that names:

1. **Which slug** is offending (PRD slug vs piece slug).
2. **The actual value** of the offending slug.
3. **The current length** (when length is the violated rule) or the offending character (when charset is the violated rule).
4. **The limit** (20 characters per slug, 50 characters per branch, or the charset spec `[a-z0-9-]`).

There is no silent truncation. There is no "did-you-mean" auto-fix. The user must edit the manifest (or rename the PRD) and re-run.

Example error message:

```
ERROR: piece-slug "user-authentication-service" is 27 characters; limit is 20.
       Edit docs/prds/auth/manifest.yaml and shorten the slug, then re-run /spec-flow:spec.
```

## Where invoked

Five skills enforce this validator. Each invokes it before creating a branch or worktree:

- `/spec-flow:prd` — when assigning the PRD slug at PRD creation or import time.
- `/spec-flow:spec` — before creating the `piece/<prd-slug>-<piece-slug>` branch and the piece worktree.
- `/spec-flow:plan` — slug validation only (no branch or worktree creation; the `piece/` branch and worktree are inherited from the spec skill).
- `/spec-flow:execute` — slug validation only (no branch or worktree creation; inherits from spec).
- `/spec-flow:migrate` — before producing v3 paths and any branch that operates on the migrated layout.

## See also

- [plugins/spec-flow/reference/v3-path-conventions.md](v3-path-conventions.md) — full v3 layout, path resolution table, and layout version detection.
- [plugins/spec-flow/reference/charter-drift-check.md](charter-drift-check.md) — Phase-1 charter-drift procedure run by every skill that touches a piece.
